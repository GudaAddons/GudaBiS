-- Auto-roll (GB-070). The only module allowed to roll for the player (RULES.md Rule 4).
-- Off by default (settings.autoRoll), and off whenever Gargul is loaded: Gargul has its
-- own AutoRoll, and two addons rolling for one player is how wrong rolls happen.
--
-- Detect hands over each drop it already matched (Match:Item: never owned items, never
-- items on neither list), so this module only decides and acts:
--   - Blizzard group loot: MS -> Need, OS -> Greed, only when the roll offers that
--     button. An MS item that cannot be Needed is left alone, never Greeded. The BoP
--     confirmation is answered for these rolls only, never for the player's own.
--   - A raid-warning roll call from the master looter or the leader (not assistants):
--     one /roll per announcement, 1-100 for MS, 1-99 for OS. Not while RCLootCouncil
--     shows that item: that is a council vote, never answered for the player.
-- It never Passes. One chat line per action.
--
--   AutoRoll.Decide(match, canNeed, canGreed) -> NEED | GREED | nil
--   AutoRoll.RollRange(match) -> 100 (MS) | 99 (OS)
--   AutoRoll:Active() -> setting on and Gargul not loaded
--   AutoRoll:GroupLoot(rollID, link, match) -> true when it rolled
--   AutoRoll:RollCall(link, match, sender, message) -> true when it rolled

local addonName, ns = ...
local L = ns.L

local AutoRoll = ns:RegisterModule("AutoRoll")

local ROLL_NEED, ROLL_GREED = 1, 2
AutoRoll.NEED, AutoRoll.GREED = ROLL_NEED, ROLL_GREED

local pending = {}
local lastCall = { message = nil, at = nil }

function AutoRoll.Decide(match, canNeed, canGreed)
    if not match then return nil end
    if match.role == "ms" then return canNeed and ROLL_NEED or nil end
    return canGreed and ROLL_GREED or nil
end

function AutoRoll.RollRange(match)
    return match.role == "ms" and 100 or 99
end

function AutoRoll:GargulLoaded()
    local loaded = ns.IsAddOnLoaded
    return loaded ~= nil and loaded("Gargul") == true
end

function AutoRoll:Enabled()
    return ns.db ~= nil and ns.db.settings.autoRoll == true
end

function AutoRoll:Active()
    return self:Enabled() and not self:GargulLoaded()
end

local function Report(action, link, match)
    ns:Print(string.format(L.AUTOROLL_DONE, action, link, ns.Match.Label(match)))
end

local function RollOptions(rollID)
    if not GetLootRollItemInfo then return false, false end
    local _, _, _, _, _, canNeed, canGreed = GetLootRollItemInfo(rollID)
    return canNeed and true or false, canGreed and true or false
end

function AutoRoll:GroupLoot(rollID, link, match)
    if not self:Active() then return false end
    local rollType = AutoRoll.Decide(match, RollOptions(rollID))
    if not rollType then return false end
    pending[rollID] = rollType
    RollOnLoot(rollID, rollType)
    Report(rollType == ROLL_NEED and NEED or GREED, link, match)
    return true
end

-- One /roll per announcement: every matched link of one raid-warning message arrives
-- here at the same moment, and only the first of them rolls; the others count as
-- answered, so no popup asks for a second roll.
function AutoRoll:RollCall(link, match, sender, message)
    if not self:Active() or not ns.Detect.IsLootLeader(sender) then return false end
    local now = GetTime()
    if lastCall.message == message and lastCall.at == now then return true end
    lastCall.message, lastCall.at = message, now
    local high = AutoRoll.RollRange(match)
    RandomRoll(1, high)
    Report("/roll 1-" .. high, link, match)
    return true
end

local function OnConfirm(_, rollID, rollType)
    if pending[rollID] == nil or pending[rollID] ~= rollType then return end
    pending[rollID] = nil
    ConfirmLootRoll(rollID, rollType)
    if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID) end
end

local function OnRollGone(_, rollID)
    pending[rollID] = nil
end

local function SetEnabled(on)
    ns.Database:SetSetting("autoRoll", on)
    if on and AutoRoll:GargulLoaded() then
        ns:Print(L.AUTOROLL_GARGUL)
    else
        ns:Print(on and L.AUTOROLL_ON or L.AUTOROLL_OFF)
    end
end

ns.SlashCommands:Register("autoroll", function(args)
    if not ns.db then return end
    local mode = args[1] and args[1]:lower()
    if mode == "on" then
        SetEnabled(true)
    elseif mode == "off" then
        SetEnabled(false)
    else
        SetEnabled(not AutoRoll:Enabled())
    end
end, L.HELP_AUTOROLL)

ns.Events:Register("GBIS_INITIALIZED", function()
    ns.Events:RegisterGroup("CONFIRM_LOOT_ROLL", OnConfirm, "AutoRoll")
    ns.Events:RegisterGroup("CANCEL_LOOT_ROLL", OnRollGone, "AutoRoll")
end, "AutoRoll")
