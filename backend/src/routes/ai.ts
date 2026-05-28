import { Router } from 'express';
import { litellm } from '../services/litellm-service';
import { supabase } from '../config/supabase';

const router = Router();

// POST /api/ai/analyze-card
router.post('/analyze-card', async (req, res, next) => {
  try {
    const image: string | undefined = req.body?.image ?? req.body?.imageData;

    if (!image) {
      return res.status(400).json({ error: 'Image is required' });
    }

    const prompt = `
      You are an expert at extracting professional information from photos. 
      Analyze the attached image (which could be a business card, event badge, or document) and extract the contact information.
      
      Strict Guidelines:
      1. Identify the person's name, company, and job title from the text profile.
      2. For emails, ensure you include the domain (e.g., .com, .net) correctly.
      3. If the image is a badge, the most prominent name is usually the person.
      4. If a field is not present, return null.
      5. Return ONLY a valid JSON object.
    `;

    const schema = `{
      "first_name": "string",
      "last_name": "string",
      "name": "string (full name)",
      "company": "string",
      "email": "string",
      "phone": "string",
      "job_title": "string",
      "website": "string",
      "address": "string"
    }`;

    const result = await litellm.analyzeImage<any>(image, prompt, schema);

    res.json({ data: result });
  } catch (error: any) {
    console.error('AI Analysis Error:', error);
    res.status(500).json({ error: error.message || 'Failed to process capture' });
  }
});

// POST /api/ai/transcribe
router.post('/transcribe', async (req, res, next) => {
  try {
    const { audio_data } = req.body;

    if (!audio_data) {
      return res.status(400).json({ error: 'Audio data is required' });
    }

    const transcript = await litellm.transcribeAudio(audio_data);

    res.json({ transcript });
  } catch (error: any) {
    console.error('Transcription error:', error);
    res.status(500).json({ error: error.message || 'Failed to transcribe audio' });
  }
});

// POST /api/ai/analyze-note
router.post('/analyze-note', async (req, res, next) => {
  try {
    const { noteId, contactId, content } = req.body;

    if (!content || (!noteId && !contactId)) {
      return res.status(400).json({ error: 'Content and either noteId or contactId required' });
    }

    // Get contact current status if contactId provided
    let currentContact = null;
    if (contactId) {
      const { data: contact } = await supabase
        .from('contacts')
        .select('follow_up_status, follow_up_urgency, first_name, last_name')
        .eq('id', contactId)
        .single();
      currentContact = contact;
    }

    // Analyze note content with AI
    const prompt = `
      You are an intelligent CRM assistant analyzing a note about a business contact interaction.
      
      Analyze this note content and determine:
      1. Whether this represents actual contact/communication with the person
      2. What follow-up status should be set based on the interaction
      3. The urgency level of any needed follow-up
      
      Note content: "${content}"
      
      Guidelines:
      - "contacted" = actual conversation, meeting, call, or meaningful exchange happened
      - "needs_followup" = contact made but requires follow-up action (they asked for info, promised to connect, etc.)
      - "not_contacted" = just notes about the person, no actual interaction yet
      - "ignore" = explicitly mentioned not to follow up or not interested
      
      Urgency levels:
      - "high" = time-sensitive, hot lead, requested immediate follow-up
      - "medium" = standard follow-up needed within a week
      - "low" = general follow-up, no rush
      
      Return ONLY valid JSON with no additional text.
    `;

    const schema = `{
      "status": "contacted | needs_followup | not_contacted | ignore",
      "urgency": "high | medium | low",
      "reasoning": "brief explanation of the decision",
      "interaction_detected": boolean,
      "follow_up_needed": boolean
    }`;

    interface AnalysisResult {
      status: 'contacted' | 'needs_followup' | 'not_contacted' | 'ignore';
      urgency: 'high' | 'medium' | 'low';
      reasoning: string;
      interaction_detected: boolean;
      follow_up_needed: boolean;
    }

    const analysis = await litellm.generateCompletion([
      {
        role: 'system',
        content: prompt
      },
      {
        role: 'user',
        content: `Please analyze this and return JSON matching the schema: ${schema}`
      }
    ], { temperature: 0.3 });

    const result = litellm.cleanAndParseJSON<AnalysisResult>(analysis);

    // Update contact status if contactId provided and status should change
    if (contactId && currentContact) {
      const shouldUpdate =
        currentContact.follow_up_status === 'not_contacted' &&
        (result.status === 'contacted' || result.status === 'needs_followup');

      if (shouldUpdate) {
        const updateData: any = {
          follow_up_status: result.status === 'needs_followup' ? 'needs_follow_up' : result.status,
          follow_up_urgency: result.urgency,
          updated_at: new Date().toISOString()
        };

        if (result.status === 'contacted' || result.status === 'needs_followup') {
          updateData.last_contacted_at = new Date().toISOString();
        }

        await supabase
          .from('contacts')
          .update(updateData)
          .eq('id', contactId);
      }
    }

    res.json({
      success: true,
      analysis: result,
      updated: currentContact?.follow_up_status === 'not_contacted' &&
        (result.status === 'contacted' || result.status === 'needs_followup')
    });

  } catch (error: any) {
    console.error('Note analysis error:', error);
    res.status(500).json({ error: error.message || 'Failed to analyze note' });
  }
});

export default router;
