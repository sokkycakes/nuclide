@echo off
setlocal
set "ROOT=%~dp0.."
set "QCC=%~1"
if "%QCC%"=="" if not "%FTEQCC%"=="" set "QCC=%FTEQCC%"
if "%QCC%"=="" set "QCC=%~dp0..\..\..\fteqw\engine\release\fteqcc64.exe"
if not exist "%QCC%" set "QCC=%~dp0..\..\..\fteqw\engine\release\winqcc64.exe"
if not exist "%QCC%" (
  echo FTEQCC not found.
  echo   Pass full path: rebuild_menu_hud.bat path\to\fteqcc64.exe
  echo   Or set FTEQCC, or build fteqw so one of these exists:
  echo     %~dp0..\..\..\fteqw\engine\release\fteqcc64.exe
  echo     %~dp0..\..\..\fteqw\engine\release\winqcc64.exe
  echo   Or run: "%~dp0..\..\..\fteqw\run_qcc.bat" to print the resolved path.
  exit /b 2
)
echo Using QCC: %QCC%
set "MENU=%ROOT%\src\menu"
set "HUD=%ROOT%\src\hud"
echo Building menu.dat...
start /wait /D "%MENU%" "%QCC%" progs.src
if errorlevel 1 (
  echo menu compile failed, exit %ERRORLEVEL%
  exit /b 1
)
echo Building hud.dat...
start /wait /D "%HUD%" "%QCC%" progs.src
if errorlevel 1 (
  echo hud compile failed, exit %ERRORLEVEL%
  exit /b 1
)
echo Done.
exit /b 0
