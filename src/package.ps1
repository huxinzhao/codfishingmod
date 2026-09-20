$ErrorActionPreference = 'Stop'
$modPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../outputs/cod fishing mod'))
$manifest = Get-Content -LiteralPath (Join-Path $modPath 'manifest.json') -Raw | ConvertFrom-Json
if ($manifest.UpdateKeys -notcontains 'Nexus:52606') { throw 'Missing Nexus update key.' }
if ($manifest.MinimumGameVersion -ne '1.6.15') { throw 'Minimum game version must match the supported release.' }
if ($manifest.UniqueID -ne 'Xinzh.KeniOctopus') { throw 'The stable mod ID must not change.' }
$required = @('manifest.json', 'CodFishingMod.dll', 'data.json', 'i18n/zh.json', 'i18n/default.json', 'INSTALL.txt', '安装说明.txt', 'assets/keni.png')
$required += @('ke-a','ke-b','ni','konig','ghost','soap','keegan') | ForEach-Object { "assets/seahares/$_.png" }
foreach ($file in $required) {
    if (!(Test-Path -LiteralPath (Join-Path $modPath $file) -PathType Leaf)) { throw "Missing release file: $file" }
}
# Verify that the entry point is a readable managed assembly, not an empty failed build.
$null = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $modPath $manifest.EntryDll))
foreach ($file in @('data.json','i18n/zh.json','i18n/default.json')) {
    $null = Get-Content -LiteralPath (Join-Path $modPath $file) -Raw | ConvertFrom-Json
}
$archive = Join-Path (Split-Path $modPath) "cod-fishing-mod-$($manifest.Version).zip"
# Only ship the known runtime files; never bundle source, editor files or earlier ZIPs.
$zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $required) {
        $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $modPath $file), "cod fishing mod/$file")
    }
} finally { $zip.Dispose() }
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    if ($zip.Entries.Count -ne $required.Count) { throw 'Release archive is incomplete.' }
    foreach ($entry in $zip.Entries) {
        if ($entry.Length -eq 0) { throw "Empty release file: $($entry.FullName)" }
    }
} finally { $zip.Dispose() }
Get-FileHash -LiteralPath $archive -Algorithm SHA256
