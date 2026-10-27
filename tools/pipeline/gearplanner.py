"""Decode Wowhead gear-planner strings ([gear-planner=class/race/CODE]).

CODE is URL-safe base64 of:
  version (1 byte, 3) · level (1) · talent byte count N (1) · talents (N bytes)
  hunters only: a pet block, 0x00 · pet talent byte count P · P bytes · 2 bytes (the pet)
  then one entry per equipped slot:
    slot byte: bit 7 = has enchant, bit 6 = has random suffix, bits 0-5 = INVSLOT
    flags byte: bits 5-7 = gem count, bits 0-4 = item ID bits 16-20
    item ID low 16 bits (2 bytes, big-endian)
    enchant spell ID (2 bytes) when bit 7 of the slot byte is set
    random suffix ID (2 bytes, signed) when bit 6 is set
    per gem: socket byte (bits 5-7 = socket index, bits 0-4 = gem ID bits 16-20)
             + gem ID low 16 bits (2 bytes)

Worked out from the saved TBC guides (2026-10-28) and checked against their tables:
  - item high bits: Retribution Phase 4 trinket 0d 04 4c8b = 0x4 << 16 | 0x4c8b = 281739
    (an Anniversary seasonal trinket)
  - random suffix: Feral nature-resistance 46 00 77d4 ffde = slot 6, item 30676, -34
  - pet block: every hunter string has 00 00 xxxx between talents and gear
Anything outside this layout raises instead of guessing.
"""

import base64

SUPPORTED_VERSION = 3
MAX_SLOT = 19


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
    if pos < len(raw) and raw[pos] == 0:
        if pos + 2 > len(raw):
            raise GearPlannerError("truncated pet block")
        pos += 2 + raw[pos + 1] + 2
    slots = {}
    while pos < len(raw):
        if pos + 2 > len(raw):
            raise GearPlannerError(f"truncated entry at byte {pos}")
        slot_byte, flags = raw[pos], raw[pos + 1]
        pos += 2
        slot = slot_byte & 0x3F
        if not 1 <= slot <= MAX_SLOT:
            raise GearPlannerError(f"slot {slot} out of range")
        if slot in slots:
            raise GearPlannerError(f"slot {slot} twice")
        item = ((flags & 0x1F) << 16) | _u16(raw, pos)
        pos += 2
        enchant = None
        if slot_byte & 0x80:
            enchant = _u16(raw, pos)
            pos += 2
        suffix = None
        if slot_byte & 0x40:
            suffix = _u16(raw, pos)
            if suffix >= 0x8000:
                suffix -= 0x10000
            pos += 2
        gems = []
        for _ in range(flags >> 5):
            if pos + 3 > len(raw):
                raise GearPlannerError(f"truncated gem in slot {slot}")
            socket = raw[pos]
            gems.append((socket >> 5, ((socket & 0x1F) << 16) | _u16(raw, pos + 1)))
            pos += 3
        gems.sort()
        slots[slot] = {"item": item, "enchant": enchant, "suffix": suffix, "gems": [gem for _, gem in gems]}
    return {"version": version, "level": level, "slots": slots}
