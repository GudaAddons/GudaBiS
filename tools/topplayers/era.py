"""Build Data/Vanilla/Lists.lua (the Classic Era TOC's data) from what the top raiders of
each spec wore in each phase of 2019 Classic, from Warcraft Logs (GB-101).

Usage (WSL; the key file is described in wcl.py):
  python3 -B tools/topplayers/era.py --check     # the key works: points left this hour
  python3 -B tools/topplayers/era.py

Warcraft Logs keeps the 2019 Classic raids (zones 1000-1006, classic.warcraftlogs.com)
partitioned by phase, and its rankings can carry each player's gear as worn in that
kill. Per phase the rankings of its last boss give the top 50 players of every spec with
their gear in one query (author, 2026-10-28):
  Phase 1-2  Ragnaros (Molten Core)         partition "P1 & P2"
  Phase 3-4  Nefarian (Blackwing Lair)      partition "P3 & P4"
  Phase 5    C'Thun (Temple of Ahn'Qiraj)   partition "P5"
  Phase 6    Kel'Thuzad (Naxxramas)         partition "P6"
Rankings carry no enchants, so those come from the raid reports of the top
ENCHANT_SAMPLE players (one report covers everyone in that fight, and reports are
cached). The counting is aggregate.py's, the same as Retail's. Pre-Raid gear cannot come
from raid logs; it stays a later addition from saved Wowhead pages.

The output is sorted, so an unchanged result gives no diff. Never edit it by hand
(RULES.md Rule 7): change the tool and rerun it.
"""

import argparse
import datetime
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import aggregate  # noqa: E402
import api  # noqa: E402
import build  # noqa: E402
import wcl  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA_DIR = "/mnt/g/addon-data/GudaBis"
TOP = 50
ENCHANT_SAMPLE = 10

# GudaBiS phase number, its label, the Warcraft Logs zone, boss and partition.
PHASES = [
    {"phase": 2, "label": "Phase 1-2", "zone": 1000, "boss": "Ragnaros", "partition": 1},
    {"phase": 4, "label": "Phase 3-4", "zone": 1002, "boss": "Nefarian", "partition": 2},
    {"phase": 5, "label": "Phase 5", "zone": 1005, "boss": "C'Thun", "partition": 3},
    {"phase": 6, "label": "Phase 6", "zone": 1006, "boss": "Kel'Thuzad", "partition": 5},
]
DEFAULT_PHASE = 6

# Warcraft Logs class and spec names -> talent tab (the tree with the most points picks
# the default list on Era). Feral and Guardian are both the second tab.
TREES = {
    "Druid": {"Balance": 1, "Feral": 2, "Guardian": 2, "Restoration": 3},
    "Hunter": {"BeastMastery": 1, "Marksmanship": 2, "Survival": 3},
    "Mage": {"Arcane": 1, "Fire": 2, "Frost": 3},
    "Paladin": {"Holy": 1, "Protection": 2, "Retribution": 3},
    "Priest": {"Discipline": 1, "Holy": 2, "Shadow": 3},
    "Rogue": {"Assassination": 1, "Combat": 2, "Subtlety": 3},
    "Shaman": {"Elemental": 1, "Enhancement": 2, "Restoration": 3},
    "Warlock": {"Affliction": 1, "Demonology": 2, "Destruction": 3},
    "Warrior": {"Arms": 1, "Fury": 2, "Protection": 3},
}

FIELD_ORDER = ["id", "spec", "class", "tree", "phase", "set", "players", "updated",
               "items", "enchantIDs", "enchantNames", "alts", "usage"]


def specs():
    out = []
    for class_name, trees in TREES.items():
        for spec_name, tree in trees.items():
            out.append({"key": f"{class_name.upper()}_{spec_name.upper()}", "class": class_name.upper(),
                        "tree": tree, "wclClass": class_name, "wclSpec": spec_name})
    return out


def boss_id(client, zone, name):
    data = client.query(f"{{ worldData {{ zone(id: {zone}) {{ encounters {{ id name }} }} }} }}")
    for encounter in data["worldData"]["zone"]["encounters"]:
        if encounter["name"] == name:
            return encounter["id"]
    raise api.ApiError(f"no boss {name} in zone {zone}")


def rankings(client, encounter, spec, partition):
    data = client.query(
        f'{{ worldData {{ encounter(id: {encounter}) {{ characterRankings(className: "{spec["wclClass"]}", '
        f'specName: "{spec["wclSpec"]}", partition: {partition}, includeCombatantInfo: true) }} }} }}')
    ranked = (data["worldData"]["encounter"]["characterRankings"] or {}).get("rankings") or []
    seen, out = set(), []
    for entry in ranked:
        key = (entry.get("name"), (entry.get("server") or {}).get("id"))
        if key in seen or not entry.get("gear"):
            continue
        seen.add(key)
        out.append(entry)
    return out[:TOP]


def gear_from_ranking(entry):
    """A ranking's gear (a list in slot order, no enchants) -> aggregate.equipped() shape."""
    out = {}
    for index, item in enumerate(entry.get("gear") or []):
        item_id = (item or {}).get("id")
        if item_id:
            out[index + 1] = {"item": item_id, "level": None, "bonus": [], "enchant": None,
                              "enchantName": None, "gems": []}
    return out


def enchants_from_report(client, entry):
    """{INVSLOT: (enchantID, name)} for one ranked player, from that kill's report."""
    report = entry.get("report") or {}
    code, fight = report.get("code"), report.get("fightID")
    if not (code and fight):
        return {}
    try:
        data = client.query(f'{{ reportData {{ report(code: "{code}") {{ playerDetails(fightIDs: [{fight}], '
                            f'includeCombatantInfo: true) }} }} }}')
    except api.ApiError:
        return {}
    details = (((data["reportData"]["report"] or {}).get("playerDetails") or {}).get("data") or {})
    for players in (details.get("playerDetails") or {}).values():
        for player in players:
            if player.get("name") != entry.get("name"):
                continue
            out = {}
            for item in (player.get("combatantInfo") or {}).get("gear") or []:
                if item.get("permanentEnchant"):
                    out[item["slot"] + 1] = (item["permanentEnchant"], item.get("permanentEnchantName"))
            return out
    return {}


def build_lists(client, report_lines):
    lists = []
    updated = datetime.date.today().isoformat()
    for phase in PHASES:
        encounter = boss_id(client, phase["zone"], phase["boss"])
        for spec in specs():
            ranked = rankings(client, encounter, spec, phase["partition"])
            if not ranked:
                report_lines.append(f"SKIPPED {spec['key']} {phase['label']}: no ranked players")
                continue
            players = [gear_from_ranking(entry) for entry in ranked]
            for entry, gear in zip(ranked[:ENCHANT_SAMPLE], players):
                for slot, (enchant, name) in enchants_from_report(client, entry).items():
                    if slot in gear:
                        gear[slot]["enchant"], gear[slot]["enchantName"] = enchant, name
            made = aggregate.build_list(spec, players, None, updated, set_name=f"Top {TOP} raiders",
                                        suffix=f"top:{phase['phase']}", phase=phase["phase"])
            lists.append(made)
            report_lines.append(f"ok {spec['key']} {phase['label']}: {len(players)} players")
    return lists


def render(lists, updated):
    labels = ", ".join(f'[{p["phase"]}] = "{p["label"]}"' for p in PHASES)
    out = [
        "-- Generated by tools/topplayers/era.py from Warcraft Logs: the gear the top raiders",
        f"-- of each spec wore in each phase of 2019 Classic ({updated}). Do not edit by hand:",
        "-- change the tool and rerun it (RULES.md Rule 7).",
        "-- Slots are INVSLOT numbers; enchantIDs are SpellItemEnchantment IDs (the number in an",
        "-- item link) with their names; usage[slot] counts the players wearing the #1 item and",
        "-- each alternative, in that order.",
        "",
        "local addonName, ns = ...",
        "",
        "ns.Data:Register({",
        '    flavor = "Vanilla",',
        f"    defaultPhase = {DEFAULT_PHASE},",
        f"    phaseLabels = {{ {labels} }},",
        f'    source = "Top {TOP} raiders per phase (Warcraft Logs)",',
        "    lists = {",
    ]
    for entry in sorted(lists, key=lambda e: e["id"]):
        out.append("        {")
        for field in FIELD_ORDER:
            value = entry.get(field)
            if value is None or value == {}:
                continue
            out.append(f"            {field} = {build.lua_value(value, 3)},")
        out.append("        },")
    out += ["    },", "})", ""]
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", default=os.path.join(DATA_DIR, "blizzard.env"))
    parser.add_argument("--cache", default=os.path.join(DATA_DIR, "Era", "cache"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    client = wcl.Client(args.key, args.cache)
    try:
        if args.check:
            data = client.query("{ rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn } }", cache=False)
            limit = data["rateLimitData"]
            print(f"key works: {limit['limitPerHour'] - limit['pointsSpentThisHour']:.0f} of "
                  f"{limit['limitPerHour']} points left this hour")
            return
        report_lines = []
        lists = build_lists(client, report_lines)
    except api.ApiError as error:
        sys.exit(f"error: {error}")
    for line in report_lines:
        print(line, file=sys.stderr)
    if not lists:
        sys.exit("no lists built")
    out_dir = os.path.join(ROOT, "Data", "Vanilla")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "Lists.lua")
    updated = datetime.date.today().isoformat()
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render(lists, updated))
    print(f"wrote {out_path}: {len(lists)} list(s); {client.queries} queries, {client.cache_hits} from cache")


if __name__ == "__main__":
    main()
