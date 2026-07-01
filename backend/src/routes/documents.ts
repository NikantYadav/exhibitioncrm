import { Router } from 'express';
import type { SupabaseClient } from '@supabase/supabase-js';
import multer from 'multer';
import { randomUUID } from 'crypto';
import { supabase as supabaseAdmin } from '../config/supabase';
import {
  checkScopedRateLimit, DOC_UPLOAD_SCOPE, DOC_UPLOAD_MAX, DOC_UPLOAD_WINDOW_MS,
} from '../utils/rateLimit';

const router = Router();

// Passive file vault for documents a contact shared. NO AI: files are stored
// as-is in the private `contact-documents` bucket; no extraction/embeddings/
// summaries. Uploads go through the backend (multipart -> service-role storage
// write -> RLS-checked row insert), mirroring chat-attachments/contact-cards.
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 15 * 1024 * 1024 } });
const DOC_BUCKET = 'contact-documents';

async function ownsContact(db: SupabaseClient, userId: string, contactId: string): Promise<boolean> {
  const { data } = await db
    .from('contacts')
    .select('id')
    .eq('id', contactId)
    .eq('user_id', userId)
    .is('deleted_at', null)
    .maybeSingle();
  return data !== null;
}

// POST /api/documents  (multipart/form-data: file + contact_id + optional description)
router.post('/', upload.single('file'), async (req, res) => {
  try {
    const supabase = req.supabase!;          // user client (RLS) for the DB row
    const userId = req.user!.id;
    const { contact_id, description } = req.body;

    if (!contact_id) return res.status(400).json({ error: 'contact_id required' });
    if (!req.file) return res.status(400).json({ error: 'Missing file' });

    // Ownership (defense-in-depth; RLS also enforces on the insert below).
    if (!(await ownsContact(supabase, userId, contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Rate limit — each upload is a storage write.
    const rate = await checkScopedRateLimit(userId, DOC_UPLOAD_SCOPE, DOC_UPLOAD_MAX, DOC_UPLOAD_WINDOW_MS);
    if (!rate.ok) {
      res.setHeader('Retry-After', String(rate.retryAfterSeconds));
      return res.status(429).json({ error: 'Too many uploads. Please retry shortly.' });
    }

    // Server-generated path (NEVER client-controlled). Only a safe extension is
    // carried over from the client filename; the rest is a random UUID.
    const original = req.file.originalname || 'file';
    const ext = (() => {
      const idx = original.lastIndexOf('.');
      if (idx === -1) return '';
      const e = original.slice(idx).toLowerCase();
      return /^[.][a-z0-9]{1,10}$/.test(e) ? e : '';
    })();
    const storage_path = `${userId}/${contact_id}/${randomUUID()}${ext}`;

    // Store via service role (private bucket).
    const { error: upErr } = await supabaseAdmin.storage.from(DOC_BUCKET)
      .upload(storage_path, req.file.buffer, { contentType: req.file.mimetype, upsert: false });
    if (upErr) return res.status(500).json({ error: upErr.message });

    // Signed URL for immediate display (1h; re-signed on every list).
    const { data: signed } = await supabaseAdmin.storage.from(DOC_BUCKET).createSignedUrl(storage_path, 60 * 60);

    // Insert row via user client (RLS-checked). user_id stamped server-side only.
    const { data: doc, error } = await supabase.from('contact_documents').insert({
      contact_id,
      user_id: userId,
      name: original,
      description: description ?? null,
      file_url: signed?.signedUrl ?? '',
      file_type: ext.replace('.', ''),
      file_size: req.file.size,
      bucket: DOC_BUCKET,
      storage_path,
    }).select('*').single();

    if (error) {
      // Best-effort rollback of the stored object so we don't orphan it.
      await supabaseAdmin.storage.from(DOC_BUCKET).remove([storage_path]);
      console.error('Doc save error:', error);
      return res.status(500).json({ error: 'Failed to save document' });
    }

    // No interaction logging: a passive file vault upload is not a contact
    // interaction (the old stub logged one; that behavior is intentionally gone).

    res.json({ success: true, document: doc });
  } catch (error) {
    console.error('Documents upload error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/documents?contact_id=...  — list + re-sign each row's storage URL.
router.get('/', async (req, res) => {
  try {
    const supabase = req.supabase!;
    const { contact_id } = req.query;

    if (!contact_id) return res.status(400).json({ error: 'Contact ID required' });
    if (!(await ownsContact(supabase, req.user!.id, contact_id as string))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { data: documents, error } = await supabase
      .from('contact_documents')
      .select('*')
      .eq('contact_id', contact_id)
      .order('created_at', { ascending: false });

    if (error) return res.status(500).json({ error: 'Failed to fetch' });

    // Signed URLs expire (1h), so re-sign from the durable storage pointer.
    const withUrls = await Promise.all((documents ?? []).map(async (d) => {
      if (!d.storage_path || !d.bucket) return d;  // defensive; post-migration all have it
      const { data: s } = await supabaseAdmin.storage.from(d.bucket).createSignedUrl(d.storage_path, 60 * 60);
      return { ...d, file_url: s?.signedUrl ?? d.file_url };
    }));

    res.json({ documents: withUrls });
  } catch (error) {
    console.error('Documents list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/documents/:id — remove the row + its stored object.
router.delete('/:id', async (req, res) => {
  try {
    const supabase = req.supabase!;

    const { data: doc } = await supabase
      .from('contact_documents')
      .select('id, contact_id, bucket, storage_path')
      .eq('id', req.params.id)
      .maybeSingle();

    if (!doc) return res.status(404).json({ error: 'Document not found' });
    if (!(await ownsContact(supabase, req.user!.id, doc.contact_id))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (doc.storage_path && doc.bucket) {
      await supabaseAdmin.storage.from(doc.bucket).remove([doc.storage_path]); // best-effort
    }

    // RLS-scoped delete; also already ownership-checked above (doubly safe).
    const { error } = await supabase.from('contact_documents').delete().eq('id', req.params.id);
    if (error) return res.status(500).json({ error: 'Failed to delete' });

    res.json({ success: true });
  } catch (error) {
    console.error('Documents delete error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
