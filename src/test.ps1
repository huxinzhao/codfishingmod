$ErrorActionPreference='Stop'
$source=Get-Content "$PSScriptRoot/ModEntry.cs" -Raw
$source=$source.Replace('namespace KeniOctopus.QuestRuntime;', 'namespace KeniOctopus.QuestRuntime {') + "`n}"
$stubs=@'
namespace KeniOctopus.QuestRuntime { internal static class SurveyRuntime { internal static void Initialize(StardewModdingAPI.IModHelper h,string id){} } }
namespace KeniOctopus.QuestRuntime { internal static class ContentAssets { internal static void Initialize(StardewModdingAPI.IModHelper h){} } }
namespace HarmonyLib {
 public class Harmony { public Harmony(string id){} public void Patch(object m, HarmonyMethod postfix){} }
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
 public static class Game1 { public static Farmer player=new(); }
 public class Farmer {
  public System.Collections.Generic.HashSet<string> mailReceived=new();
  public System.Collections.Generic.HashSet<string> Quests=new();
  public bool RejectAdd;
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


