import { LiteLLMService, LiteLLMMessage } from '../services/litellm-service';

// Determine which provider to use
const hasGemini = !!(process.env.GOOGLE_AI_API_KEY || process.env.GEMINI_API_KEY);
const hasOpenAI = !!process.env.OPENAI_API_KEY;

if (!hasGemini && !hasOpenAI) {
  throw new Error('At least one AI provider (OpenAI or Google Gemini) must be configured');
}

// Prefer Gemini as default, fallback to OpenAI
export const AI_PROVIDER = hasGemini ? 'gemini' : 'openai';

// Initialize LiteLLM service
const litellm = new LiteLLMService({
  provider: AI_PROVIDER as 'openai' | 'gemini',
});

export class AIService {
  static async generateCompletion(
    messages: LiteLLMMessage[],
    options?: {
      temperature?: number;
      maxTokens?: number;
      jsonMode?: boolean;
    }
  ): Promise<string> {
    try {
      return await litellm.generateCompletion(messages, options);
    } catch (error) {
      console.error('AI completion error:', error);
      throw error;
    }
  }

  static async extractStructuredData<T>(
    text: string,
    schema: string,
    example?: string
  ): Promise<T> {
    const messages: LiteLLMMessage[] = [
      {
        role: 'system',
        content: `You are a data extraction assistant. Extract information according to this schema: ${schema}. Return ONLY valid JSON, no additional text.${example ? `\n\nExample output:\n${example}` : ''}`,
      },
      {
        role: 'user',
        content: text,
      },
    ];

    const response = await this.generateCompletion(messages, {
      temperature: 0.3,
      jsonMode: true,
    });

    try {
      return litellm.cleanAndParseJSON<T>(response);
    } catch (error) {
      console.error('Failed to parse AI response as JSON:', response);
      throw new Error('AI returned invalid JSON');
    }
  }

  static async transcribeAudio(base64Audio: string): Promise<string> {
    return await litellm.transcribeAudio(base64Audio);
  }
}

export { litellm };
