import { AIService } from '../../config/ai';
import { supabase } from '../../config/supabase';

export async function enrichContact(contactId: string) {
  try {
    const { data: contact } = await supabase
      .from('contacts')
      .select('*, company:companies(*)')
      .eq('id', contactId)
      .single();

    if (!contact) {
      throw new Error('Contact not found');
    }

    const prompt = `Research and provide additional information about:
Name: ${contact.first_name} ${contact.last_name || ''}
Company: ${contact.company?.name || 'Unknown'}
Job Title: ${contact.job_title || 'Unknown'}

Provide: LinkedIn profile, bio, company details, industry insights.`;

    const enrichedData = await AIService.generateCompletion([
      { role: 'system', content: 'You are a professional contact enrichment assistant.' },
      { role: 'user', content: prompt }
    ]);

    return {
      success: true,
      data: { enriched_info: enrichedData }
    };
  } catch (error) {
    console.error('Enrichment error:', error);
    throw error;
  }
}
