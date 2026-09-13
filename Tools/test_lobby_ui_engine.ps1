param([switch]$SkipStart)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path $PSScriptRoot -Parent
$gameExe = Join-Path $gameRoot 'fteqw64.exe'
$runId = 'lobby_ui_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$runRoot = Join-Path $gameRoot "_lobby_diag/figma-port/$runId"
$testProcesses = @()
$testConfigs = @()
$countdownSeen = @{}
$cancelSeen = @{}
$observedPhases = @{}
$port = 27671
$shot = "${runId}.png"
function Start-LobbyClient([string]$role, [string[]]$commands) {
    $dir = Join-Path $runRoot $role
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $configName = "_${runId}_${role}.cfg"
    $config = Join-Path $gameRoot "base/$configName"
    $setup = @('set cfg_save_auto 0','set ruleset_allow_in 1','set webcore_menumap ""',"name UI_$role",'set developer 1')
    $setup += $commands
    $setup += @('in 10 lobby_chat_snapshot','in 10 lobby_snapshot','in 11.5 echo LOBBY_UI_PRESTART_CHECK','in 25 g_gametype','in 25 timelimit','in 25 fraglimit','in 25 status','in 28 quit')
    $setup | Set-Content -LiteralPath $config -Encoding ascii
    $script:testConfigs += $config
    $arguments = @('-basedir',('"'+$gameRoot+'"'),'+game','base','-window','-width','960','-height','720','-nosound','-nojoy','-noupdates','-debugstdout','-condebug',
        '+set','log_name',"${runId}_${role}",'+set','cfg_save_auto','0','+exec',$configName)
    $process = Start-Process -FilePath $gameExe -ArgumentList $arguments -WorkingDirectory $dir -WindowStyle Hidden `
        -RedirectStandardOutput "$dir/stdout.txt" -RedirectStandardError "$dir/stderr.txt" -PassThru
    $script:testProcesses += $process
    return $process
}
function Hex-Message([string]$text) { return -join ([Text.Encoding]::UTF8.GetBytes($text) | ForEach-Object { $_.ToString('x2') }) }
try {
    $hostCommands = @("set lobby_port $port",'set lobby_readytime 10','lobby_create lan','in 1 menu_webcore_lobby',
        'in 2 lobby_set ruleset TEAMDM','in 2.2 lobby_limits 12 25',
        ('in 6 lobby_chat_hex '+(Hex-Message 'host says hello')), 'in 6.5 lobby_ready', 'in 11 lobby_cancel', "in 9 screenshot $shot")
    if (!$SkipStart) { $hostCommands += 'in 13 lobby_start' }
    $null = Start-LobbyClient 'host' $hostCommands
    $deadline = (Get-Date).AddSeconds(12)
    while (!(Test-Path -LiteralPath "$runRoot/host/lobby_snapshot.json")) {
        if ((Get-Date) -gt $deadline) { throw 'Host lobby did not start.' }
        Start-Sleep -Milliseconds 200
    }
    foreach ($role in @('guest1','guest2')) {
        $null = Start-LobbyClient $role @("lobby_join 127.0.0.1:$port",'in 1 menu_webcore_lobby',
            ('in 4 lobby_chat_hex '+(Hex-Message "$role says hello")), 'in 4.8 lobby_ready')
        Start-Sleep -Milliseconds 600
    }
    $deadline = (Get-Date).AddSeconds(38)
    do {
        Start-Sleep -Milliseconds 250
        foreach ($role in @('host','guest1','guest2')) {
            try {
                $live = Get-Content -LiteralPath "$runRoot/$role/lobby_snapshot.json" -Raw | ConvertFrom-Json
                if ($observedPhases[$role] -ne $live.phase) {
                    "$role $($live.phase) remaining=$($live.countdownEnd - $live.serverTime)" | Add-Content -LiteralPath "$runRoot/phases.log"
                    $observedPhases[$role] = $live.phase
                }
                if ($live.phase -eq 'COUNTDOWN' -and $live.countdownEnd -gt $live.serverTime -and ($live.countdownEnd - $live.serverTime) -le 11) { $countdownSeen[$role] = $true }
                if ($countdownSeen[$role] -and $live.phase -eq 'WAITING') { $cancelSeen[$role] = $true }
            } catch { } # A snapshot can be momentarily incomplete while being replaced.
        }
        foreach ($process in $testProcesses) { $process.Refresh() }
    } while (@($testProcesses | Where-Object { !$_.HasExited }).Count -and (Get-Date) -lt $deadline)
    foreach ($role in @('host','guest1','guest2')) {
        if (!$countdownSeen[$role] -or !$cancelSeen[$role]) { throw "$role did not receive both countdown and cancellation." }
        $path = "$runRoot/$role/lobby_snapshot.json"
        $state = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $logPath = Join-Path $gameRoot "base/${runId}_${role}.log"
        $log = Get-Content -LiteralPath "$runRoot/$role/stdout.txt" -Raw
        if (Test-Path -LiteralPath $logPath) {
            $log += Get-Content -LiteralPath $logPath -Raw
            Copy-Item -LiteralPath $logPath -Destination "$runRoot/$role/console.log"
        }
        $prestart = $log.IndexOf('LOBBY_UI_PRESTART_CHECK')
        if ($prestart -lt 0 -or $log.Substring(0,$prestart).Contains('Initializing Client Game')) { throw "$role loaded gameplay before Start." }
        foreach ($message in @('host says hello','guest1 says hello','guest2 says hello')) {
            if (!$log.Contains($message)) { throw "$role did not receive chat: $message" }
        }
        if ($state.settings.ruleset -ne 'TEAMDM' -or $state.settings.timelimit -ne '12' -or $state.settings.fraglimit -ne '25') {
            throw "$role has incorrect lobby settings."
        }
        if ($state.map -ne 'envtest') { throw "$role lost the selected map: $($state.map)" }
        if (!$SkipStart -and $state.phase -ne 'INGAME') { throw "$role did not finish the game handoff: $($state.phase)" }
        if (!$SkipStart -and $role -ne 'host' -and !$log.Contains('Initializing Client Game')) { throw "$role received the start message but did not enter gameplay." }
    }
    $sourceShot = Join-Path $gameRoot "base/$shot"
    if (Test-Path -LiteralPath $sourceShot) { Copy-Item -LiteralPath $sourceShot -Destination "$runRoot/engine-lobby.png"; Remove-Item -LiteralPath $sourceShot }
    $handoff = if ($SkipStart) { 'game-start check skipped' } else { 'game-start handoff' }
    Write-Output "PASS: three actual engine clients, chat delivery in both directions, synchronized ruleset/limits, countdown/cancellation, $handoff. Artifacts: $runRoot"
} finally {
    foreach ($process in $testProcesses) {
        $process.Refresh()
        if (!$process.HasExited -and $process.Path -eq $gameExe) { Stop-Process -Id $process.Id }
    }
    foreach ($config in $testConfigs) { if (Test-Path -LiteralPath $config) { Remove-Item -LiteralPath $config } }
    Write-Output "Test artifacts: $runRoot"
}
