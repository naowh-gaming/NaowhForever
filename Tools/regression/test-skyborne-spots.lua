-- Run with Lua 5.1 from the repository root: Skyborne Spots. A long Skysight (Horde) or a
-- Read Ley Line that goes off (Alliance) saves the spot once, a find close to a known spot
-- is that spot, other races watch nothing, and the map pins the character's own kind only.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, mapSkyborne = true, mapSkyborneSize = 20 }
local S = { Get = function(key) return settings[key] end, Set = function() end }
local account, printed, card = {}, {}, nil
local ns = {
    QoLSettings = S,
    Apply = function() end,
    AccountSettings = function() return account end,
    Print = function(msg) printed[#printed + 1] = msg end,
    ThemeTint = function() return nil end,
    PlaceWaypoint = function() end,
    Shared = { Settings = { Page = function() return { Card = function(_, c) card = c end } end } },
}

local race, faction = "Skyborne", "Horde"
local where = { map = 2521, x = 0.434, y = 0.441 }
local aura
local function Vector(x, y) return { GetXY = function() return x, y end } end

-- Frames in the order the file makes them: the watcher first, then the login frame.
local frames = {}
local function NewFrame()
    local f = { events = {}, unitEvents = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:RegisterUnitEvent(e) self.unitEvents[e] = true end
    function f:UnregisterAllEvents() self.events, self.unitEvents = {}, {} end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end

local provider
local pins = {}
local mapShown = {
    GetMapID = function() return 2521 end,
    IsMaximized = function() return false end,
    AcquirePin = function(_, _, entry, x, y) pins[#pins + 1] = { entry = entry, x = x, y = y } end,
    RemoveAllPinsByTemplate = function() for i = #pins, 1, -1 do pins[i] = nil end end,
}

local function Mixin(...)
    local t = {}
    for i = 1, select("#", ...) do for k, v in pairs(select(i, ...)) do t[k] = v end end
    return t
end

local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = Mixin,
    CreateVector2D = Vector,
    MapCanvasPinMixin = {},
    MapCanvasDataProviderMixin = { GetMap = function() return mapShown end },
    CreateFrame = NewFrame,
    hooksecurefunc = function() end,
    InCombatLockdown = function() return false end,
    UnitRace = function() return "Windshaper Skyborne", race, 96 end,
    UnitFactionGroup = function() return faction end,
    C_Map = {
        GetBestMapForUnit = function() return where.map end,
        GetPlayerMapPosition = function() return Vector(where.x, where.y) end,
        GetMapInfo = function() return { name = "Zephras Isle", mapType = 3 } end,
        -- 1000 yards across the zone, on continent 1.
        GetWorldPosFromMapPos = function(_, v)
            local x, y = v:GetXY()
            return 1, Vector(x * 1000, y * 1000)
        end,
        GetMapPosFromWorldPos = function() return 1, nil end,
    },
    C_UnitAuras = {
        GetPlayerAuraBySpellID = function(id) return id == 1259686 and aura or nil end,
        GetAuraDataByIndex = function() return nil end,
    },
    C_Spell = { GetSpellName = function(id) return id == 4242 and "Read Ley Line" or "Something" end },
    WorldMapFrame = {
        IsShown = function() return true end,
        HookScript = function() end,
        AddDataProvider = function(_, p) provider = p end,
    },
}, { __index = _G })
local chunk = assert(loadstring(Read("QoL/NaowhForever_SkyborneSpots.lua")))
setfenv(chunk, env)
chunk()
local watch, boot = frames[1], frames[2]

Check(Read("QoL/NaowhForever_QoL.lua"):find("mapSkyborne = false", 1, true), "Skyborne Spots starts off")
Check(card and card.switch == "mapSkyborne", "the card switches the setting")

boot.onEvent(boot, "PLAYER_LOGIN")
Check(watch.unitEvents.UNIT_AURA and not watch.unitEvents.UNIT_SPELLCAST_SUCCEEDED,
    "a Horde Skyborne watches its buffs only")

aura = { duration = 30, expirationTime = 100 }
watch.onEvent(watch, "UNIT_AURA", "player")
Check(not account.skyborneSpots or #account.skyborneSpots.convergence == 0, "a short Skysight saves nothing")

aura = { duration = 900, expirationTime = 200 }
watch.onEvent(watch, "UNIT_AURA", "player")
local found = account.skyborneSpots.convergence
Check(#found == 1 and found[1][1] == 2521 and found[1][2] == 43.4 and found[1][3] == 44.1,
    "a long Skysight saves the spot, in percent")
Check(printed[1] and printed[1]:find("Elemental Convergence saved", 1, true), "and says so")

watch.onEvent(watch, "UNIT_AURA", "player")
where.x = 0.45   -- 16 yards on
aura = { duration = 900, expirationTime = 300 }
watch.onEvent(watch, "UNIT_AURA", "player")
Check(#found == 1, "the same buff, or a find a few yards away, is the same spot")

where.x = 0.6
aura = { duration = 900, expirationTime = 400 }
watch.onEvent(watch, "UNIT_AURA", "player")
Check(#found == 2, "a find far off is a new spot")

provider:RefreshAllData()
Check(#pins == 2 and pins[1].entry.kind == "convergence" and pins[1].entry.found, "the map pins both")
Check(math.abs(pins[1].x - 0.434) < 1e-9, "where they were found")

settings.mapSkyborne = false
provider:RefreshAllData()
Check(#pins == 0, "no pins while off")
settings.mapSkyborne = true

faction = "Alliance"
boot.onEvent(boot, "PLAYER_LOGIN")
Check(watch.unitEvents.UNIT_SPELLCAST_SUCCEEDED and not watch.unitEvents.UNIT_AURA,
    "an Alliance Skyborne watches its casts only")
watch.onEvent(watch, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 99)
Check(not account.skyborneSpots.leyline or #account.skyborneSpots.leyline == 0, "another spell saves nothing")
watch.onEvent(watch, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 4242)
Check(#account.skyborneSpots.leyline == 1, "a Read Ley Line that goes off saves a ley line")
provider:RefreshAllData()
Check(#pins == 1 and pins[1].entry.kind == "leyline", "an Alliance map shows ley lines, not convergences")

race = "Human"
boot.onEvent(boot, "PLAYER_LOGIN")
Check(next(watch.unitEvents) == nil, "another race watches nothing")
provider:RefreshAllData()
Check(#pins == 0, "and sees no pins")
Check(card.summary() == "Only for Skyborne characters", "the card says who it is for")

print(("test-skyborne-spots: %d checks passed"):format(checks))
