import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger, logInfo } from './middleware/logger';
import routes from './routes';
import { AI_PROVIDER } from './config/ai';
import { supabase } from './config/supabase';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : [];

// Security headers
app.use(helmet());

// Middleware
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, Postman in dev)
    if (!origin) return callback(null, true);
    if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
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

    const { error: schemaError } = await supabase.rpc('pgrst_reload_schema');
    if (schemaError) {
      console.warn('PostgREST schema reload failed:', schemaError.message);
    }
  });
}
