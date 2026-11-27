-- RollBars.lua: Roll Bars, Blizzard's Need / Greed / Pass popups restyled: size, bar, text, bigger roll buttons, a BiS glow and star, roll counts, who rolled on hover, the winner, and a place of their own.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local St = ns.Shared.Style
local STATE = Enum.EncounterLootDropRollState

local FRAMES = 4
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BLIZZARD_BAR = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local BLIZZARD_W, BLIZZARD_H = 277, 67
local BLIZZARD_COUNT_X = -5
local BIS = { r = 1, g = 0.5, b = 0 }
local BLACK = { r = 0, g = 0, b = 0 }
local ILVL_AT = { bottomright = { "BOTTOMRIGHT", -1, 1 }, bottomleft = { "BOTTOMLEFT", 1, 1 },
    topleft = { "TOPLEFT", 1, -1 }, center = { "CENTER", 0, 0 } }
local DEFAULT_Y = 250
local GLOW_LIB, GLOW_KEY = "LibCustomGlow-1.0", "NaowhRollBis"
local GLOW_COLOR = { BIS.r, BIS.g, BIS.b, 1 }
local GLOW_LINES, GLOW_SPEED, GLOW_THICKNESS, GLOW_OUT = 10, 0.25, 2, 2
local FLASH_RINGS, FLASH_PEAK, FLASH_FALLOFF, FLASH_LEVEL = 8, 1, 1.5, 7
local FLASH_IN, FLASH_FADE = 0.2, 0.4
local PAD, GAP, BUTTON_GAP, TEXT_INSET, STAR_GAP = 4, 6, 4, 3, 2
local ICON_ZOOM = 0.08
local DISABLED_ALPHA = 0.35
local BOE_RGB = { r = 1, g = 0.82, b = 0 }
local BIND_ON_EQUIP = Enum.ItemBind and Enum.ItemBind.OnEquip or 2
local MS, MINUTE = 1000, 60
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Loot & Items", "QoL/Loot & Items:lootRollBars"
local EVENTS = { "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_CLEAR_HISTORY" }
local BUTTONS = { "NeedButton", "GreedButton", "TransmogButton", "PassButton" }
local ATLAS = { NeedButton = "need", GreedButton = "greed", TransmogButton = "transmog", PassButton = "pass" }
local ROLL_TYPE = { NeedButton = 1, GreedButton = 2, TransmogButton = 4, PassButton = 0 }
local KIND = {
    [STATE.NeedMainSpec] = "NeedButton", [STATE.NeedOffSpec] = "NeedButton", [STATE.Greed] = "GreedButton",
    [STATE.Transmog] = "TransmogButton", [STATE.Pass] = "PassButton",
}
local MOVED = { "IconFrame", "Name", "Timer" }
local TEXT_MOVER = "Roll Bars"
local TEXT_MINUTES = "%d:%02d"
local TEXT_BOE = ns.L("BoE")
local TEXT_OFF_SPEC = ns.L("off spec")
local TEXT_NOBODY = ns.L("Nobody yet")
local TEXT_WAITING = ns.L("%d still choosing")
local TEXT_WON = ns.L("Won by %s")
local TEXT_WON_ROLL = ns.L("Won by %s (%d)")
local TEXT_ALL_PASSED = ns.L("Everyone passed")
local GRACE = 5
local TEXT_EUI_SKIN = ns.L("Roll Bars: EllesmereUI's Blizzard Skin also restyles the roll popups. Turn off its Loot "
    .. "Roll Popups (EllesmereUI > Blizzard Skin) and reload, or the two looks mix.")
local TEXT_EUI_OFF = ns.L("Roll Bars turned off EllesmereUI's skin for the roll popups. Reload to finish.")
local TEXT_EUI_BACK = ns.L("Roll Bars gave the roll popups back to EllesmereUI's skin. Reload to finish.")
local EUI_SKIN, EUI_KEY = "EllesmereUIBlizzardSkin", "reskinLootRoll"
local LABEL = { NeedButton = NEED, GreedButton = GREED, TransmogButton = TRANSMOGRIFICATION, PassButton = PASS }
local SAMPLES = {
    { id = 12640, name = "Lionheart Helm", quality = 4, ilvl = 63, bis = true, canNeed = true, canGreed = true,
      fill = 0.8, waiting = 1,
      who = { NeedButton = { { "Thorne", "WARRIOR" }, { "Maela", "PALADIN", true } },
              GreedButton = { { "Brask", "HUNTER" } } } },
    { id = 13965, name = "Blackhand's Breadth", quality = 3, ilvl = 63, canNeed = true, canGreed = true,
      fill = 0.55,
      who = { GreedButton = { { "Ysolde", "MAGE" }, { "Kerrin", "ROGUE" } }, PassButton = { { "Thorne", "WARRIOR" } } } },
    { id = 15211, name = "Militant Shortsword", quality = 2, ilvl = 31, boe = true, canGreed = true, reasonNeed = 1,
      fill = 0.3, waiting = 2,
      who = { PassButton = { { "Maela", "PALADIN" }, { "Brask", "HUNTER" }, { "Kerrin", "ROGUE" } } } },
}

local RollBars = {}
ns.RollBars = RollBars

local skins, ours, saved, keyOf = {}, {}, {}, {}
local anchor, events, unlocked, testing
local samples = {}
local results, resultPool = {}, {}
local order, seq, warned = {}, 0, false

local function On()
    return S.Get("enabled") and S.Get("lootRollBars")
end

local function Active()
    return On() and not InputUtil.IsGamepadUIEnabled()
end
RollBars.On = On

local function Snapshot(region)
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    return { w = region:GetWidth(), h = region:GetHeight(), points = points }
end

local function Put(region, snap)
    region:ClearAllPoints()
    for _, p in ipairs(snap.points) do region:SetPoint(unpack(p)) end
    region:SetSize(snap.w, snap.h)
end

local function TimeText(timer, value)
    local s = skins[timer:GetParent()]
    if not (s and s.styled) or s.timeAt == "none" then return end
    local sec = math.max(0, math.ceil((value or 0) / MS))
    if sec == s.sec then return end
    s.sec = sec
    s.time:SetText(sec >= MINUTE and TEXT_MINUTES:format(math.floor(sec / MINUTE), sec % MINUTE) or sec)
end

local function ButtonEnter(b)
    local s = skins[b:GetParent():GetParent()]
    if not (s and s.styled and S.Get("lootRollBarsWho")) then return end
    local key, tip, muted = keyOf[b], GameTooltip, T.muted
    if not tip:IsOwned(b) then
        tip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(tip, LABEL[key])
    end
    local who = s.who
    local list = who and who[key]
    if list and #list > 0 then
        for _, e in ipairs(list) do
            local c = e.class and RAID_CLASS_COLORS[e.class] or HIGHLIGHT_FONT_COLOR
            tip:AddDoubleLine(e.name, e.roll or e.offSpec and TEXT_OFF_SPEC or "", c.r, c.g, c.b, muted.r, muted.g, muted.b)
        end
    else
        tip:AddLine(TEXT_NOBODY, muted.r, muted.g, muted.b)
    end
    if who and who.waiting > 0 then tip:AddLine(TEXT_WAITING:format(who.waiting), muted.r, muted.g, muted.b) end
    tip:Show()
end

local function Skin(f)
    local s = skins[f]
    if s then return s end
    s = { counts = {} }
    s.flash = CreateFrame("Frame", nil, f)
    s.flash:SetAllPoints()
    s.flash:Hide()
    for i = 1, FLASH_RINGS do
        local a = FLASH_PEAK * (1 - (i - 1) / FLASH_RINGS) ^ FLASH_FALLOFF
        local sides = { { "TOPLEFT", -i, i, "TOPRIGHT", i, i - 1 }, { "BOTTOMLEFT", -i, -i + 1, "BOTTOMRIGHT", i, -i },
            { "TOPLEFT", -i, i - 1, "BOTTOMLEFT", -i + 1, -i + 1 }, { "TOPRIGHT", i - 1, i - 1, "BOTTOMRIGHT", i, -i + 1 } }
        for _, at in ipairs(sides) do
            local edge = s.flash:CreateTexture(nil, "OVERLAY")
            edge:SetColorTexture(BIS.r, BIS.g, BIS.b, a)
            edge:SetBlendMode("ADD")
            edge:SetPoint(at[1], f, at[1], at[2], at[3])
            edge:SetPoint(at[4], f, at[4], at[5], at[6])
        end
    end
    s.flashAnim = s.flash:CreateAnimationGroup()
    local glowIn = s.flashAnim:CreateAnimation("Alpha")
    glowIn:SetFromAlpha(0)
    glowIn:SetToAlpha(1)
    glowIn:SetDuration(FLASH_IN)
    glowIn:SetOrder(1)
    s.flashOut = s.flashAnim:CreateAnimation("Alpha")
    s.flashOut:SetFromAlpha(1)
    s.flashOut:SetToAlpha(0)
    s.flashOut:SetDuration(FLASH_FADE)
    s.flashOut:SetOrder(2)
    s.flashAnim:SetScript("OnFinished", function() s.flash:Hide() end)
    s.bg = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    s.bg:SetAllPoints()
    s.border = ns.Border(f, BLACK)
    s.barBorder = ns.Border(f.Timer, BLACK)
    ns.PixelInset(s.barBorder._frame, -1, f.Timer)
    s.over = CreateFrame("Frame", nil, f.Timer)
    s.over:SetAllPoints(f.Timer)
    s.iconBorder = ns.Border(f.IconFrame, T.line)
    ns.PixelInset(s.iconBorder._frame, -1, f.IconFrame)
    s.star = s.over:CreateTexture(nil, "OVERLAY")
    s.star:SetTexture(St.STAR)
    s.star:SetVertexColor(BIS.r, BIS.g, BIS.b)
    s.time = s.over:CreateFontString(nil, "OVERLAY")
    s.barName = s.over:CreateFontString(nil, "OVERLAY")
    s.barName:SetJustifyH("LEFT")
    s.barName:SetWordWrap(false)
    s.ilvl = f.IconFrame:CreateFontString(nil, "OVERLAY")
    s.boe = s.over:CreateFontString(nil, "OVERLAY")
    s.boe:SetTextColor(BOE_RGB.r, BOE_RGB.g, BOE_RGB.b)
    for _, key in ipairs(BUTTONS) do
        local b = f.LootButtonContainer[key]
        local count = b:CreateFontString(nil, "OVERLAY")
        count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        s.counts[key] = count
        keyOf[b] = key
        b:HookScript("OnEnter", ButtonEnter)
    end
    f.Timer:HookScript("OnValueChanged", TimeText)
    skins[f] = s
    return s
end

local function Flash(f, s)
    local time = S.Get("lootRollBarsBisGlowTime")
    s.flashAnim:Stop()
    s.flash:SetFrameLevel(f:GetFrameLevel() + FLASH_LEVEL)
    s.flash:Show()
    if time == "always" then return end
    s.flashOut:SetStartDelay(tonumber(time) - FLASH_IN - FLASH_FADE)
    s.flashAnim:Play()
end

local function Glow(f, s, kind, key)
    local LCG = LibStub(GLOW_LIB)
    if kind ~= "pixel" then LCG.PixelGlow_Stop(f, GLOW_KEY) end
    if kind == "pixel" then
        LCG.PixelGlow_Start(f, GLOW_COLOR, GLOW_LINES, GLOW_SPEED, nil, GLOW_THICKNESS, GLOW_OUT, GLOW_OUT, false,
            GLOW_KEY)
    elseif kind and s.flashKey ~= key then
        Flash(f, s)
    end
    local flash = kind and kind ~= "pixel"
    if not flash then
        s.flashAnim:Stop()
        s.flash:Hide()
    end
    s.flashKey = flash and key or nil
end

local function Font(fs, size)
    Parts.HudFont(fs, S.Get("lootRollBarsFont"), size, S.Get("lootRollBarsOutline"))
end

local function SetShown(f, s, on)
    s.bg:SetShown(on)
    s.border._frame:SetShown(on and S.Get("lootRollBarsBorder"))
    s.barBorder._frame:SetShown(on and S.Get("lootRollBarsBarBorder"))
    s.iconBorder._frame:SetShown(on and S.Get("lootRollBarsIconBorder") ~= "none")
    s.time:SetShown(on)
    s.ilvl:SetShown(on)
    s.boe:SetShown(on)
    for _, count in pairs(s.counts) do count:SetShown(on) end
    if not on then
        Glow(f, s, nil)
        s.star:Hide()
        s.barName:Hide()
    end
end

function RollBars.Style(f, w, h)
    local s = Skin(f)
    if ours[f] and not saved[f] then
        local snap = {}
        for _, key in ipairs(MOVED) do snap[key] = Snapshot(f[key]) end
        for _, key in ipairs(BUTTONS) do snap[key] = Snapshot(f.LootButtonContainer[key]) end
        saved[f] = snap
    end
    w, h = w or S.Get("lootRollBarsWidth"), h or S.Get("lootRollBarsHeight")
    local barH = math.min(S.Get("lootRollBarsBarHeight"), h - 2 * PAD)
    local bs = S.Get("lootRollBarsButtonSize")
    local size, small = S.Get("lootRollBarsFontSize"), S.Get("lootRollBarsSmallSize")
    local icon = S.Get("lootRollBarsIconSize")
    f:SetSize(w, h)
    f.Background:Hide()
    f.Border:Hide()
    f.IconFrame.Border:Hide()
    SetShown(f, s, true)

    local iconFrame = f.IconFrame
    iconFrame:ClearAllPoints()
    iconFrame:SetPoint("LEFT", PAD + S.Get("lootRollBarsIconX"), S.Get("lootRollBarsIconY"))
    iconFrame:SetSize(icon, icon)
    iconFrame.Icon:ClearAllPoints()
    iconFrame.Icon:SetAllPoints()
    iconFrame.Icon:SetTexCoord(ICON_ZOOM, 1 - ICON_ZOOM, ICON_ZOOM, 1 - ICON_ZOOM)
    iconFrame.Count:ClearAllPoints()
    iconFrame.Count:SetPoint("TOPRIGHT", -1, -1)
    Font(iconFrame.Count, small)
    local at = ILVL_AT[S.Get("lootRollBarsIlvlPos")] or ILVL_AT.bottomright
    s.ilvl:ClearAllPoints()
    s.ilvl:SetPoint(at[1], at[2] + S.Get("lootRollBarsIlvlX"), at[3] + S.Get("lootRollBarsIlvlY"))
    Font(s.ilvl, small)
    Font(s.boe, small)
    s.boeAt = S.Get("lootRollBarsBoePos")
    local bg = S.Get("lootRollBarsBgColor")
    s.bg:SetColorTexture(bg.r, bg.g, bg.b, S.Get("lootRollBarsBgAlpha"))

    local timer = f.Timer
    local texture = UI.TexturePath(S.Get("lootRollBarsTexture"), FLAT)
    timer:ClearAllPoints()
    timer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + icon + GAP, PAD)
    timer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    timer:SetHeight(barH)
    timer:SetStatusBarTexture(texture)
    timer.Background:SetTexture(texture)

    local mid = -(PAD + (h - 2 * PAD - barH) / 2)
    local c = f.LootButtonContainer
    local prev
    for i = #BUTTONS, 1, -1 do
        local key = BUTTONS[i]
        local b = c[key]
        b:SetSize(bs, bs)
        b:ClearAllPoints()
        if key == "TransmogButton" then
            b:SetPoint("CENTER", c.GreedButton, "CENTER")
        elseif prev then
            b:SetPoint("RIGHT", prev, "LEFT", -BUTTON_GAP, 0)
            prev = b
        else
            b:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, mid)
            prev = b
        end
        Font(s.counts[key], small)
    end

    Font(f.Name, size)
    Font(s.barName, size)
    f.Name:SetWordWrap(false)
    s.star:SetSize(size, size)
    s.nameAt, s.timeAt = S.Get("lootRollBarsNamePos"), S.Get("lootRollBarsTimePos")
    s.nameLeft = PAD + icon + GAP
    s.nameRight = PAD + 3 * bs + 2 * BUTTON_GAP + GAP
    s.mid = mid

    local tx, ty = S.Get("lootRollBarsTimeX"), S.Get("lootRollBarsTimeY")
    s.time:ClearAllPoints()
    if s.timeAt == "left" then
        s.time:SetPoint("LEFT", timer, "LEFT", TEXT_INSET + tx, ty)
    elseif s.timeAt == "center" then
        s.time:SetPoint("CENTER", timer, "CENTER", tx, ty)
    elseif s.timeAt == "icon" then
        s.time:SetPoint("CENTER", iconFrame, "CENTER", tx, ty)
    else
        s.time:SetPoint("RIGHT", timer, "RIGHT", -TEXT_INSET + tx, ty)
    end
    Font(s.time, S.Get("lootRollBarsTimeSize"))
    s.time:SetShown(s.timeAt ~= "none")
    s.sec = nil
    s.styled = true
    return s
end

local function PlaceBoe(f, s)
    local boe, x, y = s.boe, S.Get("lootRollBarsBoeX"), S.Get("lootRollBarsBoeY")
    boe:ClearAllPoints()
    if s.boeAt == "buttons" then
        boe:SetPoint("RIGHT", f.LootButtonContainer.NeedButton, "LEFT", -GAP + x, y)
    else
        local at = ILVL_AT[s.boeAt] or ILVL_AT.bottomleft
        boe:SetPoint(at[1], f.IconFrame, at[1], at[2] + x, at[3] + y)
    end
end

local function PlaceName(f, s, bis, q)
    local onBar = s.nameAt == "bar"
    f.Name:SetAlpha(onBar and 0 or 1)
    s.barName:SetShown(onBar)
    local name, star = f.Name, s.star
    if onBar then
        name = s.barName
        name:SetText(f.Name:GetText())
        name:SetTextColor(q.r, q.g, q.b)
    end
    local x, y = S.Get("lootRollBarsNameX"), S.Get("lootRollBarsNameY")
    local room = s.boeAt == "buttons" and s.boe:GetText() ~= "" and s.boe:GetStringWidth() + GAP or 0
    local left = s.nameLeft + (bis and star:GetWidth() + STAR_GAP or 0) + x
    name:ClearAllPoints()
    name:SetHeight(name:GetLineHeight() + 2)
    if s.nameAt == "top" then
        name:SetJustifyV("TOP")
        name:SetPoint("TOPLEFT", f, "TOPLEFT", left, -PAD + y)
        name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -s.nameRight - room + x, -PAD + y)
    elseif s.nameAt == "bar" then
        local timer = f.Timer
        name:SetJustifyV("MIDDLE")
        name:SetPoint("LEFT", timer, "LEFT", TEXT_INSET + left - s.nameLeft, y)
        name:SetPoint("RIGHT", timer, "RIGHT",
            -TEXT_INSET - (s.timeAt == "right" and s.time:GetStringWidth() + GAP or 0) + x, y)
    else
        name:SetJustifyV("MIDDLE")
        name:SetPoint("LEFT", f, "TOPLEFT", left, s.mid + y)
        name:SetPoint("RIGHT", f, "TOPRIGHT", -s.nameRight - room + x, s.mid + y)
    end
    star:ClearAllPoints()
    star:SetPoint("RIGHT", name, "LEFT", -STAR_GAP, 0)
    star:SetShown(bis)
end

local function SetButton(b, can, reason)
    b:SetEnabled(can)
    b:SetAlpha(can and 1 or DISABLED_ALPHA)
    b:GetNormalTexture():SetDesaturated(not can)
    b.reason = not can and reason and _G["LOOT_ROLL_INELIGIBLE_REASON" .. reason] or nil
end

function RollBars.SetRolls(f, who)
    local s = skins[f]
    if not s then return end
    s.who = who
    local on = S.Get("lootRollBarsCounts")
    for key, fs in pairs(s.counts) do
        local n = on and who and who[key] and #who[key] or 0
        fs:SetText(n > 0 and n or "")
    end
    local owner = GameTooltip:GetOwner()
    local key = owner and keyOf[owner]
    if key and f.LootButtonContainer[key] == owner and owner:IsMouseOver() then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, LABEL[key])
        if not owner:IsEnabled() and owner.reason then
            local red = RED_FONT_COLOR
            GameTooltip:AddLine(owner.reason, red.r, red.g, red.b, true)
        end
        ButtonEnter(owner)
    end
end

function RollBars.Paint(f, d)
    local s = skins[f]
    if d.sample then
        f.IconFrame.Icon:SetTexture(d.icon)
        f.Name:SetText(d.name)
        local c = f.LootButtonContainer
        SetButton(c.NeedButton, d.canNeed, d.reasonNeed)
        SetButton(c.GreedButton, d.canGreed, d.reasonGreed)
        SetButton(c.PassButton, not d.closed)
        c.TransmogButton:Hide()
        c.GreedButton:Show()
        f.IconFrame.Count:SetText(d.count or "")
        f.IconFrame.Count:SetShown((d.count or 0) > 1)
        f.Timer:SetMinMaxValues(0, 1)
        f.Timer:SetValue(d.fill)
        s.time:SetText(math.floor(d.fill * MINUTE))
    end
    local q = ITEM_QUALITY_COLORS[d.quality] or ITEM_QUALITY_COLORS[Enum.ItemQuality.Common]
    local nameRGB = S.Get("lootRollBarsNameColor") == "custom" and S.Get("lootRollBarsNameRGB") or q
    f.Name:SetVertexColor(nameRGB.r, nameRGB.g, nameRGB.b)
    local edge = S.Get("lootRollBarsIconBorder") == "black" and BLACK or q
    s.iconBorder:SetColor(edge.r, edge.g, edge.b, 1)
    local bar = S.Get("lootRollBarsBarColor") == "accent" and T.accent or q
    f.Timer:SetStatusBarColor(bar.r, bar.g, bar.b, 1)
    local back = S.Get("lootRollBarsBarBg") == "custom" and S.Get("lootRollBarsBarBgColor") or bar
    f.Timer.Background:SetVertexColor(back.r, back.g, back.b, S.Get("lootRollBarsBarBgAlpha"))
    local level = f:GetFrameLevel()
    f.Timer:SetFrameLevel(level + 1)
    s.barBorder._frame:SetFrameLevel(level + 2)
    s.over:SetFrameLevel(level + 3)
    s.ilvl:SetText(S.Get("lootRollBarsItemLevel") and d.ilvl or "")
    s.boe:SetText(S.Get("lootRollBarsBoe") and d.boe and TEXT_BOE or "")
    PlaceBoe(f, s)
    local bis = d.bis and S.Get("lootRollBarsBis") and true or false
    Glow(f, s, bis and S.Get("lootRollBarsBisGlow"), f.rollID or d)
    local frame = bis and BIS or S.Get("lootRollBarsBorderColor") == "quality" and q or BLACK
    s.border:SetColor(frame.r, frame.g, frame.b, 1)
    PlaceName(f, s, bis, nameRGB)
    RollBars.SetRolls(f, d.who or s.who)
end

local function Restore(f)
    local s, snap = skins[f], saved[f]
    if not (s and s.styled) then return end
    s.styled = false
    SetShown(f, s, false)
    f:SetSize(BLIZZARD_W, BLIZZARD_H)
    f.Background:Show()
    f.Border:Show()
    f.IconFrame.Border:Show()
    for _, key in ipairs(MOVED) do Put(f[key], snap[key]) end
    for _, key in ipairs(BUTTONS) do Put(f.LootButtonContainer[key], snap[key]) end
    f.IconFrame.Icon:SetTexCoord(0, 1, 0, 1)
    f.IconFrame.Count:SetFontObject(NumberFontNormal)
    f.IconFrame.Count:ClearAllPoints()
    f.IconFrame.Count:SetPoint("BOTTOMRIGHT", BLIZZARD_COUNT_X, 0)
    f.Name:SetFontObject(GameFontNormal)
    f.Name:SetWordWrap(true)
    f.Name:SetJustifyV("MIDDLE")
    f.Name:SetAlpha(1)
    f.Timer:SetStatusBarTexture(BLIZZARD_BAR)
    f.Timer:SetStatusBarColor(1, 1, 0)
    f.Timer.Background:SetColorTexture(0, 0, 0)
    f.Timer.Background:SetVertexColor(1, 1, 1, 1)
    f.Timer:SetFrameLevel(f:GetFrameLevel() - 1)
end

local function LiveData(f)
    local rollID = f.rollID
    local icon, name, count, quality, bop, canNeed, canGreed = GetLootRollItemInfo(rollID)
    if not quality then return nil end
    local link = GetLootRollItemLink(rollID)
    local id = Items.IDFrom(link)
    local ilvl = link and C_Item.IsEquippableItem(link) and C_Item.GetDetailedItemLevelInfo(link) or nil
    local bind = link and select(14, C_Item.GetItemInfo(link))
    return { icon = icon, name = name, quality = quality, count = count, canNeed = canNeed, canGreed = canGreed, ilvl = ilvl,
        boe = not bop and bind == BIND_ON_EQUIP, cached = bind ~= nil, link = link,
        bis = id and ns.IsBisItem and ns.IsBisItem(id) ~= nil }
end

local function Settled(info)
    return info.winner ~= nil or info.allPassed == true
end

local function Plain(v)
    if not issecretvalue(v) then return v end
end

local function Who(info)
    local who, rolls = { waiting = 0 }, info.rollInfos or {}
    for i = 1, #rolls do
        local r = rolls[i]
        local state = Plain(r.state)
        local key = KIND[state]
        if key then
            local list = who[key] or {}
            who[key] = list
            list[#list + 1] = { name = Plain(r.playerName) or "?", class = Plain(r.playerClass),
                offSpec = state == STATE.NeedOffSpec, roll = Plain(r.roll) }
        elseif state == STATE.NoRoll then
            who.waiting = who.waiting + 1
        end
    end
    return who
end

local function ClassName(name, class)
    local c = class and RAID_CLASS_COLORS[class]
    return c and c:WrapTextInColorCode(name) or name
end

local function WonText(info)
    local w = info.winner
    if not w then return TEXT_ALL_PASSED end
    local name, roll = ClassName(Plain(w.playerName) or "?", Plain(w.playerClass)), Plain(w.roll)
    return roll and TEXT_WON_ROLL:format(name, roll) or TEXT_WON:format(name)
end

local function WonLabel(f)
    local s = skins[f]
    if not s.won then s.won = s.over:CreateFontString(nil, "OVERLAY") end
    local label = s.won
    label:ClearAllPoints()
    if S.Get("lootRollBarsWinnerSide") == "left" then
        label:SetPoint("RIGHT", f, "LEFT", -GAP, 0)
    else
        label:SetPoint("LEFT", f, "RIGHT", GAP, 0)
    end
    Font(label, S.Get("lootRollBarsFontSize"))
    return label
end

local Place

local function RemoveResult(r)
    for i, x in ipairs(results) do
        if x == r then
            table.remove(results, i)
            break
        end
    end
    if r.expire then r.expire:Cancel() end
    r.expire = nil
    skins[r].drop, skins[r].who, skins[r].done = nil, nil, nil
    skins[r].won:SetText("")
    r:Hide()
    resultPool[#resultPool + 1] = r
    Place()
end

local function Expire(r, seconds)
    if r.expire then r.expire:Cancel() end
    r.expire = C_Timer.NewTimer(seconds, function()
        r.expire = nil
        RemoveResult(r)
    end)
end

local function Finish(r, text)
    local s = skins[r]
    if s.done then return end
    s.done = true
    WonLabel(r):SetText(text)
    Expire(r, S.Get("lootRollBarsWinnerTime"))
end

local function Closed(f)
    if f:IsShown() then return end
    local s = skins[f]
    local d = s and s.styled and s.data
    if not (d and Active() and S.Get("lootRollBarsWinner")) then return end
    s.data = nil
    local r = table.remove(resultPool) or RollBars.NewSample(anchor)
    RollBars.Style(r)
    local copy = { sample = true, closed = true, fill = 0 }
    for k, v in pairs(d) do copy[k] = v end
    copy.canNeed, copy.canGreed, copy.fill = false, false, 0
    RollBars.Paint(r, copy)
    local rs = skins[r]
    rs.copy = copy
    rs.time:SetText("")
    rs.drop, rs.who, rs.seq = s.drop, s.who, s.seq
    RollBars.SetRolls(r, s.who)
    WonLabel(r):SetText("")
    results[#results + 1] = r
    r:Show()
    if s.won then
        Finish(r, s.won)
    else
        Expire(r, (f.Timer:GetValue() or 0) / MS + GRACE)
    end
    s.won, s.drop = nil, nil
    Place()
end

local function Holder(key)
    for f in pairs(ours) do
        local s = skins[f]
        if s and s.drop == key and f:IsShown() then return f end
    end
    for _, r in ipairs(results) do
        if skins[r].drop == key then return r end
    end
end

local function OnDrop(encounterID, lootKey)
    if issecretvalue(encounterID) or issecretvalue(lootKey) then return end
    local info = C_LootHistory.GetSortedInfoForDrop(encounterID, lootKey)
    local link = info and info.itemHyperlink
    if type(link) ~= "string" or issecretvalue(link) then return end
    local key = encounterID .. ":" .. lootKey
    local settled = Settled(info)
    local target = Holder(key)
    if not target and not settled then
        for i = 1, FRAMES do
            local f = _G["GroupLootFrame" .. i]
            local s = skins[f]
            if s and not s.drop and f:IsShown() and f.rollID and GetLootRollItemLink(f.rollID) == link then
                s.drop, target = key, f
                break
            end
        end
    end
    if not target then return end
    RollBars.SetRolls(target, Who(info))
    if not (settled and S.Get("lootRollBarsWinner")) then return end
    if ours[target] then
        skins[target].won = WonText(info)
    else
        Finish(target, WonText(info))
    end
end

local function FindDrop(f, link)
    for _, enc in ipairs(C_LootHistory.GetAllEncounterInfos() or {}) do
        local encounterID = Plain(enc.encounterID)
        for _, drop in ipairs(encounterID and C_LootHistory.GetSortedDropsForEncounter(encounterID) or {}) do
            local lootKey = Plain(drop.lootListKey)
            local key = lootKey and encounterID .. ":" .. lootKey
            if key and Plain(drop.itemHyperlink) == link and not Settled(drop) and not Holder(key) then
                skins[f].drop = key
                local info = C_LootHistory.GetSortedInfoForDrop(encounterID, lootKey)
                if info then RollBars.SetRolls(f, Who(info)) end
                return
            end
        end
    end
end

local function OnEvent(_, event, encounterID, lootKey)
    if event == "LOOT_HISTORY_CLEAR_HISTORY" then
        for _, s in pairs(skins) do s.drop = nil end
        return
    end
    OnDrop(encounterID, lootKey)
end

local function Step()
    return S.Get("lootRollBarsHeight") + S.Get("lootRollBarsSpacing")
end

local function Stack(f, n)
    f:ClearAllPoints()
    if S.Get("lootRollBarsGrowth") == "down" then
        f:SetPoint("TOP", anchor, "TOP", 0, -(n - 1) * Step())
    else
        f:SetPoint("BOTTOM", anchor, "BOTTOM", 0, (n - 1) * Step())
    end
end

local PlaceAnchor

local function BySeq(a, c)
    return (skins[a].seq or 0) < (skins[c].seq or 0)
end

function Place()
    if not (anchor and Active()) then return end
    PlaceAnchor()
    local container = GroupLootContainer
    wipe(order)
    for i = 1, container.maxIndex do
        local f = container.rollFrames[i]
        if f and ours[f] and skins[f] then order[#order + 1] = f end
    end
    for _, r in ipairs(results) do order[#order + 1] = r end
    if S.Get("lootRollBarsFinished") == "keep" then
        table.sort(order, BySeq)
    end
    local n = #order
    for i, f in ipairs(order) do Stack(f, i) end
    if testing then
        for _, f in ipairs(samples) do
            n = n + 1
            Stack(f, n)
        end
    end
end

function PlaceAnchor()
    local pos = S.Get("lootRollBarsPos")
    anchor:ClearAllPoints()
    if type(pos) == "table" then
        anchor:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    elseif GroupLootContainer:GetBottom() then
        anchor:SetPoint("BOTTOM", GroupLootContainer, "BOTTOM")
    else
        anchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, DEFAULT_Y)
    end
    anchor:SetSize(S.Get("lootRollBarsWidth"), S.Get("lootRollBarsHeight"))
end

local function Created()
    if anchor then return end
    anchor = CreateFrame("Frame", nil, UIParent)
    anchor:SetFrameStrata("DIALOG")
    anchor.mover = UI.AttachMover(anchor, TEXT_MOVER, function(pos) S.Set("lootRollBarsPos", pos) end,
        SETTINGS_PAGE, SETTINGS_CARD)
    for i = 1, FRAMES do
        local f = _G["GroupLootFrame" .. i]
        ours[f] = true
        f:HookScript("OnHide", Closed)
    end
end

local function OnSetup(f)
    if not (ours[f] and Active()) then return end
    local d = LiveData(f)
    if not d then return end
    local s = RollBars.Style(f)
    local fresh = s.rollID ~= f.rollID
    if fresh then
        s.rollID, s.drop, s.who, s.won = f.rollID, nil, nil, nil
        seq = seq + 1
        s.seq = seq
        if not warned and not S.Get("lootRollBarsEuiOff") and C_AddOns.IsAddOnLoaded(EUI_SKIN) then
            warned = true
            ns.Print(TEXT_EUI_SKIN)
        end
    end
    s.data = d
    RollBars.Paint(f, d)
    if fresh and d.link then FindDrop(f, d.link) end
    if fresh and not d.cached and d.link then
        local rollID = f.rollID
        Item:CreateFromItemLink(d.link):ContinueOnItemLoad(function()
            if f.rollID == rollID and f:IsShown() then OnSetup(f) end
        end)
    end
    Place()
end

function RollBars.NewSample(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.Background = f:CreateTexture(nil, "BACKGROUND")
    f.Border = f:CreateTexture(nil, "BORDER")
    f.Name = f:CreateFontString(nil, "ARTWORK")
    f.Name:SetJustifyH("LEFT")
    local iconFrame = CreateFrame("Frame", nil, f)
    iconFrame.Icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.Count = iconFrame:CreateFontString(nil, "OVERLAY")
    iconFrame.Border = iconFrame:CreateTexture(nil, "OVERLAY")
    f.IconFrame = iconFrame
    f.Timer = CreateFrame("StatusBar", nil, f)
    f.Timer.Background = f.Timer:CreateTexture(nil, "BACKGROUND")
    f.Timer.Background:SetAllPoints()
    local c = CreateFrame("Frame", nil, f)
    c:SetAllPoints()
    for _, key in ipairs(BUTTONS) do
        local b = CreateFrame("Button", nil, c)
        local atlas = "lootroll-toast-icon-" .. ATLAS[key]
        b:SetNormalAtlas(atlas .. "-up")
        b:SetPushedAtlas(atlas .. "-down")
        b:SetHighlightAtlas(atlas .. "-highlight", "ADD")
        b:SetMotionScriptsWhileDisabled(true)
        b.rollType = ROLL_TYPE[key]
        b:SetScript("OnLeave", GameTooltip_Hide)
        c[key] = b
    end
    f.LootButtonContainer = c
    return f
end

function RollBars.Samples()
    local list = {}
    for i, sample in ipairs(SAMPLES) do
        local d = { sample = true }
        for k, v in pairs(sample) do d[k] = v end
        local who = { waiting = sample.waiting or 0 }
        for key, rolled in pairs(sample.who) do
            who[key] = {}
            for j, e in ipairs(rolled) do who[key][j] = { name = e[1], class = e[2], offSpec = e[3] } end
        end
        d.who = who
        d.name = C_Item.GetItemNameByID(sample.id) or sample.name
        d.icon = C_Item.GetItemIconByID(sample.id)
        list[i] = d
    end
    return list
end

function RollBars.SampleIDs()
    local ids = {}
    for i, sample in ipairs(SAMPLES) do ids[i] = sample.id end
    return ids
end

local function PaintTest()
    local list = RollBars.Samples()
    for i, d in ipairs(list) do
        local f = samples[i] or RollBars.NewSample(anchor)
        samples[i] = f
        f:SetFrameStrata("DIALOG")
        RollBars.Style(f)
        RollBars.Paint(f, d)
        f:SetShown(testing == true)
    end
    local last = samples[#samples]
    local d = list[#list]
    WonLabel(last):SetText(S.Get("lootRollBarsWinner")
        and TEXT_WON_ROLL:format(ClassName(d.who.PassButton[1].name, d.who.PassButton[1].class), 87) or "")
    Place()
end

function RollBars.Testing()
    return testing == true
end

function RollBars.ToggleTest()
    testing = not testing and Active() or nil
    if testing then
        Items.OnLoaded(RollBars.SampleIDs(), function()
            if testing then PaintTest() end
        end)
    end
    if anchor then PaintTest() end
end

local function SyncEUI()
    local db = _G.EllesmereUIDB
    if not (type(db) == "table" and C_AddOns.IsAddOnLoaded(EUI_SKIN)) then return end
    local was = S.Get("lootRollBarsEuiWas")
    if Active() and S.Get("lootRollBarsEuiOff") then
        if db[EUI_KEY] == false then return end
        local before = db[EUI_KEY]
        db[EUI_KEY] = false
        S.Set("lootRollBarsEuiWas", { value = before })
        ns.ConfirmReload(TEXT_EUI_OFF)
    elseif type(was) == "table" then
        S.Set("lootRollBarsEuiWas", false)
        if db[EUI_KEY] ~= false then return end
        db[EUI_KEY] = was.value
        ns.ConfirmReload(TEXT_EUI_BACK)
    end
end

local function Apply()
    SyncEUI()
    if not Active() then
        if events then events:UnregisterAllEvents() end
        testing = nil
        for _, f in ipairs(samples) do f:Hide() end
        while results[1] do RemoveResult(results[1]) end
        for f in pairs(ours) do Restore(f) end
        if anchor then anchor.mover:Hide() end
        return
    end
    Created()
    PlaceAnchor()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    for f in pairs(ours) do
        if f:IsShown() then OnSetup(f) end
    end
    if testing then PaintTest() end
    for _, r in ipairs(results) do
        RollBars.Style(r)
        RollBars.Paint(r, skins[r].copy)
        skins[r].time:SetText("")
        WonLabel(r)
    end
    Place()
    anchor.mover:SetShown(unlocked == true)
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or (key:find("^lootRollBars") and key ~= "lootRollBarsPos" and key ~= "lootRollBarsEuiWas") then
        Apply()
    end
    if key == "lootRollBarsPos" and anchor then PlaceAnchor() end
end)
ns.OnApply(Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = true
    if Active() then Apply() end
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if anchor then anchor.mover:Hide() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    hooksecurefunc("GroupLootFrame_SetupItemDisplay", OnSetup)
    hooksecurefunc("GroupLootContainer_Update", Place)
    Apply()
end)
