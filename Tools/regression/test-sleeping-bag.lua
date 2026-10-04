-- Regression test for the Cozy Sleeping Bag chain (Discovery/NaowhForever_SleepingBagData.lua and
-- the chain logic in Discovery/NaowhForever_Discovery.lua): each faction's steps in order, the
-- first starting its faction's quest, every later one handing one in, and the chain read from
-- the quest log, step by step.
--   lua5.1 Tools/regression/test-sleeping-bag.lua

local checks = 0
local function Check(ok, label)
    checks = checks + 1
    assert(ok, label)
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local ns = {}
_G.NaowhForever = ns
assert(loadstring(Read("Discovery/NaowhForever_SleepingBagData.lua")))()
local data = ns.SleepingBag

-- The data.
Check(data.level == 14 and data.item == 211527, "the chain needs level 14 and gives the Cozy Sleeping Bag")
for side, first in pairs({ A = 79008, H = 79007 }) do
    local steps = data.steps[side]
    Check(#steps == 7, side .. ": seven steps")
    Check(steps[1].started == first and steps[1].done == nil, side .. ": the first starts its faction's note")
    Check(steps[2].done == first, side .. ": the second hands it in")
    for i, step in ipairs(steps) do
        Check(type(step.map) == "number" and type(step.x) == "number" and type(step.y) == "number"
            and step.object and step.place, side .. ": step " .. i .. " has where it is")
        if i > 1 then Check(type(step.done) == "number", side .. ": step " .. i .. " hands in a quest") end
    end
    Check(steps[7].done == 79976, side .. ": the last hands in This Must Be The Place")
end
Check(data.steps.A[1].map == 1436 and data.steps.H[1].map == 1413,
    "the Alliance starts in Westfall, the Horde in The Barrens")
Check(data.steps.A[3] == data.steps.H[3], "the chain is the same for both from Stonetalon on")

-- The logic, read out of the module (the part between its two markers), against a quest log.
local source = Read("Discovery/NaowhForever_Discovery.lua")
local logic = assert(source:match("(local Bag = {}.-\nfunction Bag%.Waypoint.-\nend)"), "the chain's logic")
local completed, inLog, level, side = {}, {}, 20, "A"
local env = setmetatable({
    ns = ns,
    Library = { Side = function() return side end, ZoneName = function(map) return "map " .. map end },
    C_QuestLog = {
        IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
        IsOnQuest = function(id) return inLog[id] == true end,
    },
    UnitLevel = function() return level end,
}, { __index = _G })
local chunk = assert(loadstring(logic .. "\nreturn Bag"))
setfenv(chunk, env)
local Bag = chunk()

local step, at = Bag.Current()
Check(at == 1 and step.object == "Burned-Out Remains" and step.map == 1436, "nothing done: the first remains")
inLog[79008] = true
step, at = Bag.Current()
Check(at == 2 and step.map == 1413, "the note in your log: the second remains, in The Barrens")
inLog[79008], completed[79008] = nil, true
for _, id in ipairs({ 79192, 79980, 79974 }) do completed[id] = true end
step, at = Bag.Current()
Check(at == 6 and step.object == "Messenger Bag", "four steps on: the Messenger Bag")
completed[79975], completed[79976] = true, true
Check(Bag.Current() == nil, "every step done: nothing left")
side, completed = "H", {}
step, at = Bag.Current()
Check(at == 1 and step.map == 1413, "a Horde character starts in The Barrens")
level = 13
Check(not Bag.Level(), "under level 14 it cannot start")
level = 14
Check(Bag.Level(), "at 14 it can")
Check(Bag.Where(step):find("map 1413", 1, true) ~= nil, "where a step is names its zone")

print("PASS sleeping bag: " .. checks .. " checks")
