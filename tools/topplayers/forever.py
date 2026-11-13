"""Build Data/Forever/Lists.lua (the WoW: Forever TOCs' data) from the BiS lists of
wowtbc.gg's Warcraft Forever section (M12, GB-151).

Usage (WSL):
  python3 -B tools/topplayers/forever.py            # cached pages where present
  python3 -B tools/topplayers/forever.py --refresh  # fetch every page again

Each spec page (https://wowtbc.gg/warcraftforever/bis-list/<slug>/) loads its data from
/page-data/warcraftforever/bis-list/<slug>/page-data.json: under result.pageContext,
bisList.caps["20".."60"][slot] is a ranked list of item IDs, and gearData describes
each item (source_type "Quest (Horde)" / "Quest (Alliance)" marks a faction's quest).
There are no phases on Forever: the level caps 20-60 are the addon's phases, and the
addon picks the one that fits the character's level (author, 2026-11-11).

Rules (author, 2026-11-11):
- the site's order is the rank: #1 is the slot's item, every other item an alternative
- rings and trinkets: #1 and #2 fill the pair, both slots share the rest
- no off hand when the main hand's #1 is two-handed (GB-155)
- no enchants, gems or source text
- a spec and level cap with any one-faction item becomes one list per faction, each
  without the other faction's items (the addon offers a list only to its faction)

Pages are fetched one at a time, PAUSE seconds apart, and cached under DATA_DIR. The
output is sorted, so an unchanged result gives no diff. Never edit it by hand (RULES.md
Rule 7): change the tool and rerun it.
"""

import argparse
import datetime
import json
import os
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA_DIR = "/mnt/g/addon-data/GudaBis"
URL = "https://wowtbc.gg/page-data/warcraftforever/bis-list/{slug}/page-data.json"
PAGE = "https://wowtbc.gg/warcraftforever/bis-list/{slug}/"
USER_AGENT = "GudaBiS-data-tool/1.0"
PAUSE = 2.0
SOURCE = "wowtbc.gg (Warcraft Forever BiS lists)"

# The level caps the site lists, as the addon's phases; the newest is the fallback.
PHASES = [20, 30, 40, 50, 60]
DEFAULT_PHASE = 60

# Site slug -> spec key (Era's keys), class, talent tab, and the list name shown after
# the tree's name. Two specs on one tab need different names (author, 2026-11-11):
# Shockadin after Holy, Feral DPS and Feral Tank on the second druid tab.
SPECS = {
    "balance-druid": ("DRUID_BALANCE", 1, "BiS"),
    "feral-dps-druid": ("DRUID_FERAL", 2, "Feral DPS"),
    "feral-tank-druid": ("DRUID_FERAL_TANK", 2, "Feral Tank"),
    "restoration-druid": ("DRUID_RESTORATION", 3, "BiS"),
    "beast-mastery-hunter": ("HUNTER_BEASTMASTERY", 1, "BiS"),
    "marksmanship-hunter": ("HUNTER_MARKSMANSHIP", 2, "BiS"),
    "survival-hunter": ("HUNTER_SURVIVAL", 3, "BiS"),
    "arcane-mage": ("MAGE_ARCANE", 1, "BiS"),
    "fire-mage": ("MAGE_FIRE", 2, "BiS"),
    "frost-mage": ("MAGE_FROST", 3, "BiS"),
    "holy-paladin": ("PALADIN_HOLY", 1, "BiS"),
    "shockadin-paladin": ("PALADIN_SHOCKADIN", 1, "Shockadin"),
    "protection-paladin": ("PALADIN_PROTECTION", 2, "BiS"),
    "retribution-paladin": ("PALADIN_RETRIBUTION", 3, "BiS"),
    "discipline-priest": ("PRIEST_DISCIPLINE", 1, "BiS"),
    "holy-priest": ("PRIEST_HOLY", 2, "BiS"),
    "shadow-priest": ("PRIEST_SHADOW", 3, "BiS"),
    "assassination-rogue": ("ROGUE_ASSASSINATION", 1, "BiS"),
    "combat-rogue": ("ROGUE_COMBAT", 2, "BiS"),
    "subtlety-rogue": ("ROGUE_SUBTLETY", 3, "BiS"),
    "elemental-shaman": ("SHAMAN_ELEMENTAL", 1, "BiS"),
    "enhancement-shaman": ("SHAMAN_ENHANCEMENT", 2, "BiS"),
    "restoration-shaman": ("SHAMAN_RESTORATION", 3, "BiS"),
    "affliction-warlock": ("WARLOCK_AFFLICTION", 1, "BiS"),
    "demonology-warlock": ("WARLOCK_DEMONOLOGY", 2, "BiS"),
    "destruction-warlock": ("WARLOCK_DESTRUCTION", 3, "BiS"),
    "arms-warrior": ("WARRIOR_ARMS", 1, "BiS"),
    "fury-warrior": ("WARRIOR_FURY", 2, "BiS"),
    "protection-warrior": ("WARRIOR_PROTECTION", 3, "BiS"),
}

# Site slot -> INVSLOT numbers; a pair gets #1 and #2.
SLOTS = {
    "head": (1,), "neck": (2,), "shoulder": (3,), "back": (15,), "chest": (5,),
    "wrist": (9,), "hands": (10,), "waist": (6,), "legs": (7,), "feet": (8,),
    "finger": (11, 12), "trinket": (13, 14),
    "main-hand": (16,), "off-hand": (17,), "ranged": (18,),
}

FACTIONS = ("Alliance", "Horde")

# The talent tabs' English names, per class: shown before the list name only when the
# client gives no tree name of its own (Forever before its talent API is known).
TREE_NAMES = {
    "DRUID": ("Balance", "Feral Combat", "Restoration"),
    "HUNTER": ("Beast Mastery", "Marksmanship", "Survival"),
    "MAGE": ("Arcane", "Fire", "Frost"),
    "PALADIN": ("Holy", "Protection", "Retribution"),
    "PRIEST": ("Discipline", "Holy", "Shadow"),
    "ROGUE": ("Assassination", "Combat", "Subtlety"),
    "SHAMAN": ("Elemental", "Enhancement", "Restoration"),
    "WARLOCK": ("Affliction", "Demonology", "Destruction"),
    "WARRIOR": ("Arms", "Fury", "Protection"),
}

FIELD_ORDER = ["id", "spec", "class", "tree", "treeName", "phase", "set", "faction", "url", "updated",
               "items", "alts"]


class SourceError(Exception):
    pass


# The site marks only quest rewards with a faction ("Quest (Horde)"). PvP rank gear and
# battleground reputation gear are one faction's too but carry no mark, and the site's
# single list per spec mixes both (author, 2026-11-11: a Horde paladin was offered
# Field Marshal's plate). Their faction comes from these rules instead.
#
# Rank titles, longest first so "Field Marshal's" is not read as "Marshal's". They are
# read only on the PvP vendors' new items: names starting "Premier ", or new IDs
# (>= NEW_ITEM_IDS) with no source. Older items share some titles ("General's
# Ceremonial Plate" drops in Blackrock Depths, "Champion's Legplates" is crafted).
RANKS = {
    "Alliance": ("Knight-Lieutenant's", "Knight-Captain's", "Knight-Champion's",
                 "Lieutenant Commander's", "Field Marshal's", "Grand Marshal's", "Marshal's",
                 "Commander's", "Corporal's", "Private's", "Sergeant's Cape"),
    "Horde": ("Senior Sergeant's", "First Sergeant's", "Stone Guard's", "Blood Guard's",
              "Legionnaire's", "Centurion's", "Champion's", "Lieutenant General's", "General's",
              "High Warlord's", "Warlord's", "Sergeant's Cloak"),
}
NEW_ITEM_IDS = 200000
# Battleground vendors and reputations, read from the item's source text.
SOURCES = {
    "Alliance": ("League of Arathor", "Stormpike", "Silverwing", "Illiyana Moonblaze",
                 "Thanthaldis Snowgleam"),
    "Horde": ("Defilers", "Frostwolf", "Warsong Outriders", "Kelm Hargunth", "Grunnda Wolfheart"),
}
# A PvP set's name tells its faction even where the piece's own title does not.
SET_PREFIXES = {
    "Alliance": ("Field Marshal's", "Marshal's", "Lieutenant Commander's", "Knight-"),
    "Horde": ("Warlord's", "General's", "Champion's", "Legionnaire's", "Centurion's"),
}


def pvp_faction(item):
    """"Alliance" / "Horde" for one faction's PvP or battleground item, else None."""
    name = item.get("name") or ""
    source = item.get("source") or ""
    premier = name.startswith("Premier ")
    title = name[len("Premier "):] if premier else name
    if premier or (item.get("id", 0) >= NEW_ITEM_IDS and not source):
        for faction in FACTIONS:
            if any(title.startswith(rank) for rank in RANKS[faction]):
                return faction
    for faction in FACTIONS:
        if any(word in source for word in SOURCES[faction]):
            return faction
    set_name = item.get("set") or ""
    for faction in FACTIONS:
        if any(set_name.startswith(prefix) for prefix in SET_PREFIXES[faction]):
            return faction
    return None


def item_factions(gear):
    """item ID -> "Alliance" / "Horde" for the items only one faction can get."""
    out = {}
    for item in gear:
        kind = item.get("source_type") or ""
        for faction in FACTIONS:
            if f"({faction})" in kind:
                out[item["id"]] = faction
        if item["id"] not in out:
            faction = pvp_faction(item)
            if faction:
                out[item["id"]] = faction
    return out


def unique(ids):
    seen, out = set(), []
    for item in ids:
        if isinstance(item, int) and item not in seen:
            seen.add(item)
            out.append(item)
    return out


def two_handers(gear):
    """IDs of the items gearData marks as two-handed."""
    return {item["id"] for item in gear if item.get("slot") == "two-hand"}


def slots_for(cap, keep, two_handed=frozenset()):
    """items and alts by INVSLOT from one level cap's ranked lists; keep(id) filters.

    Some pages (Beast Mastery) rank two-handers apart from the one-handers: they go into
    the main hand after the one-handers (or are the main hand when none is listed).
    The site ranks main and off hand apart and mixes staves into the main hand, so its
    two #1s can be a staff and an orb, which no one can hold together: when the main
    hand's #1 is two-handed, the list has no off hand (GB-155).
    A pair's shared alternatives are written once, on its first slot; the data's
    pairsShareAlts tells the addon to give the second slot the same table.
    """
    items, alts = {}, {}
    cap = dict(cap)
    two_hand = cap.pop("two-hand", None) or []
    cap["main-hand"] = list(cap.get("main-hand") or []) + list(two_hand)
    for site_slot, ranked in cap.items():
        slots = SLOTS.get(site_slot)
        if slots is None:
            raise SourceError(f"unknown slot {site_slot!r}")
        ranked = [i for i in unique(ranked) if keep(i)]
        if not ranked:
            continue
        lead = ranked[:len(slots)]
        rest = ranked[len(slots):]
        for slot, item in zip(slots, lead):
            items[slot] = item
        if rest:
            alts[slots[0]] = list(rest)
    if items.get(16) in two_handed:
        items.pop(17, None)
        alts.pop(17, None)
    return items, alts


def lists_for(slug, context, updated):
    """The lists of one spec page's pageContext."""
    key, tree, set_name = SPECS[slug]
    bis = context.get("bisList") or {}
    caps = bis.get("caps") or {}
    expected_class = key.split("_")[0].lower()
    if (bis.get("class") or "").lower() != expected_class:
        raise SourceError(f"{slug}: page is for class {bis.get('class')!r}")
    factions = item_factions(context.get("gearData") or [])
    two_handed = two_handers(context.get("gearData") or [])
    out = []
    for phase in PHASES:
        cap = caps.get(str(phase))
        if not cap:
            continue
        ids = {i for ranked in cap.values() for i in ranked}
        split = any(i in factions for i in ids)
        for faction in (FACTIONS if split else (None,)):
            def keep(item, faction=faction):
                owner = factions.get(item)
                return owner is None or faction is None or owner == faction
            items, alts = slots_for(cap, keep, two_handed)
            if not items:
                continue
            list_id = f"{key}:{phase}" + (f":{faction}" if faction else "")
            out.append({
                "id": list_id, "spec": key, "class": key.split("_")[0], "tree": tree,
                "treeName": TREE_NAMES[key.split("_")[0]][tree - 1],
                "phase": phase, "set": set_name, "faction": faction,
                "url": PAGE.format(slug=slug), "updated": updated,
                "items": items, "alts": alts,
            })
    return out


def render(lists, updated):
    labels = ", ".join(str(p) for p in PHASES)
    out = [
        "-- Generated by tools/topplayers/forever.py from wowtbc.gg's Warcraft Forever BiS",
        f"-- lists ({updated}). Do not edit by hand: change the tool and rerun it (RULES.md Rule 7).",
        f"-- Phases are level caps ({labels}); the addon picks the one that fits the character's",
        "-- level. Slots are INVSLOT numbers; alts are the site's other items for the slot, in",
        "-- its order, once per ring and trinket pair (pairsShareAlts: the second slot shares the",
        "-- first slot's). A list with a faction leaves out the other faction's quest rewards and",
        "-- PvP gear. A list whose main-hand #1 is two-handed has no off hand.",
        "",
        "local addonName, ns = ...",
        "",
        "ns.Data:Register({",
        '    flavor = "Forever",',
        f"    defaultPhase = {DEFAULT_PHASE},",
        '    phaseKind = "level",',
        '    pairsShareAlts = true,',
        f'    source = "{SOURCE}",',
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


def fetch(slug, cache_dir, refresh):
    """One page's pageContext, from the cache unless refresh; True when fetched."""
    path = os.path.join(cache_dir, f"{slug}.json")
    if not refresh and os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            return json.load(handle), False
    request = urllib.request.Request(URL.format(slug=slug), headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        page = json.load(response)
    context = page["result"]["pageContext"]
    os.makedirs(cache_dir, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(context, handle)
    return context, True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", default=os.path.join(DATA_DIR, "Forever", "cache"))
    parser.add_argument("--refresh", action="store_true", help="fetch every page again")
    args = parser.parse_args()
    updated = datetime.date.today().isoformat()
    lists, fetched, tagged = [], 0, {}
    for slug in sorted(SPECS):
        try:
            context, was_fetched = fetch(slug, args.cache, args.refresh)
        except Exception as error:  # noqa: BLE001 - report the page and stop
            sys.exit(f"error: {slug}: {error}")
        if was_fetched:
            fetched += 1
            time.sleep(PAUSE)
        try:
            made = lists_for(slug, context, updated)
        except SourceError as error:
            sys.exit(f"error: {error}")
        phases = sorted({entry["phase"] for entry in made})
        print(f"ok {slug}: {len(made)} list(s), levels {phases}", file=sys.stderr)
        lists += made
        gear = context.get("gearData") or []
        names = {item["id"]: item.get("name") for item in gear}
        for item_id, faction in item_factions(gear).items():
            tagged[item_id] = (faction, names.get(item_id))
    report = os.path.join(args.cache, "..", "factions.txt")
    with open(report, "w", encoding="utf-8") as handle:
        for item_id, (faction, name) in sorted(tagged.items(), key=lambda e: (e[1][0], e[1][1] or "")):
            handle.write(f"{faction}\t{item_id}\t{name}\n")
    counts = {f: sum(1 for v in tagged.values() if v[0] == f) for f in FACTIONS}
    print(f"one-faction items: {counts}; listed in {os.path.normpath(report)}", file=sys.stderr)
    out_dir = os.path.join(ROOT, "Data", "Forever")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "Lists.lua")
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render(lists, updated))
    print(f"wrote {out_path}: {len(lists)} list(s); {fetched} page(s) fetched")


if __name__ == "__main__":
    main()
