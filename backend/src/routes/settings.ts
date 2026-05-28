import { Router } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const { data: settings, error } = await supabase
      .from('user_settings')
      .select('*')
      .single();

    if (error || !settings) {
      return res.json({
        data: {
          ai_provider: 'gemini',
          ai_model: 'gemini-3.5-flash',
          ai_api_key: '',
          enrichment_enabled: true,
          smtp_host: '',
          smtp_port: 587,
          smtp_user: '',
          smtp_password: '',
          email_signature: ''
        }
      });
    }

    res.json({ data: settings });
  } catch (error) {
    console.error('Settings fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch settings' });
  }
});

router.put('/', async (req, res, next) => {
  try {
    const body = req.body;

    const { data, error } = await supabase
      .from('user_settings')
      .upsert(body)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ data });
  } catch (error) {
    console.error('Settings update error:', error);
    res.status(500).json({ error: 'Failed to update settings' });
  }
});

export default router;
