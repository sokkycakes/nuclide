---
title: "Stiletto character roster — data extrapolation from Godot prototype"
type: requirements
status: active
date: 2026-06-14
---

# Stiletto character roster — data extrapolation from Godot prototype

## Summary

Define the **seven-character Stiletto roster** (Collier, Vagrant, Beaumont, Archstiletto, Skipstream, Angel, Motionblue) as data-driven `hero_*` player defs on top of the existing Nuclide hero roster framework (`hero_base`, `selecthero`, VGUI selection). **Six characters are implemented** in the Godot prototype (`stiletto-protophase2`) as playable `ss_player_*` scenes; **Archstiletto** exists as `ss_player_arch.tscn` but is wired as a **game mode** in the lobby, not as a duel-roster pick. This document extrapolates prototype stats, shared movement/tool-punish rules, and per-character weapons/tools into product requirements for Nuclide—merged with the user's explicit design constraints (4 HP baseline, Arch HP exception, tool-stun rules).

---

## Problem frame

Nuclide already has a generic hero roster pipeline (entityDef per hero, `teams.AddClass`, `selecthero`, replicated `entityDefID`). The Stiletto cast is the actual product roster, but today only placeholder heroes (`hero_alpha` / `hero_bravo`) exist. The Godot prototype at `D:\c drive\Godot\stiletto-protophase2` is the authoritative reference for **what was built and tuned** for six characters; the user's message is authoritative for **cast-wide rules** (4 HP, shared movement kit, Arch exceptions) where the prototype differs or is incomplete.

---

## Cast-wide rules (user + prototype alignment)

### Health (R-HP)

| Rule | Detail |
|------|--------|
| **R-HP1** | All roster characters except Archstiletto use **4 max HP** and spawn at full health. |
| **R-HP2** | All roster heroes use prototype health pacing: **1.3s** post-hit invulnerability and **12s** out-of-combat heal-to-full. **1 damage = 1 HP** unless a weapon explicitly deals fractional hits. |
| **R-HP3** | **Archstiletto** uses **100 HP in Archstiletto mode** and **8 HP in normal play** when mode/context switches. |
| **R-HP4** | **Archstiletto duel (8 HP):** Tool stun has **2 HP super armor**—punish does not apply until **2 HP** of damage have been taken (then Arch-specific punish rules apply). Buffer resets on heal/respawn unless playtest says otherwise. |
| **R-HP5** | **Archstiletto arena mode (100 HP):** **Double damage while airborne** replaces standard tool punish as the mid-air vulnerability rule. |

### Shared movement kit (R-MOVE)

All non-Arch characters (and Arch in normal-play context, unless mode overrides) share the **same movement speeds** and these abilities:

| Ability | Prototype source | Nuclide mapping (today) |
|---------|------------------|-------------------------|
| Kickback (ground + wall) | `kickback_modulev2.gd` on every `ss_player_*` | Partially: Stiletto kickback / air dodge / stall in `src/shared/physics/stiletto_tuning.qc` |
| Air dash | `KickbackModulev2` — move input + secondary → dodge | `Stiletto` air dodge (`STILETTO_AIR_DASH_SPEED`, 1 per airtime) |
| Air stall | `KickbackModulev2` — secondary with no move input | `STILETTO_AIR_STALL_TIME` (0.2s) |
| Wall cling + wall slide + wall jump | `wall_movement.gd` on `WallJumpModule` (all implemented heroes) | `Stiletto` wall flags in `stiletto_tuning.qc` |
| Tool stun (tool punish) | `punish_state_machine.gd` on `PunishState` node | **Not ported** — required new rules component |

**Shared movement tuning (prototype):** All implemented heroes reference `addons/GoldGdt/Default.tres`:

| Parameter | Godot value | Approx. Nuclide `pm_*` note |
|-----------|-------------|-----------------------------|
| Forward / side speed | 10.16 m/s | ≈ **400** Quake units/s (matches `player.def` `pm_runspeed` 400) |
| Max speed | 8.128 m/s | ≈ **320** qu/s |
| Gravity | 20.32 m/s² | tune via `pm_gravity` |
| Jump height | 1.143 m | tune via jump / `pm_*` |
| Hull (stand) | 0.813 × 1.829 × 0.813 m | existing player hull keys |

**R-MOVE1:** Hero defs should **not** override `pm_*` for the six standard roster members unless playtest proves drift; inherit shared `hero_base` movement.

**R-MOVE2:** Signature movement tools (grapple, jets, warpstrike, etc.) are **per-character**, not part of the shared kit.

### Tool stun — standard characters (R-STUN)

Prototype **tool punish** (`punish_state_machine.gd`):

- **Trigger:** Player takes damage **while airborne and actively using a “tool”** (grapple active, jets active, bullet jump cooldown, warpstrike latched, stickyjump, air dodge just used, etc.).
- **Air phase:** Horizontal velocity zeroed; fall continues.
- **Land phase:** **2.0s** punish — **1.0s** full stun, **1.0s** acceleration recovery (30% → 100%).
- **Separate:** Landing acceleration windup on heavy landings (0.65s @ 50% accel)—not the same as tool stun but stacks in feel.

**R-STUN1:** Standard roster characters **can** receive tool stun when the above conditions are met.

**R-STUN2:** **Archstiletto duel (8 HP)** — after super armor is exhausted, punish **does not** zero horizontal velocity or force straight-down fall. Arch **keeps prior trajectory** with **no player control** until landing, then standard ground punish/recovery may apply.

**R-STUN3:** **Archstiletto arena mode (100 HP)** — no standard tool punish; **mid-air hits deal double damage** instead.

---

## Prototype implementation matrix

| Character | Godot scene | In duel roster (`duel_game_mode_definition.tres`) | Unlock in prototype |
|-----------|-------------|---------------------------------------------------|---------------------|
| **Collier** | `resource/entities/player/ss_player_collier.tscn` | Yes | unlocked |
| **Beaumont** | `ss_player_beaumont.tscn` | Yes | locked |
| **Vagrant** | `ss_player_vagrant.tscn` | Yes | locked |
| **Angel** | `ss_player_angel.tscn` | Yes | unlocked |
| **Motionblue** | `ss_player_mblue.tscn` (id `mblue`, display **Mblue**) | Yes | unlocked |
| **Skipstream** | `ss_player_skipstream.tscn` | Yes | unlocked |
| **Archstiletto** | `ss_player_arch.tscn` | **No** in prototype duel list; **yes** in Nuclide roster + Arch mode boss | n/a |

Internal id convention for Nuclide: `hero_collier`, `hero_vagrant`, `hero_beaumont`, `hero_archstiletto`, `hero_skipstream`, `hero_angel`, `hero_motionblue` (display names as listed).

---

## Per-character extrapolation (implemented in prototype)

### Collier

| Field | Prototype value | Notes for Nuclide |
|-------|-----------------|-------------------|
| HP | 4 (default `player_health.gd`) | `health` / `max_health` = 4 |
| Primary weapon | `revolver_projectile` instance | `fire_rate` **0.3s**, auto-reload TF2-style |
| Melee / hook attack | `HookMeleeAttack` | **2** damage, **0.6s** cooldown, parry-capable |
| Grapple | `HookController`, **max_charges = 2**, kickboost refill **2.6s** | Maps to Stiletto grapple + charge UI |
| Shared kit | Kickback v2, wall module, punish state | Standard |

### Beaumont

| Field | Prototype value | Notes for Nuclide |
|-------|-----------------|-------------------|
| HP | 4 | |
| Primary weapon | `revolver_projectile` (Beaumont script) | **10** round mag, **0.07s** fire rate, **1** damage per shot (standard bullet; prototype scene's 25 overridden per design), fast reload cadence |
| **Bullet jump** | `BulletJumpModule` | **18** jump force |
| **Lasso hook** | `LassoHook.tscn` | Pulls enemies to Beaumont; separate from grapple |
| Shared kit | Standard | Lasso counts as punishable tool |

### Vagrant

| Field | Prototype value | Notes for Nuclide |
|-------|-----------------|-------------------|
| HP | 4 | |
| Primary weapon | `spy_knife` / `vagrant_knife` | **1** damage swing, **10×** backstab, **0.8s** cooldown, **0.4m** melee radius |
| Throwable knife | recharge **2.0s** | Secondary projectile |
| **Warpstrike** | `warpstrike_module_test2.gd` | Blink along knife path; **1.0s** stun on hit; wall jump **20** force @ **45°** |
| Parry | `parry_component` on knife | Projectile parry |
| Shared kit | Standard | Warpstrike is punishable tool |

### Angel

| Field | Prototype value | Notes for Nuclide |
|-------|-----------------|-------------------|
| HP | 4 | |
| Primary weapon | `AngelSniper` | **1.5s** fire rate, **2.75s** reload; flechettes + triangle detonation (flechette scene null in scene—partial WIP) |
| Grapple | `HookController` | **1** charge, grounded recharge **4.0s**, air **5.5s**, max range **20m** |
| **Jets** | `jets_module.gd` | Ground cooldown **4.0s** |
| Drive system | `DriveAbilityManager` + gauge nodes | Extra ability layer—scope for follow-up |
| Shared kit | Standard | Jets + grapple punishable |

### Skipstream

| Field | Prototype value | Notes for Nuclide |
|-------|-----------------|-------------------|
| HP | 4 | |
| Primary weapon | `burst_fire_weapon.gd` | **9** rounds, **3**-shot burst, **0.13s** intra-burst, **0.75s** between bursts, **1** dmg per pellet, **2.0s** reload |
| **Double jump** | `double_jump_module.gd` | force **10**, boosted **18** vertical |
| **Sticky mine** | `sticky_mine_module.gd` | **1** active mine, **8s** throw cooldown, manual detonation stickyjump |
| Shared kit | Standard | Mine toss / stickyjump punishable |

### Motionblue (Mblue)

| Field | Prototype value | Notes for Nuclide |
|-------|-----------------|-------------------|
| HP | 4 | |
| Primary weapon | `mblue_weapon.gd` | **3**-round mag, **0.5s** fire rate, **25** damage (scene); explosive slug, blast-jump force **50** |
| **Grenade tool** | `mblueGrenade` node | **2** dmg, **4m** radius, **3s** cooldown, hold-charge **1s**, blast-jump radius **4m** |
| Shared kit | Standard | Grenade / slug blast punishable |

### Archstiletto (partial prototype)

| Field | Prototype value | User design | Gap |
|-------|-----------------|-------------|-----|
| HP | 4 (default only) | **100** (Arch mode) / **8** (normal) | **Not in prototype** |
| Weapon | Empty `WeaponManager` | **None in v1** — placeholder loadout; boss kit TBD | |
| Model | `arch` mesh + visible third-person weapon mesh | | |
| Shared kit | Kickback, wall, punish nodes present | Duel: 2 HP super armor + trajectory punish; mode: 2× air damage |
| Game integration | Lobby mode `archstiletto_*` maps | Arena **1-vs-many** (see arena gamemodes requirements) | Mode vs roster pick |

---

## Requirements (product)

- **R1.** Replace placeholder heroes (`hero_alpha` / `hero_bravo`) with the **seven** Stiletto `hero_*` defs inheriting `hero_base`, using extrapolated loadouts above.
- **R2.** Register all seven on appropriate rulesets via `teams.AddClass` / arena director rosters (exact per-mode list TBD).
- **R3.** **Shared movement + tool punish** behave identically across the six standard heroes; only signature tools/weapons differ.
- **R4.** **Tool punish** is implemented once in shared player/rules code and references a per-hero “punishable tools” list (data or component tags).
- **R5.** Character selection UI shows Stiletto display names and respects hero-lock / swap policies from the hero roster plan.
- **R6.** All seven heroes are selectable in v1; port order for implementation: Collier → Skipstream → Angel → Motionblue → Beaumont → Vagrant → Archstiletto.
- **R7.** **Archstiletto is both** a selectable roster hero (**8 HP** in normal duel/arena play) **and** the asymmetric boss (**100 HP**, altered tool-stun rules) when **Archstiletto arena mode** is active—the mode elevates the Arch pick, not a separate non-roster entity.
- **R8 (v1 scope, 2026-06-14):** First Nuclide pass ships **shared movement kit + primary weapon per hero only**—no secondaries (throwable knife, hook melee, flechettes, etc.). Signature movement tools deferred to follow-up.
- **R9 (v1 scope, 2026-06-14):** **Tool punish ships in v1** for **shared-kit actions only**—air dodge, air stall, and kickback usage while airborne. Punishable-tool list expands when signature tools land.

**Origin flows:** Pick Collier → spawn with revolver + standard 4 HP movement kit (hook deferred). Standard hero mid-air air dodge → take hit → tool punish on landing. Arch duel → 2 HP super armor then trajectory punish. Arch mode → 100 HP, 2× mid-air damage.

---

## Scope boundaries

### In scope (this roster pass)

- Data defs + **primary weapon only** per hero (prototype numbers); no secondaries in v1.
- Shared `hero_base` keys for HP, movement inheritance, reserved `def_ability_*`.
- Wiring roster registration and selection for implemented characters.
- Documenting Arch as **design overlay** on incomplete prototype.
- **Not in v1:** signature movement tools (grapple, lasso, warpstrike, mines, jets, bullet jump, grenade tool)—see R8.
- **In v1:** tool punish for shared-kit actions (air dodge, air stall, kickback)—see R9.

### Deferred

- **Signature movement tools** per hero (grapple, lasso, warpstrike, sticky mine, jets, bullet jump, grenade).
- **Secondary weapons** (Vagrant throw, Collier hook melee, Angel flechettes, Motionblue grenade tool).
- Full **Angel** flechette network + triangle kill (prototype partially disabled).
- **Drive gauge** system for Angel.
- **Archstiletto** boss weapon kit and 100 HP arena mode behavior (Arch is selectable in v1 at 8 HP with no weapon; mode elevation deferred).
- Generic ability framework (`def_ability_*` runtime)—signature tools may initially reuse weapon/Stiletto module pattern.
- Art export pipeline (Godot models → FTE `model` / `model_view` paths).

### Outside identity

- Changing the 4 HP duel format to traditional Quake 100 HP.
- Per-hero movement speed differentiation for the standard six (user explicitly forbids).

---

## Dependencies & assumptions

- Depends on existing hero roster implementation (`base/src/rules/shared.qc`, `selecthero`, VGUI).
- Depends on Stiletto movement in `stiletto_tuning.qc` remaining the shared movement implementation.
- **Assumption:** “Motionblue” = prototype **Mblue** (`ss_player_mblue.tscn`, id `mblue`).
- **Assumption:** Prototype damage integers map 1:1 to Nuclide HP chunks unless we introduce partial-HP weapons later.

---

## Resolved decisions

- **Archstiletto roster + mode (2026-06-14):** Selectable like the other six at **8 HP** in normal play; **Archstiletto arena mode** promotes the Arch player to **100 HP** boss with deferred/different tool stun—not a non-roster entity.
- **v1 kit scope (2026-06-14):** Weapons + shared movement only; signature tools deferred.
- **Beaumont / Vagrant gating (2026-06-14):** **Fully unlocked** in v1 hero selection alongside Collier, Skipstream, Angel, Motionblue—not gated like the Godot prototype duel roster.
- **Arch tool stun (2026-06-14):** **Duel (8 HP):** 2 HP super armor before punish; when punish applies, momentum preserved, no control until landing (not velocity zero / straight down). **Arch mode (100 HP):** double mid-air damage instead of standard tool punish. Super-armor buffer resets on heal/respawn unless playtest revises.
- **Tool punish v1 (2026-06-14):** Implement for shared kit only (air dodge, air stall, kickback); expand when signature tools ship.
- **Health pacing (2026-06-14):** Port prototype **1.3s** hit invuln + **12s** OOC heal-to-full for all roster heroes.
- **Secondary weapons (2026-06-14):** Deferred in v1—primary weapon only per hero.
- **Archstiletto v1 (2026-06-14):** Full selectable roster slot with **8 HP duel rules**; **no primary weapon** until boss kit is designed (placeholder loadout acceptable).
- **Placeholder heroes (2026-06-14):** **Remove** `hero_alpha` / `hero_bravo` when Stiletto roster ships—no parallel placeholder roster in player-facing UI.

---

## Sources

- Godot prototype: `D:\c drive\Godot\stiletto-protophase2` (scenes under `resource/entities/player/`, `resources/gamemodes/duel_game_mode_definition.tres`)
- Nuclide hero roster plan: `docs/plans/2026-06-14-001-feat-hero-roster-system-plan.md`
- Nuclide Stiletto movement: `src/shared/physics/stiletto_tuning.qc`
- Nuclide hero defs: `base/decls/def/heroes/`
