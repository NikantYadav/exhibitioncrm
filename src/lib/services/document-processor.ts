
import { MarketingAsset } from '@/app/actions/assets';
const pdf = require('pdf-parse');
import mammoth from 'mammoth';

export class DocumentProcessor {
    /**
     * Process a marketing asset to extract its text content
     */
    static async processAsset(asset: MarketingAsset): Promise<string> {
        try {
            console.log(`Processing asset: ${asset.name} (${asset.file_url})`);

            // 1. Fetch file content
            const response = await fetch(asset.file_url);
            if (!response.ok) {
                throw new Error(`Failed to fetch file: ${response.statusText}`);
            }
            const arrayBuffer = await response.arrayBuffer();
            const buffer = Buffer.from(arrayBuffer);

            // 2. Determine file type and extract text
            let text = '';
            const lowerName = asset.name.toLowerCase();

            if (lowerName.endsWith('.pdf')) {
                text = await this.extractPdfText(buffer);
            } else if (lowerName.endsWith('.docx') || lowerName.endsWith('.doc')) {
                text = await this.extractDocxText(buffer);
            } else {
                // Determine text file or other
                const contentType = response.headers.get('content-type') || '';
                if (contentType.includes('text') || lowerName.endsWith('.txt') || lowerName.endsWith('.md')) {
                    text = buffer.toString('utf-8');
                } else {
                    console.warn(`Unsupported file type for text extraction: ${asset.name}`);
                    return '';
                }
            }

            // 3. Clean text
            return this.cleanText(text);

        } catch (error) {
            console.error(`Error processing document ${asset.id}:`, error);
            throw error;
        }
    }

    private static async extractPdfText(buffer: Buffer): Promise<string> {
        try {
            const data = await pdf(buffer);
            return data.text;
        } catch (error) {
            console.error('PDF extraction error:', error);
            throw new Error('Failed to parse PDF');
        }
    }

    private static async extractDocxText(buffer: Buffer): Promise<string> {
        try {
            const result = await mammoth.extractRawText({ buffer });
            return result.value;
        } catch (error) {
            console.error('DOCX extraction error:', error);
            throw new Error('Failed to parse DOCX');
        }
    }

    private static cleanText(text: string): string {
        return text
            .replace(/\r\n/g, '\n')
            .replace(/\t/g, ' ')
            .replace(/\s+/g, ' ') // Collapse multiple spaces
            .trim();
    }

    /**
     * Split text into chunks for embedding
     * Simple overlapping window strategy
     */
    static chunkText(text: string, chunkSize: number = 1000, overlap: number = 200): string[] {
        if (!text || text.length === 0) return [];
        if (text.length <= chunkSize) return [text];

        const chunks: string[] = [];
        let startIndex = 0;

        while (startIndex < text.length) {
            let endIndex = startIndex + chunkSize;

            // If we are not at the end, try to break at a sentence or word boundary
            if (endIndex < text.length) {
                // Look for last period in the overlap zone
                const lastPeriod = text.lastIndexOf('.', endIndex);
                if (lastPeriod > startIndex + (chunkSize / 2)) {
                    endIndex = lastPeriod + 1;
                } else {
                    // Look for last space
                    const lastSpace = text.lastIndexOf(' ', endIndex);
                    if (lastSpace > startIndex + (chunkSize / 2)) {
                        endIndex = lastSpace;
                    }
                }
            }

            const chunk = text.substring(startIndex, endIndex).trim();
            if (chunk.length > 0) {
                chunks.push(chunk);
            }

            startIndex = endIndex - overlap;
            // Prevent infinite loop if forward progress is too small
            if (startIndex >= endIndex) startIndex++;
        }

        return chunks;
    }
}
