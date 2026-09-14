param([Parameter(Mandatory=$true)][string]$Compiler,
      [Parameter(Mandatory=$true)][string]$Source,
      [Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference = 'Stop'
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$outputPath = [IO.Path]::GetFullPath($Output)
$temporaryOutput = $outputPath + '.tmp'
New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($outputPath)) | Out-Null
if (Test-Path -LiteralPath $temporaryOutput) { Remove-Item -LiteralPath $temporaryOutput }
Push-Location -LiteralPath ([IO.Path]::GetDirectoryName($sourcePath))
try {
    & $compilerPath -srcfile ([IO.Path]::GetFileName($sourcePath)) -o $temporaryOutput
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryOutput)) { throw "FTEQCC failed; previous compiled output was preserved." }
    Move-Item -LiteralPath $temporaryOutput -Destination $outputPath -Force
    Write-Output "Compiled native MapC: $outputPath"
} finally { Pop-Location }
