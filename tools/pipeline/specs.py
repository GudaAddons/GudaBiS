"""The author's source folders -> our spec key (2026-10-28).

Saved pages live in <source>/<Class>/<Spec>/<file>.htm (Rogue has no spec folder).
The folder is the reliable source of class and spec: a browser's "Save complete"
rewrites many canonical links to local file names, and Wowhead's generic phase 2 and
pre-raid guides do not name the class in their slug.

key: stable CLASS_SPEC string. tree: the talent tab (1-3) used to pick the default list
on Era/TBC by points spent. specID: the client's ID, only where /gbis probe measured it
(paladin); None otherwise, never guessed. title: a phrase (or tuple of phrases) the page title must contain,
so a page saved into the wrong folder is reported instead of loaded.
"""

SPECS = {
    ("druid", "balance"): {"key": "DRUID_BALANCE", "class": "DRUID", "tree": 1, "title": "balance"},
    ("druid", "feral"): {"key": "DRUID_FERAL_TANK", "class": "DRUID", "tree": 2, "title": "feral"},
    ("hunter", "beast mastery"): {"key": "HUNTER_BEASTMASTERY", "class": "HUNTER", "tree": 1, "title": "beast mastery"},
    ("hunter", "marksmanship"): {"key": "HUNTER_MARKSMANSHIP", "class": "HUNTER", "tree": 2, "title": "marksmanship"},
    ("hunter", "survival"): {"key": "HUNTER_SURVIVAL", "class": "HUNTER", "tree": 3, "title": "survival"},
    ("mage", "arcane"): {"key": "MAGE_ARCANE", "class": "MAGE", "tree": 1, "title": "arcane"},
    ("mage", "fire"): {"key": "MAGE_FIRE", "class": "MAGE", "tree": 2, "title": "fire"},
    ("mage", "frost"): {"key": "MAGE_FROST", "class": "MAGE", "tree": 3, "title": "frost"},
    ("paladin", "holy"): {"key": "PALADIN_HOLY", "class": "PALADIN", "tree": 1, "specID": 382, "title": "holy"},
    ("paladin", "protection"): {"key": "PALADIN_PROTECTION", "class": "PALADIN", "tree": 2, "specID": 383, "title": "protection"},
    ("paladin", "retribution"): {"key": "PALADIN_RETRIBUTION", "class": "PALADIN", "tree": 3, "specID": 381, "title": "retribution"},
    ("priest", "healing"): {"key": "PRIEST_HEALING", "class": "PRIEST", "tree": 2, "title": "priest healing"},
    ("priest", "shadow"): {"key": "PRIEST_SHADOW", "class": "PRIEST", "tree": 3, "title": "shadow"},
    ("rogue", ""): {"key": "ROGUE_DPS", "class": "ROGUE", "tree": 2, "title": "rogue"},
    ("shaman", "elemental"): {"key": "SHAMAN_ELEMENTAL", "class": "SHAMAN", "tree": 1, "title": "elemental"},
    ("shaman", "enhancement"): {"key": "SHAMAN_ENHANCEMENT", "class": "SHAMAN", "tree": 2, "title": "enhancement"},
    ("shaman", "restoration"): {"key": "SHAMAN_RESTORATION", "class": "SHAMAN", "tree": 3, "title": "restoration"},
    ("warlock", "afliction"): {"key": "WARLOCK_AFFLICTION", "class": "WARLOCK", "tree": 1, "title": "affliction"},
    ("warlock", "affliction"): {"key": "WARLOCK_AFFLICTION", "class": "WARLOCK", "tree": 1, "title": "affliction"},
    ("warlock", "demonology"): {"key": "WARLOCK_DEMONOLOGY", "class": "WARLOCK", "tree": 2, "title": "demonology"},
    ("warlock", "destro"): {"key": "WARLOCK_DESTRUCTION", "class": "WARLOCK", "tree": 3, "title": "destruction"},
    ("warlock", "destruction"): {"key": "WARLOCK_DESTRUCTION", "class": "WARLOCK", "tree": 3, "title": "destruction"},
    ("warrior", "arms"): {"key": "WARRIOR_ARMS", "class": "WARRIOR", "tree": 1, "title": ("arms", "warrior dps")},
    ("warrior", "fury"): {"key": "WARRIOR_FURY", "class": "WARRIOR", "tree": 2, "title": ("fury", "warrior dps")},
    ("warrior", "prot"): {"key": "WARRIOR_PROTECTION", "class": "WARRIOR", "tree": 3, "title": "protection"},
}


class UnknownSpec(KeyError):
    pass


def lookup(class_folder, spec_folder):
    key = (class_folder.strip().lower(), spec_folder.strip().lower())
    spec = SPECS.get(key)
    if not spec:
        raise UnknownSpec(f"no spec for folder {class_folder}/{spec_folder} (add it to tools/pipeline/specs.py)")
    out = dict(spec)
    out.setdefault("specID", None)
    if isinstance(out["title"], str):
        out["title"] = (out["title"],)
    return out
