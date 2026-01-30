/**
 * AI Lead Enrichment Service
 * Enriches contact data with AI-powered research using public data only
 */

import { AIService } from './ai';
import { getUserProfile, buildProfileContext } from './profile-service';

export interface EnrichmentResult {
    website?: string;
    industry?: string;
    description?: string;
    location?: string;
    region?: string;
    products_services?: string;
    company_size?: string;
    linkedin_url?: string;
    bio?: string;
    confidence: Record<string, number>; // Field-level confidence scores
    sources: string[];
}

export class EnrichmentService {
    /**
     * Comprehensive enrichment for a contact
     */
    static async enrichContact(contactData: {
        name?: string;
        company?: string;
        email?: string;
        job_title?: string;
    }): Promise<EnrichmentResult> {
        const results: Partial<EnrichmentResult> = {
            confidence: {},
            sources: []
        };

        // Extract domain from email if available
        const domain = contactData.email?.split('@')[1];

        // Run web search first to gather context
        const companySearch = contactData.company
            ? await this.searchWeb(`${contactData.company} company official website and overview`)
            : '';

        const personSearch = contactData.name && contactData.company
            ? await this.searchWeb(`${contactData.name} ${contactData.company} ${contactData.job_title || ''} linkedin professional bio`)
            : '';

        // Run enrichment tasks in parallel, passing search contexts
        const [website, companyInfo, linkedIn, personInfo] = await Promise.all([
            domain ? this.findCompanyWebsite(contactData.company || '', domain, companySearch) : null,
            contactData.company ? this.enrichCompanyInfo(contactData.company, domain, companySearch) : null,
            contactData.name && contactData.company ? this.findLinkedInProfile(contactData.name, contactData.company, contactData.job_title, personSearch) : null,
            contactData.name ? this.enrichPersonInfo(contactData.name, contactData.company || '', contactData.job_title, personSearch) : null
        ]);

        if (website) {
            results.website = website.url;
            results.confidence!['website'] = website.confidence;
            results.sources!.push('AI Website Search');
        }

        if (companyInfo) {
            Object.assign(results, companyInfo);
            results.sources!.push('AI Company Research');
        }

        if (linkedIn) {
            results.linkedin_url = linkedIn.url;
            results.confidence!['linkedin_url'] = linkedIn.confidence;
        } else if (contactData.name && contactData.company) {
            results.linkedin_url = 'Not found';
            results.confidence!['linkedin_url'] = 0;
        }

        if (personInfo) {
            results.bio = personInfo.bio;
            results.confidence!['bio'] = personInfo.confidence;
            results.sources!.push('AI Profile Research');
        }

        return results as EnrichmentResult;
    }

    /**
     * Web search helper using Tavily
     */
    private static async searchWeb(query: string): Promise<string> {
        try {
            const apiKey = process.env.TAVILY_API_KEY;
            if (!apiKey) {
                console.warn('TAVILY_API_KEY is missing, falling back to LLM knowledge only');
                return '';
            }

            const response = await fetch('https://api.tavily.com/search', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    api_key: apiKey,
                    query: query,
                    search_depth: 'basic',
                    max_results: 3,
                }),
            });

            if (!response.ok) {
                console.error('Tavily search failed:', response.statusText);
                return '';
            }

            const data = await response.json();
            return data.results.map((r: any) => `${r.title}: ${r.content} (${r.url})`).join('\n\n');
        } catch (error) {
            console.error('Web search error:', error);
            return '';
        }
    }

    /**
     * Find company website from name and/or domain
     */
    /**
     * Find company website from name and/or domain
     */
    static async findCompanyWebsite(companyName: string, domain?: string, searchContext: string = ''): Promise<{ url: string; confidence: number } | null> {
        try {
            if (domain && !['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'icloud.com'].includes(domain.toLowerCase())) {
                // High confidence if we have a corporate domain
                return {
                    url: `https://${domain}`,
                    confidence: 0.95
                };
            }

            // Use AI to suggest website using search context
            const prompt = `Find the official website URL for "${companyName}" based on these search results:\n\n${searchContext}\n\nReturn JUST the URL starting with https://. If unknown return null.`;
            const response = await AIService.generateCompletion([
                { role: 'system', content: 'You are a corporate data expert. Return only URLs or "null".' },
                { role: 'user', content: prompt }
            ], { temperature: 0.1 });

            if (!response || response.toLowerCase().includes('null')) return null;

            const url = response.trim().toLowerCase();
            return {
                url: url.startsWith('http') ? url : `https://${url}`,
                confidence: searchContext ? 0.9 : 0.6
            };
        } catch (error) {
            console.error('Website finder error:', error);
            return null;
        }
    }

    /**
     * Enrich company information (industry, description, location, etc.)
     */
    /**
     * Enrich company information (industry, description, location, etc.)
     */
    static async enrichCompanyInfo(companyName: string, domain?: string, searchContext: string = ''): Promise<Partial<EnrichmentResult>> {
        try {
            const prompt = `Research the company "${companyName}"${domain ? ` linked to domain "${domain}"` : ''} using the following search results:\n\n${searchContext}\n\nExtract:
1. Industry (e.g., SaaS, FinTech, Manufacturing)
2. Description: A professional 1-sentence overview.
3. Location: Main headquarters (City, Country).
4. Region: Continent/Economic region.
5. Products/Services: Top 2-3 offerings.
6. Company Size: Estimate employee count range (1-10, 11-50, 51-200, 201-500, 501-1000, 1000+).

Return JSON.`;

            const schema = `{
                "industry": "string",
                "description": "string",
                "location": "string",
                "region": "string",
                "products_services": "string",
                "company_size": "string"
            }`;

            const result = await AIService.extractStructuredData<{
                industry: string;
                description: string;
                location: string;
                region: string;
                products_services: string;
                company_size: string;
            }>(prompt, schema);

            return {
                industry: result.industry,
                description: result.description,
                location: result.location,
                region: result.region,
                products_services: result.products_services,
                company_size: result.company_size,
                confidence: {
                    industry: searchContext ? 0.9 : 0.7,
                    description: searchContext ? 0.9 : 0.7,
                    location: searchContext ? 0.85 : 0.6,
                    region: searchContext ? 0.85 : 0.6,
                    products_services: searchContext ? 0.9 : 0.7,
                    company_size: searchContext ? 0.7 : 0.5
                }
            };
        } catch (error) {
            console.error('Company info enrichment error:', error);
            return {};
        }
    }

    /**
     * Find LinkedIn profile URL for a contact
     */
    static async findLinkedInProfile(name: string, company: string, jobTitle?: string, searchContext: string = ''): Promise<{ url: string; confidence: number } | null> {
        try {
            // Helper to extract using AI
            const extractWithAI = async (text: string) => {
                if (!text || text.length < 50) return null;

                const prompt = `Analyze the following search results to find the personal LinkedIn profile URL for "${name}" who works at "${company}"${jobTitle ? ` as "${jobTitle}"` : ''}.\n\nSearch Results:\n${text}\n\nReturn ONLY the full URL (starting with https://). If multiple profiles appear, choose the one that matches the name and company best. If no personal profile is found (only company pages or other directory sites), return "null".`;

                const response = await AIService.generateCompletion([
                    { role: 'system', content: 'You are an expert researcher. Return only the requested URL or "null".' },
                    { role: 'user', content: prompt }
                ], { temperature: 0.1 });

                if (!response || response.toLowerCase().includes('null')) return null;

                // Sanitize output to ensure valid URL format
                const match = response.match(/https?:\/\/(?:www\.)?linkedin\.com\/in\/[\w%-]+/i);
                return match ? match[0] : null;
            };

            // 1. Try to find in the shared context first
            let url = await extractWithAI(searchContext);

            // 2. If not found, do a specific targeted search (Google Dork)
            if (!url) {
                console.log('LinkedIn not found in general context, trying specific search...');
                const specificQuery = `site:linkedin.com/in/ "${name}" "${company}"`;
                const specificResults = await this.searchWeb(specificQuery);
                url = await extractWithAI(specificResults);
            }

            // 3. Fallback: looser natural language search
            if (!url) {
                const looseQuery = `${name} ${company} linkedin profile`;
                const looseResults = await this.searchWeb(looseQuery);
                url = await extractWithAI(looseResults);
            }

            if (url) {
                return {
                    url: url,
                    confidence: 0.9 // High confidence as AI validated the match
                };
            }

            return null;
        } catch (error) {
            console.error('LinkedIn finder error:', error);
            return null;
        }
    }

    /**
     * Infer industry from company name and description
     */
    static async inferIndustry(companyName: string, description?: string): Promise<{ industry: string; confidence: number }> {
        try {
            const prompt = `What industry or sector does "${companyName}" operate in?${description ? ` Context: ${description}` : ''} Return only the industry name, be specific.`;

            const industry = await AIService.generateCompletion([
                { role: 'system', content: 'You are an industry classification expert. Return only the industry name.' },
                { role: 'user', content: prompt }
            ], { temperature: 0.3 });

            return {
                industry: industry.trim(),
                confidence: description ? 0.8 : 0.6
            };
        } catch (error) {
            console.error('Industry inference error:', error);
            return { industry: 'Unknown', confidence: 0 };
        }
    }

    /**
     * Generate company description
     */
    static async generateCompanyDescription(companyName: string, website?: string): Promise<{ description: string; confidence: number }> {
        try {
            const prompt = `Write a brief 1-2 sentence description of the company "${companyName}"${website ? ` (${website})` : ''}. Be concise and factual.`;

            const description = await AIService.generateCompletion([
                { role: 'system', content: 'You are a business analyst. Write concise company descriptions.' },
                { role: 'user', content: prompt }
            ], { temperature: 0.5 });

            return {
                description: description.trim(),
                confidence: website ? 0.7 : 0.5
            };
        } catch (error) {
            console.error('Description generation error:', error);
            return { description: '', confidence: 0 };
        }
    }

    /**
     * Detect location/region
     */
    static async detectLocation(companyName: string, website?: string): Promise<{ location: string; region: string; confidence: number }> {
        try {
            const prompt = `Where is "${companyName}"${website ? ` (${website})` : ''} headquartered? Return as JSON with "location" (city, country) and "region" (e.g., North America, Europe, Asia).`;

            const schema = '{"location": "string", "region": "string"}';
            const result = await AIService.extractStructuredData<{ location: string; region: string }>(prompt, schema);

            return {
                location: result.location,
                region: result.region,
                confidence: website ? 0.7 : 0.5
            };
        } catch (error) {
            console.error('Location detection error:', error);
            return { location: '', region: '', confidence: 0 };
        }
    }

    /**
     * Infer products/services
     */
    static async inferProducts(companyName: string, industry?: string, website?: string): Promise<{ products_services: string; confidence: number }> {
        try {
            const prompt = `What products or services does "${companyName}" offer?${industry ? ` They are in the ${industry} industry.` : ''}${website ? ` Website: ${website}` : ''} Be specific but concise.`;

            const products = await AIService.generateCompletion([
                { role: 'system', content: 'You are a business analyst. Describe company offerings concisely.' },
                { role: 'user', content: prompt }
            ], { temperature: 0.5 });

            return {
                products_services: products.trim(),
                confidence: website ? 0.7 : 0.5
            };
        } catch (error) {
            console.error('Products inference error:', error);
            return { products_services: '', confidence: 0 };
        }
    }

    /**
     * Estimate company size
     */
    static async estimateCompanySize(companyName: string, website?: string): Promise<{ company_size: string; confidence: number }> {
        try {
            const prompt = `Estimate the employee count range for "${companyName}"${website ? ` (${website})` : ''}. Return one of: "1-10", "11-50", "51-200", "201-500", "500+". Return ONLY the range, nothing else.`;

            const size = await AIService.generateCompletion([
                { role: 'system', content: 'You are a business analyst. Return only the size range.' },
                { role: 'user', content: prompt }
            ], { temperature: 0.3 });

            return {
                company_size: size.trim(),
                confidence: 0.5 // Low confidence for size estimates
            };
        } catch (error) {
            console.error('Size estimation error:', error);
            return { company_size: '', confidence: 0 };
        }
    }

    /**
     * Enrich person details (Bio, Location, etc)
     */
    static async enrichPersonInfo(name: string, company: string, jobTitle?: string, searchContext: string = ''): Promise<{ bio: string; confidence: number } | null> {
        try {
            const prompt = `Research "${name}" who works at "${company}"${jobTitle ? ` as "${jobTitle}"` : ''} using these search results:\n\n${searchContext}\n\nExtract a plain text "Professional Biography" (2-3 sentences max) summarizing their role and background. Focus on the person, not just the company. If no specific person info is found, return "null".`;

            const response = await AIService.generateCompletion([
                { role: 'system', content: 'You are a professional biographer. Return a text summary or "null".' },
                { role: 'user', content: prompt }
            ], { temperature: 0.1 });

            if (!response || response.toLowerCase().includes('null') || response.length < 20) return null;

            return {
                bio: response.trim(),
                confidence: searchContext ? 0.8 : 0.4
            };
        } catch (error) {
            console.error('Person info error:', error);
            return null;
        }
    }
}
