import { z } from 'zod';
import { supabase as supabaseAdmin } from '../../../config/supabase';

export async function execDraftEmail(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid(),
    subject: z.string().trim().min(1).max(300),
    body: z.string().trim().min(1),
    // email_drafts.email_type is NOT NULL in the DB — default it so a draft
    // always carries a type even when the model omits it.
    email_type: z.string().trim().min(1).default('general'),
    event_id: z.string().uuid().optional(),
  }).parse(args);

  const { data: c } = await supabaseAdmin.from('contacts').select('id').eq('id', a.contact_id).eq('user_id', userId).is('deleted_at', null).maybeSingle();
  if (!c) throw new Error('Contact not found or access denied');

  if (a.event_id) {
    const { data: ev } = await supabaseAdmin.from('events').select('id').eq('id', a.event_id).eq('user_id', userId).is('deleted_at', null).maybeSingle();
    if (!ev) throw new Error('Event not found or access denied');
  }

  const { data, error } = await supabaseAdmin.from('email_drafts').insert({
    contact_id: a.contact_id, subject: a.subject, body: a.body,
    email_type: a.email_type, event_id: a.event_id ?? null, status: 'draft',
    user_id: userId,
  }).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}
