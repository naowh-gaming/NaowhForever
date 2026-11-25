-- AttuneTracker.lua: the Attunements tracker: each key you can work on, its next quest in full, with a waypoint.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local Attune = Discovery.Attune
local L = Discovery.Library
local Style = Discovery.Style
local Parts = ns.Shared.Parts

local SETTINGS_PAGE = "Discovery/Attunements"
local PLACE = { "RIGHT", "RIGHT", -260, -120 }
local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }
local TEXT_NAME = "Attunements"
local TEXT_TITLE = ns.Upper(ns.L(TEXT_NAME))
local TEXT_STEPS = ns.L("%d / %d  steps")
local TEXT_ROW = "%s  %d / %d"
local TEXT_SUB = "%s\n%s"

local panel, events, refreshQueued, dismissedZone
local entries = {}

local function On()
    return S.Get("enabled") and S.Get("attuneTracker")
end

local function Opacity()
    return S.Get("attuneTrackerAlpha") or 1
end

local function LoadPosition()
    local pos = S.Get("attuneTrackerPos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("attuneTrackerPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(frame, onMoved)
    return ns.UI.AttachMover(frame, TEXT_NAME, onMoved, SETTINGS_PAGE, SETTINGS_PAGE .. ":attunetracker")
end

local function Close()
    dismissedZone = L.PlayerZone()
    panel:Hide()
end

local function OpenSteps()
    ns.OpenDiscoveryWindow("attune")
end

local function QuestWaypoint(entry)
    Attune.Waypoint(entry.quest)
end

local function QuestTip(row)
    local entry, m = row.entry, T.muted
    GameTooltip:SetText(ns.L(entry.key.dungeon), 1, 1, 1)
    GameTooltip:AddLine(Attune.Name(entry.quest), 1, 1, 1)
    GameTooltip:AddLine(Attune.Where(entry.quest), m.r, m.g, m.b, true)
    local note = Attune.Note(entry.quest)
    if note then GameTooltip:AddLine(note, 1, 1, 1, true) end
end

local function BuildPanel()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        onTitle = OpenSteps, titleTip = TEXT_NAME,
        titleHint = ns.L("Click to see every step in the Discovery window."),
        onClose = Close,
        bar = true,
        settings = { page = SETTINGS_PAGE, card = "attunetracker", tip = ns.L("Attunements settings"),
            hint = ns.L("Opens the Attunements tracker's settings.") },
        opacity = Opacity,
        load = LoadPosition, save = SavePosition, place = PLACE,
        mover = Mover,
    })
    panel:SetScale(S.Get("attuneTrackerScale"))
    panel:Place()
    panel:Paint()
    panel:Hide()
end

local function Fill(i, key, quest, at)
    local entry = entries[i] or {}
    entries[i] = entry
    entry.key, entry.quest = key, quest
    entry.text = TEXT_ROW:format(ns.L(key.dungeon), at - 1, #Attune.Steps(key))
    entry.sub = TEXT_SUB:format(Attune.Name(quest), Attune.Where(quest))
    entry.waypoint = ns.Completo.Quests.Spot(quest) and QuestWaypoint or nil
    entry.tip = QuestTip
end

local function Render()
    local n, done, total = 0, 0, 0
    for _, key in ipairs(ns.Attunements.list) do
        local quest, at = Attune.Next(key)
        if quest then
            n = n + 1
            Fill(n, key, quest, at)
            done, total = done + at - 1, total + #Attune.Steps(key)
        end
    end
    for i = n + 1, #entries do entries[i] = nil end
    local bar = panel.bar
    bar:SetMinMaxValues(0, math.max(total, 1))
    bar:SetValue(done)
    bar:SetStatusBarColor(T.accent.r, T.accent.g, T.accent.b, Style.BAR_ALPHA)
    bar.text:SetText(TEXT_STEPS:format(done, total))
    panel:Fit(panel:SetRows(entries))
end

local function Refresh()
    local zone = L.PlayerZone()
    if zone and zone ~= dismissedZone then dismissedZone = nil end
    local show = On() and IsLoggedIn() and not dismissedZone and Attune.Open()
    if not show then
        if panel then panel:Hide() end
        return
    end
    if not panel then BuildPanel() end
    Render()
    panel:Show()
end

local function QueuedRefresh()
    refreshQueued = false
    Refresh()
end

local function OnEvent()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(C.REFRESH_DELAY, QueuedRefresh)
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    elseif events then
        events:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSet(key, value)
    if key == "attuneTrackerScale" and panel then panel:SetScale(value) end
    if key == "attuneTrackerAlpha" and panel then panel:Paint() end
    if key == "attuneTracker" then dismissedZone = nil end
    if key == "enabled" or key == "attuneTracker" then Apply() end
end

local function ShowMover()
    if not On() then return end
    if not panel then BuildPanel() end
    Render()
    panel.mover:Show()
    panel:Show()
end

local function HideMover()
    if not panel then return end
    panel.mover:Hide()
    Refresh()
end

hooksecurefunc(S, "Set", OnSet)
ns.OnApply(Apply)
hooksecurefunc(ns, "ShowUnlockMode", ShowMover)
hooksecurefunc(ns, "HideUnlockMode", HideMover)
