-- Card.lua: the Journey card: every step of the journey you are on, with the time each takes.
local ns = _G.NaowhForever

local T = ns.THEME
local Jy = ns.Journeys
local S = Jy.Settings
local Guide = Jy.Guide
local Parts = ns.Shared.Parts

local SETTINGS_PAGE = "Journeys/Settings"
local PLACE = { "RIGHT", "RIGHT", -260, 40 }
local MINUTE = 60
local BAR_ALPHA = 0.8
local TEXT_TITLE = "JOURNEY"
local TEXT_NAME = "Journey Card"
local TEXT_STEPS = "%d / %d  steps"
local TEXT_TIME = "%d:%02d"
local TEXT_WAIT = "%s, waits %s"
local TEXT_TOTAL = "%s to %s"

local panel
local entries = {}

local function On()
    return Jy.On() and S.Get("card")
end

local function Clock(seconds)
    seconds = math.floor(seconds + 0.5)
    return TEXT_TIME:format(math.floor(seconds / MINUTE), seconds % MINUTE)
end

local function LoadPosition()
    local pos = S.Get("cardPos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("cardPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(frame, onMoved)
    return ns.UI.AttachMover(frame, TEXT_NAME, onMoved, SETTINGS_PAGE, SETTINGS_PAGE .. ":card")
end

local function Opacity()
    return S.Get("cardAlpha")
end

local function BuildPanel()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        titleTip = TEXT_NAME,
        onClose = ns.ClearWaypoint,
        bar = true,
        settings = { page = SETTINGS_PAGE, card = "card", tip = "Journey settings",
            hint = "Opens the Journey card's settings." },
        opacity = Opacity,
        load = LoadPosition, save = SavePosition, place = PLACE,
        mover = Mover,
    })
    panel:SetScale(S.Get("cardScale"))
    panel:Place()
    panel:Paint()
    panel:Hide()
end

local function Fill(i, leg, current)
    local entry = entries[i] or {}
    entries[i] = entry
    entry.text = Guide.LegText(leg)
    entry.sub = leg.wait and TEXT_WAIT:format(Clock(leg.seconds), Clock(leg.wait)) or Clock(leg.seconds)
    entry.color = not current and T.muted or nil
    entry.done = false
end

local function Render(journey)
    local legs = journey.plan and journey.plan.legs or {}
    local done, total = journey.done, journey.done + #legs
    local bar = panel.bar
    bar:SetMinMaxValues(0, math.max(total, 1))
    bar:SetValue(done)
    bar:SetStatusBarColor(T.accent.r, T.accent.g, T.accent.b, BAR_ALPHA)
    bar.text:SetText(TEXT_STEPS:format(done, total))
    panel.title:SetText(journey.plan and TEXT_TOTAL:format(Clock(journey.plan.seconds), journey.title) or TEXT_TITLE)
    for i, leg in ipairs(legs) do Fill(i, leg, i == 1) end
    for i = #legs + 1, #entries do entries[i] = nil end
    panel:Fit(panel:SetRows(entries))
end

local function Refresh()
    local journey = Guide.Current()
    if not (On() and journey) then
        if panel and not (panel.mover and panel.mover:IsShown()) then panel:Hide() end
        return
    end
    if not panel then BuildPanel() end
    Render(journey)
    panel:Show()
end

local function OnSet(key, value)
    if not panel then return Refresh() end
    if key == "cardScale" then panel:SetScale(value) end
    if key == "cardAlpha" then panel:Paint() end
    Refresh()
end

local function ShowMover()
    if not On() then return end
    if not panel then BuildPanel() end
    panel.mover:Show()
    panel:Show()
end

local function HideMover()
    if not panel then return end
    panel.mover:Hide()
    Refresh()
end

Guide.OnChange(Refresh)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Refresh)
hooksecurefunc(ns, "ShowUnlockMode", ShowMover)
hooksecurefunc(ns, "HideUnlockMode", HideMover)
