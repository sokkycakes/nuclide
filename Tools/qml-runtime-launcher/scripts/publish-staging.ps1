<#
.SYNOPSIS
  Build a copyparty staging drop for the stiletto playtest updater.

.DESCRIPTION
  Writes Tools/qml-runtime-launcher/staging-drop/ containing:
    - manifest.json  (version + file list with sha256 + urls)
    - fteqw64.exe    (the engine binary)
    - fteplug_*.dll  (plugin DLLs, only if changed)
    - resources/icudt67l.dat (WebCore ICU data; required when WebCore is present)
    - base/data/web/ (web UI assets, only if changed)
    - version.txt    (same version string the client stores locally)

  Only files whose SHA256 changed since the previous manifest (if supplied
  via -PreviousManifest) are included.  Unchanged files are skipped so you
  don't re-upload DLLs or web assets every build.

  Upload the contents of staging-drop/ into:
    https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging/

.EXAMPLE
  .\scripts\publish-staging.ps1

.EXAMPLE
  .\scripts\publish-staging.ps1 -PreviousManifest ..\staging-drop\manifest.json

.EXAMPLE
  .\scripts\publish-staging.ps1 -EngineExe ..\..\fteqw64.exe -Version 2026.07.27.1 -AdditionalFiles path\to\extra.dll
#>
[CmdletBinding()]
param(
    [string]$EngineExe,

    [string]$Version,

    [string]$StagingBaseUrl = "https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging",

    [string]$Notes = "",

    [string]$OutputDirectory,

    # Path to previous manifest.json — files whose sha256 match are skipped.
    [string]$PreviousManifest,

    # Extra files to include (resolved relative to repo root).
    [string[]]$AdditionalFiles,

    [string]$DropRoot,

    [switch]$SkipSync,

    [string]$LauncherRoot
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$resolvedRepoRoot = $repoRoot

if ([string]::IsNullOrWhiteSpace($DropRoot)) {
    $resolvedDropRoot = Join-Path (Split-Path $repoRoot -Parent) "stiletto-proto"
} else {
    $resolvedDropRoot = [System.IO.Path]::GetFullPath($DropRoot)
}

if ([string]::IsNullOrWhiteSpace($LauncherRoot)) {
    $resolvedLauncherRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $resolvedLauncherRoot = [System.IO.Path]::GetFullPath($LauncherRoot)
}

. (Join-Path $PSScriptRoot "sync-playtest-drop.ps1")

$repoRoot = $resolvedRepoRoot
$DropRoot = $resolvedDropRoot
$LauncherRoot = $resolvedLauncherRoot

if (-not $SkipSync) {
    & (Join-Path $PSScriptRoot "sync-playtest-drop.ps1") -RepoRoot $repoRoot -DropRoot $DropRoot
}

if (-not (Test-Path (Join-Path $DropRoot "fteqw64.exe") -PathType Leaf)) {
    throw "missing fteqw64.exe in playtest drop at $DropRoot"
}
if (-not (Test-Path (Join-Path $DropRoot "base\progs.dat") -PathType Leaf)) {
    throw "missing base/progs.dat in playtest drop at $DropRoot"
}

function ConvertTo-EncodedRelativePath([string]$Path) {
    return (($Path -split '[\\/]') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join "/"
}

if ([string]::IsNullOrWhiteSpace($EngineExe)) {
    $EngineExe = Join-Path $DropRoot "fteqw64.exe"
} else {
    $EngineExe = (Resolve-Path $EngineExe).Path
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Date).ToString("yyyy.MMdd.HHmm")
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot "staging-drop"
}

$StagingBaseUrl = $StagingBaseUrl.TrimEnd("/")
$StagingBaseUrl = $StagingBaseUrl -replace '/$', ''
$out = [System.IO.Path]::GetFullPath($OutputDirectory)

# Load previous manifest for diffing.
$previousHashes = @{}
if ($PreviousManifest -and (Test-Path $PreviousManifest -PathType Leaf)) {
    try {
        $prev = Get-Content -Raw -Path $PreviousManifest | ConvertFrom-Json
        foreach ($f in $prev.files) {
            $previousHashes[$f.path] = $f.sha256
        }
        Write-Host "Loaded $($previousHashes.Count) previous entries from $PreviousManifest"
    } catch {
        Write-Warning "Could not read previous manifest: $_"
    }
}

# Build list of [@{source; path}] candidates from the playtest drop allowlist.
$candidates = @()

foreach ($name in $script:PlaytestRootFiles) {
    if ($name -eq "fteqw64.exe") {
        continue
    }
    $src = Join-Path $DropRoot $name
    if (Test-Path $src -PathType Leaf) {
        $candidates += [PSCustomObject]@{
            source = $src
            path   = ($name -replace '\\', '/')
        }
    }
}

if (Test-Path $EngineExe -PathType Leaf) {
    $candidates += [PSCustomObject]@{
        source = $EngineExe
        path   = "fteqw64.exe"
    }
}

$icuRelPath = "resources/icudt67l.dat"
$icuSource = Join-Path $DropRoot "resources\icudt67l.dat"
$webcorePresent = (
    (Test-Path (Join-Path $DropRoot "fteplug_webcore_x64.dll") -PathType Leaf) -or
    (Test-Path (Join-Path $DropRoot "ftewebcore.dll") -PathType Leaf)
)
if (Test-Path $icuSource -PathType Leaf) {
    $candidates += [PSCustomObject]@{ source = $icuSource; path = $icuRelPath }
} elseif ($webcorePresent) {
    throw "WebCore is present but $icuRelPath was not found in the playtest drop. HUD map-load will AV in ftewebcore.dll without it. Copy icudt67l.dat from nuclide\Resources\ or the WebCore build bin\resources\."
} else {
    Write-Host "  (not found: $icuRelPath; WebCore not present, skipping)"
}

foreach ($name in $script:PlaytestBaseFiles) {
    $src = Join-Path $DropRoot (Join-Path "base" $name)
    if (Test-Path $src -PathType Leaf) {
        $candidates += [PSCustomObject]@{
            source = $src
            path   = "base/$name"
        }
    }
}

$progsDir = Join-Path $DropRoot "base\progs"
if (Test-Path $progsDir -PathType Container) {
    Get-ChildItem -Path $progsDir -Filter "*.dat" -File | ForEach-Object {
        $rel = $_.FullName.Substring($DropRoot.Length).TrimStart("/", "\")
        $candidates += [PSCustomObject]@{
            source = $_.FullName
            path   = ($rel -replace '\\', '/')
        }
    }
}

$defaultCfgPattern = Join-Path $DropRoot "base\default_*.cfg"
Get-ChildItem -Path $defaultCfgPattern -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($DropRoot.Length).TrimStart("/", "\")
    $candidates += [PSCustomObject]@{
        source = $_.FullName
        path   = ($rel -replace '\\', '/')
    }
}

foreach ($relDir in $script:PlaytestRecursiveDirs) {
    $srcDir = Join-Path $DropRoot $relDir
    if (-not (Test-Path $srcDir -PathType Container)) {
        continue
    }
    Get-ChildItem -Path $srcDir -File -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($DropRoot.Length).TrimStart("/", "\")
        if (Test-PlaytestRecursiveSkip -RelativePath $rel -LeafName $_.Name) {
            return
        }
        if (Test-PlaytestExcludedLeaf -LeafName $_.Name) {
            return
        }
        $candidates += [PSCustomObject]@{
            source = $_.FullName
            path   = ($rel -replace '\\', '/')
        }
    }
}

$launcherExe = Join-Path $LauncherRoot "NuclideLauncher.exe"
if (-not (Test-Path $launcherExe -PathType Leaf)) {
    $launcherExe = Join-Path $LauncherRoot "actual final dist\NuclideLauncher.exe"
}
if (-not (Test-Path $launcherExe -PathType Leaf)) {
    throw "NuclideLauncher.exe not found under $LauncherRoot (also checked actual final dist\NuclideLauncher.exe)."
}

$mainQml = Join-Path $LauncherRoot "app\main.qml"
if (-not (Test-Path $mainQml -PathType Leaf)) {
    throw "app/main.qml not found under $LauncherRoot\app."
}

$candidates += [PSCustomObject]@{
    source = $launcherExe
    path   = "launcher/NuclideLauncher.exe"
}
foreach ($rel in @("app/main.qml", "app/MainForm.ui.qml", "app/config.json")) {
    $candidates += [PSCustomObject]@{
        source = Join-Path $LauncherRoot ($rel -replace "/", "\")
        path   = "launcher/$rel"
    }
}

$mediaSegmentPattern = '(^|[\\/])(runtime|maps|models|sound|textures|music)([\\/]|$)'

foreach ($f in $AdditionalFiles) {
    if ([string]::IsNullOrWhiteSpace($f)) {
        continue
    }
    $resolved = if ([System.IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $repoRoot $f }
    $resolved = (Resolve-Path $resolved -ErrorAction Stop).Path
    $leaf = [System.IO.Path]::GetFileName($resolved)

    if (Test-PlaytestExcludedLeaf -LeafName $leaf) {
        Write-Host "  skipping additional file (excluded): $leaf"
        continue
    }
    if ($leaf.EndsWith('.qc', [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "  skipping additional file (.qc): $leaf"
        continue
    }
    $underRepoRoot = (
        $resolved -eq $repoRoot -or
        $resolved.StartsWith($repoRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $resolved.StartsWith($repoRoot + '/', [StringComparison]::OrdinalIgnoreCase)
    )
    if (-not $underRepoRoot) {
        Write-Host "  skipping additional file (outside repo root): $f"
        continue
    }
    $rel = $resolved.Substring($repoRoot.Length).TrimStart("/", "\")
    if (Test-PlaytestRecursiveSkip -RelativePath $rel -LeafName $leaf) {
        Write-Host "  skipping additional file (recursive skip): $rel"
        continue
    }
    if ($rel -match $mediaSegmentPattern -or $resolved -match $mediaSegmentPattern) {
        Write-Host "  skipping additional file (media path): $rel"
        continue
    }
    $candidates += [PSCustomObject]@{
        source = $resolved
        path   = ($rel -replace '\\', '/')
    }
}

# Filter to only changed files.
$files = @()
$changedCount = 0
$skippedCount = 0
foreach ($c in $candidates) {
    if (-not (Test-Path $c.source -PathType Leaf)) {
        Write-Host "  skipping $($c.path) (source not found)"
        continue
    }
    $sha = (Get-FileHash -Algorithm SHA256 $c.source).Hash.ToLowerInvariant()
    $size = (Get-Item $c.source).Length

    if ($previousHashes.ContainsKey($c.path) -and $previousHashes[$c.path] -eq $sha) {
        Write-Host "  unchanged $($c.path)"
        $skippedCount++
        continue
    }

    $url = $StagingBaseUrl.TrimEnd("/") + "/" + (ConvertTo-EncodedRelativePath $c.path)
    $files += [PSCustomObject]@{
        source = $c.source
        path   = $c.path
        url    = $url
        sha256 = $sha
        size   = $size
    }
    $changedCount++
}
if ($files.Count -eq 0) {
    Write-Host ""
    Write-Host "Nothing changed — no files to publish."
    return
}

# Refresh output dir.
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Path $out | Out-Null

if ([string]::IsNullOrWhiteSpace($Notes)) {
    $Notes = "Nightly engine build $Version"
}

$manifest = [ordered]@{
    version = $Version
    notes   = $Notes
    files   = $files | ForEach-Object {
        [ordered]@{
            path   = $_.path
            url    = $_.url
            sha256 = $_.sha256
            size   = $_.size
        }
    }
}

$manifestPath = Join-Path $out "manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -Path $manifestPath

# Copy files to staging drop, preserving directory structure.
foreach ($f in $files) {
    $dest = Join-Path $out $f.path
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    Copy-Item -Force $f.source $dest
}

Set-Content -Encoding ascii -Path (Join-Path $out "version.txt") -Value $Version

Write-Host ""
Write-Host "Staging drop ready: $out"
Write-Host "  version:   $Version"
Write-Host "  files:     $changedCount changed, $skippedCount unchanged (skipped)"
Write-Host ""
Write-Host "Upload ALL files in that folder to:"
Write-Host "  $StagingBaseUrl/"
Write-Host ""
Write-Host "Client config already points at:"
Write-Host "  $StagingBaseUrl/manifest.json"
