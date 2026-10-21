-- Run with Lua 5.1 from the repository root: Minimap Node Icons (NodeScan.lua, UI/NodeIcons.lua).
-- A stub minimap names the herbs and veins under its soft cursor, as the game's minimap tooltip
-- does, for dots that stay put in the world while the player walks and turns. The scan finds each
-- dot, a fine probe puts its icon on the dot's middle, and the icon stays there while the player
-- walks (no jump at each rescan), turns with a rotating minimap, rings a node above your skill red,
-- never probes in combat or under the real mouse, and adds the skill each node needs to the tooltip.
-- The data table matches Glimmer's herbs and veins, name for name and skill for skill.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Near(a, b, within) return math.abs(a - b) <= within end

local WIDTH, LEFT, BOTTOM = 140, 100, 200
local VIEW_RADIUS = 140
local MAP_YARDS = 1000
local DOT = 5
local SCALE = WIDTH / 2 / VIEW_RADIUS
local ON_DOT = 1
local DOTS = {
    { name = "Tin Vein", x = 40, y = 90 },
    { name = "Copper Vein", x = 100, y = 50 },
    { name = "Peacebloom", x = 70, y = 105 },
}

local function Noop() end
local softCursor, mouseOver, inCombat = false, false, false
local probes, probesWithoutCursor = 0, 0
local cursorX, cursorY
local rotate, facing = "0", 0
local player = { x = 0.5, y = 0.5 }
local tooltipHook
local boot, holder
local textures = {}

local function Texture()
    local t = { shown = true }
    function t.SetTexture(self, tex) self.texture = tex end
    function t.SetSize(self, w) self.size = w end
    function t.SetPoint(self, _, _, _, x, y) self.x, self.y = x, y end
    function t.SetVertexColor(self, r, g, b) self.rgb = { r, g, b } end
    function t.SetShown(self, on) self.shown = on and true or false end
    function t.Hide(self) self.shown = false end
    function t.Show(self) self.shown = true end
    setmetatable(t, { __index = function(_, k) if k:find("^%u") then return Noop end end })
    textures[#textures + 1] = t
    return t
end

local frameMethods = {
    SetScript = function(f, name, fn) f[name] = fn end,
    RegisterEvent = function(f, event) if event == "PLAYER_LOGIN" then boot = f end end,
    CreateTexture = function() return Texture() end,
    CreateMaskTexture = function() return Texture() end,
    GetFrameLevel = function() return 1 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
}
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }

local Minimap = setmetatable({}, frameMeta)
function Minimap.GetWidth() return WIDTH end
function Minimap.GetLeft() return LEFT end
function Minimap.GetBottom() return BOTTOM end
function Minimap.GetEffectiveScale() return 1 end
function Minimap.IsVisible() return true end
function Minimap.IsMouseOver() return mouseOver end
function Minimap.SetUsingSoftCursor(_, on) softCursor = on end
function Minimap.UpdateMouseoverAtPoint(_, x, y)
    probes = probes + 1
    if not softCursor then probesWithoutCursor = probesWithoutCursor + 1 end
    cursorX, cursorY = x - LEFT, y - BOTTOM
end

for _, dot in ipairs(DOTS) do
    dot.east, dot.north = (dot.x - WIDTH / 2) / SCALE, (dot.y - WIDTH / 2) / SCALE
end

local function DotScreen(dot)
    local east = dot.east - (player.x - 0.5) * MAP_YARDS
    local north = dot.north + (player.y - 0.5) * MAP_YARDS
    local turn = rotate == "1" and -facing or 0
    local c, s = math.cos(turn), math.sin(turn)
    return WIDTH / 2 + (east * c - north * s) * SCALE, WIDTH / 2 + (east * s + north * c) * SCALE
end

local function Mouseover()
    if not softCursor then return nil end
    local names = {}
    for _, dot in ipairs(DOTS) do
        local x, y = DotScreen(dot)
        local dx, dy = cursorX - x, cursorY - y
        if dx * dx + dy * dy <= DOT * DOT then names[#names + 1] = dot.name end
    end
    if #names == 0 then return { lines = {} } end
    return { lines = { { leftText = "|cffffffff" .. table.concat(names, "\n") .. "|r" } } }
end

local function CreateFrame(_, _, parent)
    local f = setmetatable({}, frameMeta)
    if parent == Minimap then holder = f end
    return f
end

local profession = { herb = nil, ore = 50 }
local settings = { enabled = true, nodeIcons = true, nodeIconSize = 12 }
local setHook
local RED, BORDER = { r = 1, g = 0.3, b = 0.3 }, { r = 0, g = 0, b = 0 }
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    Apply = Noop,
    Professions = {
        Settings = { Get = function(k) return settings[k] end, Set = Noop },
        Style = {
            RED_RGB = RED, BORDER_RGB = BORDER, ICON_CROP = 0.08, ICON_CROP_HIGH = 0.92,
            DIFFICULTY_RGB = { [0] = { r = 1, g = 0.5, b = 0.25 }, [1] = { r = 1, g = 1, b = 0 },
                [2] = { r = 0.25, g = 0.75, b = 0.25 }, [3] = { r = 0.55, g = 0.55, b = 0.55 } },
        },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    Minimap = Minimap,
    CreateFrame = CreateFrame,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function() return false end,
    InCombatLockdown = function() return inCombat end,
    GetCVar = function() return rotate end,
    GetPlayerFacing = function() return facing end,
    GetMinimapShape = function() return "ROUND" end,
    GetProfessions = function() return profession.ore and 1 or nil, profession.herb and 2 or nil end,
    GetProfessionInfo = function(index)
        if index == 1 then return "Mining", nil, profession.ore, 300, nil, nil, 186, 0 end
        return "Herbalism", nil, profession.herb, 300, nil, nil, 182, 0
    end,
    C_TooltipInfo = { GetMinimapMouseover = Mouseover },
    C_Map = {
        GetBestMapForUnit = function() return 1429 end,
        GetPlayerMapPosition = function() return { x = player.x, y = player.y } end,
        GetMapWorldSize = function() return MAP_YARDS, MAP_YARDS end,
    },
    C_Minimap = {
        GetViewRadius = function() return VIEW_RADIUS end,
        GetNumTrackingTypes = function() return 1 end,
        GetTrackingInfo = function() return { active = true, spellID = 2580 } end,
    },
    C_Item = { GetItemIconByID = function(id) return "item:" .. id end },
    C_Spell = { GetSpellTexture = function(id) return "spell:" .. id end },
    Enum = { TooltipDataType = { MinimapMouseover = 22 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipHook = fn end },
    hooksecurefunc = function(target, name, fn)
        if target == ns.Professions.Settings and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env

Load({
    "NaowhForever_Professions/Constants.lua",
    "NaowhForever_Professions/Data/GatherNodes.lua",
    "NaowhForever_Professions/NodeScan.lua",
    "NaowhForever_Professions/UI/NodeIcons.lua",
}, env)

local function Rings()
    local list = {}
    for _, t in ipairs(textures) do
        if t.rgb and t.shown then list[#list + 1] = t end
    end
    return list
end

local function RingNear(x, y)
    local half = WIDTH / 2
    for _, ring in ipairs(Rings()) do
        if ring.x and Near(ring.x, x - half, 4) and Near(ring.y, y - half, 4) then return ring end
    end
end

local function Off(dot)
    local x, y = DotScreen(dot)
    local best
    for _, ring in ipairs(Rings()) do
        if ring.x then
            local d = math.sqrt((ring.x + WIDTH / 2 - x) ^ 2 + (ring.y + WIDTH / 2 - y) ^ 2)
            if not best or d < best then best = d end
        end
    end
    return best or math.huge
end

local function AllOnDots()
    for _, dot in ipairs(DOTS) do
        if Off(dot) > ON_DOT then return false end
    end
    return true
end

local function Frames(n, elapsed)
    for _ = 1, n do holder.OnUpdate(holder, elapsed or 0.1) end
end

boot.OnEvent(boot, "PLAYER_LOGIN")
check("logging in starts the scan on the minimap", holder and rawget(holder, "OnUpdate") ~= nil)
check("the minimap tooltip gets the skill line hook", tooltipHook ~= nil)

Frames(20)
check("the grid was probed", probes > 0)
check("every probe ran with the soft cursor on", probesWithoutCursor == 0)
check("the soft cursor is off between frames", softCursor == false)
check("one icon per dot", #Rings() == #DOTS)
check("each icon sits on its dot's middle, not on the grid", AllOnDots())

local tin = RingNear(40, 90)
local copper = RingNear(100, 50)
local bloom = RingNear(70, 105)
check("Tin Vein sits on its dot", tin ~= nil)
check("Copper Vein sits on its dot", copper ~= nil)
check("Peacebloom sits on its dot", bloom ~= nil)
check("Tin Vein (65) is ringed red at Mining 50", tin.rgb[1] == RED.r and tin.rgb[2] == RED.g)
check("Copper Vein (1) has the plain ring", copper.rgb[1] == BORDER.r and copper.rgb[2] == BORDER.g)
check("Peacebloom is red with no Herbalism", bloom.rgb[1] == RED.r)

local arts = {}
for _, t in ipairs(textures) do if t.texture and t.shown then arts[t.texture] = true end end
check("Tin Vein shows Tin Ore's icon", arts["item:2771"])
check("Copper Vein shows Copper Ore's icon", arts["item:2770"])
check("Peacebloom shows its herb's icon", arts["item:2447"])

profession.ore = 70
ns.Professions.NodeScan.ReadSkills()
holder.OnUpdate(holder, 0)
local before = probes
mouseOver = true
Frames(10)
check("no probing while the real mouse is over the minimap", probes == before)

player.x = player.x + 10 / MAP_YARDS
Frames(1, 0.05)
check("ten yards east moves the icons five units left", RingNear(40 - 5, 90) ~= nil and RingNear(100 - 5, 50) ~= nil)
player.y = player.y - 10 / MAP_YARDS
Frames(1, 0.05)
check("then ten yards north moves them five units down", RingNear(35, 90 - 5) ~= nil)
check("and every icon is still on its dot", AllOnDots())

mouseOver = false
inCombat = true
before = probes
Frames(20)
check("no probing in combat", probes == before)
inCombat = false

player.x, player.y = 0.5, 0.5
Frames(20)
check("back in place, a fresh scan puts Tin Vein back", RingNear(40, 90) ~= nil)

rotate, facing = "1", math.pi / 2
Frames(20)
check("a rotating minimap facing west puts Tin Vein a quarter turn round", RingNear(70 + 20, 70 + 30) ~= nil)
check("each icon on its dot", AllOnDots())
mouseOver = true
facing = math.pi
Frames(1, 0.05)
check("turning a quarter left turns the icons a quarter right", RingNear(70 + 30, 70 - 20) ~= nil
    and RingNear(70 - 30, 70 + 20) ~= nil)
check("and keeps each on its dot", AllOnDots())
mouseOver, rotate, facing = false, "0", 0
Frames(20)

local worst = 0
for _ = 1, 60 do
    player.x = player.x + 0.4 / MAP_YARDS
    player.y = player.y + 0.1 / MAP_YARDS
    Frames(1)
    for _, dot in ipairs(DOTS) do worst = math.max(worst, Off(dot)) end
end
check("walking through a dozen rescans, no icon strays from its dot (" .. worst .. ")", worst <= ON_DOT)
player.x, player.y = 0.5, 0.5

local tooltip = { added = {} }
function tooltip.AddLine(self, text, r) self.added[#self.added + 1] = { text = text, r = r } end
tooltip.Show = Noop
profession.ore = 50
ns.Professions.NodeScan.ReadSkills()
tooltipHook(tooltip, { lines = { { leftText = "Tin Vein" } } })
check("hovering Tin Vein says the Mining it needs", tooltip.added[1] and tooltip.added[1].text == "Requires Mining 65")
check("in red, as Mining 50 is too low", tooltip.added[1].r == RED.r)
tooltip.added = {}
tooltipHook(tooltip, { lines = { { leftText = "Copper Vein\nPeacebloom" } } })
check("two nodes under the mouse each name their own need", #tooltip.added == 2
    and tooltip.added[1].text == "Copper Vein: Requires Mining 1"
    and tooltip.added[2].text == "Peacebloom: Requires Herbalism 1")
tooltip.added = {}
tooltipHook(tooltip, { lines = { { leftText = "Kobold Tunneler" } } })
check("a creature on the minimap gets no skill line", #tooltip.added == 0)

settings.nodeIconSize = 6
setHook("nodeIconSize")
Frames(20)
local smallest = math.huge
for _, ring in ipairs(Rings()) do smallest = math.min(smallest, ring.size) end
check("a size saved below the slider's 10 draws at 10", smallest == 10 + 3)
settings.nodeIconSize = 10
setHook("nodeIconSize")
Frames(1)
smallest = math.huge
for _, ring in ipairs(Rings()) do smallest = math.min(smallest, ring.size) end
check("Icon Size 10 draws at 10", smallest == 10 + 3)
settings.nodeIconSize = 22
setHook("nodeIconSize")
Frames(1)
smallest = math.huge
for _, ring in ipairs(Rings()) do smallest = math.min(smallest, ring.size) end
check("and a bigger size is drawn as set", smallest == 22 + 3)

settings.nodeIcons = false
setHook("nodeIcons")
check("turning it off stops the scan", rawget(holder, "OnUpdate") == nil)
check("and hides every icon", #Rings() == 0)
tooltip.added = {}
tooltipHook(tooltip, { lines = { { leftText = "Tin Vein" } } })
check("and the tooltip line", #tooltip.added == 0)

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local nodes = ns.Professions.GatherNodes
for name, node in pairs(nodes) do
    check(name .. " is a herb or vein", node[1] == "herb" or node[1] == "ore")
    check(name .. " needs a skill", type(node[2]) == "number" and node[2] >= 1)
    check(name .. " has an item or none", node[3] == nil or type(node[3]) == "number")
end
local glimmer = Read("NaowhForever_QoL/Glimmer/Data/Nodes.lua")
local listed = 0
for kind, need, name in glimmer:gmatch('{ "(%a+)", (%d+), "([^"]+)" }') do
    if kind == "herb" or kind == "ore" then
        listed = listed + 1
        check(name .. " from Glimmer is in GatherNodes", nodes[name] ~= nil)
        check(name .. " needs the same skill as in Glimmer", nodes[name][2] == tonumber(need)
            and nodes[name][1] == kind)
    end
end
check("Glimmer's herbs and veins were read", listed > 50)

local features = Read("Core/Features.lua")
check("Minimap Node Icons is off by default", features:find("\n%s*nodeIcons = false,") ~= nil)

print(("test-node-icons: %d checks passed"):format(checks))
