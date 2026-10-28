-- Which client this is, and what it can do. Feature code asks ns.Features.<Flag>,
-- never WOW_PROJECT_ID or the interface number (RULES.md Rule 3).
--
-- WoW: Forever (interface 16000-19999, TOC suffix _Camelot) is the client where the
-- version number lies: it looks like Vanilla but runs the modern Retail API, with
-- Vanilla content and frame art. It has no WOW_PROJECT_ID constant of its own and may
-- report the Classic or Mainline ID, so it is decided by interface range, first.
-- Pattern and reasoning from GudaBags Core/Expansion.lua.

local addonName, ns = ...

local Expansion = ns:RegisterModule("Expansion")

local _, _, _, interfaceVersion = GetBuildInfo()
local iface = tonumber(interfaceVersion) or 0
Expansion.InterfaceVersion = iface

local project = WOW_PROJECT_ID

Expansion.IsForever = iface >= 16000 and iface < 20000
Expansion.IsRetail = Expansion.IsForever
    or (project == (WOW_PROJECT_MAINLINE or 1) and iface >= 100000)
Expansion.IsEra = not Expansion.IsForever and project == (WOW_PROJECT_CLASSIC or 2)
Expansion.IsTBC = project == (WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5)
Expansion.IsMists = project == (WOW_PROJECT_MISTS_CLASSIC or 19)

-- An unknown project ID must never select a feature set the client lacks, so fall
-- back to the interface range when no project test matched.
if not (Expansion.IsRetail or Expansion.IsEra or Expansion.IsTBC or Expansion.IsMists) then
    Expansion.IsRetail = iface >= 100000
    Expansion.IsEra = iface >= 11500 and iface < 20000
    Expansion.IsTBC = iface >= 20500 and iface < 30000
    Expansion.IsMists = iface >= 50500 and iface < 60000
end

Expansion.ClientKey = Expansion.IsForever and "Forever"
    or Expansion.IsEra and "Era"
    or Expansion.IsTBC and "TBC"
    or Expansion.IsMists and "Mists"
    or Expansion.IsRetail and "Retail"
    or "Unknown"

local isModernRetail = Expansion.IsRetail and not Expansion.IsForever
local isClassic = Expansion.IsEra or Expansion.IsTBC or Expansion.IsMists

-- Each flag answers one question. Flags that are true on the same clients today are
-- still kept apart when the questions differ; Forever is the client that splits them.
--
-- HasGems: sockets arrived in TBC. Forever has Vanilla items, so no gems.
-- HasMasterLoot: Retail removed it in 8.0.1. Unconfirmed on Forever, off until
--   /gbis probe proves it (GB-005).
-- HasPhases: content releases in phases (the Phase dropdown). Retail has seasons, not
--   phases: no Phase dropdown there (author, 2026-10-28).
-- HasSpecChoice: the player picks a specialization (MoP onwards). Elsewhere the spec
--   is inferred from where the talent points are. Forever unconfirmed (GB-005).
-- ChatLockdown: group chat text can be a secret value inside instances (12.0 engine).
-- ItemLevelMatters: the same item ID can be worn at different item levels (Retail
--   tracks; MoP Thunderforged, Warforged and valor upgrades).
-- HasWarbandBank: an account bank (Forever has AccountBankTab_1..9).
-- RealmlessNames: character names are "Given Family" with no realm (Forever).
-- HasRetailFrameArt: the client draws Retail's frame art (metal frames, modern
--   dropdowns). Retail, but not Forever: modern API, Vanilla art (as in GudaBags).
-- HasRangedSlot: a ranged / wand / relic slot (18). MoP removed it, so Retail has none
--   either; Forever plays Vanilla content and keeps it (author, 2026-10-28).
-- HasNativeDropdowns: use Blizzard's own dropdown (WowStyle1DropdownTemplate) with the
--   Classic frame art where the client has it: MoP Classic, besides Retail (GB-140).
--   UI/Dropdown.lua still falls back to the drawn one when the widget is missing.
-- HasModernCharacterFrame: the Character frame has no transparent margin and widens
--   with its stats pane (Retail, MoP Classic; author, 2026-10-29), so the panel and its
--   side tab dock right at its edge.
local Features = {
    RealmlessNames = Expansion.IsForever,
    HasGems = Expansion.IsTBC or Expansion.IsMists or isModernRetail,
    HasMasterLoot = isClassic,
    HasPhases = isClassic,
    HasSpecChoice = Expansion.IsMists or isModernRetail,
    ChatLockdown = Expansion.IsRetail,
    ItemLevelMatters = Expansion.IsMists or isModernRetail,
    HasWarbandBank = Expansion.IsRetail,
    HasRangedSlot = not (Expansion.IsMists or isModernRetail),
    HasRetailFrameArt = isModernRetail,
    HasNativeDropdowns = Expansion.IsMists or isModernRetail,
    HasModernCharacterFrame = Expansion.IsMists or isModernRetail,
}
Expansion.Features = Features
ns.Features = Features

-- Stable order for /gbis status, so output is comparable between runs and clients.
Expansion.FeatureNames = {
    "HasGems", "HasMasterLoot", "HasPhases", "HasSpecChoice",
    "ChatLockdown", "ItemLevelMatters", "HasWarbandBank", "RealmlessNames", "HasRangedSlot",
    "HasRetailFrameArt", "HasNativeDropdowns", "HasModernCharacterFrame",
}
