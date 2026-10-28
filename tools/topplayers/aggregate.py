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
    are the ones most players wearing the slot's #1 put in each socket.
usage[slot] holds how many players wear the #1 and each alternative, in list order, so
the addon can say "used by 18 of 50".
itemLevels[itemID] is the highest item level any of them wears a listed item at: the
level a fully upgraded copy reaches this season, which the addon compares the
player's own copy with (GB-065).
"""

import re
from collections import Counter, defaultdict

MIN_SHARE = 0.10
MAX_ALTS = 6
OFF_HAND_SHARE = 0.5

SLOTS = {
    "HEAD": 1, "NECK": 2, "SHOULDER": 3, "CHEST": 5, "WAIST": 6, "LEGS": 7, "FEET": 8,
    "WRIST": 9, "HANDS": 10, "FINGER_1": 11, "FINGER_2": 12, "TRINKET_1": 13, "TRINKET_2": 14,
    "BACK": 15, "MAIN_HAND": 16, "OFF_HAND": 17,
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
    """Blizzard's equipment response -> {INVSLOT: {item, level, enchant, enchantName, gems}}."""
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
        out[slot] = {"item": item, "level": level, "enchant": enchant, "enchantName": name, "gems": gems}
    return out


def _sorted(counter):
    return sorted(counter.items(), key=lambda kv: (-kv[1], kv[0]))


def build_list(spec, players, season, updated):
    """spec: {key, class, specID, tree, name}; players: list of equipped() results."""
    total = len(players)
    worn = defaultdict(Counter)
    levels = {}
    for gear in players:
        seen = set()
        for slot, entry in gear.items():
            group = PAIRS.get(slot, (slot,))
            key = group[0]
            if (key, entry["item"]) in seen:
                continue
            seen.add((key, entry["item"]))
            worn[key][entry["item"]] += 1
            if entry.get("level"):
                levels[entry["item"]] = max(levels.get(entry["item"], 0), entry["level"])
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
        for gear in players:
            entry = gear.get(slot)
            if not entry:
                continue
            if entry["enchant"]:
                counts[entry["enchant"]] += 1
                labels[entry["enchant"]] = entry["enchantName"]
            if entry["item"] == best:
                for i, gem in enumerate(entry["gems"]):
                    if gem:
                        sockets[i][gem] += 1
        if counts:
            enchant = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
            enchants[slot], names[slot] = enchant, labels[enchant]
        chosen = [sorted(sockets[i].items(), key=lambda kv: (-kv[1], kv[0]))[0][0] for i in sorted(sockets)]
        if chosen:
            gems[slot] = chosen
    listed = set(items.values()) | {item for rest in alts.values() for item in rest}
    return {
        "id": f"{spec['key']}:mplus", "spec": spec["key"], "class": spec["class"],
        "specID": spec["specID"], "tree": spec["tree"], "anyPhase": True,
        "set": "Top 50 M+", "season": season, "players": total, "updated": updated,
        "items": items, "enchantIDs": enchants, "enchantNames": names, "gems": gems,
        "alts": alts, "usage": usage,
        "itemLevels": {item: levels[item] for item in listed if item in levels},
    }
