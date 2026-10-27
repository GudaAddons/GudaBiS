"""Offline tests for the data pipeline: python3 -m unittest discover tools/pipeline"""

import json
import os
import sys
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


def page(markup, slug="paladin-tank-za-phase-4-best-in-slot-gear-burning-crusade", updated="2026/10/18"):
    return (f'<link rel="canonical" href="https://www.wowhead.com/tbc/guide/{slug}">'
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
        self.assertEqual(slots[1], {"item": 32521, "enchant": 35447, "gems": [25896, 32196]})
        self.assertEqual(slots[2], {"item": 32362, "enchant": None, "gems": []})
        self.assertEqual(slots[5]["item"], 30991)
        self.assertEqual(slots[5]["enchant"], 27957)
        self.assertEqual(len(slots[5]["gems"]), 3)
        self.assertEqual(slots[6], {"item": 32342, "enchant": None, "gems": [32200, 32200]})
        self.assertEqual(slots[11]["item"], 32261)
        self.assertEqual(slots[12]["item"], 29172)
        self.assertEqual(slots[15]["item"], 33593)
        self.assertEqual(slots[17], {"item": 32375, "enchant": 34009, "gems": []})
        self.assertEqual(sorted(slots), [1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18])

    def test_rejects_unknown_version_and_truncation(self):
        with self.assertRaises(gearplanner.GearPlannerError):
            gearplanner.decode("BEYA")
        with self.assertRaises(gearplanner.GearPlannerError):
            gearplanner.decode(BALANCED[:-4])


class GuideTest(unittest.TestCase):
    def test_parse(self):
        guide = wowhead.parse(page(MARKUP))
        self.assertEqual(guide["spec"]["key"], "PALADIN_PROTECTION")
        self.assertEqual(guide["phase"], 4)
        self.assertEqual(guide["updated"], "2026-10-18")
        self.assertEqual([s["name"] for s in guide["sets"]], ["Balanced set", "Threat (Horde HitCap)"])
        self.assertEqual([s["faction"] for s in guide["sets"]], [None, "Horde"])
        self.assertEqual(guide["rows"][1], [32521, 30987])
        self.assertEqual(guide["rows"][11], [30083, 32261, 29172])
        self.assertEqual(guide["rows"][12], [30083, 32261, 29172])

    def test_lists_exclude_the_chosen_items_from_alts(self):
        made = build.lists_from_guide(wowhead.parse(page(MARKUP)))
        first = made[0]
        self.assertEqual(first["id"], "PALADIN_PROTECTION:4:1")
        self.assertEqual(first["alts"][1], [30987])
        self.assertEqual(first["alts"][11], [30083])
        self.assertEqual(first["alts"][12], [30083])

    def test_phase_slugs(self):
        self.assertEqual(wowhead._phase("paladin-tank-pre-raid-best-in-slot"), 0)
        with self.assertRaises(wowhead.GuideError):
            wowhead._phase("paladin-tank-best-in-slot")

    def test_unknown_spec_and_section(self):
        with self.assertRaises(specs.UnknownSpec):
            wowhead.parse(page(MARKUP, slug="shaman-elemental-phase-4-best-in-slot"))
        with self.assertRaises(wowhead.GuideError):
            wowhead.parse(page(MARKUP + '[h3 toc="Tabard"]x[/h3][tr][td]a[/td][td][item=1][/td]'))

    def test_render_is_lua_and_sorted(self):
        made = build.lists_from_guide(wowhead.parse(page(MARKUP)))
        text = build.render("TBC", 4, list(reversed(made)))
        self.assertIn('ns.Data:Register({', text)
        self.assertLess(text.index('"PALADIN_PROTECTION:4:1"'), text.index('"PALADIN_PROTECTION:4:2"'))
        self.assertIn("[1] = 32521,", text)
        self.assertIn("[1] = { 25896, 32196 },", text)
        self.assertNotIn("faction = nil", text)


if __name__ == "__main__":
    unittest.main()
