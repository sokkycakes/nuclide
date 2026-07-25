---
title: Player IQM animation
created: 2026-07-24
updated: 2026-07-24
type: concept
tags: [player, progs, entitydef]
sources: []
confidence: high
---

# Player IQM animation

Third-person heroes can use plain **IQM** (e.g. Smash Ultimate →
`base/models/player/joker.iqm` on Vagrant) under skeletal
`animBackend` **0**. Full write-up:
`Documentation/Models/IQM.md`.

## Settled rules

- Bake **scale** and foot **Z** into the IQM — players do not network `.scale`.
- Blender `iqm_export`: **Animations** field required; `*` expands `.nuanmb`.
- Prefer **numeric** `act_*` framegroup indices on IQM heroes.
- Never use empty `""` entityDef overrides for torso/aim (pairing +
  `frameforaction` fallthrough).
- Always `RefreshPlayerAnimations` when model/hero is ready.
- Guard torso `skel_build`: only if `m_torsoFirst >= 1` and
  `m_torsoLast > m_torsoFirst` (Bip01 missing → 0 means “all bones”).
- CSQC must set `declclass` from `entityDefID` before resolving acts —
  IQM has no HL activity codes; all-`−1` acts clamp to frame 0.
- Jump + crouch are **one-shots** in `UpdatePlayerAnimation` (clamp time;
  reset on enter). Idle/walk/run still loop.

## Debug

`anim_debug 1` then `cmd selecthero hero_vagrant` — expect
`decl=hero_vagrant` with positive idle/walk/run, not all `−1`.

## Related

- [[entitydef]]
- [[nuclide]]
- [[rebuild-flow]]
- Documentation: `Documentation/Models/IQM.md`
- Retarget notes: `docs/workflows/smash-ultimate-to-goldsrc-retarget.md`
