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

        // Run enrichment tasks in parallel
        const [website, companyInfo, linkedIn] = await Promise.all([
            domain ? this.findCompanyWebsite(contactData.company || '', domain) : null,
            contactData.company ? this.enrichCompanyInfo(contactData.company, domain) : null,
            contactData.name && contactData.company ? this.findLinkedInProfile(contactData.name, contactData.company, contactData.job_title) : null
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
            results.sources!.push('AI LinkedIn Search');
        }

        return results as EnrichmentResult;
    }

    /**
     * Find company website from name and/or domain
     */
    static async findCompanyWebsite(companyName: string, domain?: string): Promise<{ url: string; confidence: number } | null> {
        try {
            if (domain && !domain.includes('gmail') && !domain.includes('yahoo') && !domain.includes('outlook')) {
                // High confidence if we have a corporate domain
                return {
                    url: `https://${domain}`,
                    confidence: 0.9
                };
            }

            // Use AI to suggest website
            const prompt = `What is the official website URL for the company "${companyName}"? Return ONLY the URL, nothing else.`;
            const response = await AIService.generateCompletion([
                { role: 'system', content: 'You are a company research assistant. Return only URLs, no explanations.' },
                { role: 'user', content: prompt }
            ], { temperature: 0.3 });

            const url = response.trim().replace(/^https?:\/\//, '').replace(/\/$/, '');
            return {
                url: `https://${url}`,
                confidence: 0.6 // Lower confidence for AI-suggested URLs
            };
        } catch (error) {
            console.error('Website finder error:', error);
            return null;
        }
    }

    /**
     * Enrich company information (industry, description, location, etc.)
     */
    static async enrichCompanyInfo(companyName: string, domain?: string): Promise<Partial<EnrichmentResult>> {
        try {
            const prompt = `Research the company "${companyName}"${domain ? ` (${domain})` : ''} and provide:
1. Industry/sector
2. Brief 1-2 sentence description
3. Headquarters location (city, country)
4. Main products or services
5. Estimated company size (e.g., "1-10", "11-50", "51-200", "201-500", "500+")

Return as JSON with keys: industry, description, location, region, products_services, company_size`;

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
                    industry: 0.7,
                    description: 0.7,
                    location: 0.6,
                    region: 0.6,
                    products_services: 0.7,
                    company_size: 0.5
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
    static async findLinkedInProfile(name: string, company: string, jobTitle?: string): Promise<{ url: string; confidence: number } | null> {
        try {
            // Simple heuristic: construct likely LinkedIn URL
            const nameParts = name.toLowerCase().split(' ');
            const firstName = nameParts[0];
            const lastName = nameParts.slice(1).join('-');

            const suggestedUrl = `https://linkedin.com/in/${firstName}-${lastName}`;

            return {
                url: suggestedUrl,
                confidence: 0.4 // Low confidence as this is just a guess
            };
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
}
