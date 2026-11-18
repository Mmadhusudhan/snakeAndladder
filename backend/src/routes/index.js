import { Router } from 'express';
import { HttpError } from '../utils/httpError.js';

import { createRoomRoutes } from './rooms.routes.js';

export function createRoutes({ service, rooms, requireAuth }) {
  const router = Router();

  router.get('/health', (req, res) => res.json({ ok: true, service: 'snakes-ladders', time: new Date().toISOString() }));

  // Public
  router.get('/leaderboard', async (req, res, next) => {
    try {
      const period = req.query.period === 'weekly' ? 'weekly' : 'allTime';
      const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 100);
      res.json({ period, entries: await service.leaderboard(period, limit) });
    } catch (e) {
      next(e);
    }
  });

  // Signed in
  router.use(requireAuth);

  router.get('/me', async (req, res, next) => {
    try {
      res.json(await service.ensureProfile(req.user));
    } catch (e) {
      next(e);
    }
  });

  router.patch('/me', async (req, res, next) => {
    try {
      await service.ensureProfile(req.user);
      res.json(await service.updateProfile(req.user.uid, req.body || {}));
    } catch (e) {
      next(e);
    }
  });

  router.post('/matches', async (req, res, next) => {
    try {
      if (!req.body || typeof req.body !== 'object') throw new HttpError(400, 'JSON body required');
      const result = await service.submitMatch(req.user.uid, req.body);
      res.status(result.duplicate ? 200 : 201).json(result);
    } catch (e) {
      next(e);
    }
  });

  if (rooms) router.use(createRoomRoutes({ rooms }));

  router.get('/history', async (req, res, next) => {
    try {
      const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 100);
      res.json({ games: await service.userHistory(req.user.uid, limit) });
    } catch (e) {
      next(e);
    }
  });

  return router;
}
