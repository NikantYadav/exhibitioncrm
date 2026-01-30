/**
 * LiteLLM Service - Unified interface for multiple AI providers
 * Supports: OpenAI, Google Gemini, and more
 */

export interface LiteLLMMessage {
    role: 'system' | 'user' | 'assistant';
    content: string;
}

export interface LiteLLMConfig {
    provider: 'openai' | 'gemini' | 'azure';
    model: string;
    apiKey: string;
    temperature?: number;
    maxTokens?: number;
}

export interface CompletionOptions {
    temperature?: number;
    maxTokens?: number;
    stream?: boolean;
}

export class LiteLLMService {
    private config: LiteLLMConfig;

    constructor(config?: Partial<LiteLLMConfig>) {
        // Default to Gemini as per user preference
        this.config = {
            provider: config?.provider || 'gemini',
            model: config?.model || this.getDefaultModel(config?.provider || 'gemini'),
            apiKey: config?.apiKey || this.getApiKey(config?.provider || 'gemini'),
            temperature: config?.temperature || 0.7,
            maxTokens: config?.maxTokens || 2000,
        };
    }

    private getDefaultModel(provider: string): string {
        const models: Record<string, string> = {
            openai: 'gpt-4-vision-preview',
            gemini: 'gemini-2.5-flash',
            azure: 'gpt-4',
        };
        return models[provider] || 'gemini-2.5-flash';
    }

    private getApiKey(provider: string): string {
        const keys: Record<string, string | undefined> = {
            openai: process.env.OPENAI_API_KEY,
            gemini: process.env.GOOGLE_API_KEY || process.env.GEMINI_API_KEY,
            azure: process.env.AZURE_OPENAI_API_KEY,
        };
        return keys[provider] || '';
    }

    /**
     * Generate completion using the configured provider
     */
    async generateCompletion(
        messages: LiteLLMMessage[],
        options?: CompletionOptions
    ): Promise<string> {
        const temperature = options?.temperature ?? this.config.temperature;
        const maxTokens = options?.maxTokens ?? this.config.maxTokens;

        try {
            switch (this.config.provider) {
                case 'gemini':
                    return await this.generateGeminiCompletion(messages, temperature!, maxTokens!);
                case 'openai':
                    return await this.generateOpenAICompletion(messages, temperature!, maxTokens!);
                default:
                    throw new Error(`Unsupported provider: ${this.config.provider}`);
            }
        } catch (error) {
            console.error('LiteLLM completion error:', error);
            throw new Error(`Failed to generate completion with ${this.config.provider}`);
        }
    }

    /**
     * Generate streaming completion
     */
    async *generateStreamingCompletion(
        messages: LiteLLMMessage[],
        options?: CompletionOptions
    ): AsyncGenerator<string> {
        const temperature = options?.temperature ?? this.config.temperature;

        try {
            switch (this.config.provider) {
                case 'gemini':
                    yield* this.streamGeminiCompletion(messages, temperature!);
                    break;
                case 'openai':
                    yield* this.streamOpenAICompletion(messages, temperature!);
                    break;
                default:
                    throw new Error(`Streaming not supported for ${this.config.provider}`);
            }
        } catch (error) {
            console.error('LiteLLM streaming error:', error);
            throw new Error(`Failed to generate streaming completion with ${this.config.provider}`);
        }
    }

    /**
     * Gemini implementation
     */
    private async generateGeminiCompletion(
        messages: LiteLLMMessage[],
        temperature: number,
        maxTokens: number
    ): Promise<string> {
        const { GoogleGenerativeAI } = await import('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(this.config.apiKey);
        const model = genAI.getGenerativeModel({ model: this.config.model });

        // Convert messages to Gemini format
        const systemMessage = messages.find(m => m.role === 'system');
        const userMessages = messages.filter(m => m.role !== 'system');

        const prompt = userMessages.map(m => m.content).join('\n\n');
        const fullPrompt = systemMessage
            ? `${systemMessage.content}\n\n${prompt}`
            : prompt;

        const result = await model.generateContent({
            contents: [{ role: 'user', parts: [{ text: fullPrompt }] }],
            generationConfig: {
                temperature,
                maxOutputTokens: maxTokens,
            },
        });

        const response = await result.response;
        return response.text();
    }

    private async *streamGeminiCompletion(
        messages: LiteLLMMessage[],
        temperature: number
    ): AsyncGenerator<string> {
        const { GoogleGenerativeAI } = await import('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(this.config.apiKey);
        const model = genAI.getGenerativeModel({ model: this.config.model });

        const systemMessage = messages.find(m => m.role === 'system');
        const userMessages = messages.filter(m => m.role !== 'system');

        const prompt = userMessages.map(m => m.content).join('\n\n');
        const fullPrompt = systemMessage
            ? `${systemMessage.content}\n\n${prompt}`
            : prompt;

        const result = await model.generateContentStream({
            contents: [{ role: 'user', parts: [{ text: fullPrompt }] }],
            generationConfig: {
                temperature,
            },
        });

        for await (const chunk of result.stream) {
            const text = chunk.text();
            if (text) {
                yield text;
            }
        }
    }

    /**
     * OpenAI implementation (fallback)
     */
    private async generateOpenAICompletion(
        messages: LiteLLMMessage[],
        temperature: number,
        maxTokens: number
    ): Promise<string> {
        const OpenAI = (await import('openai')).default;
        const openai = new OpenAI({ apiKey: this.config.apiKey });

        const response = await openai.chat.completions.create({
            model: this.config.model,
            messages,
            temperature,
            max_tokens: maxTokens,
        });

        return response.choices[0]?.message?.content || '';
    }

    private async *streamOpenAICompletion(
        messages: LiteLLMMessage[],
        temperature: number
    ): AsyncGenerator<string> {
        const OpenAI = (await import('openai')).default;
        const openai = new OpenAI({ apiKey: this.config.apiKey });

        const stream = await openai.chat.completions.create({
            model: this.config.model,
            messages,
            temperature,
            stream: true,
        });

        for await (const chunk of stream) {
            const content = chunk.choices[0]?.delta?.content;
            if (content) {
                yield content;
            }
        }
    }

    /**
     * Analyze an image (base64) using the configured provider
     */
    async analyzeImage<T>(
        base64Image: string,
        prompt: string,
        schema?: string
    ): Promise<T> {
        if (this.config.provider !== 'gemini') {
            throw new Error('Image analysis is currently only implemented for Gemini in this service');
        }

        const { GoogleGenerativeAI } = await import('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(this.config.apiKey);
        const model = genAI.getGenerativeModel({ model: this.config.model });

        // Clean base64 string
        const base64Data = base64Image.split(',')[1] || base64Image;
        const mimeType = base64Image.split(';')[0].split(':')[1] || 'image/jpeg';

        const result = await model.generateContent([
            prompt + (schema ? `\n\nReturn EXACTLY a JSON object matching this schema: ${schema}` : ''),
            {
                inlineData: {
                    data: base64Data,
                    mimeType
                }
            }
        ]);

        const response = await result.response;
        const text = response.text();

        try {
            return this.cleanAndParseJSON<T>(text);
        } catch (error) {
            console.error('Failed to parse AI image analysis response:', text);
            throw new Error('AI returned invalid JSON');
        }
    }

    /**
     * Transcribe audio (base64) using Gemini
     */
    async transcribeAudio(
        base64Audio: string,
        prompt: string = "Please provide a high-quality transcript of this audio recording. Return ONLY the transcript text."
    ): Promise<string> {
        if (this.config.provider !== 'gemini') {
            throw new Error('Audio transcription is currently only implemented for Gemini in this service');
        }

        const { GoogleGenerativeAI } = await import('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(this.config.apiKey);
        // Use gemini-2.5-flash for audio as it's very efficient
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        // Clean base64 string
        const base64Data = base64Audio.split(',')[1] || base64Audio;
        const mimeType = base64Audio.match(/^data:([^;]+);base64,/)?.[1] || 'audio/webm';

        const result = await model.generateContent([
            prompt,
            {
                inlineData: {
                    data: base64Data,
                    mimeType
                }
            }
        ]);

        const response = await result.response;
        return response.text();
    }


    /**
     * Extract structured data from text
     */
    async extractStructuredData<T>(
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
        });

        try {
            return this.cleanAndParseJSON<T>(response);
        } catch (error) {
            console.error('Failed to parse AI response as JSON:', response);
            throw new Error('AI returned invalid JSON');
        }
    }

    /**
     * Clean and parse JSON from AI response
     */
    public cleanAndParseJSON<T>(text: string): T {
        // 1. Remove markdown code blocks with any language tag (json, JSON, typescript, etc.)
        let clean = text.replace(/```[a-zA-Z]*\n?|\n?```/g, '').trim();

        // 2. Find the first '{' or '[' and last '}' or ']'
        const firstBrace = clean.indexOf('{');
        const firstBracket = clean.indexOf('[');
        const start = (firstBrace !== -1 && (firstBracket === -1 || firstBrace < firstBracket)) ? firstBrace : firstBracket;

        const lastBrace = clean.lastIndexOf('}');
        const lastBracket = clean.lastIndexOf(']');
        const end = Math.max(lastBrace, lastBracket);

        if (start !== -1 && end !== -1 && end > start) {
            clean = clean.substring(start, end + 1);
        }

        // 3. Remove trailing commas before closing braces/brackets
        clean = clean.replace(/,\s*([}\]])/g, '$1');

        try {
            return JSON.parse(clean);
        } catch (e) {
            // Last ditch effort: try to fix unquoted keys if it's a simple case
            // This is risky but sometimes helps with small mistakes
            try {
                const fixed = clean.replace(/([{,]\s*)([a-zA-Z0-9_]+)\s*:/g, '$1"$2":');
                return JSON.parse(fixed);
            } catch (innerE) {
                throw e; // Throw original error if fix fails
            }
        }
    }
}

// Export singleton instance with default config
export const litellm = new LiteLLMService();
