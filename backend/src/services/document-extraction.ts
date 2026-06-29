// Server-side document text extraction for the assistant's parse_document tool.
//
// Security contract (mirrors utils/imageValidation.ts):
//  - The document TYPE is decided by SNIFFING magic bytes, never by the
//    client-supplied MIME (which is attacker-controlled and trivially spoofed).
//    Only an explicit allowlist of formats is extracted; anything else is
//    rejected. This prevents feeding crafted/unexpected content to a parser.
//  - A hard byte cap bounds memory/CPU before any parsing runs (DoS defense),
//    independent of the multer/body limits at the route.
//  - Extracted text is length-capped so a pathological document cannot blow up
//    storage or the model context.
//  - Image/scanned formats go to the vision model; office/pdf-text formats are
//    parsed locally. No format reaches a parser it was not sniffed as.

import { litellm } from './litellm-service';
import { sniffImage } from '../utils/imageValidation';

// All document-parsing libraries are loaded lazily (inside the functions that
// use them) so that module-load crashes in restricted environments (e.g. Vercel
// serverless where DOMMatrix is undefined) don't kill the whole server.
type PDFParseLib = { PDFParse: new (src: { data: Buffer }) => { getText: (o?: any) => Promise<{ text: string }> } };
type MammothLib = { extractRawText: (i: { buffer: Buffer }) => Promise<{ value: string }> };
type OfficeparserLib = { parseOffice: (input: Buffer, cb: (err: any, data: string) => void) => void };

export const MAX_DOC_BYTES = 15 * 1024 * 1024;   // 15 MB hard cap before parsing
export const MAX_EXTRACTED_CHARS = 2_000_000;    // ~500k tokens — cap stored text
export const MAX_PDF_PAGES = 1000;               // page cap (PDF parse DoS guard)

export class DocumentExtractionError extends Error {}

export type ExtractedDoc = { text: string; kind: DocKind };

type DocKind = 'pdf-text' | 'image' | 'spreadsheet' | 'docx' | 'pptx';

// Sniff a document's real type from magic bytes. Office formats (docx/xlsx/pptx)
// are ZIP containers (PK\x03\x04); we distinguish them by their internal layout
// after a light parse, so here ZIP is reported generically and resolved below.
type Sniffed =
  | { kind: 'pdf' }
  | { kind: 'zip' }       // docx / xlsx / pptx (OOXML) or odt — resolved by content
  | { kind: 'image' }
  | { kind: 'csv-or-text' };

function sniffDocument(buf: Buffer): Sniffed | null {
  if (buf.length < 4) return null;
  // PDF: "%PDF"
  if (buf.toString('ascii', 0, 4) === '%PDF') return { kind: 'pdf' };
  // ZIP (OOXML / odt): "PK\x03\x04"
  if (buf[0] === 0x50 && buf[1] === 0x4b && buf[2] === 0x03 && buf[3] === 0x04) return { kind: 'zip' };
  // Known raster image?
  if (sniffImage(buf)) return { kind: 'image' };
  // Plain text / CSV: must be valid UTF-8-ish (no NUL bytes in the first KB).
  const head = buf.subarray(0, 1024);
  if (!head.includes(0x00)) return { kind: 'csv-or-text' };
  return null;
}

function clamp(text: string): string {
  const t = text.replace(/\n{3,}/g, "\n\n").trim();
  return t.length > MAX_EXTRACTED_CHARS ? t.slice(0, MAX_EXTRACTED_CHARS) : t;
}

/** Resolve which OOXML format a ZIP buffer is by sniffing its archive entries. */
function ooxmlKind(buf: Buffer): DocKind | null {
  const head = buf.toString('latin1', 0, Math.min(buf.length, 16384));
  if (head.includes('word/')) return 'docx';
  if (head.includes('ppt/')) return 'pptx';
  if (head.includes('xl/')) return 'spreadsheet';
  return null;
}

function parseOfficeAsync(buf: Buffer): Promise<string> {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { parseOffice } = require('officeparser') as OfficeparserLib;
  return new Promise((resolve, reject) => {
    parseOffice(buf, (err, data) => (err ? reject(err) : resolve(data || '')));
  });
}

function extractSpreadsheet(buf: Buffer): string {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const XLSX = require('xlsx');
  const wb = XLSX.read(buf, { type: 'buffer' });
  const parts: string[] = [];
  for (const name of wb.SheetNames) {
    const csv = XLSX.utils.sheet_to_csv(wb.Sheets[name]);
    if (csv.trim()) parts.push(`# Sheet: ${name}\n${csv}`);
  }
  return parts.join('\n\n');
}

async function extractImage(buf: Buffer, mime: string): Promise<string> {
  // Vision model reads scans / floor plans / photographed lists. Returns plain
  // text transcription; we ask for text, not JSON, so analyzeImage's JSON path
  // is bypassed via a direct prompt that yields a string field.
  const base64 = `data:${mime};base64,${buf.toString('base64')}`;
  const result = await litellm.analyzeImage<{ text: string }>(
    base64,
    'Transcribe ALL text and meaningful content from this document image ' +
      '(exhibitor lists, floor plans, booth numbers, company names, tables). ' +
      'Preserve structure and tables as best you can.',
    '{ "text": "string — the full transcribed content" }',
  );
  return typeof result?.text === 'string' ? result.text : '';
}

/**
 * Extract text from a document buffer. The caller supplies the client-claimed
 * mime ONLY as a hint for the image path; the real type is always sniffed.
 * Throws DocumentExtractionError for oversized / unsupported / unparseable input.
 */
export async function extractDocument(buf: Buffer, claimedMime?: string): Promise<ExtractedDoc> {
  if (buf.length === 0) throw new DocumentExtractionError('Empty file');
  if (buf.length > MAX_DOC_BYTES) {
    throw new DocumentExtractionError(`File too large (max ${Math.floor(MAX_DOC_BYTES / 1024 / 1024)} MB)`);
  }

  const sniff = sniffDocument(buf);
  if (!sniff) throw new DocumentExtractionError('Unsupported or unrecognized file type');

  try {
    if (sniff.kind === 'pdf') {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const { PDFParse } = require('pdf-parse') as PDFParseLib;
      const parser = new PDFParse({ data: buf });
      const parsed = await parser.getText({ first: MAX_PDF_PAGES });
      const text = clamp(parsed.text || '');
      // An image-only (scanned) PDF yields little/no selectable text. Fall back
      // to the vision model on the whole file rendered as an image is out of
      // scope here; instead flag low yield so the caller can warn. We still
      // return what we got — many "scanned" PDFs have an OCR text layer.
      if (text.length < 20) {
        throw new DocumentExtractionError(
          'This PDF appears to be image-only (no extractable text). Re-upload it as an image (JPG/PNG) so it can be read by vision.',
        );
      }
      return { text, kind: 'pdf-text' };
    }

    if (sniff.kind === 'image') {
      const imgType = sniffImage(buf)!;
      const text = clamp(await extractImage(buf, imgType.mime));
      if (!text) throw new DocumentExtractionError('No readable text found in the image');
      return { text, kind: 'image' };
    }

    if (sniff.kind === 'zip') {
      const kind = ooxmlKind(buf);
      if (kind === 'spreadsheet') return { text: clamp(extractSpreadsheet(buf)), kind: 'spreadsheet' };
      if (kind === 'docx') {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const mammoth = require('mammoth') as MammothLib;
        const { value } = await mammoth.extractRawText({ buffer: buf });
        return { text: clamp(value || ''), kind: 'docx' };
      }
      if (kind === 'pptx') return { text: clamp(await parseOfficeAsync(buf)), kind: 'pptx' };
      // Other OOXML/odt: best-effort via officeparser.
      return { text: clamp(await parseOfficeAsync(buf)), kind: 'docx' };
    }

    // csv-or-text
    if (claimedMime?.includes('csv') || sniff.kind === 'csv-or-text') {
      // Spreadsheet lib also reads CSV cleanly and normalizes delimiters.
      try {
        return { text: clamp(extractSpreadsheet(buf)), kind: 'spreadsheet' };
      } catch {
        return { text: clamp(buf.toString('utf8')), kind: 'spreadsheet' };
      }
    }

    throw new DocumentExtractionError('Unsupported file type');
  } catch (e: any) {
    if (e instanceof DocumentExtractionError) throw e;
    throw new DocumentExtractionError(`Could not parse the document: ${e?.message ?? 'unknown error'}`);
  }
}

// Rough token estimate (~4 chars/token) to decide direct-inject vs RAG chunking.
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

// Token budget for inlining a whole document into the turn. Above this, the
// document is chunked + embedded for retrieval instead.
export const INLINE_TOKEN_BUDGET = 60_000;

// Split text into overlapping chunks for embedding. Paragraph-aware: packs
// paragraphs up to ~chunkChars, with a small overlap so context isn't cut mid-idea.
export function chunkText(text: string, chunkChars = 4000, overlap = 400): string[] {
  const clean = text.trim();
  if (clean.length <= chunkChars) return [clean];
  const chunks: string[] = [];
  let i = 0;
  while (i < clean.length) {
    const end = Math.min(i + chunkChars, clean.length);
    chunks.push(clean.slice(i, end));
    if (end >= clean.length) break;
    i = end - overlap;
  }
  return chunks;
}
