import { HttpError } from '../utils/httpError.js';
import { applyMatch, countsForStats, emptyStats, validateMatch, weekId } from './stats.service.js';

const DISPLAY_NAME_MAX = 16;

export function cleanName(name) {
  if (typeof name !== 'string') return null;
  const trimmed = name.replace(/\s+/g, ' ').trim();
  if (!trimmed) return null;
  return trimmed.slice(0, DISPLAY_NAME_MAX);
}

// Firestore-backed operations. `db` is a Firestore instance (or the in-memory
// fake used in tests) and `now` is injectable for deterministic tests.
export function createMatchService({ db, now = () => new Date() }) {
  const users = (uid) => db.collection('users').doc(uid);
  const history = (uid, id) => db.collection('game_history').doc(uid).collection('games').doc(id);
  const entry = (period, uid) => db.collection('leaderboards').doc(period).collection('entries').doc(uid);

  async function ensureProfile(user) {
    const ref = users(user.uid);
    const snap = await ref.get();
    const ts = now().toISOString();
    if (snap.exists) {
      await ref.update({ lastSeenAt: ts });
      return { uid: user.uid, ...snap.data() };
    }
    const profile = {
      displayName: cleanName(user.name) || (user.isGuest ? `Guest ${user.uid.slice(0, 4).toUpperCase()}` : 'Player'),
      avatar: '🦁',
      isGuest: !!user.isGuest,
      stats: emptyStats(),
      createdAt: ts,
      lastSeenAt: ts,
    };
    await ref.set(profile);
    return { uid: user.uid, ...profile };
  }

  async function updateProfile(uid, { displayName, avatar }) {
    const data = {};
    const name = cleanName(displayName);
    if (displayName !== undefined) {
      if (!name) throw new HttpError(400, 'displayName must not be empty');
      data.displayName = name;
    }
    if (avatar !== undefined) {
      if (typeof avatar !== 'string' || [...avatar].length > 2) throw new HttpError(400, 'avatar must be a single emoji');
      data.avatar = avatar;
    }
    if (Object.keys(data).length === 0) throw new HttpError(400, 'Nothing to update');
    const ref = users(uid);
    await ref.update(data);
    // Keep leaderboard rows in sync so names/avatars update without a match.
    await Promise.all(['allTime', `week-${weekId(now())}`].map(async (period) => {
      const e = await entry(period, uid).get();
      if (e.exists) await entry(period, uid).update(data);
    }));
    const snap = await ref.get();
    return { uid, ...snap.data() };
  }

  // Records a finished match for `uid`. Idempotent per match id.
  async function submitMatch(uid, match) {
    const issues = validateMatch(match);
    if (issues.length) throw new HttpError(400, issues.join('; '));

    const ts = now();
    const week = `week-${weekId(ts)}`;
    return db.runTransaction(async (tx) => {
      const userRef = users(uid);
      const histRef = history(uid, match.id);
      const [userSnap, histSnap] = await Promise.all([tx.get(userRef), tx.get(histRef)]);
      if (!userSnap.exists) throw new HttpError(404, 'Profile not found; call GET /api/me first');
      if (histSnap.exists) return { recorded: false, duplicate: true, stats: userSnap.data().stats };

      const record = {
        mode: match.mode,
        players: match.players.map((p) => ({
          name: p.name, avatar: p.avatar ?? '🙂', colorIndex: p.colorIndex ?? 0, isComputer: p.isComputer,
          position: p.position, rolls: p.rolls, snakes: p.snakes, ladders: p.ladders,
        })),
        winnerIndex: match.winnerIndex,
        myIndex: match.myIndex ?? null,
        turns: match.turns,
        durationMs: match.durationMs,
        exactRollToWin: match.exactRollToWin !== false,
        endedAt: ts.toISOString(),
        source: 'client',
      };
      tx.set(histRef, record);

      const profile = userSnap.data();
      let stats = profile.stats || emptyStats();
      if (countsForStats(match)) {
        const me = match.players[match.myIndex];
        stats = applyMatch(stats, {
          won: match.winnerIndex === match.myIndex,
          turns: match.turns,
          snakes: me.snakes,
          ladders: me.ladders,
        });
        tx.update(userRef, { stats });
        const row = { displayName: profile.displayName, avatar: profile.avatar, wins: stats.wins, games: stats.games, rating: stats.rating, updatedAt: ts.toISOString() };
        tx.set(entry('allTime', uid), row);
        // Weekly board counts only this week's results.
        const weekSnap = await tx.get(entry(week, uid));
        const prev = weekSnap.exists ? weekSnap.data() : { wins: 0, games: 0, losses: 0 };
        const wWins = prev.wins + (match.winnerIndex === match.myIndex ? 1 : 0);
        const wLosses = (prev.losses || 0) + (match.winnerIndex === match.myIndex ? 0 : 1);
        tx.set(entry(week, uid), {
          displayName: profile.displayName, avatar: profile.avatar,
          wins: wWins, losses: wLosses, games: prev.games + 1,
          rating: 1000 + wWins * 25 - wLosses * 10, updatedAt: ts.toISOString(),
        });
      }
      return { recorded: true, duplicate: false, counted: countsForStats(match), stats };
    });
  }

  async function leaderboard(period, limit) {
    const id = period === 'weekly' ? `week-${weekId(now())}` : 'allTime';
    const q = await db.collection('leaderboards').doc(id).collection('entries')
      .orderBy('rating', 'desc').orderBy('wins', 'desc').limit(limit).get();
    return q.docs.map((d, i) => ({ rank: i + 1, uid: d.id, ...d.data() }));
  }

  async function userHistory(uid, limit) {
    const q = await db.collection('game_history').doc(uid).collection('games')
      .orderBy('endedAt', 'desc').limit(limit).get();
    return q.docs.map((d) => ({ id: d.id, ...d.data() }));
  }

  return { ensureProfile, updateProfile, submitMatch, leaderboard, userHistory };
}
