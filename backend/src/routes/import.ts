import { Router } from 'express';
import { supabase } from '../config/supabase';
import multer from 'multer';
import * as XLSX from 'xlsx';

const router = Router();
const upload = multer({ storage: multer.memoryStorage() });

// POST /api/import
// Accepts CSV / XLSX / XLS with columns: name/first_name, last_name, company/company_name, phone, email
router.post('/', upload.single('file'), async (req: any, res, next) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: 'File is required' });
      return;
    }

    const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const rows: Record<string, string>[] = XLSX.utils.sheet_to_json(sheet, { defval: '' });

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
