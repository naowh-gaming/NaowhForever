-------------------------------------------------------------------------------
--  NaowhForever_Campfire.lua -- the AuraBuffs campfire reminder, in two looks on one mover:
--  Round, a camp icon with a time ring and a countdown, and Simple, a slim bar listing the
--  camp's bonuses with a time line, the campfire sitting on top. Both show a greyed-out
--  "Refresh Camp" reminder when Camp Benefits is gone, and hovering the Simple bar lists each
--  bonus, the time left and when to refresh. The bonuses are read from the hidden aura each
--  camp feature puts on you, by spell ID (Camp Benefits' own description, spell 1229741,
--  wago.tools build 1.60.1.70205), with the aura's tooltip as the fallback.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local S = ns.AuraBuffSettings
local T = ns.THEME
local St, Parts = ns.Shared.Style, ns.Shared.Parts

-- Forever's Camp Benefits aura and icon, probed on the client 2026-09-19.
local CAMP_BENEFITS = 1229741
-- Area aura from being in range of a campfire, probed 2026-09-24.
local CAMPFIRE_NEARBY = 1283391
-- The 60 second aura while sitting at a campfire, before Camp Benefits lands; probed 2026-09-25.
local WELCOMING_CAMPFIRE = 1229739
local CIRCLE_MASK = "Interface\\AddOns\\NaowhForever\\Media\\circle_mask.tga"
local CIRCLE_RING = "Interface\\AddOns\\NaowhForever\\Media\\circle_ring.tga"
local CAMPFIRE_ART = "Interface\\AddOns\\NaowhForever\\Media\\CampfireHD.tga"
-- The time ring's colour by minutes left: green above 30, yellow above 5, red below.
local TIME_STEPS = { { 1800, St.TIME_OK_RGB }, { 300, St.TIME_LOW_RGB }, { 0, St.TIME_OUT_RGB } }
local REFRESH_NOW = TIME_STEPS[2][1]

local TEXT_SIZE, ALERT_SIZE = 16, 28
-- The plate behind the campfire art; ns.ThemeTint swaps in the player's Panels color.
local PLATE = { r = 0.14, g = 0.15, b = 0.16 }

local BAR = { PAD = 8, TEXT = 12, TIME_W = 40, TIME_GAP = 8,
    NOTE_GAP = 6, LINE_H = 2, TEXT_LIFT = 1, CAMP_TRIM = 2, CAMP_GAP = 8, CAMP_SEAT = 0, CAMP_INSET = 0,
    INNER_RING = 1, TIME_RING = 2, OUTER_RING = 1, PILL_ICON_TRIM = 8, PILL_GAP = 6,
    HALO_GROW = 10, HALO_ALPHA = 0.18, BONUS_ICON_GROW = 1, BONUS_ICON_GAP = 3, BONUS_ICON_DROP = 1 }
BAR.RING_OUT = BAR.INNER_RING + BAR.TIME_RING + BAR.OUTER_RING
local SIT_PREFIX = "in "
local DEFAULT_X, DEFAULT_Y = -260, 120
local UNLOCK_TEXT = "+Rested\n+Crit"

local FEATURES = {
    { id = 1229451, tag = "+Rested", short = "Rested", name = "Camp Tent", stat = "Rested experience" },
    { id = 1230587, tag = "+MP5", short = "Mana", name = "Mana Well", stat = "Mana every 5 sec",
      amount = "+%d Mana every 5 sec" },
    { id = 1230172, tag = "+STR", short = "Str", name = "Sharpening Wheel", stat = "Strength",
      amount = "+%d Strength" },
    { id = 1230653, tag = "+ARM", short = "Armor", name = "Enchanted Lute", stat = "Armor, all stats and resistances",
      amount = "+%d Armor, +%d all stats, +%d resistances", points = 3 },
    { id = 1230124, tag = "+STA", short = "Sta", name = "First Aid Kit", stat = "Stamina", amount = "+%d Stamina" },
    { id = 1230098, tag = "+Stats", short = "Stats", unit = "%", name = "Fish Bowl", stat = "All stats",
      amount = "+%d%% all stats" },
    { id = 1229513, tag = "+INT", short = "Int", name = "Incense Candle", stat = "Intellect", amount = "+%d Intellect" },
    { id = 1230164, tag = "+ATK", short = "Attack", name = "Lodestone", stat = "Melee Attack Power",
      amount = "+%d Melee Attack Power" },
    { id = 1229519, tag = "+Crit", short = "Crit", unit = "%", name = "Camp Chair", stat = "Critical Strike",
      amount = "+%d%% Critical Strike" },
    { id = 1229718, tag = "+Spirit", short = "Spirit", name = "Faction Banner", stat = "Spirit", amount = "+%d Spirit" },
}
local FEATURE_BY_TAG = {}
for i, feature in ipairs(FEATURES) do
    feature.bit = 2 ^ (i - 1)
    feature.points = feature.points or 1
    feature.labels = {}
    FEATURE_BY_TAG[feature.tag] = feature
end
local SAMPLE_BONUSES = { { FEATURES[1] }, { FEATURES[9], 2 }, { FEATURES[5], 56 }, { FEATURES[7], 25 } }

local function CampArt(icon)
    icon.tex = Parts.Smooth(icon:CreateTexture(nil, "ARTWORK"), CAMPFIRE_ART)
    icon.tex:SetAllPoints()
    icon.plate = icon:CreateTexture(nil, "BACKGROUND", nil, 1)
    icon.plate:SetAllPoints()
    local plate = ns.ThemeTint("panel", PLATE)
    icon.plate:SetColorTexture(plate.r, plate.g, plate.b, 1)
    icon.mask = icon:CreateMaskTexture()
    icon.mask:SetAllPoints()
    icon.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon.tex:AddMaskTexture(icon.mask)
    icon.plate:AddMaskTexture(icon.mask)

    -- A black circle one pixel wider on every side, behind the icon: a 1px round border.
    icon.ring = icon:CreateTexture(nil, "BACKGROUND")
    ns.PixelInset(icon.ring, -1)
    icon.ring:SetColorTexture(0, 0, 0, 1)
    icon.ringMask = icon:CreateMaskTexture()
    icon.ringMask:SetAllPoints(icon.ring)
    icon.ringMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon.ring:AddMaskTexture(icon.ringMask)
end

local Look = {}
local ROUND_ART = { "tex", "plate", "ring" }
local ROUND_EXTRAS = { "timer", "drain", "track", "label", "buffs" }

function Look.New(icon)
    CampArt(icon)

    icon.timer = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.timer:SetAllPoints()
    icon.timer:SetSwipeTexture(CIRCLE_MASK)
    icon.timer:SetDrawSwipe(false)
    icon.timer:SetDrawBling(false)
    icon.timer:SetDrawEdge(false)
    icon.timer:SetReverse(true)

    -- The black disk extends past the drain on both sides, edging the time ring.
    icon.track = icon:CreateTexture(nil, "BACKGROUND")
    icon.track:SetPoint("TOPLEFT", -6, 6)
    icon.track:SetPoint("BOTTOMRIGHT", 6, -6)
    icon.track:SetTexture(CIRCLE_MASK)
    icon.track:SetVertexColor(0, 0, 0, 1)
    icon.drain = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.drain:SetPoint("TOPLEFT", -5, 5)
    icon.drain:SetPoint("BOTTOMRIGHT", 5, -5)
    icon.drain:SetSwipeTexture(CIRCLE_RING)
    icon.drain:SetDrawEdge(false)
    icon.drain:SetDrawBling(false)
    icon.drain:SetHideCountdownNumbers(true)

    icon.label = Parts.HudText(ns.Font(icon, TEXT_SIZE, nil, T.accentSoft))
    icon.label:SetPoint("TOP", icon, "BOTTOM", 0, -4)
    icon.label:SetText("Refresh Camp")

    icon.buffs = Parts.HudText(ns.Font(icon, TEXT_SIZE))
    icon.buffs:SetPoint("TOP", icon, "BOTTOM", 0, -4)
    icon.buffs:SetJustifyH("CENTER")
end

function Look.Layout(icon)
    local size = S.Get("campIconSize")
    icon:SetSize(size, size)
    icon.buffs:SetFont(ns.UIFontPath(), S.Get("campBuffTextSize"), "")
    icon.buffs:ClearAllPoints()
    local side = S.Get("campBuffSide")
    icon.buffs:SetJustifyH(side == "right" and "LEFT" or side == "left" and "RIGHT" or "CENTER")
    if side == "right" then icon.buffs:SetPoint("LEFT", icon, "RIGHT", 12, 0)
    elseif side == "left" then icon.buffs:SetPoint("RIGHT", icon, "LEFT", -12, 0)
    elseif side == "above" then icon.buffs:SetPoint("BOTTOM", icon, "TOP", 0, 12)
    else icon.buffs:SetPoint("TOP", icon, "BOTTOM", 0, -12) end
end

function Look.Shown(icon, on)
    for i = 1, #ROUND_ART do icon[ROUND_ART[i]]:SetShown(on) end
    if on then return end
    for i = 1, #ROUND_EXTRAS do icon[ROUND_EXTRAS[i]]:Hide() end
end

function Look.Step(left)
    for _, step in ipairs(TIME_STEPS) do
        if left > step[1] or step[1] == 0 then return step end
    end
end

function Look.Timed(icon, on)
    icon.timer:SetShown(on)
    icon.drain:SetShown(on)
    icon.track:SetShown(on)
end

function Look.Up(icon, buffs)
    icon.tex:SetDesaturated(false)
    icon.label:Hide()
    icon.buffs:SetText(buffs)
    icon.buffs:Show()
end

function Look.Sitting(icon)
    icon.tex:SetDesaturated(false)
    icon.label:SetText("Resting")
    icon.label:Show()
    icon.buffs:Hide()
end

function Look.Missing(icon)
    icon.tex:SetDesaturated(true)
    icon.label:SetText("Refresh Camp")
    icon.label:Show()
    icon.buffs:Hide()
    Look.Timed(icon, false)
end

function Look.Alert(alert)
    alert.text = Parts.HudText(ns.Font(alert, ALERT_SIZE, nil, T.fg))
    alert.text:SetPoint("CENTER")
    alert.text:SetText(ns.Color("accent", "Camp") .. " Nearby")
    alert:SetSize(alert.text:GetStringWidth() + 16, 40)
end

local Bar = {}

local function Disc(owner, inset, sublevel, color)
    local disc = owner:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    ns.PixelInset(disc, -inset)
    if color then disc:SetColorTexture(color.r, color.g, color.b, 1) end
    local mask = owner:CreateMaskTexture()
    mask:SetAllPoints(disc)
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
    disc:AddMaskTexture(mask)
    return disc
end

local function Edge(f, axis)
    local edge = ns.Solid(f.edges, "OVERLAY", St.BORDER_RGB, 1)
    ns.Hairline(edge, axis)
    return edge
end

local function NewEdges(f)
    f.edges = CreateFrame("Frame", nil, f.bar)
    f.edges:SetAllPoints()
    f.edges:SetFrameLevel(f.line:GetFrameLevel() + 1)
    f.topLeft, f.topRight = Edge(f, "h"), Edge(f, "h")
    local bottom, left, right = Edge(f, "h"), Edge(f, "v"), Edge(f, "v")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
end

local function Notch(f, from, to)
    f.notchFrom, f.notchTo = from, to
    f.topLeft:ClearAllPoints()
    f.topLeft:SetPoint("TOPLEFT", f.bar, "TOPLEFT", 0, 0)
    f.topRight:ClearAllPoints()
    if not from then
        f.topLeft:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT", 0, 0)
        f.topLeft:Show()
        f.topRight:Hide()
        return
    end
    f.topLeft:SetShown(from > 0)
    f.topLeft:SetPoint("TOPRIGHT", f.bar, "TOPLEFT", from, 0)
    f.topRight:SetPoint("TOPLEFT", f.bar, "TOPLEFT", to, 0)
    f.topRight:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT", 0, 0)
    f.topRight:Show()
end

function Bar.Layout(f)
    local size, height = S.Get("campSimpleTextSize"), S.Get("campSimpleHeight")
    f.width, f.height = S.Get("campSimpleWidth"), height
    f.campSize = height - BAR.CAMP_TRIM
    f.radius = f.campSize / 2 + BAR.RING_OUT * ns.OnePixel(f.bar)
    f.rise = f.radius + BAR.CAMP_SEAT
    f.campX = BAR.CAMP_INSET + f.radius
    f.labelX = f.campX + f.radius + BAR.CAMP_GAP
    f.pillRing = (BAR.INNER_RING + BAR.TIME_RING) * ns.OnePixel(f.bar)
    f.pillIcon = height - BAR.PILL_ICON_TRIM
    f.bar:SetHeight(height)
    local font = ns.UIFontPath()
    f.time:SetFont(font, size, "")
    f.note:SetFont(font, size, "")
    f.labels:SetTextSize(size)
    f.halo:SetSize(f.campSize + BAR.HALO_GROW, f.campSize + BAR.HALO_GROW)
end

function Bar.New(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()
    f.host = host
    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetPoint("BOTTOMLEFT")
    f.bar:SetPoint("BOTTOMRIGHT")
    f.backdrop = Parts.Backdrop(f.bar)
    f.backdrop:Paint(St.BACKDROP_ALPHA)
    local fg = T.fg

    f.inner = ns.PixelInset(CreateFrame("Frame", nil, f.bar), 1)
    f.time = ns.Font(f.bar, BAR.TEXT, nil, fg)
    f.time:SetJustifyH("RIGHT")
    f.line = Parts.TimerLine(f.inner, BAR.LINE_H, f.time)
    f.line:SetPoint("BOTTOMLEFT")
    f.line:SetPoint("BOTTOMRIGHT")
    NewEdges(f)
    f.labels = Parts.LabelRow(f.bar, BAR.TEXT, nil, fg, { iconGrow = BAR.BONUS_ICON_GROW, iconGap = BAR.BONUS_ICON_GAP,
        iconDrop = BAR.BONUS_ICON_DROP, separator = St.PLACE_DOT, separatorColor = T.muted })
    Parts.HudText(f.time)
    f.note = Parts.HudText(ns.Font(f.bar, BAR.TEXT, nil, T.accentSoft))
    f.note:SetWordWrap(false)
    f.refreshText = ns.Color("accent", "Refresh") .. " Camp"
    f.nearbyText = ns.Color("accent", "Camp Nearby") .. ns.Color("muted", St.PLACE_DOT) .. "sit to refresh"
    f.moreLabels, f.moreIcons, f.more = {}, {}, 0

    f.capClip = CreateFrame("Frame", nil, f)
    f.capClip:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT")
    f.capClip:SetPoint("TOPRIGHT", f, "TOPRIGHT")
    f.capClip:SetClipsChildren(true)
    f.capClip:SetFrameLevel(f.edges:GetFrameLevel() + 1)
    f.camp = CreateFrame("Frame", nil, f)
    f.camp:SetFrameLevel(f.capClip:GetFrameLevel() + 2)
    f.cap = CreateFrame("Frame", nil, f.capClip)
    f.cap:SetAllPoints(f.camp)
    f.cap:SetFrameLevel(f.capClip:GetFrameLevel() + 1)
    f.outerRing = Disc(f.cap, BAR.RING_OUT, 0, St.BORDER_RGB)
    CampArt(f.camp)
    f.timeRing = Disc(f.camp, BAR.INNER_RING + BAR.TIME_RING, -1)
    f.halo = Parts.Smooth(f:CreateTexture(nil, "BACKGROUND"), St.ROUND)
    f.halo:SetBlendMode("ADD")
    f.halo:SetPoint("CENTER", f.camp)
    f.lit, f.low, f.lead, f.group, f.side, f.pill, f.pillW, f.color = true, false, 0, 0, 0, false, 0, T.accent
    Bar.Layout(f)
    Bar.Paint(f, T.accent, false)
    return f
end

local moreTexts = {}

local function MoreText(n)
    local text = moreTexts[n]
    if not text then
        text = ns.Color("muted", ("+%d more"):format(n))
        moreTexts[n] = text
    end
    return text
end

local function BarSize(f)
    f.host:SetSize(f.pill and f.pillW or f.width, f.height + f.rise)
end

local function Medallion(f)
    f.pill = false
    f.cap:Show()
    local y = BAR.TEXT_LIFT + BAR.LINE_H / 2
    f.camp:ClearAllPoints()
    f.camp:SetSize(f.campSize, f.campSize)
    f.camp:SetPoint("CENTER", f.bar, "TOPLEFT", f.campX, BAR.CAMP_SEAT)
    Notch(f, f.campX - f.radius, f.campX + f.radius)
    f.labels:ClearAllPoints()
    f.labels:SetPoint("LEFT", f.bar, "LEFT", f.labelX + f.lead, y)
    f.note:ClearAllPoints()
    f.note:SetPoint("LEFT", f.bar, "LEFT", f.labelX, y)
    f.time:ClearAllPoints()
    f.time:SetPoint("RIGHT", f.bar, "RIGHT", -BAR.PAD, y)
end

local function BarFit(f, labels, icons, n, timed)
    f.side = timed and BAR.TIME_W + BAR.TIME_GAP or 0
    local room = f.width - f.labelX - f.lead - f.side - BAR.PAD
    f.labels:SetLabels(labels, n, icons)
    f.group = f.labels:Pack()
    f.more = 0
    local kept = n - 1
    while f.group > room and kept >= 1 do
        local list, marks = f.moreLabels, f.moreIcons
        for i = 1, kept do list[i], marks[i] = labels[i], icons and icons[i] or false end
        list[kept + 1], marks[kept + 1] = MoreText(n - kept), false
        f.labels:SetLabels(list, kept + 1, marks)
        f.group = f.labels:Pack()
        f.more = n - kept
        kept = kept - 1
    end
    Medallion(f)
    BarSize(f)
end

local function BarNote(f, text, color)
    f.note:SetText(text)
    f.note:SetTextColor(color.r, color.g, color.b)
    f.note:Show()
end

local function RingColor(f)
    local c = f.lit and f.color or T.muted
    f.timeRing:SetColorTexture(c.r, c.g, c.b, 1)
end

local function BarLit(f, on)
    f.lit = on
    f.camp.tex:SetDesaturated(not on)
    RingColor(f)
    f.halo:SetShown(on and f.low)
end

function Bar.Paint(f, color, low)
    f.low = low and true or false
    f.color = color
    f.line:Paint(color, f.low and color or T.fg)
    RingColor(f)
    f.halo:SetVertexColor(color.r, color.g, color.b, BAR.HALO_ALPHA)
    f.halo:SetShown(f.lit and f.low)
end

function Bar.Timed(f, on)
    on = on and true or false
    if not on then f.line:Stop() end
    f.line:SetShown(on)
    f.time:SetShown(on)
end

function Bar.Up(f, labels, icons, n, timed)
    BarLit(f, true)
    f.lead = 0
    f.labels:SetColor(T.fg)
    if n > 0 then f.note:Hide() else BarNote(f, "Camp Benefits", T.fg) end
    BarFit(f, labels, icons, n, timed)
end

function Bar.Sitting(f, labels, icons, n, timed, upcoming)
    BarLit(f, true)
    f.lead = 0
    if upcoming then
        f.note:Hide()
        f.labels:SetColor(T.accentSoft)
    else
        BarNote(f, "Resting", T.accentSoft)
        f.labels:SetColor(T.muted)
        if n > 0 then f.lead = math.ceil(f.note:GetStringWidth()) + BAR.NOTE_GAP end
    end
    BarFit(f, labels, icons, n, timed)
end

function Bar.Missing(f, nearby)
    BarLit(f, false)
    f.pill = true
    f.cap:Hide()
    Notch(f, nil)
    f.labels:SetLabels(nil, 0)
    BarNote(f, nearby and f.nearbyText or f.refreshText, T.fg)
    f.camp:ClearAllPoints()
    f.camp:SetSize(f.pillIcon, f.pillIcon)
    f.camp:SetPoint("LEFT", f.bar, "LEFT", BAR.PAD + f.pillRing, 0)
    f.note:ClearAllPoints()
    f.note:SetPoint("LEFT", f.camp, "RIGHT", BAR.PILL_GAP + f.pillRing, BAR.TEXT_LIFT)
    f.pillW = math.ceil(BAR.PAD + f.pillRing * 2 + f.pillIcon + BAR.PILL_GAP + f.note:GetStringWidth() + BAR.PAD)
    Bar.Timed(f, false)
    BarSize(f)
end

local icon, unlocked
local hasCamp       -- nil until the first read
local shownExpiry   -- the expiry the swipe was last started from
local alert
local alertGen = 0   -- invalidates an older Alert Under timer
local alertArmed     -- the expiry that timer was set for
local alertDismissed -- Ctrl-clicked away; back once you leave the campfire's range
local ringGen = 0    -- invalidates an older ring colour change
local showGen = 0    -- invalidates an older "drops under the Show Only When Low time" timer
local showArmed      -- the expiry and minutes that timer was set for
local bonusTags, bonusFeatures, bonusLabels = {}, {}, {}
local barLabels, barIcons, sampleLabels, sampleIcons = {}, {}, {}, {}
local fallbackTags, joinedTags = {}, {}
local bonusCount, barCount, bonusText = 0, 0, ""
local campState, campExpiry, campUpcoming
local simpleBar

local function On()
    return S.Get("enabled") and S.Get("campfire")
end

local function Simple()
    return S.Get("campStyle") == "simple"
end

-- Camp Benefits is earned in the open world, so dungeons, raids and battlegrounds never
-- nag about it.
local function InOpenWorld()
    local inInstance = IsInInstance()
    return not inInstance
end

-- Show Active Camp Buffs: Off, Always or On Mouseover. A profile that never picked one
-- follows the old on/off switch, so nobody's setting changes.
function ns.CampBuffMode()
    local mode = S.Get("campBuffMode")
    if mode then return mode end
    return S.Get("campBuffs") and "always" or "off"
end

-- On Mouseover: the buff lines stay written but invisible until the icon is hovered.
local function PaintBuffs()
    local hidden = ns.CampBuffMode() == "hover" and not unlocked and not icon:IsMouseOver()
    icon.buffs:SetAlpha(hidden and 0 or 1)
end

local function TimeWords(left)
    if left >= 60 then return ("%d min"):format(math.ceil(left / 60)) end
    return ("%d sec"):format(math.max(0, math.ceil(left)))
end

local function Points(feature, aura)
    if not aura then return nil end
    local points = aura.points
    if issecretvalue and issecretvalue(points) then return nil end
    if type(points) ~= "table" then return nil end
    for i = 1, feature.points do
        local v = points[i]
        if (issecretvalue and issecretvalue(v)) or type(v) ~= "number" then return nil end
    end
    return points
end

local function BonusWords(feature, readable)
    local points = feature.amount and readable and Points(feature, C_UnitAuras.GetPlayerAuraBySpellID(feature.id))
    if not points then return feature.stat end
    return feature.amount:format(points[1], points[2], points[3])
end

local function BonusLabel(feature, amount)
    if not amount then return feature.short end
    local text = feature.labels[amount]
    if not text then
        text = ns.Color("muted", ("+%d%s"):format(amount, feature.unit or "")) .. " " .. feature.short
        feature.labels[amount] = text
    end
    return text
end

local function FeatureIcon(feature)
    if feature.icon == nil then feature.icon = C_Spell.GetSpellTexture(feature.id) or false end
    return feature.icon
end

local function Hidden(feature)
    local hidden = S.Get("campHiddenBonuses")
    return feature and hidden and hidden[feature.id] and true or false
end

local function FilterBar()
    local icons, n = S.Get("campBonusIcons"), 0
    for i = 1, bonusCount do
        local feature = bonusFeatures[i]
        if not Hidden(feature) then
            n = n + 1
            barLabels[n] = bonusLabels[i]
            barIcons[n] = icons and feature and FeatureIcon(feature) or false
        end
    end
    barCount = n
end

local function FillSamples(filter)
    local icons, n = S.Get("campBonusIcons"), 0
    for i = 1, #SAMPLE_BONUSES do
        local feature, amount = SAMPLE_BONUSES[i][1], SAMPLE_BONUSES[i][2]
        if not (filter and Hidden(feature)) then
            n = n + 1
            sampleLabels[n] = BonusLabel(feature, amount)
            sampleIcons[n] = icons and FeatureIcon(feature) or false
        end
    end
    return n
end

local function TipBonuses(tip, readable)
    local fg, muted = T.fg, T.muted
    for i = 1, bonusCount do
        local feature = bonusFeatures[i]
        if feature then
            tip:AddDoubleLine(BonusWords(feature, readable), feature.name, fg.r, fg.g, fg.b, muted.r, muted.g, muted.b)
        else
            tip:AddLine(bonusTags[i], fg.r, fg.g, fg.b)
        end
    end
end

local function ShowTip(owner)
    if unlocked or not Parts.Tip(owner, "ANCHOR_TOP") then return end
    local tip, fg, muted, soft = GameTooltip, T.fg, T.muted, T.accentSoft
    tip:SetText("Camp Benefits", T.accent.r, T.accent.g, T.accent.b)
    local readable = not (InCombatLockdown() or C_Secrets.ShouldAurasBeSecret())
    if campState == "sitting" then
        if campUpcoming then
            tip:AddLine("You'll get:", fg.r, fg.g, fg.b)
            TipBonuses(tip, readable)
        else
            tip:AddLine("Resting at a campfire", fg.r, fg.g, fg.b)
        end
        if campExpiry then
            tip:AddLine("Camp Benefits in " .. TimeWords(campExpiry - GetTime()), muted.r, muted.g, muted.b)
        end
    elseif campState == "up" then
        TipBonuses(tip, readable)
        if campExpiry then
            local left = campExpiry - GetTime()
            local c = Look.Step(left)[2]
            tip:AddDoubleLine("Time left", TimeWords(left), muted.r, muted.g, muted.b, c.r, c.g, c.b)
            local advice = left <= REFRESH_NOW and "Refresh now" or "Refresh in " .. TimeWords(left - REFRESH_NOW)
            tip:AddLine(advice, c.r, c.g, c.b)
        end
    else
        local out = St.TIME_OUT_RGB
        tip:AddLine("No Camp Benefits", muted.r, muted.g, muted.b)
        tip:AddLine("Refresh now", out.r, out.g, out.b)
    end
    if readable and C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY) then
        tip:AddLine("A campfire is in range", soft.r, soft.g, soft.b)
    end
    tip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function Anchored(simple, left, x, y)
    if simple then return { point = "LEFT", relPoint = "BOTTOMLEFT", x = left, y = y } end
    return { point = "CENTER", relPoint = "BOTTOMLEFT", x = x, y = y }
end

local function SavePos(pos)
    local x, y = icon:GetCenter()
    local left = icon:GetLeft()
    if x and y and left then
        pos = Anchored(Simple(), left, x, y)
        icon:ClearAllPoints()
        icon:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
    S.Set("campPos", pos)
end

local function Build()
    icon = CreateFrame("Frame", "NaowhForeverCampfire", UIParent)
    icon:SetMovable(true)
    icon:SetClampedToScreen(true)

    Look.New(icon)

    -- Hovering the icon shows the buff lines while Show Active Camp Buffs is On Mouseover. The
    -- icon only takes the mouse then (Apply), so clicks and camera drags otherwise go through.
    icon:SetScript("OnEnter", PaintBuffs)
    icon:SetScript("OnLeave", PaintBuffs)

    icon.mover = ns.UI.AttachMover(icon, "Campfire", SavePos, "AuraBuffs/Settings", "AuraBuffs/Settings:campfire")
    icon:Hide()
end

local function UseStyle(simple)
    if simple and not simpleBar then
        simpleBar = Bar.New(icon)
        simpleBar:SetMouseMotionEnabled(true)
        simpleBar:SetMouseClickEnabled(false)
        simpleBar:SetScript("OnEnter", ShowTip)
        simpleBar:SetScript("OnLeave", HideTip)
    end
    if simpleBar then simpleBar:SetShown(simple) end
    Look.Shown(icon, not simple)
end

local function Place()
    local pos = S.Get("campPos")
    icon:ClearAllPoints()
    if pos then
        icon:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    elseif Simple() then
        icon:SetPoint("LEFT", UIParent, "CENTER", DEFAULT_X - S.Get("campIconSize") / 2, DEFAULT_Y)
    else
        icon:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
    end
end

local function BarShown()
    return simpleBar ~= nil and simpleBar:IsShown()
end

local function PaintTime(color, low)
    if BarShown() then
        Bar.Paint(simpleBar, color, low)
    else
        icon.drain:SetSwipeColor(color.r, color.g, color.b, 1)
    end
end

local function RunTimer(start, duration, prefix)
    if BarShown() then
        simpleBar.line:Run(start, duration, prefix)
    else
        icon.timer:SetCooldown(start, duration)
        icon.drain:SetCooldown(start, duration)
    end
end

local function Timed(on)
    if BarShown() then Bar.Timed(simpleBar, on) else Look.Timed(icon, on) end
end

-- Nothing fires as the buff runs down, so each colour change is timed.
local function ColorRing(expiry)
    ringGen = ringGen + 1
    local left = expiry - GetTime()
    local step = Look.Step(left)
    PaintTime(step[2], step ~= TIME_STEPS[1])
    if step[1] > 0 then
        local gen = ringGen
        C_Timer.After(left - step[1] + 0.1, function()
            if gen == ringGen then ColorRing(expiry) end
        end)
    end
end

local function ShowUp(duration, expiry, text, labels, icons, n)
    local timed = S.Get("campTimer") and duration and duration > 0 and true or false
    campState, campExpiry = "up", expiry
    if BarShown() then
        Bar.Up(simpleBar, labels, icons, n, timed)
    else
        Look.Up(icon, ns.CampBuffMode() ~= "off" and text or "")
        PaintBuffs()
    end
    if timed then
        if shownExpiry ~= expiry then
            RunTimer(expiry - duration, duration)
            ColorRing(expiry)
            shownExpiry = expiry
        end
        Timed(true)
    else
        Timed(false)
        ringGen = ringGen + 1
        shownExpiry = nil
    end
    icon:Show()
end

local function ShowSitting(duration, expiry, upcoming)
    local timed = S.Get("campTimer") and true or false
    campState, campExpiry, campUpcoming = "sitting", expiry, upcoming
    if BarShown() then
        Bar.Sitting(simpleBar, barLabels, barIcons, barCount, timed, upcoming)
    else
        Look.Sitting(icon)
    end
    ringGen = ringGen + 1
    if timed and shownExpiry ~= expiry then
        RunTimer(expiry - duration, duration, SIT_PREFIX)
        PaintTime(T.accent, false)
        shownExpiry = expiry
    elseif not timed then
        shownExpiry = nil
    end
    Timed(timed)
    icon:Show()
end

local function ShowMissing(nearby)
    campState, campExpiry = "missing", nil
    if BarShown() then Bar.Missing(simpleBar, nearby) else Look.Missing(icon) end
    ringGen = ringGen + 1
    shownExpiry = nil
    icon:SetShown(S.Get("campShowMissing") or unlocked == true)
end

-- "Camp Nearby" in the middle of the screen when a campfire is in range and the camp needs
-- refreshing: no Camp Benefits, or less than two minutes left on it.
local function BuildAlert()
    alert = CreateFrame("Frame", "NaowhForeverCampNearby", UIParent)
    alert:SetMovable(true)
    alert:SetClampedToScreen(true)
    Look.Alert(alert)
    -- Ctrl-click dismisses it. It takes the mouse only while Ctrl is down, so an ordinary click
    -- or camera drag in the middle of the screen still reaches the world.
    alert:EnableMouse(false)
    alert:SetScript("OnShow", function(self)
        self:EnableMouse(IsControlKeyDown())
        self:RegisterEvent("MODIFIER_STATE_CHANGED")
    end)
    alert:SetScript("OnHide", function(self) self:UnregisterEvent("MODIFIER_STATE_CHANGED") end)
    alert:SetScript("OnEvent", function(self) self:EnableMouse(IsControlKeyDown()) end)
    alert:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() and not unlocked then
            alertDismissed = true
            self:Hide()
        end
    end)
    alert.mover = ns.UI.AttachMover(alert, "Camp Nearby", function(pos) S.Set("campAlertPos", pos) end,
        "AuraBuffs/Settings", "AuraBuffs/Settings:campNearby")
    local pos = S.Get("campAlertPos")
    if pos then
        alert:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        alert:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    end
    alert:Hide()
end

local function SetAlert(show)
    if not alert then
        if not show then return end
        BuildAlert()
    end
    alert:SetShown(show)
end

-- The same tags found in the effect text, for a camp feature not in FEATURE_TAGS. Armor comes
-- before stats, since the Enchanted Lute's effect names both.
local EFFECT_TAGS = {
    { "rested", "+Rested" }, { "rest experience", "+Rested" }, { "critical strike", "+Crit" },
    { "armor", "+ARM" }, { "attack power", "+ATK" }, { "strength", "+STR" }, { "stamina", "+STA" },
    { "intellect", "+INT" }, { "spirit", "+Spirit" }, { "mana", "+MP5" }, { "mp5", "+MP5" },
    { "stats", "+Stats" },
}
-- Each camp feature's benefit as a short stat tag. Upgraded features give the benefit of the
-- one they replace (Wowhead's Forever item data, 2026-09-30). Matched by name first, so a
-- benefit text that names other stats (all stats spelled out one by one) cannot mislabel it.
local FEATURE_TAGS = {
    ["Camp Tent"] = "+Rested", ["Tanning Rack"] = "+Rested", ["Sewing Machine"] = "+Rested",
    ["Camp Chair"] = "+Crit", ["Trapper's Workbench"] = "+Crit", ["Field Guide"] = "+Crit",
    ["Enchanted Lute"] = "+ARM", ["Arcane Salvager"] = "+ARM", ["Arcane Forge"] = "+ARM",
    ["Lodestone"] = "+ATK", ["Rock Garden"] = "+ATK", ["Molten Foundry"] = "+ATK",
    ["Sharpening Wheel"] = "+STR", ["Anvil"] = "+STR", ["Master Forge"] = "+STR",
    ["First Aid Kit"] = "+STA", ["Toxin Study"] = "+STA", ["Plague Doctor's Laboratory"] = "+STA",
    ["Incense Candle"] = "+INT", ["Greenhouse"] = "+INT", ["Seed Hybridizer"] = "+INT",
    ["Faction Banner"] = "+Spirit", ["Spinning Wheel"] = "+Spirit", ["Loom"] = "+Spirit",
    ["Mana Well"] = "+MP5", ["Fermenter"] = "+MP5", ["Alchemy Laboratory"] = "+MP5",
    ["Fish Bowl"] = "+Stats", ["Fishing Rack"] = "+Stats", ["Fishing Hut"] = "+Stats",
}

-- Anything neither list knows keeps a short effect text, or else the camp feature's name.
local function ShortCampBuff(label, effect)
    if FEATURE_TAGS[label] then return FEATURE_TAGS[label] end
    local lower = effect:lower()
    for _, tag in ipairs(EFFECT_TAGS) do
        if lower:find(tag[1], 1, true) then return tag[2] end
    end
    if #effect > 0 and #effect <= 28 then return effect end
    return label
end

-- Only readable benefit rows, excluding the tooltip header, timer and ID metadata.
local function ActiveBuffs(aura, out)
    local data = C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", aura.auraInstanceID)
    local names, seen, n = out or {}, {}, 0
    for i, line in ipairs(data and data.lines or {}) do
        local text = line.leftText
        if i > 1 and type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            for row in text:gmatch("[^\n]+") do
                local label = row:match("^%s*([^:]+):%s*%S")
                if label and not label:find("[%d|]") and not label:find("ID$") then
                    label = label:match("^%s*(.-)%s*$")
                    local effect = row:match("^[^:]+:%s*(.-)%s*$") or ""
                    local short = ShortCampBuff(label, effect)
                    if not seen[short] then
                        n = n + 1
                        names[n] = short
                        seen[short] = true
                    end
                end
            end
        end
    end
    return table.concat(names, "\n", 1, n), n
end

local Refresh

local function ReadBonuses(aura)
    local n, mask = 0, 0
    for i = 1, #FEATURES do
        local feature = FEATURES[i]
        local found = C_UnitAuras.GetPlayerAuraBySpellID(feature.id)
        if found then
            n = n + 1
            local points = feature.amount and Points(feature, found)
            bonusTags[n], bonusFeatures[n] = feature.tag, feature
            bonusLabels[n] = BonusLabel(feature, points and points[1])
            mask = mask + feature.bit
        end
    end
    if n > 0 then
        local text = joinedTags[mask]
        if not text then
            text = table.concat(bonusTags, "\n", 1, n)
            joinedTags[mask] = text
        end
        bonusText = text
    elseif aura then
        bonusText, n = ActiveBuffs(aura, fallbackTags)
        for i = 1, n do
            local tag = fallbackTags[i]
            local feature = FEATURE_BY_TAG[tag]
            bonusTags[i], bonusFeatures[i] = tag, feature or false
            bonusLabels[i] = feature and feature.short or tag
        end
    else
        return false
    end
    bonusCount = n
    FilterBar()
    return n > 0
end

local function DisarmAlert()
    alertGen = alertGen + 1
    alertArmed = nil
end

-- UNIT_AURA fires often, so the timer is only set again for a new expiry.
local function UpdateAlert(aura)
    if Simple() or not (S.Get("campNearbyAlert") and C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY)) then
        alertDismissed = nil
        DisarmAlert()
        SetAlert(false)
        return
    end
    if alertDismissed then
        DisarmAlert()
        SetAlert(false)
        return
    end
    local expiry = aura and aura.expirationTime
    if expiry and issecretvalue and issecretvalue(expiry) then expiry = nil end
    local left = expiry and expiry > 0 and expiry - GetTime()
    if aura and not left then
        DisarmAlert()
        SetAlert(false)
        return
    end
    local low = S.Get("campNearbyMinutes") * 60
    SetAlert(not aura or left < low)
    if not (aura and left >= low) then
        DisarmAlert()
    elseif alertArmed ~= expiry then
        DisarmAlert()
        alertArmed = expiry
        local gen = alertGen
        C_Timer.After(left - low + 0.1, function()
            if gen == alertGen then
                alertArmed = nil
                Refresh()
            end
        end)
    end
end

-- The client hides the player's auras from addons during combat, where this read comes back
-- empty with the buff up, so the icon keeps whatever it last showed until the fight ends.
-- InCombatLockdown() is still false while PLAYER_REGEN_DISABLED is handled.
function Refresh(_, event)
    if not icon then return end
    if unlocked then
        ShowUp(3600, GetTime() + 2400, UNLOCK_TEXT, sampleLabels, sampleIcons, FillSamples(true))
        SetAlert(S.Get("campNearbyAlert") and not Simple())
        return
    end
    if not (On() and InOpenWorld()) then
        icon:Hide()
        DisarmAlert()
        SetAlert(false)
        return
    end
    if InCombatLockdown() or event == "PLAYER_REGEN_DISABLED" or C_Secrets.ShouldAurasBeSecret() then
        DisarmAlert()
        SetAlert(false)
        return
    end

    local aura = C_UnitAuras.GetPlayerAuraBySpellID(CAMP_BENEFITS)
    local had = hasCamp
    hasCamp = aura ~= nil
    local sitting = C_UnitAuras.GetPlayerAuraBySpellID(WELCOMING_CAMPFIRE)
    local sitDuration, sitExpiry = sitting and sitting.duration, sitting and sitting.expirationTime
    if sitting and not (issecretvalue and (issecretvalue(sitDuration) or issecretvalue(sitExpiry)))
        and sitDuration > 0 then
        ShowSitting(sitDuration, sitExpiry, Simple() and ReadBonuses(nil) or false)
        DisarmAlert()
        SetAlert(false)
        return
    end
    if aura then
        local duration, expiry = aura.duration, aura.expirationTime
        if issecretvalue and (issecretvalue(duration) or issecretvalue(expiry)) then
            duration, expiry = nil, nil
        end
        local left = expiry and expiry > 0 and expiry - GetTime()
        local under = S.Get("campShowUnderMinutes") * 60
        if S.Get("campShowUnder") and left and left > under then
            icon:Hide()
            local key = expiry .. ":" .. under
            if showArmed ~= key then
                showArmed = key
                showGen = showGen + 1
                local gen = showGen
                C_Timer.After(left - under + 0.1, function()
                    if gen == showGen then
                        showArmed = nil
                        Refresh()
                    end
                end)
            end
        else
            if showArmed then
                showArmed = nil
                showGen = showGen + 1
            end
            if Simple() or ns.CampBuffMode() ~= "off" then ReadBonuses(aura) end
            ShowUp(duration, expiry, bonusText, barLabels, barIcons, barCount)
        end
    else
        ShowMissing(C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY) ~= nil)
        if had and S.Get("campSound") then
            ns.UI._PlayLSMSound(ns.UI.SoundPathFor(S.Get("campSoundKey")))
        end
    end
    UpdateAlert(aura)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", Refresh)

local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        hasCamp = nil
        ringGen = ringGen + 1
        DisarmAlert()
        SetAlert(false)
        if icon and not unlocked then icon:Hide() end
        if not unlocked then return end
    end
    if not icon then Build() end
    local simple = Simple()
    UseStyle(simple)
    icon:EnableMouse(not simple and ns.CampBuffMode() == "hover")
    if simple then Bar.Layout(simpleBar) else Look.Layout(icon) end
    Place()
    icon.mover:SetShown(unlocked == true)
    if On() then
        events:RegisterUnitEvent("UNIT_AURA", "player")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    shownExpiry = nil
    Refresh()
    if alert then alert.mover:SetShown(unlocked == true) end
end

local function Restyle()
    local x, y, left
    if icon and S.Get("campPos") then
        x, y = icon:GetCenter()
        left = icon:GetLeft()
    end
    Apply()
    if not (x and y and left and icon) then return end
    local pos = Anchored(Simple(), left, x, y)
    icon:ClearAllPoints()
    icon:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    S.Set("campPos", pos)
end

hooksecurefunc(S, "Set", function(key)
    -- A timer armed for the old threshold would fire at the wrong time.
    if key == "campNearbyMinutes" then DisarmAlert() end
    if key == "campStyle" then
        Restyle()
    elseif key == "enabled" or (key:find("^camp") and key ~= "campPos" and key ~= "campAlertPos") then
        Apply()
    end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowRaidReminderAnchorConfig", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideRaidReminderAnchorConfig", function()
    unlocked = false
    if icon then Apply() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local OFF = "Turn on AuraBuffs"
local ROUND_ONLY, SIMPLE_ONLY = "Round style only", "Simple style only"
local STAGE_H, ALERT_H, NOTE_Y, NOTE_SIZE, NOTE_GAP_Y, STAGE_MARGIN, HINT_ROOM = 230, 90, 10, 11, 4, 16, 30
local CAMP_HOUR, SIT_TIME, BUFF_GAP = 3600, 60, 12
local EDGE_HIT, HIDDEN_ALPHA, DRAG_FACTOR = 8, 0.35, 2
local WIDTH_RANGE, TEXT_RANGE, HEIGHT_RANGE = { 200, 480, 5 }, { 10, 16, 1 }, { 20, 36, 1 }
local SAMPLE_BUFFS = "+Rested\n+Crit"
local SIMPLE_HINT = "Drag the right edge for width. Wheel: text size (Shift: height). Click a bonus or the time "
    .. "to show or hide it. Right-click for more."
local SIMPLE_OFF_HINT = "Turn on the Campfire reminder to edit the bar here."
local SAMPLES = { up = 2400, low = 240, sitting = 35 }
local STYLES = { { round = "Round", simple = "Simple" }, { "round", "simple" } }
local BUFF_MODES = { { off = "Off", always = "Always", hover = "On Mouseover" }, { "off", "always", "hover" } }
local SIDES = { { below = "Below", above = "Above", left = "Left", right = "Right" },
    { "below", "above", "left", "right" } }
local BAR_KEYS = { campSimpleWidth = true, campSimpleHeight = true, campSimpleTextSize = true,
    campBonusIcons = true, campHiddenBonuses = true }

local function NearbyState() return Simple() and S.Get("campShowMissing") and true or false end

local STATES = {
    { key = "up", label = "Active", tip = "Camp Benefits with most of its hour left." },
    { key = "low", label = "Running Low", tip = "Camp Benefits about to run out." },
    { key = "sitting", label = "Resting", tip = "Sitting at a campfire, before Camp Benefits lands." },
    { key = "missing", label = "Refresh", tip = "No Camp Benefits, out in the world.", needs = "campShowMissing" },
    { key = "nearby", label = "Camp Nearby", tip = "No Camp Benefits, with a campfire in range.", needs = NearbyState },
}
local ALERT_STATES = {
    { key = "nearby", label = "Camp Nearby", tip = "A campfire in range while your camp needs refreshing." },
}

local campCard

local function Enabled() return S.Get("enabled") and true or false end
local function Needs(key) return function() return S.Get("enabled") and S.Get(key) and true or false end end
local function CampOn() return S.Get("enabled") and S.Get("campfire") and true or false end
local function RoundCampOn() return CampOn() and not Simple() end
local function RoundOn() return S.Get("enabled") and not Simple() and true or false end
local function SimpleOn() return S.Get("enabled") and Simple() and true or false end
local function PickBuffMode(v) S.Set("campBuffMode", v) end

local function HiddenNote(state)
    if state == "up" and S.Get("campShowUnder") and SAMPLES.up > S.Get("campShowUnderMinutes") * 60 then
        return ("Show Only When Low: hidden until under %d min."):format(S.Get("campShowUnderMinutes"))
    end
end

local function ToggleBonus(feature)
    local copy = {}
    for id, on in pairs(S.Get("campHiddenBonuses") or {}) do copy[id] = on end
    if copy[feature.id] then copy[feature.id] = nil else copy[feature.id] = true end
    S.Set("campHiddenBonuses", copy)
end

local function ShowAllBonuses() S.Set("campHiddenBonuses", {}) end
local function BonusShown(feature) return not Hidden(feature) end
local function Toggled(key) return S.Get(key) == true end
local function Toggle(key) S.Set(key, not S.Get(key)) end
local function StylePicked(style) return S.Get("campStyle") == style end
local function PickStyle(style) S.Set("campStyle", style) end
local function BonusClicked(zone) ToggleBonus(zone.feature) end
local function TimeClicked() Toggle("campTimer") end
local function WidthGet() return S.Get("campSimpleWidth") end
local function WidthSet(v) S.Set("campSimpleWidth", v) end

local function ResetBar()
    for _, row in ipairs(campCard.rows) do
        if BAR_KEYS[row.key] then Settings.ResetRow(row) end
    end
end

local function BarWheel(_, delta)
    local key, range = "campSimpleTextSize", TEXT_RANGE
    if IsShiftKeyDown() then key, range = "campSimpleHeight", HEIGHT_RANGE end
    local v = Settings.Snap(S.Get(key) + delta * range[3], range)
    if v ~= S.Get(key) then S.Set(key, v) end
end

local function BarMenu(_, root)
    root:CreateTitle("Style")
    root:CreateRadio("Round", StylePicked, PickStyle, "round")
    root:CreateRadio("Simple", StylePicked, PickStyle, "simple")
    root:CreateDivider()
    root:CreateCheckbox("Bonus Icons", Toggled, Toggle, "campBonusIcons")
    root:CreateCheckbox("Show Timer", Toggled, Toggle, "campTimer")
    local list = root:CreateButton("Bonuses")
    for _, feature in ipairs(FEATURES) do
        list:CreateCheckbox(feature.short .. St.PLACE_DOT .. feature.name, BonusShown, ToggleBonus, feature)
    end
    root:CreateDivider()
    root:CreateButton("Reset Bar", ResetBar)
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.icon = CreateFrame("Frame", nil, shot)
    Look.New(shot.icon)
    shot.hint = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    shot.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    return shot
end

local function Fit(shot)
    local f = shot.icon
    local reach = f:GetHeight() + (S.Get("campBuffTextSize") + BUFF_GAP) * 2
    local room = shot:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2
    local scale = 1
    if room > 0 and reach > room then scale = room / reach end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", shot, "CENTER", 0, NOTE_Y / scale)
end

local function Run(f, left, duration)
    local start = GetTime() - (duration - left)
    f.timer:SetCooldown(start, duration)
    f.drain:SetCooldown(start, duration)
    Look.Timed(f, S.Get("campTimer"))
end

local function Zone(shot, opts)
    opts.wheel, opts.menu = BarWheel, BarMenu
    local zone = Settings.EditZone(shot.bar, opts)
    zone:SetFrameLevel(shot.bar.camp:GetFrameLevel() + #shot.zones + 1)
    shot.zones[#shot.zones + 1] = zone
    return zone
end

local function PreviewBar(shot)
    if shot.bar then return shot.bar end
    shot.barHost = CreateFrame("Frame", nil, shot)
    local f = Bar.New(shot.barHost)
    shot.bar, shot.zones, shot.bonusZones = f, {}, {}
    local body = Zone(shot, {})
    body:SetAllPoints(f.bar)
    f.labels:SetLabels(sampleLabels, FillSamples(false))
    for i = 1, #SAMPLE_BONUSES do
        local zone = Zone(shot, { click = BonusClicked, wash = true })
        zone.feature = SAMPLE_BONUSES[i][1]
        zone:SetAllPoints(f.labels.labels[i])
        shot.bonusZones[i] = zone
    end
    shot.timeZone = Zone(shot, { click = TimeClicked, wash = true })
    shot.timeZone:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT")
    shot.timeZone:SetPoint("BOTTOMRIGHT", f.bar, "BOTTOMRIGHT")
    shot.timeZone:SetWidth(BAR.TIME_W + BAR.PAD)
    shot.widthZone = Zone(shot, { edge = true, drag = { get = WidthGet, set = WidthSet, range = WIDTH_RANGE,
        factor = DRAG_FACTOR, live = function(v) f.width = v; BarSize(f) end } })
    shot.widthZone:SetPoint("TOP", f.bar, "TOPRIGHT")
    shot.widthZone:SetPoint("BOTTOM", f.bar, "BOTTOMRIGHT")
    shot.widthZone:SetWidth(EDGE_HIT)
    return f
end

local function FitBar(shot)
    local host, f = shot.barHost, shot.bar
    local w, h = f.width, host:GetHeight()
    local roomW = shot:GetWidth() - STAGE_MARGIN * 2
    local roomH = shot:GetHeight() - STAGE_MARGIN * 2 - HINT_ROOM
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    host:SetScale(scale)
    host:ClearAllPoints()
    host:SetPoint("LEFT", shot, "CENTER", -w / 2, HINT_ROOM / 2 / scale)
end

local function RunBar(f, left, duration, timed, prefix)
    if timed then f.line:Run(GetTime() - (duration - left), duration, prefix) end
    Bar.Timed(f, timed)
end

local function PaintBarPreview(shot, state, hidden)
    local f = PreviewBar(shot)
    Bar.Layout(f)
    local timed = S.Get("campTimer") and true or false
    local n = FillSamples(false)
    local pill = state == "missing" or state == "nearby"
    if pill then
        Bar.Missing(f, state == "nearby")
    elseif state == "sitting" then
        Bar.Sitting(f, sampleLabels, sampleIcons, n, timed, true)
        Bar.Paint(f, T.accent, false)
        RunBar(f, SAMPLES.sitting, SIT_TIME, timed, SIT_PREFIX)
    else
        Bar.Up(f, sampleLabels, sampleIcons, n, timed)
        local step = Look.Step(SAMPLES[state])
        Bar.Paint(f, step[2], step ~= TIME_STEPS[1])
        RunBar(f, SAMPLES[state], CAMP_HOUR, timed)
    end
    local editable = CampOn()
    for i, zone in ipairs(shot.bonusZones) do
        local alpha = Hidden(zone.feature) and HIDDEN_ALPHA or 1
        f.labels.labels[i]:SetAlpha(alpha)
        if f.labels.icons[i] then f.labels.icons[i]:SetAlpha(alpha) end
    end
    for _, zone in ipairs(shot.zones) do zone:SetShown(editable and (not pill or zone == shot.zones[1])) end
    FitBar(shot)
    shot.barHost:SetShown(not hidden)
    shot.hint:SetText(editable and SIMPLE_HINT or SIMPLE_OFF_HINT)
    shot.note:ClearAllPoints()
    shot.note:SetPoint("BOTTOM", shot.hint, "TOP", 0, NOTE_GAP_Y)
    shot.note:SetText(hidden or "")
end

local function PaintPreview(shot, state)
    local f = shot.icon
    local hidden = HiddenNote(state)
    if Simple() then
        f:Hide()
        PaintBarPreview(shot, state, hidden)
        return
    end
    if shot.barHost then shot.barHost:Hide() end
    shot.hint:SetText("")
    shot.note:ClearAllPoints()
    shot.note:SetPoint("BOTTOM", shot, "BOTTOM", 0, NOTE_Y)
    Look.Layout(f)
    Fit(shot)
    local mode = ns.CampBuffMode()
    local note = hidden
    if state == "missing" then
        Look.Missing(f)
    elseif state == "sitting" then
        Look.Sitting(f)
        f.drain:SetSwipeColor(T.accent.r, T.accent.g, T.accent.b, 1)
        Run(f, SAMPLES.sitting, SIT_TIME)
    else
        Look.Up(f, mode ~= "off" and SAMPLE_BUFFS or "")
        f.buffs:SetAlpha(1)
        local color = Look.Step(SAMPLES[state])[2]
        f.drain:SetSwipeColor(color.r, color.g, color.b, 1)
        Run(f, SAMPLES[state], CAMP_HOUR)
        if not note and mode == "hover" then note = "The buffs show while you hover the icon." end
    end
    f:SetShown(not hidden)
    shot.note:SetText(note or "")
end

local function NewAlert(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.alert = CreateFrame("Frame", nil, shot)
    Look.Alert(shot.alert)
    shot.alert:SetPoint("CENTER")
    return shot
end

local function PaintAlert() end

local function CampSummary(store)
    if store.Get("campStyle") == "simple" then
        local parts = { "Simple bar", store.Get("campTimer") and "timer" or "no timer" }
        if store.Get("campBonusIcons") then parts[#parts + 1] = "bonus icons" end
        if store.Get("campSound") then parts[#parts + 1] = "a sound to refresh" end
        return table.concat(parts, ", ")
    end
    local parts = { store.Get("campTimer") and "Timer" or "No timer" }
    local mode = ns.CampBuffMode()
    if mode == "always" then parts[#parts + 1] = "camp buffs"
    elseif mode == "hover" then parts[#parts + 1] = "camp buffs on mouseover" end
    if store.Get("campSound") then parts[#parts + 1] = "a sound to refresh" end
    return table.concat(parts, ", ")
end

local function AlertSummary(store)
    return ("Under %d min"):format(store.Get("campNearbyMinutes"))
end

local page = Settings.Page("AuraBuffs/Settings", S)

campCard = page:Card({
    id = "campfire", name = "Campfire", order = 20, switch = "campfire",
    help = "Your camp's bonuses and time left on screen, and a reminder when Camp Benefits runs out.",
    summary = CampSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "campStyle", label = "Style", choice = STYLES, needs = Enabled, why = OFF,
          help = "Round shows the camp icon; Simple shows a slim bar listing your camp's bonuses." },
        Group("Icon"),
        { key = "campIconSize", label = "Icon Size", slider = { 24, 110, 1 }, needs = RoundOn, why = ROUND_ONLY },
        { key = "campTimer", label = "Show Camp Timer", toggle = true, needs = Enabled, why = OFF,
          help = "A countdown, and a ring or line that drains green, yellow, then red as the camp runs down." },
        { key = "campShowMissing", label = "Show Refresh Reminder", toggle = true, needs = Enabled, why = OFF,
          help = "The camp icon, greyed out and saying Refresh Camp, while you have no Camp Benefits." },
        { key = "campShowUnder", label = "Show Only When Low", toggle = true, needs = Enabled, why = OFF,
          help = "Keeps the icon hidden while Camp Benefits has more time left than Show Under, and shows "
              .. "it once the camp drops under that. The sitting countdown and the Refresh Camp reminder "
              .. "still show." },
        { key = "campShowUnderMinutes", label = "Show Under", slider = { 1, 59, 1 }, unit = " min",
          needs = Needs("campShowUnder"), why = "Needs Show Only When Low" },
        Group("Simple Bar"),
        { key = "campSimpleWidth", label = "Bar Width", slider = WIDTH_RANGE, needs = SimpleOn, why = SIMPLE_ONLY,
          help = "How wide the bar is; bonuses that do not fit show as +N more." },
        { key = "campSimpleHeight", label = "Bar Height", slider = HEIGHT_RANGE, needs = SimpleOn, why = SIMPLE_ONLY },
        { key = "campSimpleTextSize", label = "Text Size", slider = TEXT_RANGE, needs = SimpleOn, why = SIMPLE_ONLY },
        { key = "campBonusIcons", label = "Bonus Icons", toggle = true, needs = SimpleOn, why = SIMPLE_ONLY,
          help = "A small icon before each bonus on the bar." },
        { key = "campHiddenBonuses", label = "Hidden Bonuses", buttonText = "Show All", button = ShowAllBonuses,
          needs = SimpleOn, why = SIMPLE_ONLY,
          help = "Shows every bonus again; click a bonus on the preview to hide it." },
        Group("Camp Buffs"),
        { key = "campBuffMode", label = "Show Active Camp Buffs", choice = BUFF_MODES, get = ns.CampBuffMode,
          set = PickBuffMode, needs = RoundOn, why = ROUND_ONLY,
          help = "The active effects reported in your Camp Benefits tooltip. On Mouseover shows them while "
              .. "the mouse is over the camp icon." },
        { key = "campBuffTextSize", label = "Buff Text Size", slider = { 8, 28, 1 }, needs = RoundOn, why = ROUND_ONLY },
        { key = "campBuffSide", label = "Buff Text Position", choice = SIDES, needs = RoundOn, why = ROUND_ONLY },
        Group("Sound"),
        { key = "campSound", label = "Play a Sound to Refresh", toggle = true, needs = Enabled, why = OFF,
          help = "Plays when it is time to refresh the camp." },
        { key = "campSoundKey", label = "Sound", sound = true, needs = Needs("campSound"),
          why = "Needs Play a Sound to Refresh" },
    },
})

page:Card({
    id = "campNearby", name = "Camp Nearby", order = 30, switch = "campNearbyAlert",
    help = "With the Round style, a big \"Camp Nearby\" when a campfire is in range and your camp needs refreshing.",
    summary = AlertSummary,
    studio = { height = ALERT_H, states = ALERT_STATES, new = NewAlert, paint = PaintAlert },
    rows = {
        { key = "campNearbyMinutes", label = "Alert Under", slider = { 1, 59, 1 }, unit = " min",
          needs = RoundCampOn, why = "Needs the Campfire reminder, Round style",
          help = "How little Camp Benefits time counts as needing a refresh." },
    },
})
