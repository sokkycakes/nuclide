param([switch]$PrivateCandidates, [int]$TimeoutSeconds = 75)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path $PSScriptRoot -Parent
$gameExe = Join-Path $gameRoot 'fteqw64.exe'
$runId = 'join_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$runRoot = Join-Path $gameRoot "_lobby_diag\$runId"
$testProcesses = @()
New-Item -ItemType Directory -Force -Path "$runRoot\host", "$runRoot\client" | Out-Null

function Start-TestClient([string]$Role, [string[]]$Action) {
    $arguments = @('-basedir', ('"' + $gameRoot + '"'), '-window','-width','320','-height','240',
        '-nosound','-nojoy','-debugstdout','-condebug','+set','log_name',"${runId}_${Role}",
        '+set','developer','1','+set','net_ice_debug','1','+set','cfg_save_auto','0',
        '+name',"LobbyTest_${Role}")
    if ($PrivateCandidates) {
        $arguments += @('+set','net_ice_allowmdns','0','+set','net_ice_exchangeprivateips','1')
    }
    $arguments += $Action
    $process = Start-Process -FilePath $gameExe -ArgumentList $arguments -WorkingDirectory "$runRoot\$Role" `
        -WindowStyle Hidden -RedirectStandardOutput "$runRoot\$Role\stdout.txt" `
        -RedirectStandardError "$runRoot\$Role\stderr.txt" -PassThru
    $script:testProcesses += $process
    return $process
}

function Read-Snapshot([string]$Role) {
    $path = "$runRoot\$Role\lobby_snapshot.json"
    if (Test-Path -LiteralPath $path) {
        try { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

try {
    $hostProcess = Start-TestClient 'host' @('+lobby_create','online')
    $deadline = (Get-Date).AddSeconds(50)
    do {
        Start-Sleep -Milliseconds 250
        $hostState = Read-Snapshot 'host'
        if ($hostProcess.HasExited) { throw 'Host exited during startup.' }
    } until (($hostState -and $hostState.phase -eq 'WAITING') -or (Get-Date) -ge $deadline)
    if (!$hostState -or $hostState.phase -ne 'WAITING') { throw 'Host did not register with the broker.' }
    Write-Output 'Host registered; joining its room code with a second client.'
    $clientProcess = Start-TestClient 'client' @('+lobby_join', $hostState.roomCode)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 250
        $clientState = Read-Snapshot 'client'
        if ($clientProcess.HasExited) { throw 'Client exited during join.' }
    } until (($clientState -and $clientState.localSeat -ge 0) -or (Get-Date) -ge $deadline)
    if (!$clientState -or $clientState.localSeat -lt 0) {
        throw ('Join failed: ' + $clientState.status)
    }
    Start-Sleep -Seconds 12
    $clientState = Read-Snapshot 'client'
    $hostState = Read-Snapshot 'host'
    if (!$clientState.active -or $clientState.localSeat -lt 0 -or @($hostState.players).Count -ne 2 -or @($clientState.players).Count -ne 2) {
        throw 'Lobby membership failed the heartbeat stability check.'
    }
    foreach ($state in @($hostState, $clientState)) {
        if (@($state.players | Where-Object name -EQ 'LobbyTest_host').Count -ne 1 -or @($state.players | Where-Object name -EQ 'LobbyTest_client').Count -ne 1) {
            throw 'A player name changed during lobby initialization or synchronization.'
        }
    }
    Write-Output "PASS: online room-code join, two players on both clients, stable heartbeat. Logs: $runRoot"
} finally {
    foreach ($process in $testProcesses) {
        $process.Refresh()
        if (!$process.HasExited -and $process.Path -eq $gameExe) { Stop-Process -Id $process.Id }
    }
    foreach ($role in @('host','client')) {
        $log = Join-Path $gameRoot "base\${runId}_${role}.log"
        if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log -Destination "$runRoot\$role\console.log" }
    }
    Write-Output "Test artifacts: $runRoot"
}
