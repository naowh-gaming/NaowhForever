-- Run with Lua 5.1 from the repository root: the Dungeon Journal's runs (NaowhForever_DungeonJournal/Runs.lua,
-- on the real Kills.lua and Team.lua). A run starts at the door and keeps each boss's split, the gold, XP,
-- deaths, trash and Need rolls; it is finished once every numbered boss of a wing is dead; bests and
-- averages leave out the run asked about and reset runs; leaving and coming back adds the time outside;
-- a new copy of the instance starts a new run; a boss of another dungeon on the same instance map (a
-- Scarlet Monastery wing) starts that dungeon's run; a run with nothing in it is not kept; and nothing is
-- listened to while the Run Panel is off.
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local SECRET = {}
local DEADMINES_MAP = 36
local NEED, GREED = 0, 3

local Frame = {}
local methods = {}
Frame.__index = function(_, key) return methods[key] or function() end end

function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:UnregisterAllEvents() self.events = {} end

local function Dungeons()
    return { { key = "Deadmines", name = "The Deadmines", instance = DEADMINES_MAP, wings = { { bosses = {
        { npc = 1, name = "Rhahk'Zor", encounters = { 1 } },
        { npc = 20, name = "Sneed's Shredder", encounters = { 2 }, with = "Sneed" },
        { npc = 2, name = "Sneed", encounters = { 2 } },
        { npc = 9, name = "Miner Johnson", rare = true, encounters = { 9 } },
        { npc = 3, name = "Edwin VanCleef", encounters = { 3 } },
        { name = "Trash", trash = true },
    } } } }, { key = "Library", name = "Library", instance = DEADMINES_MAP, wings = { { bosses = {
        { npc = 30, name = "Houndmaster Loksey", encounters = { 30 } },
        { npc = 31, name = "Arcanist Doan", encounters = { 31 } },
    } } } } }
end

local function Fixture(opts)
    opts = opts or {}
    local seen = { frames = {}, now = 1000, inside = false, account = {}, settings = {}, xp = 100, xpMax = 1000,
        drops = {} }
    local values = { enabled = true, runPanel = opts.on ~= false }
    local listeners, applied, lootListeners = {}, {}, {}
    local S = {
        Get = function(key) return values[key] end,
        Set = function(key, value)
            values[key] = value
            for _, fn in ipairs(listeners) do fn(key, value) end
        end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
    }
    local dungeons = Dungeons()
    local byNpc = {}
    for _, boss in ipairs(dungeons[1].wings[1].bosses) do
        if boss.npc then byNpc[boss.npc] = boss end
    end
    local function Split(sep, text)
        local out = {}
        for part in (text .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
        return unpack(out)
    end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L,
        Print = function() end,
        AccountSettings = function() return seen.settings end,
        Shared = { LayerOf = function(guid)
            if type(guid) ~= "string" then return end
            local kind, _, server, _, zone = Split("-", guid)
            if kind ~= "Creature" then return end
            return server .. "-" .. zone, tonumber(zone)
        end },
        Journal = {
            Settings = S,
            C = { SECONDS_PER_MINUTE = 60, ROUND_HALF = 0.5 },
            View = { Parts = { FightLength = function(s) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end } },
            Looted = { OnAdd = function(fn) lootListeners[#lootListeners + 1] = fn end },
            Dungeons = function() return dungeons end,
            Get = function(key) return key == "Deadmines" and dungeons[1] or key == "Library" and dungeons[2] or nil end,
            Current = function() if seen.inside then return { dungeons[seen.here or 1] } end end,
            Boss = function(npc) return byNpc[npc] end,
            NpcID = function(guid)
                local kind, _, _, _, _, id = Split("-", guid)
                if kind == "Creature" then return tonumber(id) end
            end,
            RedrawDungeonMaps = function() end,
            CharacterData = function(key, create)
                local mine = seen.account[key]
                if mine == nil and create then
                    mine = {}
                    seen.account[key] = mine
                end
                return mine
            end,
        },
    }
    local J = ns.Journal
    function J.Numbered(boss)
        return not (boss.rare or boss.optional or boss.quest or boss.chest or boss.trash)
    end
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        CreateFrame = function()
            local f = setmetatable({ scripts = {}, events = {} }, Frame)
            seen.frames[#seen.frames + 1] = f
            return f
        end,
        issecretvalue = function(v) return v == SECRET end,
        time = function() return seen.now end,
        GetTime = function() return seen.now end,
        IsLoggedIn = function() return true end,
        GetInstanceInfo = function() return "", "party", 1, "", 5, 0, false, DEADMINES_MAP end,
        UnitXP = function() return seen.xp end,
        UnitXPMax = function() return seen.xpMax end,
        UnitName = function() return "Glyadin" end,
        UnitGUID = function(unit) return seen.guids and seen.guids[unit] end,
        UnitClass = function() return "Paladin", "PALADIN" end,
        UnitGroupRolesAssigned = function() return "NONE" end,
        IsInRaid = function() return false end,
        GetNumSubgroupMembers = function() return 0 end,
        GOLD_AMOUNT = "%d Gold", SILVER_AMOUNT = "%d Silver", COPPER_AMOUNT = "%d Copper",
        Enum = { EncounterLootDropRollState = { NeedMainSpec = 0, NeedOffSpec = 1 } },
        C_LootHistory = { GetSortedInfoForDrop = function(enc, key) return seen.drops[enc .. ":" .. key] end },
        strsplit = Split,
    }, { __index = _G })
    function ns.OnApply(fn) applied[#applied + 1] = fn end
    for _, path in ipairs({ "Team.lua", "Kills.lua", "Runs.lua" }) do
        local chunk = assert(loadfile("NaowhForever_DungeonJournal/" .. path))
        setfenv(chunk, env)
        chunk()
    end
    for _, fn in ipairs(applied) do fn() end

    function seen.Fire(event, ...)
        for _, f in ipairs(seen.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end
    function seen.Listening(event)
        for _, f in ipairs(seen.frames) do
            if f.events[event] then return true end
        end
        return false
    end
    function seen.Enter(login)
        seen.inside = true
        seen.Fire("PLAYER_ENTERING_WORLD", login == true, false)
    end
    function seen.Leave(login)
        seen.inside = false
        seen.Fire("PLAYER_ENTERING_WORLD", login == true, false)
    end
    function seen.Kill(encounterID, after)
        seen.now = seen.now + (after or 0)
        seen.Fire("ENCOUNTER_START", encounterID)
        seen.Fire("ENCOUNTER_END", encounterID, "", 1, 5, 1)
    end
    function seen.Loot(item)
        item.at = item.at or seen.now
        for _, fn in ipairs(lootListeners) do fn(item) end
    end
    seen.S, seen.J, seen.Runs, seen.dungeon = S, J, J.Runs, dungeons[1]
    seen.boss = function(npc) return byNpc[npc] end
    return seen
end

Case("a run starts at the door and keeps each boss's split from it", function()
    local w = Fixture()
    w.Enter()
    local run = w.Runs.Open()
    assert(run and run.start == 1000 and run.dungeon == "Deadmines", "a run is open from the door")
    w.Kill(1, 120)
    w.Kill(2, 200)
    assert(w.Runs.Split(run, w.boss(1)) == 120 and w.Runs.Split(run, w.boss(2)) == 320, "splits from the door")
    assert(not run.done, "not finished with VanCleef alive")
end)

Case("every numbered boss of a wing dead finishes the run; a rare is not needed", function()
    local w = Fixture()
    local done
    w.Runs.OnChange(function(kind) if kind == "done" then done = (done or 0) + 1 end end)
    w.Enter()
    w.Kill(1, 60)
    w.Kill(2, 60)
    w.Kill(3, 60)
    local run = w.Runs.Open()
    assert(run.done == 180 and run.wing == 1 and done == 1, "finished at VanCleef, once")
    w.Kill(9, 30)
    assert(run.done == 180 and done == 1, "a rare after it changes nothing")
end)

Case("gold, XP, deaths and trash are counted; a boss and the same mob twice are not trash", function()
    local w = Fixture()
    w.Enter()
    w.Fire("CHAT_MSG_MONEY", "You loot 1 Gold, 2 Silver, 3 Copper")
    w.Fire("CHAT_MSG_MONEY", "Your share of the loot is 5 Silver.")
    w.Fire("CHAT_MSG_MONEY", SECRET)
    w.xp = 400
    w.Fire("PLAYER_XP_UPDATE", "player")
    w.xp, w.xpMax = 50, 1200
    w.Fire("PLAYER_XP_UPDATE", "player")
    w.Fire("PLAYER_DEAD")
    w.Fire("PARTY_KILL", "Player-1", "Creature-0-1-2-3-500-AA")
    w.Fire("PARTY_KILL", "Player-1", "Creature-0-1-2-3-500-AA")
    w.Fire("PARTY_KILL", "Player-1", "Creature-0-1-2-3-501-BB")
    w.Fire("PARTY_KILL", "Player-1", "Creature-0-1-2-3-3-CC")
    w.Fire("PARTY_KILL", "Player-1", SECRET)
    local run = w.Runs.Open()
    assert(run.copper == 10203 + 500, "both money lines, the secret one skipped")
    assert(run.xp == 300 + 600 + 50, "XP across a level up")
    assert(run.deaths == 1 and run.trash == 2, "one death, two trash")
end)

Case("a finished run teaches the dungeon's trash count", function()
    local w = Fixture()
    w.Enter()
    for i = 1, 30 do w.Fire("PARTY_KILL", "Player-1", "Creature-0-1-2-3-500-" .. i) end
    assert(w.Runs.TrashTotal("Deadmines") == nil, "unknown before a finished run")
    w.Kill(1)
    w.Kill(2)
    w.Kill(3)
    assert(w.Runs.TrashTotal("Deadmines") == 30, "learned at the end")
end)

Case("only your own Need rolls are counted, each drop once", function()
    local w = Fixture()
    w.Enter()
    w.drops["1:1"] = { winner = {}, rollInfos = { { isSelf = true, state = NEED, isWinner = true } } }
    w.drops["1:2"] = { winner = {}, rollInfos = { { isSelf = false, state = NEED, isWinner = true },
        { isSelf = true, state = NEED, isWinner = false } } }
    w.drops["1:3"] = { winner = {}, rollInfos = { { isSelf = true, state = GREED, isWinner = true } } }
    w.drops["1:4"] = { rollInfos = { { isSelf = true, state = NEED } } }
    for key = 1, 4 do w.Fire("LOOT_HISTORY_UPDATE_DROP", 1, key) end
    w.Fire("LOOT_HISTORY_UPDATE_DROP", 1, 1)
    local run = w.Runs.Open()
    assert(run.needWon == 1 and run.needLost == 1, "a win and a loss, greed and an open roll left out")
end)

Case("loot from the run is kept, loot from before it is not", function()
    local w = Fixture()
    w.Enter()
    w.Loot({ id = 5, link = "[Cape]", boss = "Edwin VanCleef" })
    w.Loot({ id = 6, link = "[Old]", at = 10 })
    local run = w.Runs.Open()
    assert(#run.loot == 1 and run.loot[1].id == 5, "only this run's loot")
end)

Case("bests and averages leave out the run asked about", function()
    local w = Fixture()
    w.Enter()
    w.Kill(1, 100)
    w.Kill(2, 100)
    w.Kill(3, 100)
    local first = w.Runs.Open()
    w.Leave(true)
    w.now = w.now + 10000
    w.Enter()
    w.Kill(1, 80)
    local second = w.Runs.Open()
    assert(second ~= first and first.ended, "a new run, the old one closed")
    assert(w.Runs.BestSplit("Deadmines", w.boss(1), second) == 100, "the other run's split")
    assert(w.Runs.BestSplit("Deadmines", w.boss(1)) == 80, "both runs")
    assert(w.Runs.AverageSplit("Deadmines", w.boss(1)) == 90, "the average")
    assert(w.Runs.BestTime("Deadmines", 1, second) == 300, "the finished run's time")
    assert(w.Runs.IsBest(first), "the only finished run is the best")
    w.Kill(2, 60)
    w.Kill(3, 60)
    assert(second.done == 200 and w.Runs.IsBest(second) and not w.Runs.IsBest(first), "beaten")
    local out = w.Runs.Summary("Deadmines", {})
    assert(out.runs == 2 and out.finished == 2 and out.best == 200 and out.time == 250, "the summary")
end)

Case("a boss of the run killed again starts a reset run that sets no bests", function()
    local w = Fixture()
    w.Enter()
    w.Kill(1, 100)
    local first = w.Runs.Open()
    w.Kill(1, 600)
    local reset = w.Runs.Open()
    assert(reset ~= first and reset.partial and reset.start == w.now, "a new run from the kill")
    assert(w.Runs.Split(reset, w.boss(1)) == 0, "its split")
    assert(w.Runs.BestSplit("Deadmines", w.boss(1)) == 100, "left out of bests")
end)

Case("leaving and coming back adds the time outside to the same run", function()
    local w = Fixture()
    w.Enter()
    local run = w.Runs.Open()
    w.now = w.now + 50
    w.Leave()
    assert(run.leftAt == 1050 and not w.Runs.Inside(), "outside")
    assert(not w.Listening("PARTY_KILL"), "nothing counted outside")
    w.now = w.now + 40
    w.Enter()
    assert(w.Runs.Open() == run and run.out == 40 and w.Runs.Inside(), "the same run, 40s outside")
end)

Case("logging in outside closes the run", function()
    local w = Fixture()
    w.Enter()
    local run = w.Runs.Open()
    w.Leave(true)
    assert(run.ended and w.Runs.Open() == nil, "closed")
end)

Case("a reset instance seen on coming back starts a new run from the door, its bosses alive", function()
    local w = Fixture()
    w.Enter()
    w.Fire("PARTY_KILL", "Player-1", "Creature-0-1-36-700-500-AA")
    w.Kill(1, 60)
    local first = w.Runs.Open()
    w.now = w.now + 30
    w.Leave()
    w.now = w.now + 120
    w.Enter()
    assert(w.Runs.Open() == first, "back within the grace, still the same run until the copy is seen")
    w.guids = { nameplate1 = "Creature-0-1-36-701-500-BB" }
    w.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local second = w.Runs.Open()
    assert(second ~= first and first.ended, "a new copy, a new run")
    assert(second.start == w.now and not second.partial, "from the door, not a reset run")
    assert(w.Runs.Split(second, w.boss(1)) == nil, "Rhahk'Zor is alive again")
    w.Kill(1, 90)
    assert(w.Runs.Open() == second and w.Runs.Split(second, w.boss(1)) == 90, "its kill is in the new run")
    w.guids = { target = "Creature-0-1-36-701-501-CC" }
    w.Fire("PLAYER_TARGET_CHANGED")
    assert(w.Runs.Open() == second, "the same copy changes nothing")
end)

Case("a boss of another dungeon on the same instance map starts that dungeon's run", function()
    local w = Fixture()
    w.Enter()
    w.Kill(1, 60)
    w.Kill(2, 60)
    w.Kill(3, 60)
    local first = w.Runs.Open()
    w.now = w.now + 30
    w.Leave()
    w.now = w.now + 120
    w.here = 2
    w.Enter()
    local entered = w.now
    w.Kill(30, 100)
    local second = w.Runs.Open()
    assert(second ~= first and first.ended and first.done == 180, "the first run kept, finished")
    assert(second.dungeon == "Library" and second.start == entered and not second.partial, "from the door")
    assert(w.Runs.Split(second, w.boss(1)) == nil and second.kills[30] == 100, "only its own boss")
    w.Kill(31, 50)
    assert(second.done == 150 and w.Runs.BestTime("Library") == 150, "finished, and its own best")
    assert(w.Runs.BestTime("Deadmines") == 180, "the first dungeon's best unchanged")
end)

Case("another dungeon's boss without leaving the instance starts a run that sets no bests", function()
    local w = Fixture()
    w.Enter()
    w.Kill(1, 60)
    w.Kill(30, 60)
    local second = w.Runs.Open()
    assert(second.dungeon == "Library" and second.partial, "the time from the door holds the other dungeon")
end)

Case("a run with nothing in it is not kept", function()
    local w = Fixture()
    w.Enter()
    w.Leave(true)
    assert(#w.Runs.List() == 0, "an empty visit is dropped")
end)

Case("deleting a run removes it", function()
    local w = Fixture()
    w.Enter()
    local run = w.Runs.Open()
    w.Runs.Delete(run)
    assert(#w.Runs.List() == 0 and w.Runs.Open() == nil, "gone")
end)

Case("nothing is kept or listened to while the Run Panel is off", function()
    local w = Fixture({ on = false })
    w.Enter()
    w.Kill(1, 10)
    assert(w.Runs.Open() == nil and w.account.journalRuns == nil, "no run kept")
    for _, event in ipairs({ "CHAT_MSG_MONEY", "PLAYER_XP_UPDATE", "PLAYER_DEAD", "PARTY_KILL" }) do
        assert(not w.Listening(event), event .. " not listened to")
    end
    w.S.Set("runPanel", true)
    assert(w.Runs.Open() and w.Listening("PARTY_KILL"), "turned on inside, it starts")
    w.S.Set("runPanel", false)
    assert(not w.Listening("PARTY_KILL"), "turned off, it stops")
end)

print(("%d cases passed"):format(count))
