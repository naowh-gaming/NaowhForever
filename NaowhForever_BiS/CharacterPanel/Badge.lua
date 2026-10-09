-- Badge.lua: your supporter badge on the character panel (CP.BadgePlate).
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local CP = ns.CharacterPanel

local INSET = 10
local SLOT_GAP = 3
local EMBLEM = 44
local PLATE_TEXT_W = 150
local GLOW, GLOW_ALPHA = 1.25, 0.3
local FILTER = "TRILINEAR"
local SHADOW_X, SHADOW_Y, SHADOW_ALPHA = 2, -2, 0.7
local TEXT_SHADOW_ALPHA, TEXT_SHADOW_X = 0.8, 1
local SHADOW_RGB = { r = 0, g = 0, b = 0 }
local TITLE_SIZE, LINE_SIZE = 15, 11
local TEXT_GAP = 8
local TITLE_LIFT, LINE_DROP = 1, 2
local TIP_GAP = 4
local PLATE_LIFT = 60
local BADGES_LIVE = 1
local TEXT_FOREVER = "Naowh Forever"
local TEXT_TEAM = "Naowh Forever Team"
local TEXT_TIER = "Naowh Forever "

local mine, installed

local function BadgeOn()
    local wanted = S.Get("characterPanelBadge")
    if ns.FEATURE_BADGES ~= BADGES_LIVE then wanted = S.Default("characterPanelBadge") end
    if not (CP.On() and wanted == true) then return false end
    return ns.BadgeOf(UnitGUID("player")) ~= nil
end

local function Center()
    local slot = CharacterHeadSlot
    local paneTop, slotTop = CharacterFrame.LeftPaneHost:GetTop(), slot and slot:GetTop()
    if not (paneTop and slotTop) then return end
    mine:ClearAllPoints()
    mine:SetPoint("BOTTOM", slot, "TOP", 0, math.max(0, (paneTop - slotTop - EMBLEM) / 2))
end

local function Paint()
    CP.PaintBadgePlate(mine, UnitGUID("player"))
    Center()
end

local function Enter(self)
    if not ns.Shared.Parts.Tip(self, "ANCHOR_NONE") then return end
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", self.emblem, "BOTTOMLEFT", 0, -TIP_GAP)
    local tier = ns.BadgeOf(self.guid)
    if not tier then return GameTooltip:Hide() end
    local c = tier.color
    if self.compact then
        GameTooltip:SetText(self.title:GetText(), c.r, c.g, c.b)
        GameTooltip:AddLine(self.line:GetText(), T.muted.r, T.muted.g, T.muted.b)
    else
        GameTooltip:SetText(tier.label or (TEXT_TIER .. tier.title), c.r, c.g, c.b)
    end
    GameTooltip:AddLine(tier.about, T.fg.r, T.fg.g, T.fg.b, true)
    GameTooltip:Show()
end

local function TextShadow(text)
    text:SetShadowColor(SHADOW_RGB.r, SHADOW_RGB.g, SHADOW_RGB.b, TEXT_SHADOW_ALPHA)
    text:SetShadowOffset(TEXT_SHADOW_X, -TEXT_SHADOW_X)
end

local function Art(frame)
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetSize(EMBLEM * GLOW, EMBLEM * GLOW)
    frame.glow:SetPoint("CENTER", frame, "LEFT", EMBLEM / 2, 0)
    frame.glow:SetBlendMode("ADD")
    frame.emblem = frame:CreateTexture(nil, "ARTWORK")
    frame.emblem:SetSize(EMBLEM, EMBLEM)
    frame.emblem:SetPoint("LEFT")
    frame.shadow = frame:CreateTexture(nil, "BORDER")
    frame.shadow:SetSize(EMBLEM, EMBLEM)
    frame.shadow:SetPoint("CENTER", frame.emblem, "CENTER", SHADOW_X, SHADOW_Y)
    frame.shadow:SetVertexColor(SHADOW_RGB.r, SHADOW_RGB.g, SHADOW_RGB.b, SHADOW_ALPHA)
end

local function Build()
    local left = CharacterFrame.LeftPaneHost
    mine = CP.BadgePlate(PaperDollFrame or left, true)
    if CharacterHeadSlot then
        mine:SetPoint("BOTTOM", CharacterHeadSlot, "TOP", 0, SLOT_GAP)
    else
        mine:SetPoint("TOPLEFT", INSET, -INSET)
    end
    mine:SetFrameLevel(left:GetFrameLevel() + PLATE_LIFT)
    mine:SetScript("OnShow", Paint)
    CP.supportBadge = mine
end

local function Apply()
    local on = BadgeOn()
    if on and not installed and CharacterFrame then
        installed = true
        Build()
        CharacterFrame.LeftPaneHost:HookScript("OnShow", Apply)
    end
    if not installed then return end
    mine:SetShown(on)
    if on and mine:IsVisible() then Paint() end
end

local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") then Apply() end
end

CP.BADGE_MID = INSET + EMBLEM / 2
CP.BADGE_INSET = INSET

function CP.PaintBadgePlate(frame, guid)
    frame.guid = guid
    local tier, entry = ns.BadgeOf(guid)
    if not tier then
        frame:Hide()
        return false
    end
    local c = tier.color
    frame.emblem:SetTexture(tier.large, nil, nil, FILTER)
    frame.shadow:SetTexture(tier.large, nil, nil, FILTER)
    frame.glow:SetTexture(tier.large, nil, nil, FILTER)
    frame.glow:SetVertexColor(c.r, c.g, c.b, GLOW_ALPHA)
    frame.title:SetText(type(entry) == "table" and entry.title or tier.title)
    frame.line:SetText(ns.BadgeSince(entry) or (tier == ns.BADGE_TIERS.legendary and TEXT_FOREVER or TEXT_TEAM))
    frame.title:SetTextColor(c.r, c.g, c.b)
    if frame.compact then
        frame:SetWidth(EMBLEM)
        return true
    end
    local text = math.max(frame.title:GetStringWidth(), frame.line:GetStringWidth())
    frame:SetWidth(EMBLEM + TEXT_GAP + math.ceil(text))
    return true
end

function CP.BadgePlate(parent, compact)
    local frame = CreateFrame("Button", nil, parent)
    frame.compact = compact
    frame:SetSize(compact and EMBLEM or EMBLEM + PLATE_TEXT_W, EMBLEM)
    Art(frame)
    frame.title = ns.Font(frame, TITLE_SIZE)
    frame.title:SetPoint("BOTTOMLEFT", frame.emblem, "RIGHT", TEXT_GAP, TITLE_LIFT)
    frame.line = ns.Font(frame, LINE_SIZE, nil, T.muted)
    frame.line:SetPoint("TOPLEFT", frame.emblem, "RIGHT", TEXT_GAP, -LINE_DROP)
    TextShadow(frame.title)
    TextShadow(frame.line)
    frame.title:SetShown(not compact)
    frame.line:SetShown(not compact)
    frame:SetScript("OnEnter", Enter)
    frame:SetScript("OnLeave", GameTooltip_Hide)
    return frame
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
