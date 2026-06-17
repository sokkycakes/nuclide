---
name: fte_geo_translator
description: Extracts geometric data from FTEQW's memory and builds Godot-compatible mesh and physics data. Converts model_t and texture_t structures to Godot ArrayMesh and CollisionShape3D. Use when loading maps via SV_SpawnServer or CL_BeginServer, extracting surfaces from model_t, converting lightmaps to UV2, mapping Quake textures to Godot materials, or generating physics collision from BSP clipnodes.
---

# FTE Geo Translator

Extracts geometric data from FTEQW's memory structures and converts them to Godot-compatible meshes, materials, and physics collision.

## Core Objective

Convert FTEQW's internal world geometry (`model_t*`, `texture_t*`) into Godot resources:
- Extract surfaces from `model_t` structures
- Build Godot `ArrayMesh` with proper winding order; **vertex positions are always added**—never drop geometry when texture info is missing or invalid (use 64×64 default texture size for UVs)
- Extract lightmap data to UV2 channel
- Map Quake texture names to Godot materials
- Generate physics collision from BSP clipnodes/hulls
- Extract entity data from BSP header

## Key Concepts

**FTE Structures:**
- `model_t*` - FTE's internal world model containing surfaces
- `texture_t*` - Quake texture data (name, dimensions, pixels)
- `surface_t` - Surface data (vertices, indices, texture, lightmap)

**Godot Resources:**
- `ArrayMesh` - Godot mesh resource
- `StandardMaterial3D` - Godot material
- `CollisionShape3D` - Physics collision shape
- `ConvexPolygonShape3D` - Convex hull collision

**Triggers:**
- `SV_SpawnServer` - Server-side map loading
- `CL_BeginServer` - Client-side map loading

## Critical Constraints

### 1. Winding Order: Flip from Quake (Clockwise) to Godot (Counter-Clockwise)

**Quake uses clockwise winding, Godot uses counter-clockwise:**

```cpp
// When building indices, reverse winding order
void flip_winding_order(PackedInt32Array &indices) {
    // Reverse every triangle (groups of 3)
    for (int i = 0; i < indices.size(); i += 3) {
        int temp = indices[i];
        indices[i] = indices[i + 2];
        indices[i + 2] = temp;
    }
}
```

**Or reverse during index building:**

```cpp
// Build indices with reversed winding
for (int i = 0; i < triangle_count; i++) {
    // Quake: v0, v1, v2 (clockwise)
    // Godot: v0, v2, v1 (counter-clockwise)
    indices.push_back(quake_indices[i * 3 + 0]);
    indices.push_back(quake_indices[i * 3 + 2]);  // Swap order
    indices.push_back(quake_indices[i * 3 + 1]);
}
```

### 2. Lightmaps: Extract to Second UV Channel or Custom Sampler2D

**Extract lightmap UVs to UV2 channel:**

```cpp
// FTE lightmap data structure (example)
struct lightmap_data_t {
    float u, v;  // Lightmap UV coordinates
    // ... other data
};

// Extract lightmap UVs to UV2
PackedVector2Array lightmap_uvs;
for (int i = 0; i < vertex_count; i++) {
    lightmap_data_t *lm = &surface->lightmap_data[i];
    Vector2 uv2(lm->u, lm->v);
    lightmap_uvs.push_back(uv2);
}

// Add to mesh as UV2
mesh->surface_set_uv2(surface_index, lightmap_uvs);
```

**Or use custom Sampler2D in material:**

```gdscript
# In material shader
shader_type spatial;

uniform sampler2D lightmap : source_color;

void fragment() {
    vec4 lightmap_color = texture(lightmap, UV2);
    ALBEDO = texture(ALBEDO_TEXTURE, UV).rgb * lightmap_color.rgb;
}
```

### 3. Materials: Map Quake Texture Names to Godot .tres Materials

**Create texture name to material mapping:**

```cpp
// Texture name mapping table
std::unordered_map<String, Ref<Material>> texture_material_map;

void initialize_texture_mapping() {
    // Load mapping from config or build dynamically
    texture_material_map["e1u1/plat_top"] = ResourceLoader::load("res://materials/e1u1_plat_top.tres");
    texture_material_map["*01water1"] = ResourceLoader::load("res://materials/water.tres");
    // ... more mappings
}

Ref<Material> get_material_for_texture(const char *texture_name) {
    String name = String(texture_name);
    
    // Check direct mapping
    if (texture_material_map.find(name) != texture_material_map.end()) {
        return texture_material_map[name];
    }
    
    // Try to load from standard path
    String material_path = "res://materials/" + name + ".tres";
    Ref<Material> material = ResourceLoader::load(material_path);
    
    if (material.is_valid()) {
        texture_material_map[name] = material;
        return material;
    }
    
    // Fallback: create a loud "Debug/Missing" material (hot pink)
    // IMPORTANT: Never return invalid material refs here. See "Decouple Geometry from Materials" rule.
    Ref<StandardMaterial3D> missing_material;
    missing_material.instantiate();
    missing_material->set_albedo(Color(1.0, 0.0, 1.0)); // hot pink
    missing_material->set_metallic(0.0);
    missing_material->set_roughness(1.0);
    return missing_material;
}
```

**Lookup table structure:**

```cpp
// Texture name patterns to material paths
struct texture_mapping_t {
    const char *pattern;  // Quake texture name pattern
    const char *material_path;  // Godot material path
};

texture_mapping_t texture_mappings[] = {
    {"e1u1/plat_top", "res://materials/e1u1_plat_top.tres"},
    {"*01water1", "res://materials/water.tres"},
    {"sky", "res://materials/sky.tres"},
    // ... more mappings
};
```

### 4. Physics: Convert BSP Clipnodes/Hulls to CollisionShape3D

**Extract collision hulls from BSP:**

```cpp
// Convert BSP clipnode to convex hull
Ref<ConvexPolygonShape3D> create_collision_from_clipnode(clipnode_t *clipnode) {
    PackedVector3Array points;
    
    // Extract vertices from clipnode brush
    for (int i = 0; i < clipnode->num_planes; i++) {
        mplane_t *plane = &clipnode->planes[i];
        
        // Convert plane to Godot coordinates
        float godot_normal[3];
        QUAKE_TO_GODOT_VEC3(plane->normal, godot_normal);
        
        // Build convex hull from planes
        // (simplified - actual implementation needs plane intersection)
        Vector3 point = Vector3(godot_normal[0], godot_normal[1], godot_normal[2]) * plane->dist;
        points.push_back(point);
    }
    
    Ref<ConvexPolygonShape3D> shape;
    shape.instantiate();
    shape->set_points(points);
    
    return shape;
}
```

**Or use mesh-based collision:**

```cpp
// Generate collision from mesh
Ref<ConcavePolygonShape3D> create_collision_from_mesh(Ref<ArrayMesh> mesh) {
    // Use Godot's mesh to generate collision
    Ref<Shape3D> collision = mesh->create_trimesh_shape();
    return collision;
}
```

### 5. Default Texture Size and "Fallback Dimension" Rule (UV Safety)

**Use a default texture size of 64×64 whenever the surface's texture info is missing or invalid.** This ensures UV math never divides by zero and that geometry is never skipped due to bad texture data.

- If `texture_t*` is null, or the surface has no valid texture reference → use **64×64** for UV calculation.
- If `texture->width` or `texture->height` is zero or invalid → use **64** for that dimension (never allow 0 in the divisor).
- Vertex positions and the full surface must **always** be added to the Godot `ArrayMesh`; UV calculation must use this fallback so that missing or invalid texture info never causes geometry to be dropped.

```cpp
// Default when texture is missing or invalid (use in all UV calculation paths)
#define FTE_GEO_DEFAULT_TEX_WIDTH  64
#define FTE_GEO_DEFAULT_TEX_HEIGHT 64

// Inside your mesh builder / UV calculation logic
// Rule A: Never allow 0 dimensions in UV math. Always use 64×64 when texture info is missing/invalid.
float tex_w = (texture && texture->width  > 0) ? (float)texture->width  : (float)FTE_GEO_DEFAULT_TEX_WIDTH;
float tex_h = (texture && texture->height > 0) ? (float)texture->height : (float)FTE_GEO_DEFAULT_TEX_HEIGHT;

// Calculate UVs safely (vertex positions are always emitted; UVs use fallback dimensions when needed)
Vector2 uv;
uv.x = (vertex.dot(tex_info.s_vector) + tex_info.s_offset) / tex_w;
uv.y = (vertex.dot(tex_info.t_vector) + tex_info.t_offset) / tex_h;
```

### 6. Vertex Positions Always Emitted (Geometry Never Conditional on Texture)

**Vertex positions must always be added to the Godot ArrayMesh, regardless of whether the surface's texture info is missing or invalid.** Do not skip a surface, skip vertices, or skip adding a mesh surface because UV calculation would otherwise reference a missing/invalid texture.

- **Stage 1**: For each surface, collect vertex positions (and normals). Compute UVs using the surface's texture when valid; when texture is missing or invalid, use the 64×64 default dimensions above so UVs are still well-defined.
- **Stage 2**: Always append the surface's vertices/indices to the mesh arrays and call `add_surface_from_arrays`. Geometry emission must not depend on texture validity.
- **Stage 3**: Assign material (real or Debug/Missing) and set on the surface.

If your pipeline currently has any branch that skips adding geometry when texture is null or invalid, remove that branch and rely on the 64×64 fallback for UV math instead.

### 7. Decouple Geometry from Materials (Always Commit Surfaces)

**Always create the `ArrayMesh` surface (geometry) even if material lookup fails.** Missing materials must not block mesh creation.

Implementation staging:

- **Stage 1**: Collect all vertices/indices for the face (or surface batch). Use 64×64 default texture size for UVs when texture info is missing or invalid (see rule 5).
- **Stage 2**: Attempt to find the Godot `Material`. If it fails, assign a **"Debug/Missing"** material (hot pink and obvious, or a checkerboard).
- **Stage 3**: Commit the geometry (`add_surface_from_arrays`) regardless of whether the lookup succeeded.

Practical implication: do **not** early-return on missing material; do **not** skip surfaces because a `.tres` is missing; do **not** skip or drop geometry because the surface's texture reference is null or invalid.

## Implementation Logic

### Step 1: Surface Extraction - Iterate model->surfaces

**Extract surfaces from model_t:**

```cpp
#include "fte_godot_math.h"  // For coordinate conversion

void extract_surfaces_from_model(model_t *model) {
    if (!model || !model->surfaces) {
        return;
    }
    
    // Group surfaces by texture for batching
    std::unordered_map<String, Array> surfaces_by_texture;
    
    for (int i = 0; i < model->num_surfaces; i++) {
        surface_t *surf = &model->surfaces[i];
        
        if (!surf || surf->num_vertices == 0) {
            continue;
        }
        
        // Get texture name (fallback when texture is missing)
        const char *texture_name = (surf->texture && surf->texture->name) ? surf->texture->name : "__missing";
        String texture_key = String(texture_name);
        
        // Extract surface data (UVs use 64×64 when texture is null/invalid)
        SurfaceData surface_data = extract_surface_data(surf);
        
        // Group by texture
        if (surfaces_by_texture.find(texture_key) == surfaces_by_texture.end()) {
            surfaces_by_texture[texture_key] = Array();
        }
        surfaces_by_texture[texture_key].push_back(surface_data);
    }
    
    // Build meshes grouped by texture
    for (auto &pair : surfaces_by_texture) {
        build_mesh_from_surfaces(pair.first, pair.second);
    }
}
```

**Extract individual surface data:**

```cpp
struct SurfaceData {
    PackedVector3Array vertices;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedVector2Array uv2s;  // Lightmap UVs
    PackedInt32Array indices;
    const char *texture_name;
};

SurfaceData extract_surface_data(surface_t *surf) {
    SurfaceData data;
    
    // UV dimensions: use 64×64 when texture is missing or invalid (vertex positions always emitted)
    texture_t *tex = surf->texture;
    float tex_w = (tex && tex->width  > 0) ? (float)tex->width  : (float)FTE_GEO_DEFAULT_TEX_WIDTH;
    float tex_h = (tex && tex->height > 0) ? (float)tex->height : (float)FTE_GEO_DEFAULT_TEX_HEIGHT;
    
    // Always extract every vertex; never skip due to texture/UV
    for (int i = 0; i < surf->num_vertices; i++) {
        vec3_t quake_pos = surf->vertices[i].position;
        float godot_pos[3];
        QUAKE_TO_GODOT_VEC3(quake_pos, godot_pos);
        
        data.vertices.push_back(Vector3(godot_pos[0], godot_pos[1], godot_pos[2]));
        
        // Extract normals
        vec3_t quake_normal = surf->vertices[i].normal;
        float godot_normal[3];
        QUAKE_TO_GODOT_VEC3(quake_normal, godot_normal);
        data.normals.push_back(Vector3(godot_normal[0], godot_normal[1], godot_normal[2]));
        
        // UVs: use precomputed u,v from surface; tex_w/tex_h (64×64 when texture missing) used if you derive UV from world/tex_info elsewhere
        data.uvs.push_back(Vector2(surf->vertices[i].u, surf->vertices[i].v));
        
        // Extract lightmap UVs (UV2)
        if (surf->lightmap_data) {
            data.uv2s.push_back(Vector2(surf->lightmap_data[i].u, surf->lightmap_data[i].v));
        }
    }
    
    // Extract indices with winding order flip
    for (int i = 0; i < surf->num_indices; i += 3) {
        // Flip winding: Quake (CW) -> Godot (CCW)
        data.indices.push_back(surf->indices[i + 0]);
        data.indices.push_back(surf->indices[i + 2]);  // Swap
        data.indices.push_back(surf->indices[i + 1]);
    }
    
    data.texture_name = (tex && tex->name) ? tex->name : "__missing";
    
    return data;
}
```

### Step 2: Mesh Building - Use fte_math_distill and Group by Texture

**Build Godot ArrayMesh from surfaces:**

```cpp
Ref<ArrayMesh> build_mesh_from_surfaces(const String &texture_name, const Array &surfaces) {
    Ref<ArrayMesh> mesh;
    mesh.instantiate();
    
    // Combine all surfaces with same texture
    PackedVector3Array combined_vertices;
    PackedVector3Array combined_normals;
    PackedVector2Array combined_uvs;
    PackedVector2Array combined_uv2s;
    PackedInt32Array combined_indices;
    
    int index_offset = 0;
    
    for (int s = 0; s < surfaces.size(); s++) {
        SurfaceData *surf_data = surfaces[s];
        
        // Append vertices
        for (int i = 0; i < surf_data->vertices.size(); i++) {
            combined_vertices.push_back(surf_data->vertices[i]);
            combined_normals.push_back(surf_data->normals[i]);
            combined_uvs.push_back(surf_data->uvs[i]);
            if (surf_data->uv2s.size() > i) {
                combined_uv2s.push_back(surf_data->uv2s[i]);
            }
        }
        
        // Append indices with offset
        for (int i = 0; i < surf_data->indices.size(); i++) {
            combined_indices.push_back(surf_data->indices[i] + index_offset);
        }
        
        index_offset += surf_data->vertices.size();
    }
    
    // Create mesh arrays
    Array mesh_arrays;
    mesh_arrays.resize(Mesh::ARRAY_MAX);
    mesh_arrays[Mesh::ARRAY_VERTEX] = combined_vertices;
    mesh_arrays[Mesh::ARRAY_NORMAL] = combined_normals;
    mesh_arrays[Mesh::ARRAY_TEX_UV] = combined_uvs;
    mesh_arrays[Mesh::ARRAY_TEX_UV2] = combined_uv2s;
    mesh_arrays[Mesh::ARRAY_INDEX] = combined_indices;
    
    // Add surface to mesh
    mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, mesh_arrays);
    
    // Rule B: Decouple geometry from materials
    // - Commit geometry first (already done above).
    // - Then set a real material if found, otherwise a Debug/Missing material.
    Ref<Material> material = get_material_for_texture(texture_name.utf8().get_data());
    if (!material.is_valid()) {
        Ref<StandardMaterial3D> missing_material;
        missing_material.instantiate();
        missing_material->set_albedo(Color(1.0, 0.0, 1.0)); // hot pink
        missing_material->set_metallic(0.0);
        missing_material->set_roughness(1.0);
        material = missing_material;
    }
    mesh->surface_set_material(0, material);
    
    return mesh;
}
```

### Step 3: Brush Parsing (Optional/Map) - Plane-Clipping for Convex Hulls

**Parse .map brushes and generate convex hulls:**

```cpp
// Parse brush from .map format
struct map_brush_t {
    Array planes;  // Array of mplane_t
};

Ref<ConvexPolygonShape3D> create_convex_hull_from_brush(map_brush_t *brush) {
    // Use plane-clipping algorithm to generate vertices
    PackedVector3Array vertices;
    
    // Start with a large bounding box
    AABB bounds(Vector3(-4096, -4096, -4096), Vector3(8192, 8192, 8192));
    
    // Clip by each plane
    for (int i = 0; i < brush->planes.size(); i++) {
        mplane_t *plane = brush->planes[i];
        
        // Convert plane to Godot
        float godot_normal[3];
        QUAKE_TO_GODOT_VEC3(plane->normal, godot_normal);
        Plane godot_plane(Vector3(godot_normal[0], godot_normal[1], godot_normal[2]), plane->dist);
        
        // Clip vertices by plane
        vertices = clip_vertices_by_plane(vertices, godot_plane);
    }
    
    // Create convex hull shape
    Ref<ConvexPolygonShape3D> shape;
    shape.instantiate();
    shape->set_points(vertices);
    
    return shape;
}

PackedVector3Array clip_vertices_by_plane(const PackedVector3Array &vertices, const Plane &plane) {
    PackedVector3Array result;
    
    for (int i = 0; i < vertices.size(); i++) {
        Vector3 v = vertices[i];
        float dist = plane.distance_to(v);
        
        if (dist >= 0) {
            result.push_back(v);
        }
    }
    
    return result;
}
```

### Step 4: Entity Injection - Read Entities String from BSP Header

**Extract entities from BSP:**

```cpp
// Extract entity string from BSP
String extract_entities_from_bsp(model_t *model) {
    if (!model || !model->entities) {
        return String();
    }
    
    // Entities are stored as a string in BSP header
    const char *entity_string = model->entities;
    
    if (!entity_string) {
        return String();
    }
    
    return String(entity_string);
}

// Parse entities and pass to Entity Syncer
void inject_entities_to_scene(const String &entity_string) {
    // Parse entity string (Quake format: { "key" "value" ... })
    Array entities = parse_entity_string(entity_string);
    
    // Emit signal or call Entity Syncer
    emit_signal("entities_loaded", entities);
    
    // Or directly call Entity Syncer
    // entity_syncer->spawn_entities(entities);
}
```

**Parse Quake entity format:**

```cpp
Array parse_entity_string(const String &entity_string) {
    Array entities;
    
    // Quake entity format: { "key1" "value1" "key2" "value2" }
    // Parse braces and key-value pairs
    
    int pos = 0;
    while (pos < entity_string.length()) {
        // Find opening brace
        int open_brace = entity_string.find("{", pos);
        if (open_brace == -1) break;
        
        // Find closing brace
        int close_brace = entity_string.find("}", open_brace);
        if (close_brace == -1) break;
        
        // Extract entity block
        String entity_block = entity_string.substr(open_brace + 1, close_brace - open_brace - 1);
        
        // Parse key-value pairs
        Dictionary entity = parse_entity_block(entity_block);
        entities.push_back(entity);
        
        pos = close_brace + 1;
    }
    
    return entities;
}
```

## Implementation Workflow

### Step 1: Hook into Map Loading

```cpp
// Hook SV_SpawnServer or CL_BeginServer
void SV_SpawnServer_Hook(const char *server_name) {
    // Call original
    SV_SpawnServer(server_name);
    
    // Extract geometry after map loads
    model_t *world_model = SV_GetWorldModel();
    if (world_model) {
        extract_and_build_geometry(world_model);
    }
}
```

### Step 2: Extract and Build Geometry

```cpp
void extract_and_build_geometry(model_t *model) {
    // 1. Extract surfaces
    extract_surfaces_from_model(model);
    
    // 2. Build meshes (grouped by texture)
    build_meshes_from_surfaces();
    
    // 3. Generate physics collision
    generate_physics_collision(model);
    
    // 4. Extract and inject entities
    String entities = extract_entities_from_bsp(model);
    inject_entities_to_scene(entities);
}
```

## Implementation Checklist

When implementing geo translator:

- [ ] Hook into `SV_SpawnServer` or `CL_BeginServer`
- [ ] Extract surfaces from `model_t->surfaces`
- [ ] Convert vertex positions using `fte_math_distill` macros
- [ ] Flip winding order (Quake CW -> Godot CCW)
- [ ] Extract lightmap UVs to UV2 channel
- [ ] Group surfaces by texture name
- [ ] Build `ArrayMesh` with grouped surfaces
- [ ] Map Quake texture names to Godot materials
- [ ] Use default texture size **64×64** when surface texture is missing or invalid (`FTE_GEO_DEFAULT_TEX_WIDTH` / `FTE_GEO_DEFAULT_TEX_HEIGHT`)
- [ ] Enforce "Fallback Dimension" Rule in UV math (never divide by 0 width/height)
- [ ] Enforce "Vertex Positions Always Emitted": never skip adding geometry when texture/UV is invalid; use 64×64 for UV math instead
- [ ] Enforce "Decouple Geometry from Materials" (always commit surfaces; Debug/Missing fallback material)
- [ ] Generate `CollisionShape3D` from BSP clipnodes/hulls
- [ ] Extract entity string from BSP header
- [ ] Parse entity string and pass to Entity Syncer
- [ ] Handle brush parsing for .map files (optional)
- [ ] Create convex hulls from brush planes (optional)

## Common Patterns

### Pattern: Surface Grouping by Texture

```cpp
// Group surfaces to minimize draw calls
std::unordered_map<String, Array> group_surfaces_by_texture(Array surfaces) {
    std::unordered_map<String, Array> grouped;
    
    for (int i = 0; i < surfaces.size(); i++) {
        SurfaceData *surf = surfaces[i];
        String texture = String(surf->texture_name);
        
        if (grouped.find(texture) == grouped.end()) {
            grouped[texture] = Array();
        }
        grouped[texture].push_back(surf);
    }
    
    return grouped;
}
```

### Pattern: Material Lookup with Fallback

```cpp
Ref<Material> get_material_with_fallback(const char *texture_name) {
    // Try lookup table
    Ref<Material> material = get_material_for_texture(texture_name);
    if (material.is_valid()) {
        return material;
    }
    
    // Try loading from standard path
    String path = "res://materials/" + String(texture_name) + ".tres";
    material = ResourceLoader::load(path);
    if (material.is_valid()) {
        return material;
    }
    
    // Rule B: Debug/Missing fallback material (hot pink)
    Ref<StandardMaterial3D> missing_mat;
    missing_mat.instantiate();
    missing_mat->set_albedo(Color(1.0, 0.0, 1.0));
    missing_mat->set_metallic(0.0);
    missing_mat->set_roughness(1.0);
    return missing_mat;
}
```

### Pattern: Lightmap UV Extraction

```cpp
PackedVector2Array extract_lightmap_uvs(surface_t *surf) {
    PackedVector2Array uv2s;
    
    if (!surf->lightmap_data) {
        return uv2s;
    }
    
    for (int i = 0; i < surf->num_vertices; i++) {
        lightmap_data_t *lm = &surf->lightmap_data[i];
        uv2s.push_back(Vector2(lm->u, lm->v));
    }
    
    return uv2s;
}
```

## Integration Points

### With fte_math_distill

```cpp
#include "fte_godot_math.h"

// Use coordinate conversion macros
void convert_vertex_position(const vec3_t quake_pos, Vector3 &godot_pos) {
    float temp[3];
    QUAKE_TO_GODOT_VEC3(quake_pos, temp);
    godot_pos = Vector3(temp[0], temp[1], temp[2]);
}
```

### With Entity Syncer

```cpp
// After extracting entities
void inject_entities(const String &entity_string) {
    Array entities = parse_entity_string(entity_string);
    
    // Emit signal for Entity Syncer
    emit_signal("spawn_entities", entities);
    
    // Or call directly
    // entity_syncer->spawn_entities(entities);
}
```

## Testing Considerations

After implementation, verify:
- Surfaces are extracted correctly from `model_t`
- Vertex positions match expected coordinates (coordinate conversion)
- Winding order is correct (faces render properly)
- Lightmap UVs are in UV2 channel
- Materials are mapped correctly from texture names
- Physics collision matches geometry
- Entities are extracted and parsed correctly
- Mesh batching reduces draw calls (surfaces grouped by texture)
- Convex hulls are generated correctly from brushes (if implemented)
