import { supabase as supabaseAdmin } from '../../config/supabase';

// Resolve a target record from a direct UUID or a name, and verify ownership.
// Name lookups are user-scoped; a directly-supplied UUID is trusted by the
// resolver, so INSERT paths that use it as an FK must call the matching
// assertOwns* guard (see backend/CLAUDE.md write-tool checklist).

export async function resolveContactId(
  args: { contact_id?: string; contact_name?: string },
  userId: string,
): Promise<string> {
  if (args.contact_id) return args.contact_id;

  if (!args.contact_name) {
    throw new Error('Either contact_id or contact_name is required.');
  }

  const { data: matches, error } = await supabaseAdmin
    .from('contacts')
    .select('id, first_name, last_name')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .or(`first_name.ilike.%${args.contact_name}%,last_name.ilike.%${args.contact_name}%`);
  if (error) throw new Error(error.message);

  if (!matches || matches.length === 0) {
    throw new Error(`No contact named "${args.contact_name}" found. Use query_crm to list the user's contacts and confirm the exact name.`);
  }
  if (matches.length > 1) {
    const names = matches.map((m) => `${m.first_name ?? ''} ${m.last_name ?? ''}`.trim()).join(', ');
    throw new Error(`Multiple contacts match "${args.contact_name}": ${names}. Ask the user which one.`);
  }
  return matches[0].id;
}

export async function resolveEventId(
  args: { event_id?: string; event_name?: string },
  userId: string,
): Promise<string> {
  if (args.event_id) return args.event_id;

  if (!args.event_name) {
    throw new Error('Either event_id or event_name is required.');
  }

  const { data: matches, error } = await supabaseAdmin
    .from('events')
    .select('id, name, start_date')
    .eq('user_id', userId)
    .is('deleted_at', null)
    .ilike('name', `%${args.event_name}%`);
  if (error) throw new Error(error.message);

  if (!matches || matches.length === 0) {
    throw new Error(`No event named "${args.event_name}" found. Use query_crm to list the user's events and confirm the exact name.`);
  }
  if (matches.length > 1) {
    const names = matches.map((m) => `${m.name} (${m.start_date})`).join(', ');
    throw new Error(`Multiple events match "${args.event_name}": ${names}. Ask the user which one.`);
  }
  return matches[0].id;
}

export async function assertOwnsEvent(eventId: string, userId: string): Promise<void> {
  const { data } = await supabaseAdmin
    .from('events').select('id').eq('id', eventId).eq('user_id', userId).is('deleted_at', null).maybeSingle();
  if (!data) throw new Error('Event not found or access denied');
}

export async function assertOwnsContact(contactId: string, userId: string): Promise<void> {
  const { data } = await supabaseAdmin
    .from('contacts').select('id').eq('id', contactId).eq('user_id', userId).is('deleted_at', null).maybeSingle();
  if (!data) throw new Error('Contact not found or access denied');
}

// Resolve + verify a chat attachment belongs to the caller, walking the
// attachment -> message -> user_id chain. supabaseAdmin bypasses RLS, so this
// ownership check is the security boundary for parse_document (a user must not
// read another user's uploaded document or its chunks).
export async function assertOwnsAttachment(attachmentId: string, userId: string) {
  const { data, error } = await supabaseAdmin
    .from('message_attachments')
    .select('id, extracted_text, extraction_status, token_estimate, mime_type, messages!inner(user_id)')
    .eq('id', attachmentId)
    .eq('messages.user_id', userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Attachment not found or access denied');
  return data as unknown as {
    id: string; extracted_text: string | null; extraction_status: string;
    token_estimate: number | null; mime_type: string | null;
  };
}

// Find-or-create a company by name (companies are an admin-managed shared
// resource — no per-user scoping), or accept a known company_id. Mirrors the
// resolution in execCreateContact and the targets import route.
export async function resolveCompanyId(
  args: { company_id?: string; company_name?: string },
): Promise<string> {
  if (args.company_id) return args.company_id;
  const nameRaw = args.company_name?.trim();
  if (!nameRaw) throw new Error('Either company_id or company_name is required.');

  const { data: existing } = await supabaseAdmin
    .from('companies').select('id').ilike('name', nameRaw).maybeSingle();
  if (existing?.id) return existing.id;

  const { data: created, error } = await supabaseAdmin
    .from('companies').insert({ name: nameRaw }).select('id').single();
  if (error) throw new Error(error.message);
  return created.id;
}
