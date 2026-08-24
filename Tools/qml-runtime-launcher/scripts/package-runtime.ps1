[CmdletBinding()]
param(
    # Optional offline/CI override. This must be the bin directory containing
    # qml.exe and windeployqt.exe.
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$QtBin,

    [ValidateSet("6.8.0")]
    [string]$QtVersion = "6.8.0",

    [ValidateSet("msvc2022_64")]
    [string]$QtKit = "msvc2022_64",

    [string]$QtCacheDirectory,

    [string]$BuildDirectory,

    [string]$OutputDirectory,

    [switch]$RefreshQt
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($QtCacheDirectory)) {
    $QtCacheDirectory = Join-Path $PSScriptRoot "..\.qt-cache"
}
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $PSScriptRoot "..\build"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $PSScriptRoot "..\dist"
}

$QtRepository = "https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt6_680/qt6_680/qt.qt6.680.win64_msvc2022_64"
$QtArchivePrefix = "6.8.0-0-202410030750"
$SevenZipUrl = "https://www.7-zip.org/a/7zr.exe"
$QtArchives = @(
    "qtbase-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-X86_64.7z",
    "qtdeclarative-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-X86_64.7z",
    "qttools-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-X86_64.7z",
    "qtsvg-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-X86_64.7z",
    "d3dcompiler_47-x64.7z",
    "opengl32sw-64-mesa_11_2_2-signed_sha256.7z"
)

function Invoke-External([string]$FileName, [string[]]$ArgumentList) {
    if ([string]::IsNullOrWhiteSpace($FileName)) {
        throw "Cannot invoke an external command with an empty executable path"
    }

    & $FileName @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$FileName failed with exit code $LASTEXITCODE"
    }
}

function Save-Download([string]$Uri, [string]$Destination) {
    if (Test-Path $Destination -PathType Leaf) {
        return
    }

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temporary = "$Destination.download"
    Remove-Item -Force -ErrorAction SilentlyContinue $temporary

    Write-Host "Downloading $Uri"
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $temporary -UseBasicParsing
        Move-Item -Force $temporary $Destination
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $temporary
    }
}

function Test-QtArchive([string]$ArchivePath, [string]$Sha1Path) {
    $publishedText = (Get-Content -Raw $Sha1Path).Trim()
    $match = [regex]::Match($publishedText, "(?i)[0-9a-f]{40}")
    if (-not $match.Success) {
        throw "Qt's checksum file has no valid SHA-1 digest: $Sha1Path"
    }

    $expected = $match.Value.ToUpperInvariant()
    $actual = (Get-FileHash -Algorithm SHA1 $ArchivePath).Hash.ToUpperInvariant()
    if ($actual -ne $expected) {
        throw "Checksum mismatch for $ArchivePath (expected $expected, got $actual)"
    }
}

function Get-DownloadedQtBin {
    param(
        [string]$CacheDirectory,
        [string]$Version,
        [string]$Kit,
        [bool]$Refresh
    )

    $cacheRoot = [System.IO.Path]::GetFullPath($CacheDirectory)
    $kitRoot = Join-Path $cacheRoot (Join-Path $Version $Kit)
    $binDirectory = Join-Path $kitRoot "bin"
    $qmlRuntime = Join-Path $binDirectory "qml.exe"
    $deploymentTool = Join-Path $binDirectory "windeployqt.exe"

    if ($Refresh) {
        if (Test-Path $kitRoot) {
            Remove-Item -Recurse -Force $kitRoot
        }
        $archiveDirectory = Join-Path $cacheRoot "archives"
        if (Test-Path $archiveDirectory) {
            Remove-Item -Recurse -Force $archiveDirectory
        }
    }

    if ((Test-Path $qmlRuntime -PathType Leaf) -and
        (Test-Path $deploymentTool -PathType Leaf)) {
        Write-Host "Using cached Qt $Version ($Kit): $binDirectory"
        return $binDirectory
    }

    New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
    $toolsDirectory = Join-Path $cacheRoot "tools"
    $sevenZip = Join-Path $toolsDirectory "7zr.exe"
    Save-Download -Uri $SevenZipUrl -Destination $sevenZip

    $archiveDirectory = Join-Path $cacheRoot "archives"
    New-Item -ItemType Directory -Force -Path $archiveDirectory | Out-Null

    foreach ($archiveName in $QtArchives) {
        $remoteName = "$QtArchivePrefix$archiveName"
        $archivePath = Join-Path $archiveDirectory $remoteName
        $sha1Path = "$archivePath.sha1"
        $archiveUrl = "$QtRepository/$remoteName"

        Save-Download -Uri $archiveUrl -Destination $archivePath
        Save-Download -Uri "$archiveUrl.sha1" -Destination $sha1Path

        try {
            Test-QtArchive -ArchivePath $archivePath -Sha1Path $sha1Path
        } catch {
            Remove-Item -Force -ErrorAction SilentlyContinue $archivePath
            Remove-Item -Force -ErrorAction SilentlyContinue $sha1Path
            throw
        }
    }

    Write-Host "Extracting Qt $Version ($Kit)..."
    foreach ($archiveName in $QtArchives) {
        $archivePath = Join-Path $archiveDirectory "$QtArchivePrefix$archiveName"
        Invoke-External $sevenZip @("x", "-y", "-o$cacheRoot", $archivePath)
    }

    if (-not (Test-Path $qmlRuntime -PathType Leaf) -or
        -not (Test-Path $deploymentTool -PathType Leaf)) {
        throw "Qt extraction completed but qml.exe or windeployqt.exe is missing from $binDirectory"
    }

    return $binDirectory
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildPath = [System.IO.Path]::GetFullPath($BuildDirectory)
$launcher = Join-Path $buildPath "NuclideLauncher.exe"

if (-not (Test-Path $launcher -PathType Leaf)) {
    throw "Build the launcher first; missing $launcher"
}

if ([string]::IsNullOrWhiteSpace($QtBin)) {
    $qtBinPath = Get-DownloadedQtBin -CacheDirectory $QtCacheDirectory `
        -Version $QtVersion -Kit $QtKit -Refresh $RefreshQt.IsPresent
} else {
    $qtBinPath = (Resolve-Path $QtBin).Path
    Write-Host "Using supplied Qt kit: $qtBinPath"
}

$windeployqt = Join-Path $qtBinPath "windeployqt.exe"
$qmlRuntime = Join-Path $qtBinPath "qml.exe"
if (-not (Test-Path $windeployqt -PathType Leaf)) {
    throw "windeployqt.exe was not found in $qtBinPath"
}
if (-not (Test-Path $qmlRuntime -PathType Leaf)) {
    throw "qml.exe was not found in $qtBinPath. Supply a complete Qt QML tooling kit."
}

$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path $outputPath) {
    Remove-Item -Recurse -Force $outputPath
}
New-Item -ItemType Directory -Path $outputPath | Out-Null
$runtimePath = Join-Path $outputPath "runtime"
New-Item -ItemType Directory -Path $runtimePath | Out-Null

Copy-Item $launcher (Join-Path $outputPath "NuclideLauncher.exe")
Copy-Item (Join-Path $projectRoot "runtime.qt.conf") (Join-Path $runtimePath "qt.conf")
Copy-Item -Recurse (Join-Path $projectRoot "app") (Join-Path $outputPath "app")
Copy-Item $qmlRuntime (Join-Path $runtimePath "qml.exe")

# Run deployment after qml.exe has been copied so its dependent DLLs, platform
# plugin, QML imports, and matching MSVC runtime are all written below runtime/.
Invoke-External $windeployqt @(
    "--release",
    "--compiler-runtime",
    "--qmldir", (Join-Path $projectRoot "app"),
    "--dir", $runtimePath,
    (Join-Path $runtimePath "qml.exe")
)

$compilerRuntime = Get-ChildItem -Path $runtimePath -Filter "vcruntime*.dll" -File -ErrorAction SilentlyContinue
if ($null -eq $compilerRuntime) {
    Write-Warning @"
windeployqt did not copy the Microsoft Visual C++ runtime. The package works on
machines with the current x64 Visual C++ Redistributable installed, but is not
yet guaranteed to run on a clean Windows machine.
"@
}

# MainForm.ui.qml imports QtQuick.Studio.DesignEffects.
# Ship pure-QML stubs (no DS plugin DLL) so runtime qml.exe can load the form.
# Design Studio itself still uses its real module from the DS kit.
$designEffectsStub = Join-Path $projectRoot "app\imports\QtQuick\Studio\DesignEffects"
$designEffectsDest = Join-Path $runtimePath "qml\QtQuick\Studio\DesignEffects"
if (Test-Path $designEffectsStub -PathType Container) {
    New-Item -ItemType Directory -Force -Path (Split-Path $designEffectsDest) | Out-Null
    if (Test-Path $designEffectsDest) {
        Remove-Item -Recurse -Force $designEffectsDest
    }
    Copy-Item -Recurse -Force $designEffectsStub $designEffectsDest
    Write-Host "Bundled DesignEffects QML stubs for runtime"
} else {
    Write-Warning "Missing DesignEffects stubs at $designEffectsStub"
}

Write-Host "Packaged launcher: $outputPath\NuclideLauncher.exe"
Write-Host "Qt runtime:         $runtimePath"
