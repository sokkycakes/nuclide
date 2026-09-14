"""Exercise native global MP3 and looping WAV playback, stop, restart and updates.

Requires the test_audio_export.gd fixture and compiled audio_probe.qc MapC.
Uses the real mixer at low volume; no persistent audio configuration is saved.
"""
from pathlib import Path
import os, subprocess, re, json
ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT/'worldsrc/build'

def main():
    config = ROOT/'base/ftew_audio_probe.cfg'
    config.write_text('''wait
cfg_save_auto 0
log_enable 1
sv_public 0
maxclients 4
set g_gametype deathmatch
set sv_progs maps/ftew_framework.dat
set sv_csqc_progname maps/ftew_client.dat
set webcore_hud 0
set webcore_menu_enabled 0
set s_logLevel 4
set ftew_audio_stage 0
volume 0.02
snd_inactive 0
in 2 map ftew_audio_probe.ftew
in 8 set ftew_audio_stage 1
in 11 set ftew_audio_stage 2
in 14 set ftew_audio_stage 3
in 17 set ftew_audio_stage 4
in 20 set ftew_audio_stage 5
in 23 soundlist
in 24 echo FTEW_AUDIO_DONE
in 25 quit
''')
    log = ROOT/'base/ftew_audio_probe.log'
    log.unlink(missing_ok=True)
    env = os.environ.copy()
    env['PATH'] = 'C:/msys64/mingw64/bin;'+env.get('PATH','')
    cmd = [str(ROOT/'fteqw-world.exe'),'-basedir',str(ROOT),'-manifest',str(ROOT/'base.fmf'),'-nohome','-nojoy','-nomouse','-window','-width','640','-height','480','+set','log_name','ftew_audio_probe','+exec',config.name]
    with (BUILD/'audio-runtime.stdout').open('w') as stream:
        p = subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        try: code = p.wait(timeout=50)
        except subprocess.TimeoutExpired:
            p.kill();p.wait();code=-1
    text = log.read_text(errors='replace') if log.exists() else ''
    (BUILD/'audio-runtime.log').write_text(text)
    states = re.findall(r'Global audio:.*playing=(\d+) loop=(\d+) volume=([\d.]+) pitch=([\d.]+) serial=([\d.]+)',text)
    channels = re.findall(r'Global channel:.*?/[^/\s"]+?\.(mp3\.wav|wav).*serial=([\d.]+) time=([-\d.]+) level=([-\d.]+)',text)
    channels = [('mp3' if c[0]=='mp3.wav' else 'wav',*c[1:]) for c in channels]
    moving = {ext:any(c[0]==ext and float(c[2])>0 and float(c[3])>0 for c in channels) for ext in ['mp3','wav']}
    stopped = any(float(c[1]) in [2,4] and float(c[2])<0 for c in channels)
    updated = any(float(s[2])==0.25 and float(s[3])==150 for s in states)
    passed = code==0 and 'FTEW_AUDIO_DONE' in text and all(moving.values()) and stopped and updated and all('FTEW_AUDIO_STAGE '+str(i) in text for i in range(6))
    print(json.dumps({'ok':passed,'exit':code,'decoded_audio':moving,'stopped':stopped,'updated':updated,'states':states,'channels':channels[-8:]}))
    return 0 if passed else 1

if __name__=='__main__': raise SystemExit(main())
