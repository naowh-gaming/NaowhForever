-- Run with Lua 5.1 from the repository root: the Map Pins panel on the world map. Every town
-- pin switch is on the panel and on the options card, both drawn from one list, with Pin Size
-- on the card. Other modules' pin rows (ns.Shared.MapPins) follow on both, in their own store,
-- and the button is made once the town pins are on or a module adds pins.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local panelSrc = Read("NaowhForever_QoL/Interface/MapPinsPanel.lua")
local townSrc = Read("NaowhForever_QoL/Interface/TownMap.lua")
for _, key in ipairs({ "townCapitalsOnly", "townMinimap", "townMinimapSpirit", "townSpiritHealers", "townZoneLinks", "townTravel",
    "townClass", "townProfession", "townFlight", "townInn", "townBank", "townRepair", "townSupplies",
    "townStable", "townVendors", "townMail" }) do
    Check(townSrc:find('key = "' .. key .. '"', 1, true), "in the pin list: " .. key)
    Check(not panelSrc:find('key = "' .. key .. '"', 1, true), "not copied into the panel: " .. key)
end
Check(panelSrc:find("local ROWS = ns.TownPinRows", 1, true), "the panel reads the town map's list")
Check(townSrc:find('key = "townPinSize"', 1, true), "the card keeps Pin Size")
local pinRows = assert(loadstring("return " .. townSrc:match("local PIN_ROWS = (%b{})")))()

local questStore = { values = { mapPins = false } }
function questStore.Get(key) return questStore.values[key] end
function questStore.Set(key, v) questStore.values[key] = v end
local questSection = { title = "Quests", rows = {
    { key = "mapPins", label = "Quest Givers", toggle = true, store = questStore, always = true },
    { key = "mapPinSize", label = "Quest Pin Size", slider = { 12, 32, 1 }, store = questStore, always = true },
} }

do
    local card
    local function Group(title) return { group = title } end
    local cardNs = { QoLConstants = dofile("Tools/regression/qol_constants.lua"), QoLSettings = {},
        Apply = function() end, ThemeTint = function() end, TownCapitals = {}, TownNPCs = {},
        Shared = { MapPins = { questSection }, ScalePin = function() end,
            Settings = { Group = Group, Page = function() return { Card = function(_, c) card = c end } end } } }
    local cardEnv = setmetatable({ _G = { NaowhForever = cardNs },
        CreateFromMixins = function() return {} end, MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
        hooksecurefunc = function() end,
        CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end,
    }, { __index = _G })
    local chunk = assert(loadstring(townSrc))
    setfenv(chunk, cardEnv)
    chunk()
    local labels, groups = {}, {}
    local rows = card.rows()
    for _, row in ipairs(rows) do
        if row.group then groups[#groups + 1] = row.group elseif row.toggle then labels[row.key] = row.label end
    end
    for _, row in ipairs(pinRows) do
        if row.key then Check(labels[row.key] == row.text, "the card has the panel's toggle: " .. row.key) end
    end
    Check(groups[1] == "Options" and groups[2] == "Show", "grouped as the drawer groups them")
    Check(rows[1].key == "townPinSize", "Pin Size first")
    Check(groups[3] == "Quests" and rows[#rows - 1] == questSection.rows[1] and rows[#rows] == questSection.rows[2],
        "a module's pin rows follow the town rows under its own title, as it declared them")
    Check(cardNs.TownPinRows ~= nil, "the list is shared with the panel")
    local Search = dofile("Tools/regression/settings_search.lua")({ ["QoL/Interface"] = { card } })
    local hit = Search("flight master")[1]
    Check(hit and hit.label == "Flight Masters" and hit.card == "QoL/Interface:townMap",
        "the options search finds a pin by name")
    hit = Search("graveyard")[1]
    Check(hit and hit.card == "QoL/Interface:townMap", "and the card by its search words")
    hit = Search("quest givers")[1]
    Check(hit and hit.label == "Quest Givers" and hit.card == "QoL/Interface:townMap",
        "and a module's pin row on it")
end
Check(Read("NaowhForever_QoL/Interface/TownMap.xml"):find('<Script file="MapPinsPanel.lua"/>', 1, true),
    "the panel loads")

local settings = { enabled = true, townMap = false }
local S = { Get = function(key) return settings[key] end, Set = function(key, v) settings[key] = v end }
local ns = { QoLSettings = S, TownPinRows = pinRows, Apply = function() end, THEME = { bg = {}, line = {}, accent = {}, accentSoft = {}, panel = {}, fg = {} }, UI = {} }
local made, boot, button, panel = 0, nil, nil, nil
local mapLeft, maximized, mapHeight = 500, false, 700
local canvasLeft = 350
local canvas = { GetLeft = function() return canvasLeft end }
-- One of the map's own buttons in its top right corner, x from the corner.
local function MapButton(x)
    return { IsShown = function() return true end, GetNumPoints = function() return 1 end,
        GetPoint = function() return "TOPRIGHT", canvas, "TOPRIGHT", x end, GetSize = function() return 30, 30 end }
end
local function NewFrame()
    local f = { events = {}, scripts = {}, shown = true }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetFrameStrata() end
    function f:CreateTexture() return { SetTexture = function() end, SetPoint = function() end } end
    function f:ClearAllPoints() end
    function f:SetSize() end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:SetFrameLevel() end
    function f:GetFrameLevel() return 1 end
    function f:EnableMouse() end
    function f:IsShown() return self.shown end
    function f:SetShown(on) self.shown = on end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    return f
end
ns.Solid = function() return { SetAllPoints = function() end, SetPoint = function() end } end
ns.Hairline = function() end
ns.Shared = { MapPins = {}, Style = { BACKDROP_ALPHA = 0.97, BORDER_RGB = {}, LOGO_SMALL = "LogoSmall" } }
ns.Border = function() return { SetColor = function() end } end
ns.Tooltip = function() end
local function Text() return { SetPoint = function() end, SetText = function() end, SetJustifyH = function() end,
    SetWordWrap = function() end } end
ns.Font = Text
ns.Button = function() return { SetPoint = function() end } end
local toggles = {}
ns.UI.BuildToggleControl = function(_, _, get, set)
    toggles[#toggles + 1] = { get = get, set = set }
    return { SetPoint = function() end, _refreshValue = function() end }
end
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFrame = function(kind)
        local f = NewFrame()
        if kind == "Button" then made, button = made + 1, f
        elseif boot then panel = panel or f
        else boot = f end
        return f
    end,
    hooksecurefunc = function(t, name, fn)
        local old = t[name]
        t[name] = function(...) old(...); fn(...) end
    end,
    WorldMapFrame = { GetCanvasContainer = function() return canvas end, HookScript = function() end,
        GetFrameLevel = function() return 1 end, GetLeft = function() return mapLeft end,
        GetHeight = function() return mapHeight end, IsMaximized = function() return maximized end,
        Maximize = function() end, Minimize = function() end,
        overlayFrames = { MapButton(-4), MapButton(-36), { IsShown = function() return true end,
            GetNumPoints = function() return 1 end, GetPoint = function() return "BOTTOMLEFT", canvas, "BOTTOMLEFT", 0 end } } },
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/MapPinsPanel.lua")))
setfenv(chunk, env)
chunk()
boot.scripts.OnEvent(boot)
Check(made == 0, "nothing made while the town pins are off and no module adds pins")
ns.Shared.MapPins[1] = questSection
ns.Apply()
Check(made == 1, "a module's pins bring the button, town pins off")
S.Set("townMap", true)
Check(button.point[1] == "TOPRIGHT" and button.point[3] == "TOPLEFT" and button.point[2].GetPoint
    and select(4, button.point[2].GetPoint()) == -36, "top right, left of the map's own buttons there")
S.Set("townFlight", true)
Check(made == 1, "and is made once")

-- The drawer beside the map window.
local map = env.WorldMapFrame
button.scripts.OnClick()
Check(panel and panel.shown, "the button opens the drawer")
local towns = 0
for _, row in ipairs(pinRows) do if row.key then towns = towns + 1 end end
Check(#toggles == 1 + towns + 1, "a Town Pins switch, every town row, and the module's switches only")
toggles[1].set(false)
Check(settings.townMap == false, "Town Pins is the town map's own switch")
toggles[1].set(true)
toggles[#toggles].set(true)
Check(questStore.values.mapPins == true and settings.mapPins == nil and toggles[#toggles].get(),
    "a module's switch reads and writes its own store")
Check(panel.point[1] == "TOPRIGHT" and panel.point[2] == map and panel.point[3] == "TOPLEFT",
    "against the map window's left side")
Check(panel.height == 700, "the map's height")
button.scripts.OnClick()
Check(not panel.shown, "and closes it")
mapHeight = 500
button.scripts.OnClick()
Check(panel.height == 500, "a small map: the rows shrink so the drawer keeps the map's height")
button.scripts.OnClick()
mapHeight = 300
button.scripts.OnClick()
Check(panel.height > 300, "too small for every row: the drawer runs past the map's foot rather than lose one")
button.scripts.OnClick()
mapHeight = 700
mapLeft = 100
button.scripts.OnClick()
Check(panel.point[2] == map and panel.point[3] == "TOPRIGHT", "no room on the left: the right side")
maximized = true
map.Maximize()
Check(panel.point[1] == "TOPRIGHT" and panel.point[2] == canvas and panel.point[3] == "TOPLEFT"
    and panel.width == 234, "the maximized map: in the black bar left of the picture, as wide as it")
canvasLeft = 250
map.Maximize()
Check(panel.point[1] == "TOPRIGHT" and panel.point[2] == button and panel.point[3] == "BOTTOMRIGHT",
    "no bar wide enough: under the button in the top right")

print(("test-map-pins-panel: %d checks passed"):format(checks))
