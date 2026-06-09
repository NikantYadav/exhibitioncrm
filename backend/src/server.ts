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

app.listen(PORT, async () => {
  console.log('\n' + '='.repeat(60));
  console.log('🚀 Server Started Successfully');
  console.log('='.repeat(60));
  console.log(`📍 Port:        ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🤖 AI Provider: ${AI_PROVIDER}`);
  console.log(`📡 API Base:    http://localhost:${PORT}/api`);
  console.log(`💚 Health:      http://localhost:${PORT}/health`);
  console.log('='.repeat(60) + '\n');

  logInfo('Server is ready to accept requests');

  // Reload PostgREST schema cache so FK-based embeds (e.g. company:companies(*))
  // are always up to date, even if schema changed while the server was down.
  const { error: schemaError } = await supabase.rpc('pgrst_reload_schema');
  if (schemaError) {
    console.warn('⚠️  PostgREST schema reload failed:', schemaError.message);
  } else {
    console.log('🔄 PostgREST schema cache reloaded');
  }
});
