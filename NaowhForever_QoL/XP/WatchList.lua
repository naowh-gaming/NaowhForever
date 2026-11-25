-- WatchList.lua: Watch List, a small window of the reputations, currencies and items you pick to watch.
local ns = _G.NaowhForever

local GetFactionDataByID = C_Reputation.GetFactionDataByID
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local GetItemCount = C_Item.GetItemCount
local GetItemIconByID = C_Item.GetItemIconByID

local T = ns.THEME
local S = ns.QoLSettings
local UI = ns.UI
local Parts = ns.Shared.Parts
local St = ns.Shared.Style
local Items = ns.Shared.Items

local MAX_HEIGHT = 420
local WIDTH = St.TRACKER_W
local NEXT_FRAME = 0
local EXALTED = 8
local PLACE = { "RIGHT", "RIGHT", -260, -120 }
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/XP", "watchList"
local KEY = "^(%a):(%d+)$"
local FACTION, CURRENCY, ITEM = "f", "c", "i"
local EVENTS = { "UPDATE_FACTION", "CURRENCY_DISPLAY_UPDATE" }
local ITEM_EVENTS = { "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED" }
local STANDING_LABEL = "FACTION_STANDING_LABEL"
local TEXT_TITLE = ns.L("WATCH LIST")
local TEXT_NAME = "Watch List"
local TEXT_PICK_HINT = ns.L("Click to pick reputations, currencies and items to watch.")
local TEXT_REPUTATIONS = ns.L("Reputations")
local TEXT_CURRENCIES = ns.L("Currencies")
local TEXT_ADD_ITEM = ns.L("Add an Item...")
local TEXT_NONE = ns.L("None yet")
local TEXT_COLLAPSED = ns.L("%s (collapsed)")
local TEXT_COLLAPSED_TIP = ns.L("Open this header in the game's window to list what is under it.")
local TEXT_ITEM_PROMPT = "Type an item ID, or paste an item link or a Wowhead item link."
local TEXT_NOT_ITEM = ns.L("Not an item ID yet.")
local TEXT_ADD = "Add"
local TEXT_EMPTY = ns.L("Nothing watched yet.")
local TEXT_EMPTY_SUB = ns.L("Click here or the title to pick what to watch.")
local TEXT_STANDING = ns.L("%s  %s / %s")
local TEXT_OF_MAX = ns.L("%s / %s")
local TEXT_IN_BANK = ns.L("%s  (%s in bank)")
local TEXT_ICON_NAME = "|T%s:0|t %s"
local TEXT_UNKNOWN = ns.L("Unknown (%s)")
local TEXT_MOVE_UP = ns.L("Move Up")
local TEXT_MOVE_DOWN = ns.L("Move Down")
local TEXT_STOP = ns.L("Stop Watching")
local TEXT_ROW_HINT = ns.L("Right-click to move it or stop watching it.")
local TEXT_ITEM_HINT = ns.L("Shift-click to link it, right-click to move it or stop watching it.")

local panel, events, unlocked, closed, queued
local entries, pool = {}, {}
local labels = {}
local loading = {}

local function On()
    return S.Get("enabled") and S.Get("watchList")
end

local function Keys()
    return S.Get("watchListItems")
end

local function IndexOf(key)
    local keys = Keys()
    for i = 1, #keys do
        if keys[i] == key then return i end
    end
end

local function IsWatched(key)
    return IndexOf(key) ~= nil
end

local function Toggle(key)
    local keys = CopyTable(Keys())
    local i = IndexOf(key)
    if i then table.remove(keys, i) else keys[#keys + 1] = key end
    S.Set("watchListItems", keys)
end

local function Move(key, by)
    local keys = CopyTable(Keys())
    local i = IndexOf(key)
    local j = i and i + by
    if not (j and keys[j]) then return end
    keys[i], keys[j] = keys[j], keys[i]
    S.Set("watchListItems", keys)
end

local function HasItems()
    local keys = Keys()
    for i = 1, #keys do
        if keys[i]:match(KEY) == ITEM then return true end
    end
    return false
end

local function StandingLabel(reaction)
    local label = labels[reaction]
    if label then return label end
    label = GetText(STANDING_LABEL .. reaction, UnitSex("player")) or tostring(reaction)
    labels[reaction] = label
    return label
end

local function Number(n)
    return BreakUpLargeNumbers(n)
end

local function FillFaction(entry, id, bars)
    local data = GetFactionDataByID(id)
    if not (data and data.name and data.reaction) then
        entry.text, entry.sub, entry.color = TEXT_UNKNOWN:format(id), nil, T.muted
        return
    end
    local reaction = data.reaction
    entry.text, entry.color = data.name, St.STANDING_RGB[reaction]
    entry.barColor = entry.color
    if reaction >= EXALTED then
        entry.sub = StandingLabel(reaction)
        if bars then entry.bar = 1 end
        return
    end
    local low = data.currentReactionThreshold or 0
    local span = math.max(1, (data.nextReactionThreshold or low + 1) - low)
    local done = data.currentStanding - low
    entry.sub = TEXT_STANDING:format(StandingLabel(reaction), Number(done), Number(span))
    if bars then entry.bar = done / span end
end

local function FillCurrency(entry, id, bars)
    local info = GetCurrencyInfo(id)
    if not (info and info.name and info.name ~= "") then
        entry.text, entry.sub, entry.color = TEXT_UNKNOWN:format(id), nil, T.muted
        return
    end
    entry.text, entry.color = TEXT_ICON_NAME:format(info.iconFileID, info.name), nil
    local quantity = info.quantity or 0
    local max = info.maxQuantity or 0
    entry.sub = max > 0 and TEXT_OF_MAX:format(Number(quantity), Number(max)) or Number(quantity)
    if bars and max > 0 then entry.bar = quantity / max end
end

local function FillItem(entry, id)
    local icon = GetItemIconByID(id)
    local name = Items.Name(id)
    entry.text = icon and TEXT_ICON_NAME:format(icon, name) or name
    entry.color = Items.QualityColor(id)
    local bags, bank = GetItemCount(id), ns.BankCount(id)
    entry.sub = bank > 0 and TEXT_IN_BANK:format(Number(bags + bank), Number(bank)) or Number(bags)
end

local Render, Pick

local function Redraw()
    if panel and panel:IsShown() then Render() end
end

local function WatchTip(row)
    local entry = row.entry
    if entry.kind == ITEM then
        GameTooltip:SetItemByID(entry.id)
        GameTooltip:AddLine(TEXT_ITEM_HINT, T.muted.r, T.muted.g, T.muted.b, true)
        return
    end
    GameTooltip:SetText(entry.text, 1, 1, 1)
    if entry.sub then GameTooltip:AddLine(entry.sub, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:AddLine(TEXT_ROW_HINT, T.muted.r, T.muted.g, T.muted.b, true)
end

local function MoveUp(key) Move(key, -1) end
local function MoveDown(key) Move(key, 1) end

local function RowMenu(row, root)
    local key = row.entry.key
    local i, n = IndexOf(key), #Keys()
    root:CreateButton(TEXT_MOVE_UP, MoveUp, key):SetEnabled(i ~= nil and i > 1)
    root:CreateButton(TEXT_MOVE_DOWN, MoveDown, key):SetEnabled(i ~= nil and i < n)
    root:CreateButton(TEXT_STOP, Toggle, key)
end

local function WatchClick(row, button)
    local entry = row.entry
    if button == "RightButton" then
        ns.ContextMenu(row, RowMenu)
        return
    end
    if entry.kind == ITEM and IsModifiedClick() then
        local _, link = C_Item.GetItemInfo(entry.id)
        if link then HandleModifiedItemClick(link) end
    end
end

local function EmptyClick()
    Pick()
end

local function Entry(n)
    local entry = pool[n] or {}
    pool[n] = entry
    entries[n] = entry
    return entry
end

local function AddEmpty()
    local entry = Entry(1)
    entry.key, entry.kind, entry.id = nil, nil, nil
    entry.text, entry.sub, entry.color = TEXT_EMPTY, TEXT_EMPTY_SUB, T.muted
    entry.tip, entry.click = nil, EmptyClick
    entry.bar, entry.barColor = nil, nil
    return 1
end

function Render()
    local keys, n = Keys(), 0
    local bars = S.Get("watchListBars")
    for i = 1, #keys do
        local kind, id = keys[i]:match(KEY)
        id = tonumber(id)
        if id then
            n = n + 1
            local entry = Entry(n)
            entry.key, entry.kind, entry.id = keys[i], kind, id
            entry.tip, entry.click = WatchTip, WatchClick
            entry.bar, entry.barColor = nil, nil
            if kind == FACTION then FillFaction(entry, id, bars)
            elseif kind == CURRENCY then FillCurrency(entry, id, bars)
            else FillItem(entry, id) end
        end
    end
    if n == 0 then n = AddEmpty() end
    for i = n + 1, #entries do entries[i] = nil end
    if panel:Fit(panel:SetRows(entries)) then
        panel:SetTrackerWidth(WIDTH)
        C_Timer.After(NEXT_FRAME, Redraw)
    end
end

local function CollapsedTip(tooltip)
    tooltip:SetText(TEXT_COLLAPSED_TIP, 1, 1, 1, 1, true)
end

local function Header(menu, name, collapsed)
    if collapsed then
        menu:CreateTitle(TEXT_COLLAPSED:format(name)):SetTooltip(CollapsedTip)
    else
        menu:CreateTitle(name)
    end
end

local function FactionList(menu)
    for i = 1, C_Reputation.GetNumFactions() do
        local data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.name then
            if data.isHeader and not data.isHeaderWithRep then
                Header(menu, data.name, data.isCollapsed)
            else
                menu:CreateCheckbox(data.name, IsWatched, Toggle, FACTION .. ":" .. data.factionID)
            end
        end
    end
    if #menu.children == 0 then menu:CreateTitle(TEXT_NONE) end
end

local function CurrencyList(menu)
    for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.name then
            if info.isHeader then
                Header(menu, info.name, not info.isHeaderExpanded)
            else
                menu:CreateCheckbox(info.name, IsWatched, Toggle, CURRENCY .. ":" .. info.currencyID)
            end
        end
    end
    if #menu.children == 0 then menu:CreateTitle(TEXT_NONE) end
end

local function TypedItem(value)
    local id = Items.IDFrom(value)
    if not id then return TEXT_NOT_ITEM end
    return Items.Name(id)
end

local function AddItem(value)
    local id = Items.IDFrom(value)
    if not id then return end
    local key = ITEM .. ":" .. id
    if not IsWatched(key) then Toggle(key) end
end

local function PromptItem()
    ns.PromptText(TEXT_ITEM_PROMPT, "", nil, AddItem, TEXT_ADD, nil, TypedItem)
end

local function PickerMenu(_, root)
    root:CreateTitle(ns.L(TEXT_NAME))
    FactionList(root:CreateButton(TEXT_REPUTATIONS))
    CurrencyList(root:CreateButton(TEXT_CURRENCIES))
    root:CreateButton(TEXT_ADD_ITEM, PromptItem)
end

function Pick()
    ns.ContextMenu(panel.titleButton, PickerMenu)
end

local function WaitForItems()
    local keys = Keys()
    wipe(loading)
    for i = 1, #keys do
        local kind, id = keys[i]:match(KEY)
        if kind == ITEM then loading[#loading + 1] = tonumber(id) end
    end
    Items.OnLoaded(loading, Redraw)
end

local function LoadPosition()
    local pos = S.Get("watchListPos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("watchListPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(frame, onMoved)
    return UI.AttachMover(frame, TEXT_NAME, onMoved, SETTINGS_PAGE, SETTINGS_PAGE .. ":" .. SETTINGS_CARD)
end

local function Locked()
    return S.Get("watchListLock")
end

local function Close()
    closed = true
    panel:Hide()
end

local function Build()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        onTitle = Pick, titleTip = TEXT_NAME, titleHint = TEXT_PICK_HINT,
        onClose = Close,
        load = LoadPosition, save = SavePosition, place = PLACE,
        mover = Mover, locked = Locked,
        maxHeight = function() return MAX_HEIGHT end,
    })
    panel:SetScale(S.Get("watchListScale"))
    panel:Place()
    panel:Paint()
    panel:Hide()
end

local function Refresh()
    if not On() or (closed and not unlocked) then
        if panel then panel:Hide() end
        return
    end
    if not panel then Build() end
    Render()
    panel.mover:SetShown(unlocked == true)
    panel:Show()
end

local function QueuedRefresh()
    queued = false
    Redraw()
end

local function OnEvent()
    if queued then return end
    queued = true
    C_Timer.After(NEXT_FRAME, QueuedRefresh)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return Refresh()
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:UnregisterAllEvents()
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if HasItems() then
        for _, event in ipairs(ITEM_EVENTS) do events:RegisterEvent(event) end
        WaitForItems()
    end
    if panel then
        panel:SetScale(S.Get("watchListScale"))
        panel:Place()
    end
    Refresh()
end

local function OnSettingChanged(key, value)
    if key == "watchListScale" and panel then panel:SetScale(value) end
    if key == "watchList" then closed = nil end
    if key == "watchListBars" then Redraw() end
    if key == "enabled" or key == "watchList" or key == "watchListItems" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
ns.OnApply(Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Refresh()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Refresh()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/XP", S):Card({
    id = "watchList", name = "Watch List", order = 40, switch = "watchList",
    help = "A small window of the reputations, currencies and items you pick to watch.",
    rows = {
        { key = "watchListScale", label = "Scale", slider = St.SCALE_RANGE, unit = "%", scale = St.PERCENT_SCALE,
          help = "How big the window is." },
        { key = "watchListLock", label = "Lock Window", toggle = true,
          help = "The window cannot be dragged. The HUD Editor still moves it." },
        { key = "watchListBars", label = "Progress Bars", toggle = true,
          help = "A bar under each reputation, and under each currency that has a cap." },
    },
})
