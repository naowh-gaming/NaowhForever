-- RollBarsSettings.lua: the Roll Bars settings card and the preview you edit it on: drag the edges, wheel the parts, click one for its settings.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local St = ns.Shared.Style
local Settings = ns.Shared.Settings
local Group = Settings.Group
local RB = ns.RollBars
local UI = ns.UI

local ROUND = ns.QoLConstants.ROUND
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Loot & Items", "QoL/Loot & Items:lootRollBars"
local STAGE_H, STAGE_MARGIN, TEXT_ROOM = 240, 14, 34
local NOTE_Y, NOTE_SIZE = 8, St.STAGE_NOTE_SIZE
local EDGE_HIT, EDGE_LINE, TOP_LEVEL = 6, 2, 20
local WIDTH_RANGE, HEIGHT_RANGE, SPACING_RANGE = { 200, 600, 5 }, { 28, 80, 1 }, { 0, 20, 1 }
local BAR_RANGE, BUTTON_RANGE = { 2, 30, 1 }, { 16, 56, 1 }
local SIZE_RANGE, SMALL_RANGE, OFFSET_RANGE = St.HUD_TEXT_RANGE, { 6, 20, 1 }, { -60, 60, 1 }
local ILVL_POS = { { bottomright = "Bottom Right", bottomleft = "Bottom Left", topleft = "Top Left", center = "Centre" },
    { "bottomright", "bottomleft", "topleft", "center" } }
local GROWTH = { { up = "Up", down = "Down" }, { "up", "down" } }
local BIS_GLOW = { { flash = "Flash", pixel = "Pixel Lines" }, { "flash", "pixel" } }
local GLOW_TIME = { { ["1"] = "1 Second", ["3"] = "3 Seconds", ["5"] = "5 Seconds", ["10"] = "10 Seconds",
    always = "Always On" }, { "1", "3", "5", "10", "always" } }
local function Flashing() return S.Get("lootRollBarsBis") and S.Get("lootRollBarsBisGlow") ~= "pixel" end
local SIDE = { { right = "Right", left = "Left" }, { "right", "left" } }
local FINISHED = { { ["end"] = "Move to the End", keep = "Keep Its Place" }, { "end", "keep" } }
local ICON_RANGE = { 16, 80, 1 }
local ICON_BORDER = { { quality = "Item Quality", black = "Black", none = "None" }, { "quality", "black", "none" } }
local BORDER_COLOR = { { black = "Black", quality = "Item Quality" }, { "black", "quality" } }
local NAME_COLOR = { { quality = "Item Quality", custom = "Custom" }, { "quality", "custom" } }
local BAR_BG = { { bar = "Bar Color", custom = "Custom" }, { "bar", "custom" } }
local BOE_POS = { { buttons = "Left of the Buttons", bottomleft = "Icon Bottom Left", bottomright = "Icon Bottom Right",
    topleft = "Icon Top Left", center = "Icon Centre" }, { "buttons", "bottomleft", "bottomright", "topleft", "center" } }
local function CustomName() return S.Get("lootRollBarsNameColor") == "custom" end
local function CustomBarBg() return S.Get("lootRollBarsBarBg") == "custom" end
local WINNER_TIME = { 3, 60, 1 }
local BAR_COLOR = { { quality = "Item Quality", accent = "Accent" }, { "quality", "accent" } }
local NAME_POS = { { above = "Beside the Buttons", top = "Top", bar = "On the Bar" }, { "above", "top", "bar" } }
local TIME_POS = { { right = "Bar Right", center = "Bar Centre", left = "Bar Left", icon = "On the Icon", none = "Hidden" },
    { "right", "center", "left", "icon", "none" } }
local STATES = { { key = "rolling", label = "Rolling", tip = "Three drops up for rolls; the top one is on your BiS list." } }
local TEXT_EDIT = ns.L("Edit the Roll Bars")
local TEXT_SHOW, TEXT_HIDE = ns.L("Show"), ns.L("Hide")
local TIP_VALUE = "%s (%d)"
local HINT = ns.L("Drag the right edge for width, the bottom edge for height. Wheel over a part to size it; "
    .. "Shift + wheel for spacing. Click a part for its settings below.")
local TEXT_CLICK = ns.L("Click for settings")
local OFF_HINT = ns.L("Turn on Roll Bars to edit them here.")
local TIPS = {
    { "width", ns.L("Drag the right edge"), ns.L("Width"), "lootRollBarsWidth" },
    { "height", ns.L("Drag the bottom edge"), ns.L("Height"), "lootRollBarsHeight" },
    { "icon", ns.L("Wheel over the icon"), ns.L("Icon Size"), "lootRollBarsIconSize", ICON_RANGE },
    { "buttons", ns.L("Wheel over the buttons"), ns.L("Button Size"), "lootRollBarsButtonSize", BUTTON_RANGE },
    { "bar", ns.L("Wheel over the bar"), ns.L("Bar Height"), "lootRollBarsBarHeight", BAR_RANGE },
    { "name", ns.L("Wheel over the name"), ns.L("Font Size"), "lootRollBarsFontSize", SIZE_RANGE },
    { "spacing", ns.L("Shift + wheel"), ns.L("Spacing"), "lootRollBarsSpacing", SPACING_RANGE },
}
local GO = { width = "Width", height = "Height", icon = "Icon Size", buttons = "Button Size", bar = "Bar Texture",
    name = "Font" }

local PaintPreview

local function Snap(v, range)
    local low, high, step = range[1], range[2], range[3]
    v = low + math.floor((v - low) / step + ROUND) * step
    return math.max(low, math.min(high, v))
end

local function Over(preview)
    for _, f in ipairs(preview.bars) do
        if f:IsMouseOver() then
            local c = f.LootButtonContainer
            for _, b in ipairs({ c.NeedButton, c.GreedButton, c.PassButton }) do
                if b:IsMouseOver() then return "buttons" end
            end
            if f.Timer:IsMouseOver() then return "bar" end
            if f.IconFrame:IsMouseOver() then return "icon" end
            return "name"
        end
    end
end

local function Part(preview)
    if preview.drag then return preview.drag.part end
    if IsShiftKeyDown() then return "spacing" end
    return Over(preview)
end

local function GoTo(part)
    local label = GO[part]
    if label then UI.GoToSetting(SETTINGS_PAGE, label, SETTINGS_CARD) end
end

local function ShowTip(preview)
    local part, fg, a, m = Part(preview), T.fg, T.accent, T.muted
    GameTooltip:SetOwner(preview.box, "ANCHOR_RIGHT")
    GameTooltip:AddLine(TEXT_EDIT, fg.r, fg.g, fg.b)
    for _, tip in ipairs(TIPS) do
        if tip[1] == part or (tip[1] == "spacing" and part ~= "width" and part ~= "height") then
            local c = tip[1] == part and a or m
            GameTooltip:AddDoubleLine(tip[2], TIP_VALUE:format(tip[3], S.Get(tip[4])), c.r, c.g, c.b, c.r, c.g, c.b)
        end
    end
    if GO[part] then GameTooltip:AddDoubleLine(TEXT_CLICK, ns.L(GO[part]), m.r, m.g, m.b, m.r, m.g, m.b) end
    GameTooltip:Show()
end

local function HideTip(preview)
    if GameTooltip:GetOwner() == preview.box then GameTooltip:Hide() end
end

local function Fit(preview)
    local box, area = preview.box, preview.area
    local w, h = box:GetWidth(), box:GetHeight()
    local roomW, roomH = area:GetWidth(), area:GetHeight()
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    box:SetScale(scale)
    box:ClearAllPoints()
    box:SetPoint("CENTER", area, "CENTER")
    return scale
end

local function Stack(preview, w, h)
    local bars, gap = preview.bars, S.Get("lootRollBarsSpacing")
    for i, f in ipairs(bars) do
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", preview.box, "TOPLEFT", 0, -(i - 1) * (h + gap))
    end
    preview.box:SetSize(w, #bars * (h + gap) - gap)
end

local function Resize(preview, w, h)
    local list = RB.Samples()
    for i, f in ipairs(preview.bars) do
        RB.Style(f, w, h)
        RB.Paint(f, list[i])
    end
    Stack(preview, w, h)
end

local function Wheel(preview, delta)
    if not preview.editable or preview.drag then return end
    local part = Part(preview)
    for _, tip in ipairs(TIPS) do
        local range = tip[5]
        if tip[1] == part and range then
            local v = Snap(S.Get(tip[4]) + delta * range[3], range)
            if v ~= S.Get(tip[4]) then S.Set(tip[4], v) end
        end
    end
    ShowTip(preview)
end

local function DragUpdate(hit)
    local preview = hit.preview
    local scale = preview.box:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local w, h = preview.dragW, preview.dragH
    if hit.part == "width" then
        w = Snap(preview.from + x / scale - preview.fromX, WIDTH_RANGE)
    else
        h = Snap(preview.from + (preview.fromY - y / scale) / #preview.bars, HEIGHT_RANGE)
    end
    if w == preview.dragW and h == preview.dragH then return end
    preview.dragW, preview.dragH = w, h
    Resize(preview, w, h)
end

local function DragStart(hit, button)
    local preview = hit.preview
    if button ~= "LeftButton" or not preview.editable then return end
    local scale = preview.box:GetEffectiveScale()
    local x, y = GetCursorPosition()
    preview.fromX, preview.fromY = x / scale, y / scale
    preview.from = S.Get(hit.key)
    preview.dragW, preview.dragH = S.Get("lootRollBarsWidth"), S.Get("lootRollBarsHeight")
    preview.drag = hit
    local box = preview.box
    local s = box:GetScale()
    local left, top = box:GetLeft() - preview:GetLeft() / s, box:GetTop() - preview:GetTop() / s
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", preview, "TOPLEFT", left, top)
    HideTip(preview)
    hit:SetScript("OnUpdate", DragUpdate)
end

local function DragStop(hit)
    local preview = hit.preview
    if preview.drag ~= hit then return end
    hit:SetScript("OnUpdate", nil)
    preview.drag = nil
    if not hit:IsMouseOver() then hit.line:Hide() end
    local w, h = preview.dragW, preview.dragH
    if w == S.Get("lootRollBarsWidth") and h == S.Get("lootRollBarsHeight") then
        if hit:IsMouseOver() then GoTo(hit.part) end
        return
    end
    if w ~= S.Get("lootRollBarsWidth") then S.Set("lootRollBarsWidth", w) end
    if h ~= S.Get("lootRollBarsHeight") then S.Set("lootRollBarsHeight", h) end
    if preview:IsVisible() then PaintPreview(preview) end
end

local function Edge(preview, part, key)
    local hit = CreateFrame("Frame", nil, preview.box)
    hit.preview, hit.part, hit.key = preview, part, key
    hit:EnableMouse(true)
    hit.line = ns.Solid(hit, "OVERLAY", T.accent, 1)
    hit.line:Hide()
    hit:SetScript("OnEnter", function()
        hit.line:Show()
        if not preview.drag then ShowTip(preview) end
    end)
    hit:SetScript("OnLeave", function()
        if preview.drag ~= hit then hit.line:Hide() end
        HideTip(preview)
    end)
    hit:SetScript("OnMouseDown", DragStart)
    hit:SetScript("OnMouseUp", DragStop)
    return hit
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.area = CreateFrame("Frame", nil, preview)
    preview.area:SetPoint("TOPLEFT", STAGE_MARGIN, -STAGE_MARGIN)
    preview.area:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, TEXT_ROOM)
    local box = CreateFrame("Frame", nil, preview)
    box:EnableMouse(true)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta) Wheel(preview, delta) end)
    box:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and preview.editable and not preview.drag then GoTo(Over(preview)) end
    end)
    local function Hovering()
        if not preview.drag and Part(preview) ~= preview.part then
            preview.part = Part(preview)
            ShowTip(preview)
        end
    end
    box:SetScript("OnEnter", function()
        preview.part = nil
        box:SetScript("OnUpdate", Hovering)
    end)
    box:SetScript("OnLeave", function()
        box:SetScript("OnUpdate", nil)
        HideTip(preview)
    end)
    preview.box = box
    preview.bars = {}
    for i = 1, 3 do
        local f = RB.NewSample(box)
        local c = f.LootButtonContainer
        for _, b in ipairs({ c.NeedButton, c.GreedButton, c.PassButton, c.TransmogButton }) do b:EnableMouse(false) end
        preview.bars[i] = f
    end
    preview.width = Edge(preview, "width", "lootRollBarsWidth")
    preview.width:SetPoint("TOP", box, "TOPRIGHT")
    preview.width:SetPoint("BOTTOM", box, "BOTTOMRIGHT")
    preview.width.line:SetPoint("TOP")
    preview.width.line:SetPoint("BOTTOM")
    preview.height = Edge(preview, "height", "lootRollBarsHeight")
    preview.height:SetPoint("LEFT", box, "BOTTOMLEFT")
    preview.height:SetPoint("RIGHT", box, "BOTTOMRIGHT")
    preview.height.line:SetPoint("LEFT")
    preview.height.line:SetPoint("RIGHT")
    preview.hint = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    preview.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    preview:SetScript("OnHide", function()
        if preview.drag then DragStop(preview.drag) end
        HideTip(preview)
    end)
    return preview
end

function PaintPreview(preview)
    local list = RB.Samples()
    for i, f in ipairs(preview.bars) do
        RB.Style(f)
        RB.Paint(f, list[i])
        f:Show()
    end
    Stack(preview, S.Get("lootRollBarsWidth"), S.Get("lootRollBarsHeight"))
    local scale = Fit(preview)
    local editable = RB.On() and true or false
    preview.editable = editable
    preview.box:EnableMouseWheel(editable)
    local edge, line = EDGE_HIT / scale, EDGE_LINE / scale
    for _, hit in ipairs({ preview.width, preview.height }) do
        hit:SetFrameLevel(preview.box:GetFrameLevel() + TOP_LEVEL)
        hit:SetShown(editable)
    end
    preview.width:SetWidth(edge)
    preview.width.line:SetWidth(line)
    preview.height:SetHeight(edge)
    preview.height.line:SetHeight(line)
    preview.hint:SetText(editable and HINT or OFF_HINT)
    if not preview.loading then
        preview.loading = true
        ns.Shared.Items.OnLoaded(RB.SampleIDs(), function()
            if preview:IsVisible() then PaintPreview(preview) end
        end)
    end
end

local function TestText()
    return RB.Testing() and TEXT_HIDE or TEXT_SHOW
end

Settings.Page("QoL/Loot & Items", S):Card({
    id = "lootRollBars", name = "Roll Bars", order = 7, switch = "lootRollBars",
    help = "Restyles the game's Need, Greed and Pass popups, with roll counts, who rolled and a BiS glow.",
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Layout"),
        { key = "lootRollBarsEuiOff", label = "Turn Off EllesmereUI's Popup Skin", toggle = true,
          needs = function() return C_AddOns.IsAddOnLoaded("EllesmereUIBlizzardSkin") end,
          why = "Only for EllesmereUI's Blizzard Skin",
          help = "Turns off EllesmereUI's Loot Roll Popups skin while Roll Bars is on; needs a reload." },
        { key = "lootRollBarsWidth", label = "Width", slider = WIDTH_RANGE },
        { key = "lootRollBarsHeight", label = "Height", slider = HEIGHT_RANGE },
        { key = "lootRollBarsSpacing", label = "Spacing", slider = SPACING_RANGE },
        { key = "lootRollBarsGrowth", label = "Growth Direction", choice = GROWTH,
          help = "Which way more rolls stack from the first." },
        { key = "lootRollBarsButtonSize", label = "Button Size", slider = BUTTON_RANGE,
          help = "The Need, Greed and Pass buttons." },
        Settings.Look("lootRollBars", { text = true, size = SIZE_RANGE, bar = "Flat" }),
        { key = "lootRollBarsBarHeight", label = "Bar Height", slider = BAR_RANGE },
        { key = "lootRollBarsBarColor", label = "Bar Color", choice = BAR_COLOR },
        { key = "lootRollBarsBarBorder", label = "Bar Border", toggle = true, help = "A thin black edge round the bar." },
        { key = "lootRollBarsBarBg", label = "Bar Background", choice = BAR_BG,
          help = "Behind the part of the bar that has run out: a dim copy of the bar's color, or your own." },
        { key = "lootRollBarsBarBgColor", label = "Bar Background Color", colour = true, needs = CustomBarBg,
          why = "Bar Background is Bar Color" },
        { key = "lootRollBarsBarBgAlpha", label = "Bar Background Opacity", slider = St.ALPHA_RANGE, unit = "%",
          scale = St.PERCENT_SCALE },
        Group("Icon"),
        { key = "lootRollBarsIconSize", label = "Icon Size", slider = ICON_RANGE,
          help = "The item's icon, on the left; the bar starts after it." },
        { key = "lootRollBarsIconBorder", label = "Icon Border", choice = ICON_BORDER },
        { key = "lootRollBarsIconX", label = "Icon X", slider = OFFSET_RANGE, help = "Moves the icon right or left." },
        { key = "lootRollBarsIconY", label = "Icon Y", slider = OFFSET_RANGE, help = "Moves the icon up or down." },
        Group("Background"),
        { key = "lootRollBarsBgColor", label = "Background Color", colour = true },
        { key = "lootRollBarsBgAlpha", label = "Background Opacity", slider = St.ALPHA_RANGE, unit = "%",
          scale = St.PERCENT_SCALE, help = "0% leaves only the icon, text, buttons and bar." },
        { key = "lootRollBarsBorder", label = "Border", toggle = true, help = "A thin edge round each roll." },
        { key = "lootRollBarsBorderColor", label = "Border Color", choice = BORDER_COLOR, needs = "lootRollBarsBorder",
          help = "Black or the item's quality color; BiS items stay orange." },
        Group("Item Name"),
        { key = "lootRollBarsNameX", label = "Item Name X", slider = OFFSET_RANGE },
        { key = "lootRollBarsNameY", label = "Item Name Y", slider = OFFSET_RANGE },
        { key = "lootRollBarsNamePos", label = "Item Name Place", choice = NAME_POS },
        { key = "lootRollBarsNameColor", label = "Item Name Color", choice = NAME_COLOR },
        { key = "lootRollBarsNameRGB", label = "Item Name Custom Color", colour = true, needs = CustomName,
          why = "Item Name Color is Item Quality" },
        Group("Time Left"),
        { key = "lootRollBarsTimePos", label = "Time Left Place", choice = TIME_POS },
        { key = "lootRollBarsTimeSize", label = "Time Left Size", slider = SIZE_RANGE },
        { key = "lootRollBarsTimeX", label = "Time Left X", slider = OFFSET_RANGE },
        { key = "lootRollBarsTimeY", label = "Time Left Y", slider = OFFSET_RANGE },
        Group("Item Level"),
        { key = "lootRollBarsItemLevel", label = "Item Level", toggle = true },
        { key = "lootRollBarsIlvlPos", label = "Item Level Place", choice = ILVL_POS },
        { key = "lootRollBarsIlvlX", label = "Item Level X", slider = OFFSET_RANGE },
        { key = "lootRollBarsIlvlY", label = "Item Level Y", slider = OFFSET_RANGE },
        Group("BoE"),
        { key = "lootRollBarsBoe", label = "Show BoE", toggle = true,
          help = "\"BoE\" on items that bind when equipped, so you know they can be traded or sold." },
        { key = "lootRollBarsBoePos", label = "BoE Place", choice = BOE_POS },
        { key = "lootRollBarsBoeX", label = "BoE X", slider = OFFSET_RANGE },
        { key = "lootRollBarsBoeY", label = "BoE Y", slider = OFFSET_RANGE },
        Group("Small Text"),
        { key = "lootRollBarsSmallSize", label = "Small Text Size", slider = SMALL_RANGE,
          help = "The stack count and item level on the icon, and the roll counts on the buttons." },
        Group("Show"),
        { key = "lootRollBarsBis", label = "BiS Glow and Star", toggle = true,
          help = "An item on your BiS list glows orange with a star by its name. Needs the BiS List module." },
        { key = "lootRollBarsBisGlow", label = "BiS Glow Style", choice = BIS_GLOW, needs = "lootRollBarsBis",
          help = "Flash glows round the roll when it appears; Pixel Lines stay while it is open." },
        { key = "lootRollBarsBisGlowTime", label = "Flash Time", choice = GLOW_TIME, needs = Flashing,
          help = "How long the orange glow stays round a BiS roll once it appears." },
        { key = "lootRollBarsCounts", label = "Roll Counts", toggle = true,
          help = "How many in the group have picked Need, Greed or Pass, on each button." },
        { key = "lootRollBarsWho", label = "Who Rolled on Hover", toggle = true,
          help = "Point at Need, Greed or Pass to see who picked it and their roll." },
        Group("Winner"),
        { key = "lootRollBarsWinner", label = "Show Winner", toggle = true,
          help = "Keeps a roll on screen after it ends and shows who won it." },
        { key = "lootRollBarsWinnerSide", label = "Winner Side", choice = SIDE,
          help = "Which side of the roll the winner's name sits." },
        { key = "lootRollBarsWinnerTime", label = "Winner Time", slider = WINNER_TIME, unit = "s",
          help = "How long a finished roll stays once it has a winner." },
        { key = "lootRollBarsFinished", label = "Finished Roll Place", choice = FINISHED,
          help = "Where a roll goes once you pick: the end of the list or its own place." },
        { label = "Test Rolls", button = function() RB.ToggleTest() end, buttonText = TestText,
          help = "Three sample rolls on screen where your real ones will appear." },
    },
})
