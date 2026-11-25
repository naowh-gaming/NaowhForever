-- Library Books' Nearest Book waypoint: the nearest book in the zone, kept until looted, never over the player's own.
local checks = 0
local function Check(value, label) assert(value, label); checks = checks + 1 end

local settings = { enabled = true, nearbySound = false, nearestBook = false, nearbyRange = 40 }
local S = { Get = function(k) return settings[k] end }
function S.Set(k, v) settings[k] = v end

local ZONE, OTHER = 1, 2
local bookA = { name = "Book A", quest = 1 }
local bookB = { name = "Book B", quest = 2 }
local bookC = { name = "Book C", quest = 3 }
local spotA, spotB, spotC = { ZONE, 20, 20 }, { ZONE, 80, 80 }, { OTHER, 50, 50 }
local onMap = { [ZONE] = { { bookA, spotA }, { bookB, spotB } }, [OTHER] = { { bookC, spotC } } }
local zone, px, py = ZONE, 0.1, 0.1

local current, writes, clears = nil, 0, 0
local ns = { L = function(s) return s end, Apply = function() end, Print = function() end }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end
function ns.NoWaypoint() return current == nil end
function ns.GuideWaypointIsCurrent() return current ~= nil and current.details ~= nil and current.details.guide == true end
function ns.SetGuideWaypoint(title, map, x, y, details)
    writes = writes + 1
    current = { title = title, map = map, x = x, y = y, details = details }
    ns.placedWaypoint = current
    return true
end
function ns.ClearGuideWaypoint(details)
    if current and current.details == details then
        clears = clears + 1
        current, ns.placedWaypoint = nil, nil
    end
end
function ns.DismissGuideWaypoint() current, ns.placedWaypoint = nil, nil end
local function PlaceOwn()
    current = { title = "Mine", map = ZONE, x = 1, y = 1 }
    ns.placedWaypoint = current
end

ns.Discovery = {
    C = { PERCENT = 100, SPOT_MAP = 1, SPOT_X = 2, SPOT_Y = 3, SPOT_PLACE = 4 },
    Settings = S,
    Library = {
        PlayerZone = function() return zone end,
        OnMap = function(id)
            local out = {}
            for i, pair in ipairs(onMap[id] or {}) do out[i] = pair end
            return out
        end,
    },
}

local frames = {}
local function Vector(x, y) return { GetXY = function() return x, y end } end
local env = setmetatable({
    NaowhForever = ns,
    CreateVector2D = function(x, y) return { x = x, y = y } end,
    C_Map = {
        GetWorldPosFromMapPos = function(_, v) return 0, Vector(v.x * 1000, v.y * 1000) end,
        GetPlayerMapPosition = function() return Vector(px, py) end,
    },
    C_Timer = { NewTicker = function() return { Cancel = function() end } end },
    IsInInstance = function() return false end,
    IsPlayerMoving = function() return false end,
    PlaySound = function() end,
    SOUNDKIT = { MAP_PING = 1 },
    CreateFrame = function()
        local f = { events = {} }
        function f:SetScript(_, fn) self.handler = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        frames[#frames + 1] = f
        return f
    end,
    hooksecurefunc = function(t, key, fn)
        local old = t[key]
        t[key] = function(...) old(...); fn(...) end
    end,
}, { __index = _G })
env._G = env

local Load = dofile("Tools/regression/load_files.lua")
Load({ "NaowhForever_Discovery/Nearby.lua" }, env)

local function Fire(event, ...)
    for _, f in ipairs(frames) do if f.events[event] then f.handler(f, event, ...) end end
end
local function Listening(event)
    for _, f in ipairs(frames) do if f.events[event] then return true end end
    return false
end

Fire("PLAYER_LOGIN")
Check(writes == 0 and not Listening("ZONE_CHANGED_NEW_AREA"), "off: no waypoint and no zone events")

S.Set("nearestBook", true)
Check(current and current.title == "Book A" and current.x == 20 and current.y == 20, "on: the nearest book gets the waypoint")
Check(not Listening("PLAYER_STARTED_MOVING"), "without the nearby alert, movement is not watched")

px, py = 0.9, 0.9
Fire("BAG_UPDATE_DELAYED")
Check(writes == 1 and current.title == "Book A", "the waypoint stays on its book while that book is still to find")

onMap[ZONE] = { { bookB, spotB } }
Fire("BAG_UPDATE_DELAYED")
Check(writes == 2 and current.title == "Book B", "once looted, the next nearest book gets it")

onMap[ZONE] = { { bookA, spotA }, { bookB, spotB } }
PlaceOwn()
onMap[ZONE] = { { bookA, spotA } }
Fire("BAG_UPDATE_DELAYED")
Check(writes == 2 and current.title == "Mine", "the player's own waypoint is left alone")

current, ns.placedWaypoint = nil, nil
Fire("BAG_UPDATE_DELAYED")
Check(writes == 3 and current.title == "Book A", "with no waypoint up, it places again")

ns.DismissGuideWaypoint(current.details)
Fire("BAG_UPDATE_DELAYED")
Check(writes == 3 and current == nil, "dismissed by hand, it does not come back in the same zone")

zone = OTHER
Fire("ZONE_CHANGED_NEW_AREA")
Check(writes == 4 and current.title == "Book C", "a new zone with books places again")

onMap[OTHER] = {}
Fire("BAG_UPDATE_DELAYED")
Check(current == nil and clears == 1, "the zone's last book looted clears its waypoint")

onMap[OTHER] = { { bookC, spotC } }
Fire("ZONE_CHANGED_NEW_AREA")
Check(current and current.title == "Book C", "back in a zone with books")
S.Set("nearestBook", false)
Check(current == nil and clears == 2, "turned off, it clears its own waypoint")

S.Set("nearbySound", true)
Check(writes == 5 and Listening("PLAYER_STARTED_MOVING"), "the nearby alert alone still watches movement, with no waypoint")

print(("Library nearest book regression test: PASS (%d checks)"):format(checks))
