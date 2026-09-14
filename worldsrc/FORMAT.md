# FTEW v1 experimental world resource

All integers are unsigned 32-bit little-endian unless stated otherwise. Floats are IEEE-754 float32, little-endian. Fields are packed without alignment padding. The reader is `Tools/stiletto/engine/fte_world_format.h`; the compiler is `addons/stiletto_tools/exporter.gd`.

## Header: 96 bytes

| Offset | Meaning |
| --- | --- |
| 0 | Four ASCII bytes `FTEW` |
| 4 | Version, currently `1` |
| 8 | Exact total file length |
| 12 | Number of models, including world model zero |
| 16 | Five 16-byte directory records |

A directory record contains tag[4], offset, byte length, record count. Tags and sections must occur in this exact order: `MATL`, `MESH`, `INST`, `COLL`, `ENTS`. Sections are contiguous beginning at byte 96; overlaps, gaps and trailing bytes are rejected.

## Sections

**MATL:** repeated string byte length followed by path bytes, without a terminator. Paths are printable ASCII, game-relative, under 64 bytes, with no traversal, quotes, backslashes, colon or semicolon. They identify native FTE materials; generated individual `.mat` files live beside their textures.

**MESH:** material index, vertex count, index count, then vertices and indices. Each vertex is nine floats: position XYZ, UV, RGBA. Each triangle is three u32 vertex indices. Vertices use FTE coordinates and clockwise front faces. v1 stores no smooth normal or tangent stream.

**INST:** fixed 60 bytes: mesh index, model index, flags, transform[12 floats]. Flag bit 0 means visible, bit 1 means collidable; at least one is required. The transform is three basis columns followed by translation. Meshes are shared independently of placement. The renderer reverses triangle order for negative-determinant transforms.

**COLL:** model index, contents (v1 requires `1`, solid), mins[3], maxs[3], plane count, then plane[4 floats] records. A plane is normalized XYZ normal plus distance; the convex interior satisfies `dot(normal, point) <= distance`. Exported boxes include face and axial bevel planes. Collision model zero belongs to the world; other models are referenced from entities as `*N` and use entity-local positions. Entity box rotation is baked into its collider, so its native angles are zero.

**ENTS:** one null-terminated UTF-8 native entity lump; directory record count must be one. The first entity is worldspawn. Records use quoted key/value text inside braces. This is ordinary entity data, not raw MAP brush geometry. Origins, classnames, targetnames and native output strings are stored here.

WorldEnvironment backgrounds use worldspawn `skyname` and external PNG resources; no new binary section is required. Nested panorama references include the full game-relative path, e.g. `env/fteworld/<hash>` (without `.png`). The world renderer submits an infinite sky background through FTE's existing sky renderer, allowing native `r_skybox` overrides without BSP sky faces. Environment ambient color, when explicitly selected, is baked into generated lit vertex RGBA and is not runtime sky lighting.

## Coordinates and resource limits

Default scale is 32 FTE units per Godot meter. Conversion is `(x,y,z) -> (x,-z,y) * scale`. Its determinant is positive; clockwise winding is preserved. Transform bases use `C * B * inverse(C)`, while translations and vertex positions use the scaled coordinate conversion.

Reader limits: 128 MiB total file size, 4 MiB entity text, 4,096 materials, 4,096 meshes, 65,535 vertices per mesh, 16,384 instances, 16,384 colliders, 1,024 models, 4–64 planes per collider and 50,000 triangles after instance expansion. All serialized floats must be finite and bounded in magnitude by 1e8. Transforms must be invertible and collider bounds nonempty. These are initial guardrails, not a performance promise.

## Runtime

The engine module initializes a terrain-backed world without parsing a raw MAP, inserts render triangles into existing material batches, and builds a BIH from triangle and convex collision primitives. Model/visibility/light callbacks use existing FTE infrastructure. Server-only builds omit render patch insertion and retain the same collision data. Godot is absent from this path.

Materials are external resources, currently generated with content-derived names. Mesh-resource identity survives repeated placements within a world, while runtime instance streaming and cross-world mesh packages remain future work. Full rebuilds are deterministic; incremental region rebuilds and backward migration between future format versions are not yet implemented.
