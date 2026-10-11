-- Run with Lua 5.1 from the repository root: the quest automation's Modifier skips or triggers
-- every quest step, and Auto Gossip picks only the one option the game itself would pick.
local settings = {
    enabled = true, questAccept = true, questTurnIn = true, questGossip = true, questShare = true,
    questRewardPicks = false, questSkipModifier = "ALT", questModifierMode = "SKIP",
    gossipAuto = true, gossipModifier = "ALT", gossipModifierMode = "SKIP",
}
local down = {}
local calls
local combat, forced = false, false
local activeQuests, availableQuests, options = {}, {}, {}

local frames = {}
local function Frame()
    local f = { events = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end

local S = { Get = function(key) return settings[key] end, DB = function() return {} end }
local function Log(name) return function(...) calls[#calls + 1] = { name, ... } end end
local ns = { QoLSettings = S, Print = function() end, cards = {} }
ns.Shared = { Settings = { Page = function()
    return { Card = function(_, card) ns.cards[#ns.cards + 1] = card end }
end } }

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    hooksecurefunc = function() end,
    IsAltKeyDown = function() return down.ALT == true end,
    IsControlKeyDown = function() return down.CTRL == true end,
    IsShiftKeyDown = function() return down.SHIFT == true end,
    InCombatLockdown = function() return combat end,
    IsInGroup = function() return true end,
    UnitIsPlayer = function() return false end,
    GetQuestID = function() return 1 end,
    QuestGetAutoAccept = function() return false end,
    AcceptQuest = Log("AcceptQuest"),
    CloseQuest = Log("CloseQuest"),
    ConfirmAcceptQuest = Log("ConfirmAcceptQuest"),
    StaticPopup_Hide = function() end,
    IsQuestCompletable = function() return true end,
    CompleteQuest = Log("CompleteQuest"),
    GetNumQuestChoices = function() return 0 end,
    GetQuestReward = Log("GetQuestReward"),
    GetNumActiveQuests = function() return 0 end,
    GetNumAvailableQuests = function() return 0 end,
    QuestLogPushQuest = Log("QuestLogPushQuest"),
    C_QuestLog = { IsPushableQuest = function() return true end, GetLogIndexForQuestID = function() return 7 end },
    Enum = { GossipOptionStatus = { Available = 0, Unavailable = 1, Locked = 2, AlreadyComplete = 3 } },
    C_GossipInfo = {
        ForceGossip = function() return forced end,
        GetActiveQuests = function() return activeQuests end,
        GetAvailableQuests = function() return availableQuests end,
        GetOptions = function() return options end,
        SelectActiveQuest = Log("SelectActiveQuest"),
        SelectAvailableQuest = Log("SelectAvailableQuest"),
        SelectOptionByIndex = Log("SelectOptionByIndex"),
    },
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/QuestAutomation.lua"))
setfenv(chunk, env)
chunk()

local events = frames[1]
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Fire(event, ...)
    calls = {}
    events.onEvent(events, event, ...)
    return calls
end
local function Count(name)
    local n = 0
    for _, call in ipairs(calls) do if call[1] == name then n = n + 1 end end
    return n
end

local QUEST_STEPS = {
    { "QUEST_DETAIL", "AcceptQuest" }, { "QUEST_ACCEPT_CONFIRM", "ConfirmAcceptQuest" },
    { "QUEST_PROGRESS", "CompleteQuest" }, { "QUEST_COMPLETE", "GetQuestReward" },
    { "QUEST_ACCEPTED", "QuestLogPushQuest", 5 },
}
availableQuests = { { questID = 9 } }
local function Steps(label, wantRun)
    for _, step in ipairs(QUEST_STEPS) do
        Fire(step[1], step[3])
        check(label .. " " .. step[1], (Count(step[2]) == 1) == wantRun)
    end
    Fire("GOSSIP_SHOW")
    check(label .. " GOSSIP_SHOW", (Count("SelectAvailableQuest") == 1) == wantRun)
end

settings.questModifierMode = "SKIP"
down = {}
Steps("skips, key up", true)
down.ALT = true
Steps("skips, key held", false)
settings.questModifierMode = "TRIGGER"
Steps("triggers, key held", true)
down = {}
Steps("triggers, key up", false)
settings.questSkipModifier = "SHIFT"
down.SHIFT = true
Steps("triggers, other key held", true)
down = { ALT = true }
Steps("triggers, wrong key held", false)
settings.questSkipModifier, settings.questModifierMode = "ALT", "SKIP"
down = {}
availableQuests = {}

local ONLY = { orderIndex = 3, status = 0, selectOptionWhenOnlyOption = true }
local function Gossip(label, want)
    Fire("GOSSIP_SHOW")
    check(label, (Count("SelectOptionByIndex") == 1) == want)
    if want then check(label .. " picks the option's order index", calls[1][2] == ONLY.orderIndex) end
end
local function Reset() Fire("GOSSIP_CLOSED") end

options = { ONLY }
Gossip("single flagged option is picked", true)
Gossip("not picked twice in one window", false)
Reset()
Gossip("picked again in the next window", true)

Reset()
options = { ONLY, { orderIndex = 4, status = 0, selectOptionWhenOnlyOption = true } }
Gossip("two options are left alone", false)
options = { { orderIndex = 3, status = 0, selectOptionWhenOnlyOption = false } }
Gossip("an option without the game's flag is left alone", false)
options = { { orderIndex = 3, status = 2, selectOptionWhenOnlyOption = true } }
Gossip("a locked option is left alone", false)
options = { ONLY }
forced = true
Gossip("a window the game keeps open for a forced gossip is left alone", false)
forced = false
availableQuests = { { questID = 9 } }
Gossip("a quest on offer is left to the quest automation", false)
availableQuests = {}
activeQuests = { { questID = 9, isComplete = false } }
Gossip("a quest in progress is left alone", false)
activeQuests = {}
combat = true
Gossip("no pick in combat", false)
combat = false
settings.gossipAuto = false
Gossip("the switch is off", false)
settings.gossipAuto = true

down.ALT = true
Gossip("skips mode: key held", false)
down = {}
Gossip("skips mode: key up", true)
Reset()
settings.gossipModifierMode = "TRIGGER"
Gossip("triggers mode: key up", false)
down.ALT = true
Gossip("triggers mode: key held", true)
settings.gossipModifier, down = "CTRL", { CTRL = true }
Reset()
Gossip("triggers mode follows the chosen key", true)

settings.gossipModifier, settings.gossipModifierMode, down = "ALT", "SKIP", {}
settings.questAccept, settings.questTurnIn = false, false
events:UnregisterAllEvents()
local apply = nil
for _, f in ipairs(frames) do if f ~= events then apply = f end end
check("a boot frame exists", apply)
apply.onEvent()
check("auto gossip listens without the quest steps", events.events.GOSSIP_SHOW and events.events.GOSSIP_CLOSED)
settings.gossipAuto = false
apply.onEvent()
check("auto gossip off stops listening", not events.events.GOSSIP_SHOW)

local keys = {}
for _, card in ipairs(ns.cards) do
    for _, row in ipairs(card.rows) do keys[row.key] = true end
end
check("the quest card has the mode row", keys.questModifierMode and keys.questSkipModifier)
check("the gossip card has its rows", keys.gossipModifier and keys.gossipModifierMode)

print(("quest modifier: %d checks passed"):format(checks))
