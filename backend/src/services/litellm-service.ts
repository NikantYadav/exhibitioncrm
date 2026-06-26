import { GoogleGenerativeAI, FunctionCallingMode } from '@google/generative-ai';
import OpenAI from 'openai';

export interface LiteLLMMessage {
    role: 'system' | 'user' | 'assistant';
    content: string;
}

// ─── Native tool-calling types ───────────────────────────────────────────────

export interface ToolSchema {
    name: string;
    description: string;
    parameters: Record<string, unknown>; // JSON Schema object
}

export interface ToolCall {
    id: string;
    name: string;
    args: Record<string, unknown>;
}

export type ToolCallingResult =
    | { type: 'tool_calls'; calls: ToolCall[]; _geminiParts?: any[] }
    | { type: 'text'; content: string };

/** One turn in a multi-turn tool-calling conversation. */
export type ConversationTurn =
    | { role: 'user'; content: string }
    | { role: 'assistant'; content: string }
    | { role: 'tool_calls'; calls: ToolCall[]; _geminiParts?: any[] }
    | { role: 'tool_results'; results: Array<{ id: string; name: string; result: unknown }> };

export interface LiteLLMConfig {
    provider: 'openai' | 'gemini';
    model?: string;
    apiKey?: string;
    temperature?: number;
    maxTokens?: number;
}

export interface CompletionOptions {
    temperature?: number;
    maxTokens?: number;
    jsonMode?: boolean;
}

export class LiteLLMService {
    private config: LiteLLMConfig;
    private static geminiKeys: string[] = [];
    private static currentGeminiIndex: number = 0;

    constructor(config?: Partial<LiteLLMConfig>) {
        if (LiteLLMService.geminiKeys.length === 0) {
            this.initGeminiKeys();
        }

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

        if (process.env.GEMINI_API_KEY) {
            process.env.GEMINI_API_KEY.split(',').forEach(k => keys.add(k.trim()));
        }
        if (process.env.GOOGLE_AI_API_KEY) {
            process.env.GOOGLE_AI_API_KEY.split(',').forEach(k => keys.add(k.trim()));
        }

        for (let i = 1; i <= 20; i++) {
            const key = process.env[`GEMINI_API_KEY_${i}`] || process.env[`GOOGLE_API_KEY_${i}`];
            if (key) keys.add(key.trim());
        }

        LiteLLMService.geminiKeys = Array.from(keys).filter(Boolean);
        LiteLLMService.geminiKeys.sort(() => Math.random() - 0.5);

        if (LiteLLMService.geminiKeys.length > 0) {
            console.log(`LiteLLMService initialized with ${LiteLLMService.geminiKeys.length} Gemini API keys`);
        }
    }

    private getNextGeminiKey(): string {
        if (LiteLLMService.geminiKeys.length === 0) return this.config.apiKey || '';
        const key = LiteLLMService.geminiKeys[LiteLLMService.currentGeminiIndex];
        LiteLLMService.currentGeminiIndex = (LiteLLMService.currentGeminiIndex + 1) % LiteLLMService.geminiKeys.length;
        return key;
    }

    private getDefaultModel(provider: string): string {
        const models: Record<string, string> = {
            openai: 'gpt-4o-mini',
            gemini: 'gemini-3.1-flash-lite',
        };
        return models[provider] || 'gemini-3.1-flash-lite';
    }

    private getApiKey(provider: string): string {
        if (provider === 'gemini') {
            return this.getNextGeminiKey();
        }
        return process.env.OPENAI_API_KEY || '';
    }

    async generateCompletion(
        messages: LiteLLMMessage[],
        options?: CompletionOptions
    ): Promise<string> {
        const temperature = options?.temperature ?? this.config.temperature;
        const maxTokens = options?.maxTokens ?? this.config.maxTokens;

        try {
            switch (this.config.provider) {
                case 'gemini':
                    return await this.generateGeminiCompletion(messages, temperature!, maxTokens!, options?.jsonMode);
                case 'openai':
                    return await this.generateOpenAICompletion(messages, temperature!, maxTokens!, options?.jsonMode);
                default:
                    throw new Error(`Unsupported provider: ${this.config.provider}`);
            }
        } catch (error) {
            console.error('LiteLLM completion error:', error);
            throw error;
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
                const isRateLimit = error.status === 429 ||
                    error.message?.includes('429') ||
                    error.message?.includes('quota') ||
                    error.message?.includes('Rate limit');

                if (isRateLimit && i < attempts - 1) {
                    console.warn(`Gemini rate limit hit. Retrying with next key... (${i + 1}/${attempts})`);
                    continue;
                }
                throw error;
            }
        }
        throw lastError;
    }

    private async generateGeminiCompletion(
        messages: LiteLLMMessage[],
        temperature: number,
        maxTokens: number,
        jsonMode?: boolean
    ): Promise<string> {
        return this.withGemini(async (apiKey) => {
            const genAI = new GoogleGenerativeAI(apiKey);

            const model = genAI.getGenerativeModel({
                model: this.config.model!,
                generationConfig: {
                    temperature,
                    maxOutputTokens: maxTokens,
                    ...(jsonMode && { responseMimeType: 'application/json' })
                },
            });

            const systemMessage = messages.find(m => m.role === 'system');
            const userMessages = messages.filter(m => m.role !== 'system');

            const prompt = userMessages.map(m => m.content).join('\n\n');
            const fullPrompt = systemMessage
                ? `${systemMessage.content}\n\n${prompt}`
                : prompt;

            const result = await model.generateContent(fullPrompt);
            const response = await result.response;
            return response.text();
        });
    }

    private async generateOpenAICompletion(
        messages: LiteLLMMessage[],
        temperature: number,
        maxTokens: number,
        jsonMode?: boolean
    ): Promise<string> {
        const openai = new OpenAI({ apiKey: this.config.apiKey });

        const response = await openai.chat.completions.create({
            model: this.config.model!,
            messages,
            temperature,
            max_tokens: maxTokens,
            ...(jsonMode && { response_format: { type: 'json_object' } })
        });

        return response.choices[0]?.message?.content || '';
    }

    // ─── Native tool calling ──────────────────────────────────────────────────

    /**
     * One step of a native tool-calling conversation.
     * Returns either a list of tool calls the model wants to make,
     * or a final text response when the model is done.
     *
     * @param systemPrompt  The system instruction (injected once).
     * @param history       The conversation so far (user/assistant/tool turns).
     * @param tools         Tool schemas to offer the model.
     */
    async generateWithTools(
        systemPrompt: string,
        history: ConversationTurn[],
        tools: ToolSchema[]
    ): Promise<ToolCallingResult> {
        switch (this.config.provider) {
            case 'gemini':
                return this.withGemini((key) =>
                    this._geminiToolCall(key, systemPrompt, history, tools)
                );
            case 'openai':
                return this._openaiToolCall(systemPrompt, history, tools);
            default:
                throw new Error(`Unsupported provider for tool calling: ${this.config.provider}`);
        }
    }

    private async _geminiToolCall(
        apiKey: string,
        systemPrompt: string,
        history: ConversationTurn[],
        tools: ToolSchema[]
    ): Promise<ToolCallingResult> {
        const genAI = new GoogleGenerativeAI(apiKey);

        // Convert our ToolSchema[] to Gemini function declarations
        const functionDeclarations = tools.map((t) => ({
            name: t.name,
            description: t.description,
            parameters: t.parameters as any,
        }));

        // When no tools are offered (e.g. the loop-exhaustion summary call), Gemini
        // rejects a request that still carries a functionCalling toolConfig with
        // "Function calling config is set without function_declarations". Only attach
        // tools/toolConfig when there is at least one declaration.
        const hasTools = functionDeclarations.length > 0;

        const model = genAI.getGenerativeModel({
            model: this.config.model!,
            systemInstruction: systemPrompt,
            ...(hasTools && {
                tools: [{ functionDeclarations }],
                toolConfig: {
                    functionCallingConfig: { mode: FunctionCallingMode.AUTO },
                },
            }),
            generationConfig: { temperature: 0.2 },
        });

        // Build Gemini contents array from our history
        const contents: any[] = [];
        for (const turn of history) {
            if (turn.role === 'user') {
                contents.push({ role: 'user', parts: [{ text: turn.content }] });
            } else if (turn.role === 'assistant') {
                contents.push({ role: 'model', parts: [{ text: turn.content }] });
            } else if (turn.role === 'tool_calls') {
                // Replay raw Gemini parts (including thought_signature) if available,
                // otherwise fall back to reconstructed functionCall parts.
                const parts = turn._geminiParts ?? turn.calls.map((c) => ({
                    functionCall: { name: c.name, args: c.args },
                }));
                contents.push({ role: 'model', parts });
            } else if (turn.role === 'tool_results') {
                // Tool results — add as user turn with functionResponse parts
                contents.push({
                    role: 'user',
                    parts: turn.results.map((r) => ({
                        functionResponse: {
                            name: r.name,
                            response: { result: r.result },
                        },
                    })),
                });
            }
        }

        const result = await model.generateContent({ contents });
        const response = result.response;

        // Check for function calls in the response
        const calls = response.functionCalls();
        if (calls && calls.length > 0) {
            // Preserve the raw response parts (which include thought_signature)
            // so they can be replayed verbatim in subsequent turns.
            const rawParts = response.candidates?.[0]?.content?.parts ?? [];
            return {
                type: 'tool_calls',
                calls: calls.map((c, i) => ({
                    id: `gemini-${i}-${c.name}`,
                    name: c.name,
                    args: (c.args ?? {}) as Record<string, unknown>,
                })),
                _geminiParts: rawParts,
            };
        }

        return { type: 'text', content: response.text() };
    }

    private async _openaiToolCall(
        systemPrompt: string,
        history: ConversationTurn[],
        tools: ToolSchema[]
    ): Promise<ToolCallingResult> {
        const openai = new OpenAI({ apiKey: this.config.apiKey });

        // Build OpenAI messages array
        const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
            { role: 'system', content: systemPrompt },
        ];

        for (const turn of history) {
            if (turn.role === 'user') {
                messages.push({ role: 'user', content: turn.content });
            } else if (turn.role === 'assistant') {
                messages.push({ role: 'assistant', content: turn.content });
            } else if (turn.role === 'tool_calls') {
                messages.push({
                    role: 'assistant',
                    content: null,
                    tool_calls: turn.calls.map((c) => ({
                        id: c.id,
                        type: 'function' as const,
                        function: { name: c.name, arguments: JSON.stringify(c.args) },
                    })),
                });
            } else if (turn.role === 'tool_results') {
                for (const r of turn.results) {
                    messages.push({
                        role: 'tool',
                        tool_call_id: r.id,
                        content: JSON.stringify(r.result),
                    });
                }
            }
        }

        const openaiTools: OpenAI.Chat.ChatCompletionTool[] = tools.map((t) => ({
            type: 'function' as const,
            function: {
                name: t.name,
                description: t.description,
                parameters: t.parameters as Record<string, unknown>,
            },
        }));

        const response = await openai.chat.completions.create({
            model: this.config.model!,
            messages,
            tools: openaiTools,
            tool_choice: 'auto',
            temperature: 0.2,
        });

        const choice = response.choices[0];
        if (choice.message.tool_calls && choice.message.tool_calls.length > 0) {
            return {
                type: 'tool_calls',
                calls: choice.message.tool_calls.map((tc) => ({
                    id: tc.id,
                    name: tc.function.name,
                    args: JSON.parse(tc.function.arguments || '{}') as Record<string, unknown>,
                })),
            };
        }

        return { type: 'text', content: choice.message.content || '' };
    }

    // ─── End native tool calling ──────────────────────────────────────────────

    async transcribeAudio(base64Audio: string): Promise<string> {
        if (this.config.provider === 'gemini') {
            return this.withGemini(async (apiKey) => {
                const genAI = new GoogleGenerativeAI(apiKey);
                const model = genAI.getGenerativeModel({
                    model: 'gemini-3.1-flash-lite',
                    generationConfig: { temperature: 0 },
                });

                const base64Data = base64Audio.split(',')[1] || base64Audio;
                const mimeType = base64Audio.match(/^data:([^;]+);base64,/)?.[1] || 'audio/webm';

                const result = await model.generateContent([
                    "You are a speech-to-text transcriber. Transcribe ONLY the words actually spoken in this audio recording.\n" +
                    "Do NOT invent, guess, summarize, or add any content that is not clearly spoken.\n" +
                    "If the audio contains no discernible speech (silence, background noise, music, or unintelligible sounds), " +
                    "respond with exactly the token NO_SPEECH and nothing else.\n" +
                    "Return ONLY the transcript text (or NO_SPEECH).",
                    {
                        inlineData: {
                            data: base64Data,
                            mimeType
                        }
                    }
                ]);

                const response = await result.response;
                const text = response.text().trim();

                // The model returns NO_SPEECH when no speech is detected. Treat that
                // (and any near-empty / sentinel-only response) as an empty transcript
                // so callers don't persist hallucinated text for silent recordings.
                if (!text || /^NO_SPEECH\b/i.test(text) || text.replace(/[^a-z0-9]/gi, '') === 'NOSPEECH') {
                    return '';
                }
                return text;
            });
        } else if (this.config.provider === 'openai') {
            // OpenAI Whisper transcription
            throw new Error('OpenAI Whisper transcription not implemented in this version');
        }

        throw new Error('No transcription provider available');
    }

    async analyzeImage<T>(
        base64Image: string,
        prompt: string,
        schema?: string
    ): Promise<T> {
        if (this.config.provider !== 'gemini') {
            throw new Error('Image analysis is currently only implemented for Gemini');
        }

        const text = await this.withGemini(async (apiKey) => {
            const genAI = new GoogleGenerativeAI(apiKey);
            const model = genAI.getGenerativeModel({
                model: this.config.model!,
                generationConfig: { responseMimeType: 'application/json' },
            });

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

    cleanAndParseJSON<T>(text: string): T {
        let clean = text.replace(/```[a-zA-Z]*\n?|\n?```/g, '').trim();

        const firstBrace = clean.indexOf('{');
        const firstBracket = clean.indexOf('[');
        const start = (firstBrace !== -1 && (firstBracket === -1 || firstBrace < firstBracket)) ? firstBrace : firstBracket;

        const lastBrace = clean.lastIndexOf('}');
        const lastBracket = clean.lastIndexOf(']');
        const end = Math.max(lastBrace, lastBracket);

        if (start !== -1 && end !== -1 && end > start) {
            clean = clean.substring(start, end + 1);
        }

        // Remove control characters that break JSON parsing
        clean = clean.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
        // Strip trailing commas
        clean = clean.replace(/,\s*([}\]])/g, '$1');

        const tryParse = (s: string): T => {
            try {
                return JSON.parse(s);
            } catch {
                // Fix unquoted keys
                const fixed = s.replace(/([{,]\s*)([a-zA-Z0-9_]+)\s*:/g, '$1"$2":');
                return JSON.parse(fixed);
            }
        };

        try {
            return tryParse(clean);
        } catch (e) {
            // Last resort: truncate to last complete top-level object by finding
            // the last closing brace preceded by valid content
            const lastClose = clean.lastIndexOf('}');
            if (lastClose > 0) {
                try {
                    return tryParse(clean.substring(0, lastClose + 1));
                } catch {}
            }
            throw e;
        }
    }
}

// Export singleton instance
export const litellm = new LiteLLMService();
