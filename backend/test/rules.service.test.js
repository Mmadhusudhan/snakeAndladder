import assert from 'node:assert/strict';
import { test } from 'node:test';

import { forfeitsTurn, grantsExtraTurn, normalizeRules, resolveMove } from '../src/services/rules.service.js';

test('plain move, snake, ladder, win, overshoot', () => {
  assert.deepEqual(resolveMove(2, 3), { path: [3, 4, 5], landing: 5, finalPosition: 5, outcome: 'normal' });
  assert.equal(resolveMove(10, 6).outcome, 'snake');
  assert.equal(resolveMove(10, 6).finalPosition, 6);
  assert.equal(resolveMove(25, 3).finalPosition, 84);
  assert.equal(resolveMove(77, 3).outcome, 'win');
  assert.equal(resolveMove(97, 3).outcome, 'win');
  assert.equal(resolveMove(97, 4).outcome, 'blocked');
  assert.equal(resolveMove(97, 6, normalizeRules({ exactRollToWin: false })).finalPosition, 100);
  assert.equal(resolveMove(100, 1).outcome, 'blocked');
});

test('need six to start, extra turn, forfeit', () => {
  const strict = normalizeRules({ needSixToStart: true });
  assert.equal(resolveMove(0, 3, strict).outcome, 'blocked');
  assert.equal(resolveMove(0, 6, strict).finalPosition, 6);
  assert.equal(grantsExtraTurn(6), true);
  assert.equal(grantsExtraTurn(6, normalizeRules({ extraTurnOnSix: false })), false);
  assert.equal(forfeitsTurn(3), true);
  assert.equal(forfeitsTurn(2), false);
  assert.equal(forfeitsTurn(9, normalizeRules({ maxConsecutiveSixes: 0 })), false);
});

test('normalizeRules ignores garbage', () => {
  const r = normalizeRules({ exactRollToWin: 'yes', maxConsecutiveSixes: 99, extraTurnOnSix: false });
  assert.equal(r.exactRollToWin, true);
  assert.equal(r.maxConsecutiveSixes, 3);
  assert.equal(r.extraTurnOnSix, false);
});
