-- Quests.lua: a quest you track that is far away becomes a journey to it; arriving hands it back to the game.
local ns = _G.NaowhForever

local Jy = ns.Journeys
local C = Jy.C
local S = Jy.Settings
local World = Jy.World
local Guide = Jy.Guide

local PERCENT = 100
local PLAYER = "player"

local events

local function On()
    return Jy.On() and S.Get("quests")
end

local function Target(quest)
    local map, x, y = C_QuestLog.GetNextWaypoint(quest)
    if map and x and y then return map, x, y end
    local here = C_Map.GetBestMapForUnit(PLAYER)
    if not here then return nil end
    for _, info in ipairs(C_QuestLog.GetQuestsOnMap(here)) do
        if info.questID == quest then return info.mapID or here, info.x, info.y end
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
