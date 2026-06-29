import { z } from 'zod';
import { supabase as supabaseAdmin } from '../../../config/supabase';
import { stripImmutable, toIso, scannedDetailsSchema, mergeScannedDetails } from '../validation';
import { resolveContactId, resolveEventId, assertOwnsEvent } from '../resolvers';
import { saveAttachmentAsCard } from './documents';

// ─── Per-contact item Zod schema (reused by both single and bulk) ─────────────
const contactItemSchema = z.object({
  first_name: z.string().trim().min(1),
  last_name: z.string().trim().optional(),
  email: z.string().trim().email().optional(),
  phone: z.string().trim().optional(),
  job_title: z.string().trim().optional(),
  linkedin_url: z.string().trim().optional(),
  scanned_details: scannedDetailsSchema.optional(),
  company_id: z.string().uuid().optional(),
  company_name: z.string().trim().optional(),
  event_id: z.string().uuid().optional(),
  is_priority: z.boolean().optional(),
  card_attachment_id: z.string().uuid().optional(),
});

type ContactItem = z.infer<typeof contactItemSchema>;

// ─── Core single-contact logic — called by both single and bulk executors ─────
async function createOneContact(item: ContactItem, userId: string): Promise<Record<string, unknown>> {
  // Verify the linked event belongs to this user
  if (item.event_id) {
    const { data: ev } = await supabaseAdmin.from('events').select('id').eq('id', item.event_id).eq('user_id', userId).is('deleted_at', null).maybeSingle();
    if (!ev) throw new Error('Event not found or access denied');
  }

  // Deduplication: refuse to create a contact that already exists for this user.
  // Match on email (strongest signal) when present, else on exact first+last
  // name. The model is told to report the existing contact, not duplicate it.
  {
    let dup = supabaseAdmin
      .from('contacts')
      .select('id, first_name, last_name, email')
      .eq('user_id', userId)
      .is('deleted_at', null);
    if (item.email) {
      dup = dup.ilike('email', item.email);
    } else {
      dup = dup.ilike('first_name', item.first_name);
      dup = item.last_name ? dup.ilike('last_name', item.last_name) : dup.is('last_name', null);
    }
    const { data: existing } = await dup.limit(1).maybeSingle();
    if (existing) {
      const who = `${existing.first_name ?? ''} ${existing.last_name ?? ''}`.trim();
      throw new Error(
        `A contact already exists${who ? ` for "${who}"` : ''}${existing.email ? ` (${existing.email})` : ''} ` +
        `(id: ${existing.id}). Not creating a duplicate — tell the user it already exists, ` +
        `and use update_contact if they want to change it.`,
      );
    }
  }

  let company_id = item.company_id;
  if (item.company_name && !company_id) {
    const { data: existing } = await supabaseAdmin.from('companies').select('id').ilike('name', item.company_name).maybeSingle();
    if (existing?.id) {
      company_id = existing.id;
    } else {
      const { data: newCo, error } = await supabaseAdmin.from('companies').insert({ name: item.company_name }).select('id').single();
      if (error) throw new Error(error.message);
      company_id = newCo.id;
    }
  }

  // Generic copy of the plain column values: every provided field flows through
  // except the linking/resolver keys handled explicitly below.
  const LINKING_KEYS = new Set(['company_id', 'company_name', 'event_id', 'card_attachment_id']);
  const insert: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(item)) {
    if (v === undefined || LINKING_KEYS.has(k)) continue;
    insert[k] = v;
  }
  // Normalise scanned_details (drop empty-string keys) — no existing on create.
  if (item.scanned_details !== undefined) {
    insert.scanned_details = mergeScannedDetails(null, item.scanned_details);
  }
  const { data: contact, error } = await supabaseAdmin
    .from('contacts')
    .insert({ ...stripImmutable(insert), company_id, user_id: userId })
    .select('*').single();
  if (error) throw new Error(error.message);

  if (item.event_id) {
    await supabaseAdmin.from('interactions').insert({ contact_id: contact.id, event_id: item.event_id, interaction_type: 'capture', summary: 'Added by assistant', user_id: userId });
    await supabaseAdmin.from('captures').insert({ contact_id: contact.id, event_id: item.event_id, capture_type: 'manual', status: 'completed', raw_data: { source: 'assistant' }, user_id: userId });
  }

  // If the contact was read from an attached business-card image, copy that
  // image into the contact-cards bucket and create a card_scan capture so it is
  // viewable via "View card" in the app. Best-effort: a failure here must not
  // fail contact creation (the contact still exists, just without a card image).
  if (item.card_attachment_id) {
    try {
      await saveAttachmentAsCard(item.card_attachment_id, contact.id, item.event_id ?? null, userId);
    } catch (e) {
      console.warn(`[create_contact] could not save card image: ${(e as Error).message}`);
    }
  }

  return contact as Record<string, unknown>;
}

export async function execCreateContact(args: Record<string, unknown>, userId: string) {
  const item = contactItemSchema.parse(args);
  return createOneContact(item, userId);
}

export async function execBulkImportContacts(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    event_id: z.string().uuid().optional(),
    event_name: z.string().trim().optional(),
    contacts: z.array(contactItemSchema).min(1).max(100),
  }).parse(args);

  // Resolve the shared event once (if provided), then verify ownership.
  let sharedEventId: string | undefined;
  if (a.event_id || a.event_name) {
    sharedEventId = await resolveEventId(a, userId);
    if (a.event_id) await assertOwnsEvent(sharedEventId, userId);
  }

  const created: Record<string, unknown>[] = [];
  const skipped: { item: unknown; reason: string }[] = [];
  const failed: { item: unknown; error: string }[] = [];

  for (const item of a.contacts) {
    // Inject the resolved shared event id if the item didn't supply its own.
    const resolved: ContactItem = {
      ...item,
      event_id: item.event_id ?? sharedEventId,
    };
    try {
      const contact = await createOneContact(resolved, userId);
      created.push(contact);
    } catch (e: any) {
      const msg: string = e?.message ?? 'Unknown error';
      // Deduplicate errors are expected and non-fatal — report as skipped.
      if (msg.includes('already exists')) {
        skipped.push({ item: { first_name: item.first_name, last_name: item.last_name, email: item.email }, reason: msg });
      } else {
        failed.push({ item: { first_name: item.first_name, last_name: item.last_name, email: item.email }, error: msg });
      }
    }
  }

  const eventLabel = sharedEventId ? ` into event` : '';
  const summary =
    `Imported ${created.length} contact${created.length !== 1 ? 's' : ''}${eventLabel}.` +
    (skipped.length > 0 ? ` ${skipped.length} skipped (already exist).` : '') +
    (failed.length > 0 ? ` ${failed.length} failed.` : '');

  return { success: true, created, skipped, failed, summary };
}

export async function execUpdateContact(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    contact_id: z.string().uuid().optional(),
    contact_name: z.string().trim().optional(),
    first_name: z.string().trim().optional(),
    last_name: z.string().trim().optional(),
    email: z.string().trim().email().optional(),
    phone: z.string().trim().optional(),
    job_title: z.string().trim().optional(),
    linkedin_url: z.string().trim().optional(),
    is_priority: z.boolean().optional(),
    follow_up_status: z.string().trim().optional(),
    last_contacted_at: z.any().optional(),
    scanned_details: scannedDetailsSchema.optional(),
  }).refine((v) => !!(v.contact_id || v.contact_name), {
    message: 'Either contact_id or contact_name is required.',
  }).parse(args);

  const contactId = await resolveContactId(a, userId);

  // Build the update from every provided value except the resolver keys (which
  // pick the target, not a column) and any specially-handled field. Adding a new
  // editable field then means only adding it to the Zod schema above.
  const RESOLVER_KEYS = new Set(['contact_id', 'contact_name', 'last_contacted_at', 'scanned_details']);
  const raw: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(a)) {
    if (v === undefined || RESOLVER_KEYS.has(k)) continue;
    raw[k] = v;
  }
  if (a.last_contacted_at !== undefined) raw.last_contacted_at = toIso(a.last_contacted_at, 'last_contacted_at');

  // scanned_details is merged into the existing object so editing one field
  // never wipes the rest of the scanned card data.
  if (a.scanned_details !== undefined) {
    const { data: existing } = await supabaseAdmin
      .from('contacts').select('scanned_details')
      .eq('id', contactId).eq('user_id', userId).is('deleted_at', null).maybeSingle();
    raw.scanned_details = mergeScannedDetails(existing?.scanned_details as Record<string, unknown> | null, a.scanned_details);
  }

  const update = stripImmutable(raw);
  if (Object.keys(update).length === 0) throw new Error('No valid fields to update');

  // user_id filter ensures the LLM cannot update a contact belonging to another user
  const { data, error } = await supabaseAdmin.from('contacts').update(update).eq('id', contactId).eq('user_id', userId).is('deleted_at', null).select('*').maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Contact not found or access denied');
  return data;
}
