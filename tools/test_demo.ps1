$ErrorActionPreference = 'Stop'
$demoRoot = Split-Path -Parent $PSScriptRoot
$demoEngine = [IO.Path]::GetFullPath((Join-Path $demoRoot 'engine\Godot_v4.7.2-stable_win64_console.exe'))
if (-not (Test-Path -LiteralPath $demoEngine)) {
    throw "Godot executable not found: $demoEngine"
}
$demoLogDir = Join-Path $demoRoot 'artifacts\test-logs'
New-Item -ItemType Directory -Force -Path $demoLogDir | Out-Null
$demoCases = @(
    @{ Name = 'spawn'; Script = 'test_player_spawn.gd'; Extra = @() },
    @{ Name = 'interactions'; Script = 'test_interactions.gd'; Extra = @() },
    @{ Name = 'progression'; Script = 'test_level_flow.gd'; Extra = @() },
    # Old throwable/gravity walkthrough is archived until the level is redesigned.
    @{ Name = 'elements'; Script = 'test_elements.gd'; Extra = @() },
    @{ Name = 'magazines'; Script = 'test_magazines.gd'; Extra = @() },
    @{ Name = 'weapon-audio'; Script = 'test_weapon_audio.gd'; Extra = @() },
    @{ Name = 'animation-states'; Script = 'test_animation_states.gd'; Extra = @() },
    @{ Name = 'combat'; Script = 'test_combat.gd'; Extra = @() },
    @{ Name = 'pixel-workbench'; Script = 'test_pixel_workbench.gd'; Extra = @() }
)
foreach ($demoCase in $demoCases) {
    $demoLogPath = Join-Path $demoLogDir ($demoCase.Name + '.log')
    $demoArgs = @('--headless', '--path', $demoRoot, '--fixed-fps', '60', '--log-file', $demoLogPath, '--script', ('res://tests/' + $demoCase.Script), '--', '--test-mode') + $demoCase.Extra
    # Windows PowerShell promotes native stderr to error records; inspect the
    # engine output below instead of aborting before the PASS/error checks.
    try {
        $ErrorActionPreference = 'Continue'
        $demoOutput = (& $demoEngine @demoArgs 2>&1 | ForEach-Object { $_.ToString() } | Out-String)
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    $demoCombined = $demoOutput
    if (Test-Path -LiteralPath $demoLogPath) {
        $demoCombined += Get-Content -LiteralPath $demoLogPath -Raw
    }
    if ($demoCombined -notmatch 'PASS:' -or $demoCombined -match '(SCRIPT ERROR:|FAILED CHECK:|FAIL:|ERROR: (?!Failed to read the root certificate store))') {
        Write-Output $demoCombined
        throw "Demo verification failed: $($demoCase.Name)"
    }
    Write-Output ($demoOutput -split '\r?\n' | Where-Object { $_ -match '^PASS:' })
}
Write-Output 'PASS: all 9 demo verification scenarios'
