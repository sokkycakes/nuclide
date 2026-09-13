---
title: "Arena / Duel rules foundation (state machine, participation, results)"
date: 2026-08-24
type: refactor
severity: high
module: "Arena director / Duel rules"
category: gameplay
affected_runtime: FTEQW-RuleC
tags:
  - quakec
  - arena
  - duel
  - rules
problem_type: architecture
status: resolved
related:
  - docs/plans/2026-08-24-001-refactor-arena-duel-rules-foundation-plan.md
  - docs/solutions/runtime-errors/csqc-viewmodel-invisible-after-arena-spectate.md
---

# Arena / Duel rules foundation

## Summary

Arena is now the authoritative multiplayer-rules director: one transition function owns lifecycle, one participation function owns queue/roster membership, results are explicit (`NONE`/`WIN`/`DRAW`/`VOID`), and Duel sudden-death policy (one-hit + reaper) lives in Duel hooks. Nuclide spawn/class/prediction is unchanged. Waiting/queued players still never `ChangeToClass("spectator")`.

Compile gate (from nuclide root / `base/src/rules`):

```text
fteqcc.exe duel.src     → base/progs/duel.dat   (0 warnings)
fteqcc.exe progs.src    → base/progs.dat        from base/src/server (pre-existing warnings only)
```

`arena_invariants` defaults to 1 and prints `Arena invariant: ...` on roster/queue failures.

## Code-verified behavior

These are guaranteed by the new control flow, not by a live match:

- `g_arenaState` / `g_arenaStateTime` are assigned only in `Arena_Transition`.
- Disconnect / spectate / play / ready / notready / team-to-spec all call `Arena_ChangeParticipation`.
- Initial countdown competitor loss cancels to `WARMUP` and requeues survivors at the front; after the match has gone live the same loss voids to `MATCH_END` with `ARENARESULT_VOID`.
- `MATCH_END` departures do not rewrite the finalized result.
- `duel.qc` does not read `*arena_state`; it uses `Arena_GetPlayerState` / `Arena_GetState` / `Arena_IsCompetitor`.
- Reaper autocvars and one-hit flags live in `duel.qc` (`Duel_SuddenDeath`, `Duel_SuddenDeathTick`, `Duel_PlayerPain`).
- Dead competitors stay `ARENASTATE_COMPETITOR` while on the fake-spec camera (`Arena_OnPlayerKilled` only demotes the shell).

## In-engine cases still to play

Leave `arena_invariants 1`. Host a 1v1 Duel and walk these:

1. Two ready players enter countdown and begin a normal round (`FIGHT!`).
2. Competitor disconnects during the **first** countdown: survivor requeued, no match result, back to warmup.
3. Same as (2) via `notready` (identical cancel) and via `spectate` (departing player becomes a pure spectator).
4. Competitor leaves during `LIVE` or `SUDDEN DEATH`: `VOID`, no win, survivor keeps queue priority.
5. Competitor leaves during `ROUND END` before match resolution: void.
6. Player leaves during `MATCH END`: result stays; rotation skips the missing player.
7. Player leaves during a **later** inter-round countdown: void (not treated as a never-started matchup).
8. Queued (non-competitor) disconnect/spectate/notready: queue stays valid, competitors untouched.
9. Spam ready/play/spectate: no duplicate queue entries.
10. Winner-stays: winner in front of loser, then remaining queue fill.
11. Round draw awards both a point without becoming a void match result.
12. Round-limit tie → tiebreaker countdown → sudden death (one-hit + reaper).
13. A normal (non-SD) round is unaffected by Duel SD hooks.
14. Spectator → play → hero pick → ready: one Arena participation state at each step; hero change does not double-spawn.
15. HUD `arena_state` / scores / names update on each transition; `arena_result` is `NONE`/`WIN`/`DRAW`/`VOID`.

A hypothetical boss/VSH mode is sketched in `base/src/rules/arena.h` using only the public Arena API and hooks.
