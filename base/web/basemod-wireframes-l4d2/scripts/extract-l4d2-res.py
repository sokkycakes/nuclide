#!/usr/bin/env python3
"""Extract L4D2 l4d360ui .res files from pak01_dir.vpk into res/."""

import os
import sys

try:
    import vpk
except ImportError:
    print("pip install vpk", file=sys.stderr)
    sys.exit(1)

DEFAULT_L4D2 = r"D:\Steam\steamapps\common\Left 4 Dead 2\left4dead2\pak01_dir.vpk"

CORE = [
    "resource/ui/l4d360ui/mainmenu.res",
    "resource/ui/l4d360ui/gamelobby.res",
    "resource/ui/l4d360ui/gamesettings_coopcreate.res",
    "resource/ui/l4d360ui/loadingprogress.res",
    "resource/ui/l4d360ui/ingamemainmenu.res",
    "resource/ui/l4d360ui/voteoptions.res",
    "resource/ui/l4d360ui/genericconfirmation.res",
    "resource/ui/l4d360ui/ingamechapterselect.res",
    "resource/ui/l4d360ui/ingamedifficultyselect.res",
    "resource/ui/l4d360ui/campaignflyout.res",
    "resource/ui/l4d360ui/optionsflyout.res",
]

EXTRA = [
    "resource/ui/l4d360ui/mainmenustub.res",
    "resource/ui/l4d360ui/teamlobby.res",
    "resource/ui/l4d360ui/playeritem.res",
]


def main():
    vpk_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_L4D2
    out_dir = os.path.join(os.path.dirname(__file__), "..", "res")
    out_dir = os.path.normpath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    pak = vpk.open(vpk_path)
    files = CORE + EXTRA
    if "--all" in sys.argv:
        files = sorted(f for f in pak if f.startswith("resource/ui/l4d360ui/") and f.endswith(".res"))

    for path in files:
        if path not in pak:
            print("skip (missing):", path)
            continue
        name = os.path.basename(path)
        dest = os.path.join(out_dir, name)
        with open(dest, "wb") as f:
            f.write(pak[path].read())
        print("wrote", name)

    print("done ->", out_dir)


if __name__ == "__main__":
    main()
