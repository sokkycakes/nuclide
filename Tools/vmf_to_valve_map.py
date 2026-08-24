#!/usr/bin/env python3
"""Quick-and-dirty Source VMF -> Valve220 .map for ericw qbsp / FTE playtests.

Lossy on purpose: drops props/overlays, strips displacement detail (keeps base
brush), remaps TF/Source entities + tool textures into Quake-friendly names.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PLANE_RE = re.compile(
    r'"plane"\s+"\(([^)]+)\)\s+\(([^)]+)\)\s+\(([^)]+)\)"'
)
UAXIS_RE = re.compile(r'"uaxis"\s+"\[([^\]]+)\]\s+([-\d.]+)"')
VAXIS_RE = re.compile(r'"vaxis"\s+"\[([^\]]+)\]\s+([-\d.]+)"')
MAT_RE = re.compile(r'"material"\s+"([^"]+)"', re.I)
KV_RE = re.compile(r'"([^"]+)"\s+"([^"]*)"')
CLASS_RE = re.compile(r'"classname"\s+"([^"]+)"', re.I)

TOOL_TEX = {
    "tools/toolsnodraw": "skip",
    "tools/toolsskip": "skip",
    "tools/toolsblockbullets": "skip",
    "tools/toolsblocklight": "skip",
    "tools/toolsblocklos": "skip",
    "tools/toolsclip": "clip",
    "tools/toolshplayerclip": "clip",
    "tools/toolsplayerclip": "clip",
    "tools/toolsnpcclip": "clip",
    "tools/toolstrigger": "trigger",
    "tools/toolsinvisible": "skip",
    "tools/toolsinvisibleladder": "skip",
    "tools/toolsskybox": "sky",
    "tools/toolsskybox2d": "sky",
    "tools/toolsblack": "skip",
    "tools/toolsfog": "skip",
    "tools/toolsorigin": "skip",
    "tools/toolshint": "hint",
    "tools/toolsskip": "skip",
}

# Keep a few readable surface categories so the map isn't one solid color.
# Short basenames — ericw qbsp stores Quake miptex names without paths.
VIS_TEX = {
    "concrete": "mat_concrete",
    "metal": "mat_metal",
    "wood": "mat_wood",
    "nature": "mat_dirt",
    "tile": "mat_concrete",
    "glass": "mat_glass",
    "water": "#water",
    "dev": "wall128",
}

KEEP_POINT = {
    "light": "light",
    "light_spot": "light",
    "light_environment": "light",
    "info_player_teamspawn": "info_player_deathmatch",
    "info_player_start": "info_player_start",
    "info_player_deathmatch": "info_player_deathmatch",
    "info_target": "info_null",
    "info_observer_point": "info_player_deathmatch",
}

KEEP_BRUSH = {
    "func_detail": "func_detail",
    "func_detail_illusionary": "func_detail",
    "func_illusionary": "func_illusionary",
    "func_wall": "func_wall",
    "func_brush": "func_wall",
    "func_door": "func_door",
    "trigger_multiple": "trigger_multiple",
    "trigger_once": "trigger_once",
    "trigger_hurt": "trigger_hurt",
    "trigger_teleport": "trigger_teleport",
}


def remap_material(mat: str) -> str:
    key = mat.replace("\\", "/").lower()
    if key in TOOL_TEX:
        return TOOL_TEX[key]
    if key.startswith("tools/"):
        return "skip"
    for prefix, tex in VIS_TEX.items():
        if f"/{prefix}" in f"/{key}" or key.startswith(prefix):
            return tex
    return "mat_concrete"


def parse_blocks(text: str, start: int = 0) -> tuple[list, int]:
    """Parse VMF brace tree into nested lists/dicts. Returns (nodes, next_index)."""
    nodes: list = []
    i = start
    n = len(text)
    while i < n:
        while i < n and text[i] in " \t\r\n":
            i += 1
        if i >= n:
            break
        if text[i] == "}":
            return nodes, i + 1
        # name
        j = i
        while j < n and text[j] not in " \t\r\n{":
            j += 1
        name = text[i:j].strip()
        i = j
        while i < n and text[i] in " \t\r\n":
            i += 1
        if i < n and text[i] == "{":
            children, i = parse_blocks(text, i + 1)
            nodes.append((name, children))
        else:
            # shouldn't happen for well-formed VMF between braces
            break
    return nodes, i


def kv_map(children: list) -> dict[str, str]:
    # KVs are stored as raw strings mixed in? Our parser only gets named blocks.
    # So we re-scan the original chunk... handled differently below.
    return {}


def extract_kvs(chunk: str) -> dict[str, str]:
    return {k.lower(): v for k, v in KV_RE.findall(chunk)}


def find_matching_brace(text: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    n = len(text)
    while i < n:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unbalanced braces")


def iter_named_blocks(text: str, name: str):
    """Yield (full_block_text_including_name, inner_text) for top-level-ish name { }."""
    # Search globally; VMF nesting means we only want top-level world/entity
    # by scanning with depth tracking from file start.
    pattern = re.compile(rf"(?m)^({re.escape(name)})\s*\{{")
    for m in pattern.finditer(text):
        open_brace = text.find("{", m.start())
        close = find_matching_brace(text, open_brace)
        full = text[m.start() : close + 1]
        inner = text[open_brace + 1 : close]
        yield full, inner


def solid_to_brush(solid_inner: str) -> str | None:
    if "dispinfo" in solid_inner:
        # Keep base brush only — drop displacement mesh payload.
        pass
    sides = []
    for sm in re.finditer(r"(?m)^\t+side\s*\{", solid_inner):
        # sides are nested under solid (tab depth varies for world vs entity).
        open_brace = solid_inner.find("{", sm.start())
        close = find_matching_brace(solid_inner, open_brace)
        side = solid_inner[open_brace + 1 : close]
        pm = PLANE_RE.search(side)
        if not pm:
            continue
        um = UAXIS_RE.search(side)
        vm = VAXIS_RE.search(side)
        mm = MAT_RE.search(side)
        mat = remap_material(mm.group(1) if mm else "tools/toolsnodraw")
        if um and vm:
            ux = um.group(1).strip()
            us = um.group(2).strip()
            vx = vm.group(1).strip()
            vs = vm.group(2).strip()
            # Source scale is often 0.25 (= 4 texels/unit). Quake Valve uses
            # texture scale directly; invert for roughly correct sizing.
            try:
                usf = abs(float(us))
                vsf = abs(float(vs))
                us_out = f"{(1.0 / usf) if usf else 1.0:.6g}"
                vs_out = f"{(1.0 / vsf) if vsf else 1.0:.6g}"
            except ValueError:
                us_out, vs_out = "1", "1"
            line = (
                f"( {pm.group(1)} ) ( {pm.group(2)} ) ( {pm.group(3)} ) "
                f"{mat} [ {ux} ] [ {vx} ] 0 {us_out} {vs_out}"
            )
        else:
            line = (
                f"( {pm.group(1)} ) ( {pm.group(2)} ) ( {pm.group(3)} ) "
                f"{mat} 0 0 0 1 1"
            )
        sides.append(line)
    if len(sides) < 4:
        return None
    return "{\n" + "\n".join(sides) + "\n}"


def collect_solids(inner: str) -> list[str]:
    brushes = []
    for m in re.finditer(r"(?m)^\tsolid\s*\{", inner):
        open_brace = inner.find("{", m.start())
        close = find_matching_brace(inner, open_brace)
        brush = solid_to_brush(inner[open_brace + 1 : close])
        if brush:
            brushes.append(brush)
    # worldspawn solids are nested deeper under world { solid {
    if not brushes:
        for m in re.finditer(r"(?m)^\tsolid\s*\{|^(?!\t)solid\s*\{", inner):
            open_brace = inner.find("{", m.start())
            close = find_matching_brace(inner, open_brace)
            brush = solid_to_brush(inner[open_brace + 1 : close])
            if brush:
                brushes.append(brush)
    return brushes


def convert(vmf_path: Path, map_path: Path) -> None:
    text = vmf_path.read_text(encoding="utf-8", errors="replace")
    out: list[str] = []
    out.append("// Game: stiletto")
    out.append("// Format: Valve")
    out.append("// Converted from Source VMF (lossy playtest convert)")

    # worldspawn
    world_blocks = list(iter_named_blocks(text, "world"))
    if not world_blocks:
        raise SystemExit("no world{} block in VMF")
    _, world_inner = world_blocks[0]
    wkvs = extract_kvs(world_inner)
    brushes = []
    # solids directly under world use one-tab indent in BSPSource output
    for m in re.finditer(r"(?m)^\tsolid\s*\{", world_inner):
        open_brace = world_inner.find("{", m.start())
        close = find_matching_brace(world_inner, open_brace)
        brush = solid_to_brush(world_inner[open_brace + 1 : close])
        if brush:
            brushes.append(brush)

    out.append("{")
    out.append('"classname" "worldspawn"')
    msg = wkvs.get("message") or wkvs.get("comment") or vmf_path.stem
    out.append(f'"message" "{msg}"')
    # Prefer an existing local sky material stem if present later; name is fine.
    out.append('"sky" "sundown"')
    out.append('"_sun" "1"')
    for b in brushes:
        out.append(b)
    out.append("}")

    spawn_origins: list[str] = []
    ent_count = 0
    skipped = 0

    for _, ent_inner in iter_named_blocks(text, "entity"):
        kvs = extract_kvs(ent_inner)
        cls = kvs.get("classname", "")
        solids = []
        for m in re.finditer(r"(?m)^\tsolid\s*\{", ent_inner):
            open_brace = ent_inner.find("{", m.start())
            close = find_matching_brace(ent_inner, open_brace)
            brush = solid_to_brush(ent_inner[open_brace + 1 : close])
            if brush:
                solids.append(brush)

        if solids:
            mapped = KEEP_BRUSH.get(cls)
            if not mapped:
                # fold unknown brush ents into world-like func_detail
                mapped = "func_detail"
            out.append("{")
            out.append(f'"classname" "{mapped}"')
            if "targetname" in kvs:
                out.append(f'"targetname" "{kvs["targetname"]}"')
            for b in solids:
                out.append(b)
            out.append("}")
            ent_count += 1
            continue

        mapped = KEEP_POINT.get(cls)
        if not mapped:
            skipped += 1
            continue
        out.append("{")
        out.append(f'"classname" "{mapped}"')
        if "origin" in kvs:
            out.append(f'"origin" "{kvs["origin"]}"')
            if mapped == "info_player_deathmatch":
                spawn_origins.append(kvs["origin"])
        if "angle" in kvs:
            out.append(f'"angle" "{kvs["angle"]}"')
        elif "angles" in kvs:
            # Quake often wants yaw only
            parts = kvs["angles"].split()
            yaw = parts[1] if len(parts) >= 2 else "0"
            out.append(f'"angle" "{yaw}"')
        if mapped == "light":
            # crude brightness from Source light
            bright = kvs.get("_light", "255 255 255 200")
            parts = bright.split()
            intensity = parts[3] if len(parts) >= 4 else "200"
            out.append(f'"light" "{intensity}"')
        out.append("}")
        ent_count += 1

    # Ensure at least a couple deathmatch spawns for freeplay.
    if spawn_origins:
        ox, oy, oz = map(float, spawn_origins[0].split())
        extras = [
            (ox + 64, oy, oz),
            (ox - 64, oy, oz),
            (ox, oy + 64, oz),
            (ox, oy - 64, oz),
        ]
        for x, y, z in extras:
            out.append("{")
            out.append('"classname" "info_player_deathmatch"')
            out.append(f'"origin" "{x:g} {y:g} {z:g}"')
            out.append("}")
            ent_count += 1
        out.append("{")
        out.append('"classname" "info_player_start"')
        out.append(f'"origin" "{spawn_origins[0]}"')
        out.append("}")
        ent_count += 1
    else:
        out.append("{")
        out.append('"classname" "info_player_start"')
        out.append('"origin" "0 0 64"')
        out.append("}")
        out.append("{")
        out.append('"classname" "info_player_deathmatch"')
        out.append('"origin" "0 0 64"')
        out.append("}")
        ent_count += 2

    map_path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(
        f"Wrote {map_path} ({map_path.stat().st_size} bytes) "
        f"worldbrushes={len(brushes)} ents={ent_count} skipped_point={skipped}"
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("vmf")
    ap.add_argument("map")
    args = ap.parse_args()
    convert(Path(args.vmf), Path(args.map))


if __name__ == "__main__":
    main()
