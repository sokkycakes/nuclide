# Plan 003 implementation notes (2026-07-17)

Plan: `docs/plans/2026-07-17-003-feat-mapless-webcore-lobby-plan.md`  
Build-of-record: `workspace/fteqw/_worktrees/webcore-cpu-renderer/` → `C:\bld\fteqw_src2` → staged `nuclide/fteqw64.exe` + `fteplug_webcore_x64.dll`

## Units

| Unit | Status | Notes |
|------|--------|--------|
| U0 | Done | Single worktree + include transport; staged binary |
| U1 | Done | `Lobby_RunFrame` from `cl_main` |
| U2 | Done | Host-authoritative phases, ready clear, countdown |
| U3 | Done | Seq/ack reliable wrap; reject; heartbeat; endpoint bind; versioned join; `Lobby_FmtMsg` (Q_snprintfz is truncation, not length) |
| U4 | Done | `lobby_snapshot` registered + `Cvar_Set` (was SetNamed → silent no-op → empty getlobby); basemod WT_GAMELOBBY lobby-menu; Leave always enabled |
| U5 | Done | Mapless create; title LAN/address/room UI |
| U6 | Done | `ICEP_LOBBY` + ice backend; room create publishes `roomCode`; `Lobby_Transport_NoteIcePeer` on ICE connect for joiner send route. Same-PC broker P2P join still flaky vs internet peers. |
| U7 | Done | STARTING → listen-ready (`sv.state`) → per-peer `G:`; `gamedir`/`maxplayers`/`deathmatch` before `map` |
| U8 | Done (localhost) | Two-process LAN: join → ready → countdown → cancel → start → game port 27500 + both INGAME. Mapless pre-start (only 27501). |

## Localhost E2E (2026-07-17)

Proven with staged `fteqw64.exe` via `+lobby_create_lan` / `+lobby_join 127.0.0.1` and timed `+in` ready/cancel:

1. Mapless WAITING with only lobby port 27501
2. Second process joins seat 1; shared roster (no duplicate seats on retry)
3. Both ready → COUNTDOWN; host cancel → WAITING, ready cleared
4. Countdown completes → STARTING → game listen 27500 → INGAME + `Game starting.`

## Online smoke

- `+lobby_create_online` → WAITING with `roomCode` (broker path opens).
- Same-machine room-code join did not complete ICE P2P in the harness; treat multi-host/internet as the operator check for U6/U8 online column.

## Start handoff pitfalls fixed

- `Q_snprintfz` used as length aborted join/ready sends → `Lobby_FmtMsg` / `strlen` after snprintf
- Join retries allocated ghost seats → reuse seat by peer address
- Ready `P:` broadcasts never sent (same snprintf bug in LAN/ICE backends)
- Listen-ready checked `sv.active` (never set) → use `sv.state >= ss_active`
- Client `fs_game` can be empty so `map` cannot see `maps/*.bsp` → `gamedir base` when empty; `deathmatch 1` + `maxplayers` before map
- Default map `start` → `envtest` (present in `base/maps`)

## Smoke helpers

- `base/lobby_u8_host.cfg` — `lobby_create_lan`
- `base/lobby_u8_join.cfg` — `lobby_join 127.0.0.1`

## Operator remaining

- LAN: two machines, join by LAN IP (same protocol as localhost)
- Online: `lobby_create_online` / room-code join with reachable `net_ice_broker`
- WebCore title Create/Join/Ready/Start (engine path proven; UI is allowlisted `lobby_action:*`)

## Text-click crash (2026-07-17 evening)

WinCairo host crashed in `EventHandler::handleMousePressEventSingleClick` → `positionForPoint` when mouse-press hit ordinary text (map name, labels). Buttons were fine.

**Fix:** `page->settings().setTextInteractionEnabled(false)` in `workspace/webcore-fte/Tools/FTE/host/fte_render_harness.cpp` so `mouseDownMayStartSelect()` is always false. Rebuilt via `C:\w\wc-fte\build-harness-only.cmd`, staged `nuclide/ftewebcore.dll`. Lobby CSS click-shield bumped to `?v=7` (belt-and-suspenders only).

## In-game HUD regression (2026-07-17 evening)

`autoexec.cfg` + `hud.qc` switched primary HUD to incomplete WebCore HTML (`webcore_hud 1`, `slint_hud 0`). Symptoms: missing `hudring`, static timer/speedo, HP states all visible, no live stats.

**Fix:** `gethud` query in plugin (CSQC publishes timer/health/ammo cvars; speed via `GetPredInfo`); HTML/CSS add hudring + hide inactive HP; `app.js` polls `gethud`. Staged `fteplug_webcore_x64.dll` + rebuilt `hud.dat`. URL cache-bust `?v=2`.

## CSQC player underread exposed by lobby start (2026-07-18)

The lobby-to-map transition exposed an existing FTEQCC virtual-dispatch collision between the player and inherited spectator `ReceiveEntity(float,float)` methods. The lobby transport delivered the correct bytes; it was not the source of the corruption. The fixed `ENT_PLAYER` schema now uses the uniquely named nonvirtual `ReceivePlayerEntity(float,float)` decoder.

See [FTEQCC virtual `ReceiveEntity` dispatch causes CSQC player underreads](../solutions/runtime-errors/fteqcc-virtual-receiveentity-csqc-underread.md) for the symptoms, byte accounting, eliminated hypotheses, root cause, and verification.
