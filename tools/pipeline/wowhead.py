"""Read a Wowhead BiS guide saved from the browser ("Webpage, HTML only").

The page embeds the guide as Wowhead markup in WH.markup.printHtml("...").
From it we take:
  - the canonical URL (class, spec and phase come from its slug)
  - the "Updated" date
  - every [tab name="..."] holding a [gear-planner=class/race/CODE]: one BiS set each
  - the per-slot tables under [h3 toc="Head"] etc.: [td][item=ID] rows, in page order
"""

import json
import re

import gearplanner
import specs

# Wowhead section names (the h3 toc attribute) -> INVSLOT numbers.
SECTION_SLOTS = {
    "head": [1], "helm": [1], "helmet": [1],
    "neck": [2],
    "shoulder": [3], "shoulders": [3],
    "back": [15], "cloak": [15], "cloaks": [15],
    "chest": [5],
    "wrist": [9], "wrists": [9], "bracers": [9],
    "hands": [10], "gloves": [10],
    "waist": [6], "belt": [6], "belts": [6],
    "legs": [7],
    "feet": [8], "boots": [8],
    "rings": [11, 12], "ring": [11, 12],
    "trinkets": [13, 14], "trinket": [13, 14],
    "weapons": [16], "weapon": [16], "main hand": [16], "main-hand": [16], "two-hand": [16],
    "two-handed weapons": [16], "one-handed weapons": [16],
    "off hand": [17], "off-hand": [17], "off-hands": [17], "shields": [17], "shield": [17],
    "librams": [18], "libram": [18], "idols": [18], "idol": [18], "totems": [18], "totem": [18],
    "relics": [18], "relic": [18], "ranged": [18], "wands": [18], "wand": [18], "thrown": [18],
}

# Sections that are prose about choices, not gear tables.
IGNORED_SECTIONS = {"aldor vs. scryer"}


class GuideError(ValueError):
    pass


def _markup(html):
    blocks = [json.loads(m.group(1)) for m in re.finditer(r'WH\.markup\.printHtml\(("(?:[^"\\]|\\.)*")', html)]
    if not blocks:
        raise GuideError("no WH.markup.printHtml block (was the page saved as HTML?)")
    return max(blocks, key=len)


def _canonical(html):
    m = re.search(r'<link rel="canonical" href="([^"]+)"', html)
    if not m:
        raise GuideError("no canonical URL")
    return m.group(1)


def _updated(html):
    m = re.search(r'Updated:\s*<span[^>]*>\s*(\d{4})/(\d{2})/(\d{2})', html)
    return f"{m.group(1)}-{m.group(2)}-{m.group(3)}" if m else None


def _phase(slug):
    m = re.search(r"phase-(\d)", slug)
    if m:
        return int(m.group(1))
    if "pre-raid" in slug or "preraid" in slug:
        return 0
    raise GuideError(f"no phase in {slug}")


def _sets(markup):
    found = []
    tabs = list(re.finditer(r'\[tab\b[^\]]*\bname="([^"]+)"[^\]]*\](.*?)\[/tab\]', markup, re.S))
    sources = [(m.group(1).strip(), m.group(2)) for m in tabs] or [("BiS", markup)]
    for name, body in sources:
        m = re.search(r"\[gear-planner=([a-z-]+)/([a-z-]+)/([A-Za-z0-9_-]+)\]", body)
        if not m:
            continue
        faction = None
        lowered = name.lower()
        if "horde" in lowered:
            faction = "Horde"
        elif "alliance" in lowered:
            faction = "Alliance"
        decoded = gearplanner.decode(m.group(3))
        found.append({"name": name, "faction": faction, "race": m.group(2), "slots": decoded["slots"]})
    if not found:
        raise GuideError("no [gear-planner] set found")
    return found


def _section_rows(markup):
    rows = {}
    parts = re.split(r'(\[h3\b[^\]]*\])', markup)
    for i in range(1, len(parts), 2):
        m = re.search(r'toc="([^"]+)"', parts[i])
        body = parts[i + 1] if i + 1 < len(parts) else ""
        items = [int(x) for x in re.findall(r"\[td\]\s*\[item=(\d+)", body)]
        if not items:
            continue
        name = (m.group(1) if m else "").strip().lower()
        if name in IGNORED_SECTIONS:
            continue
        if name not in SECTION_SLOTS:
            raise GuideError(f"unknown gear section '{name}' (add it to SECTION_SLOTS)")
        for slot in SECTION_SLOTS[name]:
            rows.setdefault(slot, [])
            for item in items:
                if item not in rows[slot]:
                    rows[slot].append(item)
    return rows


def parse(html):
    url = _canonical(html)
    slug = url.rstrip("/").rsplit("/", 1)[-1]
    spec = specs.lookup(slug)
    markup = _markup(html)
    page_items = {int(x) for x in re.findall(r"\[item=(\d+)", markup)}
    return {
        "url": url,
        "updated": _updated(html),
        "spec": spec,
        "phase": _phase(slug),
        "sets": _sets(markup),
        "rows": _section_rows(markup),
        "page_items": page_items,
    }
