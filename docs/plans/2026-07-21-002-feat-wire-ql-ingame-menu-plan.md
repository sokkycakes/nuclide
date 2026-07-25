---
title: "feat: Wire QL in-game menu demo for WebCore testing"
type: feat
status: draft
date: 2026-07-21
origin: conversation in demos/ql-ingame-menu/ (agent-transcripts/8af9760b-81c5-47d9-9f55-f97b3aa15d6b)
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
execution: code
---

# feat: Wire QL in-game menu demo for WebCore testing

## Goal Capsule

**Objective:** Make the Quake Live in-game menu Canvas demo (demos/ql-ingame-menu/) actually functional when loaded
through WebCore in the FTE engine — not a fully production menu, but a testable demo where JOIN MATCH / JOIN RED /
JOIN BLUE / SPECTATE send real engine commands, Esc closes the menu, and the warmup/esc UI is navigable in-game.

**Authority:** Existing WebCore menu infrastructure (m_webcore_menu.c), window.fte_query bridge (see
base/data/web/pause-menu/app.js), and the QL demo canvas implementation in demos/ql-ingame-menu/app.js.

**Stop when:** Loading menu_webcore fte://data/web/ql-menu/index.html in-game shows the warmup/join panel;
clicking JOIN MATCH actually puts you on a team; Esc closes the menu; demo still opens standalone in a browser for
offline layout work.
r

## Product Contract

### Summary

A lightweight, in-game-testable variant of the QL warmup + esc menu Canvas page. Assets live under
base/data/web/ql-menu/ (not demos/ql-ingame-menu/). The Canvas app.js gains a cbuf() bridge that sends real
engine commands via window.fte_query when loaded in WebCore, while keeping a demoMode flag so the page still
works standalone in a browser for layout iteration.

### Requirements

- **R1.** The QL menu loads in WebCore at menu_webcore fte://data/web/ql-menu/index.html or by setting
  webcore_menu_url temporarily for testing.
- **R2.** All join/spectate buttons send real team r, team b, team a, team s commands.
- **R3.** The ready toggle sends cbuf(\"ready\").
- **R4.** Esc key in the esc-menu view closes the WebCore menu via cbuf(\"webcore_closemenu\").
- **R5.** Esc-menu tab buttons for Controls / Call Vote push real engine menus (menu_options, menu_callvote).
- **R6.** LEAVE MATCH sends cbuf(\"disconnect\").
- **R7.** RETURN TO MATCH closes the menu (webcore_closemenu).
- **R8.** The demo still opens standalone in a browser (no WebCore) with the fake phase machine intact for offline
  layout work. A demoMode flag selects the mode.
- **R9.** The warmup center HUD (WARMUP banner, countdown, FIGHT) is visual-only when in WebCore — real game state
  drives the actual warmup, not the page's fake phase machine.

### Scope Boundaries

- **In scope:** Asset staging under base/data/web/ql-menu/, fte_query bridge wiring, demo-mode guard, keyboard
  and Esc handling for WebCore, test-command documentation.
- **Not in scope:** Hero/class selection panel, full production pause-menu replacement, title menu changes, HUD
  integration, lobby integration, real warmup-state polling from CSQC.
- **Deferred:** Real game-state querying (player count, warmup phase, team assignment) via fte_query getters;
  persistent config cvar for the QL menu URL.

### Key Technical Decisions

- **KTD1.** Page is served from base/data/web/ql-menu/ (VFS path fte://data/web/ql-menu/index.html), loaded
  on-demand via menu_webcore with the full URL. Does not replace webcore_menu_url or the existing pause-menu
  path.
- **KTD2.** demoMode flag (true when window.fte_query is undefined, false otherwise) selects fake vs real
  command dispatch. The fake phase machine (waiting → countdown → fight → live) only runs in demo mode.
- **KTD3.** Commands use the same cbuf wrapper pattern as base/data/web/pause-menu/app.js for consistency.
r
## Implementation Units

### U1. Stage assets under VFS

**Goal:** Copy the QL demo HTML, JS, and asset files into the WebCore-serveable VFS path.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Create: base/data/web/ql-menu/index.html
- Create: base/data/web/ql-menu/app.js
- Create: base/data/web/ql-menu/assets/ (recursively, all files from demos/ql-ingame-menu/assets/)

**Approach:**
- Copy demos/ql-ingame-menu/index.html → base/data/web/ql-menu/index.html
- Copy demos/ql-ingame-menu/app.js → base/data/web/ql-menu/app.js
- Copy entire demos/ql-ingame-menu/assets/ tree → base/data/web/ql-menu/assets/
- Remove the fonts-data.js script tag from index.html and inline it or load it from the new relative path
  (it should still work since assets/ is at the same relative depth).
- Update the HTML <title> and help-text line to reflect "WebCore test" rather than "Canvas demo".

**Patterns to follow:** base/data/web/pause-menu/index.html — same VFS location pattern, relative asset paths.

**Test scenarios:**
- Open fte://data/web/ql-menu/index.html in a browser directly (via file:// or local server) — page renders,
  Canvas draws the warmup UI.
- menu_webcore fte://data/web/ql-menu/index.html in-engine loads the page without errors.

**Verification:** Both browser and in-engine paths show the QL warmup/join UI with no 404s in engine or browser
console.r

### U2. Wire fte_query command bridge

**Goal:** Replace stub/toy commands in app.js with real engine commands via window.fte_query, and add a
demoMode flag to preserve standalone browser operation.

**Requirements:** R2, R3, R7, R8, R9

**Dependencies:** U1 (asset staging)

**Files:**
- Modify: base/data/web/ql-menu/app.js

**Approach:**
- Add a cbuf(cmd) helper that calls window.fte_query when available and returns a boolean, same as
  base/data/web/pause-menu/app.js uses.
- Set state.demoMode = typeof window.fte_query !== "function" at init. This controls whether fake commands
  and the phase machine run.
- Replace setMyTeam() stub bodies with real cbuf("team r|b|a|s") calls per the mapping below. Keep the
  state.showJoinPanel = false logic (set when joining, reset to true when spectating).
- Replace warmup wJoinMatch / wJoinRed/Blue/Auto / wSpecNav click handlers to call cbuf() instead of
  setMyTeam() + toast().
- Replace Esc-menu tab buttons (About, Controls, Settings, Call Vote) with real commands:
  `
  Controls → cbuf("menu_options")
  Settings → cbuf("menu_options")
  Call Vote → cbuf("menu_callvote")
  `
  About (Current Match) needs no command — it is informational.
- Replace bottom LEAVE MATCH with cbuf("disconnect").
- Replace RETURN TO MATCH with state.open = false then cbuf("webcore_closemenu").
- Add ready-toggle cbuf("ready") for the warmup ready button.
- Guard the fake phase machine (tickWarmup, readyCount, playingCount, phase transitions) behind
  if (state.demoMode) so it does not run in WebCore. In WebCore, the warmup HUD text remains visible as
  static art but does not trigger countdown/fight state changes.

**Execution note:** Test in-engine after each button group, not all at once. Start with JOIN MATCH (single button
in non-team mode), then team buttons, then Esc navigation, then ready toggle.

**Patterns to follow:** base/data/web/pause-menu/app.js cbuf wrapper and command dispatch.

**Test scenarios:**
- R2: Click JOIN MATCH in non-team warmup → engine executes team a (join action, panel closes).
- R2: Click JOIN RED / BLUE / AUTO in team-mode warmup → team r/b/a.
- R2: Click SPECTATE → engine executes team s, join panel re-appears.
- R3: Click CLICK TO READY → engine sees ready command.
- R4: Press Esc in esc-menu view → webcore_closemenu runs, menu unlinks.
- R5: Click Controls tab → engine options menu opens.
- R5: Click Call Vote tab → engine callvote menu opens.
- R6: Click LEAVE MATCH → disconnect.
- R7: Click RETURN TO MATCH → menu closes.
- R8: Open index.html in browser → demoMode is true, all stubs/toasts work as before.

**Verification:** All button clicks in-engine produce the expected behavior (team join, menu close, disconnect).
The demo still opens standalone in a browser with no WebCore dependency.r

### U3. Esc key and close-menu wiring

**Goal:** Ensure the keyboard handler in app.js correctly maps Escape to close the WebCore menu when in the esc
view, and does not conflict with engine-level Esc handling.

**Requirements:** R4, R7

**Dependencies:** U2

**Files:**
- Modify: base/data/web/ql-menu/app.js

**Approach:**
- In the keydown handler: when e.key === "Escape" and the page is showing the esc menu view (state.view ===
  "esc" && state.open), call cbuf("webcore_closemenu") and e.preventDefault().
- Return to game (closing the esc menu) also works via the RETURN TO MATCH button calling
  cbuf("webcore_closemenu").
- Ensure the Escape key is NOT swallowed when the page is in warmup/join view (so the engine's own Esc handling
  is not blocked).
- In demoMode (browser), Escape still closes the esc view locally as before.

**Patterns to follow:** base/data/web/pause-menu/app.js line ~69 (Escape → cbuf("webcore_closemenu")).

**Test scenarios:**
- Press Esc while in esc-menu view → menu unlinks, game view returns.
- Press Esc while in warmup view in-engine → Esc is not consumed by the page, engine opens the pause menu
  (or nothing if no other menu handler).
- Press Esc in standalone browser → esc view closes locally.

**Verification:** In-engine, pressing Esc from the esc menu view returns to the game. In browser, Esc closes
the esc view and shows the warmup view.r

## Verification Contract

### Smoke Test (in-engine)

1. Connect to a local or LAN server (or load a map).
2. In console: menu_webcore fte://data/web/ql-menu/index.html
3. Verify: warmup/join panel renders with correct layout, no console errors from WebCore.
4. Click JOIN MATCH (or JOIN RED/BLUE in team mode).
5. Verify: you join the game, the join panel closes, the warmup center HUD (text only) remains.
6. Press Esc.
7. Verify: the QL esc menu opens with tabs.
8. Click RETURN TO MATCH or press Esc.
9. Verify: menu closes, game view returns.
10. Open menu again, click LEAVE MATCH.
11. Verify: disconnect.

### Smoke Test (standalone browser)

1. Open base/data/web/ql-menu/index.html directly in a browser.
2. Verify: warmup UI renders, join/spectate buttons show toasts (not errors), Esc toggles esc menu view,
   phase machine runs and advances to countdown/fight/live.

## Definition of Done

- [ ] All U1–U3 files created/modified and committed.
- [ ] Smoke test in-engine passes all steps.
- [ ] Smoke test standalone browser passes.
- [ ] No engine or WebCore console errors during menu interaction.
- [ ] The existing demos/ql-ingame-menu/ is unchanged (original demo preserved).

## Risks and Dependencies

- window.fte_query is only available when the page is loaded through WebCore's cinematic shader path. The
  demoMode guard correctly detects its absence.
- The QL menu page at fte://data/web/ql-menu/index.html is loaded on-demand via menu_webcore <url>. The
  user must type or bind this command — no autoexec changes are part of this plan.
- The fake phase machine is a demo aid only. In WebCore mode, warmup state comes from the actual game server.
  The page does not try to read or display real warmup countdown state.r
