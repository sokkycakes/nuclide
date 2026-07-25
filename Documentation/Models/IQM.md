# Inter-Quake Model (IQM) {#iqm}

**IQM** is FTE’s common skeletal mesh + animation container. Nuclide also
ships **VVM** (IQM-FTE extensions); plain IQM is enough for third-person
heroes that do not need hitmeshes / model-events. See [VVM](VVM.md) for
the extended toolchain.

This page covers **player / hero IQM** wiring: export, entityDef `act_*`,
skeletal playback vs GoldSrc (CSO), and failure modes we hit with Smash
Ultimate → `joker.iqm` (Vagrant).

## Preview

```
modelviewer models/player/joker.iqm
```

PgUp / PgDn cycle framegroups; HUD shows `looped` / `unlooped`. If anims
are missing here, the file itself is wrong — fix export before QC.

## Export (Blender)

Use FTE’s `iqm_export` addon (or an equivalent IQM exporter).

| Setting | Why |
|---------|-----|
| **Animations** field required | Empty → mesh-only / empty anim table (tiny IQM, no clips). |
| `*` / `*.nuanmb` (local patch) | Expands all Smash `.nuanmb` actions; skips SAP Data. |
| `IQM_LOOP` | Set on locomotion (idle / walk / run). Leave **clear** on jump, crouch-enter, land, attacks. |
| **Scale** | Bake into the IQM. Player entities do **not** network `.scale`; hero `modelscale` will not change what clients see. |
| **Root Z** | Place feet at Quake hull bottom after scale (≈ **−36** for `VEC_HULL` ±36). |

Verify after export: `num_anims` > 0, clip names match what you will put
in the hero def, and loop flags match intent (`modelviewer`).

## Hero entityDef

Example: `base/decls/def/heroes/hero_vagrant.def`.

```
"model"        "models/player/joker.iqm"
"animBackend"  "0"   /* inherit from player — skeletal */

"act_idle"         "1"
"act_walk"         "4"
"act_run"          "3"
"act_jump"         "9"
"act_idle_crouch"  "16"
"act_walk_crouch"  "16"
```

Prefer **numeric framegroup indices** for IQM heroes. Name lookup
(`frameforname`) works when names match exactly, but indices avoid
CSQC / rename footguns. Indices are 0-based in the IQM anim table
(confirm with `modelviewer` or a header dump).

### Do not use empty `""` overrides

entityDef spawn data is tokenized as key/value pairs. Empty quoted values
are easy to mis-pair, and an empty `act_aim` does **not** disable aim —
`Activities_GetSequenceForEntity` then falls through to
`activities.decl` + `frameforaction`, which is wrong for IQM (see below).

Omit torso / aim keys and let inheritance point at CSO Bip01 /
`ref_aim_*` names: `gettagindex` misses → torso overlay skipped;
`frameforname` misses → `ACTIVITY_NOTFOUND` (−1).

## Player animation pipeline

Shared code: `src/shared/game/Player.qc`, `Actor.qc`,
`src/shared/system/activities.qc`.

1. **`RefreshPlayerAnimations` / `SetAnimationPrefix`** resolves
   `act_*` → sequence indices into `m_actIdle`, `m_actWalk`, …
2. **`UpdatePlayerAnimation`** picks `anim_bottom` / `anim_top` from
   velocity, crouch, jump, then advances `anim_*_time`.
3. **`animBackend` 0 (skeletal)** → `UpdatePlayerAnimation_Skeletal`:
   `skel_create` + `skel_build` for legs; optional torso overlay.

Always call `RefreshPlayerAnimations` after the player model / hero def
is valid (`MakePlayer`, `Spawned`, and on CSQC when
`PLAYER_MODELINDEX` / `PLAYER_WEAPON` change). Skipping it left
`m_actWalk` etc. at 0 → permanent “sequence 0” (often eyelid / idle).

### GoldSrc / CSO vs IQM

| | CSO `alice2`-family `.mdl` | Smash / custom IQM |
|--|---------------------------|--------------------|
| Skeleton | Bip01 ordered bones | Smash bone names (`Hip`, `Waist`, …) |
| Torso split | `torsoStart` / `torsoEnd` tags | Tags missing → **skip** torso `skel_build` |
| Activity fallback | HL activity codes via `frameforaction` | IQM anims usually have **action = −1** |
| Typical stuck look | Idle / early walk frames | Frozen eyelid (group 0) or T-pose |

**Torso overlay trap:** `gettagindex` returns **0** on miss. Passing
`skel_build(..., 0, 0)` means “all bones”. With a tiny retain fraction
toward the aim pose, gait is nearly replaced — looks like permanent idle
with rare flashes of walk. Guard:

```
if (m_torsoFirst >= 1 && m_torsoLast > m_torsoFirst)
    skel_build(... torso range ...);
```

### CSQC must have `declclass`

Client prediction **recomputes** `anim_bottom` from `m_act*` every frame.
Those acts come from entityDef keys via `declclass`, not from the
networked sequence alone.

IQM has no HL activity codes, so if CSQC `declclass` is empty,
`frameforaction` fails and every act becomes **−1**. QC then clamps to
**0** (BYTE-safe) → static wrong pose. CSO can still limp along via
embedded activities; IQM cannot.

`ReceivePlayerEntity` / `RefreshPlayerAnimations` must sync:

```
declclass = EntityDef_NameFromNetID(entityDefID);
```

whenever `entityDefID` is known — not only on a MODELINDEX bit edge.

Debug: `anim_debug 1` then re-select the hero. Healthy lines look like:

```
SetAnimationPrefix decl=hero_vagrant idle=1 walk=4 run=3 jump=9 aim=-1
```

All-`−1` rows mean decl / act resolve failed on that VM.

### One-shot crouch / jump

`UpdatePlayerAnimation` used to **wrap** `anim_bottom_time` whenever it
exceeded `frameduration`, which forced a loop even when the IQM had
`IQM_LOOP` clear.

Jump (`m_actJump`) and crouch (`m_actIdleCrouch` / `m_actWalkCrouch`) are
treated as **one-shots**: time resets on enter, then **clamps** to the
last pose. Idle / walk / run still wrap (loop).

Export still matters: clear `IQM_LOOP` on those clips so `modelviewer`
and any engine-native playback agree.

## Scale and hull

Quake player hull is roughly 72u tall (`VEC_HULL` ±36). Smash characters
export tiny; bake **Scale ≈ 4** (project-specific) and a negative root Z
so feet sit on the hull floor. Do not rely on networked `.scale`.

## Checklist (new IQM hero)

1. Export with animations + correct loop flags; preview in `modelviewer`.
2. Place under `base/models/player/…`, set hero `model`.
3. Map `act_idle` / `act_walk` / `act_run` / `act_jump` / crouch (prefer indices).
4. Keep `animBackend` skeletal (0); do not invent empty torso/aim keys.
5. Restart game (defs are runtime); rebuild progs only if QC changed.
6. `cmd selecthero <hero>`; `anim_debug 1` — no all-`−1` resolves.
7. Confirm walk loops, crouch/jump play once and hold.

## Related code

| Piece | Path |
|-------|------|
| Hero example | `base/decls/def/heroes/hero_vagrant.def` |
| Player anim | `src/shared/game/Player.qc` |
| Act resolve | `src/shared/system/activities.qc` |
| Prefix / tags | `src/shared/game/Actor.qc` |
| Base player def | `base/decls/def/player.def` |
| Smash → GoldSrc retarget notes | `docs/workflows/smash-ultimate-to-goldsrc-retarget.md` |
