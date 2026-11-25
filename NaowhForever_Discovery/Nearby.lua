-- Nearby.lua: a sound and a chat line near a library book you still need, and a waypoint to the nearest one.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local L = Discovery.Library

local INTERVAL = 1
local REARM = 1.5
local BOOK, SPOT, WORLD = 1, 2, 3
local CHANNEL = "Master"
local TEXT_NEARBY = ns.L("Library book nearby: %s, %d yards%s")
local TEXT_PLACE = " - %s"

local ticker, zoneEvents, bagEvents, moveEvents
local zone, targets, guide, dismissed
local alerted = {}

local function On()
    return S.Get("enabled") and (S.Get("nearbySound") or S.Get("nearestBook"))
end

local function WorldPos(mapID, x, y)
    local _, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    return pos
end

local function PlayerPos()
    local here = C_Map.GetPlayerMapPosition(zone, "player")
    return here and WorldPos(zone, here:GetXY())
end

local function Unguide()
    if guide then ns.ClearGuideWaypoint(guide) end
    guide = nil
end

local function Guiding()
    if not guide then return false end
    local placed = ns.placedWaypoint
    return ns.GuideWaypointIsCurrent() and placed ~= nil and placed.details == guide
        or ns.JourneyDetails ~= nil and ns.JourneyDetails() == guide
end

local function Nearest(me)
    local mx, my = me:GetXY()
    local best, bestDist
    for _, target in ipairs(targets) do
        local tx, ty = target[WORLD]:GetXY()
        local dist = (tx - mx) ^ 2 + (ty - my) ^ 2
        if not bestDist or dist < bestDist then best, bestDist = target, dist end
    end
    return best
end

local function Guide()
    if not S.Get("nearestBook") then return Unguide() end
    if dismissed then return end
    if Guiding() then
        for _, target in ipairs(targets) do
            if target[SPOT] == guide.spot then return end
        end
    elseif not ns.NoWaypoint() then
        return
    end
    local me = PlayerPos()
    local target = me and Nearest(me)
    if not target then return end
    local book, spot = target[BOOK], target[SPOT]
    local details = { guide = true, title = book.name, spot = spot }
    if ns.SetGuideWaypoint(book.name, spot[C.SPOT_MAP], spot[C.SPOT_X], spot[C.SPOT_Y], details) then
        guide = details
    end
end

local function Announce(target, dist)
    if S.Get("nearbyPing") then PlaySound(SOUNDKIT.MAP_PING, CHANNEL) end
    if not S.Get("nearbyChat") then return end
    local place = target[SPOT][C.SPOT_PLACE]
    ns.Print(TEXT_NEARBY:format(target[BOOK].name, math.floor(dist), place and TEXT_PLACE:format(place) or ""))
end

local function Check()
    local me = PlayerPos()
    if not me then return end
    local range = S.Get("nearbyRange")
    local mx, my = me:GetXY()
    for _, target in ipairs(targets) do
        local tx, ty = target[WORLD]:GetXY()
        local dist = math.sqrt((tx - mx) ^ 2 + (ty - my) ^ 2)
        local quest = target[BOOK].quest
        if dist <= range and not alerted[quest] then
            alerted[quest] = true
            Announce(target, dist)
        elseif dist > range * REARM then
            alerted[quest] = nil
        end
    end
end

local function StartTicker()
    ticker = ticker or C_Timer.NewTicker(INTERVAL, Check)
end

local function StopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function Stop()
    StopTicker()
    Unguide()
    zone, targets = nil, nil
    if bagEvents then bagEvents:UnregisterAllEvents() end
    if moveEvents then moveEvents:UnregisterAllEvents() end
end

local function Targets(id)
    local list = {}
    for _, item in ipairs(L.OnMap(id)) do
        local spot = item[SPOT]
        local pos = WorldPos(id, spot[C.SPOT_X] / C.PERCENT, spot[C.SPOT_Y] / C.PERCENT)
        if pos then list[#list + 1] = { item[BOOK], spot, pos } end
    end
    return list
end

local function Refresh()
    if not On() or IsInInstance() then return Stop() end
    local id = L.PlayerZone()
    local list = Targets(id)
    if #list == 0 then return Stop() end
    if id ~= zone then dismissed = nil end
    zone, targets = id, list
    bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
    bagEvents:RegisterEvent("QUEST_TURNED_IN")
    Guide()
    if not S.Get("nearbySound") then
        moveEvents:UnregisterAllEvents()
        return StopTicker()
    end
    moveEvents:RegisterEvent("PLAYER_STARTED_MOVING")
    moveEvents:RegisterEvent("PLAYER_STOPPED_MOVING")
    Check()
    if IsPlayerMoving() then StartTicker() else StopTicker() end
end

local function OnMove(_, event)
    if event == "PLAYER_STARTED_MOVING" then return StartTicker() end
    StopTicker()
    Check()
end

local function Build()
    zoneEvents = CreateFrame("Frame")
    zoneEvents:SetScript("OnEvent", Refresh)
    bagEvents = CreateFrame("Frame")
    bagEvents:SetScript("OnEvent", Refresh)
    moveEvents = CreateFrame("Frame")
    moveEvents:SetScript("OnEvent", OnMove)
end

local function Apply()
    if On() then
        if not zoneEvents then Build() end
        zoneEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
        zoneEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    elseif zoneEvents then
        zoneEvents:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSet(key)
    if key == "enabled" or key == "nearbySound" or key == "nearestBook" then Apply() end
end

local function OnDismiss(gone)
    if gone ~= nil and gone == guide then dismissed = true end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "DismissGuideWaypoint", OnDismiss)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
