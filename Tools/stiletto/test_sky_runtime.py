"""Capture map default, two live sky overrides, and reset in one client session."""
from pathlib import Path
import os
import subprocess
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

def main():
    names = ["default", "day", "dusk", "reset"]
    images = [ROOT/"base"/('ftew_sky_'+name+'.png') for name in names]
    for path in images: path.unlink(missing_ok=True)
    config = ROOT/"base/ftew_sky_probe.cfg"
    config.write_text('''wait
cfg_save_auto 0
log_enable 1
sv_public 0
set webcore_hud 0
set webcore_menu_enabled 0
set sv_progs maps/ftew_framework.dat
set sv_csqc_progname maps/ftew_client.dat
in 2 map editor_lab.ftew
in 6 r_fastsky 0
in 7 r_skybox ""
in 8 screenshot ftew_sky_default.png
in 9 r_skybox env/fteworld/day
in 11 screenshot ftew_sky_day.png
in 12 r_skybox env/fteworld/dusk
in 14 screenshot ftew_sky_dusk.png
in 15 r_skybox ""
in 17 screenshot ftew_sky_reset.png
in 18 echo FTEW_SKY_PROBE_DONE
in 19 quit
''')
    log = ROOT/"base/ftew_sky_probe.log"
    log.unlink(missing_ok=True)
    env = os.environ.copy()
    env["PATH"] = "C:/msys64/mingw64/bin;" + env.get("PATH", "")
    command = [str(ROOT/"fteqw-world.exe"), "-basedir", str(ROOT), "-manifest", str(ROOT/"base.fmf"),
               "-nohome", "-nojoy", "-nosound", "-window", "-width", "960", "-height", "640",
               "+set", "cfg_save_auto", "0", "+set", "log_name", "ftew_sky_probe", "+exec", config.name]
    with (ROOT/"worldsrc/build/sky-runtime.stdout").open("w") as stream:
        process = subprocess.Popen(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        try: code = process.wait(timeout=40)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],capture_output=True)
            code = -1
    pixels = []
    for name,path in zip(names,images):
        if not path.exists(): raise AssertionError("Missing capture: "+name)
        with Image.open(path) as img:
            pixels.append(img.convert("RGB").getpixel((100,100)))
            img.save(ROOT/"worldsrc/build"/("sky_"+name+".png"))
    text = log.read_text(errors="replace")
    (ROOT/"worldsrc/build/sky-runtime.log").write_text(text)
    passed = (code == 0 and "FTEW_SKY_PROBE_DONE" in text and
              pixels[0] == pixels[3] and len(set(pixels[:3])) == 3 and pixels[1][2]>pixels[1][0])
    print(json.dumps({"ok":passed,"exit":code,"sky_pixels":dict(zip(names,pixels))}))
    return 0 if passed else 1

if __name__ == "__main__": raise SystemExit(main())
