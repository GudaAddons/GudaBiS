-- The Guda look shared by every GudaBiS frame: a dark window with the tooltip border,
-- as in GudaBags. Colors live here only.

local addonName, ns = ...

local Theme = ns:RegisterModule("Theme")

Theme.COLORS = {
    background = { 0.06, 0.06, 0.07, 0.95 },
    border = { 0.35, 0.35, 0.38, 1 },
    title = { 1, 1, 1 },
    muted = { 0.6, 0.6, 0.6 },
    highlight = { 1, 1, 1, 0.12 },
}

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- A frame with the BackdropTemplate, painted as a Guda window.
function Theme.CreateWindow(frameType, name, parent)
    local frame = CreateFrame(frameType, name, parent, "BackdropTemplate")
    Theme.Window(frame)
    return frame
end

function Theme.Window(frame)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(unpack(Theme.COLORS.background))
    frame:SetBackdropBorderColor(unpack(Theme.COLORS.border))
end

function Theme.Color(fontString, key)
    local c = Theme.COLORS[key]
    fontString:SetTextColor(c[1], c[2], c[3])
end
