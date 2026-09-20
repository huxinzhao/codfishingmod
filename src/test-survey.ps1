$ErrorActionPreference='Stop'
$source=(Get-Content -LiteralPath "$PSScriptRoot/SurveyRuntime.cs" -Raw).Replace('namespace KeniOctopus.QuestRuntime;', 'namespace KeniOctopus.QuestRuntime {') + "`n}"
$stubs=@'
namespace HarmonyLib {
 public class Harmony { public Harmony(string id){} public void Patch(object m,HarmonyMethod prefix=null,HarmonyMethod postfix=null){} }
 public class HarmonyMethod { public HarmonyMethod(System.Type t,string n){} }
 public static class AccessTools { public static object Method(System.Type t,string n,System.Type[] p)=>null; public static object PropertyGetter(System.Type t,string n)=>null; }
}
namespace StardewModdingAPI {
 public static class Context {public static bool IsWorldReady=true; public static bool IsMainPlayer=true;}
 public class Text {string value; public Text(string v){value=v;} public override string ToString()=>value; public static implicit operator string(Text t)=>t.value;}
 public class Translation {public Text Get(string key,object tokens=null)=>new Text(key);}
 public interface IModHelper {EventApi Events{get;} Translation Translation{get;}}
 public class Helper:IModHelper {public EventApi Events{get;}=new(); public Translation Translation{get;}=new();}
 public class EventApi {public Loop GameLoop=new();}
 public class Loop {public event System.EventHandler DayEnding,DayStarted,SaveLoaded;}
}
namespace StardewValley {
 public class Field<T>{public T Value; public Field(T v){Value=v;}}
 public class Item{public string QualifiedItemId;}
 public class NPC {public string Name; public bool tryToReceiveActiveObject(Farmer p,bool probe)=>true;}
 public class Dialogue {public string Text; public Dialogue(NPC npc,string key,string text){Text=text;}} public class Date {public int TotalDays;}
 public static class Game1 {public static Farmer player=new(); public static Date Date=new(); public static string LastDialogue; public static void DrawDialogue(Dialogue d){LastDialogue=d.Text;} public static System.Collections.Generic.List<Farmer> Farmers=new(); public static System.Collections.Generic.IEnumerable<Farmer> getAllFarmers()=>Farmers;}
 public class Farmer {
 public Field<int> fishingLevel=new(0); public Item ActiveObject; public int Consumed;
 public System.Collections.Generic.List<Quests.Quest> questLog=new();
 public System.Collections.Generic.HashSet<string> mailReceived=new();
 public System.Collections.Generic.List<string> mailbox=new(),mailForTomorrow=new();
 public System.Collections.Generic.Dictionary<string,string> modData=new();
 public bool hasQuest(string id)=>questLog.Exists(q=>q.id.Value==id);
 public void addQuest(string id){questLog.Add(new Quests.Quest{id=new(id)});}
 public void reduceActiveItemByOne(){Consumed++; ActiveObject=null;}
 }
}
namespace StardewValley.Quests {
 public class Quest {public StardewValley.Field<string> id=new(""); public StardewValley.Field<bool> completed=new(false); public StardewValley.Field<int> moneyReward=new(0); public int Completions; public void questComplete(){completed.Value=true;Completions++;} public void OnFishCaught(string id,int count,int size,bool probe){} }
}
'@
Add-Type -TypeDefinition ($source+$stubs) -IgnoreWarnings -WarningAction SilentlyContinue
$type=[StardewValley.Game1].Assembly.GetType('KeniOctopus.QuestRuntime.SurveyRuntime')
function Call($name,[object[]]$values=@()){ $type.GetMethod($name,[Reflection.BindingFlags]'Static,NonPublic').Invoke($null,$values) }
function Check($ok,$message){if(-not $ok){throw $message}}
Call Initialize @([StardewModdingAPI.Helper]::new(),'test')
$p=[StardewValley.Game1]::player
[StardewValley.Game1]::Farmers.Add($p)
[StardewValley.Game1]::Date.TotalDays=20
$p.fishingLevel.Value=4; Call Schedule
Check ($p.mailForTomorrow.Count -eq 0) 'Level 4 triggered letter'
$p.fishingLevel.Value=5; Call Schedule; Call Schedule
Check ($p.mailForTomorrow.Count -eq 1) 'Letter absent or duplicated'
Call StartDay
Check (-not $p.mailReceived.Contains('Xinzh.KeniOctopus_SeaHareUnlocked')) 'Unlocked on threshold day'
[StardewValley.Game1]::Date.TotalDays=21; Call StartDay
Check ($p.mailReceived.Contains('Xinzh.KeniOctopus_SeaHareUnlocked')) 'Did not unlock next day'
Check (-not $p.hasQuest('Xinzh.KeniOctopus_SeaHareResearch')) 'Quest started before letter read'
$p.mailReceived.Add('Xinzh.KeniOctopus_SeaHareIntro')|Out-Null; Call StartDay
$q=$p.questLog[0]
$npc=[StardewValley.NPC]::new();$npc.Name='Demetrius'
function Catch($suffix,$probe=$false,$count=1){Call OnCatch @($q,"(O)Xinzh.KeniOctopus_SeaHare$suffix",$count,$probe)}
function Deliver($suffix,$probe=$false){$p.ActiveObject=[StardewValley.Item]::new();$p.ActiveObject.QualifiedItemId="(O)Xinzh.KeniOctopus_SeaHare$suffix"; Call OnDeliver @($npc,$p,$probe,$false)|Out-Null}
Catch Ke $true; Catch Ke $false 0
Check (-not $p.mailReceived.Contains('Xinzh.KeniOctopus_SeaHare_Caught_Ke')) 'Probe or zero catch counted'
Deliver Ke
Check ($p.Consumed -eq 0) 'Uncaught sample consumed'
Catch Ke; Deliver Ke $true
Check ($p.Consumed -eq 0) 'Probe consumed item'
Deliver Ke; Deliver Ke
Check ($p.Consumed -eq 1) 'Duplicate sample consumed'
foreach($s in @('Ni','Keegan','Konig','Ghost','Soap')){Catch $s;Deliver $s}
Check ($p.Consumed -eq 6 -and $q.completed.Value -and $q.moneyReward.Value -eq 5000) 'Wrong completion or reward'
Call Schedule;Call StartDay;Deliver Ke
Check ($q.Completions -eq 1 -and @($p.mailForTomorrow|Where-Object {$_ -eq 'Xinzh.KeniOctopus_SeaHareReturn'}).Count -eq 1) 'Duplicate completion or mail'
'PASS: survey level/date gates, letter acceptance, catches, probes, six deliveries and reward deduplication (isolated stubs).'


