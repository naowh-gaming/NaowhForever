-- Run with Lua 5.1 from the repository root: what a Dungeon Journal quest needs before it can be picked up, and
-- where its chain is done. The generated data has the reputation each quest needs and the steps done inside an
-- instance; your standing is read against it (Reputation.lua), the quest panel's reputation row is green when you
-- have it and red with your standing on a bar when you don't (View/QuestDetailRows.lua), and "Level %d to pick up"
-- is the quest rows' red.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local TIMBERMAW = 576

local J = {}
local data = Load({ "NaowhForever_DungeonJournal/Data/QuestChains.lua" },
    setmetatable({ _G = { NaowhForever = { Journal = J } } }, { __index = _G }))
check("the data loads", data ~= nil and J.QuestMinRep ~= nil and J.QuestInside ~= nil)
for _, id in ipairs({ 92065, 92066, 92070 }) do
    local need = J.QuestMinRep[id]
    check("Blackmaw Hold quest " .. id .. " needs Neutral with Timbermaw Hold",
        need and need[1] == TIMBERMAW and need[2] == 0 and need[3] == "Timbermaw Hold")
end
check("The Defias Brotherhood's last step is done inside the Deadmines", J.QuestInside[166] == 1581)
local steps = {}
for _, list in pairs(J.QuestChains) do
    for _, step in ipairs(list) do
        if type(step) == "table" then for _, id in ipairs(step) do steps[id] = true end else steps[step] = true end
    end
end
for _, list in pairs(J.QuestPrereqs) do
    for _, step in ipairs(list) do
        if type(step) == "table" then for _, id in ipairs(step) do steps[id] = true end else steps[step] = true end
    end
end
for id in pairs(J.QuestInside) do check("inside step " .. id .. " is in a chain", steps[id]) end

local standings = {}
local function Color(text) return text end
local ns
ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    MEDIA = "media\\",
    Journal = J,
    THEME = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end }),
    Shared = {},
    Color = function(_, text) return Color(text) end,
}
local META = { __index = function(t, key)
    if key == "SetText" then return function(f, text) f.text = text end end
    if key == "SetShown" then return function(f, shown) f.shown = shown and true or false end end
    if key == "SetWidth" then return function(f, w) f.width = w end end
    if key == "GetWidth" then return function() return 300 end end
    if key == "GetStringHeight" then return function() return 12 end end
    if key == "CreateTexture" then return function(f) return setmetatable({ parent = f }, getmetatable(t)) end end
    return NOTHING
end }
local function Frame() return setmetatable({}, META) end
ns.Font, ns.Solid = Frame, Frame
local env = setmetatable({
    _G = { NaowhForever = ns },
    NaowhForever = ns,
    CreateFrame = Frame,
    GetText = function(key) return ({ FACTION_STANDING_LABEL3 = "Unfriendly", FACTION_STANDING_LABEL4 = "Neutral",
        FACTION_STANDING_LABEL5 = "Friendly" })[key] end,
    UnitSex = function() return 2 end,
    BreakUpLargeNumbers = tostring,
    C_Reputation = { GetFactionDataByID = function(id) return standings[id] end },
    C_Item = { GetItemCount = NOTHING },
    C_QuestLog = { GetNumQuestLogEntries = NOTHING, GetQuestIDForLogIndex = NOTHING,
        DoesQuestAwardReputationWithFaction = NOTHING, ReadyForTurnIn = NOTHING },
}, { __index = _G })
J.Settings = { Get = NOTHING }
J.Loot = {}
J.View = { Kinds = {} }
J.Colored = function(color, text) return (color == ns.Shared.Style.HAVE_RGB and "GREEN:" or "") .. text end
ns.Shared.Kinds = {}
Load({ "Shared/Style.lua", "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/View/Style.lua",
    "NaowhForever_DungeonJournal/Reputation.lua", "NaowhForever_DungeonJournal/View/QuestDetailRows.lua" }, env)

local St, Rep = J.Style, J.Reputation
check("Level to pick up is the quest rows' red", St.QUEST_CODE.low == St.QUEST_CODE.tooHigh)
check("standings start where the game's do", Rep.ReactionAt(-1) == 3 and Rep.ReactionAt(0) == 4
    and Rep.ReactionAt(2999) == 4 and Rep.ReactionAt(3000) == 5 and Rep.ReactionAt(-42000) == 1
    and Rep.ReactionAt(42999) == 8)

local need = J.QuestMinRep[92066]
check("the need is worded for players", Rep.NeedText(need) == "Requires Neutral with Timbermaw Hold")
check("an unmet faction does not meet it", Rep.Meets(need) == false)
standings[TIMBERMAW] = { reaction = 3, currentStanding = -1, currentReactionThreshold = -3000,
    nextReactionThreshold = 0 }
check("one short of Neutral does not meet it", Rep.Meets(need) == false)

local Kind = J.View.Kinds.questRep
local row = Kind.New(Frame())
Kind.Set(row, need)
check("short of it, the need is red", row.need.text == St.QUEST_CODE.tooHigh .. Rep.NeedText(need) .. "|r")
check("and your standing shows on the bar", row.standing.text:find("Unfriendly", 1, true) and row.track.shown
    and row.fill.shown and row.fill.width > 100)

standings[TIMBERMAW] = { reaction = 4, currentStanding = 0, currentReactionThreshold = 0, nextReactionThreshold = 3000 }
check("Neutral meets it", Rep.Meets(need) == true)
Kind.Set(row, need)
check("having it, the need is green", row.need.text == "GREEN:" .. Rep.NeedText(need))
check("an empty bar is not drawn", row.track.shown and not row.fill.shown)

standings[TIMBERMAW] = nil
Kind.Set(row, need)
check("a faction you have not met has no bar", row.standing.text == "Not met yet" and not row.track.shown)

print("journal quest needs: " .. checks .. " checks passed")
