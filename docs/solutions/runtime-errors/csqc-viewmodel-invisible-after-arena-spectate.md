---
title: "CSQC viewmodel invisible after arena wait / spawn (weapon churn + half-ready edicts)"
date: 2026-07-22
type: fix
severity: high
module: "CSQC viewmodel / arena waiting"
category: networking-protocol
affected_runtime: FTEQW-CSQC
tags:
  - fteqw
  - quakec
  - csqc
  - viewmodel
  - arena
  - weapons
  - prediction
problem_type: runtime_error
status: resolved
related:
  - docs/solutions/runtime-errors/fteqcc-virtual-receiveentity-csqc-underread.md
---

# CSQC viewmodel invisible after arena wait / spawn

## Summary

Closing the arena menu or spawning after a waiting-camera park left the local viewmodel missing (and could crash on `ClientFX` / `PredictPreFrame`). This is **not** fixed by reverting `ReceivePlayerEntity`. That rename is required for correct `ENT_PLAYER` decoding; shipping it alone without the companion weapon-readiness layers can make the viewmodel bug look “new” because the client now correctly receives weapon entity refs that were previously mis-decoded.

## Causal chain

1. **Arena waiting churn (server root for the menu path)**  
   `Arena_SpawnWaitingView` used `ChangeToClass("spectator")`. For clients that helper is effectively: spawn as `player` (gives weapons) → `MakeTempSpectator` (destroys them). Repeating that give/destroy cycle leaves CSQC with weapon edicts that look live (`m_activeWeapon` truthy / `_isItem` set) while vtable slots like `ClientFX` / `PredictPreFrame` are still null.

2. **Double-destroy on fake-spec (server)**  
   `MakeTempSpectator` destroyed `m_activeWeapon` and then destroyed `m_itemList`, but the active weapon is already on that list. Tear inventory down once via `RemoveAllItems`.

3. **Half-ready weapon edicts (client)**  
   Same race `ProcessInput` already documents: `findentity` / `_isWeapon` can be true before `spawnfunc_ncWeapon` installs the vtable. `View_DrawViewModel` / `ncView::UpdateView` must refuse to cache or call through until `ClientFX` is present; `ncWeapon::PredictPreFrame` must not call a null `super::` slot.

4. **Authoritative weapon num wiped by prediction SAVE_STATE (client)**  
   `activeweapon` can be cleared locally without a `PLAYER_WEAPON` delta. `PredictPreFrame`’s `SAVE_STATE(activeweapon)` then copies `0` into `activeweapon_net`, permanently losing the last good network value until the next weapon change. Restore `activeweapon` from `activeweapon_net` **before** `SAVE_STATE`.

## Correct stack (ship together)

| Layer | File | Fix |
|-------|------|-----|
| Wire decode | `src/client/entities.qc` | `pl.ReceivePlayerEntity(new, a)` — see related underread doc |
| Waiting cam | `base/src/rules/arena.qc` | No `ChangeToClass("spectator")`; `Spectate` / `MakeTempSpectator` only |
| Fake-spec inventory | `src/shared/game/Player.qc` | `RemoveAllItems` in `MakeTempSpectator` |
| Weapon prediction | `src/shared/game/Weapon.qc` | Inline item SAVE/ROLL; no null `super::Predict*` |
| Player prediction | `src/shared/game/Player.qc` | Null-check item `Predict*`; restore `activeweapon` from `_net` before `SAVE_STATE` |
| View bind/draw | `src/client/View.qc`, `viewmodel.qc` | Require `_isWeapon` + `ClientFX` before caching / drawing |

Rebuild both:

```text
fteqcc.exe -srcfile base/src/client/progs.src   → base/csprogs.dat
fteqcc.exe -srcfile base/src/rules/duel.src     → base/progs/duel.dat
```

## Anti-drift rules

- Do **not** “fix remote origin” by reverting `ReceivePlayerEntity` or by calling `ncSpectator::ReceiveEntity` for `ENT_PLAYER`.
- Do **not** rebuild `csprogs.dat` for the receive rename while stashing / excluding `Player.qc`, `Weapon.qc`, `View.qc`, or `viewmodel.qc` — that reintroduces invisible VMs.
- Do **not** paper over missing VMs by force-sending unrelated player bits or by skipping prediction entirely.
- Remote-at-origin-until-move is a **separate** placement/predict bug (`csqc-remote-player-stuck-at-world-origin.md`) — keep those spawn/predict/oldorigin layers when rebuilding.
- When changing any one layer above, rebuild the VM that owns it and re-check: join arena → close menu / spawn → viewmodel present; second client still sees remotes at real origins while idle.

## Verification

1. Host duel_alley; open arena join UI; close / join match — local viewmodel appears without needing a weapon switch.
2. Respawn / leave waiting cam — no null `ClientFX` / `PredictPreFrame` crash.
3. Second client joins while host stands still — host model not stuck at world origin (ReceivePlayerEntity still wired).
4. Optional: `cl_viewmodelDebug 1` / `g_weaponDebug 1` for state transitions.
