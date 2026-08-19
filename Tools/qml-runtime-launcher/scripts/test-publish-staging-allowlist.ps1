$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$drop = Join-Path $env:TEMP ("publish-drop-" + [guid]::NewGuid().ToString("n"))
$launcherFake = Join-Path $env:TEMP ("publish-launcher-" + [guid]::NewGuid().ToString("n"))
$out = Join-Path $env:TEMP ("publish-out-" + [guid]::NewGuid().ToString("n"))

New-Item -ItemType Directory -Path (Join-Path $drop "base\data\web\hud") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $drop "resources") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $launcherFake "app") | Out-Null

[IO.File]::WriteAllText((Join-Path $drop "fteqw64.exe"), "engine-bytes")
[IO.File]::WriteAllText((Join-Path $drop "fteplug_webcore_x64.dll"), "plug")
[IO.File]::WriteAllText((Join-Path $drop "resources\icudt67l.dat"), "icu")
[IO.File]::WriteAllText((Join-Path $drop "base\progs.dat"), "progs-bytes")
[IO.File]::WriteAllText((Join-Path $drop "base\data\web\hud\index.html"), "hud")
[IO.File]::WriteAllText((Join-Path $drop "identity.pfx"), "secret")

[IO.File]::WriteAllText((Join-Path $launcherFake "NuclideLauncher.exe"), "launcher")
[IO.File]::WriteAllText((Join-Path $launcherFake "app\main.qml"), "main")
[IO.File]::WriteAllText((Join-Path $launcherFake "app\MainForm.ui.qml"), "form")
[IO.File]::WriteAllText((Join-Path $launcherFake "app\config.json"), "{}")

& (Join-Path $here "publish-staging.ps1") `
    -DropRoot $drop `
    -SkipSync `
    -LauncherRoot $launcherFake `
    -EngineExe (Join-Path $drop "fteqw64.exe") `
    -OutputDirectory $out `
    -Version "test.1"

$manifestPath = Join-Path $out "manifest.json"
if (-not (Test-Path $manifestPath)) { throw "missing manifest.json" }
$manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
$paths = @($manifest.files | ForEach-Object { $_.path })

$required = @(
    "fteqw64.exe",
    "base/progs.dat",
    "resources/icudt67l.dat",
    "launcher/NuclideLauncher.exe",
    "launcher/app/main.qml"
)
foreach ($req in $required) {
    if ($paths -notcontains $req) { throw "manifest missing path: $req" }
}

if ($paths -contains "identity.pfx") { throw "identity.pfx must not be in manifest" }

$launcherDest = Join-Path $out "launcher\NuclideLauncher.exe"
if (-not (Test-Path $launcherDest)) { throw "missing staged launcher/NuclideLauncher.exe" }

$identityUnderOut = Get-ChildItem -Path $out -Recurse -Filter "identity.pfx" -ErrorAction SilentlyContinue
if ($identityUnderOut) { throw "identity.pfx must not be under output" }

Remove-Item -Recurse -Force $drop, $launcherFake, $out

Write-Host "test-publish-staging-allowlist ok"
