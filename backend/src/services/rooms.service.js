import { randomInt } from 'node:crypto';

import { HttpError } from '../utils/httpError.js';
import { forfeitsTurn, grantsExtraTurn, normalizeRules, resolveMove } from './rules.service.js';
import { applyMatch, emptyStats, weekId } from './stats.service.js';

export const TURN_SECONDS = 30;
export const QUEUE_TTL_MS = 2 * 60 * 1000;
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function randomCode(rng = randomInt) {
  let s = '';
  for (let i = 0; i < 6; i++) s += CODE_ALPHABET[rng(CODE_ALPHABET.length)];
  return s;
}

const seatList = (room) =>
  Object.entries(room.seats || {})
    .map(([k, v]) => ({ seat: Number(k), ...v }))
    .sort((a, b) => a.seat - b.seat);

const activeSeats = (room) => seatList(room).filter((s) => !s.forfeited);

function nextActiveSeat(room, from) {
  const seats = seatList(room);
  if (seats.length === 0) return from;
  const maxSeat = Math.max(...seats.map((s) => s.seat));
  for (let i = 1; i <= maxSeat + 1; i++) {
    const cand = (from + i) % (maxSeat + 1);
    const s = seats.find((x) => x.seat === cand);
    if (s && !s.forfeited) return cand;
  }
  return from;
}

// Room orchestration on top of Realtime Database (`rtdb`) with Firestore
// (`db`) for durable records. Everything that changes a room goes through an
// RTDB transaction so concurrent requests cannot corrupt it.
export function createRoomsService({ rtdb, db, now = () => new Date(), rng = randomInt, matchService }) {
  const roomRef = (id) => rtdb.ref(`rooms/${id}`);

  async function profileFor(uid) {
    const snap = await db.collection('users').doc(uid).get();
    const p = snap.exists ? snap.data() : {};
    return { name: p.displayName || 'Player', avatar: p.avatar || '🙂' };
  }

  async function currentRoomId(uid) {
    const snap = await rtdb.ref(`users_rooms/${uid}`).get();
    return snap.exists() ? snap.val() : null;
  }

  async function getRoom(id) {
    const snap = await roomRef(id).get();
    if (!snap.exists()) throw new HttpError(404, 'Room not found');
    return { id, ...snap.val() };
  }

  function requireSeat(room, uid) {
    const s = seatList(room).find((x) => x.uid === uid);
    if (!s) throw new HttpError(403, 'You are not in this room');
    return s;
  }

  async function createRoom(uid, { maxPlayers = 2, rules = {}, quick = false } = {}, extraPlayers = []) {
    if (!Number.isInteger(maxPlayers) || maxPlayers < 2 || maxPlayers > 4) throw new HttpError(400, 'maxPlayers must be 2-4');
    const existing = await currentRoomId(uid);
    if (existing) {
      const snap = await roomRef(existing).get();
      if (snap.exists() && ['open', 'playing'].includes(snap.val().meta.status)) {
        throw new HttpError(409, 'You are already in a room');
      }
    }
    const host = await profileFor(uid);
    const id = `r_${now().getTime().toString(36)}${rng(1 << 30).toString(36)}`;
    let code = randomCode(rng);
    for (let i = 0; i < 5; i++) {
      const taken = await rtdb.ref(`codes/${code}`).get();
      if (!taken.exists()) break;
      code = randomCode(rng);
    }
    const ts = now().toISOString();
    const seats = { 0: { uid, name: host.name, avatar: host.avatar, colorIndex: 0, joinedAt: ts, forfeited: false } };
    extraPlayers.forEach((p, i) => {
      seats[i + 1] = { uid: p.uid, name: p.name, avatar: p.avatar, colorIndex: i + 1, joinedAt: ts, forfeited: false };
    });
    const room = {
      meta: { code, hostUid: uid, status: 'open', maxPlayers, rules: normalizeRules(rules), createdAt: ts, quick },
      seats,
    };
    const updates = { [`rooms/${id}`]: room, [`codes/${code}`]: id };
    for (const s of Object.values(seats)) updates[`users_rooms/${s.uid}`] = id;
    await rtdb.ref().update(updates);
    await db.collection('private_rooms').doc(code).set({ roomId: id, hostUid: uid, status: 'open', maxPlayers, createdAt: ts, quick });
    return { id, ...room };
  }

  async function joinByCode(uid, code) {
    const clean = String(code || '').trim().toUpperCase();
    if (!/^[A-Z0-9]{6}$/.test(clean)) throw new HttpError(400, 'Invite code must be 6 characters');
    const idSnap = await rtdb.ref(`codes/${clean}`).get();
    if (!idSnap.exists()) throw new HttpError(404, 'No room with that code');
    const id = idSnap.val();
    const me = await profileFor(uid);
    const ts = now().toISOString();
    let error;
    const result = await roomRef(id).transaction((room) => {
      if (!room) return room;
      const seats = seatList(room);
      if (seats.some((s) => s.uid === uid)) return room; // already in: idempotent
      if (room.meta.status !== 'open') { error = new HttpError(409, 'Game already started'); return; }
      if (seats.length >= room.meta.maxPlayers) { error = new HttpError(409, 'Room is full'); return; }
      let seat = 0;
      while (seats.some((s) => s.seat === seat)) seat++;
      return {
        ...room,
        seats: { ...room.seats, [seat]: { uid, name: me.name, avatar: me.avatar, colorIndex: seat, joinedAt: ts, forfeited: false } },
      };
    });
    if (error) throw error;
    if (!result.committed || !result.snapshot.exists()) throw new HttpError(404, 'Room not found');
    await rtdb.ref(`users_rooms/${uid}`).set(id);
    return { id, ...result.snapshot.val() };
  }

  function freshState(room) {
    const positions = {};
    for (const s of seatList(room)) positions[s.seat] = 0;
    return {
      currentSeat: seatList(room)[0].seat,
      phase: 'waiting',
      positions,
      lastRoll: null,
      turn: 1,
      consecutiveSixes: 0,
      winnerSeat: null,
      moveCount: 0,
      turnDeadline: now().getTime() + TURN_SECONDS * 1000,
    };
  }

  async function startRoom(uid, id) {
    let error;
    const result = await roomRef(id).transaction((room) => {
      if (!room) return room;
      if (room.meta.hostUid !== uid) { error = new HttpError(403, 'Only the host can start'); return; }
      if (room.meta.status !== 'open') { error = new HttpError(409, 'Game already started'); return; }
      if (seatList(room).length < 2) { error = new HttpError(409, 'Need at least 2 players'); return; }
      // Compact seats to 0..n-1 so colours and turn order are tidy.
      const seats = {};
      seatList(room).forEach((s, i) => { const { seat, ...rest } = s; seats[i] = { ...rest, colorIndex: i }; });
      const started = { ...room, seats, meta: { ...room.meta, status: 'playing', startedAt: now().toISOString() } };
      return { ...started, state: freshState(started) };
    });
    if (error) throw error;
    if (!result.committed || !result.snapshot.exists()) throw new HttpError(404, 'Room not found');
    const room = result.snapshot.val();
    await db.collection('private_rooms').doc(room.meta.code).update({ status: 'playing' });
    return { id, ...room };
  }

  // Rolls for the current seat. A member may roll on behalf of the current
  // player once their turn deadline has passed (anti-AFK).
  async function roll(uid, id) {
    const roll = rng(6) + 1;
    const nowMs = now().getTime();
    let error;
    let move;
    const result = await roomRef(id).transaction((room) => {
      if (!room) return room;
      if (room.meta.status !== 'playing') { error = new HttpError(409, 'Game is not in progress'); return; }
      const mine = seatList(room).find((s) => s.uid === uid);
      if (!mine) { error = new HttpError(403, 'You are not in this room'); return; }
      const st = room.state;
      const current = seatList(room).find((s) => s.seat === st.currentSeat);
      const auto = mine.seat !== st.currentSeat;
      if (auto && nowMs < st.turnDeadline) { error = new HttpError(403, 'Not your turn'); return; }
      const rules = room.meta.rules;
      const seat = st.currentSeat;
      const sixes = roll === rules.diceSides ? st.consecutiveSixes + 1 : 0;
      const positions = { ...st.positions };
      const n = st.moveCount;
      let next = { ...st, lastRoll: roll, moveCount: n + 1, turnDeadline: nowMs + TURN_SECONDS * 1000 };
      let m = { n, seat, roll, from: positions[seat], landing: positions[seat], to: positions[seat], outcome: 'blocked', extraTurn: false, forfeit: false, auto, at: nowMs };
      let status = room.meta.status;
      let winnerSeat = null;
      if (forfeitsTurn(sixes, rules)) {
        m = { ...m, forfeit: true };
        next = { ...next, consecutiveSixes: 0, currentSeat: nextActiveSeat(room, seat), turn: st.turn + 1 };
      } else {
        const res = resolveMove(positions[seat], roll, rules);
        positions[seat] = res.finalPosition;
        m = { ...m, landing: res.landing, to: res.finalPosition, outcome: res.outcome };
        if (res.outcome === 'win') {
          status = 'finished';
          winnerSeat = seat;
          next = { ...next, positions, phase: 'finished', winnerSeat: seat, consecutiveSixes: 0 };
        } else {
          const extra = grantsExtraTurn(roll, rules);
          m = { ...m, extraTurn: extra };
          next = {
            ...next,
            positions,
            consecutiveSixes: extra ? sixes : 0,
            currentSeat: extra ? seat : nextActiveSeat(room, seat),
            turn: st.turn + 1,
          };
        }
      }
      move = { ...m, by: current?.uid ?? null };
      return {
        ...room,
        meta: status === 'finished' ? { ...room.meta, status, finishedAt: new Date(nowMs).toISOString(), winnerSeat } : room.meta,
        state: next,
        moves: { ...(room.moves || {}), [n]: move },
      };
    });
    if (error) throw error;
    if (!result.committed || !result.snapshot.exists()) throw new HttpError(404, 'Room not found');
    const room = result.snapshot.val();
    if (room.meta.status === 'finished') await finishRoom(id, room);
    return { id, move, state: room.state, status: room.meta.status };
  }

  async function leaveRoom(uid, id) {
    let error;
    let outcome = 'left';
    const result = await roomRef(id).transaction((room) => {
      if (!room) return room;
      const seats = seatList(room);
      const mine = seats.find((s) => s.uid === uid);
      if (!mine) return room;
      if (room.meta.status === 'open') {
        const remaining = { ...room.seats };
        delete remaining[mine.seat];
        const left = Object.values(remaining);
        if (left.length === 0) {
          outcome = 'closed';
          return { ...room, seats: {}, meta: { ...room.meta, status: 'closed' } };
        }
        const hostUid = room.meta.hostUid === uid ? seatList({ seats: remaining })[0].uid : room.meta.hostUid;
        return { ...room, seats: remaining, meta: { ...room.meta, hostUid } };
      }
      if (room.meta.status !== 'playing') return room;
      outcome = 'forfeited';
      const updatedSeats = { ...room.seats, [mine.seat]: { ...room.seats[mine.seat], forfeited: true } };
      const updated = { ...room, seats: updatedSeats };
      const active = activeSeats(updated);
      if (active.length <= 1) {
        const winnerSeat = active.length === 1 ? active[0].seat : null;
        return {
          ...updated,
          meta: { ...room.meta, status: 'finished', finishedAt: now().toISOString(), winnerSeat, endedBy: 'forfeit' },
          state: { ...room.state, phase: 'finished', winnerSeat },
        };
      }
      if (room.state.currentSeat === mine.seat) {
        return {
          ...updated,
          state: { ...room.state, currentSeat: nextActiveSeat(updated, mine.seat), consecutiveSixes: 0, turnDeadline: now().getTime() + TURN_SECONDS * 1000 },
        };
      }
      return updated;
    });
    if (error) throw error;
    if (!result.committed || !result.snapshot.exists()) throw new HttpError(404, 'Room not found');
    const room = result.snapshot.val();
    await rtdb.ref(`users_rooms/${uid}`).remove();
    if (room.meta.status === 'closed') {
      await rtdb.ref(`codes/${room.meta.code}`).remove();
      await db.collection('private_rooms').doc(room.meta.code).update({ status: 'closed' });
    } else if (room.meta.status === 'finished') {
      await finishRoom(id, room);
    }
    return { id, outcome, status: room.meta.status };
  }

  // Durable record + stats for every seat; idempotent per room.
  async function finishRoom(id, room) {
    const ref = db.collection('games').doc(id);
    const existing = await ref.get();
    if (existing.exists) return;
    const seats = seatList(room);
    const moves = Object.values(room.moves || {});
    const ts = now();
    const players = seats.map((s) => ({
      uid: s.uid, name: s.name, avatar: s.avatar, colorIndex: s.colorIndex, isComputer: false,
      position: room.state?.positions?.[s.seat] ?? 0,
      rolls: moves.filter((m) => m.seat === s.seat).length,
      snakes: moves.filter((m) => m.seat === s.seat && m.outcome === 'snake').length,
      ladders: moves.filter((m) => m.seat === s.seat && m.outcome === 'ladder').length,
      forfeited: !!s.forfeited,
    }));
    const winnerSeat = room.meta.winnerSeat ?? room.state?.winnerSeat ?? null;
    const record = {
      mode: 'online', roomId: id, code: room.meta.code, players, winnerSeat, winnerUid: winnerSeat == null ? null : seats.find((s) => s.seat === winnerSeat)?.uid ?? null,
      turns: room.state?.turn ?? 0, durationMs: room.meta.startedAt ? ts.getTime() - new Date(room.meta.startedAt).getTime() : 0,
      rules: room.meta.rules, endedBy: room.meta.endedBy || 'win', createdAt: room.meta.createdAt, endedAt: ts.toISOString(), source: 'server',
    };
    await ref.set(record);
    const updates = {};
    for (const s of seats) updates[`users_rooms/${s.uid}`] = null;
    updates[`codes/${room.meta.code}`] = null;
    await rtdb.ref().update(updates);
    await db.collection('private_rooms').doc(room.meta.code).update({ status: 'finished', gameId: id });
    await Promise.all(players.map((p, i) => recordForPlayer(p, i, record, ts)));
  }

  async function recordForPlayer(p, index, record, ts) {
    const userRef = db.collection('users').doc(p.uid);
    const histRef = db.collection('game_history').doc(p.uid).collection('games').doc(record.roomId);
    const week = `week-${weekId(ts)}`;
    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      const profile = userSnap.exists ? userSnap.data() : { displayName: p.name, avatar: p.avatar, isGuest: true, stats: emptyStats() };
      const won = record.winnerSeat === index;
      tx.set(histRef, {
        mode: 'online', players: record.players, winnerIndex: record.winnerSeat ?? 0, myIndex: index,
        turns: record.turns, durationMs: record.durationMs, exactRollToWin: record.rules.exactRollToWin,
        endedAt: record.endedAt, source: 'server',
      });
      // A forfeiting player takes the loss; a winner by forfeit still wins.
      const stats = applyMatch(profile.stats, { won, turns: record.turns, snakes: p.snakes, ladders: p.ladders });
      if (userSnap.exists) tx.update(userRef, { stats }); else tx.set(userRef, { ...profile, stats });
      const row = { displayName: profile.displayName, avatar: profile.avatar, wins: stats.wins, games: stats.games, rating: stats.rating, updatedAt: ts.toISOString() };
      tx.set(db.collection('leaderboards').doc('allTime').collection('entries').doc(p.uid), row);
      const weekRef = db.collection('leaderboards').doc(week).collection('entries').doc(p.uid);
      const weekSnap = await tx.get(weekRef);
      const prev = weekSnap.exists ? weekSnap.data() : { wins: 0, losses: 0, games: 0 };
      const wWins = prev.wins + (won ? 1 : 0);
      const wLosses = (prev.losses || 0) + (won ? 0 : 1);
      tx.set(weekRef, { displayName: profile.displayName, avatar: profile.avatar, wins: wWins, losses: wLosses, games: prev.games + 1, rating: 1000 + wWins * 25 - wLosses * 10, updatedAt: ts.toISOString() });
    });
    if (matchService?.onOnlineResult) await matchService.onOnlineResult(p.uid, record);
  }

  // Random opponent: pair with someone waiting for the same table size, or
  // wait in the queue. Matched players get a room that is already playing.
  async function joinQueue(uid, { maxPlayers = 2 } = {}) {
    if (![2, 3, 4].includes(maxPlayers)) throw new HttpError(400, 'maxPlayers must be 2-4');
    const existing = await currentRoomId(uid);
    if (existing) {
      const snap = await roomRef(existing).get();
      if (snap.exists() && ['open', 'playing'].includes(snap.val().meta.status)) return { status: 'in_room', roomId: existing };
    }
    const me = await profileFor(uid);
    const nowMs = now().getTime();
    let partners = [];
    const result = await rtdb.ref(`queue/${maxPlayers}`).transaction((q) => {
      const queue = { ...(q || {}) };
      delete queue[uid];
      const fresh = Object.entries(queue).filter(([, v]) => nowMs - v.at < QUEUE_TTL_MS).sort((a, b) => a[1].at - b[1].at);
      if (fresh.length >= maxPlayers - 1) {
        partners = fresh.slice(0, maxPlayers - 1).map(([pUid, v]) => ({ uid: pUid, ...v }));
        for (const p of partners) delete queue[p.uid];
        return queue;
      }
      return { ...queue, [uid]: { at: nowMs, name: me.name, avatar: me.avatar } };
    });
    if (!result.committed) throw new HttpError(500, 'Matchmaking failed, try again');
    if (partners.length === 0) return { status: 'queued', maxPlayers };
    const room = await createRoom(uid, { maxPlayers, quick: true }, partners);
    const started = await startRoom(uid, room.id);
    return { status: 'matched', roomId: room.id, room: started };
  }

  async function leaveQueue(uid) {
    const updates = {};
    for (const n of [2, 3, 4]) updates[`queue/${n}/${uid}`] = null;
    await rtdb.ref().update(updates);
    return { status: 'left' };
  }

  return { createRoom, joinByCode, startRoom, roll, leaveRoom, getRoom, requireSeat, joinQueue, leaveQueue, currentRoomId, finishRoom };
}
