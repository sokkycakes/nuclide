#!/usr/bin/env python3
"""Writes coop/maps/coop_arena.bsp, a GoldSrc (BSP30) arena for testing the
co-op rules with many players, and coop/data/coop_arena.way, a waypoint graph
for Nuclide's bots and monsters.

One closed arena (2048 x 2048 x 384) with pillars for cover. Players and
allies start in the south-west corner, monster spawn points line the north and
east walls. Textures are stored in the map, so no WAD is needed. Based on
bulwark-engine's tools/mkq1map_test.py. ISC licence.

usage: mkcoopmap.py [out.bsp] [out.way]"""
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "maps", "coop_arena.bsp")
way_out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "data", "coop_arena.way")

SIZE, HEIGHT = 2048, 384
ROOMS = [((0, 0, 0), (SIZE, SIZE, HEIGHT))]
BLOCKS = [((x, y, 0), (x + 128, y + 128, 192))
          for x, y in ((576, 576), (1344, 576), (576, 1344), (1344, 1344), (960, 960))]
BLOCKS += [((256, 1088, 0), (384, 1472, 96)), ((1664, 576, 0), (1792, 960, 96))]
LIGHTS = [(512, 512, 320), (1536, 512, 320), (512, 1536, 320), (1536, 1536, 320), (1024, 1024, 320)]
TILE = 256  # faces are cut into tiles so lightmaps stay small
BIG = 8192
HULLS = [((0, 0, 0), (0, 0, 0)), ((-16, -16, -36), (16, 16, 36)), ((-32, -32, -32), (32, 32, 32)),
         ((-16, -16, -18), (16, 16, 18))]  # point, standing, large, crouching

def empty(p, hull):
    mins, maxs = hull
    inroom = any(all(r0[k] - mins[k] <= p[k] <= r1[k] - maxs[k] for k in range(3)) for r0, r1 in ROOMS)
    inblock = any(all(b0[k] - maxs[k] < p[k] < b1[k] - mins[k] for k in range(3)) for b0, b1 in BLOCKS)
    return inroom and not inblock

def split_planes(hull):
    mins, maxs = hull
    ps = set()
    for r0, r1 in ROOMS:
        for k in range(3):
            ps.add((k, r0[k] - mins[k]))
            ps.add((k, r1[k] - maxs[k]))
    for b0, b1 in BLOCKS:
        for k in range(3):
            ps.add((k, b0[k] - maxs[k]))
            ps.add((k, b1[k] - mins[k]))
    return sorted(ps)

planes = []  # (axis, dist)
def plane_index(axis, dist):
    if (axis, dist) not in planes:
        planes.append((axis, dist))
    return planes.index((axis, dist))

# --- hull 0: nodes and leafs ---------------------------------------------------

nodes = []   # [planenum, front, back, mins, maxs]
leafs = [dict(contents=-2, mins=(-BIG,) * 3, maxs=(BIG,) * 3, faces=[])]

def build(lo, hi, hull, cand, node_list, leaf_cb):
    for axis, dist in cand:
        if lo[axis] < dist < hi[axis]:
            pn = plane_index(axis, dist)
            idx = len(node_list)
            node_list.append(None)
            flo = list(lo)
            flo[axis] = dist
            bhi = list(hi)
            bhi[axis] = dist
            front = build(flo, hi, hull, cand, node_list, leaf_cb)
            back = build(lo, bhi, hull, cand, node_list, leaf_cb)
            node_list[idx] = [pn, front, back, lo, hi]
            return idx
    centre = [(lo[k] + hi[k]) / 2 for k in range(3)]
    return leaf_cb(empty(centre, hull), lo, hi)

def hull0_leaf(is_empty, lo, hi):
    if not is_empty:
        return -1  # leaf 0, solid
    leafs.append(dict(contents=-1, mins=lo, maxs=hi, faces=[]))
    return -len(leafs)

root0 = build([-BIG] * 3, [BIG] * 3, HULLS[0], split_planes(HULLS[0]), nodes, hull0_leaf)

# --- hulls 1 to 3: clipnodes -------------------------------------------------------

clipnodes = []
def clip_leaf(is_empty, lo, hi):
    return -1 if is_empty else -2
clip_roots = [build([-BIG] * 3, [BIG] * 3, HULLS[h], split_planes(HULLS[h]), clipnodes, clip_leaf)
              for h in range(1, 4)]

# --- faces -------------------------------------------------------------------------

def tiles(axis, dist, sign, lo, hi):
    a1, a2 = [k for k in range(3) if k != axis]
    out = []
    u = lo[a1]
    while u < hi[a1]:
        v = lo[a2]
        u2 = min(hi[a1], (u // TILE + 1) * TILE)
        while v < hi[a2]:
            v2 = min(hi[a2], (v // TILE + 1) * TILE)
            tlo, thi = list(lo), list(hi)
            tlo[a1], thi[a1], tlo[a2], thi[a2] = u, u2, v, v2
            out.append((axis, dist, sign, tlo, thi))
            v = v2
        u = u2
    return out

def rect_faces():
    """(axis, dist, normal sign, lo, hi) rectangles facing into the empty space"""
    fs = []
    for r0, r1 in ROOMS:
        for k in range(3):
            fs += tiles(k, r0[k], +1, list(r0), list(r1))
            fs += tiles(k, r1[k], -1, list(r0), list(r1))
    for b0, b1 in BLOCKS:
        for k in range(3):
            if k == 2:
                fs += tiles(2, b1[2], +1, list(b0), list(b1))  # top only; the bottom sits on the floor
            else:
                fs += tiles(k, b0[k], -1, list(b0), list(b1))
                fs += tiles(k, b1[k], +1, list(b0), list(b1))
    return fs

texinfos = []
def texinfo_for(axis, tex):
    if axis == 2:
        s, t = (1, 0, 0), (0, -1, 0)
    elif axis == 0:
        s, t = (0, 1, 0), (0, 0, -1)
    else:
        s, t = (1, 0, 0), (0, 0, -1)
    ti = (s + (0,), t + (0,), tex)
    if ti not in texinfos:
        texinfos.append(ti)
    return texinfos.index(ti)

verts, edges, surfedges, faces, lighting = [], [(0, 0)], [], [], bytearray()

def light_at(p):
    v = 40
    for c in LIGHTS:
        v += 150 * max(0.0, 1 - math.dist(p, c) / 700)
    return int(min(255, v))

for axis, dist, sign, lo, hi in rect_faces():
    a1, a2 = [k for k in range(3) if k != axis]
    corners = []
    for u, v in ((lo[a1], lo[a2]), (hi[a1], lo[a2]), (hi[a1], hi[a2]), (lo[a1], hi[a2])):
        p = [0, 0, 0]
        p[axis], p[a1], p[a2] = dist, u, v
        corners.append(tuple(p))
    # clockwise seen from the side the normal points to
    normal = [0, 0, 0]
    normal[axis] = sign
    e1 = [corners[1][k] - corners[0][k] for k in range(3)]
    e2 = [corners[2][k] - corners[0][k] for k in range(3)]
    cross = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]]
    if sum(cross[k] * normal[k] for k in range(3)) > 0:
        corners.reverse()
    pn = plane_index(axis, dist)
    side = 0 if sign > 0 else 1
    tex = 1 if axis == 2 and sign > 0 else 0
    ti = texinfo_for(axis, tex)
    first = len(surfedges)
    base = len(verts)
    verts.extend(corners)
    for i in range(4):
        edges.append((base + i, base + (i + 1) % 4))
        surfedges.append(len(edges) - 1)
    s_vec, t_vec, _ = texinfos[ti]
    ss = [sum(c[k] * s_vec[k] for k in range(3)) + s_vec[3] for c in corners]
    ts = [sum(c[k] * t_vec[k] for k in range(3)) + t_vec[3] for c in corners]
    smin, smax = math.floor(min(ss) / 16), math.ceil(max(ss) / 16)
    tmin, tmax = math.floor(min(ts) / 16), math.ceil(max(ts) / 16)
    w, h = smax - smin + 1, tmax - tmin + 1
    lightofs = len(lighting)
    for j in range(h):
        for i in range(w):
            s, t = (smin + i) * 16, (tmin + j) * 16
            p = [0, 0, 0]
            p[axis] = dist
            for k in (a1, a2):
                p[k] = s * s_vec[k] + t * t_vec[k]
            v = light_at(p)
            lighting.extend((v, v * 7 // 8, v * 3 // 4))  # warm white
    faces.append(dict(plane=pn, side=side, firstedge=first, numedges=4, texinfo=ti, lightofs=lightofs,
                      axis=axis, dist=dist, sign=sign, lo=lo, hi=hi))

# each face belongs to the first node on its plane whose box holds the face's
# centre (light sampling walks these lists); faces are stored grouped by node
def face_node(f):
    a = f["axis"]
    c = [(f["lo"][k] + f["hi"][k]) / 2 for k in range(3)]
    c[a] = f["dist"]
    for ni, n in enumerate(nodes):
        if n[0] == f["plane"] and all(n[3][k] <= c[k] <= n[4][k] for k in range(3)):
            return ni
    return len(nodes)

for f in faces:
    f["node"] = face_node(f)
faces.sort(key=lambda f: f["node"])
node_faces = [[0, 0] for _ in nodes]
for fi, f in enumerate(faces):
    if f["node"] < len(nodes):
        nf = node_faces[f["node"]]
        if not nf[1]:
            nf[0] = fi
        nf[1] += 1

# faces touching each empty leaf (the leaf's boundary holds the face's plane)
for lf in leafs:
    if lf["contents"] != -1:
        continue
    for fi, f in enumerate(faces):
        a = f["axis"]
        face_side = lf["mins"][a] if f["sign"] > 0 else lf["maxs"][a]
        if face_side != f["dist"]:
            continue
        if all(lf["mins"][k] < f["hi"][k] and lf["maxs"][k] > f["lo"][k] for k in range(3) if k != a):
            lf["faces"].append(fi)

marksurfaces = []
for lf in leafs:
    lf["firstmark"] = len(marksurfaces)
    marksurfaces.extend(lf["faces"])

# --- visibility: one room, every leaf sees every other ----------------------------------

nvis = len(leafs) - 1
vis = bytearray()
row = bytearray(b"\xff" * ((nvis + 7) // 8))
if nvis % 8:
    row[-1] = (1 << (nvis % 8)) - 1
for li, lf in enumerate(leafs):
    lf["visofs"] = -1 if li == 0 else 0
vis += row

# --- textures ------------------------------------------------------------------------------

def miptex(name, a, b):
    size = 64
    hdr = name.encode().ljust(16, b"\0") + struct.pack("<II", size, size)
    data = b""
    offs = []
    for m in range(4):
        s = size >> m
        offs.append(40 + len(data))
        data += bytes(a if ((x * (1 << m) // 16) + (y * (1 << m) // 16)) % 2 else b
                      for y in range(s) for x in range(s))
    data += struct.pack("<H", 256) + bytes(c for i in range(256) for c in (i, (i * 3) & 255, 255 - i)) + b"\0\0"
    return hdr + struct.pack("<4I", *offs) + data

texs = [miptex("coopwall", 90, 96), miptex("coopfloor", 40, 48)]
texlump = struct.pack("<I", len(texs))
ofs = 4 + 4 * len(texs)
blob = b""
for t in texs:
    texlump += struct.pack("<i", ofs + len(blob))
    blob += t
texlump += blob

# --- entities ------------------------------------------------------------------------------

ents = [dict(classname="worldspawn", message="Co-op arena", wad="")]
for i in range(16):  # players: a 4x4 block in the south-west corner
    x, y = 96 + (i % 4) * 64, 96 + (i // 4) * 64
    for cls in ("info_player_coop", "info_player_deathmatch"):
        ents.append(dict(classname=cls, origin=f"{x} {y} 40", angle="45"))
ents.append(dict(classname="info_player_start", origin="96 96 40", angle="45"))
for x, y in ((448, 160), (160, 448)):  # allies guarding the start
    ents.append(dict(classname="monster_barney", origin=f"{x} {y} 0", angle="45"))
for i, (x, y) in enumerate(((1024, 1920), (1600, 1920), (1920, 1920), (1920, 1600), (1920, 1024), (448, 1920),
                            (1920, 448), (1024, 1600))):
    ents.append(dict(classname="info_monster_spawn", origin=f"{x} {y} 40", angle="225"))
for cls, (x, y) in (("weapon_9mmAR", (352, 96)), ("weapon_shotgun", (96, 352)), ("ammo_9mmAR", (352, 160)),
                    ("ammo_buckshot", (160, 352)), ("item_healthkit", (352, 352)), ("item_battery", (416, 352))):
    ents.append(dict(classname=cls, origin=f"{x} {y} 16"))

def ent_text(e):
    return "{\n" + "".join(f'"{k}" "{v}"\n' for k, v in e.items()) + "}\n"
entities = ("".join(ent_text(e) for e in ents)).encode() + b"\0"

# --- lumps ----------------------------------------------------------------------------------

def pack_planes():
    b = b""
    for axis, dist in planes:
        n = [0.0, 0.0, 0.0]
        n[axis] = 1.0
        b += struct.pack("<4fi", *n, dist, axis)
    return b

def bbox_short(lo, hi):
    return [max(-32768, min(32767, int(v))) for v in list(lo) + list(hi)]

lumps = [None] * 15
lumps[0] = entities
lumps[1] = pack_planes()
lumps[2] = texlump
lumps[3] = b"".join(struct.pack("<3f", *v) for v in verts)
lumps[4] = bytes(vis)
lumps[5] = b"".join(struct.pack("<i2h6h2H", n[0], n[1], n[2], *bbox_short(n[3], n[4]), *node_faces[i])
                    for i, n in enumerate(nodes))
lumps[6] = b"".join(struct.pack("<8f2i", *s, *t, tex, 0) for s, t, tex in texinfos)
lumps[7] = b"".join(struct.pack("<hhihh4Bi", f["plane"], f["side"], f["firstedge"], f["numedges"], f["texinfo"],
                                0, 255, 255, 255, f["lightofs"]) for f in faces)
lumps[8] = bytes(lighting)
lumps[9] = b"".join(struct.pack("<i2h", n[0], n[1], n[2]) for n in clipnodes)
lumps[10] = b"".join(struct.pack("<ii6h2H4B", lf["contents"], lf["visofs"], *bbox_short(lf["mins"], lf["maxs"]),
                                 lf["firstmark"], len(lf["faces"]), 0, 0, 0, 0) for lf in leafs)
lumps[11] = b"".join(struct.pack("<H", m) for m in marksurfaces)
lumps[12] = b"".join(struct.pack("<2H", *e) for e in edges)
lumps[13] = b"".join(struct.pack("<i", e) for e in surfedges)
lumps[14] = struct.pack("<9f4i3i", 0, 0, 0, SIZE, SIZE, HEIGHT, 0, 0, 0, root0, *clip_roots,
                        len(leafs) - 1, 0, len(faces))

data = bytearray(struct.pack("<i", 30) + b"\0" * (15 * 8))
for i, l in enumerate(lumps):
    while len(data) % 4:
        data.append(0)
    struct.pack_into("<ii", data, 4 + i * 8, len(data), len(l))
    data += l
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, "wb").write(data)
print(f"{out}: {len(nodes)} nodes, {len(leafs)} leafs, {len(clipnodes)} clipnodes, {len(faces)} faces")

# --- waypoints: a grid, linked to neighbours when the straight line misses every pillar ---------

GRID, PAD = 128, 48
def clear(p):
    return all(not (b0[0] - PAD < p[0] < b1[0] + PAD and b0[1] - PAD < p[1] < b1[1] + PAD) for b0, b1 in BLOCKS)

def line_clear(a, b):
    steps = int(math.dist(a, b) // 16) + 1
    return all(clear((a[0] + (b[0] - a[0]) * i / steps, a[1] + (b[1] - a[1]) * i / steps)) for i in range(steps + 1))

points = [(x, y) for y in range(64, SIZE, GRID) for x in range(64, SIZE, GRID) if clear((x, y))]
index = {p: i for i, p in enumerate(points)}
lines = [str(len(points))]
for p in points:
    links = []
    for dx in (-GRID, 0, GRID):
        for dy in (-GRID, 0, GRID):
            q = (p[0] + dx, p[1] + dy)
            if (dx or dy) and q in index and line_clear(p, q):
                links.append((index[q], math.dist(p, q)))
    lines.append(f"{p[0]} {p[1]} 36 {GRID / 2:.6f} {len(links)}")
    lines += [f" {j} {c:.6f} 0" for j, c in links]
os.makedirs(os.path.dirname(way_out), exist_ok=True)
open(way_out, "w").write("\n".join(lines) + "\n")
print(f"{way_out}: {len(points)} waypoints")
