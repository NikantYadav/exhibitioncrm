import type { NextFunction, Request, Response } from 'express';
import { createSupabaseUserClient, supabaseAuth } from '../config/supabaseClients';

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing Authorization header' });
    }

    const accessToken = authHeader.slice('Bearer '.length).trim();
    if (!accessToken) {
      return res.status(401).json({ error: 'Missing access token' });
    }

    const { data, error } = await supabaseAuth.auth.getUser(accessToken);
    if (error || !data.user) {
      return res.status(401).json({ error: 'Invalid session' });
    }

    req.user = data.user;
    req.accessToken = accessToken;
    // Per-request RLS-enforced client. Routes use this instead of the service_role
    // client so Postgres RLS structurally enforces tenant isolation.
    req.supabase = createSupabaseUserClient(accessToken);
    next();
  } catch (err: any) {
    res.status(500).json({ error: err?.message || 'Auth error' });
  }
}
