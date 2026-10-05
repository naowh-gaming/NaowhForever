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

local BAR_W, BAR_H, BAR_PAD, BAR_ALPHA, BAR_DIM = 220, 22, 10, 0.92, 0.6
local BAR_TEXT, LABEL_GAP, TIME_W, TIME_GAP = 12, 10, 30, 6
local LINE_H, SHEEN_ALPHA, TEXT_LIFT = 3, 0.06, 1
local TEXT_Y = TEXT_LIFT + math.floor(LINE_H / 2)
local CAMP_SIZE, CAMP_SINK = 32, 4
local HALOS = { { 44, 0.16 }, { 38, 0.26 } }
local UNLOCK_TAGS, UNLOCK_TEXT = { "+Rested", "+Crit" }, "+Rested\n+Crit"

local FEATURES = {
    { id = 1229451, tag = "+Rested", name = "Camp Tent", stat = "Rested experience" },
    { id = 1230587, tag = "+MP5", name = "Mana Well", stat = "Mana every 5 sec", amount = "+%d Mana every 5 sec" },
    { id = 1230172, tag = "+STR", name = "Sharpening Wheel", stat = "Strength", amount = "+%d Strength" },
    { id = 1230653, tag = "+ARM", name = "Enchanted Lute", stat = "Armor, all stats and resistances",
      amount = "+%d Armor, +%d all stats, +%d resistances", points = 3 },
    { id = 1230124, tag = "+STA", name = "First Aid Kit", stat = "Stamina", amount = "+%d Stamina" },
    { id = 1230098, tag = "+Stats", name = "Fish Bowl", stat = "All stats", amount = "+%d%% all stats" },
    { id = 1229513, tag = "+INT", name = "Incense Candle", stat = "Intellect", amount = "+%d Intellect" },
    { id = 1230164, tag = "+ATK", name = "Lodestone", stat = "Melee Attack Power", amount = "+%d Melee Attack Power" },
    { id = 1229519, tag = "+Crit", name = "Camp Chair", stat = "Critical Strike", amount = "+%d%% Critical Strike" },
    { id = 1229718, tag = "+Spirit", name = "Faction Banner", stat = "Spirit", amount = "+%d Spirit" },
}
for i, feature in ipairs(FEATURES) do
    feature.bit = 2 ^ (i - 1)
    feature.points = feature.points or 1
end

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

function Bar.New(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()
    f.host = host
    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetPoint("BOTTOMLEFT")
    f.bar:SetPoint("BOTTOMRIGHT")
    f.bar:SetHeight(BAR_H)
    f.bg = ns.Solid(f.bar, "BACKGROUND", ns.ThemeTint("panel", PLATE), BAR_ALPHA)
    f.bg:SetAllPoints()
    local fg = T.fg
    f.sheen = f.bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.sheen:SetAllPoints()
    f.sheen:SetColorTexture(fg.r, fg.g, fg.b, 1)
    f.sheen:SetGradient("VERTICAL", CreateColor(fg.r, fg.g, fg.b, 0), CreateColor(fg.r, fg.g, fg.b, SHEEN_ALPHA))

    f.time = ns.Font(f.bar, BAR_TEXT, nil, fg)
    f.time:SetJustifyH("RIGHT")
    f.time:SetPoint("RIGHT", f.bar, "RIGHT", -BAR_PAD, TEXT_Y)
    f.line = Parts.TimerLine(f.bar, LINE_H, f.time)
    f.line:SetPoint("BOTTOMLEFT")
    f.line:SetPoint("BOTTOMRIGHT")
    f.edge = ns.Border(f.bar, St.BORDER_RGB)
    f.edge._frame:SetFrameLevel(f.line:GetFrameLevel() + 1)
    f.labels = Parts.LabelRow(f.bar, BAR_TEXT)
    f.labels:SetPoint("LEFT", f.bar, "LEFT", BAR_PAD, TEXT_Y)
    f.note = ns.Font(f.bar, BAR_TEXT, nil, T.accentSoft)
    f.note:SetWordWrap(false)

    f.camp = CreateFrame("Frame", nil, f)
    f.camp:SetSize(CAMP_SIZE, CAMP_SIZE)
    f.camp:SetPoint("BOTTOM", f.bar, "TOP", 0, -CAMP_SINK)
    f.camp:SetFrameLevel(f.edge._frame:GetFrameLevel() + 1)
    CampArt(f.camp)
    f.halos = {}
    for i, halo in ipairs(HALOS) do
        local glow = Parts.Smooth(f:CreateTexture(nil, "BACKGROUND", nil, i), St.ROUND)
        glow:SetBlendMode("ADD")
        glow:SetSize(halo[1], halo[1])
        glow:SetPoint("CENTER", f.camp)
        f.halos[i] = glow
    end
    Bar.Paint(f, T.accent)
    return f
end

local function BarFit(f, tags, n, right)
    local widest = f.labels:SetLabels(tags, n)
    local side = right > 0 and right + TIME_GAP or 0
    local w = math.max(BAR_W, math.ceil(BAR_PAD * 2 + n * (widest + LABEL_GAP) + side))
    f.host:SetSize(w, BAR_H + CAMP_SIZE - CAMP_SINK)
    f.labels:Spread(w - BAR_PAD * 2 - side)
end

local function BarNote(f, text, color, right)
    f.note:SetText(text)
    f.note:SetTextColor(color.r, color.g, color.b)
    f.note:ClearAllPoints()
    if right then
        f.note:SetPoint("RIGHT", f.bar, "RIGHT", -BAR_PAD, TEXT_Y)
    else
        f.note:SetPoint("CENTER", f.bar, "CENTER", 0, TEXT_Y)
    end
    f.note:Show()
end

local function BarLit(f, on)
    f.bg:SetAlpha(on and 1 or BAR_DIM)
    f.camp.tex:SetDesaturated(not on)
    for i = 1, #f.halos do f.halos[i]:SetShown(on) end
end

function Bar.Paint(f, color)
    f.line:Paint(color)
    for i, halo in ipairs(HALOS) do f.halos[i]:SetVertexColor(color.r, color.g, color.b, halo[2]) end
end

function Bar.Timed(f, on)
    on = on and true or false
    if not on then f.line:Stop() end
    f.line:SetShown(on)
    f.time:SetShown(on)
end

function Bar.Up(f, tags, n, timed)
    BarLit(f, true)
    f.labels:SetColor(T.fg)
    if n > 0 then f.note:Hide() else BarNote(f, "Camp Benefits", T.fg, false) end
    BarFit(f, tags, n, timed and TIME_W or 0)
end

function Bar.Sitting(f, timed)
    BarLit(f, true)
    BarNote(f, "Resting", T.accentSoft, false)
    BarFit(f, nil, 0, timed and TIME_W or 0)
end

function Bar.Missing(f, tags, n)
    BarLit(f, false)
    f.labels:SetColor(T.muted)
    BarNote(f, "Refresh Camp", T.accentSoft, n > 0)
    BarFit(f, tags, n, n > 0 and math.ceil(f.note:GetStringWidth()) or 0)
    Bar.Timed(f, false)
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
local bonusTags, bonusFeatures, fallbackTags, joinedTags = {}, {}, {}, {}
local bonusCount, bonusText = 0, ""
local campState, campExpiry
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

local function BonusWords(feature, readable)
    if not (feature.amount and readable) then return feature.stat end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(feature.id)
    local points = aura and aura.points
    if not points or (issecretvalue and issecretvalue(points)) or type(points) ~= "table" then
        return feature.stat
    end
    for i = 1, feature.points do
        local v = points[i]
        if (issecretvalue and issecretvalue(v)) or type(v) ~= "number" then return feature.stat end
    end
    return feature.amount:format(points[1], points[2], points[3])
end

local function ShowTip(owner)
    if unlocked or not Parts.Tip(owner, "ANCHOR_TOP") then return end
    local tip, fg, muted, soft = GameTooltip, T.fg, T.muted, T.accentSoft
    tip:SetText("Camp Benefits", T.accent.r, T.accent.g, T.accent.b)
    local readable = not (InCombatLockdown() or C_Secrets.ShouldAurasBeSecret())
    if campState == "sitting" then
        tip:AddLine("Resting at a campfire", fg.r, fg.g, fg.b)
        if campExpiry then
            tip:AddLine("Camp Benefits in " .. TimeWords(campExpiry - GetTime()), muted.r, muted.g, muted.b)
        end
    elseif campState == "up" then
        for i = 1, bonusCount do
            local feature = bonusFeatures[i]
            if feature then
                tip:AddDoubleLine(BonusWords(feature, readable), feature.name, fg.r, fg.g, fg.b,
                    muted.r, muted.g, muted.b)
            else
                tip:AddLine(bonusTags[i], fg.r, fg.g, fg.b)
            end
        end
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

local function Build()
    icon = CreateFrame("Frame", "NaowhForeverCampfire", UIParent)
    icon:SetMovable(true)
    icon:SetClampedToScreen(true)

    Look.New(icon)

    -- Hovering the icon shows the buff lines while Show Active Camp Buffs is On Mouseover. The
    -- icon only takes the mouse then (Apply), so clicks and camera drags otherwise go through.
    icon:SetScript("OnEnter", PaintBuffs)
    icon:SetScript("OnLeave", PaintBuffs)

    icon.mover = ns.UI.AttachMover(icon, "Campfire", function(pos) S.Set("campPos", pos) end,
        "AuraBuffs/Settings", "AuraBuffs/Settings:campfire")
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
    else
        icon:SetPoint("CENTER", UIParent, "CENTER", -260, 120)
    end
end

local function BarShown()
    return simpleBar ~= nil and simpleBar:IsShown()
end

local function PaintTime(color)
    if BarShown() then
        Bar.Paint(simpleBar, color)
    else
        icon.drain:SetSwipeColor(color.r, color.g, color.b, 1)
    end
end

local function RunTimer(start, duration)
    if BarShown() then
        simpleBar.line:Run(start, duration)
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
    PaintTime(step[2])
    if step[1] > 0 then
        local gen = ringGen
        C_Timer.After(left - step[1] + 0.1, function()
            if gen == ringGen then ColorRing(expiry) end
        end)
    end
end

local function ShowUp(duration, expiry, text, tags, n)
    local timed = S.Get("campTimer") and duration and duration > 0 and true or false
    campState, campExpiry = "up", expiry
    if BarShown() then
        Bar.Up(simpleBar, tags, n, timed)
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

local function ShowSitting(duration, expiry)
    local timed = S.Get("campTimer")
    campState, campExpiry = "sitting", expiry
    if BarShown() then Bar.Sitting(simpleBar, timed) else Look.Sitting(icon) end
    ringGen = ringGen + 1
    if timed and shownExpiry ~= expiry then
        RunTimer(expiry - duration, duration)
        PaintTime(T.accent)
        shownExpiry = expiry
    elseif not timed then
        shownExpiry = nil
    end
    Timed(timed)
    icon:Show()
end

local function ShowMissing()
    campState, campExpiry = "missing", nil
    if BarShown() then Bar.Missing(simpleBar, bonusTags, bonusCount) else Look.Missing(icon) end
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
        if C_UnitAuras.GetPlayerAuraBySpellID(feature.id) then
            n = n + 1
            bonusTags[n], bonusFeatures[n] = feature.tag, feature
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
    else
        bonusText, n = ActiveBuffs(aura, fallbackTags)
        for i = 1, n do bonusTags[i], bonusFeatures[i] = fallbackTags[i], false end
    end
    bonusCount = n
end

local function DisarmAlert()
    alertGen = alertGen + 1
    alertArmed = nil
end

-- UNIT_AURA fires often, so the timer is only set again for a new expiry.
local function UpdateAlert(aura)
    if not (S.Get("campNearbyAlert") and C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY)) then
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
        ShowUp(3600, GetTime() + 2400, UNLOCK_TEXT, UNLOCK_TAGS, #UNLOCK_TAGS)
        SetAlert(S.Get("campNearbyAlert"))
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
        ShowSitting(sitDuration, sitExpiry)
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
            ShowUp(duration, expiry, bonusText, bonusTags, bonusCount)
        end
    else
        ShowMissing()
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
    if not simple then Look.Layout(icon) end
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
    local pos = S.Get("campPos")
    local x, y
    if icon and pos and pos.point ~= "CENTER" then x, y = icon:GetCenter() end
    Apply()
    if not (x and y and icon) then return end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    S.Set("campPos", { point = "CENTER", relPoint = "BOTTOMLEFT", x = x, y = y })
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
local ROUND_ONLY = "Round style only"
local STAGE_H, ALERT_H, NOTE_Y, NOTE_SIZE, STAGE_MARGIN = 230, 90, 10, 11, 16
local CAMP_HOUR, SIT_TIME, BUFF_GAP = 3600, 60, 12
local SAMPLE_BUFFS = "+Rested\n+Crit"
local PREVIEW_TAGS = { "+Rested", "+Crit", "+STA" }
local BAR_HINT = "Hover the bar for each bonus and when to refresh."
local SAMPLES = { up = 2400, low = 240, sitting = 35 }
local STYLES = { { round = "Round", simple = "Simple" }, { "round", "simple" } }
local BUFF_MODES = { { off = "Off", always = "Always", hover = "On Mouseover" }, { "off", "always", "hover" } }
local SIDES = { { below = "Below", above = "Above", left = "Left", right = "Right" },
    { "below", "above", "left", "right" } }
local STATES = {
    { key = "up", label = "Camp Up", tip = "Camp Benefits with most of its hour left." },
    { key = "low", label = "Running Low", tip = "Camp Benefits about to run out." },
    { key = "sitting", label = "Sitting", tip = "Sitting at a campfire, before Camp Benefits lands." },
    { key = "missing", label = "Refresh Camp", tip = "No Camp Benefits, out in the world.",
      needs = "campShowMissing" },
}
local ALERT_STATES = {
    { key = "nearby", label = "Camp Nearby", tip = "A campfire in range while your camp needs refreshing." },
}

local function Enabled() return S.Get("enabled") and true or false end
local function Needs(key) return function() return S.Get("enabled") and S.Get(key) and true or false end end
local function CampOn() return S.Get("enabled") and S.Get("campfire") and true or false end
local function RoundOn() return S.Get("enabled") and not Simple() and true or false end
local function PickBuffMode(v) S.Set("campBuffMode", v) end

local function Hidden(state)
    if state == "up" and S.Get("campShowUnder") and SAMPLES.up > S.Get("campShowUnderMinutes") * 60 then
        return ("Show Only When Low: hidden until under %d min."):format(S.Get("campShowUnderMinutes"))
    end
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.icon = CreateFrame("Frame", nil, shot)
    Look.New(shot.icon)
    shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.note:SetPoint("BOTTOM", 0, NOTE_Y)
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

local function PreviewBar(shot)
    if not shot.bar then
        shot.barHost = CreateFrame("Frame", nil, shot)
        shot.bar = Bar.New(shot.barHost)
    end
    return shot.bar
end

local function FitBar(shot)
    local host = shot.barHost
    local w, h = host:GetWidth(), host:GetHeight()
    local roomW = shot:GetWidth() - STAGE_MARGIN * 2
    local roomH = shot:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    host:SetScale(scale)
    host:ClearAllPoints()
    host:SetPoint("CENTER", shot, "CENTER", 0, NOTE_Y / scale)
end

local function RunBar(f, left, duration, timed)
    if timed then f.line:Run(GetTime() - (duration - left), duration) end
    Bar.Timed(f, timed)
end

local function PaintBarPreview(shot, state, hidden)
    local f = PreviewBar(shot)
    local timed = S.Get("campTimer") and true or false
    if state == "missing" then
        Bar.Missing(f, PREVIEW_TAGS, #PREVIEW_TAGS)
    elseif state == "sitting" then
        Bar.Sitting(f, timed)
        Bar.Paint(f, T.accent)
        RunBar(f, SAMPLES.sitting, SIT_TIME, timed)
    else
        Bar.Up(f, PREVIEW_TAGS, #PREVIEW_TAGS, timed)
        Bar.Paint(f, Look.Step(SAMPLES[state])[2])
        RunBar(f, SAMPLES[state], CAMP_HOUR, timed)
    end
    FitBar(shot)
    shot.barHost:SetShown(not hidden)
    shot.note:SetText(hidden or ((state == "up" or state == "low") and BAR_HINT) or "")
end

local function PaintPreview(shot, state)
    local f = shot.icon
    local hidden = Hidden(state)
    if Simple() then
        f:Hide()
        PaintBarPreview(shot, state, hidden)
        return
    end
    if shot.barHost then shot.barHost:Hide() end
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

page:Card({
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
    help = "\"Camp Nearby\" in the middle of the screen when a campfire is in range and your camp needs "
        .. "refreshing: no Camp Benefits, or less than Alert Under minutes left. Ctrl-click it to dismiss "
        .. "it until you leave that campfire. Part of the Campfire reminder, so it needs that on. Move it "
        .. "in Unlock Mode.",
    summary = AlertSummary,
    studio = { height = ALERT_H, states = ALERT_STATES, new = NewAlert, paint = PaintAlert },
    rows = {
        { key = "campNearbyMinutes", label = "Alert Under", slider = { 1, 59, 1 }, unit = " min",
          needs = CampOn, why = "Needs the Campfire reminder",
          help = "How little Camp Benefits time counts as needing a refresh." },
    },
})
