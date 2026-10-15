-- Run with Lua 5.1: manual transport calibration, estimates, dock selection and enable/disable lifecycle.
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end
local now = 100
local ns = { Shared = { Parts = {}, Settings = {} }, THEME = {}, UI = {},
    QoLConstants = { PERCENT = 100, SECONDS_PER_MINUTE = 60 } }
_G.NaowhForever = ns
ns.L = function(text) return text end

dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
local Times = ns.TransportTimes
local function Next(key, time, seconds, kind)
    local actual, state = Times.Next(key, time)
    Check(actual == seconds and state == kind, key .. " at " .. time .. ": " .. tostring(actual) .. ", " .. state)
end
Next("boat", now, nil, "new")
Check(not Times.Record("boat", "departure", now), "a departure alone cannot start calibration")
Check(Times.Record("boat", "arrival", now), "first arrival")
Check(not Times.Record("boat", "arrival", now + 1), "double clicks do not overwrite an arrival")
Check(not Times.Record("boat", "departure", now), "simultaneous observations rejected")
Next("boat", now + 10, nil, "departure")
Check(Times.Record("boat", "departure", 120), "departure records dwell")
Next("boat", 130, nil, "arrival")
Check(Times.Record("boat", "arrival", 220), "next arrival completes a full cycle")
Next("boat", 225, 15, "departure")
Next("boat", 240, 100, "arrival")
Next("boat", 340, 20, "departure")
Next("boat", 460, nil, "stale")
Next("other", 225, nil, "new")
Check(Times.Record("other", "arrival", 225), "a second dock learns independently")
Times.Clear("other")
Next("boat", 225, 15, "departure")
Next("other", 225, nil, "new")
Check(Times.Record("boat", "departure", 245), "late observation updates dwell")
Next("boat", 250, 90, "arrival")
Check(Times.Record("boat", "arrival", 350), "next full cycle updates period")
Next("boat", 355, 20, "departure")
Next("boat", 2000, nil, "stale")
Next("boat", 349, nil, "stale")
Times.Clear()
Check(Times.Record("short", "arrival", 0) and Times.Record("short", "departure", 1), "short cycle starts")
Check(not Times.Record("short", "arrival", 2), "implausibly short cycle rejected")
Check(Times.Record("long", "arrival", 0) and Times.Record("long", "departure", 600), "long cycle starts")
Check(Times.Record("long", "arrival", 1000), "an arrival past MAX_PERIOD restarts learning instead of being refused")
Next("long", 1010, nil, "departure")
Check(not Times.Record("short", "flight", 100), "unknown observation type rejected")
Check(not Times.Record(nil, "arrival", 100), "no observations without a selected dock")
Times.Clear()

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
_G.GetTime = function() return now end
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
Check(hud.shown and events.events.PLAYER_ENTERING_WORLD, "enabled HUD and events")
Check(hud.route.text:find("Booty Bay", 1, true), "nearby selects the Ratchet boat without Journeys or Town Map")
Check(hud.arrived.enabled and not hud.departed.enabled, "first step is arrival")
Check(hud.scripts.OnUpdate == nil, "no countdown before learning")
now = 100
hud.arrived._onClick()
Check(not hud.arrived.enabled and hud.departed.enabled, "arrival moves controls to departure")
now = 120
hud.departed._onClick()
Check(hud.arrived.enabled and not hud.departed.enabled and hud.scripts.OnUpdate == nil, "wait for next arrival")
now = 220
hud.arrived._onClick()
Check(hud.status.text == "Estimate: leaves in 0:20" and hud.scripts.OnUpdate, "recorded full cycle starts estimated countdown")
now = 245
hud.scripts.OnUpdate(hud, .2)
Check(hud.status.text == "Estimate: arrives in 1:35", "countdown changes phase")
now = 460
hud.scripts.OnUpdate(hud, .2)
Check(hud.scripts.OnUpdate == nil and hud.status.text:find("expired", 1, true), "stale countdown removes OnUpdate")
Check(not hud.arrived.enabled and not hud.departed.enabled, "expired calibration requires reset")
hud.reset._onClick()
Check(hud.arrived.enabled and not hud.departed.enabled, "reset restarts calibration")
local values, order = card.rows[1].choice()
Check(values.nearby and #order == 29, "all 28 dock routes can be selected, plus nearby")
ns.QoLSettings.Set("transportDock", "1434:1:4")
Check(hud.route.text:find("Ratchet", 1, true), "explicit dock can be tracked remotely")
ns.QoLSettings.Set("transportDock", "removed-dock")
Check(not hud.arrived.enabled and not hud.departed.enabled, "invalid saved dock cannot record")
ns.QoLSettings.Set("transportDock", "nearby")
playerPos = { x = "secret", y = "secret" }
events.scripts.OnEvent(events, "PLAYER_STOPPED_MOVING")
Check(not hud.arrived.enabled, "secret coordinates never enter distance arithmetic")
playerPos = nil
events.scripts.OnEvent(events, "ZONE_CHANGED")
Check(not hud.arrived.enabled, "no player map position hides nearby selection")
playerPos = { x = .638, y = .388 }
events.scripts.OnEvent(events, "PLAYER_STOPPED_MOVING")
now = 500; hud.arrived._onClick()
now = 520; hud.departed._onClick()
now = 620; hud.arrived._onClick()
events.scripts.OnEvent(events, "PLAYER_ENTERING_WORLD")
Check(hud.arrived.enabled and hud.scripts.OnUpdate == nil, "loading into a world invalidates old phase")
ns.savePosition({ point = "TOP", relPoint = "TOP", x = 20, y = -100 })
Check(settings.transportTimersPos.x == 20, "mover saves position through settings store")
ns.QoLSettings.Set("enabled", false)
Check(not hud.shown and next(events.events) == nil and hud.scripts.OnUpdate == nil, "module off unregisters events and stops countdown")
ns.QoLSettings.Set("enabled", true)
now = 700; hud.arrived._onClick()
now = 720; hud.departed._onClick()
now = 820; hud.arrived._onClick()
ns.QoLSettings.Set("transportTimers", false)
Check(not hud.shown and next(events.events) == nil and hud.scripts.OnUpdate == nil, "feature off stops active countdown")
ns.QoLSettings.Set("transportTimers", true)
Check(made == 2 and hud.arrived.enabled and hud.scripts.OnUpdate == nil, "reenable reuses frames and starts fresh")
print("transport timers: " .. checks .. " checks passed")
