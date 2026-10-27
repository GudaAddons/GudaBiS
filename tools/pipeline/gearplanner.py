"""Decode Wowhead gear-planner strings ([gear-planner=class/race/CODE]).

CODE is URL-safe base64 of:
  version (1 byte, 3) · level (1) · talent byte count N (1) · talents (N bytes)
  then one entry per equipped slot:
    slot byte: bit 7 = has enchant, bits 0-6 = INVSLOT number (1 head ... 18 ranged/relic)
    flags byte: bits 5-7 = gem count, bits 0-4 = unknown (must be 0)
    item ID (2 bytes, big-endian)
    enchant spell ID (2 bytes) when bit 7 of the slot byte is set
    per gem: socket byte (bits 5-7 = socket index, bits 0-4 must be 0) + gem item ID (2 bytes)

Worked out from the TBC Protection Paladin Phase 4 guide (2026-10-28) and checked
against the guide's own tables. Anything outside this layout raises instead of
guessing: item IDs above 65535 (Anniversary seasonal items such as 281893) have not
been seen in a gear-planner string yet, and their encoding is unknown.
"""

import base64

SUPPORTED_VERSION = 3


class GearPlannerError(ValueError):
    pass


def _u16(raw, pos):
    if pos + 2 > len(raw):
        raise GearPlannerError(f"truncated at byte {pos}")
    return int.from_bytes(raw[pos:pos + 2], "big")


def decode(code):
    raw = base64.urlsafe_b64decode(code + "=" * (-len(code) % 4))
    if len(raw) < 3:
        raise GearPlannerError("too short")
    version, level, talent_bytes = raw[0], raw[1], raw[2]
    if version != SUPPORTED_VERSION:
        raise GearPlannerError(f"unsupported version {version}")
    pos = 3 + talent_bytes
    slots = {}
    while pos < len(raw):
        if pos + 2 > len(raw):
            raise GearPlannerError(f"truncated entry at byte {pos}")
        slot_byte, flags = raw[pos], raw[pos + 1]
        pos += 2
        slot = slot_byte & 0x7F
        if not 1 <= slot <= 19:
            raise GearPlannerError(f"slot {slot} out of range")
        if slot in slots:
            raise GearPlannerError(f"slot {slot} twice")
        if flags & 0x1F:
            raise GearPlannerError(f"unknown flag bits {flags & 0x1F:#x} in slot {slot}")
        item = _u16(raw, pos)
        pos += 2
        enchant = None
        if slot_byte & 0x80:
            enchant = _u16(raw, pos)
            pos += 2
        gems = []
        for _ in range(flags >> 5):
            if pos + 3 > len(raw):
                raise GearPlannerError(f"truncated gem in slot {slot}")
            socket = raw[pos]
            if socket & 0x1F:
                raise GearPlannerError(f"unknown socket bits {socket & 0x1F:#x} in slot {slot}")
            gems.append((socket >> 5, _u16(raw, pos + 1)))
            pos += 3
        gems.sort()
        slots[slot] = {"item": item, "enchant": enchant, "gems": [gem for _, gem in gems]}
    return {"version": version, "level": level, "slots": slots}
