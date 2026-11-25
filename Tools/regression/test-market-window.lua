-- Run with Lua 5.1 from the repository root: The Market's own window, free, docked beside the auction house, or over
-- it. Free, it opens at its saved spot, its own size and strata, and drags. Docked, it sits right of Blizzard's window,
-- top to bottom, on its strata, as wide as the screen leaves room for (never past its right edge, never under its
-- minimum); a drag needs Shift and moves Blizzard's window; its X closes it as its tab would, and it goes back to its
-- free spot afterwards. Over the auction house (Full Window), it covers Blizzard's window a strata above with every
-- page, Buy first, shares each page with the panel rather than building it twice, offers Scan Prices and Blizzard's
-- window, takes the posting keys when Post With Keys is on, and its X closes the auction house.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local uiHidden = false
local function Frame()
    local f = { shown = false, scripts = {}, points = {} }
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and not uiHidden end
    function f:Show()
        if self.shown then return end
        self.shown = true
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide and not uiHidden then self.scripts.OnHide(self) end
    end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:GetScript(name) return self.scripts[name] end
    function f:HookScript(name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...) if old then old(...) end; fn(...) end
    end
    function f:SetPoint(point, relative, relativePoint, x, y) self.points[point] = { relative, relativePoint, x, y } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetWidth(w) self.w = w end
    function f:SetClampRectInsets(left, right, top, bottom) self.insets = { left, right, top, bottom } end
    function f:GetWidth() return self.w end
    function f:GetRight() return self.right end
    function f:SetScale(s) self.scale = s end
    function f:GetEffectiveScale() return self.scale or 1 end
    function f:SetFrameStrata(s) self.strata = s end
    function f:Raise() self.raised = true end
    function f:GetFrameStrata() return self.strata end
    function f:SetText() end
    function f:SetVertexColor() end
    function f:SetShown(on) if on then self:Show() else self:Hide() end end
    function f:SetTexture() end
    function f:CreateTexture() return Frame() end
    function f:SetParent(parent) self.parent = parent end
    function f:SetAllPoints() self.points.ALL = { self.parent } end
    function f:GetHeight() return self.h end
    function f:SetPropagateKeyboardInput(on) self.propagate = on end
    return f
end

local function Page()
    local page = { shows = 0 }
    function page.Build() end
    function page.Show() page.shown, page.shows = true, page.shows + 1 end
    function page.Hide() page.shown = false end
    return page
end

local placed, moves, freeStops = 0, {}, 0
local bars, tabBars, settings, closes, scans, escapes = {}, {}, { postKeys = false }, 0, 0, 0
local ns = {
    THEME = { muted = {} },
    L = function(text) return text end,
    UIScale = function() return 0.8 end,
    Font = function() return Frame() end,
    Market = {
        Style = { WINDOW_W = 1144, WINDOW_H = 650, WINDOW_HEADER = 50, WINDOW_PAD = 10, WINDOW_FOOTER = 20, BAR_GAP = 8,
            TAB_H = 26, SMALL_SIZE = 11, HAVE_RGB = {}, WARN_RGB = {} },
        Settings = { Get = function(key) return settings[key] end },
        Tabs = {
            Build = function(_, _, pages, onPick)
                local bar = Frame()
                bar.shown, bar.pages, bar.pick = true, pages, onPick
                tabBars[#tabBars + 1] = bar
                return bar
            end,
            Paint = function(bar, key) bar.painted = key end,
        },
        Move = { Start = function() moves[#moves + 1] = "start" end, Stop = function() moves[#moves + 1] = "stop" end },
    },
    Shared = { Parts = {
        Window = function(w, h)
            local window = Frame()
            window:SetSize(w, h)
            window.strata = "HIGH"
            function window:StartMoving() self.moving = true end
            window.scripts.OnDragStart = window.StartMoving
            window.scripts.OnDragStop = function() freeStops = freeStops + 1 end
            window:SetClampRectInsets(1030, -1030, 0, 585)
            window.scripts.OnSizeChanged = function(self, width, height)
                self:SetClampRectInsets(width * 0.9, -width * 0.9, 0, height * 0.9)
            end
            window.backdrop = { Paint = function() end }
            window.subtitle = Frame()
            return window
        end,
        TitleBar = function() return Frame() end,
        BarButton = function(_, _, tip, _, onClick)
            local button = Frame()
            button.shown, button.click = true, onClick
            bars[tip] = button
            return button
        end,
        LabelBar = function(button, text) button.fitted = text end,
        FooterBrand = function() end,
        Place = function(window) placed = placed + 1; window:SetPoint("CENTER", "saved") end,
    } },
}
local screen = Frame()
screen.right, screen.scale = 1920, 1
local env = setmetatable({
    _G = { NaowhForever = ns },
    UIParent = screen,
    CreateFrame = function() return Frame() end,
    C_Timer = { NewTicker = function() return { Cancel = function() end } end, After = function(_, f) f() end },
    C_AuctionHouse = { CloseAuctionHouse = function() closes = closes + 1 end },
    InCombatLockdown = function() return false end,
    IsModifierKeyDown = function() return false end,
    GetServerTime = function() return 0 end,
}, { __index = _G })
local fn = assert(loadfile("NaowhForever_Market/UI/Window.lua"))
setfenv(fn, env)
fn()
local Window, Pages = ns.Market.Window, ns.Market.Pages
Pages.farm, Pages.reagents, Pages.prices, Pages.ledger = Page(), Page(), Page(), Page()
Pages.buy, Pages.sell, Pages.mine, Pages.shop = Page(), Page(), Page(), Page()
ns.UI = { CloseOnEscape = function(self) escapes = escapes + 1; self:Hide() end }
ns.Professions = { Shopping = {} }
ns.AuctionScan = function() scans = scans + 1 end

check("its pages are offered to the auction house's tabs", #Window.PAGES == 4 and Window.PAGES[1].key == "farm"
    and Window.PAGES[4].key == "ledger")
check("the prices page is labelled Price Graph", Window.PAGES[3].key == "prices" and Window.PAGES[3].label == "Price Graph")

local ah = Frame()
ah.strata, ah.scale, ah.right = "MEDIUM", 1, 820
local picked, closed = {}, 0
local function OnPick(key) picked[#picked + 1] = key end
local function OnClose() closed = closed + 1 end

Window.DockTo(ah, "prices", 4, OnPick, OnClose)
local window = Window.Docked()
check("docked, it shows its page right of Blizzard's window", window and window.shown and Pages.prices.shown
    and window.points.TOPLEFT[1] == ah and window.points.TOPLEFT[2] == "TOPRIGHT" and window.points.TOPLEFT[3] == 4)
check("top to bottom, at Blizzard's window's height", window.points.BOTTOMLEFT[1] == ah
    and window.points.BOTTOMLEFT[2] == "BOTTOMRIGHT")
check("at its own width where the screen has room for it", window.w == 1144)
check("on Blizzard's strata", window.strata == "MEDIUM")
check("raised over other frames on it", window.raised)
check("and says which page it shows", picked[1] == "prices")
ah.right = 1300
Window.DockTo(ah, "farm", 4, OnPick, OnClose)
check("narrowed to end at the screen's right edge, in its own scale", window.w == math.floor((1920 - 1300) / 0.8 - 4)
    and Pages.farm.shown and not Pages.prices.shown and picked[2] == "farm")
ah.right = 1500
local shows = Pages.farm.shows
Window.FitDock()
check("never under its minimum, where the pages still lay out", window.w == 700)
window.scripts.OnSizeChanged(window, 700, 538)
check("and wider than the room there is, it is kept whole on the screen, over Blizzard's window",
    window.insets[1] == 0 and window.insets[2] == 0 and window.insets[3] == 0 and window.insets[4] == 0)
check("and its page redrawn at the new width", Pages.farm.shows == shows + 1)
Window.FitDock()
check("a fit that changes nothing redraws nothing", Pages.farm.shows == shows + 1)
screen.scale, ah.scale = 2, 2
Window.FitDock()
check("Blizzard's window and the screen read in their own scales", window.w == math.floor((1920 - 1500) * 2 / 0.8 - 4))
screen.scale, ah.scale, ah.right = 1, 1, 820
Window.FitDock()
check("a move back gives it its full width again", window.w == 1144)

window.scripts.OnDragStart(window)
window.scripts.OnDragStop(window)
check("a drag on it is the auction house's Shift + drag", moves[1] == "start" and moves[2] == "stop"
    and not window.moving and freeStops == 0)

window:Hide()
check("its X closes it as its tab would", closed == 1 and not Window.Docked())
check("and puts it back to its free spot, size and strata", placed == 1 and window.w == 1144 and window.h == 650
    and window.strata == "HIGH" and window.points.CENTER and not window.points.BOTTOMLEFT)
window.scripts.OnSizeChanged(window, 1144, 650)
check("free again, it may be dragged most of the way off the screen as before", window.insets[1] > 1000
    and window.insets[2] < -1000)
local fits = Pages.farm.shows
Window.FitDock()
check("free, a move of Blizzard's window leaves it alone", window.w == 1144 and Pages.farm.shows == fits)

ns.foreverSkin = true
ns.Market.Style.FOREVER_TITLE_H, ns.Market.Style.FOREVER_SIDE = 21, 2
ah.right = 1300
Window.DockTo(ah, "farm", 4, OnPick, OnClose)
check("with the Forever look, its frame's title bar and sides stay within Blizzard's window's height",
    window.points.TOPLEFT[3] == 4 + 2 and window.points.TOPLEFT[4] == -21 and window.points.BOTTOMLEFT[4] == 2
    and window.w == math.floor((1920 - 1300) / 0.8 - 4 - 2 * 2))
ns.foreverSkin, ah.right = nil, 820
Window.Undock()
check("put away by the auction house, it is not a close", closed == 1 and not window.shown and not Window.Docked())

Window.DockTo(ah, "reagents", 4, OnPick, OnClose)
Window.Open("prices")
check("opened from the key or /market while docked, it goes free and its tab lets go", closed == 2
    and not Window.Docked() and window.shown and window.points.CENTER and window.scale == 0.8)
window.scripts.OnDragStart(window)
window.scripts.OnDragStop(window)
check("free, it drags and keeps its spot", window.moving and freeStops == 1 and #moves == 2)
local count = #picked
window:Hide()
check("free, closing it tells no tab", closed == 2 and #picked == count)

Pages.farm.WIDTH = 966
Window.Open("farm")
check("Farm opens at its own, narrower width", window.w == 966)
Window.Open("prices")
check("and the other pages at the window's", window.w == 1144)
Window.DockTo(ah, "farm", 4, OnPick, OnClose)
check("docked with room to spare, Farm keeps its narrower width", window.w == 966)
window:Hide()
Pages.farm.WIDTH = nil

-- Over the auction house.
for _, page in pairs(Pages) do
    local build = page.Build
    page.builds = 0
    page.Build = function(parent) page.builds, page.parent = page.builds + 1, parent; build() end
end
local panelBody = Frame()
Window.ShowPageIn(panelBody, "sell")
Window.HidePage("sell")
check("a page the panel shows is built in a holder of the panel's", Pages.sell.builds == 1
    and Pages.sell.parent.parent == panelBody)
ah.w, ah.h, ah.scale = 800, 538, 1
local asides = 0
Window.Cover(ah, function() asides = asides + 1 end)
local fullBar = tabBars[2]
check("Full Window shows it over Blizzard's window, from its top left corner", window.shown
    and window.points.TOPLEFT[1] == ah and window.points.TOPLEFT[2] == "TOPLEFT" and Window.Covering())
check("a strata above Blizzard's", window.strata == "HIGH")
check("as big as its own size, or Blizzard's window and its tabs in its scale",
    window.w == 1144 and window.h == 538 / 0.8 + 40)
check("with every page as a tab: Buy, Sell, My Auctions, Shopping List, Farm, Price Graph, Reagents and Ledger",
    fullBar and fullBar.shown and not tabBars[1].shown and #fullBar.pages == 8 and fullBar.pages[1].key == "buy"
    and fullBar.pages[4].key == "shop" and fullBar.pages[5].key == "farm" and fullBar.pages[6].key == "prices"
    and fullBar.pages[7].key == "reagents" and fullBar.pages[8].key == "ledger")
check("on Buy", Pages.buy.shown and fullBar.painted == "buy")
check("with Scan Prices and Blizzard's window in its title bar", bars["Scan Prices"].shown
    and bars["Blizzard's Auction House"].shown)
bars["Scan Prices"].fitted = nil
Window.Refresh()
check("each scan line fits Scan Prices to its label again",
    bars["Scan Prices"].fitted == "Scan Prices")
check("Professions' panels sit beside it", Window.Docked() == window)
fullBar.pick("sell")
check("Sell is the panel's page, moved here and not built again", Pages.sell.shown and not Pages.buy.shown
    and Pages.sell.builds == 1 and Pages.sell.parent.parent ~= panelBody)
bars["Scan Prices"].click()
check("Scan Prices scans", scans == 1)
moves = {}
window.scripts.OnDragStart(window)
window.scripts.OnDragStop(window)
check("a drag on it is the auction house's Shift + drag", moves[1] == "start" and moves[2] == "stop")
local acted = 0
Pages.sell.KeyAction = function(key) if key == "SPACE" then return function() acted = acted + 1 end end end
window.scripts.OnKeyDown(window, "SPACE")
check("with Post With Keys off, Space is left alone", acted == 0 and escapes == 1 and not window.shown)
check("and as with Escape, closing it closes the auction house", closes == 1 and not Window.Covering())
check("and it goes back to its free spot", window.w == 1144 and window.h == 650 and window.strata == "HIGH"
    and window.points.CENTER and tabBars[1].shown and not fullBar.shown and not bars["Scan Prices"].shown)
settings.postKeys = true
Window.Cover(ah, function() asides = asides + 1 end)
check("next time it opens on the page it was last on", Pages.sell.shown and fullBar.painted == "sell")
window.scripts.OnKeyDown(window, "SPACE")
check("with Post With Keys on, Space posts", acted == 1 and window.shown)
bars["Blizzard's Auction House"].click()
check("its Blizzard button asks for Blizzard's window", asides == 1)
Window.Uncover()
check("put away for Blizzard's window, it does not close the auction house", closes == 1 and not window.shown
    and not Window.Covering() and not Pages.sell.shown)
Window.Open()
check("opened free afterwards, it is on one of its own pages", Pages.farm.shown and tabBars[1].painted == "farm")
window:Hide()

Window.Cover(ah, function() asides = asides + 1 end)
uiHidden = true
Window.Uncover()
uiHidden = false
check("put away while the UI is hidden, Sell still lets go", not Pages.sell.shown and not window.shown
    and not Window.Covering() and closes == 1)
Window.Open("farm")
check("so Farm opens alone afterwards", Pages.farm.shown and not Pages.sell.shown)
window:Hide()

Window.DockTo(ah, "reagents", 4, OnPick, OnClose)
local closedBefore = closed
uiHidden = true
Window.Undock()
uiHidden = false
check("undocked while the UI is hidden, it lets go of Blizzard's window", not Pages.reagents.shown
    and not Window.Docked() and closed == closedBefore)
Window.Open("prices")
check("and opens free afterwards", Pages.prices.shown and window.points.CENTER)
window:Hide()

Window.DockTo(ah, "reagents", 4, OnPick, OnClose)
closedBefore = closed
uiHidden = true
Window.Hide()
uiHidden = false
check("hidden while the UI is hidden, its tab still lets go", not Pages.reagents.shown
    and not Window.Docked() and closed == closedBefore + 1)

-- The pages at the docked window's narrowest, from the numbers their files lay out with.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end
local function Numbers(path)
    local found = {}
    for names, values in Read(path):gmatch("local ([%u_][%w_, ]-) = ([%d%., ]+)\r?\n") do
        local list = {}
        for v in values:gmatch("[%d%.]+") do list[#list + 1] = tonumber(v) end
        local i = 0
        for name in names:gmatch("[%u%d_]+") do
            i = i + 1
            found[name] = list[i]
        end
    end
    return found
end
local win, prices = Numbers("NaowhForever_Market/UI/Window.lua"), Numbers("NaowhForever_Market/UI/Prices.lua")
local farm, finder = Numbers("NaowhForever_Market/UI/Farm.lua"), Numbers("NaowhForever_Market/View/Finder.lua")
local money = Numbers("Shared/UI/Money.lua")
local pad = tonumber(Read("Shared/Style.lua"):match("WINDOW_PAD = (%d+)"))
local body = win.DOCK_MIN_W - pad * 2
check("at its narrowest, the window's three tabs fit along its bottom", win.TAB_W * 3 <= body)
local priceRoom = body - prices.LIST_W - prices.PANE_GAP
local moneyW = money.GOLD_W + (money.SMALL_W + money.BOX_GAP) * 2
check("Price Graph's Watch row, its x included, fits beside its list",
    moneyW + finder.WATCH_GAP + prices.BUTTON_W + finder.GAP + prices.BUTTON_H <= priceRoom)
local strip = farm.ROW_IN * 2 + farm.STRIP_ICON
local map = body - farm.ZONES_W - farm.PANE_GAP
check("Farm's strip drops its 14 days of prices there", map < farm.STRIP_FULL_W)
check("and still leaves its item's name room", map - strip - farm.PANE_GAP * 2 - farm.KV_NARROW_W - farm.OPEN_W
    - farm.ROW_IN >= farm.STRIP_ICON * 2)
local full = tonumber(Read("NaowhForever_Market/View/Style.lua"):match("WINDOW_W = (%d+)")) - pad * 2
check("at the window's own width the strip has all of it", full - farm.ZONES_W - farm.PANE_GAP >= farm.STRIP_FULL_W)
check("the strip's full layout leaves its item's name room too", farm.STRIP_FULL_W - strip - farm.PANE_GAP * 3
    - farm.SPARK_W - farm.KV_W - farm.OPEN_W - farm.ROW_IN >= farm.STRIP_ICON * 2)

local told, on = {}, false
local M = ns.Market
M.On = function() return on end
M.BagWorth = { Changed = function() told[#told + 1] = "bags" end }
M.Crafts = { Changed = function() told[#told + 1] = "crafts" end }
M.Farm = { Changed = function() told[#told + 1] = "farm" end }
ns.MarketPricesSeen({ 2589 }, 1)
check("prices seen at the auction house reach nothing with The Market off", #told == 0)
on = true
ns.MarketPricesSeen({ 2589 }, 1)
check("and with it on, Bag Worth, Crafts and Farm, without a redraw or the price history, which takes medians",
    table.concat(told, ", ") == "bags, crafts, farm")

print(("test-market-window: %d checks passed"):format(checks))
