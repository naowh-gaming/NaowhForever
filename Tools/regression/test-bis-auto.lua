-- BiS Auto list: each slot gets the items worth most to the spec's weights, from what you wear and
-- the pool, that need no more than Levels Ahead (default 5) levels over yours; a one-hander counts
-- the best off hand beside it; Ring 2 skips Ring 1's pick; an item not loaded yet is asked for and
-- waited on; a kept slot is never refilled.
local Load = dofile("Tools/regression/load_files.lua")
local FILES = { "NaowhForever_BiS/BiS/BiS.lua", "NaowhForever_BiS/BiS/Constants.lua", "NaowhForever_BiS/BiS/Auto.lua" }

local EQUIP = {
    [1] = "head", [2] = "head", [3] = "head", [4] = "head", [5] = "head",
    [10] = "ring", [11] = "ring", [12] = "ring",
    [20] = "one", [21] = "two", [22] = "off",
    [30] = "trinket", [31] = "trinket", [32] = "trinket", [33] = "trinket",
}
local SLOTS = { head = { 1 }, ring = { 11, 12 }, one = { 16, 17 }, two = { 16 }, off = { 17 }, trinket = { 13, 14 } }

local function Fixture(o)
    local requested, timers, frame = {}, {}, { events = {} }
    local list = o.list or { auto = true, slots = {}, extra = {} }
    local spec = { key = "arms-warrior", slots = o.ranked or {}, trinkets = o.trinkets }
    local ns = { QoLSettings = {
        Get = function(key) if key == "bisAutoAhead" then return o.ahead or 5 end return true end,
        OnChange = function(fn) o.onSetting = fn end },
        BiSLeveling = { levels = { 30 } }, Apply = function() end }
    function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end
    ns.Shared = { Items = {
        GEAR_SLOTS = { { 1 }, { 11 }, { 12 }, { 13 }, { 14 }, { 16 }, { 17 } },
        SlotsFor = function(id) return SLOTS[EQUIP[id]] end,
        IsTwoHand = function(id) return EQUIP[id] == "two" end,
        PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 },
    } }
    ns.UI = {}
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        UnitLevel = function() return o.level or 20 end,
        GetInventoryItemID = function(_, slot) return (o.worn or {})[slot] end,
        GetInventoryItemLink = function(_, slot) return (o.worn or {})[slot] and "worn:" .. o.worn[slot] end,
        C_Item = { RequestLoadItemDataByID = function(id) requested[id] = true end },
        C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
        CreateFrame = function()
            function frame.SetScript(_, _, fn) frame.script = fn end
            function frame.RegisterEvent(_, event) frame.events[event] = true end
            function frame.UnregisterEvent(_, event) frame.events[event] = nil end
            return frame
        end,
        hooksecurefunc = function() end,
        GetTime = function() return o.now or 0 end,
    }, { __index = _G })
    env.ns = ns
    Load({ FILES[1], FILES[2] }, env)
    local B = ns.BiS
    B.Rankings = {
        Candidates = function(slot, s) return s.slots[slot] or {} end,
        DungeonDrops = function(slot) return (o.drops or {})[slot] or {} end,
        LevelPicks = function() return o.levelPicks end,
        Wieldable = function() return true end,
        NeedLevel = function(id) return math.max((o.req or {})[id] or 1, (o.questLevel or {})[id] or 0) end,
        OtherSideQuest = function(id) return (o.otherSide or {})[id] == true end,
    }
    B.Lists = { CurrentSpec = function() return spec end, List = function() return o.list or list end,
        Changed = function() end }
    local loading = o.loading or {}
    ns.StatWeights = {
        For = function(key) o.weightsFor = key return o.weights or { str = 1 } end,
        Usable = function(id) if loading[id] then return nil end return true end,
        Stats = function(item)
            local id = type(item) == "number" and item or tonumber(item:match("%d+"))
            if loading[id] then return nil end
            return { str = o.worth[id] or 0, agi = (o.agi or {})[id] or 0 }
        end,
        Worth = function(stats, weights) return stats.str * weights.str + stats.agi * (weights.agi or 0) end,
        DpsShare = function() return 1 end,
        OnChange = function(fn) o.onWeights = fn end,
    }
    Load({ FILES[3] }, env)
    return { Auto = B.Auto, list = list, spec = spec, requested = requested, B = B, timers = timers, frame = frame }
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end
local function Join(t) return table.concat(t, ",") end

Case("a slot's picks are best first, up to three, and none past Levels Ahead (default 5)", function()
    local m = Fixture({ level = 20, ranked = { [1] = { 1, 2, 3, 4, 5 } },
        req = { [5] = 26, [4] = 25 }, worth = { [1] = 1, [2] = 4, [3] = 3, [4] = 9, [5] = 20 } })
    local picks = m.Auto.Build(m.spec)
    assert(Join(picks[1]) == "4,2,3", Join(picks[1]))
end)

Case("picks follow the spec's own weights, and a level up lets the next items in", function()
    local o = { level = 20, ranked = { [1] = { 1, 2, 3 } }, req = { [3] = 26 },
        worth = { [1] = 5, [2] = 1, [3] = 9 }, agi = { [2] = 5 } }
    local m = Fixture(o)
    assert(Join(m.Auto.Build(m.spec)[1]) == "1,2", "level 20: 3 needs 26")
    assert(o.weightsFor == "arms-warrior", "weighed by the list's spec")
    o.weights = { str = 1, agi = 2 }
    assert(Join(m.Auto.Build(m.spec)[1]) == "2,1", "Agility weighed up: the Agility item first")
    o.level = 21
    assert(Join(m.Auto.Build(m.spec)[1]) == "2,3,1", "level 21: 3 is within 5 levels")
end)

Case("Levels Ahead sets how far over your level the picks reach, and a change refills the list", function()
    local o = { level = 20, ranked = { [1] = { 1, 2, 3 } }, req = { [2] = 21, [3] = 30 },
        worth = { [1] = 1, [2] = 2, [3] = 3 }, ahead = 0 }
    o.list = { id = 1, auto = true, slots = {}, extra = {} }
    local m = Fixture(o)
    assert(Join(m.Auto.Build(m.spec)[1]) == "1", "0 ahead: only what you can wear now")
    o.ahead = 10
    assert(Join(m.Auto.Build(m.spec)[1]) == "3,2,1", "10 ahead: up to level 30")
    m.B.ListChanged()
    m.timers[1]()
    o.ahead = 1
    o.onSetting("bisAutoAhead")
    assert(#m.timers == 2, "the change queues a refill")
    m.timers[2]()
    assert(o.list.slots[1] == 2 and o.list.extra[1][1] == 1, "refilled to level 21")
end)

Case("a quest reward is held back until its quest's level is within Levels Ahead", function()
    local o = { level = 16, ranked = { [1] = { 1, 2 } }, req = { [1] = 10, [2] = 10 }, questLevel = { [1] = 45 },
        worth = { [1] = 9, [2] = 1 } }
    local m = Fixture(o)
    assert(Join(m.Auto.Build(m.spec)[1]) == "2", "level 16: a level 45 quest's reward waits")
    o.level = 40
    assert(Join(m.Auto.Build(m.spec)[1]) == "1,2", "level 40: the quest is within 5 levels")
end)

Case("what you wear competes, so the list never asks you to wear worse", function()
    local m = Fixture({ worn = { [1] = 3 }, ranked = { [1] = { 1, 2 } }, worth = { [1] = 1, [2] = 2, [3] = 5 } })
    assert(m.Auto.Build(m.spec)[1][1] == 3)
end)

Case("the pool is the ranking, the dungeon drops and the leveling lists", function()
    local m = Fixture({ drops = { [1] = { 1 } }, levelPicks = { [1] = 2 }, worth = { [1] = 1, [2] = 2 } })
    assert(Join(m.Auto.Build(m.spec)[1]) == "2,1")
end)

Case("Ring 2 skips Ring 1's pick, and a worn ring counts for either", function()
    local m = Fixture({ worn = { [12] = 12 }, ranked = { [11] = { 10, 11 } }, worth = { [10] = 2, [11] = 1, [12] = 5 } })
    local picks = m.Auto.Build(m.spec)
    assert(picks[11][1] == 12 and picks[12][1] == 10, Join(picks[11]) .. " / " .. Join(picks[12]))
end)

Case("trinkets go in sim order, those the sim did not rank after them by weights", function()
    local m = Fixture({ level = 20, trinkets = { 32, 31, 33 }, ranked = { [13] = { 30 } }, req = { [32] = 60 },
        worth = { [30] = 9, [31] = 1, [32] = 2, [33] = 0 } })
    local picks = m.Auto.Build(m.spec)
    assert(Join(picks[13]) == "31,33,30", Join(picks[13]))
    assert(picks[14][1] == 33, "Trinket 2 skips Trinket 1's pick")
    m = Fixture({ ranked = { [13] = { 30, 31 } }, worth = { [30] = 1, [31] = 2 } })
    assert(Join(m.Auto.Build(m.spec)[13]) == "31,30", "no sim order: by weights")
end)

Case("a sim trinket from the other side's quest is never picked", function()
    local m = Fixture({ trinkets = { 32, 31, 33 }, otherSide = { [32] = true },
        worth = { [31] = 1, [32] = 9, [33] = 0 } })
    local picks = m.Auto.Build(m.spec)
    assert(Join(picks[13]) == "31,33", Join(picks[13]))
end)

Case("a two-hander wins only when it beats a one-hander and the best off hand together", function()
    local m = Fixture({ ranked = { [16] = { 20, 21 }, [17] = { 22 } }, worth = { [20] = 3, [21] = 5, [22] = 3 } })
    local picks = m.Auto.Build(m.spec)
    assert(picks[16][1] == 20 and picks[17][1] == 22, Join(picks[16]))
    m = Fixture({ ranked = { [16] = { 20, 21 }, [17] = { 22 } }, worth = { [20] = 3, [21] = 7, [22] = 3 } })
    assert(m.Auto.Build(m.spec)[16][1] == 21)
end)

Case("a two-hander as the main hand's pick leaves the off hand empty", function()
    local m = Fixture({ ranked = { [16] = { 20, 21 }, [17] = { 22 } }, worth = { [20] = 3, [21] = 7, [22] = 3 } })
    local picks = m.Auto.Build(m.spec)
    assert(picks[16][1] == 21 and #picks[17] == 0, Join(picks[17]))
end)

Case("an item not loaded yet is asked for and waited on, not picked", function()
    local m = Fixture({ ranked = { [1] = { 1, 2 } }, worth = { [1] = 1, [2] = 9 }, loading = { [2] = true } })
    local picks, waiting = m.Auto.Build(m.spec)
    assert(waiting and m.requested[2] and Join(picks[1]) == "1")
end)

Case("filling leaves a kept slot as you set it, and says when nothing changed", function()
    local list = { auto = true, slots = { [1] = 1 }, extra = {}, kept = { [1] = true } }
    local m = Fixture({ list = list, ranked = { [1] = { 1, 2 }, [11] = { 10 } }, worth = { [1] = 1, [2] = 9, [10] = 1 } })
    assert(m.Auto.Fill(list) == true)
    assert(list.slots[1] == 1 and list.extra[1] == nil, "kept slot untouched")
    assert(list.slots[11] == 10)
    assert(m.Auto.Fill(list) == false, "the same picks again are no change")
end)

Case("a worn item not loaded yet is asked for and waited on too", function()
    local m = Fixture({ worn = { [1] = 3 }, ranked = { [1] = { 1 } }, worth = { [1] = 1, [3] = 5 }, loading = { [3] = true } })
    local _, waiting = m.Auto.Build(m.spec)
    assert(waiting and m.requested[3] and m.frame.events.GET_ITEM_INFO_RECEIVED)
end)

Case("only an awaited item the server sends wakes it; a refused one does not", function()
    local m = Fixture({ ranked = { [1] = { 1, 2 } }, worth = { [1] = 1, [2] = 9 }, loading = { [2] = true } })
    m.Auto.Build(m.spec)
    m.frame.script(m.frame, "GET_ITEM_INFO_RECEIVED", 2, false)
    m.frame.script(m.frame, "GET_ITEM_INFO_RECEIVED", 99, true)
    assert(#m.timers == 0, "refused or unawaited: nothing queued")
    m.frame.script(m.frame, "GET_ITEM_INFO_RECEIVED", 2, true)
    assert(#m.timers == 1)
end)

Case("switching to another Auto list refills it", function()
    local o = { ranked = { [1] = { 1 } }, worth = { [1] = 1 } }
    o.list = { id = 1, auto = true, slots = {}, extra = {} }
    local m = Fixture(o)
    m.B.ListChanged()
    assert(#m.timers == 1 and m.frame.events.PLAYER_LEVEL_UP)
    m.timers[1]()
    o.list = { id = 2, auto = true, slots = {}, extra = {} }
    m.B.ListChanged()
    assert(#m.timers == 2, "a second Auto list is refilled")
    m.timers[2]()
    assert(o.list.slots[1] == 1)
    o.list = { id = 3, slots = {}, extra = {} }
    m.B.ListChanged()
    assert(not m.frame.events.PLAYER_LEVEL_UP, "an own list stops the listening")
end)

print(("bis auto: %d cases passed"):format(count))
