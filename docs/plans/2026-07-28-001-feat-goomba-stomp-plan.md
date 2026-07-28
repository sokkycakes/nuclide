---
title: "Goomba Stomp - Plan"
type: feat
date: 2026-07-28
topic: goomba-stomp
artifact_contract: ce-unified-plan/v1
artifact_readiness: requirements-only
product_contract_source: ce-brainstorm
execution: code
---

# Goomba Stomp - Plan

## Goal Capsule

**Objective:** Let players instantly kill enemies by landing on them from above when both a downward-speed gate and an airtime gate are met, with a random stomp sound from a six-sound pool.

**Authority:** This Product Contract for behavior and scope. Numeric thresholds and wiring details belong to planning / playtest tuning.

**Open blockers:** None. Bounce is deferred polish, not a planning blocker.

---

## Product Contract

### Summary

Landing on a player or monster from above after meeting both downward-speed and airtime gates kills them instantly and plays one of six goomba-stomp sounds at random. Every hero can stomp by default; specific heroes may opt out. Teammates are never valid targets.

### Problem Frame

High-mobility play already puts players above opponents often, but landing on someone does nothing special. TF2 Mantreads and community goomba-stomp plugins show the expected fantasy: a committed aerial landing should be a decisive one-hit finish, not just a collision.

### Key Decisions

- **Landing-from-above detection over continuous feet probe.** Stomp fires when the stomper lands on a valid target from above, Mantreads-style. A continuous falling probe is out unless playtest proves landing detection too unreliable. *(session-settled: user-directed — chosen over feet-probe and victim-side crush)*
- **Both speed and airtime required.** Short hops and slow drops should not stomp. *(session-settled: user-directed — chosen over OR / speed-only / airtime-only)*
- **Hero default-on with opt-out.** Universal unless a hero is explicitly excluded. *(session-settled: user-directed — hero-gated, everyone by default)*
- **Kill + random sound is the proof cut.** Small bounce is desired later, not required to prove the mechanic. *(session-settled: user-approved — bounce deferred as follow-on polish)*
- **No fall-damage coupling.** This game has no fall damage, so Mantreads-style fall mitigation is irrelevant. *(session-settled: user-directed)*

### Actors

- A1. Stomper — a living player whose hero has stomp enabled (default)
- A2. Victim player — living enemy player under the stomper
- A3. Victim monster — living monster under the stomper
- A4. Teammate — same-team player; never a valid victim

### Key Flows

- F1. Successful player stomp
  - **Trigger:** A1 lands on A2 from above while both gates pass
  - **Actors:** A1, A2
  - **Steps:** Contact qualifies; A2 dies instantly; one of six stomp sounds plays at random
  - **Outcome:** A2 dead; A1 continues (no required bounce in this cut)
  - **Covered by:** R1, R2, R3, R4, R7

- F2. Successful monster stomp
  - **Trigger:** A1 lands on A3 from above while both gates pass
  - **Actors:** A1, A3
  - **Steps:** Same as F1 against a monster
  - **Outcome:** A3 dead; stomp sound plays
  - **Covered by:** R1, R2, R3, R4, R7

- F3. Rejected teammate contact
  - **Trigger:** A1 lands on A4 from above while both gates would otherwise pass
  - **Actors:** A1, A4
  - **Steps:** Contact is not a stomp; no kill; no stomp sound
  - **Outcome:** Normal collision / landing only
  - **Covered by:** R5

- F4. Failed qualification
  - **Trigger:** A1 lands on a valid enemy from above but speed or airtime fails
  - **Actors:** A1, A2 or A3
  - **Steps:** No stomp
  - **Outcome:** Victim unharmed by stomp; no stomp sound
  - **Covered by:** R2, R3

### Requirements

**Qualification**

- R1. A stomp requires landing on a valid target from above (downward contact onto them). Sideways or non-above contact never stomps.
- R2. A stomp requires both a minimum downward speed and a minimum airtime. Either gate alone is insufficient.
- R3. Exact speed and airtime thresholds are tunable; both gates must exist and be independently adjustable.

**Targets and availability**

- R4. Valid victims are living enemy players and living monsters.
- R5. Teammates are never valid stomp targets.
- R6. Stomp is available to every hero by default. A hero may opt out when explicitly configured to disable it.

**Outcome and feedback**

- R7. A successful stomp kills the victim instantly (one hit, lethal).
- R8. A successful stomp plays exactly one sound chosen at random from a fixed pool of six goomba-stomp sounds.
- R9. Failed or rejected contacts do not play a stomp sound from that pool.

### Acceptance Examples

- AE1. Committed aerial land on enemy player
  - **Covers:** R1, R2, R4, R7, R8
  - **Given:** A1 has been airborne long enough and is falling fast enough; A2 is a living enemy below
  - **When:** A1 lands on A2 from above
  - **Then:** A2 dies immediately; one of the six stomp sounds plays

- AE2. Short hop on enemy
  - **Covers:** R2, R9
  - **Given:** A1 is above A2 but airtime or downward speed is below threshold
  - **When:** A1 lands on A2 from above
  - **Then:** A2 is not killed by stomp; no stomp-pool sound plays

- AE3. Sideways bump while falling
  - **Covers:** R1, R9
  - **Given:** Both gates would pass
  - **When:** A1 collides with A2 from the side, not from above
  - **Then:** No stomp kill; no stomp-pool sound

- AE4. Teammate land
  - **Covers:** R5, R9
  - **Given:** Both gates pass; target is A4
  - **When:** A1 lands on A4 from above
  - **Then:** No stomp kill; no stomp-pool sound

- AE5. Monster land
  - **Covers:** R4, R7, R8
  - **Given:** Both gates pass; target is a living monster
  - **When:** A1 lands on the monster from above
  - **Then:** Monster dies; one of the six stomp sounds plays

- AE6. Opted-out hero
  - **Covers:** R6
  - **Given:** A1's hero has stomp disabled
  - **When:** A1 would otherwise satisfy all stomp conditions on an enemy
  - **Then:** No stomp occurs

- AE7. Sound pool variety
  - **Covers:** R8
  - **Given:** Multiple successful stomps in a session
  - **When:** Stomps succeed repeatedly
  - **Then:** Sounds are drawn from the six-sound pool (not a single fixed clip every time)

### Success Criteria

- A committed aerial land on an enemy reads as an intentional one-hit finish.
- Accidental short hops and sideways bumps do not feel like random instakills.
- Hearing a successful stomp is immediate and varied across the six-sound pool.
- Opt-out heroes never stomp; default heroes always can when conditions pass.

### Scope Boundaries

**In this cut**

- Instant kill + random sound from six-clip pool
- Players and monsters as victims
- From-above landing detection
- Dual gates (speed and airtime)
- Hero default-on with opt-out
- No teammate stomps

**Deferred for later**

- Small bounce / hop on successful stomp
- VFX / camera punch beyond what existing land feedback already does
- Continuous feet-probe detection if landing detection proves unreliable
- Strict upper-hitbox-only “head zone” precision

**Out**

- Fall-damage cancel or mitigation (no fall damage in this game)
- Sideways or any-contact kills while airborne
- Victim-side crush as the primary detection model
- Friendly-fire teammate stomps

### Dependencies / Assumptions

- Existing landing / airborne timing already exists and can supply airtime and impact context for the gates.
- The six goomba-stomp sound assets are available to ship with the feature (or will be before playtest acceptance).
- “Teammate” follows the game’s existing team rules for the active mode.
- Numeric gate values will be chosen in planning / playtest; they are not fixed in this contract.

### Outstanding Questions

**Deferred to Planning**

- What initial speed and airtime numbers feel right for Stiletto mobility?
- How should “from above” be judged at the contact moment (angle, relative height, downward velocity sign)?
- Where do the six sounds live and how is the pool authored for designers?
- Confirm whether any shipping hero should opt out at launch, or ship with none opted out.

### Sources / Research

- TF2 Mantreads and community goomba-stomp plugins as the player-facing reference for aerial landing kills.
- No existing goomba-stomp behavior in this project; adjacent landing / airtime / fall handling is the natural hook for planning.
