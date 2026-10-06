-------------------------------------------------------------------------------
--  UI/EntrancePins.lua -- the dungeon and raid entrances on the world map (Entrances on the
--  World Map): the Journal's door icon on each entrance it knows (Data/Dungeons, `entrance`),
--  on its zone's map and on every map that holds the spot (the continent, a neighbouring
--  zone). Entrances on one spot (the Scarlet Monastery's wings, Blackrock Spire's halves)
--  share a pin. Only the dungeons the window lists show (the faction switch). Hover a pin for
--  each one's levels; click it for a waypoint. Built like Discovery's book pins; nothing is
--  made or added to the map until it is switched on.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local J = ns.Journal
local S = J.Settings

local TEMPLATE = "NaowhForeverEntrancePinTemplate"
local PIN_SIZE = 22
local ICON = "dungeon"   -- the door the dungeon map draws on its own entrance
local RAID_ICON = "raid"

local provider, added, events

local function On()
    return S.Get("enabled") and S.Get("mapEntrances")
end

-- Where the entrance sits on the map shown, 0-1, or nil when that map does not hold it. Asked
-- of the game once per entrance and map, since it is the same every time.
local spots = {}
local function SpotOn(mapID, entrance)
    local known = spots[mapID]
    if not known then
        known = {}
        spots[mapID] = known
    end
    local spot = known[entrance]
    if spot == nil then
        spot = false
        local x, y = entrance.x / 100, entrance.y / 100
        if entrance.map == mapID then
            spot = { x, y }
        else
            local continent, world = C_Map.GetWorldPosFromMapPos(entrance.map, CreateVector2D(x, y))
            local pos = continent and world and select(2, C_Map.GetMapPosFromWorldPos(continent, world, mapID))
            if pos then
                local px, py = pos:GetXY()
                if px >= 0 and px <= 1 and py >= 0 and py <= 1 then spot = { px, py } end
            end
        end
        known[entrance] = spot
    end
    return spot or nil
end

-------------------------------------------------------------------------------
--  Pins
-------------------------------------------------------------------------------
local function MakePinMixin()
    -- A global so the XML template can name it.
    NaowhForeverEntrancePinMixin = CreateFromMixins(MapCanvasPinMixin)
    local Pin = NaowhForeverEntrancePinMixin

    function Pin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    end

    -- The map calls this on every acquired pin, and its SetPassThroughButtons is protected:
    -- from our refresh it is blocked in combat. These pins want their clicks.
    function Pin:CheckMouseButtonPassthrough() end

    -- group: { x, y, dungeons } the dungeons whose entrance is on this spot.
    function Pin:OnAcquired(group)
        self.group = group
        self:SetSize(PIN_SIZE, PIN_SIZE)
        local raid = true
        for _, dungeon in ipairs(group.dungeons) do
            if not dungeon.raid then raid = false end
        end
        -- The raid door where the client has it, else the dungeon's.
        if not (raid and self.Icon:SetAtlas(RAID_ICON)) then self.Icon:SetAtlas(ICON) end
        self:SetPosition(group.x, group.y)
    end

    function Pin:OnMouseEnter()
        local dungeons = self.group.dungeons
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(#dungeons == 1 and dungeons[1].name or dungeons[1].zone or "Entrance", 1, 1, 1)
        for _, dungeon in ipairs(dungeons) do
            local levels = J.ColoredLevelRange(dungeon)
            local kind = dungeon.raid and ("Raid, %d players"):format(dungeon.raid) or "Dungeon"
            local right = levels and (kind .. ", " .. levels) or kind
            if #dungeons == 1 then
                GameTooltip:AddLine(right, 0.61, 0.64, 0.69)
            else
                GameTooltip:AddDoubleLine(dungeon.name, right, 1, 0.82, 0, 0.61, 0.64, 0.69)
            end
        end
        local c = ns.ThemeTint("accentSoft", nil)
        GameTooltip:AddLine("Click for a waypoint.", c and c.r or 0.3, c and c.g or 0.71, c and c.b or 0.96)
        GameTooltip:Show()
    end

    function Pin:OnMouseLeave()
        GameTooltip:Hide()
    end

    function Pin:OnClick(button)
        if button ~= "LeftButton" then return end
        local dungeons = self.group.dungeons
        local entrance = dungeons[1].entrance
        local name = #dungeons == 1 and dungeons[1].name or dungeons[1].zone or dungeons[1].name
        ns.PlaceWaypoint(name, entrance.map, entrance.x, entrance.y, " (entrance)")
    end
end

-------------------------------------------------------------------------------
--  The map's data provider
-------------------------------------------------------------------------------
local function MakeProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end

    function provider:RefreshAllData()
        self:RemoveAllData()
        if not On() then return end
        local map = self:GetMap()
        local mapID = map:GetMapID()
        if not mapID then return end
        -- One pin per spot: the dungeons on it in level order (J.Dungeons is).
        local groups, bySpot = {}, {}
        for _, dungeon in ipairs(J.Dungeons()) do
            local entrance = dungeon.entrance
            local spot = entrance and J.FactionShown(dungeon) and SpotOn(mapID, entrance)
            if spot then
                local key = entrance.map .. ":" .. entrance.x .. ":" .. entrance.y
                local group = bySpot[key]
                if not group then
                    group = { x = spot[1], y = spot[2], dungeons = {} }
                    bySpot[key] = group
                    groups[#groups + 1] = group
                end
                group.dungeons[#group.dungeons + 1] = dungeon
            end
        end
        for _, group in ipairs(groups) do map:AcquirePin(TEMPLATE, group) end
    end
end

-------------------------------------------------------------------------------
--  Wiring
-------------------------------------------------------------------------------
local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

-- Pins acquired in combat taint the map (its SetPassThroughButtons is protected), so a redraw
-- asked for then waits for combat to end.
local function Event(_, event)
    if event == "PLAYER_REGEN_ENABLED" then events:UnregisterEvent(event) end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Redraw()
end

local waitingForMap = false

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        Redraw()   -- takes the pins away
        return
    end
    -- The map may load after this file does.
    if not WorldMapFrame then
        if not waitingForMap then
            waitingForMap = true
            EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Apply)
        end
        return
    end
    if not provider then
        MakePinMixin()
        MakeProvider()
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", Event)
    end
    if not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        Redraw()
    end
end

-- The faction switch changes which dungeons the window lists, and so which pins show.
S.OnChange(function(key)
    if key == "enabled" or key == "mapEntrances" or key == "showAlliance" or key == "showHorde" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
