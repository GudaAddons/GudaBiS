"""Wowhead guide slug prefix -> our spec key.

key: stable CLASS_SPEC string (data and saved lists use it; feral splits by role).
specID: the client's specialization ID (seen with /gbis probe); None until measured.
tree: talent tab index (1-3) used to detect the spec on Era/TBC by points spent.

Add a row when a new guide's slug is not found. Never guess a specID: it comes
from /gbis probe on that class (architecture.md section 10).
"""

SPECS = {
    "paladin-tank": {"key": "PALADIN_PROTECTION", "class": "PALADIN", "specID": 383, "tree": 2},
}


class UnknownSpec(KeyError):
    pass


def lookup(slug):
    best = None
    for prefix in SPECS:
        if slug == prefix or slug.startswith(prefix + "-"):
            if best is None or len(prefix) > len(best):
                best = prefix
    if best is None:
        raise UnknownSpec(f"no spec for guide slug '{slug}' (add it to tools/pipeline/specs.py)")
    return dict(SPECS[best])
