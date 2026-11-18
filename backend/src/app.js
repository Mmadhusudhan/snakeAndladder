// Builds the Express app. Dependencies are injected so tests can use an
// in-memory Firestore and a fake token verifier.
import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';

import { requireAuth } from './middleware/auth.js';
import { errorHandler } from './middleware/errorHandler.js';
import { notFound } from './middleware/notFound.js';
import { createRoutes } from './routes/index.js';
import { createMatchService } from './services/match.service.js';
import { createRoomsService } from './services/rooms.service.js';

export function createApp({ db, rtdb, verifyIdToken, now, rng, corsOrigins, rateLimitMax = 120 }) {
  const app = express();
  app.set('trust proxy', 1);
  app.disable('x-powered-by');

  const origins = corsOrigins ?? (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
  app.use(cors({ origin: origins.length ? origins : true }));
  app.use(express.json({ limit: '64kb' }));
  app.use(rateLimit({ windowMs: 60_000, limit: rateLimitMax, standardHeaders: 'draft-8', legacyHeaders: false }));

  const service = createMatchService({ db, now });
  const rooms = rtdb ? createRoomsService({ rtdb, db, now, rng, matchService: service }) : null;
  app.use('/api', createRoutes({ service, rooms, requireAuth: requireAuth(verifyIdToken) }));

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
