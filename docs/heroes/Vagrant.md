# Vagrant — Knife Thrower

The Vagrant is a close-quarters skirmisher who throws knives, melees with blade swings,
and teleports via the **warpknife**.

## Controls

| Input | Action |
|-------|--------|
| **M1** | Throw knife projectile (arc physics, 1 shot, 2s reload) |
| **Q**  | Melee swing (89u range) + bullet cut + backstab |
| **M2** | Warpknife: throw / teleport / hold-to-pickup (1.5s) |
| **R**  | — (no function) |

## Backstab

Hitting an enemy from **behind** with Q instantly sets their health to **0**,
bypassing HP and any future armor/barrier system.

Detection: the target's yaw angle is compared to the direction from target to
attacker. If the difference exceeds **120°** (the attacker is behind the target),
it is a backstab.

## Warpknife

- **Throw**: press M2. Spawns a sticky projectile that embeds in surfaces.
- **Teleport**: press M2 again while the knife is stuck. Teleports you to it.
- **Pick up**: hold M2 within **32 units** of the stuck knife for **1.5 seconds**.
- **Despawn**: the knife vanishes if you take damage after throwing it.

### Cooldown

Scaled by teleport distance:

| Distance | Cooldown |
|----------|----------|
| 0–512 units | **1s** (close reposition) |
| 512–2000 units | ramps 1s → **10s** |
| ≥2000 units | **10s** (max) |

### Wall Stick (vertical surfaces)

Teleporting to a knife on a wall puts you in **wall cling** state with
**1.5 seconds** of stick (gravity reduced, downward velocity zeroed via
air stall timer). After 1.5s you slide down naturally.

Wall jumping during the stick period immediately cancels it. The jump
launches in your **look direction** (not away from the wall normal) at
**double** normal wall jump power.

### Long-Range Freeze

Teleports of **≥512 units** also apply a **1.3-second freeze** (`VFL_FROZEN`):
no movement, no gravity, then auto-release.

## Normal Knife Throw

- 1 round clip, 2-second reload
- Projectile: MOVETYPE_TOSS, gravity 1.0, velocity 1100, modelscale 5
- During the 2s reload: melee, throw, and warpknife throw are all blocked

## Melee

- 89 unit range (75% of Collier's 118)
- Simple forward traceline (no hull trace, no cleave)
- Can cut projectiles (`can_cut`) with a 1.75s deflect cooldown
- Full clip/ammo/reserve integration

## Projectile Definitions

### `projectile_vagrant_throwknife` (normal throw)
- Standalone (not inherited from `projectile_nail`)
- Sticky: no — passes through/impacts normally
- Same gravity/velocity/scale as the throw

### `projectile_vagrant_warpknife` (warpknife)
- `"stick_to_world" "1"` — embeds in surfaces
- Picked up within 32 units
- Despawns on damage event (`m_stilettoLastDamageTime > m_flWarpThrowTime`)

## Technical Notes

- Inherits **ncWeapon** directly (not ncWeaponBaseMelee)
- Melee re-implemented from ncWeaponBaseMelee as a simple traceline
  to avoid compiler crashes in fteqcc.exe (git-6739)
- Ghost on teleport: frame 13.40 of `treadwater`, alpha 0.3, 1s duration,
  faces horizontal travel direction
- Wall-stick uses `m_stilettoAirStallEnd` (air stall timer) for gravity
  reduction and `VFL_STILETTO_WALL` + `m_stilettoWallNorm` for wall cling
- Long-range freeze uses `VFL_FROZEN` cleared by `FreezeEndThink` think
- Viewmodel hides during reload via `m_weaponFireInfoValue` (networked to client)
