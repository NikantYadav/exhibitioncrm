/**
 * Document Parser Service
 * Extracts text from various document formats for AI summarization
 */

const pdfParse = require('pdf-parse');

export interface ParsedDocument {
    text: string;
    metadata: {
        pages?: number;
        title?: string;
        author?: string;
        wordCount: number;
    };
}

export class DocumentParser {
    /**
     * Parse document based on file type
     */
    static async parseDocument(
        buffer: Buffer,
        fileType: string
    ): Promise<ParsedDocument> {
        const type = fileType.toLowerCase();

        if (type.includes('pdf') || type === 'application/pdf') {
            return await this.parsePDF(buffer);
        } else if (
            type.includes('word') ||
            type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
            type === 'application/msword'
        ) {
            return await this.parseDOCX(buffer);
        } else if (type.includes('text') || type === 'text/plain') {
            return this.parseText(buffer);
        } else {
            throw new Error(`Unsupported file type: ${fileType}`);
        }
    }

    /**
     * Parse PDF documents
     */
    private static async parsePDF(buffer: Buffer): Promise<ParsedDocument> {
        try {
            const data = await pdfParse(buffer);

            return {
                text: data.text,
                metadata: {
                    pages: data.numpages,
                    title: data.info?.Title,
                    author: data.info?.Author,
                    wordCount: data.text.split(/\s+/).length,
                },
            };
        } catch (error) {
            console.error('PDF parsing error:', error);
            throw new Error('Failed to parse PDF document');
        }
    }

    /**
     * Parse DOCX documents
     */
    private static async parseDOCX(buffer: Buffer): Promise<ParsedDocument> {
        try {
            const mammoth = await import('mammoth');
            const result = await mammoth.extractRawText({ buffer });

            return {
                text: result.value,
                metadata: {
                    wordCount: result.value.split(/\s+/).length,
                },
            };
        } catch (error) {
            console.error('DOCX parsing error:', error);
            throw new Error('Failed to parse DOCX document');
        }
    }

    /**
     * Parse plain text documents
     */
    private static parseText(buffer: Buffer): ParsedDocument {
        const text = buffer.toString('utf-8');

        return {
            text,
            metadata: {
                wordCount: text.split(/\s+/).length,
            },
        };
    }

    /**
     * Summarize document text using AI
     */
    static async summarizeDocument(
        text: string,
        options?: {
            maxLength?: number;
            style?: 'brief' | 'detailed' | 'bullet_points';
        }
    ): Promise<string> {
        const { AIService } = await import('./ai');

        const style = options?.style || 'brief';
        const maxLength = options?.maxLength || 500;

        const styleInstructions = {
            brief: 'Provide a concise summary in 2-3 sentences.',
            detailed: 'Provide a comprehensive summary covering all key points.',
            bullet_points: 'Provide a summary as bullet points highlighting main topics.',
        };

        const messages = [
            {
                role: 'system' as const,
                content: `You are a document summarization assistant. ${styleInstructions[style]} Keep the summary under ${maxLength} words.`,
            },
            {
                role: 'user' as const,
                content: `Summarize this document:\n\n${text.slice(0, 10000)}`, // Limit input to avoid token limits
            },
        ];

        return await AIService.generateCompletion(messages, {
            temperature: 0.3,
            maxTokens: Math.min(maxLength * 2, 1000),
        });
    }

    /**
     * Extract key information from document
     */
    static async extractKeyInfo(text: string): Promise<{
        topics: string[];
        entities: string[];
        keyPoints: string[];
    }> {
        const { AIService } = await import('./ai');

        const schema = `{
            "topics": ["string array of main topics"],
            "entities": ["string array of people, companies, or organizations mentioned"],
            "keyPoints": ["string array of 3-5 key points or takeaways"]
        }`;

        return await AIService.extractStructuredData(text.slice(0, 10000), schema);
    }
}
