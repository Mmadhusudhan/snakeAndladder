# Snakes & Ladders — backend

Node.js 22+ · Express 5 · Firebase Admin SDK. Validates client-submitted
matches, keeps player stats, maintains the leaderboards, and runs online
rooms: it owns the dice, validates turn ownership, handles invite codes,
matchmaking, idle-turn takeover and forfeits, all through Realtime Database
transactions.

## Run locally

```bash
# Node lives outside PATH on this machine:
export PATH="$HOME/development/node/bin:$PATH"

cd backend
npm install
cp .env.example .env            # then point GOOGLE_APPLICATION_CREDENTIALS at a service-account key
npm run dev                     # http://localhost:3000
npm test                        # unit + API tests (no Firebase needed)
```

Get a service-account key from Firebase console → Project settings →
Service accounts → *Generate new private key*. Keep it out of git
(`serviceAccountKey.json` is ignored).

## Routes

All routes are under `/api`. Protected routes require
`Authorization: Bearer <Firebase ID token>`.

| Method | Route | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | – | Liveness |
| GET | `/leaderboard?period=allTime\|weekly&limit=50` | – | Ranked entries |
| GET | `/me` | ✓ | Profile (created on first call) |
| PATCH | `/me` | ✓ | `{ displayName?, avatar? }` |
| POST | `/matches` | ✓ | Submit a finished match (validated, idempotent by `id`) |
| GET | `/history?limit=50` | ✓ | My finished games |
| POST | `/rooms` | ✓ | Create private room `{maxPlayers, rules?}` → code |
| GET | `/rooms/current` | ✓ | Room the user is seated in |
| GET | `/rooms/:id` | ✓ | Snapshot (members only) |
| POST | `/rooms/:code/join` | ✓ | Join by invite code |
| POST | `/rooms/:id/start` | ✓ | Host starts (≥2 players) |
| POST | `/rooms/:id/roll` | ✓ | Server rolls for the current seat |
| POST | `/rooms/:id/leave` | ✓ | Leave or forfeit |
| POST | `/matchmaking/join` | ✓ | `{maxPlayers}` → queued / matched / in_room |
| DELETE | `/matchmaking/join` | ✓ | Leave the queue |

Rate limit: 120 requests / minute / IP. JSON bodies up to 64 KB.

## Data written

```
users/{uid}                               profile + stats (client may also write its own)
game_history/{uid}/games/{matchId}        one record per match
leaderboards/allTime/entries/{uid}        backend only
leaderboards/week-YYYY-MM-DD/entries/{uid} backend only (Monday-based weeks)
```

Stats rules are in `src/services/stats.service.js` and mirrored in the
Flutter app (`lib/data/models/user_profile.dart`); game rules are in
`src/services/rules.service.js` and mirrored in
`lib/features/game/engine/game_rules.dart`. Change both sides together.

Realtime Database layout and the turn flow are described in the root README
(section 5). Tests run against in-memory fakes of Firestore and RTDB
(`test/fakeFirestore.js`, `test/fakeRtdb.js`).

## Deploy

Cloud Run is the natural fit:

```bash
gcloud run deploy snakes-ladders-api --source . --region asia-south1 \
  --set-env-vars FIREBASE_PROJECT_ID=car-game-e403f,CORS_ORIGINS=https://car-game-e403f.web.app
```

Then build the Flutter app with `--dart-define=API_BASE_URL=https://<cloud-run-url>`.
