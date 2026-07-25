---
date: 2026-07-17
topic: serverless-lobby-session
---

# Serverless Pre-Game Lobby Session

## Summary

Replace the broken pre-game lobby with a real serverless session that works on LAN, same-machine testing, and online—using proven FTE/KEX-style session patterns (no listen server, no map until start)—and ship a basemod-layout WebCore lobby UI around create/join, roster, ready, countdown-to-start, and map pick.

---

## Problem Frame

Pre-game lobbies are meant to behave like Quake Kex, L4D, or Halo: players gather in a session room, see each other, ready up, pick what to play, then the game starts. Nuclide already has lobby session APIs, WebCore title/lobby UI, and FTE already contains KEX-style lobby transport plus ICE for online peering. What players actually experience today is a fragile custom lobby path where joiners stick on empty/joining state, ready/roster do not stay in sync, and the UI cannot be trusted as a source of truth. Patching that path further has not produced a dependable LAN or same-machine loop, and the product still needs the same session model to work online later without starting a map or listen server during the lobby phase.

---

## Actors

- A1. Host player: creates a lobby, owns map pick and start/cancel-countdown, leaves or closes the session.
- A2. Joining player: finds or addresses a lobby, joins the session room, readies, leaves.
- A3. Lobby session system: owns pre-game membership, ready state, map selection, countdown, and the transition into loading the game—without a listen server or loaded map while in lobby.
- A4. WebCore lobby UI: presents create/join and the basemod-layout session room; mirrors live session state.

---

## Key Flows

- F1. Create lobby
  - **Trigger:** Title menu Create Lobby
  - **Actors:** A1, A3, A4
  - **Steps:** Host creates a LAN (or later online) session → session becomes active with host in the roster → UI opens the basemod session room → host can pick map and wait for joiners
  - **Outcome:** Host is in an active pre-game lobby with no map loaded
  - **Covered by:** R1, R2, R8, R9, R14

- F2. Join lobby (LAN / address / same-machine)
  - **Trigger:** Title menu Join Lobby → LAN list or direct address
  - **Actors:** A2, A3, A4
  - **Steps:** Joiner discovers or enters host address → joins session → receives seat and full roster → UI opens the same session room shape as create
  - **Outcome:** Joiner and host both see a shared roster; no map is loaded yet
  - **Covered by:** R1, R3, R4, R5, R8, R9, R14

- F3. Ready and countdown start
  - **Trigger:** Players toggle Ready until all are ready
  - **Actors:** A1, A2, A3, A4
  - **Steps:** Each player’s ready state syncs to everyone → when all are ready, a short countdown begins → UI shows countdown → host may cancel → if cancel, return to waiting with ready states preserved or reset per R12 → if countdown completes, session commits to start
  - **Outcome:** Either back in lobby waiting, or game-start transition begins
  - **Covered by:** R6, R10, R11, R12, R13

- F4. Game start transition
  - **Trigger:** Countdown completes (all-ready path)
  - **Actors:** A1, A2, A3, A4
  - **Steps:** Session signals game starting with the selected map → host brings up the game server/map only now → joiners leave the lobby channel and connect to the game → lobby UI yields to loading/in-game
  - **Outcome:** Everyone is loading or in the chosen map; lobby phase is over
  - **Covered by:** R7, R11, R13, R14

- F5. Leave / abandon
  - **Trigger:** Leave in session room, or host closes lobby
  - **Actors:** A1 or A2, A3, A4
  - **Steps:** Player leaves (or host closes) → peers update roster → leavers return to title menu
  - **Outcome:** No stale “active lobby” UI; remaining players see the updated roster (or lobby ends if host left, per R15)
  - **Covered by:** R9, R15

---

## Requirements

**Session model**
- R1. The lobby is a pre-game session with no listen server and no map loaded until start commits.
- R2. One session architecture must support LAN, same-machine testing, and online; first hard validation may prioritize LAN/same-machine, but online must not require a rewrite.
- R3. Prefer proven FTE/Nuclide approaches (KEX-style lobby session semantics and existing ICE/online peering where applicable) over inventing a new fire-and-forget lobby protocol.

**Create / join**
- R4. Host can create a lobby from the WebCore title menu and land in the session room.
- R5. Joiners can join via LAN discovery and via direct address; same-machine join against localhost must work for two clients.
- R6. After join, both sides show the same roster (names, host marker, ready state) without requiring a Ready click to “populate” seats.

**In-session behavior**
- R7. Host can select the map to load; joiners see the current map pick while still in lobby.
- R8. Each player can toggle Ready; ready state syncs to all peers.
- R9. When all players are ready, a short countdown to start begins automatically.
- R10. Host can cancel an active countdown; after cancel, the lobby returns to waiting without starting the map.
- R11. When countdown completes, only then may the host start the game server/map and peers transition into connect/load for that map.
- R12. Host has Start/Leave controls appropriate to basemod lobby UX; Leave returns to the WebCore title menu.
- R13. If the host leaves or closes the lobby, the session ends for joiners (they return to title with clear feedback).

**UI**
- R14. WebCore lobby UI (join surfaces and in-session room) uses the basemod GameLobby layout language (foundation/wireframe look), not H3 decorative chrome.
- R15. Session room stays live-synced while open (roster, ready, map, countdown/cancel, connection/leave events).

**Deferred capabilities (explicit non-goals for this cut)**
- R16. Lobby chat is deferred.
- R17. Rules / game-options editing beyond map pick is deferred.

---

## Acceptance Examples

- AE1. **Covers R1, R4, R14.** Given a cold title menu, when the host creates a lobby, they enter the basemod session room with themselves on the roster and no map loaded.
- AE2. **Covers R5, R6, R15.** Given a host lobby on the same machine, when a second client joins via `127.0.0.1` (or LAN list), both UIs show both players within a short settle time without either side stuck on a joining placeholder.
- AE3. **Covers R8, R9.** Given two players in lobby, when both toggle Ready, a countdown begins on both UIs.
- AE4. **Covers R10.** Given an active countdown, when the host cancels, both UIs leave countdown and return to waiting without loading a map.
- AE5. **Covers R7, R11.** Given all ready and countdown completed with map M selected, when start commits, the host loads M and joiners connect into that game; lobby was mapless until that moment.
- AE6. **Covers R12, R13.** Given a joiner in lobby, when the host leaves/closes, the joiner returns to the title menu and is not left in a zombie session room.

---

## Success Criteria

- Two processes on one PC can create/join a lobby, see a shared roster, ready up, cancel or complete countdown, and start into the chosen map without ever loading a map during the lobby phase.
- The same session model is credible for online (room-code / ICE path) without a second lobby redesign.
- A planner can implement without inventing ready/countdown/start rules or UI scope; basemod layout is the visual contract.

---

## Scope Boundaries

- No listen-server or background-map lobby.
- No full matchmaking, friends list, invites, or party system.
- No lobby chat in this cut.
- No rules/game-options panel beyond map pick in this cut.
- No hard requirement to wire-interoperate with Quake II remaster clients.
- The current custom text lobby datagram path is not the lasting solution.
- Prior WebCore lobby UI brief (`docs/brainstorms/2026-07-17-webcore-lobby-ui-requirements.md`) remains prior art for title entry patterns; this doc supersedes it for session behavior and UI target (basemod full session room).

---

## Key Decisions

- **Serverless pre-game only:** Map/server exist only after start commit.
- **Proven stack over novelty:** Rebuild on FTE/KEX-style session semantics (and ICE for online), not another ad-hoc unreliable lobby protocol.
- **Universal topology:** LAN, same-machine, and online share one session architecture.
- **All-ready countdown with host cancel:** Ready is mandatory gating; host can abort the timer.
- **Map pick in; chat and rules out** for the prove-it cut.
- **Basemod layout for WebCore lobby UI.**

---

## Dependencies / Assumptions

- FTE already contains KEX lobby session machinery and ICE/broker peering usable as reference or backbone.
- Basemod GameLobby wireframes/foundation under `base/data/web/basemod-wireframes-foundation/` (and related L4D2/ASW lobby wireframes) define the UI layout target.
- Existing WebCore title create/join entry points can be reused or reshaped to feed the new session room.

---

## Outstanding Questions

### Deferred to Planning

- [Affects R2, R3][Needs research] Which existing FTE path (KEX lobby tunnel, ICE datachannel, or a thin reliable LAN channel copying KEX semantics) is the smallest proven backbone that covers LAN + same-machine + online without listen-server?
- [Affects R9, R10][Technical] Countdown length default and whether cancel clears ready states or only aborts the timer.
- [Affects R5][Technical] Exact LAN discovery vs direct-address UX polish for the basemod join surface.
- [Affects R11][Technical] How joiners learn the post-start game connect address/port once the host brings the server up.
- [Affects R14][Technical] How much of the basemod GameLobby wireframe ships in WebCore for v1 vs a reduced layout that still reads as basemod.
