-- The panel's Wishlist tab (GB-072): this character's wishlist, newest first. Each row:
-- item, where it drops when that is known (the Dungeon Journal addon tells), a green
-- check once owned, and an ✕ that removes it. 15 pooled rows scrolled with the mouse
-- wheel, like History.
--
-- The box at the top searches the rows by name as you type, or takes an item ID or a
-- link: Enter adds it. While the tab is open, shift-clicking any item anywhere (bags,
-- chat, AtlasLoot) or dropping one on the tab adds it too, so items from addons
-- without a shield can still be wished for.
--
-- Built the first time the tab opens (RULES.md Rule 1), over the gear view like History.
--
-- Pure part, tested offline: WishlistTab.Rows(query, nameOf).

local addonName, ns = ...
local L = ns.L

local WishlistTab = ns:RegisterModule("WishlistTab")

local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant
local QualityColor = ns.Items.QualityColor

local ROWS = 15
local ROW_HEIGHT = 22
local ICON_SIZE = 18
local PADDING = 14
local INSET = 4
local INSET_TOP = 24
local SEARCH_TOP = 8
local LIST_TOP = 40
local SOURCE_WIDTH = 150
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local REMOVE_TEXTURE = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

local view, search
local rows = {}
local shown = {}
local offset = 0

local function NameOf(itemID)
    local name = GetItemInfo(itemID)
    if not name then ns.Items.WhenLoaded(itemID, function() WishlistTab:Refresh() end) end
    return name
end

-- The wishlist entries whose item name contains query (lowercase), or all of them.
function WishlistTab.Rows(query, nameOf)
    local out = {}
    for _, entry in ipairs(ns.Wishlist:Items()) do
        local name = query and nameOf(entry.itemID)
        if not query or (name and name:lower():find(query, 1, true)) then out[#out + 1] = entry end
    end
    return out
end

local function Query()
    local text = strtrim(search:GetText() or "")
    if text == "" or ns.Lists.ParseItemID(text) then return nil end
    return text:lower()
end

local function ShowRowTooltip(row)
    if not row.itemID then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.itemID)
    ns.ItemTooltip.Compare()
    GameTooltip:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, view)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PADDING - INSET, -LIST_TOP - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", view, "RIGHT", INSET - PADDING, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT")
    row.remove = CreateFrame("Button", nil, row)
    row.remove:SetSize(14, 14)
    row.remove:SetPoint("RIGHT")
    row.remove:SetNormalTexture(REMOVE_TEXTURE)
    row.remove:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.remove:SetScript("OnClick", function() ns.Wishlist:Remove(row.itemID) end)
    row.remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.WISH_REMOVE)
        GameTooltip:Show()
    end)
    row.remove:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture(CHECK_TEXTURE)
    row.check:SetSize(14, 14)
    row.check:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetWidth(SOURCE_WIDTH)
    row.source:SetJustifyH("RIGHT")
    row.source:SetWordWrap(false)
    row.source:SetPoint("RIGHT", row.check, "LEFT", -6, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.source, "LEFT", -6, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetBlendMode("ADD")
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

local function PaintRow(row, entry)
    local itemID = entry.itemID
    row.itemID = itemID
    local _, _, _, _, icon = GetItemInfoInstant(itemID)
    row.icon:SetTexture(icon)
    local name, _, quality = GetItemInfo(itemID)
    if name then
        row.name:SetText(name)
        row.name:SetTextColor(QualityColor(quality))
    else
        row.name:SetText(string.format(L.TOOLTIP_ITEM_LOADING, itemID))
        row.name:SetTextColor(0.6, 0.6, 0.6)
        ns.Items.WhenLoaded(itemID, function() WishlistTab:Refresh() end)
    end
    row.source:SetText(ns.Wishlist.SourceText(entry))
    row.check:SetShown(ns.Owned:Has(itemID))
end

function WishlistTab:Refresh()
    if not (view and view:IsShown()) then return end
    local matches = WishlistTab.Rows(Query(), NameOf)
    wipe(shown)
    for i, entry in ipairs(matches) do shown[i] = entry end
    offset = math.max(0, math.min(offset, #shown - ROWS))
    for i, row in ipairs(rows) do
        local entry = shown[i + offset]
        if entry then PaintRow(row, entry) else row.itemID = nil end
        row:SetShown(entry ~= nil)
    end
    view.emptyNote:SetShown(#shown == 0)
    view.emptyNote:SetText(ns.Wishlist:Items()[1] and L.PICK_NO_MATCH or L.WISHLIST_EMPTY)
end

local function AddFrom(text)
    local itemID = ns.Lists.ParseItemID(text)
    if itemID then ns.Wishlist:Add(itemID) end
    return itemID
end

local function OnEnterPressed(edit)
    if AddFrom(edit:GetText() or "") then edit:SetText("") end
    edit:ClearFocus()
    WishlistTab:Refresh()
end

local function OnReceiveDrag()
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return end
    ClearCursor()
    ns.Wishlist:Add(itemID)
end

local function OnWheel(_, delta)
    offset = offset - delta * 3
    WishlistTab:Refresh()
end

local function Create(panel)
    view = CreateFrame("Frame", "GudaBiSWishlistView", panel)
    view:SetPoint("TOPLEFT", INSET, -INSET_TOP)
    view:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    view:SetFrameLevel(panel:GetFrameLevel() + 20)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", OnWheel)
    view:SetScript("OnReceiveDrag", OnReceiveDrag)
    view:SetScript("OnMouseUp", OnReceiveDrag)
    local background = view:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.06, 0.06, 1)

    search = CreateFrame("EditBox", nil, view, "InputBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", PADDING, -SEARCH_TOP)
    search:SetPoint("TOPRIGHT", -PADDING + INSET, -SEARCH_TOP)
    search:SetAutoFocus(false)
    search:SetScript("OnEnterPressed", OnEnterPressed)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText(L.WISHLIST_SEARCH)
    search:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
        offset = 0
        WishlistTab:Refresh()
    end)
    view.search = search

    view.emptyNote = view:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.emptyNote:SetPoint("TOP", 0, -LIST_TOP - 10)
    view.emptyNote:SetWidth(320)

    for i = 1, ROWS do CreateRow(i) end
    view:SetScript("OnHide", function() GameTooltip:Hide() end)
end

function WishlistTab:SetShown(panel, shownNow)
    if shownNow and not view then Create(panel) end
    if not view then return end
    view:SetShown(shownNow)
    if shownNow then self:Refresh() end
end

function WishlistTab:IsShown()
    return view ~= nil and view:IsShown()
end

-- Shift-clicking an item anywhere while the tab is open adds it. A post-hook, so the
-- click still does what the game does with it.
local function OnModifiedItemClick(link)
    if not WishlistTab:IsShown() then return end
    AddFrom(link)
end

ns.Events:Register("GBIS_INITIALIZED", function()
    if HandleModifiedItemClick then hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick) end
end, "WishlistTab")

ns.Events:Register("GBIS_WISHLIST_CHANGED", function() WishlistTab:Refresh() end, "WishlistTab")
ns.Events:Register("GBIS_OWNED_CHANGED", function() WishlistTab:Refresh() end, "WishlistTab")
