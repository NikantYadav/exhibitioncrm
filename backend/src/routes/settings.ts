import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase';
import { supabaseAuth } from '../config/supabaseClients';

const router = Router();

router.get('/', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: 'No authorization header' });
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser(token);
    if (authError || !user) return res.status(401).json({ error: 'Invalid session' });

    const { data: settings, error } = await supabase
      .from('user_settings')
      .select('*')
      .eq('user_id', user.id)
      .single();

    if (error || !settings) {
      return res.json({
        data: {
          user_id: user.id,
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
          compact_meeting_cards: false,
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
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: 'No authorization header' });
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser(token);
    if (authError || !user) return res.status(401).json({ error: 'Invalid session' });

    const body = { ...req.body, user_id: user.id };

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
