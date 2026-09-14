"""Owned local server/two-client integration fixture; no game configuration saved."""
from pathlib import Path
import subprocess
import os
import time
import json

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "worldsrc/build"

def main():
    BUILD.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["PATH"] = "C:/msys64/mingw64/bin;" + env.get("PATH", "")
    processes = []
    streams = []
    names = ["ftew_net_server", "ftew_net_a", "ftew_net_b"]
    common = "cfg_save_auto 0\nlog_enable 1\nsv_public 0\nset webcore_hud 0\nset webcore_menu_enabled 0\n"
    configs = [common + "maxclients 4\nset sv_progs maps/ftew_framework.dat\nset sv_csqc_progname maps/ftew_client.dat\nset ftew_probe 1\nmap editor_lab.ftew\nin 20 status\nin 26 quit\n"]
    for suffix in ["A", "B"]:
        configs.append("wait\n" + common + f"name WorldProbe{suffix}\nspectator 0\nin 2 connect 127.0.0.1:28991\nin 17 screenshot ftew_net_{suffix}.tga\nin 22 quit\n")
    try:
        for index, name in enumerate(names):
            config = ROOT / "base" / (name + ".cfg")
            config.write_text(configs[index])
            log = ROOT / "base" / (name + ".log")
            log.unlink(missing_ok=True)
            executable = "fteqw-world-server.exe" if index == 0 else "fteqw-world.exe"
            command = [str(ROOT/executable), "-basedir", str(ROOT), "-manifest", str(ROOT/"base.fmf"),
                       "-nohome", "-nojoy", "-nosound", "+set", "cfg_save_auto", "0", "+set", "log_name", name]
            if index == 0: command += ["-port", "28991", "-ip", "127.0.0.1"]
            else: command += ["-window", "-width", "960", "-height", "640"]
            command += ["+exec", config.name]
            stream = (BUILD/(name+".stdout")).open("w")
            streams.append(stream)
            processes.append(subprocess.Popen(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW))
            if index == 0: time.sleep(3)
        for process in processes:
            process.wait(timeout=40)
    finally:
        for process in processes:
            if process.poll() is None:
                subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],capture_output=True)
        for stream in streams: stream.close()
    logs = []
    for name in names:
        path = ROOT/"base"/(name+".log")
        text = path.read_text(errors="replace") if path.exists() else ""
        (BUILD/(name+".log")).write_text(text)
        logs.append(text)
        for line in text.splitlines():
            if "FTEW" in line or "WorldProbe" in line or "current map" in line: print(name, line)
    passed = (all(p.returncode == 0 for p in processes)
              and "WorldProbeA connected" in logs[0] and "WorldProbeB connected" in logs[0]
              and "FTEW_IO before=1 after=0" in logs[0]
              and all("CSQC_WorldLoaded" in text for text in logs[1:]))
    print(json.dumps({"ok":passed,"exits":[p.returncode for p in processes]}))
    return 0 if passed else 1

if __name__ == "__main__": raise SystemExit(main())
