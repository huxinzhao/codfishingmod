param([string]$GameDir = $env:STARDEW_GAME_PATH)
$ErrorActionPreference = 'Stop'
$gameDir = & "$PSScriptRoot/game-path.ps1" -GameDir $GameDir
Add-Type -Path "$PSHOME/Microsoft.CodeAnalysis.dll"
Add-Type -Path "$PSHOME/Microsoft.CodeAnalysis.CSharp.dll"
$referencePaths = @(
    "$gameDir/System.Private.CoreLib.dll",
    "$gameDir/System.Runtime.dll",
    "$gameDir/System.Text.RegularExpressions.dll",
    "$gameDir/System.Collections.dll",
    "$gameDir/System.Linq.dll",
    "$gameDir/System.Linq.Expressions.dll",
    "$gameDir/System.ComponentModel.Primitives.dll",
    "$gameDir/System.ObjectModel.dll",
    "$gameDir/netstandard.dll",
    "$gameDir/Stardew Valley.dll",
    "$gameDir/StardewValley.GameData.dll",
    "$gameDir/StardewModdingAPI.dll",
    "$gameDir/smapi-internal/SMAPI.Toolkit.CoreInterfaces.dll",
    "$gameDir/MonoGame.Framework.dll",
    "$gameDir/smapi-internal/Newtonsoft.Json.dll",
    "$gameDir/smapi-internal/0Harmony.dll"
)
$references = [Microsoft.CodeAnalysis.MetadataReference[]]@(
    foreach ($path in $referencePaths) {
        [Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($path)
    }
)
$trees = [Microsoft.CodeAnalysis.SyntaxTree[]]@(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cs' | ForEach-Object { [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText((Get-Content -LiteralPath $_.FullName -Raw)) })
$options = [Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary).WithOptimizationLevel([Microsoft.CodeAnalysis.OptimizationLevel]::Release)
$compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create('CodFishingMod', $trees, $references, $options)
$stream = [IO.File]::Create("$PSScriptRoot/../outputs/cod fishing mod/CodFishingMod.dll")
try {
    $result = $compilation.Emit($stream)
    $result.Diagnostics | ForEach-Object { $_.ToString() }
    if (!$result.Success) { throw 'Compilation failed' }
} finally { $stream.Dispose() }
Write-Output 'Compiled against installed Stardew Valley and SMAPI assemblies.'
