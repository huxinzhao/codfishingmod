param([string]$GameDir = $env:STARDEW_GAME_PATH)
$ErrorActionPreference = 'Stop'
$gameDir = & "$PSScriptRoot/game-path.ps1" -GameDir $GameDir
Add-Type -Path "$gameDir/MonoGame.Framework.dll"
Add-Type -Path "$gameDir/StardewValley.GameData.dll"
$content = [Microsoft.Xna.Framework.Content.ContentManager]::new([Microsoft.Xna.Framework.GameServiceContainer]::new(), "$gameDir/Content")
try {
    $objects = $content.GetType().GetMethod('Load').MakeGenericMethod([System.Collections.Generic.Dictionary[string,StardewValley.GameData.Objects.ObjectData]]).Invoke($content, @('Data/Objects'))
    $native = $content.GetType().GetMethod('Load').MakeGenericMethod([System.Collections.Generic.List[StardewValley.GameData.FishPonds.FishPondData]]).Invoke($content, @('Data/FishPondData'))
} finally { $content.Dispose() }
$data = & "$PSScriptRoot/read-content-data.ps1"
function Check($ok, $message) { if (!$ok) { throw $message } }
function Income($pond, $price, $population = 10) {
    $remaining = $pond.BaseMinProduceChance + ($pond.BaseMaxProduceChance - $pond.BaseMinProduceChance) * $population / 10
    $roe = 0.0; $other = 0.0
    # Fish pond rewards are first-success trials, not independent daily probabilities.
    foreach ($reward in $pond.ProducedItems | Sort-Object Precedence -Stable) {
        if ($reward.RequiredPopulation -gt $population) { continue }
        Check (!$reward.Condition -and !$reward.RandomItemId -and !$reward.StackModifiers) 'Income model needs updating for conditional/random rewards.'
        $chance = $remaining * $reward.Chance
        $remaining *= 1 - $reward.Chance
        $quantity = ([Math]::Max(1, $reward.MinStack) + [Math]::Max(1, $reward.MaxStack)) / 2
        if ($reward.ItemId -eq '(O)812') { $roe += $chance * $quantity * (30 + [Math]::Floor($price / 2)) }
        else { $other += $chance * $quantity * $objects[$reward.ItemId.Substring(3)].Price }
    }
    [pscustomobject]@{ Raw = $roe + $other; Aged = 2 * $roe + $other; Artisan = 2.8 * $roe + $other }
}
$baseline = Income ($native | Where-Object Id -eq 'LavaEel') $objects['162'].Price
$rows = @([pscustomobject]@{ Pond='LavaEel'; Raw=$baseline.Raw; Aged=$baseline.Aged; Artisan=$baseline.Artisan })
$colors = @()
foreach ($species in @('Ke','Ni','Keegan','Konig','Ghost','Soap')) {
    $id = "Xinzh.KeniOctopus_SeaHare$species"
    $fish = $data.Objects[$id]
    $pond = @($data.FishPonds | Where-Object Id -eq "${id}_Pond")
    Check ($pond.Count -eq 1) "Missing or duplicate pond: $species"
    $pond = $pond[0]
    Check ($fish.ContextTags -contains $pond.RequiredTags[0]) "Pond cannot match fish: $species"
    Check (@($fish.ContextTags | Where-Object { $_ -like 'color_*' }).Count -eq 1) "Missing or conflicting dye tags: $species"
    Check ($pond.MaxPopulation -eq 10 -and $pond.WaterColor[0].MinPopulation -eq 1) "Invalid capacity or color gate: $species"
    $colors += $pond.WaterColor[0].Color
    $special = @($pond.ProducedItems | Where-Object ItemId -ne '(O)812')
    Check ($special.Count -eq 3) "Expected one dish, one artifact and one chest: $species"
    Check ($objects[$special[0].ItemId.Substring(3)].Name -eq 'Treasure Chest') "Wrong treasure ID: $species"
    Check ($objects[$special[1].ItemId.Substring(3)].Type -eq 'Cooking') "Wrong cooking ID: $species"
    Check ($objects[$special[2].ItemId.Substring(3)].Type -eq 'Arch') "Wrong artifact ID: $species"
    Check ($special[0].RequiredPopulation -eq 10 -and $special[0].Chance -le 0.02) "Chest unlocked too early or too common: $species"
    foreach ($reward in $pond.ProducedItems) {
        Check ($objects.ContainsKey($reward.ItemId.Substring(3))) "Unknown reward item: $species"
        Check ($reward.Chance -gt 0 -and $reward.Chance -le 1 -and $reward.MinStack -ge 1 -and $reward.MaxStack -ge $reward.MinStack) "Invalid reward: $species"
    }
    $income = Income $pond $fish.Price
    foreach ($mode in @('Raw','Aged','Artisan')) {
        Check ([Math]::Abs($income.$mode / $baseline.$mode - 1) -le 0.08) "Full-pond $mode income outside +/-8% of Lava Eel: $species"
    }
    $previous = 0
    foreach ($population in 1..10) {
        $growing = Income $pond $fish.Price $population
        Check ($growing.Raw -ge $previous -and $growing.Raw -le $income.Raw) "Unexpected population income curve: $species"
        $previous = $growing.Raw
    }
    $rows += [pscustomobject]@{Pond=$species; Raw=$income.Raw; Aged=$income.Aged; Artisan=$income.Artisan}
}
Check (@($colors | Select-Object -Unique).Count -eq 6) 'Pond colors must be distinct.'
$rows | Format-Table Pond, @{n='Raw/day';e={[Math]::Round($_.Raw,2)}}, @{n='Aged/day';e={[Math]::Round($_.Aged,2)}}, @{n='Artisan/day';e={[Math]::Round($_.Artisan,2)}}
'PASS: native reward IDs/types, pond matching, colors, population gates and expected income (no buffs, 10 fish, daily collection; not in-game testing).'

