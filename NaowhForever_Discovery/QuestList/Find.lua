-- Find.lua: the Quest List's quests, rares, and the creatures and objects its quests send you to, for QoL's Find window (ns.FindQuestsAndRares).
local ns = _G.NaowhForever
local Q, R = ns.Completo.Quests, ns.Completo.Rares
local S = ns.CompletoSettings
local D = ns.CompletoQuestData

local ALL = math.huge
local LOWER, NAME, MAP, X, Y, OBJECT, QUESTS = 1, 2, 3, 4, 5, 6, 7
local HAND_IN_NAME, HAND_IN_MAP, HAND_IN_X, HAND_IN_Y = 1, 2, 3, 4
local SOURCE_KIND, SOURCE_NAME, SOURCE_MAP, SOURCE_X, SOURCE_Y = 1, 2, 3, 4, 5
local FIRST_SOURCE = 3
local OBJECT_KIND = 2
local NPC_ICON = "Interface\\Icons\\INV_Misc_Head_Human_01"
local OBJECT_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local KEY_SEP = "\n"
local TEXT_TAKES = ns.L("Takes %s")
local TEXT_FOR = ns.L("For %s")

local index, at

local function Keep(name, map, x, y, quest, role, object)
    if not name or name == "" or not map then return end
    local key = name .. KEY_SEP .. map
    local place = at[key]
    if not place then
        place = { name:lower(), name, map, x, y, object, {} }
        at[key] = place
        index[#index + 1] = place
    end
    local quests = place[QUESTS]
    quests[#quests + 1] = quest
    quests[#quests + 1] = role
end

local function Index()
    if index then return index end
    index, at = {}, {}
    for id, hand in pairs(D.HandIns) do
        Keep(hand[HAND_IN_NAME], hand[HAND_IN_MAP], hand[HAND_IN_X], hand[HAND_IN_Y], id, TEXT_TAKES)
    end
    for id, entries in pairs(D.Objectives) do
        for _, entry in ipairs(entries) do
            for i = FIRST_SOURCE, #entry do
                local source = entry[i]
                Keep(source[SOURCE_NAME], source[SOURCE_MAP], source[SOURCE_X], source[SOURCE_Y], id, TEXT_FOR,
                    source[SOURCE_KIND] == OBJECT_KIND)
            end
        end
    end
    at = nil
    return index
end

local function Wanted(quest)
    return not Q.Done(quest) and (not D.Quests[quest] or Q.Mine(quest))
end

local function FindPlaces(text, add)
    for _, place in ipairs(Index()) do
        if place[LOWER]:find(text, 1, true) then
            local quests = place[QUESTS]
            for i = 1, #quests, 2 do
                local quest = quests[i]
                if Wanted(quest) then
                    add("npc", place[NAME], quests[i + 1]:format(Q.Title(quest) or quest), place[MAP], place[X],
                        place[Y], place[OBJECT] and OBJECT_ICON or NPC_ICON)
                    break
                end
            end
        end
    end
end

function ns.FindQuestsAndRares(text, add)
    if not S.Get("enabled") then return false end
    Q.Update()
    for _, entry in ipairs((Q.Search(text, ALL))) do
        for _, id in ipairs(entry.ids) do
            local map, x, y = Q.Spot(id)
            if map and not Q.Done(id) then add("quest", Q.Title(id), Q.Giver(id), map, x, y) end
        end
    end
    for _, entry in ipairs((R.Search(text, ALL))) do
        for _, npc in ipairs(entry.ids) do
            local map, x, y = R.Spot(npc)
            if map then add("rare", R.Name(npc), R.LevelText(npc), map, x, y) end
        end
    end
    FindPlaces(text, add)
    return true
end
