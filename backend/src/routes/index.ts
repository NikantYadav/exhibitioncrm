import { Router } from 'express';
import { requireAuth } from '../middleware/requireAuth';
import authRouter from './auth';
import contactsRouter from './contacts';
import eventsRouter from './events';
import capturesRouter from './captures';
import companiesRouter from './companies';
import followUpsRouter from './followUps';
import aiRouter from './ai';
import dashboardRouter from './dashboard';
import emailsRouter from './emails';
import documentsRouter from './documents';
import importRouter from './import';
import exportRouter from './export';
import attachmentsRouter from './attachments';
import conversationsRouter from './conversations';
import assistantRouter from './assistant';
import interactionsRouter from './interactions';
import syncRouter from './sync';

const router = Router();

// Lightweight reachability probe — no auth required.
router.get('/health', (_req, res) => {
  res.json({ ok: true });
});

// Auth routes are public by design.
router.use('/auth', authRouter);

// All remaining routes require a valid session.
router.use(requireAuth);

router.use('/contacts', contactsRouter);
router.use('/events', eventsRouter);
router.use('/captures', capturesRouter);
router.use('/companies', companiesRouter);
router.use('/follow-ups', followUpsRouter);
router.use('/ai', aiRouter);
router.use('/dashboard', dashboardRouter);
router.use('/emails', emailsRouter);
router.use('/documents', documentsRouter);
router.use('/import', importRouter);
router.use('/export', exportRouter);
router.use('/attachments', attachmentsRouter);
router.use('/conversations', conversationsRouter);
router.use('/assistant', assistantRouter);
router.use('/interactions', interactionsRouter);
router.use('/sync', syncRouter);

export default router;
