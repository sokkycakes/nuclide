@echo off
cd /d "%~dp0"
if not exist fteqw64.exe.new (
  echo Missing fteqw64.exe.new
  exit /b 1
)
copy /y fteqw64.exe.new fteqw64.exe
copy /y fteplug_webcore_x64.dll.new fteplug_webcore_x64.dll
echo Staged lobby UI binaries.
