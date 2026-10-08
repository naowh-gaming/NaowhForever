-- Run with Lua 5.1 from the repository root: the Map Pins panel on the world map. Every town
-- pin switch the options card used to hold is on the panel, the card keeps only its switch and
-- Pin Size, and the button is made only once the map pins are on.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local panelSrc = Read("QoL/NaowhForever_MapPinsPanel.lua")
local townSrc = Read("QoL/NaowhForever_TownMap.lua")
for _, key in ipairs({ "townCapitalsOnly", "townMinimap", "townSpiritHealers", "townZoneLinks", "townTravel",
    "townClass", "townProfession", "townFlight", "townInn", "townBank", "townRepair", "townSupplies",
    "townStable", "townVendors", "townMail" }) do
    Check(panelSrc:find('key = "' .. key .. '"', 1, true), "on the panel: " .. key)
    Check(not townSrc:find('key = "' .. key .. '"', 1, true), "not on the options card: " .. key)
end
Check(townSrc:find('key = "townPinSize"', 1, true), "the card keeps Pin Size")
Check(Read("QoL/NaowhForever_TownMap.xml"):find('<Script file="NaowhForever_MapPinsPanel.lua"/>', 1, true),
    "the panel loads")

local settings = { enabled = true, townMap = false }
local S = { Get = function(key) return settings[key] end, Set = function(key, v) settings[key] = v end }
local ns = { QoLSettings = S, Apply = function() end, THEME = { bg = {}, line = {}, accent = {} }, UI = {} }
local made, boot = 0, nil
local function NewFrame()
    local f = { events = {}, scripts = {}, shown = true }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetFrameStrata() end
    function f:CreateTexture() return { SetTexture = function() end, SetPoint = function() end } end
    function f:ClearAllPoints() end
    function f:SetSize() end
    function f:SetPoint() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    return f
end
ns.Solid = function() return { SetAllPoints = function() end } end
ns.Border = function() return { SetColor = function() end } end
ns.Tooltip = function() end
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFrame = function(kind)
        local f = NewFrame()
        if kind == "Button" then made = made + 1 else boot = boot or f end
        return f
    end,
    hooksecurefunc = function(t, name, fn)
        local old = t[name]
        t[name] = function(...) old(...); fn(...) end
    end,
    WorldMapFrame = { GetCanvasContainer = function() return {} end,
        SidePanelToggle = { GetSize = function() return 32, 32 end } },
}, { __index = _G })
local chunk = assert(loadstring(Read("QoL/NaowhForever_MapPinsPanel.lua")))
setfenv(chunk, env)
chunk()
boot.scripts.OnEvent(boot)
Check(made == 0, "nothing made while the map pins are off")
S.Set("townMap", true)
Check(made == 1, "the button comes with the map pins")
S.Set("townFlight", true)
Check(made == 1, "and is made once")

print(("test-map-pins-panel: %d checks passed"):format(checks))
