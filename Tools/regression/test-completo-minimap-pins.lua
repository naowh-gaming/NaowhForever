-- Run with Lua 5.1 from the repository root: the Quest List's minimap pins. Off, they register nothing; on, they
-- show the quest givers and objectives the world map's switches show, for the map you stand on, from copies the
-- world map's redraws cannot change. A quest log update redraws only the objectives, and a subzone change on the
-- same map redraws nothing.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local WESTFALL, DUSKWOOD = 1436, 1431
local settings = { enabled = true, minimapQuests = false, minimapQuestSize = 16, mapPins = true, mapGrey = false,
    mapChainsOnly = false, mapObjectives = true, mapObjectivesTracked = false }
local S = { Get = function(key) return settings[key] end, Set = function() end }

local giverCalls, objectiveCalls = 0, 0
local qGivers = {}
local Q = { Refresh = function() end, Update = function() end, Stale = function() end, Givers = function(mapID)
    giverCalls = giverCalls + 1
    for i = #qGivers, 1, -1 do qGivers[i] = nil end
    if mapID == WESTFALL then qGivers[1] = { x = 56, y = 30, quests = { 38, 22 }, grey = false } end
    return qGivers
end }
local objectiveSpots = {}
local Objectives = { List = function()
    return { ForMaps = function(_, maps)
        objectiveCalls = objectiveCalls + 1
        for i = #objectiveSpots, 1, -1 do objectiveSpots[i] = nil end
        if maps[1] == WESTFALL then objectiveSpots[1] = { map = WESTFALL, x = 40, y = 40, lines = {} } end
        return objectiveSpots
    end }
end }

local layers = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Apply = function() end,
    Completo = { Settings = S, Quests = Q, Objectives = Objectives, C = { PERCENT = 100 } },
    Shared = { Parts = { MinimapLayer = function(opts)
        local layer = { opts = opts, sets = 0 }
        function layer:Set(mapID, spots, count) self.mapID, self.spots, self.count = mapID, spots, count or 0; self.sets = self.sets + 1 end
        layers[#layers + 1] = layer
        return layer
    end } } }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local frames = {}
local mapID = WESTFALL
local giverMixin = { OnMouseEnter = function() end, OnClick = function() end, Paint = function(self, giver, size)
    self.painted, self.size = giver, size end }
local objectiveMixin = { OnMouseEnter = function() end, OnClick = function() end, Paint = function(self, spot, size)
    self.painted, self.size = spot, size end }
local env = setmetatable({
    _G = { NaowhForever = ns },
    NaowhForeverQuestGiverPinMixin = giverMixin,
    NaowhForeverQuestObjectivePinMixin = objectiveMixin,
    C_Map = { GetBestMapForUnit = function() return mapID end },
    Minimap = {},
    GameTooltip = { Hide = function() end },
    hooksecurefunc = function() end,
    CreateFrame = function()
        local f = { events = {}, scripts = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(name, fn) self.scripts[name] = fn; self[name] = fn end
        function f:CreateTexture() return { SetAllPoints = function() end } end
        function f:RegisterForClicks(...) self.clicks = { ... } end
        frames[#frames + 1] = f
        return f
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/UI/MinimapPins.lua")))
setfenv(chunk, env)
chunk()
frames[1].OnEvent(frames[1])
Check(#frames == 1 and #layers == 0 and giverCalls == 0, "off: no layers, no events, no quest reads")

settings.minimapQuests = true
ns.Apply()
local giverLayer, objectiveLayer = layers[1], layers[2]
local events = frames[2]
Check(events.events.QUEST_LOG_UPDATE and events.events.ZONE_CHANGED_NEW_AREA, "on: follows the quest log and the zone")
Check(giverLayer.mapID == WESTFALL and giverLayer.count == 1 and objectiveLayer.count == 1,
    "the givers and objectives of the map you stand on")
local copy = giverLayer.spots[1]
Check(copy ~= qGivers[1] and copy.quests[2] == 22 and copy.x == 56, "givers are copies")
Q.Givers(DUSKWOOD)
Check(giverLayer.spots[1] == copy and copy.quests[1] == 38, "the world map's next redraw leaves them as they were")

local x, y = giverLayer.opts.xy(giverLayer.spots, 1)
Check(x == 0.56 and y == 0.30, "spots go to the layer from 0 to 1")
local pin = giverLayer.opts.new(1)
Check(pin.scripts.OnEnter == giverMixin.OnMouseEnter and pin.scripts.OnClick == giverMixin.OnClick,
    "a minimap pin's tooltip and click are the world map pin's")
Check(pin.clicks[2] == "RightButtonUp", "and it takes the right-click that hides a quest")
giverLayer.opts.paint(pin, giverLayer.spots, 1)
Check(pin.painted == copy and pin.size == 16, "painted as the world map pin, at Minimap Quest Pin Size")

local givers, objectives = giverCalls, objectiveCalls
events.OnEvent(events, "QUEST_LOG_UPDATE")
Check(giverCalls == givers and objectiveCalls == objectives + 1, "a quest log update redraws only the objectives")
events.OnEvent(events, "ZONE_CHANGED")
Check(giverCalls == givers and objectiveCalls == objectives + 1, "a subzone on the same map redraws nothing")
mapID = DUSKWOOD
events.OnEvent(events, "ZONE_CHANGED")
Check(giverCalls == givers + 1 and giverLayer.mapID == DUSKWOOD and giverLayer.count == 0, "a new map redraws both")
mapID = WESTFALL
events.OnEvent(events, "ZONE_CHANGED_NEW_AREA")

settings.mapPins = false
ns.Apply()
Check(giverLayer.count == 0 and objectiveLayer.count == 1, "Quest Givers off leaves only the objectives")
settings.mapPins, settings.mapObjectives = true, false
ns.Apply()
Check(giverLayer.count == 1 and objectiveLayer.count == 0, "Quest Objectives off leaves only the givers")

settings.minimapQuests = false
ns.Apply()
Check(next(events.events) == nil and giverLayer.count == 0 and objectiveLayer.count == 0,
    "turned off: no events and nothing on the minimap")

print(("test-completo-minimap-pins: %d checks passed"):format(checks))
