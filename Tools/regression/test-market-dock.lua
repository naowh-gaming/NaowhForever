-- Run with Lua 5.1 from the repository root: The Market at an auctioneer. Blizzard's window is left as it is and
-- The Market's panel docks to its right with Buy first, then Sell, My Auctions and, with Professions loaded, Shopping
-- List, and follows Blizzard's Buy, Sell and Auctions tabs; its X closes only the panel until the next visit, with no
-- button left to bring it back. Farm, Price Graph and Reagents tabs follow Blizzard's last tab: each docks The Market's
-- window in the panel's place, and the picked tab again or the window's X brings the panel back. Leaving the
-- auctioneer puts it all away. Post With Keys and Bag Worth start off. The gamepad interface style keeps The Market
-- on but off Blizzard's windows. With Full Window on (off by default), Blizzard's
-- window is faded out and The Market's window covers it instead; its Blizzard button steps aside to the panel for
-- the visit, with a The Market button above Blizzard's window to go back, and Blizzard's window is always faded back in
-- when The Market lets go of it.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Load(path, env)
    local fn = assert(loadfile(path))
    setfenv(fn, setmetatable(env, { __index = _G }))
    fn()
end

local defaults
Load("NaowhForever_Market/Market.lua", {
    _G = { NaowhForever = {
        FEATURES = { market = { enabled = false } },
        UI = { ModuleSettings = function(_, d) defaults = d; return {} end },
    } },
    C_CVar = { GetCVarDefault = function() return "2" end },
})
check("Full Window starts off", defaults.fullWindow == false)
check("Post With Keys starts off", defaults.postKeys == false)
check("Bag Worth starts off", defaults.bagWorth == false)

local padNs = {
    FEATURES = { market = { enabled = true } },
    UI = { ModuleSettings = function() return { Get = function(k) return k == "enabled" end } end },
    GamepadStandDown = function() return true end,
}
Load("NaowhForever_Market/Market.lua", { _G = { NaowhForever = padNs }, C_CVar = { GetCVarDefault = function() return "2" end } })
check("the gamepad interface style leaves The Market on", padNs.Market.On())
check("the gamepad interface style takes it off Blizzard's windows", not padNs.Market.PanelsOn())
padNs.GamepadStandDown = function() return false end
check("without it, it is on Blizzard's windows too", padNs.Market.PanelsOn())

local function Frame()
    local f = { shown = false, alpha = 1, scripts = {}, points = {} }
    function f:IsShown() return self.shown end
    function f:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetPoint(point, relative, relativePoint) self.points[point] = { relative, relativePoint } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:HookScript(name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...) if old then old(...) end; fn(...) end
    end
    function f:SetWidth(w) self.width = w end
    function f:GetRight() return self.right end
    function f:GetEffectiveScale() return 1 end
    function f:SetHeight() end
    function f:SetShown(on) if on then self:Show() else self:Hide() end end
    function f:SetText(text) self.text = text end
    function f:SetScale(s) self.scale = s end
    function f:GetScale() return 1 end
    function f:SetFrameStrata(s) self.strata = s end
    function f:Raise() self.raised = true end
    function f:GetFrameStrata() return "MEDIUM" end
    function f:EnableKeyboard(on) self.keys = on end
    function f:SetPropagateKeyboardInput() end
    function f:RegisterForDrag(button) self.drag = button end
    function f:UnregisterAllEvents() end
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    return f
end

local settings = { postKeys = false }
local marketOn = true
local closes, resets = 0, 0

local MODES = { Buy = {}, ItemBuy = {}, CommoditiesBuy = {}, WoWTokenBuy = {}, ItemSell = {}, CommoditiesSell = {},
    WoWTokenSell = {}, Auctions = {} }
local ah = Frame()
ah.right = 800
local screen = Frame()
screen.right = 1920
ah.BuyTab, ah.SellTab, ah.AuctionsTab = Frame(), Frame(), Frame()
ah.Tabs = { ah.BuyTab, ah.SellTab, ah.AuctionsTab }
function ah:SetPostItem(location) location.locked = true end
function ah:SetDisplayMode(mode) self.displayMode = mode end
function ah:GetDisplayMode() return self.displayMode end
function ah:Open() self:Show() end
function ah:Close() self:Hide() end

local function Page()
    local page = { shows = 0 }
    function page.Build() page.built = true end
    function page.Show() page.shows, page.shown = page.shows + 1, true end
    function page.Hide() page.shown = false end
    function page.PickLocation(location) page.picked = location end
    return page
end

local pickTab, panel, panelPages, row, moved, opened, listAsked
local buttons, under = 0, 0
local made, timers = {}, {}
local window = Frame()
local docking, covering, lastButton
local ns
local onMoved
local Window = {
    PAGES = { { key = "farm", label = "Farm" }, { key = "reagents", label = "Reagents" },
        { key = "prices", label = "Price Graph" } },
    Open = function(page) opened = page or true end,
    DockTo = function(to, page, _, onPick, onClose)
        docking = { to = to, page = page, onPick = onPick, onClose = onClose }
        window:Show()
        onPick(page)
    end,
    Docked = function() if docking or covering then return window end end,
    ShowPageIn = function(_, key)
        local page = ns.Market.Pages[key]
        if not page.built then page.Build() end
        page.Show()
    end,
    HidePage = function(key) if ns.Market.Pages[key].built then ns.Market.Pages[key].Hide() end end,
    Covering = function() return covering ~= nil end,
    Cover = function(to, onAside)
        covering = { to = to, aside = onAside }
        window:Show()
    end,
    Uncover = function()
        if not covering then return end
        covering = nil
        window:Hide()
    end,
    Undock = function()
        if not docking then return end
        docking = nil
        window:Hide()
    end,
}
function Window.Hide()
    local was = docking
    docking = nil
    window:Hide()
    if was then was.onClose() end
end
ns = {
    AuctionHouseShown = function() return ah.shown and not ah.away end,
    OnAuctionHouseMoved = function(fn) onMoved = fn end,
    Market = {
        Settings = { Get = function(k) return settings[k] end, OnChange = function() end },
        PanelsOn = function() return marketOn end,
        Sell = { Reset = function() resets = resets + 1 end },
        Style = { BAR_GAP = 8, TEXT_SIZE = 12, HAVE_RGB = {}, DOCK_W = 380, DOCK_PAD = 10 },
        Pages = { buy = Page(), sell = Page(), mine = Page(), shop = Page() },
        Watch = { UnderCount = function() return under end },
        Tabs = {
            Build = function(_, _, pages, onPick)
                pickTab, panelPages = onPick, pages
                return Frame()
            end,
            Paint = function() end,
        },
        HouseTabs = {
            New = function(parent, pages, onClick)
                row = Frame()
                row.parent, row.pages, row.click, row.buttons = parent, pages, onClick, { Frame(), Frame(), Frame() }
                return row
            end,
            Style = function(_, after, tabs) row.after, row.copies = after, tabs; row.styled = (row.styled or 0) + 1 end,
            Paint = function(_, key) row.picked = key end,
        },
        Move = {
            Hook = function(frame) moved = frame end,
            Start = function() end,
            Stop = function() end,
        },
        Window = Window,
    },
    Professions = { Shopping = {} },
    Shared = { Parts = {
        Panel = function()
            panel = Frame()
            panel.close, panel.title = Frame(), Frame()
            panel.backdrop = { Paint = function() end }
            return panel
        end,
        BarButton = function() buttons = buttons + 1; return Frame() end,
    } },
    L = function(text) return text end,
    Font = function() return Frame() end,
    Button = function(_, _, _, _, onClick)
        buttons = buttons + 1
        local button = Frame()
        button.click, lastButton = onClick, button
        return button
    end,
    Tooltip = function() end,
    Apply = function() end,
}
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end
local Pages = ns.Market.Pages
Pages.sell.DOCK_W = 668
function Pages.buy.ShowList() listAsked = true end

local lib
Load("NaowhForever_Market/UI/Dock.lua", {
    _G = { NaowhForever = ns, AuctionHouseFrame = ah },
    UIParent = screen,
    AuctionHouseFrameDisplayMode = MODES,
    C_AddOns = { IsAddOnLoaded = function() return true end },
    C_AuctionHouse = { CloseAuctionHouse = function() closes = closes + 1 end },
    C_Item = { UnlockItem = function(location) location.locked = false end },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    LibStub = function() return lib end,
    CreateFrame = function()
        local f = Frame()
        made[#made + 1] = f
        return f
    end,
    InCombatLockdown = function() return false end,
    hooksecurefunc = function(t, name, fn)
        local old = t[name]
        t[name] = function(...) if old then old(...) end; fn(...) end
    end,
})
local Dock = ns.Market.Dock

local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

check("nothing shows before the auction house opens", not Dock.Shown() and row == nil)
check("Shift + drag is hooked on Blizzard's window", moved == ah)

ah:Open()
check("Blizzard's window is left as it is", ah.shown and ah.alpha == 1)
check("The Market's panel shows beside it", Dock.Shown() and panel.points.TOPLEFT[1] == ah
    and panel.points.TOPLEFT[2] == "TOPRIGHT" and panel.points.BOTTOMLEFT[2] == "BOTTOMRIGHT")
check("on Blizzard's strata", panel.strata == "MEDIUM")
check("raised over other frames on it", panel.raised)
check("with Buy first, as Blizzard's window opens on Buy", Pages.buy.shown and not Pages.sell.shown
    and not Pages.mine.shown)
check("its tabs are Buy, Sell, My Auctions and, with Professions loaded, Shopping List", #panelPages == 4
    and panelPages[1].key == "buy" and panelPages[2].key == "sell" and panelPages[3].key == "mine"
    and panelPages[4].key == "shop" and panelPages[4].label == "Shopping List")
check("it has no button to The Market's window, and nothing sits above Blizzard's window", buttons == 0)
check("Shift + drag on the panel moves Blizzard's window", panel.drag == "LeftButton"
    and panel.scripts.OnDragStart == ns.Market.Move.Start and panel.scripts.OnDragStop == ns.Market.Move.Stop)
check("Professions' panels sit beside the panel", ns.MarketAuctionWindow() == panel)
check("with Post With Keys off, the panel takes no keys", panel.keys == false)

check("Farm, Price Graph and Reagents tabs show on Blizzard's window", row and row.shown and row.parent == ah
    and #row.pages == 3 and row.pages[1].key == "farm" and row.pages[2].key == "prices"
    and row.pages[3].key == "reagents" and row.pages[2].label == "Price Graph")
check("after Blizzard's Auctions tab, drawn from Blizzard's own tabs", row.after == ah.AuctionsTab
    and row.copies == ah.Tabs)
check("none picked while the panel shows", row.picked == nil)
local styled = row.styled
RunTimers()
check("and drawn again a frame later, once a skin has had its turn", row.styled == styled + 1)
check("QoL's Scan Prices follows them", ns.MarketAuctionTabs() == row.buttons[3])

local watchLine = made[1]
check("with nothing on your watch list under your price, no watch line", watchLine.text and not watchLine.shown)
under = 2
Dock.Refresh()
check("on Buy, the watch list itself shows them, so no line", not watchLine.shown)
pickTab("sell")
check("on another tab, items under your price show a line on the panel", watchLine.shown
    and watchLine.text.text == "2 on your watch list are at or under your price")
watchLine.scripts.OnClick()
check("clicking it opens the panel's Buy tab on the watch list", listAsked and Pages.buy.shown
    and not Pages.sell.shown and not opened and not watchLine.shown)
under = 0
pickTab("sell")
check("the line goes when none are under", not watchLine.shown)

ah:SetDisplayMode(MODES.ItemSell)
check("Blizzard's Sell tab brings the panel to Sell", Pages.sell.shown and not Pages.buy.shown)
check("which widens the panel for Up Next's column when the screen has room", panel.width == 668)
screen.right = 1200
Dock.Fit()
check("and keeps it narrow when it does not", panel.width == 380)
screen.right = 1920
Dock.Fit()
check("moving Blizzard's window looks again", panel.width == 668)
ah:SetDisplayMode(MODES.Auctions)
check("Blizzard's Auctions tab brings it to My Auctions", Pages.mine.shown and not Pages.sell.shown)
check("and the other tabs keep the narrow panel", panel.width == 380)
ah:SetDisplayMode(MODES.CommoditiesBuy)
check("and Blizzard's Buy, a commodity's page too, to Buy", Pages.buy.shown and not Pages.mine.shown)
pickTab("sell")
ah:SetDisplayMode(MODES.CommoditiesBuy)
check("a tab you pick on the panel stays while Blizzard's stays where it was", Pages.sell.shown)
pickTab("shop")
check("Shopping List is a page of the panel", Pages.shop.shown and not Pages.sell.shown)
pickTab("buy")

pickTab("mine")
check("My Auctions takes Sell's place", Pages.mine.shown and not Pages.sell.shown)

local location = {}
ah:SetPostItem(location)
check("right-clicking a bag item picks it on Sell", Pages.sell.shown and Pages.sell.picked == location)
check("and unlocks it, so Sell can post it", not location.locked)

row.click("prices")
check("Price Graph docks The Market's window right of Blizzard's on its page", docking and docking.to == ah
    and docking.page == "prices" and window.shown)
check("in the panel's place", not Dock.Shown() and not Pages.sell.shown)
check("its tab shows as picked", row.picked == "prices")
check("Professions' panels sit beside the window", ns.MarketAuctionWindow() == window)
docking.onPick("reagents")
check("a page picked on the window moves the picked tab", row.picked == "reagents")
row.click("farm")
check("another tab moves the docked window to its page", docking.page == "farm" and row.picked == "farm"
    and not Dock.Shown())
row.click("farm")
check("the picked tab again closes the window and brings the panel back", not window.shown and Dock.Shown()
    and row.picked == nil and Pages.sell.shown and ns.MarketAuctionWindow() == panel)

row.click("reagents")
window:Hide()
docking.onClose()
docking = nil
check("the window's X brings the panel back too", Dock.Shown() and row.picked == nil)

row.click("farm")
location = {}
ah:SetPostItem(location)
check("right-clicking a bag item while a page is docked brings the panel back on Sell with it",
    not window.shown and Dock.Shown() and Pages.sell.shown and Pages.sell.picked == location and not location.locked)

panel.close.scripts.OnClick()
check("the X closes only the panel", not Dock.Shown() and ah.shown and closes == 0)
check("and stops its page", not Pages.sell.shown)
check("with no button to bring it back", buttons == 0)
check("Professions' panels go back beside Blizzard's window", ns.MarketAuctionWindow() == nil)
check("the tabs under Blizzard's window stay", row.shown)
location = {}
ah:SetPostItem(location)
check("a closed panel is not opened by a bag item", not Dock.Shown() and location.locked)
row.click("prices")
check("a tab still docks the window", docking and docking.page == "prices" and not Dock.Shown())
row.click("prices")
check("and closing it brings the panel back", Dock.Shown())

row.click("farm")
ah:Close()
check("leaving the auctioneer puts the window away", not window.shown and docking == nil)
check("and the tabs and panel with it", not row.shown and not Dock.Shown())
check("and forgets what you posted", resets == 1)

ah:SetDisplayMode(MODES.Buy)
ah:Open()
check("the next visit opens the panel again, not the window last docked", Dock.Shown() and not window.shown
    and row.shown and row.picked == nil)
check("on the tab Blizzard's window opens on", Pages.buy.shown and not Pages.mine.shown)

ah:Close()
lib = { internalState = { Tabs = { Frame(), Frame() } } }
ah:Open()
check("another addon's tabs after Blizzard's are followed, not covered", row.after == lib.internalState.Tabs[2])
ah:Close()
lib = nil

ah:Open()
RunTimers()
row.click("farm")
check("Blizzard's window moved away is heard", onMoved ~= nil and docking and window.shown)
ah.away = true
onMoved()
check("shrunk away by another addon's own auction window, the panel and the docked window go",
    not Dock.Shown() and not window.shown and not row.shown and docking == nil
    and ns.MarketAuctionWindow() == nil)
ah:SetDisplayMode({})
check("and stay gone", not Dock.Shown() and not window.shown)
ah.away = false
onMoved()
check("put back, they wait a frame for it to reach its place", not Dock.Shown())
RunTimers()
check("then the panel and the tabs return", Dock.Shown() and row.shown and ns.MarketAuctionWindow() == panel)
ah.away = true
onMoved()
ah:Close()
ah.away = false
ah:Open()
check("closed while away, the next visit opens as usual", Dock.Shown() and row.shown)
ah:Close()

settings.postKeys = true
ah:Open()
check("with Post With Keys on, the panel takes keys", panel.keys == true)
row.click("farm")
marketOn = false
ns.Apply()
check("turning The Market off at the auctioneer puts everything away", not row.shown and not window.shown
    and not Dock.Shown() and ns.MarketAuctionTabs() == nil and ns.MarketAuctionWindow() == nil)
ah:Close()

ah:Open()
check("with The Market off, Blizzard's window is left alone", ah.alpha == 1 and not Dock.Shown()
    and not row.shown and buttons == 0)
ah:Close()

-- Full Window.
marketOn = true
settings.postKeys = false
ah:Close()
settings.fullWindow = true
Window.Open = function(page) opened = page; window:Show() end
ah:Open()
check("with Full Window on, The Market's window covers Blizzard's", covering and covering.to == ah and window.shown)
check("Blizzard's window is faded out, not hidden", ah.alpha == 0 and ah.shown)
check("and the panel and the tabs under Blizzard's window stay away", not Dock.Shown() and not row.shown
    and ns.MarketAuctionTabs() == nil)
check("Professions' panels sit beside the window", ns.MarketAuctionWindow() == window)
check("bag items and Farm's Sell count it as at the auction house", Dock.AtAuction())
check("nothing sits above Blizzard's window", buttons == 0)
location = {}
ah:SetPostItem(location)
check("right-clicking a bag item opens the window's Sell with it", opened == "sell"
    and Pages.sell.picked == location and not location.locked)

covering.aside()
check("its Blizzard button fades Blizzard's window back in and lets go of it", ah.alpha == 1 and not covering)
check("with the panel and the tabs under it, as without Full Window", Dock.Shown() and row.shown)
local back = lastButton
check("and a The Market button above Blizzard's window, at its top right", buttons == 1 and back.shown
    and back.points.BOTTOMRIGHT[1] == ah and back.points.BOTTOMRIGHT[2] == "TOPRIGHT")
row.click("farm")
check("a tab under Blizzard's window still docks the window there", docking and docking.page == "farm")
back.click()
check("The Market button covers Blizzard's window again", covering and ah.alpha == 0 and not docking
    and not Dock.Shown() and not row.shown and not back.shown)

covering = nil
window:Hide()
ah:Close()
check("when the window's X closes the auction house, Blizzard's window is faded back in", ah.alpha == 1)
ah:Open()
check("the next visit covers it again, whatever was picked last time", covering and ah.alpha == 0)
covering.aside()
ah:Close()
ah:Open()
check("stepping aside lasts only that visit", covering and ah.alpha == 0 and buttons == 1)

settings.fullWindow = false
ns.Apply()
check("turning Full Window off at the auctioneer brings Blizzard's window and the panel back", not covering
    and ah.alpha == 1 and Dock.Shown() and row.shown and not back.shown)
settings.fullWindow = true
ns.Apply()
check("and on again covers it", covering and ah.alpha == 0 and not Dock.Shown())
marketOn = false
ns.Apply()
check("turning The Market off lets go of Blizzard's window", not covering and ah.alpha == 1 and not Dock.Shown()
    and not back.shown)
ah:Close()
check("Escape and X stay Blizzard's while it is not covered", closes == 0)
settings.fullWindow = nil

-- Without Professions the panel has no Shopping List tab.
ns.Professions = nil
panel, panelPages = nil, nil
marketOn = true
ah.scripts = {}
ah.shown = true
Load("NaowhForever_Market/UI/Dock.lua", {
    _G = { NaowhForever = ns, AuctionHouseFrame = ah },
    UIParent = screen,
    AuctionHouseFrameDisplayMode = MODES,
    C_AddOns = { IsAddOnLoaded = function() return true end },
    C_Item = { UnlockItem = function() end },
    C_Timer = { After = function() end },
    CreateFrame = function() return Frame() end,
    InCombatLockdown = function() return false end,
    hooksecurefunc = function() end,
})
check("without Professions, the panel has Buy, Sell and My Auctions only", #panelPages == 3
    and panelPages[3].key == "mine")

print(checks .. " market dock checks passed")
