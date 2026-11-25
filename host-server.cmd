@echo off
rem Host a Stiletto Proto dedicated server (Windows playtest build, FTE).
rem Settings are in base\server.cfg. Extra options are passed on, e.g.
rem   host-server.cmd -port 27600 +set g_gametype freezetag +map duel_alley
rem Type commands into this window while it runs (status, map, kick, quit).
cd /d "%~dp0"
fteqw64.exe -dedicated -basedir . -manifest base.fmf %*
