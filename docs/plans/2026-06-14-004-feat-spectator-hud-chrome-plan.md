---
title: "feat: Nuclide spectator HUD chrome"
type: feat
status: completed
date: 2026-06-14
origin: docs/brainstorms/2026-06-14-nuclide-spectator-hud-requirements.md
---

# feat: Nuclide spectator HUD chrome

## Summary

Implement `CSpectatorGUI`-parity spectator HUD chrome in Nuclide as a reusable framework feature. The spectator camera system already works (`ncSpectator`, 7 modes, networked target/mode); this plan fills the empty `HUD_DrawSpectator()` draw branch with always-on chrome (watching bar, top bar, timer/score, key hints, observer crosshair) in `src/client/`, adds a toggleable VGUI observer target list, and—last—a toggleable inset picture-in-picture via a second `ncView` pass.

---

## Problem Frame

While spectating, the local client sees the world through the camera but gets no on-screen context: who they are watching, which mode is active, the score/time, or how to switch targets. CSO provided this via `CSpectatorGUI`; Nuclide's equivalent draw hook exists but is an empty stub. (See origin for full pain narrative and CSO architecture mapping.)

---

## Requirements

- R1. While the local client is an `ncSpectator`, show a watching bar: "Spectating: `<name>`" plus the active camera-mode label.
- R2. Show a top bar / banner: server name, map, game-mode title.
- R3. Show match timer and team scores.
- R4. Show a key-hint guide reflecting the real bound spectator keys (next / previous / change mode).
- R5. Show an observer crosshair only in free-roam mode.
- R6. Provide an interactive, scrollable, **toggleable** observer target list to switch the spectated player.
- R7. Provide a **toggleable** inset PiP that, when shown, renders first-person of the currently spectated entity. Built last.
- R8. All chrome lives in the framework (`src/client/`) so every game inherits it; games may extend/override via their own `hud.dat` spectator export.

**Origin actors:** spectating client (local observer).
**Origin flows:** enter spectate → track target/mode each frame → switch target (next/prev) → change mode → toggle observer list → toggle inset PiP.
**Origin acceptance examples:** carried from origin Success Criteria (entering spectate shows chrome tracking target/mode; free-roam shows crosshair, chase/first-person do not; list toggles and switches target; PiP renders without breaking main view; overlay only for `ncSpectator`).

---

## Scope Boundaries

- Map overview modes (`FREEOVERVIEW`/`CHASEOVERVIEW`) stay remapped/disabled; the `ncRadar` render path is untouched.
- No Source `.res`-driven UI; the leftover `base/ui/l4d360ui/observerlistitem.res` stays unwired.
- No changes to spectator camera *behavior* (smoothing, cycling logic) beyond restoring the mode-cycle input binding (U1).
- No new netcode — target/mode are already networked; timer/score are already client-readable.

### Deferred to Follow-Up Work

- Inset PiP mode cycling (first-person → chase → off) beyond the basic show/hide + first-person default — a later iteration may extend U5.
- **Spectator target cycling (local multi-client)** — scroll wheel / next-prev does not switch to the other player on a same-machine two-client server. Multiple QC fixes attempted; still broken for the user. Parked for investigation. See [docs/deferred/spectator-target-cycling.md](../deferred/spectator-target-cycling.md).

---

## Context & Research

### Relevant Code and Patterns

- Draw branch already wired: `src/client/entry.qc` `CSQC_Update2D` calls `HUD_DrawSpectator()` when `Client_IsSpectator(cl)`.
- Framework forwarder (`__weak`): `src/client/hud.qc` `HUD_DrawSpectator(void)` → `HUDProgs_DrawSpectator()` → `hud.dat` export.
- Game stub (empty, wrong signature): `base/src/hud/hud.qc` `HUD_DrawSpectator(vector hud_mins, vector hud_size)`. Loader expects `void HUD_DrawSpectator(void)` (`src/client/api_func.h`, `src/client/hud.qc` `externvalue`).
- Spectator state + input: `src/shared/game/Spectator.qc` (`ProcessInput`, `InputNext`/`InputPrevious`/`InputMode`), `src/shared/game/Spectator.h` (`g_specmodes[]`, `m_spectatingEntity`, `m_spectatingMode`).
- Client-side spectator data: `src/client/api.qc` `CLPF_spectating_*` (`spectating.Name/.Mode/.LocalizedMode/.Team`); `spectating` API available to `hud.dat` (wired in `src/client/api_func.h`, included via `src/hud.src` → `client/api.h`).
- Timer/score: `src/shared/system/util.qc` `Util_GetTime()` / `Util_GetTimeLeft()`; `serverkey("teamscore_%i")` (`src/client/api.qc:220`); `serverinfo.GetString("hostname")` + `mapname` (mirrors `Scores_Draw`).
- Immediate-mode HUD reference: `base/src/hud/hud.qc` `HUD_Draw()` — `screen.HUDMins()`/`screen.HUDSize()`, `draw.Text_RGBA`, `draw.SubPic`, `font.*`.
- Hold-vs-toggle reference: scoreboard hold `+showscores`/`-showscores` (`src/client/cmd.qc:513`), VGUI toggle command `showPlayerList` → `VGUI_PlayerList()` (`src/client/cmd.qc:647`).
- VGUI list widget reference: `src/client/vgui_playerlist.qc` (`vguiWindow`, `vguiList`, `vguiScrollBar`, `vgui3DView`); modal gate `VGUI_Active()`.
- Sub-viewport / second render: `src/client/View.qc` `VIEWMODE_SPECTATING` branch (per-mode camera setup), `m_vecPosition`/`m_vecSize` (`VF_MIN`/`VF_SIZE`); `src/client/Radar.qc` is an existing secondary-render example.
- File registration: `src/client/include.src` (framework client modules), `base/src/hud/progs.src` (game hud.dat).

### Institutional Learnings

- `AGENTS.md`: favor a minimal reusable framework; place HUD widgets in the letterboxed `screen.HUDMins()`/`screen.HUDSize()` rect when they should track the safe HUD area.

---

## Key Technical Decisions

- **Draw chrome from the framework forwarder, not the game stub.** Implement chrome in a new `src/client/` module and call it from `src/client/hud.qc` `HUD_DrawSpectator()` *before* `HUDProgs_DrawSpectator()`. This makes the chrome a framework default while the `hud.dat` export remains available for per-game extension. Rationale: honors R8 and the `__weak` override pattern already used for `HUD_DrawSpectator`.
- **Fix the base stub signature to `void HUD_DrawSpectator(void)`** and derive the rect via `screen.HUDMins()`/`screen.HUDSize()` (as `HUD_Draw()` does). Rationale: matches the loader contract; the old 2-arg signature was never invoked correctly.
- **Observer target list = toggle command** (`showObservers`), modeled on `showPlayerList`. Modal `VGUI_Active()` block while open is acceptable (origin decision Q1).
- **Inset PiP = toggle command** defaulting to first-person of the current target; built last via a second `ncView` pass (origin decision Q2).
- **Reuse existing data paths; add no netcode.** All chrome reads existing `spectating.*`, `serverkey`, and `Util_Get*` sources.

---

## Open Questions

### Resolved During Planning

- Q1 (target list hold vs toggle): toggle (`showObservers`). See origin Resolved Decisions.
- Q2 (PiP default + toggleable): toggleable, default first-person of current target. See origin.
- Q3 (draw hook): use existing `HUD_DrawSpectator()` branch; implement chrome in `src/client/`, fix base signature. See origin.

### Deferred to Implementation

- Exact pixel layout/anchoring constants for each chrome element (tune against the letterboxed rect at implementation time).
- Whether the observer crosshair reuses an existing crosshair atlas pic or a dedicated sprite (decide when wiring U2's free-roam branch).
- Final widget sizing/scroll behavior for the observer list (derive from `vgui_playerlist.qc` at build time).
- Acceptable cost / exact `VF_*` setup for the second `ncView` PiP pass in this FTEQW build (validate during U5).

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
CSQC_Update2D (src/client/entry.qc)
  └─ Client_IsSpectator(cl) == true
       └─ HUD_DrawSpectator(void)            // src/client/hud.qc (__weak framework)
            ├─ Spectator_DrawHUD()           // NEW src/client/spectatorhud.qc  (R1–R5 always-on chrome)
            │     reads: spectating.Name/.LocalizedMode/.Mode/.Team,
            │            Util_GetTime(), serverkey("teamscore_N"),
            │            serverinfo hostname, mapname; anchored to screen.HUDMins/HUDSize
            └─ HUDProgs_DrawSpectator()       // game hud.dat extension point
                  └─ base HUD_DrawSpectator(void)   // base/src/hud/hud.qc (now void(); game-specific extras)

Toggle command "showObservers" (src/client/cmd.qc)
  └─ VGUI_Observers()                         // NEW src/client/vgui_observers.qc (R6)  — reuses vgui_playerlist patterns

Toggle command "showSpecInset" (src/client/cmd.qc)
  └─ sets g_specInsetActive
       └─ second ncView pass in View.qc / entry.qc render loop (R7, built last)
            renders first-person of spectating.* target into m_vecPosition/m_vecSize inset rect
```

---

## Implementation Units

- U1. **Restore spectator mode-cycle input**

**Goal:** Make the "change mode" action functional so the U2 key-hint guide reflects a real binding.

**Requirements:** R4

**Dependencies:** None

**Files:**
- Modify: `src/shared/game/Spectator.qc` (`ncSpectator::ProcessInput`)

**Approach:**
- Add an `INPUT_JUMP` branch in `ProcessInput()` that calls `InputMode()`, alongside the existing `INPUT_PRIMARY` (next) / `INPUT_SECONDARY` (prev) handling, guarded by the existing `SPECFLAG_BUTTON_RELEASED` debounce so a held key cycles once per press.
- Keep the overview-mode skip already present in `InputMode()` (no behavior change to mode set).

**Patterns to follow:**
- Existing `ProcessInput()` button handling and `SPECFLAG_BUTTON_RELEASED` debounce in `src/shared/game/Spectator.qc`.

**Test scenarios:**
- Happy path: while spectating a valid player, pressing jump advances `m_spectatingMode` through the chase/first-person cycle (wrapping at the overview boundary back to locked chase).
- Edge case: with no valid target, jump resolves to `SPECMODE_FREE` (matches existing `InputMode()` no-target branch).
- Edge case: holding jump cycles exactly one mode per press (debounce holds until release).

**Verification:** In-game, jump while spectating cycles modes; the U2 "change mode" hint corresponds to the actual jump key.

---

- U2. **Framework always-on spectator chrome module**

**Goal:** Render the always-on chrome (watching bar, top bar, timer/score, key hints, observer crosshair) for any `ncSpectator`, anchored to the letterboxed HUD rect.

**Requirements:** R1, R2, R3, R4, R5, R8

**Dependencies:** None (consumes existing APIs)

**Files:**
- Create: `src/client/spectatorhud.qc` (e.g. `Spectator_DrawHUD(void)` plus static element draw helpers)
- Modify: `src/client/include.src` (register the new module)

**Approach:**
- Anchor everything to `screen.HUDMins()` / `screen.HUDSize()` (letterboxed safe rect per `AGENTS.md`), mirroring `HUD_Draw()`.
- Watching bar (R1): `spectating.Name()` + `spectating.LocalizedMode()`.
- Top bar (R2): `serverinfo.GetString("hostname")`, `mapname`, game-mode title.
- Timer/score (R3): `Util_GetTime()` and per-team `serverkey(sprintf("teamscore_%i", t))` (mirror `Scores_Draw` reads).
- Key hints (R4): static guide reflecting next/prev/change-mode (primary/secondary/jump).
- Observer crosshair (R5): draw only when `spectating.Mode()` is the free-roam mode (`SPECMODE_FREE`); not in chase/first-person/locked.
- Pure draw module — no input handling, no state mutation; safe to call every spectator frame.

**Patterns to follow:**
- `base/src/hud/hud.qc` `HUD_Draw()` (rect anchoring, `draw.Text_RGBA`, `draw.SubPic`, `font.*`).
- `base/src/client/main.qc` `Scores_Draw()` (hostname + team score reads, layout math).

**Test scenarios:**
- Happy path: as `ncSpectator` tracking a player, watching bar shows that player's name and the current mode label; top bar shows hostname/map; timer shows remaining time; team scores render.
- Happy path (R5): in `SPECMODE_FREE`, observer crosshair draws; in chase/locked-chase/first-person it does not.
- Edge case: spectating world / no valid target (`m_spectatingEntity == 0`) draws a sane placeholder name without errors (mirror `CLPF_spectating_*` fallbacks).
- Edge case: server with no `timelimit` shows an up-counting clock (per `Util_GetTime` behavior) rather than a broken countdown.

**Verification:** Entering spectate shows all four always-on elements tracking target/mode each frame; crosshair appears only in free-roam.

---

- U3. **Wire chrome into the draw path and fix the base stub signature**

**Goal:** Call the framework chrome from the existing spectator draw branch and correct the `hud.dat` export contract.

**Requirements:** R8

**Dependencies:** U2

**Files:**
- Modify: `src/client/hud.qc` (`HUD_DrawSpectator(void)` — call `Spectator_DrawHUD()` then `HUDProgs_DrawSpectator()`)
- Modify: `base/src/hud/hud.qc` (`HUD_DrawSpectator` → `void HUD_DrawSpectator(void)`; derive rect internally if it draws anything)

**Approach:**
- In `src/client/hud.qc` `HUD_DrawSpectator()`, keep the `autocvar_g_showHud` guard, draw framework chrome via `Spectator_DrawHUD()`, then forward to `HUDProgs_DrawSpectator()` so games can extend.
- Change `base/src/hud/hud.qc` export to `void HUD_DrawSpectator(void)` to match the `externvalue` call; leave its body empty (game extension point) or derive `screen.HUDMins()`/`screen.HUDSize()` if it adds game-specific extras.

**Patterns to follow:**
- `__weak void HUD_DrawSpectator(void)` and `HUDProgs_DrawSpectator()` in `src/client/hud.qc`; `HUD_Draw()` rect derivation in `base/src/hud/hud.qc`.

**Test scenarios:**
- Integration: with the base hud.dat built, entering spectate renders U2 chrome (framework path) and the game export is invoked without arg-mismatch errors.
- Edge case: `g_showHud 0` suppresses the spectator chrome (guard respected).
- Integration: a game that defines its own spectator export still has it called after framework chrome.

**Verification:** hud.dat compiles with the corrected signature; spectator chrome renders in `base`; no QCC warnings about `HUD_DrawSpectator` arity.

---

- U4. **VGUI observer target list (toggle)**

**Goal:** A toggleable, scrollable observer list to switch the spectated player.

**Requirements:** R6

**Dependencies:** None (independent of U2/U3; uses spectator target-switch input already present)

**Files:**
- Create: `src/client/vgui_observers.qc` (`VGUI_Observers()` toggle window)
- Modify: `src/client/include.src` (register module)
- Modify: `src/client/cmd.qc` (handle + `registercommand("showObservers")`)

**Approach:**
- Model on `VGUI_PlayerList()` / `showPlayerList`: a `vguiWindow` with a `vguiList` + `vguiScrollBar` of connected players (name/team), selectable to switch target.
- Selecting an entry switches the spectated player using the existing target-switch path (no new netcode; reuse the next/prev mechanism or a direct target set if available).
- Toggle open/close via `showObservers`; modal `VGUI_Active()` block while open is acceptable per decision Q1.

**Patterns to follow:**
- `src/client/vgui_playerlist.qc` (window/list/scrollbar construction, draw loop), command registration block in `src/client/cmd.qc` (`showPlayerList`, lines ~647/680).

**Test scenarios:**
- Happy path: `showObservers` opens the list populated with current players; selecting one makes the spectator follow that player; toggling again closes it.
- Edge case: empty/solo server shows an empty-but-stable list without errors.
- Integration: while the list is open `VGUI_Active()` is true and the scoreboard branch does not also render (mirrors existing `entry.qc` VGUI/scores exclusivity).

**Verification:** Toggling `showObservers` opens/closes the panel and switching a target updates the watching bar (U2).

---

- U5. **Inset PiP via second `ncView` render (toggle)**

**Goal:** A toggleable inset rendering first-person of the currently spectated target, without breaking the main spectator view.

**Requirements:** R7

**Dependencies:** U2, U3

**Files:**
- Modify: `src/client/View.qc` (second-pass inset render into `m_vecPosition`/`m_vecSize`)
- Modify: `src/client/cmd.qc` (handle + `registercommand("showSpecInset")`, sets a toggle flag)
- Possibly modify: `src/client/entry.qc` (invoke the inset pass within the spectator render loop)

**Approach:**
- Add a client toggle flag (e.g. `g_specInsetActive`) set by `showSpecInset`.
- When active and the local client is an `ncSpectator`, run a second `ncView` pass into a fixed corner rect (`VF_MIN`/`VF_SIZE`) configured for first-person of the current `spectating` target, then restore the main viewport.
- Reuse the `VIEWMODE_SPECTATING` `SPECMODE_FIRSTPERSON` camera setup logic in `View.qc` as the inset camera source.
- Build last; ships independently of U2–U4.

**Patterns to follow:**
- `src/client/Radar.qc` (secondary `ncView` render), `src/client/View.qc` `VIEWMODE_SPECTATING` first-person branch and sub-viewport fields.

**Test scenarios:**
- Happy path: with `showSpecInset` on, the inset renders first-person of the current target in a corner; main view continues normally.
- Happy path: toggling off removes the inset and fully restores the main viewport (no leftover viewport state).
- Edge case: target with no valid first-person view (world/dead) degrades gracefully (blank/last-valid) without corrupting the main pass.
- Integration: switching targets (U4 or next/prev) updates the inset's subject.

**Verification:** Inset toggles cleanly, tracks the current target, and never leaves the main spectator view in a broken viewport state.

---

## System-Wide Impact

- **Interaction graph:** New chrome hangs off the existing `CSQC_Update2D` spectator branch; U5 adds a second render pass into the client render loop. No server-side changes except U1's input branch.
- **Error propagation:** Chrome is read-only draw; guard against null/zero `m_spectatingEntity` (reuse `CLPF_spectating_*` fallbacks). U5 must restore viewport state on every path (including early-out/error).
- **State lifecycle risks:** U4/U5 toggle flags must reset on spectate exit / disconnect so panels/inset don't persist into normal play.
- **API surface parity:** `HUD_DrawSpectator` signature change aligns base with the framework loader contract; other games' hud.dat exports must adopt `void(void)` if they defined the old 2-arg form.
- **Unchanged invariants:** Spectator camera behavior, overview render path (`ncRadar`), and networking of `m_spectatingEntity`/`m_spectatingMode` are unchanged.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Signature change to `HUD_DrawSpectator` breaks a game hud.dat that defined the 2-arg form | Only `base` defines it today (empty); update base in U3 and note the contract in System-Wide Impact for other games |
| Second `ncView` PiP pass too costly or leaves viewport state dirty in this FTEQW build | Build U5 last and independently; restore viewport on all paths; gate behind a toggle so default behavior is unaffected |
| Modal VGUI observer list blocks spectator camera input while open | Accepted per decision Q1 (toggle); closing restores input, mirroring `showPlayerList` |
| Layout constants look wrong on non-4:3 windows | Anchor to `screen.HUDMins()`/`screen.HUDSize()` letterboxed rect per `AGENTS.md` |

---

## Sources & References

- **Origin document:** [docs/brainstorms/2026-06-14-nuclide-spectator-hud-requirements.md](docs/brainstorms/2026-06-14-nuclide-spectator-hud-requirements.md)
- Related code: `src/client/entry.qc`, `src/client/hud.qc`, `base/src/hud/hud.qc`, `src/shared/game/Spectator.qc`, `src/client/api.qc`, `src/client/View.qc`, `src/client/vgui_playerlist.qc`, `src/client/cmd.qc`, `base/src/client/main.qc`, `src/shared/system/util.qc`
