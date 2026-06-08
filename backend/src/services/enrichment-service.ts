import { AIService } from '../config/ai';
import { TavilyService } from './tavily-service';

export interface EnrichmentResult {
    industry?: string;
    description?: string;
    location?: string;
    region?: string;
    company_size?: string;
    products_services?: string;
    website?: string;
    linkedin_url?: string;
    confidence: {
        industry?: number;
        description?: number;
        location?: number;
    };
}

export class EnrichmentService {
    static async enrichContact(params: {
        name: string;
        company?: string;
        email?: string;
        job_title?: string;
    }): Promise<EnrichmentResult> {
        const isIndependent = !params.company || params.company.toUpperCase() === 'INDEPENDENT';

        console.log(`[enrichment] Running Tavily search for: ${params.name} @ ${params.company || 'independent'}`);
        const webContext = await TavilyService.searchContact({
            name: params.name,
            company: isIndependent ? undefined : params.company,
            jobTitle: params.job_title,
        });

        const prompt = `Research and provide information about this professional contact:
Name: ${params.name}
${isIndependent ? 'Company: Independent (freelancer / no company)' : `Company: ${params.company}`}
Job Title: ${params.job_title || 'Unknown'}
Email: ${params.email || 'Unknown'}

${webContext ? `## Live Web Research\n${webContext}\n\n` : ''}Provide detailed information about ${isIndependent ? 'the person' : 'the company and the person'}.
Return ONLY valid JSON.`;

        const schema = `{
            "industry": "string",
            "description": "string",
            "location": "string",
            "region": "string",
            "company_size": "string",
            "products_services": "string",
            "website": "string",
            "linkedin_url": "string"
        }`;

        try {
            const result = await AIService.extractStructuredData<any>(prompt, schema);
            return {
                ...result,
                confidence: {
                    industry: 0.7,
                    description: 0.7,
                    location: 0.7
                }
            };
        } catch (error) {
            console.error('Enrichment error:', error);
            return {
                confidence: {
                    industry: 0,
                    description: 0,
                    location: 0
                }
            };
        }
    }
}
