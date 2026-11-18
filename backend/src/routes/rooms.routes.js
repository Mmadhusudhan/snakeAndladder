import { Router } from 'express';

export function createRoomRoutes({ rooms }) {
  const router = Router();

  router.post('/rooms', async (req, res, next) => {
    try {
      const { maxPlayers, rules } = req.body || {};
      res.status(201).json(await rooms.createRoom(req.user.uid, { maxPlayers: maxPlayers ?? 2, rules: rules ?? {} }));
    } catch (e) { next(e); }
  });

  router.get('/rooms/current', async (req, res, next) => {
    try {
      const id = await rooms.currentRoomId(req.user.uid);
      res.json({ roomId: id });
    } catch (e) { next(e); }
  });

  router.post('/rooms/:code/join', async (req, res, next) => {
    try {
      res.json(await rooms.joinByCode(req.user.uid, req.params.code));
    } catch (e) { next(e); }
  });

  router.get('/rooms/:id', async (req, res, next) => {
    try {
      const room = await rooms.getRoom(req.params.id);
      rooms.requireSeat(room, req.user.uid);
      res.json(room);
    } catch (e) { next(e); }
  });

  router.post('/rooms/:id/start', async (req, res, next) => {
    try { res.json(await rooms.startRoom(req.user.uid, req.params.id)); } catch (e) { next(e); }
  });

  router.post('/rooms/:id/roll', async (req, res, next) => {
    try { res.json(await rooms.roll(req.user.uid, req.params.id)); } catch (e) { next(e); }
  });

  router.post('/rooms/:id/leave', async (req, res, next) => {
    try { res.json(await rooms.leaveRoom(req.user.uid, req.params.id)); } catch (e) { next(e); }
  });

  router.post('/matchmaking/join', async (req, res, next) => {
    try { res.json(await rooms.joinQueue(req.user.uid, { maxPlayers: (req.body || {}).maxPlayers ?? 2 })); } catch (e) { next(e); }
  });

  router.delete('/matchmaking/join', async (req, res, next) => {
    try { res.json(await rooms.leaveQueue(req.user.uid)); } catch (e) { next(e); }
  });

  return router;
}
