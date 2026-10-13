-- Run with Lua 5.1 from the repository root: the saved quest rewards list reads, removes and clears the picks,
-- tolerates old and damaged entries, and falls back to the title kept at save time.
local db, account = { questRewards = { [10] = 111, [20] = 222, [30] = 333, bad = 5, [40] = "x" } }, {}
local S = { Get = function() end, DB = function() return db end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = S,
    Print = function() end, AccountSettings = function() return account end }
ns.Shared = { Settings = { Page = function() return { Card = function() end } end } }

local titles = { [10] = "Ten" }
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function() return { RegisterEvent = function() end, UnregisterAllEvents = function() end,
        SetScript = function() end } end,
    hooksecurefunc = function() end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_QuestLog = { GetTitleForQuestID = function(id) return titles[id] end },
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/QuestAutomation.lua"))
setfenv(chunk, env)
chunk()

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local R = ns.QuestRewards
local list = R.List({})
table.sort(list)
check("only well-formed picks are listed", #list == 3 and list[1] == 10 and list[3] == 30)
check("an old numeric pick reads back its item", R.ItemID(20) == 222)

check("a cached title wins", R.Title(10) == "Ten")
check("no title is nil", R.Title(20) == nil)
account.questTitles = { [20] = "Kept" }
check("the title kept at save time is the fallback", R.Title(20) == "Kept")

local changed = 0
R.OnChange(function() changed = changed + 1 end)
R.Remove(20)
check("remove drops that quest only", db.questRewards[20] == nil and db.questRewards[10] == 111 and changed == 1)
R.Clear()
check("clear drops every pick", next(db.questRewards) == nil and changed == 2)
check("an empty list is empty", #R.List({}) == 0)

print(checks .. " saved quest reward checks passed")
