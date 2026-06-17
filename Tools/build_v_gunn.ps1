# Convert gunn.glb -> base/models/v_gunn.iqm with a 90-degree yaw so the
# model's forward (Blender -Y) aligns with Quake +X. If it ends up facing the
# opposite way (forward to the right / muzzle toward player), change 90 -> 270.
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$IqmTool = Join-Path $PSScriptRoot "iqmtool64.exe"
$Src = Join-Path $Root "..\New folder\assets\modelsrc\gunn.glb"
$Dst = Join-Path $Root "base\models\v_gunn.iqm"

if (-not (Test-Path -LiteralPath $IqmTool)) { throw "Missing $IqmTool" }
if (-not (Test-Path -LiteralPath $Src)) { throw "Missing $Src" }

& $IqmTool --rotate 0 0 90 -v $Dst $Src
if ($LASTEXITCODE -ne 0) { throw "iqmtool failed with exit code $LASTEXITCODE" }

$fi = Get-Item -LiteralPath $Dst
Write-Host ("Wrote {0} ({1} bytes)" -f $fi.FullName, $fi.Length)
