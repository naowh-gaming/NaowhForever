-- RunsPage.lua: the Journal's Runs tab: this character's runs by dungeon, and the picked run's times, splits, loot and the rest (J.RunsPage).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Runs = J.Runs
local Loot = J.Loot
local Team = J.Team
local Parts = ns.Shared.Parts
local VP = J.View.Parts
local St = J.Style

local LIST_W = 300
local TOP_H, PICKER_W, PICKER_LEVEL = 26, 200, 3
local GAP, PAD = 8, 10
local GROUP_H, RUN_H = 22, 40
local TITLE_SIZE, META_SIZE, LABEL_SIZE, VALUE_SIZE, TEXT_SIZE, SMALL_SIZE = 18, 12, St.TINY_SIZE, 18, 13, 11
local PILL_SIZE, PILL_GAP = 10, 4
local CARDS, CARD_H, CARD_GAP, CARD_PAD = 4, 58, 8, 8
local CARD_ALPHA = 0.035
local TABLE_ROW, FACE = 26, 22
local COLUMNS = { 0.55, 0.67, 0.79, 0.91, 1 }
local LINE_H, LOOT_ICON = 24, 18
local LINE_GAP, BLOCK_GAP = 2, 16
local BIS_PICK = 1
local THOUSAND = 1000
local ALL = "all"

local TEXT_ALL = ns.L("All dungeons")
local TEXT_EMPTY = ns.L("No runs yet. Turn on the Run Panel and go into a dungeon: each run is kept here.")
local TEXT_BEST = ns.L("Best")
local TEXT_NOT_FINISHED = ns.L("Not finished")
local TEXT_IN_PROGRESS = ns.L("In progress")
local TEXT_RUN_SUB = ns.L("%d deaths, %s")
local TEXT_XP_SHORT = ns.L("%.1fk XP")
local TEXT_META = ns.L("%s, with %s")
local TEXT_YOU = ns.L("you")
local TEXT_TIME = ns.L("TIME")
local TEXT_GOLD = ns.L("GOLD")
local TEXT_XP = ns.L("XP")
local TEXT_RUNS = ns.L("RUNS")
local TEXT_BEST_AVG = ns.L("best %s, avg %s")
local TEXT_AVG = ns.L("avg %s")
local TEXT_FINISHED = ns.L("%d finished")
local TEXT_BOSS = ns.L("Boss")
local TEXT_THIS_RUN = ns.L("This run")
local TEXT_AVERAGE = ns.L("Average")
local TEXT_VS_BEST = ns.L("vs best")
local TEXT_LOOT = ns.L("LOOT")
local TEXT_REST = ns.L("THE REST")
local TEXT_NO_LOOT = ns.L("No loot this run.")
local TEXT_TRASH = ns.L("Trash killed")
local TEXT_OF = ns.L("%d of %d")
local TEXT_OUTSIDE = ns.L("Time outside")
local TEXT_NEED = ns.L("Need rolls")
local TEXT_NEED_COUNT = ns.L("%d won, %d lost")
local TEXT_GOLD_HOUR = ns.L("Gold per hour")
local TEXT_DELETE = ns.L("Delete this run")
local TEXT_DELETE_ASK = ns.L("Delete this run of %s?")
local TEXT_BIS = ns.L("BiS")
local TEXT_NONE = "-"
local TEXT_LIST = ", "
local TEXT_DELTA = "%s%s"
local TEXT_MINUS, TEXT_PLUS = "-", "+"
local DATE = "%a %d %b, %H:%M"

local frame, list, listBody, detail, body, picker
local picked
local filter = ALL
local groupPool, runPool, textPool, linePool = {}, {}, {}, {}
local groups, runRows, lines = 0, 0, 0
local used = {}
local names = {}
local order = {}
local values, valueOrder = {}, {}
local members = {}
local summary = {}
local latest = {}
local bosses = {}

local RunsPage = {}
J.RunsPage = RunsPage

local function Paint(fs, color)
    fs:SetTextColor(color.r, color.g, color.b)
end

local function Delta(seconds)
    return TEXT_DELTA:format(seconds <= 0 and TEXT_MINUS or TEXT_PLUS, VP.FightLength(math.abs(seconds)))
end

local function DeltaColor(seconds)
    return seconds <= 0 and St.HAVE_RGB or St.RED_RGB
end

local function Time(seconds)
    return seconds and VP.FightLength(seconds) or TEXT_NONE
end

local function Shown(run)
    return J.Get(run.dungeon) ~= nil and (filter == ALL or run.dungeon == filter)
end

local function Newer(a, b)
    if a.dungeon ~= b.dungeon then
        local x, y = latest[a.dungeon], latest[b.dungeon]
        if x ~= y then return x > y end
        return a.dungeon < b.dungeon
    end
    return a.start > b.start
end

local function Ordered()
    wipe(order)
    wipe(latest)
    local mine = Runs.List()
    for i = 1, mine and #mine or 0 do
        local run = mine[i]
        if Shown(run) then
            order[#order + 1] = run
            if run.start > (latest[run.dungeon] or 0) then latest[run.dungeon] = run.start end
        end
    end
    table.sort(order, Newer)
    return order
end

local function Group(i)
    local fs = groupPool[i]
    if fs then return fs end
    fs = ns.Font(listBody, LABEL_SIZE, nil, T.muted)
    fs:SetJustifyH("LEFT")
    groupPool[i] = fs
    return fs
end

local function Badge(row, i)
    local pill = row.badges[i]
    if pill then return pill end
    pill = Parts.Pill(row, PILL_SIZE, T.muted)
    row.badges[i] = pill
    return pill
end

local Pick

local function DeleteRun(run)
    local dungeon = J.Get(run.dungeon)
    ns.Confirm(TEXT_DELETE_ASK:format(dungeon and dungeon.name or run.dungeon), function()
        if picked == run then picked = nil end
        Runs.Delete(run)
        RunsPage.Refresh()
    end)
end

local function RunClicked(row, button)
    local run = row.run
    if button == "RightButton" then
        ns.ContextMenu(row, function(_, root)
            root:CreateButton(TEXT_DELETE, function() DeleteRun(run) end)
        end)
        return
    end
    Pick(run)
end

local function RunEnter(row)
    row.hover:Show()
end

local function RunLeave(row)
    row.hover:Hide()
end

local function RunRow(i)
    local row = runPool[i]
    if row then return row end
    row = CreateFrame("Button", nil, listBody)
    row:SetHeight(RUN_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.ROW_HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.sel = ns.Solid(row, "BACKGROUND", T.accent, St.TAB_SELECTED_FILL)
    row.sel:SetAllPoints()
    row.edge = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    row.edge:SetWidth(LINE_GAP)
    row.when = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.when:SetPoint("TOPLEFT", PAD, -GAP)
    row.sub = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.sub:SetPoint("TOPLEFT", row.when, "BOTTOMLEFT", 0, -LINE_GAP)
    row.time = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.time:SetJustifyH("RIGHT")
    row.time:SetPoint("TOPRIGHT", -PAD, -GAP)
    row.xp = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.xp:SetJustifyH("RIGHT")
    row.xp:SetPoint("TOPRIGHT", row.time, "BOTTOMRIGHT", 0, -LINE_GAP)
    row.badges = {}
    row:SetScript("OnClick", RunClicked)
    row:SetScript("OnEnter", RunEnter)
    row:SetScript("OnLeave", RunLeave)
    runPool[i] = row
    return row
end

local function SetBadge(row, n, text, color)
    n = n + 1
    local pill = Badge(row, n)
    Parts.ColorPill(pill, color)
    Parts.SetPill(pill, text)
    pill:ClearAllPoints()
    pill:SetPoint("LEFT", n == 1 and row.when or row.badges[n - 1], "RIGHT", PILL_GAP, 0)
    pill:Show()
    return n
end

local function FillRun(row, run)
    row.run = run
    row.when:SetText(date(DATE, run.start))
    row.sub:SetText(TEXT_RUN_SUB:format(run.deaths, Parts.Coins(run.copper, true)))
    row.time:SetText(Time(run.done))
    row.xp:SetText(TEXT_XP_SHORT:format(run.xp / THOUSAND))
    local n = 0
    if not run.ended and Runs.Open() == run then
        n = SetBadge(row, n, TEXT_IN_PROGRESS, T.accentSoft)
    elseif not run.done then
        n = SetBadge(row, n, TEXT_NOT_FINISHED, T.muted)
    end
    if Runs.IsBest(run) then n = SetBadge(row, n, TEXT_BEST, St.HAVE_RGB) end
    for i = n + 1, #row.badges do row.badges[i]:Hide() end
    row.sel:SetShown(run == picked)
    row.edge:SetShown(run == picked)
end

local function DrawList()
    groups, runRows = 0, 0
    local y, last = 0, nil
    for _, run in ipairs(Ordered()) do
        if run.dungeon ~= last then
            last = run.dungeon
            groups = groups + 1
            local fs = Group(groups)
            fs:SetText(J.Get(run.dungeon).name:upper())
            fs:ClearAllPoints()
            fs:SetPoint("BOTTOMLEFT", listBody, "TOPLEFT", PAD, -(y + GROUP_H - GAP / 2))
            fs:Show()
            y = y + GROUP_H
        end
        runRows = runRows + 1
        local row = RunRow(runRows)
        FillRun(row, run)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT")
        row:Show()
        y = y + RUN_H
    end
    for i = groups + 1, #groupPool do groupPool[i]:Hide() end
    for i = runRows + 1, #runPool do runPool[i]:Hide() end
    listBody:SetHeight(math.max(y, 1))
end

local function Text(size, color, justify)
    local pool = textPool[size]
    if not pool then
        pool = {}
        textPool[size] = pool
    end
    local n = (used[size] or 0) + 1
    used[size] = n
    local fs = pool[n]
    if not fs then
        fs = ns.Font(body, size, nil, color)
        pool[n] = fs
    end
    fs:SetWidth(0)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    fs:ClearAllPoints()
    Paint(fs, color or T.fg)
    fs:Show()
    return fs
end

local function Line(i)
    local line = linePool[i]
    if line then return line end
    line = CreateFrame("Frame", nil, body)
    line:SetHeight(LINE_H)
    line.icon = Parts.ItemIcon(line, LOOT_ICON)
    line.icon:SetPoint("LEFT")
    line.face = VP.BossFace(line, FACE)
    line.face:SetPoint("LEFT")
    line.card = ns.Solid(line, "BACKGROUND", T.fg, CARD_ALPHA)
    line.card:SetAllPoints()
    line.edge = ns.Border(line, St.BORDER_RGB)
    linePool[i] = line
    return line
end

local function UseLine(y, x, w, h)
    lines = lines + 1
    local line = Line(lines)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", x or 0, -y)
    line:SetSize(w or body:GetWidth(), h or LINE_H)
    line.icon:Hide()
    line.face:Hide()
    line.card:Hide()
    line.edge._frame:Hide()
    line:Show()
    return line
end

local function Members(run)
    Team.Read(run.team, members)
    wipe(names)
    for _, member in ipairs(members) do
        if not member.me then names[#names + 1] = member.name end
    end
    names[#names + 1] = TEXT_YOU
    return table.concat(names, TEXT_LIST)
end

local function Card(i, label, value, sub, y, w)
    local x = (i - 1) * (w + CARD_GAP)
    local card = UseLine(y, x, w, CARD_H)
    card.card:Show()
    card.edge._frame:Show()
    local fs = Text(LABEL_SIZE, T.muted)
    fs:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CARD_PAD)
    fs:SetText(label)
    local v = Text(VALUE_SIZE, T.fg)
    v:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -LINE_GAP)
    v:SetText(value)
    local s = Text(SMALL_SIZE, T.muted)
    s:SetPoint("TOPLEFT", v, "BOTTOMLEFT", 0, -LINE_GAP)
    s:SetWidth(w - CARD_PAD * 2)
    s:SetText(sub or "")
end

local function Column(text, size, color, i, y, w)
    local fs = Text(size, color, i == 1 and "LEFT" or "RIGHT")
    local right = COLUMNS[i] * w
    if i == 1 then
        fs:SetPoint("LEFT", body, "TOPLEFT", FACE + GAP, -(y + TABLE_ROW / 2))
        fs:SetWidth(COLUMNS[1] * w - FACE - GAP)
    else
        fs:SetPoint("RIGHT", body, "TOPLEFT", right, -(y + TABLE_ROW / 2))
    end
    fs:SetText(text)
    return fs
end

local function Bosses(dungeon)
    wipe(bosses)
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do
            if Runs.Counts(boss) then bosses[#bosses + 1] = boss end
        end
    end
end

local function Table(run, y, w)
    Column(TEXT_BOSS, SMALL_SIZE, T.muted, 1, y, w):SetPoint("LEFT", body, "TOPLEFT", 0, -(y + TABLE_ROW / 2))
    Column(TEXT_THIS_RUN, SMALL_SIZE, T.muted, 2, y, w)
    Column(TEXT_BEST, SMALL_SIZE, T.muted, 3, y, w)
    Column(TEXT_AVERAGE, SMALL_SIZE, T.muted, 4, y, w)
    Column(TEXT_VS_BEST, SMALL_SIZE, T.muted, 5, y, w)
    y = y + TABLE_ROW
    for _, boss in ipairs(bosses) do
        local at = Runs.Split(run, boss)
        local best = Runs.BestSplit(run.dungeon, boss, run)
        local line = UseLine(y, 0, w, TABLE_ROW)
        VP.SetBossFace(line.face, boss, true)
        Column(boss.name, TEXT_SIZE, at and T.fg or T.muted, 1, y, w)
        Column(Time(at), TEXT_SIZE, T.fg, 2, y, w)
        Column(Time(at and best and math.min(at, best) or best or at), TEXT_SIZE, T.fg, 3, y, w)
        Column(Time(Runs.AverageSplit(run.dungeon, boss)), TEXT_SIZE, T.fg, 4, y, w)
        local delta = at and best and at - best
        local fs = Column(delta and Delta(delta) or TEXT_NONE, TEXT_SIZE, T.muted, 5, y, w)
        if delta then Paint(fs, DeltaColor(delta)) end
        y = y + TABLE_ROW
    end
    return y
end

local function Heading(text, x, y)
    local fs = Text(LABEL_SIZE, T.muted)
    fs:SetPoint("TOPLEFT", x, -y)
    fs:SetText(text)
    return y + LABEL_SIZE + LINE_GAP * 3
end

local function LootLines(run, x, y, w)
    y = Heading(TEXT_LOOT, x, y)
    if #run.loot == 0 then
        local fs = Text(TEXT_SIZE, T.muted)
        fs:SetPoint("TOPLEFT", x, -y)
        fs:SetText(TEXT_NO_LOOT)
        return y + LINE_H
    end
    for _, item in ipairs(run.loot) do
        local line = UseLine(y, x, w)
        line.icon.texture:SetTexture(C_Item.GetItemIconByID(item.id))
        line.icon:Show()
        local name = Text(TEXT_SIZE, T.fg)
        name:SetPoint("LEFT", line, "LEFT", LOOT_ICON + GAP, 0)
        name:SetWidth(w - LOOT_ICON - GAP * 2 - PAD * 3)
        name:SetText(item.link)
        if Loot.BisOn() and Loot.Rank(item.id) == BIS_PICK then
            local note = Text(SMALL_SIZE, St.BIS_RGB, "RIGHT")
            note:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            note:SetText(TEXT_BIS)
        end
        y = y + LINE_H
    end
    return y
end

local function RestLine(label, value, x, y, w)
    local fs = Text(TEXT_SIZE, T.fg)
    fs:SetPoint("LEFT", body, "TOPLEFT", x, -(y + LINE_H / 2))
    fs:SetText(label)
    local v = Text(SMALL_SIZE, T.muted, "RIGHT")
    v:SetPoint("RIGHT", body, "TOPLEFT", x + w, -(y + LINE_H / 2))
    v:SetText(value)
    return y + LINE_H
end

local function Rest(run, x, y, w)
    y = Heading(TEXT_REST, x, y)
    local total = Runs.TrashTotal(run.dungeon)
    y = RestLine(TEXT_TRASH, total and TEXT_OF:format(run.trash, total) or tostring(run.trash), x, y, w)
    y = RestLine(TEXT_OUTSIDE, VP.FightLength(run.out), x, y, w)
    y = RestLine(TEXT_NEED, TEXT_NEED_COUNT:format(run.needWon, run.needLost), x, y, w)
    return RestLine(TEXT_GOLD_HOUR, Parts.Coins(Runs.PerHour(run.copper, Runs.Elapsed(run)), true), x, y, w)
end

local function HideDetail()
    for _, pool in pairs(textPool) do
        for i = 1, #pool do pool[i]:Hide() end
    end
    for i = 1, #linePool do linePool[i]:Hide() end
    wipe(used)
    lines = 0
end

local function DrawDetail()
    HideDetail()
    frame.empty:SetShown(picked == nil)
    if not picked then return body:SetHeight(1) end
    local run, dungeon = picked, J.Get(picked.dungeon)
    local w = body:GetWidth()
    Bosses(dungeon)
    Runs.Summary(run.dungeon, summary)
    local title = Text(TITLE_SIZE, T.fg)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(dungeon.name)
    local meta = Text(META_SIZE, T.muted)
    meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -LINE_GAP * 2)
    meta:SetText(TEXT_META:format(date(DATE, run.start), Members(run)))
    local y = TITLE_SIZE + META_SIZE + LINE_GAP * 2 + BLOCK_GAP
    local cardW = (w - CARD_GAP * (CARDS - 1)) / CARDS
    Card(1, TEXT_TIME, Time(run.done), TEXT_BEST_AVG:format(Time(summary.best), Time(summary.time)), y, cardW)
    Card(2, TEXT_GOLD, Parts.Coins(run.copper, true), summary.copper and TEXT_AVG:format(Parts.Coins(summary.copper, true)),
        y, cardW)
    Card(3, TEXT_XP, BreakUpLargeNumbers(run.xp), summary.xp and TEXT_AVG:format(BreakUpLargeNumbers(summary.xp)), y, cardW)
    Card(4, TEXT_RUNS, tostring(summary.runs), TEXT_FINISHED:format(summary.finished), y, cardW)
    y = Table(run, y + CARD_H + BLOCK_GAP, w) + BLOCK_GAP
    local half = (w - BLOCK_GAP) / 2
    local left = LootLines(run, 0, y, half)
    local right = Rest(run, half + BLOCK_GAP, y, half)
    body:SetHeight(math.max(left, right))
end

local function Values()
    wipe(values)
    wipe(valueOrder)
    values[ALL] = TEXT_ALL
    valueOrder[1] = ALL
    local mine = Runs.List()
    for i = 1, mine and #mine or 0 do
        local key = mine[i].dungeon
        local dungeon = J.Get(key)
        if dungeon and not values[key] then
            values[key] = dungeon.name
            valueOrder[#valueOrder + 1] = key
        end
    end
    return values, valueOrder
end

local function Filter()
    return filter
end

local function SetFilter(key)
    filter = key
    if picked and not Shown(picked) then picked = nil end
    RunsPage.Refresh()
end

function Pick(run)
    picked = run
    DrawList()
    DrawDetail()
    detail:SetVerticalScroll(0)
end

function RunsPage.Build(parent)
    frame = CreateFrame("Frame", nil, parent)
    Values()
    picker = ns.UI.BuildDropdownControl(frame, PICKER_W, parent:GetFrameLevel() + PICKER_LEVEL, values, valueOrder,
        Filter, SetFilter)
    picker:SetPoint("TOPRIGHT", 0, 0)
    list = ns.UI.SlimScroll(frame)
    list:SetPoint("TOPLEFT", 0, -(TOP_H + GAP))
    list:SetPoint("BOTTOMLEFT")
    list:SetWidth(LIST_W)
    listBody = CreateFrame("Frame", nil, list)
    listBody:SetWidth(LIST_W)
    list:SetScrollChild(listBody)
    local rule = ns.Solid(frame, "BORDER", T.line, 1)
    rule:SetPoint("TOPLEFT", list, "TOPRIGHT", GAP, 0)
    rule:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", GAP, 0)
    ns.Hairline(rule, "v")
    detail = ns.UI.SlimScroll(frame)
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", GAP * 2 + PAD, 0)
    detail:SetPoint("BOTTOMRIGHT", -PAD, 0)
    body = CreateFrame("Frame", nil, detail)
    detail:SetScrollChild(body)
    frame.empty = ns.Font(frame, TEXT_SIZE, nil, T.muted)
    frame.empty:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
    frame.empty:SetPoint("RIGHT", detail, "RIGHT")
    frame.empty:SetJustifyH("LEFT")
    frame.empty:SetText(TEXT_EMPTY)
    return frame
end

function RunsPage.Layout(width)
    if not frame then return end
    local w = math.max(1, width - LIST_W - GAP * 2 - PAD * 2)
    if w == body:GetWidth() then return end
    body:SetWidth(w)
    if frame:IsShown() then DrawDetail() end
end

function RunsPage.Refresh()
    if not (frame and frame:IsShown()) then return end
    Values()
    picker._refreshLabel()
    if not picked then picked = Ordered()[1] end
    DrawList()
    DrawDetail()
end

function RunsPage.Show(run)
    if run then
        picked = run
        filter = ALL
    end
    RunsPage.Refresh()
end

local function OnRuns(kind)
    if kind ~= "stats" then RunsPage.Refresh() end
end

Runs.OnChange(OnRuns)
