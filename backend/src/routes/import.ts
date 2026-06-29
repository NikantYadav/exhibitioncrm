import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth';
import multer from 'multer';
import ExcelJS from 'exceljs';

/** Keys that must never become object properties (prototype-pollution guard). */
const FORBIDDEN_KEYS = new Set(['__proto__', 'constructor', 'prototype']);

/**
 * Parse an xlsx/xls/csv buffer into an array of plain objects keyed by the
 * first-row headers. Uses exceljs; falls back to CSV text-split for .csv.
 */
async function parseSpreadsheetBuffer(buf: Buffer): Promise<Record<string, string>[]> {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) as ArrayBuffer);
  const ws = wb.worksheets[0];
  if (!ws) return [];

  const rows: Record<string, string>[] = [];
  let headers: string[] = [];
  ws.eachRow((row, rowNumber) => {
    const values = (row.values as ExcelJS.CellValue[]).slice(1); // index 0 is always null
    if (rowNumber === 1) {
      headers = values.map((v) => (v == null ? '' : String(v).trim()));
      return;
    }
    const obj = Object.create(null) as Record<string, string>;
    headers.forEach((key, i) => {
      if (!key || FORBIDDEN_KEYS.has(key)) return;
      const cell = values[i];
      obj[key] = cell == null ? '' : String(cell).trim();
    });
    rows.push(obj);
  });
  return rows;
}

const router = Router();

router.use(requireAuth);

const ALLOWED_MIME_TYPES = new Set([
  'text/csv',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/octet-stream',
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (_req, file, cb) => {
    const ext = file.originalname.split('.').pop()?.toLowerCase() ?? '';
    if (ALLOWED_MIME_TYPES.has(file.mimetype) || ['csv', 'xlsx', 'xls'].includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only CSV, XLSX, and XLS files are allowed'));
    }
  },
});

// POST /api/import
// Accepts CSV / XLSX / XLS with columns: name/first_name, last_name, company/company_name, phone, email
router.post('/', upload.single('file'), async (req: any, res, next) => {
  try {
    const supabase = req.supabase!;
    if (!req.file) {
      res.status(400).json({ error: 'File is required' });
      return;
    }

    const rows = await parseSpreadsheetBuffer(req.file.buffer);

    const results = { imported: 0, skipped: 0, errors: [] as string[] };

    for (const row of rows) {
      // Accept flexible column names
      const firstName = (row['first_name'] || row['First Name'] || row['firstname'] || row['name'] || row['Name'] || '').toString().trim();
      const lastName = (row['last_name'] || row['Last Name'] || row['lastname'] || '').toString().trim();
      const companyName = (row['company'] || row['Company'] || row['company_name'] || row['Company Name'] || '').toString().trim();
      const email = (row['email'] || row['Email'] || '').toString().trim().toLowerCase();
      const phone = (row['phone'] || row['Phone'] || row['mobile'] || row['Mobile'] || '').toString().trim();
      const jobTitle = (row['job_title'] || row['Job Title'] || row['title'] || row['Title'] || row['role'] || row['Role'] || '').toString().trim();

      if (!firstName) {
        results.skipped++;
        continue;
      }

      try {
        // Find or create company
        let companyId: string | null = null;
        if (companyName) {
          const { data: existingCo } = await supabase
            .from('companies')
            .select('id')
            .ilike('name', companyName)
            .limit(1)
            .single();

          if (existingCo) {
            companyId = existingCo.id;
          } else {
            const { data: newCo } = await supabase
              .from('companies')
              .insert({ name: companyName })
              .select('id')
              .single();
            companyId = newCo?.id ?? null;
          }
        }

        // Skip exact duplicates (same user + email)
        if (email) {
          const { data: dup } = await supabase
            .from('contacts')
            .select('id')
            .eq('user_id', req.user!.id)
            .eq('email', email)
            .is('deleted_at', null)
            .maybeSingle();
          if (dup) {
            results.skipped++;
            continue;
          }
        }

        const { error } = await supabase.from('contacts').insert({
          first_name: firstName,
          last_name: lastName || null,
          email: email || null,
          phone: phone || null,
          job_title: jobTitle || null,
          company_id: companyId,
          user_id: req.user!.id,
        });

        if (error) {
          results.errors.push(`Failed to import ${firstName} ${lastName}: ${error.message}`);
        } else {
          results.imported++;
        }
      } catch (e: any) {
        results.errors.push(e.message || `Error processing row`);
      }
    }

    res.json({
      data: results,
      imported: results.imported,
      skipped: results.skipped,
      message: `Import complete: ${results.imported} added, ${results.skipped} skipped`,
    });
  } catch (error) {
    next(error);
  }
});

export default router;
