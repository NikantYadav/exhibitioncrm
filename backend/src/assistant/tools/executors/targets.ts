import { randomUUID } from 'crypto';
import { z } from 'zod';
import { supabase as supabaseAdmin } from '../../../config/supabase';
import { resolveContactId, resolveEventId, resolveCompanyId, assertOwnsEvent, assertOwnsContact } from '../resolvers';

// ─── Per-item helpers — reused by both single-item and bulk executors ─────────

async function addOneTargetContact(
  item: { contact_id?: string; contact_name?: string },
  eventId: string,
  userId: string,
): Promise<Record<string, unknown>> {
  if (!item.contact_id && !item.contact_name) {
    throw new Error('Either contact_id or contact_name is required.');
  }
  const contactId = await resolveContactId(item, userId);
  if (item.contact_id) await assertOwnsContact(contactId, userId);

  // Restore a soft-deleted link rather than inserting a duplicate.
  const { data: softDeleted } = await supabaseAdmin
    .from('contact_events').select('id')
    .eq('contact_id', contactId).eq('event_id', eventId)
    .not('deleted_at', 'is', null).maybeSingle();
  if (softDeleted) {
    const { data, error } = await supabaseAdmin
      .from('contact_events')
      .update({ deleted_at: null, updated_at: new Date().toISOString() })
      .eq('id', softDeleted.id).select('*').single();
    if (error) throw new Error(error.message);
    return { success: true, restored: true, ...data, message: 'Contact added to the event\'s target list.' };
  }

  const { data, error } = await supabaseAdmin
    .from('contact_events')
    .insert({ contact_id: contactId, event_id: eventId, user_id: userId, status: 'not_contacted' })
    .select('*').single();
  if (error) {
    if ((error as any).code === '23505') {
      const { data: existing } = await supabaseAdmin
        .from('contact_events').select('*')
        .eq('contact_id', contactId).eq('event_id', eventId).is('deleted_at', null).maybeSingle();
      return { success: true, already_linked: true, ...(existing ?? { contact_id: contactId, event_id: eventId }), message: 'Contact was already a target for this event.' };
    }
    throw new Error(error.message);
  }
  return { success: true, ...data, message: 'Contact added to the event\'s target list.' };
}

async function addOneTargetCompany(
  item: { company_id?: string; company_name?: string; booth_location?: string; priority?: 'high' | 'medium' | 'low' },
  eventId: string,
  userId: string,
): Promise<Record<string, unknown>> {
  if (!item.company_id && !item.company_name) {
    throw new Error('Either company_id or company_name is required.');
  }
  const companyId = await resolveCompanyId(item);

  const { data: softDeleted } = await supabaseAdmin
    .from('target_companies').select('id')
    .eq('event_id', eventId).eq('company_id', companyId)
    .not('deleted_at', 'is', null).maybeSingle();
  if (softDeleted) {
    const { data, error } = await supabaseAdmin
      .from('target_companies')
      .update({
        deleted_at: null,
        priority: item.priority ?? 'medium',
        booth_location: item.booth_location ?? null,
        status: 'not_contacted',
        updated_at: new Date().toISOString(),
      })
      .eq('id', softDeleted.id).select('*, company:companies(id, name)').single();
    if (error) throw new Error(error.message);
    return { success: true, restored: true, ...data, message: 'Company added to the event\'s target list.' };
  }

  const { data, error } = await supabaseAdmin
    .from('target_companies')
    .insert({
      event_id: eventId,
      company_id: companyId,
      priority: item.priority ?? 'medium',
      status: 'not_contacted',
      booth_location: item.booth_location ?? null,
      user_id: userId,
    })
    .select('*, company:companies(id, name)').single();
  if (error) {
    if ((error as any).code === '23505') {
      const { data: existing } = await supabaseAdmin
        .from('target_companies').select('*, company:companies(id, name)')
        .eq('event_id', eventId).eq('company_id', companyId).is('deleted_at', null).maybeSingle();
      return { success: true, already_targeted: true, ...(existing ?? { event_id: eventId, company_id: companyId }), message: 'Company was already a target for this event.' };
    }
    throw new Error(error.message);
  }
  return { success: true, ...data, message: 'Company added to the event\'s target list.' };
}

// ─── Single-item executors (thin wrappers) ────────────────────────────────────

export async function execAddTargetContactToEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);
  if (a.event_id) await assertOwnsEvent(eventId, userId);

  return addOneTargetContact({ contact_id: a.contact_id, contact_name: a.contact_name }, eventId, userId);
}

// Mirrors POST /api/events/:id/targets — link an existing/new company as a
// company target for an event, with optional booth/hall location. Restores a
// soft-deleted target; idempotent on (event_id, company_id).
export async function execAddTargetCompanyToEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    company_id: z.string().uuid().optional(),
    company_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    booth_location: z.string().trim().max(100).optional(),
    priority: z.enum(['high', 'medium', 'low']).optional(),
  }).refine((v) => !!(v.company_id || v.company_name), {
    message: 'Either company_id or company_name is required.',
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);
  if (a.event_id) await assertOwnsEvent(eventId, userId);

  return addOneTargetCompany(
    { company_id: a.company_id, company_name: a.company_name, booth_location: a.booth_location, priority: a.priority },
    eventId,
    userId,
  );
}

// ─── Bulk executors ───────────────────────────────────────────────────────────

export async function execBulkAddTargetCompaniesToEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    companies: z.array(z.object({
      company_id: z.string().uuid().optional(),
      company_name: z.string().trim().optional(),
      booth_location: z.string().trim().max(100).optional(),
      priority: z.enum(['high', 'medium', 'low']).optional(),
    })).min(1).max(100),
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);
  if (a.event_id) await assertOwnsEvent(eventId, userId);

  const added: Record<string, unknown>[] = [];
  const skipped: { item: unknown; reason: string }[] = [];
  const failed: { item: unknown; error: string }[] = [];

  for (const item of a.companies) {
    try {
      const result = await addOneTargetCompany(item, eventId, userId);
      if ((result as any).already_targeted) {
        skipped.push({ item: { company_id: item.company_id, company_name: item.company_name }, reason: 'Company was already a target for this event.' });
      } else {
        added.push(result);
      }
    } catch (e: any) {
      failed.push({ item: { company_id: item.company_id, company_name: item.company_name }, error: e?.message ?? 'Unknown error' });
    }
  }

  const summary =
    `Added ${added.length} target compan${added.length !== 1 ? 'ies' : 'y'} to the event.` +
    (skipped.length > 0 ? ` ${skipped.length} already targeted (skipped).` : '') +
    (failed.length > 0 ? ` ${failed.length} failed.` : '');

  return { success: true, added, skipped, failed, summary };
}

export async function execBulkAddTargetContactsToEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    contacts: z.array(z.object({
      contact_id: z.string().uuid().optional(),
      contact_name: z.string().trim().optional(),
    })).min(1).max(100),
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);
  if (a.event_id) await assertOwnsEvent(eventId, userId);

  const added: Record<string, unknown>[] = [];
  const skipped: { item: unknown; reason: string }[] = [];
  const failed: { item: unknown; error: string }[] = [];

  for (const item of a.contacts) {
    try {
      const result = await addOneTargetContact(item, eventId, userId);
      if ((result as any).already_linked) {
        skipped.push({ item: { contact_id: item.contact_id, contact_name: item.contact_name }, reason: 'Contact was already a target for this event.' });
      } else {
        added.push(result);
      }
    } catch (e: any) {
      failed.push({ item: { contact_id: item.contact_id, contact_name: item.contact_name }, error: e?.message ?? 'Unknown error' });
    }
  }

  const summary =
    `Added ${added.length} target contact${added.length !== 1 ? 's' : ''} to the event.` +
    (skipped.length > 0 ? ` ${skipped.length} already linked (skipped).` : '') +
    (failed.length > 0 ? ` ${failed.length} failed.` : '');

  return { success: true, added, skipped, failed, summary };
}

// Soft-delete a contact's target link to an event (contact_events).
export async function execRemoveTargetContactFromEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const contactId = await resolveContactId(a, userId);
  const eventId = await resolveEventId(a, userId);

  const { data, error } = await supabaseAdmin
    .from('contact_events')
    .update({ deleted_at: new Date().toISOString() })
    .eq('contact_id', contactId).eq('event_id', eventId)
    .eq('user_id', userId).is('deleted_at', null)
    .select('id');
  if (error) throw new Error(error.message);
  if (!data || data.length === 0) throw new Error('That contact is not a target for this event (nothing to remove).');
  return { success: true, removed: true, contact_id: contactId, event_id: eventId, message: 'Contact removed from the event\'s target list.' };
}

// Soft-delete a company target for an event (target_companies).
export async function execRemoveTargetCompanyFromEvent(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    company_id: z.string().uuid().optional(),
    company_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
  }).refine((v) => !!(v.company_id || v.company_name), {
    message: 'Either company_id or company_name is required.',
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);
  // Resolve an EXISTING company only — never create one just to remove it.
  let companyId = a.company_id;
  if (!companyId) {
    const { data: co } = await supabaseAdmin
      .from('companies').select('id').ilike('name', a.company_name as string).maybeSingle();
    if (!co) throw new Error(`No company named "${a.company_name}" found.`);
    companyId = co.id;
  }

  const { data, error } = await supabaseAdmin
    .from('target_companies')
    .update({ deleted_at: new Date().toISOString() })
    .eq('event_id', eventId).eq('company_id', companyId)
    .eq('user_id', userId).is('deleted_at', null)
    .select('id');
  if (error) throw new Error(error.message);
  if (!data || data.length === 0) throw new Error('That company is not a target for this event (nothing to remove).');
  return { success: true, removed: true, event_id: eventId, company_id: companyId, message: 'Company removed from the event\'s target list.' };
}

// Attach/replace a prep note (talking points) on a target — either a target
// contact (contact_events.notes) or a target company (target_companies.notes)
// within a specific event. The target must already exist.
export async function execAddTargetNote(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    target_type: z.enum(['contact', 'company']),
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    company_id: z.string().uuid().optional(),
    company_name: z.string().trim().optional(),
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    note: z.string().trim().min(1).max(10000),
  }).refine((v) => !!(v.event_id || v.event_name), {
    message: 'Either event_id or event_name is required.',
  }).parse(args);

  const eventId = await resolveEventId(a, userId);

  if (a.target_type === 'contact') {
    if (!a.contact_id && !a.contact_name) throw new Error('Either contact_id or contact_name is required for a contact note.');
    const contactId = await resolveContactId(a, userId);
    const { data, error } = await supabaseAdmin
      .from('contact_events')
      .update({ notes: a.note, updated_at: new Date().toISOString() })
      .eq('contact_id', contactId).eq('event_id', eventId)
      .eq('user_id', userId).is('deleted_at', null)
      .select('id, contact_id, event_id, notes');
    if (error) throw new Error(error.message);
    if (!data || data.length === 0) throw new Error('That contact is not a target for this event — add them as a target first.');
    return { success: true, target_type: 'contact', contact_id: contactId, event_id: eventId, note: a.note, message: 'Prep note saved for the target contact.' };
  }

  // company target
  if (!a.company_id && !a.company_name) throw new Error('Either company_id or company_name is required for a company note.');
  let companyId = a.company_id;
  if (!companyId) {
    const { data: co } = await supabaseAdmin
      .from('companies').select('id').ilike('name', a.company_name as string).maybeSingle();
    if (!co) throw new Error(`No company named "${a.company_name}" found.`);
    companyId = co.id;
  }

  // Resolve the owning target row id (scoped to this user) so we can append
  // atomically. supabaseAdmin bypasses RLS, so .eq('user_id', userId) here is
  // the ownership boundary.
  const { data: existingRow, error: readErr } = await supabaseAdmin
    .from('target_companies')
    .select('id')
    .eq('event_id', eventId).eq('company_id', companyId)
    .eq('user_id', userId).is('deleted_at', null)
    .maybeSingle();
  if (readErr) throw new Error(readErr.message);
  if (!existingRow) throw new Error('That company is not a target for this event — add it as a target first.');

  // Append via the atomic RPC (read-modify-write in a single UPDATE) so a
  // concurrent add from the prep screen can't be clobbered by a stale replace.
  // The RPC re-checks ownership via p_user_id and raises if the row isn't ours.
  const { error } = await supabaseAdmin.rpc('append_target_company_note', {
    p_target_id: existingRow.id,
    p_user_id: userId,
    p_note_id: randomUUID(),
    p_body: a.note,
    p_created_at: new Date().toISOString(),
  });
  if (error) {
    if (error.message?.includes('not found or not owned')) {
      throw new Error('That company is not a target for this event — add it as a target first.');
    }
    throw new Error(error.message);
  }
  return { success: true, target_type: 'company', company_id: companyId, event_id: eventId, note: a.note, message: 'Prep note added for the target company.' };
}
