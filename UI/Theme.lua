-- The look of every GudaBiS frame: the game's own art (author, 2026-10-28), so the
-- panel sits next to the Character frame like part of the client.
--
--   Theme.Panel(name, parent)          BasicFrameTemplateWithInset: title bar, close
--                                      button, inset; falls back to the dialog border
--   Theme.Popup(frameType, name, parent) tooltip background and border (menus, flyout)
--   Theme.Dialog(name, parent)         the classic dialog box (name and confirm dialogs)
--   Theme.DropdownArt(button)          the classic dropdown frame and arrow
--   Theme.SlotFrame(button)            the action-button frame around an item icon
--
-- Where the client draws Retail's frame art (ns.Features.HasRetailFrameArt: Retail, not
-- WoW: Forever, which has Vanilla art on the modern API; the same flag GudaBags uses),
-- the panel is Blizzard's ButtonFrameTemplate (metal frame, gold title bar, red close
-- button) with its portrait and button bar hidden; dialogs and popups get Retail's
-- NineSlice "Dialog" and "TooltipDefaultLayout" borders; dropdowns Retail's dropdown
-- atlas (author, 2026-10-28). The client has all of that built in, so nothing is
-- copied. Each piece is guarded: whatever a client lacks keeps the classic look.

local addonName, ns = ...

local Theme = ns:RegisterModule("Theme")

Theme.COLORS = {
    highlight = { 1, 1, 1, 0.15 },
}

local TOOLTIP_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local DROPDOWN_ART = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"
local RETAIL_DROPDOWN_ATLAS = "common-dropdown-a-button"
local SLOT_FRAME = "Interface\\Buttons\\UI-Quickslot2"

local function RetailArt()
    return ns.Features.HasRetailFrameArt == true
end

local function HasAtlas(name)
    local api = C_Texture
    return api ~= nil and api.GetAtlasInfo ~= nil and api.GetAtlasInfo(name) ~= nil
end

-- A Retail NineSlice border with one of Blizzard's layouts, behind the frame's content.
-- False when the client has no such layout.
local function RetailBorder(frame, layout)
    local util = NineSliceUtil
    if not (RetailArt() and util and util.ApplyLayoutByName) then return false end
    local ok, border = pcall(CreateFrame, "Frame", nil, frame, "NineSlicePanelTemplate")
    if not ok or not border then return false end
    if not pcall(util.ApplyLayoutByName, border, layout) then
        border:Hide()
        return false
    end
    border:SetAllPoints()
    border:SetFrameLevel(frame:GetFrameLevel())
    frame.retailBorder = border
    return true
end

local function RetailPanel(name, parent)
    if not RetailArt() then return nil end
    local ok, frame = pcall(CreateFrame, "Frame", name, parent, "ButtonFrameTemplate")
    if not ok or not frame then return nil end
    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, frame) end
    if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, frame) end
    local container = frame.TitleContainer
    local title = type(container) == "table" and container.TitleText or nil
    return frame, type(title) == "table" and title or nil
end

-- The window template, or the dialog border on a client without it. Returns the frame,
-- its title font string and its close button (made when the template has none).
function Theme.Panel(name, parent)
    local frame, retailTitle = RetailPanel(name, parent)
    local ok = frame ~= nil
    if not ok then ok, frame = pcall(CreateFrame, "Frame", name, parent, "BasicFrameTemplateWithInset") end
    if not ok or not frame then
        frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
        frame:SetBackdrop(DIALOG_BACKDROP)
    end
    local title = retailTitle or frame.TitleText
    if type(title) ~= "table" then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    local close = frame.CloseButton
    if type(close) ~= "table" then close = name and _G[name .. "CloseButton"] end
    if type(close) ~= "table" then
        close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 1)
    end
    return frame, title, close
end

function Theme.Popup(frameType, name, parent)
    local frame = CreateFrame(frameType, name, parent, "BackdropTemplate")
    if RetailBorder(frame, "TooltipDefaultLayout") then
        frame:SetBackdrop({ bgFile = TOOLTIP_BACKDROP.bgFile, tile = true, tileSize = 16, insets = TOOLTIP_BACKDROP.insets })
    else
        frame:SetBackdrop(TOOLTIP_BACKDROP)
    end
    frame:SetBackdropColor(0, 0, 0, 0.92)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    return frame
end

function Theme.Dialog(name, parent)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    if RetailBorder(frame, "Dialog") then
        frame:SetBackdrop({ bgFile = DIALOG_BACKDROP.bgFile, tile = true, tileSize = 32, insets = DIALOG_BACKDROP.insets })
    else
        frame:SetBackdrop(DIALOG_BACKDROP)
    end
    return frame
end

-- The classic dropdown, laid out exactly like UIDropDownMenuTemplate: a 32-high frame,
-- 25x64 caps at (0, +17), the arrow 24x24 inside the right cap at (-16, -18), and the
-- text from 27 px in to 43 px before the right edge, 2 px up. The art has ~16 px of
-- transparent margin on each side, so the visible box is 16 px narrower per side than
-- the frame. Returns the text font string.
Theme.DROPDOWN_HEIGHT = 32
Theme.DROPDOWN_MARGIN = 16

-- Retail's dropdown: one atlas box inside the same transparent side margins the
-- classic art leaves, so every dropdown keeps its size and anchors.
local function RetailDropdownArt(button)
    local margin = Theme.DROPDOWN_MARGIN
    local box = button:CreateTexture(nil, "ARTWORK")
    box:SetAtlas(RETAIL_DROPDOWN_ATLAS)
    box:SetPoint("LEFT", margin, 0)
    box:SetPoint("RIGHT", -margin, 0)
    box:SetHeight(26)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    if HasAtlas(RETAIL_DROPDOWN_ATLAS .. "-hover") then
        hover:SetAtlas(RETAIL_DROPDOWN_ATLAS .. "-hover")
    else
        hover:SetColorTexture(1, 1, 1, 0.08)
    end
    hover:SetAllPoints(box)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(20, 20)
    arrow:SetPoint("RIGHT", box, "RIGHT", -4, 0)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", box, "LEFT", 8, 0)
    text:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

function Theme.DropdownArt(button)
    button:SetHeight(Theme.DROPDOWN_HEIGHT)
    if RetailArt() and HasAtlas(RETAIL_DROPDOWN_ATLAS) then return RetailDropdownArt(button) end
    local left = button:CreateTexture(nil, "ARTWORK")
    left:SetTexture(DROPDOWN_ART)
    left:SetTexCoord(0, 0.1953125, 0, 1)
    left:SetSize(25, 64)
    left:SetPoint("TOPLEFT", 0, 17)
    local right = button:CreateTexture(nil, "ARTWORK")
    right:SetTexture(DROPDOWN_ART)
    right:SetTexCoord(0.8046875, 1, 0, 1)
    right:SetSize(25, 64)
    right:SetPoint("TOPRIGHT", 0, 17)
    local middle = button:CreateTexture(nil, "ARTWORK")
    middle:SetTexture(DROPDOWN_ART)
    middle:SetTexCoord(0.1953125, 0.8046875, 0, 1)
    middle:SetHeight(64)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(24, 24)
    arrow:SetPoint("TOPRIGHT", right, "TOPRIGHT", -16, -18)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(arrow)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", left, "LEFT", 27, 2)
    text:SetPoint("RIGHT", right, "RIGHT", -43, 2)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

function Theme.SlotFrame(button, size)
    button:SetNormalTexture(SLOT_FRAME)
    local normal = button:GetNormalTexture()
    normal:ClearAllPoints()
    normal:SetPoint("CENTER")
    normal:SetSize(size * 64 / 37, size * 64 / 37)
end
