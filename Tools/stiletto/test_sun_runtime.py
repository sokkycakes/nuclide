"""Verify native directional lighting, shadows, rotation and reset via captures."""
from pathlib import Path
import argparse
import json
import os
import subprocess
from PIL import Image, ImageStat, ImageChops

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "worldsrc/build"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", default="fteqw-world.exe")
    args = parser.parse_args()
    names = ["off", "shadow", "unshadowed", "rotated", "reset"]
    for name in names:
        (ROOT/"base"/("ftew_sun_"+name+".png")).unlink(missing_ok=True)
    config = ROOT/"base/ftew_sun_probe.cfg"
    config.write_text('''wait
cfg_save_auto 0
log_enable 1
sv_public 0
maxclients 4
set webcore_hud 0
set webcore_menu_enabled 0
set sv_progs maps/ftew_framework.dat
set sv_csqc_progname maps/ftew_client.dat
set ftew_sun_stage 0
r_coronas 0
r_showDlights 0
r_shadow_realtime_dlight 1
r_shadow_realtime_world_shadows 1
r_shadow_realtime_dlight_shadows 1
r_shadows 0
in 2 map ftew_sun_probe.ftew
in 8 screenshot ftew_sun_off.png
in 9 set ftew_sun_stage 1
in 11 screenshot ftew_sun_shadow.png
in 12 set ftew_sun_stage 2
in 14 screenshot ftew_sun_unshadowed.png
in 15 set ftew_sun_stage 3
in 17 screenshot ftew_sun_rotated.png
in 18 set ftew_sun_stage 0
in 20 screenshot ftew_sun_reset.png
in 21 echo FTEW_SUN_PROBE_DONE
in 22 quit
''')
    log = ROOT/"base/ftew_sun_probe.log"
    log.unlink(missing_ok=True)
    env = os.environ.copy()
    env["PATH"] = "C:/msys64/mingw64/bin;"+env.get("PATH","")
    command = [str(ROOT/args.engine),"-basedir",str(ROOT),"-manifest",str(ROOT/"base.fmf"),
               "-nohome","-nojoy","-nomouse","-nosound","-window","-width","960","-height","640",
               "+set","cfg_save_auto","0","+set","log_name","ftew_sun_probe","+exec",config.name]
    with (BUILD/"sun-runtime.stdout").open("w") as stream:
        process = subprocess.Popen(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        try: code = process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],capture_output=True)
            code = -1
    images = []
    for name in names:
        with Image.open(ROOT/"base"/("ftew_sun_"+name+".png")) as image:
            image.save(BUILD/("sun_"+name+".png"))
            images.append(image.convert("RGB").crop((100,250,850,520)))
    means = [ImageStat.Stat(image.convert("L")).mean[0] for image in images]
    shadow_difference = sum(ImageStat.Stat(ImageChops.difference(images[1],images[2])).mean)
    rotation_difference = sum(ImageStat.Stat(ImageChops.difference(images[1],images[3])).mean)
    reset_difference = sum(ImageStat.Stat(ImageChops.difference(images[0],images[4])).mean)
    output = log.read_text(errors="replace")
    (BUILD/"sun-runtime.log").write_text(output)
    passed = (code == 0 and "FTEW_SUN_PROBE_DONE" in output and
              all("FTEW_SUN_STAGE "+str(stage) in output for stage in [0,1,2,3]) and
              means[1] > means[0]+3 and means[2] > means[1]+0.1 and
              shadow_difference > 0.5 and rotation_difference > 0.5 and reset_difference < 0.5)
    print(json.dumps({"ok":passed,"exit":code,"brightness":dict(zip(names,means)),
                      "shadow_difference":shadow_difference,"rotation_difference":rotation_difference,"reset_difference":reset_difference}))
    return 0 if passed else 1

if __name__ == "__main__": raise SystemExit(main())
