# Test helper: expose CP entries in the former data model for gameplay regression checks.
$pack = Get-Content "$PSScriptRoot/../outputs/cod fishing mod/Content/content.json" -Raw | ConvertFrom-Json -AsHashtable
$data = @{ Objects=@{}; Fish=@{}; Mail=@{}; Quests=@{}; Locations=@{}; FishPonds=@(); TriggerActions=@(); Events=@{}; GiftDialogue=@{}; GiftLikes=@{}; GiftLoves=@{} }
foreach ($patch in $pack.Changes) {
    switch ($patch.Target) {
        'Data/Objects' { $data.Objects = $patch.Entries }
        'Data/Fish' { $data.Fish = $patch.Entries }
        'Data/mail' { $data.Mail = $patch.Entries }
        'Data/Quests' { $data.Quests = $patch.Entries }
        'Data/Locations' { $data.Locations[$patch.TargetField[0]] = @($patch.Entries.Values) }
        'Data/FishPondData' { $data.FishPonds = @($patch.Entries.Values) }
        'Data/TriggerActions' { $data.TriggerActions = @($patch.Entries.Values) }
        'Data/NPCGiftTastes' {
            foreach ($op in $patch.TextOperations) {
                $section = if ($op.Target[2] -eq '1') { 'GiftLoves' } else { 'GiftLikes' }
                $data[$section][$op.Target[1]] = $op.Value.Split(' ')
            }
        }
        default {
            if ($patch.Target.StartsWith('Data/Events/')) { $data.Events[$patch.Target.Substring(12)] = $patch.Entries }
            if ($patch.Target.StartsWith('Characters/Dialogue/')) { $data.GiftDialogue[$patch.Target.Substring(20)] = $patch.Entries }
        }
    }
}
return $data
