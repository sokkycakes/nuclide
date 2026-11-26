#!/usr/bin/env python3
"""Give a compiled Quake 3 BSP a sky where its caulk shell faces the play space.

A map sealed with common/caulk and no sky brushes has nothing drawn above or
around the arena. Engines that do not clear the screen each frame (stock FTE
leaves gl_clear at 0) then show old frames there: the console, menus, the
previous view. q3map2 only ships as a Windows exe in this repo, so instead of
recompiling, this script edits the BSP in place, as a recompile with those
caulk faces retextured to a sky shader would:

  * every caulk brush side whose outside touches empty space gets a
    planar draw surface with the sky shader (textures/common/skyportal by
    default, which draws the skybox named by worldspawn's "skyname"),
  * the new surfaces join the world model and the surface lists of every
    empty leaf they overlap, so they are drawn whenever that leaf is seen,
  * worldspawn's "sky" key (which Nuclide ignores) becomes "skyname".

Collision is unchanged: the brushes and their caulk sides stay as they were.

usage: sky_q3bsp_caulk.py in.bsp out.bsp [--shader textures/common/skyportal]
"""
import argparse
import struct
import sys

LUMPS = 17
L_ENTITIES, L_SHADERS, L_PLANES, L_NODES, L_LEAFS, L_LEAFSURFACES, \
    L_LEAFBRUSHES, L_MODELS, L_BRUSHES, L_BRUSHSIDES, L_DRAWVERTS, \
    L_DRAWINDEXES, L_FOGS, L_SURFACES, L_LIGHTMAPS, L_LIGHTGRID, L_VIS = range(LUMPS)

SURF_SKY_FLAGS = 0x20c14   # what q3map2 gave common/skyportal in background02.bsp
LIGHTMAP_BY_VERTEX = -3
EPS = 0.01


def read_lumps(data):
    if data[:4] != b"IBSP" or struct.unpack("<i", data[4:8])[0] != 46:
        sys.exit("not a Quake 3 (IBSP 46) map")
    out = []
    for i in range(LUMPS):
        ofs, ln = struct.unpack("<ii", data[8 + i * 8:16 + i * 8])
        out.append(bytearray(data[ofs:ofs + ln]))
    return out


def write_bsp(path, lumps):
    header = bytearray(b"IBSP" + struct.pack("<i", 46))
    body = bytearray()
    pos = 8 + LUMPS * 8
    for lump in lumps:
        header += struct.pack("<ii", pos + len(body), len(lump))
        body += lump
        while len(body) % 4:
            body += b"\0"
    with open(path, "wb") as f:
        f.write(header + body)


def recs(lump, fmt):
    size = struct.calcsize(fmt)
    return [list(struct.unpack(fmt, lump[i:i + size])) for i in range(0, len(lump), size)]


def pack(recs_, fmt):
    return bytearray(b"".join(struct.pack(fmt, *r) for r in recs_))


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def base_winding(normal, dist):
    """A big square on the plane."""
    ax = max(range(3), key=lambda i: abs(normal[i]))
    up = (0.0, 0.0, 1.0) if ax != 2 else (1.0, 0.0, 0.0)
    d = dot(up, normal)
    up = sub(up, tuple(normal[i] * d for i in range(3)))
    ln = dot(up, up) ** 0.5
    up = tuple(u / ln for u in up)
    right = cross(up, normal)
    org = tuple(normal[i] * dist for i in range(3))
    big = 65536.0
    up = tuple(u * big for u in up)
    right = tuple(r * big for r in right)
    return [
        tuple(org[i] - right[i] + up[i] for i in range(3)),
        tuple(org[i] + right[i] + up[i] for i in range(3)),
        tuple(org[i] + right[i] - up[i] for i in range(3)),
        tuple(org[i] - right[i] - up[i] for i in range(3)),
    ]


def clip_back(w, normal, dist):
    """Keep the part of winding w behind the plane (dot(p, n) <= dist)."""
    out = []
    n = len(w)
    for i in range(n):
        p, q = w[i], w[(i + 1) % n]
        dp, dq = dot(p, normal) - dist, dot(q, normal) - dist
        if dp <= EPS:
            out.append(p)
        if (dp > EPS and dq < -EPS) or (dp < -EPS and dq > EPS):
            t = dp / (dp - dq)
            out.append(tuple(p[j] + t * (q[j] - p[j]) for j in range(3)))
    return out


def area(w):
    a = (0.0, 0.0, 0.0)
    for i in range(1, len(w) - 1):
        c = cross(sub(w[i], w[0]), sub(w[i + 1], w[0]))
        a = (a[0] + c[0], a[1] + c[1], a[2] + c[2])
    return dot(a, a) ** 0.5 / 2


def samples_on(w, step=16.0):
    """Points spread over a convex winding, about step units apart."""
    out = []
    for i in range(1, len(w) - 1):
        a, b, c = w[0], w[i], w[i + 1]
        edge = max(dot(sub(b, a), sub(b, a)), dot(sub(c, a), sub(c, a)), dot(sub(c, b), sub(c, b))) ** 0.5
        n = max(1, int(edge / step))
        for u in range(n + 1):
            for v in range(n + 1 - u):
                # stay a little inside the triangle's edges
                fu, fv = (u + 0.25) / (n + 1), (v + 0.25) / (n + 1)
                out.append(tuple(a[k] + fu * (b[k] - a[k]) + fv * (c[k] - a[k]) for k in range(3)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--shader", default="textures/common/skyportal")
    ap.add_argument("--caulk", default="textures/common/caulk")
    args = ap.parse_args()

    lumps = read_lumps(open(args.inp, "rb").read())
    shaders = recs(lumps[L_SHADERS], "<64sii")
    names = [s[0].split(b"\0")[0].decode() for s in shaders]
    if args.caulk not in names:
        sys.exit("no %s in this map" % args.caulk)
    caulk = names.index(args.caulk)
    if args.shader in names:
        sky = names.index(args.shader)
    else:
        sky = len(shaders)
        shaders.append([args.shader.encode().ljust(64, b"\0"), SURF_SKY_FLAGS, 1])

    planes = recs(lumps[L_PLANES], "<4f")
    nodes = recs(lumps[L_NODES], "<9i")
    leafs = recs(lumps[L_LEAFS], "<12i")
    leafsurfs = [r[0] for r in recs(lumps[L_LEAFSURFACES], "<i")]
    leafbrushes = [r[0] for r in recs(lumps[L_LEAFBRUSHES], "<i")]
    models = recs(lumps[L_MODELS], "<6f4i")
    brushes = recs(lumps[L_BRUSHES], "<3i")
    sides = recs(lumps[L_BRUSHSIDES], "<2i")
    verts = lumps[L_DRAWVERTS]
    indexes = lumps[L_DRAWINDEXES]
    surfaces = recs(lumps[L_SURFACES], "<12i12f2i")

    if any(s[0] == sky for s in surfaces):
        sys.exit("this map already has %s surfaces" % args.shader)

    def brush_planes(b):
        fs, ns, _ = brushes[b]
        return [planes[sides[fs + k][0]] for k in range(ns)]

    def leaf_for(p):
        n = 0
        while n >= 0:
            node = nodes[n]
            pl = planes[node[0]]
            n = node[1] if dot(p, pl) - pl[3] >= 0 else node[2]
        return -(n + 1)

    def in_brush(p, b):
        return all(dot(p, pl) - pl[3] < -0.5 for pl in brush_planes(b))

    def open_at(p):
        leaf = leafs[leaf_for(p)]
        if leaf[0] < 0:
            return False      # solid or outside the map
        for k in range(leaf[10], leaf[10] + leaf[11]):
            b = leafbrushes[k]
            if shaders[brushes[b][2]][2] & 1 and in_brush(p, b):
                return False  # inside a solid detail brush
        return True

    world = models[0]
    wfirst, wbrushes = world[8], world[9]
    faces = []
    for b in range(wfirst, wfirst + wbrushes):
        fs, ns, _ = brushes[b]
        bsides = [sides[fs + k] for k in range(ns)]
        seen = set()
        for i, (pnum, sshader) in enumerate(bsides):
            if sshader != caulk or pnum in seen:
                continue
            seen.add(pnum)
            pl = planes[pnum]
            w = base_winding(pl[:3], pl[3])
            for j, (qnum, _) in enumerate(bsides):
                if qnum != pnum and w:
                    q = planes[qnum]
                    if abs(dot(q[:3], pl[:3]) - 1) < 1e-6 and abs(q[3] - pl[3]) < 1e-3:
                        continue
                    w = clip_back(w, q[:3], q[3])
            if len(w) < 3 or area(w) < 1.0:
                continue      # a bevel or a degenerate side
            if any(open_at(tuple(s[k] + pl[k] * 2 for k in range(3))) for s in samples_on(w)):
                faces.append((w, pl))

    if not faces:
        sys.exit("no caulk face touches the play space")

    # new vertexes and indexes, wound like q3map2's (triangle normal against
    # the plane normal), one planar surface per face
    first_new_vert = len(verts) // 44
    new_surfs = []
    for w, pl in faces:
        fv = len(verts) // 44
        fi = len(indexes) // 4
        for p in w:
            verts += struct.pack("<3f2f2f3f4B", p[0], p[1], p[2], 0, 0, 0, 0,
                                 pl[0], pl[1], pl[2], 255, 255, 255, 255)
        tri = []
        for i in range(1, len(w) - 1):
            a, b, c = 0, i, i + 1
            if dot(cross(sub(w[b], w[a]), sub(w[c], w[a])), pl[:3]) > 0:
                b, c = c, b
            tri += [a, b, c]
        indexes += struct.pack("<%di" % len(tri), *tri)
        new_surfs.append([sky, -1, 1, fv, len(w), fi, len(tri), LIGHTMAP_BY_VERTEX, 0, 0, 0, 0,
                          0, 0, 0, 0, 0, 0, 0, 0, 0, pl[0], pl[1], pl[2], 0, 0])

    # insert them at the end of the world model's surfaces, shifting the
    # surface numbers of the brush models after it
    at = world[6] + world[7]
    count = len(new_surfs)
    surfaces[at:at] = new_surfs
    world[7] += count
    for m in models[1:]:
        if m[6] >= at:
            m[6] += count
    leafsurfs = [s + count if s >= at else s for s in leafsurfs]

    # each empty leaf lists the new faces its box overlaps
    boxes = []
    for w, _ in faces:
        boxes.append(([min(p[k] for p in w) - 2 for k in range(3)],
                      [max(p[k] for p in w) + 2 for k in range(3)]))
    new_leafsurfs = []
    added = 0
    for leaf in leafs:
        first, num = leaf[8], leaf[9]
        lst = leafsurfs[first:first + num]
        if leaf[0] >= 0:
            for k, (mn, mx) in enumerate(boxes):
                if all(mn[a] <= leaf[5 + a] and mx[a] >= leaf[2 + a] for a in range(3)):
                    lst.append(at + k)
                    added += 1
        leaf[8], leaf[9] = len(new_leafsurfs), len(lst)
        new_leafsurfs += lst

    # worldspawn: Nuclide reads "skyname", not "sky"
    ents = bytes(lumps[L_ENTITIES]).rstrip(b"\0").decode("latin-1")
    end = ents.index("}")
    head = ents[:end]
    if '"skyname"' not in head and '"sky" ' in head:
        head = head.replace('"sky" ', '"skyname" ', 1)
    ents = head + ents[end:]

    lumps[L_ENTITIES] = bytearray(ents.encode("latin-1") + b"\0")
    lumps[L_SHADERS] = pack(shaders, "<64sii")
    lumps[L_LEAFS] = pack(leafs, "<12i")
    lumps[L_LEAFSURFACES] = pack([[s] for s in new_leafsurfs], "<i")
    lumps[L_MODELS] = pack(models, "<6f4i")
    lumps[L_DRAWVERTS] = verts
    lumps[L_DRAWINDEXES] = indexes
    lumps[L_SURFACES] = pack(surfaces, "<12i12f2i")
    write_bsp(args.out, lumps)
    print("%d sky faces (%d vertexes from %d), %d leaf references, shader %s"
          % (count, len(verts) // 44 - first_new_vert, first_new_vert, added, args.shader))


if __name__ == "__main__":
    main()
