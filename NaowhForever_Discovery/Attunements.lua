-- Attunements.lua: the attunement rules: each one's quests in order, the one you are on, where a quest starts, your class's own chains and Tier 0.5 (Discovery.Attune).
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local Library = Discovery.Library

local INSIDE_DUNGEON, INSIDE_GIVER = 1, 2
local QUEST, CLASSIC = 1, 2
local UNIT_CLASS = 2
local TEXT_WHERE = "%s, %s (%.1f, %.1f)"
local TEXT_INSIDE = ns.L("Inside %s")
local TEXT_GIVER_INSIDE = ns.L("%s, inside %s")
local TEXT_NOTE = " (%s)"

local steps = {}
local classic = {}
local classChains, classSingles, classSeen = {}, {}, {}

local Attune = {}
Discovery.Attune = Attune

local function Before(Q, element)
    if type(element) == "number" then return Q.Mine(element) and element end
    for _, id in ipairs(element) do
        if Q.Mine(id) then return id end
    end
end

local function Walk(Q, id, out, seen)
    if seen[id] then return end
    seen[id] = true
    for _, element in ipairs(Q.Requires(id)) do
        local before = Before(Q, element)
        if before then Walk(Q, before, out, seen) end
    end
    out[#out + 1] = id
end

local function ClassStep(key)
    local class = select(UNIT_CLASS, UnitClass("player"))
    local pair = ns.Attunements.classQuests[Library.Side()][class][key]
    classic[pair[QUEST]] = pair[CLASSIC]
    return pair[QUEST]
end

local function Resolve(step)
    if type(step) == "number" then return step end
    if type(step) == "string" then return ClassStep(step) end
    return step[Library.Side()] or step
end

local function Done(id)
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return true end
    return classic[id] ~= nil and C_QuestLog.IsQuestFlaggedCompleted(classic[id])
end

local function InLog(id)
    if C_QuestLog.IsOnQuest(id) then return true end
    return classic[id] ~= nil and C_QuestLog.IsOnQuest(classic[id])
end

local function StepDone(step)
    if type(step) == "number" then return Done(step) end
    for _, id in ipairs(step) do
        if Done(id) then return true end
    end
    return false
end

local function Current(step)
    if type(step) == "number" then return step end
    for _, id in ipairs(step) do
        if InLog(id) then return id end
    end
    return step[1]
end

local function OnPage(Q, chain)
    for _, entry in ipairs(ns.Attunements.list) do
        if entry.class then
            for _, step in ipairs(Attune.Steps(entry)) do
                if type(step) == "number" and Q.Chain(step) == chain then return true end
            end
        end
    end
    return false
end

local function Quest(entry)
    local quest = entry.quest
    if type(quest) == "table" then return quest[Library.Side()] end
    return quest
end

local function ChainOrder(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.name < b.name
end

local function ClassLed(Q, chain)
    return chain ~= nil and Q.ClassOnly(chain.steps[1][1])
end

local function Single(Q, id)
    if Q.Repeatable(id) or Q.Expected(id) == "closed" then return false end
    return not Q.Event(id) or Q.EventOn(id)
end

function Attune.Steps(entry)
    local list = steps[entry]
    if not list then
        list = {}
        if entry.steps then
            for i, step in ipairs(entry.steps) do list[i] = Resolve(step) end
        else
            local Q = ns.Completo.Quests
            Q.Refresh()
            Walk(Q, Quest(entry), list, {})
        end
        steps[entry] = list
    end
    return list
end

function Attune.At(entry)
    local list = Attune.Steps(entry)
    for i = #list, 1, -1 do
        if StepDone(list[i]) then return i + 1 end
    end
    return 1
end

function Attune.Have(entry)
    return entry.item ~= nil and C_Item.GetItemCount(entry.item, true) > 0
end

function Attune.Next(entry)
    local list = Attune.Steps(entry)
    local at = Attune.At(entry)
    if at > #list or Attune.Have(entry) then return nil end
    if at == 1 and UnitLevel("player") < ns.Completo.Quests.RequiredLevel(list[1]) then return nil end
    return Current(list[at]), at
end

function Attune.Open()
    for _, entry in ipairs(ns.Attunements.list) do
        if Attune.Next(entry) then return true end
    end
    return false
end

function Attune.State(id, i, at)
    if i < at then return "done" end
    if InLog(id) then return "log" end
    if i > at then return "later" end
    if UnitLevel("player") < ns.Completo.Quests.RequiredLevel(id) then return "low" end
    return "now"
end

function Attune.ClassQuests()
    local Q = ns.Completo.Quests
    Q.Refresh()
    wipe(classChains)
    wipe(classSingles)
    wipe(classSeen)
    for _, id in ipairs(Q.ClassQuests()) do
        local chain = Q.Chain(id)
        if ClassLed(Q, chain) then
            if not classSeen[chain] then
                classSeen[chain] = true
                if not OnPage(Q, chain) then classChains[#classChains + 1] = chain end
            end
        elseif Single(Q, id) then
            classSingles[#classSingles + 1] = id
        end
    end
    table.sort(classChains, ChainOrder)
    return classChains, classSingles
end

function Attune.ClassState(id, i, at)
    local Q = ns.Completo.Quests
    if Q.Done(id) then return "done" end
    if i == at and not Q.Opened(id) and not C_QuestLog.IsOnQuest(id) then return "later" end
    return Attune.State(id, i, at)
end

function Attune.Name(id)
    return C_QuestLog.GetTitleForQuestID(id) or ns.Completo.Quests.Name(id)
end

function Attune.Title(entry)
    if entry.item then return C_Item.GetItemNameByID(entry.item) end
    local list = Attune.Steps(entry)
    return Attune.Name(list[#list])
end

function Attune.Icon(entry)
    return C_Item.GetItemIconByID(entry.icon or entry.item)
end

function Attune.Where(id)
    local Q = ns.Completo.Quests
    local map, x, y = Q.Spot(id)
    if map then return TEXT_WHERE:format(Q.Giver(id), Library.ZoneName(map), x, y) end
    local inside = ns.Attunements.inside[id]
    if not inside then return "" end
    local dungeon = ns.L(inside[INSIDE_DUNGEON])
    if inside[INSIDE_GIVER] then return TEXT_GIVER_INSIDE:format(inside[INSIDE_GIVER], dungeon) end
    return TEXT_INSIDE:format(dungeon)
end

function Attune.Note(id)
    local note = ns.Attunements.notes[id]
    return note and ns.L(note)
end

function Attune.Waypoint(id)
    local Q = ns.Completo.Quests
    local map, x, y = Q.Spot(id)
    Library.Waypoint(Attune.Name(id), map, x, y, TEXT_NOTE:format(Q.Giver(id)))
end
