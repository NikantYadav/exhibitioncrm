// ─── Tool schemas (given to the LLM) ─────────────────────────────────────────

export const SLAYER_QUERY_TOOL = {
  name: 'query_crm',
  description: `Query the user's data via the semantic layer (handles SQL for you). Use for ANY read: contacts, events, email drafts, captures, companies, interactions, dashboard stats, or searching messages.
DATE FILTERING: for any relative window on events (today, live now, upcoming, next N days, this week/month, past) set the "date_window" parameter instead of writing date filters — the backend computes the exact bounds; hand-written relative-date filters are rejected. For absolute dates or non-event models, use "filters" with explicit timestamptz ranges (never bare date equality like start_date = '2026-06-21'). date_window may be combined with other non-date filters.`,
  parameters: {
    type: 'object',
    properties: {
      source_model: {
        type: 'string',
        description: 'The table/model to query (e.g. contacts, events, notes)',
      },
      date_window: {
        type: 'string',
        enum: ['today', 'live_now', 'upcoming', 'next_7_days', 'next_10_days', 'next_30_days', 'this_week', 'this_month', 'past'],
        description: 'Relative time window for events. The backend expands this into correct start_date bounds — ALWAYS use this instead of hand-writing date filters for relative windows. "today"/"live_now" = events today; "upcoming" = today onward; "next_N_days"/"this_week"/"this_month" = today through N days; "past" = before today.',
      },
      measures: {
        type: 'array',
        items: { type: 'string' },
        description: 'Aggregations e.g. ["*:count", "revenue:sum"]. Omit for raw rows.',
      },
      dimensions: {
        type: 'array',
        items: { type: 'string' },
        description: 'Columns to group by or return e.g. ["status", "first_name", "email"]',
      },
      filters: {
        type: 'array',
        items: { type: 'string' },
        description: 'Filter conditions e.g. ["follow_up_status = \'needs_followup\'", "start_date >= \'2026-06-21T00:00:00Z\'", "start_date < \'2026-06-22T00:00:00Z\'"]. For date columns always use timestamptz range filters, never bare date equality.',
      },
      time_dimensions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            dimension: { type: 'string' },
            granularity: { type: 'string', enum: ['day', 'week', 'month', 'quarter', 'year'] },
            date_range: { type: 'array', items: { type: 'string' }, minItems: 2, maxItems: 2 },
          },
          required: ['dimension'],
        },
        description: 'Time-based grouping e.g. [{"dimension": "created_at", "granularity": "month"}]',
      },
      order: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            column: { type: 'string' },
            direction: { type: 'string', enum: ['asc', 'desc'] },
          },
          required: ['column'],
        },
      },
      limit: { type: 'number', description: 'Max rows to return (default 50, max 200)' },
    },
    required: ['source_model'],
  },
};

export const WRITE_TOOLS = [
  {
    name: 'create_contact',
    description: 'Create a new contact',
    parameters: {
      type: 'object',
      properties: {
        first_name: { type: 'string' },
        last_name: { type: 'string' },
        email: { type: 'string' },
        phone: { type: 'string' },
        job_title: { type: 'string' },
        linkedin_url: { type: 'string', description: 'LinkedIn profile URL' },
        scanned_details: {
          type: 'array',
          description: 'Extra business-card details with no dedicated parameter (address, fax, alternate phone, website, etc.). Provide as a list of {key, value} pairs, e.g. [{"key":"address","value":"Doha, Qatar"},{"key":"fax","value":"+974..."}]. Both key and value are strings.',
          items: {
            type: 'object',
            properties: {
              key: { type: 'string', description: 'Field name, e.g. "address", "fax", "website"' },
              value: { type: 'string', description: 'Field value' },
            },
            required: ['key', 'value'],
          },
        },
        company_name: { type: 'string', description: 'Company name — will be created if not found' },
        company_id: { type: 'string', description: 'Existing company UUID (use instead of company_name if known)' },
        event_id: { type: 'string', description: 'Link contact to this event UUID' },
        is_priority: { type: 'boolean', description: 'Mark this contact as a priority follow-up' },
        card_attachment_id: { type: 'string', description: 'If this contact was read from an attached business-card image, pass that image\'s attachment_id here so it is saved as the contact\'s card (viewable in the app).' },
      },
      required: ['first_name'],
    },
  },
  {
    name: 'update_contact',
    description: 'Update fields on an existing contact. Provide contact_id if known, otherwise contact_name. The system resolves the contact via the primary database.',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string' },
        contact_name: { type: 'string', description: 'Full or partial name of the contact to update — use this if you do not have the contact_id.' },
        first_name: { type: 'string' },
        last_name: { type: 'string' },
        email: { type: 'string' },
        phone: { type: 'string' },
        job_title: { type: 'string' },
        linkedin_url: { type: 'string', description: 'LinkedIn profile URL' },
        is_priority: { type: 'boolean', description: 'Mark this contact as a priority follow-up' },
        follow_up_status: { type: 'string', enum: ['not_contacted', 'contacted', 'needs_followup', 'ignore'] },
        last_contacted_at: { type: 'string', description: 'ISO 8601 datetime' },
        scanned_details: {
          type: 'array',
          description: 'Extra business-card details (address, fax, alternate phone, website, etc.). Provide as a list of {key, value} pairs, e.g. [{"key":"address","value":"Doha, Qatar"},{"key":"website","value":"x.com"}]. Merged into existing scanned details — only include the keys you are adding or changing; set a key\'s value to "" to remove it. Both key and value are strings.',
          items: {
            type: 'object',
            properties: {
              key: { type: 'string', description: 'Field name, e.g. "address", "fax", "website"' },
              value: { type: 'string', description: 'Field value, or "" to remove this key' },
            },
            required: ['key', 'value'],
          },
        },
      },
      required: [],
    },
  },
  {
    name: 'create_event',
    description: 'Create a new event/exhibition. A real start_date from the user is mandatory — never fabricate or default it. If the user did not specify a date, ask them first; do not call this tool yet.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        location: { type: 'string' },
        start_date: { type: 'string', description: 'ISO 8601 datetime. Must come from the user — do not guess or default.' },
        end_date: { type: 'string', description: 'ISO 8601 datetime' },
        start_time: { type: 'string', description: 'Time of day the event starts, 24h HH:MM (e.g. "09:30")' },
        end_time: { type: 'string', description: 'Time of day the event ends, 24h HH:MM. Must be after start_time.' },
        event_type: { type: 'string' },
      },
      required: ['name', 'start_date'],
    },
  },
  {
    name: 'update_event',
    description: 'Update fields on an existing event. Provide event_id if known, otherwise event_name. The system resolves the event via the primary database.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event to update' },
        event_name: { type: 'string', description: 'Name of the event to update — use this if you do not have the event_id.' },
        name: { type: 'string' },
        location: { type: 'string' },
        start_date: { type: 'string', description: 'ISO 8601 datetime' },
        end_date: { type: 'string', description: 'ISO 8601 datetime' },
        start_time: { type: 'string', description: 'Time of day the event starts, 24h HH:MM (e.g. "09:30")' },
        end_time: { type: 'string', description: 'Time of day the event ends, 24h HH:MM. Must be after start_time.' },
        event_type: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'get_event_followups',
    description: 'List contacts linked to a specific event, optionally filtered by follow-up status. Use this when the user asks for pending/done/all follow-ups for a named event.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event' },
        event_name: { type: 'string', description: 'Name of the event — use this if you do not have the event_id.' },
        follow_up_status: {
          type: 'string',
          enum: ['not_contacted', 'contacted', 'needs_followup', 'ignore'],
          description: 'Filter contacts by this follow-up status. Omit to return all contacts for the event.',
        },
      },
      required: [],
    },
  },
  {
    name: 'draft_email',
    description: 'Draft an email for a contact',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string' },
        subject: { type: 'string' },
        body: { type: 'string' },
        email_type: { type: 'string' },
        event_id: { type: 'string' },
      },
      required: ['contact_id', 'subject', 'body'],
    },
  },
  {
    name: 'log_interaction',
    description: 'Record an interaction with a contact — call, meeting, note, or other touch (e.g. "log that I called Sasha"). Provide contact_id or contact_name. Also promotes the contact\'s follow-up to pending (reopening it if done). Use for "I called/met/spoke to/noted ...", NOT for drafting emails.',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string', description: 'UUID of the contact.' },
        contact_name: { type: 'string', description: 'Full or partial name of the contact — use this if you do not have the contact_id.' },
        event_id: { type: 'string', description: 'UUID of the event this interaction relates to (optional).' },
        event_name: { type: 'string', description: 'Name of the related event — use this instead of event_id if needed (optional).' },
        interaction_type: {
          type: 'string',
          enum: ['call', 'meeting', 'note', 'manual', 'email'],
          description: 'Kind of interaction. Defaults to "note" if omitted.',
        },
        summary: { type: 'string', description: 'A short description of what happened.' },
        interaction_date: { type: 'string', description: 'ISO 8601 datetime of the interaction. Defaults to now if omitted.' },
      },
      required: [],
    },
  },
  {
    name: 'set_follow_up_status',
    description: 'Set a contact\'s follow-up status. With event_id/event_name it sets the per-event follow-up; without one it applies to ALL the contact\'s follow-up records. Use for "mark X as done", "reopen X", "skip X". Provide contact_id or contact_name.',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string', description: 'UUID of the contact.' },
        contact_name: { type: 'string', description: 'Full or partial name of the contact — use this if you do not have the contact_id.' },
        event_id: { type: 'string', description: 'UUID of the event to scope to (optional; omit to apply to all of the contact\'s follow-ups).' },
        event_name: { type: 'string', description: 'Name of the event to scope to — use instead of event_id (optional).' },
        status: {
          type: 'string',
          enum: ['new', 'pending', 'done', 'skipped'],
          description: 'new = just added, not engaged; pending = follow-up owed; done = followed up; skipped = intentionally skipped.',
        },
      },
      required: ['status'],
    },
  },
  {
    name: 'set_follow_up_priority',
    description: 'Flag/unflag a contact as a priority follow-up. With event_id/event_name it sets the per-event priority; without one it sets the contact\'s global priority. Use for "mark X as priority", "remove priority from X". Provide contact_id or contact_name.',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string', description: 'UUID of the contact.' },
        contact_name: { type: 'string', description: 'Full or partial name of the contact — use this if you do not have the contact_id.' },
        event_id: { type: 'string', description: 'UUID of the event to scope the priority to (optional; omit for global priority).' },
        event_name: { type: 'string', description: 'Name of the event to scope to — use instead of event_id (optional).' },
        is_priority: { type: 'boolean', description: 'true to flag as priority, false to remove the flag.' },
      },
      required: ['is_priority'],
    },
  },
  {
    name: 'add_target_contact_to_event',
    description: 'Link an EXISTING contact to an event as a target (someone to meet there). Provide the contact by contact_id/contact_name and the event by event_id/event_name. Idempotent. Use create_contact (with event_id) instead when the contact does not exist yet.',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string', description: 'UUID of the contact.' },
        contact_name: { type: 'string', description: 'Full or partial name of the contact — use if you do not have the contact_id.' },
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use if you do not have the event_id.' },
      },
      required: [],
    },
  },
  {
    name: 'add_target_company_to_event',
    description: 'Link a company as a target for an event, optionally with its hall/booth number. Company is found by name or created if new (or pass company_id). Provide the event by event_id/event_name. Idempotent on (event, company).',
    parameters: {
      type: 'object',
      properties: {
        company_id: { type: 'string', description: 'Existing company UUID (use instead of company_name if known).' },
        company_name: { type: 'string', description: 'Company name — created if not found.' },
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use if you do not have the event_id.' },
        booth_location: { type: 'string', description: 'Hall / booth / stand number for this company at the event (optional).' },
        priority: { type: 'string', enum: ['high', 'medium', 'low'], description: 'Target priority (defaults to medium).' },
      },
      required: [],
    },
  },
  {
    name: 'remove_target_contact_from_event',
    description: 'Remove a contact from an event\'s target list (unlink). Provide the contact by contact_id/contact_name and the event by event_id/event_name. Does NOT delete the contact, only the event link.',
    parameters: {
      type: 'object',
      properties: {
        contact_id: { type: 'string', description: 'UUID of the contact.' },
        contact_name: { type: 'string', description: 'Full or partial name of the contact — use if you do not have the contact_id.' },
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use if you do not have the event_id.' },
      },
      required: [],
    },
  },
  {
    name: 'remove_target_company_from_event',
    description: 'Remove a company from an event\'s target list. Provide the company by company_id/company_name and the event by event_id/event_name. The company must already be a target for that event.',
    parameters: {
      type: 'object',
      properties: {
        company_id: { type: 'string', description: 'UUID of the company.' },
        company_name: { type: 'string', description: 'Name of the company — use if you do not have the company_id.' },
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use if you do not have the event_id.' },
      },
      required: [],
    },
  },
  {
    name: 'set_event_goal',
    description: 'Set a goal/objective for an event (creates it, or updates a goal with the same label on that event). E.g. "set a goal to scan 50 leads at CES". total 0 = yes/no checkbox goal; total >=1 = counted goal. Provide the event by event_id/event_name.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use if you do not have the event_id.' },
        label: { type: 'string', description: 'The goal text, e.g. "Scan 50 leads".' },
        total: { type: 'number', description: 'Target count. 0 = a binary checkbox goal; >=1 = a counted goal. Defaults to 1.' },
        current: { type: 'number', description: 'Current progress toward the goal (optional; defaults to 0 on create).' },
      },
      required: ['label'],
    },
  },
  {
    name: 'bulk_import_contacts',
    description: 'Import many contacts in a single call — prefer this over repeated create_contact when adding 2+ contacts (e.g. from an exhibitor list or a batch of business cards). Each contact is de-duplicated independently: existing contacts are reported but not duplicated. Optionally link all contacts to one event by providing event_id or event_name. Up to 100 contacts per call; split larger lists across calls.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'Link all imported contacts to this event UUID (optional).' },
        event_name: { type: 'string', description: 'Name of the event to link all contacts to — use instead of event_id (optional).' },
        contacts: {
          type: 'array',
          description: 'List of contacts to import.',
          items: {
            type: 'object',
            properties: {
              first_name: { type: 'string' },
              last_name: { type: 'string' },
              email: { type: 'string' },
              phone: { type: 'string' },
              job_title: { type: 'string' },
              linkedin_url: { type: 'string', description: 'LinkedIn profile URL' },
              company_name: { type: 'string', description: 'Company name — will be created if not found' },
              company_id: { type: 'string', description: 'Existing company UUID (use instead of company_name if known)' },
              is_priority: { type: 'boolean', description: 'Mark this contact as a priority follow-up' },
              scanned_details: {
                type: 'array',
                description: 'Extra business-card details with no dedicated parameter (address, fax, alternate phone, website, etc.). Provide as a list of {key, value} pairs.',
                items: {
                  type: 'object',
                  properties: {
                    key: { type: 'string' },
                    value: { type: 'string' },
                  },
                  required: ['key', 'value'],
                },
              },
            },
            required: ['first_name'],
          },
        },
      },
      required: ['contacts'],
    },
  },
  {
    name: 'bulk_add_target_companies_to_event',
    description: 'Add many companies as targets for one event in a single call — prefer this over repeated add_target_company_to_event when adding 2+ companies (e.g. from an exhibitor list). Each company is de-duplicated independently. Up to 100 companies per call; split larger lists across calls.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use instead of event_id.' },
        companies: {
          type: 'array',
          description: 'List of companies to add as targets.',
          items: {
            type: 'object',
            properties: {
              company_id: { type: 'string', description: 'Existing company UUID (use instead of company_name if known).' },
              company_name: { type: 'string', description: 'Company name — created if not found.' },
              booth_location: { type: 'string', description: 'Hall / booth / stand number for this company at the event (optional).' },
              priority: { type: 'string', enum: ['high', 'medium', 'low'], description: 'Target priority (defaults to medium).' },
            },
          },
        },
      },
      required: ['companies'],
    },
  },
  {
    name: 'bulk_add_target_contacts_to_event',
    description: 'Link many EXISTING contacts to one event as targets in a single call — prefer this over repeated add_target_contact_to_event when adding 2+ contacts. Each contact is de-duplicated independently. Up to 100 contacts per call; split larger lists across calls.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use instead of event_id.' },
        contacts: {
          type: 'array',
          description: 'List of contacts to add as targets.',
          items: {
            type: 'object',
            properties: {
              contact_id: { type: 'string', description: 'UUID of the contact.' },
              contact_name: { type: 'string', description: 'Full or partial name of the contact — use if you do not have the contact_id.' },
            },
          },
        },
      },
      required: ['contacts'],
    },
  },
  {
    name: 'add_target_note',
    description: 'Attach a prep note to a target (contact or company) within an event. The target must already exist for that event (add it first if needed). For a company target, appends a new note to the company\'s note list (does NOT replace existing notes). For a contact target, sets the contact\'s prep note. Provide the event by event_id/event_name.',
    parameters: {
      type: 'object',
      properties: {
        target_type: { type: 'string', enum: ['contact', 'company'], description: 'Whether the note is for a target contact or a target company.' },
        contact_id: { type: 'string', description: 'UUID of the contact (when target_type is "contact").' },
        contact_name: { type: 'string', description: 'Name of the contact — use if you do not have the contact_id (when target_type is "contact").' },
        company_id: { type: 'string', description: 'UUID of the company (when target_type is "company").' },
        company_name: { type: 'string', description: 'Name of the company — use if you do not have the company_id (when target_type is "company").' },
        event_id: { type: 'string', description: 'UUID of the event.' },
        event_name: { type: 'string', description: 'Name of the event — use if you do not have the event_id.' },
        note: { type: 'string', description: 'The prep note / talking points text.' },
      },
      required: ['target_type', 'note'],
    },
  },
];

export const GET_PRIORITIES_TOOL = {
  name: 'get_priorities',
  description: `Get the count of follow-ups currently DUE (distinct contacts whose follow-up is "new" or "pending") — the home screen's Today's Priorities number. Use for "what should I do today", "how many follow-ups do I have". This is a count, not a list; to list the contacts, use query_crm on the follow_ups model.`,
  parameters: { type: 'object', properties: {} },
};

export const WEB_SEARCH_TOOL = {
  name: 'web_search',
  description: `Search the live web for current, real-time info — news, company/person background, pricing, or anything not in your training data (e.g. "latest on <company>", "who is <person>", industry news). Do NOT use for the user's own data — use query_crm for that.`,
  parameters: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'The search query' },
      search_depth: {
        type: 'string',
        enum: ['basic', 'advanced'],
        description: 'Use "advanced" for deeper, more thorough research; "basic" (default) for quick lookups',
      },
      max_results: { type: 'number', description: 'Max results to return (default 5, max 10)' },
    },
    required: ['query'],
  },
};

// ─── Table directory + describe_model (lazy / just-in-time schema) ────────────
// Instead of dumping every table's columns into the system prompt, the prompt
// carries only this one-line-per-table directory, and the model calls
// describe_model(source_model) to fetch one table's columns (with types) right
// before it builds a query_crm call. Smaller prompt + smaller hallucination
// surface (the model only ever sees the columns for the table it chose).
// Keep keys in sync with slayer-client ALLOWED_MODELS.
export const MODEL_DIRECTORY: Record<string, string> = {
  contacts: 'People you have met / your leads (name, email, phone, job, follow-up status).',
  events: 'Exhibitions / trade shows (name, location, start/end date & time).',
  email_drafts: 'Saved draft emails for contacts (subject, body, status).',
  captures: 'Business-card / lead captures taken at an event.',
  companies: 'Companies that contacts belong to (name, industry, website).',
  interactions: 'Logged interactions with a contact (type, date, summary).',
  messages: 'Chat messages in AI assistant conversations.',
  conversations: 'AI assistant conversation threads (title, timestamps).',
  attachments: 'Files attached to email drafts or interactions.',
  contact_documents: 'Documents uploaded against a contact (name, summary).',
  user_profiles: 'The user\'s own profile (name, role, products, tone).',
  target_companies: 'Companies targeted for a specific event (priority, booth, status).',
  event_goals: 'Goals/objectives set for an event (label, current, total).',
  message_attachments: 'Files attached to chat messages.',
  contact_events: 'Links between a contact and an event (status, notes).',
  follow_ups: 'Per-contact-per-event follow-up state (status, channel, priority).',
  target_company_met: 'Per-user record of which target companies were met at an event.',
};

export const DESCRIBE_MODEL_TOOL = {
  name: 'describe_model',
  description: `Get the exact column names and types for ONE table before you query it.
Call this right before query_crm whenever you are not 100% sure of a table's column names.
This is the ONLY reliable way to know a table's columns — never guess column names.
Returns the column list (name + type) plus a reminder of the correct filter format.`,
  parameters: {
    type: 'object',
    properties: {
      source_model: {
        type: 'string',
        description: 'The table to describe (e.g. "contacts", "events"). Must be one of the tables in the directory in the system prompt.',
      },
    },
    required: ['source_model'],
  },
};

export const PARSE_DOCUMENT_TOOL = {
  name: 'parse_document',
  description: `Read a document the user attached to the chat (PDF, image/scan, floor plan, spreadsheet, Word/PowerPoint) — e.g. an exhibitor list or brochure. Use whenever the user attaches a file and asks you to read, summarize, find, or act on it. The attachment_id comes from the attachment metadata on the user's message; if you don't have it, tell the user you don't see an attachment. SMALL docs return full text; for LARGE docs pass a "query" describing what to find (e.g. "fintech companies", "booth numbers in hall 3") to get the most relevant passages. READ-only — to act on what you find, call the appropriate write tool after.`,
  parameters: {
    type: 'object',
    properties: {
      attachment_id: { type: 'string', description: 'UUID of the attached document (from the user message\'s attachment metadata).' },
      query: { type: 'string', description: 'What to look for in the document. Required for large documents; optional for small ones.' },
    },
    required: ['attachment_id'],
  },
};

// web_search is gated behind research mode — it is only offered to the model when
// the user explicitly turned research on for the turn, so a normal CRM question
// can never spend a round-trip on a web lookup. BASE_TOOLS is everything else.
export const BASE_TOOLS = [SLAYER_QUERY_TOOL, DESCRIBE_MODEL_TOOL, GET_PRIORITIES_TOOL, PARSE_DOCUMENT_TOOL, ...WRITE_TOOLS];
export const ALL_TOOLS = [...BASE_TOOLS, WEB_SEARCH_TOOL];

/** Tool list for a turn — includes web_search only in research mode. */
export function toolsForTurn(researchMode: boolean) {
  return researchMode ? ALL_TOOLS : BASE_TOOLS;
}

// Tools that MUTATE data — these require explicit user permission before they run.
// get_event_followups is a read despite living in WRITE_TOOLS, so it is excluded.
export const WRITE_TOOL_NAMES = new Set([
  'create_contact', 'update_contact', 'create_event', 'update_event', 'draft_email',
  'log_interaction', 'set_follow_up_status', 'set_follow_up_priority',
  'add_target_contact_to_event', 'add_target_company_to_event',
  'remove_target_contact_from_event', 'remove_target_company_from_event',
  'set_event_goal', 'add_target_note',
  'bulk_import_contacts', 'bulk_add_target_companies_to_event', 'bulk_add_target_contacts_to_event',
]);

// Build a short, human-readable description of a proposed write for the
