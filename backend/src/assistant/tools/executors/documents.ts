import { z } from 'zod';
import { supabase as supabaseAdmin } from '../../../config/supabase';
import { litellm } from '../../../services/litellm-service';
import { assertOwnsAttachment } from '../resolvers';
import { decodeAndValidateImage } from '../../../utils/imageValidation';

const CARD_BUCKET = 'contact-cards';

export async function execParseDocument(args: Record<string, unknown>, userId: string) {
  const a = z.object({
    attachment_id: z.string().uuid(),
    query: z.string().trim().max(2000).optional(),
  }).parse(args);

  const att = await assertOwnsAttachment(a.attachment_id, userId);

  if (att.extraction_status === 'failed') {
    throw new Error('That document could not be read (it may be image-only, corrupt, or an unsupported type). Ask the user to re-upload it, or as an image if it was a scan.');
  }
  if (att.extraction_status === 'pending' || att.extraction_status === 'skipped') {
    throw new Error('That attachment has no readable text yet. If it was just uploaded, ask the user to try again in a moment.');
  }

  if (att.extraction_status === 'inline') {
    return {
      attachment_id: att.id,
      mode: 'full',
      token_estimate: att.token_estimate,
      content: att.extracted_text ?? '',
    };
  }

  // chunked (oversized) — RAG retrieval. A query is required to rank chunks.
  const query = a.query?.trim();
  if (!query) {
    throw new Error('This document is large. Provide a "query" describing what to look for (e.g. a topic, industry, or hall) so the relevant sections can be retrieved.');
  }
  const [queryEmbedding] = await litellm.embed([query]);
  const { data: matches, error } = await supabaseAdmin.rpc('match_document_chunks', {
    p_attachment_id: att.id,
    p_user_id: userId,
    p_query_embedding: queryEmbedding as unknown as number[],
    p_match_count: 8,
  });
  if (error) throw new Error(error.message);

  const passages = (matches ?? []).map((m: any) => m.content);
  return {
    attachment_id: att.id,
    mode: 'retrieved',
    query,
    match_count: passages.length,
    content: passages.join('\n\n---\n\n'),
  };
}

// Copy a chat attachment (a business-card image the user uploaded) into the
// private contact-cards bucket and create a card_scan capture row so the image
// is viewable via "View card" on the contact. Ownership of the attachment is
// re-verified (attachment -> message -> user_id) before any copy. Throws on a
// real failure (caller treats it as best-effort and only logs).
export async function saveAttachmentAsCard(
  attachmentId: string,
  contactId: string,
  eventId: string | null,
  userId: string,
): Promise<void> {
  // Re-verify ownership AND fetch the storage location (bucket + path).
  const { data: att, error: attErr } = await supabaseAdmin
    .from('message_attachments')
    .select('id, bucket, path, mime_type, messages!inner(user_id)')
    .eq('id', attachmentId)
    .eq('messages.user_id', userId)
    .maybeSingle();
  if (attErr) throw new Error(attErr.message);
  if (!att) throw new Error('Attachment not found or access denied');

  const mime = (att.mime_type as string | null) ?? '';
  if (!mime.startsWith('image/')) {
    throw new Error('Attachment is not an image — cannot save as a contact card.');
  }

  // Download the original image bytes from its (private) bucket.
  const { data: blob, error: dlErr } = await supabaseAdmin.storage
    .from(att.bucket as string)
    .download(att.path as string);
  if (dlErr || !blob) throw new Error(dlErr?.message ?? 'Could not download attachment');
  const buffer = Buffer.from(await blob.arrayBuffer());

  // Validate by magic bytes (never trust the stored mime), then re-upload to the
  // contact-cards bucket under a server-generated key.
  const { buffer: safeBuffer, type } = decodeAndValidateImage(buffer.toString('base64'));

  // Create the capture row first so its id keys the stored object.
  const { data: capture, error: capErr } = await supabaseAdmin
    .from('captures')
    .insert({
      contact_id: contactId,
      event_id: eventId,
      capture_type: 'card_scan',
      status: 'completed',
      raw_data: { source: 'assistant' },
      user_id: userId,
    })
    .select('id')
    .single();
  if (capErr) throw new Error(capErr.message);

  const cardPath = `${userId}/${capture.id}.${type.ext}`;
  const { error: upErr } = await supabaseAdmin.storage
    .from(CARD_BUCKET)
    .upload(cardPath, safeBuffer, { contentType: type.mime, upsert: true });
  if (upErr) {
    // Roll back the capture so we don't leave a card_scan row with no image.
    await supabaseAdmin.from('captures').delete().eq('id', capture.id);
    throw new Error(upErr.message);
  }

  await supabaseAdmin.from('captures').update({ image_url: cardPath }).eq('id', capture.id);
}
