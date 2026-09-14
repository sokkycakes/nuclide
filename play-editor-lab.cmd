@echo off
setlocal
set "STILETTO_RUNTIME=%~dp0"
if not exist "%STILETTO_RUNTIME%fteqw-world.exe" (
    echo Build the editor runtime with Tools/stiletto/build_engine.sh first.
    pause
    exit /b 1
)
if not exist "%STILETTO_RUNTIME%base\maps\ftew_framework.dat" (
    echo Run Tools/stiletto/build_gamecode.ps1 first.
    pause
    exit /b 1
)
if not exist "%STILETTO_RUNTIME%base\maps\ftew_client.dat" (
    echo Run Tools/stiletto/build_gamecode.ps1 first.
    pause
    exit /b 1
)
start "Stiletto native world lab" /D "%STILETTO_RUNTIME%." "%STILETTO_RUNTIME%fteqw-world.exe" -basedir "%STILETTO_RUNTIME%." -manifest "%STILETTO_RUNTIME%base.fmf" -nohome -window -width 1280 -height 720 +set cfg_save_auto 0 +set sv_public 0 +set maxclients 4 +set sv_progs maps/ftew_framework.dat +set sv_csqc_progname maps/ftew_client.dat +set webcore_hud 0 +set webcore_menu_enabled 1 +map editor_lab.ftew
