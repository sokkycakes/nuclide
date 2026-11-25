#!/usr/bin/env python3
"""Give an unlit Quake 3 BSP (IBSP 46) simple sun + sky lighting.

A map compiled with q3map2 -light but no light source (no light entities,
no q3map_sun sky shader; "_sun" in worldspawn is an ericw-tools key that
q3map2 ignores) comes out with all-zero lightmaps, vertex colours and light
grid: it renders pitch black in every engine.

This writes a plain directional light into those lumps in place: every
lightmapped triangle is rasterised in lightmap space and shaded with
ambient + sun * max(0, N.L); vertex colours get the same value, and the
light grid gets a uniform ambient + directed light so models are lit.
It is a stopgap until the map is recompiled with real lights.

usage: relight_q3bsp_unlit.py <map.bsp> [--force]
"""
import math
import struct
import sys

LM = 128                      # lightmap page size
SUN = (0.35, 0.25, 0.90)      # direction towards the sun
AMBIENT = 80                  # lightmap value for surfaces facing away
SUNLIGHT = 95                 # added at N.L == 1
TINT = (1.0, 0.98, 0.94)      # slightly warm


def norm(v):
    l = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / l for c in v)


def shade(n):
    s = norm(SUN)
    ndl = max(0.0, n[0] * s[0] + n[1] * s[1] + n[2] * s[2])
    # walls get a little sky light too, floors the most
    sky = 0.15 * max(0.0, n[2])
    v = AMBIENT + SUNLIGHT * ndl + AMBIENT * sky
    return tuple(min(255, int(v * t)) for t in TINT)


def main():
    path = sys.argv[1]
    force = "--force" in sys.argv
    d = bytearray(open(path, "rb").read())
    if d[:4] != b"IBSP" or struct.unpack_from("<i", d, 4)[0] != 46:
        sys.exit("not an IBSP 46 map")
    lumps = [struct.unpack_from("<ii", d, 8 + i * 8) for i in range(17)]
    lmoff, lmlen = lumps[14]
    if any(d[lmoff:lmoff + lmlen]) and not force:
        sys.exit("map already has lighting; pass --force to overwrite")
    pages = lmlen // (LM * LM * 3)

    voff, vlen = lumps[10]
    verts = []
    for i in range(vlen // 44):
        p = struct.unpack_from("<3f2f2f3f", d, voff + i * 44)
        verts.append((p[0:3], p[5:7], p[7:10]))
    mvoff = lumps[11][0]

    foff, flen = lumps[13]
    painted = 0
    for i in range(flen // 104):
        f = struct.unpack_from("<8i2i2i3f6f3f2i", d, foff + i * 104)
        ftype, v0, nv, m0, nm, lmi = f[2], f[3], f[4], f[5], f[6], f[7]
        n = norm(f[21:24])
        col = shade(n)
        # vertex colours (vertex-lit fallback, and what some shaders use)
        for k in range(v0, v0 + nv):
            vc = shade(norm(verts[k][2]) if any(verts[k][2]) else n)
            struct.pack_into("<4B", d, voff + k * 44 + 40, vc[0], vc[1], vc[2], 255)
        if lmi < 0 or lmi >= pages or ftype not in (1, 3) or nm < 3:
            continue
        base = lmoff + lmi * LM * LM * 3
        idx = [struct.unpack_from("<i", d, mvoff + (m0 + j) * 4)[0] for j in range(nm)]
        for t in range(0, nm - 2, 3):
            tri = [verts[v0 + idx[t + j]][1] for j in range(3)]
            xs = [u * LM for u, _ in tri]
            ys = [v * LM for _, v in tri]
            # fill the triangle's lightmap box, one texel of padding so
            # bilinear filtering at chart edges doesn't pull in black
            x0, x1 = max(0, int(min(xs)) - 1), min(LM - 1, int(max(xs)) + 1)
            y0, y1 = max(0, int(min(ys)) - 1), min(LM - 1, int(max(ys)) + 1)
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    p = base + (y * LM + x) * 3
                    d[p:p + 3] = bytes(col)
                    painted += 1

    # light grid: ambient rgb, directed rgb, then the light direction as
    # bytes 6 (angle from +z) and 7 (angle around z), 256 steps a turn
    goff, glen = lumps[15]
    s = norm(SUN)
    lng = int(round(math.acos(s[2]) / (2 * math.pi) * 256)) & 255
    lat = int(round(math.atan2(s[1], s[0]) / (2 * math.pi) * 256)) & 255
    amb = tuple(int(AMBIENT * 1.2 * t) for t in TINT)
    dirc = tuple(int(SUNLIGHT * 1.4 * t) for t in TINT)
    cell = bytes(amb + dirc + (lng, lat))
    for p in range(goff, goff + glen - 7, 8):
        d[p:p + 8] = cell

    open(path, "wb").write(d)
    print(f"{path}: painted {painted} lightmap texels on {pages} page(s), "
          f"{vlen // 44} vertex colours, {glen // 8} light grid cells")


if __name__ == "__main__":
    main()
