param([string]$GameDir = $env:STARDEW_GAME_PATH)
$ErrorActionPreference = 'Stop'
$gameDir = & "$PSScriptRoot/game-path.ps1" -GameDir $GameDir
Add-Type -Path "$gameDir/StardewValley.GameData.dll"
$root = "$PSScriptRoot/../outputs/cod fishing mod"
$pack = Get-Content "$root/Content/content.json" -Raw | ConvertFrom-Json -AsHashtable
$data = & "$PSScriptRoot/read-content-data.ps1"
function Check($ok, $message) { if (!$ok) { throw $message } }
Check ($pack.Format -eq '2.9.0') 'Wrong CP format'
Check (!(Test-Path "$root/manifest.json") -and !(Test-Path "$root/data.json")) 'Old root mod would hide nested packs'
$runtime = Get-Content "$root/Runtime/manifest.json" -Raw | ConvertFrom-Json
$content = Get-Content "$root/Content/manifest.json" -Raw | ConvertFrom-Json
Check ($runtime.UniqueID -eq 'Xinzh.KeniOctopus' -and $content.ContentPackFor.UniqueID -eq 'Pathoschild.ContentPatcher') 'Broken mod identity or content owner'
Check ($runtime.Version -eq $content.Version -and $content.Dependencies[0].UniqueID -eq $runtime.UniqueID) 'Pack versions/dependencies differ'
Check ($runtime.Dependencies[0].UniqueID -eq 'Pathoschild.ContentPatcher' -and $runtime.UpdateKeys -contains 'Nexus:52606') 'Missing dependency/update key'
$targets = @{}
foreach ($patch in $pack.Changes) {
    Check ($patch.Action -in @('Load','EditData','EditImage')) 'Unexpected action'
    Check (!$patch.When) 'A CP condition could globally change multiplayer spawn rules'
    if ($patch.Action -eq 'Load') {
        Check ($patch.Target.StartsWith('Mods/Xinzh.KeniOctopus/') -or $patch.Target.StartsWith('Xinzh.KeniOctopus_Aquarium_')) 'Replacing a vanilla texture'
        Check (!$targets.ContainsKey($patch.Target)) 'Duplicate sprite target'
        $targets[$patch.Target]=$true
        $files = if ($patch.FromFile.Contains('{{Random:')) {
            Check ($patch.FromFile -eq 'assets/seahares/ke-{{Random:a, a, a, a, b |key=SeaHareKe}}.png') 'Wrong daily variant weighting'
            @('assets/seahares/ke-a.png','assets/seahares/ke-b.png')
        } else { @($patch.FromFile) }
        foreach ($file in $files) { Check (Test-Path "$root/Content/$file") "Missing sprite: $file" }
    }
    if ($patch.Target -eq 'Data/Locations') {
        Check ($patch.TargetField.Count -eq 2 -and $patch.TargetField[1] -eq 'Fish') 'Would replace another mod location data'
        foreach ($entry in $patch.Entries.GetEnumerator()) {
            Check ($entry.Key -eq $entry.Value.Id) 'Spawn key does not match Id'
            $json=$entry.Value | ConvertTo-Json -Depth 100
            $null=[Newtonsoft.Json.JsonConvert]::DeserializeObject($json,[StardewValley.GameData.Locations.SpawnFishData])
        }
    }
}
Check ($targets.Count -eq 14 -and $data.Objects.Count -eq 7 -and $data.Fish.Count -eq 7) 'Missing fish/assets'
foreach ($entry in $data.Objects.GetEnumerator()) {
    $json=$entry.Value | ConvertTo-Json -Depth 100
    $obj=[Newtonsoft.Json.JsonConvert]::DeserializeObject($json,[StardewValley.GameData.Objects.ObjectData])
    Check ($obj.Type -eq 'Fish' -and $obj.Category -eq -4 -and $targets.ContainsKey($obj.Texture)) 'Invalid fish type/texture'
}
Check ($data.Locations.Beach.Count -eq 7 -and $data.Locations.IslandSouthEastCave.Count -eq 1) 'Location migration lost fish'
foreach ($spawn in $data.Locations.Beach | Where-Object ItemId -Like '*SeaHare*') {
    Check ($spawn.Condition -eq 'SEASON spring summer fall winter, PLAYER_HAS_MAIL Current Xinzh.KeniOctopus_SeaHareUnlocked') 'Lookup metadata or per-player unlock lost'
    Check (!$spawn.IgnoreFishDataRequirements) 'Time/weather rules bypassed'
}
foreach ($pond in $data.FishPonds) {
    $null=[Newtonsoft.Json.JsonConvert]::DeserializeObject(($pond|ConvertTo-Json -Depth 100),[StardewValley.GameData.FishPonds.FishPondData])
}
foreach ($trigger in $data.TriggerActions) {
    $null=[Newtonsoft.Json.JsonConvert]::DeserializeObject(($trigger|ConvertTo-Json -Depth 100),[StardewValley.GameData.TriggerActionData])
}
$giftPatch = @($pack.Changes | Where-Object Target -eq 'Data/NPCGiftTastes')
Check ($giftPatch.Count -eq 1 -and !$giftPatch[0].Entries -and !$giftPatch[0].Fields) 'Gift tastes replace entire NPC data'
foreach ($op in $giftPatch[0].TextOperations) {
    Check ($op.Operation -eq 'Append' -and $op.Delimiter -eq ' ' -and $op.Target[0] -eq 'Fields' -and $op.Target[2] -in @('1','3')) 'Invalid additive gift edit'
    foreach ($id in $op.Value.Split(' ')) { Check ($data.Objects.Contains($id)) 'Gift references missing object' }
}
Check ($data.GiftLikes.Count -eq 16 -and $data.GiftLoves.Willy[0] -eq 'Xinzh.KeniOctopus_Fish' -and $data.GiftLikes.Willy.Count -eq 6) 'Gift preferences lost'
$raw = Get-Content "$root/Content/content.json" -Raw
$keys = @([regex]::Matches($raw,'{{i18n:([^}]+)}}') | ForEach-Object {$_.Groups[1].Value} | Sort-Object -Unique)
foreach ($locale in @('zh','default')) {
    $i18n=Get-Content "$root/Content/i18n/$locale.json" -Raw|ConvertFrom-Json -AsHashtable
    foreach ($key in $keys) { Check ($i18n.Contains($key) -and $i18n[$key]) "Missing $locale translation: $key" }
    foreach ($item in $data.Objects.Values) {
        foreach ($field in @('DisplayName','Description')) {
            $key=[regex]::Match($item[$field],'{{i18n:([^}]+)}}').Groups[1].Value
            Check ($key -and $i18n.Contains($key)) 'Item text not localized'
            if ($locale -eq 'zh') { Check ($i18n[$key] -match '[一-龥]') 'Chinese item text missing' }
        }
    }
}
'PASS: CP pack structure, native data types, sprites, 80/20 weighting, localized text, additive gift edits and per-player unlock conditions (static validation; not an in-game CP test).'


