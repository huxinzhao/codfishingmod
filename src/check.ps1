param([string]$GameDir = $env:STARDEW_GAME_PATH)
$ErrorActionPreference = 'Stop'
$gameDir = & "$PSScriptRoot/game-path.ps1" -GameDir $GameDir
foreach ($script in @('test.ps1', 'test-survey.ps1', 'test-assets.ps1', 'sync-text.ps1')) {
    $arguments = @('-NoProfile', '-File', (Join-Path $PSScriptRoot $script))
    if ($script -eq 'test-assets.ps1') { $arguments += @('-GameDir', $gameDir) }
    if ($script -eq 'sync-text.ps1') { $arguments += @('-Mode', 'Check') }
    & (Join-Path $PSHOME 'pwsh') @arguments
    if ($LASTEXITCODE -ne 0) { throw "Check failed: $script" }
}
