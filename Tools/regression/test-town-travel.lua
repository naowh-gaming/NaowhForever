-- Run with Lua 5.1 from the repository root: the town map's boats and zeppelins. Every dock is a
-- clickable pin that opens a zone with a dock leading back, the routes run both ways, the
-- town map draws them for your faction, and the setting starts off.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = {}
local chunk = assert(loadstring(Read("QoL/NaowhForever_TownTravel.lua")))
setfenv(chunk, { _G = { NaowhForever = ns } })
chunk()

local total = 0
for map, list in pairs(ns.TownTravel) do
    for _, dock in ipairs(list) do
        Check(dock[1] >= 0 and dock[1] <= 100 and dock[2] >= 0 and dock[2] <= 100, "on the map: " .. map)
        Check(dock[3]:find("^Boat to ") or dock[3]:find("^Zeppelin to "), "says where it goes: " .. dock[3])
        Check(dock[5] == "A" or dock[5] == "H" or dock[5] == "AH", "a faction: " .. dock[3])
        local back = false
        for _, other in ipairs(ns.TownTravel[dock[4]] or {}) do
            if other[4] == map then back = true end
        end
        Check(back, "the zone it opens has a dock back: " .. dock[3])
        total = total + 1
    end
end
Check(total == 16, "both ends of the eight routes (" .. total .. ")")
Check(ns.TownTravel[1413][1][3] == "Boat to Booty Bay" and ns.TownTravel[1413][1][4] == 1434,
    "Ratchet's boat opens Stranglethorn")

local map = Read("QoL/NaowhForever_TownMap.lua")
Check(map:find("ns.TownTravel[mapID]", 1, true) and map:find('S.Get("townTravel")', 1, true),
    "the town map draws them on their own switch")
Check(map:find("linkedUiMapID = dock[4]", 1, true), "as clickable zone links")
Check(Read("QoL/NaowhForever_QoL.lua"):find("townTravel = false", 1, true), "Boats & Zeppelins starts off")

print(("test-town-travel: %d checks passed"):format(checks))
