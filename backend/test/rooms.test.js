import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { createApp } from '../src/app.js';
import { TURN_SECONDS } from '../src/services/rooms.service.js';
import { FakeFirestore } from './fakeFirestore.js';
import { FakeRtdb } from './fakeRtdb.js';

let server;
let base;
let db;
let rtdb;
let clock = new Date('2026-11-18T10:00:00Z').getTime();
let rolls = [];

const tokens = {
  ann: { uid: 'ann', name: 'Ann', firebase: { sign_in_provider: 'google.com' } },
  ben: { uid: 'ben', name: 'Ben', firebase: { sign_in_provider: 'google.com' } },
  cat: { uid: 'cat', name: 'Cat', firebase: { sign_in_provider: 'anonymous' } },
};

before(async () => {
  db = new FakeFirestore();
  rtdb = new FakeRtdb();
  const app = createApp({
    db,
    rtdb,
    verifyIdToken: async (t) => {
      if (!tokens[t]) throw new Error('bad token');
      return tokens[t];
    },
    now: () => new Date(clock),
    // Scripted dice: `rng(6)` pops from `rolls`; other ranges stay deterministic.
    rng: (max) => (max === 6 && rolls.length ? rolls.shift() - 1 : 7 % max),
    corsOrigins: [],
  });
  server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}/api`;
  for (const t of Object.keys(tokens)) await api('/me', { token: t });
});

after(() => server.close());

const api = async (path, { method = 'GET', token, body } = {}) => {
  const res = await fetch(base + path, {
    method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json() };
};

test('create room, join by code, start, roll with server dice, finish', async () => {
  const created = await api('/rooms', { method: 'POST', token: 'ann', body: { maxPlayers: 3 } });
  assert.equal(created.status, 201);
  const room = created.body;
  assert.equal(room.meta.status, 'open');
  assert.match(room.meta.code, /^[A-Z0-9]{6}$/);
  assert.equal(room.seats[0].uid, 'ann');

  // Cannot create a second room while in one.
  assert.equal((await api('/rooms', { method: 'POST', token: 'ann', body: {} })).status, 409);

  const joined = await api(`/rooms/${room.meta.code.toLowerCase()}/join`, { method: 'POST', token: 'ben' });
  assert.equal(joined.status, 200);
  assert.equal(joined.body.seats[1].uid, 'ben');
  // Idempotent join.
  assert.equal((await api(`/rooms/${room.meta.code}/join`, { method: 'POST', token: 'ben' })).status, 200);
  assert.equal((await api('/rooms/ZZZZZZ/join', { method: 'POST', token: 'cat' })).status, 404);
  assert.equal((await api('/rooms/bad/join', { method: 'POST', token: 'cat' })).status, 400);

  // Only the host starts.
  assert.equal((await api(`/rooms/${room.id}/start`, { method: 'POST', token: 'ben' })).status, 403);
  // Nobody can roll before the start.
  assert.equal((await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ann' })).status, 409);

  const started = await api(`/rooms/${room.id}/start`, { method: 'POST', token: 'ann' });
  assert.equal(started.status, 200);
  assert.equal(started.body.meta.status, 'playing');
  assert.equal(started.body.state.currentSeat, 0);
  assert.deepEqual(started.body.state.positions, { 0: 0, 1: 0 });
  // Late joiner is refused.
  assert.equal((await api(`/rooms/${room.meta.code}/join`, { method: 'POST', token: 'cat' })).status, 409);
  // Outsider cannot read the room.
  assert.equal((await api(`/rooms/${room.id}`, { token: 'cat' })).status, 403);

  // Ben cannot roll on Ann's turn.
  assert.equal((await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' })).status, 403);

  rolls = [4]; // Ann: 4 -> ladder to 14
  const r1 = await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ann' });
  assert.equal(r1.status, 200);
  assert.equal(r1.body.move.roll, 4);
  assert.equal(r1.body.move.outcome, 'ladder');
  assert.equal(r1.body.move.to, 14);
  assert.equal(r1.body.state.currentSeat, 1);
  assert.equal(r1.body.state.moveCount, 1);

  rolls = [6, 6, 6]; // Ben: 6 (extra), 6 (extra), 6 -> forfeit
  const b1 = await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' });
  assert.equal(b1.body.move.extraTurn, true);
  assert.equal(b1.body.state.currentSeat, 1);
  await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' });
  const b3 = await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' });
  assert.equal(b3.body.move.forfeit, true);
  assert.equal(b3.body.state.positions[1], 12);
  assert.equal(b3.body.state.currentSeat, 0);

  // Ann idles past the deadline: Ben may roll for her.
  assert.equal((await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' })).status, 403);
  clock += (TURN_SECONDS + 1) * 1000;
  rolls = [2];
  const auto = await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' });
  assert.equal(auto.status, 200);
  assert.equal(auto.body.move.auto, true);
  assert.equal(auto.body.move.seat, 0);
  assert.equal(auto.body.state.positions[0], 16 === 16 ? 6 : 16); // 14 + 2 = 16 is a snake head -> 6
  assert.equal(auto.body.move.outcome, 'snake');

  // Snapshot shows moves for replay.
  const snap = await api(`/rooms/${room.id}`, { token: 'ann' });
  assert.equal(Object.keys(snap.body.moves).length, 5);

  // Fast-forward Ben to 97 to finish: patch the fake store directly.
  // (the store clones on every write, so re-read the node before each patch)
  rtdb._get(['rooms', room.id]).state.positions[1] = 97;
  rtdb._get(['rooms', room.id]).state.currentSeat = 1;
  rolls = [4, 3];
  const blocked = await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' });
  assert.equal(blocked.body.move.outcome, 'blocked');
  assert.equal(blocked.body.state.currentSeat, 0);
  rtdb._get(['rooms', room.id]).state.currentSeat = 1;
  const win = await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' });
  assert.equal(win.body.status, 'finished');
  assert.equal(win.body.state.winnerSeat, 1);

  // Durable record + stats for both players.
  const game = await db.collection('games').doc(room.id).get();
  assert.equal(game.exists, true);
  assert.equal(game.data().winnerUid, 'ben');
  const ben = await (await api('/me', { token: 'ben' })).body;
  assert.equal(ben.stats.wins, 1);
  const ann = await (await api('/me', { token: 'ann' })).body;
  assert.equal(ann.stats.losses, 1);
  const lb = (await api('/leaderboard')).body;
  assert.equal(lb.entries[0].uid, 'ben');
  // Players are released from the room.
  assert.equal((await api('/rooms/current', { token: 'ann' })).body.roomId, null);
  assert.equal((await api(`/rooms/${room.id}/roll`, { method: 'POST', token: 'ben' })).status, 409);
});

test('leaving: host transfer while open, forfeit while playing ends a 2-player game', async () => {
  const room = (await api('/rooms', { method: 'POST', token: 'ann', body: { maxPlayers: 2 } })).body;
  await api(`/rooms/${room.meta.code}/join`, { method: 'POST', token: 'ben' });
  const left = await api(`/rooms/${room.id}/leave`, { method: 'POST', token: 'ann' });
  assert.equal(left.body.outcome, 'left');
  const after1 = (await api(`/rooms/${room.id}`, { token: 'ben' })).body;
  assert.equal(after1.meta.hostUid, 'ben');
  assert.equal(Object.keys(after1.seats).length, 1);
  // Ann rejoins, Ben (host) starts.
  await api(`/rooms/${room.meta.code}/join`, { method: 'POST', token: 'ann' });
  assert.equal((await api(`/rooms/${room.id}/start`, { method: 'POST', token: 'ben' })).status, 200);
  const forfeit = await api(`/rooms/${room.id}/leave`, { method: 'POST', token: 'ann' });
  assert.equal(forfeit.body.outcome, 'forfeited');
  assert.equal(forfeit.body.status, 'finished');
  const game = await db.collection('games').doc(room.id).get();
  assert.equal(game.data().endedBy, 'forfeit');
  assert.equal(game.data().winnerUid, 'ben');
  const ben = (await api('/me', { token: 'ben' })).body;
  assert.equal(ben.stats.wins, 2);
});

test('closing an empty open room frees the code', async () => {
  const room = (await api('/rooms', { method: 'POST', token: 'cat', body: {} })).body;
  const left = await api(`/rooms/${room.id}/leave`, { method: 'POST', token: 'cat' });
  assert.equal(left.body.outcome, 'closed');
  assert.equal((await api(`/rooms/${room.meta.code}/join`, { method: 'POST', token: 'ann' })).status, 404);
});

test('quick match pairs two players into a running room', async () => {
  const q1 = await api('/matchmaking/join', { method: 'POST', token: 'ann', body: { maxPlayers: 2 } });
  assert.equal(q1.body.status, 'queued');
  // Re-joining keeps you queued once.
  assert.equal((await api('/matchmaking/join', { method: 'POST', token: 'ann', body: { maxPlayers: 2 } })).body.status, 'queued');
  const q2 = await api('/matchmaking/join', { method: 'POST', token: 'ben', body: { maxPlayers: 2 } });
  assert.equal(q2.body.status, 'matched');
  assert.equal(q2.body.room.meta.status, 'playing');
  assert.equal(q2.body.room.meta.quick, true);
  const seats = Object.values(q2.body.room.seats).map((s) => s.uid).sort();
  assert.deepEqual(seats, ['ann', 'ben']);
  assert.equal((await api('/rooms/current', { token: 'ann' })).body.roomId, q2.body.roomId);
  // While in a room, joining the queue reports the room.
  assert.equal((await api('/matchmaking/join', { method: 'POST', token: 'ann', body: {} })).body.status, 'in_room');
  await api(`/rooms/${q2.body.roomId}/leave`, { method: 'POST', token: 'ann' });
  await api(`/rooms/${q2.body.roomId}/leave`, { method: 'POST', token: 'ben' });
});

test('stale queue entries are ignored and leaving the queue works', async () => {
  await api('/matchmaking/join', { method: 'POST', token: 'cat', body: { maxPlayers: 3 } });
  clock += 3 * 60 * 1000;
  const q = await api('/matchmaking/join', { method: 'POST', token: 'ann', body: { maxPlayers: 3 } });
  assert.equal(q.body.status, 'queued');
  assert.equal((await api('/matchmaking/join', { method: 'DELETE', token: 'ann' })).body.status, 'left');
  assert.equal(rtdb._get(['queue', '3', 'ann']), undefined);
});
