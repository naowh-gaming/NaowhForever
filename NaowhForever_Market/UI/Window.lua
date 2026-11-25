-- Window.lua: The Market's own window: its title bar with the scan line, the Farm, Reagents, Price Graph and Ledger pages free or docked beside the auction house, and every page in place of the auction house (ns.Market.Window).
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Parts = ns.Shared.Parts
local St = Market.Style

local W, H = St.WINDOW_W, St.WINDOW_H
local HEADER, PAD, FOOTER, BAR_GAP = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.BAR_GAP
local TABS_BOTTOM = FOOTER + PAD / 2
local BODY_BOTTOM = TABS_BOTTOM + St.TAB_H + PAD
local TAB_W = 150
local SCAN_TICK = 60
local FRESH = 3600
local DOT, DOT_GAP = 7, 8
local DOT_TEXTURE = "Interface\\AddOns\\NaowhForever\\Core\\Media\\circle_mask.tga"
local COG = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Navigation\\settings.tga"
local POSITION = "marketWindow"
local FREE_STRATA = "HIGH"
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
local BLIZZARD_TABS = 40
local NEXT_FRAME = 0
local DOCK_MIN_W = 700
local PAGE = "The Market"
local TEXT_TITLE = "The Market"
local TEXT_ABOUT = ns.L("Where to farm, what your reagents make, and every item's price over time.")
local TEXT_SETTINGS = ns.L("Settings")
local TEXT_SETTINGS_TIP = ns.L("The Market's settings.")
local TEXT_SCAN = ns.L("Scan Prices")
local TEXT_SCAN_TIP = ns.L("Reads every listing on the auction house for its lowest price.")
local TEXT_BLIZZARD = ns.L("Blizzard's Auction House")
local TEXT_BLIZZARD_TIP = ns.L("Blizzard's own window, until you leave the auctioneer.")
local TEXT_OFF = ns.L("Turn on The Market in its settings to open it.")
local PAGES = {
    { key = "farm", label = "Farm", tip = "Where your skills gather the most, priced from your last scan, and a loop through it." },
    { key = "reagents", label = "Reagents", tip = "What the reagents in your bags make, and whether to craft or sell them." },
    { key = "prices", label = "Price Graph", tip = "Any item's lowest price each day over the past two weeks." },
    { key = "ledger", label = "Ledger", tip = "What you earned and spent, and your gold over time." },
}
local AUCTION_PAGES = {
    { key = "buy", label = "Buy", tip = "Search the auction house, or pick from your watch list, and buy it." },
    { key = "sell", label = "Sell", tip = "Your bags, most valuable first, priced and posted." },
    { key = "mine", label = "My Auctions", tip = "Your auctions, and the ones someone is selling for less." },
    { key = "shop", label = "Shopping List", tip = "What your Shopping List and your alts' still need.", shopping = true },
}
local FULL_AFTER = { "farm", "prices", "reagents", "ledger" }

local window, body, tabs, fullTabs, ticker, freeStop
local dockedTo, dockGap, dockPicked, dockClosed
local covering, coverAside
local shown, fullShown = "farm", "buy"
local holders = {}

Market.Pages = {}
local Window = { PAGES = PAGES }
Market.Window = Window

local function ScanLine()
    if not window then return end
    local summary = ns.AuctionScanSummary and ns.AuctionScanSummary()
    local at = ns.AuctionScanTime and ns.AuctionScanTime()
    local dot = at and GetServerTime() - at < FRESH and St.HAVE_RGB or St.WARN_RGB
    window.dot:SetVertexColor(dot.r, dot.g, dot.b)
    window.dot:SetShown(summary ~= nil)
    window.status:SetText(summary or "")
    Parts.LabelBar(window.scan, TEXT_SCAN)
end

function Window.ShowPageIn(parent, key)
    local holder = holders[key]
    if not holder then
        holder = CreateFrame("Frame", nil, parent)
        holders[key] = holder
        Market.Pages[key].Build(holder)
    end
    holder:SetParent(parent)
    holder:ClearAllPoints()
    holder:SetAllPoints()
    Market.Pages[key].Show()
end

function Window.HidePage(key)
    if holders[key] then Market.Pages[key].Hide() end
end

local function Bar()
    return covering and fullTabs or tabs
end

local function Chrome()
    if ns.foreverSkin then return St.FOREVER_TITLE_H, St.FOREVER_SIDE end
    return 0, 0
end

local function PageWidth()
    return Market.Pages[shown].WIDTH or W
end

local function DockWidth()
    local _, side = Chrome()
    local room = (UIParent:GetRight() * UIParent:GetEffectiveScale()
        - dockedTo:GetRight() * dockedTo:GetEffectiveScale()) / window:GetEffectiveScale() - dockGap - side * 2
    return math.max(DOCK_MIN_W, math.min(PageWidth(), math.floor(room)))
end

local function ShowPage(key)
    if shown ~= key then Window.HidePage(shown) end
    shown = key
    if not covering then window:SetWidth(dockedTo and DockWidth() or PageWidth()) end
    Market.Tabs.Paint(Bar(), key)
    Window.ShowPageIn(body, key)
    if covering then fullShown = key end
    if dockedTo then dockPicked(key) end
end

local function Free()
    window:SetSize(W, H)
    window:SetFrameStrata(FREE_STRATA)
    window:ClearAllPoints()
    Parts.Place(window, POSITION)
end

local function Release()
    dockedTo = nil
    Free()
end

local function PlaceStatus()
    local left = window.scan:IsShown() and window.scan or window.blizzard:IsShown() and window.blizzard or window.cog
    window.status:ClearAllPoints()
    window.status:SetPoint("RIGHT", left, "LEFT", -BAR_GAP, 0)
end

local function Uncovered()
    fullTabs:Hide()
    tabs:Show()
    window.scan:Hide()
    window.blizzard:Hide()
    PlaceStatus()
    for _, page in ipairs(PAGES) do
        if page.key == shown then return Free() end
    end
    shown = PAGES[1].key
    Free()
end

local function OnHidden()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    Window.HidePage(shown)
    if covering then
        covering = nil
        Uncovered()
        return C_AuctionHouse.CloseAuctionHouse()
    end
    if not dockedTo then return end
    Release()
    if dockClosed then dockClosed() end
end

-- Hiding a window already hidden with UIParent (Alt+Z) fires no OnHide.
local function Close()
    local unseen = window:IsShown() and not window:IsVisible()
    window:Hide()
    if unseen then OnHidden() end
end

local function OnSized(self)
    if dockedTo then self:SetClampRectInsets(0, 0, 0, 0) end
end

local function DragStart(self)
    if dockedTo or covering then return Market.Move.Start() end
    self:StartMoving()
end

local function DragStop(self)
    if dockedTo or covering then return Market.Move.Stop() end
    freeStop(self)
end

local function PassKeysOn()
    if window and not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end

local function OnKeyDown(self, key)
    local page = covering and S.Get("postKeys") and Market.Pages[shown]
    local action = page and page.KeyAction and not InCombatLockdown() and not IsModifierKeyDown() and page.KeyAction(key)
    if not action then return ns.UI.CloseOnEscape(self, key) end
    self:SetPropagateKeyboardInput(false)
    action()
    C_Timer.After(NEXT_FRAME, PassKeysOn)
end

local function OpenSettings()
    ns.OpenOptionsWindow(PAGE)
end

local function Scan()
    if ns.AuctionScan then ns.AuctionScan() end
    ScanLine()
end

local function StepAside()
    coverAside()
end

local function Build()
    window = Parts.Window(W, H, POSITION)
    freeStop = window:GetScript("OnDragStop")
    window:SetScript("OnDragStart", DragStart)
    window:SetScript("OnDragStop", DragStop)
    window:SetScript("OnKeyDown", OnKeyDown)
    window:HookScript("OnHide", OnHidden)
    window:HookScript("OnSizeChanged", OnSized)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    window.cog = Parts.BarButton(window, COG, TEXT_SETTINGS, TEXT_SETTINGS_TIP, OpenSettings)
    window.cog:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    window.blizzard = Parts.BarButton(window, St.EYE, TEXT_BLIZZARD, TEXT_BLIZZARD_TIP, StepAside)
    window.blizzard:SetPoint("RIGHT", window.cog, "LEFT", -BAR_GAP, 0)
    window.blizzard:Hide()
    window.scan = Parts.BarButton(window, St.RESET, TEXT_SCAN, TEXT_SCAN_TIP, Scan, TEXT_SCAN)
    window.scan:SetPoint("RIGHT", window.blizzard, "LEFT", -BAR_GAP, 0)
    window.scan:Hide()
    window.status = ns.Font(window, St.SMALL_SIZE, nil, ns.THEME.muted)
    PlaceStatus()
    window.dot = window:CreateTexture(nil, "ARTWORK")
    window.dot:SetTexture(DOT_TEXTURE, nil, nil, "TRILINEAR")
    window.dot:SetSize(DOT, DOT)
    window.dot:SetPoint("RIGHT", window.status, "LEFT", -DOT_GAP, 0)
    window.subtitle:SetPoint("RIGHT", window.dot, "LEFT", -BAR_GAP, 0)
    tabs = Market.Tabs.Build(window, TAB_W * #PAGES, PAGES, ShowPage)
    tabs:SetPoint("BOTTOMLEFT", PAD, TABS_BOTTOM)
    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
    body:SetPoint("BOTTOMRIGHT", -PAD, BODY_BOTTOM)
    Parts.FooterBrand(window, PAGE)
end

local function BuildFullTabs()
    local pages = {}
    for _, page in ipairs(AUCTION_PAGES) do
        if not page.shopping or (ns.Professions and ns.Professions.Shopping) then pages[#pages + 1] = page end
    end
    for _, key in ipairs(FULL_AFTER) do
        for _, page in ipairs(PAGES) do
            if page.key == key then pages[#pages + 1] = page end
        end
    end
    fullTabs = Market.Tabs.Build(window, math.min(TAB_W * #pages, W - PAD * 2), pages, ShowPage)
    fullTabs:SetPoint("BOTTOMLEFT", PAD, TABS_BOTTOM)
end

local function Present(page)
    window:SetScale(ns.UIScale())
    window.backdrop:Paint(1)
    window:Show()
    ScanLine()
    if not ticker then ticker = C_Timer.NewTicker(SCAN_TICK, ScanLine) end
    ShowPage(page or shown)
end

function Window.Open(page)
    if not window then Build() end
    if dockedTo then
        local closed = dockClosed
        Release()
        closed()
    end
    Present(page)
end

function Window.DockTo(ah, page, gap, onPick, onClose)
    if not window then Build() end
    dockedTo, dockGap, dockPicked, dockClosed = ah, gap, onPick, onClose
    window:SetScale(ns.UIScale())
    window:SetFrameStrata(ah:GetFrameStrata())
    window:Raise()
    local top, side = Chrome()
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", ah, "TOPRIGHT", gap + side, -top)
    window:SetPoint("BOTTOMLEFT", ah, "BOTTOMRIGHT", gap + side, side)
    window:SetWidth(DockWidth())
    window:SetClampRectInsets(0, 0, 0, 0)
    Present(page)
end

function Window.FitDock()
    if not dockedTo then return end
    local width = DockWidth()
    if width == window:GetWidth() then return end
    window:SetWidth(width)
    Window.Refresh()
end

function Window.Undock()
    if not dockedTo then return end
    dockClosed = nil
    Close()
end

function Window.Docked()
    if dockedTo or covering then return window end
end

local function Above(strata)
    for i, s in ipairs(STRATA) do
        if s == strata then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return FREE_STRATA
end

function Window.Cover(ah, onAside)
    if not window then Build() end
    if not fullTabs then BuildFullTabs() end
    if window:IsShown() then Window.HidePage(shown) end
    covering, coverAside = ah, onAside
    window:SetScale(ns.UIScale())
    window:SetFrameStrata(Above(ah:GetFrameStrata()))
    local scale = ah:GetEffectiveScale() / window:GetEffectiveScale()
    window:SetSize(math.max(W, ah:GetWidth() * scale), math.max(H, ah:GetHeight() * scale + BLIZZARD_TABS))
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", ah, "TOPLEFT")
    tabs:Hide()
    fullTabs:Show()
    window.blizzard:Show()
    window.scan:SetShown(ns.AuctionScan ~= nil)
    PlaceStatus()
    shown = fullShown
    Present(fullShown)
end

function Window.Uncover()
    if not covering then return end
    covering = nil
    Close()
    Uncovered()
end

function Window.Covering()
    return covering ~= nil
end

function ns.ToggleMarketWindow()
    if not Market.On() then return ns.Print(TEXT_OFF) end
    if Window.Shown() then return Close() end
    Window.Open()
end

function Window.Hide()
    if window then Close() end
end

function Window.Shown()
    return window ~= nil and window:IsShown()
end

function Window.Refresh()
    if not Window.Shown() then return end
    ScanLine()
    Market.Tabs.Paint(Bar(), shown)
    local page = Market.Pages[shown]
    if page.Refresh then page.Refresh() else page.Show() end
end

function ns.MarketRefresh()
    if Market.On() then
        Market.History.Record()
        Market.Watch.Scanned()
        Market.BagWorth.Changed()
        Market.Crafts.Changed()
        Market.Farm.Changed()
    end
    Window.Refresh()
    if not covering then Market.Dock.Refresh() end
end

function ns.MarketPricesSeen()
    if not Market.On() then return end
    Market.BagWorth.Changed()
    Market.Crafts.Changed()
    Market.Farm.Changed()
end
