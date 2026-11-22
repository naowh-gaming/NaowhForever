-- LootFeedSettings.lua: the Loot Feed's settings card and the live preview it edits.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Parts = ns.Shared.Parts
local T = ns.THEME
local LF = ns.LootFeed
local Look, On, CountSize = LF.Look, LF.On, LF.CountSize

local COIN_ICON, PANTS_ICON = LF.COIN_ICON, LF.PANTS_ICON
local CLOTH_ICON = "Interface\\Icons\\INV_Fabric_Linen_01"
local SAMPLE_COINS, SAMPLE_PANTS, SAMPLE_PANTS_BAGS = LF.SAMPLE_COINS, LF.SAMPLE_PANTS, LF.SAMPLE_PANTS_BAGS
local SAMPLE_CLOTH, SAMPLE_PER_HOUR = 39, 412550
local SAMPLE_CLOTH_BAGS, SAMPLE_CLOTH_BANK = 7, 27
local SAMPLE_PANTS_NAME = LF.SAMPLE_PANTS_NAME
local SAMPLE_CLOTH_NAME = ns.L("|cffffffffLinen Cloth|r |cff20ff20x3|r")
local GPH_SIZE, GPH_RGB, GPH_GAP = LF.GPH_SIZE, LF.GPH_RGB, LF.GPH_GAP
local VALUE_INSET, COIN_GAP, PAIR_GAP = LF.VALUE_INSET, LF.COIN_GAP, LF.PAIR_GAP
local ROUND = ns.QoLConstants.ROUND
local DISPLAY_TIME_RANGE = { 0.5, 10, 0.5 }

local TEXT_COINS = LF.TEXT_COINS
local TEXT_FADES = ns.L("Each line fades out after %ss.")
local TEXT_SUMMARY = ns.L("%d lines, %s%s")
local TEXT_NO_BACKGROUND, TEXT_LIGHT, TEXT_DARK = ns.L("no background"), ns.L("light"), ns.L("dark")
local TEXT_GPH = ns.L(", gold per hour")
local TEXT_EDIT = ns.L("Edit the Feed")
local TEXT_LINES_SHOW = ns.L("Lines Show")
local TEXT_GLOW = ns.L("Glow")
local TEXT_QUALITY_BORDER = ns.L("Quality Border")

local Group = ns.Shared.Settings.Group
local QUALITY = { { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }, { 0, 1, 2, 3, 4 } }
local STYLE = { { dark = "Dark", light = "Light", none = "None" }, { "dark", "light", "none" } }
local PRICE = { { vendor = "Vendor Price", ahscan = "Auction (Naowh Scan)", tsm = "Auction (TSM)" },
    { "vendor", "ahscan", "tsm" } }
local GROWTH = { { up = "Up", down = "Down" }, { "up", "down" } }

local FADING = { 1, 0.6, 0.25 }
local ITEM_ROWS = 2
local STAGE_H, STAGE_MARGIN, TEXT_ROOM = 220, 14, 58
local NOTE_Y, NOTE_SIZE, NOTE_GAP = 8, ns.Shared.Style.STAGE_NOTE_SIZE, 4
local EDIT_LEVEL, TOP_LEVEL = 10, 12
local EDGE_HIT, EDGE_LINE = 6, 2
local VALUE_PAD, VALUE_ROOM = 6, 48
local HOVER_ALPHA = 0.12
local WIDTH_RANGE, HEIGHT_RANGE, SPACING_RANGE = { 200, 600, 5 }, { 20, 64, 1 }, { -1, 20, 1 }
local SIZE_RANGE, COUNT_RANGE = ns.Shared.Style.HUD_TEXT_RANGE, { 3, 12, 1 }
local HINT = ns.L("Drag the right edge for width, a line's bottom for height. Wheel: text size (Shift: spacing, "
    .. "Ctrl: lines). Right-click a line for what it shows.")
local OFF_HINT = ns.L("Turn on the Loot Feed to edit it here.")
local QOL_OFF_HINT = ns.L("Turn on QoL to edit the Loot Feed here.")
local TIP_VALUE = "%s (%d)"
local STATES = {
    { key = "looting", label = "Looting", tip = "Lines as they come in, newest at the anchor." },
    { key = "fading", label = "Fading", tip = "Older lines fading out after the display time." },
}
local TIPS = {
    { "width", ns.L("Drag the right edge"), ns.L("Width"), "lootFeedWidth" },
    { "height", ns.L("Drag a line's bottom edge"), ns.L("Line Height"), "lootFeedHeight" },
    { "lines", ns.L("Wheel"), ns.L("Font Size"), "lootFeedFontSize" },
    { "lines", ns.L("Shift + wheel"), ns.L("Spacing"), "lootFeedSpacing" },
    { "lines", ns.L("Ctrl + wheel"), ns.L("Lines Shown"), "lootFeedCount" },
    { "value", ns.L("Click the value"), ns.L("Show Item Value") },
    { "bags", ns.L("Click the bag count"), ns.L("Count Bank Items") },
    { "lines", ns.L("Right-click a line"), ns.L("What Lines Show") },
}
local LINE_TOGGLES = {
    { "lootFeedMoney", ns.L("Show Money") },
    { "lootFeedQuest", ns.L("Show Quest Rewards") },
    { "lootFeedRep", ns.L("Show Reputation") },
    { "lootFeedXP", ns.L("Show Kill Experience") },
}

local function Choices(title, key, choice)
    local list = { title = title }
    for i, value in ipairs(choice[2]) do list[i] = { key = key, value = value, label = choice[1][value] } end
    return list
end

local RADIOS = { Choices("Style", "lootFeedStyle", STYLE), Choices("Outline", "lootFeedOutline", Parts.HUD_OUTLINES),
    Choices("Growth Direction", "lootFeedGrowth", GROWTH) }

local function Snap(v, range)
    local low, high, step = range[1], range[2], range[3]
    v = low + math.floor((v - low) / step + ROUND) * step
    return math.max(low, math.min(high, v))
end

local function HideTip(preview)
    if GameTooltip:GetOwner() == preview.feed then GameTooltip:Hide() end
end

local function ShowTip(preview)
    local part, fg = preview.part, T.fg
    GameTooltip:SetOwner(preview.feed, "ANCHOR_RIGHT")
    GameTooltip:AddLine(TEXT_EDIT, fg.r, fg.g, fg.b)
    for i = 1, #TIPS do
        local tip = TIPS[i]
        local c = tip[1] == part and T.accent or T.muted
        local right = tip[4] and TIP_VALUE:format(tip[3], S.Get(tip[4])) or tip[3]
        GameTooltip:AddDoubleLine(tip[2], right, c.r, c.g, c.b, c.r, c.g, c.b)
    end
    GameTooltip:Show()
end

local function Unhover(preview)
    preview.part = nil
    local hits = preview.hits
    for i = 1, #hits do
        local hit = hits[i]
        if hit.wash then hit.wash:Hide() end
        if hit.line then hit.line:Hide() end
    end
    HideTip(preview)
end

local function PartEnter(hit)
    local preview = hit.preview
    if preview.drag then return end
    preview.part = hit.part
    if hit.wash then hit.wash:Show() end
    if hit.line then hit.line:Show() end
    preview.widthHit.line:Show()
    ShowTip(preview)
end

local function PartLeave(hit)
    local preview = hit.preview
    if hit.wash then hit.wash:Hide() end
    if preview.drag then return end
    if hit.line and hit ~= preview.widthHit then hit.line:Hide() end
    if not preview.feed:IsMouseOver() then Unhover(preview) end
end

local function Restack(preview, w, h)
    local shown, box = preview.list, preview.feed
    Look.Stack(shown, box, h)
    box:SetSize(w, #shown * h + (#shown - 1) * Look.Gap(box))
end

local function Resize(preview, w, h)
    local shown = preview.list
    for i = 1, #shown do Look.Size(shown[i], w, h) end
    Restack(preview, w, h)
end

local function Fit(preview)
    local box, area, rate = preview.feed, preview.area, preview.gph
    local extra = rate:IsShown() and GPH_GAP + rate:GetStringWidth() or 0
    local w, h = box:GetWidth() + extra, box:GetHeight()
    local roomW, roomH = area:GetWidth(), area:GetHeight()
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    preview.fitX = -extra / 2
    box:SetScale(scale)
    box:ClearAllPoints()
    box:SetPoint("CENTER", area, "CENTER", preview.fitX, 0)
    return scale
end

local function EndDrag(preview)
    local hit = preview.drag
    if not hit then return nil end
    hit:SetScript("OnUpdate", nil)
    preview.drag = nil
    return hit
end

local function DragUpdate(hit)
    local preview = hit.preview
    local scale = preview.feed:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local w, h = preview.dragW, preview.dragH
    if hit.part == "width" then
        w = Snap(preview.fromW + x / scale - preview.fromX, WIDTH_RANGE)
    else
        h = Snap(preview.fromH + (preview.fromY - y / scale) / (hit.above + 1), HEIGHT_RANGE)
    end
    if w == preview.dragW and h == preview.dragH then return end
    preview.dragW, preview.dragH = w, h
    Resize(preview, w, h)
end

local function DragStart(hit)
    local preview = hit.preview
    if preview.drag or not preview.editable then return end
    local box = preview.feed
    local scale = box:GetEffectiveScale()
    local x, y = GetCursorPosition()
    preview.fromX, preview.fromY = x / scale, y / scale
    preview.fromW, preview.fromH = S.Get("lootFeedWidth"), S.Get("lootFeedHeight")
    preview.dragW, preview.dragH = preview.fromW, preview.fromH
    preview.drag = hit
    local w, h = box:GetWidth(), box:GetHeight()
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", preview.area, "CENTER", preview.fitX - w / 2, h / 2)
    HideTip(preview)
    hit:SetScript("OnUpdate", DragUpdate)
end

local function DragStop(hit)
    local preview = hit.preview
    EndDrag(preview)
    Fit(preview)
    local w, h = preview.dragW, preview.dragH
    if w ~= S.Get("lootFeedWidth") then S.Set("lootFeedWidth", w) end
    if h ~= S.Get("lootFeedHeight") then S.Set("lootFeedHeight", h) end
    if hit:IsMouseOver() then
        preview.part = hit.part
        ShowTip(preview)
        return
    end
    if hit ~= preview.widthHit then hit.line:Hide() end
    if not preview.feed:IsMouseOver() then Unhover(preview) end
end

local function Toggled(key)
    return S.Get(key) == true
end

local function Toggle(key)
    S.Set(key, not S.Get(key))
end

local function Picked(choice)
    return S.Get(choice.key) == choice.value
end

local function Pick(choice)
    S.Set(choice.key, choice.value)
end

local function LineMenu(_, root)
    root:CreateTitle(TEXT_LINES_SHOW)
    for i = 1, #LINE_TOGGLES do
        local t = LINE_TOGGLES[i]
        root:CreateCheckbox(t[2], Toggled, Toggle, t[1])
    end
    root:CreateDivider()
    root:CreateCheckbox(TEXT_GLOW, Toggled, Toggle, "lootFeedGlow")
    root:CreateCheckbox(TEXT_QUALITY_BORDER, Toggled, Toggle, "lootFeedQualityBorder")
    for i = 1, #RADIOS do
        local radio = RADIOS[i]
        root:CreateDivider()
        root:CreateTitle(radio.title)
        for j = 1, #radio do root:CreateRadio(radio[j].label, Picked, Pick, radio[j]) end
    end
end

local function Wheel(hit, delta)
    local preview = hit.preview
    if not preview.editable or preview.drag then return end
    local key, range = "lootFeedFontSize", SIZE_RANGE
    if IsControlKeyDown() then
        key, range = "lootFeedCount", COUNT_RANGE
    elseif IsShiftKeyDown() then
        key, range = "lootFeedSpacing", SPACING_RANGE
    end
    local v = Snap(S.Get(key) + delta * range[3], range)
    if v ~= S.Get(key) then S.Set(key, v) end
end

local function HitDown(hit, button)
    if button == "LeftButton" and hit.drag then DragStart(hit) end
end

local function HitUp(hit, button)
    local preview = hit.preview
    if preview.drag == hit then
        if button == "LeftButton" then DragStop(hit) end
        return
    end
    if not preview.editable or preview.drag then return end
    if button == "RightButton" then
        HideTip(preview)
        ns.ContextMenu(hit, LineMenu)
    elseif button == "LeftButton" and hit.toggle and hit:IsMouseOver() then
        Toggle(hit.toggle)
    end
end

local function Hit(frame, preview, part)
    frame.preview, frame.part = preview, part
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnEnter", PartEnter)
    frame:SetScript("OnLeave", PartLeave)
    frame:SetScript("OnMouseDown", HitDown)
    frame:SetScript("OnMouseUp", HitUp)
    frame:SetScript("OnMouseWheel", Wheel)
end

local function NewHit(preview, part, toggle)
    local hit = CreateFrame("Frame", nil, preview.edit)
    Hit(hit, preview, part)
    hit.toggle = toggle
    if toggle then
        hit.wash = ns.Solid(hit, "OVERLAY", T.accent, HOVER_ALPHA)
        hit.wash:SetAllPoints()
        hit.wash:Hide()
    end
    preview.hits[#preview.hits + 1] = hit
    return hit
end

local function NewEdge(preview, part, from, to)
    local hit = NewHit(preview, part)
    hit.drag, hit.above = true, 0
    hit.line = ns.Solid(hit, "OVERLAY", T.accent, 1)
    hit.line:SetPoint(from)
    hit.line:SetPoint(to)
    hit.line:Hide()
    return hit
end

local function PreviewHidden(preview)
    if EndDrag(preview) then
        Resize(preview, S.Get("lootFeedWidth"), S.Get("lootFeedHeight"))
        Fit(preview)
    end
    Unhover(preview)
end

local function ValueWidth(row)
    local w, any = VALUE_INSET + VALUE_PAD, false
    for i = 1, #row.coins do
        local pair = row.coins[i]
        if pair.amount:IsShown() then
            w = w + (any and PAIR_GAP or 0) + pair.icon:GetWidth() + COIN_GAP + pair.amount:GetStringWidth()
            any = true
        end
    end
    return any and w or VALUE_ROOM
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.area = CreateFrame("Frame", nil, preview)
    preview.area:SetPoint("TOPLEFT", STAGE_MARGIN, -STAGE_MARGIN)
    preview.area:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, TEXT_ROOM)
    local box = CreateFrame("Frame", nil, preview)
    preview.feed = box
    preview.list, preview.hits = {}, {}
    Hit(box, preview, "lines")
    preview.rows = { Look.NewRow(box), Look.NewRow(box), Look.NewRow(box) }
    preview.gph = ns.Font(box, GPH_SIZE, "OUTLINE", GPH_RGB)
    preview.edit = CreateFrame("Frame", nil, box)
    preview.edit:SetAllPoints()
    local widthHit = NewEdge(preview, "width", "TOP", "BOTTOM")
    widthHit:SetPoint("TOP", box, "TOPRIGHT")
    widthHit:SetPoint("BOTTOM", box, "BOTTOMRIGHT")
    preview.widthHit = widthHit
    for i, row in ipairs(preview.rows) do
        local edge = NewEdge(preview, "height", "LEFT", "RIGHT")
        edge:SetPoint("LEFT", row, "BOTTOMLEFT")
        edge:SetPoint("RIGHT", row, "BOTTOMRIGHT")
        row.edgeHit = edge
        if i <= ITEM_ROWS then
            row.valueHit = NewHit(preview, "value", "lootFeedValue")
            row.valueHit:SetPoint("TOPRIGHT", row, "TOPRIGHT")
            row.valueHit:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
            row.bagsHit = NewHit(preview, "bags", "lootFeedBank")
            row.bagsHit:SetAllPoints(row.icon)
        end
    end
    preview.hint = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    preview.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", preview.hint, "TOP", 0, NOTE_GAP)
    preview:SetScript("OnHide", PreviewHidden)
    return preview
end

local function PaintPreview(preview, state)
    EndDrag(preview)
    local shown, samples = preview.list, preview.rows
    wipe(shown)
    local values, money = S.Get("lootFeedValue"), S.Get("lootFeedMoney")
    if money then
        Look.Fill(samples[3], COIN_ICON, TEXT_COINS, nil, nil, SAMPLE_COINS)
        shown[#shown + 1] = samples[3]
    else
        samples[3]:Hide()
    end
    local cloth = S.Get("lootFeedBank") and SAMPLE_CLOTH_BANK or SAMPLE_CLOTH_BAGS
    Look.Fill(samples[2], CLOTH_ICON, SAMPLE_CLOTH_NAME, nil, cloth, values and SAMPLE_CLOTH or nil, Enum.ItemQuality.Common)
    shown[#shown + 1] = samples[2]
    Look.Fill(samples[1], PANTS_ICON, SAMPLE_PANTS_NAME, nil, SAMPLE_PANTS_BAGS, values and SAMPLE_PANTS or nil,
        Enum.ItemQuality.Uncommon)
    shown[#shown + 1] = samples[1]
    for i, row in ipairs(shown) do
        Look.StyleRow(row)
        row:SetAlpha(state == "fading" and FADING[i] or 1)
        row:Show()
    end
    local w, h = S.Get("lootFeedWidth"), S.Get("lootFeedHeight")
    Restack(preview, w, h)
    local rate = preview.gph
    if state == "looting" and S.Get("lootFeedGPH") then
        Look.GPHFont(rate)
        Look.GPH(rate, shown[1], SAMPLE_PER_HOUR)
        rate:Show()
    else
        rate:Hide()
    end
    local scale = Fit(preview)
    Restack(preview, w, h)
    preview.note:SetText(state == "fading" and TEXT_FADES:format(S.Get("lootFeedFade")) or "")
    local editable = On() and true or false
    local box = preview.feed
    preview.editable = editable
    box:EnableMouse(editable)
    box:EnableMouseWheel(editable)
    preview.edit:SetShown(editable)
    preview.hint:SetText(editable and HINT or S.Get("enabled") and OFF_HINT or QOL_OFF_HINT)
    if not editable then
        Unhover(preview)
        return
    end
    local level = box:GetFrameLevel()
    local edge, line = EDGE_HIT / scale, EDGE_LINE / scale
    preview.edit:SetFrameLevel(level + EDIT_LEVEL)
    local widthHit = preview.widthHit
    widthHit:SetFrameLevel(level + TOP_LEVEL)
    widthHit:SetWidth(edge)
    widthHit.line:SetWidth(line)
    samples[3].edgeHit:SetShown(money)
    local down = S.Get("lootFeedGrowth") == "down"
    for i, row in ipairs(shown) do
        local hit = row.edgeHit
        hit.above = down and i - 1 or #shown - i
        hit:SetFrameLevel(level + TOP_LEVEL)
        hit:SetHeight(edge)
        hit.line:SetHeight(line)
        hit:Show()
    end
    for i = 1, ITEM_ROWS do samples[i].valueHit:SetWidth(ValueWidth(samples[i])) end
    if preview.part then ShowTip(preview) end
end

local function ResetGPH()
    ns.ResetLootFeedSession()
end

local function LootFeedSummary(store)
    local style = store.Get("lootFeedStyle")
    style = style == "none" and TEXT_NO_BACKGROUND or style == "light" and TEXT_LIGHT or TEXT_DARK
    return TEXT_SUMMARY:format(store.Get("lootFeedCount"), style, store.Get("lootFeedGPH") and TEXT_GPH or "")
end

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "lootFeed", name = "Loot Feed", order = 5, switch = "lootFeed",
    help = "Everything you loot pops up on screen with its icon, amount and value, stacking "
        .. "in your chosen direction and fading out. Hover a line for the item's tooltip. Move it in the HUD Editor.",
    summary = LootFeedSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Lines"),
        { key = "lootFeedMoney", label = "Show Money", toggle = true },
        { key = "lootFeedQuest", label = "Show Quest Rewards", toggle = true,
          help = "A line for each quest you turn in, with the experience and money it gave. "
              .. "Reward items show as their own lines." },
        { key = "lootFeedRep", label = "Show Reputation", toggle = true,
          help = "A line for every reputation gain, from quests and kills alike." },
        { key = "lootFeedXP", label = "Show Kill Experience", toggle = true,
          help = "A line for the experience from each kill. Quest experience is on the quest's "
              .. "own line." },
        { key = "lootFeedQuality", label = "Lowest Quality Shown", choice = QUALITY },
        { key = "lootFeedCount", label = "Lines Shown", slider = COUNT_RANGE },
        { key = "lootFeedFade", label = "Display Time", slider = DISPLAY_TIME_RANGE, unit = "s",
          help = "How long each line stays before it fades." },
        { key = "lootFeedGrowth", label = "Growth Direction", choice = GROWTH,
          help = "The newest line stays at the anchor; older lines stack in this direction." },
        Group("Value"),
        { key = "lootFeedValue", label = "Show Item Value", toggle = true,
          help = "What each line is worth, in gold, silver and copper." },
        { key = "lootFeedPrice", label = "Price Source", choice = PRICE,
          help = "Auction (Naowh Scan) uses your last Scan Prices at the auction house; Auction (TSM) "
              .. "needs TradeSkillMaster. An item without an auction price counts at its vendor price." },
        { key = "lootFeedBank", label = "Count Bank Items", toggle = true,
          help = "The number on each icon counts your bank as well as your bags." },
        { key = "lootFeedGPH", label = "Gold per Hour", toggle = true,
          help = "A running gold per hour beside the newest line, counting money and item value "
              .. "since your first loot this session." },
        { label = "Reset Gold per Hour", button = ResetGPH, buttonText = "Reset", always = true,
          help = "Starts the gold per hour count again from your next loot." },
        Group("Loot Window"),
        { key = "hideLootWindow", label = "Hide Blizzard Loot Window", toggle = true, always = true,
          needs = ns.GamepadFree, why = ns.GamepadWhy,
          help = "Takes everything the moment you loot, with Blizzard's loot window kept out of "
              .. "sight, so the feed is all you see. Works with or without the game's auto loot. "
              .. "Hold Shift while looting to get the window back. It also appears whenever "
              .. "something cannot be taken: a group roll, a locked item, or bags too full." },
        Group("Size"),
        { key = "lootFeedWidth", label = "Width", slider = WIDTH_RANGE },
        { key = "lootFeedHeight", label = "Line Height", slider = HEIGHT_RANGE,
          help = "The icon grows and shrinks with it." },
        { key = "lootFeedSpacing", label = "Spacing", slider = SPACING_RANGE,
          help = "Space between lines. -1 lets neighbouring lines share one border instead of two side by side." },
        ns.Shared.Settings.Look("lootFeed", { text = true, size = SIZE_RANGE }),
        { key = "lootFeedCountSize", label = "Count Size", slider = SIZE_RANGE,
          help = "Size of the number on each icon. It follows Font Size until you change it.",
          get = CountSize, set = function(v) S.Set("lootFeedCountSize", v) end },
        Group("Background"),
        { key = "lootFeedStyle", label = "Style", choice = STYLE,
          help = "A dark or light fill and edge behind each line, or none." },
        { key = "lootFeedGlow", label = "Glow", toggle = true, help = "A soft glow beside each icon." },
        { key = "lootFeedQualityBorder", label = "Quality Border", toggle = true,
          help = "Edges each item's icon in its quality color." },
    },
})
