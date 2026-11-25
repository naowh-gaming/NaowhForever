-- MinimapPins.lua: the Quest List's pins on the minimap: the quest givers and quest objectives the world map shows, near you.
local ns = _G.NaowhForever

local GetBestMapForUnit = C_Map.GetBestMapForUnit

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Objectives = Completo.Objectives
local GiverPin = NaowhForeverQuestGiverPinMixin
local ObjectivePin = NaowhForeverQuestObjectivePinMixin

local PERCENT = Completo.C.PERCENT
local MINIMAP_MAX = 40
local PLAYER = "player"
local MAP_EVENTS = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE", "QUEST_WATCH_LIST_CHANGED", "CALENDAR_UPDATE_EVENT_LIST" }
local LOG_EVENT = "QUEST_LOG_UPDATE"
local PLACE_EVENTS = { ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true }
local WHERE_EVENTS = { ZONE_CHANGED_NEW_AREA = true, ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true,
    PLAYER_ENTERING_WORLD = true, QUEST_WATCH_LIST_CHANGED = true }
local OWN_KEYS = { enabled = true, minimapQuests = true, minimapQuestSize = true, mapPins = true, mapGrey = true,
    mapChainsOnly = true, mapDungeon = true, mapDungeonColor = true, mapObjectives = true, mapObjectivesTracked = true }

local list = Objectives.List()
local givers, giverSpare, here = {}, {}, {}
local giverLayer, objectiveLayer, events, shownMap

local function On()
    return S.Get("enabled") and S.Get("minimapQuests")
end

local function OnLeave()
    GameTooltip:Hide()
end

local function NewPin(mixin)
    local pin = CreateFrame("Button", nil, Minimap)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin.Icon = pin:CreateTexture(nil, "ARTWORK")
    pin.Icon:SetAllPoints()
    pin:SetScript("OnEnter", mixin.OnMouseEnter)
    pin:SetScript("OnLeave", OnLeave)
    pin:SetScript("OnClick", mixin.OnClick)
    pin.Paint = mixin.Paint
    return pin
end

local function NewGiverPin() return NewPin(GiverPin) end
local function NewObjectivePin() return NewPin(ObjectivePin) end

local function Paint(pin, entries, i)
    pin:Paint(entries[i], S.Get("minimapQuestSize"))
end

local function XY(entries, i)
    local entry = entries[i]
    return entry.x / PERCENT, entry.y / PERCENT
end

local function CopyGivers(mapID)
    for i = #givers, 1, -1 do
        giverSpare[#giverSpare + 1] = givers[i]
        givers[i] = nil
    end
    if not S.Get("mapPins") then return end
    Q.Update()
    for _, giver in ipairs(Q.Givers(mapID, S.Get("mapGrey"), S.Get("mapChainsOnly"))) do
        local copy = table.remove(giverSpare) or { quests = {} }
        wipe(copy.quests)
        for i, id in ipairs(giver.quests) do copy.quests[i] = id end
        copy.x, copy.y = giver.x, giver.y
        copy.grey, copy.repeatable, copy.dungeon = giver.grey, giver.repeatable, giver.dungeon
        givers[#givers + 1] = copy
    end
end

local function RefreshObjectives(mapID)
    local spots
    if mapID and S.Get("mapObjectives") then
        here[1] = mapID
        spots = list:ForMaps(here, S.Get("mapObjectivesTracked"))
    end
    objectiveLayer:Set(mapID, spots, spots and #spots or 0)
end

local function Refresh()
    if not On() then
        shownMap = nil
        if giverLayer then giverLayer:Set(nil) end
        if objectiveLayer then objectiveLayer:Set(nil) end
        return
    end
    giverLayer = giverLayer or ns.Shared.Parts.MinimapLayer({ max = MINIMAP_MAX, new = NewGiverPin, paint = Paint,
        xy = XY })
    objectiveLayer = objectiveLayer or ns.Shared.Parts.MinimapLayer({ max = MINIMAP_MAX, new = NewObjectivePin,
        paint = Paint, xy = XY })
    local mapID = GetBestMapForUnit(PLAYER)
    shownMap = mapID
    if mapID then CopyGivers(mapID) end
    giverLayer:Set(mapID, givers, mapID and #givers or 0)
    RefreshObjectives(mapID)
end

local function OnEvent(_, event)
    if not (WHERE_EVENTS[event] or event == LOG_EVENT) then Q.Stale() end
    if event == LOG_EVENT then
        if objectiveLayer then RefreshObjectives(shownMap) end
    elseif not (PLACE_EVENTS[event] and GetBestMapForUnit(PLAYER) == shownMap) then
        Refresh()
    end
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(MAP_EVENTS) do events:RegisterEvent(event) end
        events:RegisterEvent(LOG_EVENT)
    elseif events then
        events:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSet(key)
    if OWN_KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(Q, "SetHidden", Refresh)
hooksecurefunc(Q, "ShowHidden", Refresh)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
