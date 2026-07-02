// IMPORTANT: instrument.ts initializes Sentry and MUST be imported before any
// other module so the SDK can instrument http/express/etc. at require-time.
// Do not move this below the other imports or convert it to a re-ordered import.
import './instrument';

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger, logInfo } from './middleware/logger';
import routes from './routes';
import { AI_PROVIDER } from './config/ai';
import { supabase } from './config/supabase';
import { initSchemaFlags } from './services/slayer-client';
import { isSentryEnabled } from './config/sentry';
import * as Sentry from '@sentry/node';

// Auto-derive the assistant's ownership / soft-delete table flags from the live
// DB schema. Fire-and-forget at module load so it runs in both the long-lived
// server and the Vercel serverless cold-start; failure is a safe no-op (the
// hardcoded fallback sets stay in effect).
void initSchemaFlags();

const app = express();
// Trust the first proxy hop so req.ip reflects the real client IP behind
// Vercel/Firebase reverse proxies (required for express-rate-limit to key on
// the correct IP rather than the proxy's address).
app.set('trust proxy', 1);
const PORT = process.env.PORT || 3001;

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim()).filter(Boolean)
  : [];

const isProduction = process.env.NODE_ENV === 'production';

// Fail closed in production: an unset/empty allowlist must NOT mean
// "allow every origin". Misconfiguration should deny cross-origin browser
// requests, not silently open CORS to the world with credentials: true.
if (isProduction && allowedOrigins.length === 0) {
  console.warn(
    '[security] ALLOWED_ORIGINS is empty in production — all cross-origin ' +
    'browser requests will be rejected. Set ALLOWED_ORIGINS to your frontend origin(s).'
  );
}

// Security headers
app.use(helmet());

// Middleware
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, Postman in dev)
    if (!origin) return callback(null, true);
    // In non-production with no allowlist configured, allow all (dev convenience).
    // In production, an empty allowlist fails closed (deny).
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    if (!isProduction && allowedOrigins.length === 0) {
      return callback(null, true);
    }
    callback(new Error(`Origin ${origin} not allowed by CORS`));
  },
  credentials: true,
}));
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));

// Request logging middleware
app.use(requestLogger);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api', routes);

// Sentry's Express error handler must run BEFORE our own error handler so it
// can capture the thrown error before we turn it into a JSON response. No-op
// when Sentry is disabled (no DSN configured).
if (isSentryEnabled()) {
  Sentry.setupExpressErrorHandler(app);
}

// Error handling
app.use(errorHandler);

// Export app for Vercel serverless
export default app;

// Start local server when not running in a serverless environment
if (process.env.VERCEL !== '1') {
  app.listen(PORT, async () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`AI Provider: ${AI_PROVIDER}`);

    logInfo('Server is ready to accept requests');

    await initSchemaFlags();

    const { error: schemaError } = await supabase.rpc('pgrst_reload_schema');
    if (schemaError) {
      console.warn('PostgREST schema reload failed:', schemaError.message);
    }
  });
}
