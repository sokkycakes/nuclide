param(
    [string]$RepoRoot,
    [string]$DropRoot
)

$ErrorActionPreference = "Stop"

$script:PlaytestExcludeLeafs = @(
    "identity.pfx",
    "conhistory.txt",
    "installed.lst",
    "lobby_snapshot.json",
    "fte.cfg"
)

$script:PlaytestRootFiles = @(
    "fteqw64.exe",
    "fteplug_webcore_x64.dll",
    "ftewebcore.dll",
    "fteplug_cef_x64.dll",
    "brotlicommon.dll",
    "brotlidec.dll",
    "bz2.dll",
    "cairo-2.dll",
    "d3dcompiler_47.dll",
    "dxcompiler.dll",
    "dxil.dll",
    "fontconfig-1.dll",
    "freetype.dll",
    "libexpat.dll",
    "libpng16.dll",
    "pixman-1-0.dll",
    "vk_swiftshader.dll",
    "vorbisfile.dll",
    "vulkan-1.dll",
    "z.dll"
)

$script:PlaytestBaseFiles = @(
    "progs.dat",
    "csprogs.dat",
    "menu.dat",
    "hud.dat",
    "autoexec.cfg",
    "quake.rc",
    "liblist.gam",
    "motd.txt",
    "mapcycle.txt"
)

$script:PlaytestRecursiveDirs = @(
    "base\decls",
    "base\data\web",
    "base\progs"
)

function Test-PlaytestExcludedLeaf {
    param([string]$LeafName)
    return $script:PlaytestExcludeLeafs -contains $LeafName
}

function Copy-PlaytestAllowlistFile {
    param(
        [string]$SourcePath,
        [string]$DestPath
    )
    $leaf = [System.IO.Path]::GetFileName($SourcePath)
    if (Test-PlaytestExcludedLeaf -LeafName $leaf) {
        return
    }
    $destDir = Split-Path -Parent $DestPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    Copy-Item -Force -LiteralPath $SourcePath -Destination $DestPath
}

function Copy-PlaytestAllowlist {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$DropRoot
    )

    $RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
    $DropRoot = [System.IO.Path]::GetFullPath($DropRoot)

    if (-not (Test-Path (Join-Path $RepoRoot "fteqw64.exe"))) {
        throw "missing fteqw64.exe"
    }
    if (-not (Test-Path (Join-Path $RepoRoot "base\progs.dat"))) {
        throw "missing base/progs.dat"
    }

    if (-not (Test-Path $DropRoot)) {
        New-Item -ItemType Directory -Force -Path $DropRoot | Out-Null
    }

    foreach ($name in $script:PlaytestRootFiles) {
        $src = Join-Path $RepoRoot $name
        if (Test-Path $src -PathType Leaf) {
            Copy-PlaytestAllowlistFile -SourcePath $src -DestPath (Join-Path $DropRoot $name)
        }
    }

    foreach ($name in $script:PlaytestBaseFiles) {
        $src = Join-Path $RepoRoot (Join-Path "base" $name)
        if (Test-Path $src -PathType Leaf) {
            $rel = Join-Path "base" $name
            Copy-PlaytestAllowlistFile -SourcePath $src -DestPath (Join-Path $DropRoot $rel)
        }
    }

    $defaultCfgPattern = Join-Path $RepoRoot "base\default_*.cfg"
    Get-ChildItem -Path $defaultCfgPattern -File -ErrorAction SilentlyContinue | ForEach-Object {
        $rel = "base\" + $_.Name
        Copy-PlaytestAllowlistFile -SourcePath $_.FullName -DestPath (Join-Path $DropRoot $rel)
    }

    foreach ($relDir in $script:PlaytestRecursiveDirs) {
        $srcDir = Join-Path $RepoRoot $relDir
        if (-not (Test-Path $srcDir -PathType Container)) {
            continue
        }
        Get-ChildItem -Path $srcDir -File -Recurse | ForEach-Object {
            $parent = $_.DirectoryName
            if ($parent -match '(^|[\\/])autosave([\\/]|$)') {
                return
            }
            $rel = $_.FullName.Substring($RepoRoot.Length).TrimStart("\", "/")
            if (Test-PlaytestExcludedLeaf -LeafName $_.Name) {
                return
            }
            $dest = Join-Path $DropRoot $rel
            $destParent = Split-Path -Parent $dest
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Force -Path $destParent | Out-Null
            }
            Copy-Item -Force -LiteralPath $_.FullName -Destination $dest
        }
    }

    $icuDest = Join-Path $DropRoot "resources\icudt67l.dat"
    $icuSources = @(
        (Join-Path $RepoRoot "Resources\icudt67l.dat"),
        (Join-Path $RepoRoot "resources\icudt67l.dat")
    )
    foreach ($icuSrc in $icuSources) {
        if (Test-Path $icuSrc -PathType Leaf) {
            $icuParent = Split-Path -Parent $icuDest
            if (-not (Test-Path $icuParent)) {
                New-Item -ItemType Directory -Force -Path $icuParent | Out-Null
            }
            Copy-Item -Force -LiteralPath $icuSrc -Destination $icuDest
            break
        }
    }

    $webcore = (Test-Path (Join-Path $RepoRoot "fteplug_webcore_x64.dll")) -or
              (Test-Path (Join-Path $RepoRoot "ftewebcore.dll")) -or
              (Test-Path (Join-Path $DropRoot "fteplug_webcore_x64.dll")) -or
              (Test-Path (Join-Path $DropRoot "ftewebcore.dll"))
    if ($webcore -and -not (Test-Path (Join-Path $DropRoot "resources\icudt67l.dat"))) {
        throw "WebCore is present but resources/icudt67l.dat was not found..."
    }

    $engineSrc = Join-Path $RepoRoot "fteqw64.exe"
    Copy-Item -Force -LiteralPath $engineSrc -Destination (Join-Path $DropRoot "stiletto.exe")
}

if ($MyInvocation.InvocationName -ne '.') {
  if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
  } else {
    $RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
  }

  if ([string]::IsNullOrWhiteSpace($DropRoot)) {
    $DropRoot = Join-Path (Split-Path $RepoRoot -Parent) "stiletto-proto"
  } else {
    $DropRoot = [System.IO.Path]::GetFullPath($DropRoot)
  }

  Copy-PlaytestAllowlist -RepoRoot $RepoRoot -DropRoot $DropRoot
}
