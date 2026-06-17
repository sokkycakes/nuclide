#!/usr/bin/env python3
"""Path-A optimization pass for a decompiled Quake1 .map.

1. Parse entities/brushes (standard Quake .map, 5-number tex form).
2. Compute an AABB over every brush plane point AND every point-entity origin.
3. Append a sealed hull box (6 slabs) to worldspawn  -> kills the leak.
4. Move all original worldspawn brushes into a single func_detail entity
   -> the BSP stops subdividing on them, collapsing vis leafs/portals.

Existing func_detail entities and all point entities pass through untouched.
"""
import re
import sys

SRC = "base/maps/arch_crux_test.map"
DST = "base/maps/arch_crux_test.map"

PT = re.compile(r"\(\s*(-?[\d.eE+]+)\s+(-?[\d.eE+]+)\s+(-?[\d.eE+]+)\s*\)")
ORIGIN = re.compile(r'"origin"\s+"\s*(-?[\d.eE+]+)\s+(-?[\d.eE+]+)\s+(-?[\d.eE+]+)\s*"')


def parse(text):
    """Return list of entities. Each = {'kv': [raw lines], 'brushes': [[raw lines]]}."""
    ents = []
    cur = None
    brush = None
    depth = 0
    for raw in text.splitlines():
        s = raw.strip()
        if not s or s.startswith("//"):
            continue
        if s == "{":
            depth += 1
            if depth == 1:
                cur = {"kv": [], "brushes": []}
            elif depth == 2:
                brush = []
            continue
        if s == "}":
            if depth == 2:
                cur["brushes"].append(brush)
                brush = None
            elif depth == 1:
                ents.append(cur)
                cur = None
            depth -= 1
            continue
        if depth == 1:
            cur["kv"].append(s)
        elif depth == 2:
            brush.append(s)
    return ents


def classname(ent):
    for kv in ent["kv"]:
        if kv.startswith('"classname"'):
            return kv.split('"')[3]
    return ""


def cube(x0, y0, z0, x1, y1, z1, tex="128_grey_3"):
    suf = " 0 0 0 1 1"
    f = []
    f.append(f"( {x1} {y0} {z1} ) ( {x0} {y0} {z1} ) ( {x0} {y1} {z1} ) {tex}{suf}")  # +Z
    f.append(f"( {x0} {y1} {z0} ) ( {x0} {y0} {z0} ) ( {x1} {y0} {z0} ) {tex}{suf}")  # -Z
    f.append(f"( {x1} {y1} {z0} ) ( {x1} {y0} {z0} ) ( {x1} {y0} {z1} ) {tex}{suf}")  # +X
    f.append(f"( {x0} {y0} {z1} ) ( {x0} {y0} {z0} ) ( {x0} {y1} {z0} ) {tex}{suf}")  # -X
    f.append(f"( {x0} {y1} {z1} ) ( {x0} {y1} {z0} ) ( {x1} {y1} {z0} ) {tex}{suf}")  # +Y
    f.append(f"( {x1} {y0} {z0} ) ( {x0} {y0} {z0} ) ( {x0} {y0} {z1} ) {tex}{suf}")  # -Y
    return f


def emit_ent(ent):
    out = ["{"]
    out.extend(ent["kv"])
    for b in ent["brushes"]:
        out.append("{")
        out.extend(b)
        out.append("}")
    out.append("}")
    return out


def main():
    text = open(SRC, "r", errors="replace").read()
    ents = parse(text)

    lo = [1e18, 1e18, 1e18]
    hi = [-1e18, -1e18, -1e18]

    def acc(x, y, z):
        v = (x, y, z)
        for i in range(3):
            lo[i] = min(lo[i], v[i])
            hi[i] = max(hi[i], v[i])

    n_struct = n_detail = n_point = 0
    world = None
    for e in ents:
        cn = classname(e)
        for b in e["brushes"]:
            for ln in b:
                for m in PT.finditer(ln):
                    acc(float(m.group(1)), float(m.group(2)), float(m.group(3)))
        for kv in e["kv"]:
            m = ORIGIN.match(kv)
            if m:
                acc(float(m.group(1)), float(m.group(2)), float(m.group(3)))
        if cn == "worldspawn":
            world = e
            n_struct += len(e["brushes"])
        elif cn == "func_detail":
            n_detail += len(e["brushes"])
        if not e["brushes"]:
            n_point += 1

    margin, thick = 256, 64
    import math
    x0 = int(math.floor(lo[0])) - margin - thick
    y0 = int(math.floor(lo[1])) - margin - thick
    z0 = int(math.floor(lo[2])) - margin - thick
    x1 = int(math.ceil(hi[0])) + margin + thick
    y1 = int(math.ceil(hi[1])) + margin + thick
    z1 = int(math.ceil(hi[2])) + margin + thick

    seal = [
        cube(x0, y0, z0, x1, y1, z0 + thick),   # bottom
        cube(x0, y0, z1 - thick, x1, y1, z1),   # top
        cube(x0, y0, z0, x0 + thick, y1, z1),   # west
        cube(x1 - thick, y0, z0, x1, y1, z1),   # east
        cube(x0, y0, z0, x1, y0 + thick, z1),   # south
        cube(x0, y1 - thick, z0, x1, y1, z1),   # north
    ]

    world_brushes = world["brushes"]
    world["brushes"] = seal  # worldspawn now = sealed hull only

    detail_ent = {"kv": ['"classname" "func_detail"'], "brushes": world_brushes}

    out = []
    for e in ents:
        out.extend(emit_ent(e))
        if e is world:
            out.extend(emit_ent(detail_ent))  # inject converted brushes right after

    open(DST, "w").write("\n".join(out) + "\n")

    print(f"AABB  min=({lo[0]:.0f},{lo[1]:.0f},{lo[2]:.0f}) max=({hi[0]:.0f},{hi[1]:.0f},{hi[2]:.0f})")
    print(f"hull  ({x0},{y0},{z0}) .. ({x1},{y1},{z1})")
    print(f"before: structural(worldspawn)={n_struct}  func_detail={n_detail}  point-ents={n_point}")
    print(f"after : structural(worldspawn)=6 (sealed hull)  func_detail={n_detail + len(world_brushes)}")


if __name__ == "__main__":
    main()
