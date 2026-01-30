
import { AIService } from './ai';
import { createClient } from '@/lib/supabase/server';
import { SupabaseClient } from '@supabase/supabase-js';

export interface DocumentChunk {
    id: string;
    content: string;
    similarity: number;
    metadata: any;
}

import { createClient as createSupabaseClient } from '@supabase/supabase-js';

export class EmbeddingsService {
    /**
     * Store document chunks with embeddings
     */
    static async storeChunks(
        assetId: string,
        chunks: string[],
        _supabase?: SupabaseClient
    ) {
        // Use Service Role client to bypass RLS for internal storage task
        const client = createSupabaseClient(
            process.env.NEXT_PUBLIC_SUPABASE_URL!,
            process.env.SUPABASE_SERVICE_ROLE_KEY!
        );

        console.log(`Generating embeddings for ${chunks.length} chunks...`);

        // Process in batches to avoid rate limits
        for (const chunk of chunks) {
            try {
                // Generate embedding
                const embedding = await AIService.generateEmbedding(chunk);

                // Store in DB
                const { error } = await client
                    .from('document_chunks')
                    .insert({
                        asset_id: assetId,
                        content: chunk,
                        embedding: embedding,
                        metadata: { length: chunk.length }
                    });

                if (error) throw error;
            } catch (error) {
                console.error('Error storing chunk:', error);
                // Continue with other chunks
            }
        }

        console.log(`Finished storing embeddings for asset ${assetId}`);
    }

    /**
     * Search for similar documents
     */
    static async searchSimilarDocuments(
        query: string,
        matchThreshold: number = 0.5,
        matchCount: number = 5,
        filter?: any
    ): Promise<DocumentChunk[]> {
        const supabase = createClient();

        try {
            // Generate query embedding
            const queryEmbedding = await AIService.generateEmbedding(query);

            // Call RPC function
            const { data: chunks, error } = await supabase.rpc('match_documents', {
                query_embedding: queryEmbedding,
                match_threshold: matchThreshold,
                match_count: matchCount
            });

            if (error) throw error;

            return chunks || [];
        } catch (error) {
            console.error('Vector search error:', error);
            return [];
        }
    }

    /**
     * Delete chunks for an asset
     */
    static async deleteAssetChunks(assetId: string) {
        const supabase = createClient();
        const { error } = await supabase
            .from('document_chunks')
            .delete()
            .eq('asset_id', assetId);

        if (error) {
            console.error('Error deleting chunks:', error);
        }
    }

    /**
     * Get a general summary of the company based on all assets
     */
    static async getGlobalContext(): Promise<string> {
        // Query for general info
        const chunks = await this.searchSimilarDocuments(
            "general company information, products, services, and value proposition",
            0.3,
            8
        );

        if (chunks.length === 0) return '';

        return `\n\nADDITIONAL COMPANY CONTEXT (from internal documents):\n${chunks.map(c => c.content).join('\n---\n')}`;
    }
}
