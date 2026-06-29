// are half-open [lo, hi) on start_date, in UTC.

export const DATE_WINDOWS = new Set([
  'today', 'live_now', 'upcoming', 'next_7_days', 'next_10_days',
  'next_30_days', 'this_week', 'this_month', 'past',
]);

/** YYYY-MM-DDT00:00:00Z for `now + n` days (UTC midnight). */
function midnightPlusDays(now: Date, n: number): string {
  return `${new Date(now.getTime() + n * 86400000).toISOString().slice(0, 10)}T00:00:00Z`;
}

/**
 * Expand a date_window value into start_date filter strings. Returns the filters
 * to append, or null for an unknown window. "live_now" maps to today's bounds:
 * most events have a null end_date, so "live" = "happening today".
 */
export function expandDateWindow(window: string, now = new Date()): string[] | null {
  const today = midnightPlusDays(now, 0);
  switch (window) {
    case 'today':
    case 'live_now':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 1)}'`];
    case 'upcoming':
      return [`start_date >= '${today}'`];
    case 'next_7_days':
    case 'this_week':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 7)}'`];
    case 'next_10_days':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 10)}'`];
    case 'next_30_days':
    case 'this_month':
      return [`start_date >= '${today}'`, `start_date < '${midnightPlusDays(now, 30)}'`];
    case 'past':
      return [`start_date < '${today}'`];
    default:
      return null;
  }
}

// ─── Linked entities from read (query_crm) results ────────────────────────────
// Columns we inject into query_crm results so any entity the assistant names in
