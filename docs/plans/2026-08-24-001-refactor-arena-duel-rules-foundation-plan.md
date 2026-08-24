---
title: Arena / Duel Rules Foundation Refactor
type: refactor
status: active
date: 2026-08-24
---

# Arena / Duel Rules Foundation Refactor

## Summary

Refactor the existing Arena director into the authoritative multiplayer-rules foundation for Stiletto rather than replacing it with FreeHL/FreeCS/TF2 code. Preserve Nuclide-native spawning, player classes, callbacks, and intermission behavior, while importing the architectural guarantees that are currently missing:

- TF2-style centralized state transitions.
- FreeCS-style normalization of “this player stopped participating” events.
- Quake 3-style Duel queue/rotation semantics.
- VSH-style separation between a generic round framework and specialized mode logic.

The primary files are `nuclide/base/src/rules/arena.h`, `arena.qc`, and `duel.qc`. Arena remains the reusable base/framework; Duel becomes a thin specialization and proving ground.

## Implementation Changes

### 1\. Make Arena an authoritative state machine

Add one internal transition operation:

`Arena_Transition(int newState, int reason)`

It becomes the only normal place that changes `g_arenaState` or `g_arenaStateTime`.

Each transition performs, in order:

1. Validate old-state → new-state legality.
2. Run old-state exit responsibilities.
3. Set authoritative state/time/reason.
4. Initialize timers and per-state bookkeeping.
5. Run new-state entry responsibilities.
6. Validate roster/queue invariants.
7. Broadcast the new state once.

Move the existing work in `Arena_EnterWarmup`, `Arena_EnterCountdown`, `Arena_BeginRound`, `Arena_EnterSuddenDeath`, `Arena_ResolveRound`, and `Arena_EndMatch` behind this transition contract. Those helpers may remain as semantic operations, but they must no longer assign `g_arenaState` directly.

Use this allowed lifecycle:

`WARMUP → COUNTDOWN → LIVE → ROUND_END → COUNTDOWN`

with optional:

`LIVE → SUDDEN_DEATH → ROUND_END`

and match completion:

`ROUND_END → MATCH_END → COUNTDOWN/WARMUP`

Cancellation/invalid-roster paths may transition to `WARMUP` before the first live round, or `MATCH_END` with a void result after the match has actually begun.

Track whether the match has entered at least one live round so that an initial countdown cancellation can be distinguished from abandoning an already-running multi-round match.

### 2\. Normalize every participation change

Introduce one semantic operation:

`Arena_ChangeParticipation(entity pl, int newState, int reason)`

All of these paths must use it:

- disconnect
- `spectate`
- `play`
- `ready`
- `notready`
- queue removal
- team-change requests that alter participation
- future admin/mode-driven removals

No callback or mode may directly clear `g_arenaCompetitor[]`, manipulate the queue and player state independently, or infer Arena participation solely from `pl.team`.

Apply these rules:

- `WARMUP`: remove/update the player normally; no match result exists.
- Initial `COUNTDOWN`, before any round has gone live: cancel the pending matchup, requeue surviving competitors at the front in their original order, clear match bookkeeping, and return to `WARMUP`.
- Later `COUNTDOWN`, after at least one completed/live round: losing a competitor voids the current match.
- `LIVE` or `SUDDEN_DEATH`: competitor departure voids the match and transitions to `MATCH_END`.
- `ROUND_END`: competitor departure before match resolution also voids the match.
- `MATCH_END`: the result is already final. A disconnect/spectate removes that player from subsequent rotation but does not retroactively change the result.

For a voided match, surviving competitors retain queue priority and nobody receives a win/loss promotion result.

This removes the present inconsistency where disconnect, spectator, and not-ready paths clear competitors differently.

### 3\. Establish hard roster/queue invariants

Arena owns four semantic player populations:

- `NOTREADY`: not queued, not competing.
- `READY`: exactly once in the ready queue, not in a competitor slot.
- `SPECTATOR`: opted out, not queued, not in a competitor slot.
- `COMPETITOR`: exactly one competitor slot, never simultaneously in the ready queue.

A dead competitor who has been moved into a fake-spectator camera remains semantically `COMPETITOR` until the round/match releases their slot.

Treat physical Nuclide state separately from Arena participation:

- `pl.team`
- temporary spectator/intermission shell
- actual spectator class
- current hero/player class

must not themselves determine queue membership.

Centralize queue insertion/removal and competitor-slot assignment/release behind Arena helpers so duplicate queue entries and half-removed competitors cannot occur.

Add an internal `Arena_ValidateInvariants()` diagnostic check after transitions and participation changes. It should detect and report:

- duplicate queue entries
- player simultaneously queued and competing
- `COMPETITOR` without exactly one slot
- non-competitor occupying a slot
- invalid/null competitor roster during states requiring a full roster
- queue/player-state disagreement

### 4\. Separate lifecycle state from results and causes

Stop using `g_arenaWinnerSlot == 0` plus `g_arenaMatchNoWinner` as the complete result model.

Define explicit constants for:

- result: `NONE`, `WIN`, `DRAW`, `VOID`
- transition/removal reasons: at minimum `NORMAL`, `ROUND_RESOLVED`, `TIME_EXPIRED`, `PARTICIPANT_LEFT`, `NOT_READY`, `SPECTATE`, `DISCONNECT`, `INVALID_ROSTER`, `MATCH_COMPLETE`

Store winner slot separately from result type.

Round resolution and match resolution become distinct semantic operations. A draw, a match with no result, and a match that has not resolved yet must never share the same implicit representation.

Keep the existing `RoundWinTest` return convention initially (`0` ongoing, `-1` draw, positive slot winner) to avoid forcing every mode hook to change at once; normalize that value immediately into the new internal result representation.

`Arena_Promote()` should consume the finalized match result rather than reconstructing intent from scattered booleans.

### 5\. Make state entry/exit responsibilities explicit

Move one-time setup out of per-frame ticks.

State entry owns:

- timers/deadlines
- countdown counters
- spawn/freeplay/fake-spec transitions
- per-round bookkeeping reset
- mode entry hooks
- state/result broadcast

State ticks own only conditions that determine when to leave the current state.

For example:

- `COUNTDOWN` tick counts down and requests the next transition.
- `LIVE` tick evaluates win conditions/time expiry.
- `SUDDEN_DEATH` tick invokes mode sudden-death processing and evaluates the result.
- `ROUND_END` tick chooses another round, tiebreaker, or match resolution.
- `MATCH_END` tick waits for the presentation period and then rotates/requeues players.

This keeps state changes from being hidden inside unrelated cleanup code.

### 6\. Remove Duel policy from generic Arena

Move these out of `arena.h`/`arena.qc` and into Duel:

- `autocvar_duel_reaperSpeed`
- `autocvar_duel_reaperTime`
- reaper timers
- sudden-death one-hit processing
- Duel-specific interpretation of damage during sudden death

Arena should know that a mode has entered sudden death, but not what “sudden death” mechanically means.

Extend the mode hook contract with the minimum generic hooks needed for specialization:

- sudden-death entry
- sudden-death per-frame tick
- player damage/pain notification if required by the mode

Arena continues evaluating the resulting round outcome after the mode hook runs.

Duel implements its present one-hit/reaper behavior through those hooks.

A future VSH-like mode must be able to implement boss selection, asymmetric win tests, and specialized sudden death without editing `arena.qc`.

### 7\. Tighten the Arena public API

Modes should interact with Arena semantically rather than touching its storage.

Expose queries for things Duel currently obtains from raw userinfo/global state, including:

- current Arena lifecycle state
- player's Arena participation state
- competitor slot lookup
- competitor/ready counts
- competitor lookup where a mode needs slot-aware behavior

Keep `*arena_state` as the underlying storage mechanism because of RuleC/entity-field constraints, but make Arena the only code responsible for reading/writing it as rules state.

`duel.qc` should stop directly checking `userinfo.GetFloat(..., "*arena_state")` for rules decisions.

Keep mode callbacks thin:

`CodeCallback_* → Arena semantic API → mode hook when applicable`

Hero-selection/menu-specific information such as `*hero` and `*duel_joining` remains Duel/UI policy rather than being pushed into Arena.

### 8\. Preserve Nuclide-native player-shell behavior

Do not rewrite the proven Nuclide player lifecycle.

Continue using the appropriate existing mechanisms for:

- temporary waiting/intermission spectators
- fake spectators watching an active round
- true opted-out spectators
- class/hero spawning
- `ChangeToClass` only when an actual class transition is intended

In particular, do not solve Arena bookkeeping by repeatedly converting waiting/queued players to the destructive spectator class.

Keep spawn ownership explicit:

- warmup/freeplay spawning may be player-request driven
- Arena owns competitor round spawns
- fake spectators do not receive an extra player spawn
- hero selection records a selection without causing duplicate inventory/class rebuilding
- closing the selector/readying must not cause two spawn paths to fire for the same transition

### 9\. Centralize broadcasting

Arena state/result publication should occur after completed semantic mutations, not opportunistically throughout individual branches.

Broadcast enough information for HUD/client code to distinguish:

- lifecycle state
- current round
- scores
- winner/draw/void result
- countdown/deadline where currently exposed

Participation changes that affect queue/roster state should trigger one synchronized update.

The existing throttled periodic broadcast can remain as recovery/refresh behavior, but correctness must not depend on waiting for it.

## Test Plan

Use the existing QC build as the compile gate, then exercise the lifecycle in-engine with invariant diagnostics enabled.

Required regression scenarios:

- Two ready players enter countdown and begin a normal Duel.
- Competitor disconnects during the initial countdown: surviving player is requeued correctly and no phantom match result is produced.
- Competitor uses `notready` during initial countdown: identical lifecycle semantics to other pre-match removals.
- Competitor uses `spectate` during initial countdown: same cancellation semantics, except the departing player becomes a pure spectator.
- Competitor disconnects, spectates, or otherwise leaves during `LIVE`: match becomes `VOID`, survivor gets no win, survivor returns to queue priority.
- Same removal cases during `SUDDEN_DEATH`.
- Competitor leaves during `ROUND_END` before the match has resolved: match becomes void.
- Player leaves during `MATCH_END`: already-final result remains valid and rotation ignores the missing player.
- Player leaves during a later inter-round countdown: existing match is voided rather than treated as a never-started matchup.
- Queued player disconnects/spectates/notreadies: queue order remains valid and active competitors are unaffected.
- Repeated ready/play/spectate commands cannot create duplicate queue entries.
- Winner-stays places a valid winner before the loser and then fills remaining slots from the queue.
- Void-match requeue preserves survivor ordering.
- Round draw awards the intended points without becoming confused with a void result.
- Round-limit tie correctly creates the tiebreaker and enters its intended sudden-death behavior.
- Duel sudden-death one-hit and reaper mechanics behave identically after moving out of Arena.
- A normal non-sudden round is unaffected by Duel's new sudden-death hooks.
- Dead competitors remain Arena competitors while using the fake-spec/chase camera.
- Late joiners remain outside the current match and enter the queue/waiting flow correctly.
- Spectator → play → hero selection → ready produces exactly one consistent Arena state at each step.
- Hero changes do not double-spawn, duplicate inventory, or break the active weapon/viewmodel.
- Server/HUD state reflects every transition/result without stale competitor, winner, or queue data.
- Invariant validation reports no failures throughout all cases.

As a structural acceptance test, sketch a minimal hypothetical boss/VSH mode using only the resulting public Arena API and hooks. If implementing that mode would require directly editing Arena's state machine for boss-specific rules, the abstraction boundary is still too narrow.

## Assumptions and Defaults

- Arena remains Stiletto's reusable multiplayer gamemode foundation; FreeHL, FreeCS, TF2, Quake 3, and VSH are references rather than replacement bases.
- Existing Nuclide/FTEQW spawning, prediction, class, and networking systems stay intact; this refactor is specifically rules/lifecycle architecture.
- Winner-stays remains Duel's promotion policy.
- A player departure after a valid `MATCH_END` result does not invalidate that result.
- A departure before the first live round cancels the pending matchup; a departure after the match has begun voids the match.
- Voided matches award no winner and preserve surviving competitors' queue priority.
- Existing userinfo storage remains for Arena per-player state, but direct mode access to `*arena_state` is removed.
- The first refactor should preserve visible Duel behavior except where it intentionally fixes inconsistent participation/removal handling.
- No new inheritance/class hierarchy is required in QuakeC: Arena acts as the base-class equivalent through a state machine, semantic API, and hook table.
