import assert from 'node:assert/strict';
import { test } from 'node:test';

import { applyMatch, countsForStats, emptyStats, ratingFor, validateMatch, weekId } from '../src/services/stats.service.js';

const goodMatch = () => ({
  id: 'm1',
  mode: 'vsComputer',
  players: [
    { name: 'You', avatar: '🦁', colorIndex: 0, isComputer: false, position: 100, rolls: 12, snakes: 1, ladders: 2 },
    { name: 'Mango', avatar: '🐵', colorIndex: 1, isComputer: true, position: 61, rolls: 11, snakes: 2, ladders: 1 },
  ],
  winnerIndex: 0,
  myIndex: 0,
  turns: 23,
  durationMs: 90_000,
});

test('applyMatch counts a win', () => {
  const s = applyMatch(emptyStats(), { won: true, turns: 20, snakes: 1, ladders: 3 });
  assert.equal(s.games, 1);
  assert.equal(s.wins, 1);
  assert.equal(s.winStreak, 1);
  assert.equal(s.bestWinTurns, 20);
  assert.equal(s.rating, 1025);
  const s2 = applyMatch(s, { won: false, turns: 30, snakes: 0, ladders: 0 });
  assert.equal(s2.losses, 1);
  assert.equal(s2.winStreak, 0);
  assert.equal(s2.bestWinTurns, 20);
  assert.equal(s2.rating, 1015);
  assert.equal(s2.totalTurns, 50);
});

test('rating never goes below zero', () => {
  assert.equal(ratingFor(0, 500), 0);
});

test('only vsComputer matches with a seat count', () => {
  assert.equal(countsForStats(goodMatch()), true);
  assert.equal(countsForStats({ ...goodMatch(), mode: 'practice' }), false);
  assert.equal(countsForStats({ ...goodMatch(), mode: 'localMultiplayer', myIndex: null }), false);
});

test('validateMatch accepts a sane match', () => {
  assert.deepEqual(validateMatch(goodMatch()), []);
});

test('validateMatch rejects nonsense', () => {
  assert.ok(validateMatch({ ...goodMatch(), winnerIndex: 1 }).some((s) => s.includes('cell 100')));
  assert.ok(validateMatch({ ...goodMatch(), turns: 2 }).some((s) => s.includes('Too few')));
  assert.ok(validateMatch({ ...goodMatch(), mode: 'online' }).some((s) => s.includes('mode')));
  assert.ok(validateMatch({ ...goodMatch(), myIndex: 1 }).some((s) => s.includes('human')));
  assert.ok(validateMatch({ ...goodMatch(), players: [] }).length > 0);
  const tooManyRolls = goodMatch();
  tooManyRolls.players[0].rolls = 500;
  assert.ok(validateMatch(tooManyRolls).some((s) => s.includes('More rolls')));
  const twoWinners = goodMatch();
  twoWinners.players[1].position = 100;
  assert.ok(validateMatch(twoWinners).some((s) => s.includes('Exactly one')));
  assert.ok(validateMatch(null).length === 1);
});

test('weekId is the Monday of the week', () => {
  assert.equal(weekId(new Date('2026-11-18T10:00:00Z')), '2026-11-16'); // Wednesday -> Monday
  assert.equal(weekId(new Date('2026-11-16T00:00:00Z')), '2026-11-16');
  assert.equal(weekId(new Date('2026-11-22T23:59:59Z')), '2026-11-16'); // Sunday
});
