"""Compare real illuminated geometry across live native brightness inputs.

First run the Godot test_light_export.gd script and compile light_probe.qc
to base/maps/ftew_light_probe.dat. Requires Pillow.
"""
from pathlib import Path
import argparse
import json
import os
import subprocess
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "worldsrc/build"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", default="fteqw-world.exe")
    args = parser.parse_args()
    names = ["zero", "one", "four", "reset"]
    for name in names:
        (ROOT / "base" / ("ftew_light_" + name + ".png")).unlink(missing_ok=True)
    config = ROOT / "base/ftew_light_probe.cfg"
    config.write_text('''wait
cfg_save_auto 0
log_enable 1
sv_public 0
maxclients 4
set webcore_hud 0
set webcore_menu_enabled 0
set sv_progs maps/ftew_framework.dat
set sv_csqc_progname maps/ftew_client.dat
set ftew_test_energy 0
r_coronas 0
r_showDlights 0
r_shadow_realtime_dlight 1
in 2 map ftew_light_probe.ftew
in 8 screenshot ftew_light_zero.png
in 9 set ftew_test_energy 1
in 11 screenshot ftew_light_one.png
in 12 set ftew_test_energy 4
in 14 screenshot ftew_light_four.png
in 15 set ftew_test_energy 0
in 17 screenshot ftew_light_reset.png
in 18 echo FTEW_LIGHT_PROBE_DONE
in 19 quit
''')
    log = ROOT / "base/ftew_light_probe.log"
    log.unlink(missing_ok=True)
    env = os.environ.copy()
    env["PATH"] = "C:/msys64/mingw64/bin;" + env.get("PATH", "")
    command = [str(ROOT / args.engine), "-basedir", str(ROOT), "-manifest", str(ROOT / "base.fmf"),
               "-nohome", "-nojoy", "-nomouse", "-nosound", "-window", "-width", "960", "-height", "640",
               "+set", "cfg_save_auto", "0", "+set", "log_name", "ftew_light_probe", "+exec", config.name]
    with (BUILD / "light-runtime.stdout").open("w") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            code = process.wait(timeout=40)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
            code = -1
    values = []
    for name in names:
        with Image.open(ROOT / "base" / ("ftew_light_" + name + ".png")) as image:
            image.save(BUILD / ("light_" + name + ".png"))
            # Floor only: exclude sky, HUD, player, and the light's debug sprite.
            values.append(ImageStat.Stat(image.convert("L").crop((200, 390, 760, 500))).mean[0])
    output = log.read_text(errors="replace")
    (BUILD / "light-runtime.log").write_text(output)
    passed = (code == 0 and "FTEW_LIGHT_PROBE_DONE" in output
              and all("FTEW_LIGHT_ENERGY " + str(e) in output for e in [0, 1, 4])
              and values[0] + 1 < values[1] and values[1] + 1 < values[2]
              and abs(values[0] - values[3]) < 0.5)
    print(json.dumps({"ok": passed, "exit": code, "floor_brightness": dict(zip(names, values))}))
    return 0 if passed else 1

if __name__ == "__main__":
    raise SystemExit(main())
