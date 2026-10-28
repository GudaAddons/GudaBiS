"""Build Data/Mists/Lists.lua (the MoP Classic TOC's data) from two sources (GB-140/141):
  - WoWSims' Pre-Raid and BiS gear sets per spec (wowsims.py, MIT licence), with
    reforges, and the enchant names for every list;
  - what the top raiders of each spec wore in each phase, from Warcraft Logs.

Usage (WSL; the key file is described in wcl.py):
  python3 -B tools/topplayers/mists.py               # both
  python3 -B tools/topplayers/mists.py --sims-only   # WoWSims only, no Warcraft Logs key

The Warcraft Logs part is era.py's idea: per phase, the rankings of the current raid's
last boss give the top 50 players of every spec with their gear in one query. MoP
rankings carry more than Era's: each item's item level, gems and enchant ID (author,
2026-10-29), so those lists get gems and item levels like Retail's. Enchant names come
from WoWSims' database (Warcraft Logs' own names are unscaled: "+3 Strength and +1
Critical Strike"). Warcraft Logs has no reforges anywhere; only WoWSims lists have them.

Phases are Warcraft Logs' partitions of the global zones (the CN zones are left out):
  Phase 1-2  Sha of Fear (Heart of Fear / Terrace)   partition "Phase 1/2"
  Phase 3    Lei Shen (Throne of Thunder)             partition "Phase 3"
  Phase 4    Lei Shen (Throne of Thunder)             partition "Phase 4"
  Phase 5    Garrosh Hellscream (Siege of Orgrimmar)  partition "Phase 5"
Siege of Orgrimmar has no rankings before Phase 5. "Phase 3.5" is left out: GudaBiS
phases are whole numbers. Phase 1 is Pre-Raid, WoWSims' sets only.

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
import era  # noqa: E402
import wcl  # noqa: E402
import wowsims  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA_DIR = "/mnt/g/addon-data/GudaBis"
TOP = era.TOP
MIN_PLAYERS = era.MIN_PLAYERS

PHASES = [
    {"phase": 2, "label": "Phase 1-2", "zone": 1040, "boss": "Sha of Fear", "partition": 1},
    {"phase": 3, "label": "Phase 3", "zone": 1046, "boss": "Lei Shen", "partition": 2},
    {"phase": 4, "label": "Phase 4", "zone": 1046, "boss": "Lei Shen", "partition": 4},
    {"phase": 5, "label": "Phase 5", "zone": 1054, "boss": "Garrosh Hellscream", "partition": 5},
]
DEFAULT_PHASE = 5
PRE_RAID_LABEL = "Pre-Raid"

# Warcraft Logs class and spec names -> the spec's index (GetSpecialization), the same
# order as Retail's (Data/Mainline/Lists.lua); MoP has Combat where Retail has Outlaw.
TREES = {
    "DeathKnight": {"Blood": 1, "Frost": 2, "Unholy": 3},
    "Druid": {"Balance": 1, "Feral": 2, "Guardian": 3, "Restoration": 4},
    "Hunter": {"BeastMastery": 1, "Marksmanship": 2, "Survival": 3},
    "Mage": {"Arcane": 1, "Fire": 2, "Frost": 3},
    "Monk": {"Brewmaster": 1, "Windwalker": 2, "Mistweaver": 3},
    "Paladin": {"Holy": 1, "Protection": 2, "Retribution": 3},
    "Priest": {"Discipline": 1, "Holy": 2, "Shadow": 3},
    "Rogue": {"Assassination": 1, "Combat": 2, "Subtlety": 3},
    "Shaman": {"Elemental": 1, "Enhancement": 2, "Restoration": 3},
    "Warlock": {"Affliction": 1, "Demonology": 2, "Destruction": 3},
    "Warrior": {"Arms": 1, "Fury": 2, "Protection": 3},
}

FIELD_ORDER = ["id", "spec", "class", "tree", "phase", "set", "author", "url", "players", "updated",
               "items", "enchantIDs", "enchantNames", "gems", "reforges", "alts", "usage", "itemLevels"]


def specs():
    out = []
    for class_name, trees in TREES.items():
        for spec_name, tree in trees.items():
            out.append({"key": f"{class_name.upper()}_{spec_name.upper()}", "class": class_name.upper(),
                        "tree": tree, "wclClass": class_name, "wclSpec": spec_name})
    return out


def _int(value):
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def gear_from_ranking(entry):
    """A MoP ranking's gear (slot order, with item level, gems and enchant ID) ->
    aggregate.equipped() shape. Enchant names are filled in from WoWSims later."""
    out = {}
    for index, item in enumerate(entry.get("gear") or []):
        item_id = _int((item or {}).get("id"))
        if not item_id:
            continue
        out[index + 1] = {"item": item_id, "level": _int(item.get("itemLevel")) or None, "bonus": [],
                          "enchant": _int(item.get("permanentEnchant")) or None, "enchantName": None,
                          "gems": [_int(gem.get("id")) for gem in item.get("gems") or []]}
    return out


def build_lists(client, report_lines, enchant_names):
    lists = []
    updated = datetime.date.today().isoformat()
    for phase in PHASES:
        encounter = era.boss_id(client, phase["zone"], phase["boss"])
        for spec in specs():
            ranked = era.rankings(client, encounter, spec, phase["partition"])
            if len(ranked) < MIN_PLAYERS:
                report_lines.append(f"SKIPPED {spec['key']} {phase['label']}: {len(ranked)} ranked players")
                continue
            players = [gear_from_ranking(entry) for entry in ranked]
            made = aggregate.build_list(spec, players, None, updated, set_name=f"Top {TOP} raiders",
                                        suffix=f"top:{phase['phase']}", phase=phase["phase"])
            if not made.get("items"):
                report_lines.append(f"SKIPPED {spec['key']} {phase['label']}: no gear")
                continue
            made["enchantNames"] = {slot: enchant_names[enchant] for slot, enchant in made["enchantIDs"].items()
                                    if enchant in enchant_names}
            lists.append(made)
            report_lines.append(f"ok {spec['key']} {phase['label']}: {len(players)} players")
    return lists


def render(lists, updated):
    labels = ", ".join([f'[{wowsims.PRE_RAID_PHASE}] = "{PRE_RAID_LABEL}"']
                       + [f'[{p["phase"]}] = "{p["label"]}"' for p in PHASES])
    out = [
        "-- Generated by tools/topplayers/mists.py: WoWSims' Pre-Raid and BiS gear sets (author",
        f'-- "WoWSims"; {wowsims.LICENCE}) and the gear the top raiders of each',
        f"-- spec wore in each phase of MoP Classic, from Warcraft Logs ({updated}). Do not edit",
        "-- by hand: change the tool and rerun it (RULES.md Rule 7).",
        "-- Slots are INVSLOT numbers; enchantIDs are SpellItemEnchantment IDs (the number in an",
        "-- item link) with their names; gems are item IDs in socket order; reforges[slot] is the",
        "-- stat reforged from and to, as Blizzard's ITEM_MOD_<stat>_SHORT names; usage[slot]",
        "-- counts the players wearing the #1 item and each alternative; itemLevels is the",
        "-- highest item level the top raiders wear a listed item at.",
        "",
        "local addonName, ns = ...",
        "",
        "ns.Data:Register({",
        '    flavor = "Mists",',
        f"    defaultPhase = {DEFAULT_PHASE},",
        f"    phaseLabels = {{ {labels} }},",
        f'    source = "WoWSims gear sets (MIT licence) and the top {TOP} raiders per phase (Warcraft Logs)",',
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
    parser.add_argument("--cache", default=os.path.join(DATA_DIR, "Mists", "cache"))
    parser.add_argument("--sims", default=os.path.join(DATA_DIR, "Mists", "wowsims"))
    parser.add_argument("--sims-only", action="store_true")
    parser.add_argument("--refresh", action="store_true", help="fetch WoWSims' files again")
    args = parser.parse_args()
    report_lines = []
    updated = datetime.date.today().isoformat()
    trees = {spec["key"]: spec for spec in specs()}
    lists, db = wowsims.build_lists(args.sims, trees, updated, report_lines, args.refresh)
    client = None
    if not args.sims_only:
        client = wcl.Client(args.key, args.cache)
        try:
            lists += build_lists(client, report_lines, db["enchant"])
        except api.ApiError as error:
            sys.exit(f"error: {error}")
    for line in report_lines:
        print(line, file=sys.stderr)
    if not lists:
        sys.exit("no lists built")
    out_dir = os.path.join(ROOT, "Data", "Mists")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "Lists.lua")
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render(lists, updated))
    queries = f"; {client.queries} queries, {client.cache_hits} from cache" if client else ""
    print(f"wrote {out_path}: {len(lists)} list(s){queries}")


if __name__ == "__main__":
    main()
