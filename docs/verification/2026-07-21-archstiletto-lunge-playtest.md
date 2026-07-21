# Archstiletto lunge — playtest checklist

Plan: `docs/plans/2026-07-21-001-feat-archstiletto-lunge-plan.md`
Rebuild: `fteqcc.exe -srcfile base/src/server/progs.src` (+ client `base/src/client/progs.src`)

## Setup

- `+game base`, select **Archstiletto**
- Ability = MOUSE2 (`+stiletto_grapple`)
- Melee = primary fire

## Acceptance

| ID | Steps | Pass? |
|----|-------|-------|
| AE1 | Hold ability on ground to full (~1.1s), release looking up-forward → strong launch; cannot ground-charge again until ~1.5s CD | |
| AE2 | Tap/release early → clearly weaker hop than AE1 | |
| AE3 | Hold charge on ground, get hit → no tool punish from charge alone | |
| AE4 | Mid-lunge (airborne), Arch super armor already spent, get hit → trajectory-preserving punish | |
| AE5 | Weak ground open → hit wall → ability press → weak wall re-lunge | |
| AE6 | Full ground open → wall chain presses → full-strength hops until land clear | |
| AE7 | After clean land (no wall), next ground charge starts fresh (not stuck at old strength) | |
| AE8 | Lunge through another player → no lunge damage/pin | |

## Regressions

| Check | Pass? |
|-------|-------|
| Collier (or non-Arch) ability still fires **grapple** | |
| Vagrant ability still **warpknife** (not grapple) | |
| Arch **M1 melee** still swings (128 range / cleave) | |

## Notes

- Tunables in `src/shared/physics/pmove.h`: `STILETTO_LUNGE_*`
- Flight-only toolActive via `m_stilettoLungeFlight` in `stiletto_combat.qc`
