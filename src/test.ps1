$ErrorActionPreference='Stop'
$source=Get-Content "$PSScriptRoot/ModEntry.cs" -Raw
$source=$source.Replace('namespace KeniOctopus.QuestRuntime;', 'namespace KeniOctopus.QuestRuntime {') + "`n}"
$stubs=@'
namespace KeniOctopus.QuestRuntime { internal static class SurveyRuntime { internal static void Initialize(StardewModdingAPI.IModHelper h,string id){} } }
namespace KeniOctopus.QuestRuntime { internal static class ContentAssets { internal static void Initialize(StardewModdingAPI.IModHelper h){} } }
namespace HarmonyLib {
 public class Harmony { public Harmony(string id){} public void Patch(object m, HarmonyMethod postfix=null, HarmonyMethod prefix=null){} }
 public class HarmonyMethod { public HarmonyMethod(System.Type t,string n){} }
 public static class AccessTools { public static System.Reflection.MethodInfo Method(System.Type t,string n,System.Type[] a)=>null; public static System.Type TypeByName(string name)=>null; }
}
namespace StardewModdingAPI {
 public enum LogLevel { Error, Warn }
 public static class Context { public static bool IsWorldReady=true; public static int ScreenId; }
 public interface IModHelper { Events.EventsApi Events {get;} }
 public class Manifest { public string UniqueID="test"; }
 public class Logger { public void Log(string s,LogLevel l){} }
 public class TranslationHelper { public string Get(string key)=>key; }
 public class RegistryStub { public bool IsLoaded(string id)=>false; } public class HelperStub { public TranslationHelper Translation=new(); public RegistryStub ModRegistry=new(); }
 public abstract class Mod { public Manifest ModManifest=new(); public Logger Monitor=new(); public HelperStub Helper=new(); public abstract void Entry(IModHelper h); }
}
namespace StardewModdingAPI.Events {
 public class UpdateTickedEventArgs:System.EventArgs {} public class GameLaunchedEventArgs:System.EventArgs {}
 public class EventsApi { public Loop GameLoop=new(); }
 public class Loop { public event System.EventHandler<GameLaunchedEventArgs> GameLaunched; public event System.EventHandler<UpdateTickedEventArgs> UpdateTicked; public event System.EventHandler ReturnedToTitle; }
}
namespace StardewValley {
 public class Item { public string QualifiedItemId {get;set;} } public class Field<T> { public T Value; public Field(T v){Value=v;} }
 public class NPC { public string Name; public bool tryToReceiveActiveObject(Farmer p,bool probe)=>true; } public class Dialogue { public string Text; public Dialogue(NPC npc,string key,string text){Text=text;} } public static class Game1 { public static Farmer player=new(); public static int Sounds; public static string LastDialogue; public static void playSound(string s){Sounds++;} public static void DrawDialogue(Dialogue d){LastDialogue=d.Text;} }
 public class Farmer {
  public System.Collections.Generic.HashSet<string> mailReceived=new();
  public System.Collections.Generic.HashSet<string> Quests=new();
  public bool RejectAdd; public Item ActiveObject;
  public bool hasQuest(string id)=>Quests.Contains(id);
  public void addQuest(string id){if(!RejectAdd)Quests.Add(id);}
  public void removeQuest(string id)=>Quests.Remove(id);
 }
}
namespace StardewValley.Quests {
 public class Quest {
  public StardewValley.Field<string> id=new("");
  public StardewValley.Field<bool> completed=new(false);
  public bool OnFishCaught(string fishId,int numberCaught,int size,bool probe)=>false;
 }
}
'@
Add-Type -TypeDefinition ($source + $stubs) -IgnoreWarnings -WarningAction SilentlyContinue
$t=[KeniOctopus.QuestRuntime.ModEntry]
$hook=$t.GetMethod('AfterFishCaught',[Reflection.BindingFlags]'NonPublic,Static')
$tick=$t.GetMethod('OnUpdateTicked',[Reflection.BindingFlags]'NonPublic,Instance')
$mod=[Activator]::CreateInstance($t)
$q=[StardewValley.Quests.Quest]::new()
$first='Xinzh.KeniOctopus_Mystery'; $second='Xinzh.KeniOctopus_ShowWilly'; $fish='(O)Xinzh.KeniOctopus_Fish'
$q.id.Value=$first
function Tick { $tick.Invoke($mod,@($null,[StardewModdingAPI.Events.UpdateTickedEventArgs]::new())) }
function Catch([string]$id,[bool]$probe=$false,[int]$count=1) { $hook.Invoke($null,@($q,$id,$count,$probe)) }
function Assert([bool]$condition,[string]$message) { if(!$condition){throw $message} }
$p=[StardewValley.Game1]::player
$p.Quests.Add($first)|Out-Null
Catch $fish $true; Tick
Assert ($p.hasQuest($first)) 'Probe advanced quest'
Catch '(O)128'; Tick
Assert ($p.hasQuest($first)) 'Other fish advanced quest'
Catch $fish $false 0; Tick
Assert ($p.hasQuest($first)) 'Zero catch advanced quest'
$q.id.Value='other'; Catch $fish; Tick; $q.id.Value=$first
Assert ($p.hasQuest($first)) 'Other quest advanced'
Catch $fish
Assert ($p.hasQuest($first) -and !$p.hasQuest($second)) 'Mutated quest log inside callback'
[StardewModdingAPI.Context]::ScreenId=1; Tick
Assert ($p.hasQuest($first)) 'Transition leaked across screens'
[StardewModdingAPI.Context]::ScreenId=0; Tick
Assert (!$p.hasQuest($first) -and $p.hasQuest($second)) 'Correct catch did not transition'
Assert ($p.mailReceived.Contains('Xinzh.KeniOctopus_InvestigationCaught')) 'Missing persistent stage flag'
Catch $fish; Tick
Assert ($p.Quests.Count -eq 1) 'Repeated catch duplicated quest'
$p.Quests.Clear(); $p.Quests.Add($first)|Out-Null
$p.mailReceived.Add('Xinzh.KeniOctopus_InvestigationDone')|Out-Null
Catch $fish; Tick
Assert ($p.hasQuest($first) -and !$p.hasQuest($second)) 'Completed quest restarted'
$p.mailReceived.Clear(); $p.RejectAdd=$true
Catch $fish; Tick
Assert ($p.hasQuest($first)) 'Missing next-stage data destroyed original quest'
'PASS: 11 state-transition checks (isolated API stubs; not an in-game test).'
$lookup=$t.GetMethod('AfterLookupTypeValue',[Reflection.BindingFlags]'NonPublic,Static')
foreach($suffix in @('Ke','Konig','Soap','Ghost','Keegan')) {
 $item=[StardewValley.Item]::new(); $item.QualifiedItemId="(O)Xinzh.KeniOctopus_SeaHare$suffix"
 $argsForHook=[object[]]@($item,'鱼'); $lookup.Invoke($null,$argsForHook)
 Assert ($null -eq $argsForHook[1]) "Lookup category still visible: $suffix"
}
foreach($id in @('(O)128','(O)Xinzh.KeniOctopus_SeaHareNi','(O)812')) {
 $item=[StardewValley.Item]::new(); $item.QualifiedItemId=$id
 $argsForHook=[object[]]@($item,'original'); $lookup.Invoke($null,$argsForHook)
 Assert ($argsForHook[1] -eq 'original') "Unrelated category changed: $id"
}
'PASS: 8 lookup heading scope checks.'


$offer=$t.GetMethod('OnOfferToWilly',[Reflection.BindingFlags]'NonPublic,Static')
$t.GetField('Instance',[Reflection.BindingFlags]'NonPublic,Static').SetValue($null,$mod)
$p.RejectAdd=$false; $p.Quests.Clear(); $p.mailReceived.Clear()
$p.Quests.Add($second)|Out-Null
$p.mailReceived.Add('Xinzh.KeniOctopus_InvestigationCaught')|Out-Null
$held=[StardewValley.Item]::new();$held.QualifiedItemId=$fish;$p.ActiveObject=$held
$willy=[StardewValley.NPC]::new();$willy.Name='Willy'
$argsForOffer=[object[]]@($willy,$p,$true,$false)
$runOriginal=$offer.Invoke($null,$argsForOffer)
Assert (!$runOriginal -and $argsForOffer[3]) 'Probe did not report inspection acceptance'
Assert ($p.hasQuest($second) -and !$p.mailReceived.Contains('Xinzh.KeniOctopus_InvestigationDone') -and [StardewValley.Game1]::Sounds -eq 0) 'Probe changed quest state'
$argsForOffer=[object[]]@($willy,$p,$false,$false)
$runOriginal=$offer.Invoke($null,$argsForOffer)
Assert (!$runOriginal -and $argsForOffer[3] -and [object]::ReferenceEquals($held,$p.ActiveObject)) 'Manual inspection became a gift or consumed fish'
Assert (!$p.hasQuest($second) -and $p.mailReceived.Contains('Xinzh.KeniOctopus_InvestigationDone')) 'Manual inspection did not finish shared quest state'
Assert ([StardewValley.Game1]::LastDialogue -eq 'dialogue.willy.inspection.1') 'Missing completion dialogue'
$runOriginal=$offer.Invoke($null,$argsForOffer)
Assert ($runOriginal -and [StardewValley.Game1]::Sounds -eq 1 -and [object]::ReferenceEquals($held,$p.ActiveObject)) 'Repeated inspection consumed fish or completed twice'
# The shop event writes the same Done flag, so its completion must also allow normal gifting.
$p.Quests.Clear(); $p.mailReceived.Clear(); $p.mailReceived.Add('Xinzh.KeniOctopus_InvestigationCaught')|Out-Null; $p.mailReceived.Add('Xinzh.KeniOctopus_InvestigationDone')|Out-Null
Assert ($offer.Invoke($null,$argsForOffer)) 'Shop completion blocked normal gifting'
$willy.Name='Demetrius'; Assert ($offer.Invoke($null,$argsForOffer)) 'Intercepted another NPC'; $willy.Name='Willy'
$held.QualifiedItemId='(O)128'; Assert ($offer.Invoke($null,$argsForOffer)) 'Intercepted another fish'; $held.QualifiedItemId=$fish
$p.mailReceived.Clear(); Assert ($offer.Invoke($null,$argsForOffer)) 'Intercepted fish before quest capture'
$p.mailReceived.Add('Xinzh.KeniOctopus_InvestigationCaught')|Out-Null; $p.Quests.Add($second)|Out-Null
$argsForOffer[1]=[StardewValley.Farmer]::new(); Assert ($offer.Invoke($null,$argsForOffer)) 'Intercepted another player'
$data=Get-Content "$PSScriptRoot/../outputs/cod fishing mod/data.json" -Raw|ConvertFrom-Json -AsHashtable
$eventKey=@($data.Events.FishShop.Keys)[0]
Assert ($eventKey.Contains('!LocalMail Xinzh.KeniOctopus_InvestigationDone') -and $eventKey.Contains('HasItem (O)Xinzh.KeniOctopus_Fish')) 'Shop event does not share completion/possession checks'
Assert ($data.Events.FishShop[$eventKey].Contains('AddMail Current Xinzh.KeniOctopus_InvestigationDone received')) 'Shop event no longer completes shared flag'
$reward=@($data.TriggerActions|Where-Object Id -eq 'Xinzh.KeniOctopus_SendWillyReward')[0]
Assert ($reward.Trigger -eq 'DayEnding' -and $reward.Condition.Contains('!PLAYER_HAS_MAIL Current Xinzh.KeniOctopus_WillyReward') -and $reward.Actions[0].EndsWith(' tomorrow')) 'Reward lost its next-day/deduplication gate'
'PASS: manual inspection, probes, retained fish, repeat offers, NPC/player scope and shared shop/reward gates.'

