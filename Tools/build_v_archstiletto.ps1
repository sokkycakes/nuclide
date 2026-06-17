# Convert v_archstiletto.gltf -> base/models/v_archstiletto.iqm with Quake orientation.
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$IqmTool = Join-Path $PSScriptRoot "iqmtool64.exe"
$Src = Join-Path $Root "..\New folder\assets\modelsrc\v_archstiletto.gltf"
$Dst = Join-Path $Root "base\models\v_archstiletto.iqm"

if (-not (Test-Path -LiteralPath $IqmTool)) { throw "Missing $IqmTool" }
if (-not (Test-Path -LiteralPath $Src)) { throw "Missing $Src" }

& $IqmTool --yup -v $Dst $Src
if ($LASTEXITCODE -ne 0) { throw "iqmtool failed with exit code $LASTEXITCODE" }

$fi = Get-Item -LiteralPath $Dst
Write-Host ("Wrote {0} ({1} bytes)" -f $fi.FullName, $fi.Length)
