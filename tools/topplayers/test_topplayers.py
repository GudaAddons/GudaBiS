"""Offline tests for the top-players tool: python3 -m unittest discover tools/topplayers"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import aggregate  # noqa: E402
import build  # noqa: E402

SPEC = {"key": "PALADIN_PROTECTION", "class": "PALADIN", "specID": 66, "tree": 2, "name": "Protection"}


def entry(slot, item, enchant=None, gems=()):
    out = {"slot": {"type": slot}, "item": {"id": item}, "enchantments": None, "sockets": None}
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
        self.assertEqual(gear[1], {"item": 271483, "enchant": 8017, "enchantName": "Enchant 8017", "gems": []})
        self.assertEqual(gear[2]["gems"], [240969, 240970])
        self.assertNotIn(4, gear, "shirts are not listed")

    def test_enchant_name(self):
        self.assertEqual(aggregate.enchant_name(
            "Enchanted: Enchant Helm - Empowered Rune of Avoidance |A:Professions-ChatIcon:20:20|a"),
            "Enchant Helm - Empowered Rune of Avoidance")


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
