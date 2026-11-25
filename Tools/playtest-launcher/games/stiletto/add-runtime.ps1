# Adds the engine's runtime files (WebCore, its DLLs, ICU data, the VC++
# runtime) to the playtest branch, so the published build can start on a PC
# that has nothing installed. They are gitignored on other branches; this
# force-adds them here only.
#
# Run from the nuclide checkout on your Windows machine, with the files in
# place next to fteqw64.exe as they are for local play:
#   git switch playtest
#   powershell -ExecutionPolicy Bypass -File Tools\playtest-launcher\games\stiletto\add-runtime.ps1
# Then push. Run it again whenever ftewebcore.dll or a plugin changes.
param(
    [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path,
    [switch]$NoCommit
)
$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "playtest" -and -not $branch.StartsWith("playtest/")) {
    throw "Switch to the playtest branch first (on '$branch'). These files should only be committed there."
}

# The game does not run without these.
$required = @(
    "fteplug_webcore_x64.dll",
    "ftewebcore.dll",
    "cairo-2.dll",
    "resources\icudt67l.dat"
)
# Shipped when present (same list the old staging drop used).
$optional = @(
    "fteplug_cef_x64.dll",
    "brotlicommon.dll", "brotlidec.dll", "bz2.dll",
    "d3dcompiler_47.dll", "dxcompiler.dll", "dxil.dll",
    "fontconfig-1.dll", "freetype.dll", "libexpat.dll", "libpng16.dll",
    "pixman-1-0.dll", "vk_swiftshader.dll", "vulkan-1.dll", "z.dll",
    "libogg-0.dll", "libvorbis-0.dll", "vorbisfile.dll"
)

# fteqw64.exe and ftewebcore.dll need the VC++ runtime. Ship it next to the
# exe (Microsoft allows app-local copies) so testers don't have to install it.
$crt = @("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "vcruntime140.dll", "vcruntime140_1.dll")
$redist = $null
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -property installationPath
    if ($vs) {
        $redist = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT" -Directory -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
    }
}
foreach ($name in $crt) {
    if (Test-Path $name) { continue }
    $src = if ($redist) { Join-Path $redist.FullName $name } else { Join-Path "$env:WINDIR\System32" $name }
    if (Test-Path $src) { Copy-Item $src $name; Write-Host "copied $name from $(Split-Path $src)" }
}

$missing = $required | Where-Object { -not (Test-Path $_ -PathType Leaf) }
if ($missing) {
    throw "Missing next to fteqw64.exe: $($missing -join ', '). Copy them from your WebCore build (bin\ and bin\resources\) and run this again."
}

$add = @($required) + ($optional + $crt | Where-Object { Test-Path $_ -PathType Leaf })
git add -f -- $add
Write-Host "Staged:"; $add | ForEach-Object { Write-Host "  $_" }
if ($NoCommit) { return }
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host "Already up to date, nothing to commit."; return }
git commit -m "Playtest: update engine runtime files"
Write-Host "Done. Run 'git push' to publish to testers."
