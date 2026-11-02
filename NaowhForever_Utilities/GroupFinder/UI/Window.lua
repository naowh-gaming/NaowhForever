-- Window.lua: the Group Finder's window (/nflfg): Forever's listings, newest first, with each leader's card when they run Naowh Forever.
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local S = GF.Settings
local Listings, Search, Browse = GF.Listings, GF.Search, GF.Browse
local Parts, View = ns.Shared.Parts, ns.Shared.View

local St = UI.Style
local HEADER, INSET, CARD_EDGE = St.WINDOW_HEADER, St.CONTENT_INSET, 6
local SCROLL_GAP, BAR_GAP = St.SCROLL_GAP, St.BAR_GAP
local WINDOW_KEY = "groupFinderWindow"
local NO_EVENTS = {}
local REDRAWN_BY = { "listings", "listing", "search", "card", "noreply", "offline" }

local TEXT_TITLE = ns.L("Looking For Group")
local TEXT_GROUPS = ns.L("%d groups")
local TEXT_SEARCH = ns.L("Search")
local TEXT_SEARCH_TIP = ns.L("Search Forever's group finder for groups at your level.")
local TEXT_FIRST = ns.L("Search to see the groups listed in Forever's group finder.")
local TEXT_SEARCHING = ns.L("Searching...")
local TEXT_FAILED = ns.L("The search failed. Wait a moment and search again.")
local TEXT_UNAVAILABLE = ns.L("Forever's group finder has nothing to search for your level yet.")
local TEXT_LOCKED = ns.L("Listings cannot be read during an encounter.")
local TEXT_NONE = ns.L("No groups found.")
local TURNED_ON = ns.L("Group Finder turned on. Turn it off on its settings page.")

local window, view
local listening = false

local function Newest(a, b)
    if a.mine ~= b.mine then return a.mine end
    return a.age < b.age
end

local function Status()
    local state = Search.state
    if Listings.state == "locked" then return TEXT_LOCKED end
    if state == "searching" then return TEXT_SEARCHING end
    if state == "failed" then return TEXT_FAILED end
    if state == "unavailable" then return TEXT_UNAVAILABLE end
    if not Listings.searched then return TEXT_FIRST end
end

local function DrawRows(v)
    local n = Listings.Read()
    Browse.Ask()
    local order = v.order
    for i = 1, n do order[i] = Listings.entries[i] end
    for i = #order, n + 1, -1 do order[i] = nil end
    table.sort(order, Newest)
    v:Clear()
    local status = Status()
    if status then v:Note(status) end
    if Search.state ~= "failed" then
        for i = 1, n do v:Add("listing", order[i], i) end
        if n == 0 and not status then v:Note(TEXT_NONE) end
    end
    v:Fit(NO_EVENTS)
    window.subtitle:SetText(Listings.searched and TEXT_GROUPS:format(n) or "")
end

local function Redraw()
    if window and window:IsShown() then view:QueueRedraw() end
end

local function OnSearch()
    Search.Run()
    Redraw()
end

local function Listen()
    if listening then return end
    listening = true
    for _, what in ipairs(REDRAWN_BY) do GF.Listen(what, Redraw) end
end

local function Build()
    window = Parts.Window(St.WINDOW_W, St.WINDOW_H, WINDOW_KEY)
    window.backdrop:Card(CARD_EDGE, HEADER + CARD_EDGE, CARD_EDGE, St.WINDOW_FOOTER + CARD_EDGE)
    local close = Parts.TitleBar(window, TEXT_TITLE, "", GF.PAGE)
    local search = Parts.BarButton(window, St.SEARCH, TEXT_SEARCH, TEXT_SEARCH_TIP, OnSearch, TEXT_SEARCH)
    search:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    window.subtitle:SetPoint("RIGHT", search, "LEFT", -BAR_GAP, 0)
    window.search = search
    Parts.FooterBrand(window, GF.PAGE)

    local scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -UI.CONTENT_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -St.SCROLLBAR - SCROLL_GAP, UI.FOOTER_ROOM)
    view = View.New(scroll, UI.Kinds, { Redraw = DrawRows })
    view:SetWidth(UI.LIST_W)
    view.order = {}
    scroll:SetScrollChild(view)
    window.scroll, window.view = scroll, view
    Listen()
end

function ns.OpenGroupFinder()
    if not GF.On() then
        S.Set("enabled", true)
        ns.Print(TURNED_ON)
    end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
    view:Redraw()
end

function ns.ToggleGroupFinder()
    if window and window:IsShown() then window:Hide() else ns.OpenGroupFinder() end
end

function UI.Window()
    return window
end

S.OnChange(function(key)
    if key == "enabled" and window and not GF.On() then window:Hide() end
end)
hooksecurefunc(ns, "Apply", function()
    if window and window:IsShown() then
        window.backdrop:Paint(1)
        view:Redraw()
    end
end)
