"""Read a Wowhead BiS guide saved from the browser.

The page embeds the guide as Wowhead markup in WH.markup.printHtml("..."). From it:
  - class and spec: from the folder the author saved it in (specs.py), checked against
    the page <title> so a page in the wrong folder is reported, not loaded
  - phase: from the <title> ("Pre-Raid" = 0, "Phase N", "Resistance" = any phase),
    else from the file name
  - sets: every [tab name="..."] holding a [gear-planner=...]; the text in parentheses
    is dropped from the name (author, 2026-10-28: "Threat (Horde HitCap)" -> "Threat"),
    after reading the faction from it. A page with no gear planner gets one set built
    from its tables: the first row of each slot (first two for rings and trinkets).
  - the per-slot tables under [h3 toc="Head"] etc.: the Item column, in page order
"""

import json
import re

import gearplanner

# Wowhead section names (the h3 toc attribute, lowercased) -> INVSLOT numbers.
SECTION_SLOTS = {
    "head": [1], "helm": [1], "helmet": [1], "heads": [1],
    "neck": [2], "necks": [2], "necklace": [2], "amulet": [2],
    "shoulder": [3], "shoulders": [3],
    "back": [15], "cloak": [15], "cloaks": [15], "capes": [15],
    "chest": [5], "chests": [5],
    "wrist": [9], "wrists": [9], "bracers": [9],
    "hands": [10], "hand": [10], "gloves": [10],
    "waist": [6], "belt": [6], "belts": [6],
    "legs": [7], "leg": [7],
    "feet": [8], "boots": [8], "foot": [8],
    "rings": [11, 12], "ring": [11, 12], "finger": [11, 12], "fingers": [11, 12],
    "trinkets": [13, 14], "trinket": [13, 14],
    "weapons": [16], "weapon": [16], "main hand": [16], "main-hand": [16], "mainhand": [16],
    "main hand weapons": [16], "main-hand weapons": [16], "two-hand": [16], "two hand": [16],
    "two-handed": [16], "two-handed weapons": [16], "two-handed weapon": [16], "2h weapons": [16],
    "one-handed weapons": [16], "one-hand weapons": [16], "melee weapons": [16], "staves": [16],
    "staff": [16], "weapons & off-hands": [16], "dual wield": [16],
    "off hand": [17], "off-hand": [17], "off-hands": [17], "offhand": [17], "off hands": [17],
    "off hand weapons": [17], "off-hand weapons": [17], "shields": [17], "shield": [17],
    "held in off-hand": [17], "offhands": [17], "off hands and shields": [17], "shields & offhands": [17],
    "1h weapons": [16],
    "librams": [18], "libram": [18], "idols": [18], "idol": [18], "totems": [18], "totem": [18],
    "relics": [18], "relic": [18], "ranged": [18], "ranged weapons": [18], "ranged weapon": [18],
    "wands": [18], "wand": [18], "thrown": [18], "bows": [18], "guns": [18],
}

# Sections with item tables that are not single equipment slots (prose, enchants, gems,
# ammo, overviews that repeat the slot tables).
IGNORED_SECTIONS = {
    "", "aldor vs. scryer", "aldor vs scryer", "enchants", "gems", "gems and enchants",
    "enchantments", "meta gem", "consumables", "tier sets", "tier set", "set bonuses",
    "quivers / ammo pouches", "quivers", "ammunition", "badges of justice", "jewelry", "body armor",
    "frost resist gear", "nature resist gear", "fire resist gear", "shadow resist gear", "arcane resist gear",
}

FALLBACK_SET_NAME = "Best in Slot"
ITEM_COLUMN = 1


class GuideError(ValueError):
    pass


def _markup(html):
    blocks = [json.loads(m.group(1)) for m in re.finditer(r'WH\.markup\.printHtml\(("(?:[^"\\]|\\.)*")', html)]
    if not blocks:
        raise GuideError("no WH.markup.printHtml block (was the page saved as HTML?)")
    return max(blocks, key=len)


def _title(html):
    m = re.search(r"<title>(.*?)</title>", html, re.S)
    return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""


def _canonical(html):
    m = re.search(r'<link rel="canonical" href="(https://www\.wowhead\.com/[^"]+)"', html)
    return m.group(1) if m else None


def _updated(html):
    m = re.search(r'Updated:\s*<span[^>]*>\s*(\d{4})/(\d{2})/(\d{2})', html)
    return f"{m.group(1)}-{m.group(2)}-{m.group(3)}" if m else None


# The guide's writer, from the page's structured data ("author":{"@type":"Person","name":...}).
# Guides credited to the site itself have no writer to name (author, 2026-10-28: Wowhead
# only hosts the guides), so they get None.
HOST_AUTHORS = {"Wowhead"}


def _author(html):
    m = re.search(r'"author":\{"@type":"Person","name":"([^"]+)"', html)
    name = m.group(1).strip() if m else None
    return None if not name or name in HOST_AUTHORS else name


def phase_of(title, filename):
    """0 for pre-raid, n for Phase n, "res" for a resistance guide (any phase)."""
    lowered = title.lower()
    if "resist" in lowered:
        return "res"
    if "pre-raid" in lowered or "pre raid" in lowered:
        return 0
    m = re.search(r"phase\s*(\d)", lowered)
    if m:
        return int(m.group(1))
    name = filename.lower()
    if "pre" in name:
        return 0
    m = re.search(r"(\d)", name)
    if m:
        return int(m.group(1))
    raise GuideError(f"no phase in title '{title}' or file name '{filename}'")


def clean_set_name(name):
    cleaned = re.sub(r"\s*\([^)]*\)", "", name).strip()
    return cleaned or FALLBACK_SET_NAME


def _faction(name):
    lowered = name.lower()
    if "horde" in lowered:
        return "Horde"
    if "alliance" in lowered:
        return "Alliance"
    return None


def _sets(markup):
    found = []
    tabs = list(re.finditer(r'\[tab\b[^\]]*\bname="([^"]+)"[^\]]*\](.*?)\[/tab\]', markup, re.S))
    sources = [(m.group(1).strip(), m.group(2)) for m in tabs] or [(FALLBACK_SET_NAME, markup)]
    for name, body in sources:
        m = re.search(r"\[gear-planner=([a-z-]+)/([a-z-]+)/([A-Za-z0-9_-]+)\]", body)
        if not m:
            continue
        decoded = gearplanner.decode(m.group(3))
        found.append({
            "name": clean_set_name(name), "faction": _faction(name),
            "race": m.group(2), "slots": decoded["slots"],
        })
    return found


def _table_items(body):
    """The Item column (second cell) of each table row. Other cells can start with an
    item too, e.g. a Source cell "[item=31358] - Jewelcrafting" is a recipe."""
    items = []
    for row in re.findall(r"\[tr\](.*?)\[/tr\]", body, re.S):
        cells = re.findall(r"\[td\b[^\]]*\](.*?)\[/td\]", row, re.S)
        if len(cells) <= ITEM_COLUMN:
            continue
        m = re.match(r"\s*\[item=(\d+)", cells[ITEM_COLUMN])
        if m:
            items.append(int(m.group(1)))
    return items


def _section_rows(markup, warnings):
    rows = {}
    parts = re.split(r'(\[h3\b[^\]]*\])', markup)
    for i in range(1, len(parts), 2):
        m = re.search(r'toc="([^"]+)"', parts[i])
        body = parts[i + 1] if i + 1 < len(parts) else ""
        items = _table_items(body)
        if not items:
            continue
        name = (m.group(1) if m else "").strip().lower()
        if name in IGNORED_SECTIONS:
            continue
        if name not in SECTION_SLOTS:
            warnings.append(f"unknown gear section '{name}' skipped")
            continue
        for slot in SECTION_SLOTS[name]:
            rows.setdefault(slot, [])
            for item in items:
                if item not in rows[slot]:
                    rows[slot].append(item)
    return rows


def _table_set(rows):
    """A set from the tables alone: the first row per slot, the first two for pairs."""
    slots = {}
    for slot, items in rows.items():
        if slot in (12, 14):
            continue
        if slot in (11, 13):
            if items:
                slots[slot] = {"item": items[0], "enchant": None, "gems": []}
            if len(items) > 1:
                slots[slot + 1] = {"item": items[1], "enchant": None, "gems": []}
        elif items:
            slots[slot] = {"item": items[0], "enchant": None, "gems": []}
    return {"name": FALLBACK_SET_NAME, "faction": None, "race": None, "slots": slots}


def parse(html, spec, filename):
    title = _title(html)
    if not any(phrase in title.lower() for phrase in spec["title"]):
        raise GuideError(f"page title '{title}' does not match the folder (expected '{' or '.join(spec['title'])}')")
    markup = _markup(html)
    warnings = []
    rows = _section_rows(markup, warnings)
    sets = _sets(markup)
    if not sets:
        if not rows:
            raise GuideError("no gear planner and no gear tables")
        sets = [_table_set(rows)]
        warnings.append("no gear planner: set built from the tables (no enchants or gems)")
    if "progression" in title.lower():
        for gear_set in sets:
            if gear_set["name"] == FALLBACK_SET_NAME:
                gear_set["name"] = "Progression"
    page_items = {int(x) for x in re.findall(r"\[item=(\d+)", markup)}
    return {
        "title": title,
        "url": _canonical(html),
        "updated": _updated(html),
        "author": _author(html),
        "spec": spec,
        "phase": phase_of(title, filename),
        "sets": sets,
        "rows": rows,
        "page_items": page_items,
        "warnings": warnings,
    }
