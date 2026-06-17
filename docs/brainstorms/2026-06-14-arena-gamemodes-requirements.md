---
date: 2026-06-14
topic: arena-gamemodes
---

# Arena Gamemodes — Queue, Spectator, and Round Foundation

## Summary

Build a generic **arena match director** that owns queue management, spectator promotion, and the round/match state machine, with thin per-mode rules plugging in via hooks and configuration (team shape, promotion policy, round rules). **Duel** is the first mode to prove the foundation; Freeze Tag, Archstiletto, and Duel Minus are subsequent plug-ins.

---

## Problem Frame

Nuclide ships several multiplayer rulesets (deathmatch, teamdm, domination, LMS) but none support structured arena play: a waiting queue, spectator rotation, round-based matches on a single map, or mode-specific win conditions layered on shared pacing. The game needs multiple competitive modes — Duel, Archstiletto, Freeze Tag, Duel Minus — that all share Q3-style duel rotation or fighting-game lobby flow. Without a shared foundation, each mode would reimplement queue logic, spectator promotion, warmup, and round orchestration independently, producing inconsistent UX and high maintenance cost.

Existing infrastructure helps: `ncSpectator` and fake-spec patterns, teamdm's "spawn as spectator until ready" join flow, intermission/map-end, and timelimit/scorelimit. What is missing is a on-map round state machine (WARMUP → COUNTDOWN → LIVE → round/match end → queue rotation) and a queue data model distinguishing ready players, not-ready players, and pure spectators.

---

## Actors

- A1. **Active competitor**: A player currently in the arena fighting in a live round.
- A2. **Queued player (ready)**: A player who has opted into the rotation queue and will be promoted when a slot opens.
- A3. **Queued player (not ready)**: A player present on the server but not currently eligible for promotion (AFK, declined ready, or temporarily unavailable).
- A4. **Pure spectator**: A player watching without entering the rotation queue; never auto-promoted.
- A5. **Match director**: The mode-agnostic subsystem that drives queue state, round/match transitions, and promotion; asks the active mode rules module for mode-specific decisions (round over? who won? what happens on death?).
- A6. **Mode rules module**: The per-gamemode plug-in (e.g. Duel) that declares team shape, promotion policy, and round rules via hooks; does not own queue or state-machine flow.

---

## Key Flows

- F1. **Server boot → warmup**
  - **Trigger:** Arena gamemode loads with fewer than the minimum ready players for a match.
  - **Actors:** A2, A3, A4, A5
  - **Steps:** Director enters WARMUP. Present players spawn into free-play (infinite respawn, no scoring). Queued-ready and not-ready players may practice. Pure spectators observe. UI shows waiting-for-players / ready count.
  - **Outcome:** Arena is playable but no match score is recorded.
  - **Covered by:** R3, R4, R5, R14

- F2. **Ready-up → match start**
  - **Trigger:** Minimum ready players reached for the configured team shape (e.g. 2 for 1v1).
  - **Actors:** A1, A2, A5, A6
  - **Steps:** Director transitions WARMUP → COUNTDOWN. Non-competitors become spectators. Countdown completes → LIVE round 1 of best-of-N begins. Mode rules module applies round-start hooks (spawn placement, loadout, round rules).
  - **Outcome:** First round of a match is in progress with defined competitors.
  - **Covered by:** R3, R4, R6, R7, R8

- F3. **Round play → round end (Duel)**
  - **Trigger:** A competitor is eliminated, or round timer expires.
  - **Actors:** A1, A5, A6
  - **Steps:** On elimination, mode rules declare round winner. On timeout, director enters SUDDEN DEATH: one-hit kills activate; reaper timer eliminates stationary players below speed threshold. Round winner recorded. If match not decided (best-of-N incomplete), director resets arena for next round (competitors respawn, round counter increments). If match decided, proceed to F4.
  - **Outcome:** Round winner known; either next round begins or match ends.
  - **Covered by:** R9, R10, R11, R12, R29, R30

- F4. **Match end → queue rotation**
  - **Trigger:** A player wins the best-of-N match.
  - **Actors:** A1, A2, A4, A5, A6
  - **Steps:** Director records match winner. Loser moves to back of ready queue (FIFO). Winner stays as active competitor. Next ready player(s) per team shape promoted from queue. If insufficient ready players, return to WARMUP (F1). Otherwise, COUNTDOWN → new match.
  - **Outcome:** Rotation complete; winner remains; new challenger(s) enter.
  - **Covered by:** R2, R10, R11, R28

- F5. **Opt-in / opt-out of queue**
  - **Trigger:** Player toggles ready status or chooses pure-spectate.
  - **Actors:** A2, A3, A4, A5
  - **Steps:** Ready → player joins tail of ready queue (if not already competing). Not ready → removed from promotion eligibility but may remain on server. Pure spectator → removed from queue entirely; never auto-promoted.
  - **Outcome:** Player's queue population is explicit and respected by promotion logic.
  - **Covered by:** R1, R2, R21, R22

---

## Requirements

**Match director (shared foundation)**

- R1. The match director maintains three distinct player populations: ready queue, not-ready (present but ineligible), and pure spectator (opted out of rotation).
- R2. Ready queue ordering is FIFO; promotion always pulls from the front of the ready queue per team-shape slot requirements.
- R3. The match director owns a state machine with at minimum: WARMUP, COUNTDOWN, LIVE, SUDDEN_DEATH (conditional), ROUND_END, MATCH_END. Mode rules modules do not drive transitions directly — they answer queries and receive lifecycle callbacks. MATCH_END is reachable two ways: by a normal match win (R10/R20) and by a mid-match competitor disconnect with **no winner credited** (R28); both paths funnel into promotion / queue rotation.
- R4. In WARMUP, all present non-spectator players may free-play: spawn, move, shoot, and respawn without scoring or match progression.
- R5. WARMUP ends and COUNTDOWN begins when the number of ready players meets the minimum for the configured team shape.
- R6. COUNTDOWN removes non-competitors to spectator state before LIVE begins.
- R7. LIVE round behavior is delegated to the mode rules module via hooks (round-start setup, death handling, round-win test, round-end cleanup).
- R8. Between rounds within a match (best-of-N not yet decided), the director resets the arena for the next round without queue rotation.
- R9. When a round timer expires without elimination, the director enters SUDDEN_DEATH and notifies the mode rules module to apply sudden-death rules.
- R10. On match completion, the director executes promotion policy: winner stays, loser to back of queue, next ready player(s) promoted per team shape.
- R11. If insufficient ready players remain after match end, the director returns to WARMUP rather than forcing a match.
- R12. The match director is parameterized by **team shape** (1v1, 2v2, 1-vs-many) and **promotion policy** (default: winner stays, loser rotates). Team shape determines minimum ready count and slots to fill on promotion.
- R28. If a competitor disconnects during an active match (in COUNTDOWN, LIVE, SUDDEN_DEATH, or ROUND_END within a match), the director ends the match immediately via MATCH_END with **no winner credited** — the remaining competitor does **not** receive an automatic win (this is intentionally not a forfeit-to-survivor). The director then cleans up the vacated competitor slot and any queue entry so no phantom competitor or leaked slot remains, promotes the next queued player(s) per team shape, and starts a **fresh match** (COUNTDOWN if enough ready players, otherwise WARMUP per R11). The server/match continues running as long as the host/listen-server player remains.

**Mode plug-in interface**

- R13. Each arena gamemode is a thin rules module that declares team shape, promotion policy, best-of-N count, and round rules via configuration and hooks — not by reimplementing queue or state-machine logic.
- R14. Mode hooks must cover at minimum: round-start setup, player death / incapacitation handling, round-win determination, round-end cleanup, and sudden-death rule application.
- R15. Modes that are config variants of an existing mode (e.g. Duel Minus vs Duel) differ only in hook behavior and configuration, not in director logic.

**Duel (v1 proving mode)**

- R16. Duel uses team shape 1v1, promotion policy winner-stays, and best-of-N rounds (N configurable).
- R17. Each Duel round is single elimination: killing the opponent wins the round.
- R18. On round timeout, sudden death activates: all hits are lethal (one-hit kills).
- R19. During sudden death, a reaper timer eliminates any player whose movement speed remains below a configurable threshold; the timer resets or clears when speed rises above threshold.
- R20. A Duel match runs best-of-N rounds (N configurable). Round points accumulate per competitor, including drawn rounds that score both players (R29). After the configured N rounds, the competitor with the higher round-point total wins; if the competitors are tied, the match is resolved by a tiebreaker round (R30). This replaces a strict odd-N / simple-majority constraint: because draws award points to both players, a tie is possible at any N, and the tiebreaker is the general resolution.
- R29. When both competitors die in the same round (simultaneous mutual kill — guaranteed possible under sudden-death one-hit kills), the round is a **draw**: each competitor is awarded one round point and the round counter advances normally. The match proceeds; neither competitor is eliminated by a drawn round.
- R30. If the competitors are tied on round points after the configured N rounds, the match is resolved by a **tiebreaker round**: a single sudden-death round with **no round time limit** (the reaper anti-stall mechanic from R19 still applies, but no round timer ends it — it runs until a competitor dies). If a tiebreaker round itself ends in a simultaneous-death draw, another tiebreaker round is played until the tie is broken.

**Spectator and queue UX**

- R21. Players can toggle ready / not-ready without disconnecting.
- R22. Players can enter pure-spectator mode and will never be auto-promoted until they explicitly ready up.
- R23. Eliminated competitors and rotated-out players transition to an appropriate spectator state (fake-spec or real spec per existing patterns) until promoted or they change queue status.
- R24. Queue position, ready count, match state (warmup / countdown / round N of M / sudden death), and current competitors are visible to all connected players.

**Future plug-in modes (designed for, not v1 deliverables)**

- R25. Freeze Tag will use team shape 2v2, shared round/match pacing with Duel, and freeze-on-hit instead of elimination as its death hook behavior.
- R26. Archstiletto will use team shape 1-vs-many (one boss vs multiple challengers) with asymmetric mode hooks; the director treats slot assignment asymmetrically but uses the same queue and state machine.
- R27. Duel Minus will be a Duel config variant: each weapon limited to 2 magazines total, no infinite ammo; a single map ammo pickup restores ammo to full.

---

## Acceptance Examples

- AE1. **Covers R1, R2, R5, F2.** Given 3 players on server (P1 ready, P2 ready, P3 pure spectator) in 1v1 Duel, when both P1 and P2 are ready, countdown starts with P1 and P2 as competitors; P3 remains spectating and is not promoted.
- AE2. **Covers R4, R11, F1.** Given 1 player on server in 1v1 Duel, when they are ready, the arena stays in WARMUP free-play with no match scoring until a second ready player joins.
- AE3. **Covers R8, R16, R20, F3.** Given a best-of-3 Duel match at 1-1, when P1 eliminates P2 in round 3, the match ends with P1 as match winner; no further round is played.
- AE4. **Covers R9, R18, R19, F3.** Given a Duel round where neither player has eliminated the other when the round timer expires, sudden death activates with one-hit kills; a player who stops moving below the speed threshold is eliminated by the reaper timer.
- AE5. **Covers R10, R13, F4.** Given P1 wins a best-of-3 match against P2, P1 stays as active competitor, P2 moves to the back of the ready queue, and the next ready player in queue is promoted to challenge P1.
- AE6. **Covers R22, F5.** Given P3 is in pure-spectator mode, when a match ends and a queue slot opens, P3 is not promoted even if they are the only available player.
- AE7. **Covers R21, F5.** Given P2 is in the ready queue but toggles to not-ready during an active match, P2 is not promoted when the next slot opens; P2 may still free-play during WARMUP.
- AE8. **Covers R28, R10, R11, F4.** Given an active best-of-N Duel match (P1 vs P2) in LIVE, when P2 disconnects mid-match, the match ends immediately with **no winner credited** (P1 is NOT awarded the match); the director cleans up P2's vacated slot and queue entry, promotes the next ready player from the queue, and starts a fresh match in COUNTDOWN — or returns to WARMUP if no other ready player exists. The server keeps running with the host player present.
- AE9. **Covers R29, F3.** Given a Duel round in sudden death where P1 and P2 land mutually lethal one-hit kills on the same frame, the round is scored as a draw: both P1 and P2 are awarded one round point, the round counter advances, and neither is eliminated from the match.
- AE10. **Covers R30, R20, F3.** Given a best-of-N Duel match tied on round points after the configured N rounds (e.g. 1–1 in best-of-2, or any tie produced by drawn rounds), the director plays a tiebreaker round: a single sudden-death round with **no time limit** (reaper still active) that runs until one competitor dies and wins the match.

---

## Success Criteria

- A developer can add a new arena mode (e.g. Freeze Tag) by writing a thin rules module and configuration — without modifying match director logic.
- Duel playable end-to-end on a single map: join → warmup → ready → countdown → best-of-N rounds with sudden death → winner stays / loser rotates → next challenger.
- Queue and spectator behavior is consistent and predictable: ready vs not-ready vs pure spectator is always respected.
- A downstream planner (`ce-plan`) can derive implementation tasks from this doc without inventing product behavior for queue flow, state transitions, or Duel round rules.

---

## Scope Boundaries

- v1 delivers the match director foundation and Duel as the proving mode.
- Freeze Tag, Archstiletto, and Duel Minus are designed as future plug-ins (requirements R25–R27 define their shape) but are not v1 deliverables.
- Cross-server matchmaking, ranked ladders, and ELO are out of scope.
- Bot backfill for solo warmup or queue is out of scope.
- Map rotation and intermission changes beyond existing infrastructure are out of scope.
- Hero roster / class selection UX is out of scope; reuse existing teamdm patterns where a mode needs loadout choice.

---

## Key Decisions

- **Hybrid architecture (A + C)**: A shared arena base owns the match director (queue + state machine, decoupled from mode logic); each gamemode is a thin rules module with hooks and config. Rationale: avoids god-object config (pure B) while staying idiomatic to Nuclide's RuleC one-progs-per-gametype model (pure C alone).
- **Generic from the start**: Team shape and promotion policy are director parameters, not hardcoded for Duel. Rationale: all four target modes share queue/spectator UX; building Duel-only would require refactor when Freeze Tag ships.
- **Duel first**: Duel proves the foundation before other modes. Rationale: simplest team shape (1v1), clearest rotation policy, and the user's stated priority.
- **Three queue populations**: Ready, not-ready, and pure spectator are distinct. Rationale: fighting-game lobby UX requires opt-in rotation; auto-promoting watchers breaks the social contract.
- **Winner stays, best-of-N, loser rotates**: Default promotion policy for Duel. Rationale: classic Q3 duel pacing; user-specified.
- **Warmup free-play**: Present players practice freely until minimum ready count. Rationale: avoids dead air on low-pop servers; user-specified.
- **Sudden death with reaper anti-stall**: Timeout triggers one-hit kills plus speed-threshold elimination. Rationale: aggressive pacing; prevents stalling; user-specified distinctive mechanic.
- **Duel Minus as config variant**: Not a separate foundation. Rationale: differs only in ammo rules; validates the hook/config model.
- **Mid-match disconnect ends the match with no winner (R28)**: A competitor leaving an active match voids that match — the survivor is **not** credited an automatic win, by design. Rationale: an unearned forfeit-win distorts winner-stays standings and rewards opponents for quitting; voiding the match and immediately promoting the next challenger keeps the server live and the rotation fair without granting a hollow victory. The director, not the mode, owns this so it applies to all arena modes.
- **Drawn round awards both competitors a point (R29)**: Simultaneous mutual kills are guaranteed possible under sudden-death one-hit kills, so the round-scoring semantics must define them. Rationale: awarding both a point (rather than replaying or arbitrarily picking a winner) is deterministic and order-independent; the round counter still advances so matches can't stall on repeated draws.
- **Tiebreaker round, no time limit (R30)**: Ties after N rounds are resolved by a single sudden-death round with no round timer (reaper still applies). Rationale: with draws awarding points to both players, ties are possible at any N, so a general resolution is needed rather than constraining to odd N; removing the timer guarantees the tiebreaker produces a death (and thus a result), while the reaper still prevents stalling.

---

## Dependencies / Assumptions

- Existing `ncSpectator`, `MakeTempSpectator()`, and teamdm join-as-spectator patterns are reused rather than rebuilt.
- Existing RuleC / `ncRuleDelegate` callback hub (`g_grMode`) remains the integration point; the match director extends or wraps this, not replaces it.
- Existing intermission/map-end (`IntermissionStart`, `nextmap`) is unchanged; arena modes run multiple matches per map load without triggering map rotation.
- `g_gametype` cvar continues to select which rules module loads.
- No on-map round state machine exists today; this is net-new work (verified against codebase exploration).

---

## Outstanding Questions

### Deferred to Planning

- [Affects R12, R25, R26][Technical] Exact hook surface API for mode rules modules — which `CodeCallback_*` points are extended vs which director methods are called from shared includes.
- [Affects R24][Technical] How queue/match state is communicated to clients (HUD elements, centerprint, VGUI panel, or RmlUI overlay).
- [Affects R19][Technical] Exact speed threshold, reaper timer duration, and reset behavior for the anti-stall mechanic — tunable cvars vs fixed constants.
- [Affects R16][Technical] Default best-of-N value for Duel and whether it is a cvar or per-mode config.
- [Affects R6, R23][Technical] Whether eliminated competitors use fake-spec or real-spec, and whether they retain chase-cam of the ongoing match.
- [Affects R27][Needs research] How ammo limits interact with existing weapon/inventory systems — magazine count enforcement point and pickup entity wiring for Duel Minus.
