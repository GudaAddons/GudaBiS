-- RCLootCouncil (GB-064). Raiders with RCLootCouncil get its loot frame (the
-- RCLootFrame module) listing the items of the session, one entry per item. After each
-- LootFrame:Update we badge the entries holding a BiS item. We never answer for the
-- player: the response buttons belong to RCLootCouncil and the council's vote.
--
-- Read from RCLootCouncil_Classic source (Modules/lootFrame.lua): the module is
-- addon:GetModule("RCLootFrame"), entries live in LootFrame.EntryManager.entries, each
-- with entry.item.link and entry.frame. Guarded throughout (RULES.md Rule 5).

local addonName, ns = ...

local RCLootCouncilBridge = ns:RegisterModule("RCLootCouncilBridge")

local ADDON_NAMES = { RCLootCouncil = true, RCLootCouncil_Classic = true }

local lootFrame
local announced = {}

local function LootFrameModule()
    local aceAddon = LibStub and LibStub("AceAddon-3.0", true)
    if not aceAddon then return nil end
    local ok, rc = pcall(aceAddon.GetAddon, aceAddon, "RCLootCouncil", true)
    if not ok or not rc then return nil end
    local found, module = pcall(rc.GetModule, rc, "RCLootFrame", true)
    return found and module or nil
end

local function Entries()
    local manager = lootFrame and lootFrame.EntryManager
    return type(manager) == "table" and type(manager.entries) == "table" and manager.entries or nil
end

-- Whether RCLootCouncil's frame shows this item now.
function RCLootCouncilBridge:IsShowing(itemID)
    for _, entry in pairs(Entries() or {}) do
        local item = type(entry) == "table" and entry.item
        local frame = type(entry) == "table" and entry.frame
        if type(item) == "table" and frame and frame:IsShown()
            and ns.Match.ItemIDFromLink(item.link) == itemID then
            return true
        end
    end
    return false
end

local function OnUpdate()
    if not ns.Alerts:Enabled() then return end
    for _, entry in pairs(Entries() or {}) do
        local item = type(entry) == "table" and entry.item
        local frame = type(entry) == "table" and entry.frame
        if type(item) == "table" and frame then
            local itemID = ns.Match.ItemIDFromLink(item.link)
            local match = itemID and ns.Match:Item(itemID, nil, item.link)
            if match then
                local icon = type(entry.icon) == "table" and entry.icon or nil
                ns.Alerts:Badge(frame, match, icon)
                if not announced[item.link] then
                    announced[item.link] = true
                    ns.Alerts:Sound()
                end
            else
                ns.Alerts:ClearBadge(frame)
            end
        end
    end
end

local function Hook()
    if lootFrame then return end
    local module = LootFrameModule()
    if type(module) ~= "table" or type(module.Update) ~= "function" then return end
    lootFrame = module
    hooksecurefunc(module, "Update", function()
        local ok, err = pcall(OnUpdate)
        if not ok then ns:Debug("RCLootCouncil update:", err) end
    end)
end

ns.Events:Register("GBIS_INITIALIZED", Hook, "RCLootCouncilBridge")
ns.Events:Register("ADDON_LOADED", function(_, name)
    if ADDON_NAMES[name] then Hook() end
end, "RCLootCouncilBridge")
