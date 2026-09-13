# Juliet hero kit — playtest checklist

Plan: `docs/plans/2026-08-26-001-feat-juliet-hero-kit-plan.md`
Rebuild: `fteqcc.exe -srcfile base/src/server/progs.src` and `base/src/client/progs.src` (or `make game GAME=base`).

SSQC (`progs.dat`) and rules (`progs/duel.dat`) rebuilt in this session. CSQC (`csprogs.dat`) must also be rebuilt before playtest so `PLAYER_STILETTO` send/receive stay matched. From the nuclide root:

```
.\fteqcc.exe -srcfile base/src/server/progs.src
.\fteqcc.exe -srcfile base/src/client/progs.src
.\fteqcc.exe -srcfile base/src/rules/duel.src
```

If the client compile access-violates (exit `0xC0000005`) before writing `csprogs.dat`, do not play with the leftover CSQC — the Juliet charge fields will underread. Rebuild CSQC from an interactive `cmd.exe` window (same commands) and confirm `base/csprogs.dat` timestamp updates.

Use a **compiled BSP** (`duel_alley.bsp`). Raw `.map` can fake `FL_ONGROUND` and look like infinite double jumps.

## Setup

- `+game base`, select **Juliet** (`selecthero hero_juliet`)
- Primary = charge gun (press to start/resume, press again while charging to fire)
- Guard = `+hero_guard`
- Ability / tool should do **nothing** (no grapple, no Stinger)

## Acceptance

| ID | Steps | Pass? |
|----|-------|-------|
| AE1 | Pick Juliet. She is 4 HP, normal hull. Fall next to Collier from the same drop — Juliet falls slower. | |
| AE2 | Empty, press primary, wait ~1s, press again. A projectile fires. Charge is empty. | |
| AE3 | Charge, guard, wait, press primary. Charging resumes; **no shot**. Second press while charging fires. | |
| AE4 | Charge, tap a move direction. Short burst, recovery, no i-frames (getting shot during burst deals damage). Charge kept. Next primary **resumes**, does not fire. | |
| AE5 | Hit **while charging** → charge empty. Store via guard, then get hit → charge **kept**. | |
| AE6 | One extra jump in air, then land restores it. Second air jump does nothing until land. | |
| AE7 | Die or `selecthero` away and back. Charge empty. | |

## Edges

| Check | Pass? |
|-------|-------|
| Hold charge to full (~2.5s), wait, fire — still full-tier shot | |
| Primary during burst recovery is ignored | |
| Tiny stick below air-move threshold does not burst | |
| Burst during recovery does not chain | |
| Jump while charging stores (no burst); next primary resumes | |
| Tool press as Juliet does not throw a grapple | |

## Regressions

| Check | Pass? |
|-------|-------|
| Collier ability still fires **grapple** | |
| Archstiletto ability still **lunge** | |
| Collier / Arch fall at default gravity (faster than Juliet) | |
| Collier / Arch have **no** extra air jump | |

## Notes

- Charge time `JULIET_CHARGE_TIME` 2.5s in `src/shared/game/WeaponJuliet.qc`
- Burst recovery `JULIET_DASH_RECOVERY` 0.5s — full action lock (fire/melee/tool/guard/jump) until it ends
- Juliet gravity `pm_gravity` 560 in `base/decls/def/heroes/hero_juliet.def` (shared default 800)
- Two-client listen server: second client should see the ball; local fire should not double after correction
