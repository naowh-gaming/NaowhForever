-- Run with Lua 5.1 from the repository root: Completo's quest giver pins on the world map are
-- Pin Size on the small map and the full screen map alike, and keep one size on screen as the
-- map zooms. While Ctrl is held they take no clicks, so a Ctrl+Click reaches the map's waypoint. A
-- map no giver stands on, a dungeon's, reads nothing of your quests.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, mapPins = true, mapPinSize = 20, mapDungeon = true }
local S = { Get = function(key) return settings[key] end, Set = function() end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, CompletoSettings = S, Apply = function() end, ThemeTint = function() end,
    Completo = { Settings = S, Style = {}, C = { PERCENT = 100 },
        Quests = { Refresh = function() end, Update = function() end, Stale = function() end, Givers = function() return {} end,
        HasGivers = function() return true end } } }
function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end

local maximized, canvasScale = false, 1
local pins = {}
local provider
local map = {
    IsShown = function() return true end,
    IsMaximized = function() return maximized end,
    AddDataProvider = function(_, p) provider = p end,
    GetCanvasScale = function() return canvasScale end,
    GetMapID = function() return 1 end,
    RemoveAllPinsByTemplate = function() end,
    AcquirePin = function() end,
    EnumeratePinsByTemplate = function()
        local i = 0
        return function() i = i + 1; return pins[i] end
    end,
}
local boot, lastFrame
local ctrl = false
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = function() return { GetMap = function() return map end } end,
    MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
    CreateFrame = function()
        local f = { events = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:SetScript(name, fn) self[name] = fn end
        if not boot then boot = f end
        lastFrame = f
        return f
    end,
    hooksecurefunc = function() end,
    IsControlKeyDown = function() return ctrl end,
    WorldMapFrame = map,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
local shared = assert(loadstring(Read("Shared/Shared.lua")))
setfenv(shared, env)
shared()
ns.Shared.OpenMap = dofile("Tools/regression/shared_openmap.lua")
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/UI/QuestPins.lua")))
setfenv(chunk, env)
chunk()
boot.OnEvent(boot)

local Pin = env.NaowhForeverQuestGiverPinMixin
local function NewPin()
    local pin = setmetatable({ Icon = { SetAtlas = function() return true end, SetDesaturated = function() end,
        SetVertexColor = function() end } }, { __index = Pin })
    function pin:GetMap() return map end
    function pin:SetSize(w) self.size = w end
    function pin:SetPosition() end
    function pin:SetScale(s) self.scale = s end
    function pin:ApplyCurrentPosition() end
    function pin:EnableMouse(on) self.clicks = on end
    return pin
end

local pin = NewPin()
pin:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(pin.size == 20, "Pin Size on the small map")
Check(pin.scale == 0.75, "scaled as it is placed, not only on the next zoom, at half the shared scale")
maximized = true
local big = NewPin()
big:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(big.size == 20, "the same Pin Size on the full screen map")
Check(math.abs(big.scale - pin.scale * 1.5) < 1e-9, "drawn half as big again there")
maximized = false

Check(pin.clicks == true, "a placed pin takes clicks")
local watch = lastFrame
ctrl = true
watch.OnEvent(watch, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(pin.clicks == true, "another modifier changes nothing")
watch.OnEvent(watch, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(pin.clicks == false and big.clicks == false, "no clicks while Ctrl is held")
local held = NewPin()
held:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(held.clicks == false, "a pin placed while Ctrl is held takes no clicks either")
ctrl = false
watch.OnEvent(watch, "MODIFIER_STATE_CHANGED", "RCTRL", 0)
Check(pin.clicks == true and held.clicks == true, "clicks again once Ctrl is let go")

Check(Pin.ApplyCurrentScale ~= nil, "scaled by the shared map pin scale, with its own factor")
local onScreen
for _, scale in ipairs({ 0.5, 1, 2.5 }) do
    canvasScale = scale
    pin:ApplyCurrentScale()
    local size = pin.scale * scale
    Check(not onScreen or math.abs(size - onScreen) < 1e-9, "one size on screen at canvas scale " .. scale)
    onScreen = size
end

-- The mark: a dungeon quest's giver is the ! tinted green, a repeatable-only giver the game's blue
-- !, a grey one the game's grey mark.
ns.Completo.Style.DUNGEON_RGB = { r = 0.3, g = 1, b = 0.3 }
ns.Completo.Style.REPEAT_RGB = { r = 0.35, g = 0.7, b = 1 }
local function Mark(giver)
    local seen = {}
    local p = NewPin()
    p.Icon.SetAtlas = function(_, atlas) seen.atlas = atlas; return true end
    p.Icon.SetDesaturated = function(_, on) seen.desaturated = on end
    p.Icon.SetVertexColor = function(_, r, g, b) seen.color = { r, g, b } end
    giver.x, giver.y, giver.quests = 50, 50, { 1 }
    p:OnAcquired(giver)
    return seen
end
local m = Mark({ grey = false, repeatable = false, dungeon = true })
Check(m.atlas == "QuestNormal" and m.desaturated and m.color[2] == 1 and m.color[1] < 1, "a dungeon quest's giver is green")
m = Mark({ grey = false, repeatable = true, dungeon = true })
Check(m.atlas == "QuestNormal" and m.color[2] == 1, "a dungeon quest stays green when it is also repeatable")
m = Mark({ grey = false, repeatable = true, dungeon = false })
Check(m.atlas == "QuestDaily" and not m.desaturated, "a repeatable-only giver gets the game's blue !")
m = Mark({ grey = true, repeatable = true, dungeon = false })
Check(m.atlas == "QuestDaily", "a repeatable-only giver stays blue when its quests no longer give experience")
m = Mark({ grey = true, repeatable = false, dungeon = true })
Check(m.atlas == "TrivialQuests", "a grey dungeon quest stays grey")
m = Mark({ grey = false, repeatable = false, dungeon = false })
Check(m.atlas == "QuestNormal" and not m.desaturated and m.color[1] == 1, "any other giver keeps the yellow !")

settings.mapDungeonColor = { r = 0.8, g = 0.2, b = 0.6 }
m = Mark({ grey = false, repeatable = false, dungeon = true })
Check(m.desaturated and m.color[1] == 0.8 and m.color[2] == 0.2 and m.color[3] == 0.6,
    "a dungeon quest's giver takes the color picked")
settings.mapDungeon = false
m = Mark({ grey = false, repeatable = false, dungeon = true })
Check(m.atlas == "QuestNormal" and not m.desaturated and m.color[1] == 1 and m.color[3] == 1,
    "with Color Dungeon Quests off, a dungeon quest's giver keeps the yellow !")
m = Mark({ grey = false, repeatable = true, dungeon = true })
Check(m.atlas == "QuestDaily", "and a repeatable dungeon quest's giver gets the blue ! as any other")

-- Shift shows the rest of a quest's chain and the open breadcrumbs that lead to it, and the
-- tooltip redraws as Shift goes down and up while the pin is hovered.
local Q = ns.Completo.Quests
local names = { [1] = "First", [2] = "Second", [3] = "Third A", [4] = "Third B", [5] = "Alliance Fourth",
    [6] = "Horde Fourth", [7] = "Breadcrumb", [8] = "Done Breadcrumb", [9] = "Single", [10] = "Paid" }
local chain = { steps = { { 1 }, { 2 }, { 3, 4 }, { 5, 6, any = true } } }
local stepOf = { [1] = 1, [2] = 2 }
Q.Name = function(id) return names[id] end
Q.Level = function() return 10 end
Q.Trivial = function() return false end
Q.Repeatable = function() return false end
Q.Dungeon = function() return false end
Q.Giver = function() return "Giver" end
Q.Item = function() end
Q.Hidden = function() return false end
Q.Chain = function(id) return stepOf[id] and chain end
Q.ChainStep = function(id) return stepOf[id], #chain.steps end
Q.Breadcrumbs = function(id) return id == 1 and { 7, 8 } or {} end
Q.Available = function(id) return id ~= 8 end
local gains = { [1] = { 1000, 250, 72, 75, 999, 10, 87, -500 }, [10] = { 115, -300 } }
local instances = { [9] = 1581 }
Q.Gains = function(id) return gains[id] end
Q.Instance = function(id) return instances[id] end
local playerLevel = 10
env.UnitLevel = function() return playerLevel end
env.GetMaxLevelForPlayerExpansion = function() return 60 end
env.BreakUpLargeNumbers = function(n) return tostring(n) end
env.C_CurrencyInfo = { GetCoinTextureString = function(c) return c .. "c" end }
env.C_Reputation = { GetFactionDataByID = function(id) return ({ [72] = { name = "Stormwind" }, [87] = { name = "Bloodsail" } })[id] end }
env.C_Map = { GetAreaInfo = function(id) return id == 1581 and "The Deadmines" or nil end }
ns.Completo.Style.GREY_RGB = { r = 0.5, g = 0.5, b = 0.5 }
ns.Completo.Style.GOLD_RGB = { r = 1, g = 0.82, b = 0 }
ns.Completo.Style.Hint = function() return 0.6, 0.6, 0.6 end
local lines, owner, shown = {}, nil, false
env.GameTooltip = {
    SetOwner = function(_, o) owner = o; lines = {} end,
    SetText = function(_, t) lines[#lines + 1] = t end,
    AddLine = function(_, t) lines[#lines + 1] = t end,
    AddDoubleLine = function(_, t) lines[#lines + 1] = t end,
    Show = function() shown = true end,
    Hide = function() shown = false end,
    IsShown = function() return shown end,
    GetOwner = function() return owner end,
}
env.GetQuestDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
local shift = false
env.IsShiftKeyDown = function() return shift end
local function Has(text)
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local giver = NewPin()
giver:OnAcquired({ x = 50, y = 50, quests = { 1 } })
giver:OnMouseEnter()
Check(Has("First") and not Has("Second") and not Has("Breadcrumb"), "without Shift only the quest itself")
Check(Has("Hold Shift for rewards and the rest of the chain."), "and a hint that Shift shows more")
Check(not Has("XP"), "no rewards without Shift")
local shiftFrame = lastFrame
Check(shiftFrame.events.MODIFIER_STATE_CHANGED, "listening for Shift while hovered")
shift = true
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(Has("Next in chain:") and Has("Second") and Has("Third A") and Has("Third B"),
    "pressing Shift redraws with every later step, parallel quests and all")
Check(Has("Alliance Fourth") and not Has("Horde Fourth"), "one version of a step taken by either version")
Check(Has("Also sent here by:") and Has("    Breadcrumb") and not Has("Done Breadcrumb"),
    "and the breadcrumbs still open to you")
Check(not Has("Hold Shift"), "no hint while Shift is held")
Check(Has("1000 XP") and Has("250c"), "the quest's experience at its own level, and its money")
Check(Has("+75 Stormwind") and not Has("+10"), "its reputation, leaving out a faction the game does not know")
Check(Has("-500 Bloodsail") and not Has("+-"), "and a reputation it costs")
playerLevel = 15
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(Has("1000 XP"), "the full experience up to five levels over the quest")
playerLevel = 16
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(Has("800 XP"), "less after that: six levels over gives 80%")
playerLevel = 17
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(Has("600 XP"), "seven levels over gives 60%")
playerLevel = 18
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(Has("500 XP"), "eight levels over gives half")
playerLevel = 30
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(Has("500 XP") and not Has("100 XP"), "and never less than half on Forever, however far over")
playerLevel = 60
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(not Has("XP") and Has("250c"), "no experience at max level, the money still")
playerLevel = 10
shift = false
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 0)
Check(not Has("Second") and Has("Hold Shift"), "letting go of Shift redraws it short again")

giver:OnAcquired({ x = 50, y = 50, quests = { 9 } })
shift = true
giver:OnMouseEnter()
Check(not Has("Next in chain:") and not Has("Also sent here by:"), "a single quest has no chain")
Check(Has("Instance: The Deadmines"), "an instance quest names its instance")
instances[9] = nil
giver:OnMouseEnter()
Check(#lines == 4, "a quest with nothing more adds no lines")
shift = false
giver:OnMouseEnter()
Check(not Has("Hold Shift"), "and no Shift hint")

giver:OnAcquired({ x = 50, y = 50, quests = { 10 } })
shift = true
giver:OnMouseEnter()
Check(Has("115 XP") and not Has("300c"), "full experience as Wowhead gives it, and no money for a quest that costs some")
playerLevel = 60
shift = false
giver:OnMouseEnter()
Check(not Has("Hold Shift"), "no Shift hint at max level when experience is all a quest gives")
playerLevel = 10

shown = false
shiftFrame.OnEvent(shiftFrame, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(not shiftFrame.events.MODIFIER_STATE_CHANGED, "stops listening once the tooltip is gone")

local reads, standing = 0, {}
Q.Update = function() reads = reads + 1 end
Q.HasGivers = function(mapID) return standing[mapID] == true end
Q.Givers = function() return {} end
provider:RefreshAllData()
Check(reads == 0, "opening a map no giver stands on reads nothing of your quests")
standing[1] = true
provider:RefreshAllData()
Check(reads == 1, "one a giver stands on reads them")

print(("test-completo-quest-pins: %d checks passed"):format(checks))
