-- Which BiS items this account already has (GB-030/031).
--
-- Each character keeps three small sets of item IDs in its GudaBiS_DB.chars entry:
-- equipped, bags and bank. Only equippable items (armor, weapons) are kept, by ID and
-- without counts, so a character costs a few hundred numbers at most, and another
-- character's lists can still say "on <alt>". The bank is read only while it is open and
-- kept from the last visit.
--
-- Scans are ID-only (GetInventoryItemID, C_Container.GetContainerItemID) and run on
-- the batched events: PLAYER_EQUIPMENT_CHANGED, BAG_UPDATE_DELAYED, and the bank events
-- while the bank is open. Each scan fires GBIS_OWNED_CHANGED once.
--
-- Manual marks (char.manual[itemID] = true | false) override everything: true counts
-- the item as owned, false as not needed.
--
-- Pure part, tested offline: Owned.SlotStatus.

local addonName, ns = ...

local Owned = ns:RegisterModule("Owned")

local GetItemInfoInstant = ns.GetItemInfoInstant

local CLASS_WEAPON = 2
local CLASS_ARMOR = 4
local FIRST_EQUIP_SLOT = 1
local LAST_EQUIP_SLOT = 19

local bankOpen = false

local function Equippable(itemID)
    local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
    return classID == CLASS_ARMOR or classID == CLASS_WEAPON
end

local function CharTable(name)
    local char = ns.Database:Char()
    if not char then return nil end
    local t = char[name]
    if not t then
        t = {}
        char[name] = t
    end
    return t
end

local function ScanBag(target, bag)
    local api = C_Container
    for slot = 1, api.GetContainerNumSlots(bag) or 0 do
        local itemID = api.GetContainerItemID(bag, slot)
        if itemID and Equippable(itemID) then target[itemID] = true end
    end
end

local function ScanBags(target, first, last, extra)
    wipe(target)
    if extra then ScanBag(target, extra) end
    for bag = first, last do ScanBag(target, bag) end
end

function Owned:ScanEquipped()
    local equipped = CharTable("equipped")
    if not equipped then return end
    wipe(equipped)
    for slot = FIRST_EQUIP_SLOT, LAST_EQUIP_SLOT do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then equipped[itemID] = true end
    end
    ns.Events:Fire("GBIS_OWNED_CHANGED")
end

function Owned:ScanBags()
    local bags = CharTable("bags")
    if not bags then return end
    ScanBags(bags, 0, NUM_BAG_SLOTS or 4)
    ns.Events:Fire("GBIS_OWNED_CHANGED")
end

-- The classic bank: the main bank container plus the bank bags after the carried
-- ones. Retail and Forever bank tabs are handled in their flavor milestones.
function Owned:ScanBank()
    if not bankOpen then return end
    local bank = CharTable("bank")
    if not bank then return end
    local first = (NUM_BAG_SLOTS or 4) + 1
    ScanBags(bank, first, first + (NUM_BANKBAGSLOTS or 6) - 1, BANK_CONTAINER or -1)
    ns.Events:Fire("GBIS_OWNED_CHANGED")
end

local function ShortName(key)
    return (key:match("^([^%-]+)")) or key
end

-- How the account has this item: "equipped", "bags", "bank", "manual" (marked owned),
-- "skip" (marked not needed), "alt" (another character, its name second), or nil.
function Owned:State(itemID)
    local char = ns.Database:Char()
    if not char or not itemID then return nil end
    local mark = char.manual and char.manual[itemID]
    if mark == false then return "skip" end
    if char.equipped and char.equipped[itemID] then return "equipped" end
    if char.bags and char.bags[itemID] then return "bags" end
    if char.bank and char.bank[itemID] then return "bank" end
    if mark == true then return "manual" end
    local me = ns.Database:PlayerKey()
    for key, other in pairs(ns.db.chars) do
        if key ~= me and ((other.equipped and other.equipped[itemID])
            or (other.bags and other.bags[itemID]) or (other.bank and other.bank[itemID])) then
            return "alt", ShortName(key)
        end
    end
    return nil
end

local OWNED_STATES = { equipped = true, bags = true, bank = true, manual = true, skip = true }

local STATE_TEXT = {
    equipped = "OWNED_EQUIPPED", bags = "OWNED_BAGS", bank = "OWNED_BANK",
    manual = "OWNED_MANUAL", skip = "OWNED_SKIP",
}

-- The tooltip line for an item's state: text, r, g, b; nil when the account lacks it.
function Owned:Describe(itemID)
    local L = ns.L
    local state, altName = self:State(itemID)
    if state == "alt" then return string.format(L.OWNED_ALT, altName), 0.7, 0.7, 0.7 end
    if state then return L[STATE_TEXT[state]], 0.1, 1, 0.1 end
    return nil
end

-- Owned counts as done for the slot: on this character or marked by hand. An item on
-- another character still needs moving, so it is shown but does not complete the slot.
function Owned:Has(itemID)
    return OWNED_STATES[self:State(itemID)] == true
end

-- Right-click on a slot: an item that counts as owned is marked "not needed" so it
-- stops alerting; anything else is marked owned; a second right-click clears the mark.
function Owned:ToggleManual(itemID)
    local char = ns.Database:Char()
    if not char or not itemID then return end
    char.manual = char.manual or {}
    if char.manual[itemID] ~= nil then
        char.manual[itemID] = nil
    else
        local state = self:State(itemID)
        char.manual[itemID] = not (state == "equipped" or state == "bags" or state == "bank")
    end
    ns.Events:Fire("GBIS_OWNED_CHANGED")
end

-- The check a slot shows: "best" when the #1 item is had, "using" when one of its
-- ranked alternatives is equipped, "elsewhere" when only another character has the #1,
-- else nil. An alternative only in bags or bank gives no check (author, 2026-10-28).
-- The second value is the item that decided it. `has(itemID)` and `state(itemID)` are
-- passed in so this stays pure.
function Owned.SlotStatus(list, slot, has, state)
    if not list then return nil end
    local best = list.items[slot]
    if not best then return nil end
    if has(best) then return "best", best end
    local alts = list.alts and list.alts[slot]
    if alts then
        for _, itemID in ipairs(alts) do
            if state(itemID) == "equipped" then return "using", itemID end
        end
    end
    if state(best) == "alt" then return "elsewhere", best end
    return nil
end

local events = ns.Events

events:Register("PLAYER_LOGIN", function()
    Owned:ScanEquipped()
    Owned:ScanBags()
end, "Owned")
events:Register("PLAYER_EQUIPMENT_CHANGED", function() Owned:ScanEquipped() end, "Owned")
events:Register("BAG_UPDATE_DELAYED", function()
    Owned:ScanBags()
    Owned:ScanBank()
end, "Owned")
events:Register("BANKFRAME_OPENED", function()
    bankOpen = true
    Owned:ScanBank()
end, "Owned")
events:Register("PLAYERBANKSLOTS_CHANGED", function() Owned:ScanBank() end, "Owned")
events:Register("BANKFRAME_CLOSED", function() bankOpen = false end, "Owned")
