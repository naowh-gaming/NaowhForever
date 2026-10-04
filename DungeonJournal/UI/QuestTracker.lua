-------------------------------------------------------------------------------
--  UI/QuestTracker.lua -- a dungeon's quests in a small window of their own, to keep on
--  screen while you run it: each quest on one line, with its mark, its chain, who in your
--  group has it and its waypoint, all as on the Journal's page (hover for the quest, click
--  one in your log for its details, right-click for its menu, the group icon to ask for a
--  share, the pin's right-click to share where it is). Opened from Tracker on the Dungeon
--  Quests title of a dungeon's page, and moved anywhere by its title; while it is open it
--  follows you into the next dungeon the Journal lists. Made the first time it is opened;
--  closed, it listens to nothing.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local T = ns.THEME
local J = ns.Journal
local S = J.Settings

local St = J.Style
local PANEL_PAD, PANEL_HEADER = St.PANEL_PAD, St.PANEL_HEADER

local MIN_W, MAX_W = 420, 640   -- it widens to show its longest quest name in full, up to MAX_W
-- Taller than this it scrolls: 70% of the screen's height, at the window's scale, and 420 at
-- the least.
local MIN_MAX_H, SCREEN_SHARE = 420, 0.7
local function MaxH()
    local screen = (UIParent:GetHeight() or 0) * SCREEN_SHARE / ns.UIScale()
    return math.max(MIN_MAX_H, math.floor(screen))
end
local SCROLL_GAP = 20     -- the view's right edge to the window's, for the scrollbar, while it scrolls
local PICKER_H, PICKER_GAP = 24, 6   -- the dungeon dropdown under the title, and the room under it
local TOP = PANEL_HEADER + 4 + PICKER_H + PICKER_GAP   -- the window's top to its quests
local NAME_SIZE = 13      -- a quest row's title font (View/QuestRows.lua)
local SHARE_W, SHARE_H = 70, 20
local FOOTER = ns.Shared.Style.ACTION + 6   -- the cog under the quests, and the room above it
local SETTINGS_PAGE = "Dungeon Journal/Quest Tracker"
local TITLE_RIGHT = -34 - SHARE_W - 4   -- the title stops short of Share and the close button

local panel, view, scroll
local scrolling = false   -- taller than MaxH(): the scrollbar has its room
local shown               -- the dungeon it shows
local closedIn            -- closed inside this dungeon (Open Tracker in Dungeons), until you leave it
local closedOutside       -- closed out in the world (Show Outside Dungeons), until you have been in one

-- Where you left it, kept for the account.
local function SavePosition()
    local point, _, relativePoint, x, y = panel:GetPoint(1)
    ns.AccountSettings().journalTracker = { point, relativePoint, x, y }
end

local function Place()
    panel:ClearAllPoints()
    local saved = ns.AccountSettings().journalTracker
    if type(saved) == "table" and type(saved[1]) == "string" then
        panel:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        panel:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60)
    end
end

-- The width that shows every quest name of the dungeon in full, between MIN_W and MAX_W.
local measured, measurePool = {}, {}
local Parts = ns.Shared.Parts

local function WidthFor(dungeon)
    local widest = 0
    if dungeon.quests then
        for _, entry in ipairs(J.Quests.List(dungeon.quests, measured, measurePool)) do
            local name = entry.name
            if entry.quest and Parts.IsForever("quests", entry.quest[1]) then
                name = name .. Parts.ForeverInline(11, Parts.CARD_DROP)
            end
            panel.measure:SetText(name)
            local w = panel.measure.GetUnboundedStringWidth and panel.measure:GetUnboundedStringWidth()
                or panel.measure:GetStringWidth()
            widest = math.max(widest, math.ceil(w) + 1)
        end
    end
    local gap = scrolling and SCROLL_GAP or 0
    return math.max(MIN_W, math.min(MAX_W, J.View.QuestRowWidth(widest) + PANEL_PAD * 2 + gap))
end

-- The window, its dropdown and its list at width w; the list leaves the scrollbar room only
-- while it scrolls.
local function Size(w)
    local gap = scrolling and SCROLL_GAP or 0
    panel:SetWidth(w)
    panel.picker:SetWidth(w - PANEL_PAD * 2)
    scroll:SetPoint("BOTTOMRIGHT", -PANEL_PAD - gap, PANEL_PAD + FOOTER)
    view:SetWidth(w - PANEL_PAD * 2 - gap)
end

-- The dropdown's names, each dungeon's range coloured for your level now.
local function Labels()
    for _, dungeon in ipairs(J.Dungeons()) do
        local range = J.ColoredLevelRange(dungeon)
        panel.dungeonNames[dungeon.key] = range and dungeon.name .. "  " .. range or dungeon.name
    end
end

local function Draw(dungeon)
    shown = dungeon
    Labels()
    panel.picker._refreshLabel()
    Size(WidthFor(dungeon))
    view:DrawTracker(dungeon)
end

-- As tall as its quests, up to MaxH(). Starting or stopping to scroll changes the list's
-- width, so it is drawn again at the new one.
local function Fit(height)
    local maxH = MaxH()
    panel:SetHeight(math.min(maxH, TOP + height + FOOTER + PANEL_PAD))
    local scrolls = TOP + height + FOOTER + PANEL_PAD > maxH
    if scrolls ~= scrolling then
        scrolling = scrolls
        C_Timer.After(0, function()
            if panel:IsShown() and shown then Draw(shown) end
        end)
    end
end

-- PLAYER_ENTERING_WORLD: a new instance, and its dungeon when the Journal lists one.
local SyncGameTracker   -- below: the game's quest tracker, faded while this one is up in a dungeon

-- A loading screen, or a new subzone inside (a shared instance's wing is told by it, and
-- the subzone may only be known after the loading screen): it moves to the dungeon you are
-- in when that changes, so one picked from the dropdown stays until you go elsewhere.
local lastHere

local function OnEvent()
    local here = J.Current()
    local dungeon = here and here[1]
    if dungeon ~= lastHere then
        lastHere = dungeon
        if dungeon and dungeon ~= shown then Draw(dungeon) end
    end
    SyncGameTracker()
end

local function DragStop(frame)
    frame:StopMovingOrSizing()
    SavePosition()
end

local function OnShow(frame)
    lastHere = J.Current() and J.Current()[1]
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
end

-- Closed while inside the dungeon it shows (its X, or Tracker again): Open Tracker in Dungeons
-- leaves it closed there until you leave.
local function OnHide(frame)
    frame:UnregisterAllEvents()
    local here = J.Current()
    if here and here[1] == shown then closedIn = shown end
    if not here then closedOutside = true end
    SyncGameTracker()
end

-- In the Journal window's look rather than the plain dark panel's, so the two match side by
-- side: its gradient faded by its Opacity, its card behind the quests, and its titles' blue.
local function Paint()
    panel.backdrop:Paint(S.Get("trackerAlpha") or 1)
end

local function Build()
    panel = J.View.Parts.Panel("DUNGEON QUEST TRACKER", true)
    panel.backdrop:Card(4, PANEL_HEADER, 4, 4)
    panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    panel:SetFrameStrata("MEDIUM")
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", DragStop)
    panel.title:SetPoint("RIGHT", TITLE_RIGHT, 0)
    local titleBtn = CreateFrame("Button", nil, panel)
    titleBtn:SetPoint("TOPLEFT", panel.title, "TOPLEFT", -4, 4)
    titleBtn:SetPoint("BOTTOMRIGHT", panel.title, "BOTTOMRIGHT", 0, -4)
    titleBtn:SetScript("OnClick", function() ns.OpenOptionsWindow(SETTINGS_PAGE) end)
    titleBtn:RegisterForDrag("LeftButton")
    titleBtn:SetScript("OnDragStart", function() panel:StartMoving() end)
    titleBtn:SetScript("OnDragStop", function() DragStop(panel) end)
    titleBtn:SetScript("OnEnter", function(self)
        panel.title:SetTextColor(T.accent.r, T.accent.g, T.accent.b)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Dungeon Quest Tracker")
        GameTooltip:AddLine("Click to open the Dungeon Journal settings.", T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
        GameTooltip:Show()
    end)
    titleBtn:SetScript("OnLeave", function()
        panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
        GameTooltip:Hide()
    end)
    panel.share = ns.Button(panel, "Share All", SHARE_W, SHARE_H, function() J.Sharing.ShareAll(shown) end)
    panel.share:SetPoint("RIGHT", panel.close, "LEFT", -4, 0)
    panel.share:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Share Quests")
        GameTooltip:AddLine("Shares your quests for this dungeon with your group, one at a time.", 1, 1, 1, true)
        local count = #J.Sharing.Shareable(shown)
        if not IsInGroup() then
            GameTooltip:AddLine("You are not in a group.", T.muted.r, T.muted.g, T.muted.b)
        elseif count == 0 then
            GameTooltip:AddLine("None of your quests here can be shared.", T.muted.r, T.muted.g, T.muted.b)
        else
            GameTooltip:AddLine(("%d to share."):format(count), T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
        end
        GameTooltip:Show()
    end)
    panel.share:HookScript("OnLeave", GameTooltip_Hide)
    -- Bottom right, under the quests: the tracker's own settings, the Quests card on the
    -- Journal's settings page.
    panel.settings = J.View.Parts.IconButton(panel, function()
        ns.OpenOptionsWindow(SETTINGS_PAGE)
        ns.UI.GoToSetting(SETTINGS_PAGE, nil, SETTINGS_PAGE .. ":quests")
    end, ns.UI.COGS_ICON, 0, "Dungeon Quest Tracker settings")
    panel.settings:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    panel.settings.hint = "Opens the Dungeon Journal's Quest Tracker settings."
    -- Every dungeon the Journal has quests for, in its order, with its level range in the quest
    -- log's colours for you (Labels, on every draw, as your level changes): the one it shows,
    -- and a pick to show another. All of them at once, never scrolled.
    local values, order = {}, {}
    for _, dungeon in ipairs(J.Dungeons()) do
        if dungeon.quests and #dungeon.quests.quests > 0 then order[#order + 1] = dungeon.key end
    end
    panel.dungeonNames = values
    panel.picker = ns.UI.BuildDropdownControl(panel, MIN_W - PANEL_PAD * 2, panel:GetFrameLevel() + 3, values, order,
        function() return shown and shown.key end,
        function(key) Draw(J.Get(key)) end)
    panel.picker:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEADER - 4)
    panel.picker._menuHeight = function() return UIParent:GetHeight() end
    -- Measures the quest names (WidthFor), as a quest row writes them; never shown.
    panel.measure = ns.Font(panel, NAME_SIZE)
    panel.measure:Hide()
    scroll = ns.UI.SlimScroll(panel)
    scroll:SetPoint("TOPLEFT", PANEL_PAD, -TOP)
    view = J.View.New(scroll)
    Size(MIN_W)
    view.tracker = true   -- it draws a dungeon's quests alone, each on one line
    view.onResize = Fit
    scroll:SetScrollChild(view)
    panel:SetScript("OnEvent", OnEvent)
    panel:SetScript("OnShow", OnShow)
    panel:SetScript("OnHide", OnHide)
end

local function Show(dungeon)
    if not panel then Build() end
    panel:SetScale(ns.UIScale())
    Paint()
    Place()
    panel:Show()
    Draw(dungeon)
    SyncGameTracker()
end

-- Opens the tracker on the dungeon's quests; on the dungeon it shows already, closes it.
---@param dungeon JournalDungeon
function ns.OpenQuestTracker(dungeon)
    if panel and panel:IsShown() and shown == dungeon then
        panel:Hide()
        return
    end
    Show(dungeon)
end

-------------------------------------------------------------------------------
--  Hide the Game's Quest Tracker (hideGameTracker)
-------------------------------------------------------------------------------
-- While the tracker is up inside a dungeon, the game's quest tracker (ObjectiveTrackerFrame)
-- is faded out, and faded back in on closing the tracker or leaving. Only its alpha is set:
-- it is an Edit Mode frame with secure quest item buttons, so it is never hidden or shown.
local gameFaded, gameHooked = false, false

local function KeepFaded(frame)
    if gameFaded then frame:SetAlpha(0) end
end

function SyncGameTracker()
    local frame = _G.ObjectiveTrackerFrame
    if not frame then return end
    local fade = S.Get("enabled") and S.Get("hideGameTracker") and panel ~= nil and panel:IsShown()
        and J.Current() ~= nil
    if fade then
        if not gameHooked then
            gameHooked = true
            hooksecurefunc(frame, "Show", KeepFaded)
        end
        gameFaded = true
        frame:SetAlpha(0)
    elseif gameFaded then
        gameFaded = false
        frame:SetAlpha(1)
    end
end

-------------------------------------------------------------------------------
--  Open Tracker in Dungeons (trackerAuto) and Show Outside Dungeons (trackerOutside)
-------------------------------------------------------------------------------
-- Entering a dungeon the Journal lists, with quests for you there, opens the tracker on it.
-- Closed inside it, it stays closed until you leave. Out in the world (Show Outside
-- Dungeons), every loading screen, a login too, opens it on the dungeon your quests are for;
-- closed out there, it stays closed until you have been in a dungeon. Listened for only while
-- the Journal and one of the options are on.
local autoFrame

-- Out in the world: the first dungeon (the Journal's order, by level) with one of your
-- quests in your log; else the first for your level with quests still to pick up; else nil.
local function QuestsFor()
    local level = UnitLevel("player")
    local forLevel
    for _, dungeon in ipairs(J.Dungeons()) do
        local data = dungeon.quests
        if data then
            local toPickUp, inLog = J.Quests.Count(data)
            if inLog > 0 then return dungeon end
            local levels = not forLevel and toPickUp > 0 and J.Levels(dungeon)
            if levels and level >= levels[1] and level <= levels[2] then forLevel = dungeon end
        end
    end
    return forLevel
end

local function OnEnterWorld()
    local here = J.Current()
    local dungeon = here and here[1]
    if dungeon ~= closedIn then closedIn = nil end
    if dungeon then closedOutside = nil end
    if panel and panel:IsShown() and (not dungeon or shown == dungeon) then return end
    if not dungeon then
        if not S.Get("trackerOutside") or closedOutside then return end
        local pick = QuestsFor()
        if pick then Show(pick) end
        return
    end
    if not S.Get("trackerAuto") or dungeon == closedIn then return end
    local data = dungeon.quests
    if not data then return end
    local toPickUp, inLog = J.Quests.Count(data)
    if toPickUp + inLog > 0 then Show(dungeon) end
end

local function SyncAuto()
    local on = S.Get("enabled") and (S.Get("trackerAuto") or S.Get("trackerOutside"))
    if not (on or autoFrame) then return end
    if not autoFrame then
        autoFrame = CreateFrame("Frame")
        autoFrame:SetScript("OnEvent", OnEnterWorld)
    end
    if on then
        autoFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        -- Where you are now too: after a /reload this runs inside that loading screen's own
        -- PLAYER_ENTERING_WORLD, too late to hear it, so a reload in a dungeon opened nothing.
        OnEnterWorld()
    else
        autoFrame:UnregisterAllEvents()
    end
end
hooksecurefunc(ns, "Apply", SyncAuto)

-- The Journal switched off: the tracker goes with it. Its own Opacity (trackerAlpha): it follows.
S.OnChange(function(key)
    if key == "enabled" or key == "trackerAuto" or key == "trackerOutside" then SyncAuto() end
    if key == "enabled" or key == "hideGameTracker" then SyncGameTracker() end
    if not panel then return end
    if key == "enabled" and not S.Get("enabled") then
        panel:Hide()
    elseif key == "trackerAlpha" then
        Paint()
    end
end)
