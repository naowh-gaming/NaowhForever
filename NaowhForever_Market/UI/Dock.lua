-- Dock.lua: The Market at Blizzard's auction house: its panel docked to the right with Buy, Sell, My Auctions and Shopping List, the Farm, Price Graph and Reagents tabs that dock The Market's window there instead, or with Full Window on, The Market's window in place of Blizzard's (Market.Dock).
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local Parts = ns.Shared.Parts

local AH_ADDON = "Blizzard_AuctionHouseUI"
local AH_TABS = "LibAHTab-1-0"
local DOCK_W, PAD = St.DOCK_W, St.DOCK_PAD
local DOCK_GAP, HEAD_H = 4, 34
local NEXT_FRAME = 0
local WATCH_H = 20
local DRAG_BUTTON = "LeftButton"
local BACK_W, BACK_H, BACK_GAP = 120, 22, 4
local TEXT_TITLE = "The Market"
local TEXT_BACK_TIP = ns.L("The Market's full window, in place of Blizzard's.")
local TEXT_WATCH_ONE = ns.L("%d on your watch list is at or under your price")
local TEXT_WATCH_MANY = ns.L("%d on your watch list are at or under your price")
local PAGES = {
    { key = "buy", label = "Buy", tip = "Your watch list: the items you want, and when they are at or under your price." },
    { key = "sell", label = "Sell", tip = "Your bags, most valuable first, priced and posted." },
    { key = "mine", label = "My Auctions", tip = "Your auctions, and the ones someone is selling for less." },
    { key = "shop", label = "Shopping List", tip = "What your Shopping List and your alts' still need.", shopping = true },
}
local WINDOW_PAGES = { "farm", "prices", "reagents", "ledger" }

local BLIZZARD_PAGES = { Buy = "buy", ItemBuy = "buy", CommoditiesBuy = "buy", WoWTokenBuy = "buy",
    ItemSell = "sell", CommoditiesSell = "sell", WoWTokenSell = "sell", Auctions = "mine" }

local dock, body, tabs, events, ah, watchLine, row, back
local shown = "buy"
local blizzardPage, docked
local closed, stepped = false, false

local Dock = {}
Market.Dock = Dock

local PaintWatch

local function Width(key)
    local wide = Market.Pages[key].DOCK_W
    if not wide then return DOCK_W end
    local room = (UIParent:GetRight() * UIParent:GetEffectiveScale() - ah:GetRight() * ah:GetEffectiveScale())
        / dock:GetEffectiveScale() - DOCK_GAP
    return room >= wide and wide or DOCK_W
end

local function ShowPage(key)
    if shown ~= key then Market.Window.HidePage(shown) end
    shown = key
    dock:SetWidth(Width(key))
    Market.Tabs.Paint(tabs, key)
    Market.Window.ShowPageIn(body, key)
    PaintWatch()
end

local function PassKeysOn()
    if dock and not InCombatLockdown() then dock:SetPropagateKeyboardInput(true) end
end

local function OnKeyDown(self, key)
    local page = Market.Pages[shown]
    local action = not InCombatLockdown() and not IsModifierKeyDown() and page.KeyAction and page.KeyAction(key)
    if not action then return end
    self:SetPropagateKeyboardInput(false)
    action()
    C_Timer.After(NEXT_FRAME, PassKeysOn)
end

local function OnHidden()
    Market.Window.HidePage(shown)
end

local function OpenWatch()
    Market.Pages.buy.ShowList()
    ShowPage("buy")
end

function PaintWatch()
    local n = shown ~= "buy" and Market.Watch.UnderCount() or 0
    watchLine:SetShown(n > 0)
    watchLine.text:SetText((n == 1 and TEXT_WATCH_ONE or TEXT_WATCH_MANY):format(n))
    body:SetPoint("TOPLEFT", n > 0 and watchLine or tabs, "BOTTOMLEFT", 0, -PAD)
end

local Activate

local function Changed()
    if ns.AuctionWindowChanged then ns.AuctionWindowChanged() end
end

local function Close()
    closed = true
    dock:Hide()
    Changed()
end

local function HasShopping()
    local P = ns.Professions
    return P ~= nil and P.Shopping ~= nil
end

local function Build()
    dock = Parts.Panel(TEXT_TITLE, true)
    dock:SetWidth(DOCK_W)
    dock.backdrop:Paint(1)
    dock.close:SetScript("OnClick", Close)
    dock:SetScript("OnKeyDown", OnKeyDown)
    dock:HookScript("OnHide", OnHidden)
    dock:RegisterForDrag(DRAG_BUTTON)
    dock:SetScript("OnDragStart", Market.Move.Start)
    dock:SetScript("OnDragStop", Market.Move.Stop)
    local pages = {}
    for _, page in ipairs(PAGES) do
        if not page.shopping or HasShopping() then pages[#pages + 1] = page end
    end
    tabs = Market.Tabs.Build(dock, DOCK_W - PAD * 2, pages, ShowPage)
    tabs:SetPoint("TOPLEFT", PAD, -HEAD_H)
    watchLine = CreateFrame("Button", nil, dock)
    watchLine:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 0, -PAD)
    watchLine:SetPoint("RIGHT", -PAD, 0)
    watchLine:SetHeight(WATCH_H)
    watchLine.text = ns.Font(watchLine, St.TEXT_SIZE, nil, St.HAVE_RGB)
    watchLine.text:SetPoint("LEFT")
    watchLine:SetScript("OnClick", OpenWatch)
    body = CreateFrame("Frame", nil, dock)
    body:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end

local function WindowPicked(key)
    docked = key
    Market.HouseTabs.Paint(row, key)
end

local function WindowClosed()
    docked, closed = nil, false
    Market.HouseTabs.Paint(row, nil)
    Activate()
end

local function TabClicked(key)
    if key == docked then return Market.Window.Hide() end
    docked = key
    if dock then dock:Hide() end
    Market.Window.DockTo(ah, key, DOCK_GAP, WindowPicked, WindowClosed)
    Changed()
end

local function LastTab()
    local lib = LibStub and LibStub(AH_TABS, true)
    local added = lib and lib.internalState and lib.internalState.Tabs
    if added and #added > 0 then return added[#added] end
    return ah.AuctionsTab
end

local function StyleRow()
    if not (row and row:IsShown()) then return end
    Market.HouseTabs.Style(row, LastTab(), ah.Tabs)
    Market.HouseTabs.Paint(row, docked)
end

local function ShowRow()
    if not row then
        local pages = {}
        for i, key in ipairs(WINDOW_PAGES) do
            for _, page in ipairs(Market.Window.PAGES) do
                if page.key == key then pages[i] = page end
            end
        end
        row = Market.HouseTabs.New(ah, pages, TabClicked)
    end
    row:Show()
    StyleRow()
end

local function Uncover()
    Market.Window.Uncover()
    if ah then ah:SetAlpha(1) end
end

local function StepAside()
    stepped = true
    Activate()
end

local function Return()
    stepped = false
    Activate()
end

local function Cover()
    if docked then
        docked = nil
        Market.Window.Undock()
    end
    if dock then dock:Hide() end
    if row then row:Hide() end
    if back then back:Hide() end
    ah:SetAlpha(0)
    Market.Window.Cover(ah, StepAside)
    Changed()
end

local function ShowBack()
    if not S.Get("fullWindow") then
        if back then back:Hide() end
        return
    end
    if not back then
        back = ns.Button(ah, TEXT_TITLE, BACK_W, BACK_H, Return)
        back:SetPoint("BOTTOMRIGHT", ah, "TOPRIGHT", 0, BACK_GAP)
        ns.Tooltip(back, TEXT_TITLE, TEXT_BACK_TIP)
    end
    back:Show()
end

function Activate()
    if not (Market.PanelsOn() and ah and ns.AuctionHouseShown()) then return end
    if S.Get("fullWindow") and not stepped then return Cover() end
    Uncover()
    ShowRow()
    ShowBack()
    if closed or docked then return end
    if not dock then Build() end
    dock:SetScale(ah:GetScale())
    dock:SetFrameStrata(ah:GetFrameStrata())
    dock:Raise()
    dock:ClearAllPoints()
    dock:SetPoint("TOPLEFT", ah, "TOPRIGHT", DOCK_GAP, 0)
    dock:SetPoint("BOTTOMLEFT", ah, "BOTTOMRIGHT", DOCK_GAP, 0)
    if not InCombatLockdown() then
        dock:EnableKeyboard(S.Get("postKeys"))
        dock:SetPropagateKeyboardInput(true)
    end
    dock:Show()
    ShowPage(shown)
    Changed()
end

local function Deactivate()
    Uncover()
    if dock then dock:Hide() end
    docked = nil
    Market.Window.Undock()
    if row then row:Hide() end
    if back then back:Hide() end
    Changed()
end

local function OnBlizzardShow()
    closed = false
    Activate()
    C_Timer.After(NEXT_FRAME, StyleRow)
end

local function OnMoved()
    if ns.AuctionHouseShown() then return C_Timer.After(NEXT_FRAME, Activate) end
    Deactivate()
end

local function OnBlizzardHide()
    closed, stepped = false, false
    blizzardPage = nil
    Market.Move.Stop()
    Deactivate()
    Market.Sell.Reset()
end

function Dock.Shown()
    return dock ~= nil and dock:IsShown()
end

function Dock.Fit()
    if Dock.Shown() then dock:SetWidth(Width(shown)) end
end

function Dock.AtAuction()
    return Dock.Shown() or docked ~= nil or Market.Window.Covering()
end

function Dock.Pick(location)
    if not Dock.AtAuction() then return end
    if Market.Window.Covering() then
        Market.Window.Open("sell")
    else
        if docked then Market.Window.Hide() end
        ShowPage("sell")
    end
    Market.Pages.sell.PickLocation(location)
end

function Dock.Refresh()
    if Market.Window.Covering() then return Market.Window.Refresh() end
    if not Dock.Shown() then return end
    PaintWatch()
    Market.Tabs.Paint(tabs, shown)
    local page = Market.Pages[shown]
    if page.Refresh then page.Refresh() else page.Show() end
end

function ns.MarketAuctionWindow()
    if Dock.Shown() then return dock end
    return Market.Window.Docked()
end

function ns.MarketAuctionTabs()
    if row and row:IsShown() then return row.buttons[#row.buttons] end
end

local function OnPostItem(_, location)
    if Dock.AtAuction() then C_Item.UnlockItem(location) end
    Dock.Pick(location)
end

local function PageOf(mode)
    for name, key in pairs(BLIZZARD_PAGES) do
        if AuctionHouseFrameDisplayMode[name] == mode then return key end
    end
end

local function OnDisplayMode()
    local key = PageOf(ah:GetDisplayMode())
    if not key or key == blizzardPage then return end
    blizzardPage = key
    if Dock.Shown() then
        ShowPage(key)
    else
        shown = key
    end
end

local function Hook()
    ah = _G.AuctionHouseFrame
    ah:HookScript("OnShow", OnBlizzardShow)
    ah:HookScript("OnHide", OnBlizzardHide)
    hooksecurefunc(ah, "SetPostItem", OnPostItem)
    hooksecurefunc(ah, "SetDisplayMode", OnDisplayMode)
    ns.OnAuctionHouseMoved(OnMoved)
    Market.Move.Hook(ah)
end

local function OnEvent(_, _, name)
    if name ~= AH_ADDON then return end
    events:UnregisterEvent("ADDON_LOADED")
    Hook()
end

local function Apply()
    if not Market.PanelsOn() then
        if events then events:UnregisterAllEvents() end
        closed = false
        return Deactivate()
    end
    if ah then return Activate() end
    if C_AddOns.IsAddOnLoaded(AH_ADDON) then
        Hook()
        return Activate()
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:RegisterEvent("ADDON_LOADED")
end

local function OnSetting(key)
    if key == "enabled" or key == "postKeys" or key == "fullWindow" then Apply() end
end

S.OnChange(OnSetting)
ns.OnApply(Apply)
Apply()
