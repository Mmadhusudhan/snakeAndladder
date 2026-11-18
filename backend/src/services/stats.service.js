// Pure rules shared with the Flutter client (lib/data/models/user_profile.dart).
// Keep both in sync.

export const BASE_RATING = 1000;
export const WIN_POINTS = 25;
export const LOSS_POINTS = 10;

export const MODES = ['vsComputer', 'localMultiplayer', 'practice'];

export function emptyStats() {
  return {
    games: 0, wins: 0, losses: 0, winStreak: 0, bestWinTurns: null,
    totalTurns: 0, snakes: 0, ladders: 0, rating: BASE_RATING,
  };
}

export function ratingFor(wins, losses) {
  return Math.max(0, BASE_RATING + wins * WIN_POINTS - losses * LOSS_POINTS);
}

export function applyMatch(stats, { won, turns, snakes, ladders }) {
  const s = { ...emptyStats(), ...(stats || {}) };
  const wins = s.wins + (won ? 1 : 0);
  const losses = s.losses + (won ? 0 : 1);
  return {
    games: s.games + 1,
    wins,
    losses,
    winStreak: won ? s.winStreak + 1 : 0,
    bestWinTurns: won ? (s.bestWinTurns == null ? turns : Math.min(s.bestWinTurns, turns)) : s.bestWinTurns,
    totalTurns: s.totalTurns + turns,
    snakes: s.snakes + snakes,
    ladders: s.ladders + ladders,
    rating: ratingFor(wins, losses),
  };
}

// Only matches against the computer feed wins/losses/rating.
export function countsForStats(match) {
  return match.mode === 'vsComputer' && Number.isInteger(match.myIndex);
}

const isInt = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;

// Sanity-checks a client-submitted local match. Returns a list of problems
// (empty = acceptable). Local games cannot be proven, but obvious nonsense
// (two winners, 3-turn wins, 500 snakes) is rejected.
export function validateMatch(m) {
  const issues = [];
  if (!m || typeof m !== 'object') return ['Body must be an object'];
  if (typeof m.id !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(m.id)) issues.push('Invalid id');
  if (!MODES.includes(m.mode)) issues.push('Invalid mode');
  if (!Array.isArray(m.players) || m.players.length < 2 || m.players.length > 4) {
    issues.push('players must have 2-4 entries');
    return issues;
  }
  m.players.forEach((p, i) => {
    if (!p || typeof p !== 'object') return issues.push(`players[${i}] invalid`);
    if (typeof p.name !== 'string' || p.name.length === 0 || p.name.length > 24) issues.push(`players[${i}].name invalid`);
    if (!isInt(p.position, 0, 100)) issues.push(`players[${i}].position out of range`);
    if (!isInt(p.rolls, 0, 10000)) issues.push(`players[${i}].rolls out of range`);
    if (!isInt(p.snakes, 0, 10000) || !isInt(p.ladders, 0, 10000)) issues.push(`players[${i}] counters out of range`);
    if (typeof p.isComputer !== 'boolean') issues.push(`players[${i}].isComputer must be boolean`);
  });
  if (!isInt(m.winnerIndex, 0, m.players.length - 1)) {
    issues.push('winnerIndex out of range');
  } else {
    if (m.players[m.winnerIndex].position !== 100) issues.push('Winner must be on cell 100');
    const finished = m.players.filter((p) => p.position === 100).length;
    if (finished !== 1) issues.push('Exactly one player may be on cell 100');
  }
  if (m.myIndex != null && !isInt(m.myIndex, 0, m.players.length - 1)) issues.push('myIndex out of range');
  if (m.myIndex != null && m.players[m.myIndex]?.isComputer) issues.push('myIndex must be a human seat');
  if (!isInt(m.turns, 1, 100000)) issues.push('turns out of range');
  if (!isInt(m.durationMs, 0, 24 * 3600 * 1000)) issues.push('durationMs out of range');
  // Reaching 100 from 0 needs at least 3 dice rolls on the classic board
  // (1->38 ladder, then 80->100), so the whole match has at least 3 turns.
  if (Number.isInteger(m.turns) && m.turns < 3) issues.push('Too few turns for a finished game');
  if (Number.isInteger(m.turns) && m.players.every((p) => Number.isInteger(p.rolls))) {
    const rolls = m.players.reduce((a, p) => a + p.rolls, 0);
    if (rolls > m.turns + 1) issues.push('More rolls than turns');
  }
  if (m.mode === 'vsComputer' && !m.players.some((p) => p.isComputer)) issues.push('vsComputer needs a computer player');
  return issues;
}

// Monday 00:00 UTC of the week containing `date`, as YYYY-MM-DD.
export function weekId(date = new Date()) {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = (d.getUTCDay() + 6) % 7; // Monday = 0
  d.setUTCDate(d.getUTCDate() - day);
  return d.toISOString().slice(0, 10);
}
