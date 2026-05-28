import Tesseract from 'tesseract.js';
import { AIService } from '../../config/ai';

export async function analyzeCard(imageData: string) {
  try {
    // OCR extraction
    const { data: { text } } = await Tesseract.recognize(imageData, 'eng');

    // AI parsing
    const extracted = await AIService.extractStructuredData(
      text,
      'Extract contact information: { name: string, company: string, email: string, phone: string, job_title: string }'
    );

    return {
      success: true,
      data: {
        raw_text: text,
        extracted_data: extracted
      }
    };
  } catch (error) {
    console.error('Card analysis error:', error);
    throw error;
  }
}
