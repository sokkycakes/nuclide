---
name: fte_distill_math
description: Converts data types and coordinate systems between Quake (Z-up, scale 1:1) and Godot (Y-up, scale 1:0.0254 or 1:1). Handles vec3_t, quat_t, trace_t conversions. Use when converting Quake coordinates to Godot Vector3/Basis, wrapping FTE SV_Trace, or converting AABB between coordinate systems.
---

# FTE Distill Math

Coordinate system and data type conversions between Quake and Godot.

## Coordinate System Differences

**Quake:**
- Z-up coordinate system
- Scale: 1:1 (1 Quake unit = 1 unit)

**Godot:**
- Y-up coordinate system  
- Scale: 1:0.0254 (1 Quake unit = 0.0254 meters) OR 1:1 depending on configuration
- Uses Vector3 and Basis types

## Conversion Rules

### Vector3 Conversion (vec3_t → Vector3)

Apply coordinate transformation:
```
Godot_Y = Quake_Z
Godot_X = Quake_X  
Godot_Z = -Quake_Y
```

**Example:**
```gdscript
# Quake vec3_t: (x=100, y=200, z=300)
# Godot Vector3: (100, 300, -200)
func quake_to_godot_vec3(quake_vec: Array) -> Vector3:
    return Vector3(quake_vec[0], quake_vec[2], -quake_vec[1])
```

### Quaternion Conversion (quat_t → Basis)

Convert quaternion to Godot Basis, applying coordinate system transformation:

```gdscript
func quake_to_godot_quat(quake_quat: Array) -> Basis:
    # quat_t is typically [x, y, z, w]
    var q = Quaternion(quake_quat[0], quake_quat[2], -quake_quat[1], quake_quat[3])
    return Basis(q)
```

### Trace Conversion (trace_t → Dictionary)

Wrap FTE SV_Trace results into a Godot-compatible dictionary:

```gdscript
func quake_to_godot_trace(trace_result: Dictionary) -> Dictionary:
    return {
        "all_solid": trace_result.all_solid,
        "start_solid": trace_result.start_solid,
        "fraction": trace_result.fraction,
        "endpos": quake_to_godot_vec3(trace_result.endpos),
        "plane": {
            "normal": quake_to_godot_vec3(trace_result.plane.normal),
            "dist": trace_result.plane.dist
        },
        "surface": trace_result.surface,
        "contents": trace_result.contents,
        "ent": trace_result.ent
    }
```

## AABB Conversion

Godot AABB uses **center-extents** format. Convert Quake AABB (min-max) to Godot AABB:

```gdscript
func quake_to_godot_aabb(quake_min: Array, quake_max: Array) -> AABB:
    var min_vec = quake_to_godot_vec3(quake_min)
    var max_vec = quake_to_godot_vec3(quake_max)
    var center = (min_vec + max_vec) / 2.0
    var size = max_vec - min_vec
    return AABB(center, size)
```

## Scale Conversion

Apply scale factor if needed (1:0.0254 conversion):

```gdscript
const QUAKE_TO_GODOT_SCALE = 0.0254  # 1 Quake unit = 0.0254 meters

func apply_scale(vec: Vector3, use_scale: bool = true) -> Vector3:
    if use_scale:
        return vec * QUAKE_TO_GODOT_SCALE
    return vec
```

## Implementation Checklist

When implementing conversions:

- [ ] Use Vector3 for all Godot vector outputs
- [ ] Use Basis for all Godot rotation outputs  
- [ ] Apply coordinate transformation: Y=Z, X=X, Z=-Y
- [ ] Convert AABB from min-max to center-extents format
- [ ] Wrap FTE SV_Trace to return dictionary with converted vectors
- [ ] Apply scale factor (0.0254) if required by project configuration

## Reverse Conversions (Godot → Quake)

```gdscript
func godot_to_quake_vec3(godot_vec: Vector3) -> Array:
    return [godot_vec.x, -godot_vec.z, godot_vec.y]

func godot_to_quake_quat(godot_basis: Basis) -> Array:
    var q = godot_basis.get_quaternion()
    return [q.x, -q.z, q.y, q.w]
```
