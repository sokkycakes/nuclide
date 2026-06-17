---
title: "Deferred: spectator target cycling (local multi-client)"
status: deferred
date: 2026-06-16
related_plan: docs/plans/2026-06-14-004-feat-spectator-hud-chrome-plan.md
---

# Spectator target cycling — deferred

**Status:** deferred / blocked on investigation  
**Related plan:** [feat: Nuclide spectator HUD chrome](../plans/2026-06-14-004-feat-spectator-hud-chrome-plan.md)

---

## Problem statement

On a **local two-client** FTE server (same machine, internal server), a spectator client cannot **cycle to the other connected player** using scroll wheel or next/previous target input.

**User scenario:**

- Two FTE clients on one PC connect to the same internal server.
- Duplicate display names get a `(1)` suffix (expected FTE behavior).
- One client runs `spectate` (or connects as observer).
- Scroll wheel / target cycling never lands on the other connected player.
- The other player may be in the **lobby** or **spawned**; user reports "other player in the server" for both cases.

Spectator HUD chrome (watching bar, observer list, PiP) was implemented separately; **target switching remains broken** for this setup after multiple fix attempts.

---

## What was attempted

Multiple passes (3+) touched server routing, validation, client replication, and camera display. Summary:

- **Server input routing** — `SV_RunClientCommand` in `src/server/entry.qc` routes real spectators (`classname == "spectator"`) through `ServerInputFrame` → `ProcessInput` → `InputNext`/`InputPrevious`, then `EvaluateEntity()`.
- **`Spectator_IsValidChaseTarget`** — Expanded filters: exclude self via `num_for_edict`, `clienttype` on server, userinfo `*spec`/`*spectator` on client, require `modelindex > 0`, slot-based checks.
- **Client entity lookup** — Replaced `edict_num()` on CSQC with `Spectator_EntityForPlayerSlot()` using `findfloat(world, ::entnum, slot)` for remote player ents.
- **`is.Player()` fix** — Remote CSQC players lack replicated `classname` (only `declclass`); replaced with `Spectator_TargetIsPlayablePlayer()` using `_isPlayer` + `pl.IsPlayer()`.
- **View / inset validation** — Chase cameras in `View.qc` and spec inset in `entry.qc` updated to use spectator chase helpers instead of raw `is.Player(c)`.
- **`SpectatorTrackPlayer`** — Stopped calling `InputNext()` every frame when target invalid; later changed so **client no longer clears** `m_spectatingEntity` when client-side validation fails (server still authoritative).
- **Client validation relaxation** — `Spectator_TargetIsPlayablePlayer` split server vs client: client trusts `modelindex` + userinfo; avoids stale `health`/`team` on freshly replicated ents.
- **`InputNext`/`InputPrevious`** — Only enter chase mode after a valid `best` target is found; early return if none.
- **`Spectator_HasChaseTargetEntity`** — Camera/inset helper trusting server-chosen slot + playable check.
- **FreeHL comparison** — FreeHL has no separate `Spectator.qc`; arena waiting uses `spectator` class, competitors spawn with models (similar constraints). Scoreboard skips `*spec` slots.

**Outcome:** User still reports broken behavior on local two-client setup. Further investigation parked.

---

## Known constraints

| Situation | Chaseable? | Why |
|-----------|------------|-----|
| **Spawned `player_mp` / hero** (DM auto-spawn, duel auto-join) | Expected yes | Has `modelindex`, `FL_CLIENT`, playable class |
| **Connecting / unspawned lobby** | No | `Disappear()` → `modelindex == 0`; `SendEntity` skips ents with no model to other clients |
| **Arena waiting queue** | No | `Arena_SpawnWaitingView` → `ChangeToClass("spectator")`; excluded by classname and `*spec` userinfo |
| **Fake spectator** (`MakeSpectator` / arena) | Different path | `ncPlayer` + `VFL_FAKESPEC`, not `classname == "spectator"`; uses `ncPlayer::ProcessInput` |

**CSQC replication gaps** (affect client-side validation even when server target is correct):

- Remote players often lack `classname` until late in the stream (`declclass` only).
- `team` may not be in `SendEntity` for players.
- `health` can be stale `0` on freshly replicated remote ents.
- `FL_CLIENT` unreliable on client for remote ents.

**Two spectator entry paths:**

- Engine `spectate` connect → `ncSpectator` (`classname == "spectator"`).
- In-game `cmd spectate` / arena → `MakeSpectator()` → `ncPlayer` fake spec.

---

## How to trace in-game next time (FTE-specific)

### Console / engine

1. Run with **`developer 1`** for extra console output.
2. Enable QC debugging if exceptions occur: **`pr_debugger 1`** (or attach FTE debugger) to catch runtime errors in `Spectator.qc` / `ProcessInput`.
3. Confirm wheel impulses: client sets **`input_impulse` 210** (next) / **211** (prev) in `CSQC_Input_Frame` (`src/client/entry.qc`); server receives via `SV_RunClientCommand`.

### Temporary `print()` hooks (remove after debug)

Add guarded prints in `src/shared/game/Spectator.qc`:

- **`ProcessInput`** — log when `input_impulse == 210/211` fires and `SPECFLAG_TARGET_RELEASED` blocks.
- **`InputNext` / `InputPrevious`** — per slot in loop: slot index, `IsValidChaseTarget` result, `best` chosen, `m_spectatingEntity` before/after.
- **`SpectatorTrackPlayer`** — log when client vs server clears or holds target.

Rebuild: `base/src/server` and `base/src/client` with `fteqcc.exe` → `base/progs.dat` + `base/csprogs.dat`.

### State to compare (server vs client)

For each player slot `1..sv_playerslots`:

| Check | Server | Client |
|-------|--------|--------|
| `m_spectatingEntity` on spectator ent | `edict_num` / server ent fields | `findfloat(world, entnum, …)` after `ReceiveEntity` |
| `m_spectatingMode` | authoritative | replicated `ENT_SPECTATOR` / `SPECFL_TARGET` |
| Target entity exists | `edict_num(slot)` | `findfloat(world, ::entnum, slot)` |
| Userinfo | N/A | `getplayerkeyfloat(slot-1, "*spec")`, `"*spectator"`, `"*team"`, `"*dead"` |
| Target drawable | `modelindex`, `clienttype`, `team` | `modelindex`, userinfo fallbacks |

### Key files

- `src/shared/game/Spectator.qc` — `InputNext`, `InputPrevious`, `Spectator_IsValidChaseTarget`, `SpectatorTrackPlayer`, `ProcessInput`
- `src/server/entry.qc` — `SV_RunClientCommand` spectator branch
- `src/client/entry.qc` — wheel → impulse 210/211
- `src/client/View.qc` — chase camera modes
- `base/src/rules/arena.qc`, `base/src/rules/deathmatch.qc` — when players spawn vs wait as spectator

### Suggested repro

1. Internal server, two local clients, `+game base`.
2. Client A: `spectate`.
3. Client B: ensure **spawned** in DM (not arena waiting spectator).
4. Client A: scroll; watch server prints for `best` and client `m_spectatingEntity` after `ReceiveEntity`.

---

## Next steps when resuming

1. Confirm server `InputNext` finds slot 2 with `IsValidChaseTarget` on **server** (authoritative).
2. If server sets target but client camera does not follow, trace `ReceiveEntity` `SPECFL_TARGET` and `SpectatorTrackPlayer` / `View.qc` chase branch.
3. If server never finds valid target, log each rejection reason in `Spectator_IsValidChaseTarget` for spawned `ncPlayer`.
4. Decide product rule: should **lobby-connected** players (no model) be chaseable? Would need visible proxy entity or relaxed replication.
5. Test **fake spectator** path separately if repro uses in-game `spectate` cmd vs connect-as-observer.

---

## References

- Plan: [docs/plans/2026-06-14-004-feat-spectator-hud-chrome-plan.md](../plans/2026-06-14-004-feat-spectator-hud-chrome-plan.md)
- FreeHL (sibling repo): `freehl/src/rules/arena.qc`, `freehl/src/rules/deathmatch.qc`, `freehl/src/client/scoreboard*.qc`
