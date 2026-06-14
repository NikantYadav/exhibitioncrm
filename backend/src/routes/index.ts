import { Router } from 'express';
import authRouter from './auth';
import contactsRouter from './contacts';
import eventsRouter from './events';
import notesRouter from './notes';
import capturesRouter from './captures';
import companiesRouter from './companies';
import followUpsRouter from './followUps';
import aiRouter from './ai';
import dashboardRouter from './dashboard';
import emailsRouter from './emails';
import settingsRouter from './settings';
import enrichRouter from './enrich';
import documentsRouter from './documents';
import importRouter from './import';
import exportRouter from './export';
import uploadRouter from './upload';
import attachmentsRouter from './attachments';
import conversationsRouter from './conversations';
import assistantRouter from './assistant';
import interactionsRouter from './interactions';

const router = Router();

// Lightweight reachability probe — no auth required.
router.get('/health', (_req, res) => {
  res.json({ ok: true });
});

router.use('/auth', authRouter);
router.use('/contacts', contactsRouter);
router.use('/events', eventsRouter);
router.use('/notes', notesRouter);
router.use('/captures', capturesRouter);
router.use('/companies', companiesRouter);
router.use('/follow-ups', followUpsRouter);
router.use('/ai', aiRouter);
router.use('/dashboard', dashboardRouter);
router.use('/emails', emailsRouter);
router.use('/settings', settingsRouter);
router.use('/enrich', enrichRouter);
router.use('/documents', documentsRouter);
router.use('/import', importRouter);
router.use('/export', exportRouter);
router.use('/upload', uploadRouter);
router.use('/attachments', attachmentsRouter);
router.use('/conversations', conversationsRouter);
router.use('/assistant', assistantRouter);
router.use('/interactions', interactionsRouter);

export default router;
