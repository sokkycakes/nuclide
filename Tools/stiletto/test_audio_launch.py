"""Check cold Export + Play startup keeps the requested map and starts its audio."""
from pathlib import Path
import argparse, os, subprocess, re, json
ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT/'worldsrc/build'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine',default='fteqw-world.exe')
    parser.add_argument('--map',default='ftew_audio_probe')
    parser.add_argument('--loop-duration',type=float,default=0,help='Verify a music wrap after this many seconds of source audio')
    args = parser.parse_args()
    config = ROOT/'base/ftew_audio_launch.cfg'
    duration = max(17,int(args.loop_duration)+16)
    config.write_text(f'wait\nlog_enable 1\nvolume 0.02\nsnd_inactive 0\nin 12 status\nin {duration-1} echo FTEW_AUDIO_LAUNCH_DONE\nin {duration} quit\n')
    logfile = ROOT/'base/ftew_audio_launch.log'
    logfile.unlink(missing_ok=True)
    env = os.environ.copy()
    env['PATH'] = 'C:/msys64/mingw64/bin;'+env.get('PATH','')
    cmd = [str(ROOT/args.engine),'-basedir',str(ROOT),'-manifest',str(ROOT/'base.fmf'),'-nohome','-window','-nomouse','-nojoy','-width','640','-height','480']
    for key,value in [('log_name','ftew_audio_launch'),('log_enable','1'),('s_logLevel','4'),('sv_progs','maps/ftew_framework.dat'),('sv_csqc_progname','maps/ftew_client.dat'),('cfg_save_auto','0'),('webcore_hud','0'),('webcore_menu_enabled','1'),('sv_public','0'),('maxclients','4'),('ftew_audio_stage','0')]:
        cmd += ['+set',key,value]
    # Same ordering as the editor: map on the command line, without a delayed map command.
    cmd += ['+set','g_gametype','deathmatch']
    cmd += ['+map',args.map+'.ftew','+exec',config.name]
    with (BUILD/'audio-launch.stdout').open('w') as stream:
        p = subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        try: code = p.wait(timeout=duration+25)
        except subprocess.TimeoutExpired:
            p.kill();p.wait();code=-1
    text = logfile.read_text(errors='replace') if logfile.exists() else ''
    (BUILD/'audio-launch.log').write_text(text)
    channels = re.findall(r'Global channel:.*\.mp3\.wav.*time=([-\d.]+) level=([-\d.]+)',text)
    audible = any(float(t)>1 and float(level)>0 for t,level in channels)
    kept_map = 'current map      : '+args.map+'.ftew' in text
    looped = any(float(a[0])>args.loop_duration-3 and 0<=float(b[0])<3 and float(b[1])>0 for a,b in zip(channels,channels[1:])) if args.loop_duration else None
    passed = code==0 and audible and kept_map and 'FTEW_AUDIO_LAUNCH_DONE' in text and (looped if args.loop_duration else True)
    print(json.dumps({'ok':passed,'exit':code,'kept_requested_map':kept_map,'decoded_music':audible,'looped':looped,'samples':channels[-3:]}))
    return 0 if passed else 1

if __name__=='__main__': raise SystemExit(main())
