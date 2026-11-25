-- Run with Lua 5.1 from the repository root: the Dungeon Journal's quests (DungeonJournal/
-- Quests.lua). Where each quest stands for you (in your log, ready, done, part done, what to
-- do first and how far along, the level it needs, too high for now), which are listed and in
-- what order, its chain and each step's state, where its waypoint goes, and that the list
-- reuses its entries. Then checks the generated quest and chain data holds together.
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local DEFIAS = { 65, 132, 135, 141, 142, 155 }
local function Set(t)
    local out = {}
    for _, id in ipairs(t or {}) do out[id] = true end
    return out
end

-- The quest log's colouring (DifficultyUtil.GetRelativeDifficultyColor) for a player of this
-- level, with 8 levels of standard under it.
local COLORS = { trivial = {}, standard = {}, difficult = {}, verydifficult = {}, impossible = {} }
local function DifficultyColor(level, player)
    local diff = level - player
    if diff >= 5 then return COLORS.impossible end
    if diff >= 3 then return COLORS.verydifficult end
    if diff >= -4 then return COLORS.difficult end
    if -diff <= 8 then return COLORS.standard end
    return COLORS.trivial
end

local function Data()
    return {
        QuestData = { { name = "The Deadmines", quests = {
            { 214, "Red Silk Bandanas", 17, "A", "pre",
              "Westfall, Sentinel Hill - Scout Riell Complete 6 quests, starting with The Defias "
              .. "Brotherhood (56.7, 47.4)", 1436, 56.7, 47.4 },
            { 500, "Split", 20, "B", "pre", "Somewhere", 1411, 10, 10 },
            { 600, "Plain", 20, "B", true, "Plain place", 1411, 20, 20 },
        } } },
        QuestPrereqs = { [214] = DEFIAS, [500] = { { 501, 502 }, 503 }, [700] = DEFIAS },
        -- 700's Series starts at the last prerequisite and goes on past it.
        QuestChains = { [700] = { 155, 700, 701 }, [5728] = { 5727, 5728, 5729, 5730 },
            [914] = { 1489, { 1490, 1491 }, 914 } },
        QuestMinLevel = { [214] = 14, [600] = 30 },
        QuestWhere = { [214] = "Westfall, Sentinel Hill - Scout Riell (56.7, 47.4)" },
        QuestChainNames = { [65] = "The Defias Brotherhood", [132] = "The Defias Brotherhood",
            [135] = "The Defias Brotherhood", [141] = "The Defias Brotherhood",
            [142] = "The Defias Brotherhood", [155] = "The Defias Brotherhood",
            [501] = "Alliance Start", [502] = "Horde Start", [503] = "Middle" },
        QuestChainStarts = { [141] = { 1436, 56.3, 47.5, "Gryan Stoutmantle" } },
        QuestTurnIns = {},
        QuestClosedBy = {}, QuestClosedByNames = {},
        QuestTips = {},
    }
end

-- on: quest IDs in the log; done: turned in; complete: logged IDs with objectives done;
-- level: yours; levels: the game's quest levels, where loaded. Returns the quests module, the
-- quests by ID and what the stubs saw.
local function Fixture(opts)
    opts = opts or {}
    local on, done, complete = Set(opts.on), Set(opts.done), Set(opts.complete)
    local level, levels = opts.level or 20, opts.levels or {}
    local seen = { placed = {}, printed = {}, requested = {} }
    local J = Data()
    J.Settings = { Get = function(key) return key == "questHelp" and opts.help == true end }
    for _, quest in ipairs(opts.extra or {}) do table.insert(J.QuestData[1].quests, quest) end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        Journal = J,
        Print = function(text) seen.printed[#seen.printed + 1] = text end,
        PlaceWaypoint = function(title, map, x, y, note)
            seen.placed[#seen.placed + 1] = { title = title, map = map, x = x, y = y, note = note }
            return true
        end,
        CanPlaceWaypoint = function() return true end,   -- every map takes one, as PlaceWaypoint says
        GamepadOwnsPanels = function() return opts.gamepad == true end,
        OnApply = function() end,
        Shared = {},
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_QuestLog = {
            IsOnQuest = function(id) return on[id] == true end,
            IsComplete = function(id) return complete[id] == true end,
            IsQuestFlaggedCompleted = function(id) return done[id] == true end,
            GetTitleForQuestID = function() return nil end,
            GetQuestDifficultyLevel = function(id) return levels[id] or 0 end,
            RequestLoadQuestByID = function(id) seen.requested[#seen.requested + 1] = id end,
            GetNextWaypoint = function(id) if on[id] and not opts.noRoute then return 1437, 0.25, 0.75 end end,
            IsUnitOnQuest = function(unit, id)
                local member = opts.party and opts.party[tonumber(unit:match("%d+$"))]
                return member ~= nil and member[id] == true
            end,
        },
        UnitLevel = function() return level end,
        InCombatLockdown = function() return opts.combat == true end,
        C_Map = { OpenWorldMap = function(map) seen.mapOpened = map end },
        -- opts.party: one set of quest IDs per group member, party1 first.
        GetNumSubgroupMembers = function() return opts.party and #opts.party or 0 end,
        UnitClass = function() return "Mage", opts.class or "MAGE" end,
        UnitRace = function() return "Human", "Human", opts.race or 1 end,
        UnitFactionGroup = function() return opts.faction or "Alliance" end,
        QuestDifficultyColors = COLORS,
        GetQuestDifficultyColor = function(questLevel) return DifficultyColor(questLevel, level) end,
    }, { __index = _G })
    for _, path in ipairs({ "Shared/Data/SameMaps.lua", "Shared/Game/Places.lua",
            "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/Quests.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local byID = {}
    for _, quest in ipairs(J.QuestData[1].quests) do byID[quest[1]] = quest end
    return J.Quests, byID, seen, J
end

-- The game's levels for the test quests, so none is grey to a level-30 player.
local AT_30 = { [214] = 30, [500] = 30, [600] = 30 }

-- The list entry for a quest, or nil when it is not listed.
local function EntryFor(Q, J, id)
    for _, entry in ipairs(Q.List(J.QuestData[1], {}, {})) do
        if entry.quest[1] == id then return entry end
    end
end

-------------------------------------------------------------------------------
--  In your log, done or part done
-------------------------------------------------------------------------------
local plain = { 100, "Plain", 20, "B", true, "" }
local chain = { 200, "Chain", 20, "B", true, "", steps = { 201, { 202, 203 } } }
local alt = { 300, "Alt", 20, "B", true, "", alt = { 301 } }
local lead = { 400, "Lead", 20, "B", true, "", lead = { 401 } }

Case("a quest with a giver per faction takes the player's own giver and spot", function()
    local sides = { A = { "Alliance giver", 2548, 66.7, 81.0 }, H = { "Horde giver", 2548, 59.4, 44.2 } }
    local function Shared() return { 500, "Sided", 20, "B", true, "Both givers", sides = sides } end
    local _, byID = Fixture({ extra = { Shared() } })
    local q = byID[500]
    assert(q[6] == "Alliance giver" and q[7] == 2548 and q[8] == 66.7 and q[9] == 81.0, q[6])
    _, byID = Fixture({ extra = { Shared() }, faction = "Horde" })
    q = byID[500]
    assert(q[6] == "Horde giver" and q[8] == 59.4 and q[9] == 44.2, q[6])
end)

Case("a quest in the log with objectives left is In log", function()
    local Q = Fixture({ on = { 100 } })
    assert(Q.Kind(plain) == "active" and Q.InLog("active"))
end)

Case("a quest in the log with its objectives done is ready to hand in", function()
    local Q = Fixture({ on = { 100 }, complete = { 100 } })
    assert(Q.Kind(plain) == "ready" and Q.InLog("ready"))
end)

Case("ready follows the logged step, alt or lead-in, not the first ID", function()
    local Q = Fixture({ on = { 203, 301, 401 }, complete = { 203, 401 }, done = { 200, 201 } })
    assert(Q.Kind(chain) == "ready")
    assert(Q.Kind(alt) == "active")
    assert(Q.Kind(lead) == "ready")
    assert(Q.LoggedID(chain) == 203 and Q.LoggedID(alt) == 301 and Q.LoggedID(lead) == 401)
end)

Case("objectives done on a quest that is not in the log do not count", function()
    local Q = Fixture({ complete = { 100 } })
    assert(Q.Kind(plain) == "pickup")
end)

Case("handed in, part done, an alt handed in, and a lead-in not carried", function()
    local Q = Fixture({ done = { 100, 200, 301 } })
    assert(Q.Kind(plain) == "done")
    assert(Q.Kind(chain) == "next")
    assert(Q.Kind(alt) == "done")
    assert(Q.Kind(lead) == "pickup")
    assert(not Q.InLog("done") and not Q.InLog("next") and not Q.InLog("pickup"))
end)

Case("the quest itself in the log or done ignores its prerequisites", function()
    local Q, q = Fixture({ on = { 214 } })
    assert(Q.Kind(q[214]) == "active")
    Q, q = Fixture({ done = { 214 } })
    assert(Q.Kind(q[214]) == "done")
end)

-------------------------------------------------------------------------------
--  What to do first, and the level it needs
-------------------------------------------------------------------------------
Case("nothing done: Requires names the first step, 1 of 6", function()
    local Q, q, _, J = Fixture()
    assert(Q.Kind(q[214]) == "prereq" and Q.ToPickUp("prereq"))
    assert(EntryFor(Q, J, 214).where == "Requires: The Defias Brotherhood (1/6)")
end)

Case("some steps done: Requires names the next step, with where it starts", function()
    local Q, q, _, J = Fixture({ done = { 65, 132, 135 } })
    assert(Q.Kind(q[214]) == "prereq")
    local where = EntryFor(Q, J, 214).where
    assert(where == "Requires: The Defias Brotherhood (4/6) (Gryan Stoutmantle)", where)
end)

Case("a later step done counts the ones before it as done", function()
    local Q, _, _, J = Fixture({ done = { 142 } })
    local where = EntryFor(Q, J, 214).where
    assert(where == "Requires: The Defias Brotherhood (6/6)", where)
end)

Case("the step to do in your log is the in-log Requires", function()
    local Q, q, _, J = Fixture({ on = { 141 }, done = { 65, 132, 135 } })
    assert(Q.Kind(q[214]) == "prereqLog")
    local entry = EntryFor(Q, J, 214)
    assert(entry.where == "Requires (in your log): The Defias Brotherhood (4/6) (Gryan Stoutmantle)", entry.where)
    assert(entry.canWaypoint)
end)

Case("a step with faction versions: either one done or in the log counts", function()
    local Q, q, _, J = Fixture({ done = { 502 } })
    assert(Q.Kind(q[500]) == "prereq")
    assert(EntryFor(Q, J, 500).where == "Requires: Middle (2/2)")
    Q, q, _, J = Fixture({ on = { 502 } })
    assert(Q.Kind(q[500]) == "prereqLog")
    assert(EntryFor(Q, J, 500).where == "Requires (in your log): Horde Start (1/2)")
end)

Case("all done but your level too low: waiting on your level", function()
    local Q, q = Fixture({ done = DEFIAS, level = 12 })
    assert(Q.Kind(q[214]) == "low" and Q.MinLevel(q[214]) == 14 and Q.ToPickUp("low"))
    Q, q = Fixture({ level = 29 })
    assert(Q.Kind(q[600]) == "low")
end)

Case("all done and your level high enough: to pick up, at the quest giver", function()
    local Q, q, _, J = Fixture({ done = DEFIAS, level = 14 })
    assert(Q.Kind(q[214]) == "pickup")
    -- The where line drops the guide's prerequisite note once the list is known.
    assert(EntryFor(Q, J, 214).where == "Westfall, Sentinel Hill - Scout Riell (56.7, 47.4)")
    Q, q, _, J = Fixture({ level = 30, levels = AT_30 })
    assert(Q.Kind(q[600]) == "pickup")
    assert(EntryFor(Q, J, 600).where == "Plain place")
end)

Case("to pick up but five levels or more above you: too high", function()
    local Q, _, _, J = Fixture({ done = { 501, 503 }, level = 15 })
    local entry = EntryFor(Q, J, 500)
    assert(entry.kind == "pickup" and entry.tooHigh and entry.level == 20)
    Q, _, _, J = Fixture({ done = { 501, 503 }, level = 16 })
    assert(not EntryFor(Q, J, 500).tooHigh)
end)

-------------------------------------------------------------------------------
--  Which quests are listed, and in what order
-------------------------------------------------------------------------------
Case("grey follows the quest log's own color for the game's quest level", function()
    local Q, _, _, J = Fixture({ level = 30, done = DEFIAS, levels = { [214] = 21, [600] = 22, [500] = 40 } })
    assert(EntryFor(Q, J, 214) == nil, "a grey quest to pick up is not listed")
    assert(EntryFor(Q, J, 600) and EntryFor(Q, J, 500))
    Q, _, _, J = Fixture({ level = 30, on = { 214 }, levels = { [214] = 21 } })
    assert(EntryFor(Q, J, 214), "a grey quest in your log still is")
end)

Case("an unloaded quest is judged by the data's level, and loaded once", function()
    local Q, q, seen, J = Fixture({ level = 30, done = DEFIAS })
    assert(EntryFor(Q, J, 214) == nil, "17 in the data is grey at 30")
    assert(Q.Level(q[214]) == 17)
    local asked = 0
    for _, id in ipairs(seen.requested) do if id == 214 then asked = asked + 1 end end
    assert(asked == 1, asked)
end)

Case("only your faction's quests and your class's class quests", function()
    local Q, _, _, J = Fixture({ faction = "Horde", done = DEFIAS })
    assert(EntryFor(Q, J, 214) == nil and EntryFor(Q, J, 600))
    J.QuestData[1].quests[3].class = "WARRIOR"
    assert(EntryFor(Q, J, 600) == nil)
    J.QuestData[1].quests[3].class = "MAGE"
    assert(EntryFor(Q, J, 600))
end)

Case("a quest for two classes is listed for either", function()
    local Q, _, _, J = Fixture({ faction = "Horde", done = DEFIAS })
    J.QuestData[1].quests[3].class = { "WARRIOR", "PALADIN" }
    assert(EntryFor(Q, J, 600) == nil, "not for the mage")
    assert(Q.ForClass(J.QuestData[1].quests[3].class, "PALADIN"), "a paladin's")
    J.QuestData[1].quests[3].class = { "WARRIOR", "MAGE" }
    assert(EntryFor(Q, J, 600), "a mage's")
end)

Case("a quest only some races can take is listed for those races", function()
    local Q, _, _, J = Fixture({ faction = "Horde", race = 5, done = DEFIAS })
    J.QuestData[1].quests[3].races = 162
    assert(EntryFor(Q, J, 600) == nil, "Undead cannot take an Orc, Tauren and Troll quest")
    Q, _, _, J = Fixture({ faction = "Horde", race = 6, done = DEFIAS })
    J.QuestData[1].quests[3].races = 162
    assert(EntryFor(Q, J, 600), "a Tauren can")
    Q, _, _, J = Fixture({ faction = "Horde", race = 5, done = DEFIAS })
    J.QuestData[1].quests[3].races = 16
    assert(EntryFor(Q, J, 600), "an Undead-only quest is listed for Undead")
    Q, _, _, J = Fixture({ faction = "Horde", race = 96, done = DEFIAS })
    J.QuestData[1].quests[3].races = 162 + 2 ^ 33
    assert(EntryFor(Q, J, 600), "Horde Skyborne's bit is past 32 and still read")
end)

Case("handed in quests are not listed", function()
    local Q, _, _, J = Fixture({ done = { 600 }, level = 30 })
    assert(EntryFor(Q, J, 600) == nil)
end)

Case("the list goes prerequisites, level, pick up, in your log, ready", function()
    local Q, _, _, J = Fixture({ level = 29, levels = AT_30, on = { 801, 800 }, complete = { 801 } })
    local quests = J.QuestData[1].quests
    quests[#quests + 1] = { 801, "Ready", 25, "B", true, "", 1411, 1, 1 }
    quests[#quests + 1] = { 800, "Active", 25, "B", true, "", 1411, 1, 1 }
    quests[#quests + 1] = { 802, "Open", 25, "B", true, "", 1411, 1, 1 }
    local order = {}
    for i, entry in ipairs(Q.List(J.QuestData[1], {}, {})) do order[i] = entry.kind end
    assert(table.concat(order, ",") == "prereq,prereq,low,pickup,active,ready", table.concat(order, ","))
end)

Case("the list reuses the caller's entries, and two callers never share one", function()
    local Q, _, _, J = Fixture({ level = 30, levels = AT_30 })
    local data = J.QuestData[1]
    local out, pool = {}, {}
    Q.List(data, out, pool)
    local first = out[1]
    assert(Q.List(data, out, pool) == out and out[1] == first and #out == 3)
    local other = Q.List(data, {}, {})
    assert(other[1] ~= first and other[1].quest == first.quest)
end)

Case("the list counts who in your group is on each quest", function()
    local Q, _, _, J = Fixture({ level = 30, levels = AT_30, on = { 600 },
        party = { { [600] = true }, { [214] = true }, { [600] = true } } })
    local byID = {}
    for _, entry in ipairs(Q.List(J.QuestData[1], {}, {})) do byID[entry.quest[1]] = entry end
    assert(byID[600].party == 2 and byID[214].party == 1 and byID[500].party == 0)
    Q, _, _, J = Fixture({ level = 30, levels = AT_30 })
    assert(Q.List(J.QuestData[1], {}, {})[1].party == 0, "out of a group, none")
end)

Case("the count agrees with the list", function()
    local Q, _, _, J = Fixture({ level = 30, levels = AT_30, on = { 600 } })
    local toPickUp, inLog = Q.Count(J.QuestData[1])
    assert(toPickUp == 2 and inLog == 1, toPickUp .. " " .. inLog)
    assert(#Q.List(J.QuestData[1], {}, {}) == toPickUp + inLog)
end)

Case("the signature changes with a quest's state, and only then", function()
    local Q, _, _, J = Fixture({ level = 30 })
    local a = Q.Signature(J.QuestData[1])
    assert(Q.Signature(J.QuestData[1]) == a)
    local Q2, _, _, J2 = Fixture({ level = 30, on = { 600 } })
    assert(Q2.Signature(J2.QuestData[1]) ~= a)
end)

-------------------------------------------------------------------------------
--  Lockouts: a quest another closes for good
-------------------------------------------------------------------------------
-- 910 is a breadcrumb to 911; 920 and 921 are two versions of one quest, only one of which counts.
local LOCKS = {
    { 910, "Crumb", 20, "A", true, "Crumb place", 1411, 5, 5 },
    { 911, "Villainy", 20, "A", true, "Inside" },
    { 920, "Amulet", 20, "B", true, "Here" },
    { 921, "Amulet", 20, "B", true, "There" },
}
local CLOSED_BY = { [910] = { 911 }, [920] = { 921 }, [921] = { 920 } }
local LOCK_LEVELS = { [910] = 30, [911] = 30, [920] = 30, [921] = 30 }

local function LockFixture(opts)
    opts.extra, opts.level, opts.levels = LOCKS, 30, LOCK_LEVELS
    local Q, q, seen, J = Fixture(opts)
    J.QuestClosedBy = CLOSED_BY
    return Q, q, seen, J
end

Case("with Quest Help off, a closed quest stays as it was", function()
    local Q, q = LockFixture({ on = { 911 } })
    assert(Q.Kind(q[910]) == "pickup")
    assert(#Q.Warnings(q[910], {}) == 0)
end)

Case("a breadcrumb is lost once the quest it leads to is in your log or done", function()
    local Q, q = LockFixture({ help = true, on = { 911 } })
    assert(Q.Kind(q[910]) == "lost")
    Q, q = LockFixture({ help = true, done = { 911 } })
    assert(Q.Kind(q[910]) == "lost")
    Q, q = LockFixture({ help = true, done = { 911, 910 } })
    assert(Q.Kind(q[910]) == "done", "one handed in first is done, not lost")
end)

Case("a lost quest is listed last, greyed, with no waypoint, and counted nowhere", function()
    local Q, _, _, J = LockFixture({ help = true, on = { 911 } })
    local list = Q.List(J.QuestData[1], {}, {})
    local last = list[#list]
    assert(last.quest[1] == 910 and last.kind == "lost" and last.lostTo == 911 and not last.canWaypoint)
    local toPickUp, inLog = Q.Count(J.QuestData[1])
    assert(toPickUp + inLog == #list - 1)
    local done, total = Q.Progress(J.QuestData[1])
    local Q2, _, _, J2 = LockFixture({ help = false, on = { 911 } })
    local _, before = Q2.Progress(J2.QuestData[1])
    assert(done == 0 and total == before - 1, total .. " " .. before)
end)

Case("the signature changes when a quest is lost", function()
    local Q, _, _, J = LockFixture({ help = true })
    local Q2, _, _, J2 = LockFixture({ help = true, on = { 911 } })
    assert(Q.Signature(J.QuestData[1]) ~= Q2.Signature(J2.QuestData[1]))
end)

Case("before it is too late, both quests warn", function()
    local Q, q = LockFixture({ help = true })
    local crumb = Q.Warnings(q[910], {})
    assert(#crumb == 1 and crumb[1] == "Lost if you take Villainy first.", crumb[1])
    local villainy = Q.Warnings(q[911], {})
    assert(#villainy == 1 and villainy[1] == "Taking it loses Crumb for good.", villainy[1])
    Q, q = LockFixture({ help = true, done = { 910 } })
    assert(#Q.Warnings(q[911], {}) == 0, "nothing left to lose")
    Q, q = LockFixture({ help = true, on = { 911 } })
    assert(#Q.Warnings(q[910], {}) == 0 and #Q.Warnings(q[911], {}) == 0, "too late, or in your log")
end)

Case("versions of one quest: one warning, and the others lost once one is taken", function()
    local Q, q = LockFixture({ help = true })
    local lines = Q.Warnings(q[920], {})
    assert(#lines == 1 and lines[1]:find("versions", 1, true), lines[1])
    Q, q = LockFixture({ help = true, on = { 921 } })
    assert(Q.Kind(q[920]) == "lost" and Q.Kind(q[921]) == "active")
end)

Case("a quest's tip warns until it is handed in, with Quest Help on", function()
    local tipped = { { 930, "Gems", 20, "B", true, "Here" } }
    local function TipFixture(opts)
        opts.extra = tipped
        local Q, q, _, J = Fixture(opts)
        J.QuestTips[930] = "Finish it before the last boss."
        return Q, q
    end
    local Q, q = TipFixture({})
    assert(#Q.Warnings(q[930], {}) == 0, "Quest Help off")
    Q, q = TipFixture({ help = true })
    local lines = Q.Warnings(q[930], {})
    assert(#lines == 1 and lines[1] == "Finish it before the last boss.", lines[1])
    Q, q = TipFixture({ help = true, on = { 930 } })
    assert(#Q.Warnings(q[930], {}) == 1, "still shown in your log")
    Q, q = TipFixture({ help = true, done = { 930 } })
    assert(#Q.Warnings(q[930], {}) == 0, "handed in")
end)

Case("a chain step's tip shows on the quest while that step is the next one", function()
    local chained = { { 914, "Leaders", 20, "B", true, "Here" } }
    local function TipFixture(opts)
        opts.extra = chained
        local Q, q, _, J = Fixture(opts)
        J.QuestTips[1489] = "A group quest."
        J.QuestChainNames[1489] = "First Step"
        return Q, q
    end
    local Q, q = TipFixture({ help = true })
    local lines = Q.Warnings(q[914], {})
    assert(#lines == 1 and lines[1] == "First Step: A group quest.", lines[1])
    Q, q = TipFixture({ help = true, done = { 1489 } })
    assert(#Q.Warnings(q[914], {}) == 0, "step done")
end)

Case("a step that can be any of several quests shows the tip of whichever has one", function()
    local Q, q, _, J = Fixture({ help = true, extra = { { 914, "Leaders", 20, "B", true, "Here" } }, done = { 1489 } })
    J.QuestTips[1491] = "A group quest."
    J.QuestChainNames[1491] = "Second Step"
    local lines = Q.Warnings(q[914], {})
    assert(#lines == 1 and lines[1] == "Second Step: A group quest.", lines[1])
end)

-------------------------------------------------------------------------------
--  Chains
-------------------------------------------------------------------------------
Case("the chain lists the prerequisites first, then the quest", function()
    local Q, q = Fixture()
    local steps, own = Q.Chain(q[214])
    assert(#steps == 7 and steps[1] == 65 and steps[6] == 155 and steps[7] == 214 and own == 7)
end)

Case("a Series overlapping the prerequisites lists each step once, in order", function()
    local Q = Fixture()
    local steps, own = Q.Chain({ 700 })
    assert(#steps == 8 and steps[6] == 155 and steps[7] == 700 and steps[8] == 701 and own == 7)
end)

Case("a quest in a Series knows its step", function()
    local Q = Fixture()
    local steps, own = Q.Chain({ 5728 })
    assert(#steps == 4 and own == 2)
    steps, own = Q.Chain({ 914 })
    assert(#steps == 3 and own == 3)
end)

-- Forever's own quests have no Series on Wowhead; the guide's note names the quest before.
local FOLLOW_UPS = {
    { 800, "Elder", 24, "H", "pre", "Somewhere, loot a relic" },
    { 801, "Echo", 24, "H", "pre", "Follow-up from Elder" },
    { 802, "Echo Again", 24, "H", "pre", "Follow-up from Echo" },
    { 810, "Elder", 24, "A", "pre", "Somewhere, loot a relic" },
    { 811, "Prism", 24, "A", "pre", "Follow-up from Elder" },
    { 820, "Brotherhood", 20, "B", "pre", "Follow-up from Red Silk Bandanas" },
}

Case("a follow-up note chains the quest after the one it names", function()
    local Q, q = Fixture({ extra = FOLLOW_UPS })
    local steps, own = Q.Chain(q[801])
    assert(#steps == 3 and steps[1] == 800 and steps[2] == 801 and steps[3] == 802 and own == 2)
    steps, own = Q.Chain(q[800])
    assert(#steps == 3 and own == 1)
    steps, own = Q.Chain(q[802])
    assert(#steps == 3 and own == 3)
end)

Case("a follow-up waits on the quest before it", function()
    local Q, q = Fixture({ extra = FOLLOW_UPS })
    assert(Q.Kind(q[801]) == "prereq" and Q.Kind(q[802]) == "prereq")
    Q, q = Fixture({ extra = FOLLOW_UPS, done = { 800 } })
    assert(Q.Kind(q[801]) == "pickup" and Q.Kind(q[802]) == "prereq")
    Q, q = Fixture({ extra = FOLLOW_UPS, on = { 800 } })
    assert(Q.Kind(q[801]) == "prereqLog")
end)

Case("a follow-up picks its own side's quest of that name", function()
    local Q, q = Fixture({ extra = FOLLOW_UPS })
    local steps = Q.Chain(q[811])
    assert(#steps == 2 and steps[1] == 810 and steps[2] == 811)
end)

Case("a follow-up carries on after the named quest's own prerequisites", function()
    local Q, q = Fixture({ extra = FOLLOW_UPS })
    local steps, own = Q.Chain(q[820])
    assert(#steps == 8 and steps[1] == 65 and steps[7] == 214 and steps[8] == 820 and own == 8)
end)

Case("a quest with neither prerequisites nor a Series has no chain", function()
    local Q, q = Fixture()
    assert(Q.Chain(q[600]) == nil)
end)

Case("each step is done, in the log, or to do", function()
    local Q = Fixture({ on = { 5728 }, done = { 5727 } })
    assert(Q.StepState(5727) == "done")
    assert(Q.StepState(5728) == "active")
    local state, id = Q.StepState(5729)
    assert(state == "todo" and id == 5729)
end)

Case("a step with faction versions is named by the version you have", function()
    local step = { 1490, 1491 }
    local state, id = Fixture({ done = { 1491 } }).StepState(step)
    assert(state == "done" and id == 1491)
    state, id = Fixture({ on = { 1491 } }).StepState(step)
    assert(state == "active" and id == 1491)
    state, id = Fixture().StepState(step)
    assert(state == "todo" and id == 1490)
end)

Case("a step is named by the chain data, the quest data, or its ID", function()
    local Q = Fixture()
    assert(Q.StepName(503) == "Middle" and Q.StepName(600) == "Plain" and Q.StepName(9) == "9")
end)

-------------------------------------------------------------------------------
--  Waypoints
-------------------------------------------------------------------------------
Case("Requires goes to where that step starts", function()
    local Q, q, seen = Fixture({ done = { 65, 132, 135 } })
    Q.Waypoint(q[214])
    local p = seen.placed[1]
    assert(#seen.placed == 1 and p.map == 1436 and p.x == 56.3 and p.note == " (Gryan Stoutmantle)")
end)

Case("a waypoint opens the map to it, out of combat only", function()
    local Q, q, seen = Fixture({ done = { 65, 132, 135 } })
    Q.Waypoint(q[214])
    assert(seen.mapOpened == 1436)
    local Q2, q2, seen2 = Fixture({ done = { 65, 132, 135 }, combat = true })
    Q2.Waypoint(q2[214])
    assert(#seen2.placed == 1 and seen2.mapOpened == nil)
end)

Case("with the gamepad owning the game's panels, the waypoint is set and chat says why the map stays shut", function()
    local Q, q, seen = Fixture({ done = { 65, 132, 135 }, gamepad = true })
    Q.Waypoint(q[214])
    assert(#seen.placed == 1 and seen.mapOpened == nil and #seen.printed == 1)
end)

Case("a step in your log goes where the game routes you", function()
    local Q, q, seen = Fixture({ on = { 141 }, done = { 65, 132, 135 } })
    Q.Waypoint(q[214])
    local p = seen.placed[1]
    assert(#seen.placed == 1 and p.map == 1437 and p.x == 25 and p.y == 75)
end)

Case("a step with nowhere known says so", function()
    local Q, q, seen = Fixture()
    Q.Waypoint(q[214])
    assert(#seen.placed == 0 and seen.printed[1]:find("is not known", 1, true))
end)

Case("a quest to pick up goes to its quest giver", function()
    local Q, q, seen = Fixture({ done = DEFIAS })
    Q.Waypoint(q[214])
    local p = seen.placed[1]
    assert(#seen.placed == 1 and p.map == 1436 and p.x == 56.7 and p.y == 47.4)
end)

Case("a quest in your log: the game's route, else the turn-in, else the quest giver", function()
    local Q, q, seen = Fixture({ on = { 214 } })
    Q.Waypoint(q[214])
    assert(seen.placed[1].map == 1437)
    local J
    Q, q, seen, J = Fixture({ on = { 214 }, noRoute = true })
    J.QuestTurnIns[214] = { 1436, 50, 50, "Gryan Stoutmantle" }
    Q.Waypoint(q[214])
    assert(seen.placed[1].x == 50 and seen.placed[1].note == " (turn in: Gryan Stoutmantle)")
    Q, q, seen = Fixture({ on = { 214 }, noRoute = true })
    Q.Waypoint(q[214])
    assert(seen.placed[1].x == 56.7 and seen.placed[1].note == " (quest giver)")
end)

-------------------------------------------------------------------------------
--  A dungeon map's quest pin: what each of its quests is for you, by what the NPC or
--  object does with it (start, finish, use), the one to show first, and greyed when nothing.
-------------------------------------------------------------------------------
local function PinKinds(Q, pin)
    local kinds = {}
    for i, entry in ipairs(Q.PinQuests(pin, {}, {})) do kinds[i] = entry.quest[1] .. "=" .. entry.kind end
    return table.concat(kinds, " ")
end

Case("a quest pin's giver: ! to pick up, red under its level, grey before its chain", function()
    local Q = Fixture({ level = 20 })
    assert(PinKinds(Q, { start = { 600 } }) == "600=low")
    Q = Fixture({ level = 30 })
    assert(PinKinds(Q, { start = { 600 } }) == "600=pickup")
    Q = Fixture({ level = 30, levels = { [600] = 36 } })
    local entry = Q.PinQuests({ start = { 600 } }, {}, {})[1]
    assert(entry.kind == "pickup" and entry.tooHigh and entry.level == 36)
    Q = Fixture({ level = 30 })
    assert(PinKinds(Q, { start = { 214 } }) == "214=prereq")
    Q = Fixture({ level = 30, done = DEFIAS })
    assert(PinKinds(Q, { start = { 214 } }) == "214=pickup")
end)

Case("a step that is no quest of the list waits on the step before it", function()
    local Q = Fixture()
    assert(PinKinds(Q, { start = { 503 } }) == "503=prereq")
    Q = Fixture({ done = { 502 } })
    assert(PinKinds(Q, { start = { 503 } }) == "503=pickup")
end)

Case("a quest pin's hand-in: grey ? in your log, ? when ready, nothing otherwise", function()
    local Q = Fixture()
    assert(PinKinds(Q, { finish = { 600 } }) == "600=none")
    Q = Fixture({ on = { 600 } })
    assert(PinKinds(Q, { finish = { 600 }, use = { 600 } }) == "600=active")
    Q = Fixture({ on = { 600 }, complete = { 600 } })
    assert(PinKinds(Q, { finish = { 600 } }) == "600=ready")
    assert(PinKinds(Q, { use = { 600 } }) == "600=none")
    assert(Q.PinQuests({ finish = { 600 } }, {}, {})[1].loggedID == 600)
end)

Case("a quest a pin gives and takes is listed once, the best first, greyed when nothing", function()
    local Q = Fixture({ level = 30, on = { 600 }, complete = { 600 } })
    assert(PinKinds(Q, { start = { 503, 600 }, finish = { 600 } }) == "600=ready 503=prereq")
    Q = Fixture({ level = 30, done = { 600 } })
    assert(PinKinds(Q, { start = { 600 }, finish = { 600 } }) == "600=none")
end)

Case("a quest pin's quests for your side and class only", function()
    local Q = Fixture({ level = 30 })
    assert(PinKinds(Q, { start = { { H = 600 } } }) == "")
    assert(PinKinds(Q, { start = { { A = 600, H = 9 } } }) == "600=pickup")
    Q = Fixture({ level = 30, faction = "Horde", done = DEFIAS })
    assert(PinKinds(Q, { start = { 214 } }) == "")
    assert(PinKinds(Q, { start = { { H = 9 } } }) == "9=pickup")
end)

Case("a quest pin reuses its entries and asks the game once for a quest's name", function()
    local Q, _, seen = Fixture({ level = 30 })
    local out, pool = {}, {}
    Q.PinQuests({ start = { 9 } }, out, pool)
    local first = out[1]
    Q.PinQuests({ start = { 9 } }, out, pool)
    assert(out[1] == first and #out == 1 and first.name == "9")
    local asked = 0
    for _, id in ipairs(seen.requested) do
        if id == 9 then asked = asked + 1 end
    end
    assert(asked == 1)
end)

-------------------------------------------------------------------------------
--  The generated data: each step a quest ID or a table of them, none twice, never the quest
--  itself, every step named, and no quest reachable from its own prerequisites.
-------------------------------------------------------------------------------
Case("the generated quest and chain data is well formed and free of loops", function()
    local J = {}
    local env = setmetatable({ _G = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Journal = J } } }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestChains.lua",
        "NaowhForever_DungeonJournal/Data/BiSQuests.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    -- byID: the quests; logged: every ID one of them can be in your log as (its own, an alt,
    -- a step of its chain, a lead-in), which is what a turn-in is keyed by.
    local byID, logged = {}, {}
    local function Log(list)
        for _, step in ipairs(list or {}) do
            for _, id in ipairs(type(step) == "table" and step or { step }) do logged[id] = true end
        end
    end
    for _, dungeon in ipairs(J.QuestData) do
        assert(type(dungeon.name) == "string" and type(dungeon.quests) == "table")
        for _, quest in ipairs(dungeon.quests) do
            assert(type(quest[1]) == "number" and type(quest[2]) == "string", "bad quest")
            assert(quest[4] == "A" or quest[4] == "H" or quest[4] == "B", "bad side for " .. quest[1])
            assert(not quest[7] or (quest[8] > 0 and quest[8] < 100 and quest[9] > 0 and quest[9] < 100),
                "quest giver off the map for " .. quest[1])
            byID[quest[1]], logged[quest[1]] = quest, true
            Log(quest.alt); Log(quest.steps); Log(quest.lead)
        end
    end
    -- The BiS List's quests are quest records too, with their chains in the same data.
    for _, quest in ipairs(J.BiSQuestData.quests) do
        assert(type(quest[1]) == "number" and type(quest[2]) == "string", "bad BiS quest")
        assert(quest[4] == "A" or quest[4] == "H" or quest[4] == "B", "bad side for " .. quest[1])
        assert(not quest[7] or (quest[8] > 0 and quest[8] < 100 and quest[9] > 0 and quest[9] < 100),
            "quest giver off the map for " .. quest[1])
        byID[quest[1]] = byID[quest[1]] or quest
        logged[quest[1]] = true
    end
    local function IDs(step)
        if type(step) == "number" then return { step } end
        assert(type(step) == "table" and #step > 0, "a step is an ID or a table of IDs")
        for _, id in ipairs(step) do assert(type(id) == "number" and id > 0, "bad ID") end
        return step
    end
    local lists = 0
    for questID, list in pairs(J.QuestPrereqs) do
        assert(byID[questID], "prerequisites for " .. questID .. ", which is not a quest in the data")
        assert(type(list) == "table" and #list > 0, "empty list for " .. questID)
        local seen = {}
        for _, step in ipairs(list) do
            for _, id in ipairs(IDs(step)) do
                assert(id ~= questID, questID .. " is among its own prerequisites")
                assert(not seen[id], questID .. " lists " .. id .. " twice")
                seen[id] = true
                assert(J.QuestChainNames[id] or byID[id], "no name for quest " .. id)
            end
        end
        lists = lists + 1
    end
    -- Depth-first over quest -> each ID of its prerequisites; a quest met again while its
    -- own walk is open is a loop.
    local state = {}
    local function Walk(id)
        if state[id] == "open" then error("prerequisite loop through quest " .. id) end
        if state[id] == "done" then return end
        state[id] = "open"
        for _, step in ipairs(J.QuestPrereqs[id] or {}) do
            for _, other in ipairs(IDs(step)) do Walk(other) end
        end
        state[id] = "done"
    end
    for questID in pairs(J.QuestPrereqs) do Walk(questID) end
    for questID, level in pairs(J.QuestMinLevel) do
        assert(byID[questID], "a level for " .. questID .. ", which is not a dungeon quest")
        assert(type(level) == "number" and level >= 1 and level <= 60 and level % 1 == 0)
    end
    for questID, where in pairs(J.QuestWhere) do
        assert(J.QuestPrereqs[questID] and type(where) == "string" and where ~= "")
    end
    for _, series in pairs(J.QuestChains) do
        for _, step in ipairs(series) do
            for _, id in ipairs(IDs(step)) do
                assert(J.QuestChainNames[id] or byID[id], "no name for quest " .. id)
            end
        end
    end
    for id, start in pairs(J.QuestChainStarts) do
        assert(type(start[1]) == "number" and start[2] > 0 and start[2] < 100 and start[3] > 0
            and start[3] < 100 and type(start[4]) == "string", "bad start for " .. id)
    end
    for id, turnIn in pairs(J.QuestTurnIns) do
        assert(logged[id], "a turn-in for " .. id .. ", which is no quest here")
        assert(type(turnIn[1]) == "number" and turnIn[2] > 0 and turnIn[2] < 100 and turnIn[3] > 0
            and turnIn[3] < 100 and type(turnIn[4]) == "string", "bad turn-in for " .. id)
    end
    -- The example the feature started from.
    local bandanas = J.QuestPrereqs[214]
    assert(bandanas and bandanas[1] == 65 and #bandanas == 6, "Red Silk Bandanas starts with 65, 6 steps")
    assert(J.QuestMinLevel[214] == 14)
    -- Old Ironforge Incursion needs Underground Map, which an item Captain Beld drops begins.
    assert(J.QuestChainStarts[96391], "Underground Map has no start")
    assert(lists > 50, "only " .. lists .. " lists")
end)

Case("every quest in a generated chain is in its own chain", function()
    local J = {}
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Journal = J,
        OnApply = function() end }
    local env = setmetatable({ _G = { NaowhForever = ns }, C_QuestLog = {},
        UnitFactionGroup = function() return "Alliance" end }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestChains.lua",
                            "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/Quests.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local chained = 0
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            if J.QuestChains[quest[1]] then
                assert(J.Quests.Chain(quest), "quest " .. quest[1] .. " is not in its own chain")
                chained = chained + 1
            end
        end
    end
    assert(chained > 0)
    local echo = J.Quests.ByID(98823)
    local steps, own = J.Quests.Chain(echo)
    assert(steps and steps[own - 1] == 95664, "Earthen Echo is not after Elder Knowledge")
    assert(J.Quests.Chain(J.Quests.ByID(95664)), "Elder Knowledge has no chain")
end)

Case("the generated quest help data names real quests and items", function()
    local J = {}
    local env = setmetatable({ _G = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Journal = J } } },
        { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestHelp.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local byID = {}
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do byID[quest[1]] = quest end
    end
    for id, list in pairs(J.QuestClosedBy) do
        assert(byID[id], "a quest closed that is not listed: " .. id)
        for _, other in ipairs(list) do
            assert(other ~= id and (byID[other] or J.QuestClosedByNames[other]), "no name for closer " .. other)
        end
    end
    -- In Search of Thaelrid is lost once Blackfathom Villainy is taken; Valthalak's pieces are one per dungeon.
    assert(J.QuestClosedBy[1198][1] == 1200)
    assert(#J.QuestClosedBy[8966] == 3)
    for id, items in pairs(J.QuestItems) do
        for _, item in ipairs(items) do
            assert(item[1] > 0 and item[2] > 0, "bad item for " .. id)
            assert(item[3] == nil or item[2] == 1, "a boss gives one, not " .. item[2])
        end
    end
    assert(J.QuestItems[1200][1][1] == 5881 and J.QuestItems[1200][1][3] == 4832, "Head of Kelris from Kelris")
    assert(J.QuestItems[2770][1][3] == 7273, "the scale from Gahz'rilla")
end)

Case("the generated quest rewards are for listed quests, each item a choice or a gift, never both", function()
    local J = {}
    local env = setmetatable({ _G = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Journal = J } } },
        { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestRewards.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local listed = {}
    local function List(value)
        if type(value) == "table" then
            for _, v in ipairs(value) do List(v) end
        else
            listed[value] = true
        end
    end
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            listed[quest[1]] = true
            List(quest.steps or {})
        end
    end
    for id, rewards in pairs(J.QuestRewards) do
        assert(listed[id], "rewards for a quest the Journal does not list: " .. id)
        local choose, get = rewards.choose or {}, rewards.get or {}
        assert(#choose + #get > 0, "an empty reward entry for " .. id)
        local seen = {}
        for _, item in ipairs(choose) do seen[item] = true end
        for _, item in ipairs(get) do assert(not seen[item], id .. " both offers and gives " .. item) end
    end
    -- Vorrel's Revenge: a cape or a mantle, and his boots as well; Deviate Hides is a pick of two.
    local vorrel = J.QuestRewards[1051]
    assert(#vorrel.choose == 2 and vorrel.get[1] == 7751, "Vorrel's Revenge rewards")
    assert(#J.QuestRewards[1486].choose == 2 and J.QuestRewards[1486].get == nil, "Deviate Hides rewards")
end)

Case("every quest tip is on a listed quest or a step of one's chain", function()
    local J = {}
    local env = setmetatable({ _G = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Journal = J } } },
        { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestChains.lua",
        "NaowhForever_DungeonJournal/Data/QuestTips.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local reached = {}
    local function Reach(list)
        for _, step in ipairs(list or {}) do
            for _, id in ipairs(type(step) == "table" and step or { step }) do reached[id] = true end
        end
    end
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            reached[quest[1]] = true
            Reach(J.QuestPrereqs[quest[1]])
            Reach(J.QuestChains[quest[1]])
        end
    end
    local tips = 0
    for id, tip in pairs(J.QuestTips) do
        tips = tips + 1
        assert(reached[id], "a tip for a quest the Journal never shows: " .. id)
        assert(type(tip) == "string" and tip:find("^%u") and tip:find("%.$"), "tip " .. id .. " is not one sentence")
        assert(not tip:find("[\128-\255]"), "tip " .. id .. " is not ASCII")
    end
    assert(tips > 0 and J.QuestTips[2201]:find("last boss", 1, true), "Find the Gems' tip")
end)

print(("test-journal-quests: %d cases passed"):format(count))
