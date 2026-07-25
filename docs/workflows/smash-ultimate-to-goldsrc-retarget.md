# Smash Ultimate → GoldSrc (Bip01) Animation Retarget

Repeatable Blender workflow for retargeting Smash Ultimate `nuanmb` animation (via `smush_blender_import`) onto Valve/GoldSrc **Bip01** player skeletons for export back to GoldSrc / Nuclide.

Validated on Blender **5.1.x** with official Blender Lab MCP. First successful target: HEV-style `helmet_ARM` from Samus `a02run.nuanmb`.

---

## Goal

Produce a GoldSrc-ready action on a Bip01 armature where:

1. Motion matches Smash (run cycle, weight shift, limb swing).
2. **Rest pose** stays a normal upright Bip01 bind (facing ≈ world −Y, up ≈ +Z).
3. Model origin stays at the feet / ground (not floated or swung aside).
4. Feet do not persistently clip through the floor.
5. Animation is keyed as **local bone rotations** (and root Z bob), not object-level hacks.

---

## Prerequisites

| Item | Notes |
|------|--------|
| Blender 5.1+ | Slotted actions; older Rokoko builds break here |
| Source armature | `smush_blender_import` (or equivalent Smash import) with the `*.nuanmb` action |
| Dest armature | GoldSrc `Bip01*` hierarchy (e.g. `helmet_ARM`, `aswat_ARM`) |
| Scale | Smash is huge (~20 unit height span vs ~1.2 m Bip01). Expect scale ≈ **0.06–0.07** for root translation only |
| Tooling | Custom bake script (this doc). Official Retarget add-on / Rokoko are **not** sufficient alone |

### Why stock tools fail

- **Rokoko on Blender 5**: fcurve / slotted-action breakage.
- **Official Retarget Bind**: scales/moves the Smash source, bone-axis mismatch → pretzeling.
- **Naive world-matrix copy**: Smash root helpers (`Trans` / long horizontal bones) explode stub-length Bip01 bones.
- **Raw hip-local matrix deltas**: Smash Hip axes ≠ Bip01 Pelvis axes (see below) → arms fold into the torso “on the wrong side.”

---

## Skeleton facts (read these before changing the bake)

### Smash hierarchy (relevant roots)

```
Trans → Rot → Hip → LegC → …
                └→ (spine / clavicles / …)
```

- **`Hip`** carries the weight-shift / pelvis roll that keeps feet planted.
- **`LegC`** is a **child of Hip**. Its local rotation is often identity; use it for **vertical bob** (world Z), not as the hip rotator.
- Do **not** treat Smash `Trans` as Bip01 rotation — it is a long helper, not a pelvis.

### GoldSrc hierarchy (typical)

```
Bip01 → Bip01 Pelvis → spine / legs
                    → (arms may parent under Neck on some HEV rigs)
```

- Object **origin** ≈ feet / ground.
- **`Bip01`** rest sits near pelvis height (often ~0.6–0.8 above origin). That distance is **normal**, not a bug.
- Limb bones often share the same rest aim axis (both upper arms +Y); L/R is mostly **placement + roll**, not opposite rest aims.

### Axis mismatch (root cause of “arms into body”)

| Space | Smash Hip (typical) | Bip01 Pelvis (typical) |
|-------|---------------------|-------------------------|
| Up | local **Y** | local **X** |
| Left | local **Z** | local **Z** |
| Forward | ≈ −local **X** | local **Y** |

Samus arms at rest often extend **laterally** in character space; Bip01 arms often **hang down**. Copying a world/hip-local swing quaternion therefore does **not** move Bip01 limbs the way Samus moved — Samus’s swing can be nearly parallel to the helmet hang axis, so dest arms barely leave rest or both collapse to the same side.

**Fix:** retarget limb **aim directions** in a shared **anatomical** basis (right / up / forward), not raw Hip local axes.

### Spazzing (root cause)

Building the character basis every frame from **live shoulder positions** feeds arm motion back into “what is left/right/up.” Pelvis/spine then get ~180° quaternion pops.

**Fix:** build anatomical axes **once from rest** shoulders/head, then lock that frame to the **posed hip/pelvis**:

```text
char_pose = hip_pose @ hip_rest.inverted() @ char_rest
```

### Why HL1 remaps look “wrong” (legs side-to-side, huge shoulders)

Retargeting does **not** copy “move this foot straight up 10 cm.” It copies something closer to:

> Relative to this character’s hips, rotate this bone from its **rest** orientation to its **posed** orientation.

That only looks the same on both characters when their **rest** orientations mean the same thing in space. Smash Ultimate and Valve **Bip01** almost never do.

| What you see on Smash (Joker/Samus) | What happens on Bip01 (helmet) | Why |
|-------------------------------------|--------------------------------|-----|
| Leg pumps mostly **up/down** in the viewport | Same step becomes a **left/right** kick | Rest bone aim + roll differ; the swing plane remaps when the delta is applied to the HL1 rest pose |
| Arms/shoulders look mild | Shoulders **pump** or fold hard | Smash rest is more “fighter”; Bip01 upper arms **hang down**, often parented under **Neck**, with stub clavicles — matching aim needs a large local rotation |
| Chest heading stays stable | Torso **yaws** left/right hard | Dumping full **Bust** matrix onto **`Bip01 Spine2`** remaps a stable Smash chest into mid-spine twist/yaw on HL1 |
| Motion looks “normal energy” | Feels exaggerated even at 1:1 | Stub bones + hierarchy mismatch amplify **angles**; length/scale of the mesh is unrelated |

Important separations:

- **Scale** (Smash height → Bip01 height) only affects root **Z bob** from `LegC`. It does **not** choose left vs right or shoulder pump.
- **Intensity** (slerp toward rest) only makes a bad transfer quieter. It will **not** fix a swing that landed in the wrong plane.
- **Name mapping** (`ShoulderL` → `Bip01 L Arm1`) is necessary but not sufficient. Wrong plane/yaw usually means rest-axis / hierarchy / over-mapping spine or clavicles.

Practical mitigations used in later bakes:

1. Limb **aim** in a shared anatomical frame (not raw Hip-local matrices).
2. Prefer **relative rest→pose swing** on limbs (`swing @ dst_rest_aim`), not absolute “point where Smash points.” Absolute aim forces hanging Bip01 arms to match fighter-rest directions and pumps shoulders.
3. **Sagittal-lock legs** for walks: zero the character-right component of leg aim before applying swing (keeps stride in the forward/up plane).
4. **Damp arm swing weight** separately (e.g. ~0.35) — Smash shoulder angles look mild on a T-ish fighter rest and huge on hanging HEV arms.
5. Leave **`Bip01 L/R Arm` clavicles** near rest; aim upper/lower only (avoids chain compounding).
6. Do **not** dump all of **Bust** into **`Spine2`**. Prefer distributing torso (e.g. **Waist→Spine1**, **Bust→Spine3**) and/or **strip yaw around character-up** on pelvis/torso deltas.
7. Fix facing with a **constant `Bip01` offset** baked into local keys — not object rotation. Do **not** reuse a facing/Pelvis offset from a different source clip (e.g. Samus run → Joker walk): a large Pelvis yaw tilts the sagittal plane into world X and looks like left/right legs again.

---

## Bone map (Smash → Bip01)

Adjust if the dest rig is missing bones (some HEV rigs omit mid-spine / toes / right fingers — Samus arm cannon often has no right finger chain).

| Dest (Bip01) | Source (Smash) | Role |
|--------------|----------------|------|
| `Bip01` | `LegC` (Z bob) + facing offset | Root: XY locked, Z bob, constant facing |
| `Bip01 Pelvis` | `Hip` | Weight shift / foot plant (prefer variation + strip yaw around up) |
| `Bip01 Spine1` | `Waist` | Lower torso (prefer over dumping Bust into Spine2) |
| `Bip01 Spine3` | `Bust` | Chest (keep Spine / Spine2 nearer rest if needed) |
| `Bip01 Neck` | `Neck` | |
| `Bip01 Head` | `Head` | |
| `Bip01 L/R Arm` | *(often leave at rest)* | Stub clavicles; aiming them compounds flail |
| `Bip01 L/R Arm1` | `ShoulderL/R` | Upper arm aim |
| `Bip01 L/R Arm2` | `ArmL/R` | Forearm aim |
| `Bip01 L/R Hand` | `HandL/R` | |
| `Bip01 L/R Leg` | `LegL/R` | |
| `Bip01 L/R Leg1` | `KneeL/R` | |
| `Bip01 L/R Foot` | `FootL/R` | |
| Fingers (optional) | `FingerL*` / `FingerR*` | Right side often missing on Samus |

---

## Workflow overview

```text
1. Import / align scene
2. Clear dest pose + old bake action
3. Bake core retarget (script)
4. Validate motion (no spazz, sides correct, feet)
5. Fix facing with a LOCAL Bip01 tweak → bake offset into all frames
6. Origin / rest hygiene (feet on origin, object rot = 0)
7. Export to GoldSrc (SMD/etc.)
```

---

## Phase 1 — Scene setup

1. Source and dest armatures in one Blender file; source action active (`a02run.nuanmb` or similar).
2. Dest meshes parented to dest armature (so origin fixes move skin + bones together).
3. Clear dest constraints; set all pose bones to **Quaternion** rotation.
4. Delete any previous bake action on dest (`helmet_a02run`, etc.).
5. Keep dest **object** rotation/scale at identity during the bake. Do **not** “fix facing” with object rotate as the permanent solution (it twists **Rest Position**).

---

## Phase 2 — Core bake algorithm

Bake **hierarchy order** (parents before children). After **every** `pose_bone.matrix = …`, call:

```python
bpy.context.view_layer.update()
```

Without per-bone depsgraph updates, early frames flail (stale parent matrices).

### 2.1 Shared helpers

**Height scale** (root translation only):

```text
scale = dest_height_head_to_foot / src_height_head_to_foot
```

**Anatomical rest basis** (once):

```text
right   = normalize(rest(shR) - rest(shL))
up      = normalize(rest(head) - rest(hip))
forward = normalize(up × right)
# re-orthonormalize…
char_rest.translation = rest(hip)
```

**Posed character basis** (hip-locked):

```text
char_pose = hip_pose @ hip_rest⁻¹ @ char_rest
```

**Quaternion continuity** before every key:

```python
if prev.dot(q) < 0:
    q.negate()
```

**FK translation lock** (limbs/spine): keep rest length along the parent chain; apply **rotation only**:

```text
pose.matrix = Translation(fk_rest_translation) @ desired_rotation
```

### 2.2 Root — `Bip01`

| Channel | Source | Rule |
|---------|--------|------|
| Location XY | — | **Always 0** (in-place) |
| Location Z | `LegC` world Z − rest Z | `(dz - mean(dz)) * scale` so bob is centered (no permanent crouch) |
| Rotation | Constant facing offset | Do **not** copy Smash `Trans`/`Rot` wholesale; set facing in Phase 4 |

`LegC` local rotation is usually identity; bob comes from its **posed height**, not its local quat.

### 2.3 Pelvis — `Bip01 Pelvis` ← `Hip`

Parent-relative delta (Smash `Hip` under `Rot` → dest Pelvis under `Bip01`):

```text
src_delta = (Rot_pose⁻¹ @ Hip_pose) @ (Rot_rest⁻¹ @ Hip_rest)⁻¹
desired_pelvis_world = Bip01_pose @ (src_delta @ pelvis_rel_rest)
```

This restores Samus hip roll/weight shift (~tens of degrees over a run) so feet plant instead of skating through the floor.

After changing Pelvis, **re-aim legs** (section 2.5) so leg keys follow the new parent.

### 2.4 Body — spine / neck / head

Full orientation delta in **anatomical** space:

```text
src_rel_pose = char_src⁻¹ @ bone_pose_world
delta = src_rel_pose @ src_rel_rest⁻¹
desired = char_dst @ (delta @ dst_rel_rest)
```

Use hip-locked `char_*` bases. Prefer fewer spine samples (`Bust` → `Spine2`) over copying every Smash waist bone onto every Bip01 spine (less compounding).

### 2.5 Limbs — aim retarget (arms & legs)

For each mapped bone with a child tip:

```text
want   = aim_dir(src_bone → src_child) in src char space
align  = rotation_difference(dst_rest_aim, want)
desired = char_dst @ (align @ dst_rel_rest)
```

- Match **character-space aim**, not “same swing quaternion as source.”
- Hands/feet without a further tip: use the body-style matrix delta in char space, or aim from prior bone → hand/foot.
- Re-run leg aims whenever Pelvis is re-baked.

### 2.6 Keying

Per frame, after pose is stable:

1. Key `Bip01` location + rotation_quaternion.
2. For other mapped bones: `location = (0,0,0)`, key location + rotation_quaternion.
3. Set fcurve interpolation to **LINEAR** (or your export preference).

---

## Phase 3 — Validation checklist

Run these before export:

| Check | Pass criteria |
|-------|----------------|
| Spazz | Max per-frame bone turn ≲ a few degrees (not ~180°) |
| Hand sides | L/R hands on opposite character-space sides (match Samus signs) |
| Feet | Min foot Z over clip ≈ 0; few/no deep negative frames |
| Pelvis live | Pelvis quat span over clip ≈ Smash Hip span (not frozen identity) |
| Rest Position | Armature Rest Position upright, facing −Y, **object rotation 0** |
| Origin | Feet midpoint near world origin; object not swung away |

---

## Phase 4 — Facing correction (Bip01 local offset bake)

Core bake often leaves the character pitched/yawed wrong while limb *motion* looks right. Fix **in the viewport on `Bip01`**, then bake the delta into every frame.

### Preferred: tweak in **Local** rotation

1. Pose Mode → select `Bip01`.
2. Transform orientation: **Local**.
3. Rotate until the posed character looks correct on the current frame (do not apply object rotation).
4. Run the bake-offset script:

```python
# Local tweak: R_new = R_keyed @ offset
offset = keyed_q.inverted() @ current_q
for each frame:
    new_q = keyed_q(frame) @ offset
    # quaternion continuity…
    keyframe_insert rotation_quaternion
```

### If you tweaked with **Global** gizmo instead

```python
# World/parent-space: R_new = offset @ R_keyed
offset = current_q @ keyed_q.inverted()
for each frame:
    new_q = offset @ keyed_q(frame)
```

Global green (Y) will **not** 1:1 match a local axis — always derive `offset` from keyed vs current quats, never from “I rotated Y by N degrees” alone.

### Do **not** leave facing as object rotation

Object rotation fixes the animation preview but makes **Rest Position** look rotated/offset. If you already did that:

1. Sample each bone’s **world** matrix across the clip (with object rot).
2. Clear object rotation to identity.
3. Re-apply those world matrices into local pose keys.
4. Recenter feet to origin.

---

## Phase 5 — Origin / rest hygiene

After any object move/rotate:

1. Object rotation must end at **(0,0,0)** for export.
2. Slide armature (meshes parented) so **feet midpoint** is at world origin (XY and Z).
3. Accept that with intentional lean, bbox center may sit slightly off the foot line — that is tilt, not pivot error.
4. Confirm Armature **Rest Position** still looks like a normal standing Bip01.

---

## Phase 6 — Export notes (GoldSrc)

- Export the **dest action** only; Smash armature stays in the `.blend` as reference.
- Apply/confirm object transforms are identity before SMD/QC export.
- Bip01 above origin at rest is expected; do not “fix” by moving rest bones to (0,0,0).
- Re-test in-engine: spawn origin, feet vs floor, and that idle/rest reference pose is upright.

---

## Failed approaches (do not revive without a new reason)

| Approach | Symptom | Why |
|----------|---------|-----|
| Rokoko on Blender 5 | Broken keys | Slotted actions |
| Official Retarget Bind | Pretzel / scaled Smash | Axis + scale mismatch |
| Full world matrix copy from `Trans` | Dest explodes | Wrong root semantics |
| World rotation delta on limbs | Arms into body, mirrored sides | Rest aims differ ~90°; Hip axes disagree |
| `swing = rest→pose` then `swing @ dst_rest` | Arms barely move | Swing axis ∥ dest hang axis |
| Char basis from **posed** shoulders | Whole model spazzes | Feedback into left/right/up |
| Object rotate for facing | Rest pose wrong; XY orbit | Object matrix applies to rest too |
| Freeze Pelvis / skip Hip | Feet clip floor | Lost Smash weight shift |
| Map Hip → Bip01 only, ignore Pelvis | Awkward / incomplete | Dest legs hang under Pelvis |
| Full **Bust** matrix → **`Spine2`** | Body yaws L/R hard; Smash chest looks stable | Rest-axis remap; mid-spine absorbs chest twist as heading |
| Aim every arm bone incl. clavicles | Shoulder flail / exaggerated shrug | Stub chain compounding under Neck |
| Lower “intensity” to fix L/R legs | Quieter wrong plane | Intensity ≠ swing-plane correction |
| Blame height **scale** for limb weirdness | — | Scale only scales LegC→root Z bob |

---

## Minimal operator order (cheat sheet)

1. Clear dest action/constraints; quat mode; object transform identity.
2. Bake: LegC→Bip01 Z bob (XY=0); Hip→Pelvis parent-delta; body matrix in hip-locked anatomical space; limbs aim in that space; `view_layer.update()` per bone; quat continuity.
3. Re-aim legs if Pelvis changed.
4. Local-tweak `Bip01` facing → `new = keyed @ offset` all frames.
5. Feet to origin; object rot stays 0; validate Rest Position.
6. Export.

---

## Reference session

- Source: Smash Ultimate Samus / `smush_blender_import` / `a02run.nuanmb` (frames ~1–111).
- Dest: `helmet_ARM` (HEV Bip01; arms under Neck).
- Bake action name used: `helmet_a02run`.
- Retarget presets also exist under Blender user presets (optional, not required for this bake):
  - `%APPDATA%/Blender Foundation/Blender/5.1/scripts/presets/retarget/humanoid/Smash_Ultimate_Samus.py`
  - `%APPDATA%/Blender Foundation/Blender/5.1/scripts/presets/retarget/humanoid/GoldSrc_Bip01.py`

---

## Next improvements (optional)

- Package Phase 2–4 as a single Blender operator / addon with the bone map as a preset.
- Add twist extraction for forearms/hands (aim-only leaves roll at rest).
- Per-clip foot lock / ground constraint pass after bake.
- Auto-detect Smash↔Bip01 map from name heuristics with a confirm UI.
