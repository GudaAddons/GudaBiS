"""Offline tests for the data pipeline: python3 -m unittest discover tools/pipeline"""

import base64
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build  # noqa: E402
import gearplanner  # noqa: E402
import specs  # noqa: E402
import wowhead  # noqa: E402

# Balanced set of the TBC Protection Paladin Phase 4 guide (2026-10-18).
BALANCED = ("A0YT8FMFEwUAABIlIQXwUgUBEwAwH4FAfwmKdwBlKCB9xAIAfmqDQHkWcygAfcggfciFYHkPbTUAfcQgfcRAfd0GQH5W"
            "AH3IIH3IhyB5E3qMAH3IiEB99W0uAH3IIH3IiQB96G0KiiB5CWHwAH3EiwB-BW0UjABx9G0UDQCEJQ4AfHKPAIM5Yf6Q"
            "AHi-bUeRAH53hNkSAILg")

TITLE = "Protection Paladin Tank Phase 4 Best in Slot (BiS) Gear - Wowhead"
PALADIN_PROT = specs.lookup("Paladin", "Protection")


def code(raw):
    return base64.urlsafe_b64encode(bytes(raw)).decode().rstrip("=")


def page(markup, title=TITLE, updated="2026/10/18", author="Zephan"):
    byline = f'<script type="application/ld+json">{{"author":{{"@type":"Person","name":"{author}"}}}}</script>' if author else ""
    return (f"<title>{title}</title>" + byline +
            '<link rel="canonical" href="https://www.wowhead.com/tbc/guide/paladin-tank-phase-4">'
            f'Updated: <span class="date-tip" title="x">\n {updated} </span>'
            f"<script>WH.markup.printHtml({json.dumps(markup)});</script>")


MARKUP = (
    '[tabs name="BiS"][tab icon=x name="Balanced set"][gear-planner=paladin/human/' + BALANCED + '][/tab]'
    '[tab icon=y name="Threat (Horde HitCap)"][gear-planner=paladin/blood-elf/' + BALANCED + '][/tab][/tabs]'
    '[h3 toc="Aldor vs. Scryer"]x[/h3] prose [item=28889]'
    '[h3 toc="Head"]x[/h3][tr][td]Best[/td]\n[td][item=32521][/td][/tr][tr][td]Alt[/td]\n[td][item=30987][/td][/tr]'
    '[h3 toc="Rings"]x[/h3][tr][td]a[/td][td][item=30083][/td][/tr][tr][td]b[/td][td][item=32261][/td][/tr]'
    '[tr][td]c[/td][td][item=29172][/td][/tr]'
)


class GearPlannerTest(unittest.TestCase):
    def test_balanced_set(self):
        slots = gearplanner.decode(BALANCED)["slots"]
        self.assertEqual(slots[1], {"item": 32521, "enchant": 35447, "suffix": None, "gems": [25896, 32196]})
        self.assertEqual(slots[2], {"item": 32362, "enchant": None, "suffix": None, "gems": []})
        self.assertEqual(slots[5]["item"], 30991)
        self.assertEqual(slots[5]["enchant"], 27957)
        self.assertEqual(len(slots[5]["gems"]), 3)
        self.assertEqual(slots[6]["gems"], [32200, 32200])
        self.assertEqual(slots[11]["item"], 32261)
        self.assertEqual(slots[12]["item"], 29172)
        self.assertEqual(slots[15]["item"], 33593)
        self.assertEqual(slots[17]["enchant"], 34009)
        self.assertEqual(sorted(slots), [1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18])

    def test_high_item_bits_suffix_and_pet_block(self):
        raw = [3, 70, 1, 0xAA,
               0x00, 2, 0x11, 0x22, 0x01, 0x02,
               0x0D, 0x04, 0x4C, 0x8B,
               0x46, 0x00, 0x77, 0xD4, 0xFF, 0xDE]
        slots = gearplanner.decode(code(raw))["slots"]
        self.assertEqual(slots[13]["item"], 281739)
        self.assertEqual(slots[6], {"item": 30676, "enchant": None, "suffix": -34, "gems": []})

    def test_rejects_unknown_version_and_truncation(self):
        with self.assertRaises(gearplanner.GearPlannerError):
            gearplanner.decode("BEYA")
        with self.assertRaises(gearplanner.GearPlannerError):
            gearplanner.decode(BALANCED[:-4])


class SpecTest(unittest.TestCase):
    def test_folders(self):
        self.assertEqual(PALADIN_PROT["key"], "PALADIN_PROTECTION")
        self.assertEqual(PALADIN_PROT["specID"], 383)
        self.assertEqual(specs.lookup("Rogue", "")["key"], "ROGUE_DPS")
        self.assertEqual(specs.lookup("Warlock", "Afliction")["key"], "WARLOCK_AFFLICTION")
        self.assertIsNone(specs.lookup("Mage", "Fire")["specID"])
        with self.assertRaises(specs.UnknownSpec):
            specs.lookup("Monk", "Brewmaster")


class GuideTest(unittest.TestCase):
    def test_parse(self):
        guide = wowhead.parse(page(MARKUP), PALADIN_PROT, "4.htm")
        self.assertEqual(guide["phase"], 4)
        self.assertEqual(guide["updated"], "2026-10-18")
        self.assertEqual(guide["author"], "Zephan")
        self.assertEqual([s["name"] for s in guide["sets"]], ["Balanced set", "Threat"])
        self.assertEqual([s["faction"] for s in guide["sets"]], [None, "Horde"])
        self.assertEqual(guide["rows"][1], [32521, 30987])
        self.assertEqual(guide["rows"][11], [30083, 32261, 29172])
        self.assertEqual(guide["rows"][12], [30083, 32261, 29172])

    def test_author_from_the_page_and_none_for_the_host(self):
        self.assertIsNone(wowhead.parse(page(MARKUP, author="Wowhead"), PALADIN_PROT, "4.htm")["author"])
        self.assertIsNone(wowhead.parse(page(MARKUP, author=None), PALADIN_PROT, "4.htm")["author"])
        made = build.lists_from_guide(wowhead.parse(page(MARKUP), PALADIN_PROT, "4.htm"))
        self.assertEqual(made[0]["author"], "Zephan")
        self.assertIn('author = "Zephan",', build.render("TBC", 4, made))

    def test_title_must_match_folder(self):
        with self.assertRaises(wowhead.GuideError):
            wowhead.parse(page(MARKUP, title="Fire Mage DPS Phase 5"), PALADIN_PROT, "4.htm")
        arms = specs.lookup("Warrior", "Arms")
        self.assertEqual(wowhead.parse(page(MARKUP, title="Warrior DPS Phase 1"), arms, "x.htm")["phase"], 1)

    def test_phases(self):
        self.assertEqual(wowhead.phase_of("Holy Paladin Pre-Raid Best in Slot", "phase1.htm"), 0)
        self.assertEqual(wowhead.phase_of("Warrior Tank Resist Gear", "r.htm"), "res")
        self.assertEqual(wowhead.phase_of("Phase 3 Best in Slot", "1.htm"), 3)
        self.assertEqual(wowhead.phase_of("Best in Slot", "pre-bis.htm"), 0)
        self.assertEqual(wowhead.phase_of("Best in Slot", "phase2.htm"), 2)
        with self.assertRaises(wowhead.GuideError):
            wowhead.phase_of("Best in Slot", "guide.htm")

    def test_table_set_without_planner(self):
        markup = MARKUP.split("[/tabs]")[1]
        guide = wowhead.parse(page(markup, title="Protection Paladin Progression Phase 4"), PALADIN_PROT, "4.htm")
        gear_set = guide["sets"][0]
        self.assertEqual(gear_set["name"], "Progression")
        self.assertEqual(gear_set["slots"][1]["item"], 32521)
        self.assertEqual(gear_set["slots"][11]["item"], 30083)
        self.assertEqual(gear_set["slots"][12]["item"], 32261)

    def test_lists_exclude_the_chosen_items_from_alts(self):
        first = build.lists_from_guide(wowhead.parse(page(MARKUP), PALADIN_PROT, "4.htm"))[0]
        self.assertEqual(first["id"], "PALADIN_PROTECTION:4:1")
        self.assertEqual(first["alts"][1], [30987])
        self.assertEqual(first["alts"][11], [30083])
        self.assertEqual(first["alts"][12], [30083])

    def test_resistance_lists_belong_to_every_phase(self):
        guide = wowhead.parse(page(MARKUP, title="Protection Paladin Resistance Gear"), PALADIN_PROT, "r.htm")
        first = build.lists_from_guide(guide)[0]
        self.assertEqual(first["id"], "PALADIN_PROTECTION:res:1")
        self.assertIsNone(first["phase"])
        self.assertTrue(first["anyPhase"])

    def test_only_the_item_column_counts(self):
        markup = MARKUP + (
            '[h3 toc="Trinkets"]x[/h3]'
            '[tr][td background=c2][b]Rank[/b][/td][td][b]Item[/b][/td][td]Source[/td][/tr]'
            '[tr][td]Viable[/td]\n[td][item=24125][/td]\n[td][item=31358] - Jewelcrafting[/td][/tr]'
            '[tr][td]Great[/td]\n[td][item=29370][/td]\n[td]41[item=29434] - vendor[/td][/tr]'
        )
        rows = wowhead.parse(page(markup), PALADIN_PROT, "4.htm")["rows"]
        self.assertEqual(rows[13], [24125, 29370])
        self.assertNotIn(31358, rows[14])

    def test_unknown_section_is_a_warning(self):
        markup = MARKUP + '[h3 toc="Tabard"]x[/h3][tr][td]a[/td][td][item=1][/td][/tr]'
        guide = wowhead.parse(page(markup), PALADIN_PROT, "4.htm")
        self.assertEqual(guide["warnings"], ["unknown gear section 'tabard' skipped"])

    def test_render_is_lua_and_sorted(self):
        made = build.lists_from_guide(wowhead.parse(page(MARKUP), PALADIN_PROT, "4.htm"))
        text = build.render("TBC", 4, list(reversed(made)))
        self.assertIn('ns.Data:Register({', text)
        self.assertLess(text.index('"PALADIN_PROTECTION:4:1"'), text.index('"PALADIN_PROTECTION:4:2"'))
        self.assertIn("[1] = 32521,", text)
        self.assertIn("[1] = { 25896, 32196 },", text)
        self.assertNotIn("faction = nil", text)


class CollectTest(unittest.TestCase):
    def test_merges_numbers_and_skips(self):
        with tempfile.TemporaryDirectory() as root:
            folder = os.path.join(root, "Paladin", "Protection")
            os.makedirs(os.path.join(folder, "4_files"))
            same = '[tabs][tab name="Balanced (A)"][gear-planner=paladin/human/' + BALANCED + '][/tab][/tabs]'
            pages = {
                "4.htm": page(same),
                "4b.htm": page(same, title="Protection Paladin Phase 4 Alternative"),
                "dup.htm": page(same),
                "bad.htm": page(same, title="Fire Mage Phase 4"),
                os.path.join("4_files", "x.htm"): page(same),
            }
            for name, text in pages.items():
                with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                    handle.write(text)
            lists, report = build.collect(root)
        self.assertEqual([(e["id"], e["set"]) for e in lists],
                         [("PALADIN_PROTECTION:4:1", "Balanced"), ("PALADIN_PROTECTION:4:2", "Balanced #2")])
        self.assertTrue(any(line.startswith("SKIPPED Paladin") and "bad.htm" in line for line in report))
        self.assertTrue(any("dup.htm" in line and "same page" in line for line in report))


if __name__ == "__main__":
    unittest.main()
