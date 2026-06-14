import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase';

const router = Router();

router.get('/', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;

    const { data: settings, error } = await supabase
      .from('user_settings')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (error || !settings) {
      return res.json({
        data: {
          user_id: userId,
          ai_provider: 'gemini',
          ai_model: 'gemini-2.0-flash-lite',
          ai_api_key: '',
          enrichment_enabled: true,
          smtp_host: '',
          smtp_port: 587,
          smtp_user: '',
          smtp_password: '',
          email_signature: '',
          push_notifications: true,
          daily_digest: true,
        }
      });
    }

    res.json({ data: settings });
  } catch (error: any) {
    console.error('Settings fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch settings' });
  }
});

router.put('/', async (req: Request, res: Response) => {
  try {
    const body = { ...req.body, user_id: req.user!.id };

    const { data, error } = await supabase
      .from('user_settings')
      .upsert(body, { onConflict: 'user_id' })
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({ data });
  } catch (error: any) {
    console.error('Settings update error:', error);
    res.status(500).json({ error: 'Failed to update settings' });
  }
});

export default router;
