// Tesseract.js will be dynamically imported


export interface OCRResult {
    text: string;
    confidence: number;
    extractedData?: {
        name?: string;
        company?: string;
        email?: string;
        phone?: string;
        jobTitle?: string;
        address?: string;
    };
}

export class ClientOCRService {
    /**
     * Extract text from image using Tesseract.js in the browser
     */
    static async extractTextFromImage(imageUrl: string, onProgress?: (progress: number) => void): Promise<OCRResult> {
        try {
            const Tesseract = (await import('tesseract.js')).default;
            const result = await Tesseract.recognize(imageUrl, 'eng', {
                logger: (m) => {
                    if (m.status === 'recognizing text' && onProgress) {
                        onProgress(m.progress * 100);
                    }
                },
            });

            const text = result.data.text;
            const confidence = result.data.confidence / 100;

            // Extract structured data from OCR text
            const extractedData = this.parseBusinessCard(text);

            return {
                text,
                confidence,
                extractedData,
            };
        } catch (error) {
            console.error('OCR error:', error);
            throw new Error('Failed to extract text from image');
        }
    }

    /**
     * Parse business card text to extract structured information
     * (Reused logic from original server-side service)
     */
    private static parseBusinessCard(text: string): OCRResult['extractedData'] {
        const lines = text.split('\n').map(line => line.trim()).filter(Boolean);
        const data: OCRResult['extractedData'] = {};

        // Email regex
        const emailRegex = /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)/gi;
        const emailMatch = text.match(emailRegex);
        if (emailMatch) {
            data.email = emailMatch[0].toLowerCase();
        }

        // Phone regex (various formats)
        const phoneRegex = /(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g;
        const phoneMatch = text.match(phoneRegex);
        if (phoneMatch) {
            data.phone = phoneMatch[0];
        }

        // Website/domain extraction
        const websiteRegex = /(www\.[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|[a-zA-Z0-9.-]+\.(com|net|org|io|co))/gi;
        const websiteMatch = text.match(websiteRegex);

        // Assume first line is name (if it doesn't contain email/phone/website)
        if (lines.length > 0) {
            const firstLine = lines[0];
            if (!emailRegex.test(firstLine) && !phoneRegex.test(firstLine) && !websiteRegex.test(firstLine)) {
                data.name = firstLine;
            }
        }

        // Try to find company name (usually second or third line, or line with Inc, LLC, Ltd, etc.)
        const companyKeywords = /\b(Inc|LLC|Ltd|Corporation|Corp|Company|Co\.|GmbH|Limited)\b/i;
        for (const line of lines) {
            if (companyKeywords.test(line) && line !== data.name) {
                data.company = line;
                break;
            }
        }

        // If no company found with keywords, try second line
        if (!data.company && lines.length > 1 && lines[1] !== data.name) {
            const secondLine = lines[1];
            if (!emailRegex.test(secondLine) && !phoneRegex.test(secondLine)) {
                data.company = secondLine;
            }
        }

        // Job title keywords
        const titleKeywords = /\b(CEO|CTO|CFO|COO|Director|Manager|President|VP|Vice President|Head|Lead|Engineer|Developer|Designer|Analyst|Consultant|Specialist|Coordinator)\b/i;
        for (const line of lines) {
            if (titleKeywords.test(line) && line !== data.name && line !== data.company) {
                data.jobTitle = line;
                break;
            }
        }

        return data;
    }
}
