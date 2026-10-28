"""From the equipment of a spec's top players to one GudaBiS list (GB-131). No network.

Per slot (author, 2026-10-28):
  - #1 is the item most of the players wear there; ties go to the lower item ID so the
    output is stable;
  - alternatives are the other items worn there by at least MIN_SHARE of the players,
    most worn first, at most MAX_ALTS;
  - rings and trinkets are counted over both of their slots: the most worn ring is
    ring 1, the next one ring 2, and neither slot lists the other's #1 as an
    alternative;
  - an off hand is listed only if at least half the players carry one (two-handers
    leave it empty);
  - the enchant is the one most players have on that slot, whatever the item; the gems
    are the ones most players wearing the slot's #1 put in each socket, for the sockets
    at least half of them have filled.
usage[slot] holds how many players wear the #1 and each alternative, in list order, so
the addon can say "used by 18 of 50".
itemLevels[itemID] is the highest item level any of them wears a listed item at: the
level a fully upgraded copy reaches this season, which the addon compares the
player's own copy with (GB-065). itemBonuses[itemID] are that copy's bonus IDs: on
Retail an item ID alone is the item's low base version, so the addon builds a full item
link from them to show the item as the top players wear it.
"""

import re
from collections import Counter, defaultdict

MIN_SHARE = 0.10
MAX_ALTS = 6
OFF_HAND_SHARE = 0.5

SLOTS = {
    "HEAD": 1, "NECK": 2, "SHOULDER": 3, "CHEST": 5, "WAIST": 6, "LEGS": 7, "FEET": 8,
    "WRIST": 9, "HANDS": 10, "FINGER_1": 11, "FINGER_2": 12, "TRINKET_1": 13, "TRINKET_2": 14,
    "BACK": 15, "MAIN_HAND": 16, "OFF_HAND": 17, "RANGED": 18,
}
PAIRS = {11: (11, 12), 12: (11, 12), 13: (13, 14), 14: (13, 14)}


def enchant_name(display):
    """ "Enchanted: Enchant Helm - Rune |A:...|a" -> "Enchant Helm - Rune"; colour codes
    ("|cnIQ4:...|r", "|cffffffff...|r") are dropped too."""
    text = display.split("|A:")[0]
    text = re.sub(r"\|cn[^:|]*:|\|c[0-9a-fA-F]{8}|\|r", "", text).strip()
    if text.startswith("Enchanted:"):
        text = text[len("Enchanted:"):].strip()
    return text


def equipped(equipment):
    """Blizzard's equipment response -> {INVSLOT: {item, level, bonus, enchant, enchantName, gems}}."""
    out = {}
    for entry in (equipment or {}).get("equipped_items") or []:
        slot = SLOTS.get((entry.get("slot") or {}).get("type"))
        item = (entry.get("item") or {}).get("id")
        if not slot or not item:
            continue
        enchant, name = None, None
        for e in entry.get("enchantments") or []:
            if (e.get("enchantment_slot") or {}).get("type") == "PERMANENT":
                enchant, name = e.get("enchantment_id"), enchant_name(e.get("display_string") or "")
        gems = [((s.get("item") or {}).get("id")) for s in entry.get("sockets") or []]
        level = (entry.get("level") or {}).get("value")
        bonus = [b for b in entry.get("bonus_list") or [] if isinstance(b, int)]
        out[slot] = {"item": item, "level": level, "bonus": bonus, "enchant": enchant, "enchantName": name, "gems": gems}
    return out


def _sorted(counter):
    return sorted(counter.items(), key=lambda kv: (-kv[1], kv[0]))


def build_list(spec, players, season, updated, set_name="Top 50 M+", suffix="mplus", phase=None):
    """spec: {key, class, specID, tree, name}; players: list of equipped() results.
    A phase (Era, GB-101) makes the list that phase's; without one it belongs to every
    phase (Retail)."""
    total = len(players)
    worn = defaultdict(Counter)
    levels, bonuses = {}, {}
    for gear in players:
        seen = set()
        for slot, entry in gear.items():
            group = PAIRS.get(slot, (slot,))
            key = group[0]
            if (key, entry["item"]) in seen:
                continue
            seen.add((key, entry["item"]))
            worn[key][entry["item"]] += 1
            if entry.get("level") and entry["level"] > levels.get(entry["item"], 0):
                levels[entry["item"]] = entry["level"]
                bonuses[entry["item"]] = entry.get("bonus") or []
    items, alts, usage = {}, {}, {}
    for slot in sorted(set(SLOTS.values())):
        group = PAIRS.get(slot, (slot,))
        ranked = [r for r in _sorted(worn[group[0]]) if r[0] not in (items.get(s) for s in group)]
        if not ranked:
            continue
        if slot == 17 and sum(worn[17].values()) < total * OFF_HAND_SHARE:
            continue
        items[slot] = ranked[0][0]
        usage[slot] = [ranked[0][1]]
    for slot, best in items.items():
        group = PAIRS.get(slot, (slot,))
        taken = {items[s] for s in group if s in items}
        rest = [(item, n) for item, n in _sorted(worn[group[0]])
                if item not in taken and n >= total * MIN_SHARE][:MAX_ALTS]
        if rest:
            alts[slot] = [item for item, _ in rest]
            usage[slot] += [n for _, n in rest]
    enchants, names, gems = {}, {}, {}
    for slot, best in items.items():
        counts, labels = Counter(), {}
        sockets = defaultdict(Counter)
        wearers = 0
        for gear in players:
            entry = gear.get(slot)
            if not entry:
                continue
            if entry["enchant"]:
                counts[entry["enchant"]] += 1
                labels[entry["enchant"]] = entry["enchantName"]
            if entry["item"] == best:
                wearers += 1
                for i, gem in enumerate(entry["gems"]):
                    if gem:
                        sockets[i][gem] += 1
        if counts:
            enchant = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
            enchants[slot], names[slot] = enchant, labels[enchant]
        # A socket only some wearers have (MoP blacksmith wrist and hand sockets) is left
        # out, or everyone without it would be told to fill it; the sockets kept are the
        # leading ones, so gem positions still match the item link's.
        chosen = []
        for i in sorted(sockets):
            if i != len(chosen) or sum(sockets[i].values()) * 2 < wearers:
                break
            chosen.append(sorted(sockets[i].items(), key=lambda kv: (-kv[1], kv[0]))[0][0])
        if chosen:
            gems[slot] = chosen
    listed = set(items.values()) | {item for rest in alts.values() for item in rest}
    return {
        "id": f"{spec['key']}:{suffix}", "spec": spec["key"], "class": spec["class"],
        "specID": spec.get("specID"), "tree": spec["tree"],
        "phase": phase, "anyPhase": None if phase is not None else True,
        "set": set_name, "season": season, "players": total, "updated": updated,
        "items": items, "enchantIDs": enchants, "enchantNames": names, "gems": gems,
        "alts": alts, "usage": usage,
        "itemLevels": {item: levels[item] for item in listed if item in levels},
        "itemBonuses": {item: bonuses[item] for item in listed if bonuses.get(item)},
    }
