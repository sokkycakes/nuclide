---
date: 2026-07-21
topic: archstiletto-lunge
status: active
type: requirements
---

# Archstiletto lunge — class tool

## Summary

Give Archstiletto a **mobility-only lunge** as his class tool: ground hold-to-charge, release to launch along look direction, short cooldown, mild charge slow, and **instant wall re-lunges that reuse the charge strength of the current sequence**. Mid-lunge hits use Arch’s existing tool-punish rules; charging on the ground does not.

---

## Problem Frame

Archstiletto is selectable with duel HP/super-armor rules and a placeholder long-range melee, but he has **no class tool**. Other roster heroes express identity through a signature ability on the shared hero-ability input. Without a lunge, Arch is incomplete as a duel pick and his mobility fantasy (Hale-style charge jump + Hunter-style wall chaining) never shows up in play.

---

## Key Flows

### Ground-charged lunge

1. Arch is on the ground and ability is off cooldown.
2. Player holds the hero-ability input; Arch moves at a mild reduced speed while charge builds (~1.0–1.25s to full).
3. Player releases; Arch launches in the look direction with power scaled to charge held.
4. Ground charge enters a short fixed cooldown (~1–2s) before another ground charge can start.
5. While airborne from that lunge, Arch is tool-active for punish purposes.

### Wall re-lunge chain

1. During an active lunge flight (or when landing into a wall while still in that sequence), Arch contacts a wall.
2. Player presses ability again while wall-touching.
3. Arch immediately re-lunges in the **current look direction** with **no new charge**, at the **same strength** as the ground launch that started this sequence.
4. Wall re-lunges do not consume or bypass the need for the ground cooldown before the *next* ground charge; they only skip charging within the airborne chain.
5. Sequence charge strength clears when the chain ends (land without continuing a wall re-lunge); the next ground charge starts fresh.

---

## Requirements

| ID | Requirement |
|----|-------------|
| **R1** | Lunge is Archstiletto’s **class tool** (hero-ability input), mobility only — no damage, pin, or body-check on impact. |
| **R2** | **Charge only on ground.** Holding ability while airborne does not build charge (except wall re-lunge, which needs no charge). |
| **R3** | Hold ability to charge; release launches along **look direction**. Charge reaches full in ~**1.0–1.25s**. Early release yields a weaker hop; a minimum charge still produces a weak lunge (tap ≠ zero). |
| **R4** | While charging on ground, move speed is **mildly reduced** (~70–80% of normal). |
| **R5** | After a ground-charged release, a **short fixed cooldown** (~1–2s) applies before another ground charge may start. |
| **R6** | **Wall re-lunge:** while wall-touching during the current lunge sequence, pressing ability fires an immediate re-lunge (no charge) in look direction. |
| **R7** | Wall re-lunges **reuse the charge strength** of the ground launch that opened the sequence. Weak open → weak wall hops; full open → full wall hops. |
| **R8** | Wall re-lunges **ignore** the ground cooldown (they do not wait for it). They do not themselves start a new ground-charge meter. |
| **R9** | **Tool punish:** charging on ground is **not** tool-active. Once airborne from a lunge or wall re-lunge, Arch is tool-active; hits use Arch’s existing duel punish path (2 HP super armor, then trajectory-preserving punish). |
| **R10** | Lunge does **not** replace shared-kit air dodge / air stall / kickback. |

---

## Acceptance Examples

**AE1 — Full ground lunge**  
Arch holds ability on ground to full charge, releases looking up-forward, launches strongly, then cannot ground-charge again until the short cooldown elapses.  
*Covers: R2, R3, R5*

**AE2 — Weak hop**  
Arch taps/releases early on ground; launch is clearly weaker than full charge.  
*Covers: R3*

**AE3 — Charge not punishable**  
While holding charge on ground, Arch is hit; no tool punish applies from the charge itself (normal hit rules only).  
*Covers: R9*

**AE4 — Flight punishable**  
Arch releases a lunge, is airborne mid-flight, takes a hit with super armor already spent → Arch trajectory-preserving punish applies.  
*Covers: R9*

**AE5 — Weak wall chain**  
Arch opens with a weak ground lunge, hits a wall, presses ability → re-lunge is also weak (same strength).  
*Covers: R6, R7*

**AE6 — Full wall chain**  
Arch opens with full charge, wall-contacts, presses ability repeatedly along walls → each re-lunge keeps full sequence strength until the chain ends.  
*Covers: R6, R7, R8*

**AE7 — Fresh charge after land**  
After a wall chain, Arch lands with no wall contact and later ground-charges again → charge strength is independent of the previous sequence.  
*Covers: R7*

**AE8 — No damage on skim**  
Arch lunges through another player; no damage or pin is applied by the lunge.  
*Covers: R1*

---

## Success Criteria

- Playing Arch, the ability key feels like a distinct class tool (not just longer melee).
- A full charge clearly outranges/outjumps a weak release; wall chains preserve that read.
- Wall chaining is skillful and readable without becoming free infinite full-power spam from a tap.
- Mid-lunge vulnerability is consistent with existing Arch duel punish rules.
- Shared air tools still work and remain separately punishable as today.

---

## Scope Boundaries

- Damage, pin, or grab on lunge impact
- Archstiletto arena mode (100 HP, 2× air damage, boss kit elevation)
- Dedicated charge HUD / VFX beyond what playtest needs
- New viewmodel / third-person lunge animations (placeholder OK)
- Reworking shared air-dodge / stall / kickback
- Per-hero ability framework beyond wiring this one tool

---

## Key Decisions

| Decision | Choice |
|----------|--------|
| Impact | Mobility only |
| Charge location | Ground only |
| Feel references | VSH Hale super jump + L4D Hunter pounce aim/release; not Hunter damage/pin |
| Wall chain | Instant re-lunge on ability press while wall-touching; **same strength as opening charge** |
| Cooldown | Short fixed (~1–2s) on ground charge; wall re-lunges bypass charging, not “reset” into a new full meter |
| Punish | Flight only |
| Charge time | ~1.0–1.25s to full |
| Charge move | Mild slow (~70–80%) |
| Input | Hero-ability bind (right-click / existing ability key), not melee secondary |

---

## Dependencies / Assumptions

- Hero-ability press/release path already exists for other class tools (e.g. Vagrant).
- Wall-touch detection already exists in the shared Stiletto movement kit.
- Arch duel super-armor / trajectory punish already exists and is the punish path for mid-lunge hits.
- Exact impulse magnitudes, cooldown seconds, and slow % are playtest-tunable within the stated bands.

---

## Outstanding Questions

None blocking planning. Tuning numbers (exact impulse curve, cooldown length, wall-contact grace) are deferred to planning/playtest.
