"""MoP Classic Pre-Raid and BiS lists from WoWSims' gear sets (GB-141). No key needed.

WoWSims (github.com/wowsims/mop, MIT licence; author's choice 2026-10-29) ships, for
each spec, the gear sets its simulator starts from: ui/specs/<class>/<spec>/gear_sets/
<name>.gear.json, items in WoWSims' ItemSlot order with enchant (a SpellItemEnchantment
ID, the number in an item link), gems in socket order and a reforge ID. Its item
database (assets/database/db.json) gives each item's content phase, the reforges'
stats and the enchants' names.

  - A set whose name starts with a pre-raid word is the Pre-Raid phase. Any other set is
    placed by the phase in its name (p1-p5, t14-t16); a set whose newest item (the
    database's item phase) is older than that is a stale copy and left out. A set with
    no phase in its name (msv, hof, default) is placed by its newest item. A set with an
    item outside the MoP item database (older expansion gear) is left out.
  - The rest of the name becomes the list's name ("p5_offensive" -> "BiS Offensive");
    item-swap and test sets are not full sets and are left out.
  - Reforges are kept as Blizzard's stat names ("CRIT_RATING"), so the addon shows them
    in the client's language; upgrade levels and tinkers are left out.

Files are fetched once into the cache (G:\\addon-data\\GudaBis\\Mists\\wowsims); --refresh
fetches them again. mists.py renders these lists together with the Warcraft Logs ones.
"""

import json
import os
import re
import urllib.request

REPO = "wowsims/mop"
BRANCH = "master"
RAW = f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/"
TREE = f"https://api.github.com/repos/{REPO}/git/trees/{BRANCH}?recursive=1"
CREDIT = "WoWSims"
LICENCE = "WoWSims (github.com/wowsims/mop), MIT licence"

# WoWSims ItemSlot order -> INVSLOT.
SLOT_ORDER = [1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17]

# WoWSims Stat numbers of the reforgeable stats -> Blizzard's ITEM_MOD_<name>_SHORT.
REFORGE_STATS = {4: "SPIRIT", 5: "HIT_RATING", 6: "CRIT_RATING", 7: "HASTE_RATING",
                 8: "EXPERTISE_RATING", 9: "DODGE_RATING", 10: "PARRY_RATING", 11: "MASTERY_RATING"}

PRE_RAID = re.compile(r"^(pre_?raid|prebis|p1[_-]pre_?(bis|raid))(?=[_.-]|$)")
SKIP = re.compile(r"item_swap|simtest")
# Item content phase (WoWSims) -> GudaBiS phase (Warcraft Logs' partitions, mists.py).
PHASE_OF_ITEMS = {1: 2, 2: 2, 3: 3, 4: 4, 5: 5}
PRE_RAID_PHASE = 1
MIN_ITEMS = 10

# Words of a set's file name -> its list name. Words not here are dropped (the phase,
# "bis", the spec's own name).
WORDS = [
    ("2h-obliterate", "Two-Hand Obliterate"), ("masterfrost", "Masterfrost"),
    ("post_hof", "after Heart of Fear"), ("post_msv", "after Mogu'shan Vaults"),
    ("prehof", "before Heart of Fear"), ("pretoes", "before Terrace"),
    ("p4p3upgraded", "Phase 3 upgraded"), ("offensive", "Offensive"), ("prog", "Progression"),
    ("balanced", "Balanced"), ("realistic", "Realistic"), ("tierless", "Tierless"),
    ("mastery", "Mastery"), ("smf", "Single-Minded Fury"), ("tg", "Titan's Grip"),
    ("2h", "Two-Hand"), ("dw", "Dual Wield"), ("msv", "Mogu'shan Vaults"), ("hof", "Heart of Fear"),
]


def _fetch(url, path, refresh):
    if refresh or not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": "GudaBiS data tool"})
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
        with open(path, "wb") as handle:
            handle.write(data)
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def spec_key(class_dir, spec_dir):
    """("death_knight", "beast_mastery") -> "DEATHKNIGHT_BEASTMASTERY"."""
    return class_dir.replace("_", "").upper() + "_" + spec_dir.replace("_", "").upper()


def set_name(file_name):
    """ "p5_offensive" -> ("BiS Offensive", False, True): the name, whether it is a
    Pre-Raid set, whether it is a variant (has words beyond "Pre-Raid" / "BiS")."""
    base = file_name.replace(".gear.json", "")
    pre = bool(PRE_RAID.match(base))
    rest = PRE_RAID.sub("", base) if pre else base
    words = []
    for token, label in WORDS:
        if re.search(r"(^|[_.\-])" + re.escape(token) + r"($|[_.\-])", rest):
            words.append(label)
            rest = re.sub(r"(^|[_.\-])" + re.escape(token) + r"($|[_.\-])", "_", rest)
    return " ".join(["Pre-Raid" if pre else "BiS"] + words), pre, bool(words)


def named_phase(file_name):
    """The WoWSims phase a set's name gives ("p4_bis" -> 4, "t15" -> 4), or None."""
    match = re.match(r"^p(\d)", file_name)
    if match:
        return int(match.group(1))
    tier = re.match(r"^t1([4-6])", file_name)
    return {"4": 2, "5": 4, "6": 5}[tier.group(1)] if tier else None


def database(cache, refresh=False):
    db = _fetch(RAW + "assets/database/db.json", os.path.join(cache, "db.json"), refresh)
    return {
        "phase": {item["id"]: item.get("phase") or 1 for item in db["items"]},
        "reforge": {r["id"]: (REFORGE_STATS.get(r["fromStat"]), REFORGE_STATS.get(r["toStat"]))
                    for r in db["reforgeStats"]},
        "enchant": {e["effectId"]: e["name"] for e in db["enchants"] if e.get("effectId")},
    }


def gear_set_paths(cache, refresh=False):
    tree = _fetch(TREE, os.path.join(cache, "tree.json"), refresh)
    return sorted(entry["path"] for entry in tree["tree"]
                  if re.match(r"^ui/specs/[a-z_]+/[a-z_]+/gear_sets/[^/]+\.gear\.json$", entry["path"]))


def list_from_set(path, gear, db, trees, updated):
    """One GudaBiS list from one gear set, or None (not a full set, unknown spec)."""
    _, _, class_dir, spec_dir, _, file_name = path.split("/")
    key = spec_key(class_dir, spec_dir)
    if key not in trees or SKIP.search(file_name):
        return None
    name, pre, variant = set_name(file_name)
    items, enchants, gems, reforges = {}, {}, {}, {}
    for index, entry in enumerate(gear.get("items") or []):
        if index >= len(SLOT_ORDER) or not entry.get("id"):
            continue
        slot = SLOT_ORDER[index]
        items[slot] = entry["id"]
        if entry.get("enchant"):
            enchants[slot] = entry["enchant"]
        if entry.get("gems"):
            gems[slot] = [gem for gem in entry["gems"] if gem]
        stats = db["reforge"].get(entry.get("reforging"))
        if stats and all(stats):
            reforges[slot] = list(stats)
    if len(items) < MIN_ITEMS:
        return None
    # An item outside the MoP item database is older gear: four pre-raid sets are still
    # WotLK or Cataclysm gear sets nobody updated (2026-10-29), so the set is left out.
    if any(item not in db["phase"] for item in items.values()):
        return None
    by_items = PHASE_OF_ITEMS.get(max(db["phase"][item] for item in items.values()), 5)
    named = named_phase(file_name)
    if pre:
        phase = PRE_RAID_PHASE
    elif named:
        # A set older than its name (healer p2-p4 sets still in Phase 1 gear) is a copy
        # nobody updated: left out rather than shown as that phase's BiS.
        if by_items < PHASE_OF_ITEMS[named]:
            return None
        phase = PHASE_OF_ITEMS[named]
    else:
        phase = by_items
    if phase == 2 and named in (1, 2) and file_name.startswith("p"):
        name += f" Phase {named}"
    # Sorted by id within a spec and phase: the plain set first, then variants; in
    # Phase 1-2, Phase 2 sets before Phase 1 ones.
    order = ("1" if variant else "0") + str(9 - (named or 0))
    slug = file_name.replace(".gear.json", "")
    return {
        "id": f"{key}:sim:{phase}:{order}:{slug}", "spec": key, "class": trees[key]["class"],
        "tree": trees[key]["tree"], "phase": phase, "set": name, "author": CREDIT,
        "url": f"https://github.com/{REPO}/blob/{BRANCH}/{path}", "updated": updated,
        "items": items, "enchantIDs": enchants,
        "enchantNames": {slot: db["enchant"][e] for slot, e in enchants.items() if e in db["enchant"]},
        "gems": {slot: g for slot, g in gems.items() if g}, "reforges": reforges,
    }


def build_lists(cache, trees, updated, report_lines, refresh=False):
    db = database(cache, refresh)
    out = []
    for path in gear_set_paths(cache, refresh):
        gear = _fetch(RAW + path, os.path.join(cache, path.replace("/", "_")), refresh)
        made = list_from_set(path, gear, db, trees, updated)
        if made:
            out.append(made)
            report_lines.append(f"ok {made['spec']} phase {made['phase']}: {made['set']} ({path.split('/')[-1]})")
        else:
            report_lines.append(f"SKIPPED {path}")
    return out, db
