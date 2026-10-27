-- A small dialog asking for a list name, optionally with a "copy the current list"
-- box, or (confirm = true) just a question with OK/Cancel. Our own frame rather than a
-- StaticPopup, so nothing of Blizzard's is touched (developer-guide §8). Built on first
-- use and reused.
--
--   NameDialog:Open({ title, text, showCopy, confirm, onAccept = function(name, copy) end })

local addonName, ns = ...
local L = ns.L

local NameDialog = ns:RegisterModule("NameDialog")

local dialog

local function Accept()
    local name = strtrim(dialog.edit:GetText() or "")
    if name == "" and not dialog.confirm then return end
    local onAccept = dialog.onAccept
    local copy = dialog.copy:IsShown() and dialog.copy:GetChecked()
    dialog:Hide()
    if onAccept then onAccept(name, copy and true or false) end
end

local function Create()
    dialog = ns.Theme.CreateWindow("Frame", "GudaBiSNameDialog", UIParent)
    dialog:SetSize(280, 132)
    dialog:SetPoint("CENTER", 0, 120)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:Hide()
    tinsert(UISpecialFrames, "GudaBiSNameDialog")

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.title:SetPoint("TOP", 0, -12)

    local edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    edit:SetSize(230, 22)
    edit:SetPoint("TOP", 0, -36)
    edit:SetAutoFocus(true)
    edit:SetMaxLetters(40)
    edit:SetScript("OnEnterPressed", Accept)
    edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
    dialog.edit = edit

    local copy = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    copy:SetSize(22, 22)
    copy:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -6, -4)
    copy.label = copy:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copy.label:SetPoint("LEFT", copy, "RIGHT", 2, 0)
    copy.label:SetText(L.COPY_CURRENT)
    dialog.copy = copy

    local ok = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    ok:SetSize(100, 22)
    ok:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 12)
    ok:SetText(OKAY)
    ok:SetScript("OnClick", Accept)

    local cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancel:SetSize(100, 22)
    cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 12)
    cancel:SetText(CANCEL)
    cancel:SetScript("OnClick", function() dialog:Hide() end)
end

function NameDialog:Open(options)
    if not dialog then Create() end
    dialog.title:SetText(options.title)
    dialog.confirm = options.confirm and true or false
    dialog.edit:SetText(options.text or "")
    dialog.edit:SetShown(not dialog.confirm)
    dialog.copy:SetShown(options.showCopy and true or false)
    dialog.copy:SetChecked(false)
    dialog.onAccept = options.onAccept
    dialog:Show()
    if not dialog.confirm then
        dialog.edit:HighlightText()
        dialog.edit:SetFocus()
    end
end

function NameDialog:IsShown()
    return dialog ~= nil and dialog:IsShown()
end
