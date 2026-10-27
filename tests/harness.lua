-- Offline harness: stubs just enough of the WoW API to load the real addon files
-- (in TOC order) under a chosen client, fire events at them and inspect the result.
-- Never loaded by the game (tests/ is in no TOC and is not packaged).

local H = {}

local ROOT = assert(arg and arg[1], "usage: lua5.1 tests/run.lua <addon root>")
H.ROOT = ROOT

-- Each client's interface number, project ID and TOC. A flavor whose TOC does not
-- exist yet loads the TBC one, so the shared code is still tested on that client.
local CLIENTS = {
    era = { iface = 11509, project = 2, toc = "GudaBiS_Vanilla.toc" },
    tbc = { iface = 20506, project = 5, toc = "GudaBiS_TBC.toc" },
    mists = { iface = 50504, project = 19, toc = "GudaBiS_Mists.toc" },
    retail = { iface = 120105, project = 1, toc = "GudaBiS_Mainline.toc" },
    forever = { iface = 16001, project = 1, toc = "GudaBiS_Camelot.toc" },
}
H.CLIENTS = CLIENTS

local function FileExists(path)
    local file = io.open(path, "r")
    if file then file:close() end
    return file ~= nil
end

function H.TocFor(client)
    if client.toc and FileExists(ROOT .. "/" .. client.toc) then return client.toc end
    return "GudaBiS_TBC.toc"
end

-- The .lua paths a TOC lists, in order, with forward slashes.
function H.TocFiles(tocName)
    local files = {}
    local toc = assert(io.open(ROOT .. "/" .. tocName, "r"))
    for line in toc:lines() do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    toc:close()
    return files
end

local frames

local function NoOp() end

local function NewFrame(name)
    local frame = { registered = {}, scripts = {}, shown = false, globalName = name }
    function frame:RegisterEvent(event) self.registered[event] = true end
    function frame:UnregisterEvent(event) self.registered[event] = nil end
    function frame:SetScript(script, fn) self.scripts[script] = fn end
    function frame:GetScript(script) return self.scripts[script] end
    function frame:IsShown() return self.shown end
    function frame:SetText(text) self.shownText = text end
    function frame:GetStringWidth() return #(rawget(self, "shownText") or "") * 6 end
    function frame:GetText() return self.shownText end
    function frame:SetTexture(texture) self.texture = texture end
    function frame:SetShown(shown) self.shown = shown and true or false end
    function frame:GetVerticalScrollRange() return 0 end
    function frame:GetFrameLevel() return 0 end
    function frame:GetWidth() return rawget(self, "width") or 0 end
    function frame:GetHeight() return rawget(self, "height") or 0 end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetTextColor(r, g, b) self.textColor = { r, g, b } end
    function frame:SetVertexColor(r, g, b) self.vertexColor = { r, g, b } end
    function frame:GetHighlightTexture()
        self.highlight = rawget(self, "highlight") or NewFrame()
        return self.highlight
    end
    function frame:GetNormalTexture()
        self.normalTexture = rawget(self, "normalTexture") or NewFrame()
        return self.normalTexture
    end
    function frame:GetFontString()
        self.fontString = rawget(self, "fontString") or NewFrame()
        return self.fontString
    end
    function frame:GetCheckedTexture()
        self.checkedTexture = rawget(self, "checkedTexture") or NewFrame()
        return self.checkedTexture
    end
    function frame:SetBlendMode(mode) self.blendMode = mode end
    function frame:IsMouseOver() return rawget(self, "mouseOver") or false end
    function frame:CreateAnimationGroup()
        local group = NewFrame()
        function group:CreateAnimation() return NewFrame() end
        function group:Play()
            self.playing = true
            local finished = self.scripts.OnFinished
            if finished then finished(self) end
        end
        function group:Stop() self.playing = false end
        return group
    end
    function frame:SetButtonState(state, locked) self.buttonState, self.stateLocked = state, locked end
    function frame:SetChecked(checked) self.checked = checked and true or false end
    function frame:GetChecked() return rawget(self, "checked") or false end
    function frame:Script(name, ...)
        local fn = self.scripts[name]
        if fn then return fn(self, ...) end
    end
    function frame:HookScript(script, fn)
        local previous = self.scripts[script]
        self.scripts[script] = function(...)
            if previous then previous(...) end
            fn(...)
        end
    end
    function frame:Click()
        local onClick = self.scripts.OnClick
        if onClick then onClick(self, "LeftButton") end
    end
    function frame:Enter()
        local onEnter = self.scripts.OnEnter
        if onEnter then onEnter(self) end
    end
    function frame:Show()
        self.shown = true
        local onShow = self.scripts.OnShow
        if onShow then onShow(self) end
    end
    function frame:Hide()
        local was = self.shown
        self.shown = false
        local onHide = self.scripts.OnHide
        if was and onHide then onHide(self) end
    end
    frame.children = {}
    function frame:CreateFontString() local child = NewFrame(); self.children[#self.children + 1] = child; return child end
    function frame:CreateTexture() local child = NewFrame(); self.children[#self.children + 1] = child; return child end
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return setmetatable(frame, {
        __index = function(_, key)
            if type(key) == "string" and key:match("^%u") then return NoOp end
            return nil
        end,
    })
end

function H.AllFrames()
    return frames
end

-- Replaces every stubbed global. opts.client is a CLIENTS key (default "tbc") or a
-- custom { iface, project }; opts.locale, opts.saved (GudaBiS_DB before load),
-- opts.playerName, opts.normalizedRealm (false removes GetNormalizedRealmName).
function H.Install(opts)
    opts = opts or {}
    local client = type(opts.client) == "table" and opts.client or CLIENTS[opts.client or "tbc"]
    H.client = client

    for _, old in ipairs(frames or {}) do
        local name = rawget(old, "globalName")
        if name and _G[name] == old then _G[name] = nil end
    end
    frames = {}
    H.printed = {}
    H.errors = {}
    H.timers = {}
    H.clock = 1000
    H.inGroup = false

    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        H.printed[#H.printed + 1] = table.concat(parts, " ")
    end
    _G.geterrorhandler = function()
        return function(err) H.errors[#H.errors + 1] = tostring(err) end
    end

    _G.GetBuildInfo = function() return "0.0.0", "1", "Jan 1 2026", client.iface end
    _G.WOW_PROJECT_MAINLINE = 1
    _G.WOW_PROJECT_CLASSIC = 2
    _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
    _G.WOW_PROJECT_MISTS_CLASSIC = 19
    _G.WOW_PROJECT_ID = client.project
    _G.GetLocale = function() return opts.locale or "enUS" end

    local modern = client.iface >= 100000 or (client.iface >= 16000 and client.iface < 20000)

    -- Item data: H.cached[itemID] = true makes GetItemInfo answer; Item mixin loads
    -- queue in H.itemLoads until H.LoadItems() runs them.
    H.cached = {}
    H.itemLoads = {}
    H.itemClass = {}
    H.itemSubclass = {}
    H.itemStats = {}
    H.equipLoc = {}
    H.cursor = nil
    _G.GetCursorInfo = function()
        if H.cursor then return "item", H.cursor end
    end
    _G.ClearCursor = function() H.cursor = nil end
    _G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    _G.OKAY, _G.CANCEL = "Okay", "Cancel"
    _G.hooksecurefunc = function(target, name, hook)
        if type(target) ~= "table" then
            target, name, hook = _G, target, name
        end
        local original = target[name]
        target[name] = function(...)
            local result = original(...)
            hook(...)
            return result
        end
    end

    -- Loot: sounds and rolls are recorded; H.leaders / H.assistants name the raid roles;
    -- H.lootRolls[rollID] is a roll's item link; H.lootMethod = { method, partyID, raidID }.
    H.sounds = {}
    H.rolled = {}
    H.leaders, H.assistants = {}, {}
    H.lootRolls = {}
    H.lootMethod = nil
    H.raidRoster = {}
    _G.SOUNDKIT = { RAID_WARNING = 8959 }
    _G.PlaySound = function(sound) H.sounds[#H.sounds + 1] = sound end
    _G.RandomRoll = function(low, high) H.rolled[#H.rolled + 1] = low .. "-" .. high end
    _G.UnitIsGroupLeader = function(name) return H.leaders[name] == true end
    _G.UnitIsGroupAssistant = function(name) return H.assistants[name] == true end
    _G.Ambiguate = function(name) return (name:match("^([^%-]+)")) or name end
    _G.GetRaidRosterInfo = function(index) return H.raidRoster[index] end
    _G.C_PartyInfo = { GetLootMethod = function()
        if H.lootMethod then return unpack(H.lootMethod) end
        return 3
    end }
    _G.GetLootRollItemLink = function(rollID) return H.lootRolls[rollID] end
    _G.GetTime = function() return H.clock end
    _G.NUM_GROUP_LOOT_FRAMES = 4
    _G.LibStub = nil
    _G.Gargul = nil

    -- Inventory: H.equipped[slot] = itemID, H.containers[bag] = { itemID or false, ... }
    H.equipped = opts.equipped or {}
    H.containers = opts.containers or {}
    _G.NUM_BAG_SLOTS = 4
    _G.NUM_BANKBAGSLOTS = 6
    _G.BANK_CONTAINER = -1
    _G.GetInventoryItemID = function(_, slot) return H.equipped[slot] end
    H.links = opts.links or {}
    _G.GetInventoryItemLink = function(_, slot)
        if H.links[slot] then return H.links[slot] end
        local itemID = H.equipped[slot]
        return itemID and ("|cffa335ee|Hitem:" .. itemID .. ":0:0:0:0:0:0:0:70|h[x]|h|r") or nil
    end
    _G.C_Container = {
        GetContainerNumSlots = function(bag) return H.containers[bag] and #H.containers[bag] or 0 end,
        GetContainerItemID = function(bag, slot)
            local itemID = H.containers[bag] and H.containers[bag][slot]
            return itemID or nil
        end,
    }
    local itemFns = {
        GetItemInfo = function(itemID)
            if not H.cached[itemID] then return nil end
            return "Item" .. itemID, "|cffa335ee|Hitem:" .. itemID .. "|h[Item" .. itemID .. "]|h|r", 4
        end,
        GetItemInfoInstant = function(itemID)
            return itemID, "Armor", "Plate", H.equipLoc[itemID] or "INVTYPE_HEAD", "icon" .. itemID,
                H.itemClass[itemID] or 4, H.itemSubclass[itemID] or 0
        end,
        GetItemStats = function(link)
            local itemID = tonumber(link:match("item:(%d+)"))
            return H.itemStats[itemID] or {}
        end,
        GetDetailedItemLevelInfo = function() end,
    }
    _G.Item = {
        CreateFromItemID = function(_, itemID)
            return {
                ContinueOnItemLoad = function(_, fn)
                    H.itemLoads[#H.itemLoads + 1] = { id = itemID, fn = fn }
                end,
            }
        end,
    }
    _G.ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
    _G.GetInventorySlotInfo = function(name) return 1, "empty-" .. name end
    _G.IsModifiedClick = function() return H.modified end
    H.compares = 0
    H.alwaysCompare = false
    _G.GameTooltip_ShowCompareItem = function() H.compares = H.compares + 1 end
    _G.GetCVarBool = (not modern) and function(name) return name == "alwaysCompareItems" and H.alwaysCompare end or nil
    _G.C_CVar = { GetCVarBool = function(name) return name == "alwaysCompareItems" and H.alwaysCompare end }
    H.modified = false
    H.linked = {}
    _G.HandleModifiedItemClick = function(link) H.linked[#H.linked + 1] = link end
    H.class, H.faction = opts.class or "PALADIN", opts.faction or "Alliance"
    _G.UnitClass = function() return "Paladin", H.class end
    _G.UnitFactionGroup = function() return H.faction end
    H.talentPoints = opts.talentPoints
    _G.C_SpecializationInfo = {
        GetSpecializationInfo = function(tree)
            local points = H.talentPoints
            if not points or not points[tree] then return 0 end
            return 380 + tree, "Tree" .. tree, "", "treeicon" .. tree, nil, nil, points[tree]
        end,
    }
    _G.C_Item = itemFns
    _G.C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return "0.0.0-test" end }
    local function SpellTexture(spellID) return "spellicon" .. spellID end
    _G.C_Spell = { GetSpellTexture = SpellTexture }
    _G.GetSpellTexture = (not modern) and SpellTexture or nil
    _G.GetItemStats = (not modern) and itemFns.GetItemStats or nil
    _G.GetSpellInfo = (not modern) and function(spellID) return "Spell" .. spellID end or nil
    _G.GetItemInfo = (not modern) and itemFns.GetItemInfo or nil
    _G.GetItemInfoInstant = (not modern) and itemFns.GetItemInfoInstant or nil
    _G.GetDetailedItemLevelInfo = nil
    _G.IsAddOnLoaded = (not modern) and function() return false end or nil
    _G.GetAddOnMetadata = nil

    _G.CreateFrame = function(_, name) return NewFrame(name) end
    _G.UIParent = NewFrame()
    _G.UISpecialFrames = {}
    _G.tinsert = table.insert
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.date = os.date
    _G.YES, _G.NO = "Yes", "No"
    _G.UNKNOWNOBJECT = "Unknown"
    _G.ChatFontNormal = {}
    _G.BackdropTemplateMixin = {}
    _G.C_Timer = {
        After = function(seconds, fn)
            H.timers[#H.timers + 1] = { at = H.clock + seconds, fn = fn }
        end,
        NewTicker = function(seconds, fn, iterations)
            local ticker = { cancelled = false }
            function ticker:Cancel() self.cancelled = true end
            local left = iterations or math.huge
            local function Tick()
                if ticker.cancelled then return end
                fn(ticker)
                left = left - 1
                if left > 0 and not ticker.cancelled then
                    H.timers[#H.timers + 1] = { at = H.clock + seconds, fn = Tick }
                end
            end
            H.timers[#H.timers + 1] = { at = H.clock + seconds, fn = Tick }
            return ticker
        end,
    }

    _G.SlashCmdList = {}
    _G.SLASH_GUDABIS1 = nil

    local forever = client.iface >= 16000 and client.iface < 20000
    _G.UnitName = function(unit)
        if unit == "player" then return opts.playerName or (forever and "Vati Guda" or "Vati") end
    end
    _G.GetNormalizedRealmName = function() return "Spineshatter" end
    if opts.normalizedRealm == false then _G.GetNormalizedRealmName = nil end
    _G.GetRealmName = function() return "Thunder Fury" end
    _G.IsInGroup = function() return H.inGroup end

    for i = 1, 4 do _G["GroupLootFrame" .. i] = nil end

    _G.CharacterFrame = NewFrame("CharacterFrame")
    _G.CharacterFrame.width = 384
    _G.PaperDollFrame = NewFrame("PaperDollFrame")
    local tooltip = NewFrame("GameTooltip")
    tooltip.lines = {}
    function tooltip:SetOwner(owner) self.owner = owner; self.lines = {}; self.item = nil end
    function tooltip:SetItemByID(itemID) self.item = itemID end
    function tooltip:SetText(text) self.lines = { text } end
    function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
    function tooltip:IsOwned(owner) return self.owner == owner end
    function tooltip:Hide() self.shown = false; self.owner = nil end

    _G.GudaBiS_DB = opts.saved
end

-- Load every file listed in the client's TOC, in order, with a fresh namespace.
function H.Load()
    local ns = {}
    H.toc = H.TocFor(H.client)
    for _, file in ipairs(H.TocFiles(H.toc)) do
        local chunk = assert(loadfile(ROOT .. "/" .. file))
        chunk("GudaBiS", ns)
    end
    H.ns = ns
    return ns
end

function H.Fire(event, ...)
    for _, frame in ipairs(frames) do
        local onEvent = frame.scripts.OnEvent
        if frame.registered[event] and onEvent then
            onEvent(frame, event, ...)
        end
    end
end

-- True when any frame listens to event.
function H.Registered(event)
    for _, frame in ipairs(frames) do
        if frame.registered[event] then return true end
    end
    return false
end

-- Install + load + ADDON_LOADED + PLAYER_LOGIN + PLAYER_ENTERING_WORLD.
function H.Boot(opts)
    H.Install(opts)
    local ns = H.Load()
    H.Fire("ADDON_LOADED", "GudaBiS")
    H.Fire("PLAYER_LOGIN")
    H.Fire("PLAYER_ENTERING_WORLD", true, false)
    return ns
end

-- Runs every C_Timer callback due within the next `seconds`.
function H.Advance(seconds)
    H.clock = H.clock + seconds
    local due, pending = {}, {}
    for _, timer in ipairs(H.timers) do
        if timer.at <= H.clock then due[#due + 1] = timer else pending[#pending + 1] = timer end
    end
    H.timers = pending
    for _, timer in ipairs(due) do timer.fn() end
end

-- Finishes every pending Item:ContinueOnItemLoad: the items become cached first.
function H.LoadItems()
    local loads = H.itemLoads
    H.itemLoads = {}
    for _, load in ipairs(loads) do H.cached[load.id] = true end
    for _, load in ipairs(loads) do load.fn() end
end

function H.SetGroup(inGroup)
    H.inGroup = inGroup
    H.Fire("GROUP_ROSTER_UPDATE")
end

function H.Slash(input)
    _G.SlashCmdList.GUDABIS(input)
end

function H.Printed(pattern, plain)
    for _, line in ipairs(H.printed) do
        if line:find(pattern, 1, plain) then return true end
    end
    return false
end

return H
