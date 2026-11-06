-- Run with Lua 5.1 from the repository root: Layer Tracker.
-- Off it builds nothing and listens to nothing. On, the layer is the zone copy in an NPC's GUID: the target
-- and mouseover always take over, a nameplate only fills an empty reading, and players and secret GUIDs or
-- units are never read. A zone change, a layer move and a loading screen start it over; inside an instance
-- it hides, except in Unlock Mode.
local NOTHING = function() end
local SECRET = "Creature-0-5250-1-999-3100-0000ABCDEF"
local frames = {}
local guids = {}
local inInstance = false

local function Frame()
    local f = { scripts = {}, events = {}, shown = false }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    f.SetMovable, f.SetClampedToScreen, f.ClearAllPoints, f.SetPoint, f.SetSize = NOTHING, NOTHING, NOTHING, NOTHING, NOTHING
    frames[#frames + 1] = f
    return f
end

local settings = { enabled = true, layerTrackerFontSize = 14, layerTrackerFont = "", layerTrackerOutline = "OUTLINE",
    layerTrackerBackground = "none" }
local setHooks, hooks = {}, {}
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end }
local card, mover
local ns = {
    QoLSettings = S,
    Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
    L = dofile("Tools/regression/locale_stub.lua").L,
    UI = {
        AttachMover = function()
            mover = { SetShown = function(self, on) self.shown = on end }
            return mover
        end,
    },
    Font = function()
        return { SetPoint = NOTHING, SetText = function(self, text) self.text = text end }
    end,
    Shared = {
        Parts = {
            HudBackdrop = function() return { SetMode = function(_, mode) return mode end } end,
            HudFont = NOTHING,
        },
        Settings = {
            Page = function() return { Card = function(_, c) card = c end } end,
            Look = function() return {} end,
        },
    },
}

local function Split(sep, text)
    assert(text ~= SECRET, "a secret GUID was split")
    local parts = {}
    for part in (text .. sep):gmatch("(.-)" .. sep) do parts[#parts + 1] = part end
    return unpack(parts)
end

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    UIParent = {},
    strsplit = Split,
    issecretvalue = function(v) return v == SECRET end,
    UnitGUID = function(unit)
        assert(unit ~= SECRET, "a secret unit reached UnitGUID")
        return guids[unit]
    end,
    IsInInstance = function() return inInstance end,
    hooksecurefunc = function(t, name, fn)
        if t == S then setHooks[#setHooks + 1] = fn else hooks[name] = fn end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/LayerTracker.lua"))
setfenv(chunk, env)
chunk()
local boot = frames[1]
local readout, events

local function Set(k, v)
    settings[k] = v
    for _, fn in ipairs(setHooks) do fn(k) end
end

local function Fire(event, ...)
    events.scripts.OnEvent(events, event, ...)
end

local function Shown()
    if not readout.shown then return nil end
    return readout.text.text
end

local function NPC(zone, id)
    return ("Creature-0-5250-1-%d-%d-0000ABCDEF"):format(zone, id or 3100)
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("the card is on Questing & Group, behind its own switch", function()
    assert(card and card.switch == "layerTracker" and card.id == "layerTracker")
end)

Case("off by default: no frame built, no events", function()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    assert(#frames == 1, "only the login frame exists")
end)

Case("switched on: the readout shows, waiting for an NPC", function()
    Set("layerTracker", true)
    readout, events = frames[2], frames[3]
    assert(events.events.NAME_PLATE_UNIT_ADDED and events.events.SHARD_TRANSFER and events.events.UPDATE_MOUSEOVER_UNIT)
    assert(Shown() == "Layer ?", Shown())
end)

Case("a nameplate fills the reading with its zone copy", function()
    guids.nameplate1 = NPC(18853)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    assert(Shown() == "Layer 18853", Shown())
end)

Case("a later nameplate does not take over", function()
    guids.nameplate2 = NPC(16)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    assert(Shown() == "Layer 18853", Shown())
end)

Case("the target and the mouseover do", function()
    guids.target = NPC(16)
    Fire("PLAYER_TARGET_CHANGED")
    assert(Shown() == "Layer 16", Shown())
    guids.mouseover = NPC(4410, 3296)
    Fire("UPDATE_MOUSEOVER_UNIT")
    assert(Shown() == "Layer 4410", Shown())
end)

Case("a vehicle counts as an NPC", function()
    guids.mouseover = "Vehicle-0-5250-1-77-2961-0000ABCDEF"
    Fire("UPDATE_MOUSEOVER_UNIT")
    assert(Shown() == "Layer 77", Shown())
end)

Case("players, pets, no unit and a zero copy are not read", function()
    guids.target = "Player-5250-0A1B2C3D"
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = "Pet-0-5250-1-99-416-0100ABCDEF"
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = nil
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = NPC(0)
    Fire("PLAYER_TARGET_CHANGED")
    assert(Shown() == "Layer 77", Shown())
end)

Case("a secret GUID or nameplate unit is never read", function()
    guids.target = SECRET
    Fire("PLAYER_TARGET_CHANGED")
    Fire("SHARD_TRANSFER")
    Fire("NAME_PLATE_UNIT_ADDED", SECRET)
    assert(Shown() == "Layer ?", Shown())
end)

Case("a layer move starts over, and the next nameplate fills it", function()
    guids.nameplate3 = NPC(20112)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    assert(Shown() == "Layer 20112")
    Fire("SHARD_TRANSFER")
    assert(Shown() == "Layer ?", Shown())
    guids.nameplate4 = NPC(20113)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    assert(Shown() == "Layer 20113", Shown())
end)

Case("a new zone starts over", function()
    Fire("ZONE_CHANGED_NEW_AREA")
    assert(Shown() == "Layer ?", Shown())
end)

Case("a loading screen starts over and reads the target there", function()
    guids.target = NPC(5120)
    Fire("PLAYER_ENTERING_WORLD", false, true)
    assert(Shown() == "Layer 5120", Shown())
end)

Case("inside an instance it hides and reads nothing", function()
    inInstance = true
    guids.target = NPC(36)
    Fire("PLAYER_ENTERING_WORLD", false, false)
    assert(Shown() == nil, "hidden")
    Fire("PLAYER_TARGET_CHANGED")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    assert(Shown() == nil, "still hidden")
end)

Case("Unlock Mode shows it inside an instance, so it can be moved", function()
    hooks.ShowUnlockMode()
    assert(mover.shown == true and Shown() == "Layer ?", Shown())
    hooks.HideUnlockMode()
    assert(mover.shown == false and Shown() == nil)
end)

Case("back outside it shows again", function()
    inInstance = false
    guids.target = nil
    Fire("PLAYER_ENTERING_WORLD", false, false)
    assert(Shown() == "Layer ?", Shown())
end)

Case("a look change keeps the reading", function()
    guids.target = NPC(612)
    Fire("PLAYER_TARGET_CHANGED")
    Set("layerTrackerFontSize", 20)
    assert(Shown() == "Layer 612", Shown())
end)

Case("switched off: hidden, events dropped, and a reload's Apply keeps them off", function()
    Set("layerTracker", false)
    assert(next(events.events) == nil and Shown() == nil)
    hooks.Apply()
    assert(next(events.events) == nil and Shown() == nil)
end)

Case("switched back on: the old reading is gone", function()
    guids.target = nil
    Set("layerTracker", true)
    assert(Shown() == "Layer ?", Shown())
    assert(#frames == 3, "nothing built twice")
end)

print(("passed %d cases"):format(count))
