using System.Linq;
using HarmonyLib;
using StardewModdingAPI;
using StardewValley;
using StardewValley.Quests;

namespace KeniOctopus.QuestRuntime;

internal static class SurveyRuntime
{
    internal const string QuestId = "Xinzh.KeniOctopus_SeaHareResearch";
    private const string Intro = "Xinzh.KeniOctopus_SeaHareIntro";
    private const string Unlock = "Xinzh.KeniOctopus_SeaHareUnlocked";
    private const string Done = "Xinzh.KeniOctopus_SeaHareResearchDone";
    private const string ReturnMail = "Xinzh.KeniOctopus_SeaHareReturn";
    private const string DueKey = "Xinzh.KeniOctopus/SeaHareDueDay";
    private static readonly string[] Species = { "Ke", "Ni", "Keegan", "Konig", "Ghost", "Soap" };
    private static IModHelper Helper;

    internal static void Initialize(IModHelper helper, string harmonyId)
    {
        Helper = helper;
        var harmony = new Harmony(harmonyId);
        harmony.Patch(AccessTools.Method(typeof(NPC), nameof(NPC.tryToReceiveActiveObject),
            new[] { typeof(Farmer), typeof(bool) }),
            prefix: new HarmonyMethod(typeof(SurveyRuntime), nameof(OnDeliver)));
        harmony.Patch(AccessTools.PropertyGetter(typeof(Quest), "currentObjective"),
            postfix: new HarmonyMethod(typeof(SurveyRuntime), nameof(OnObjective)));
        helper.Events.GameLoop.DayEnding += (_, _) => Schedule();
        helper.Events.GameLoop.DayStarted += (_, _) => StartDay();
        helper.Events.GameLoop.SaveLoaded += (_, _) => StartDay();
    }

    private static string Flag(string phase, string species) => "Xinzh.KeniOctopus_SeaHare_" + phase + "_" + species;
    private static string GetSpecies(string id) => Species.FirstOrDefault(s => id == "(O)Xinzh.KeniOctopus_SeaHare" + s || id == "Xinzh.KeniOctopus_SeaHare" + s);
    private static Quest Active(Farmer player) => player.questLog.FirstOrDefault(q => q.id.Value == QuestId && !q.completed.Value);
    private static bool HasMail(Farmer p, string id) => p.mailReceived.Contains(id) || p.mailbox.Contains(id) || p.mailForTomorrow.Contains(id);

    private static void Schedule()
    {
        if (!Context.IsWorldReady) return;
        Farmer p = Game1.player;
        if (p.fishingLevel.Value >= 5 && !p.mailReceived.Contains(Unlock) && !p.modData.ContainsKey(DueKey))
        {
            p.modData[DueKey] = (Game1.Date.TotalDays + 1).ToString(System.Globalization.CultureInfo.InvariantCulture);
            if (!HasMail(p, Intro)) p.mailForTomorrow.Add(Intro);
        }
        if (p.mailReceived.Contains(Done) && !HasMail(p, ReturnMail))
            p.mailForTomorrow.Add(ReturnMail);
    }

    private static void StartDay()
    {
        if (!Context.IsWorldReady) return;

        Farmer p = Game1.player;
        if (p.modData.TryGetValue(DueKey, out string due) && int.TryParse(due, out int day) && Game1.Date.TotalDays >= day)
        {
            p.mailReceived.Add(Unlock);
            p.modData.Remove(DueKey);
            if (!HasMail(p, Intro) && !p.mailReceived.Contains(Done)) p.mailbox.Add(Intro);
        }
        // Recover a removed journal entry after its invitation has already been read.
        if (p.mailReceived.Contains(Intro) && !p.mailReceived.Contains(Done) && !p.hasQuest(QuestId))
            p.addQuest(QuestId);
        Quest active = Active(p);
        if (active != null && IsFinished(p)) Complete(p, active);
    }

    private static bool OnDeliver(NPC __instance, Farmer __0, bool __1, ref bool __result)
    {
        if (!Context.IsWorldReady || __instance.Name != "Demetrius" || __0 != Game1.player || __1) return true;
        Quest quest = Active(__0);
        string species = GetSpecies(__0.ActiveObject?.QualifiedItemId);
        if (quest == null || species == null) return true;
        __result = true;
        string message;
        if (__0.mailReceived.Contains(Flag("Delivered", species)))
            message = Helper.Translation.Get("survey.already-delivered");
        else
        {
            __0.reduceActiveItemByOne();
            __0.mailReceived.Add(Flag("Delivered", species));
            if (IsFinished(__0))
            {
                Complete(__0, quest);
                message = Helper.Translation.Get("dialogue.demetrius.complete");
            }
            else message = Helper.Translation.Get("dialogue.demetrius.sample");
        }
        Game1.DrawDialogue(new Dialogue(__instance, null, message));
        return false;
    }

    private static bool IsFinished(Farmer p) => Species.All(s => p.mailReceived.Contains(Flag("Delivered", s)));

    private static void Complete(Farmer p, Quest quest)
    {
        p.mailReceived.Add(Done);
        quest.moneyReward.Value = 5000;
        quest.questComplete();
        if (!HasMail(p, ReturnMail)) p.mailForTomorrow.Add(ReturnMail);
    }

    private static void OnObjective(Quest __instance, ref string __result)
    {
        if (!Context.IsWorldReady || __instance.id.Value != QuestId || __instance.completed.Value) return;
        __result = string.Join("\n", Species.Select(s => Helper.Translation.Get("survey.progress", new
        {
            fish = Helper.Translation.Get("fish.seahare." + s.ToLowerInvariant() + ".name").ToString(),
            delivered = Game1.player.mailReceived.Contains(Flag("Delivered", s)) ? 1 : 0
        }).ToString()));
    }

}

