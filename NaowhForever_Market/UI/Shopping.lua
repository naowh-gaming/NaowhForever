-- Shopping.lua: the Shopping List page: what your Shopping List and your alts' still need, each counted on its own list when bought, and the listings of the one you pick, with Buy.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Finder, Listings = Market.Finder, Market.Listings

local HEAD_H, HEAD_ICON, NAME_SIZE, NAME_GAP, SUB_GAP, GAP = 40, 32, 15, 8, 3, 10
local BUTTON_W, BUTTON_H = 86, 24
local WIDTH = St.DOCK_W - St.DOCK_PAD * 2
local ROSTER = "marketCharacters"
local BUY_EVENTS = { "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED" }
local TEXT_LIST = ns.L("From Professions, what you still need")
local TEXT_EMPTY = ns.L("Nothing on your Shopping List.")
local TEXT_MORE = ns.L("%d more")
local TEXT_MORE_FOR = ns.L("%d more for %s")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")

local page, column, head, watch, finder, events, roster, listPane, itemEvents
local entries, pool, alts = {}, {}, {}
local buying, focus = {}, {}
local docked = false

local Page = {}
Market.Pages.shop = Page

local function Shopping()
    local P = ns.Professions
    return P and P.Shopping
end

local function Add(materials, owner, who)
    for _, m in ipairs(materials) do
        local n = #entries + 1
        local e = pool[n] or {}
        pool[n] = e
        e.item, e.qty, e.owner, e.who = m.item, m.qty, owner, who
        entries[n] = e
    end
end

local function ByAltName(a, b)
    local x, y = roster[a].full or roster[a].name, roster[b].full or roster[b].name
    if x ~= y then return x < y end
    return a < b
end

function Page.Entries()
    wipe(entries)
    local shopping = Shopping()
    if not shopping then return entries end
    Add((shopping.Materials()))
    roster = ns.AccountSettings()[ROSTER]
    if not roster then return entries end
    wipe(alts)
    local me, house = UnitGUID("player"), Market.HouseKey()
    local myName, myFull = UnitName("player"), roster[me] and roster[me].full
    for guid, alt in pairs(roster) do
        local other
        if alt.full and myFull then other = alt.full ~= myFull else other = alt.name ~= myName end
        local legacy = alt.name ~= myName and alt.name or nil
        if guid ~= me and other and alt.house == house and shopping.HasList(guid, legacy) then
            alts[#alts + 1] = guid
        end
    end
    table.sort(alts, ByAltName)
    for _, guid in ipairs(alts) do
        local name = roster[guid].name
        if name == myName then name = nil end
        Add((shopping.MaterialsOf(guid, name)), guid, name)
    end
    return entries
end

local function FromList(found)
    wipe(found)
    for i, e in ipairs(Page.Entries()) do found[i] = e.item end
    return #found > 0 and TEXT_LIST or TEXT_EMPTY
end

local function Side(i)
    local e = entries[i]
    if not e then return end
    if not e.owner then return TEXT_MORE:format(e.qty) end
    local alt = roster[e.owner]
    return TEXT_MORE_FOR:format(e.qty, alt.full or alt.name)
end

function Page.Picked()
    local at = finder and finder.listed and finder.at
    local e = at and entries[at]
    if e and e.item == finder.picked then return e end
end

local function DrawHead(itemID)
    head:SetShown(itemID ~= nil)
    Finder.PaintWatch(watch, itemID)
    if not itemID then return end
    head.icon.texture:SetTexture(C_Item.GetItemIconByID(itemID))
    local color = Items.QualityColor(itemID) or T.fg
    head.name:SetTextColor(color.r, color.g, color.b)
    head.name:SetText(Items.Name(itemID))
    local scan = Finder.Scan(itemID)
    head.sub:SetText(scan and TEXT_SCAN_SUB:format(Parts.Coins(scan)) or TEXT_NO_SCAN_SUB)
end

local function Focus()
    if focus.itemID then return focus end
end

local function Want()
    local info = C_AuctionHouse.GetItemKeyInfo(focus.itemKey)
    focus.waiting = info == nil
    if not info then return Listings.Want(nil) end
    focus.commodity = info.isCommodity
    Listings.Want(focus)
end

local function DropFocus()
    if not focus.itemID then return end
    listPane:Close()
    wipe(focus)
    Listings.Want(nil)
end

local function DrawListings()
    if docked and focus.itemID ~= finder.picked then DropFocus() end
    local shown = docked and focus.itemID ~= nil
    listPane:SetShown(shown)
    if shown then
        listPane:SetHeight(listPane:Paint(focus))
        finder.frame:SetPoint("BOTTOMRIGHT", listPane, "TOPRIGHT", 0, GAP)
    else
        finder.frame:SetPoint("BOTTOMRIGHT")
    end
end

function Page.Draw()
    Finder.Draw(finder)
    DrawHead(finder.picked)
    DrawListings()
end

local function Done()
    wipe(buying)
    events:UnregisterAllEvents()
end

local function OnBuyNow(dialog)
    Done()
    local e = page:IsVisible() and Page.Picked()
    if not (e and e.item == dialog.itemID) then return end
    buying.item, buying.qty, buying.owner, buying.who = e.item, dialog.quantity, e.owner, e.who
    for _, event in ipairs(BUY_EVENTS) do events:RegisterEvent(event) end
end

local function Counted(item, qty, owner, who)
    local shopping = Shopping()
    if owner then
        shopping.BoughtFor(owner, who, item, qty)
        if page:IsShown() then Page.Draw() end
    else
        shopping.Bought(item, qty)
        shopping.Redraw()
    end
end

local function OnEvent(_, event)
    local item, qty, owner, who = buying.item, buying.qty, buying.owner, buying.who
    Done()
    if event == "COMMODITY_PURCHASE_SUCCEEDED" then Counted(item, qty, owner, who) end
end

local function BoughtHere(entry, count)
    local e = Page.Picked()
    if entry.commodity and e and e.item == entry.itemID and e.owner == entry.owner then
        Counted(entry.itemID, count, entry.owner, entry.who)
    end
end

local function Picked(itemID)
    local e = Page.Picked()
    local owner, who = e and e.owner, e and e.who
    if Market.Window.Covering() then return Market.Browse.PickItem(itemID, owner, who) end
    if focus.itemID == itemID and focus.owner == owner then return end
    DropFocus()
    focus.key, focus.itemID, focus.link = itemID, itemID, itemID
    focus.itemKey = C_AuctionHouse.MakeItemKey(itemID)
    focus.owner, focus.who = owner, who
    Want()
end

local function OnItemInfo(_, _, itemID)
    if focus.waiting and itemID == focus.itemID then Want() end
end

local function StartDocked()
    if docked then return end
    docked = true
    listPane.bought = BoughtHere
    Market.Listed.Use(listPane)
    Listings.Start()
    Listings.onChange = Page.Draw
    itemEvents:RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED")
end

local function StopDocked()
    if not docked then return end
    docked = false
    DropFocus()
    Listings.Stop()
    itemEvents:UnregisterAllEvents()
end

local function OnListChanged()
    if page:IsShown() then Page.Draw() end
end

local function BuildHead()
    head = CreateFrame("Frame", nil, column)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    head.icon = Parts.ItemIcon(head, HEAD_ICON)
    head.icon:SetPoint("LEFT")
    head.name = ns.Font(head, NAME_SIZE, nil, T.fg, true)
    head.name:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", NAME_GAP, 0)
    head.name:SetPoint("RIGHT")
    head.name:SetJustifyH("LEFT")
    head.name:SetWordWrap(false)
    head.sub = ns.Font(head, St.SMALL_SIZE, nil, T.muted)
    head.sub:SetPoint("TOPLEFT", head.name, "BOTTOMLEFT", 0, -SUB_GAP)
    watch = Finder.Watch(column, BUTTON_W, BUTTON_H, Page.Draw)
    watch:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    watch:SetPoint("RIGHT")
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    column = CreateFrame("Frame", nil, page)
    column:SetPoint("TOPLEFT")
    column:SetPoint("BOTTOMLEFT")
    column:SetWidth(WIDTH)
    BuildHead()
    finder = Finder.New(column, WIDTH, FromList, Page.Draw)
    finder.side = Side
    finder.onPick = Picked
    finder.frame:SetPoint("TOPLEFT", watch, "BOTTOMLEFT", 0, -GAP)
    finder.frame:SetPoint("BOTTOMRIGHT")
    listPane = Market.Listed.New(column, Page.Draw, Focus)
    listPane:SetPoint("BOTTOMLEFT")
    listPane:SetPoint("BOTTOMRIGHT")
    listPane:Hide()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    itemEvents = CreateFrame("Frame")
    itemEvents:SetScript("OnEvent", OnItemInfo)
    hooksecurefunc(_G.AuctionHouseFrame.BuyDialog, "BuyNow", OnBuyNow)
    Shopping().OnChange(OnListChanged)
end

function Page.Show()
    page:Show()
    if Market.Window.Covering() then
        StopDocked()
        Market.Browse.Attach(page, column, BoughtHere)
    else
        Market.Browse.Detach()
        StartDocked()
    end
    Page.Draw()
end

function Page.Refresh()
    Page.Draw()
end

function Page.Hide()
    page:Hide()
    StopDocked()
    Market.Browse.Detach()
end
