$ErrorActionPreference = 'Stop'
$modPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../outputs/cod fishing mod'))
$manifest = Get-Content "$modPath/Runtime/manifest.json" -Raw | ConvertFrom-Json
if ($manifest.UpdateKeys -notcontains 'Nexus:52606' -or $manifest.UniqueID -ne 'Xinzh.KeniOctopus') { throw 'Missing stable ID/update key.' }
$pack = Get-Content "$modPath/Content/manifest.json" -Raw | ConvertFrom-Json
if ($pack.Version -ne $manifest.Version -or $pack.ContentPackFor.UniqueID -ne 'Pathoschild.ContentPatcher') { throw 'Invalid content pack.' }
$required = @('Runtime/manifest.json','Runtime/CodFishingMod.dll','Runtime/i18n/zh.json','Runtime/i18n/default.json','Content/manifest.json','Content/content.json','Content/i18n/zh.json','Content/i18n/default.json','INSTALL.txt','安装说明.txt','Content/assets/keni.png','Content/assets/aquarium-canvas.png')
$required += @('ke-a','ke-b','ni','konig','ghost','soap','keegan') | ForEach-Object { "Content/assets/seahares/$_.png" }
foreach ($file in $required) {
    if (!(Test-Path -LiteralPath (Join-Path $modPath $file) -PathType Leaf)) { throw "Missing release file: $file" }
    if ($file.EndsWith('.json')) { $null=Get-Content (Join-Path $modPath $file) -Raw|ConvertFrom-Json }
}
$null=[Reflection.AssemblyName]::GetAssemblyName("$modPath/Runtime/CodFishingMod.dll")
if (Test-Path "$modPath/manifest.json") { throw 'Root manifest would hide the two component folders.' }
$archive=Join-Path (Split-Path $modPath) "cod-fishing-mod-$($manifest.Version).zip"
$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach($file in $required) { $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $modPath $file),"cod fishing mod/$file") }
} finally { $zip.Dispose() }
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try {
    if ($zip.Entries.Count -ne $required.Count) { throw 'Incomplete archive' }
    foreach($entry in $zip.Entries) { if($entry.Length -eq 0){throw "Empty file: $($entry.FullName)"} }
} finally { $zip.Dispose() }
Get-FileHash $archive -Algorithm SHA256

