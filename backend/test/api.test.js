import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { createApp } from '../src/app.js';
import { FakeFirestore } from './fakeFirestore.js';

let server;
let base;
let db;

const tokens = {
  'token-ann': { uid: 'ann', name: 'Ann Example', firebase: { sign_in_provider: 'google.com' } },
  'token-guest': { uid: 'g1234', firebase: { sign_in_provider: 'anonymous' } },
};

before(async () => {
  db = new FakeFirestore();
  const app = createApp({
    db,
    verifyIdToken: async (t) => {
      if (!tokens[t]) throw new Error('bad token');
      return tokens[t];
    },
    now: () => new Date('2026-11-18T10:00:00Z'),
    corsOrigins: [],
  });
  server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}/api`;
});

after(() => server.close());

const api = (path, { method = 'GET', token, body } = {}) =>
  fetch(base + path, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

const match = (id = 'm1', overrides = {}) => ({
  id,
  mode: 'vsComputer',
  players: [
    { name: 'You', avatar: '🦁', colorIndex: 0, isComputer: false, position: 100, rolls: 12, snakes: 1, ladders: 2 },
    { name: 'Mango', avatar: '🐵', colorIndex: 1, isComputer: true, position: 61, rolls: 11, snakes: 2, ladders: 1 },
  ],
  winnerIndex: 0,
  myIndex: 0,
  turns: 23,
  durationMs: 90_000,
  ...overrides,
});

test('health is public', async () => {
  const res = await api('/health');
  assert.equal(res.status, 200);
  assert.equal((await res.json()).ok, true);
});

test('protected routes need a valid token', async () => {
  assert.equal((await api('/me')).status, 401);
  assert.equal((await api('/me', { token: 'nope' })).status, 401);
});

test('GET /me creates the profile on first call', async () => {
  const res = await api('/me', { token: 'token-ann' });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.uid, 'ann');
  assert.equal(body.displayName, 'Ann Example');
  assert.equal(body.stats.games, 0);
  const guest = await (await api('/me', { token: 'token-guest' })).json();
  assert.equal(guest.isGuest, true);
  assert.match(guest.displayName, /^Guest G123$/);
});

test('PATCH /me validates and updates', async () => {
  const bad = await api('/me', { method: 'PATCH', token: 'token-ann', body: { displayName: '   ' } });
  assert.equal(bad.status, 400);
  const ok = await api('/me', { method: 'PATCH', token: 'token-ann', body: { displayName: '  Zara  the Great  ', avatar: '🐸' } });
  assert.equal(ok.status, 200);
  const body = await ok.json();
  assert.equal(body.displayName, 'Zara the Great');
  assert.equal(body.avatar, '🐸');
});

test('POST /matches records history, stats and leaderboard; duplicates are ignored', async () => {
  const res = await api('/matches', { method: 'POST', token: 'token-ann', body: match() });
  assert.equal(res.status, 201);
  const body = await res.json();
  assert.equal(body.recorded, true);
  assert.equal(body.counted, true);
  assert.equal(body.stats.wins, 1);
  assert.equal(body.stats.rating, 1025);

  const dup = await api('/matches', { method: 'POST', token: 'token-ann', body: match() });
  assert.equal(dup.status, 200);
  assert.equal((await dup.json()).duplicate, true);

  const lost = await api('/matches', {
    method: 'POST',
    token: 'token-ann',
    body: match('m2', { winnerIndex: 1, players: [
      { name: 'You', avatar: '🦁', colorIndex: 0, isComputer: false, position: 40, rolls: 10, snakes: 3, ladders: 0 },
      { name: 'Mango', avatar: '🐵', colorIndex: 1, isComputer: true, position: 100, rolls: 10, snakes: 0, ladders: 3 },
    ] }),
  });
  assert.equal(lost.status, 201);
  assert.equal((await lost.json()).stats.losses, 1);

  const me = await (await api('/me', { token: 'token-ann' })).json();
  assert.equal(me.stats.games, 2);
  assert.equal(me.stats.rating, 1015);

  const hist = await (await api('/history', { token: 'token-ann' })).json();
  assert.equal(hist.games.length, 2);

  const lb = await (await api('/leaderboard')).json();
  assert.equal(lb.entries.length, 1);
  assert.equal(lb.entries[0].uid, 'ann');
  assert.equal(lb.entries[0].displayName, 'Zara the Great');
  assert.equal(lb.entries[0].rank, 1);

  const weekly = await (await api('/leaderboard?period=weekly')).json();
  assert.equal(weekly.entries[0].games, 2);
  assert.equal(weekly.entries[0].wins, 1);
});

test('practice matches go to history but not stats', async () => {
  const res = await api('/matches', { method: 'POST', token: 'token-ann', body: match('m3', { mode: 'practice' }) });
  assert.equal(res.status, 201);
  const body = await res.json();
  assert.equal(body.counted, false);
  const me = await (await api('/me', { token: 'token-ann' })).json();
  assert.equal(me.stats.games, 2);
});

test('invalid matches are rejected with details', async () => {
  const res = await api('/matches', { method: 'POST', token: 'token-ann', body: match('m4', { turns: 1 }) });
  assert.equal(res.status, 400);
  assert.match((await res.json()).error, /Too few turns/);
  const malformed = await fetch(base + '/matches', {
    method: 'POST',
    headers: { Authorization: 'Bearer token-ann', 'Content-Type': 'application/json' },
    body: '{not json',
  });
  assert.equal(malformed.status, 400);
});

test('renaming updates leaderboard rows', async () => {
  await api('/me', { method: 'PATCH', token: 'token-ann', body: { displayName: 'Renamed' } });
  const lb = await (await api('/leaderboard')).json();
  assert.equal(lb.entries[0].displayName, 'Renamed');
});

test('unknown routes are 404 JSON', async () => {
  const res = await api('/nope', { token: 'token-ann' });
  assert.equal(res.status, 404);
  assert.match((await res.json()).error, /not found/i);
});
