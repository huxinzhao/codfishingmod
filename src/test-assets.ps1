$ErrorActionPreference='Stop'
$source=(Get-Content -LiteralPath "$PSScriptRoot/ContentAssets.cs" -Raw).Replace('namespace KeniOctopus.QuestRuntime;', 'namespace KeniOctopus.QuestRuntime {') + "`n}"
$stubs=@'
namespace Microsoft.Xna.Framework.Graphics {public class Texture2D {}}
namespace StardewValley {public static class Game1 {public static ulong uniqueIDForThisGame=123456;public static Date Date=new();} public class Date {public int TotalDays=20;}}
namespace StardewModdingAPI {
 public enum AssetLoadPriority {Exclusive}
 public interface IAssetData {DictionaryAsset<K,V> AsDictionary<K,V>(); T GetData<T>();}
 public class DictionaryAsset<K,V>{public System.Collections.Generic.IDictionary<K,V> Data;}
 public class Asset:IAssetData {public object Value;public DictionaryAsset<K,V> AsDictionary<K,V>()=>new(){Data=(System.Collections.Generic.IDictionary<K,V>)Value};public T GetData<T>()=>(T)Value;}
 public class Name {public string Value; public string NameValue=>Value;}
 public class AssetName {public string Name;}
 public class Translation {public System.Collections.Generic.Dictionary<string,string> Text;public string Get(string key)=>Text[key];}
 public class DataHelper {public string Root;public T ReadJsonFile<T>(string file)=>Newtonsoft.Json.JsonConvert.DeserializeObject<T>(System.IO.File.ReadAllText(System.IO.Path.Combine(Root,file)));}
 public class ContentHelper {public System.Collections.Generic.List<string> Invalidated=new(); public void InvalidateCache(string name){Invalidated.Add(name);}}
 public class EventsApi {public ContentEvents Content=new();public Loop GameLoop=new();}
 public class ContentEvents {public event System.EventHandler<Events.AssetRequestedEventArgs> AssetRequested; public event System.EventHandler LocaleChanged; public void ChangeLocale()=>LocaleChanged?.Invoke(this,System.EventArgs.Empty);}
 public class Loop {public event System.EventHandler SaveLoaded,DayStarted,ReturnedToTitle;}
 public interface IModHelper {DataHelper Data{get;} Translation Translation{get;} ContentHelper GameContent{get;} EventsApi Events{get;}}
 public class Helper:IModHelper {public DataHelper Data{get;}=new();public Translation Translation{get;}=new();public ContentHelper GameContent{get;}=new();public EventsApi Events{get;}=new();}
}
namespace StardewModdingAPI.Events {
 public class AssetRequestedEventArgs:System.EventArgs {public StardewModdingAPI.AssetName NameWithoutLocale=new(); public StardewModdingAPI.Asset Target;public string LoadedPath;public void Edit(System.Action<StardewModdingAPI.IAssetData> edit)=>edit(Target);public void LoadFromModFile<T>(string path,StardewModdingAPI.AssetLoadPriority priority){LoadedPath=path;}}
}
'@
$refs=@(Get-ChildItem -LiteralPath "$PSHOME/ref" -Filter '*.dll' | ForEach-Object FullName)+@('D:/steam/steamapps/common/Stardew Valley/StardewValley.GameData.dll',[Newtonsoft.Json.JsonConvert].Assembly.Location)
Add-Type -Path 'D:/steam/steamapps/common/Stardew Valley/StardewValley.GameData.dll'
Add-Type -TypeDefinition ($source+$stubs) -ReferencedAssemblies $refs -IgnoreWarnings -WarningAction SilentlyContinue
$type=[StardewValley.Game1].Assembly.GetType('KeniOctopus.QuestRuntime.ContentAssets')
$helper=[StardewModdingAPI.Helper]::new();$helper.Data.Root=Join-Path $PSScriptRoot '../outputs/cod fishing mod'
$helper.Translation.Text=[Newtonsoft.Json.JsonConvert]::DeserializeObject((Get-Content -LiteralPath (Join-Path $helper.Data.Root 'i18n/zh.json') -Raw),[System.Collections.Generic.Dictionary[string,string]])
$null=$type.GetMethod('Initialize',[Reflection.BindingFlags]'Static,NonPublic').Invoke($null,@($helper))
function Load($name,$data){
 $e=[StardewModdingAPI.Events.AssetRequestedEventArgs]::new();$e.NameWithoutLocale.Name=$name;$e.Target=[StardewModdingAPI.Asset]::new();$e.Target.Value=$data
 $null=$type.GetMethod('OnAssetRequested',[Reflection.BindingFlags]'Static,NonPublic').Invoke($null,@($null,$e));return $e
}
function Check($value,$message){if(-not $value){throw $message}}
$objects=[System.Collections.Generic.Dictionary[string,StardewValley.GameData.Objects.ObjectData]]::new()
$null=Load 'Data/Objects' $objects
Check ($objects.Count -eq 7 -and $objects['Xinzh.KeniOctopus_SeaHareKe'].DisplayName -eq '海兔克') 'Objects or translations failed'
$helper.Translation.Text=[Newtonsoft.Json.JsonConvert]::DeserializeObject((Get-Content -LiteralPath (Join-Path $helper.Data.Root 'i18n/default.json') -Raw),[System.Collections.Generic.Dictionary[string,string]])
$helper.Events.Content.ChangeLocale()
Check ($helper.GameContent.Invalidated.Contains('Data/Objects')) 'Object translations not invalidated after language change'
$null=Load 'Data/Objects' $objects
Check ($objects['Xinzh.KeniOctopus_SeaHareKe'].DisplayName -eq 'Sea Hare Krueger') 'English item name failed'
Check ($objects['Xinzh.KeniOctopus_Fish'].Description -eq 'An odd-looking octopus, plump and juicy.') 'English item description failed'
$helper.Translation.Text=[Newtonsoft.Json.JsonConvert]::DeserializeObject((Get-Content -LiteralPath (Join-Path $helper.Data.Root 'i18n/zh.json') -Raw),[System.Collections.Generic.Dictionary[string,string]])
$helper.Events.Content.ChangeLocale()
$null=Load 'Data/Objects' $objects
foreach($obj in $objects.Values) {
 Check ($obj.DisplayName -match '[\p{IsCJKUnifiedIdeographs}]') 'Chinese name fell back to English'
 Check ($obj.Description -match '[\p{IsCJKUnifiedIdeographs}]') 'Chinese description fell back to English'
}
$events=[System.Collections.Generic.Dictionary[string,string]]::new();$null=Load 'Data/Events/FishShop' $events
Check ($events.Count -eq 1 -and @($events.Values)[0].Contains('把它好好养在鱼塘里')) 'Edited Willy event text not applied'
$locations=[System.Collections.Generic.Dictionary[string,StardewValley.GameData.Locations.LocationData]]::new()
$locations['Beach']=[StardewValley.GameData.Locations.LocationData]::new();$locations['IslandSouthEastCave']=[StardewValley.GameData.Locations.LocationData]::new()
$null=Load 'Data/Locations' $locations;$null=Load 'Data/Locations' $locations
Check ($locations['Beach'].Fish.Count -eq 7 -and $locations['IslandSouthEastCave'].Fish.Count -eq 1) 'Fish locations duplicated or lost'
foreach($name in @('Fish','mail','Quests')){$dict=[System.Collections.Generic.Dictionary[string,string]]::new();$null=Load "Data/$name" $dict;Check ($dict.Count -gt 0) "Missing $name";Check (-not (@($dict.Values)-match '\{\{i18n:')) "Unresolved text in $name"}
$ponds=[System.Collections.Generic.List[StardewValley.GameData.FishPonds.FishPondData]]::new();$null=Load 'Data/FishPondData' $ponds
Check ($ponds.Count -eq 1 -and $ponds[0].MaxPopulation -eq 1) 'Fish pond data changed'
$triggers=[System.Collections.Generic.List[StardewValley.GameData.TriggerActionData]]::new();$null=Load 'Data/TriggerActions' $triggers
Check ($triggers.Count -eq 2) 'Willy letter triggers missing'
foreach($id in @('Fish','SeaHareKe','SeaHareNi','SeaHareKeegan','SeaHareKonig','SeaHareGhost','SeaHareSoap')){$e=Load "Mods/Xinzh.KeniOctopus/$id" $null;Check (Test-Path -LiteralPath (Join-Path $helper.Data.Root $e.LoadedPath)) "Sprite missing $id"}
$variant=$type.GetMethod('KeVariant',[Reflection.BindingFlags]'Static,NonPublic');$b=0
for($day=1;$day -le 10000;$day++){if($variant.Invoke($null,@([ulong]123456,[int]$day)) -eq 'b'){$b++}}
Check ($b -gt 1800 -and $b -lt 2200) 'Unexpected daily variant distribution'
'PASS: all native asset edits, localized event/mail/quest text, idempotent spawns, sprites and daily variant weighting.'


