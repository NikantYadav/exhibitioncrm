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
    private static geminiKeys: string[] = [];
    private static currentGeminiIndex: number = 0;

    constructor(config?: Partial<LiteLLMConfig>) {
        if (LiteLLMService.geminiKeys.length === 0) {
            this.initGeminiKeys();
        }

        // Default to Gemini as per user preference
        const provider = config?.provider || 'gemini';
        this.config = {
            provider,
            model: config?.model || this.getDefaultModel(provider),
            apiKey: config?.apiKey || this.getApiKey(provider),
            temperature: config?.temperature || 0.7,
            maxTokens: config?.maxTokens || 2000,
        };
    }

    private initGeminiKeys() {
        const keys = new Set<string>();

        // Primary keys
        if (process.env.GEMINI_API_KEY) {
            process.env.GEMINI_API_KEY.split(',').forEach(k => keys.add(k.trim()));
        }
        if (process.env.GOOGLE_API_KEY) {
            process.env.GOOGLE_API_KEY.split(',').forEach(k => keys.add(k.trim()));
        }

        // Supporting multiple keys via GEMINI_API_KEY_1, GEMINI_API_KEY_2, etc.
        for (let i = 1; i <= 20; i++) {
            const key = process.env[`GEMINI_API_KEY_${i}`] || process.env[`GOOGLE_API_KEY_${i}`];
            if (key) keys.add(key.trim());
        }

        LiteLLMService.geminiKeys = Array.from(keys).filter(Boolean);

        // Shuffle keys to distribute load evenly across instances/starts
        LiteLLMService.geminiKeys.sort(() => Math.random() - 0.5);

        if (LiteLLMService.geminiKeys.length > 0) {
            console.log(`LiteLLMService initialized with ${LiteLLMService.geminiKeys.length} Gemini API keys`);
        }
    }

    private getNextGeminiKey(): string {
        if (LiteLLMService.geminiKeys.length === 0) return this.config.apiKey;
        const key = LiteLLMService.geminiKeys[LiteLLMService.currentGeminiIndex];
        LiteLLMService.currentGeminiIndex = (LiteLLMService.currentGeminiIndex + 1) % LiteLLMService.geminiKeys.length;
        return key;
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
        if (provider === 'gemini') {
            return this.getNextGeminiKey();
        }

        const keys: Record<string, string | undefined> = {
            openai: process.env.OPENAI_API_KEY,
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

    private async withGemini<T>(operation: (apiKey: string) => Promise<T>): Promise<T> {
        let lastError: any;
        const attempts = Math.max(1, LiteLLMService.geminiKeys.length);

        for (let i = 0; i < attempts; i++) {
            const apiKey = this.getNextGeminiKey();
            try {
                return await operation(apiKey);
            } catch (error: any) {
                lastError = error;
                // Check for 429 Too Many Requests
                const isRateLimit = error.status === 429 ||
                    error.message?.includes('429') ||
                    error.message?.includes('quota') ||
                    error.message?.includes('Rate limit');

                if (isRateLimit && i < attempts - 1) {
                    console.warn(`Gemini rate limit hit. Retrying with next available key... (Attempt ${i + 1}/${attempts})`);
                    continue;
                }
                throw error;
            }
        }
        throw lastError;
    }

    /**
     * Gemini implementation
     */
    private async generateGeminiCompletion(
        messages: LiteLLMMessage[],
        temperature: number,
        maxTokens: number
    ): Promise<string> {
        return this.withGemini(async (apiKey) => {
            const { GoogleGenerativeAI } = await import('@google/generative-ai');
            const genAI = new GoogleGenerativeAI(apiKey);
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
        });
    }

    private async *streamGeminiCompletion(
        messages: LiteLLMMessage[],
        temperature: number
    ): AsyncGenerator<string> {
        const { GoogleGenerativeAI } = await import('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(this.getNextGeminiKey());
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

        const text = await this.withGemini(async (apiKey) => {
            const { GoogleGenerativeAI } = await import('@google/generative-ai');
            const genAI = new GoogleGenerativeAI(apiKey);
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
            return response.text();
        });


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

        return this.withGemini(async (apiKey) => {
            const { GoogleGenerativeAI } = await import('@google/generative-ai');
            const genAI = new GoogleGenerativeAI(apiKey);
            const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

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
        });
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
     * Generate embedding for text
     */
    async generateEmbedding(text: string): Promise<number[]> {
        if (this.config.provider !== 'gemini') {
            throw new Error('Embeddings are currently only implemented for Gemini in this service');
        }

        return this.withGemini(async (apiKey) => {
            const { GoogleGenerativeAI } = await import('@google/generative-ai');
            const genAI = new GoogleGenerativeAI(apiKey);
            const model = genAI.getGenerativeModel({ model: 'text-embedding-004' });

            const result = await model.embedContent(text);
            return result.embedding.values;
        });
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
