/**
 * Exa Search Service
 * Performs real-time web searches before AI calls so Gemini has current,
 * grounded information rather than relying solely on training data.
 *
 * Drop-in replacement for the former Tavily service: same public API
 * (`search`, `formatForPrompt`, `searchContact`) and same result shape, so
 * existing call sites need only swap the import.
 *
 * Search-depth mapping (Tavily -> Exa search `type`):
 *   'basic'    -> 'fast'  (low-latency, good relevance)
 *   'advanced' -> 'auto'  (balanced relevance/speed, smarter retrieval)
 *
 * API key rotation (mirrors the Gemini key pool in litellm-service.ts):
 *   Multiple keys are read from EXA_API_KEY (comma-separated) and/or the
 *   numbered EXA_API_KEY_1..N env vars, de-duped, and shuffled once. Each
 *   request round-robins to the next key. On a retryable failure (429 rate
 *   limit, or 401 invalid/exhausted key) the request is retried with the next
 *   key in the pool. Non-retryable errors (400 bad request, 422 validation)
 *   fail fast since another key would not help.
 */

import * as Sentry from '@sentry/node';

export interface ExaResult {
  title: string;
  url: string;
  content: string;
  score: number;
}

interface ExaApiResult {
  title?: string | null;
  url?: string;
  highlights?: string[];
  text?: string;
  score?: number;
}

interface ExaApiResponse {
  results?: ExaApiResult[];
  // Verified live against the production Exa account (see INFRASTRUCTURE_COSTS.md
  // §2.3): `total` reflects $0.007 flat for ≤10 results (+$0.001/result above
  // 10), broken down per search-type key (`neural`/`keyword`). No `contents`
  // surcharge has been observed for `highlights`/`text` in this account.
  costDollars?: { total?: number; search?: Record<string, number> };
}

/** Thrown internally so the retry loop can inspect the HTTP status. */
class ExaHttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ExaHttpError';
  }
}

export class ExaService {
  private static readonly API_URL = 'https://api.exa.ai/search';

  private static keys: string[] | null = null;
  private static currentIndex = 0;

  /** Lazily build (and shuffle once) the pool of API keys from the env. */
  private static getKeys(): string[] {
    if (this.keys !== null) return this.keys;

    const pool = new Set<string>();

    if (process.env.EXA_API_KEY) {
      process.env.EXA_API_KEY.split(',').forEach((k) => {
        const t = k.trim();
        if (t) pool.add(t);
      });
    }
    for (let i = 1; i <= 20; i++) {
      const key = process.env[`EXA_API_KEY_${i}`];
      if (key && key.trim()) pool.add(key.trim());
    }

    const keys = Array.from(pool);
    keys.sort(() => Math.random() - 0.5);
    this.keys = keys;

    if (keys.length > 0) {
      console.log(`[exa] initialized with ${keys.length} API key(s)`);
    }
    return keys;
  }

  private static getNextKey(): string | null {
    const keys = this.getKeys();
    if (keys.length === 0) return null;
    const key = keys[this.currentIndex];
    this.currentIndex = (this.currentIndex + 1) % keys.length;
    return key;
  }

  /** Run an Exa request, rotating to the next key on a retryable failure. */
  private static async withKeyRotation<T>(
    operation: (apiKey: string) => Promise<T>
  ): Promise<T> {
    const keys = this.getKeys();
    if (keys.length === 0) {
      console.warn('[exa] EXA_API_KEY not set — skipping web search');
      throw new ExaHttpError(401, 'No Exa API key configured');
    }

    const attempts = keys.length;
    let lastError: any;

    for (let i = 0; i < attempts; i++) {
      const apiKey = this.getNextKey()!;
      try {
        return await operation(apiKey);
      } catch (error: any) {
        lastError = error;
        const status = error instanceof ExaHttpError ? error.status : 0;
        // 429 = rate limit / quota exhausted, 401 = invalid or exhausted key.
        // Both are worth retrying with a different key. 400/422 (bad request /
        // validation) and 500 are not — another key would behave identically.
        const retryable = status === 429 || status === 401;

        if (retryable && i < attempts - 1) {
          console.warn(
            `[exa] key ${i + 1}/${attempts} failed (${status}) — retrying with next key`
          );
          continue;
        }
        throw error;
      }
    }
    throw lastError;
  }

  static async search(
    query: string,
    options: {
      maxResults?: number;
      searchDepth?: 'basic' | 'advanced';
      category?: 'company' | 'people' | 'research paper' | 'news';
    } = {}
  ): Promise<ExaResult[]> {
    try {
      return await this.withKeyRotation(async (apiKey) => {
        const response = await fetch(this.API_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
          },
          body: JSON.stringify({
            query,
            type: options.searchDepth === 'advanced' ? 'auto' : 'fast',
            // num_results defaults to 5 for every search.
            numResults: options.maxResults ?? 5,
            // category narrows results to a result kind (e.g. "company" for
            // company-profile enrichment). Omitted -> general web search.
            ...(options.category ? { category: options.category } : {}),
            contents: { highlights: true },
          }),
        });

        if (!response.ok) {
          const text = await response.text();
          throw new ExaHttpError(
            response.status,
            `Exa search failed (${response.status}): ${text}`
          );
        }

        const data = (await response.json()) as ExaApiResponse;

        // Cost-instrumentation: actual per-search Exa cost for
        // INFRASTRUCTURE_ANALYSIS.md's Exa formula. costDollars.total is read
        // straight from Exa's response (no assumed surcharge math) — see the
        // verified pricing table in INFRASTRUCTURE_COSTS.md §2.3.
        Sentry.logger.info('exa_search_cost', {
          query_chars: query.length,
          type: options.searchDepth === 'advanced' ? 'auto' : 'fast',
          num_results_requested: options.maxResults ?? 5,
          num_results_returned: (data.results ?? []).length,
          category: options.category ?? 'none',
          cost_total_usd: data.costDollars?.total ?? 0,
        });

        return (data.results ?? []).map((r) => ({
          title: r.title ?? '',
          url: r.url ?? '',
          content: (r.highlights && r.highlights.length > 0
            ? r.highlights.join(' … ')
            : r.text ?? '').trim(),
          score: r.score ?? 0,
        }));
      });
    } catch (err) {
      // Web search is a best-effort grounding step — never let it break the
      // caller. Log and degrade to no results (same contract as before).
      if (err instanceof ExaHttpError) {
        console.error(`[exa] ${err.message}`);
      } else {
        console.error('[exa] Search error:', err);
      }
      return [];
    }
  }

  /** Format results as a compact context block for injection into an AI prompt. */
  static formatForPrompt(results: ExaResult[]): string {
    if (results.length === 0) return '';
    return results
      .map((r, i) => `[${i + 1}] ${r.title}\n${r.url}\n${r.content.slice(0, 400)}`)
      .join('\n\n');
  }

  /**
   * Search for a contact + company and return a formatted context string.
   * Runs up to two queries in parallel: one for the person, one for the company.
   */
  static async searchContact(params: {
    name: string;
    company?: string;
    jobTitle?: string;
  }): Promise<string> {
    const { name, company, jobTitle } = params;
    const isIndependent = !company || company.toUpperCase() === 'INDEPENDENT';

    const queries: Promise<ExaResult[]>[] = [
      this.search(
        `${name}${jobTitle ? ` ${jobTitle}` : ''}${!isIndependent ? ` ${company}` : ''} professional background`,
        { maxResults: 5, searchDepth: 'basic' }
      ),
    ];

    if (!isIndependent) {
      queries.push(
        this.search(`${company} company overview industry products`, { maxResults: 5, searchDepth: 'basic' })
      );
    }

    const [personResults, companyResults = []] = await Promise.all(queries);
    const allResults = [...personResults, ...companyResults];

    if (allResults.length === 0) return '';

    console.log(`[exa] ${allResults.length} results for "${name}" / "${company ?? 'independent'}"`);
    return this.formatForPrompt(allResults);
  }
}
