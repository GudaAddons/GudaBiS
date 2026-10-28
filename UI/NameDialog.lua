-- A small dialog asking for a list name, optionally with a "copy the current list"
-- box and a Wowhead gear-planner link box (GB-043), or (confirm = true) just a question
-- with OK/Cancel. Our own frame rather than a StaticPopup, so nothing of Blizzard's is
-- touched (developer-guide §8). Built on first use and reused.
--
-- onAccept may return an error text: the dialog then stays open and shows it in red
-- under the boxes (a link that does not read).
--
--   NameDialog:Open({ title, text, showCopy, showLink, confirm,
--                     onAccept = function(name, copy, link) return errorText? end })

local addonName, ns = ...
local L = ns.L

local NameDialog = ns:RegisterModule("NameDialog")

local HEIGHT = 140
local LINK_HEIGHT = 56

-- The dialog is as tall as what it shows (author, 2026-10-28: the delete question had a
-- lot of empty space): a question is its wrapped title plus the buttons; the name box
-- adds the copy box and the link box only when they are shown.
local WIDTH = 300
local TITLE_INSET = 24
local CONFIRM_BASE = 72
local NAME_BASE = 114
local COPY_HEIGHT = 26

local dialog

local function Accept()
    local name = strtrim(dialog.edit:GetText() or "")
    if name == "" and not dialog.confirm then return end
    local onAccept = dialog.onAccept
    local copy = dialog.copy:IsShown() and dialog.copy:GetChecked()
    local link = dialog.link:IsShown() and strtrim(dialog.link:GetText() or "") or ""
    local problem = onAccept and onAccept(name, copy and true or false, link)
    if problem then
        dialog.problem:SetText(problem)
        dialog.problem:Show()
        return
    end
    dialog:Hide()
end

local function Create()
    dialog = ns.Theme.Dialog("GudaBiSNameDialog", UIParent)
    dialog:SetSize(WIDTH, HEIGHT)
    dialog:SetPoint("CENTER", 0, 120)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:Hide()
    tinsert(UISpecialFrames, "GudaBiSNameDialog")

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.title:SetPoint("TOP", 0, -18)
    dialog.title:SetWidth(WIDTH - TITLE_INSET * 2)
    dialog.title:SetWordWrap(true)

    local edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    edit:SetSize(230, 22)
    edit:SetPoint("TOP", 0, -42)
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

    local link = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    link:SetSize(230, 22)
    link:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -30)
    link:SetAutoFocus(false)
    link:SetScript("OnEnterPressed", Accept)
    link:SetScript("OnEscapePressed", function() dialog:Hide() end)
    local placeholder = link:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText(L.IMPORT_PLACEHOLDER)
    link:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
        dialog.problem:Hide()
    end)
    dialog.link = link

    local problem = dialog:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    problem:SetPoint("TOPLEFT", link, "BOTTOMLEFT", -4, -4)
    problem:SetWidth(240)
    problem:SetJustifyH("LEFT")
    problem:Hide()
    dialog.problem = problem

    local ok = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    ok:SetSize(100, 22)
    ok:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 18)
    ok:SetText(OKAY)
    ok:SetScript("OnClick", Accept)

    local cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancel:SetSize(100, 22)
    cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 18)
    cancel:SetText(CANCEL)
    cancel:SetScript("OnClick", function() dialog:Hide() end)
end

function NameDialog:Open(options)
    if not dialog then Create() end
    dialog.title:SetText(options.title)
    dialog.confirm = options.confirm and true or false
    dialog.edit:SetText(options.text or "")
    dialog.edit:SetShown(not dialog.confirm)
    local showCopy = options.showCopy and true or false
    dialog.copy:SetShown(showCopy)
    dialog.copy:SetChecked(false)
    dialog.link:SetShown(options.showLink and true or false)
    dialog.link:SetText("")
    dialog.link:ClearAllPoints()
    dialog.link:SetPoint("TOPLEFT", dialog.edit, "BOTTOMLEFT", 0, showCopy and -30 or -6)
    dialog.problem:Hide()
    if dialog.confirm then
        dialog:SetHeight(CONFIRM_BASE + (dialog.title:GetStringHeight() or 14))
    else
        dialog:SetHeight(NAME_BASE + (showCopy and COPY_HEIGHT or 0) + (options.showLink and LINK_HEIGHT or 0))
    end
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
