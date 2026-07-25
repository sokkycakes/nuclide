---
title: "feat: WebCore lobby UI (create + LAN join)"
type: feat
status: completed
date: 2026-07-17
origin: docs/brainstorms/2026-07-17-webcore-lobby-ui-requirements.md
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
execution: code
---

# feat: WebCore lobby UI (create + LAN join)

## Goal Capsule

- **Objective:** On the WebCore title menu, replace Map Browser / Create Server with Create Lobby / Join Lobby. Join opens a multi-method dialog (only LAN live); create and LAN join land on a VGUI-twin session room. Chrome matches basemod-foundation (semi-transparent panels + Trade Gothic). *(see origin: docs/brainstorms/2026-07-17-webcore-lobby-ui-requirements.md)*
- **Authority:** Requirements R1–R10, flows F1–F3, AE1–AE4.
- **Non-goals:** Room-code/address join, full Find Servers, H3/Slint polish, serverless/ICE transport, in-map RuleC lobby, classic `map` Create Server from these buttons.

## Problem Frame

Engine pre-game lobbies exist (`lobby_session`), but the live title surface is WebCore and the only lobby UI is brittle MenuQC VGUI. Title still points at classic Map Browser / Create Server. Need create + LAN join on WebCore without porting VGUI show/hide bugs.

## Requirements Trace

| ID | Requirement | Units |
|----|-------------|-------|
| R1 | Title: Create Lobby / Join Lobby replace Map Browser / Create Server | U4 |
| R2 | Create Lobby → LAN create → session room | U2, U3, U5 |
| R3 | Join Lobby → multi-method dialog | U4, U6 |
| R4 | Only LAN interactive; room code / address grayed | U6 |
| R5 | LAN refresh + join; empty state visible | U1, U6 |
| R6 | Session room VGUI twin | U5 |
| R7 | Ready / Start / Leave → engine lobby cmds | U1, U5 |
| R8 | Live sync of session state | U1, U5 |
| R9 | Leave → title menu | U2, U5 |
| R10 | Basemod-foundation panels + Trade Gothic | U4, U5, U6 |

## Key Technical Decisions

1. **Approach A (confirmed):** Title stays home; join is a dialog overlay; create/join open one session-room page via `menu_webcore lobby`.
2. **Restore `Lobby_SyncCvars` in the webcore-cpu-renderer worktree** (present on main FTE tree, missing in worktree). WebCore `getlobby` reads those cvars via plugin `Cvar` funcs — same contract as VGUI, no new Lobby plugin export.
3. **LAN list via plugin `Master` API** (`QueryServers` / `InfoForNum` / serverinfo `lobby` key) — not Client2, not QC builtins.
4. **Arg-bearing actions use colon queries**, not spaceful `cbuf:` (allowlist is single-token): e.g. `lobby_join:<addr>`, plus allowlisted tokens `lobby_create_lan`, `lobby_ready`, `lobby_start`, `lobby_close`, `menu_lobby_create`, `menu_webcore` (or dedicated `menu_lobby`).
5. **Create command:** `menu_lobby_create` runs `lobby_create_lan` then opens lobby URL (mirror `SlintLobby_Open` shape).
6. **Visuals:** Semi-transparent panels + system Trade Gothic stack — **no `@font-face`** (WebCore crash). Basemod-foundation is layout language reference; wireframe.css uses Consolas only as a wireframe stand-in.

## Architecture Sketch

```
Title HTML
  Create Lobby → cbuf:menu_lobby_create
       → lobby_create_lan + menu_webcore lobby
  Join Lobby → local dialog
       → fte_query(hostcache_refresh / gethostcache)
       → fte_query(lobby_join:<addr>) then menu_webcore lobby

Lobby HTML (session)
  poll getlobby → room/host/state/roster
  Ready/Start/Leave → allowlisted lobby_* (+ title on leave)
```

## Implementation Units

### U1. Plugin bridge: lobby queries + allowlist + Master hostcache

**Files:**
- `workspace/fteqw/_worktrees/webcore-cpu-renderer/plugins/webcore/webcore.c` (and staged build tree as used for rebuilds)
- Rebuild/stage `fteplug_webcore_x64.dll`

**Approach:** Extend `WebCore_JSQuery`: allowlist lobby tokens; `getlobby` JSON from cvars; `hostcache_refresh` / `gethostcache` via `plugmasterfuncs_t`; `lobby_join:<addr>` → `AddText("lobby_join …")`. Wire `cvarfuncs` + `masterfuncs` in `Plug_Init`.

**Test scenarios:**
- `fte_query("cbuf:lobby_create_lan")` returns `ok` when plugin loaded
- `getlobby` returns inactive snapshot when no session
- `gethostcache` returns JSON array (possibly empty) after refresh
- `lobby_join:` with empty addr rejected

**Verify:** Console smoke with plugin loaded; no spaces in allowlisted `cbuf:` path.

---

### U2. Engine menu: lobby URL alias + `menu_lobby_create`

**Files:**
- `workspace/fteqw/_worktrees/webcore-cpu-renderer/engine/client/m_webcore_menu.c`
- Sync to incremental build tree if used

**Approach:** Resolve alias `lobby` → `fte://data/web/lobby-menu/index.html`. Register `menu_lobby_create` (create LAN + push lobby menu). Ensure leave path can return to title (`menu_webcore` / title URL).

**Test scenarios:**
- `menu_webcore lobby` loads lobby HTML
- `menu_lobby_create` creates session and shows lobby page
- Esc on title still ignored; from lobby leave returns to title

---

### U3. Restore `Lobby_SyncCvars` in worktree

**Files:**
- `workspace/fteqw/_worktrees/webcore-cpu-renderer/engine/common/lobby_session.c` (port from `workspace/fteqw/engine/common/lobby_session.c`)

**Approach:** Restore SyncCvars on `Lobby_Emit` so `lobby_room_code`, `lobby_host_name`, `lobby_state_str`, `lobby_player_count`, `lobby_max_players`, `lobby_player1_name`…`4` stay populated. Required for U1 `getlobby` and keeps VGUI workable.

**Test scenarios:**
- After `lobby_create_lan`, `lobby_player_count` > 0 and room/host strings non-empty
- After `lobby_close`, count clears to 0

---

### U4. Title menu: Create / Join labels + join dialog shell

**Files:**
- `base/data/web/title-menu/index.html`
- `base/data/web/title-menu/app.js`
- `base/data/web/title-menu/style.css` (dialog + Trade Gothic / panel tokens as needed)

**Approach:** Relabel first two items; `data-cmd="menu_lobby_create"` for Create; Join opens overlay dialog (R3) without leaving title. Dialog lists Room Code / Address (disabled) + LAN section placeholder wired in U6. Basemod-ish semi-transparent panels.

**Test scenarios:**
- AE labels match R1
- Join opens dialog; Create does not open dialog
- Grayed methods not clickable

---

### U5. Lobby session page (VGUI twin)

**Files:**
- `base/data/web/lobby-menu/index.html`
- `base/data/web/lobby-menu/app.js`
- `base/data/web/lobby-menu/style.css`

**Approach:** Poll `getlobby`; show room/host/state/count/roster; Ready / Start / Leave → allowlisted cmds; Leave also returns to title. Same visual language as U4/U6.

**Test scenarios:**
- AE1 fields visible after create
- Leave → title (AE3)
- Poll updates when second player would appear (manual two-client)

---

### U6. Join dialog LAN list (refresh + join)

**Files:**
- `base/data/web/title-menu/app.js` (+ CSS)
- Relies on U1 hostcache queries

**Approach:** Refresh button → `hostcache_refresh`; populate list from `gethostcache` filtered to lobby rows when flag present (or show all LAN with lobby badge). Join selected → `lobby_join:<addr>` then `menu_webcore lobby`. Empty state message (AE4).

**Test scenarios:**
- AE2 / AE4
- Non-lobby rows either hidden or clearly not primary; joining a lobby entry opens session page

---

## Dependency Order

U3 → U1 → U2 → U4 → U5 → U6 (U4 shell can land before U6 LAN wiring).

## Risks

| Risk | Mitigation |
|------|------------|
| LAN lobbies not in hostcache until `sv.active` / serverinfo | Document; filter on `lobby` key; if empty after create on second client, note transport dependency (out of scope serverless plan) |
| Trade Gothic missing on machine | Fallback stack (Arial Narrow / Segoe UI); no `@font-face` |
| `lobby_ready` is set-ready not toggle | Match engine: Ready sends `lobby_ready` (ready=1); optional later toggle |
| Stale SyncCvars merge conflicts | Port carefully from main tree; call site on Lobby_Emit |

## Verification

Manual (two local clients preferred):
1. Title shows Create Lobby / Join Lobby
2. Create Lobby → session room with live cvars/getlobby
3. Join Lobby → dialog; room/address gray; LAN refresh; join → session room
4. Ready / Start / Leave behave; Leave → title
5. Empty LAN list shows empty state

## Deferred to Implementation

- Exact JSON field names for `getlobby` / `gethostcache` (keep small, mirror cvar names)
- Whether non-lobby hostcache rows are hidden vs shown muted
- Rebuild path: worktree vs `C:\bld\fteqw_src2` incremental — use whatever is currently staging `fteqw64.exe` / plugin
