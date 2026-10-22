-- Bar.lua: the Druid Mana bar on screen: your mana while shapeshifted, the five second rule, the shift cost and your shifts left.
local ns = _G.NaowhForever

local DM = ns.DruidMana
local S = DM.Settings
local St = DM.Style
local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local ItemBar = ns.Shared.ItemBar

local MANA, MANA_TOKEN = Enum.PowerType.Mana, "MANA"
local PLAYER = "player"
local FIVE_SECONDS = 5
local TICK_SECONDS = 2
local HOME_Y = -200
local PERCENT = 100
local FRAME_NAME = "NaowhForeverDruidMana"
local MOVER_LABEL = "Druid Mana"
local CARD = DM.PAGE .. ":bar"
local SPARK_TEX = "Interface\\CastingBar\\UI-CastingBar-Spark"
local CAT_FORM, TRAVEL_FORM, AQUATIC_FORM, BEAR_FORM, DIRE_BEAR_FORM = 1, 3, 4, 5, 8
local FORMS = { [CAT_FORM] = "showCat", [BEAR_FORM] = "showBear", [DIRE_BEAR_FORM] = "showBear",
    [TRAVEL_FORM] = "showTravel", [AQUATIC_FORM] = "showAquatic" }
local BASE_EVENTS = { "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
    "UNIT_DISPLAYPOWER", "UNIT_SPELLCAST_SUCCEEDED" }
local SHOWN_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER" }

local TEXT_VALUES, TEXT_CURRENT, TEXT_PERCENT = "%d / %d", "%d", "%.0f%%"
local TEXT_SHIFTS, TEXT_SHIFT = ns.L("%d shifts left"), ns.L("1 shift left")

local holder, bar, warnClip, warnBar, tick, spark, left, right, line, countdown, info, border, bg
local unlocked, inCombat, inFive, pendingPlace, pendingApply, fiveTimer, cost, curve
local tickX = 0
local events = CreateFrame("Frame")

local Readable = DM.Readable

local function Percent()
    if not curve then
        curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        curve:AddPoint(0, 0)
        curve:AddPoint(1, PERCENT)
    end
    return UnitPowerPercent(PLAYER, MANA, false, curve)
end

local function ManaCost(spellID)
    if not Readable(spellID) then return nil end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if not Readable(costs) or (issecrettable and issecrettable(costs)) or type(costs) ~= "table" then return nil end
    for i = 1, #costs do
        local kind, amount = costs[i].type, costs[i].cost
        if not (Readable(kind) and Readable(amount)) then return nil end
        if kind == MANA and amount > 0 then return amount end
    end
    return nil
end

local function SavePosition(pos)
    S.Set("druidManaPos", pos)
    if ItemBar.Anchored(S, DM.PREFIX) then S.Set("druidManaAnchor", "UIParent") end
end

local function Build()
    holder = ItemBar.Frame(FRAME_NAME, MOVER_LABEL, SavePosition, DM.PAGE, CARD)
    bg = ns.Solid(holder, "BACKGROUND", T.bg)
    bg:SetAllPoints()
    bar = CreateFrame("StatusBar", nil, holder)
    ns.PixelInset(bar, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    warnClip = CreateFrame("Frame", nil, bar)
    warnClip:SetPoint("TOPLEFT")
    warnClip:SetPoint("BOTTOMLEFT")
    warnClip:SetWidth(0)
    warnClip:SetClipsChildren(true)
    warnBar = CreateFrame("StatusBar", nil, warnClip)
    warnBar:SetAllPoints(bar)
    warnBar:SetMinMaxValues(0, 1)
    warnBar:SetValue(0)
    local over = CreateFrame("Frame", nil, bar)
    over:SetAllPoints()
    over:SetFrameLevel(warnBar:GetFrameLevel() + 1)
    tick = over:CreateTexture(nil, "OVERLAY")
    tick:SetColorTexture(St.TICK_RGB.r, St.TICK_RGB.g, St.TICK_RGB.b, 1)
    spark = over:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(SPARK_TEX)
    spark:SetBlendMode("ADD")
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT")
    local pulse = spark:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(St.SPARK_ALPHA)
    fade:SetToAlpha(St.SPARK_LOW)
    fade:SetDuration(TICK_SECONDS / 2)
    spark.pulse = pulse
    left = ns.Font(over, St.TEXT_SIZE, St.OUTLINE)
    left:SetPoint("LEFT", St.TEXT_INSET, 0)
    right = ns.Font(over, St.TEXT_SIZE, St.OUTLINE)
    right:SetPoint("RIGHT", -St.TEXT_INSET, 0)
    border = ns.Border(holder, St.EDGE_RGB)
    countdown = ns.Font(holder, St.TEXT_SIZE, St.OUTLINE)
    countdown:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -(St.LINE_GAP + St.LINE_H + St.INFO_GAP))
    info = ns.Font(holder, St.TEXT_SIZE, St.OUTLINE)
    info:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -(St.LINE_GAP + St.LINE_H + St.INFO_GAP))
    line = Parts.TimerLine(holder, St.LINE_H, countdown)
    line:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -St.LINE_GAP)
    line:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -St.LINE_GAP)
    line:Hide()
    holder:Hide()
end

local function Style()
    local width, height = S.Get("width"), S.Get("height")
    holder:SetSize(width, height)
    local texture = UI.TexturePath(S.Get("texture"), St.FLAT_TEX)
    local mana, warn = S.Get("manaColor"), S.Get("warnColor")
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(mana.r, mana.g, mana.b)
    warnBar:SetStatusBarTexture(texture)
    warnBar:SetStatusBarColor(warn.r, warn.g, warn.b)
    bg:SetColorTexture(T.bg.r, T.bg.g, T.bg.b, S.Get("bgAlpha"))
    local size = S.Get("textSize")
    local small = math.max(1, math.floor(size * St.INFO_SIZE))
    Parts.HudFont(left, S.Get("font"), size, S.Get("outline"))
    Parts.HudFont(right, S.Get("font"), size, S.Get("outline"))
    Parts.HudFont(info, S.Get("font"), small, S.Get("outline"))
    Parts.HudFont(countdown, S.Get("font"), small, S.Get("outline"))
    countdown:SetTextColor(St.COUNTDOWN_RGB.r, St.COUNTDOWN_RGB.g, St.COUNTDOWN_RGB.b)
    tick:SetSize(St.TICK_W, height + St.TICK_REACH * 2)
    spark:SetSize(St.SPARK_W, height * 2)
    line:Paint(mana)
end

local function Place()
    if InCombatLockdown() then
        pendingPlace = true
        return
    end
    pendingPlace = false
    if UI.HasAnchor(holder.mover) then return end
    ItemBar.Put(holder, S, DM.PREFIX, HOME_Y)
end

local function FormWanted()
    return S.Get(FORMS[GetShapeshiftFormID()] or "showCaster") == true
end

local function Wanted()
    if unlocked then return true end
    return DM.On() and FormWanted() and (not S.Get("combatOnly") or inCombat) and true or false
end

local function FormCost()
    local index = GetShapeshiftForm()
    if not Readable(index) or index == 0 then return nil end
    local _, _, _, spellID = GetShapeshiftFormInfo(index)
    return ManaCost(spellID)
end

local function Inner()
    return S.Get("width") - 2
end

local function PlaceTick()
    local max = UnitPowerMax(PLAYER, MANA)
    tickX = 0
    if S.Get("powershift") and S.Get("shiftMark") and cost and Readable(max) and max > 0 then
        tickX = Inner() * math.min(cost / max, 1)
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", bar, "LEFT", tickX, 0)
        tick:Show()
    else
        tick:Hide()
    end
end

local function Text(cur, max)
    local format = S.Get("text")
    if format == "both" or format == "values" then
        left:SetFormattedText(TEXT_VALUES, cur, max)
    elseif format == "current" then
        left:SetFormattedText(TEXT_CURRENT, cur)
    else
        left:SetText("")
    end
    if format == "both" or format == "percent" then
        right:SetFormattedText(TEXT_PERCENT, Percent())
    else
        right:SetText("")
    end
end

local function Values()
    local cur, max = UnitPower(PLAYER, MANA), UnitPowerMax(PLAYER, MANA)
    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)
    warnBar:SetMinMaxValues(0, max)
    warnBar:SetValue(cur)
    Text(cur, max)
    local readable = Readable(cur) and Readable(max)
    local shifting = S.Get("powershift") and cost ~= nil
    local low = readable and shifting and cur < cost
    local edge = St.EDGE_RGB
    if shifting and S.Get("warnLow") then
        if readable then
            warnClip:SetWidth(low and Inner() or 0)
            if low then edge = S.Get("warnColor") end
        else
            warnClip:SetWidth(tickX)
        end
    else
        warnClip:SetWidth(0)
    end
    border:SetColor(edge.r, edge.g, edge.b, 1)
    if shifting and S.Get("shiftsLeft") and readable then
        local n = math.floor(cur / cost)
        if n == 1 then info:SetText(TEXT_SHIFT) else info:SetFormattedText(TEXT_SHIFTS, n) end
    else
        info:SetText("")
    end
    local sparking = S.Get("fiveSecond") and S.Get("regenSpark") and not inFive and not (readable and cur >= max)
    spark:SetShown(sparking and true or false)
    if sparking then spark.pulse:Play() else spark.pulse:Stop() end
end

local function SetEvents(list, on)
    for _, event in ipairs(list) do
        if event:find("^UNIT_") then
            if on then events:RegisterUnitEvent(event, PLAYER) else events:UnregisterEvent(event) end
        elseif on then
            events:RegisterEvent(event)
        else
            events:UnregisterEvent(event)
        end
    end
end

local function Refresh()
    local show = Wanted()
    holder:SetShown(show)
    SetEvents(SHOWN_EVENTS, show)
    if not show then return end
    cost = FormCost()
    PlaceTick()
    line:SetShown(S.Get("fiveSecond") and S.Get("fiveLine") and true or false)
    countdown:SetShown(S.Get("fiveSecond") and S.Get("fiveCountdown") and true or false)
    Values()
end

local function EndFive()
    fiveTimer, inFive = nil, false
    line:Stop()
    if holder:IsShown() then Values() end
end

local function StartFive()
    if fiveTimer then fiveTimer:Cancel() end
    inFive = true
    line:Run(GetTime(), FIVE_SECONDS)
    fiveTimer = C_Timer.NewTimer(FIVE_SECONDS, EndFive)
    if holder:IsShown() then Values() end
end

local function OnSpellcast(spellID)
    if S.Get("fiveSecond") and ManaCost(spellID) then StartFive() end
end

local function Stop()
    events:UnregisterAllEvents()
    if fiveTimer then fiveTimer:Cancel() end
    fiveTimer, inFive = nil, false
    if not holder then return end
    line:Stop()
    holder:Hide()
    holder.mover:Hide()
end

local function Apply()
    if not (DM.On() or unlocked) then return Stop() end
    if not holder then Build() end
    SetEvents(BASE_EVENTS, true)
    inCombat = UnitAffectingCombat(PLAYER) == true
    Style()
    Place()
    holder.mover:SetShown(unlocked == true)
    Refresh()
end

local function OnEvent(_, event, ...)
    if event == "UNIT_POWER_UPDATE" then
        local kind = select(2, ...)
        if Readable(kind) and kind == MANA_TOKEN then Values() end
    elseif event == "UNIT_MAXPOWER" then
        PlaceTick()
        Values()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellcast(select(3, ...))
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if pendingPlace then Place() end
        Refresh()
    else
        Refresh()
    end
end

local function ApplyNow()
    pendingApply = false
    Apply()
end

local function OnSet(key)
    if key == "druidManaPos" or pendingApply then return end
    pendingApply = true
    C_Timer.After(0, ApplyNow)
end

local function OnUnlock()
    unlocked = DM.On()
    Apply()
end

local function OnLock()
    unlocked = false
    Apply()
end

function DM.Frame()
    return holder
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
