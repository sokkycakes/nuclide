$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function New-PublishFixture {
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

    return [PSCustomObject]@{
        Drop = $drop
        LauncherFake = $launcherFake
        Out = $out
    }
}

function Remove-PublishFixture {
    param($Fixture)
    foreach ($path in @($Fixture.Drop, $Fixture.LauncherFake, $Fixture.Out)) {
        if ($path -and (Test-Path $path)) {
            Remove-Item -Recurse -Force $path
        }
    }
}

# --- SkipSync happy-path allowlist ---
$fx = New-PublishFixture
try {
    & (Join-Path $here "publish-staging.ps1") `
        -DropRoot $fx.Drop `
        -SkipSync `
        -LauncherRoot $fx.LauncherFake `
        -EngineExe (Join-Path $fx.Drop "fteqw64.exe") `
        -OutputDirectory $fx.Out `
        -Version "test.1"

    $manifestPath = Join-Path $fx.Out "manifest.json"
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

    $launcherDest = Join-Path $fx.Out "launcher\NuclideLauncher.exe"
    if (-not (Test-Path $launcherDest)) { throw "missing staged launcher/NuclideLauncher.exe" }

    $identityUnderOut = Get-ChildItem -Path $fx.Out -Recurse -Filter "identity.pfx" -ErrorAction SilentlyContinue
    if ($identityUnderOut) { throw "identity.pfx must not be under output" }
} finally {
    Remove-PublishFixture $fx
}

# --- -EngineExe override uses override bytes, not drop copy ---
$fx = New-PublishFixture
$engineOverride = Join-Path $env:TEMP ("publish-engine-" + [guid]::NewGuid().ToString("n") + ".exe")
try {
    [IO.File]::WriteAllText($engineOverride, "override-engine-bytes")

    & (Join-Path $here "publish-staging.ps1") `
        -DropRoot $fx.Drop `
        -SkipSync `
        -LauncherRoot $fx.LauncherFake `
        -EngineExe $engineOverride `
        -OutputDirectory $fx.Out `
        -Version "test.engine"

    $stagedEngine = Join-Path $fx.Out "fteqw64.exe"
    if (-not (Test-Path $stagedEngine)) { throw "missing staged fteqw64.exe" }
    $stagedHash = (Get-FileHash -Algorithm SHA256 $stagedEngine).Hash
    $overrideHash = (Get-FileHash -Algorithm SHA256 $engineOverride).Hash
    $dropHash = (Get-FileHash -Algorithm SHA256 (Join-Path $fx.Drop "fteqw64.exe")).Hash
    if ($stagedHash -ne $overrideHash) { throw "staged fteqw64.exe does not match -EngineExe override" }
    if ($stagedHash -eq $dropHash) { throw "staged fteqw64.exe incorrectly matches drop copy" }
} finally {
    Remove-PublishFixture $fx
    if (Test-Path $engineOverride) { Remove-Item -Force $engineOverride }
}

# --- -AdditionalFiles must not ship excluded identity.pfx ---
$fx = New-PublishFixture
try {
    & (Join-Path $here "publish-staging.ps1") `
        -DropRoot $fx.Drop `
        -SkipSync `
        -LauncherRoot $fx.LauncherFake `
        -EngineExe (Join-Path $fx.Drop "fteqw64.exe") `
        -OutputDirectory $fx.Out `
        -Version "test.pfx" `
        -AdditionalFiles (Join-Path $fx.Drop "identity.pfx")

    $manifestPath = Join-Path $fx.Out "manifest.json"
    $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
    $paths = @($manifest.files | ForEach-Object { $_.path })
    if ($paths -contains "identity.pfx") { throw "identity.pfx must not be in manifest via AdditionalFiles" }
    $identityUnderOut = Get-ChildItem -Path $fx.Out -Recurse -Filter "identity.pfx" -ErrorAction SilentlyContinue
    if ($identityUnderOut) { throw "identity.pfx must not be under output via AdditionalFiles" }
} finally {
    Remove-PublishFixture $fx
}

# --- -AdditionalFiles under repo root (repoRoot restore) ---
$repoExtra = Join-Path $here "..\README.txt"
if (Test-Path $repoExtra -PathType Leaf) {
    $fx = New-PublishFixture
    try {
        & (Join-Path $here "publish-staging.ps1") `
            -DropRoot $fx.Drop `
            -SkipSync `
            -LauncherRoot $fx.LauncherFake `
            -EngineExe (Join-Path $fx.Drop "fteqw64.exe") `
            -OutputDirectory $fx.Out `
            -Version "test.extra" `
            -AdditionalFiles $repoExtra

        $manifestPath = Join-Path $fx.Out "manifest.json"
        $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
        $paths = @($manifest.files | ForEach-Object { $_.path })
        if ($paths -notcontains "Tools/qml-runtime-launcher/README.txt") {
            throw "AdditionalFiles repo-root extra missing from manifest"
        }
        $stagedExtra = Join-Path $fx.Out "Tools\qml-runtime-launcher\README.txt"
        if (-not (Test-Path $stagedExtra)) { throw "AdditionalFiles repo-root extra not staged" }
    } finally {
        Remove-PublishFixture $fx
    }
}

Write-Host "test-publish-staging-allowlist ok"
