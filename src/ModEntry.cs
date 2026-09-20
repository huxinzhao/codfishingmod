using System;
using System.Collections.Generic;
using HarmonyLib;
using StardewModdingAPI;
using StardewModdingAPI.Events;
using StardewValley;
using StardewValley.Quests;

namespace KeniOctopus.QuestRuntime;

public sealed class ModEntry : Mod
{
    private const string FishId = "(O)Xinzh.KeniOctopus_Fish";
    private const string FirstQuest = "Xinzh.KeniOctopus_Mystery";
    private const string SecondQuest = "Xinzh.KeniOctopus_ShowWilly";
    private const string CaughtFlag = "Xinzh.KeniOctopus_InvestigationCaught";
    private const string DoneFlag = "Xinzh.KeniOctopus_InvestigationDone";
    private static readonly HashSet<int> PendingScreens = new();

    public override void Entry(IModHelper helper)
    {
        ContentAssets.Initialize(helper);
        new Harmony(ModManifest.UniqueID).Patch(
            AccessTools.Method(typeof(Quest), nameof(Quest.OnFishCaught),
                new[] { typeof(string), typeof(int), typeof(int), typeof(bool) }),
            postfix: new HarmonyMethod(typeof(ModEntry), nameof(AfterFishCaught)));
        helper.Events.GameLoop.UpdateTicked += OnUpdateTicked;
        helper.Events.GameLoop.ReturnedToTitle += (_, _) => PendingScreens.Clear();
        helper.Events.GameLoop.GameLaunched += OnGameLaunched;
        SurveyRuntime.Initialize(helper, ModManifest.UniqueID);
    }

    private void OnGameLaunched(object sender, GameLaunchedEventArgs e)
    {
        if (!Helper.ModRegistry.IsLoaded("Pathoschild.LookupAnything"))
            return;

        try
        {
            var type = AccessTools.TypeByName("Pathoschild.Stardew.LookupAnything.Framework.Lookups.Items.ItemSubject");
            var method = type == null ? null : AccessTools.Method(type, "GetTypeValue", new[] { typeof(Item) });
            if (method == null || method.ReturnType != typeof(string))
                throw new InvalidOperationException("Lookup Anything GetTypeValue method unavailable.");
            new Harmony(ModManifest.UniqueID).Patch(method,
                postfix: new HarmonyMethod(typeof(ModEntry), nameof(AfterLookupTypeValue)));
        }
        catch (Exception)
        {
            Monitor.Log(Helper.Translation.Get("warning.lookup-compatibility-unavailable"), LogLevel.Warn);
        }
    }

    // Hide only the lookup heading's category label; keep the real fish category intact.
    private static void AfterLookupTypeValue(Item __0, ref string __result)
    {
        if (__0?.QualifiedItemId is "(O)Xinzh.KeniOctopus_SeaHareKe"
            or "(O)Xinzh.KeniOctopus_SeaHareKonig"
            or "(O)Xinzh.KeniOctopus_SeaHareSoap"
            or "(O)Xinzh.KeniOctopus_SeaHareGhost"
            or "(O)Xinzh.KeniOctopus_SeaHareKeegan")
            __result = null;
    }

    // This callback is also used for probes. Never progress a quest during a probe.
    private static void AfterFishCaught(Quest __instance, string fishId, int numberCaught, bool probe)
    {
        if (!Context.IsWorldReady || probe || numberCaught < 1
            || (fishId != FishId && fishId != "Xinzh.KeniOctopus_Fish")
            || __instance.id.Value != FirstQuest || __instance.completed.Value
            || Game1.player.mailReceived.Contains(DoneFlag))
            return;

        // The game is iterating questLog here; defer changes until the next update.
        PendingScreens.Add(Context.ScreenId);
    }

    private void OnUpdateTicked(object sender, UpdateTickedEventArgs e)
    {
        if (!Context.IsWorldReady || !PendingScreens.Remove(Context.ScreenId))
            return;
        Farmer player = Game1.player;
        if (player.mailReceived.Contains(DoneFlag) || !player.hasQuest(FirstQuest))
            return;

        // Add the next stage first so a missing data entry never loses the old quest.
        if (!player.hasQuest(SecondQuest))
            player.addQuest(SecondQuest);
        if (!player.hasQuest(SecondQuest))
        {
            Monitor.Log(Helper.Translation.Get("error.inspection-quest-unavailable"), LogLevel.Error);
            return;
        }
        player.removeQuest(FirstQuest);
        if (!player.mailReceived.Contains(CaughtFlag))
            player.mailReceived.Add(CaughtFlag);
    }
}
