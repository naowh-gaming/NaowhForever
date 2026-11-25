-- FiltersMenu.lua: the window's Filters icon and its menu of the Journal's switches, ticked while on, and its level range (J.FiltersMenu).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local Parts = J.View.Parts
local GROUPS = J.OPTION_GROUPS
local St = J.Style
local BORDER_RGB, BAR_ICON, FUNNEL, TICK = St.BORDER_RGB, St.BAR_ICON, St.FUNNEL, St.TICK
local TEXT_SIZE, SMALL_SIZE, HEADING_SIZE = St.TEXT_SIZE, St.SMALL_SIZE, St.HEADING_SIZE

local MENU_W, MENU_PAD = 220, 12
local MENU_TITLE_H, MENU_GROUP_GAP = 16, 10
local MENU_ROW_H = 26
local MENU_BOX, MENU_BOX_GAP = 14, 10
local MENU_DIMMED = 0.5
local MENU_BAND = 0.08
local MENU_DROP = 6
local COUNT_GAP = 2
local BUTTON_PAD = 4
local LABEL_COUNT_GAP = 5
local LEVEL_W, LEVEL_H, LEVEL_LETTERS, LEVEL_GAP = 32, 20, 2, 6

local TEXT_ONE_ON = ns.L("Filters: 1 hiding loot or bosses")
local TEXT_MANY_ON = ns.L("Filters: %d hiding loot or bosses")
local TEXT_CLICK = ns.L("Click to choose what is listed and shown.")
local TEXT_FILTERS = "Filters"
local TEXT_LEVEL_DASH = "-"

local window, button, menu

local function Available(option)
    return not option.needsBis or Loot.BisOn()
end

local function Hiding(option)
    if option.to then return S.Get(option.key) > 0 or S.Get(option.to) > 0 end
    return option.hides ~= nil and S.Get(option.key) == option.hides and Available(option)
end

local function Offered(group)
    return not group.newLayout or S.Get("newLayout") == true
end

local function FiltersOn()
    local on = 0
    for _, group in ipairs(GROUPS) do
        for _, option in ipairs(group.options) do
            if Offered(group) and Hiding(option) then on = on + 1 end
        end
    end
    return on
end

local function PaintRow(part, option)
    local on, available = S.Get(option.key), Available(option)
    part.tick:SetShown(on and true or false)
    local edge = on and available and T.accent or BORDER_RGB
    part.edge:SetColor(edge.r, edge.g, edge.b, 1)
    part:SetAlpha(available and 1 or MENU_DIMMED)
    part:SetHeight(MENU_ROW_H)
end

local function LevelText(level)
    return level > 0 and tostring(level) or ""
end

local function PaintLevels(part, option)
    if not part.low:HasFocus() then part.low:SetText(LevelText(S.Get(option.key))) end
    if not part.high:HasFocus() then part.high:SetText(LevelText(S.Get(option.to))) end
    part:SetHeight(MENU_ROW_H)
end

local function PaintMenu()
    local y = MENU_PAD
    for _, part in ipairs(menu.parts) do
        part:ClearAllPoints()
        part:SetPoint("TOPLEFT", MENU_PAD, -y)
        part:SetPoint("RIGHT", -MENU_PAD, 0)
        local option = part.option
        local offered = Offered(part.group)
        part:SetShown(offered)
        if offered and option and option.to then
            PaintLevels(part, option)
            y = y + MENU_ROW_H
        elseif offered and option then
            PaintRow(part, option)
            y = y + MENU_ROW_H
        elseif offered then
            y = y + (part.gap or 0)
            part:SetPoint("TOPLEFT", MENU_PAD, -y)
            y = y + MENU_TITLE_H
        end
    end
    menu:SetHeight(y + MENU_PAD)
end

local function RowClicked(row)
    local option = row.option
    if not Available(option) then return end
    local on = not S.Get(option.key)
    if not on and option.other and not S.Get(option.other) then S.Set(option.other, true) end
    S.Set(option.key, on)
end

local function RowEnter(row)
    row.band:Show()
    local option = row.option
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", MENU_PAD, 0)
    GameTooltip:SetText(option.label, 1, 1, 1)
    GameTooltip:AddLine(option.tooltip, T.muted.r, T.muted.g, T.muted.b, true)
    if not Available(option) then
        GameTooltip:AddLine(J.NEEDS_BIS, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, true)
    end
    GameTooltip:Show()
end

local function RowLeave(row)
    row.band:Hide()
    GameTooltip:Hide()
end

local function TickBox(row)
    local box = CreateFrame("Frame", nil, row)
    box:SetSize(MENU_BOX, MENU_BOX)
    box:SetPoint("LEFT", 0, 0)
    ns.Solid(box, "BACKGROUND", T.bg, 1):SetAllPoints()
    row.edge = ns.Border(box, BORDER_RGB)
    row.tick = box:CreateTexture(nil, "ARTWORK")
    row.tick:SetTexture(TICK)
    ns.PixelInset(row.tick, 1)
    row.tick:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, 1)
end

local function MenuRow(option)
    local row = CreateFrame("Button", nil, menu)
    row.option = option
    row.band = ns.Solid(row, "BACKGROUND", T.accent, MENU_BAND)
    row.band:SetPoint("TOPLEFT", -MENU_PAD / 2, 0)
    row.band:SetPoint("BOTTOMRIGHT", MENU_PAD / 2, 0)
    row.band:Hide()
    TickBox(row)
    row.label = ns.Font(row, HEADING_SIZE, nil, T.fg)
    row.label:SetPoint("LEFT", MENU_BOX + MENU_BOX_GAP, 0)
    row.label:SetPoint("RIGHT")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetText(option.label)
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function LevelTyped(box)
    local level = tonumber(box:GetText()) or 0
    box:SetText(LevelText(level))
    if level ~= S.Get(box.key) then S.Set(box.key, level) end
end

local function LevelUndo(box)
    box:SetText(LevelText(S.Get(box.key)))
    box:ClearFocus()
end

local function LevelBox(row, key)
    local box = ns.NewEditBox(row)
    box:SetSize(LEVEL_W, LEVEL_H)
    box:SetNumeric(true)
    box:SetMaxLetters(LEVEL_LETTERS)
    box:SetJustifyH("CENTER")
    box.key = key
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", LevelUndo)
    box:SetScript("OnEditFocusLost", LevelTyped)
    ns.Tooltip(box, row.option.label, row.option.tooltip)
    return box
end

local function LevelRow(option)
    local row = CreateFrame("Frame", nil, menu)
    row.option = option
    row.label = ns.Font(row, HEADING_SIZE, nil, T.fg)
    row.label:SetPoint("LEFT")
    row.label:SetText(option.label)
    row.high = LevelBox(row, option.to)
    row.high:SetPoint("RIGHT")
    local dash = ns.Font(row, HEADING_SIZE, nil, T.muted)
    dash:SetPoint("RIGHT", row.high, "LEFT", -LEVEL_GAP, 0)
    dash:SetText(TEXT_LEVEL_DASH)
    row.low = LevelBox(row, option.key)
    row.low:SetPoint("RIGHT", dash, "LEFT", -LEVEL_GAP, 0)
    return row
end

local function MenuMouseDown()
    if not (menu:IsMouseOver() or button:IsMouseOver()) then menu:Hide() end
end

local function MenuShown(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
end

local function MenuHidden(self)
    self:UnregisterAllEvents()
end

local function AddGroup(g, group)
    menu.added[g] = true
    local title = ns.Font(menu, SMALL_SIZE, nil, T.muted)
    title:SetText(group.title:upper())
    title:SetJustifyH("LEFT")
    title.gap = g > 1 and MENU_GROUP_GAP or 0
    title.group = group
    menu.parts[#menu.parts + 1] = title
    for _, option in ipairs(group.options) do
        local row = option.to and LevelRow(option) or MenuRow(option)
        row.group = group
        menu.parts[#menu.parts + 1] = row
    end
end

local function BuildMenu()
    menu = CreateFrame("Frame", nil, window)
    menu:SetWidth(MENU_W)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetToplevel(true)
    menu:EnableMouse(true)
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -MENU_DROP)
    ns.Solid(menu, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(menu, BORDER_RGB)
    menu.parts, menu.added = {}, {}
    menu:SetScript("OnShow", MenuShown)
    menu:SetScript("OnHide", MenuHidden)
    menu:SetScript("OnEvent", MenuMouseDown)
    menu:Hide()
end

local function OpenFilters()
    if not menu then BuildMenu() end
    if menu:IsShown() then
        menu:Hide()
        return
    end
    GameTooltip:Hide()
    for g, group in ipairs(GROUPS) do
        if Offered(group) and not menu.added[g] then AddGroup(g, group) end
    end
    menu:Show()
    PaintMenu()
end

local function FiltersEnter(self)
    Parts.LightBarIcon(self, true)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    local on = FiltersOn()
    GameTooltip:SetText(on == 1 and TEXT_ONE_ON or TEXT_MANY_ON:format(on), 1, 1, 1)
    GameTooltip:AddLine(TEXT_CLICK, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local FiltersMenu = {}
J.FiltersMenu = FiltersMenu

function FiltersMenu.Button(parent)
    window = parent
    button = Parts.BarIcon(parent, FUNNEL, true)
    button.count = ns.Font(button, TEXT_SIZE, nil, T.accentSoft)
    button.count:SetPoint("LEFT", button.icon, "RIGHT", COUNT_GAP, 0)
    button:SetScript("OnClick", OpenFilters)
    button:SetScript("OnEnter", FiltersEnter)
    return button
end

function FiltersMenu.Paint()
    local on = FiltersOn()
    local labelled = S.Get("newLayout") == true
    button.count:SetText(on > 0 and on or "")
    local count = on > 0 and math.ceil(button.count:GetStringWidth()) + COUNT_GAP or 0
    Parts.LabelBar(button, labelled and TEXT_FILTERS or nil)
    button.count:ClearAllPoints()
    button.count:SetPoint("LEFT", labelled and button.label or button.icon, "RIGHT", labelled and LABEL_COUNT_GAP or COUNT_GAP, 0)
    if labelled then
        button:SetWidth(button:GetWidth() + count + (on > 0 and LABEL_COUNT_GAP or 0))
    else
        button:SetWidth(BAR_ICON + BUTTON_PAD + count)
    end
end

function FiltersMenu.Repaint()
    if menu and menu:IsShown() then PaintMenu() end
end
