/**
 * Tavily Search Service
 * Performs real-time web searches before AI calls so Gemini has current,
 * grounded information rather than relying solely on training data.
 */

export interface TavilyResult {
  title: string;
  url: string;
  content: string;
  score: number;
}

export interface TavilySearchResponse {
  results: TavilyResult[];
  query: string;
}

export class TavilyService {
  private static readonly API_URL = 'https://api.tavily.com/search';
  private static readonly API_KEY = process.env.TAVILY_API_KEY || '';

  static async search(
    query: string,
    options: { maxResults?: number; searchDepth?: 'basic' | 'advanced' } = {}
  ): Promise<TavilyResult[]> {
    if (!this.API_KEY) {
      console.warn('[tavily] TAVILY_API_KEY not set — skipping web search');
      return [];
    }

    try {
      const response = await fetch(this.API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          api_key: this.API_KEY,
          query,
          search_depth: options.searchDepth ?? 'basic',
          max_results: options.maxResults ?? 5,
          include_answer: false,
          include_raw_content: false,
        }),
      });

      if (!response.ok) {
        const text = await response.text();
        console.error(`[tavily] Search failed (${response.status}): ${text}`);
        return [];
      }

      const data = (await response.json()) as TavilySearchResponse;
      return data.results ?? [];
    } catch (err) {
      console.error('[tavily] Search error:', err);
      return [];
    }
  }

  /** Format results as a compact context block for injection into an AI prompt. */
  static formatForPrompt(results: TavilyResult[]): string {
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

    const queries: Promise<TavilyResult[]>[] = [
      this.search(
        `${name}${jobTitle ? ` ${jobTitle}` : ''}${!isIndependent ? ` ${company}` : ''} professional background`,
        { maxResults: 4, searchDepth: 'basic' }
      ),
    ];

    if (!isIndependent) {
      queries.push(
        this.search(`${company} company overview industry products`, { maxResults: 3, searchDepth: 'basic' })
      );
    }

    const [personResults, companyResults = []] = await Promise.all(queries);
    const allResults = [...personResults, ...companyResults];

    if (allResults.length === 0) return '';

    console.log(`[tavily] ${allResults.length} results for "${name}" / "${company ?? 'independent'}"`);
    return this.formatForPrompt(allResults);
  }
}
