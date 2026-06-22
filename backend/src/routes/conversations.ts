import { Router } from 'express';
import { z } from 'zod';
import { autoTitleConversation } from '../services/ai/titling';

import multer from 'multer';
import { randomUUID } from 'crypto';
import { requireAuth } from '../middleware/requireAuth';
import { createSupabaseUserClient } from '../config/supabaseClients';
import { supabase as supabaseAdmin } from '../config/supabase';

const router = Router();

router.use(requireAuth);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB
});

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
        firstMsgByConv.set(m.conversation_id, m.content);
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

  const data = (desc ?? []).slice().reverse();
  const next_before = desc && desc.length > 0 ? (desc[desc.length - 1] as any).created_at : null;
  res.json({ data, next_before });
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
  res.json({ data });
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
  const original = req.file.originalname || 'file';
  const ext = (() => {
    const idx = original.lastIndexOf('.');
    if (idx === -1) return '';
    const e = original.slice(idx).toLowerCase();
    return /^[.][a-z0-9]{1,10}$/.test(e) ? e : '';
  })();

  const path = `${userId}/${conversationId}/${randomUUID()}${ext}`;

  const { error: uploadErr } = await supabaseAdmin.storage.from(bucket).upload(path, req.file.buffer, {
    contentType: req.file.mimetype,
    upsert: false,
  });

  if (uploadErr) return res.status(500).json({ error: uploadErr.message });

  const { data: attachment, error: attachErr } = await supabaseUser
    .from('message_attachments')
    .insert({
      message_id: parsed.data.message_id,
      bucket,
      path,
      mime_type: req.file.mimetype,
      size_bytes: req.file.size,
    })
    .select('*')
    .single();

  if (attachErr) return res.status(400).json({ error: attachErr.message });

  const { data: signed, error: signedErr } = await supabaseAdmin.storage.from(bucket).createSignedUrl(path, 60 * 60);
  if (signedErr) return res.status(500).json({ error: signedErr.message });

  res.json({ data: attachment, signed_url: signed.signedUrl });
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
  const supabase = createSupabaseUserClient(req.accessToken!);

  const { error } = await supabase
    .from('conversations')
    .delete()
    .eq('id', conversationId);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ success: true });
});

export default router;
