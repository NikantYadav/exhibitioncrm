import { LiteLLMService, LiteLLMMessage } from './litellm-service';

// Legacy OpenAI import for backward compatibility
import OpenAI from 'openai';

// OpenAI instance for legacy fallback (lazy initialized)
let openaiInstance: OpenAI | null = null;
const getOpenAI = () => {
    if (!openaiInstance) {
        if (!process.env.OPENAI_API_KEY) {
            throw new Error('OPENAI_API_KEY is missing');
        }
        openaiInstance = new OpenAI({
            apiKey: process.env.OPENAI_API_KEY,
        });
    }
    return openaiInstance;
};

// Initialize LiteLLM with Gemini as default
const litellm = new LiteLLMService({
    provider: 'gemini',
});

export interface AIMessage {
    role: 'system' | 'user' | 'assistant';
    content: string;
}

export class AIService {
    /**
     * Generate completion using LiteLLM (Gemini by default)
     * Falls back to OpenAI if LiteLLM fails
     */
    static async generateCompletion(
        messages: AIMessage[],
        options?: {
            model?: string;
            temperature?: number;
            maxTokens?: number;
            useLegacy?: boolean; // Force use of OpenAI
        }
    ): Promise<string> {
        try {
            // Use legacy OpenAI if explicitly requested
            if (options?.useLegacy) {
                return await this.generateOpenAICompletion(messages, options);
            }

            // Use LiteLLM (Gemini) by default
            return await litellm.generateCompletion(messages as LiteLLMMessage[], {
                temperature: options?.temperature,
                maxTokens: options?.maxTokens,
            });
        } catch (error) {
            console.error('LiteLLM generation error, falling back to OpenAI:', error);

            // Fallback to OpenAI if LiteLLM fails
            try {
                return await this.generateOpenAICompletion(messages, options);
            } catch (fallbackError) {
                console.error('OpenAI fallback also failed:', fallbackError);
                throw new Error('Failed to generate AI response');
            }
        }
    }

    /**
     * Legacy OpenAI completion (fallback)
     */
    private static async generateOpenAICompletion(
        messages: AIMessage[],
        options?: {
            model?: string;
            temperature?: number;
            maxTokens?: number;
        }
    ): Promise<string> {
        const response = await getOpenAI().chat.completions.create({
            model: options?.model || 'gpt-4-turbo-preview',
            messages,
            temperature: options?.temperature || 0.7,
            max_tokens: options?.maxTokens || 1000,
        });

        return response.choices[0]?.message?.content || '';
    }

    /**
     * Generate streaming completion using LiteLLM
     */
    static async *generateStreamingCompletion(
        messages: AIMessage[],
        options?: {
            model?: string;
            temperature?: number;
            useLegacy?: boolean;
        }
    ): AsyncGenerator<string> {
        try {
            if (options?.useLegacy) {
                yield* this.generateOpenAIStream(messages, options);
                return;
            }

            yield* litellm.generateStreamingCompletion(messages as LiteLLMMessage[], {
                temperature: options?.temperature,
            });
        } catch (error) {
            console.error('LiteLLM streaming error, falling back to OpenAI:', error);
            yield* this.generateOpenAIStream(messages, options);
        }
    }

    /**
     * Legacy OpenAI streaming (fallback)
     */
    private static async *generateOpenAIStream(
        messages: AIMessage[],
        options?: {
            model?: string;
            temperature?: number;
        }
    ): AsyncGenerator<string> {
        const stream = await getOpenAI().chat.completions.create({
            model: options?.model || 'gpt-4-turbo-preview',
            messages,
            temperature: options?.temperature || 0.7,
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
     * Extract structured data from text using LiteLLM
     */
    static async extractStructuredData<T>(
        text: string,
        schema: string,
        example?: string
    ): Promise<T> {
        try {
            return await litellm.extractStructuredData<T>(text, schema, example);
        } catch (error) {
            console.error('LiteLLM extraction error:', error);

            // Fallback to legacy implementation
            const messages: AIMessage[] = [
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
                useLegacy: true,
            });

            try {
                return this.parseJSON<T>(response);
            } catch (parseError) {
                console.error('Failed to parse AI response as JSON:', response);
                throw new Error('AI returned invalid JSON');
            }
        }
    }

    /**
     * Parse JSON from AI response, cleaning markdown if necessary
     */
    static parseJSON<T>(text: string): T {
        return litellm.cleanAndParseJSON<T>(text);
    }
    /**
     * Generate embedding for text
     */
    static async generateEmbedding(text: string): Promise<number[]> {
        return litellm.generateEmbedding(text);
    }
}
