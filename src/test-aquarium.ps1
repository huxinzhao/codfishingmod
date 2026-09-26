$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root="$PSScriptRoot/../outputs/cod fishing mod/Content"
$pack=Get-Content "$root/content.json" -Raw|ConvertFrom-Json -AsHashtable
$objects=@($pack.Changes|Where-Object Target -eq 'Data/Objects')[0].Entries
$patches=@($pack.Changes|Where-Object Target -eq 'Data/AquariumFish')
function Check($ok,$message){if(!$ok){throw $message}}
Check ($patches.Count -eq 1 -and $patches[0].Action -eq 'EditData') 'Aquarium data missing or replacing vanilla data'
$entries=$patches[0].Entries
Check ($entries.Count -eq 7) 'Not all seven fish support tanks'
foreach($id in $objects.Keys){
    Check ($entries.Contains($id)) "Missing unqualified fish ID: $id"
    $fields=$entries[$id].Split('/')
    Check ($fields.Count -eq 7 -and $fields[0] -eq '0') 'Malformed aquarium data'
    Check ($fields[1] -eq $(if($id -eq 'Xinzh.KeniOctopus_Fish'){'float'}else{'crawl'})) 'Wrong tank behavior'
    foreach($index in 2..5){Check ($fields[$index] -eq '0') 'Animation references nonexistent frame'}
    $texture=$fields[6]
    $load=@($pack.Changes|Where-Object {$_.Target -eq $texture -and $_.Action -eq 'Load'})
    $edit=@($pack.Changes|Where-Object {$_.Target -eq $texture -and $_.Action -eq 'EditImage'})
    Check ($load.Count -eq 1 -and $edit.Count -eq 1) 'Missing aquarium texture load/edit pair'
    $canvas=[Drawing.Bitmap]::new([IO.Path]::GetFullPath("$root/$($load[0].FromFile)"))
    try{
        Check ($canvas.Width -eq 24 -and $canvas.Height -eq 24) 'Tank frames require 24x24 textures'
        for($y=0;$y -lt 24;$y++){for($x=0;$x -lt 24;$x++){Check ($canvas.GetPixel($x,$y).A -eq 0) 'Canvas must be transparent'}}
    }finally{$canvas.Dispose()}
    $spriteLoad=@($pack.Changes|Where-Object {$_.Action -eq 'Load' -and $_.Target -eq $objects[$id].Texture})[0]
    Check ($edit[0].FromFile -ceq $spriteLoad.FromFile) 'Tank sprite differs from inventory or daily random key'
    $source=$edit[0].FromArea;$dest=$edit[0].ToArea
    Check ($source.X -eq 0 -and $source.Y -eq 0 -and $source.Width -eq 16 -and $source.Height -eq 16) 'Unexpected sprite crop'
    Check ($dest.X -eq 4 -and $dest.Y -eq 8 -and $dest.Width -eq 16 -and $dest.Height -eq 16) 'Sprite scaled or outside frame'
    $files=if($spriteLoad.FromFile.Contains('{{Random:')){@('assets/seahares/ke-a.png','assets/seahares/ke-b.png')}else{@($spriteLoad.FromFile)}
    foreach($file in $files){
        $image=[Drawing.Bitmap]::new([IO.Path]::GetFullPath("$root/$file"))
        try{Check ($image.Width -eq 16 -and $image.Height -eq 16) 'Sprite does not fit intended crop'}finally{$image.Dispose()}
    }
}
'PASS: seven aquarium IDs, behaviors, frame indexes, transparent 24x24 canvases, unscaled sprites and shared daily variant key.'

