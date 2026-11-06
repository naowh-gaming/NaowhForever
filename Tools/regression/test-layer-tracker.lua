-- Run with Lua 5.1 from the repository root: Layer Tracker.
-- Off it builds nothing and listens to nothing. On, the layer is the server and zone copy in an NPC's GUID: the
-- target and mouseover always take over, a nameplate only fills an empty reading, and players and secret GUIDs or
-- units are never read. A zone change, a layer move and a loading screen start it over; inside an instance it
-- hides, except in Unlock Mode. The game's layer change counts down on the line, a move is said in chat once, and
-- the hover lists the layers seen in the zone, newest first.
local NOTHING = function() end
local SECRET = "Creature-0-5250-1-999-3100-0000ABCDEF"
local frames = {}
local guids = {}
local inInstance = false
local now, clock = 1000, 5000
local eviction = 161
local printed = {}
local tickers = {}
local mapNow = 1411
local MAPS = { [1411] = { name = "Durotar", mapType = 3, parentMapID = 12 }, [1454] = { name = "Orgrimmar", mapType = 3, parentMapID = 12 },
    [1412] = { name = "Mulgore", mapType = 3, parentMapID = 12 }, [1413] = { name = "The Barrens", mapType = 3, parentMapID = 12 }, [2001] = { name = "Cleft", mapType = 5, parentMapID = 1454 } }

local function Frame(kind)
    local f = { kind = kind, scripts = {}, events = {}, shown = false, width = 0 }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetWidth(w) self.width = w end
    f.SetMovable, f.SetClampedToScreen, f.ClearAllPoints, f.SetPoint, f.SetHeight = NOTHING, NOTHING, NOTHING, NOTHING, NOTHING
    f.RegisterForClicks = NOTHING
    frames[#frames + 1] = f
    return f
end

local tip = { lines = {} }
function tip:SetText(text) self.title, self.lines = text, {} end
function tip:AddLine(text) self.lines[#self.lines + 1] = { text } end
function tip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = { tostring(left), right } end
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end

local settings = { enabled = true, layerTrackerFontSize = 14, layerTrackerFont = "", layerTrackerOutline = "OUTLINE",
    layerTrackerBackground = "none", layerTrackerCountdown = true, layerTrackerChat = true }
local setHooks, hooks = {}, {}
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end }
local card, mover
local ns = {
    QoLSettings = S,
    QoLConstants = { SECONDS_PER_MINUTE = 60 },
    THEME = { muted = { r = 0.5, g = 0.5, b = 0.5 }, accentSoft = { r = 0, g = 0.6, b = 1 } },
    Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
    Print = function(text) printed[#printed + 1] = text end,
    L = dofile("Tools/regression/locale_stub.lua").L,
    UI = {
        AttachMover = function()
            mover = { SetShown = function(self, on) self.shown = on end }
            return mover
        end,
    },
    Font = function()
        return { SetPoint = NOTHING, SetText = function(self, text) self.text = text end,
            GetStringWidth = function(self) return #self.text * 7 end }
    end,
    Shared = {
        Ago = function(at) return ("%d min ago"):format(math.floor((now - at) / 60)) end,
        Parts = {
            HudBackdrop = function() return { SetMode = function(_, mode) return mode end } end,
            HudFont = NOTHING,
            Tip = function() return true end,
        },
        Settings = {
            Page = function() return { Card = function(_, c) card = c end } end,
            Look = function() return {} end,
            Group = function(title) return { group = title } end,
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
    Enum = { UIMapType = { Zone = 3 } },
    CreateFrame = Frame,
    UIParent = {},
    GameTooltip = tip,
    strsplit = Split,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function(v) return v == SECRET end,
    UnitGUID = function(unit)
        assert(unit ~= SECRET, "a secret unit reached UnitGUID")
        return guids[unit]
    end,
    IsInInstance = function() return inInstance end,
    GetTime = function() return clock end,
    time = function() return now end,
    GetEvictionTimeRemaining = function() return eviction end,
    C_Map = {
        GetBestMapForUnit = function() return mapNow end,
        GetMapInfo = function(id) return MAPS[id] end,
    },
    C_Timer = {
        NewTicker = function(_, fn)
            local t = { fn = fn }
            function t:Cancel() self.cancelled = true end
            tickers[#tickers + 1] = t
            return t
        end,
    },
    hooksecurefunc = function(t, name, fn)
        if t == S then setHooks[#setHooks + 1] = fn else hooks[name] = fn end
    end,
}, { __index = _G })
env._G = env
for _, path in ipairs({ "Shared/Game/Layers.lua", "NaowhForever_QoL/Questing/LayerTracker.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end
local Layers = ns.Layers
local clicks, tipped = 0, 0
Layers.Click = function() clicks = clicks + 1 end
Layers.AddTip = function() tipped = tipped + 1 end
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

local function NPC(zone, server, id)
    return ("Creature-0-%d-1-%d-%d-0000ABCDEF"):format(server or 5250, zone, id or 3100)
end

local function Ticker()
    local live = tickers[#tickers]
    if live and not live.cancelled then return live end
end

local function Hover()
    readout.scripts.OnEnter(readout)
    return tip.lines
end

local count = 0
local function Case(name, fn) printed = {}; fn(); count = count + 1; print("PASS " .. name) end

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
    assert(readout.kind == "Button")
    assert(events.events.NAME_PLATE_UNIT_ADDED and events.events.SHARD_TRANSFER and events.events.SHARD_TRANSFER_IMMINENT)
    assert(Shown() == "Layer ?", Shown())
    assert(Layers.Map() == 1411 and Layers.Current() == nil)
end)

Case("a nameplate fills the reading with its zone copy, sized to the text", function()
    guids.nameplate1 = NPC(18853)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    assert(Shown() == "Layer 18853", Shown())
    assert(readout.width == #"Layer 18853" * 7 + 16)
    local key, zone = Layers.Current()
    assert(key == "5250-18853" and zone == 18853, key)
end)

Case("a later nameplate does not take over", function()
    guids.nameplate2 = NPC(16)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    assert(Shown() == "Layer 18853", Shown())
end)

Case("the target and the mouseover do", function()
    now = now + 60
    guids.target = NPC(16)
    Fire("PLAYER_TARGET_CHANGED")
    assert(Shown() == "Layer 16", Shown())
    now = now + 60
    guids.mouseover = NPC(4410, 5250, 3296)
    Fire("UPDATE_MOUSEOVER_UNIT")
    assert(Shown() == "Layer 4410", Shown())
    assert(#printed == 0, "a reading that is not a move says nothing")
end)

Case("a vehicle counts as an NPC", function()
    guids.mouseover = "Vehicle-0-5250-1-77-2961-0000ABCDEF"
    Fire("UPDATE_MOUSEOVER_UNIT")
    assert(Shown() == "Layer 77", Shown())
end)

Case("players, pets, no unit and a zero server or copy are not read", function()
    guids.target = "Player-5250-0A1B2C3D"
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = "Pet-0-5250-1-99-416-0100ABCDEF"
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = nil
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = NPC(0)
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = NPC(55, 0)
    Fire("PLAYER_TARGET_CHANGED")
    assert(Shown() == "Layer 77", Shown())
end)

Case("the same copy number on another server is another layer", function()
    guids.target = NPC(77, 5251)
    Fire("PLAYER_TARGET_CHANGED")
    assert(Layers.Current() == "5251-77")
end)

Case("the hover lists the zone's layers, newest first, yours marked", function()
    local lines = Hover()
    assert(tip.title == "Layers in Durotar", tip.title)
    assert(lines[1][1] == "77" and lines[1][2] == "You are here", lines[1][2])
    assert(#lines == 5, #lines)
    assert(lines[#lines][1] == "18853" and lines[#lines][2] == "2 min ago", lines[#lines][2])
    assert(tipped == 1, "the swap hint is asked for")
end)

Case("a layer heard from a swap request is listed as one", function()
    Layers.Note(1411, "5250-20112", 20112)
    Layers.Note(1412, "5250-31", 31)
    local lines = Hover()
    assert(lines[1][1] == "20112" and lines[1][2] == "From a swap request, 0 min ago", lines[1][2])
    for _, line in ipairs(lines) do assert(line[1] ~= "31", "another zone's layer is not listed") end
end)

Case("a request naming a layer you saw does not mark it as heard", function()
    Layers.Note(1411, "5250-16", 16)
    for _, line in ipairs(Hover()) do
        if line[1] == "16" then assert(line[2] == "0 min ago", line[2]) end
    end
end)

Case("a heard layer you then see yourself is no longer marked as heard", function()
    Layers.Note(1411, "5250-30000", 30000)
    guids.target = NPC(30000)
    Fire("PLAYER_TARGET_CHANGED")
    guids.target = NPC(16)
    Fire("PLAYER_TARGET_CHANGED")
    local found
    for _, line in ipairs(Hover()) do
        if line[1] == "30000" then found = line[2] end
    end
    assert(found == "0 min ago", found)
end)

Case("a click goes to the swaps", function()
    readout.scripts.OnClick(readout, "LeftButton")
    assert(clicks == 1)
end)

Case("a secret GUID or nameplate unit is never read", function()
    guids.target = SECRET
    Fire("PLAYER_TARGET_CHANGED")
    Fire("SHARD_TRANSFER")
    Fire("NAME_PLATE_UNIT_ADDED", SECRET)
    assert(Shown() == "Layer ?", Shown())
end)

Case("the game's layer change counts down on the line", function()
    guids.target = NPC(612)
    Fire("PLAYER_TARGET_CHANGED")
    Fire("SHARD_TRANSFER_IMMINENT")
    assert(Shown() == "Layer 612 - changes in 2:41", Shown())
    local ticker = assert(Ticker(), "a ticker runs while counting")
    clock = clock + 61
    ticker.fn()
    assert(Shown() == "Layer 612 - changes in 1:40", Shown())
    clock = clock + 100
    ticker.fn()
    assert(Shown() == "Layer 612 - changing", Shown())
end)

Case("a cancelled change stops the countdown", function()
    Fire("SHARD_TRANSFER_CANCELLED")
    assert(Shown() == "Layer 612" and not Ticker(), Shown())
end)

Case("Countdown off: no ticker and no countdown", function()
    Set("layerTrackerCountdown", false)
    Fire("SHARD_TRANSFER_IMMINENT")
    assert(Shown() == "Layer 612" and not Ticker(), Shown())
    Set("layerTrackerCountdown", true)
    assert(Ticker() and Shown():find("changes in"), "turning it back on mid-change counts down")
end)

Case("a move starts over and the next reading says the move once", function()
    Fire("SHARD_TRANSFER")
    assert(Shown() == "Layer ?" and not Ticker(), Shown())
    guids.nameplate4 = NPC(20113)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    assert(Shown() == "Layer 20113", Shown())
    assert(#printed == 1 and printed[1] == "You moved to layer 20113 (it was 612).", printed[1])
    guids.target = NPC(612)
    Fire("PLAYER_TARGET_CHANGED")
    assert(#printed == 1, "a later reading is not a move")
end)

Case("a move back to the same layer says nothing", function()
    Fire("SHARD_TRANSFER")
    Fire("PLAYER_TARGET_CHANGED")
    assert(Shown() == "Layer 612" and #printed == 0)
end)

Case("Say When You Move off: a move says nothing", function()
    Set("layerTrackerChat", false)
    Fire("SHARD_TRANSFER")
    guids.target = NPC(700)
    Fire("PLAYER_TARGET_CHANGED")
    assert(Shown() == "Layer 700" and #printed == 0)
    Set("layerTrackerChat", true)
end)

Case("a new zone starts over, and a move is not carried across it", function()
    Fire("SHARD_TRANSFER")
    mapNow = 1454
    Fire("ZONE_CHANGED_NEW_AREA")
    assert(Shown() == "Layer ?" and Layers.Map() == 1454, Shown())
    guids.target = NPC(900)
    Fire("PLAYER_TARGET_CHANGED")
    assert(#printed == 0)
    Hover()
    assert(tip.title == "Layers in Orgrimmar" and #tip.lines == 1, #tip.lines)
end)

Case("a smaller map inside a zone counts as the zone", function()
    mapNow = 2001
    Fire("ZONE_CHANGED_NEW_AREA")
    assert(Layers.Map() == 1454)
end)

Case("an empty zone says how to read it", function()
    mapNow = 1413
    Fire("ZONE_CHANGED_NEW_AREA")
    local lines = Hover()
    assert(#lines == 1 and lines[1][1] == "Target or mouse over an NPC to read your layer.", lines[1][1])
end)

Case("the seen list keeps the newest twelve", function()
    mapNow = 1412
    Fire("ZONE_CHANGED_NEW_AREA")
    for i = 1, 14 do
        now = now + 1
        Layers.Note(1412, "5250-" .. i, i)
    end
    local lines = Hover()
    assert(#lines == 12, #lines)
    for _, line in ipairs(lines) do assert(line[1] ~= "1" and line[1] ~= "2" and line[1] ~= "31", "the oldest went") end
end)

Case("a loading screen starts over and reads the target there", function()
    mapNow = 1411
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
    assert(Shown() == nil and Layers.Current() == nil, "still hidden, nothing read")
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

Case("the line shows when swaps are asking", function()
    Layers.asking = true
    Layers.Refresh()
    assert(Shown() == "Layer 612 - asking", Shown())
    Layers.asking = nil
    Layers.Refresh()
end)

Case("switched off: hidden, events dropped, the countdown stopped, and a reload's Apply keeps them off", function()
    Fire("SHARD_TRANSFER_IMMINENT")
    assert(Ticker())
    Set("layerTracker", false)
    assert(next(events.events) == nil and Shown() == nil and not Ticker())
    hooks.Apply()
    assert(next(events.events) == nil and Shown() == nil)
    assert(Layers.Current() == nil, "nothing is reported while off")
end)

Case("switched back on: the old reading is gone", function()
    guids.target = nil
    Set("layerTracker", true)
    assert(Shown() == "Layer ?", Shown())
    assert(#frames == 3, "nothing built twice")
end)

print(("passed %d cases"):format(count))
