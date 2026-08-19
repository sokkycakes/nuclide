<#
.SYNOPSIS
  Generate and upload the Nuclide updater staging drop to copyparty.
#>
[CmdletBinding()]
param(
    [string]$EngineExe,
    [string]$Version,
    [string]$Notes = "",
    [string]$OutputDirectory,
    [string]$PreviousManifest,
    [string[]]$AdditionalFiles,
    [string]$StagingBaseUrl = "https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging",
    [string]$DropRoot,
    [switch]$SkipSync,
    [string]$LauncherRoot
)

$CopypartyCredential = $env:COPYPARTY_PW
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CopypartyCredential) -or $CopypartyCredential -eq "REPLACE_ME") {
    throw "Set env COPYPARTY_PW before publishing."
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "staging-drop"
}

$publishArgs = @{
    OutputDirectory = $OutputDirectory
    StagingBaseUrl  = $StagingBaseUrl
}
foreach ($name in @("EngineExe", "Version", "Notes", "PreviousManifest", "AdditionalFiles", "DropRoot", "SkipSync", "LauncherRoot")) {
    $value = Get-Variable -Name $name -ValueOnly
    if ($null -ne $value -and -not ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
        $publishArgs[$name] = $value
    }
}

$out = [IO.Path]::GetFullPath($OutputDirectory)
$manifestPath = Join-Path $out "manifest.json"
$manifestExisted = $false
$manifestWriteTimeUtc = $null
if (Test-Path $manifestPath -PathType Leaf) {
    $manifestExisted = $true
    $manifestWriteTimeUtc = (Get-Item $manifestPath).LastWriteTimeUtc
}

& (Join-Path $PSScriptRoot "publish-staging.ps1") @publishArgs

if (-not (Test-Path $manifestPath -PathType Leaf)) {
    Write-Host "Nothing changed — generate returned without writing a drop."
    return
}
if ($manifestExisted) {
    $newWriteTimeUtc = (Get-Item $manifestPath).LastWriteTimeUtc
    if ($newWriteTimeUtc -eq $manifestWriteTimeUtc) {
        Write-Host "Nothing changed — skipping upload."
        return
    }
}

function ConvertTo-EncodedRelativePath([string]$Path) {
    return (($Path -split '[\\/]') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join "/"
}

function Send-CopypartyFile([IO.FileInfo]$File) {
    $relative = $File.FullName.Substring($out.Length).TrimStart("\", "/")
    $url = $StagingBaseUrl.TrimEnd("/") + "/" + (ConvertTo-EncodedRelativePath $relative)
    Write-Host "  uploading $relative"

    $request = [Net.HttpWebRequest]::CreateHttp($url)
    $request.Method = "PUT"
    $request.Headers.Add("PW", $CopypartyCredential)
    $request.Headers.Add("Replace", "1")
    $request.ContentType = "application/octet-stream"
    $request.ContentLength = $File.Length
    $request.AllowWriteStreamBuffering = $false

    $source = $File.OpenRead()
    try {
        $target = $request.GetRequestStream()
        try { $source.CopyTo($target) } finally { $target.Dispose() }
    } finally {
        $source.Dispose()
    }

    try {
        $response = [Net.HttpWebResponse]$request.GetResponse()
        try {
            if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
                throw "HTTP $([int]$response.StatusCode) $($response.StatusDescription)"
            }
        } finally { $response.Dispose() }
    } catch [Net.WebException] {
        $status = if ($_.Exception.Response) {
            $r = [Net.HttpWebResponse]$_.Exception.Response
            try { "HTTP $([int]$r.StatusCode) $($r.StatusDescription)" } finally { $r.Dispose() }
        } else {
            $_.Exception.Message
        }
        throw "Upload failed for '$relative': $status"
    }
}

$payloadFiles = Get-ChildItem -File -Recurse $out | Where-Object { $_.FullName -ne $manifestPath }
foreach ($file in $payloadFiles) { Send-CopypartyFile $file }
Send-CopypartyFile (Get-Item $manifestPath)

Write-Host ""
Write-Host "Published staging version to:"
Write-Host "  $($StagingBaseUrl.TrimEnd('/') + '/manifest.json')"
