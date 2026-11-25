# Copies the TrenchBroom game profiles into TrenchBroom's user games folder.
#
#   powershell -ExecutionPolicy Bypass -File install.ps1 [-Dest <games folder>]
#
# The default folder is %APPDATA%\TrenchBroom\games. Profiles already there
# are replaced, except your CompilationProfiles.cfg and GameEngineProfiles.cfg,
# which TrenchBroom rewrites with your own paths: those are only copied the
# first time.
param([string]$Dest = (Join-Path $env:APPDATA 'TrenchBroom\games'))
$ErrorActionPreference = 'Stop'
$games = Join-Path $PSScriptRoot 'games'
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
foreach ($game in Get-ChildItem -LiteralPath $games -Directory) {
    $target = Join-Path $Dest $game.Name
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $game.FullName -File) {
        $out = Join-Path $target $file.Name
        if ($file.Name -in @('CompilationProfiles.cfg', 'GameEngineProfiles.cfg') -and (Test-Path -LiteralPath $out)) {
            continue
        }
        Copy-Item -LiteralPath $file.FullName -Destination $out -Force
    }
    Write-Output "installed $($game.Name)"
}
Write-Output "into $Dest. Restart TrenchBroom, then set each game's path in Preferences."
