import { Router } from 'express';
import { supabase } from '../config/supabase';
import { EnrichmentService } from '../services/enrichment-service';

const router = Router();

router.post('/', async (req, res, next) => {
  try {
    const { contactId, contactData } = req.body;

    if (!contactId && !contactData) {
      return res.status(400).json({ error: 'Contact ID or contact data required' });
    }

    // If contactId provided, fetch contact data
    let dataToEnrich = contactData;
    if (contactId) {
      const { data: contact, error } = await supabase
        .from('contacts')
        .select('*, company:companies(*)')
        .eq('id', contactId)
        .single();

      if (error || !contact) {
        return res.status(404).json({ error: 'Contact not found' });
      }

      dataToEnrich = {
        name: `${contact.first_name} ${contact.last_name || ''}`.trim(),
        company: contact.company?.name,
        email: contact.email,
        job_title: contact.job_title
      };
    }

    // Run enrichment
    const enrichmentResult = await EnrichmentService.enrichContact(dataToEnrich);

    // If contactId provided, update the contact
    if (contactId) {
      await supabase
        .from('contacts')
        .update({
          enrichment_status: 'completed',
          enrichment_suggestions: enrichmentResult,
          enrichment_confidence: enrichmentResult.confidence,
          last_enriched_at: new Date().toISOString()
        })
        .eq('id', contactId);
    }

    res.json({
      success: true,
      enrichment: enrichmentResult
    });
  } catch (error) {
    console.error('Enrichment API error:', error);
    res.status(500).json({ error: 'Failed to enrich contact' });
  }
});

// POST /api/enrich/batch
router.post('/batch', async (req, res, next) => {
  try {
    const { contactIds } = req.body;

    if (!contactIds || !Array.isArray(contactIds)) {
      return res.status(400).json({ error: 'Contact IDs array required' });
    }

    const results = [];
    const errors = [];

    for (const contactId of contactIds) {
      try {
        const { data: contact } = await supabase
          .from('contacts')
          .select('*, company:companies(*)')
          .eq('id', contactId)
          .single();

        if (contact) {
          const enrichmentResult = await EnrichmentService.enrichContact({
            name: `${contact.first_name} ${contact.last_name || ''}`.trim(),
            company: contact.company?.name,
            email: contact.email,
            job_title: contact.job_title
          });

          await supabase
            .from('contacts')
            .update({
              enrichment_status: 'completed',
              enrichment_suggestions: enrichmentResult,
              last_enriched_at: new Date().toISOString()
            })
            .eq('id', contactId);

          results.push({ contactId, success: true });
        }
      } catch (error) {
        errors.push({ contactId, error: 'Enrichment failed' });
      }
    }

    res.json({
      success: true,
      results,
      errors,
      total: contactIds.length,
      enriched: results.length
    });
  } catch (error) {
    console.error('Batch enrichment error:', error);
    res.status(500).json({ error: 'Failed to enrich contacts' });
  }
});

export default router;
