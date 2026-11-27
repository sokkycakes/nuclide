@echo off
rem Host a Stiletto Proto dedicated server (Windows playtest build, FTE).
rem Settings are in base\server.cfg. Extra options are passed on, e.g.
rem   host-server.cmd -port 27600 +set g_gametype freezetag +map duel_alley
rem Type commands into this window while it runs (status, map, kick, quit).
cd /d "%~dp0"
rem An older server.cfg starts its first map with a plain "map" line,
rem which runs before the command line, so a +map here loads two maps.
rem Updates never overwrite server.cfg, so point that out.
findstr /b /l /i /c:"map " base\server.cfg >nul 2>&1
if not errorlevel 1 echo Note: base\server.cfg has an old "map" line. Replace it with: alias startmap_dm "map duel_alley" - see PLAYTESTERS.txt.
fteqw64.exe -dedicated -basedir . -manifest base.fmf %*
