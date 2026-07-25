#!/usr/bin/env python3
"""Assert duel_alley DM spawns sit on the end platforms (floor+36).

Run: python tools/check_duel_alley_spawns.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "base" / "maps" / "duel_alley.map"
BSP = ROOT / "base" / "maps" / "duel_alley.bsp"

# End platforms are flat at z ~= -624.115; hull mins.z = -36
FLOOR_Z = -624.115
HULL_MIN_Z = -36.0
EXPECTED_ORIGIN_Z = FLOOR_Z + abs(HULL_MIN_Z)
TOLERANCE = 2.0


def main() -> int:
    text = MAP.read_text(encoding="utf-8", errors="replace")
    spawns = re.findall(
        r'"classname"\s+"info_player_deathmatch"\s*\n"origin"\s+"([^"]+)"',
        text,
    )
    if len(spawns) < 2:
        print(f"FAIL: expected >=2 info_player_deathmatch, got {spawns!r}")
        return 1

    errors = []
    for origin in spawns:
        x, y, z = (float(p) for p in origin.split())
        if abs(z - EXPECTED_ORIGIN_Z) > TOLERANCE:
            errors.append(
                f"spawn ({x}, {y}, {z}) z off by {z - EXPECTED_ORIGIN_Z:.3f} "
                f"(want ~{EXPECTED_ORIGIN_Z})"
            )

    if not BSP.is_file():
        errors.append(f"missing playable BSP: {BSP}")

    if errors:
        print("FAIL:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(
        f"OK: {len(spawns)} DM spawns at z~={EXPECTED_ORIGIN_Z}, "
        f"BSP present ({BSP.stat().st_size} bytes)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
