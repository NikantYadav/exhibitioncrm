/**
 * Company Research Service
 * AI-powered company research and analysis using Tavily for real-time data
 */

import { tavily } from '@tavily/core';
import { AIService } from './ai';
import { getFullAIContext } from './profile-service';

// Initialize Tavily client
const tvly = tavily({ apiKey: process.env.TAVILY_API_KEY || '' });

export interface CompanyResearchResult {
    companyName: string;
    overview: string;
    industry: string;
    competitors: string[];
    recentNews: NewsItem[];
    keyInsights: string[];
    sources: string[];
    confidence: number;
    website?: string;
    location?: string;
    products_services?: string;
    products?: string[];
    talkingPoints?: string[];
}

export interface NewsItem {
    title: string;
    summary: string;
    date: string;
    source: string;
    url?: string;
}

export interface IndustryAnalysis {
    trends: string[];
    challenges: string[];
    opportunities: string[];
    marketSize?: string;
}

export class CompanyResearchService {
    /**
     * Perform comprehensive company research using Tavily Search + AI
     */
    static async researchCompany(companyData: {
        name: string;
        website?: string;
        industry?: string;
        description?: string;
    }): Promise<CompanyResearchResult> {
        try {
            console.log(`Starting research for: ${companyData.name}`);

            // 1. Search for company using Tavily
            let searchContext = "";
            let sources: string[] = [];
            let foundWebsite = companyData.website;

            if (process.env.TAVILY_API_KEY) {
                const query = `Analyze the company "${companyData.name}" ${companyData.website ? `(${companyData.website})` : ''}. Find their industry, key products, location, competitors, and recent news.`;

                try {
                    const searchResult = await tvly.search(query, {
                        search_depth: "advanced",
                        include_answer: true,
                        max_results: 5,
                        include_domains: companyData.website ? [companyData.website] : undefined
                    });

                    searchContext = searchResult.answer || searchResult.results.map(r => r.content).join('\n\n');
                    sources = searchResult.results.map(r => r.url);

                    // Try to find website if not provided
                    if (!foundWebsite && searchResult.results.length > 0) {
                        foundWebsite = searchResult.results[0].url;
                    }
                } catch (tavilyError) {
                    console.error("Tavily search failed, falling back to pure LLM:", tavilyError);
                }
            }

            // 2. Use AI to structure the findings
            const researchPrompt = this.buildResearchPrompt({
                ...companyData,
                website: foundWebsite,
                description: searchContext ? `Search Findings:\n${searchContext}\n\nOriginal Description: ${companyData.description || ''}` : companyData.description
            });

            const schema = `{
                "companyName": "Official Full Name of the Company",
                "overview": "string",
                "industry": "string",
                "competitors": ["array of competitor names"],
                "recentNews": [{"title": "string", "summary": "string", "date": "string", "source": "string", "url": "string"}],
                "keyInsights": ["array of insights"],
                "sources": ["array of source references"],
                "confidence": 0.0-1.0,
                "location": "string",
                "products_services": "string"
            }`;

            const result = await AIService.extractStructuredData<CompanyResearchResult>(
                researchPrompt,
                schema
            );

            // Merge Tavily sources
            if (sources.length > 0) {
                result.sources = Array.from(new Set([...result.sources, ...sources]));
                result.confidence = 0.9; // High confidence with real search
            }
            if (foundWebsite) result.website = foundWebsite;

            return result;

        } catch (error) {
            console.error('Company research error:', error);
            throw new Error('Failed to research company');
        }
    }

    /**
     * Generate industry analysis
     */
    static async analyzeIndustry(industry: string): Promise<IndustryAnalysis> {
        try {
            // Optional: Use Tavily for industry trends too
            let context = "";
            if (process.env.TAVILY_API_KEY) {
                try {
                    const search = await tvly.search(`Current trends and challenges in ${industry} industry ${new Date().getFullYear()}`, {
                        search_depth: "advanced",
                        max_results: 3
                    });
                    context = search.results.map(r => r.content).join('\n');
                } catch (e) { console.warn("Industry search failed", e); }
            }

            const messages = [
                {
                    role: 'system' as const,
                    content: 'You are an industry analyst. Provide insights about the given industry.',
                },
                {
                    role: 'user' as const,
                    content: `Analyze the ${industry} industry.${context ? `\nBased on recent search data:\n${context}` : ''}\n\nProvide:\n1. Current trends\n2. Key challenges\n3. Growth opportunities\n4. Market size\n\nFormat as JSON.`,
                },
            ];

            const schema = `{
                "trends": ["array of current industry trends"],
                "challenges": ["array of key challenges"],
                "opportunities": ["array of growth opportunities"],
                "marketSize": "estimated market size"
            }`;

            return await AIService.extractStructuredData(
                await AIService.generateCompletion(messages, { temperature: 0.5 }),
                schema
            );
        } catch (error) {
            console.error('Industry analysis error:', error);
            throw new Error('Failed to analyze industry');
        }
    }

    /**
     * Generate talking points for a meeting with a company
     */
    static async generateTalkingPoints(
        companyData: {
            name: string;
            industry?: string;
            description?: string;
            recentNews?: string[];
            products_services?: string;
        },
        memory?: {
            pastInteractions?: string[];
            previousNotes?: string[];
        }
    ): Promise<string[]> {
        try {
            // Get full augmented context (Profile + RAG Global)
            const profileContext = await getFullAIContext();

            let context = `Company: ${companyData.name}
Industry: ${companyData.industry || 'Unknown'}
Description: ${companyData.description || 'Not available'}
Products/Services: ${companyData.products_services || 'Unknown'}
Recent News: ${companyData.recentNews?.join(', ') || 'None'}

My Information:
${profileContext}`;

            if (memory) {
                if (memory.pastInteractions?.length) {
                    context += `\n\nPast Interactions:\n${memory.pastInteractions.join('\n')}`;
                }
                if (memory.previousNotes?.length) {
                    context += `\n\nPrevious Notes:\n${memory.previousNotes.join('\n')}`;
                }
            }

            const schema = `["point 1", "point 2", ...]`;
            const example = `["Discuss how Cisco's security fabric integrates with your existing SD-WAN", "Explore synergy with ScoreLabs recent expansion into AI cloud"]`;

            try {
                const response = await AIService.extractStructuredData<string[]>(
                    `Generate 5-7 talking points for a meeting with this company based on our profile and history:\n\n${context}`,
                    schema,
                    example
                );
                return Array.isArray(response) ? response : [];
            } catch (error) {
                console.warn('Structured extraction failed, falling back to basic completion:', error);

                const messages = [
                    {
                        role: 'system' as const,
                        content: 'You are a business development consultant. Generate relevant talking points for a meeting. Focus on synergy and history. Return ONLY the bullet points, one per line.',
                    },
                    {
                        role: 'user' as const,
                        content: `Generate 5-7 talking points for a meeting with this company:\n\n${context}`,
                    },
                ];

                const response = await AIService.generateCompletion(messages, { temperature: 0.7 });

                // Clean up any artifacts if fallback is used
                return response
                    .split('\n')
                    .map(line => line.trim())
                    .filter(line => {
                        const l = line.toLowerCase();
                        return l &&
                            !l.startsWith('```') &&
                            !l.startsWith('[') &&
                            !l.startsWith(']') &&
                            !l.startsWith('{') &&
                            !l.startsWith('}') &&
                            l.length > 5; // Ignore very short garbage lines
                    })
                    .map(l => l.replace(/^[-•*]\d*\.\s*/, '').trim());
            }
        } catch (error) {
            console.error('Talking points generation error:', error);
            throw new Error('Failed to generate talking points');
        }
    }

    /**
     * Build research prompt from company data
     */
    private static buildResearchPrompt(companyData: {
        name: string;
        website?: string;
        industry?: string;
        description?: string;
    }): string {
        return `Research the following company and provide comprehensive information:

Company Name: ${companyData.name}
Website: ${companyData.website || 'Not provided'}
Industry: ${companyData.industry || 'Unknown'}
Context/Description: ${companyData.description || 'Not available'}

Please provide:
1. Company Overview
2. Industry Classification
3. Main Competitors
4. Recent News or Developments
5. Key Insights
6. Location
7. Key Products/Services

Format the response as JSON with the following structure:
{
    "companyName": "Official Full Name of the Company",
    "overview": "string",
    "industry": "string",
    "competitors": ["array of competitor names"],
    "recentNews": [{"title": "string", "summary": "string", "date": "string", "source": "string"}],
    "keyInsights": ["array of insights"],
    "sources": ["array of source references"],
    "confidence": 0.0-1.0,
    "location": "string",
    "products_services": "string"
}`;
    }

    /**
     * Parse AI research response
     */
    private static parseResearchResponse(
        response: string,
        companyData: { name: string }
    ): CompanyResearchResult {
        try {
            const parsed = AIService.parseJSON<any>(response);
            return {
                companyName: parsed.companyName || companyData.name,
                overview: parsed.overview || `Research data for ${companyData.name}`,
                industry: parsed.industry || 'Unknown',
                competitors: Array.isArray(parsed.competitors) ? parsed.competitors : [],
                recentNews: Array.isArray(parsed.recentNews) ? parsed.recentNews : [],
                keyInsights: Array.isArray(parsed.keyInsights) ? parsed.keyInsights : [],
                sources: Array.isArray(parsed.sources) ? parsed.sources : ['AI Generated'],
                confidence: parsed.confidence || 0.6,
                location: parsed.location,
                products_services: parsed.products_services,
                products: Array.isArray(parsed.products) ? parsed.products : [],
                talkingPoints: Array.isArray(parsed.talkingPoints) ? parsed.talkingPoints : []
            };
        } catch (error) {
            console.error('Failed to parse research response:', error);
            // Return skeleton data rather than failing completely
            return {
                companyName: companyData.name,
                overview: `Research data for ${companyData.name}`,
                industry: 'Unknown',
                competitors: [],
                recentNews: [],
                keyInsights: [],
                sources: ['AI Generated'],
                confidence: 0.4,
                products: [],
                talkingPoints: []
            };
        }
    }

    static getCacheKey(companyId: string, researchType: string): string {
        return `company_research:${companyId}:${researchType}`;
    }

    static isCacheValid(createdAt: Date): boolean {
        return (new Date().getTime() - new Date(createdAt).getTime()) < (24 * 60 * 60 * 1000);
    }
}
