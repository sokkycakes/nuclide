$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$js = [IO.File]::ReadAllText((Join-Path $root "app.js"))
$css = [IO.File]::ReadAllText((Join-Path $root "style.css"))
$html = [IO.File]::ReadAllText((Join-Path $root "index.html"))

function Require([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

function Require-Order([string]$text, [string[]]$needles, [string]$message) {
    $position = -1
    foreach ($needle in $needles) {
        $next = $text.IndexOf($needle, $position + 1)
        if ($next -lt 0) { throw "$message (missing or out of order: $needle)" }
        $position = $next
    }
}

Require ($js.Contains("var transitioning = true;")) "Initial transition guard is missing"
Require ($js.Contains('if (!el || transitioning || joinOpen) return;')) "Activation guard is missing"
Require ($js.Contains('if (joinOpen || transitioning) return;')) "Wheel guard is missing"
Require ($js.Contains('if (transitioning) {')) "Keyboard guard is missing"
Require ($js.Contains('if (!addr || transitioning || !joinOpen) return;')) "Join guard is missing"
Require ($js.Contains('titleChrome.setAttribute("aria-hidden"')) "Title aria-hidden synchronization is missing"
Require ($js.Contains('joinDialog.setAttribute("aria-hidden"')) "Dialog aria-hidden synchronization is missing"
$openStart = $js.IndexOf("  function openJoin() {")
$openEnd = $js.IndexOf("  function closeJoin", $openStart)
Require ($openStart -ge 0 -and $openEnd -gt $openStart) "openJoin block is missing"
$openJoin = $js.Substring($openStart, $openEnd - $openStart)
Require-Order $openJoin @('refreshLan();', 'setTitleHidden(true);', 'joinDialog.classList.remove("hidden");', 'joinDialog.offsetWidth;', 'setDialogAvailable(true);') "Join dialog open order or layout flush regressed"

$closeStart = $js.IndexOf("  function closeJoin")
$closeEnd = $js.IndexOf("  function leaveTitle", $closeStart)
$closeJoin = $js.Substring($closeStart, $closeEnd - $closeStart)
Require-Order $closeJoin @('setDialogAvailable(false);', 'joinDialog.classList.add("hidden");', 'setTitleHidden(false);') "Join dialog close order regressed"

$joinStart = $js.IndexOf("  function joinAddr")
$joinEnd = $js.IndexOf("  function joinCode", $joinStart)
$joinAddr = $js.Substring($joinStart, $joinEnd - $joinStart)
Require-Order $joinAddr @('setDialogAvailable(false);', 'cbuf("menu_webcore_lobby");') "Successful join must fade before navigation"
Require (-not [regex]::IsMatch($js, 'afterTransition\s*\(\s*function\s*\(\s*\)\s*\{[^{}]*cbuf\s*\(', [Text.RegularExpressions.RegexOptions]::Singleline)) "External cbuf calls must not depend on afterTransition callbacks"
Require (-not $joinAddr.Contains('setTitleHidden(false)')) "Successful join must not flash title chrome"

$leaveStart = $js.IndexOf("  function leaveTitle")
$leaveEnd = $js.IndexOf("  function escapeHtml", $leaveStart)
Require ($leaveStart -ge 0 -and $leaveEnd -gt $leaveStart) "leaveTitle block is missing"
$leaveTitle = $js.Substring($leaveStart, $leaveEnd - $leaveStart)
Require-Order $leaveTitle @('cbuf(cmd);', 'if (cmd === "menu_options") {', 'afterTransition(function () {', 'setTitleHidden(false);', 'transitioning = false;') "Settings must dispatch synchronously before timer-based title restoration"

Require ($css.Contains("transition: opacity 180ms")) "180ms opacity transition is missing"
Require ($css.Contains("@media (prefers-reduced-motion: reduce)")) "Reduced-motion CSS is missing"
Require ($js.Contains("transitionMs = reduceMotion ? 0 : TRANSITION_MS")) "Reduced-motion JS timing is missing"
Require ($html.Contains('id="title-chrome" class="title-chrome is-hidden"')) "Initial title fade state is missing"
Require ($html.Contains('class="join-dialog hidden is-hidden" aria-hidden="true"')) "Initial dialog availability state is missing"
Require ($html.Contains('style.css?v=15')) "CSS cache version was not bumped"
Require ($html.Contains('app.js?v=17')) "JS cache version was not bumped"

Write-Host "title-menu-v2 transition regression checks passed"