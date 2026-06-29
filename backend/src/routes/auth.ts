import { Router, Request, Response } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { supabaseAdmin as supabase } from '../config/supabase';
import { supabaseAuth } from '../config/supabaseClients';
import { logInfo, logError, logSuccess, logWarning } from '../middleware/logger';

// IP-keyed rate limiters for brute-forceable auth routes.
// NOTE: uses express's default in-memory store — per-process, not shared.
// On serverless deployments the effective limit is max × number of instances;
// this is acceptable as a first-pass defence (see CYBERSECURITY.md B11).
// Upgrade to a Redis store (rate-limit-redis) for a shared counter if needed.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts, please try again later.' },
});

const signupLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts, please try again later.' },
});

const signupSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(8).max(128),
  name: z.string().trim().min(1).max(100),
});

const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(128),
});

const safeText = (max: number) => z.string().trim().max(max).optional();

const completeProfileSchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  profile_type: z.enum(['individual', 'company']).optional(),
  designation: safeText(150),
  products_services: safeText(1000),
  value_proposition: safeText(1000),
  website: z.string().url().max(500).optional().or(z.literal('')),
  linkedin_url: z.string().url().max(500).optional().or(z.literal('')),
  ai_tone: z.enum(['professional', 'casual', 'formal', 'friendly']).optional(),
  additional_context: safeText(2000),
});

const router = Router();

/**
 * POST /api/auth/signup
 * Register a new user
 */
router.post('/signup', signupLimiter, async (req: Request, res: Response) => {
  try {
    const parsed = signupSchema.safeParse(req.body);
    if (!parsed.success) {
      logWarning('Signup failed: Validation error');
      return res.status(400).json({ error: parsed.error.flatten() });
    }
    const { email, password, name } = parsed.data;

    logInfo('Signup attempt', { email, name });

    // Create user in Supabase Auth
    const { data: authData, error: authError } = await supabaseAuth.auth.signUp({
      email,
      password,
      options: {
        data: {
          name,
        },
      },
    });

    if (authError) {
      logError(new Error(authError.message), 'Supabase Auth Signup');
      return res.status(400).json({ error: authError.message });
    }

    if (!authData.user) {
      logError(new Error('No user returned from signup'), 'Supabase Auth');
      return res.status(400).json({ error: 'Failed to create user' });
    }

    logSuccess('User created in Auth', { userId: authData.user.id, email });

    // Create basic user profile (will be completed in onboarding)
    const { error: profileError } = await supabase
      .from('user_profiles')
      .upsert({
        user_id: authData.user.id,
        name,
        email,
        profile_type: 'individual',
        ai_tone: 'professional',
      }, { onConflict: 'user_id', ignoreDuplicates: false });

    if (profileError) {
      logError(new Error(profileError.message), 'Profile Creation');
      // Don't fail signup if profile creation fails
    } else {
      logSuccess('User profile created', { userId: authData.user.id });
    }

    res.json({
      success: true,
      user: authData.user,
      session: authData.session,
    });
  } catch (error: any) {
    logError(error, 'Signup');
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/auth/complete-profile
 * Complete user profile after onboarding
 */
router.post('/complete-profile', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      logWarning('Complete profile failed: No authorization header');
      return res.status(401).json({ error: 'No authorization header' });
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser(token);

    if (authError || !user) {
      logError(authError || new Error('No user found'), 'Auth Verification');
      return res.status(401).json({ error: 'Invalid session' });
    }

    logInfo('Completing profile', { userId: user.id });

    const bodyParsed = completeProfileSchema.safeParse(req.body);
    if (!bodyParsed.success) {
      return res.status(400).json({ error: bodyParsed.error.flatten() });
    }

    const {
      name,
      profile_type,
      designation,
      products_services,
      value_proposition,
      website,
      linkedin_url,
      ai_tone,
      additional_context,
    } = bodyParsed.data;

    // Update user profile
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .update({
        name,
        profile_type,
        designation,
        products_services,
        value_proposition,
        website,
        linkedin_url,
        ai_tone,
        additional_context,
        onboarding_completed: true,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', user.id)
      .select()
      .single();

    if (profileError) {
      logError(new Error(profileError.message), 'Profile Update');
      return res.status(400).json({ error: profileError.message });
    }

    logSuccess('Profile completed', { 
      userId: user.id, 
      profileType: profile_type,
      hasDesignation: !!designation 
    });

    res.json({
      success: true,
      profile,
    });
  } catch (error: any) {
    logError(error, 'Complete Profile');
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/auth/login
 * Login existing user
 */
router.post('/login', authLimiter, async (req: Request, res: Response) => {
  try {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      logWarning('Login failed: Validation error');
      return res.status(400).json({ error: parsed.error.flatten() });
    }
    const { email, password } = parsed.data;

    logInfo('Login attempt', { email });

    const { data, error } = await supabaseAuth.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      logError(new Error(error.message), 'Login');
      return res.status(401).json({ error: error.message });
    }

    logSuccess('User logged in', { userId: data.user.id, email });

    // Get user profile
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', data.user.id)
      .single();

    if (profile) {
      logInfo('Profile loaded', { 
        userId: data.user.id, 
        profileType: profile.profile_type 
      });
    }

    res.json({
      success: true,
      user: data.user,
      session: data.session,
      profile,
    });
  } catch (error: any) {
    logError(error, 'Login');
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/auth/logout
 * Logout user
 */
router.post('/logout', async (req: Request, res: Response) => {
  try {
    logInfo('Logout attempt');

    const { error } = await supabaseAuth.auth.signOut();

    if (error) {
      logError(new Error(error.message), 'Logout');
      return res.status(400).json({ error: error.message });
    }

    logSuccess('User logged out');

    res.json({ success: true });
  } catch (error: any) {
    logError(error, 'Logout');
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/auth/session
 * Get current session
 */
router.get('/session', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      logWarning('Session check failed: No authorization header');
      return res.status(401).json({ error: 'No authorization header' });
    }

    const token = authHeader.replace('Bearer ', '');
    
    const { data: { user }, error } = await supabaseAuth.auth.getUser(token);

    if (error || !user) {
      logWarning('Session check failed: Invalid token');
      return res.status(401).json({ error: 'Invalid session' });
    }

    logInfo('Session validated', { userId: user.id });

    // Get user profile
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', user.id)
      .single();

    res.json({
      success: true,
      user,
      profile,
    });
  } catch (error: any) {
    logError(error, 'Session Check');
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/auth/refresh
 * Refresh access token
 */
router.post('/refresh', authLimiter, async (req: Request, res: Response) => {
  try {
    const bodyParsed = z.object({ refresh_token: z.string().min(1).max(2048) }).safeParse(req.body);
    if (!bodyParsed.success) {
      logWarning('Refresh failed: No refresh token provided');
      return res.status(400).json({ error: 'Refresh token required' });
    }
    const { refresh_token } = bodyParsed.data;

    logInfo('Token refresh attempt');

    const { data, error } = await supabaseAuth.auth.refreshSession({
      refresh_token,
    });

    if (error) {
      logError(new Error(error.message), 'Token Refresh');
      return res.status(401).json({ error: error.message });
    }

    logSuccess('Token refreshed');

    res.json({
      success: true,
      session: data.session,
    });
  } catch (error: any) {
    logError(error, 'Token Refresh');
    res.status(500).json({ error: error.message });
  }
});

export default router;
