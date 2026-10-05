-------------------------------------------------------------------------------
--  NaowhForever_XPTicker.lua -- the QoL XP per hour ticker: a small card with the rate, time to
--  level, session time and recent level times, and its settings card with a live preview.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local S = ns.QoLSettings
local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local OUTLINE = "OUTLINE"
local PAD, KICKER_GAP, TAG_GAP, HEAD_GAP, COL_GAP = 8, 2, 6, 10, 16
local SECTION_GAP, ROW_GAP, CONTROL_GAP, CONTROLS_INSET = 6, 3, 2, 6
local KICKER_SHARE, KICKER_MIN, ROW_SHARE, ROW_MIN = 0.42, 9, 0.6, 10
local HISTORY_SHARE, HISTORY_MIN, HISTORY_MAX = 0.5, 9, 10
local WIDTH_PER_SIZE, WIDTH_STEP = 6, 8
local KICKER, PAUSED, NONE, LEVEL = "XP / HOUR", "PAUSED", "--", "Level %d"
local PAUSE_TIP, PAUSE_HINT = "Pause", "Stops the clock and the XP count."
local START_TIP, START_HINT = "Start", "Carries on from where you paused."
local RESET_TIP, RESET_HINT = "Reset", "Starts the session again from zero."

local ticker, clock, clockRate, unlocked
local sessionStart, sessionXP = 0, 0
local paused, pausedAt, pausedTotal = false, nil, 0
local lastXP, lastXPMax
local cur, anchor
local historyKeys = {}

local function On()
    return S.Get("enabled") and S.Get("xpTicker")
end

local function AtMaxLevel()
    return UnitLevel("player") >= GetMaxLevelForPlayerExpansion() or IsXPUserDisabled()
end

local function Hidden()
    if unlocked then return false end
    return AtMaxLevel() or (S.Get("xpTickerHideResting") and IsResting())
end

local function Short(n)
    if n >= 1000000 then return ("%.1fm"):format(n / 1000000) end
    if n >= 1000 then return ("%.1fk"):format(n / 1000) end
    return tostring(math.floor(n))
end

local function Duration(seconds)
    if seconds >= 3600 then return ("%.1f hours"):format(seconds / 3600) end
    local m = math.max(math.floor(seconds / 60), 1)
    return m == 1 and "1 min" or (m .. " mins")
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60,
            seconds % 60)
    end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local Look = {}

local function NewText(f, color)
    local fs = ns.Font(f, ROW_MIN, nil, color)
    f.texts[#f.texts + 1] = fs
    return fs
end

local function NewRow(f, label)
    local row = { label = NewText(f, T.muted), value = NewText(f, T.fg), on = false }
    row.value:SetJustifyH("RIGHT")
    row.label:Hide()
    row.value:Hide()
    if label then row.label:SetText(label) end
    return row
end

local function CardEnter(f)
    f.controls:Show()
end

local function CardLeave(f)
    if not f:IsMouseOver() then f.controls:Hide() end
end

local function ButtonLeave(button)
    CardLeave(button.card)
end

local function NewButton(f, texture, tip, hint)
    local button = Parts.BarButton(f.controls, texture, tip, hint)
    button.card = f
    button:HookScript("OnLeave", ButtonLeave)
    return button
end

function Look.New(f)
    f.texts = {}
    f.bg = ns.Solid(f, "BACKGROUND", T.bg, St.HUD_CARD_ALPHA)
    f.bg:SetAllPoints()
    f.border = ns.Border(f, St.BORDER_RGB)
    f.kicker = NewText(f, T.accentSoft)
    f.kicker:SetPoint("TOPLEFT", PAD, -PAD)
    f.kicker:SetText(KICKER)
    f.tag = NewText(f, T.muted)
    f.tag:SetPoint("LEFT", f.kicker, "RIGHT", TAG_GAP, 0)
    f.tag:SetText(PAUSED)
    f.tag:Hide()
    f.rate = NewText(f, T.fg)
    f.rate:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -KICKER_GAP)
    f.ding, f.time = NewRow(f, "Ding"), NewRow(f, "Time")
    f.history = {}
    for i = 1, HISTORY_MAX do f.history[i] = NewRow(f) end

    f.controls = CreateFrame("Frame", nil, f)
    f.controls:SetPoint("TOPRIGHT", -CONTROLS_INSET, -CONTROLS_INSET)
    f.toggle = NewButton(f, St.PAUSE, PAUSE_TIP, PAUSE_HINT)
    f.toggle:SetPoint("LEFT")
    f.reset = NewButton(f, St.RESET, RESET_TIP, RESET_HINT)
    f.reset:SetPoint("LEFT", f.toggle, "RIGHT", CONTROL_GAP, 0)
    f.controls:SetSize(f.toggle:GetWidth() + CONTROL_GAP + f.reset:GetWidth(), f.toggle:GetHeight())
    f.controls:Hide()
    f:EnableMouse(true)
    f:SetScript("OnEnter", CardEnter)
    f:SetScript("OnLeave", CardLeave)
end

local function RowFont(row, font, size, flags)
    row.label:SetFont(font, size, flags)
    row.value:SetFont(font, size, flags)
end

function Look.Fonts(f)
    local font, size = ns.UI.FontPath(S.Get("xpTickerFont")), S.Get("xpTickerFontSize")
    local card = S.Get("xpTickerBackground") and true or false
    local outlined = (S.Get("xpTickerOutline") or not card) and true or false
    local flags = outlined and OUTLINE or ""
    local small = math.max(KICKER_MIN, math.floor(size * KICKER_SHARE))
    f.kicker:SetFont(font, small, flags)
    f.tag:SetFont(font, small, flags)
    f.rate:SetFont(font, size, flags)
    local rowSize = math.max(ROW_MIN, math.floor(size * ROW_SHARE))
    RowFont(f.ding, font, rowSize, flags)
    RowFont(f.time, font, rowSize, flags)
    local historySize = math.max(HISTORY_MIN, math.floor(size * HISTORY_SHARE))
    for i = 1, HISTORY_MAX do RowFont(f.history[i], font, historySize, flags) end
    for i = 1, #f.texts do Parts.HudText(f.texts[i], not outlined) end
    f.bg:SetShown(card)
    f.border._frame:SetShown(card)
    f.minW = size * WIDTH_PER_SIZE
    f.arranged = nil
end

local function PlaceRow(f, row, y)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
    row.value:ClearAllPoints()
    row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -y)
    return y + row.label:GetStringHeight()
end

local function ShowRow(row, on)
    row.on = on
    row.label:SetShown(on)
    row.value:SetShown(on)
end

local function Arrange(f, showDing, showTime, count)
    local key = (showDing and 1 or 0) + (showTime and 2 or 0) + count * 4
    if f.arranged == key then return false end
    f.arranged = key
    local head = math.ceil(f.kicker:GetStringHeight() + KICKER_GAP + f.rate:GetStringHeight())
    local y, gap = PAD + math.max(head, f.controls:GetHeight()), SECTION_GAP
    ShowRow(f.ding, showDing)
    if showDing then
        y, gap = PlaceRow(f, f.ding, y + gap), ROW_GAP
    end
    ShowRow(f.time, showTime)
    if showTime then y = PlaceRow(f, f.time, y + gap) end
    gap = SECTION_GAP
    for i = 1, HISTORY_MAX do
        local row = f.history[i]
        ShowRow(row, i <= count)
        if i <= count then
            y, gap = PlaceRow(f, row, y + gap), ROW_GAP
        end
    end
    f.height = math.ceil(y) + PAD
    return true
end

local function RowWidth(w, row)
    if not row.on then return w end
    return math.max(w, row.label:GetStringWidth() + COL_GAP + row.value:GetStringWidth())
end

function Look.Fit(f)
    local head = math.max(f.kicker:GetStringWidth() + TAG_GAP + f.tag:GetStringWidth(), f.rate:GetStringWidth())
    local w = math.max(f.minW, head + HEAD_GAP + f.controls:GetWidth())
    w = RowWidth(RowWidth(w, f.ding), f.time)
    for i = 1, HISTORY_MAX do w = RowWidth(w, f.history[i]) end
    f:SetSize(math.ceil(w / WIDTH_STEP) * WIDTH_STEP + 2 * PAD, f.height)
end

local function SetValue(fs, text)
    if fs.drawn == text then return false end
    fs.drawn = text
    fs:SetText(text)
    return true
end

local function ShowPaused(f, isPaused)
    if f.paused == isPaused then return end
    f.paused = isPaused
    f.tag:SetShown(isPaused)
    local toggle = f.toggle
    toggle.icon:SetTexture(isPaused and St.PLAY or St.PAUSE)
    toggle.tip = isPaused and START_TIP or PAUSE_TIP
    toggle.hint = isPaused and START_HINT or PAUSE_HINT
end

function Look.Paint(f, rate, ding, elapsed, isPaused, keys, levels)
    local changed = SetValue(f.rate, Short(rate))
    ShowPaused(f, isPaused and true or false)
    local showDing = S.Get("xpTickerLevel") and true or false
    local showTime = S.Get("xpTickerElapsed") and true or false
    if showDing and SetValue(f.ding.value, ding and Duration(ding) or NONE) then changed = true end
    if showTime then
        local sec = math.max(0, math.floor(elapsed + 0.5))
        if f.time.sec ~= sec then
            f.time.sec = sec
            f.time.value:SetText(Clock(sec))
            changed = true
        end
    end
    local count = math.min(#keys, S.Get("xpTickerHistoryCount") or HISTORY_MAX, HISTORY_MAX)
    for i = 1, count do
        local row, level = f.history[i], keys[i]
        local total = levels[level].total
        if row.level ~= level then
            row.level = level
            row.label:SetText(LEVEL:format(level))
            changed = true
        end
        if row.total ~= total then
            row.total = total
            row.value:SetText(Clock(total))
            changed = true
        end
    end
    if Arrange(f, showDing, showTime, count) then changed = true end
    if changed then Look.Fit(f) end
end

local function Splits()
    local account = ns.AccountSettings()
    account.levelSplits = account.levelSplits or {}
    local key = UnitName("player") .. "-" .. GetRealmName()
    account.levelSplits[key] = account.levelSplits[key] or { levels = {} }
    return account.levelSplits[key]
end

local function LevelTime()
    return cur.base + (anchor and GetTime() - anchor or 0)
end

local function StartLevel(fromStart, level)
    cur = { level = level or UnitLevel("player"), base = 0, partial = not fromStart }
    anchor = not paused and GetTime() or nil
    Splits().current = cur
end

local function TrackSplits(newLevel)
    if not cur then
        local saved = Splits().current
        if saved and saved.level == UnitLevel("player") then
            cur, anchor = saved, not paused and GetTime() or nil
        else
            StartLevel(UnitXP("player") == 0)
        end
    end
    local level = newLevel or UnitLevel("player")
    if level > cur.level then
        Splits().levels[cur.level] = { total = not cur.partial and LevelTime() or nil }
        StartLevel(true, level)
    elseif not anchor and not paused then
        anchor = GetTime()
    end
end

local function Newest(a, b)
    return a > b
end

local function History()
    wipe(historyKeys)
    if not (cur and S.Get("xpTickerSplits")) then return historyKeys end
    local levels = Splits().levels
    for level, record in pairs(levels) do
        if type(level) == "number" and level < cur.level and record.total then
            historyKeys[#historyKeys + 1] = level
        end
    end
    table.sort(historyKeys, Newest)
    return historyKeys, levels
end

local function Update()
    if not ticker then return end
    if Hidden() then
        ticker:Hide()
        return
    end
    local now = GetTime()
    local elapsed = now - sessionStart - pausedTotal - (paused and now - pausedAt or 0)
    local rate = sessionXP / (math.max(elapsed, 60) / 3600)
    local ding
    if rate > 0 and S.Get("xpTickerLevel") then
        ding = (UnitXPMax("player") - UnitXP("player")) / rate * 3600
    end
    local keys, levels = History()
    Look.Paint(ticker, rate, ding, elapsed, paused, keys, levels)
    ticker:Show()
end

function ns.ResetXPTicker()
    sessionStart, sessionXP, pausedTotal = GetTime(), 0, 0
    if paused then pausedAt = sessionStart end
    Update()
    ns.ResetXPBarSession()
end

function ns.PauseXPTicker()
    if paused then return end
    paused, pausedAt = true, GetTime()
    if cur and anchor then cur.base, anchor = LevelTime(), nil end
    Update()
end

function ns.StartXPTicker()
    if not paused then return end
    pausedTotal = pausedTotal + GetTime() - pausedAt
    paused, pausedAt = false, nil
    if cur then anchor = GetTime() end
    Update()
end

local function TogglePause()
    if paused then ns.StartXPTicker() else ns.PauseXPTicker() end
end

local function ResetClicked()
    ns.ResetXPTicker()
end

function ns.XPTickerCommand(arg)
    local run = ({ start = ns.StartXPTicker, pause = ns.PauseXPTicker, reset = ns.ResetXPTicker })[arg]
    if run then run() else print(ns.Color("accent", "Naowh") .. ": /naowh xp start, pause or reset") end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGOUT" then
        if cur then cur.base = LevelTime() end
        return
    end
    if event == "PLAYER_XP_UPDATE" then
        local xp, max = UnitXP("player"), UnitXPMax("player")
        local gained = xp >= lastXP and xp - lastXP or (lastXPMax - lastXP) + xp
        lastXP, lastXPMax = xp, max
        if not paused then sessionXP = sessionXP + gained end
    end
    TrackSplits(event == "PLAYER_LEVEL_UP" and arg1 or nil)
    Update()
end)

local function Place()
    local pos = S.Get("xpTickerPos")
    ticker:ClearAllPoints()
    if pos then
        ticker:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        ticker:SetPoint("LEFT", UIParent, "CENTER", -811, 3)
    end
end

local function Apply()
    if not On() then
        if cur and anchor then cur.base, anchor = LevelTime(), nil end
        events:UnregisterAllEvents()
        if clock then clock:Cancel(); clock = nil end
        if ticker then ticker:Hide() end
        return
    end
    if not ticker then
        ticker = CreateFrame("Frame", "NaowhForeverXPTicker", UIParent)
        ticker:SetMovable(true)
        ticker:SetClampedToScreen(true)
        Look.New(ticker)
        ticker.toggle:SetScript("OnClick", TogglePause)
        ticker.reset:SetScript("OnClick", ResetClicked)
        ticker.mover = ns.UI.AttachMover(ticker, "XP per Hour", function(pos) S.Set("xpTickerPos", pos) end,
            "QoL/XP", "QoL/XP:xpTicker")
        sessionStart, sessionXP = GetTime(), 0
    end
    Look.Fonts(ticker)
    Place()
    lastXP, lastXPMax = UnitXP("player"), UnitXPMax("player")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_UPDATE_RESTING")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_LOGOUT")
    TrackSplits()
    local rate = S.Get("xpTickerSplits") and 1 or 5
    if AtMaxLevel() and not unlocked then rate = nil end
    if clock and clockRate ~= rate then clock:Cancel(); clock = nil end
    if rate and not clock then clock, clockRate = C_Timer.NewTicker(rate, Update), rate end
    ticker.mover:SetShown(unlocked == true)
    Update()
end

hooksecurefunc(S, "Set", function(key, value)
    if key == "enabled" or (key:find("^xpTicker") and key ~= "xpTickerPos") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowRaidReminderAnchorConfig", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideRaidReminderAnchorConfig", function()
    unlocked = false
    if ticker then
        ticker.mover:Hide()
        Apply()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group
local STAGE_H, STAGE_MARGIN, TEXT_ROOM = 210, 16, 44
local NOTE_Y, NOTE_SIZE, NOTE_GAP = 8, 11, 4
local HOVER_ALPHA, HIT_PAD = 0.12, 1
local SIZE_RANGE = { 8, 32, 1 }
local SAMPLE_RATE, SAMPLE_DING, SAMPLE_TIME = 48200, 23 * 60, 72 * 60 + 40
local SAMPLE_PAUSED_TIME, SAMPLE_RESTING_RATE, SAMPLE_RESTING_DING = 41 * 60 + 5, 31600, 35 * 60
local SAMPLE_KEYS = { 22, 21, 20, 19, 18 }
local SAMPLE_LEVELS = { [22] = { total = 3125 }, [21] = { total = 2864 }, [20] = { total = 2702 },
    [19] = { total = 2391 }, [18] = { total = 2248 } }
local NO_KEYS = {}
local HINT = "Wheel: text size. Click a line to hide it. Right-click for more."
local OFF_HINT = "Turn on XP per Hour to edit it here."
local HIDDEN_NOTE = "Hide While Resting is on: hidden in cities and inns."
local STATES = {
    { key = "levelling", label = "Levelling", tip = "Out in the world, earning experience." },
    { key = "paused", label = "Paused", tip = "Paused from its header: the clock and the count stop." },
    { key = "resting", label = "Resting", tip = "In a city or an inn." },
}
local LOOK_TOGGLES = {
    { "xpTickerBackground", "Background" },
    { "xpTickerOutline", "Outlined Text" },
}
local LINE_TOGGLES = {
    { "xpTickerLevel", "Show Ding Time" },
    { "xpTickerElapsed", "Show Time" },
    { "xpTickerSplits", "Level History" },
}

local function Toggled(key)
    return S.Get(key) == true
end

local function Toggle(key)
    S.Set(key, not S.Get(key))
end

local function AddToggles(root, list)
    for i = 1, #list do root:CreateCheckbox(list[i][2], Toggled, Toggle, list[i][1]) end
end

local function CardMenu(_, root)
    root:CreateTitle("XP per Hour")
    AddToggles(root, LOOK_TOGGLES)
    root:CreateDivider()
    AddToggles(root, LINE_TOGGLES)
    root:CreateDivider()
    root:CreateButton("Reset XP per Hour", ResetClicked)
end

local function Wheel(f, delta)
    if not f.preview.editable then return end
    local size = S.Get("xpTickerFontSize")
    local v = math.max(SIZE_RANGE[1], math.min(SIZE_RANGE[2], size + delta * SIZE_RANGE[3]))
    if v ~= size then S.Set("xpTickerFontSize", v) end
end

local function CardUp(f, button)
    if f.preview.editable and button == "RightButton" then MenuUtil.CreateContextMenu(f, CardMenu) end
end

local function HitEnter(hit)
    CardEnter(hit.card)
    if hit.card.preview.editable then hit.wash:Show() end
end

local function HitLeave(hit)
    hit.wash:Hide()
    CardLeave(hit.card)
end

local function HitUp(hit, button)
    if not hit.card.preview.editable then return end
    if button == "RightButton" then
        CardUp(hit.card, button)
    elseif button == "LeftButton" and hit:IsMouseOver() then
        Toggle(hit.key)
    end
end

local function HitWheel(hit, delta)
    Wheel(hit.card, delta)
end

local function NewHit(preview, row, key)
    local f = preview.ticker
    local hit = CreateFrame("Frame", nil, f)
    hit:SetPoint("TOPLEFT", row.label, "TOPLEFT", -HIT_PAD, HIT_PAD)
    hit:SetPoint("BOTTOMRIGHT", row.value, "BOTTOMRIGHT", HIT_PAD, -HIT_PAD)
    hit.wash = ns.Solid(hit, "BACKGROUND", T.accent, HOVER_ALPHA)
    hit.wash:SetAllPoints()
    hit.wash:Hide()
    hit.card, hit.row, hit.key = f, row, key
    hit:EnableMouse(true)
    hit:EnableMouseWheel(true)
    hit:SetScript("OnEnter", HitEnter)
    hit:SetScript("OnLeave", HitLeave)
    hit:SetScript("OnMouseUp", HitUp)
    hit:SetScript("OnMouseWheel", HitWheel)
    hit:Hide()
    preview.hits[#preview.hits + 1] = hit
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.area = CreateFrame("Frame", nil, preview)
    preview.area:SetPoint("TOPLEFT", STAGE_MARGIN, -STAGE_MARGIN)
    preview.area:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, TEXT_ROOM)
    local f = CreateFrame("Frame", nil, preview)
    preview.ticker, f.preview = f, preview
    Look.New(f)
    f.toggle:EnableMouse(false)
    f.reset:EnableMouse(false)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", Wheel)
    f:SetScript("OnMouseUp", CardUp)
    preview.hits = {}
    NewHit(preview, f.ding, "xpTickerLevel")
    NewHit(preview, f.time, "xpTickerElapsed")
    for i = 1, HISTORY_MAX do NewHit(preview, f.history[i], "xpTickerSplits") end
    preview.hint = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    preview.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", preview.hint, "TOP", 0, NOTE_GAP)
    return preview
end

local function FitPreview(preview)
    local f, area = preview.ticker, preview.area
    local w, h = f:GetWidth(), f:GetHeight()
    local roomW, roomH = area:GetWidth(), area:GetHeight()
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", area, "CENTER", 0, 0)
end

local function PaintPreview(preview, state)
    local f = preview.ticker
    Look.Fonts(f)
    local keys = S.Get("xpTickerSplits") and SAMPLE_KEYS or NO_KEYS
    if state == "paused" then
        Look.Paint(f, SAMPLE_RATE, SAMPLE_DING, SAMPLE_PAUSED_TIME, true, keys, SAMPLE_LEVELS)
    elseif state == "resting" then
        Look.Paint(f, SAMPLE_RESTING_RATE, SAMPLE_RESTING_DING, SAMPLE_TIME, false, keys, SAMPLE_LEVELS)
    else
        Look.Paint(f, SAMPLE_RATE, SAMPLE_DING, SAMPLE_TIME, false, keys, SAMPLE_LEVELS)
    end
    FitPreview(preview)
    local hidden = state == "resting" and S.Get("xpTickerHideResting") and true or false
    f:SetShown(not hidden)
    preview.note:SetText(hidden and HIDDEN_NOTE or "")
    local editable = (On() and not hidden) and true or false
    preview.editable = editable
    preview.hint:SetText(editable and HINT or hidden and "" or OFF_HINT)
    local hits = preview.hits
    for i = 1, #hits do
        local hit = hits[i]
        hit:SetShown(editable and hit.row.on)
        if not editable then hit.wash:Hide() end
    end
end

local function Summary(store)
    if store.Get("xpTickerSplits") then
        return ("Rate, time to level and the last %d levels"):format(store.Get("xpTickerHistoryCount"))
    end
    return "Rate and time to level"
end

ns.Shared.Settings.Page("QoL/XP", S):Card({
    id = "xpTicker", name = "XP per Hour", order = 20, switch = "xpTicker",
    help = "Your experience per hour on a small card, with time to level, session length and recent level "
        .. "times. Hidden at max level. Hover it for Start, Pause and Reset (also /naowh xp start, pause "
        .. "or reset). Move it in Unlock Mode.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Shown"),
        { key = "xpTickerLevel", label = "Show Ding Time", toggle = true,
          help = "How long the next level takes at your current rate." },
        { key = "xpTickerElapsed", label = "Show Time", toggle = true, help = "How long this session has run." },
        { key = "xpTickerHideResting", label = "Hide While Resting", toggle = true, help = "Hidden in cities and inns." },
        Group("Level History"),
        { key = "xpTickerSplits", label = "Level History", toggle = true,
          help = "Completed levels, newest first. No placeholder rows." },
        { key = "xpTickerHistoryCount", label = "Levels Shown", slider = { 1, HISTORY_MAX, 1 }, needs = "xpTickerSplits",
          help = "The most recent completed levels." },
        Group("Look"),
        { key = "xpTickerBackground", label = "Background", toggle = true,
          help = "A dark card behind the text; off leaves outlined text alone." },
        { key = "xpTickerOutline", label = "Outlined Text", toggle = true, needs = "xpTickerBackground",
          help = "A thick black outline round the text, in place of the soft shadow." },
        { key = "xpTickerFont", label = "Font", font = true },
        { key = "xpTickerFontSize", label = "Font Size", slider = SIZE_RANGE },
        { label = "Reset XP per Hour", buttonText = "Reset", button = ns.ResetXPTicker,
          help = "Starts the session again: its time, XP and rate. The XP Bar's XP/Hour starts again with it." },
    },
})
