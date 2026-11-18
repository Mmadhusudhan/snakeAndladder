# Snakes & Ladders 🐍🎲 — Jungle Edition

A premium, fully playable Snakes & Ladders for **Android, iOS and Web**, built with
Flutter + Riverpod + CustomPainter, with a Node.js + Firebase backend for online play.

> Status: **Phase 8 complete (v1.0.0)** — playable game (phases 1–4),
> accounts, stats and leaderboards (5), online multiplayer (6), sound, music,
> settings and onboarding (7), and release tooling: launcher icons, Android
> signing + shrinking, iOS/web naming, CI, privacy policy and deployment
> notes (8). Everything degrades gracefully (offline guest, simulated online
> opponents) until Firebase is configured.

---

## 1. Quick start

```bash
flutter pub get
flutter run -d chrome          # web (offline mode until Firebase is configured, see §5)
flutter run                    # connected phone / emulator
flutter analyze && flutter test
flutter build web --release    # output in build/web
```

Desktop / web controls: **Space** or **Enter** rolls, **Esc** pauses.

---

## 2. Repository layout

```
.
├── lib/
│   ├── main.dart                      entry: ProviderScope + app
│   ├── app.dart                       MaterialApp, themes
│   ├── core/
│   │   ├── services/                  AudioService (+ SilentAudioService), HapticsService
│   │   ├── constants/board_constants.dart
│   │   ├── theme/app_colors.dart      jungle palette, player + snake colours
│   │   ├── theme/app_theme.dart       light / dark themes, background gradient
│   │   └── utils/board_geometry.dart  cell <-> pixel maths (zigzag numbering)
│   ├── features/
│   │   ├── home/                      home, game setup, rules dialog
│   │   ├── game/
│   │   │   ├── models/                Player, BoardConfig, GameRulesConfig, GameState, BotPersonality
│   │   │   ├── engine/                Dice, GameRules (pure), GameEngine (state machine)
│   │   │   ├── board/                 BoardPainter, SnakeRenderer, LadderRenderer, BoardWidget
│   │   │   ├── components/            PlayerToken, DiceWidget (3D cube), RollButton, PlayerPanel, TurnBanner
│   │   │   ├── animations/            DiceCubeMath, AnimatedToken (hop), CellEffect (bursts)
│   │   │   └── screens/               GameScreen, GameResultScreen
│   │   ├── multiplayer/               OnlineLobbyScreen, RoomScreen, OnlineGameScreen
│   │   ├── settings/                  SettingsScreen
│   │   ├── onboarding/                OnboardingScreen
│   │   ├── leaderboard/               (Phase 5)
│   │   └── profile/                   (Phase 5)
│   ├── data/                          models, AuthService, ProfileRepository, RoomService (+ local simulation)
│   └── providers/                     game_providers, app_providers, online_providers (OnlineGameController)
├── assets/audio/                      generated WAVs (see tool/gen_audio.py)
├── tool/gen_audio.py                  synthesises every sound and the music loop
├── test/                              unit + widget tests
└── backend/                           Node.js + Express API (Phase 5–6, Firebase Admin)
```

### Architecture rules

| Layer | Knows about | Never touches |
|---|---|---|
| `engine/` (GameRules, GameEngine) | models only | Flutter, Riverpod, Firebase |
| `providers/` | engine + models | widgets |
| `board/`, `components/`, `screens/` | providers + models | engine internals |
| `data/` | Firebase SDKs, HTTP | widgets |

`GameRules` is pure and stateless. `GameEngine` owns the state machine and
sequences phases with injectable delays, so the same engine runs in tests
instantly and in the UI with animation timings. Online play (Phase 6) reuses
the engine with a server-provided `Dice`.

---

## 3. Game engine

### State machine

```
waiting ──roll──▶ rolling ──▶ moving ──┬──▶ climbingLadder ──┐
                                       ├──▶ slidingSnake ────┤
                                       └─────────────────────┴──▶ switchingTurn ──▶ waiting
                                                              └──▶ completed
```

- Rolls are refused unless the phase is `waiting` and the game is not paused.
  The lock is taken synchronously, so a double tap cannot roll twice.
- Every in-flight turn carries a generation number; `reset()` / `dispose()`
  bump it so stale `await`s stop cleanly.
- Computer players roll automatically after a short "thinking" delay.
- The dice value is decided when the roll starts (`pendingRoll`) so the 3D
  dice can tumble and land on the right face exactly as the roll phase ends;
  players only see it as `lastRoll` afterwards.
- Snake slides and ladder climbs take `base + perCell × distance` (capped),
  so long snakes take longer. The board widget runs its own animation for the
  same duration, so the token arrives exactly when the engine commits the new
  position and emits a `landed` event.

### Sound, music & settings (Phase 7)

All audio is **synthesised** by `tool/gen_audio.py` (dice rattle, step tick,
ladder arpeggio, snake hiss + bite, win fanfare, six chime, blocked thud,
UI click, turn chime, and a 20 s looping jungle groove), so the assets are
original and licence-free. Re-run the script to regenerate `assets/audio/`.

- `AudioService` (`audioplayers`) plays effects from a small player pool and
  loops the music; sound and music are independent toggles. Players are
  created lazily and any platform failure silently disables audio.
- `GameAudioMapper` turns state transitions into sounds (and matching
  haptics): dice on roll start, a tick per cell, hiss on a snake, arpeggio on
  a ladder, chime on a six, thud when blocked, fanfare on a win, and a soft
  chime when the turn passes to a human. The same bridge is used for local
  and online games.
- `AppSettings` (sound, music, vibration, theme mode, onboarding flag) are
  persisted with `shared_preferences`; the music pauses when the app goes to
  the background. On web the music starts on the first tap, as browsers
  require.
- First launch shows a three-page onboarding (replayable from Settings); the
  rules live on their own screen.

### Computer opponents (Phase 4)

Snakes & Ladders is pure luck, so "difficulty" works on the dice and is
shown openly in the setup screen:

| Level | Behaviour | Thinking delay |
|---|---|---|
| Easy | Rolls twice, keeps the *worse* roll half the time | 1.5× |
| Normal | Rolls exactly like a human | 1× |
| Hard | Rolls twice, keeps the better roll (ladders and wins preferred, snakes avoided) | 0.65× |

Bots have personalities (`BotPersonality`: Mango 🐵, Tembo 🐘, Koko 🦜) with
their own remarks that appear on their player card after a snake, ladder,
six, blocked roll or win. Practice mode is you versus one easy bot with the
exact-roll rule off.

Each match tracks `PlayerStats` (rolls, sixes, snakes, ladders, blocked,
cells moved); the result screen ranks players by position then fewer rolls
and offers *Play again*, *Players* (back to setup) and *Home*. A turn banner
slides in whenever the seat changes so pass-and-play groups know whose turn
it is.

### Snake & ladder animation (Phase 3)

- Each snake's spine is a cubic curve sampled into points (`SnakeShape`).
  The body sway is computed from the same samples that the sliding token
  follows (`swayedPointAt`), so the token stays glued to the body. Sway is
  zero at the head and tail so they never leave their cells.
- When a token lands on a snake, the snake lunges forward with a gaping jaw
  and fangs, its eyes narrow, the body thrashes harder, and a swallow bulge
  travels down the body with the token.
- Ladders expose their rung positions; a climbing token moves rung to rung
  with eased hops and alternating lean, while the ladder glows and the active
  rung lights up.

### Rules (all configurable in `GameRulesConfig`)

| Rule | Default |
|---|---|
| Exact roll required to land on 100 | on |
| Six grants another turn | on |
| Three sixes in a row forfeit the turn | on (3) |
| Need a six to leave the start | off |
| Dice sides | 6 |

Board layout lives in `BoardConfig` (classic 10 snakes / 9 ladders) and is
validated: snakes go down, ladders go up, no cell is both, no chaining.

---

## 4. Roadmap

| Phase | Deliverable | Status |
|---|---|---|
| 1 | Project, folder structure, responsive board, rules engine, tests | ✅ done |
| 2 | 3D-style dice, step-by-step token walk with hop/bounce, landing effects | ✅ done |
| 3 | Tokens slide along the snake spine / climb rung by rung; snakes lunge, bite and swallow | ✅ done |
| 4 | Computer personalities & strength, turn banner, colour/avatar choice, result screen with stats | ✅ done |
| 5 | Firebase Auth (Google + guest), Firestore profile/stats/history, leaderboard, backend | ✅ done |
| 6 | Online multiplayer: rooms, invite codes, matchmaking, server-validated turns, forfeits | ✅ done |
| 7 | Sound, music, haptics, settings, onboarding, rules screen, theme choice | ✅ done |
| 8 | Icons, signing, CI, privacy policy, store / hosting release notes | ✅ done |

---

## 5. Firebase setup & database design

Firebase project: `car-game-e403f` (project number `214273362799`).

### Setup status (done on 18 Nov 2026)

| Item | Status |
|---|---|
| Web, Android, iOS apps registered; `lib/firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist` generated | ✅ |
| Cloud Firestore `(default)` database, region `asia-south1` (Mumbai) | ✅ |
| Firestore rules + composite index deployed | ✅ |
| Realtime Database `car-game-e403f-default-rtdb`, region `asia-southeast1` (Singapore) | ✅ |
| Realtime Database rules deployed | ✅ |
| Authentication: Anonymous + Google sign-in | ⏳ console step (below) |
| Backend on Cloud Run + `API_BASE_URL` | ⏳ |

Tooling used (Node lives outside PATH on this Mac):

```bash
export PATH="$HOME/development/node/bin:$HOME/.pub-cache/bin:$PATH"
firebase login                                   # one-time
flutterfire configure --project=car-game-e403f   # re-run after adding platforms
firebase deploy --only firestore,database        # after editing rules
```

**Authentication (console):** open
https://console.firebase.google.com/project/car-game-e403f/authentication,
click *Get started*, then under *Sign-in method* enable **Anonymous** and
**Google** (pick a support e-mail). For Google on Android, add your debug and
release SHA-1 / SHA-256 fingerprints under *Project settings → Your apps →
Android* (`./gradlew signingReport` in `android/` prints them) and re-run
`flutterfire configure`. On web, add your hosting domain to *Authorized
domains*.

Firebase client keys in these files are not secrets (access is governed by
the security rules), so they are committed. The backend's service-account
key is the real secret and stays git-ignored.

### How accounts work

- `AuthService` has two implementations: `FirebaseAuthService` (anonymous
  guests, Google via popup on web / `google_sign_in` on mobile, guest →
  Google account linking) and `LocalAuthService` (offline).
- `ProfileRepository` has `FirestoreProfileRepository` and
  `InMemoryProfileRepository`. Finished games go to the user's history; only
  **vs-computer** games feed wins, losses and rating (pass-and-play is
  history only, practice never counts). The same stat rules live in the
  backend (`stats.service.js`) and the client (`user_profile.dart`).
- When the backend URL is set (`--dart-define=API_BASE_URL=https://…`) the
  client also POSTs each match to `/api/matches`; the server validates it and
  is the only writer of the leaderboards. Without a backend, the leaderboard
  screen shows what it can read (offline: players on this device).

### Firestore

```
users/{uid}
  displayName, photoUrl, isGuest, createdAt, lastSeenAt
  stats: { games, wins, losses, winStreak, bestWinTurns, totalTurns }

games/{gameId}                     # finished matches (written by backend only)
  mode, players[{uid, name, colorIndex}], winnerUid, turns, durationMs,
  rules{...}, boardId, createdAt, endedAt

game_history/{uid}/games/{gameId}  # per-user index of games/{gameId}

leaderboards/{period}/entries/{uid}   # period = allTime | weekly | daily
  displayName, wins, games, rating, updatedAt

private_rooms/{code}
  hostUid, status (open|playing|closed), maxPlayers, createdAt, gameId
```

### Realtime Database (live match state)

```
rooms/{roomId}
  meta:   { code, hostUid, status: open|playing|finished|closed, maxPlayers, rules, quick,
            createdAt, startedAt, finishedAt, winnerSeat, endedBy }
  seats/{seat}: { uid, name, avatar, colorIndex, joinedAt, forfeited }
  state:  { currentSeat, phase, positions{seat: cell}, lastRoll, turn, consecutiveSixes,
            winnerSeat, moveCount, turnDeadline }
  moves/{n}: { n, seat, roll, from, landing, to, outcome, extraTurn, forfeit, auto, at }
  presence/{uid}: true|false            # the only client-writable path
users_rooms/{uid}: roomId               # current room, so queued players learn their match
codes/{code}: roomId                    # invite code lookup (backend only)
queue/{size}/{uid}: { at, name, avatar } # matchmaking queue (backend only)
```

Rules are in `database.rules.json`: clients can read rooms and their own
`users_rooms` entry and write only their presence flag. **Every room change
goes through the backend inside an RTDB transaction.**

### How an online turn works

1. The player taps *Roll*; the app POSTs `/api/rooms/{id}/roll`.
2. The server checks the room is playing and that it is this seat's turn
   (or that the current player's 30 s deadline passed, in which case anyone
   at the table may roll for them), draws the dice with `crypto.randomInt`,
   applies the shared rules (`rules.service.js`), appends a move and updates
   the state atomically.
3. Every client sees the new move in RTDB and replays it through the normal
   local `GameEngine` with a `ScriptedDice`, so the dice tumble, hops, snake
   slides and ladder climbs look exactly like local play. If the local result
   ever disagrees with the server, the board re-syncs from the server state.
4. Leaving a running game forfeits the seat; the remaining player wins a
   2-player game. Finished games are written to Firestore `games/{roomId}`,
   each player's history, their stats and both leaderboards, server-side.

Without Firebase and a backend URL the lobby runs an **offline simulation**
(`LocalRoomService`): the same room logic in Dart with bots that join and
roll, so the whole flow can be tried on one device.

### Security principles

- Clients never write wins, stats or leaderboard entries.
- Backend verifies Firebase ID tokens, checks turn ownership, generates the
  dice value server-side, applies `GameRules`, and writes the result.
- Firestore / RTDB rules: users may read their own data and public leaderboards;
  all game writes come from the Admin SDK.

---

## 6. Backend API (`backend/`)

Node.js 22+ · Express 5 · Firebase Admin. See `backend/README.md` for
running, testing and deploying it (Cloud Run).

| Method | Route | Auth | Status |
|---|---|---|---|
| GET | `/api/health` | – | ✅ |
| GET | `/api/leaderboard?period=allTime\|weekly&limit=50` | – | ✅ |
| GET | `/api/me` | ✓ | ✅ profile created on first call |
| PATCH | `/api/me` | ✓ | ✅ display name / avatar (also updates leaderboard rows) |
| POST | `/api/matches` | ✓ | ✅ validated, idempotent by match id |
| GET | `/api/history?limit=50` | ✓ | ✅ |
| POST | `/api/rooms` `{maxPlayers, rules?}` | ✓ | ✅ create private room → invite code |
| GET | `/api/rooms/current` | ✓ | ✅ room the user is seated in |
| GET | `/api/rooms/:id` | ✓ | ✅ snapshot (members only) |
| POST | `/api/rooms/:code/join` | ✓ | ✅ idempotent; refused when full/started |
| POST | `/api/rooms/:id/start` | ✓ | ✅ host only, ≥2 players |
| POST | `/api/rooms/:id/roll` | ✓ | ✅ server dice; turn / deadline validated |
| POST | `/api/rooms/:id/leave` | ✓ | ✅ leave (open) or forfeit (playing) |
| POST | `/api/matchmaking/join` `{maxPlayers}` | ✓ | ✅ queued \| matched \| in_room |
| DELETE | `/api/matchmaking/join` | ✓ | ✅ |

Security: Firebase ID tokens are verified on every protected route; bodies
are size-limited and validated (two winners, 2-turn wins, impossible roll
counts are rejected); 120 req/min/IP rate limit; CORS allow-list.

---

## 7. Testing

```
test/board_geometry_test.dart   zigzag numbering, pixel maths, hit testing
test/board_config_test.dart     board validation
test/game_rules_test.dart       movement, snakes, ladders, exact-100, six rules, forfeits
test/game_engine_test.dart      state machine, locking, pause, reset, auto-play, dispose
test/dice_cube_math_test.dart   face normals, target orientations, spin maths
test/dice_widget_test.dart      dice lands on the rolled value, incl. long frames
test/settings_audio_test.dart   sound mapping, settings persistence/audio sync, onboarding and settings flows
test/online_test.dart           scripted replay, snapshots, forfeits, room parsing, local room service, controller sync
test/online_flow_test.dart      lobby -> room -> bot joins -> start -> roll -> bot replies -> leave
backend/test/rooms.test.js      create/join/start/roll/forfeit/quick-match against fake Firestore + RTDB
test/data_layer_test.dart       stats rules, profile/match serialisation, offline auth, in-memory repository
test/auth_flow_test.dart        splash -> login -> offline guest -> home -> leaderboard/profile -> sign out
backend/test/                   stats rules + full API tests against an in-memory Firestore (`npm test`)
test/computer_player_test.dart  bot strength on the dice, stats counters, ranking, personalities
test/game_setup_test.dart       setup notifier: modes, seats, colours, bot level
test/result_screen_test.dart    result screen ranking and actions
test/board_shapes_test.dart     snake spine / sway invariants, ladder rungs and climb path
test/board_widget_test.dart     token actually follows the snake spine and the ladder
test/widget_test.dart           home -> setup -> game flow, portrait + landscape layouts
```

---

## 8. Release checklist (Phase 8)

### Assets & identity
- Launcher icons are generated from `assets/icon/*.png` (drawn by
  `tool/gen_icon.py`) with `dart run flutter_launcher_icons`
  (`flutter_launcher_icons.yaml`). Re-run both after changing the artwork.
- App name is *Snakes & Ladders* on Android, iOS and web; application id /
  bundle id `in.nextaqua.snakes_ladders`; version lives in `pubspec.yaml`.

### Android (Play Store)
```bash
keytool -genkey -v -keystore ~/snakes-ladders-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias snakes
cp android/key.properties.example android/key.properties   # fill in paths/passwords (git-ignored)
flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-backend>
# upload build/app/outputs/bundle/release/app-release.aab to Play Console
```
Release builds are minified and resource-shrunk (`proguard-rules.pro` keeps
Flutter and Firebase). Without `key.properties` the release build signs with
the debug key so it can still be installed for testing. Add the release
key's SHA-1/SHA-256 to the Firebase project for Google sign-in.

### iOS (App Store)
```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://<your-backend>
```
Flutter 3.50 resolves the Firebase iOS SDK through Swift Package Manager
(no Podfile); the first build clones the packages into `build/ios/` and takes
a long time.
Set your team in Xcode (Runner → Signing & Capabilities), add the
`GoogleService-Info.plist` from the Firebase console, and the reversed
client id URL scheme for Google sign-in.

### Web (Firebase Hosting)
```bash
flutter build web --release --dart-define=API_BASE_URL=https://<your-backend>
firebase deploy --only hosting
```
Add the hosting domain to Firebase Auth *Authorized domains* and to the
backend's `CORS_ORIGINS`.

### Backend (Cloud Run)
See `backend/README.md`. Set `FIREBASE_PROJECT_ID`, `FIREBASE_DATABASE_URL`
and `CORS_ORIGINS`; the Cloud Run service account needs Firestore and RTDB
access (default compute service account is fine).

### Before submitting
- Run the one-time Firebase setup (§5) and deploy Firestore + RTDB rules.
- Fill in the contact line in `PRIVACY.md` and host it (Play/App Store need
  a privacy policy URL; Firebase Hosting works: copy it into `web/`).
- CI (`.github/workflows/ci.yml`) runs analyze, tests, the web build, the
  backend tests and a debug APK on every push.
- Performance: the board's static layer is cached as a `Picture`, the board
  sits in its own `RepaintBoundary`, and snakes animate with a single ticker.
