$ErrorActionPreference = 'Stop'
$demoRoot = Split-Path -Parent $PSScriptRoot
$demoEngine = [IO.Path]::GetFullPath((Join-Path $demoRoot '..\Godot_v4.7.2-stable_win64.exe'))
if (-not (Test-Path -LiteralPath $demoEngine)) {
    throw "Godot executable not found: $demoEngine"
}
$demoLogDir = Join-Path $demoRoot 'artifacts\test-logs'
New-Item -ItemType Directory -Force -Path $demoLogDir | Out-Null
$demoCases = @(
    @{ Name = 'spawn'; Script = 'test_player_spawn.gd'; Extra = @() },
    @{ Name = 'interactions'; Script = 'test_interactions.gd'; Extra = @() },
    @{ Name = 'progression'; Script = 'test_level_flow.gd'; Extra = @() },
    @{ Name = 'chemical-walkthrough'; Script = 'test_walkthrough.gd'; Extra = @() },
    @{ Name = 'physical-walkthrough'; Script = 'test_walkthrough.gd'; Extra = @('--physical-route') }
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
Write-Output 'PASS: all 5 demo verification scenarios'
