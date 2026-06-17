@echo off
setlocal EnableExtensions
rem Args: source.bsp destdir mapname (no extension)
set "SRC=%~1"
set "MAPDIR=%~2"
set "MAPNAME=%~3"
if "%SRC%"=="" exit /b 1
if "%MAPDIR%"=="" exit /b 1
if "%MAPNAME%"=="" exit /b 1
if not exist "%MAPDIR%" mkdir "%MAPDIR%"
copy /Y "%SRC%" "%MAPDIR%\%MAPNAME%.bsp"
exit /b %ERRORLEVEL%
