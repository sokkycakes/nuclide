# Nuclide Spectator HUD — Requirements

**Date:** 2026-06-14
**Status:** Ready for planning
**Scope:** Deep — feature

## Problem & Value

Nuclide already has a working native spectator system (`src/shared/game/Spectator.qc`, `ncSpectator`) with 7 camera modes that mirror CSO/GoldSrc. What it lacks is the on-screen **spectator HUD chrome** — the part CSO's `CSpectatorGUI` provided. While spectating, the player sees the world through the camera but gets no context: who they're watching, which mode they're in, the score/time, how to switch targets, etc.

Goal: recreate `CSpectatorGUI`-parity spectator HUD chrome in Nuclide, using the most engine-native mechanism per element, built as a **reusable framework** feature so every game inherits it.

## Target Outcome

When a client is an `ncSpectator`, they see a complete spectator overlay: who/what they're watching, the active camera mode, match timer/score, key hints, an observer crosshair in free-roam, an interactive list of switchable targets, and an inset picture-in-picture secondary camera — visually consistent with how Nuclide draws its in-game HUD.

## Existing Context (verified)

- `ncSpectator` networks `m_spectatingEntity` and `m_spectatingMode` to the client (see `SendEntity`/`ReceiveEntity` in `src/shared/game/Spectator.qc`). **No new netcode needed** to know who/which-mode.
- Camera mode set (client labels in `Spectator.h`): Death Cam, Locked Chase, Free Chase (`THIRDPERSON`), Free Look (`FREE`), First Person, Free Overview, Chase Overview.
- Overview modes (`FREEOVERVIEW`/`CHASEOVERVIEW`) are intentionally remapped/disabled in `SharedInputFrame`/`InputMode`; the render path (`ncRadar`, `src/client/View.qc`) is left intact but unreachable from input.
- Three native UI mechanisms exist:
  - Immediate-mode QC HUD — `base/src/hud/hud.qc` (`draw.Text_RGBA`, `draw.SubPic`, anchored to `g_hudMins`/`g_hudRes`).
  - Nuclide QC VGUI — `src/client/vgui.qc`, `src/client/vgui_*.qc` (`vguiWindow`, `vguiLabel`, `vguiList`, `vguiScrollBar`, `vgui3DView`); `vgui_playerlist.qc` is the closest existing analog to a target list.
  - RmlUI — `base/ui/rml/hud.rml` (Stiletto HUD layer; CEF/menu-restart bound).
- `base/ui/l4d360ui/observerlistitem.res` is a leftover Source VGUI2 asset; Nuclide's VGUI is QC-driven and does not parse `.res`. Not wired to anything.

## Requirements

### HUD elements (all in scope — full `CSpectatorGUI` parity)

1. **Watching bar** — "Spectating: `<player>`" plus the active camera-mode label.
2. **Top bar / banner** — server name, map, game-mode title.
3. **Timer / score** — match time left and team scores.
4. **Key hint guide** — reflects the real bound spectator keys (next / previous / change mode).
5. **Observer crosshair** — shown in free-roam mode only.
6. **Observer target list** — interactive, scrollable list of switchable players.
7. **Inset PiP** — secondary camera rendered into a corner rectangle.

### Mechanism mapping (recommended: Hybrid)

| Element | Mechanism | Rationale |
|---|---|---|
| Watching bar | Immediate-mode HUD | Always-on, read-only; reads networked target + mode |
| Top bar | Immediate-mode HUD | Static read-only (`serverkey`, map name, game mode) |
| Timer / score | Immediate-mode HUD | Read from game rules (`ncGameRules`) |
| Key hints | Immediate-mode HUD | Reflect bound keys, corner-anchored |
| Observer crosshair | Immediate-mode HUD | Draw pic when mode is free-roam |
| Target list | Nuclide VGUI (toggle) | Needs scroll/select; reuse `vgui_playerlist.qc` patterns; modal `VGUI_Active()` block is acceptable for a hold/toggle panel |
| Inset PiP | Second `ncView` render | Reuses spectator camera logic into an inset rect |

### Placement & reusability

- Lives in the **framework** (`src/client/`), not `base/` — every game inherits it; game HUDs can style/override. Consistent with the "minimal reusable Nuclide framework" goal in `AGENTS.md`.
- Always-on chrome is drawn only while the local client is an `ncSpectator`.

## Scope Boundaries

### Deferred for later
- **Inset PiP** is the one genuinely complex element (second scene render). Build it **last**; the rest of the chrome ships independently of it.

### Outside this feature
- **Map overview modes** (`FREEOVERVIEW`/`CHASEOVERVIEW`) — stay remapped/disabled; the `ncRadar` render path remains available if revisited separately.
- Source `.res`-driven UI / importing the leftover `observerlistitem.res`.
- Changes to spectator camera *behavior* (smoothing, cycling logic) — the modes already work.

## Dependencies / Assumptions

- **Assumption (verify in planning):** game-rules timer/score are accessible client-side. If `ncGameRules` doesn't already expose time-left/team-scores to the client, a small read path (serverinfo keys or a networked field) is needed.
- **Assumption:** a second `ncView`/scene render for the inset PiP is feasible at acceptable cost in this FTEQW build — flagged as the reason to build PiP last.
- Reuses existing `vgui_playerlist.qc` widget patterns for the target list.

## Success Criteria

- Entering spectator shows the watching bar, top bar, timer/score, and key hints, all tracking the current target/mode each frame.
- Free-roam mode shows the observer crosshair; chase/first-person modes do not.
- The target list can be toggled and used to switch the spectated player.
- The inset PiP renders a secondary camera without breaking the main spectator view.
- The whole overlay only appears for `ncSpectator` clients and is drawn consistently with Nuclide's in-game HUD.
- Implemented in `src/client/` such that a second game using the framework gets the spectator HUD with no per-game work.

## Resolved Decisions (2026-06-14)

1. **Target list: toggle key.** An explicit toggle command (e.g. `showObservers`) opens/closes the interactive list, consistent with the other VGUI panels registered in `src/client/cmd.qc` (`showPlayerList`, etc.). Modal `VGUI_Active()` blocking is acceptable while the list is open.
2. **Inset PiP: toggleable, default first-person of the current target.** A user bind shows/hides the inset; when shown it renders first-person of the currently spectated entity (CSO `insetBox` behavior). Still built **last** (second `ncView` render pass; `View.qc` already branches on `spec.m_spectatingMode`).
3. **Use the existing spectator draw branch.** `CSQC_Update2D` already calls `HUD_DrawSpectator()` when `Client_IsSpectator(cl)` is true (`src/client/entry.qc`), forwarded through `src/client/hud.qc` → `hud.dat`. The game-side export `HUD_DrawSpectator(vector hud_mins, vector hud_size)` in `base/src/hud/hud.qc` is an empty stub to fill. **Signature mismatch to resolve in planning:** the framework loader expects `void HUD_DrawSpectator(void)` (`src/client/api_func.h`); either add a `void(void)` wrapper in `base/src/hud/hud.qc` that derives `screen.HUDMins()`/`screen.HUDSize()` (as `HUD_Draw()` does), or draw the chrome from `src/client/` directly.

### Additional planning notes (verified during investigation)

- **Timer/score data is already client-side** — no new netcode. Use `serverkey("teamscore_%i")` (`src/client/api.qc`), `Util_GetTime()`/`Util_GetTimeLeft()` (`src/shared/system/util.qc`), and `serverinfo.GetString("hostname")` + `mapname` (same sources as `Scores_Draw`).
- **Mode-cycle input is missing** in current `src/shared/game/Spectator.qc`: `ncSpectator::ProcessInput()` handles only `INPUT_PRIMARY` (next) / `INPUT_SECONDARY` (prev). Restore `INPUT_JUMP` → `InputMode()` when wiring the key-hint guide so the displayed "change mode" hint is functional.
