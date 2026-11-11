"""Offline tests for the top-players tool: python3 -m unittest discover tools/topplayers"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import aggregate  # noqa: E402
import build  # noqa: E402

SPEC = {"key": "PALADIN_PROTECTION", "class": "PALADIN", "specID": 66, "tree": 2, "name": "Protection"}


def entry(slot, item, enchant=None, gems=(), level=None, bonus=None):
    out = {"slot": {"type": slot}, "item": {"id": item}, "enchantments": None, "sockets": None}
    if level:
        out["level"] = {"value": level}
    if bonus:
        out["bonus_list"] = bonus
    if enchant:
        out["enchantments"] = [{"enchantment_id": enchant, "enchantment_slot": {"type": "PERMANENT"},
                                "display_string": f"Enchanted: Enchant {enchant} |A:Quality-Tier2:20:20|a"}]
    if gems:
        out["sockets"] = [{"item": {"id": g}} for g in gems]
    return out


def player(*entries):
    return aggregate.equipped({"equipped_items": list(entries)})


class EquippedTest(unittest.TestCase):
    def test_reads_blizzard_equipment(self):
        gear = player(entry("HEAD", 271483, 8017), entry("NECK", 268265, gems=(240969, 240970)),
                      {"slot": {"type": "SHIRT"}, "item": {"id": 1}})
        self.assertEqual(gear[1], {"item": 271483, "level": None, "bonus": [], "enchant": 8017,
                                   "enchantName": "Enchant 8017", "gems": []})
        self.assertEqual(gear[2]["gems"], [240969, 240970])
        self.assertNotIn(4, gear, "shirts are not listed")

    def test_enchant_name(self):
        self.assertEqual(aggregate.enchant_name(
            "Enchanted: Enchant Helm - Empowered Rune of Avoidance |A:Professions-ChatIcon:20:20|a"),
            "Enchant Helm - Empowered Rune of Avoidance")
        self.assertEqual(aggregate.enchant_name("|cnIQ4:Ancient Hash'ey Battle Art: Heat Wave|r"),
                         "Ancient Hash'ey Battle Art: Heat Wave")
        self.assertEqual(aggregate.enchant_name("+41 Agility/Strength & +115 Stamina"),
                         "+41 Agility/Strength & +115 Stamina")


class BuildListTest(unittest.TestCase):
    def build(self, players):
        return aggregate.build_list(SPEC, players, "Midnight Season 2", "2026-10-28")

    def test_most_worn_first_alternatives_over_ten_percent(self):
        players = ([player(entry("HEAD", 100, 8017))] * 6 + [player(entry("HEAD", 101, 8017))] * 3
                   + [player(entry("HEAD", 102, 9000))])
        made = self.build(players)
        self.assertEqual(made["items"][1], 100)
        self.assertEqual(made["alts"][1], [101, 102])
        self.assertEqual(made["usage"][1], [6, 3, 1])
        self.assertEqual(made["enchantIDs"][1], 8017)
        self.assertEqual(made["enchantNames"][1], "Enchant 8017")
        self.assertEqual(made["players"], 10)
        self.assertEqual(made["id"], "PALADIN_PROTECTION:mplus")
        self.assertTrue(made["anyPhase"])

    def test_item_levels_are_the_highest_seen_for_listed_items(self):
        players = ([player(entry("HEAD", 100, level=334))] * 5 + [player(entry("HEAD", 100, level=320))] * 4
                   + [player(entry("HEAD", 101, level=340))] * 2 + [player(entry("HEAD", 102, level=350))])
        made = self.build(players)
        self.assertEqual(made["itemLevels"][100], 334, "the #1 at its highest")
        self.assertEqual(made["itemLevels"][101], 340, "an alternative too")
        self.assertNotIn(102, made["itemLevels"], "not listed (under 10 %), not kept")

    def test_bonus_ids_of_the_highest_level_copy(self):
        players = ([player(entry("HEAD", 100, level=320, bonus=[1, 2]))] * 3
                   + [player(entry("HEAD", 100, level=334, bonus=[1, 9, 12]))] * 2)
        made = self.build(players)
        self.assertEqual(made["itemBonuses"][100], [1, 9, 12])

    def test_rings_share_a_count_and_never_repeat(self):
        players = ([player(entry("FINGER_1", 10), entry("FINGER_2", 20))] * 5
                   + [player(entry("FINGER_1", 20), entry("FINGER_2", 30))] * 3)
        made = self.build(players)
        self.assertEqual(made["items"][11], 20, "worn by all 8, over both slots")
        self.assertEqual(made["items"][12], 10)
        self.assertEqual(made["alts"].get(11), [30])
        self.assertEqual(made["alts"].get(12), [30])
        self.assertNotIn(10, made["alts"].get(11, []))

    def test_off_hand_only_when_half_carry_one(self):
        two_hand = [player(entry("MAIN_HAND", 500))] * 6
        made = self.build(two_hand + [player(entry("MAIN_HAND", 501), entry("OFF_HAND", 600))] * 4)
        self.assertNotIn(17, made["items"])
        made = self.build([player(entry("MAIN_HAND", 501), entry("OFF_HAND", 600))] * 6 + two_hand[:4])
        self.assertEqual(made["items"][17], 600)

    def test_gems_from_players_wearing_the_number_one(self):
        players = ([player(entry("NECK", 1, gems=(7, 8)))] * 3 + [player(entry("NECK", 1, gems=(7, 9)))]
                   + [player(entry("NECK", 2, gems=(5, 5)))] * 2)
        made = self.build(players)
        self.assertEqual(made["gems"][2], [7, 8])

    def test_a_socket_few_wearers_have_is_left_out(self):
        players = [player(entry("WRIST", 1, gems=(7, 9)))] + [player(entry("WRIST", 1, gems=(7,)))] * 3
        made = self.build(players)
        self.assertEqual(made["gems"][9], [7], "the blacksmith socket of one player is not listed")

    def test_render_is_lua(self):
        made = self.build([player(entry("HEAD", 100, 8017))])
        text = build.render([made], "Midnight Season 2", "2026-10-28")
        self.assertIn('flavor = "Retail",', text)
        self.assertIn('id = "PALADIN_PROTECTION:mplus",', text)
        self.assertIn('enchantNames = {', text)
        self.assertIn('season = "Midnight Season 2",', text)

    def test_character_paths_are_encoded(self):
        region, path = build.character_path(("kr", "아즈샤라", "테스트"), "equipment")
        self.assertEqual(region, "kr")
        self.assertTrue(path.isascii())
        self.assertTrue(path.endswith("/equipment"))
        _, path = build.character_path(("eu", "zirkel-des-cenarius", "êlune"), "mythic-keystone-profile")
        self.assertIn("/zirkel-des-cenarius/%C3%AAlune/", path)

    def test_season_label(self):
        self.assertEqual(build.season_label("Mythic+ Dungeons (Midnight Season 2)"), "Midnight Season 2")


if __name__ == "__main__":
    unittest.main()


class EraTest(unittest.TestCase):
    def setUp(self):
        import era
        self.era = era

    def test_specs_cover_every_era_class_with_their_talent_tab(self):
        made = {s["key"]: s for s in self.era.specs()}
        self.assertEqual(len(made), 28)
        self.assertEqual(made["WARRIOR_FURY"]["tree"], 2)
        self.assertEqual(made["DRUID_GUARDIAN"]["tree"], 2)
        self.assertEqual(made["ROGUE_COMBAT"]["wclSpec"], "Combat")
        self.assertNotIn("DEATHKNIGHT_BLOOD", made)

    def test_ranking_gear_is_in_slot_order(self):
        gear = self.era.gear_from_ranking({"gear": [{"id": 12640}, {"id": 23053}, {"id": 0}, {"id": 4335},
                                                    {"id": 23000}] + [{"id": 0}] * 12 + [{"id": 22812}]})
        self.assertEqual(gear[1]["item"], 12640, "head")
        self.assertEqual(gear[2]["item"], 23053, "neck")
        self.assertNotIn(3, gear, "empty shoulder")
        self.assertEqual(gear[18]["item"], 22812, "ranged")

    def test_phase_list_and_labels(self):
        players = [{1: {"item": 12640, "level": None, "bonus": [], "enchant": 2543, "enchantName": "+4 Haste",
                        "gems": []}, 18: {"item": 22812, "level": None, "bonus": [], "enchant": None,
                                          "enchantName": None, "gems": []}}] * 3
        spec = {"key": "WARRIOR_FURY", "class": "WARRIOR", "tree": 2}
        made = aggregate.build_list(spec, players, None, "2026-10-28", set_name="Top 50 raiders",
                                    suffix="top:6", phase=6)
        self.assertEqual(made["id"], "WARRIOR_FURY:top:6")
        self.assertEqual(made["phase"], 6)
        self.assertIsNone(made["anyPhase"])
        self.assertEqual(made["items"][18], 22812, "ranged slot listed")
        text = self.era.render([made], "2026-10-28")
        self.assertIn('flavor = "Vanilla",', text)
        self.assertIn("defaultPhase = 6,", text)
        self.assertIn('[2] = "Phase 1-2"', text)
        self.assertIn("phase = 6,", text)


class MistsTest(unittest.TestCase):
    def setUp(self):
        import mists
        self.mists = mists

    def test_specs_use_the_specialization_order(self):
        made = {s["key"]: s for s in self.mists.specs()}
        self.assertEqual(len(made), 34)
        self.assertEqual(made["DRUID_RESTORATION"]["tree"], 4)
        self.assertEqual(made["MONK_WINDWALKER"]["tree"], 2)
        self.assertEqual(made["DEATHKNIGHT_BLOOD"]["wclClass"], "DeathKnight")

    def test_ranking_gear_carries_level_enchant_and_gems(self):
        gear = self.mists.gear_from_ranking({"gear": [
            {"id": 99379, "itemLevel": "574", "gems": [{"id": "95346"}, {"id": "76671"}]},
            {"id": 0, "itemLevel": "0"},
            {"id": 99373, "itemLevel": "580", "permanentEnchant": "4803"},
        ]})
        self.assertEqual(gear[1], {"item": 99379, "level": 574, "bonus": [], "enchant": None,
                                   "enchantName": None, "gems": [95346, 76671]})
        self.assertNotIn(2, gear)
        self.assertEqual(gear[3]["enchant"], 4803)
        self.assertEqual(gear[3]["level"], 580)

    def test_render_has_gems_and_item_levels(self):
        players = [{1: {"item": 99379, "level": 574, "bonus": [], "enchant": 4803, "enchantName": None,
                        "gems": [95346]}}] * 3
        spec = {"key": "PALADIN_RETRIBUTION", "class": "PALADIN", "tree": 3}
        made = aggregate.build_list(spec, players, None, "2026-10-29", set_name="Top 50 raiders",
                                    suffix="top:5", phase=5)
        text = self.mists.render([made], "2026-10-29")
        self.assertIn('flavor = "Mists",', text)
        self.assertIn("defaultPhase = 5,", text)
        self.assertIn('[3] = "Phase 3"', text)
        self.assertIn("itemLevels = {", text)
        self.assertIn("gems = {", text)


class WowSimsTest(unittest.TestCase):
    def setUp(self):
        import mists
        import wowsims
        self.wowsims = wowsims
        self.trees = {spec["key"]: spec for spec in mists.specs()}
        self.db = {"phase": {1: 1, 2: 5, 3: 3}, "reforge": {167: ("MASTERY_RATING", "HASTE_RATING")},
                   "enchant": {4803: "Greater Tiger Fang Inscription"}}

    def gear(self, newest):
        items = [{"id": newest, "enchant": 4803, "gems": [76671], "reforging": 167}]
        return {"items": items + [{"id": 1}] * 14 + [{}]}

    def make(self, path, newest=2):
        return self.wowsims.list_from_set(path, self.gear(newest), self.db, self.trees, "2026-10-29")

    def test_names(self):
        self.assertEqual(self.wowsims.set_name("p5_offensive.gear.json"), ("BiS Offensive", False, True))
        self.assertEqual(self.wowsims.set_name("preraid_fury_tg.gear.json"), ("Pre-Raid Titan's Grip", True, True))
        self.assertEqual(self.wowsims.set_name("p1-prebis.gear.json"), ("Pre-Raid", True, False))
        self.assertEqual(self.wowsims.set_name("p2_bis_dw.gear.json"), ("BiS Dual Wield", False, True))

    def test_phase_from_the_name_and_slots_in_order(self):
        made = self.make("ui/specs/paladin/retribution/gear_sets/p5.gear.json")
        self.assertEqual(made["phase"], 5)
        self.assertEqual(made["id"], "PALADIN_RETRIBUTION:sim:5:04:p5")
        self.assertEqual(made["author"], "WoWSims")
        self.assertEqual(made["items"][1], 2, "head")
        self.assertEqual(made["items"][15], 1, "the fourth WoWSims slot is the back")
        self.assertNotIn(17, made["items"], "empty off hand")
        self.assertEqual(made["reforges"][1], ["MASTERY_RATING", "HASTE_RATING"])
        self.assertEqual(made["enchantNames"][1], "Greater Tiger Fang Inscription")

    def test_pre_raid_phase_1_and_phase_2_named(self):
        self.assertEqual(self.make("ui/specs/paladin/retribution/gear_sets/preraid.gear.json", 1)["phase"], 1)
        made = self.make("ui/specs/paladin/protection/gear_sets/p2_balanced.gear.json", 1)
        self.assertEqual((made["phase"], made["set"]), (2, "BiS Balanced Phase 2"))
        self.assertEqual(self.make("ui/specs/druid/balance/gear_sets/t14.gear.json", 1)["set"], "BiS")

    def test_stale_and_partial_sets_are_left_out(self):
        self.assertIsNone(self.make("ui/specs/priest/holy/gear_sets/p4.gear.json", 1), "Phase 1 gear named p4")
        self.assertIsNone(self.make("ui/specs/druid/feral/gear_sets/p1_item_swap.gear.json"))
        partial = {"items": [{"id": 2}] * 3}
        self.assertIsNone(self.wowsims.list_from_set("ui/specs/paladin/holy/gear_sets/p1.gear.json",
                                                     partial, self.db, self.trees, "2026-10-29"))
        self.assertIsNone(self.make("ui/specs/demon_hunter/havoc/gear_sets/p1.gear.json"), "no such spec in MoP")

    def test_a_set_with_older_expansion_gear_is_left_out(self):
        gear = self.gear(2)
        gear["items"][1] = {"id": 59359}
        self.assertIsNone(self.wowsims.list_from_set("ui/specs/death_knight/blood/gear_sets/preraid.gear.json",
                                                     gear, self.db, self.trees, "2026-10-29"))


class ForeverTest(unittest.TestCase):
    """forever.py: wowtbc.gg's Warcraft Forever page data -> lists per level cap."""

    @classmethod
    def setUpClass(cls):
        import forever
        cls.forever = forever

    def context(self, caps, gear=(), cls="warrior"):
        return {"bisList": {"class": cls, "spec": "fury", "caps": caps}, "gearData": list(gear)}

    def test_rank_order_pairs_and_alternatives(self):
        caps = {"60": {"head": [1, 2, 3], "finger": [10, 11, 12, 13], "trinket": [20],
                       "main-hand": [30, 31], "off-hand": []}}
        made = self.forever.lists_for("fury-warrior", self.context(caps), "2026-11-11")
        self.assertEqual(len(made), 1)
        entry = made[0]
        self.assertEqual(entry["id"], "WARRIOR_FURY:60")
        self.assertEqual((entry["class"], entry["tree"], entry["phase"], entry["set"]), ("WARRIOR", 2, 60, "BiS"))
        self.assertIsNone(entry["faction"])
        self.assertEqual(entry["items"][1], 1)
        self.assertEqual(entry["alts"][1], [2, 3])
        self.assertEqual((entry["items"][11], entry["items"][12]), (10, 11), "#1 and #2 fill the pair")
        self.assertEqual(entry["alts"][11], [12, 13])
        self.assertNotIn(12, entry["alts"], "written once, on the first ring slot")
        self.assertEqual(entry["items"][13], 20)
        self.assertNotIn(14, entry["items"], "one trinket listed")
        self.assertNotIn(17, entry["items"], "no off hand listed")
        self.assertEqual(entry["items"][16], 30)

    def test_two_handers_rank_after_the_main_hand(self):
        caps = {"60": {"main-hand": [30, 31], "two-hand": [40, 30]}, "50": {"two-hand": [41]}}
        made = {m["phase"]: m for m in self.forever.lists_for("fury-warrior", self.context(caps), "d")}
        self.assertEqual(made[60]["items"][16], 30)
        self.assertEqual(made[60]["alts"][16], [31, 40])
        self.assertEqual(made[50]["items"][16], 41, "no one-handers listed")

    def test_one_faction_items_split_the_list(self):
        caps = {"20": {"head": [5, 6, 7]}, "30": {"head": [8]}}
        gear = [{"id": 5, "source_type": "Quest (Alliance)"}, {"id": 6, "source_type": "Quest (Horde)"},
                {"id": 7, "source_type": "Quest"}]
        made = {m["id"]: m for m in self.forever.lists_for("fury-warrior", self.context(caps, gear), "d")}
        self.assertEqual(sorted(made), ["WARRIOR_FURY:20:Alliance", "WARRIOR_FURY:20:Horde", "WARRIOR_FURY:30"])
        self.assertEqual(made["WARRIOR_FURY:20:Alliance"]["items"][1], 5)
        self.assertEqual(made["WARRIOR_FURY:20:Alliance"]["alts"][1], [7])
        self.assertEqual(made["WARRIOR_FURY:20:Horde"]["items"][1], 6)
        self.assertEqual(made["WARRIOR_FURY:20:Horde"]["faction"], "Horde")

    def test_shared_tab_specs_are_named(self):
        made = self.forever.lists_for("shockadin-paladin", self.context({"60": {"head": [1]}}, cls="paladin"), "d")
        self.assertEqual((made[0]["spec"], made[0]["tree"], made[0]["set"]), ("PALADIN_SHOCKADIN", 1, "Shockadin"))
        made = self.forever.lists_for("feral-tank-druid", self.context({"60": {"head": [1]}}, cls="druid"), "d")
        self.assertEqual((made[0]["spec"], made[0]["tree"]), ("DRUID_FERAL_TANK", 2))

    def test_wrong_class_or_unknown_slot_stops_the_build(self):
        with self.assertRaises(self.forever.SourceError):
            self.forever.lists_for("fury-warrior", self.context({"60": {"head": [1]}}, cls="mage"), "d")
        with self.assertRaises(self.forever.SourceError):
            self.forever.lists_for("fury-warrior", self.context({"60": {"shirt": [1]}}), "d")

    def test_every_site_spec_maps_to_a_class_tab(self):
        self.assertEqual(len(self.forever.SPECS), 29)
        for slug, (key, tree, _) in self.forever.SPECS.items():
            self.assertIn(tree, (1, 2, 3), slug)
            self.assertTrue(slug.endswith("-" + key.split("_")[0].lower()), slug)

    def test_render_registers_level_phases(self):
        made = self.forever.lists_for("fury-warrior", self.context({"60": {"head": [1, 2]}}), "2026-11-11")
        text = self.forever.render(made, "2026-11-11")
        self.assertIn('flavor = "Forever"', text)
        self.assertIn('phaseKind = "level"', text)
        self.assertIn("pairsShareAlts = true", text)
        self.assertIn('id = "WARRIOR_FURY:60"', text)
        self.assertIn("alts = {", text)


class ForeverFactionTest(unittest.TestCase):
    """forever.py: PvP and battleground gear belongs to one faction though the site says not."""

    @classmethod
    def setUpClass(cls):
        import forever
        cls.forever = forever

    def faction(self, name, item_id=272000, source=None, set_name=None):
        return self.forever.pvp_faction({"id": item_id, "name": name, "source": source, "set": set_name})

    def test_rank_titles(self):
        self.assertEqual(self.faction("Premier Field Marshal's Chevalier Faceguard"), "Alliance")
        self.assertEqual(self.faction("Premier Marshal's Chevalier Pauldrons"), "Alliance")
        self.assertEqual(self.faction("Premier Grand Marshal's Barricade"), "Alliance")
        self.assertEqual(self.faction("Premier High Warlord's Battle Mace"), "Horde")
        self.assertEqual(self.faction("Premier Lieutenant General's Plate"), "Horde")
        self.assertEqual(self.faction("Premier Sergeant's Cape"), "Alliance")
        self.assertEqual(self.faction("Premier Sergeant's Cloak"), "Horde")
        self.assertEqual(self.faction("First Sergeant's Plate Bracers"), "Horde", "new ID, no source")

    def test_old_items_with_rank_like_names_stay_both(self):
        self.assertIsNone(self.faction("General's Ceremonial Plate", 12970))
        self.assertIsNone(self.faction("Champion's Legplates", 250598, "Blacksmithing"))
        self.assertIsNone(self.faction("Grunt's Pauldrons", 15513, "World drop"))
        self.assertIsNone(self.faction("Medallion of Grand Marshal Morris", 13091, "World drop"))

    def test_battleground_sources_and_sets(self):
        self.assertEqual(self.faction("Defiler's Talisman", 20072, "The Defilers - Friendly"), "Horde")
        self.assertEqual(self.faction("Highlander's Plate Girdle", 20041, "The League of Arathor - Honored"), "Alliance")
        self.assertEqual(self.faction("Frostwolf Advisor's Cloak", 19085, "Grunnda Wolfheart"), "Horde")
        self.assertEqual(self.faction("Legionnaire's Band", 19510, "Kelm Hargunth"), "Horde")
        self.assertEqual(self.faction("Premier Chevalier Gauntlets", set_name="Lieutenant Commander's Vindication"), "Alliance")

    def test_pvp_items_split_the_list(self):
        caps = {"60": {"head": [1, 2], "main-hand": [3, 4]}}
        gear = [{"id": 1, "name": "Premier Field Marshal's Chevalier Faceguard"},
                {"id": 2, "name": "Enriched Thorium Helm", "source": "Blacksmithing", "source_type": "Crafted"},
                {"id": 3, "name": "Premier High Warlord's Battle Mace"},
                {"id": 4, "name": "Sageblade", "source": "Blacksmithing", "source_type": "Crafted"}]
        context = {"bisList": {"class": "paladin", "caps": caps}, "gearData": gear}
        made = {m["faction"]: m for m in self.forever.lists_for("protection-paladin", context, "d")}
        self.assertEqual((made["Horde"]["items"][1], made["Horde"]["items"][16]), (2, 3))
        self.assertEqual((made["Alliance"]["items"][1], made["Alliance"]["items"][16]), (1, 4))
        self.assertEqual(made["Horde"]["treeName"], "Protection")
