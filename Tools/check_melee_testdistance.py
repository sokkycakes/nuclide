#!/usr/bin/env python3
"""Assert TF2-style melee weapons never gate swings on a line-only testDistance.

Negative testDistance made UseAmmo require a crosshair LINE hit before
DoSwingTrace ran, so the ±18 hull forgiveness path was unreachable.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFS = [
    ROOT / "base/decls/def/weapons/weapon_melee_base.def",
    ROOT / "base/decls/def/weapons/axe.def",
    ROOT / "base/decls/def/weapons/archstiletto.def",
]

KEY = re.compile(r'"testDistance"\s+"([^"]+)"')


def main() -> int:
    failed = 0
    for path in DEFS:
        text = path.read_text(encoding="utf-8")
        matches = KEY.findall(text)
        if not matches:
            print(f"FAIL {path.name}: missing testDistance")
            failed += 1
            continue
        val = matches[-1]
        if float(val) != 0.0:
            print(f"FAIL {path.name}: testDistance={val!r} (want 0)")
            failed += 1
        else:
            print(f"ok   {path.name}: testDistance=0")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
