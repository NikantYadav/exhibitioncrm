import { litellm } from '../litellm-service';
import { SupabaseClient } from '@supabase/supabase-js';

// Replace each @-mention directive (`@[type:uuid:Display Name]`) with just its
// display name, so titles/previews read naturally instead of showing raw UUIDs.
const MENTION_DIRECTIVE = /@\[(?:contact|event|company):[0-9a-fA-F-]{36}:([^\]]+)\]/g;
export function stripMentionDirectives(text: string): string {
    return text.replace(MENTION_DIRECTIVE, (_m, name) => String(name).trim()).trim();
}

export async function autoTitleConversation(
    supabase: SupabaseClient,
    conversationId: string,
    firstMessageContentRaw: string
) {
    const firstMessageContent = stripMentionDirectives(firstMessageContentRaw);
    try {
        const { data: conv } = await supabase
            .from('conversations')
            .select('id, title')
            .eq('id', conversationId)
            .single();

        if (conv && !conv.title) {
            const titleText = await litellm.generateCompletion([
                {
                    role: 'system',
                    content: 'You are a titling assistant. Generate a professional and descriptive 3-5 word title for a chat conversation based on the user\'s first message. Avoid generic words like "My", "Chat", or "Conversation". Focus on the core intent or topic. Return ONLY the title text, no quotes or punctuation.'
                },
                {
                    role: 'user',
                    content: firstMessageContent
                }
            ], { temperature: 0.3, maxTokens: 20 });

            if (titleText && titleText.trim()) {
                let clean = titleText.trim().replace(/^"|"$/g, '').slice(0, 50);

                // If the LLM returned something too short, generic, or just one word that might be filler
                const words = clean.split(/\s+/);
                const genericWords = ['my', 'chat', 'conversation', 'the', 'assistant', 'help', 'question'];

                if (words.length < 2) {
                    if (clean.length < 3 || genericWords.includes(clean.toLowerCase())) {
                        // Better fallback: Take first 5 words of message or "Chat about..."
                        const contentWords = firstMessageContent.trim().split(/\s+/);
                        if (contentWords.length > 1) {
                            clean = contentWords.slice(0, 5).join(' ');
                            if (clean.length > 40) clean = clean.substring(0, 40);
                        } else {
                            clean = `Chat about ${clean}`;
                        }
                    }
                }

                await supabase
                    .from('conversations')
                    .update({ title: clean })
                    .eq('id', conversationId);
                return clean;
            }
        }
    } catch (err) {
        console.warn('Auto-titling failed:', err);
    }
    return null;
}
