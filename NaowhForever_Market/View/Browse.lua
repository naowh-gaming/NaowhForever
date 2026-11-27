-- Browse.lua: the full window's own auction house search beside Buy and Shopping List: a name and a category, what it finds, and the listings of what you pick with Buy on them (Market.Browse).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Results, Listings, Columns, Searches = Market.Results, Market.Listings, Market.Columns, Market.Searches

local GAP, PANE_GAP, SECTION_GAP, SUB_GAP = St.GAP, 12, 10, 4
local CATEGORY_W, COLUMNS_H = 200, 16
local ROW_H, ROW_ICON, ROW_IN, ICON_GAP = 28, 20, 8, 8
local LOWEST_W, LISTED_W, SCROLL_IN, MORE_ROWS = 120, 70, 4, 10
local NAME_SIZE, NAME_H, LISTED_H, CHART_W = 15, 22, 110, 280
local DETAIL_H = NAME_H + SUB_GAP + LISTED_H
local ALL = "all"
local PATH_JOIN = "."
local NEXT_FRAME = 0
local TOKEN_FLAG = "WOW_TOKEN_FLAG"
local TEXT_SEARCH = ns.L("Search the auction house")
local TEXT_HINT = ns.L("Type a name and press Enter, or pick a category.")
local TEXT_SEARCHING = ns.L("Searching")
local TEXT_NOTHING = ns.L("Nothing found.")
local TEXT_ALL_CATEGORIES = ns.L("All Categories")
local TEXT_ALL = ns.L("All")
local TEXT_PATH = ns.L("%s / %s")
local TEXT_ITEM, TEXT_LOWEST, TEXT_LISTED = ns.L("Item"), ns.L("Lowest"), ns.L("Listed")
local TEXT_PICK = ns.L("Pick an item to see its listings.")

local pane, search, picker, sorter, scroll, list, note, detail, nameText, pickNote, listPane, chart, events
local rows, results = {}, {}
local labels = { [ALL] = TEXT_ALL_CATEGORIES }
local picked = {}
local category = ALL
local active, queued = false, false

local Browse = {}
Market.Browse = Browse

local function KeyLook(itemKey)
    local info = C_AuctionHouse.GetItemKeyInfo(itemKey)
    if not info then return Items.Name(itemKey.itemID), T.fg, nil end
    return info.itemName, ITEM_QUALITY_COLORS[info.quality] or T.fg, info.iconFileID
end

local function SameKey(a, b)
    return a ~= nil and b ~= nil and a.itemID == b.itemID and a.itemLevel == b.itemLevel
        and a.itemSuffix == b.itemSuffix and a.battlePetSpeciesID == b.battlePetSpeciesID
end

local function Focus()
    if picked.itemID then return picked end
end

local function Want()
    local info = C_AuctionHouse.GetItemKeyInfo(picked.itemKey)
    picked.waiting = info == nil
    if not info then return Listings.Want(nil) end
    picked.commodity = info.isCommodity
    Listings.Want(picked)
end

local function RowEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip_SuppressAutomaticCompareItem(GameTooltip)
    local key = row.itemKey
    local link = C_AuctionHouse.GetItemKeySampleLink(key)
    if link then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetItemKey(key.itemID, key.itemLevel, key.itemSuffix, C_AuctionHouse.GetItemKeyRequiredLevel(key))
    end
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function RowClicked(row)
    Browse.Pick(row.itemKey)
end

local function NewRow()
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    Parts.RowBands(row, 0)
    row.picked = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.picked:SetAllPoints()
    row.icon = Parts.ItemIcon(row, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.listed = ns.Font(row, St.TEXT_SIZE, nil, T.muted)
    row.listed:SetPoint("RIGHT", -ROW_IN, 0)
    row.listed:SetWidth(LISTED_W)
    row.listed:SetJustifyH("RIGHT")
    row.lowest = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.lowest:SetPoint("RIGHT", row.listed, "LEFT", -GAP, 0)
    row.lowest:SetWidth(LOWEST_W)
    row.lowest:SetJustifyH("RIGHT")
    row.name = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.lowest, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function PaintRow(row, i)
    local result = results[i]
    local name, color, icon = KeyLook(result.itemKey)
    local moved = row.itemKey ~= result.itemKey
    row.itemKey = result.itemKey
    row.stripe:SetShown(i % 2 == 0)
    row.picked:SetShown(SameKey(picked.itemKey, result.itemKey))
    row.icon.texture:SetTexture(icon or C_Item.GetItemIconByID(result.itemKey.itemID))
    row.name:SetTextColor(color.r, color.g, color.b)
    row.name:SetText(name)
    row.lowest:SetText(Parts.Coins(result.minPrice))
    row.listed:SetText(BreakUpLargeNumbers(result.totalQuantity))
    if moved and GameTooltip:IsOwned(row) then RowEnter(row) end
end

local function DrawRows()
    local first = math.floor(scroll:GetVerticalScroll() / ROW_H) + 1
    local last = math.min(#results, first + math.ceil(scroll:GetHeight() / ROW_H))
    local used = 0
    for i = first, last do
        used = used + 1
        local row = rows[used] or NewRow()
        rows[used] = row
        PaintRow(row, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
    end
    for i = used + 1, #rows do rows[i]:Hide() end
end

local function DrawResults()
    wipe(results)
    for i, result in ipairs(Results.list) do results[i] = result end
    Columns.Sort(sorter, results)
    list:SetHeight(math.max(1, #results * ROW_H))
    DrawRows()
    note:SetShown(#results == 0)
    note:SetText(Results.searching and TEXT_SEARCHING or Results.searched and TEXT_NOTHING or TEXT_HINT)
end

local function DrawPicked()
    local on = picked.itemID ~= nil
    pickNote:SetShown(not on)
    nameText:SetShown(on)
    listPane:SetShown(on)
    chart:SetShown(on)
    if not on then return end
    local name, color = KeyLook(picked.itemKey)
    nameText:SetTextColor(color.r, color.g, color.b)
    nameText:SetText(name)
    listPane:SetHeight(listPane:Paint(picked))
    chart:Paint(picked.itemID)
end

function Browse.Draw()
    if not active then return end
    DrawResults()
    DrawPicked()
end

local function Run()
    local text = search:GetText() or ""
    if text == "" and category == ALL then return end
    local path
    if category ~= ALL then
        path = {}
        for index in category:gmatch("%d+") do path[#path + 1] = tonumber(index) end
    end
    Results.Sent()
    Searches.Run({ text = text, cat = path })
    scroll:SetVerticalScroll(0)
    Browse.Draw()
end

local function IsCategory(key)
    return category == key
end

local function PickCategory(key)
    category = key
    picker._refreshLabel()
    Run()
end

local function GetCategory()
    return category
end

local function AddCategory(menu, c, key, label)
    labels[key] = label
    if not c.subCategories then
        menu:CreateRadio(c.name, IsCategory, PickCategory, key)
        return
    end
    local sub = menu:CreateButton(c.name)
    sub:CreateRadio(TEXT_ALL, IsCategory, PickCategory, key)
    sub:CreateDivider()
    for i, child in ipairs(c.subCategories) do
        AddCategory(sub, child, key .. PATH_JOIN .. i, TEXT_PATH:format(c.name, child.name))
    end
end

local function FillCategories(menu)
    menu:CreateRadio(TEXT_ALL_CATEGORIES, IsCategory, PickCategory, ALL)
    menu:CreateDivider()
    for i, c in ipairs(AuctionCategories) do
        if not c:HasFlag(TOKEN_FLAG) then AddCategory(menu, c, tostring(i), c.name) end
    end
end

local function Scrolled(_, offset)
    DrawRows()
    if offset >= scroll:GetVerticalScrollRange() - MORE_ROWS * ROW_H then Results.More() end
end

local function Later()
    queued = false
    if not active then return end
    if Columns.Current(sorter) == "item" then return Browse.Draw() end
    DrawRows()
    DrawPicked()
end

local function OnEvent(_, _, itemID)
    if picked.waiting and itemID == picked.itemID then Want() end
    if queued then return end
    queued = true
    C_Timer.After(NEXT_FRAME, Later)
end

local function BuildResults()
    search = Parts.SearchBox(pane, TEXT_SEARCH)
    search:SetHeight(St.SEARCH_H)
    search:SetPoint("TOPLEFT")
    search:SetPoint("TOPRIGHT", -(CATEGORY_W + GAP), 0)
    search:HookScript("OnEnterPressed", Run)
    picker = ns.UI.BuildDropdownControl(pane, CATEGORY_W, nil, labels, nil, GetCategory)
    picker._menuFill = FillCategories
    picker:SetPoint("TOPRIGHT")
    picker._refreshLabel()
    local head = CreateFrame("Frame", nil, pane)
    head:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -SECTION_GAP)
    head:SetPoint("RIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    head:SetHeight(COLUMNS_H)
    sorter = Columns.New(head, Market.Settings, "sortBuy", "lowest", Browse.Draw)
    Columns.Add(sorter, { key = "item", text = TEXT_ITEM, left = ROW_IN + ROW_ICON + ICON_GAP, up = true,
        value = function(result) return ns.Lower((KeyLook(result.itemKey)) or "") end })
    Columns.Add(sorter, { key = "lowest", text = TEXT_LOWEST, right = ROW_IN + LISTED_W + GAP, width = LOWEST_W,
        up = true, value = function(result) return result.minPrice end })
    Columns.Add(sorter, { key = "listed", text = TEXT_LISTED, right = ROW_IN, width = LISTED_W,
        value = function(result) return result.totalQuantity end })
    local frame = CreateFrame("Frame", nil, pane)
    frame:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -SUB_GAP)
    frame:SetPoint("BOTTOMRIGHT", detail, "TOPRIGHT", 0, SECTION_GAP)
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
    scroll:HookScript("OnVerticalScroll", Scrolled)
    note = ns.Font(frame, St.TEXT_SIZE, nil, T.muted)
    note:SetPoint("TOP", 0, -SECTION_GAP)
end

local function BuildDetail()
    detail = CreateFrame("Frame", nil, pane)
    detail:SetPoint("BOTTOMLEFT")
    detail:SetPoint("BOTTOMRIGHT")
    detail:SetHeight(DETAIL_H)
    nameText = ns.Font(detail, NAME_SIZE, nil, T.fg, true)
    chart = Market.Chart.New(detail)
    chart:SetPoint("TOPRIGHT")
    chart:SetSize(CHART_W, DETAIL_H)
    nameText:SetPoint("TOPLEFT")
    nameText:SetPoint("RIGHT", chart, "LEFT", -PANE_GAP, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    pickNote = ns.Font(detail, St.TEXT_SIZE, nil, T.muted)
    pickNote:SetPoint("TOPLEFT")
    pickNote:SetText(TEXT_PICK)
    listPane = Market.Listed.New(detail, Browse.Draw, Focus)
    listPane:SetPoint("TOPLEFT", 0, -(NAME_H + SUB_GAP))
    listPane:SetPoint("RIGHT", chart, "LEFT", -PANE_GAP, 0)
end

local function Build()
    pane = CreateFrame("Frame")
    BuildDetail()
    BuildResults()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

function Browse.Pick(itemKey, owner, who)
    if not SameKey(picked.itemKey, itemKey) or picked.owner ~= owner then
        listPane:Close()
        wipe(picked)
        picked.key, picked.itemKey, picked.itemID, picked.link = itemKey.itemID, itemKey, itemKey.itemID, itemKey.itemID
        picked.owner, picked.who = owner, who
        Want()
    end
    Browse.Draw()
end

function Browse.PickItem(itemID, owner, who)
    Browse.Pick(C_AuctionHouse.MakeItemKey(itemID), owner, who)
end

function Browse.Attach(page, column, bought)
    if not pane then Build() end
    pane:SetParent(page)
    pane:ClearAllPoints()
    pane:SetPoint("TOPLEFT", column, "TOPRIGHT", PANE_GAP, 0)
    pane:SetPoint("BOTTOMRIGHT")
    pane:Show()
    listPane.bought = bought
    Market.Listed.Use(listPane)
    if not active then
        active = true
        Results.Start()
        Listings.Start()
        events:RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED")
        if picked.itemID then Want() end
    end
    Results.onChange, Listings.onChange = Browse.Draw, Browse.Draw
    Browse.Draw()
end

function Browse.Detach()
    if not active then return end
    active = false
    pane:Hide()
    listPane:Close()
    Results.Stop()
    Listings.Stop()
    events:UnregisterAllEvents()
end
