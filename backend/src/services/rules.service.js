// Pure game rules, mirrored from the Flutter engine
// (lib/features/game/engine/game_rules.dart). Keep both in sync.

export const FINAL_CELL = 100;

export const CLASSIC_BOARD = {
  snakes: { 16: 6, 47: 26, 49: 11, 56: 53, 62: 19, 64: 60, 87: 24, 93: 73, 95: 75, 98: 78 },
  ladders: { 1: 38, 4: 14, 9: 31, 21: 42, 28: 84, 36: 44, 51: 67, 71: 91, 80: 100 },
};

export const DEFAULT_RULES = {
  exactRollToWin: true,
  extraTurnOnSix: true,
  needSixToStart: false,
  maxConsecutiveSixes: 3,
  diceSides: 6,
};

export function normalizeRules(input = {}) {
  const r = { ...DEFAULT_RULES };
  if (typeof input.exactRollToWin === 'boolean') r.exactRollToWin = input.exactRollToWin;
  if (typeof input.extraTurnOnSix === 'boolean') r.extraTurnOnSix = input.extraTurnOnSix;
  if (typeof input.needSixToStart === 'boolean') r.needSixToStart = input.needSixToStart;
  if (Number.isInteger(input.maxConsecutiveSixes) && input.maxConsecutiveSixes >= 0 && input.maxConsecutiveSixes <= 10) {
    r.maxConsecutiveSixes = input.maxConsecutiveSixes;
  }
  return r;
}

// Applies `roll` to a token on `from`. Returns { path, landing, finalPosition, outcome }
// where outcome is normal | blocked | snake | ladder | win.
export function resolveMove(from, roll, rules = DEFAULT_RULES, board = CLASSIC_BOARD) {
  const blocked = { path: [], landing: from, finalPosition: from, outcome: 'blocked' };
  if (from >= FINAL_CELL) return blocked;
  if (rules.needSixToStart && from === 0 && roll !== rules.diceSides) return blocked;
  let landing = from + roll;
  if (landing > FINAL_CELL) {
    if (rules.exactRollToWin) return blocked;
    landing = FINAL_CELL;
  }
  const path = [];
  for (let c = from + 1; c <= landing; c++) path.push(c);
  if (landing === FINAL_CELL) return { path, landing, finalPosition: landing, outcome: 'win' };
  const tail = board.snakes[landing];
  if (tail !== undefined) return { path, landing, finalPosition: tail, outcome: 'snake' };
  const top = board.ladders[landing];
  if (top !== undefined) {
    return { path, landing, finalPosition: top, outcome: top === FINAL_CELL ? 'win' : 'ladder' };
  }
  return { path, landing, finalPosition: landing, outcome: 'normal' };
}

export const grantsExtraTurn = (roll, rules = DEFAULT_RULES) => rules.extraTurnOnSix && roll === rules.diceSides;

export const forfeitsTurn = (consecutiveSixes, rules = DEFAULT_RULES) =>
  rules.maxConsecutiveSixes > 0 && consecutiveSixes >= rules.maxConsecutiveSixes;
