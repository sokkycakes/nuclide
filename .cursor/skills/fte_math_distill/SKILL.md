---
name: fte_math_distill
description: Translates coordinate systems and units between Quake and Godot using C/C++ inline macros and wrapper functions. Converts vec3_t, quat_t, mplane_t between Z-up (Quake) and Y-up (Godot) coordinate systems. Use when creating fte_godot_math.h header, wrapping SV_LinkEdict or SV_Trace functions, or converting Quake math types to Godot-compatible structures.
---

# FTE Math Distill

C/C++ coordinate system and unit conversions between Quake and Godot using inline macros and wrapper functions.

## Core Objective

Create `fte_godot_math.h` header with inline conversion macros and apply conversions to all `SV_LinkEdict` and `SV_Trace` wrappers.

## Coordinate System Conversion

**Quake:** Z-up coordinate system  
**Godot:** Y-up coordinate system

**Conversion Formula:**
```
Godot.x = Quake.x
Godot.y = Quake.z
Godot.z = -Quake.y
```

## Scale Conversion

**Default scale:** 1 Quake Unit = 0.0254 Godot Meters (standard scale)  
**Alternative:** 1:1 scale (no unit conversion)

## Input Types

- `vec3_t` - 3D vector (float[3] or struct with x, y, z)
- `quat_t` - Quaternion (float[4] or struct with x, y, z, w)
- `mplane_t` - Plane structure (normal vec3_t + distance float)

## Implementation: fte_godot_math.h Header

### Header Structure

```c
#ifndef FTE_GODOT_MATH_H
#define FTE_GODOT_MATH_H

#include "q_shared.h"  // For vec3_t, quat_t, mplane_t definitions

#ifdef __cplusplus
extern "C" {
#endif

// Scale configuration
#ifndef QUAKE_TO_GODOT_SCALE
#define QUAKE_TO_GODOT_SCALE 0.0254f  // Default: 1 Quake unit = 0.0254 meters
#endif

// Option to disable scaling (1:1)
#ifndef FTE_USE_SCALE
#define FTE_USE_SCALE 1  // Set to 0 for 1:1 scale
#endif

// ... conversion macros and functions ...

#ifdef __cplusplus
}
#endif

#endif // FTE_GODOT_MATH_H
```

### vec3_t Conversion Macros

**Quake to Godot (Z-up → Y-up):**

```c
// Inline macro for vec3_t conversion
#define QUAKE_TO_GODOT_VEC3(qvec, gvec) \
    do { \
        (gvec)[0] = (qvec)[0];                    /* X stays X */ \
        (gvec)[1] = (qvec)[2];                    /* Y becomes Z */ \
        (gvec)[2] = -(qvec)[1];                   /* Z becomes -Y */ \
        if (FTE_USE_SCALE) { \
            (gvec)[0] *= QUAKE_TO_GODOT_SCALE; \
            (gvec)[1] *= QUAKE_TO_GODOT_SCALE; \
            (gvec)[2] *= QUAKE_TO_GODOT_SCALE; \
        } \
    } while(0)

// Function version (for non-macro contexts)
static inline void quake_to_godot_vec3(const vec3_t qvec, float gvec[3]) {
    gvec[0] = qvec[0];
    gvec[1] = qvec[2];
    gvec[2] = -qvec[1];
    if (FTE_USE_SCALE) {
        gvec[0] *= QUAKE_TO_GODOT_SCALE;
        gvec[1] *= QUAKE_TO_GODOT_SCALE;
        gvec[2] *= QUAKE_TO_GODOT_SCALE;
    }
}
```

**Godot to Quake (Y-up → Z-up):**

```c
// Inline macro for reverse conversion
#define GODOT_TO_QUAKE_VEC3(gvec, qvec) \
    do { \
        float tx = (gvec)[0]; \
        float ty = (gvec)[1]; \
        float tz = (gvec)[2]; \
        if (FTE_USE_SCALE) { \
            tx /= QUAKE_TO_GODOT_SCALE; \
            ty /= QUAKE_TO_GODOT_SCALE; \
            tz /= QUAKE_TO_GODOT_SCALE; \
        } \
        (qvec)[0] = tx;                    /* X stays X */ \
        (qvec)[1] = -tz;                   /* Y becomes -Z */ \
        (qvec)[2] = ty;                    /* Z becomes Y */ \
    } while(0)

// Function version
static inline void godot_to_quake_vec3(const float gvec[3], vec3_t qvec) {
    float tx = gvec[0];
    float ty = gvec[1];
    float tz = gvec[2];
    if (FTE_USE_SCALE) {
        tx /= QUAKE_TO_GODOT_SCALE;
        ty /= QUAKE_TO_GODOT_SCALE;
        tz /= QUAKE_TO_GODOT_SCALE;
    }
    qvec[0] = tx;
    qvec[1] = -tz;
    qvec[2] = ty;
}
```

### quat_t Conversion Macros

**Quake to Godot quaternion:**

```c
// Quaternion conversion (quat_t is typically [x, y, z, w])
#define QUAKE_TO_GODOT_QUAT(qquat, gquat) \
    do { \
        (gquat)[0] = (qquat)[0];                    /* X stays X */ \
        (gquat)[1] = (qquat)[2];                    /* Y becomes Z */ \
        (gquat)[2] = -(qquat)[1];                   /* Z becomes -Y */ \
        (gquat)[3] = (qquat)[3];                    /* W stays W */ \
    } while(0)

// Function version
static inline void quake_to_godot_quat(const quat_t qquat, float gquat[4]) {
    gquat[0] = qquat[0];
    gquat[1] = qquat[2];
    gquat[2] = -qquat[1];
    gquat[3] = qquat[3];
}
```

**Godot to Quake quaternion:**

```c
#define GODOT_TO_QUAKE_QUAT(gquat, qquat) \
    do { \
        (qquat)[0] = (gquat)[0];                    /* X stays X */ \
        (qquat)[1] = -(gquat)[2];                  /* Y becomes -Z */ \
        (qquat)[2] = (gquat)[1];                   /* Z becomes Y */ \
        (qquat)[3] = (gquat)[3];                   /* W stays W */ \
    } while(0)

// Function version
static inline void godot_to_quake_quat(const float gquat[4], quat_t qquat) {
    qquat[0] = gquat[0];
    qquat[1] = -gquat[2];
    qquat[2] = gquat[1];
    qquat[3] = gquat[3];
}
```

### mplane_t Conversion

**Plane structure conversion:**

```c
// mplane_t typically has: vec3_t normal, float dist
#define QUAKE_TO_GODOT_PLANE(qplane, gnormal, gdist) \
    do { \
        QUAKE_TO_GODOT_VEC3((qplane)->normal, gnormal); \
        if (FTE_USE_SCALE) { \
            (gdist) = (qplane)->dist * QUAKE_TO_GODOT_SCALE; \
        } else { \
            (gdist) = (qplane)->dist; \
        } \
    } while(0)

// Function version
static inline void quake_to_godot_plane(const mplane_t *qplane, float gnormal[3], float *gdist) {
    quake_to_godot_vec3(qplane->normal, gnormal);
    if (FTE_USE_SCALE) {
        *gdist = qplane->dist * QUAKE_TO_GODOT_SCALE;
    } else {
        *gdist = qplane->dist;
    }
}

// Reverse conversion
#define GODOT_TO_QUAKE_PLANE(gnormal, gdist, qplane) \
    do { \
        GODOT_TO_QUAKE_VEC3(gnormal, (qplane)->normal); \
        if (FTE_USE_SCALE) { \
            (qplane)->dist = (gdist) / QUAKE_TO_GODOT_SCALE; \
        } else { \
            (qplane)->dist = (gdist); \
        } \
    } while(0)

static inline void godot_to_quake_plane(const float gnormal[3], float gdist, mplane_t *qplane) {
    godot_to_quake_vec3(gnormal, qplane->normal);
    if (FTE_USE_SCALE) {
        qplane->dist = gdist / QUAKE_TO_GODOT_SCALE;
    } else {
        qplane->dist = gdist;
    }
}
```

## Applying Conversions to SV_LinkEdict Wrapper

**SV_LinkEdict** links an entity into the BSP tree. Wrap it to convert coordinates:

```c
#include "fte_godot_math.h"

// Original FTE function signature (example):
// void SV_LinkEdict(edict_t *ent);

// Wrapper that converts Godot coordinates to Quake before calling
void SV_LinkEdict_Godot(edict_t *ent, const float godot_origin[3]) {
    // Convert Godot origin to Quake coordinates
    vec3_t quake_origin;
    GODOT_TO_QUAKE_VEC3(godot_origin, quake_origin);
    
    // Store original origin
    vec3_t old_origin;
    VectorCopy(ent->s.origin, old_origin);
    
    // Set Quake coordinates
    VectorCopy(quake_origin, ent->s.origin);
    
    // Call original function
    SV_LinkEdict(ent);
    
    // Optionally restore original (if needed)
    // VectorCopy(old_origin, ent->s.origin);
}
```

**Alternative: In-place conversion wrapper:**

```c
// Wrapper that modifies edict in-place
void SV_LinkEdict_Wrapper(edict_t *ent) {
    // If ent->s.origin is already in Quake coordinates, use directly
    // If it's in Godot coordinates, convert first
    
    // For entities passed from Godot, convert origin
    // (assuming a flag or separate function for Godot-originated entities)
    if (ent->godot_origin_set) {
        vec3_t quake_origin;
        GODOT_TO_QUAKE_VEC3(ent->godot_origin, quake_origin);
        VectorCopy(quake_origin, ent->s.origin);
        ent->godot_origin_set = false;
    }
    
    SV_LinkEdict(ent);
}
```

## Applying Conversions to SV_Trace Wrapper

**SV_Trace** performs collision detection. Wrap it to convert input/output:

```c
#include "fte_godot_math.h"

// Original FTE function signature (example):
// trace_t SV_Trace(vec3_t start, vec3_t mins, vec3_t maxs, vec3_t end, edict_t *passent, int contentmask);

// Wrapper that accepts Godot coordinates and returns Godot coordinates
typedef struct {
    float start[3];
    float end[3];
    float endpos[3];
    float plane_normal[3];
    float plane_dist;
    float fraction;
    int all_solid;
    int start_solid;
    int contents;
    // ... other trace fields
} godot_trace_t;

godot_trace_t SV_Trace_Godot(const float godot_start[3], 
                               const float godot_mins[3],
                               const float godot_maxs[3],
                               const float godot_end[3],
                               edict_t *passent,
                               int contentmask) {
    // Convert inputs from Godot to Quake
    vec3_t quake_start, quake_mins, quake_maxs, quake_end;
    GODOT_TO_QUAKE_VEC3(godot_start, quake_start);
    GODOT_TO_QUAKE_VEC3(godot_mins, quake_mins);
    GODOT_TO_QUAKE_VEC3(godot_maxs, quake_maxs);
    GODOT_TO_QUAKE_VEC3(godot_end, quake_end);
    
    // Call original FTE function
    trace_t trace = SV_Trace(quake_start, quake_mins, quake_maxs, quake_end, passent, contentmask);
    
    // Convert outputs from Quake to Godot
    godot_trace_t result;
    QUAKE_TO_GODOT_VEC3(trace.endpos, result.endpos);
    QUAKE_TO_GODOT_VEC3(trace.plane.normal, result.plane_normal);
    
    if (FTE_USE_SCALE) {
        result.plane_dist = trace.plane.dist * QUAKE_TO_GODOT_SCALE;
    } else {
        result.plane_dist = trace.plane.dist;
    }
    
    result.fraction = trace.fraction;
    result.all_solid = trace.all_solid;
    result.start_solid = trace.start_solid;
    result.contents = trace.contents;
    
    return result;
}
```

**Macro-based wrapper (more efficient):**

```c
// Macro wrapper for SV_Trace
#define SV_TRACE_GODOT(gstart, gmins, gmaxs, gend, passent, mask, result) \
    do { \
        vec3_t qstart, qmins, qmaxs, qend; \
        trace_t qtrace; \
        GODOT_TO_QUAKE_VEC3(gstart, qstart); \
        GODOT_TO_QUAKE_VEC3(gmins, qmins); \
        GODOT_TO_QUAKE_VEC3(gmaxs, qmaxs); \
        GODOT_TO_QUAKE_VEC3(gend, qend); \
        qtrace = SV_Trace(qstart, qmins, qmaxs, qend, passent, mask); \
        QUAKE_TO_GODOT_VEC3(qtrace.endpos, (result).endpos); \
        QUAKE_TO_GODOT_VEC3(qtrace.plane.normal, (result).plane_normal); \
        (result).plane_dist = FTE_USE_SCALE ? qtrace.plane.dist * QUAKE_TO_GODOT_SCALE : qtrace.plane.dist; \
        (result).fraction = qtrace.fraction; \
        (result).all_solid = qtrace.all_solid; \
        (result).start_solid = qtrace.start_solid; \
        (result).contents = qtrace.contents; \
    } while(0)
```

## Implementation Checklist

When creating `fte_godot_math.h` and applying conversions:

- [ ] Create `fte_godot_math.h` header file
- [ ] Define `QUAKE_TO_GODOT_SCALE` constant (default 0.0254f)
- [ ] Define `FTE_USE_SCALE` flag (default 1, set to 0 for 1:1)
- [ ] Implement `QUAKE_TO_GODOT_VEC3` macro and function
- [ ] Implement `GODOT_TO_QUAKE_VEC3` macro and function
- [ ] Implement `QUAKE_TO_GODOT_QUAT` macro and function
- [ ] Implement `GODOT_TO_QUAKE_QUAT` macro and function
- [ ] Implement `QUAKE_TO_GODOT_PLANE` macro and function
- [ ] Implement `GODOT_TO_QUAKE_PLANE` macro and function
- [ ] Create `SV_LinkEdict_Godot` wrapper function
- [ ] Create `SV_Trace_Godot` wrapper function or macro
- [ ] Apply coordinate conversion formula: X=X, Y=Z, Z=-Y
- [ ] Apply scale conversion when `FTE_USE_SCALE` is enabled
- [ ] Test wrappers with both scale modes (0.0254 and 1:1)

## Common Patterns

### Pattern: Converting Entity Origins

```c
// When syncing entity from Godot to Quake
void sync_entity_origin(edict_t *ent, const float godot_origin[3]) {
    GODOT_TO_QUAKE_VEC3(godot_origin, ent->s.origin);
    SV_LinkEdict(ent);
}

// When reading entity from Quake to Godot
void get_entity_origin(const edict_t *ent, float godot_origin[3]) {
    QUAKE_TO_GODOT_VEC3(ent->s.origin, godot_origin);
}
```

### Pattern: Batch Conversion

```c
// Convert multiple vectors efficiently
void convert_entity_origins(const edict_t *edicts, int count, float (*godot_origins)[3]) {
    for (int i = 0; i < count; i++) {
        if (!edicts[i].free) {
            QUAKE_TO_GODOT_VEC3(edicts[i].s.origin, godot_origins[i]);
        }
    }
}
```

### Pattern: Conditional Scaling

```c
// Use macros that respect FTE_USE_SCALE
#if FTE_USE_SCALE
    // Scale-aware conversion
    QUAKE_TO_GODOT_VEC3(quake_vec, godot_vec);
#else
    // Direct conversion without scaling
    QUAKE_TO_GODOT_VEC3(quake_vec, godot_vec);
#endif
```

## Integration with GDExtension

From GDExtension C++ code:

```cpp
#include "fte_godot_math.h"
#include <godot_cpp/variant/vector3.hpp>

// Convert Godot Vector3 to Quake vec3_t
void godot_vector3_to_quake(const godot::Vector3 &gvec, vec3_t qvec) {
    float temp[3] = {gvec.x, gvec.y, gvec.z};
    GODOT_TO_QUAKE_VEC3(temp, qvec);
}

// Convert Quake vec3_t to Godot Vector3
godot::Vector3 quake_to_godot_vector3(const vec3_t qvec) {
    float temp[3];
    QUAKE_TO_GODOT_VEC3(qvec, temp);
    return godot::Vector3(temp[0], temp[1], temp[2]);
}
```

## Performance Considerations

- **Use macros** for performance-critical paths (no function call overhead)
- **Use functions** when you need address-taking or debugging
- **Batch conversions** when processing multiple entities
- **Cache conversions** if the same values are used multiple times
- **Consider SIMD** for bulk vector operations if available

## Testing Considerations

After implementation, verify:
- Coordinate conversion matches expected values (X=X, Y=Z, Z=-Y)
- Scale conversion applies correctly (0.0254 factor)
- 1:1 scale mode works when `FTE_USE_SCALE` is 0
- `SV_LinkEdict` wrapper correctly links entities
- `SV_Trace` wrapper returns correct collision results
- Reverse conversions (Godot→Quake) produce original values
- Plane distance scaling is correct
