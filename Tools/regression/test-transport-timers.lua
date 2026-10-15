-- Run with Lua 5.1: single-sighting server-clock estimates, loading continuity, dock visibility and lifecycle.
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end
local now = 100
local ns = { Shared = { Parts = {}, Settings = {} }, THEME = {}, UI = {},
    QoLConstants = { PERCENT = 100, SECONDS_PER_MINUTE = 60 } }
_G.NaowhForever = ns
ns.L = function(text) return text end

ns.TransportData = { boat = { period = 120, dwell = 20 }, other = { period = 150, dwell = 30 } }
dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
local Times = ns.TransportTimes
local function Next(key, time, seconds, kind)
    local actual, state = Times.Next(key, time)
    Check(actual == seconds and state == kind, key .. " at " .. time .. ": " .. tostring(actual) .. ", " .. state)
end
Next("boat", now, nil, "new")
Check(Times.Record("boat", "departure", now), "a single departure calibrates immediately")
Next("boat", now, 100, "arrival")
Next("boat", now + 100, 20, "departure")
Check(Times.Record("boat", "arrival", 220), "a single arrival replaces the previous phase")
Check(not Times.Record("boat", "arrival", 220), "double clicks do not replace a sighting")
Next("boat", 225, 15, "departure")
Next("boat", 240, 100, "arrival")
Next("boat", 340, 20, "departure")
Next("boat", 460, 20, "departure")
Next("boat", 360220, 20, "departure")
Next("boat", 219, nil, "stale")
Next("other", 225, nil, "new")
Check(Times.Record("other", "arrival", 225), "a second dock calibrates independently")
Next("other", 230, 25, "departure")
Times.Clear("other")
Next("boat", 225, 15, "departure")
Next("other", 230, nil, "new")
Check(Times.Record("boat", "departure", 245), "a new departure resynchronizes immediately")
Next("boat", 250, 95, "arrival")
Check(Times.Record("boat", "arrival", 200), "fresh sighting recovers after clock rollback")
Next("boat", 205, 15, "departure")
Check(not Times.Record("boat", "flight", 300), "unknown observation type rejected")
Check(not Times.Record(nil, "arrival", 300), "no observations without a selected dock")
Check(not Times.Record("unknown", "arrival", 300), "unknown route cannot be calibrated")
Times.Clear()
Next("boat", 300, nil, "new")

-- Every selectable dock must match the source route, including both choices at shared pins
-- and the three-stop Southshore loop. These are estimates, not measured transport schedules.
dofile("NaowhForever_QoL/Travel/TransportData.lua")
dofile("NaowhForever_QoL/Interface/TownTravel.lua")
ns.Journeys = {}
dofile("NaowhForever_Journeys/Constants.lua")
dofile("NaowhForever_Journeys/Data/Network.lua")
local total = 0
for map, pins in pairs(ns.TownTravel) do
    for index, pin in ipairs(pins) do
        for label = 4, #pin, 2 do
            local key = map .. ":" .. index .. ":" .. label
            local timing = ns.TransportData[key]
            Check(timing and timing.period > timing.dwell and timing.dwell > 0, "timing for " .. key)
            local matched = false
            for _, ship in ipairs(ns.JourneyNetwork.ships) do
                local period = 0
                for i = 3, #ship do period = period + ship[i][6] + ship[i][7] / ns.Journeys.C.SHIP_SPEED[ship[1]] end
                for i = 3, #ship do
                    if ship[i][4] == map then
                        for j = 3, #ship do
                            if i ~= j and pin[label] == ship[1] .. " to " .. ship[j][5] then
                                Check(math.abs(timing.period - period) < .000001 and timing.dwell == ship[i][6],
                                    "generated period/dwell matches source for " .. key)
                                matched = true
                            end
                        end
                    end
                end
            end
            Check(matched, "source route for " .. key)
            total = total + 1
        end
    end
end
Check(total == 28, "all 28 dock routes have timings")
ns.Journeys, ns.JourneyNetwork = nil, nil

local made, mapReads, widgets, listeners = 0, 0, {}, {}
local function Widget()
    local w = { scripts = {}, events = {} }
    function w:SetScript(key, fn) self.scripts[key] = fn end
    function w:RegisterEvent(key) self.events[key] = true end
    function w:UnregisterAllEvents() self.events = {} end
    function w:SetText(text) self.text = text end
    function w:SetEnabled(value) self.enabled = value end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:SetSize() end
    function w:SetMovable() end
    function w:SetClampedToScreen() end
    function w:SetPoint() end
    function w:ClearAllPoints() end
    function w:SetWidth() end
    function w:SetHeight() end
    function w:SetJustifyH() end
    widgets[#widgets + 1] = w
    return w
end
_G.CreateFrame = function() made = made + 1; return Widget() end
_G.UIParent = {}
_G.GetTime = function() error("transport phase must use the server clock") end
_G.GetServerTime = function() return now end
local moving = false
_G.IsPlayerMoving = function() return moving end
_G.issecretvalue = function(v) return v == "secret" end
_G.CreateVector2D = function(x, y) return { x = x, y = y } end
local playerMap, playerPos = 1413, { x = .638, y = .388 }
_G.C_Map = {
    GetMapInfo = function(id) mapReads = mapReads + 1; return { name = "Map " .. id } end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function() return playerPos end,
    GetWorldPosFromMapPos = function(map, pos) return map, { x = pos.x * 1000, y = pos.y * 1000 } end,
}
_G.hooksecurefunc = function(target, key, fn)
    local original = target[key]
    target[key] = function(...) original(...); fn(...) end
end
ns.Apply = function() end
ns.Font = function() return Widget() end
ns.Button = function(_, text, _, _, fn)
    local button = Widget()
    button.text, button._onClick = text, fn
    return button
end
ns.Shared.Parts.HudBackdrop = function() end
ns.UI.AttachMover = function(_, _, callback) ns.savePosition = callback end
local card
ns.Shared.Settings.Page = function()
    return { Card = function(_, spec) card = spec end }
end
local settings = { enabled = true, transportTimers = false, transportDock = "nearby",
    transportTimersPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 } }
ns.QoLSettings = {
    Get = function(key) return settings[key] end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
    Set = function(key, value)
        settings[key] = value
        for _, fn in ipairs(listeners) do fn(key) end
    end,
}
dofile("NaowhForever_QoL/Interface/TownTravel.lua")
dofile("NaowhForever_QoL/Travel/Transport.lua")
Check(made == 0 and mapReads == 0, "default off builds no frames and reads no maps")
ns.QoLSettings.Set("unrelated", true)
Check(made == 0, "unrelated setting builds nothing")
ns.QoLSettings.Set("transportTimers", true)
Check(made == 2, "enable builds one HUD and one event frame")
local hud, events = widgets[1], widgets[#widgets]
Check(hud.shown and events.events.PLAYER_ENTERING_WORLD, "nearby HUD and events enabled")
Check(hud.route.text:find("Booty Bay", 1, true), "nearby selects the Ratchet boat without Journeys or Town Map")
Check(hud.arrived.enabled and hud.departed.enabled, "either sighting starts calibration")
Check(hud.scripts.OnUpdate == nil and events.scripts.OnUpdate == nil, "stationary without calibration does no update work")
local function Event(name) events.scripts.OnEvent(events, name) end
local function Status(kind, seconds)
    local rounded = math.ceil(seconds)
    Check(hud.status.text == ("Estimate: %s in %d:%02d"):format(kind, math.floor(rounded / 60), rounded % 60),
        "HUD phase: " .. hud.status.text)
end
local period = ns.TransportData["1413:1:4"].period
now = 1700000100
hud.arrived._onClick()
Status("leaves", 60)
Check(hud.scripts.OnUpdate and hud.arrived.enabled and hud.departed.enabled, "one arrival starts countdown and allows correction")
now = now + 65
hud.scripts.OnUpdate(hud, 1)
Status("arrives", period - 65)
Event("PLAYER_LEAVING_WORLD")
Check(not hud.shown and hud.scripts.OnUpdate == nil and events.scripts.OnUpdate == nil, "loading hides HUD and stops updates")
moving = true
ns.QoLSettings.Set("transportDock", "nearby")
Check(not hud.shown and events.scripts.OnUpdate == nil, "settings changes during loading do not restart HUD or movement updates")
moving = false
now = now + 20
playerPos = nil
Event("PLAYER_ENTERING_WORLD")
Check(not hud.shown, "missing position after loading stays hidden")
playerPos = { x = .638, y = .388 }
Event("ZONE_CHANGED")
Check(hud.shown and hud.scripts.OnUpdate, "loading retains the single sighting")
Status("arrives", period - 85)
now = now + 60 * 60
Event("PLAYER_ENTERING_WORLD")
local expected, kind = Times.Next("1413:1:4", now)
Status(kind == "arrival" and "arrives" or "leaves", expected)
Check(hud.scripts.OnUpdate, "server-clock estimate survives a long loading screen")
now = 1700000099
Event("ZONE_CHANGED")
Check(hud.status.text:find("Server clock changed", 1, true) and hud.scripts.OnUpdate == nil,
    "clock rollback suspends the estimate")
hud.departed._onClick()
Status("arrives", period - 60)
hud.reset._onClick()
Check(hud.scripts.OnUpdate == nil and hud.arrived.enabled and hud.departed.enabled, "reset removes the phase")
now = now + 1
hud.departed._onClick()
Status("arrives", period - 60)
Check(hud.scripts.OnUpdate, "single departure starts countdown")
local values, order = card.rows[1].choice()
Check(values.nearby and #order == 29, "all 28 dock routes can be selected, plus nearby")
ns.QoLSettings.Set("transportDock", "1434:1:4")
Check(not hud.shown and hud.scripts.OnUpdate == nil, "explicit remote dock hides the HUD")
-- A hidden callback must not record a remote dock using stale selection.
hud.arrived._onClick()
Next("1434:1:4", now, nil, "new")
playerMap, playerPos = 1434, { x = .257, y = .731 }
Event("ZONE_CHANGED_NEW_AREA")
Check(hud.shown and hud.route.text:find("Ratchet", 1, true), "selected route shows when its dock is reached")
now = now + 1
hud.arrived._onClick()
Status("leaves", 60)
ns.QoLSettings.Set("transportDock", "removed-dock")
Check(not hud.shown and hud.scripts.OnUpdate == nil, "invalid saved dock stays hidden")
ns.QoLSettings.Set("transportDock", "nearby")
playerPos = { x = "secret", y = "secret" }
Event("PLAYER_STOPPED_MOVING")
Check(not hud.shown and hud.scripts.OnUpdate == nil, "secret coordinates hide the HUD without arithmetic")
playerPos = nil
Event("ZONE_CHANGED")
Check(not hud.shown, "missing map position hides the HUD")
playerMap, playerPos = 1413, { x = .638, y = .388 }
Event("ZONE_CHANGED_NEW_AREA")
Check(hud.shown and hud.scripts.OnUpdate, "returning to a dock restores its earlier phase")
moving = true
Event("PLAYER_STARTED_MOVING")
Check(events.scripts.OnUpdate, "movement enables proximity checks")
playerPos = { x = 0, y = 0 }
events.scripts.OnUpdate(events, .5)
Check(not hud.shown and hud.scripts.OnUpdate == nil, "moving outside dock range hides the HUD and stops countdown work")
playerPos = { x = .638, y = .388 }
events.scripts.OnUpdate(events, .5)
Check(hud.shown and hud.scripts.OnUpdate, "moving into dock range restores countdown without stopping")
moving = false
Event("PLAYER_STOPPED_MOVING")
Check(events.scripts.OnUpdate == nil, "stopping movement stops proximity updates")
-- Movement with a transport can change position even without a player movement event.
playerPos = { x = 0, y = 0 }
hud.scripts.OnUpdate(hud, 1)
Check(not hud.shown and hud.scripts.OnUpdate == nil, "active countdown rechecks proximity while riding away")
playerPos = { x = .638, y = .388 }
Event("PLAYER_STOPPED_MOVING")
ns.savePosition({ point = "TOP", relPoint = "TOP", x = 20, y = -100 })
Check(settings.transportTimersPos.x == 20, "mover saves position through settings store")
moving = true
Event("PLAYER_STARTED_MOVING")
ns.QoLSettings.Set("enabled", false)
Check(not hud.shown and next(events.events) == nil and hud.scripts.OnUpdate == nil
    and events.scripts.OnUpdate == nil, "module off unregisters events and stops all updates")
ns.QoLSettings.Set("enabled", true)
now = now + 1
hud.arrived._onClick()
ns.QoLSettings.Set("transportTimers", false)
Check(not hud.shown and next(events.events) == nil and hud.scripts.OnUpdate == nil
    and events.scripts.OnUpdate == nil, "feature off stops countdown and movement updates")
ns.QoLSettings.Set("transportTimers", true)
Check(made == 2 and hud.arrived.enabled and hud.departed.enabled and hud.scripts.OnUpdate == nil,
    "reenable reuses frames and needs a fresh sighting")
Times.Record("1413:1:4", "arrival", now)
dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
Check(ns.TransportTimes.Next("1413:1:4", now) == nil, "UI reload starts without old phase")
print("transport timers: " .. checks .. " checks passed")
