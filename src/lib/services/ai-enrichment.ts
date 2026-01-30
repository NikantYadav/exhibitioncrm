import { AIService, AIMessage } from './ai';
import { Company } from '@/types';
import { getUserProfile, buildProfileContext } from './profile-service';

export interface EnrichmentResult {
    company?: {
        name: string;
        website?: string;
        industry?: string;
        description?: string;
        location?: string;
        region?: string;
        company_size?: string;
        products_services?: string;
    };
    contact?: {
        linkedin_url?: string;
        job_title?: string;
    };
    confidence: number;
    sources: string[];
}

export class AIEnrichmentService {
    /**
     * Enrich company data from email domain
     */
    static async enrichCompanyFromEmail(email: string): Promise<EnrichmentResult> {
        const domain = email.split('@')[1];

        if (!domain || domain.includes('gmail.com') || domain.includes('yahoo.com') || domain.includes('outlook.com')) {
            return {
                confidence: 0,
                sources: [],
            };
        }

        const website = `https://${domain}`;

        const messages: AIMessage[] = [
            {
                role: 'system',
                content: `You are a company research assistant. Given a company domain, provide information about the company. Return ONLY valid JSON with this structure:
{
  "name": "Company Name",
  "industry": "Industry/Sector",
  "description": "Brief 1-2 sentence description",
  "location": "City, Country",
  "region": "Geographic region",
  "company_size": "Estimated size (e.g., '50-100', '100-500', '500+')",
  "products_services": "Main products or services offered"
}

If you cannot find reliable information, return null for that field. Be conservative with estimates.`,
            },
            {
                role: 'user',
                content: `Research this company domain: ${domain}\nWebsite: ${website}`,
            },
        ];

        try {
            const result = await AIService.extractStructuredData<{
                name: string;
                industry?: string;
                description?: string;
                location?: string;
                region?: string;
                company_size?: string;
                products_services?: string;
            }>(
                `Research company: ${domain}`,
                'Company information schema',
            );

            return {
                company: {
                    name: result.name,
                    website,
                    industry: result.industry,
                    description: result.description,
                    location: result.location,
                    region: result.region,
                    company_size: result.company_size,
                    products_services: result.products_services,
                },
                confidence: 0.7, // AI-estimated, mark as moderate confidence
                sources: ['AI-generated from domain'],
            };
        } catch (error) {
            console.error('Company enrichment error:', error);
            return {
                company: {
                    name: domain.split('.')[0],
                    website,
                },
                confidence: 0.3,
                sources: ['Domain only'],
            };
        }
    }

    /**
     * Enrich company data from company name
     */
    static async enrichCompanyFromName(companyName: string): Promise<EnrichmentResult> {
        const messages: AIMessage[] = [
            {
                role: 'system',
                content: `You are a company research assistant. Research the given company and provide information. Return ONLY valid JSON with this structure:
{
  "name": "Official Company Name",
  "website": "https://company-website.com",
  "industry": "Industry/Sector",
  "description": "Brief 1-2 sentence description",
  "location": "Headquarters location",
  "region": "Geographic region",
  "company_size": "Estimated size",
  "products_services": "Main products or services"
}`,
            },
            {
                role: 'user',
                content: `Research this company: ${companyName}`,
            },
        ];

        try {
            const result = await AIService.extractStructuredData<{
                name: string;
                website?: string;
                industry?: string;
                description?: string;
                location?: string;
                region?: string;
                company_size?: string;
                products_services?: string;
            }>(
                `Research company: ${companyName}`,
                'Company information schema',
            );

            return {
                company: result,
                confidence: 0.6,
                sources: ['AI-generated from company name'],
            };
        } catch (error) {
            console.error('Company enrichment error:', error);
            return {
                company: {
                    name: companyName,
                },
                confidence: 0.2,
                sources: ['Name only'],
            };
        }
    }

    /**
     * Find LinkedIn profile for contact
     */
    static async findLinkedInProfile(
        name: string,
        company?: string,
        jobTitle?: string
    ): Promise<{ linkedin_url?: string; confidence: number }> {
        // Note: This is a simplified version. In production, you'd use LinkedIn API or web scraping
        // For MVP, we'll use AI to suggest likely profile URL format

        const firstName = name.split(' ')[0];
        const lastName = name.split(' ').slice(1).join('-');
        const suggestedUrl = `https://linkedin.com/in/${firstName.toLowerCase()}-${lastName.toLowerCase()}`;

        return {
            linkedin_url: suggestedUrl,
            confidence: 0.4, // Low confidence as this is just a guess
        };
    }

    /**
     * Generate talking points for a company
     */
    static async generateTalkingPoints(company: Company): Promise<string[]> {
        // Get user profile for context
        const profile = await getUserProfile();
        const profileContext = buildProfileContext(profile);

        const messages: AIMessage[] = [
            {
                role: 'system',
                content: 'You are a business development assistant. Generate 3-5 concise talking points for meeting with this company. Each point should be one sentence. Return as JSON array of strings.',
            },
            {
                role: 'user',
                content: `Company: ${company.name}
Industry: ${company.industry || 'Unknown'}
Description: ${company.description || 'No description'}
Products/Services: ${company.products_services || 'Unknown'}

My Information:
${profileContext}`,
            },
        ];

        try {
            const result = await AIService.extractStructuredData<string[]>(
                `Generate talking points for ${company.name}`,
                'Array of talking point strings',
                '["Point 1", "Point 2", "Point 3"]'
            );

            return result;
        } catch (error) {
            console.error('Talking points generation error:', error);
            return [
                `Discuss their ${company.industry || 'business'} solutions`,
                'Explore potential collaboration opportunities',
                'Understand their current challenges and needs',
            ];
        }
    }
}
