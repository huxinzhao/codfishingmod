using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.Xna.Framework.Graphics;
using Newtonsoft.Json.Linq;
using StardewModdingAPI;
using StardewModdingAPI.Events;
using StardewValley;
using StardewValley.GameData;
using StardewValley.GameData.FishPonds;
using StardewValley.GameData.Locations;
using StardewValley.GameData.Objects;

namespace KeniOctopus.QuestRuntime;

internal static class ContentAssets
{
    private const string Prefix = "Mods/Xinzh.KeniOctopus/";
    private static readonly Regex TranslationToken = new(@"\{\{i18n:([^}]+)\}\}");
    private static IModHelper Helper;
    private static JObject Data;

    internal static void Initialize(IModHelper helper)
    {
        Helper = helper;
        Data = helper.Data.ReadJsonFile<JObject>("data.json")
            ?? throw new InvalidOperationException("Missing data.json.");
        helper.Events.Content.AssetRequested += OnAssetRequested;
        helper.Events.Content.LocaleChanged += (_, _) => RefreshLocalizedAssets();
        helper.Events.GameLoop.SaveLoaded += (_, _) =>
        {
            RefreshDailySprite();
            RefreshLocalizedAssets();
        };
        helper.Events.GameLoop.DayStarted += (_, _) => RefreshDailySprite();
        helper.Events.GameLoop.ReturnedToTitle += (_, _) => RefreshDailySprite();
    }

    private static void RefreshDailySprite() => Helper.GameContent.InvalidateCache(Prefix + "SeaHareKe");

    private static void RefreshLocalizedAssets()
    {
        // These assets contain resolved translations and may have been cached on the title screen.
        foreach (string asset in new[] { "Data/Objects", "Data/mail", "Data/Quests" })
            Helper.GameContent.InvalidateCache(asset);
        foreach (var npc in ((JObject)Data["GiftDialogue"]).Properties())
            Helper.GameContent.InvalidateCache("Characters/Dialogue/" + npc.Name);
        foreach (var location in ((JObject)Data["Events"]).Properties())
            Helper.GameContent.InvalidateCache("Data/Events/" + location.Name);
    }

    internal static string KeVariant(ulong saveId, int day)
    {
        // Stable per save and date, including reloads and multiplayer clients.
        int seed = unchecked((int)(saveId ^ (saveId >> 32)) * 397 ^ day * 7919);
        return new Random(seed).Next(5) == 0 ? "b" : "a";
    }

    private static T Read<T>(string section)
    {
        JToken source = Data;
        foreach (string part in section.Split('/')) source = source[part];
        JToken token = source.DeepClone();
        foreach (JValue value in ((JContainer)token).Descendants().OfType<JValue>().ToArray())
        {
            if (value.Type == JTokenType.String)
                value.Value = TranslationToken.Replace(value.Value<string>(), match => Helper.Translation.Get(match.Groups[1].Value).ToString());
        }
        return token.ToObject<T>();
    }

    private static void EditDictionary<T>(IAssetData asset, string section)
    {
        var target = asset.AsDictionary<string, T>().Data;
        foreach (var entry in Read<Dictionary<string, T>>(section)) target[entry.Key] = entry.Value;
    }

    private static void OnAssetRequested(object sender, AssetRequestedEventArgs e)
    {
        string name = e.NameWithoutLocale.Name;
        string sprite = name switch
        {
            Prefix + "Fish" => "assets/keni.png",
            Prefix + "SeaHareKe" => "assets/seahares/ke-" + KeVariant(Game1.uniqueIDForThisGame, Game1.Date.TotalDays) + ".png",
            Prefix + "SeaHareNi" => "assets/seahares/ni.png",
            Prefix + "SeaHareKeegan" => "assets/seahares/keegan.png",
            Prefix + "SeaHareKonig" => "assets/seahares/konig.png",
            Prefix + "SeaHareGhost" => "assets/seahares/ghost.png",
            Prefix + "SeaHareSoap" => "assets/seahares/soap.png",
            _ => null
        };
        if (sprite != null)
        {
            e.LoadFromModFile<Texture2D>(sprite, AssetLoadPriority.Exclusive);
            return;
        }
        switch (name)
        {
            case "Data/NPCGiftTastes":
                e.Edit(a =>
                {
                    var target = a.AsDictionary<string, string>().Data;
                    foreach (string section in new[] { "GiftLikes", "GiftLoves" })
                    foreach (var entry in Read<Dictionary<string, string[]>>(section))
                    {
                        if (!target.TryGetValue(entry.Key, out string original)) continue;
                        string[] fields = original.Split('/');
                        if (fields.Length < 10) continue;
                        var ids = new HashSet<string>(entry.Value);
                        foreach (int index in new[] { 1, 3, 5, 7, 9 })
                        {
                            var retained = fields[index].Split(' ', StringSplitOptions.RemoveEmptyEntries)
                                .Where(id => !ids.Contains(id.StartsWith("(O)") ? id.Substring(3) : id));
                            fields[index] = string.Join(" ", index == (section == "GiftLoves" ? 1 : 3) ? retained.Concat(entry.Value) : retained);
                        }
                        target[entry.Key] = string.Join("/", fields);
                    }
                });
                break;
            case "Data/Objects": e.Edit(a => EditDictionary<ObjectData>(a, "Objects")); break;
            case "Data/Fish": e.Edit(a => EditDictionary<string>(a, "Fish")); break;
            case "Data/mail": e.Edit(a => EditDictionary<string>(a, "Mail")); break;
            case "Data/Quests": e.Edit(a => EditDictionary<string>(a, "Quests")); break;
            case "Data/Locations":
                e.Edit(a =>
                {
                    var target = a.AsDictionary<string, LocationData>().Data;
                    foreach (var entry in Read<Dictionary<string, List<SpawnFishData>>>("Locations"))
                    {
                        if (!target.TryGetValue(entry.Key, out LocationData location)) continue;
                        location.Fish ??= new List<SpawnFishData>();
                        foreach (SpawnFishData fish in entry.Value)
                        {
                            location.Fish.RemoveAll(existing => existing.Id == fish.Id);
                            location.Fish.Add(fish);
                        }
                    }
                });
                break;
            case "Data/FishPondData":
                e.Edit(a =>
                {
                    var target = a.GetData<List<FishPondData>>();
                    foreach (var pond in Read<List<FishPondData>>("FishPonds"))
                    {
                        target.RemoveAll(existing => existing.Id == pond.Id);
                        target.Add(pond);
                    }
                });
                break;
            case "Data/TriggerActions":
                e.Edit(a =>
                {
                    var target = a.GetData<List<TriggerActionData>>();
                    foreach (var action in Read<List<TriggerActionData>>("TriggerActions"))
                    {
                        target.RemoveAll(existing => existing.Id == action.Id);
                        target.Add(action);
                    }
                });
                break;
            default:
                const string dialoguePrefix = "Characters/Dialogue/";
                if (name.StartsWith(dialoguePrefix, StringComparison.OrdinalIgnoreCase)
                    && Data["GiftDialogue"][name.Substring(dialoguePrefix.Length)] != null)
                    e.Edit(a => EditDictionary<string>(a, "GiftDialogue/" + name.Substring(dialoguePrefix.Length)));
                if (name.StartsWith("Data/Events/", StringComparison.OrdinalIgnoreCase) && Data["Events"][name.Substring(12)] != null)
                    e.Edit(a => EditDictionary<string>(a, "Events/" + name.Substring(12)));
                break;
        }
    }
}


