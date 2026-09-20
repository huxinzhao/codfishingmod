param([string]$GameDir = $env:STARDEW_GAME_PATH)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GameDir)) {
    throw 'Provide -GameDir pointing to Stardew Valley, or set STARDEW_GAME_PATH.'
}
$resolvedGameDir = (Resolve-Path -LiteralPath $GameDir).Path
if (!(Test-Path -LiteralPath (Join-Path $resolvedGameDir 'StardewValley.GameData.dll'))) {
    throw 'GameDir must contain StardewValley.GameData.dll.'
}
$resolvedGameDir
