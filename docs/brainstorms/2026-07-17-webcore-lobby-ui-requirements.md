---
date: 2026-07-17
topic: webcore-lobby-ui
---

# WebCore Lobby UI

## Summary

Replace the WebCore title menu’s Map Browser and Create Server entries with Create Lobby and Join Lobby. Join opens a multi-method dialog (room code, address, LAN list) where only LAN works for now; create and successful LAN join both land on a minimal in-session lobby room matching the existing VGUI twin. Visual chrome follows the basemod-foundation look: semi-transparent panels and Trade Gothic.

---

## Problem Frame

Pre-game lobbies are being brought up in the engine, but the only workable UI today is a thin, brittle menu-VGUI shell, while the live title surface is already WebCore. Players (and the developer iterating on lobbies) need create/join entry points on that title surface without depending on MenuQC VGUI or classic Create Server / Map Browser flows that do not match the lobby session model.

---

## Actors

- A1. Host player: creates a LAN lobby from the title menu, waits in the session room, starts when ready.
- A2. Joining player: opens Join Lobby, picks a LAN lobby from the list, enters the same session room, can Ready / Leave.
- A3. Engine lobby session: owns room/player/ready/start/leave state consumed by the UI.

---

## Key Flows

- F1. Create Lobby
  - **Trigger:** Title menu “Create Lobby”
  - **Actors:** A1, A3
  - **Steps:** Player activates Create Lobby → engine creates a LAN lobby session → UI switches to the in-session lobby room → roster and status update while the session is live
  - **Outcome:** Host is in the session room for an active LAN lobby
  - **Covered by:** R1, R2, R6, R7, R8

- F2. Join Lobby (LAN)
  - **Trigger:** Title menu “Join Lobby”
  - **Actors:** A2, A3
  - **Steps:** Join dialog opens with all join methods listed → player refreshes/selects a LAN lobby → joins → UI switches to the in-session lobby room
  - **Outcome:** Joiner is in the session room for that LAN lobby
  - **Covered by:** R1, R3, R4, R5, R6, R7, R8

- F3. Leave / close session
  - **Trigger:** Leave in the session room, or session ends
  - **Actors:** A1 or A2, A3
  - **Steps:** Player leaves (or session closes) → return to the WebCore title menu
  - **Outcome:** No lobby session UI is showing; title menu is active again
  - **Covered by:** R7, R9

---

## Requirements

**Title entry**
- R1. On the WebCore title menu, replace Map Browser with Create Lobby and Create Server with Join Lobby.
- R2. Create Lobby immediately creates a LAN lobby session and opens the in-session lobby room (no create-method dialog in this pass).
- R3. Join Lobby opens a dialog over the title that lists all intended join methods: room code, address, and local LAN servers.

**Join dialog**
- R4. In the join dialog, only the local LAN servers list is interactive and joinable; room code and address methods are visible but grayed out / non-interactive.
- R5. The LAN list supports refresh and join; empty or failed refresh is a normal UI state (not a crash or silent no-op without feedback).

**In-session lobby room**
- R6. After create or successful LAN join, show a VGUI-twin session room: room identity, host, state, player count, roster names, and Ready / Start / Leave actions.
- R7. Session room actions drive the existing engine lobby session behavior (ready, start, leave/close); no map or ruleset picker in this pass.
- R8. Session room content stays in sync with live lobby session state while the room is shown.
- R9. Leaving or closing the lobby returns the player to the WebCore title menu.

**Visual**
- R10. Lobby UI chrome (join dialog and session room) follows the basemod-foundation layout language: basic semi-transparent panels and Trade Gothic (same font family used there), not H3 or title/pause decorative styling.

---

## Acceptance Examples

- AE1. From a cold title menu, activating Create Lobby places the host in the session room with a live LAN lobby (room/host/roster visible).
  - **Covers:** R1, R2, R6, R8

- AE2. From the title menu, Join Lobby shows room code, address, and LAN list; room code and address cannot be used; a LAN entry can be refreshed and joined into the same session room shape as create.
  - **Covers:** R3, R4, R5, R6

- AE3. Leave from the session room returns to the title menu with Create Lobby / Join Lobby still available.
  - **Covers:** R9, R1

- AE4. When no LAN lobbies are found after refresh, the join dialog remains usable and communicates the empty state without enabling the grayed methods.
  - **Covers:** R4, R5

---

## Success Criteria

- Create Lobby and Join Lobby are the two multiplayer entry points on the WebCore title menu (replacing Map Browser and Create Server for this surface).
- A host can create a LAN lobby and a second local client can join it via the LAN list, both ending in the VGUI-twin session room.
- Grayed join methods are present and clearly unavailable without implying they work.
- Leave reliably returns to the title menu.
- Visuals read as basemod-foundation panels + Trade Gothic, not as a title-menu clone or H3 lobby.

---

## Scope Boundaries

- Working room-code or address join
- Full Find Servers / Internet / History / Spectate browser
- H3 or Slint visual lobby polish
- Serverless / ICE transport work
- In-map RuleC lobby overlay
- Classic Create Server (`map`) from these two title buttons
- Create-method dialog (online vs LAN vs offline)

---

## Key Decisions

- Approach A: title remains home; join is a dialog; create/join land on one session-room surface.
- In-session UI is a VGUI twin (fields/actions), not a richer visual lobby.
- Join dialog shows future methods now, with only LAN operational.
- Visual reference is basemod-foundation (semi-transparent panels + Trade Gothic), not title/pause or H3.

---

## Dependencies / Assumptions

- Engine pre-game lobby session (LAN create/join, ready/start/leave, synced lobby state) remains the backend; this work is UI + wiring, not a new lobby protocol.
- Menu VGUI lobby may stay as reference/fallback but is not the primary path once WebCore lobby ships.
- Trade Gothic is available in the WebCore environment the same way basemod-foundation expects (system / existing font setup; no new `@font-face` crash path).

---

## Outstanding Questions

None blocking planning. Deferred product choices (room-code/address join UX details, create-method dialog) wait until those methods are enabled.
