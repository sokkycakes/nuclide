# Convert reference.obj -> base/models/v_reference.iqm.
# NO axis conversion: the OBJ is authored directly in Quake orientation,
# so this is the known-good reference for what "correct" looks like.
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$IqmTool = Join-Path $PSScriptRoot "iqmtool64.exe"
$Src = Join-Path $Root "..\New folder\assets\modelsrc\reference.iqe"
$Dst = Join-Path $Root "base\models\v_reference.iqm"

if (-not (Test-Path -LiteralPath $IqmTool)) { throw "Missing $IqmTool" }
if (-not (Test-Path -LiteralPath $Src)) { throw "Missing $Src" }

& $IqmTool -v $Dst $Src
if ($LASTEXITCODE -ne 0) { throw "iqmtool failed with exit code $LASTEXITCODE" }

$fi = Get-Item -LiteralPath $Dst
Write-Host ("Wrote {0} ({1} bytes)" -f $fi.FullName, $fi.Length)
