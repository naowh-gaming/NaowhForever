-- Buy.lua: the Buy page: your watch list with any item in your scans to add to it, your saved searches, or the gear in your scans that beats yours, and in the full window the auction house's own search beside them.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Finder, Watch, Upgrades, Columns = Market.Finder, Market.Watch, Market.Upgrades, Market.Columns

local HEAD_H, HEAD_ICON, NAME_SIZE, NAME_GAP, SUB_GAP, GAP = 40, 32, 15, 8, 3, 10
local BUTTON_W, BUTTON_H = 86, 24
local TEXT_LIST = ns.L("Watch List: %d, %d at or under your price")
local TEXT_EMPTY = ns.L("Nothing on your watch list. Search an item to watch it.")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")
local TEXT_UP_TO = ns.L("Up to This Price")
local TEXT_NO_UPGRADES = ns.L("No upgrades at or under your price in your scans.")
local TEXT_NO_WEIGHTS = ns.L("Turn on the BiS List to weigh gear for upgrades.")
local TEXT_GAIN = "%s  +%.1f%%  %s"
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_SORT = ns.L("Sort By")
local TEXT_SORT_LEVEL = ns.L("Level")
local TEXT_SORT_GAIN = ns.L("Gain")
local MONEY_LABEL_H = 16
local SORT_W = 44
local WIDTH = St.DOCK_W - St.DOCK_PAD * 2
local VIEWS = {
    { key = "watch", label = "Watch List", tip = "Your watch list: the items you want, and when they are at or under your price." },
    { key = "searches", label = "Searches", tip = "Your saved searches, run in the auction house's own Buy tab." },
}
local UPGRADES_VIEW = { key = "upgrades", label = "Upgrades",
    tip = "Gear in your scans that beats what you wear, at or under your price." }
local VIEWS_UPGRADES = { VIEWS[1], VIEWS[2], UPGRADES_VIEW }

local page, column, views, head, watch, finder, searches, upgrades, gear, sorter
local view = "watch"
local watched = {}
local stale = true
local tabsWithUpgrades

local Page = {}
Market.Pages.buy = Page

local function FromList(found)
    wipe(found)
    for _, id in ipairs(Watch.Items(watched)) do found[#found + 1] = id end
    if #found == 0 then return TEXT_EMPTY end
    return TEXT_LIST:format(#found, Watch.UnderCount())
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

local function GainNote(i)
    local id = upgrades.found[i]
    local price = Upgrades.Price(id)
    return TEXT_GAIN:format(TEXT_LEVEL:format(Upgrades.levels[id] or 0), Upgrades.gains[id] or 0,
        price and Parts.Coins(price) or "")
end

local function UpgradeOrder()
    local key, up = Columns.Current(sorter)
    local order = key == "level" and Upgrades.ByLevel or Upgrades.Order
    if not up then return order end
    return function(a, b) return order(b, a) end
end

local function DrawUpgrades()
    if stale then
        stale = false
        upgrades.none = Upgrades.Find(Page.Stale) == "weights" and TEXT_NO_WEIGHTS or TEXT_NO_UPGRADES
    end
    if not upgrades.money:HasFocus() then upgrades.money:SetAmount(Market.Settings.Get("upgradesMax")) end
    upgrades.order = UpgradeOrder()
    Finder.Draw(upgrades)
end

function Page.Draw()
    if view == "upgrades" then return DrawUpgrades() end
    if view ~= "watch" then return Market.SearchView.Draw() end
    Finder.Draw(finder)
    DrawHead(finder.picked)
end

function Page.Stale()
    stale = true
    if view == "upgrades" and page:IsShown() then Page.Draw() end
end

local function BuildHead()
    head = CreateFrame("Frame", nil, column)
    head:SetPoint("TOPLEFT", views, "BOTTOMLEFT", 0, -GAP)
    head:SetPoint("RIGHT")
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

local function PickedUpgrade(itemID)
    if Market.Window.Covering() then return Market.Browse.PickItem(itemID) end
    local name = Items.Name(itemID)
    if name then Market.Searches.Run({ text = name }) end
end

local function MaxChanged(_, amount)
    if not (amount and amount > 0) then return end
    Market.Settings.Set("upgradesMax", amount)
    Page.Stale()
end

local function BuildUpgrades()
    local box = CreateFrame("Frame", nil, column)
    box:SetPoint("TOPLEFT", views, "BOTTOMLEFT", 0, -GAP)
    box:SetPoint("RIGHT")
    box:SetHeight(MONEY_LABEL_H + BUTTON_H)
    local label = ns.Font(box, St.SMALL_SIZE, nil, T.muted)
    label:SetPoint("TOPLEFT")
    label:SetText(TEXT_UP_TO)
    upgrades = Finder.New(column, WIDTH, nil, Page.Draw)
    upgrades.box, upgrades.side, upgrades.onPick = box, GainNote, PickedUpgrade
    upgrades.money = Parts.MoneyBox(box, MaxChanged)
    upgrades.money:SetPoint("TOPLEFT", 0, -MONEY_LABEL_H)
    local sortLabel = ns.Font(box, St.SMALL_SIZE, nil, T.muted)
    sortLabel:SetPoint("TOPRIGHT")
    sortLabel:SetText(TEXT_SORT)
    local sorts = CreateFrame("Frame", nil, box)
    sorts:SetPoint("BOTTOMLEFT")
    sorts:SetPoint("BOTTOMRIGHT")
    sorts:SetHeight(BUTTON_H)
    sorter = Columns.New(sorts, Market.Settings, "sortUpgrades", "gain", Page.Draw)
    Columns.Add(sorter, { key = "gain", text = TEXT_SORT_GAIN, right = 0, width = SORT_W })
    Columns.Add(sorter, { key = "level", text = TEXT_SORT_LEVEL, right = SORT_W + GAP, width = SORT_W })
    upgrades.only = Upgrades.gains
    upgrades.frame:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -GAP)
    upgrades.frame:SetPoint("BOTTOMRIGHT")
    gear = CreateFrame("Frame")
    gear:SetScript("OnEvent", Page.Stale)
end

local function ShowView(key)
    view = key
    Parts.PaintTabs(views, key)
    local watching, upgrading = key == "watch", key == "upgrades"
    if not watching then
        head:Hide()
        watch:Hide()
    end
    finder.frame:SetShown(watching)
    if key == "searches" and not searches then
        searches = Market.SearchView.Build(column, WIDTH)
        searches:SetPoint("TOPLEFT", views, "BOTTOMLEFT", 0, -GAP)
        searches:SetPoint("BOTTOMRIGHT")
    end
    if searches then searches:SetShown(key == "searches") end
    if upgrading and not upgrades then BuildUpgrades() end
    if upgrades then
        upgrades.box:SetShown(upgrading)
        upgrades.frame:SetShown(upgrading)
        if upgrading then
            stale = true
            gear:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        else
            gear:UnregisterAllEvents()
        end
    end
    Page.Draw()
end

local function SyncViews()
    local on = Upgrades.On()
    if on == tabsWithUpgrades then return end
    tabsWithUpgrades = on
    Parts.SetTabs(views, on and VIEWS_UPGRADES or VIEWS)
    if not on and view == "upgrades" then ShowView("watch") end
end

local function Picked(itemID)
    if Market.Window.Covering() then Market.Browse.PickItem(itemID) end
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    column = CreateFrame("Frame", nil, page)
    column:SetPoint("TOPLEFT")
    column:SetPoint("BOTTOMLEFT")
    column:SetWidth(WIDTH)
    tabsWithUpgrades = Upgrades.On()
    views = Parts.Tabs(column, WIDTH, tabsWithUpgrades and VIEWS_UPGRADES or VIEWS, ShowView, true)
    views:SetPoint("TOPLEFT")
    Parts.PaintTabs(views, view)
    BuildHead()
    finder = Finder.New(column, WIDTH, FromList, Page.Draw, true)
    finder.onPick = Picked
    finder.frame:SetPoint("TOPLEFT", watch, "BOTTOMLEFT", 0, -GAP)
    finder.frame:SetPoint("BOTTOMRIGHT")
    Market.Searches.Watch()
end

function Page.Show()
    page:Show()
    SyncViews()
    if view == "upgrades" then
        stale = true
        gear:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    end
    if Market.Window.Covering() then
        Market.Browse.Attach(page, column)
    else
        Market.Browse.Detach()
    end
    Page.Draw()
end

function Page.Refresh()
    SyncViews()
    stale = true
    Page.Draw()
end

function Page.ShowList()
    if not finder then return end
    if view ~= "watch" then ShowView("watch") end
    Finder.Reset(finder)
end

function Page.Hide()
    page:Hide()
    if gear then gear:UnregisterAllEvents() end
    Market.Searches.Stop()
    Market.Browse.Detach()
end
