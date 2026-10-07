-------------------------------------------------------------------------------
--  NaowhForever_CompletoRareMap.lua -- rares on the world map: the game's rare star at each
--  spot a rare you have not killed spawns, and with Show Killed Rares a grey one for those you
--  have. A rare that patrols has a star on its way. Hover a star for the rare: its other
--  stars stand out, every other rare's fade, and for one that patrols a trail of small stars
--  shows along its way until you move off it. Click a star for a waypoint. Built like the quest giver pins
--  (NaowhForever_CompletoMap.lua).
--
--  Off until Rare Pins is switched on: then a data provider on the world map, redrawn when a
--  rare is killed or ticked off while the map is open.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local S = ns.CompletoSettings
local R = ns.Completo.Rares

local TEMPLATE = "NaowhForeverRarePinTemplate"
-- The game's rare star; the skull raid mark where the client has no such atlas.
local STAR_ATLAS = "VignetteKill"
local SKULL_FILE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local KILLED_ALPHA = 0.7
local DOT_SCALE, DOT_ALPHA = 0.45, 0.6     -- a trail's dot against a star
local LIT_SCALE = 1.3                      -- the hovered rare's stars
local FADED_ALPHA = 0.2                    -- every other rare's, while one is hovered

local function On()
    return S.Get("enabled") and S.Get("rarePins")
end

local function SoftBlue(r, g, b)
    local c = ns.ThemeTint("accentSoft", nil)
    if c then return c.r, c.g, c.b end
    return r, g, b
end

-------------------------------------------------------------------------------
--  Pins
-------------------------------------------------------------------------------
-- A global so the XML template can name it.
NaowhForeverRarePinMixin = CreateFromMixins(MapCanvasPinMixin)

function NaowhForeverRarePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

-- The map calls this on every acquired pin, and its SetPassThroughButtons is protected: from
-- our refresh it is blocked in combat. These pins want their clicks, so there is nothing to
-- pass through.
function NaowhForeverRarePinMixin:CheckMouseButtonPassthrough() end

-- Not smaller on the small map than on the full-screen one.
NaowhForeverRarePinMixin.ApplyCurrentScale = ns.Completo.ScalePin

-- How it looks: as drawn, or while a rare is hovered (lit: this pin's rare; else faded).
local function Look(pin, lit, faded)
    local size = S.Get("rarePinSize") * (pin.dot and DOT_SCALE or 1)
    if lit and not pin.dot then size = size * LIT_SCALE end
    pin:SetSize(size, size)
    local alpha = pin.dot and DOT_ALPHA or 1
    if pin.killed then alpha = alpha * KILLED_ALPHA end
    if lit then alpha = 1 elseif faded then alpha = FADED_ALPHA end
    pin.Icon:SetAlpha(alpha)
end

-- spot: { npc, x, y (percent), dot = true for a trail's dot }.
function NaowhForeverRarePinMixin:OnAcquired(spot)
    self.npc, self.spotX, self.spotY, self.dot = spot.npc, spot.x, spot.y, spot.dot
    self.killed = R.Killed(spot.npc)
    -- A star a level above the dots, so a trail never covers one.
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI", spot.dot and 0 or 1)
    -- A dot takes no mouse: the pointer stays on the star it belongs to.
    self:EnableMouse(not spot.dot)
    local icon = self.Icon
    if not icon:SetAtlas(STAR_ATLAS) then icon:SetTexture(SKULL_FILE) end
    icon:SetDesaturated(self.killed)
    Look(self)
    self:SetPosition(spot.x / 100, spot.y / 100)
    if self.ApplyCurrentScale then self:ApplyCurrentScale() end
end

local provider
local trail = {}    -- the dots of the way shown, while its star is hovered
local spot = {}     -- handed to each pin; OnAcquired copies what it needs

local function Place(map, npc, points, dot, into)
    for i = 1, points and #points or 0, 2 do
        spot.npc, spot.x, spot.y, spot.dot = npc, points[i], points[i + 1], dot
        local pin = map:AcquirePin(TEMPLATE, spot)
        if into then into[#into + 1] = pin end
    end
end

-- A patrolling rare's way, shown while its star is hovered; nil takes the one shown away.
local function ShowTrail(npc)
    local map = provider and provider:GetMap()
    if not map then return end
    for i = #trail, 1, -1 do
        map:RemovePin(trail[i])
        trail[i] = nil
    end
    if npc then Place(map, npc, R.Trail(npc), true, trail) end
end

-- npc: the rare hovered, its pins lit and the rest faded; nil puts every pin back.
local function Highlight(npc)
    local map = provider and provider:GetMap()
    if not map then return end
    for pin in map:EnumeratePinsByTemplate(TEMPLATE) do
        Look(pin, npc ~= nil and pin.npc == npc, npc ~= nil and pin.npc ~= npc)
    end
end

function NaowhForeverRarePinMixin:OnMouseEnter()
    local npc = self.npc
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(R.Name(npc), 1, 1, 1)
    local low, high = R.Levels(npc)
    local level = low <= 0 and "??" or low == high and tostring(low) or ("%d-%d"):format(low, high)
    GameTooltip:AddLine(("%s, level %s"):format(R.Elite(npc) and "Rare elite" or "Rare", level), 1, 0.82, 0)
    local record = R.Record(npc)
    if record then
        GameTooltip:AddLine(record.n > 1 and ("Killed %d times"):format(record.n) or "Killed", 0.62, 0.62, 0.62)
    else
        GameTooltip:AddLine("Not killed yet", 1, 1, 1)
    end
    if R.Trail(npc) then
        GameTooltip:AddLine("Patrols: the small stars are its way", 0.62, 0.62, 0.62)
    elseif R.SpotCount(npc) > 1 then
        GameTooltip:AddLine(("One of %d spots it spawns at"):format(R.SpotCount(npc)), 0.62, 0.62, 0.62)
    end
    GameTooltip:AddLine("Click for a waypoint.", SoftBlue(0.3, 0.71, 0.96))
    GameTooltip:Show()
    if R.Trail(npc) then ShowTrail(npc) end
    Highlight(npc)
end

function NaowhForeverRarePinMixin:OnMouseLeave()
    GameTooltip:Hide()
    ShowTrail(nil)
    Highlight(nil)
end

function NaowhForeverRarePinMixin:OnClick(button)
    if button ~= "LeftButton" then return end
    ns.PlaceWaypoint(R.Name(self.npc), R.Map(self.npc), self.spotX, self.spotY)
end

-------------------------------------------------------------------------------
--  The map's data provider
-------------------------------------------------------------------------------
provider = CreateFromMixins(MapCanvasDataProviderMixin)

function provider:RemoveAllData()
    wipe(trail)
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    local killedToo = S.Get("rarePinsKilled")
    for _, npc in ipairs(R.OnMap(map:GetMapID())) do
        if killedToo or not R.Killed(npc) then Place(map, npc, R.Spots(npc), false) end
    end
end

-------------------------------------------------------------------------------
--  Wiring
-------------------------------------------------------------------------------
local added

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function Apply()
    if On() and not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    Redraw()
end

-- A rare killed or ticked off: its star goes, or turns grey.
R.OnChange(function()
    if On() then Redraw() end
end)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "rarePins" or key == "rarePinsKilled" or key == "rarePinSize" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local OFF = "Turn on Completo"
local function Enabled() return S.Get("enabled") == true end

Settings.Page("Completo/Rares", S):Card({
    id = "rarePins", name = "Map Pins", order = 30, switch = "rarePins",
    help = "A star on the world map at every spot a rare you have not killed spawns. Hover one to pick its "
        .. "rare out, with small stars along its way for one that patrols; click it for a waypoint.",
    summary = function(store)
        return store.Get("rarePinsKilled") and "Every rare, the ones you killed in grey"
            or "The rares you have not killed"
    end,
    rows = {
        { key = "rarePinsKilled", label = "Show Killed Rares", toggle = true, needs = Enabled, why = OFF,
          help = "Also a grey star on the map for the rares you have killed." },
        { key = "rarePinSize", label = "Pin Size", slider = { 12, 32, 1 }, needs = Enabled, why = OFF,
          help = "How big the stars are on the map." },
    },
})
