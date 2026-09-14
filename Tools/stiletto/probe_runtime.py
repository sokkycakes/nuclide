"""Run owned, isolated FTEW smoke processes; keep logs out of normal console logs."""
from pathlib import Path
import subprocess
import argparse
import os
import json
import re

ROOT = Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--client",action="store_true")
    args=parser.parse_args()
    build=ROOT/"worldsrc/build"
    build.mkdir(exist_ok=True)
    logname="ftew_client_probe" if args.client else "ftew_server_probe"
    cfg=ROOT/"base"/(logname+".cfg")
    config='''wait
cfg_save_auto 0
log_enable 1
sv_public 0
maxclients 4
set sv_progs maps/ftew_framework.dat
set sv_csqc_progname maps/ftew_client.dat
webcore_hud 0
set webcore_menu_enabled 0
developer 1
in 2 map editor_lab.ftew
in 10 ftew_trace 0 -192 96 0 -192 -32
in 10 ftew_trace 0 -192 96 0 -192 -32 1
in 10 ftew_trace 160 -96 192 160 -96 -32
in 10 status
in 11 echo FTEW_PROBE_DONE
in 12 quit
'''
    screenshot=ROOT/"base/ftew_probe.png"
    if args.client:
        screenshot.unlink(missing_ok=True)
        config += "in 10 screenshot ftew_probe.png\n"
    cfg.write_text(config)
    console=ROOT/"base"/(logname+".log")
    if console.exists(): console.unlink()
    executable="fteqw-world.exe" if args.client else "fteqw-world-server.exe"
    command=[str(ROOT/executable),"-basedir",str(ROOT),"-manifest",str(ROOT/"base.fmf"),"-nohome","-nojoy","-nosound","-debugstdout","-condebug"]
    command += ["-window","-width","960","-height","640"] if args.client else ["-dedicated"]
    command += ["+set","log_name",logname,"+set","cfg_save_auto","0","+exec",cfg.name]
    env=os.environ.copy()
    env["PATH"]="C:/msys64/mingw64/bin;"+env.get("PATH","")
    with (build/(logname+".stdout")).open("w") as stdout:
        process=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=subprocess.STDOUT,env=env,creationflags=subprocess.CREATE_NO_WINDOW)
        try: code=process.wait(timeout=50)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            code=-1
    console=ROOT/"base"/(logname+".log")
    text=console.read_text(errors="replace") if console.exists() else (build/(logname+".stdout")).read_text(errors="replace")
    (build/(logname+".log")).write_text(text)
    for line in text.splitlines():
        if any(key in line for key in ("FTEW", "Error", "ERROR", "error", "Couldn't", "couldn't", "WARNING")): print(line)
    traces=[tuple(map(float,match)) for match in re.findall(r"FTEW_TRACE fraction ([\d.]+) end ([-\d.]+) ([-\d.]+) ([-\d.]+) startsolid (\d+)",text)]
    expected=[(0,-192,0.031),(0,-192,24.031),(160,-96,43.532)]
    collision_ok=len(traces)==3 and all(any(0<t[0]<1 and t[4]==0 and all(abs(t[i+1]-p[i])<0.05 for i in range(3)) for t in traces) for p in expected)
    passed=code==0 and collision_ok and "FTEW_PROBE_DONE" in text and "FTEW_MAPC:" in text and "current map      : editor_lab.ftew" in text
    if args.client: passed=passed and screenshot.exists() and screenshot.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    print(json.dumps({"ok":passed,"exit":code,"collision_ok":collision_ok,"log":str(build/(logname+".log")),"bytes":len(text)}))
    return 0 if passed else 1
if __name__=="__main__":raise SystemExit(main())
