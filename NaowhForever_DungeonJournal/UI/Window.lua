-- Window.lua: the Dungeon Journal's window: its tabs, its lists, the page it shows and its search.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local List = J.DungeonList
local Home = J.Home
local Factions = J.FactionList
local FactionHome = J.FactionHome
local Filters = J.FiltersMenu
local Switch = J.FactionSwitch
local Parts = J.View.Parts
local St = J.Style
local WIDTH, HEIGHT, HEADER, PAD = St.WINDOW_W, St.WINDOW_H, St.WINDOW_HEADER, St.WINDOW_PAD
local FOOTER = St.WINDOW_FOOTER
local LIST_W, SEARCH_H, SCROLLBAR, CONTENT_INSET = St.LIST_W, St.SEARCH_H, St.SCROLLBAR, St.CONTENT_INSET
local PLACE_DOT, LIST_SHOWN, LIST_HIDDEN = St.PLACE_DOT, St.LIST_SHOWN, St.LIST_HIDDEN
local FACTION_W, FACTION_GAP = St.FACTION_W, St.FACTION_GAP
local TAB_H, TAB_GAP = St.TAB_H, St.TAB_GAP

local PAGE = "Dungeon Journal"
local SEARCH_DELAY = 0.15
local NEXT_FRAME = 0
local MIN_QUERY = 2
local SEARCH_ROOM = 8
local SEARCH_W = LIST_W - SEARCH_ROOM - FACTION_W * 2 - FACTION_GAP
local SEARCH_FULL_W = LIST_W - SEARCH_ROOM
local CARD_EDGE, CARD_RIGHT, CARD_LIST_GAP = 6, 4, 14
local LIST_TOP = 4
local SCROLL_TOP, SCROLL_RIGHT, VIEW_ROOM = 4, 4, 8
local FILTERS_GAP, BAR_GAP = 18, 12
local BACK_GAP, BACK_DROP = 16, 1
local BAR_TABS_W, BAR_TAB_GAP, BAR_SEARCH_GAP = 430, 18, 12
local HOME_ROW = 20
local FINDER = "finder"
local FINDER_TAB = { key = FINDER, label = "Loot Finder" }
local CRAFTING = "crafting"
local CRAFTING_TAB = { key = CRAFTING, label = "Crafting" }
local CRAFTING_TAB_W = 70
local PANE_COLUMNS = 1
local PANE_RIGHT = 10
local SCREEN_MARGIN = 32
local DUNGEONS = "dungeons"
local REPUTATION, PVP = "reputation", "pvp"
local RUNS = "runs"
local RUNS_TAB = { key = RUNS, label = "Runs" }
local TABS = {
    { key = DUNGEONS, label = "Dungeons & Raids" },
    { key = "reputation", label = "Reputation" },
    { key = "pvp", label = "PvP" },
}

local TEXT_SUBTITLE = ns.L("Dungeons and raids, reputation and PvP: what drops, your quests, and more.")
local TEXT_SEARCH = ns.L("Search items, bosses or factions")
local TEXT_SEARCH_SHORT = ns.L("Search")
local TEXT_SHOW_LIST = ns.L("Show the dungeon list")
local TEXT_HIDE_LIST = ns.L("Hide the dungeon list")
local TEXT_DATA = ns.L("Game data: WoW Forever ")
local TEXT_DATA_DATE = ns.L("That build came out on %s.")
local TEXT_DATA_HELP = ns.L("Faction rewards, their standings and prices, and the boss fights the kill counts follow, "
    .. "are read from it. A daily check moves them on to each new build.")
local TEXT_DATA_NOTE = ns.L("Game data: build ")
local TEXT_BACK = ns.L("Back")
local TEXT_HOME = { dungeons = "All Dungeons", reputation = "All Factions", pvp = "PvP Rank" }
local TEXT_FINDER = ns.L("Loot Finder")
local TEXT_FINDER_HINT = ns.L("Find loot from every dungeon by its slot, armor type and stats.")
local TEXT_CRAFTING = ns.L("Crafting")
local TEXT_CRAFTING_HINT = ns.L("Browse every profession's recipes: gear, consumables and enchants.")

local window, view, scroll, search, listFrame, factionFrame
local listCard, contentCard, finderButton, craftingButton
local selected
local awayForMap = false
local onClose
local shownTab
local picked = {}
local barTabs = {}
local titlePoint
local shownQuery = ""
local searchQueued = false
local clearing = false
local finding = false
local wantedBoss
local homeFrame, factionHome, runsFrame
local atHome = false
local Arrange, ShowHome, ApplyMode, DrawSelected, Find

local function DataDate(text)
    local day, month, year = tostring(text or ""):match("^(%d+) (%a+) (%d+)$")
    if not day then return text end
    return ns.L("%d %s %d"):format(tonumber(day), ns.L(month), tonumber(year))
end

local function TabOf(page)
    return page.tab or DUNGEONS
end

local function SavedTab()
    local tab = ns.AccountSettings().journalTab
    return (tab == "reputation" or tab == "pvp") and tab or DUNGEONS
end

local function Wide()
    return S.Get("newLayout") == true
end

local function HomeShown()
    return atHome and Wide() and shownTab ~= PVP and shownQuery == "" and not finding
end

local function HomeLinked()
    if not Wide() or shownTab == RUNS then return false end
    if shownQuery ~= "" or finding then return true end
    if shownTab == PVP then return selected ~= J.RANK end
    return not atHome
end

local function ShowLists()
    if not shownTab then return end
    local wide = Wide()
    local hidden = S.Get("listHidden") and not wide
    local dungeons = shownTab == DUNGEONS or shownTab == RUNS
    local sides = shownTab ~= "reputation"
    listFrame:SetShown(dungeons and not hidden and not wide)
    factionFrame:SetShown(not dungeons and not hidden and not wide)
    window.factionSwitch:SetShown(sides and not hidden and not S.Get("newLayout"))
    search:SetWidth(sides and SEARCH_W or SEARCH_FULL_W)
    if not dungeons then Factions.Layout(shownTab) end
end

local function ShowTab(tab)
    shownTab = tab
    ns.AccountSettings().journalTab = tab
    view.watchFactions = tab ~= DUNGEONS
    if S.Get("newLayout") then Arrange() else ShowLists() end
    Parts.PaintTabs(window.tabBar, tab)
end

local function FirstPage(tab)
    if tab == DUNGEONS then return J.Suggested() end
    if tab == "pvp" then return J.RANK end
    return Factions.First(tab) or J.Suggested()
end

local function ClearSearch()
    if search:GetText() ~= "" then
        clearing = true
        search:SetText("")
        clearing = false
    end
    shownQuery = ""
end

local function DrawPage(page)
    if page.rank then
        view:DrawRank()
    elseif page.tab then
        view:DrawFaction(page)
    else
        view:Draw(page)
    end
end

local function PaintFinder()
    if finderButton then Parts.LightBarIcon(finderButton, finding == FINDER) end
    if craftingButton then Parts.LightBarIcon(craftingButton, finding == CRAFTING) end
end

local function StopFinding()
    finding = false
    PaintFinder()
    if shownTab and S.Get("newLayout") then Parts.PaintTabs(window.tabBar, shownTab) end
end

local function Select(page)
    StopFinding()
    local tab = TabOf(page)
    if tab ~= shownTab then ShowTab(tab) end
    selected = page
    picked[tab] = page
    atHome = false
    ClearSearch()
    DrawSelected()
    scroll:SetVerticalScroll(0)
    ShowHome()
end

local function GoHome(tab)
    if tab == PVP then return Select(J.RANK) end
    StopFinding()
    ClearSearch()
    atHome = true
    if shownTab ~= tab then ShowTab(tab) end
    ApplyMode()
    ShowHome()
end

local function HomeClicked()
    GoHome(shownTab)
end

local function ShowRuns(run)
    StopFinding()
    ClearSearch()
    atHome = false
    if shownTab ~= RUNS then ShowTab(RUNS) end
    ApplyMode()
    ShowHome()
    J.RunsPage.Show(run)
end

local function TabPicked(tab)
    if tab == RUNS then return ShowRuns() end
    if tab == FINDER or tab == CRAFTING then
        if finding ~= tab then Find(tab) end
        return
    end
    if S.Get("newLayout") then return GoHome(tab) end
    Select(picked[tab] or FirstPage(tab))
end

local function RunSearch()
    searchQueued = false
    if not window:IsShown() then return end
    local query = strtrim(search:GetText()):lower()
    if #query < MIN_QUERY then query = "" end
    if query == shownQuery then return end
    shownQuery = query
    StopFinding()
    if query == "" then
        DrawSelected()
    else
        ApplyMode()
        view:DrawSearch(query, Select)
    end
    scroll:SetVerticalScroll(0)
    ShowHome()
end

local function OnSearch()
    if clearing or searchQueued then return end
    searchQueued = true
    C_Timer.After(SEARCH_DELAY, RunSearch)
end

local function IsItem(row, itemID)
    return row.itemID == itemID and (wantedBoss == nil or row.boss == wantedBoss)
end

local function GoToItem(itemID, boss)
    wantedBoss = boss
    local row = itemID and view:Find("item", IsItem, itemID)
    if not row then return end
    view:ScrollToRow(scroll, row)
    if not row.boss then return end
    if J.DungeonPane.shown then return J.DungeonPane.Pick(row.boss) end
    if view.pinned ~= row.boss then view:Pin(row.boss) end
end

local function OpenFound(boss, dungeon, itemID)
    Select(dungeon)
    GoToItem(itemID, boss)
end

function Find(mode)
    finding = finding ~= mode and mode
    if finding then
        ClearSearch()
        ApplyMode()
        if finding == CRAFTING then view:DrawCrafting() else view:DrawFinder(OpenFound) end
        if S.Get("newLayout") then Parts.PaintTabs(window.tabBar, finding) end
    else
        DrawSelected()
    end
    scroll:SetVerticalScroll(0)
    PaintFinder()
    ShowHome()
end

local function FinderClicked()
    Find(FINDER)
end

local function CraftingClicked()
    Find(CRAFTING)
end

local function FinderLeave(button)
    PaintFinder()
    GameTooltip:Hide()
end

local function PlaceCrafting()
    local on = S.Get("crafting")
    if on and not craftingButton then
        craftingButton = Parts.BarButton(window, St.HAMMER, TEXT_CRAFTING, TEXT_CRAFTING_HINT, CraftingClicked)
        craftingButton:SetScript("OnLeave", FinderLeave)
    end
    if craftingButton then
        local favourites = window.favourites
        local left = finderButton and finderButton:IsShown() and finderButton
            or favourites and favourites:IsShown() and favourites or window.recent
        craftingButton:ClearAllPoints()
        craftingButton:SetPoint("RIGHT", left, "LEFT", -BAR_GAP, 0)
        craftingButton:SetShown(on and not S.Get("newLayout"))
    end
    if finding == CRAFTING and not on then
        StopFinding()
        DrawSelected()
        ShowHome()
    end
end

local function PlaceFinder()
    local on = S.Get("lootFinder")
    if on and not finderButton then
        finderButton = Parts.BarButton(window, St.BAG, TEXT_FINDER, TEXT_FINDER_HINT, FinderClicked)
        finderButton:SetScript("OnLeave", FinderLeave)
    end
    if finderButton then
        local favourites = window.favourites
        finderButton:ClearAllPoints()
        finderButton:SetPoint("RIGHT", favourites and favourites:IsShown() and favourites or window.recent, "LEFT",
            -BAR_GAP, 0)
        finderButton:SetShown(on and not S.Get("newLayout"))
    end
    if finding == FINDER and not on then
        StopFinding()
        DrawSelected()
        ShowHome()
    end
    PlaceCrafting()
end

local function PassKeysOn()
    if not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end

local function Step(key)
    if atHome and Wide() or shownTab == RUNS then return end
    local by = key == "UP" and -1 or 1
    Select(shownTab == DUNGEONS and List.Next(selected, by) or Factions.Next(selected, by))
end

local function FocusSearch()
    search:SetFocus()
end

local function KeyAction(self, key)
    if InCombatLockdown() or not self:IsMouseOver() or search:HasFocus() then return nil end
    if key == "UP" or key == "DOWN" then return Step end
    if key == "F" and IsControlKeyDown() then return FocusSearch end
end

local function OnKeyDown(self, key)
    local action = KeyAction(self, key)
    if not action then return ns.UI.CloseOnEscape(self, key) end
    self:SetPropagateKeyboardInput(false)
    action(key)
    C_Timer.After(NEXT_FRAME, PassKeysOn)
end

local function PaintBackdrop()
    window.backdrop:Paint(1)
end

local function ToggleEnter(button)
    Parts.LightBarIcon(button, true)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(S.Get("listHidden") and TEXT_SHOW_LIST or TEXT_HIDE_LIST, 1, 1, 1)
    GameTooltip:Show()
end

local function ToggleClicked(button)
    S.Set("listHidden", not S.Get("listHidden"))
    ToggleEnter(button)
end

local function PlaceContent(hidden)
    local wide = Wide()
    local grownW, grownH = 0, 0
    if wide then
        local scale = ns.UIScale()
        grownW, grownH = J.DungeonPane.Grown(UIParent:GetWidth() / scale - WIDTH - SCREEN_MARGIN,
            UIParent:GetHeight() / scale - HEIGHT - SCREEN_MARGIN,
            WIDTH - CARD_EDGE - CONTENT_INSET - SCROLL_RIGHT - PAD - PANE_RIGHT)
    end
    local width = WIDTH + grownW
    window:SetSize(width, HEIGHT + grownH)
    local cardLeft = (hidden or wide) and CARD_EDGE or LIST_W + PAD + CARD_LIST_GAP
    local drop = HomeLinked() and HOME_ROW or 0
    local fill = contentCard[1]
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", cardLeft, -(HEADER + CARD_EDGE))
    fill:SetPoint("BOTTOMRIGHT", -CARD_RIGHT, FOOTER + CARD_EDGE)
    local left = cardLeft + CONTENT_INSET
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", left, -(HEADER + PAD + SCROLL_TOP + drop))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_RIGHT, FOOTER + PAD)
    view:SetWidth(width - left - SCROLLBAR - PAD - VIEW_ROOM)
    local pane = J.DungeonPane
    if pane.Built() and pane.shown then
        pane.Place(left, HEADER + PAD + SCROLL_TOP + drop, SCROLL_RIGHT + PAD + PANE_RIGHT, FOOTER + PAD)
    end
    local homeW = width - left - SCROLLBAR - PAD - VIEW_ROOM
    if homeFrame then
        homeFrame:ClearAllPoints()
        homeFrame:SetPoint("TOPLEFT", left, -(HEADER + PAD + SCROLL_TOP))
        homeFrame:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT, FOOTER + PAD)
        Home.Layout(homeW)
    end
    if factionHome then
        factionHome:ClearAllPoints()
        factionHome:SetPoint("TOPLEFT", left, -(HEADER + PAD + SCROLL_TOP))
        factionHome:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT, FOOTER + PAD)
        FactionHome.Layout(homeW)
    end
    if runsFrame then
        runsFrame:ClearAllPoints()
        runsFrame:SetPoint("TOPLEFT", left, -(HEADER + PAD + SCROLL_TOP))
        runsFrame:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT, FOOTER + PAD)
        J.RunsPage.Layout(width - left - SCROLL_RIGHT)
    end
end

local function Paned()
    return Wide() and shownTab == DUNGEONS and not atHome and shownQuery == "" and not finding
end

function ApplyMode()
    local pane, paned = J.DungeonPane, Paned()
    if paned and not pane.Built() then pane.Build(window, view, scroll, Select, List.Next) end
    pane.shown = paned
    view.headAside, view.questsAside, view.keysAside, view.lootDense = paned, paned, paned, paned
    view.gridColumns = paned and PANE_COLUMNS or nil
    view.gridLoose = paned
    view.finderAside = Wide()
    view.factionAside = Wide()
    view.searchTable = Wide()
    view.openBoss = paned and pane.Pick or J.View.OpenBossLoot
    view.openHistory = nil
    if not paned then view.marked = nil end
    if pane.Built() then pane.SetShown(paned) end
    PlaceContent(S.Get("listHidden") and not Wide())
end

function DrawSelected()
    ApplyMode()
    DrawPage(selected)
    if J.DungeonPane.shown then J.DungeonPane.Show(selected) end
end

local function PlaceSearch()
    local new = S.Get("newLayout")
    search.hint:SetText(new and TEXT_SEARCH_SHORT or TEXT_SEARCH)
    search:SetHeight(new and TAB_H or SEARCH_H)
    if not new then return end
    search:ClearAllPoints()
    search:SetPoint("LEFT", window.tabBar, "RIGHT", BAR_SEARCH_GAP, 0)
    search:SetPoint("RIGHT", window.filters, "LEFT", -BAR_SEARCH_GAP, 0)
end

local function PlaceBar(new)
    local tabs = window.tabBar
    local title = window.title
    window.subtitle:SetShown(not new)
    titlePoint = titlePoint or { title:GetPoint(1) }
    title:ClearAllPoints()
    if new and window.forever then
        title:SetPoint("LEFT", window, "TOPLEFT", titlePoint[4], -HEADER / 2)
    elseif new then
        title:SetPoint("LEFT", window.logo, "RIGHT", titlePoint[4], 0)
    else
        title:SetPoint(titlePoint[1], titlePoint[2], titlePoint[3], titlePoint[4], titlePoint[5])
    end
    wipe(barTabs)
    for i, tab in ipairs(TABS) do barTabs[i] = tab end
    if S.Get("runPanel") then barTabs[#barTabs + 1] = RUNS_TAB end
    if new and S.Get("lootFinder") then barTabs[#barTabs + 1] = FINDER_TAB end
    local crafting = new and S.Get("crafting")
    if crafting then barTabs[#barTabs + 1] = CRAFTING_TAB end
    tabs:ClearAllPoints()
    search:ClearAllPoints()
    listFrame:ClearAllPoints()
    if new then
        local back = window.back:IsShown() and window.back or window.backLink:IsShown() and window.backLink
        tabs:SetWidth(BAR_TABS_W + (crafting and CRAFTING_TAB_W or 0))
        tabs:SetPoint("LEFT", back or title, "RIGHT", BAR_TAB_GAP, back and BACK_DROP or 0)
        listFrame:SetPoint("TOPLEFT", PAD, -(HEADER + PAD + LIST_TOP))
    else
        tabs:SetWidth(SEARCH_FULL_W)
        tabs:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
        search:SetPoint("TOPLEFT", PAD, -(HEADER + PAD + TAB_H + TAB_GAP))
        listFrame:SetPoint("TOPLEFT", PAD, -(HEADER + PAD + TAB_H + TAB_GAP + SEARCH_H + LIST_TOP))
    end
    listFrame:SetPoint("BOTTOMLEFT", PAD, FOOTER + PAD)
    Parts.SetTabs(tabs, barTabs)
    window.recent:SetShown(not new)
    if window.favourites then window.favourites:SetShown(J.Favourites.On() and not new) end
    Filters.Paint()
    PlaceSearch()
    if shownTab then Parts.PaintTabs(tabs, finding and new and finding or shownTab) end
end

function ShowHome()
    local home = HomeShown()
    local dungeons, factions = home and shownTab == DUNGEONS, home and shownTab == REPUTATION
    local runs = shownTab == RUNS and shownQuery == "" and not finding
    if runs and not runsFrame then
        runsFrame = J.RunsPage.Build(window)
        PlaceContent(S.Get("listHidden") and not Wide())
    end
    if runsFrame then runsFrame:SetShown(runs) end
    if dungeons and not homeFrame then
        homeFrame = Home.Build(window, Select)
        PlaceContent(false)
    end
    if factions and not factionHome then
        factionHome = FactionHome.Build(window, Select)
        PlaceContent(false)
    end
    if homeFrame then homeFrame:SetShown(dungeons) end
    if factionHome then factionHome:SetShown(factions) end
    scroll:SetShown(not home and not runs)
    scroll.bar:SetShown(not home and not runs and scroll:GetVerticalScrollRange() > 0)
    window.home:SetShown(HomeLinked())
    if TEXT_HOME[shownTab] then Parts.SetLink(window.home, TEXT_HOME[shownTab]) end
    if dungeons then Home.Paint() end
    if factions then FactionHome.Paint() end
end

function Arrange()
    local wide = Wide()
    local hidden = S.Get("listHidden") and not wide
    if hidden then ClearSearch() end
    search:SetShown(not hidden)
    window.tabBar:SetShown(not hidden)
    PlaceBar(S.Get("newLayout"))
    ShowLists()
    for _, part in ipairs(listCard) do part:SetShown(not hidden and not wide) end
    PlaceContent(hidden)
    window.listToggle:SetShown(not wide)
    window.listToggle.icon:SetTexture(hidden and LIST_HIDDEN or LIST_SHOWN)
    ShowHome()
end

local function RefreshHome()
    if homeFrame and homeFrame:IsShown() then
        Home.Layout()
        Home.Paint()
    end
    if factionHome and factionHome:IsShown() then
        FactionHome.Layout()
        FactionHome.Paint()
    end
end

local function DataEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetText(TEXT_DATA .. J.DATA_BUILD, 1, 1, 1)
    if J.DATA_DATE ~= "" then
        GameTooltip:AddLine(TEXT_DATA_DATE:format(DataDate(J.DATA_DATE)), T.muted.r, T.muted.g, T.muted.b)
    end
    GameTooltip:AddLine(TEXT_DATA_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function Hidden()
    if awayForMap then return end
    local back = onClose
    onClose = nil
    window.back:Hide()
    if back then back() end
end

local function BackClicked()
    window:Hide()
end

local function Drawn()
    if shownTab == DUNGEONS or shownTab == RUNS then List.Paint(selected) else Factions.Paint(selected) end
end

local function ShowFavourite(page, itemID)
    Select(page)
    GoToItem(itemID)
end

local function PlaceFavourites()
    local on = J.Favourites.On()
    if on and not window.favourites then
        window.favourites = J.FavouritesPanel.Button(window, ShowFavourite)
        window.favourites:SetPoint("RIGHT", window.recent, "LEFT", -BAR_GAP, 0)
    end
    if window.favourites then
        window.favourites:SetShown(on and not S.Get("newLayout"))
    end
    PlaceSearch()
    PlaceFinder()
end

local function BuildTitleBar()
    local close = Parts.TitleBar(window, PAGE, TEXT_SUBTITLE, PAGE)
    window.filters = Filters.Button(window)
    window.filters:SetPoint("RIGHT", close, "LEFT", -FILTERS_GAP, 0)
    window.listToggle = Parts.BarIcon(window, LIST_SHOWN, true)
    window.listToggle:SetScript("OnClick", ToggleClicked)
    window.listToggle:SetScript("OnEnter", ToggleEnter)
    window.listToggle:SetPoint("RIGHT", window.filters, "LEFT", -BAR_GAP, 0)
    window.recent = J.Recent.Button(window, Select)
    window.recent:SetPoint("RIGHT", window.listToggle, "LEFT", -BAR_GAP, 0)
    window.back = Parts.Link(window, BackClicked, true)
    window.back:SetPoint("LEFT", window.title, "RIGHT", BACK_GAP, -BACK_DROP)
    window.back:Hide()
    window.home = Parts.Link(window, HomeClicked, true)
    window.home:SetPoint("LEFT", window, "TOPLEFT", CARD_EDGE + CONTENT_INSET, -(HEADER + PAD + HOME_ROW / 2))
    window.home:Hide()
end

local function BuildFooter()
    Parts.FooterBrand(window, PAGE)
    if not J.DATA_BUILD then return end
    Parts.FooterNote(window, TEXT_DATA_NOTE .. J.DATA_BUILD .. (J.DATA_DATE ~= "" and PLACE_DOT .. DataDate(J.DATA_DATE) or ""),
        DataEnter)
end

local function BuildLists()
    window.tabBar = Parts.Tabs(window, SEARCH_FULL_W, TABS, TabPicked)
    window.tabBar:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
    local below = HEADER + PAD + TAB_H + TAB_GAP
    search = Parts.SearchBox(window, TEXT_SEARCH, OnSearch)
    search:SetSize(SEARCH_W, SEARCH_H)
    search:SetPoint("TOPLEFT", PAD, -below)
    window.factionSwitch, window.factions = Switch.New(window)
    window.factionSwitch:SetPoint("LEFT", search, "RIGHT", FACTION_GAP, 0)
    listFrame = CreateFrame("Frame", nil, window)
    listFrame:SetPoint("TOPLEFT", PAD, -(below + SEARCH_H + LIST_TOP))
    listFrame:SetPoint("BOTTOMLEFT", PAD, FOOTER + PAD)
    listFrame:SetWidth(LIST_W)
    List.Build(listFrame, Select)
    factionFrame = CreateFrame("Frame", nil, window)
    factionFrame:SetPoint("TOPLEFT", listFrame)
    factionFrame:SetPoint("BOTTOMLEFT", listFrame)
    factionFrame:SetWidth(LIST_W)
    factionFrame:Hide()
    Factions.Build(factionFrame, Select)
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "journalWindow")
    local backdrop = window.backdrop
    listCard = backdrop:Card(CARD_EDGE, HEADER + CARD_EDGE, WIDTH - LIST_W - PAD - CARD_EDGE, FOOTER + CARD_EDGE)
    contentCard = backdrop:Card(LIST_W + PAD + CARD_LIST_GAP, HEADER + CARD_EDGE, CARD_RIGHT, FOOTER + CARD_EDGE)
    window:SetScript("OnKeyDown", OnKeyDown)
    BuildTitleBar()
    window:HookScript("OnHide", Hidden)
    BuildFooter()
    BuildLists()
    scroll = ns.UI.SlimScroll(window)
    view = J.View.New(scroll)
    scroll:SetScrollChild(view)
    view.onResize = Drawn
    view.navigate = Select
    view.step = List.Next
    view.openBoss = J.View.OpenBossLoot
    view.onFound = OpenFound
end

local function ApplyProfile()
    PaintBackdrop()
    Switch.Paint(window.factions)
    Arrange()
    PlaceFavourites()
    Filters.Paint()
    List.Layout()
    PlaceFinder()
end

local function RedrawFactions()
    if shownTab == DUNGEONS or shownTab == RUNS then return end
    Factions.Layout(shownTab)
    Factions.Paint(selected)
end

local function SettingChanged(key)
    if not (window and window:IsShown()) then return end
    if key == "enabled" then
        if not S.Get("enabled") then window:Hide() end
    elseif key == "newLayout" then
        atHome = false
        if TabOf(selected) ~= shownTab then selected = picked[shownTab] or FirstPage(shownTab) end
        Arrange()
        PlaceFinder()
        DrawSelected()
        ShowHome()
    elseif key:find("^closedGroup") then
        List.Layout()
        RefreshHome()
    elseif key == "openUnreleased" then
        RedrawFactions()
        RefreshHome()
    elseif key == "runPanel" then
        if shownTab == RUNS and not S.Get("runPanel") then TabPicked(DUNGEONS) end
        Arrange()
    elseif key == "lootFinder" or key == "crafting" then
        PlaceFinder()
        if S.Get("newLayout") then Arrange() end
    elseif key == "mapSize" then
        if not Wide() then return end
        Arrange()
        view:Redraw()
        if J.DungeonPane.shown then J.DungeonPane.Show(selected) end
    elseif key == "showAlliance" or key == "showHorde" then
        Switch.Paint(window.factions)
        List.Layout()
        RedrawFactions()
        RefreshHome()
        if shownQuery ~= "" or finding then view:Redraw() end
    else
        if key == "listHidden" then Arrange() end
        if key == "favourites" then PlaceFavourites() end
        if key == "hideCompleted" then List.Layout() end
        Filters.Paint()
        Filters.Repaint()
        view:Redraw()
        J.DungeonPane.Redraw()
        RefreshHome()
    end
end

local function ProfileApplied()
    if not (window and window:IsShown()) then return end
    ApplyProfile()
    view:Redraw()
    J.DungeonPane.Redraw()
end

function ns.RedrawJournalWindow()
    if window and window:IsShown() then
        view:Redraw()
        J.DungeonPane.Redraw()
    end
    J.View.BossPanel.Refresh()
end

function ns.OpenJournalWindow(dungeon, back, backText, itemID)
    awayForMap = false
    J.TurnOn()
    if not window then Build() end
    onClose = back
    window.back:SetShown(back ~= nil)
    if back then Parts.SetLink(window.back, backText or TEXT_BACK) end
    window:SetScale(ns.UIScale())
    window:Show()
    ApplyProfile()
    local here = J.Current()
    local page = dungeon or here and here[1]
    if not page and S.Get("newLayout") then
        selected = selected or FirstPage(SavedTab())
        GoHome(SavedTab())
    else
        Select(page or selected or FirstPage(SavedTab()))
    end
    GoToItem(itemID)
end

function J.OpenRun(run)
    ns.OpenJournalWindow()
    ShowRuns(run)
end

function J.OpenBossPage(dungeon, boss)
    ns.OpenJournalWindow(dungeon)
    if J.DungeonPane.shown then
        J.DungeonPane.Pick(boss)
    else
        J.View.OpenBossLoot(boss, dungeon)
    end
end

function ns.ToggleJournalWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenJournalWindow() end
end

function J.WindowAwayForMap(mapShown)
    if mapShown then
        if not (window and window:IsShown()) then return end
        awayForMap = true
        window.stepAside = true
        window:Hide()
        window.stepAside = nil
    elseif awayForMap then
        awayForMap = false
        if window and S.Get("enabled") then window:Show() end
    end
end

function NaowhForever_ToggleJournal()
    ns.ToggleJournalWindow()
end

S.OnChange(SettingChanged)
ns.OnApply(ProfileApplied)
