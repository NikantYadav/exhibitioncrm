import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger, logInfo } from './middleware/logger';
import routes from './routes';
import { AI_PROVIDER } from './config/ai';
import { supabase } from './config/supabase';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

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
