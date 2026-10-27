-- The spell-activation "proc" glow (author, 2026-10-28): the golden glow with marching
-- ants that action buttons get when a spell procs, put around any button.
--
-- Built from the same textures as Blizzard's ActionBarButtonSpellActivationAlert, but
-- with our own frames. Blizzard's ActionButton_ShowOverlayGlow takes its frames from a
-- pool shared with the action bars, so calling it on another addon's or Blizzard's loot
-- frame could taint the action bars in combat; LibButtonGlow is not used either (it
-- needs AnimateTexCoords, which WoW: Forever lacks).
--
-- The ants run as a FlipBook animation played by the client (no OnUpdate from us,
-- RULES.md Rule 1). A client without FlipBook animations shows still ants and a pulse.
--
--   Glow.Show(target)   Glow.Hide(target)

local addonName, ns = ...

local Glow = ns:RegisterModule("Glow")

local ALERT = "Interface\\SpellActivationOverlay\\IconAlert"
local ANTS = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local SCALE = 1.4
local ANT_FRAME = 48
local ANT_COLUMNS, ANT_ROWS, ANT_FRAMES = 5, 5, 22
local ANT_SECONDS = 0.6

local function FlipBook(group, texture)
    local ok, anim = pcall(group.CreateAnimation, group, "FlipBook")
    if not ok or not anim or not anim.SetFlipBookFrames then return nil end
    anim:SetTarget(texture)
    anim:SetDuration(ANT_SECONDS)
    anim:SetFlipBookRows(ANT_ROWS)
    anim:SetFlipBookColumns(ANT_COLUMNS)
    anim:SetFlipBookFrames(ANT_FRAMES)
    anim:SetFlipBookFrameWidth(ANT_FRAME)
    anim:SetFlipBookFrameHeight(ANT_FRAME)
    return anim
end

local function Create(target)
    local glow = CreateFrame("Frame", nil, target)
    glow:SetFrameLevel(target:GetFrameLevel() + 5)

    local outer = glow:CreateTexture(nil, "ARTWORK")
    outer:SetTexture(ALERT)
    outer:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    outer:SetAllPoints()
    glow.outer = outer

    local ants = glow:CreateTexture(nil, "OVERLAY")
    ants:SetTexture(ANTS)
    ants:SetPoint("TOPLEFT", -2, 2)
    ants:SetPoint("BOTTOMRIGHT", 2, -2)
    glow.ants = ants

    local burst = glow:CreateAnimationGroup()
    local grow = burst:CreateAnimation("Scale")
    grow:SetTarget(outer)
    if grow.SetScaleFrom then
        grow:SetScaleFrom(1.5, 1.5)
        grow:SetScaleTo(1, 1)
    else
        grow:SetScale(0.67, 0.67)
    end
    grow:SetDuration(0.25)
    local appear = burst:CreateAnimation("Alpha")
    appear:SetTarget(outer)
    appear:SetFromAlpha(0)
    appear:SetToAlpha(1)
    appear:SetDuration(0.25)
    glow.burst = burst

    local loop = glow:CreateAnimationGroup()
    loop:SetLooping("REPEAT")
    if not FlipBook(loop, ants) then
        loop:SetLooping("BOUNCE")
        local pulse = loop:CreateAnimation("Alpha")
        pulse:SetTarget(outer)
        pulse:SetFromAlpha(1)
        pulse:SetToAlpha(0.4)
        pulse:SetDuration(0.6)
        ants:SetTexCoord(0, ANT_FRAME / 256, 0, ANT_FRAME / 256)
    end
    glow.loop = loop

    glow:Hide()
    target.gudaBiSGlow = glow
    return glow
end

function Glow.Show(target)
    if not target then return end
    local glow = target.gudaBiSGlow or Create(target)
    local width, height = target:GetWidth(), target:GetHeight()
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", target, "CENTER")
    glow:SetSize(width * SCALE, height * SCALE)
    glow:Show()
    glow.burst:Play()
    glow.loop:Play()
end

function Glow.Hide(target)
    local glow = target and target.gudaBiSGlow
    if not glow then return end
    glow.loop:Stop()
    glow.burst:Stop()
    glow:Hide()
end

function Glow.IsShown(target)
    local glow = target and target.gudaBiSGlow
    return glow ~= nil and glow:IsShown()
end
