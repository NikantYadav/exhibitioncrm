import { Router } from 'express';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { type = 'contacts', event_id } = req.query;

    if (type === 'contacts') {
      const { data: contacts } = await supabase
        .from('contacts')
        .select('*, company:companies(*)')
        .eq('user_id', req.user!.id)
        .is('deleted_at', null)
        .order('created_at', { ascending: false });

      // Simplified - return JSON instead of Excel
      res.json({ data: contacts || [] });
    } else if (type === 'companies') {
      const { data: companies } = await supabase
        .from('companies')
        .select('*')
        .order('name', { ascending: true });

      res.json({ data: companies || [] });
    } else if (type === 'template') {
      res.json({
        message: 'Excel export requires ExcelJS service',
        template: {
          columns: ['first_name', 'last_name', 'email', 'phone', 'job_title', 'company_name']
        }
      });
    } else {
      res.status(400).json({ error: 'Invalid export type' });
    }
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ error: 'Failed to export data' });
  }
});

// GET /api/export/csv
router.get('/csv', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data: contacts, error } = await supabase
      .from('contacts')
      .select(`
        *,
        company:companies(name)
      `)
      .eq('user_id', req.user!.id)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // CSV generation with formula-injection neutralization + RFC-4180 quoting.
    // Every field is quoted (embedded quotes doubled) so commas/newlines can't
    // break out into new columns/rows; and any field starting with a formula
    // trigger (= + - @, or a leading tab/CR) is prefixed with a single quote so
    // spreadsheet apps treat it as text rather than executing it.
    const csvCell = (value: unknown): string => {
      let s = value == null ? '' : String(value);
      if (/^[=+\-@\t\r]/.test(s)) {
        s = `'${s}`;
      }
      return `"${s.replace(/"/g, '""')}"`;
    };

    const headers = ['first_name', 'last_name', 'email', 'phone', 'job_title', 'company'];
    const rows = contacts?.map(c => [
      c.first_name || '',
      c.last_name || '',
      c.email || '',
      c.phone || '',
      c.job_title || '',
      Array.isArray(c.company) ? c.company[0]?.name : c.company?.name || ''
    ]) || [];

    const csv = [
      headers.map(csvCell).join(','),
      ...rows.map(r => r.map(csvCell).join(',')),
    ].join('\r\n');

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="contacts.csv"');
    res.send(csv);
  } catch (error) {
    console.error('CSV export error:', error);
    res.status(500).json({ error: 'Failed to export CSV' });
  }
});

// GET /api/export/excel
router.get('/excel', async (req, res, next) => {
  try {
    const supabase = req.supabase!;
    const { data: contacts, error } = await supabase
      .from('contacts')
      .select(`
        *,
        company:companies(name, industry, website)
      `)
      .eq('user_id', req.user!.id)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Simplified - return JSON (Excel generation requires ExcelJS)
    res.json({
      message: 'Excel export requires ExcelJS library',
      data: contacts || []
    });
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ error: 'Failed to export data' });
  }
});

export default router;
