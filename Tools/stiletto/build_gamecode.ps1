$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$compiler = Join-Path $taskRoot 'fteqcc.exe'
& (Join-Path $PSScriptRoot 'compile_map.ps1') -Compiler $compiler -Source (Join-Path $taskRoot 'base/src/client/progs.src') -Output (Join-Path $taskRoot 'base/maps/ftew_client.dat')
& (Join-Path $PSScriptRoot 'compile_map.ps1') -Compiler $compiler -Source (Join-Path $taskRoot 'base/src/server/progs.src') -Output (Join-Path $taskRoot 'base/maps/ftew_framework.dat')
& (Join-Path $PSScriptRoot 'compile_map.ps1') -Compiler $compiler -Source (Join-Path $taskRoot 'worldsrc/maps/editor_lab.qc') -Output (Join-Path $taskRoot 'base/maps/editor_lab.dat')
