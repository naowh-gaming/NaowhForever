-- SpecStats.lua: the character panel's stats for your spec, and the switch to the game's.
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local CP = ns.CharacterPanel
local C = CP.C
local SW = ns.StatWeights
local Parts = ns.Shared.Parts
local Totals = CP.Totals

local EDGE, PANE_W = CP.EDGE, CP.PANE_W
local STRIPE = ns.Shared.Style.STRIPE
local CONTENT_W = PANE_W - 2 * EDGE
local SWITCH_W = CONTENT_W
local SWITCH_H = 26
local GAP = 6
local ROOM = 20
local ROWS = 16
local SECTION_TOP = 12
local TITLE_SIZE, HEAD_SIZE = C.SECTION_SIZE, C.SMALL_SIZE
local LINE_Y = SECTION_TOP + 16
local HEAD_GAP = 5
local ROWS_TOP = LINE_Y + 20
local ROWS_BOTTOM = 4
local ROW_MAX, ROW_ROOMY, ROW_FLOOR = 30, 24, 12
local ROW_SIZE, ROW_SIZE_TIGHT = 13, C.TEXT_SIZE
local VALUE_W, COLUMN_GAP, NAME_GAP = 44, 10, 6
local BAR_W, BAR_H, BAR_MIN = 50, 4, 2
local NAME_W = CONTENT_W - VALUE_W - COLUMN_GAP - BAR_W - NAME_GAP
local BAR_X = NAME_W + NAME_GAP
local BAND_PAD = 4
local TRACK_ALPHA = 0.08
local BAR_LAYER = 1
local VIEW_LIFT = 10
local BAR_DROP = Parts.CARD_DROP
local YARD = 1
local TITLE_RGB = C.TITLE_RGB
local SPEC_PICK = "spec"
local ORDER = { "agi", "str", "int", "spi", "ap", "rap", "spell", "heal", "fire", "frost", "shadow",
    "nature", "arcane", "holy", "crit", "scrit", "hit", "shit", "haste", "dps", "mp5", "def", "dodge",
    "block", "sta", "armor" }
local ALWAYS = { sta = true, armor = true }
local EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED" }
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE",
    "UNIT_ATTACK_SPEED", "UNIT_RESISTANCES" }
local SHORT = { rap = "Ranged AP", mp5 = "Mana / 5 sec" }
local YARDSTICKS = { "agi", "str", "sta", "spell", "heal", "int", "ap" }
local HEADING = { agi = "VS AGI", str = "VS STR", sta = "VS STA", spell = "VS SPELL", heal = "VS HEAL",
    int = "VS INT", ap = "VS AP" }
local DOES = {
    agi = "Attack power, crit chance, dodge and armor.",
    str = "Attack power, and block with a shield.",
    int = "Mana and spell crit chance.",
    spi = "Mana and health back while not casting.",
    ap = "More damage from your weapons.",
    rap = "More damage from your ranged weapon.",
    spell = "More damage from your spells.",
    heal = "More healing from your spells.",
    crit = "Chance for a hit to deal double damage.",
    scrit = "Chance for a spell to crit.",
    hit = "Chance not to miss: worth the most until you stop missing.",
    shit = "Chance for a spell not to miss: worth the most until you stop missing.",
    haste = "Faster attacks.",
    dps = "Your weapon's damage per second.",
    mp5 = "Mana back every 5 seconds, even while casting.",
    def = "Lowers the chance to be hit, crit and dazed.",
    dodge = "Chance to dodge a melee hit.",
    block = "Chance to block a hit with a shield.",
    sta = "Health.",
    armor = "Less physical damage taken.",
}
local SCHOOL_NAME = { fire = "Fire", frost = "Frost", shadow = "Shadow", nature = "Nature", arcane = "Arcane",
    holy = "Holy" }
local SCHOOL_DOES = "More damage from your %s spells."
local PERCENT = { hit = true, shit = true, crit = true, haste = true, scrit = true, dodge = true, block = true }
local WORTH_LINE = "%s %s is worth %s %s to %s."
local YARDSTICK_LINE = "%s is the yardstick: every other stat is weighed against it."
local UNCOUNTED_LINE = "%s does not count it."
local UNMEASURED_LINE = "%s weighs it %s."
local YOU_LINE = "You: %s"
local TOOLTIP_LINE = "GameTooltipTextLeft"
local BLANK = " "
local ONE_POINT, ONE_PERCENT = "1", "1%"
local PERCENT_TAIL = " %%$"
local PLAIN_FORMAT = "%.3f"
local SPEC_SHORT = "^(.-) %a+$"
local TEXT_YOUR_SPEC = "Your Spec"
local TEXT_BEST_FOR = "BEST FOR "
local TEXT_YOUR_STATS = "YOUR STATS"
local TEXT_WORTH = "WORTH"
local TEXT_YOU = "YOU"
local TEXT_WEIGHTS = "Stat Weights"
local TEXT_WEIGHTS_HINT = "What each stat is worth to your spec: change them as you like."
local LABELS = { { key = "spec", label = "Your Spec" }, { key = "all", label = "All Stats" } }

for school, name in pairs(SCHOOL_NAME) do DOES[school] = SCHOOL_DOES:format(name) end

local NAME = {}
for _, stat in ipairs(SW.STATS) do NAME[stat[1]] = stat[2] end

local switch, view, installed
local keys = {}
local shortNames, titles = {}, {}

local function ShortName(spec)
    if not spec then return TEXT_YOUR_SPEC end
    local short = shortNames[spec.name]
    if not short then
        short = spec.name:match(SPEC_SHORT) or spec.name
        shortNames[spec.name] = short
    end
    return short
end

local function Title(short)
    local title = titles[short]
    if not title then
        title = TEXT_BEST_FOR .. short:upper()
        titles[short] = title
    end
    return title
end

local function Yardstick(weights)
    if not weights then return nil end
    local heaviest
    for _, stat in ipairs(YARDSTICKS) do
        local weight = weights[stat] or 0
        if weight == YARD then return stat end
        if weight > 0 and (not heaviest or weight > weights[heaviest]) then heaviest = stat end
    end
    return heaviest
end

local function Plain(value)
    local text = PLAIN_FORMAT:format(value):gsub("0+$", ""):gsub("%.$", "")
    return text
end

local function SpecShown()
    return CP.On() and S.Get("characterPanelStats") == SPEC_PICK
end

local function WorthLine(row)
    local stat, spec, yard = row.stat, view.specName, view.yard
    if row.weight <= 0 then return UNCOUNTED_LINE:format(spec) end
    if stat == yard then return YARDSTICK_LINE:format(NAME[stat]) end
    if not yard then return UNMEASURED_LINE:format(spec, Plain(row.weight)) end
    local name = NAME[stat] or stat
    local amount = ONE_POINT
    if PERCENT[stat] then
        name = name:gsub(PERCENT_TAIL, "")
        amount = ONE_PERCENT
    end
    return WORTH_LINE:format(amount, name, Plain(row.weight / view.yardWeight), NAME[yard], spec)
end

local function YouLine(row)
    local fg = T.fg
    if row.secret then
        GameTooltip:AddLine(BLANK, fg.r, fg.g, fg.b)
        _G[TOOLTIP_LINE .. GameTooltip:NumLines()]:SetFormattedText(YOU_LINE, row.total:GetText())
    else
        GameTooltip:AddLine(YOU_LINE:format(row.total:GetText() or ""), fg.r, fg.g, fg.b)
    end
end

local function RowEnter(row)
    if not row.stat or not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local a, m = T.accentSoft, T.muted
    GameTooltip:SetText(NAME[row.stat] or row.stat, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    GameTooltip:AddLine(WorthLine(row), a.r, a.g, a.b, true)
    if DOES[row.stat] then GameTooltip:AddLine(DOES[row.stat], m.r, m.g, m.b, true) end
    YouLine(row)
    GameTooltip:Show()
end

local function Lay(count)
    local room = view:GetHeight() - ROWS_TOP - ROWS_BOTTOM
    local height = math.max(ROW_FLOOR, math.min(ROW_MAX, math.floor(room / math.max(1, count))))
    if height == view.rowH then return end
    view.rowH = height
    local size = height >= ROW_ROOMY and ROW_SIZE or ROW_SIZE_TIGHT
    local font = ns.UIFontPath()
    for i, row in ipairs(view.rows) do
        local y = -(ROWS_TOP + (i - 1) * height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", view, "TOPLEFT", EDGE - BAND_PAD, y)
        row:SetPoint("TOPRIGHT", view, "TOPRIGHT", -(EDGE - BAND_PAD), y)
        row:SetHeight(height)
        if size ~= view.size then
            row.name:SetFont(font, size, "")
            row.total:SetFont(font, size, "")
        end
    end
    view.size = size
end

local function Shown(weights)
    wipe(keys)
    local top = 0
    for _, stat in ipairs(ORDER) do
        local weight = weights and weights[stat] or 0
        if ALWAYS[stat] or weight > 0 then
            keys[#keys + 1] = stat
            if weight > top then top = weight end
        end
    end
    return top
end

local function PaintTotal(row, stat, hidden)
    row.secret = hidden and Totals.Secret[stat] ~= nil
    if row.secret then
        Totals.Secret[stat](row.total)
    else
        row.total:SetText(hidden and Totals.HIDDEN or Totals.Plain[stat]())
    end
end

local function PaintRow(row, stat, weights, top, hidden)
    local weight = weights and weights[stat] or 0
    row.stat, row.weight = stat, weight
    row.name:SetText(SHORT[stat] or NAME[stat] or stat)
    PaintTotal(row, stat, hidden)
    row.track:SetShown(weight > 0)
    row.bar:SetShown(weight > 0)
    if weight > 0 then row.bar:SetWidth(math.max(BAR_MIN, math.floor(BAR_W * math.sqrt(weight / top) + 0.5))) end
end

local function Paint()
    local key = SW.ActiveSpec()
    local spec = key and SW.Spec(key)
    local weights = key and SW.For(key)
    local short = ShortName(spec)
    local yard = Yardstick(weights)
    view.title:SetText(spec and Title(short) or TEXT_YOUR_STATS)
    view.head:SetText(HEADING[yard] or TEXT_WORTH)
    view.specName, view.yard = short, yard
    view.yardWeight = yard and weights[yard] or YARD
    local top = Shown(weights)
    Lay(math.min(#keys, ROWS))
    local hidden = C_Secrets.ShouldUnitStatsBeSecret()
    for i, row in ipairs(view.rows) do
        local stat = keys[i]
        row:SetShown(stat ~= nil)
        if stat then PaintRow(row, stat, weights, top, hidden) end
    end
end

local function OnEvent()
    if view:IsVisible() then Paint() end
end

local function Resized()
    if view:IsVisible() then Lay(math.min(#keys, ROWS)) end
end

local function WeightsChanged()
    if view:IsVisible() then Paint() end
end

local function PlaceList(drop, lift)
    local stats = CharacterStatsPaneScrollBox
    stats:ClearAllPoints()
    stats:SetPoint("TOPLEFT", CharacterFrameRightPaneHostStoneBg, "BOTTOMLEFT", 0, -drop)
    stats:SetPoint("BOTTOMRIGHT", CharacterFrame.RightPaneHost, "BOTTOMRIGHT", 0, lift)
end

local function Under(badge)
    local cardBottom = badge:GetBottom()
    local stoneBottom = CharacterFrameRightPaneHostStoneBg:GetBottom()
    if not (cardBottom and stoneBottom) then return CP.BADGE_GAP + CP.BADGE_H - ROOM end
    return stoneBottom - cardBottom + CP.BADGE_GAP
end

local function Layout()
    local badge = CP.badge
    local drop = badge ~= nil and badge:IsShown() and Under(badge) or 0
    PlaceList(math.max(0, drop), SWITCH_H + 2 * GAP)
end

local function Listen(spec)
    view:UnregisterAllEvents()
    if not spec then return end
    for _, event in ipairs(EVENTS) do view:RegisterEvent(event) end
    for _, event in ipairs(UNIT_EVENTS) do view:RegisterUnitEvent(event, "player") end
    Paint()
end

local function Show()
    local stats = CharacterStatsPaneScrollBox
    local on = CP.On() and stats:IsShown()
    switch:SetShown(on)
    if CP.On() then Layout() end
    LABELS[1].label = ShortName(SW.Spec(SW.ActiveSpec() or ""))
    Parts.SetTabs(switch, LABELS)
    Parts.PaintTabs(switch, S.Get("characterPanelStats"))
    local spec = on and SpecShown()
    view:SetShown(spec)
    stats:SetAlpha(spec and 0 or 1)
    Listen(spec)
end

local function Picked(key)
    S.Set("characterPanelStats", key)
end

local function OpenWeights()
    ns.OpenStatWeightsWindow()
end

local function Row(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    if i % 2 == 1 then ns.Solid(row, "BACKGROUND", T.fg, STRIPE):SetAllPoints() end
    row.name = ns.Font(row, ROW_SIZE_TIGHT, nil, T.muted)
    row.name:SetPoint("LEFT", BAND_PAD, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.track = ns.Solid(row, "ARTWORK", T.fg, TRACK_ALPHA)
    row.track:SetPoint("LEFT", BAND_PAD + BAR_X, -BAR_DROP)
    row.track:SetSize(BAR_W, BAR_H)
    row.bar = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.bar:SetDrawLayer("ARTWORK", BAR_LAYER)
    row.bar:SetPoint("LEFT", BAND_PAD + BAR_X, -BAR_DROP)
    row.bar:SetHeight(BAR_H)
    row.total = ns.Font(row, ROW_SIZE_TIGHT, nil, T.fg)
    row.total:SetPoint("RIGHT", -BAND_PAD, 0)
    row.total:SetJustifyH("RIGHT")
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function Heading()
    local weights = Parts.IconButton(view, OpenWeights, ns.Shared.Style.SCALES, nil, TEXT_WEIGHTS)
    weights.hint = TEXT_WEIGHTS_HINT
    weights:SetPoint("RIGHT", view, "TOPRIGHT", -EDGE, -(SECTION_TOP + TITLE_SIZE / 2))
    view.weights = weights
    view.title = ns.Font(view, TITLE_SIZE, nil, T.accentSoft)
    view.title:SetPoint("TOPLEFT", EDGE, -SECTION_TOP)
    local line = ns.Solid(view, "ARTWORK", T.line, 1)
    line:SetPoint("TOPLEFT", EDGE, -LINE_Y)
    line:SetPoint("TOPRIGHT", -EDGE, -LINE_Y)
    ns.Hairline(line, "h")
    view.head = ns.Font(view, HEAD_SIZE, nil, T.muted)
    view.head:SetPoint("TOPLEFT", line, "BOTTOMLEFT", BAR_X, -HEAD_GAP)
    local you = ns.Font(view, HEAD_SIZE, nil, T.muted)
    you:SetPoint("TOPRIGHT", line, "BOTTOMRIGHT", 0, -HEAD_GAP)
    you:SetText(TEXT_YOU)
end

local function Build()
    local panel, stats = CharacterFrame, CharacterStatsPaneScrollBox
    switch = Parts.Tabs(panel, SWITCH_W, LABELS, Picked)
    switch:SetPoint("BOTTOM", CharacterFrame.RightPaneHost, "BOTTOM", 0, GAP)
    switch:SetFrameLevel(stats:GetFrameLevel() + VIEW_LIFT)
    view = CreateFrame("Frame", nil, panel)
    view:SetAllPoints(stats)
    view:SetFrameLevel(stats:GetFrameLevel() + VIEW_LIFT)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnEvent", OnEvent)
    view:SetScript("OnSizeChanged", Resized)
    Heading()
    view.rows = {}
    for i = 1, ROWS do view.rows[i] = Row(view, i) end
    stats:HookScript("OnShow", Show)
    stats:HookScript("OnHide", Show)
    SW.OnChange(WeightsChanged)
end

local function Apply()
    if CP.On() and not installed and CharacterFrame and CharacterStatsPaneScrollBox then
        installed = true
        Build()
    end
    if not installed then return end
    if CP.On() then return Show() end
    switch:Hide()
    view:Hide()
    view:UnregisterAllEvents()
    CharacterStatsPaneScrollBox:SetAlpha(1)
    PlaceList(0, 0)
end

local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") then Apply() end
end

CP.ShowSpecStats = Show

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
