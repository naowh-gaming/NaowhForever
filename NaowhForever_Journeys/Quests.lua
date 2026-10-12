-- Quests.lua: a quest you track that is far away becomes a journey to it; arriving hands it back to the game.
local ns = _G.NaowhForever

local Jy = ns.Journeys
local C = Jy.C
local S = Jy.Settings
local World = Jy.World
local Guide = Jy.Guide

local PERCENT = 100
local CENTER = 0.5
local PLAYER = "player"
local CONTINENTS = { 1415, 1414 }

local events

local function On()
    return Jy.On() and S.Get("quests")
end

local function OnMap(quest, map)
    for _, info in ipairs(C_QuestLog.GetQuestsOnMap(map)) do
        if info.questID == quest then return info.x, info.y end
    end
end

local function Continent(map)
    local info = C_Map.GetMapInfo(map)
    while info and info.mapType ~= Enum.UIMapType.Continent do
        info = info.parentMapID and info.parentMapID ~= 0 and C_Map.GetMapInfo(info.parentMapID) or nil
    end
    return info and info.mapID
end

local function Inside(x, y)
    return CENTER - math.max(math.abs(x - CENTER), math.abs(y - CENTER))
end

local function InZones(quest, continent)
    local bestMap, bestX, bestY, bestInside
    for _, zone in ipairs(C_Map.GetMapChildrenInfo(continent, Enum.UIMapType.Zone, true)) do
        local x, y = OnMap(quest, zone.mapID)
        if x and (not bestInside or Inside(x, y) > bestInside) then
            bestMap, bestX, bestY, bestInside = zone.mapID, x, y, Inside(x, y)
        end
    end
    return bestMap, bestX, bestY
end

local function Target(quest)
    local map, x, y = C_QuestLog.GetNextWaypoint(quest)
    if map and x and y then return map, x, y end
    local here = C_Map.GetBestMapForUnit(PLAYER)
    if not here then return nil end
    x, y = OnMap(quest, here)
    if x then return here, x, y end
    local mine = Continent(here)
    if mine then
        map, x, y = InZones(quest, mine)
        if map then return map, x, y end
    end
    for _, continent in ipairs(CONTINENTS) do
        if continent ~= mine then
            map, x, y = InZones(quest, continent)
            if map then return map, x, y end
        end
    end
end

local function Far(map, x, y)
    local here, there = World.Player(), World.FromMap(map, x * PERCENT, y * PERCENT)
    if not here or not there then return false end
    if here.c ~= there.c then return true end
    local dx, dy = here.x - there.x, here.y - there.y
    return dx * dx + dy * dy > C.QUEST_NEAR * C.QUEST_NEAR
end

local function OnSuperTrack()
    local quest = C_SuperTrack.GetSuperTrackedQuestID()
    if not quest or quest == 0 then return end
    local current = Guide.Current()
    if current and current.quest == quest then return end
    local map, x, y = Target(quest)
    if not map or not Far(map, x, y) then return end
    local title = C_QuestLog.GetTitleForQuestID(quest) or ""
    Guide.Start(title, { { title, map, x * PERCENT, y * PERCENT } }, quest)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnSuperTrack)
    end
    events:RegisterEvent("SUPER_TRACKING_CHANGED")
end

S.OnChange(Apply)
hooksecurefunc(ns, "Apply", Apply)
Apply()
