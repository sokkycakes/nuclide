$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "sync-playtest-drop.ps1")

$repo = Join-Path $env:TEMP ("sync-repo-" + [guid]::NewGuid().ToString("n"))
$drop = Join-Path $env:TEMP ("sync-drop-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path (Join-Path $repo "base\progs") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "base\decls") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "base\data\web\hud") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "Resources") | Out-Null
New-Item -ItemType Directory -Path $drop | Out-Null
[IO.File]::WriteAllText((Join-Path $repo "fteqw64.exe"), "engine-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\progs.dat"), "progs-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\progs\duel.dat"), "duel-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\decls\hero.def"), "def-bytes")
New-Item -ItemType Directory -Path (Join-Path $repo "base\decls\logs") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "base\decls\autosave") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "base\decls\autosaves") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "base\decls\mapsrc") | Out-Null
[IO.File]::WriteAllText((Join-Path $repo "base\decls\hero.qc"), "qc-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\decls\logs\x.txt"), "log-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\decls\autosave\x.txt"), "autosave-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\decls\autosaves\x.txt"), "autosaves-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\decls\mapsrc\x.txt"), "mapsrc-bytes")
[IO.File]::WriteAllText((Join-Path $repo "base\data\web\hud\index.html"), "hud")
[IO.File]::WriteAllText((Join-Path $repo "base\autoexec.cfg"), "ae")
[IO.File]::WriteAllText((Join-Path $repo "identity.pfx"), "secret")
[IO.File]::WriteAllText((Join-Path $repo "base\fte.cfg"), "user")
[IO.File]::WriteAllText((Join-Path $repo "fteplug_webcore_x64.dll"), "plug")
[IO.File]::WriteAllText((Join-Path $repo "Resources\icudt67l.dat"), "icu")

Copy-PlaytestAllowlist -RepoRoot $repo -DropRoot $drop

function Assert-File($rel, $expect) {
    $p = Join-Path $drop $rel
    if (-not (Test-Path $p)) { throw "missing $rel" }
    $got = [IO.File]::ReadAllText($p)
    if ($got -ne $expect) { throw "$rel content mismatch" }
}

Assert-File "fteqw64.exe" "engine-bytes"
Assert-File "stiletto.exe" "engine-bytes"
Assert-File "base\progs.dat" "progs-bytes"
Assert-File "base\progs\duel.dat" "duel-bytes"
Assert-File "base\decls\hero.def" "def-bytes"
Assert-File "base\data\web\hud\index.html" "hud"
Assert-File "base\autoexec.cfg" "ae"
Assert-File "fteplug_webcore_x64.dll" "plug"
Assert-File "resources\icudt67l.dat" "icu"
if (Test-Path (Join-Path $drop "identity.pfx")) { throw "identity.pfx must not sync" }
if (Test-Path (Join-Path $drop "base\fte.cfg")) { throw "fte.cfg must not sync" }
if (Test-Path (Join-Path $drop "base\decls\hero.qc")) { throw "hero.qc must not sync" }
if (Test-Path (Join-Path $drop "base\decls\logs\x.txt")) { throw "logs/x.txt must not sync" }
if (Test-Path (Join-Path $drop "base\decls\autosave\x.txt")) { throw "autosave/x.txt must not sync" }
if (Test-Path (Join-Path $drop "base\decls\autosaves\x.txt")) { throw "autosaves/x.txt must not sync" }
if (Test-Path (Join-Path $drop "base\decls\mapsrc\x.txt")) { throw "mapsrc/x.txt must not sync" }

$engineHash = (Get-FileHash (Join-Path $drop "fteqw64.exe") -Algorithm SHA256).Hash
$aliasHash = (Get-FileHash (Join-Path $drop "stiletto.exe") -Algorithm SHA256).Hash
if ($engineHash -ne $aliasHash) { throw "stiletto.exe must match fteqw64.exe" }

Remove-Item -Recurse -Force $repo, $drop

# missing progs.dat must throw
$repo2 = Join-Path $env:TEMP ("sync-repo-" + [guid]::NewGuid().ToString("n"))
$drop2 = Join-Path $env:TEMP ("sync-drop-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path $repo2 | Out-Null
New-Item -ItemType Directory -Path $drop2 | Out-Null
[IO.File]::WriteAllText((Join-Path $repo2 "fteqw64.exe"), "engine-bytes")
$threw = $false
try {
    Copy-PlaytestAllowlist -RepoRoot $repo2 -DropRoot $drop2
} catch {
    if ($_.Exception.Message -notmatch "missing base/progs.dat") { throw }
    $threw = $true
}
if (-not $threw) { throw "expected throw for missing base/progs.dat" }
Remove-Item -Recurse -Force $repo2, $drop2

Write-Host "test-sync-playtest-drop ok"
