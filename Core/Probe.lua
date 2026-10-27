-- /gbis probe (GB-005): writes what this client offers to the debug log, so feature
-- flags are decided from the real client instead of guesses (developer-guide §1).
-- Read-only: it calls query functions and checks names. It never registers an event,
-- creates a frame or rolls, so it is safe anywhere, in combat and in a raid too.

local addonName, ns = ...
local L = ns.L

local Probe = ns:RegisterModule("Probe")

local GLOBAL_FUNCTIONS = {
    "RollOnLoot", "RandomRoll", "ConfirmLootRoll", "GetLootRollItemInfo", "GetLootRollItemLink",
    "GetLootSlotLink", "GetLootMethod", "IsMasterLooter", "GetMasterLootCandidate",
    "UnitIsGroupLeader", "UnitIsGroupAssistant", "GetInventoryItemID", "GetInventoryItemLink",
    "GetTalentTabInfo", "GetActiveTalentGroup", "GetNumTalentGroups", "GetSpecialization",
    "InterfaceOptions_AddCategory", "GetNormalizedRealmName", "IsInGroup", "IsInRaid",
}

local NAMESPACED_FUNCTIONS = {
    { "C_PartyInfo", "GetLootMethod" },
    { "C_ChatInfo", "InChatMessagingLockdown" },
    { "C_SpecializationInfo", "GetSpecialization" },
    { "C_SpecializationInfo", "GetSpecializationInfo" },
    { "C_SpecializationInfo", "GetActiveSpecGroup" },
    { "C_Item", "RequestLoadItemDataByID" },
    { "C_Item", "GetItemInfo" },
    { "C_Container", "GetContainerItemID" },
    { "C_EventUtils", "IsEventValid" },
    { "Settings", "RegisterCanvasLayoutCategory" },
    { "Settings", "RegisterAddOnCategory" },
    { "Settings", "OpenToCategory" },
    { "Item", "CreateFromItemID" },
}

local EVENTS = {
    "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "LOOT_ROLLS_COMPLETE", "CONFIRM_LOOT_ROLL",
    "LOOT_OPENED", "OPEN_MASTER_LOOT_LIST", "CHAT_MSG_LOOT", "CHAT_MSG_RAID_WARNING",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "ITEM_DATA_LOAD_RESULT",
    "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED",
}

local FRAMES = {
    "CharacterFrame", "PaperDollFrame", "CharacterHeadSlot", "GroupLootContainer",
    "GroupLootFrame1", "MasterLooterFrame", "LootFrame",
}

local ADDONS = { "GudaBags", "Gargul", "RCLootCouncil", "RCLootCouncil_Classic" }

local function Describe(...)
    local n = select("#", ...)
    if n == 0 then return "(nothing)" end
    local parts = {}
    for i = 1, n do
        local value = select(i, ...)
        parts[i] = type(value) == "table" and "table" or tostring(value)
    end
    return table.concat(parts, ", ")
end

local function CallResult(ok, ...)
    if not ok then return "error: " .. tostring((...)) end
    return Describe(...)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return "MISSING" end
    return CallResult(pcall(fn, ...))
end

local function Write(fmt, ...)
    ns.Log:Add("probe", string.format(fmt, ...))
end

local function ProbeClient()
    local version, build, _, iface = GetBuildInfo()
    Write("client %s · version %s · build %s · interface %s · project %s",
        ns.Expansion.ClientKey, tostring(version), tostring(build), tostring(iface), tostring(WOW_PROJECT_ID))
end

local function ProbeNames()
    local missing = {}
    for _, name in ipairs(GLOBAL_FUNCTIONS) do
        if type(_G[name]) ~= "function" then missing[#missing + 1] = name end
    end
    Write("global functions missing: %s", #missing > 0 and table.concat(missing, ", ") or "none")
    wipe(missing)
    for _, pair in ipairs(NAMESPACED_FUNCTIONS) do
        local namespace = _G[pair[1]]
        if type(namespace) ~= "table" or type(namespace[pair[2]]) ~= "function" then
            missing[#missing + 1] = pair[1] .. "." .. pair[2]
        end
    end
    Write("namespaced functions missing: %s", #missing > 0 and table.concat(missing, ", ") or "none")
end

local function ProbeEvents()
    local isValid = C_EventUtils and C_EventUtils.IsEventValid
    if type(isValid) ~= "function" then
        Write("events: C_EventUtils.IsEventValid MISSING, cannot check")
        return
    end
    local unknown = {}
    for _, event in ipairs(EVENTS) do
        local ok, valid = pcall(isValid, event)
        if not ok or not valid then unknown[#unknown + 1] = event end
    end
    Write("events not valid: %s", #unknown > 0 and table.concat(unknown, ", ") or "none")
end

local function ProbeLoot()
    Write("in group %s · in raid %s", Call(IsInGroup), Call(IsInRaid))
    Write("GetLootMethod() = %s", Call(_G.GetLootMethod))
    Write("C_PartyInfo.GetLootMethod() = %s", Call(C_PartyInfo and C_PartyInfo.GetLootMethod))
    Write("IsMasterLooter() = %s", Call(_G.IsMasterLooter))
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        local container = frame and frame.LootButtonContainer
        Write("GroupLootFrame%d: %s · .NeedButton %s · .LootButtonContainer.NeedButton %s · resolved %s",
            i, frame and "yes" or "no",
            frame and frame.NeedButton and "yes" or "no",
            container and container.NeedButton and "yes" or "no",
            ns.Compat.GetGroupLootNeedButton(i) and "yes" or "no")
    end
end

local function ProbeChat()
    Write("C_ChatInfo.InChatMessagingLockdown() = %s",
        Call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown))
end

local function ProbeSpec()
    local spec = C_SpecializationInfo
    Write("C_SpecializationInfo.GetSpecialization() = %s", Call(spec and spec.GetSpecialization))
    Write("C_SpecializationInfo.GetActiveSpecGroup() = %s", Call(spec and spec.GetActiveSpecGroup))
    for i = 1, 4 do
        Write("C_SpecializationInfo.GetSpecializationInfo(%d) = %s", i, Call(spec and spec.GetSpecializationInfo, i))
    end
    for i = 1, 3 do
        Write("GetTalentTabInfo(%d) = %s", i, Call(_G.GetTalentTabInfo, i))
    end
    Write("GetActiveTalentGroup() = %s · GetNumTalentGroups() = %s",
        Call(_G.GetActiveTalentGroup), Call(_G.GetNumTalentGroups))
end

local function ProbeUI()
    local missing = {}
    for _, name in ipairs(FRAMES) do
        if not _G[name] then missing[#missing + 1] = name end
    end
    Write("frames missing now: %s", #missing > 0 and table.concat(missing, ", ") or "none")
    Write("Settings API: canvas %s · addon category %s · InterfaceOptions_AddCategory %s",
        Settings and Settings.RegisterCanvasLayoutCategory and "yes" or "no",
        Settings and Settings.RegisterAddOnCategory and "yes" or "no",
        _G.InterfaceOptions_AddCategory and "yes" or "no")
    Write("Item:CreateFromItemID %s · ItemMixin:ContinueOnItemLoad %s",
        Item and Item.CreateFromItemID and "yes" or "no",
        ItemMixin and ItemMixin.ContinueOnItemLoad and "yes" or "no")
end

local function ProbeAddons()
    local loaded = {}
    for _, name in ipairs(ADDONS) do
        local ok, isLoaded = pcall(ns.IsAddOnLoaded, name)
        loaded[#loaded + 1] = name .. "=" .. (ok and isLoaded and "yes" or "no")
    end
    Write("addons: %s · Gargul global %s · Gargul.Events %s",
        table.concat(loaded, ", "),
        _G.Gargul and "yes" or "no",
        _G.Gargul and _G.Gargul.Events and "yes" or "no")
end

function Probe:Run()
    ProbeClient()
    ProbeNames()
    ProbeEvents()
    ProbeLoot()
    ProbeChat()
    ProbeSpec()
    ProbeUI()
    ProbeAddons()
end

ns.SlashCommands:Register("probe", function()
    Probe:Run()
    ns:Print(L.PROBE_DONE)
    if not (ns.Log.frame and ns.Log.frame:IsShown()) then ns.Log:Toggle() end
end, L.HELP_PROBE)
