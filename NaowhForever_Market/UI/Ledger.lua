-- Ledger.lua: the Ledger page: each character's gold over time with what it earned and spent, and its sales, purchases, other gold and failed auctions as sortable lists.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local C = Market.C
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Ledger, Columns, Chart = Market.Ledger, Market.Columns, Market.Chart

local DAY = C.SECONDS_PER_DAY
local GAP, PANE_GAP, SUB_GAP, IN = St.GAP, 12, 4, 10
local TABS_W, SEARCH_W, CHARACTER_W, RANGE_W, KIND_W = 400, 260, 150, 130, 150
local COMPACT_W = 1000
local COLUMNS_H, ROW_H, ROW_ICON, ROW_IN, ICON_GAP, SCROLL_IN = 20, 24, 18, 8, 6, 4
local CHAR_W, WHO_W, TYPE_W, QTY_W, EACH_W, TOTAL_W, WHEN_W = 110, 140, 96, 50, 100, 110, 90
local CARD_H, CARD_TITLE_H, LINE_H, CARDS, CARD_LINES = 112, 24, 20, 5, 3
local FOOT_H = 20
local SHORT_RANGE = DAY
local TIME_FORMAT, DATE_FORMAT = "%H:%M", "%d %b"
local ALL = ""
local RANGES = {
    ["1d"] = { label = "Last Day", seconds = DAY, points = 25 },
    ["1w"] = { label = "Last Week", seconds = 7 * DAY, points = 29 },
    ["1m"] = { label = "Last 30 Days", seconds = 30 * DAY, points = 31 },
    ["3m"] = { label = "Last 3 Months", seconds = 91 * DAY, points = 46 },
    ["6m"] = { label = "Last 6 Months", seconds = 182 * DAY, points = 53 },
    ["1y"] = { label = "Last Year", seconds = 365 * DAY, points = 53 },
    all = { label = "All Time", points = 60 },
}
local RANGE_ORDER = { "1d", "1w", "1m", "3m", "6m", "1y", "all" }
local VIEWS = {
    { key = "summary", label = "Summary", tip = "Your gold over time, and what you earned and spent." },
    { key = "sales", label = "Sales", tip = "What you sold, at the auction house and to vendors." },
    { key = "purchases", label = "Purchases", tip = "What you bought, at the auction house and from vendors." },
    { key = "other", label = "Other", tip = "Gold from quests, loot and mail, and gold spent on repairs, fees and travel." },
    { key = "failed", label = "Failed", tip = "Your auctions that came back by mail, expired or cancelled." },
}
local KINDS = {
    auction = ns.L("Auction"), vendor = ns.L("Vendor"), quest = ns.L("Quest"), loot = ns.L("Loot"),
    mail = ns.L("Mail"), trade = ns.L("Trade"), repair = ns.L("Repair"), deposit = ns.L("Auction Fees"),
    postage = ns.L("Postage"), flight = ns.L("Flight"), training = ns.L("Training"), other = ns.L("Other"),
    expired = ns.L("Expired"), cancelled = ns.L("Cancelled"),
}
local KIND_ORDER = { "auction", "vendor", "trade", "quest", "loot", "mail", "repair", "deposit", "postage", "flight",
    "training", "other", "expired", "cancelled" }
local KIND_KEYS = { sales = "ledgerKindSales", purchases = "ledgerKindPurchases", other = "ledgerKindOther",
    failed = "ledgerKindFailed" }
local TEXT_ALL_CHARACTERS = ns.L("All Characters")
local TEXT_ALL_TYPES = ns.L("All Types")
local TEXT_FILTER = ns.L("Filter by item or name")
local TEXT_GOLD = ns.L("Gold")
local TEXT_NO_GOLD = ns.L("Your gold shows here once the Ledger has seen it change.")
local TEXT_CHANGE = ns.L("Last day %s%s")
local TEXT_UP, TEXT_DOWN = "+", "-"
local TEXT_ITEM, TEXT_CHARACTER, TEXT_WHO, TEXT_TYPE = ns.L("Item"), ns.L("Character"), ns.L("From / To"), ns.L("Type")
local TEXT_QTY, TEXT_EACH, TEXT_TOTAL, TEXT_WHEN = ns.L("Qty"), ns.L("Per Item"), ns.L("Total"), ns.L("When")
local TEXT_SALES, TEXT_PURCHASES, TEXT_OTHER, TEXT_PROFIT = ns.L("Sales"), ns.L("Purchases"), ns.L("Other"),
    ns.L("Profit")
local TEXT_TOTAL_LINE, TEXT_PER_DAY, TEXT_TOP = ns.L("Total"), ns.L("Per Day"), ns.L("Top Item")
local TEXT_EARNED, TEXT_SPENT = ns.L("Earned"), ns.L("Spent")
local TEXT_NOW, TEXT_HIGH, TEXT_LOW = ns.L("Now"), ns.L("High"), ns.L("Low")
local TEXT_NONE_ITEM = "-"
local TEXT_SOLD_FOOT = ns.L("%s items sold for %s")
local TEXT_BOUGHT_FOOT = ns.L("%s items bought for %s")
local TEXT_OTHER_FOOT = ns.L("Earned %s, spent %s")
local TEXT_FAILED_FOOT = ns.L("%s items came back")
local TEXT_EMPTY = ns.L("Nothing here for these characters in this time.")
local TEXT_EMPTY_KIND = ns.L("None of this type here: pick All Types to see the rest.")
local TEXT_OFF = ns.L("The Ledger is off: turn it on in The Market's settings to record what you earn and spend.")

local page, views, search, kindPick, characterPick, rangePick, summary, listPane, chart, scroll, list, note, sorter
local footLeft, footRight, whoColumn, characterColumn
local cards = {}
local rows, shownRows, chars, all, series = {}, {}, {}, {}, {}
local characterLabels, characterOrder = { [ALL] = TEXT_ALL_CHARACTERS }, { ALL }
local rangeLabels = {}
local kindLabels, kindOrder, seenKinds = { [ALL] = TEXT_ALL_TYPES }, { ALL }, {}
local asked, ask = {}, {}
local active, queued, compact = false, false, false
local wanted, kindWanted = "", ALL
local chartFrom, chartStep = 0, 0

local Page = {}
Market.Pages.ledger = Page

for key, range in pairs(RANGES) do rangeLabels[key] = range.label end
for key, label in pairs(KINDS) do kindLabels[key] = label end

local function Span()
    local range = RANGES[S.Get("ledgerRange")] or RANGES["1m"]
    local now = time()
    if range.seconds then return now - range.seconds, now, range end
    return Ledger.First(chars) or now - DAY, now, range
end

local function Days(from, to)
    return math.max(1, math.ceil((to - from) / DAY))
end

local function Picked()
    wipe(chars)
    local want = S.Get("ledgerCharacter")
    for _, char in ipairs(all) do
        if want == ALL or char.guid == want then chars[#chars + 1] = char end
    end
end

local function ByName(a, b)
    return (a.data.name or "") < (b.data.name or "")
end

local function ReadCharacters()
    Ledger.Characters(all)
    table.sort(all, ByName)
    wipe(characterOrder)
    characterOrder[1] = ALL
    for _, char in ipairs(all) do
        characterOrder[#characterOrder + 1] = char.guid
        characterLabels[char.guid] = char.data.name or char.guid
    end
    if not characterLabels[S.Get("ledgerCharacter")] then S.Set("ledgerCharacter", ALL) end
    characterPick._refreshLabel()
    Picked()
end

local function ItemName(item)
    if type(item) == "string" then return item end
    if item == 0 then return nil end
    return Items.Name(item)
end

local function Later()
    queued = false
    Page.Draw()
end

local function Changed()
    if queued or not active then return end
    queued = true
    C_Timer.After(0, Later)
end

local function Flush()
    if #ask == 0 then return end
    Items.OnLoaded(ask, Changed)
    wipe(ask)
end

local function Want(item)
    if type(item) ~= "number" or item == 0 or asked[item] then return end
    asked[item] = true
    ask[#ask + 1] = item
end

local function ItemText(item)
    Want(item)
    local name = ItemName(item)
    if not name then return TEXT_NONE_ITEM end
    if type(item) == "number" then return Items.QualityHex(item) .. name .. "|r" end
    return name
end

local function Signed(copper)
    local tint = copper < 0 and St.RED_RGB or St.HAVE_RGB
    return ns.Color(tint, (copper < 0 and TEXT_DOWN or "") .. Parts.Coins(math.abs(copper)))
end

local function ChartLabel(_, i)
    local when = chartFrom + (i - 1) * chartStep
    return date(chartStep * (#series - 1) <= SHORT_RANGE and TIME_FORMAT or DATE_FORMAT, when)
end

local function DrawCard(card, lines)
    for i, line in ipairs(card.lines) do
        local entry = lines[i]
        line.label:SetText(entry and entry[1] or "")
        line.value:SetText(entry and entry[2] or "")
    end
end

local function GoldStats(to)
    local now, high, low
    for _, gold in ipairs(series) do
        if gold then
            now = gold
            high, low = math.max(high or gold, gold), math.min(low or gold, gold)
        end
    end
    local change = Ledger.Change(chars, to - DAY, to)
    return now, high, low, change
end

local function DrawSummary()
    local from, to, range = Span()
    chartFrom, chartStep = from, (to - from) / (range.points - 1)
    Ledger.Gold(chars, from, to, range.points, series)
    local now, high, low, change = GoldStats(to)
    local status = change and TEXT_CHANGE:format(change < 0 and TEXT_DOWN or TEXT_UP, Parts.Coins(math.abs(change)))
    Chart.PaintSeries(chart, series, ChartLabel, status, change and (change < 0 and St.RED_RGB or St.HAVE_RGB))
    local sum, days = Ledger.Summary(chars, from), Days(from, to)
    DrawCard(cards[1], { { TEXT_TOTAL_LINE, Parts.Coins(sum.sales) }, { TEXT_PER_DAY, Parts.Coins(math.floor(sum.sales / days)) },
        { TEXT_TOP, sum.topSale and ItemText(sum.topSale) or TEXT_NONE_ITEM } })
    DrawCard(cards[2], { { TEXT_TOTAL_LINE, Parts.Coins(sum.purchases) },
        { TEXT_PER_DAY, Parts.Coins(math.floor(sum.purchases / days)) },
        { TEXT_TOP, sum.topPurchase and ItemText(sum.topPurchase) or TEXT_NONE_ITEM } })
    DrawCard(cards[3], { { TEXT_EARNED, Parts.Coins(sum.otherIn) }, { TEXT_SPENT, Parts.Coins(sum.otherOut) } })
    local profit = sum.earned - sum.spent
    DrawCard(cards[4], { { TEXT_TOTAL_LINE, Signed(profit) }, { TEXT_PER_DAY, Signed(math.floor(profit / days)) } })
    DrawCard(cards[5], { { TEXT_NOW, now and Parts.Coins(now) or TEXT_NONE_ITEM },
        { TEXT_HIGH, high and Parts.Coins(high) or TEXT_NONE_ITEM }, { TEXT_LOW, low and Parts.Coins(low) or TEXT_NONE_ITEM } })
end

local function RowData(row)
    return Ledger.Row(chars, row)
end

local function Matches(data, i)
    local kind = data.kind[i]
    if kindWanted ~= ALL and kind ~= kindWanted and seenKinds[kind] then return false end
    if wanted ~= "" then
        local name = ItemName(data.item[i]) or KINDS[kind] or ""
        if not (ns.Lower(name):find(wanted, 1, true) or ns.Lower(data.who[i]):find(wanted, 1, true)) then return false end
    end
    seenKinds[kind] = true
    return kindWanted == ALL or kind == kindWanted
end

local function ListKinds()
    wipe(kindOrder)
    kindOrder[1] = ALL
    for _, kind in ipairs(KIND_ORDER) do
        if seenKinds[kind] or kind == kindWanted then kindOrder[#kindOrder + 1] = kind end
    end
    kindPick._refreshLabel()
end

local function PerItem(data, i)
    local qty = data.qty[i]
    if qty <= 0 then return nil end
    return math.floor(math.abs(data.amount[i]) / qty)
end

local function RowEnter(row)
    row.hover:Show()
    if type(row.item) ~= "number" or row.item == 0 then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.item)
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function Cell(row, width, color)
    local text = ns.Font(row, St.TEXT_SIZE, nil, color)
    text:SetWidth(width)
    text:SetJustifyH("RIGHT")
    text:SetWordWrap(false)
    return text
end

local function Lay(row)
    row.who:SetShown(not compact)
    row.char:SetShown(not compact)
    row.name:SetPoint("RIGHT", compact and row.kind or row.char, "LEFT", -GAP, 0)
end

local function NewRow()
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)
    Parts.RowBands(row, 0)
    row.icon = Parts.ItemIcon(row, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.when = Cell(row, WHEN_W, T.muted)
    row.when:SetPoint("RIGHT", -ROW_IN, 0)
    row.total = Cell(row, TOTAL_W, T.fg)
    row.total:SetPoint("RIGHT", row.when, "LEFT", -GAP, 0)
    row.each = Cell(row, EACH_W, T.fg)
    row.each:SetPoint("RIGHT", row.total, "LEFT", -GAP, 0)
    row.qty = Cell(row, QTY_W, T.fg)
    row.qty:SetPoint("RIGHT", row.each, "LEFT", -GAP, 0)
    row.kind = Cell(row, TYPE_W, T.muted)
    row.kind:SetPoint("RIGHT", row.qty, "LEFT", -GAP, 0)
    row.who = Cell(row, WHO_W, T.muted)
    row.who:SetPoint("RIGHT", row.kind, "LEFT", -GAP, 0)
    row.char = Cell(row, CHAR_W, T.muted)
    row.char:SetPoint("RIGHT", row.who, "LEFT", -GAP, 0)
    row.name = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.char, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    Lay(row)
    return row
end

local function PaintRow(row, n)
    local data, i, char = RowData(shownRows[n])
    local item, kind, amount = data.item[i], data.kind[i], data.amount[i]
    row.item = item
    row.stripe:SetShown(n % 2 == 0)
    row.icon:SetShown(type(item) == "number" and item ~= 0)
    if row.icon:IsShown() then row.icon.texture:SetTexture(C_Item.GetItemIconByID(item)) end
    row.name:SetText(ItemName(item) and ItemText(item) or KINDS[kind] or kind)
    row.char:SetText(char.data.name or "")
    row.who:SetText(data.who[i])
    row.kind:SetText(KINDS[kind] or kind)
    row.qty:SetText(data.qty[i] > 0 and BreakUpLargeNumbers(data.qty[i]) or "")
    local each = PerItem(data, i)
    row.each:SetText(each and amount ~= 0 and Parts.Coins(each) or "")
    row.total:SetText(amount == 0 and "" or S.Get("ledgerView") == "other" and Signed(amount)
        or Parts.Coins(math.abs(amount)))
    row.when:SetText(ns.Shared.Ago(data.at[i]))
end

local function DrawRows()
    if not scroll:IsVisible() then return end
    local first = math.floor(scroll:GetVerticalScroll() / ROW_H) + 1
    local last = math.min(#shownRows, first + math.ceil(scroll:GetHeight() / ROW_H))
    local used = 0
    for n = first, last do
        used = used + 1
        local row = rows[used] or NewRow()
        rows[used] = row
        PaintRow(row, n)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(n - 1) * ROW_H)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
    end
    for n = used + 1, #rows do rows[n]:Hide() end
    Flush()
end

local function Foot(view)
    local qty, earned, spent = 0, 0, 0
    for _, row in ipairs(shownRows) do
        local data, i = RowData(row)
        local amount = data.amount[i]
        qty = qty + data.qty[i]
        if amount > 0 then earned = earned + amount else spent = spent - amount end
    end
    if view == "sales" then return TEXT_SOLD_FOOT:format(BreakUpLargeNumbers(qty), Parts.Coins(earned)) end
    if view == "purchases" then return TEXT_BOUGHT_FOOT:format(BreakUpLargeNumbers(qty), Parts.Coins(spent)) end
    if view == "other" then return TEXT_OTHER_FOOT:format(Parts.Coins(earned), Parts.Coins(spent)) end
    return TEXT_FAILED_FOOT:format(BreakUpLargeNumbers(qty))
end

local function DrawList(view)
    local from = Span()
    kindWanted = S.Get(KIND_KEYS[view])
    wipe(seenKinds)
    Ledger.Collect(shownRows, chars, view, from, Matches)
    ListKinds()
    Columns.Sort(sorter, shownRows)
    list:SetHeight(math.max(1, #shownRows * ROW_H))
    DrawRows()
    note:SetShown(#shownRows == 0)
    note:SetText(kindWanted == ALL and TEXT_EMPTY or TEXT_EMPTY_KIND)
    footLeft:SetText(Foot(view))
end

function Page.Draw()
    if not active then return end
    local view = S.Get("ledgerView")
    Parts.PaintTabs(views, view)
    rangePick._refreshLabel()
    local listed = view ~= "summary"
    summary:SetShown(not listed)
    listPane:SetShown(listed)
    footLeft:SetShown(listed)
    footRight:SetShown(not Ledger.On())
    if listed then DrawList(view) else DrawSummary() end
    Flush()
end

local function ShowView(key)
    S.Set("ledgerView", key)
    scroll:SetVerticalScroll(0)
    Page.Draw()
end

local function OnFilter(text)
    wanted = ns.Lower(strtrim(text))
    scroll:SetVerticalScroll(0)
    Page.Draw()
end

local function PickCharacter(key)
    S.Set("ledgerCharacter", key)
    Picked()
    Page.Draw()
end

local function PickKind(key)
    S.Set(KIND_KEYS[S.Get("ledgerView")], key)
    scroll:SetVerticalScroll(0)
    Page.Draw()
end

local function GetKind() return kindWanted end

local function PickRange(key)
    S.Set("ledgerRange", key)
    Page.Draw()
end

local function GetCharacter() return S.Get("ledgerCharacter") end
local function GetRange() return S.Get("ledgerRange") end

local function SortValue(read)
    return function(row)
        local data, i, char = RowData(row)
        return read(data, i, char)
    end
end

local function NewCard(parent, title)
    local card = CreateFrame("Frame", nil, parent)
    card:SetHeight(CARD_H)
    ns.Solid(card, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(card, St.BORDER_RGB)
    local head = ns.Font(card, St.SMALL_SIZE, nil, T.muted)
    head:SetPoint("TOPLEFT", IN, -(CARD_TITLE_H - St.SMALL_SIZE) / 2)
    head:SetText(title)
    card.lines = {}
    for i = 1, CARD_LINES do
        local y = -(CARD_TITLE_H + (i - 1) * LINE_H)
        local label = ns.Font(card, St.TEXT_SIZE, nil, T.muted)
        label:SetPoint("TOPLEFT", IN, y)
        local value = ns.Font(card, St.TEXT_SIZE, nil, T.fg)
        value:SetPoint("TOPRIGHT", -IN, y)
        value:SetPoint("LEFT", label, "RIGHT", GAP, 0)
        value:SetJustifyH("RIGHT")
        value:SetWordWrap(false)
        card.lines[i] = { label = label, value = value }
    end
    return card
end

local function BuildSummary(top)
    summary = CreateFrame("Frame", nil, page)
    summary:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -PANE_GAP)
    summary:SetPoint("BOTTOMRIGHT", 0, FOOT_H + SUB_GAP)
    local titles = { TEXT_SALES, TEXT_PURCHASES, TEXT_OTHER, TEXT_PROFIT, TEXT_GOLD }
    for i = 1, CARDS do
        local card = NewCard(summary, titles[i])
        if i == 1 then
            card:SetPoint("BOTTOMLEFT")
        else
            card:SetPoint("LEFT", cards[i - 1], "RIGHT", PANE_GAP, 0)
        end
        cards[i] = card
    end
    summary:SetScript("OnSizeChanged", function(_, width)
        local cardW = (width - PANE_GAP * (CARDS - 1)) / CARDS
        for _, card in ipairs(cards) do card:SetWidth(cardW) end
    end)
    chart = Chart.New(summary, TEXT_GOLD, TEXT_NO_GOLD)
    chart:SetPoint("TOPLEFT")
    chart:SetPoint("BOTTOMRIGHT", 0, CARD_H + PANE_GAP)
end

local function BuildColumns(head)
    sorter = Columns.New(head, S, "sortLedger", "when", Page.Draw)
    local right = ROW_IN
    local function Right(width)
        local at = right
        right = right + width + GAP
        return at
    end
    Columns.Add(sorter, { key = "when", text = TEXT_WHEN, right = Right(WHEN_W), width = WHEN_W,
        value = SortValue(function(data, i) return data.at[i] end) })
    Columns.Add(sorter, { key = "total", text = TEXT_TOTAL, right = Right(TOTAL_W), width = TOTAL_W,
        value = SortValue(function(data, i) return math.abs(data.amount[i]) end) })
    Columns.Add(sorter, { key = "each", text = TEXT_EACH, right = Right(EACH_W), width = EACH_W,
        value = SortValue(PerItem) })
    Columns.Add(sorter, { key = "qty", text = TEXT_QTY, right = Right(QTY_W), width = QTY_W,
        value = SortValue(function(data, i) return data.qty[i] end) })
    Columns.Add(sorter, { key = "type", text = TEXT_TYPE, right = Right(TYPE_W), width = TYPE_W, up = true,
        value = SortValue(function(data, i) return KINDS[data.kind[i]] or data.kind[i] end) })
    whoColumn = Columns.Add(sorter, { key = "who", text = TEXT_WHO, right = Right(WHO_W), width = WHO_W, up = true,
        value = SortValue(function(data, i) return ns.Lower(data.who[i]) end) })
    characterColumn = Columns.Add(sorter, { key = "character", text = TEXT_CHARACTER, right = Right(CHAR_W), width = CHAR_W, up = true,
        value = SortValue(function(_, _, char) return char.data.name or "" end) })
    Columns.Add(sorter, { key = "item", text = TEXT_ITEM, left = ROW_IN + ROW_ICON + ICON_GAP, up = true,
        value = SortValue(function(data, i) return ns.Lower(ItemName(data.item[i]) or KINDS[data.kind[i]] or "") end) })
end

local function BuildList(top)
    listPane = CreateFrame("Frame", nil, page)
    listPane:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -PANE_GAP)
    listPane:SetPoint("BOTTOMRIGHT", 0, FOOT_H + SUB_GAP)
    search = Parts.SearchBox(listPane, TEXT_FILTER, OnFilter)
    search:SetSize(SEARCH_W, St.SEARCH_H)
    search:SetPoint("TOPLEFT")
    kindPick = ns.UI.BuildDropdownControl(listPane, KIND_W, nil, kindLabels, kindOrder, GetKind, PickKind)
    kindPick:SetPoint("LEFT", search, "RIGHT", GAP, 0)
    local head = CreateFrame("Frame", nil, listPane)
    head:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -PANE_GAP)
    head:SetPoint("RIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    head:SetHeight(COLUMNS_H)
    BuildColumns(head)
    local frame = CreateFrame("Frame", nil, listPane)
    frame:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -SUB_GAP)
    frame:SetPoint("BOTTOMRIGHT")
    ns.Solid(frame, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(frame, St.BORDER_RGB)
    scroll = ns.UI.SlimScroll(frame)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetHeight(1)
    scroll:SetScrollChild(list)
    scroll:HookScript("OnSizeChanged", function(_, width)
        list:SetWidth(width)
        DrawRows()
    end)
    scroll:HookScript("OnVerticalScroll", DrawRows)
    note = ns.Font(frame, St.TEXT_SIZE, nil, T.muted)
    note:SetPoint("TOP", 0, -PANE_GAP)
end

local function BuildBar()
    views = Parts.Tabs(page, TABS_W, VIEWS, ShowView, true)
    views:SetPoint("TOPLEFT")
    rangePick = ns.UI.BuildDropdownControl(page, RANGE_W, nil, rangeLabels, RANGE_ORDER, GetRange, PickRange)
    rangePick:SetPoint("RIGHT", page, "TOPRIGHT", 0, -St.TAB_H / 2)
    characterPick = ns.UI.BuildDropdownControl(page, CHARACTER_W, nil, characterLabels, characterOrder, GetCharacter,
        PickCharacter)
    characterPick:SetPoint("RIGHT", rangePick, "LEFT", -GAP, 0)
    return views
end

local function Fit(_, width)
    local narrow = width < COMPACT_W
    if narrow == compact then return end
    compact = narrow
    whoColumn.button:SetShown(not compact)
    characterColumn.button:SetShown(not compact)
    for _, row in ipairs(rows) do Lay(row) end
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:SetScript("OnSizeChanged", Fit)
    local top = BuildBar()
    BuildSummary(top)
    BuildList(top)
    footLeft = ns.Font(page, St.SMALL_SIZE, nil, T.muted)
    footLeft:SetPoint("BOTTOMLEFT", 0, (FOOT_H - St.SMALL_SIZE) / 2)
    footRight = ns.Font(page, St.SMALL_SIZE, nil, St.WARN_RGB)
    footRight:SetPoint("BOTTOMRIGHT", 0, (FOOT_H - St.SMALL_SIZE) / 2)
    footRight:SetText(TEXT_OFF)
end

function Page.Show()
    page:Show()
    active = true
    Ledger.onChange = Changed
    ReadCharacters()
    Page.Draw()
end

function Page.Refresh()
    Page.Draw()
end

function Page.Hide()
    page:Hide()
    active = false
    Ledger.onChange = nil
end
