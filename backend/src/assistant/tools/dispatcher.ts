import { ToolCall } from '../../services/litellm-service';
import { slayerQuery, USER_ID_TABLES, slayerGetModelColumnsTyped, ALLOWED_MODELS } from '../../services/slayer-client';
import { ExaService } from '../../services/exa-service';
import { fenceUntrusted } from '../security';
import { expandDateWindow } from '../dateWindows';
import { LINKABLE_CARD_COLUMNS, normaliseRow, readRowToEntity, unprefix } from '../entities';
import { execCreateContact, execUpdateContact, execBulkImportContacts } from './executors/contacts';
import { execCreateEvent, execUpdateEvent, execGetEventFollowups, execSetEventGoal } from './executors/events';
import { execLogInteraction, execSetFollowUpStatus, execSetFollowUpPriority, execGetPriorities } from './executors/followups';
import {
  execAddTargetContactToEvent, execAddTargetCompanyToEvent,
  execRemoveTargetContactFromEvent, execRemoveTargetCompanyFromEvent, execAddTargetNote,
  execBulkAddTargetCompaniesToEvent, execBulkAddTargetContactsToEvent,
} from './executors/targets';
import { execDraftEmail } from './executors/email';
import { execParseDocument } from './executors/documents';

// ─── Confirmation-card summary for a proposed write ───────────────────────────
export function describeWrite(call: ToolCall): string {
  const a = call.args as Record<string, any>;
  const name = (v: any) => (typeof v === 'string' && v.trim() ? v.trim() : null);
  switch (call.name) {
    case 'create_contact': {
      const full = [name(a.first_name), name(a.last_name)].filter(Boolean).join(' ');
      const co = name(a.company_name) ? ` at ${name(a.company_name)}` : '';
      return `Create a new contact${full ? `: ${full}` : ''}${co}`;
    }
    case 'update_contact':
      return `Update contact ${name(a.contact_name) ?? '(selected)'}`;
    case 'create_event':
      return `Create a new event${name(a.name) ? `: ${name(a.name)}` : ''}`;
    case 'update_event':
      return `Update event ${name(a.event_name) ?? '(selected)'}`;
    case 'draft_email':
      return `Draft an email${name(a.subject) ? `: "${name(a.subject)}"` : ''}`;
    case 'add_target_contact_to_event':
      return `Add ${name(a.contact_name) ?? 'a contact'} as a target for ${name(a.event_name) ?? 'the event'}`;
    case 'add_target_company_to_event':
      return `Add ${name(a.company_name) ?? 'a company'} as a target for ${name(a.event_name) ?? 'the event'}${name(a.booth_location) ? ` (booth ${name(a.booth_location)})` : ''}`;
    case 'remove_target_contact_from_event':
      return `Remove ${name(a.contact_name) ?? 'a contact'} from ${name(a.event_name) ?? 'the event'}'s targets`;
    case 'remove_target_company_from_event':
      return `Remove ${name(a.company_name) ?? 'a company'} from ${name(a.event_name) ?? 'the event'}'s targets`;
    case 'set_event_goal':
      return `Set event goal${name(a.label) ? `: "${name(a.label)}"` : ''}${name(a.event_name) ? ` for ${name(a.event_name)}` : ''}`;
    case 'add_target_note':
      return `Add a prep note for ${name(a.contact_name) ?? name(a.company_name) ?? 'a target'}${name(a.event_name) ? ` at ${name(a.event_name)}` : ''}`;
    case 'bulk_import_contacts': {
      const count = Array.isArray(a.contacts) ? a.contacts.length : 0;
      const evLabel = name(a.event_name) ? ` into ${name(a.event_name)}` : '';
      return `Import ${count} contact${count !== 1 ? 's' : ''}${evLabel}`;
    }
    case 'bulk_add_target_companies_to_event': {
      const count = Array.isArray(a.companies) ? a.companies.length : 0;
      const evLabel = name(a.event_name) ?? 'the event';
      return `Add ${count} target compan${count !== 1 ? 'ies' : 'y'} to ${evLabel}`;
    }
    case 'bulk_add_target_contacts_to_event': {
      const count = Array.isArray(a.contacts) ? a.contacts.length : 0;
      const evLabel = name(a.event_name) ?? 'the event';
      return `Add ${count} target contact${count !== 1 ? 's' : ''} to ${evLabel}`;
    }
    default:
      return `Perform ${call.name.replace(/_/g, ' ')}`;
  }
}

// ─── date_window expansion ────────────────────────────────────────────────────
// The model picks a window name; we compute the exact timestamptz bounds here so
// it never has to do date math or hand-write fragile filter strings. All bounds

// ─── Tool dispatcher ──────────────────────────────────────────────────────────
export type ToolResult = { name: string; ok: boolean; result?: unknown; error?: string };

export async function executeTool(
  call: ToolCall,
  userId: string,
): Promise<ToolResult> {
  try {
    let result: unknown;

    if (call.name === 'query_crm') {
      // ── READ: validate shape then forward to Slayer semantic layer ──────────
      // slayerQuery() runs Zod validation + ownership injection internally
      const q = call.args;
      if (typeof q.limit === 'number') q.limit = Math.min(q.limit, 200);

      // Expand date_window into start_date filters, then strip it (Slayer's schema
      // doesn't know the key). This is the model's only correct path for relative
      // date queries — the backend owns the math, so no fragile hand-written filters.
      if (typeof q.date_window === 'string') {
        const windowFilters = expandDateWindow(q.date_window);
        if (windowFilters) {
          q.filters = [...(Array.isArray(q.filters) ? q.filters : []), ...windowFilters];
        }
        delete q.date_window;
      }

      // Ensure card-building columns (id + display fields) are present in the
      // result even when the model didn't ask for them, so any entity the reply
      // mentions can be turned into a linked-entity card. We remember which of
      // these columns the model did NOT request so we can strip them back out of
      // the copy sent to the LLM (cards need them; the model's prose does not).
      const cardCols = LINKABLE_CARD_COLUMNS[q.source_model as string];
      const requestedDims = new Set<string>(Array.isArray(q.dimensions) ? q.dimensions : []);
      let autoAddedCols: string[] = [];
      if (cardCols) {
        autoAddedCols = cardCols.filter((c) => !requestedDims.has(c));
        const dims = new Set<string>(requestedDims);
        for (const c of cardCols) dims.add(c);
        q.dimensions = Array.from(dims);
      }

      let slayerResult = await slayerQuery(q, userId);

      // Self-heal: a 0-row result on a user-scoped table may be Supabase pooler/replica
      // lag right after a write (Slayer's read connection hasn't caught up yet). One
      // short retry closes that narrow window without masking genuine "no data" results
      // (a second empty read is treated as real).
      if (
        slayerResult.row_count === 0 &&
        typeof q.source_model === 'string' &&
        USER_ID_TABLES.has(q.source_model)
      ) {
        await new Promise((r) => setTimeout(r, 350));
        slayerResult = await slayerQuery(q, userId);
      }

      // Full rows (with the auto-added card columns) — kept ONLY for the loop's
      // single-row card builder, never sent to the model. Capped to the same
      // window as the LLM data; the loop only uses them when there's one row.
      const cardRows = slayerResult.data.slice(0, 30);

      // LLM-facing rows: cap lower (the model writes prose from these — 30 rows is
      // plenty and far cheaper than 100) and strip the columns the model didn't
      // ask for (the card-only id/display fields just bloat the token count).
      const llmData = cardRows.map((row) => {
        if (autoAddedCols.length === 0) return row;
        const trimmed: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(row)) {
          // Slayer may dot-prefix keys ("contacts.id"); compare on the bare name.
          if (!autoAddedCols.includes(unprefix(k))) trimmed[k] = v;
        }
        return trimmed;
      });

      // Reflect the trimmed shape in the columns list sent to the model too.
      const llmColumns = Array.isArray(slayerResult.columns)
        ? slayerResult.columns.filter((c: string) => !autoAddedCols.includes(unprefix(c)))
        : slayerResult.columns;

      result = {
        row_count: slayerResult.row_count,
        columns: llmColumns,
        data: llmData,
        _cardRows: cardRows, // internal: consumed by the loop, not forwarded to the LLM
      };
    } else if (call.name === 'describe_model') {
      // ── READ (schema): return one table's columns + types, on demand ─────────
      const model = typeof call.args.source_model === 'string' ? call.args.source_model.trim() : '';
      if (!model) throw new Error('source_model is required');
      if (!(ALLOWED_MODELS as readonly string[]).includes(model)) {
        throw new Error(`Unknown model "${model}". Valid models: ${ALLOWED_MODELS.join(', ')}.`);
      }
      const columns = await slayerGetModelColumnsTyped(model);
      if (columns.length === 0) {
        throw new Error(`Could not load columns for "${model}" — the schema service may be unavailable. Try again shortly.`);
      }
      result = {
        source_model: model,
        columns,
        filter_format:
          "When you call query_crm, each filter is a plain condition string like " +
          "\"follow_up_status = 'needs_followup'\". For date/timestamp columns use a " +
          "half-open range (\"start_date >= '2026-06-21T00:00:00Z'\"), never bare date " +
          "equality, and for relative event windows use the date_window parameter instead. " +
          "Do not add user_id filters — ownership is enforced automatically.",
      };
    } else if (call.name === 'get_priorities') {
      // ── READ: follow-up workload summary (home dashboard count) ─────────────
      result = await execGetPriorities(userId);
    } else if (call.name === 'parse_document') {
      // ── READ: extracted text / retrieved passages from an attached document ──
      result = await execParseDocument(call.args, userId);
    } else if (call.name === 'web_search') {
      const a = call.args;
      const query = typeof a.query === 'string' ? a.query.trim() : '';
      if (!query) throw new Error('query is required');
      const rawResults = await ExaService.search(query, {
        maxResults: Math.min(typeof a.max_results === 'number' ? a.max_results : 5, 10),
        searchDepth: a.search_depth === 'advanced' ? 'advanced' : 'basic',
      });
      // Fence each result's page body — web content is untrusted and may carry
      // hidden instructions (indirect injection). title/url stay as-is (short,
      // shown as citations); the body is the injection vector.
      const results = rawResults.map((r) => ({
        ...r,
        content: fenceUntrusted(r.content, `web page (${r.url})`),
      }));
      result = { query, results };
    } else {
      // ── WRITE: execute directly against Supabase ────────────────────────────
      switch (call.name) {
        case 'create_contact': result = await execCreateContact(call.args, userId); break;
        case 'update_contact': result = await execUpdateContact(call.args, userId); break;
        case 'create_event': result = await execCreateEvent(call.args, userId); break;
        case 'update_event': result = await execUpdateEvent(call.args, userId); break;
        case 'get_event_followups': result = await execGetEventFollowups(call.args, userId); break;
        case 'draft_email': result = await execDraftEmail(call.args, userId); break;
        case 'log_interaction': result = await execLogInteraction(call.args, userId); break;
        case 'set_follow_up_status': result = await execSetFollowUpStatus(call.args, userId); break;
        case 'set_follow_up_priority': result = await execSetFollowUpPriority(call.args, userId); break;
        case 'add_target_contact_to_event': result = await execAddTargetContactToEvent(call.args, userId); break;
        case 'add_target_company_to_event': result = await execAddTargetCompanyToEvent(call.args, userId); break;
        case 'remove_target_contact_from_event': result = await execRemoveTargetContactFromEvent(call.args, userId); break;
        case 'remove_target_company_from_event': result = await execRemoveTargetCompanyFromEvent(call.args, userId); break;
        case 'set_event_goal': result = await execSetEventGoal(call.args, userId); break;
        case 'add_target_note': result = await execAddTargetNote(call.args, userId); break;
        case 'bulk_import_contacts': result = await execBulkImportContacts(call.args, userId); break;
        case 'bulk_add_target_companies_to_event': result = await execBulkAddTargetCompaniesToEvent(call.args, userId); break;
        case 'bulk_add_target_contacts_to_event': result = await execBulkAddTargetContactsToEvent(call.args, userId); break;
        default:
          throw new Error(`Unknown tool: ${call.name}`);
      }
    }

    return { name: call.name, ok: true, result };
  } catch (e: any) {
    const msg = e?.message || 'Tool error';
    return { name: call.name, ok: false, error: msg };
  }
}

// ─── System prompt builder ────────────────────────────────────────────────────
