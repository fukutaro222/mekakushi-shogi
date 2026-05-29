# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Deploy

```bash
/Users/fukutaro222/.npm-global/bin/vercel --prod
```

The Vercel CLI is installed at that path (not on system PATH). Always use the full path.

After changes to `index.html`, commit and push to GitHub first, then run the deploy command.

## Architecture

This is a **single-file web app** — all HTML, CSS, and JavaScript live in `index.html` (~9,200 lines). There is no build step, no bundler, no framework. Editing `index.html` is the only way to change the app.

### File layout

| File | Purpose |
|------|---------|
| `index.html` | Entire application |
| `vercel.json` | COOP/COEP headers (required for SharedArrayBuffer / WASM) |
| `supabase.min.js` | Supabase JS v2 UMD build, served locally (CDN blocked by COEP) |
| `engine/` | やねうら王 WASM build (`yaneuraou.js` + `yaneuraou.data`) |
| `*.sql` | Supabase table definitions — run manually in Supabase SQL Editor |

### External CDN scripts

Loaded in `<head>` with `crossorigin="anonymous"` (required by COEP):
- PeerJS 1.5.4 — WebRTC P2P signaling
- Supabase JS 2.50.0 — loaded from jsDelivr CDN (also mirrored as `supabase.min.js` locally)
- QRCode.js 1.0.0

### index.html structure

```
<head>          lines 1–13      CDN scripts
<style>         lines 14–3387   All CSS
<body>          lines 3388+     HTML panels + <script> (all JS)
```

The `<script>` block is one large IIFE-like block with sections delimited by `// ── Section Name ──` comments. Key sections and approximate line numbers:

| Lines | Section |
|-------|---------|
| 3389 | Supabase init (`sb` client, `currentUser`) |
| 3408 | Auth state listener + `getSession` |
| 3473 | `showAuthOverlay()` / `hideAuthOverlay()` |
| 3725 | `auth-submit` onclick handler |
| 4188 | Game constants (KANJI, ROW_KANJI) |
| 4225 | All game state variables |
| 4342 | Initial board layout |
| 4372 | Legal move generation |
| 4466 | Check / checkmate detection |
| 4554 | Move execution (`executeMove`) |
| 4609 | WASM engine loader (`_startWasmEngine`) |
| 4761 | Game clock |
| 4873 | PvP / PeerJS logic |
| 5132 | Auto-matchmaking (Supabase Realtime) |
| 5411 | In-game chat |
| 5542 | Bulletin board (掲示板) |
| 6088 | `pvpCleanup` / `showTitleScreen` |
| 6213 | Spectator mode (stub — not functional) |
| 6360 | Rematch (stub — not functional) |
| 6448 | JS alpha-beta CPU engine |
| 6620 | Click handler (board cell selection) |
| 6823 | Board rendering (`drawBoard`) |
| 7172 | Rating calc + game record save to Supabase |
| 7279 | Title screen / `updateTitleAuth` / `#global-auth-corner` |
| 7431 | Ranking (`showRanking`) |
| 7506 | Kifu history (`loadKifuList`) |
| 7518 | Kifu replay |
| 7745 | Research mode |
| 8446 | Speech synthesis |
| 8521 | Speech recognition |
| 8947 | Startup / event listener wiring |

### Supabase

Client is stored in `sb` (not `supabase`). Always guard with `if (sb && sb.auth)` before calling auth methods.

Project: `rmupcpezaodhkqorvuvc.supabase.co`

Tables (SQL files in repo root, run in Supabase SQL Editor to create):

| Table | SQL file | Purpose |
|-------|----------|---------|
| `profiles` | `migration.sql` | User nickname, rating, rank |
| `games` | `games.sql` | Game records, kifu (jsonb), ratings |
| `matchmaking_queue` | `matchmaking_queue.sql` | Auto-match waiting queue |
| `game_chat` | `game_chat.sql` | In-game chat messages |
| `boards` / `board_replies` / `board_reports` | `boards.sql` | Bulletin board |
| `chat_messages` | `chat_messages.sql` | (Legacy chat table) |

### WASM engine

`_startWasmEngine()` loads `/engine/yaneuraou.js` on demand. It is triggered **only** by the practice game button click — never on page load. The `_wasmStarted` boolean prevents double-loading. When `window.crossOriginIsolated` is false (COOP/COEP headers missing), the function exits early and the JS alpha-beta engine is used as fallback.

### Auth flow

1. `sb.auth.onAuthStateChange` fires on login/logout → sets `currentUser` → calls `updateTitleAuth()` and `updateUserBar()`
2. `#global-auth-corner` (`position: fixed; z-index: 2050`) shows login state on every screen
3. After successful login, `window.location.href = '/'` forces a full reload to sync state
4. `translateAuthError(msg)` maps Supabase English error strings to Japanese

### PvP matchmaking flow

1. User clicks 「対局」→ `showMatchmakingPanel()` (login required)
2. 「対局相手を探す」→ `startMatchmaking()` inserts row into `matchmaking_queue`, subscribes to Realtime
3. Match found → PeerJS connection established → `pvpCreateRoom()` / `pvpJoinRoom()`
4. Game end → rating + kifu saved to `games` table via `saveGameRecord()`

### Incomplete features (stubs only — do not assume they work)

- **Rematch** (`startRematch`, `showRematchDialog`) — state vars and protocol messages exist, functions are empty
- **Spectator mode** (`watchMode`, `broadcastToWatchers`, `buildWatchState`) — UI exists, core logic is not implemented
