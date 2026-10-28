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
-- Where the same item drops at different item levels (ns.Features.ItemLevelMatters,
-- Retail), Owned:BestLevel reads the item level of the player's equipped and bagged
-- copies of one item, only when asked (a panel slot or tooltip on show, a drop): the
-- scans above stay ID-only. Bank and other characters keep IDs only, so they have no
-- level (GB-065).
--
-- Pure parts, tested offline: Owned.SlotStatus, Owned.LevelStatus.

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

-- The check a slot shows, about the item shown only (author, 2026-10-28): "best" when
-- this character has it, "elsewhere" when only another character does, else nil.
-- Alternatives never mark the slot. `has(itemID)` and `state(itemID)` are passed in so
-- this stays pure.
-- The highest item level among the player's equipped and bagged copies of itemID, or
-- nil when there is none there (or the client cannot tell).
function Owned:BestLevel(itemID)
    local levelOf = ns.GetDetailedItemLevelInfo
    if not (itemID and levelOf) then return nil end
    local best
    local function Consider(link)
        local level = link and levelOf(link)
        if level and (not best or level > best) then best = level end
    end
    for slot = FIRST_EQUIP_SLOT, LAST_EQUIP_SLOT do
        if GetInventoryItemID("player", slot) == itemID then Consider(GetInventoryItemLink("player", slot)) end
    end
    local api = C_Container
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, api.GetContainerNumSlots(bag) or 0 do
            if api.GetContainerItemID(bag, slot) == itemID then Consider(api.GetContainerItemLink(bag, slot)) end
        end
    end
    return best
end

-- "lower" when the player's best copy is under the list's target level for the item
-- (the highest the top players wear it at), "full" when at or above it, nil when either
-- level is unknown.
function Owned.LevelStatus(have, target)
    if not (have and target) then return nil end
    return have < target and "lower" or "full"
end

function Owned.SlotStatus(list, slot, has, state)
    if not list then return nil end
    local best = list.items[slot]
    if not best then return nil end
    if has(best) then return "best" end
    if state(best) == "alt" then return "elsewhere" end
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
