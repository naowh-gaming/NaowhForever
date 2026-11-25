-- Run with Lua 5.1 from the repository root: the Quest List and the Dungeon Quest Tracker give each
-- character only its own faction's quests and its own class's class quests, read from the shipped
-- data: Alliance-only, Horde-only and warlock-only quests for an Alliance and a Horde hunter and a
-- Human warlock.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ALLIANCE_HUNTER = { faction = "Alliance", race = "Dwarf", raceID = 3, class = "HUNTER", classID = 3 }
local HORDE_HUNTER = { faction = "Horde", race = "Orc", raceID = 2, class = "HUNTER", classID = 3 }
local HUMAN_WARLOCK = { faction = "Alliance", race = "Human", raceID = 1, class = "WARLOCK", classID = 9 }
local WINDSHAPER_MAGE = { faction = "Horde", race = "WindshaperSkyborne", raceID = 96, class = "MAGE", classID = 8 }
local HIGH_ORDER_MAGE = { faction = "Alliance", race = "HighOrderSkyborne", raceID = 95, class = "MAGE", classID = 8 }

local function Env(ns, who)
    return setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        UnitFactionGroup = function() return who.faction, who.faction end,
        UnitRace = function() return who.race, who.race, who.raceID end,
        UnitClass = function() return who.class, who.class, who.classID end,
        UnitLevel = function() return 60 end,
        GetProfessions = function() end,
        C_SpellBook = { IsSpellKnown = function() return false end },
        C_Reputation = { GetFactionDataByID = function() end },
        C_QuestLog = { GetAllCompletedQuestIDs = function() return {} end, GetNumQuestLogEntries = function() return 0 end },
    }, { __index = _G })
end

local function Run(path, env)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end

-- The Quest List: Kobold Camp Cleanup (7) and Hearts of the Lost (87318) are Alliance-only,
-- Cutting Teeth (788) and Strahnbrad Mystery (95534) Horde-only, You Have Served Us Well (397) is
-- for Human and Gnome warlocks, and An Earnest Proposition has a version per class (84148 hunter,
-- 84153 warlock).
local function QuestList(who)
    local ns = { AccountSettings = function() return {} end,
        Completo = { Holidays = { Read = function() end, On = function() return false end },
            CharKey = function() return "Me-Realm" end }, CompletoQuestData = {},
        Shared = { Places = dofile("Tools/regression/shared_places.lua") } }
    local env = Env(ns, who)
    Run("NaowhForever_DiscoveryData/Quests.lua", env)
    Run("NaowhForever_Discovery/QuestList/Quests.lua", env)
    local Q = ns.Completo.Quests
    Q.Refresh()
    return Q, ns, env
end

local Q = QuestList(ALLIANCE_HUNTER)
Check(Q.Mine(7) and Q.Mine(87318), "an Alliance hunter has the Alliance-only quests")
Check(not Q.Mine(788) and not Q.Mine(95534), "an Alliance hunter does not have the Horde-only quests")
Check(not Q.Mine(397), "an Alliance hunter does not have the warlock quest")
Check(Q.Mine(84148) and not Q.Mine(84153), "an Alliance hunter has the hunter version, not the warlock one")

Q = QuestList(HORDE_HUNTER)
Check(Q.Mine(788) and Q.Mine(95534), "a Horde hunter has the Horde-only quests")
Check(not Q.Mine(7) and not Q.Mine(87318), "a Horde hunter does not have the Alliance-only quests")
Check(not Q.Mine(397) and not Q.Mine(84148) and not Q.Mine(84153), "a Horde hunter has no Alliance class quest")

Q = QuestList(HUMAN_WARLOCK)
Check(Q.Mine(397) and Q.Mine(84153), "a Human warlock has the warlock quests")
Check(not Q.Mine(84148), "a Human warlock does not have the hunter version")

-- Zephras Isle: Coming of Age (92460) is both sides' first quest; The High Order (92596) is the Alliance's.
Q = QuestList(WINDSHAPER_MAGE)
Check(Q.Mine(92460) and not Q.Mine(92596), "a Windshaper Skyborne has the island's shared quests")
Q = QuestList(HIGH_ORDER_MAGE)
Check(Q.Mine(92460) and Q.Mine(92596) and not Q.Mine(92595), "a High Order Skyborne has its own")

-- The Dungeon Quest Tracker: Serpentbloom (962) is Horde-only, Important Heirlooms (96403)
-- Alliance-only, and The Orb of Soran'ruk (1740) is for warlocks of either faction.
local function Tracker(who)
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Journal = {}, OnApply = function() end }
    local env = Env(ns, who)
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/Data/Quests.lua",
        "NaowhForever_DungeonJournal/Data/QuestChains.lua", "NaowhForever_DungeonJournal/Quests.lua" }) do
        Run(path, env)
    end
    local J = ns.Journal
    return function(id) return J.Quests.ForMe(assert(J.Quests.ByID(id), id)) end
end

local ForMe = Tracker(ALLIANCE_HUNTER)
Check(ForMe(96403) and not ForMe(962), "the tracker gives an Alliance hunter the Alliance quest, not the Horde one")
Check(not ForMe(1740), "the tracker gives a hunter no warlock quest")

ForMe = Tracker(HORDE_HUNTER)
Check(ForMe(962) and not ForMe(96403), "the tracker gives a Horde hunter the Horde quest, not the Alliance one")
Check(not ForMe(1740), "the tracker gives a Horde hunter no warlock quest")

ForMe = Tracker(HUMAN_WARLOCK)
Check(ForMe(1740) and ForMe(96403) and not ForMe(962), "the tracker gives a warlock its class quest and its faction's")

-- Discovery's Class page (Attune.ClassQuests): the chains a class quest starts, then that class's
-- other quests. The Dreadsteed chain starts at Mor'zul Bloodbringer (7562) and ends at Dreadsteed of
-- Xoroth (7631), with Lord Banehollow (7623) beside it in the first step; A Gently Shaken Gift (8788)
-- is a Winter Veil quest for warlocks among others.
local DREADSTEED_START, DREADSTEED_END, BANEHOLLOW, WINTER_GIFT, FELSTEED_A = 7562, 7631, 7623, 8788, 4488
local function ClassPage(who, completed)
    local rules, ns, env = QuestList(who)
    env.C_QuestLog.GetAllCompletedQuestIDs = function() return completed or {} end
    env.C_QuestLog.IsOnQuest = function() return false end
    env.C_QuestLog.GetLogIndexForQuestID = function() end
    ns.L = dofile("Tools/regression/locale_stub.lua").L
    ns.Discovery = { Library = { Side = function() return who.faction == "Horde" and "H" or "A" end } }
    Run("NaowhForever_Discovery/Data/Attunements.lua", env)
    Run("NaowhForever_Discovery/Attunements.lua", env)
    return ns.Discovery.Attune, rules, ns
end

local function ChainOf(chains, id)
    for _, chain in ipairs(chains) do
        for _, step in ipairs(chain.steps) do
            for _, other in ipairs(step) do
                if other == id then return chain end
            end
        end
    end
end

local function Has(list, id)
    for _, other in ipairs(list) do
        if other == id then return true end
    end
    return false
end

local Attune, ns
Attune, Q, ns = ClassPage(HUMAN_WARLOCK)
local all = Q.ClassQuests()
Check(#all > 0, "a warlock has class quests")
for i, id in ipairs(all) do
    Check(Q.Mine(id) and Q.ClassOnly(id), "every class quest listed is a class-only quest of this warlock")
    if i > 1 then Check(Q.Level(all[i - 1]) <= Q.Level(id), "the class quests are listed by level") end
end
Check(not Has(all, 84148), "a warlock's class quests leave out the hunter's")
local chains, singles = Attune.ClassQuests()
Check(#chains > 0 and #singles > 0, "a warlock gets class chains and other class quests")
for i, chain in ipairs(chains) do
    Check(Q.ClassOnly(chain.steps[1][1]), "each chain on the page starts with a class quest")
    if i > 1 then Check(chains[i - 1].level <= chain.level, "the chains are listed by level") end
end
local dreadsteed = ChainOf(chains, DREADSTEED_END)
Check(dreadsteed ~= nil and dreadsteed.steps[1][1] == DREADSTEED_START, "the Dreadsteed chain starts at Mor'zul Bloodbringer")
Check(Has(all, FELSTEED_A) and (ChainOf(chains, FELSTEED_A) ~= nil) ~= Has(singles, FELSTEED_A),
    "Summon Felsteed is on the page once, in a chain or with the other class quests")
for _, id in ipairs(singles) do
    Check(not ChainOf(chains, id), "a quest in a chain on the page is not listed again")
    Check(not Q.Repeatable(id), "no repeatable quest among the other class quests")
end
Check(Has(all, WINTER_GIFT) and not Has(singles, WINTER_GIFT), "the Winter Veil gift stays off the page while Winter Veil is off")
ns.Completo.Holidays.On = function() return true end
singles = select(2, Attune.ClassQuests())
Check(Has(singles, WINTER_GIFT), "the Winter Veil gift shows while Winter Veil is on")
Check(Attune.ClassState(DREADSTEED_START, 1, 1) == "now", "the chain's first quest is next while nothing is done")
local blocked
for _, id in ipairs(singles) do
    if not Q.Opened(id) then blocked = id end
end
Check(blocked ~= nil and Attune.ClassState(blocked, 1, 1) == "later", "an other class quest still waiting on a quest before it is later")

Attune, Q = ClassPage(HUMAN_WARLOCK, { DREADSTEED_START })
chains = Attune.ClassQuests()
dreadsteed = ChainOf(chains, DREADSTEED_END)
local first = dreadsteed.steps[1]
Check(#first == 2 and first[2] == BANEHOLLOW, "the Dreadsteed chain's first step is Mor'zul Bloodbringer and Lord Banehollow")
local at = Q.ChainAt(dreadsteed)
Check(at == 1, "with only Mor'zul Bloodbringer handed in, the chain is still on its first step")
Check(Attune.ClassState(DREADSTEED_START, 1, at) == "done" and Attune.ClassState(BANEHOLLOW, 1, at) == "now",
    "the handed-in quest of the step shows done, the other one next")

Attune, Q = ClassPage(HUMAN_WARLOCK, { DREADSTEED_START, BANEHOLLOW })
dreadsteed = ChainOf(Attune.ClassQuests(), DREADSTEED_END)
at = Q.ChainAt(dreadsteed)
Check(at == 2 and Attune.ClassState(dreadsteed.steps[2][1], 2, at) == "now", "with both handed in, the second step is next")

-- Heeding the Call (5923, 5924, 5925) is one quest from three trainers: hand in one and the others close.
local NIGHT_ELF_DRUID = { faction = "Alliance", race = "NightElf", raceID = 4, class = "DRUID", classID = 11 }
Attune = ClassPage(NIGHT_ELF_DRUID)
singles = select(2, Attune.ClassQuests())
Check(Has(singles, 5923) and Has(singles, 5924) and Has(singles, 5925), "a druid sees all three Heeding the Call quests")
Attune = ClassPage(NIGHT_ELF_DRUID, { 5923 })
singles = select(2, Attune.ClassQuests())
Check(Has(singles, 5923) and not Has(singles, 5924) and not Has(singles, 5925),
    "with one handed in, the two it closes leave the page")

Attune, Q = ClassPage(ALLIANCE_HUNTER)
chains, singles = Attune.ClassQuests()
Check(not ChainOf(chains, DREADSTEED_END) and not Has(singles, DREADSTEED_END), "a hunter's page has no warlock chain")
Check(Q.Chain(84148) ~= nil and not ChainOf(chains, 84148) and not Has(singles, 84148),
    "the Quest List's An Earnest Proposition chain is left off: the page's Tier 0.5 has it")

print(("test-quest-faction-class: %d checks passed"):format(checks))
