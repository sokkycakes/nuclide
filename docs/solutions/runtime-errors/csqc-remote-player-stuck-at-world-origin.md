---
title: "Remote CSQC players stuck at world origin until movement"
date: 2026-07-22
type: fix
severity: high
module: "CSQC player replication"
category: networking-protocol
affected_runtime: FTEQW-CSQC
tags:
  - fteqw
  - quakec
  - csqc
  - networking
  - origin
  - prediction
problem_type: runtime_error
status: resolved
related:
  - docs/solutions/runtime-errors/fteqcc-virtual-receiveentity-csqc-underread.md
  - docs/solutions/runtime-errors/csqc-viewmodel-invisible-after-arena-spectate.md
---

# Remote CSQC players stuck at world origin until movement

## Summary

Observers see remote players at `[0,0,0]` after join/respawn until that player moves. Wiring `ENT_PLAYER` → `ReceivePlayerEntity` is necessary (wrong decoder reads `SPECFL_*`) but **not sufficient**.

## Causal chain

1. Default CSQC origin is `0,0,0`. Standing still does not dirty `PLAYER_ORIGIN`, so a bad first snapshot sticks until movement.
2. **Server race:** `MakePlayer()` sets `SendFlags = UPDATE_ALL` before `Spawn_PlaceAtSpot` / teleport. A full update can leave with origin still at death/`0`; after placement, `PLAYER_ORIGIN` must be forced again.
3. **Client re-init:** `Predict_EntityUpdate` used `new || !is.Player(pl)`. Virtual `IsPlayer()` on the Client→Spectator→Player hierarchy can false-negative (same class of FTEQCC virtual hazard as `ReceiveEntity`). That re-ran `Util_ChangeClass` on later deltas that omit `PLAYER_ORIGIN`, wiping remotes back to world origin.
4. **Interpolation:** without snapping `oldorigin` when origin is authoritative, remotes can visually linger at `0` even after a good read.

## Correct stack

| Layer | File | Fix |
|-------|------|-----|
| Wire decode | `src/client/entities.qc` | `pl.ReceivePlayerEntity(new, a)` |
| Placement | `src/server/spawn.qc` | After place/teleport: `SendFlags \|= PLAYER_ORIGIN \| PLAYER_ANGLES` |
| Predict setup | `src/client/predict.qc` | Class-setup on `new \|\| !pl._isPlayer` only (not virtual `is.Player`) |
| Receive snap | `src/shared/game/Player.qc` | On `isNew` / `PLAYER_ORIGIN` / `UPDATE_ALL`: `oldorigin = origin` after `Relink` |

Rebuild:

```text
fteqcc.exe -srcfile base/src/client/progs.src   → base/csprogs.dat
fteqcc.exe -srcfile base/src/server/progs.src   → base/progs.dat
```

## Anti-drift

- Do not treat the `ReceivePlayerEntity` rename as the complete origin fix.
- Do not reintroduce `!is.Player(pl)` as the predict class-setup gate.
- Keep viewmodel readiness layers when rebuilding csprogs (see related viewmodel doc).

## Verification

1. Client B joins while host stands still — host model at real spawn, not map center.
2. Host respawns while B watches — no flash/stick at origin.
3. Local viewmodel still appears after arena menu close / spawn.
