# U0 Build-of-Record — Mapless WebCore Lobby

Date: 2026-07-17  
Plan: `docs/plans/2026-07-17-003-feat-mapless-webcore-lobby-plan.md`

## Decision

**Integration / build-of-record tree:**  
`workspace/fteqw/_worktrees/webcore-cpu-renderer/`

**Runtime build copy (ccache script):**  
`C:\bld\fteqw_src2\` via `C:\w\wc-fte\rebuild_menu_console.sh`  
Lobby sources are copied from the WebCore worktree into the bld tree before each lobby-related rebuild. Do not edit lobby files only in canonical `workspace/fteqw/engine/` without porting the same patch into the worktree.

## Drift found (pre-fix)

| File | Canonical vs worktree |
|------|------------------------|
| `lobby_session.c` | Different; worktree missing `#include "lobby_transport.c"` and Transport join/close/poll wiring |
| `lobby_session.h` | Worktree declares APIs transport needs that session did not define |
| `lobby_transport.c` | Different; worktree has `G:` game_starting path |
| Makefile | Compiles `lobby_session.o` + backends only — transport must be **included** into `lobby_session.c` (no `lobby_transport.o`) |
| `Lobby_RunFrame` | Canonical: `cl_main`; worktree: Slint lobby draw only |

## U0 fixes applied in worktree

- `#include "lobby_transport.c"` at end of `lobby_session.c` (Makefile agreement)
- Implement missing session APIs used by transport: `Lobby_GetMap`, `Lobby_RejectsJoins`, `Lobby_RememberJoinHost`, `Lobby_OnGameStartingMsg`, `Lobby_CancelCountdown`, `Lobby_GetCountdownRemaining`
- Host-only seat 0 on create; LAN join via Transport (not `connect`)
- `Lobby_Close` broadcasts leave + `Lobby_Transport_Close`
- `Lobby_RunFrame` calls `Lobby_Transport_Poll` then backend poll
- `Lobby_RunFrame` from `cl_main` every client frame; removed Slint-only pump
- `Lobby_Transport_RegisterCvars` from `Lobby_Init`

## Carrier note (for U3+)

Current transport is still raw UDP with periodic full sync — **not** seq/ack reliable. U0 only makes the tree link and pump correctly. Reliability remains U3.

## Staging rule

After building from bld: stage `fteqw64.exe` (and plugin if rebuilt) to nuclide root together — no mixed-version tests.

## U0 verification (2026-07-17)

- Incremental `rebuild_menu_console.sh` linked successfully after adding `#include "netinc.h"` before transport include and `lobby_session.h` in `cl_main.c`.
- Staged `nuclide/fteqw64.exe` from `C:\bld\fteqw_src2\build\`.
- Transport remains raw UDP (seq unused for ack); reliability is U3.
