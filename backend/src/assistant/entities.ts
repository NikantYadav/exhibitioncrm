// Linked-entity (card) helpers for query_crm read results.

export const LINKABLE_CARD_COLUMNS: Record<string, string[]> = {
  events: ['id', 'name', 'start_date', 'location'],
  contacts: ['id', 'first_name', 'last_name'],
  email_drafts: ['id', 'subject'],
};

/** Strip a Slayer dotted column prefix ("events.name" -> "name"). */
export function unprefix(key: string): string {
  const dot = key.indexOf('.');
  return dot === -1 ? key : key.slice(dot + 1);
}

/** Flatten a Slayer row's dotted keys to plain field names. */
export function normaliseRow(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) out[unprefix(k)] = v;
  return out;
}

/** Build a linked-entity payload from a normalised read row, or null if no id. */
export function readRowToEntity(model: string, r: Record<string, unknown>): { type: string; id: string; payload: Record<string, unknown> } | null {
  if (!r.id || typeof r.id !== 'string') return null;
  const id = r.id;
  if (model === 'events') {
    return { type: 'event', id, payload: { type: 'event', id, name: r.name, start_date: r.start_date, location: r.location } };
  }
  if (model === 'contacts') {
    return { type: 'contact', id, payload: { type: 'contact', id, first_name: r.first_name, last_name: r.last_name } };
  }
  if (model === 'email_drafts') {
    return { type: 'email_draft', id, payload: { type: 'email_draft', id, subject: r.subject } };
  }
  return null;
}

// ─── @-mention resolution ─────────────────────────────────────────────────────

import type { SupabaseClient } from '@supabase/supabase-js';

export type MentionRef = { type: 'contact' | 'event' | 'company'; id: string };

// The columns we surface per mentioned entity. Kept lean — enough for the model
// to reason about the record without dumping every field.
const MENTION_SELECT: Record<MentionRef['type'], { table: string; columns: string }> = {
  contact: { table: 'contacts', columns: 'id, first_name, last_name, email, phone, job_title, company_name' },
  event: { table: 'events', columns: 'id, name, start_date, end_date, location, event_type' },
  company: { table: 'companies', columns: 'id, name, industry, website, headquarters, description' },
};

function describeMention(type: MentionRef['type'], r: Record<string, any>): string {
  const fields: Array<[string, unknown]> = [];
  if (type === 'contact') {
    const name = `${r.first_name ?? ''} ${r.last_name ?? ''}`.trim() || 'Contact';
    fields.push(['email', r.email], ['phone', r.phone], ['job title', r.job_title], ['company', r.company_name]);
    return `- Contact "${name}" (id: ${r.id})` + fmtFields(fields);
  }
  if (type === 'event') {
    fields.push(['start', r.start_date], ['end', r.end_date], ['location', r.location], ['type', r.event_type]);
    return `- Event "${r.name ?? 'Event'}" (id: ${r.id})` + fmtFields(fields);
  }
  fields.push(['industry', r.industry], ['website', r.website], ['HQ', r.headquarters], ['description', r.description]);
  return `- Company "${r.name ?? 'Company'}" (id: ${r.id})` + fmtFields(fields);
}

function fmtFields(fields: Array<[string, unknown]>): string {
  const parts = fields
    .filter(([, v]) => v != null && `${v}`.trim() !== '')
    .map(([k, v]) => `${k}: ${`${v}`.trim().slice(0, 400)}`);
  return parts.length ? `: ${parts.join(', ')}` : '';
}

/**
 * Resolve user-mentioned records to a context note appended to the turn.
 * Uses the caller's user-scoped client so RLS enforces ownership; an unowned or
 * missing id simply returns no row and is skipped. Returns '' when there is
 * nothing to add.
 */
export async function buildMentionNote(
  supabaseUser: SupabaseClient,
  mentions: MentionRef[] | undefined,
): Promise<string> {
  if (!mentions || mentions.length === 0) return '';
  const lines: string[] = [];
  for (const m of mentions) {
    const spec = MENTION_SELECT[m.type];
    if (!spec) continue;
    const { data } = await supabaseUser.from(spec.table).select(spec.columns).eq('id', m.id).maybeSingle();
    if (data) lines.push(describeMention(m.type, data as Record<string, any>));
  }
  if (lines.length === 0) return '';
  return (
    `\n\n[The user mentioned the following record(s). Treat them as the subject ` +
    `of this turn and use their details directly:\n${lines.join('\n')}]`
  );
}
