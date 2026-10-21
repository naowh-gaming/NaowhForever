-- NodeIcons.lua: Minimap Node Icons: each herb and vein the minimap tracks shows its item, ringed red when your skill is too low, and its tooltip the skill it needs.
local ns = _G.NaowhForever

local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetPlayerMapPosition = C_Map.GetPlayerMapPosition
local GetItemIconByID = C_Item.GetItemIconByID
local cos, sin, abs = math.cos, math.sin, math.abs

local P = ns.Professions
local S = P.Settings
local Style = P.Style
local Scan = P.NodeScan
local C = P.C

local FIND_SPELL = { herb = 2383, ore = 2580 }
local SCAN_WAIT = 0.5
local IDLE_WAIT = 2
local FOLLOW_WAIT = 0.03
local MAX_ICONS = 40
local MATCH_UNITS = 12
local REFINES_PER_FRAME = 2
local REFINE_EVERY = 4
local RING_WIDTH = 1.5
local LEVEL_UP = 5
local SKILL_ORANGE, SKILL_YELLOW, SKILL_GREEN = 25, 50, 100
local TIER_ORANGE, TIER_YELLOW, TIER_GREEN, TIER_GREY = 0, 1, 2, 3
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local SQUARE_SHAPE = "SQUARE"
local ROTATE_CVAR = "rotateMinimap"
local ROTATE_ON = "1"
local CROP_LOW, CROP_HIGH = Style.ICON_CROP, Style.ICON_CROP_HIGH
local EVENTS = { "MINIMAP_UPDATE_TRACKING", "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA" }
local TEXT_REQUIRES = ns.L("Requires %s %d")
local TEXT_NAMED = "%s: %s"
local TEXT_PROFESSION = { herb = ns.L("Herbalism"), ore = ns.L("Mining") }

local holder, events, hooked
local tracking, scanning = false, false
local wait, followWait = 0, 0
local anchorMap, anchorFacing, anchorScale = nil, 0, 1
local anchorEast, anchorNorth = 0, 0
local icons, nodes, pending = {}, {}, {}
local shown = 0
local sizes = {}
local found, said = {}, {}

local function On()
    return S.Get("enabled") and S.Get("nodeIcons") and true or false
end

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Tracking()
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and info.active and (info.spellID == FIND_SPELL.herb or info.spellID == FIND_SPELL.ore) then
            return true
        end
    end
    return false
end

local function MapSize(mapID)
    local size = sizes[mapID]
    if size ~= nil then return size end
    size = false
    if C_Map.GetMapWorldSize then
        local width, height = C_Map.GetMapWorldSize(mapID)
        if width and width > 0 and height and height > 0 then size = { width, height } end
    end
    if not size and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local _, low = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
        local _, high = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
        if low and high then size = { abs(high.y - low.y), abs(high.x - low.x) } end
    end
    sizes[mapID] = size
    return size
end

local function PlayerYards()
    local mapID = GetBestMapForUnit("player")
    local size = mapID and MapSize(mapID)
    local pos = size and GetPlayerMapPosition(mapID, "player")
    if not pos then return nil, 0, 0 end
    return mapID, pos.x * size[1], -pos.y * size[2]
end

local function Facing()
    if GetCVar(ROTATE_CVAR) ~= ROTATE_ON then return 0 end
    return GetPlayerFacing() or 0
end

local function UnitsPerYard()
    local radius = C_Minimap.GetViewRadius()
    if not radius or radius <= 0 then return nil end
    return Minimap:GetWidth() / 2 / radius
end

local function Square()
    return GetMinimapShape ~= nil and GetMinimapShape() == SQUARE_SHAPE
end

local function IconSize()
    return math.max(S.Get("nodeIconSize"), C.NODE_ICON_MIN)
end

local function Unsnap(texture)
    if not texture.SetSnapToPixelGrid then return end
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
end

local function NewIcon()
    local icon = {}
    icon.ring = holder:CreateTexture(nil, "ARTWORK")
    icon.ring:SetTexture(ROUND)
    icon.art = holder:CreateTexture(nil, "OVERLAY")
    icon.art:SetPoint("CENTER", icon.ring)
    icon.art:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    icon.mask = holder:CreateMaskTexture()
    icon.mask:SetTexture(ROUND, MASK_WRAP, MASK_WRAP)
    icon.mask:SetAllPoints(icon.art)
    icon.art:AddMaskTexture(icon.mask)
    Unsnap(icon.ring)
    Unsnap(icon.art)
    return icon
end

local function Paint(icon, node)
    local size = IconSize()
    icon.ring:SetSize(size + 2 * RING_WIDTH, size + 2 * RING_WIDTH)
    icon.art:SetSize(size, size)
    local item = Scan.Item(node)
    icon.art:SetTexture(item and GetItemIconByID(item) or C_Spell.GetSpellTexture(FIND_SPELL[Scan.Kind(node)]))
    local c = Scan.TooHard(node) and Style.RED_RGB or Style.BORDER_RGB
    icon.ring:SetVertexColor(c.r, c.g, c.b)
end

local function HideIcon(icon)
    icon.ring:Hide()
    icon.art:Hide()
end

local function Clear()
    for i = 1, shown do nodes[i].live = false end
    shown = 0
    wipe(pending)
    for _, icon in ipairs(icons) do HideIcon(icon) end
end

local function Repaint()
    for i = 1, shown do Paint(icons[i], nodes[i].node) end
end

local function ToMinimap(spot, east, north, c, s, scale)
    local dx, dy = spot.east - east, spot.north - north
    return (dx * c - dy * s) * scale, (dx * s + dy * c) * scale
end

local function ToWorld(x, y, east, north, facing, scale)
    local c, s = cos(facing), sin(facing)
    x, y = x / scale, y / scale
    return east + x * c - y * s, north + x * s + y * c
end

local function Follow()
    local mapID, east, north = PlayerYards()
    if mapID ~= anchorMap then
        Clear()
        wait = 0
        return
    end
    local scale = UnitsPerYard()
    if not scale then return end
    local turn = -Facing()
    local c, s = cos(turn), sin(turn)
    local edge = (Minimap:GetWidth() - IconSize()) / 2
    local square = Square()
    for i = 1, shown do
        local icon = icons[i]
        local x, y = ToMinimap(nodes[i], east, north, c, s, scale)
        local inside = square and (abs(x) <= edge and abs(y) <= edge) or (x * x + y * y <= edge * edge)
        icon.ring:SetPoint("CENTER", holder, "CENTER", x, y)
        icon.ring:SetShown(inside)
        icon.art:SetShown(inside)
    end
end

local function Ready()
    return tracking and Minimap:IsVisible() and Minimap:GetLeft() ~= nil and not InCombatLockdown()
        and not Minimap:IsMouseOver()
end

local function StartScan()
    wait = SCAN_WAIT
    if not tracking then
        Clear()
        wait = IDLE_WAIT
        return
    end
    if not Ready() then return end
    anchorScale = UnitsPerYard()
    if not anchorScale then return end
    anchorMap, anchorEast, anchorNorth = PlayerYards()
    anchorFacing = Facing()
    Scan.Start(Minimap:GetWidth(), Square())
    scanning = true
end

local function Match(name, east, north, reach)
    local best, bestDistance
    for i = 1, shown do
        local spot = nodes[i]
        if not spot.seen and spot.name == name then
            local dx, dy = spot.east - east, spot.north - north
            local distance = dx * dx + dy * dy
            if distance <= reach * reach and (not best or distance < bestDistance) then
                best, bestDistance = spot, distance
            end
        end
    end
    return best
end

local function Seen(spot, east, north)
    spot.seen = true
    spot.scans = spot.scans + 1
    if not spot.refined then
        spot.east, spot.north = east, north
    elseif spot.scans >= REFINE_EVERY then
        spot.scans = 0
        pending[#pending + 1] = spot
    end
end

local function Track(name, east, north)
    shown = shown + 1
    local spot = nodes[shown]
    if not spot then
        spot = {}
        nodes[shown] = spot
    end
    spot.name, spot.node = name, Scan.Node(name)
    spot.east, spot.north = east, north
    spot.seen, spot.live, spot.refined, spot.scans = true, true, false, 0
    pending[#pending + 1] = spot
    icons[shown] = icons[shown] or NewIcon()
end

local function DropUnseen()
    local kept = 0
    for i = 1, shown do
        local spot = nodes[i]
        if spot.seen then
            kept = kept + 1
            nodes[i], nodes[kept] = nodes[kept], spot
        else
            spot.live = false
        end
    end
    shown = kept
end

local function FinishScan()
    scanning = false
    if not anchorMap then Clear() end
    local places, count = Scan.Places()
    local half = Minimap:GetWidth() / 2
    local reach = MATCH_UNITS / anchorScale
    for i = 1, shown do nodes[i].seen = false end
    for i = 1, count do
        local place = places[i]
        local east, north = ToWorld(place.x - half, place.y - half, anchorEast, anchorNorth, anchorFacing,
            anchorScale)
        local spot = Match(place.name, east, north, reach)
        if spot then
            Seen(spot, east, north)
        elseif shown < MAX_ICONS then
            Track(place.name, east, north)
        end
    end
    DropUnseen()
    for i = 1, shown do Paint(icons[i], nodes[i].node) end
    for i = shown + 1, #icons do HideIcon(icons[i]) end
    Follow()
end

local function RefineSome()
    local mapID, east, north = PlayerYards()
    local scale = UnitsPerYard()
    if mapID ~= anchorMap or not scale or not Ready() then
        wipe(pending)
        return
    end
    local facing = Facing()
    local c, s = cos(-facing), sin(-facing)
    local half = Minimap:GetWidth() / 2
    local left, bottom, ui = Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetEffectiveScale()
    for _ = 1, REFINES_PER_FRAME do
        local spot = pending[#pending]
        if not spot then return end
        pending[#pending] = nil
        if spot.live then
            local x, y = ToMinimap(spot, east, north, c, s, scale)
            x, y = Scan.Refine(left, bottom, ui, spot.name, x + half, y + half)
            spot.east, spot.north = ToWorld(x - half, y - half, east, north, facing, scale)
            spot.refined = true
        end
    end
end

local function OnUpdate(_, elapsed)
    if scanning then
        if not Ready() then
            scanning = false
        elseif Scan.Step(Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetEffectiveScale()) then
            FinishScan()
        end
    elseif pending[1] then
        RefineSome()
    else
        wait = wait - elapsed
        if wait <= 0 then StartScan() end
    end
    followWait = followWait - elapsed
    if followWait <= 0 and shown > 0 then
        followWait = FOLLOW_WAIT
        Follow()
    end
end

local function Tier(over)
    if over < SKILL_ORANGE then return TIER_ORANGE end
    if over < SKILL_YELLOW then return TIER_YELLOW end
    if over < SKILL_GREEN then return TIER_GREEN end
    return TIER_GREY
end

local function AddNeed(tooltip, name, named)
    local node = Scan.Node(name)
    local kind, need = Scan.Kind(node), Scan.Need(node)
    local over = Scan.Skill(kind) - need
    local c = over < 0 and Style.RED_RGB or Style.DIFFICULTY_RGB[Tier(over)]
    local text = TEXT_REQUIRES:format(TEXT_PROFESSION[kind], need)
    if named then text = TEXT_NAMED:format(name, text) end
    tooltip:AddLine(text, c.r, c.g, c.b)
end

local function OnMinimapTooltip(tooltip, data)
    if not On() or not (data and Plain(data)) then return end
    local lines = data.lines
    if not (lines and Plain(lines)) then return end
    wipe(found)
    wipe(said)
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and Plain(text) then
            for _, name in ipairs(Scan.Known(text)) do
                if not said[name] then
                    said[name] = true
                    found[#found + 1] = name
                end
            end
        end
    end
    if #found == 0 then return end
    for _, name in ipairs(found) do AddNeed(tooltip, name, #found > 1) end
    tooltip:Show()
end

local function OnEvent(_, event)
    if event == "SKILL_LINES_CHANGED" then
        Scan.ReadSkills()
        return Repaint()
    end
    tracking = Tracking()
    if event ~= "MINIMAP_UPDATE_TRACKING" then Scan.ReadSkills() end
    Clear()
    scanning = false
    wait = 0
end

local function Build()
    holder = CreateFrame("Frame", nil, Minimap)
    holder:SetAllPoints()
    holder:SetFrameLevel(Minimap:GetFrameLevel() + LEVEL_UP)
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

local function Hook()
    hooked = true
    local kind = Enum.TooltipDataType and Enum.TooltipDataType.MinimapMouseover
    if kind and TooltipDataProcessor then TooltipDataProcessor.AddTooltipPostCall(kind, OnMinimapTooltip) end
end

local function Apply()
    if not On() or not Scan.Usable() then
        if holder then
            holder:SetScript("OnUpdate", nil)
            holder:Hide()
            events:UnregisterAllEvents()
            Clear()
        end
        scanning = false
        return
    end
    if not holder then Build() end
    if not hooked then Hook() end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Scan.ReadSkills()
    tracking = Tracking()
    scanning, wait = false, 0
    holder:Show()
    holder:SetScript("OnUpdate", OnUpdate)
    Repaint()
end

local function OnSettingChanged(key)
    if key == "enabled" or key:find("^nodeIcon") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
