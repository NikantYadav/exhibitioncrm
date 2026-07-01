import { Router } from 'express';
import { z } from 'zod';
import { autoTitleConversation, stripMentionDirectives } from '../services/ai/titling';

import multer from 'multer';
import { randomUUID } from 'crypto';
import { requireAuth } from '../middleware/requireAuth';
import { createSupabaseUserClient } from '../config/supabaseClients';
import { supabase as supabaseAdmin } from '../config/supabase';
import { litellm } from '../services/litellm-service';
import {
  extractDocument,
  estimateTokens,
  chunkText,
  INLINE_TOKEN_BUDGET,
  DocumentExtractionError,
} from '../services/document-extraction';
import { sniffImage } from '../utils/imageValidation';
import { compressImage } from '../utils/imageCompression';
import {
  checkScopedRateLimit,
  DOC_UPLOAD_SCOPE,
  DOC_UPLOAD_MAX,
  DOC_UPLOAD_WINDOW_MS,
} from '../utils/rateLimit';

const router = Router();

router.use(requireAuth);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB
});

// Attachments live in the PRIVATE chat-attachments bucket, so a stored `path`
// is not directly fetchable by the client. For each message's attachments we
// mint a short-lived signed URL (images render inline; files offer a download)
// and tag a coarse `kind` (image | file) the Flutter client uses to pick a
// renderer. Best-effort: a failed sign leaves `signed_url` null and the client
// falls back to a file chip.
async function signMessageAttachments(
  messages: Array<Record<string, any>>,
): Promise<Array<Record<string, any>>> {
  const all = messages.flatMap((m) =>
    Array.isArray(m.attachments) ? (m.attachments as Array<Record<string, any>>) : [],
  );
  const IMAGE_EXTS = new Set(['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic']);
  await Promise.all(
    all.map(async (att) => {
      const mime = typeof att.mime_type === 'string' ? att.mime_type : '';
      const path = typeof att.path === 'string' ? att.path : '';
      const ext = path.includes('.') ? path.split('.').pop()!.toLowerCase() : '';
      // mime_type is often a generic "application/octet-stream" (the client does
      // not always set a content type on upload), so fall back to the file
      // extension kept in the storage path to classify images.
      att.kind = mime.startsWith('image/') || IMAGE_EXTS.has(ext) ? 'image' : 'file';
      att.name = path ? path.split('/').pop() : 'file';
      if (typeof att.bucket === 'string' && path) {
        const { data: signed } = await supabaseAdmin.storage
          .from(att.bucket)
          .createSignedUrl(att.path, 60 * 60);
        att.signed_url = signed?.signedUrl ?? null;
      } else {
        att.signed_url = null;
      }
    }),
  );
  return messages;
}

const createConversationSchema = z.object({
  title: z.string().trim().min(1).max(200).optional(),
});

const createAttachmentSchema = z.object({
  message_id: z.string().uuid(),
  bucket: z.string().trim().min(1).max(128),
  path: z.string().trim().min(1).max(1024),
  mime_type: z.string().trim().min(1).max(255).optional(),
  size_bytes: z.number().int().nonnegative().optional(),
});

const uploadAttachmentSchema = z.object({
  message_id: z.string().uuid(),
});

// GET /api/conversations
router.get('/', async (req, res) => {
  const supabase = createSupabaseUserClient(req.accessToken!);

  const { data, error } = await supabase
    .from('conversations')
    .select('*')
    .order('updated_at', { ascending: false });
  if (error) return res.status(400).json({ error: error.message });

  // Enrich each untitled conversation with its first user message as a preview
  // (used as fallback title in the app when AI title hasn't been set yet).
  // Single batched query instead of one per conversation (was an N+1): fetch
  // user messages for all untitled conversations ordered by created_at and
  // keep the earliest seen per conversation.
  const conversations = data ?? [];
  const untitledIds = conversations.filter((c) => !c.title).map((c) => c.id);

  const firstMsgByConv = new Map<string, string>();
  if (untitledIds.length > 0) {
    const { data: msgs } = await supabase
      .from('messages')
      .select('conversation_id, content')
      .in('conversation_id', untitledIds)
      .eq('sender_type', 'user')
      .order('created_at', { ascending: true });
    for (const m of msgs ?? []) {
      if (!firstMsgByConv.has(m.conversation_id)) {
        // Strip @-mention directives so the fallback preview reads naturally.
        firstMsgByConv.set(m.conversation_id, stripMentionDirectives(m.content));
      }
    }
  }

  const enriched = conversations.map((conv) =>
    conv.title
      ? conv
      : { ...conv, first_message_preview: firstMsgByConv.get(conv.id) ?? null }
  );

  res.json({ data: enriched });
});

// POST /api/conversations
router.post('/', async (req, res) => {
  const parsed = createConversationSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const supabase = createSupabaseUserClient(req.accessToken!);
  const userId = req.user!.id;
  const { title } = parsed.data;

  const { data: conversation, error } = await supabase
    .from('conversations')
    .insert({
      user_id: userId,
      title: title ?? null,
    })
    .select('*')
    .single();

  if (error) return res.status(400).json({ error: error.message });

  res.json({ data: conversation, reused: false });
});

// GET /api/conversations/:id/messages
router.get('/:id/messages', async (req, res) => {
  const conversationId = req.params.id;
  const limit = Math.min(200, Math.max(1, Number(req.query.limit ?? 50) || 50));
  const before = typeof req.query.before === 'string' ? req.query.before : undefined;

  const supabase = createSupabaseUserClient(req.accessToken!);

  let query = supabase
    .from('messages')
    .select('*, attachments:message_attachments(*)')
    .eq('conversation_id', conversationId);

  // Pagination: return latest N messages by default.
  // If `before` is provided, return messages strictly older than that timestamp.
  if (before) {
    const d = new Date(before);
    if (Number.isNaN(d.getTime())) return res.status(400).json({ error: 'Invalid before timestamp' });
    query = query.lt('created_at', d.toISOString());
  }

  const { data: desc, error } = await query.order('created_at', { ascending: false }).limit(limit);

  if (error) return res.status(400).json({ error: error.message });

  const data = await signMessageAttachments((desc ?? []).slice().reverse());
  const next_before = desc && desc.length > 0 ? (desc[desc.length - 1] as any).created_at : null;

  // Fold in the latest unresolved pending write so the in-flight poll only needs
  // one round-trip per cycle (was a separate GET /assistant/pending). Same query
  // as that route — user-scoped via supabaseAdmin since it bypasses RLS.
  const { data: pendingAction } = await supabaseAdmin
    .from('assistant_pending_actions')
    .select('id, tool_name, tool_args, summary')
    .eq('conversation_id', conversationId)
    .eq('user_id', req.user!.id)
    .eq('status', 'pending')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  res.json({ data, next_before, pending_action: pendingAction ?? null });
});

// GET /api/conversations/:id/messages/search?q=...
router.get('/:id/messages/search', async (req, res) => {
  const conversationId = req.params.id;
  const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
  if (!q) return res.status(400).json({ error: 'Missing q' });

  const limit = Math.min(50, Math.max(1, Number(req.query.limit ?? 20) || 20));
  const supabase = createSupabaseUserClient(req.accessToken!);

  const { data, error } = await supabase
    .from('messages')
    .select('*, attachments:message_attachments(*)')
    .eq('conversation_id', conversationId)
    .textSearch('content', q, { type: 'websearch', config: 'english' })
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ data: await signMessageAttachments(data ?? []) });
});

// POST /api/conversations/:id/attachments
router.post('/:id/attachments', async (req, res) => {
  const conversationId = req.params.id;
  const parsed = createAttachmentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const supabase = createSupabaseUserClient(req.accessToken!);

  // Ensure the message belongs to this conversation (RLS should also enforce this).
  const { data: message, error: msgErr } = await supabase
    .from('messages')
    .select('id, conversation_id')
    .eq('id', parsed.data.message_id)
    .maybeSingle();

  if (msgErr) return res.status(400).json({ error: msgErr.message });
  if (!message || message.conversation_id !== conversationId) {
    return res.status(400).json({ error: 'Message not found in conversation' });
  }

  const { data, error } = await supabase
    .from('message_attachments')
    .insert({
      message_id: parsed.data.message_id,
      bucket: parsed.data.bucket,
      path: parsed.data.path,
      mime_type: parsed.data.mime_type ?? null,
      size_bytes: parsed.data.size_bytes ?? null,
    })
    .select('*')
    .single();

  if (error) return res.status(400).json({ error: error.message });
  res.json({ data });
});

// POST /api/conversations/:id/attachments/upload (multipart/form-data: file + message_id)
router.post('/:id/attachments/upload', upload.single('file'), async (req, res) => {
  const conversationId = req.params.id;
  const parsed = uploadAttachmentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  if (!req.file) return res.status(400).json({ error: 'Missing file' });

  const supabaseUser = createSupabaseUserClient(req.accessToken!);
  const userId = req.user!.id;

  // Rate-limit uploads: each can trigger vision/embedding calls.
  const rate = await checkScopedRateLimit(userId, DOC_UPLOAD_SCOPE, DOC_UPLOAD_MAX, DOC_UPLOAD_WINDOW_MS);
  if (!rate.ok) {
    res.setHeader('Retry-After', String(rate.retryAfterSeconds));
    return res.status(429).json({ error: 'Too many uploads. Please retry shortly.' });
  }

  // Ensure the message belongs to this conversation
  const { data: message, error: msgErr } = await supabaseUser
    .from('messages')
    .select('id, conversation_id')
    .eq('id', parsed.data.message_id)
    .maybeSingle();

  if (msgErr) return res.status(400).json({ error: msgErr.message });
  if (!message || message.conversation_id !== conversationId) {
    return res.status(400).json({ error: 'Message not found in conversation' });
  }

  const bucket = 'chat-attachments';

  // Re-encode image attachments to a capped-dimension WebP before storing —
  // same rationale as card images (see utils/imageCompression.ts). Type is
  // SNIFFED from magic bytes, never the client-claimed mimetype/extension.
  // Non-image documents (PDF/xlsx/docx/etc.) are already compressed formats
  // and pass through untouched. Best-effort: a compression failure falls
  // back to storing the original buffer rather than failing the upload.
  let uploadBuffer = req.file.buffer;
  let uploadMimeType = req.file.mimetype;
  let ext = (() => {
    const original = req.file!.originalname || 'file';
    const idx = original.lastIndexOf('.');
    if (idx === -1) return '';
    const e = original.slice(idx).toLowerCase();
    return /^[.][a-z0-9]{1,10}$/.test(e) ? e : '';
  })();

  if (sniffImage(req.file.buffer)) {
    try {
      const compressed = await compressImage(req.file.buffer);
      uploadBuffer = compressed.buffer;
      uploadMimeType = compressed.type.mime;
      ext = `.${compressed.type.ext}`;
    } catch (err) {
      console.error('Attachment image compression failed, storing original:', err);
    }
  }

  const path = `${userId}/${conversationId}/${randomUUID()}${ext}`;

  const { error: uploadErr } = await supabaseAdmin.storage.from(bucket).upload(path, uploadBuffer, {
    contentType: uploadMimeType,
    upsert: false,
  });

  if (uploadErr) return res.status(500).json({ error: uploadErr.message });

  const { data: attachment, error: attachErr } = await supabaseUser
    .from('message_attachments')
    .insert({
      message_id: parsed.data.message_id,
      bucket,
      path,
      mime_type: uploadMimeType,
      size_bytes: uploadBuffer.length,
    })
    .select('*')
    .single();

  if (attachErr) return res.status(400).json({ error: attachErr.message });

  const { data: signed, error: signedErr } = await supabaseAdmin.storage.from(bucket).createSignedUrl(path, 60 * 60);
  if (signedErr) return res.status(500).json({ error: signedErr.message });

  // Extract text from the document so the assistant's parse_document tool can
  // read it. Small docs are stored inline (extracted_text); oversized docs are
  // chunked + embedded into document_chunks for retrieval. Best-effort: an
  // extraction failure must not fail the upload — the attachment still exists
  // and extraction_status records the outcome.
  let extraction_status = 'skipped';
  let token_estimate: number | null = null;
  try {
    const { text } = await extractDocument(uploadBuffer, uploadMimeType);
    token_estimate = estimateTokens(text);
    if (token_estimate <= INLINE_TOKEN_BUDGET) {
      extraction_status = 'inline';
      await supabaseAdmin
        .from('message_attachments')
        .update({ extracted_text: text, extraction_status, token_estimate })
        .eq('id', attachment.id);
    } else {
      // Oversized: chunk + embed for the RAG fallback. user_id is stamped from
      // the verified caller (never client input) so chunks are owner-scoped.
      const chunks = chunkText(text);
      const embeddings = await litellm.embed(chunks);
      const rows = chunks.map((content, i) => ({
        attachment_id: attachment.id,
        user_id: userId,
        chunk_index: i,
        content,
        embedding: embeddings[i] ?? null,
      }));
      const { error: chunkErr } = await supabaseAdmin.from('document_chunks').insert(rows);
      if (chunkErr) throw new Error(chunkErr.message);
      extraction_status = 'chunked';
      await supabaseAdmin
        .from('message_attachments')
        .update({ extraction_status, token_estimate })
        .eq('id', attachment.id);
    }
  } catch (e: any) {
    extraction_status = 'failed';
    const reason = e instanceof DocumentExtractionError ? e.message : 'extraction error';
    await supabaseAdmin
      .from('message_attachments')
      .update({ extraction_status, extracted_text: null })
      .eq('id', attachment.id);
    console.warn(`[attachments] extraction failed for ${attachment.id}: ${reason}`);
  }

  res.json({
    data: { ...attachment, extraction_status, token_estimate },
    signed_url: signed.signedUrl,
  });
});

// POST /api/conversations/:id/messages
router.post('/:id/messages', async (req, res) => {
  const conversationId = req.params.id;
  const schema = z.object({ content: z.string().trim().min(1).max(8000) });
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const supabase = createSupabaseUserClient(req.accessToken!);
  const userId = req.user!.id;

  const { data, error } = await supabase
    .from('messages')
    .insert({
      conversation_id: conversationId,
      user_id: userId,
      sender_type: 'user',
      sender_user_id: userId,
      content: parsed.data.content,
    })
    .select('*')
    .single();

  if (error) return res.status(400).json({ error: error.message });

  // Auto-titling service (fire and forget)
  autoTitleConversation(supabase, conversationId, parsed.data.content);

  res.json({ data });
});

// PATCH /api/conversations/:id
router.patch('/:id', async (req, res) => {
  const conversationId = req.params.id;
  const schema = z.object({
    title: z.string().trim().min(1).max(200).optional(),
  });

  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const supabase = createSupabaseUserClient(req.accessToken!);

  const { data, error } = await supabase
    .from('conversations')
    .update(parsed.data)
    .eq('id', conversationId)
    .select('*')
    .single();

  if (error) return res.status(400).json({ error: error.message });
  res.json({ data });
});

// DELETE /api/conversations/:id
router.delete('/:id', async (req, res) => {
  const conversationId = req.params.id;
  const userId = req.user!.id;
  const supabase = createSupabaseUserClient(req.accessToken!);

  const prefix = `${userId}/${conversationId}`;
  const { data: files } = await supabaseAdmin.storage.from('chat-attachments').list(prefix);
  if (files?.length) {
    await supabaseAdmin.storage
      .from('chat-attachments')
      .remove(files.map((f) => `${prefix}/${f.name}`));
  }

  const { error } = await supabase
    .from('conversations')
    .delete()
    .eq('id', conversationId);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ success: true });
});

export default router;
