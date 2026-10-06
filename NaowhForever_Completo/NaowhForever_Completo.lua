-------------------------------------------------------------------------------
--  NaowhForever_Completo.lua -- the Completo module: what you have done of everything the
--  game has to collect. Its first part is Quests: every quest of every zone for your
--  character (Data/NaowhForever_CompletoQuests.lua), how many you have done per zone, and
--  for each quest chain the step you are on. Mounts, transmog and more are to follow as
--  tabs of their own.
--
--  Off by default. Nothing runs until its window is open: the window reads what you have
--  done when it draws, and listens for quest events only while it is shown.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local UI = ns.UI

local S = UI.ModuleSettings("completo", {
    enabled = false, hideDone = false, windowAlpha = 1,
})
ns.CompletoSettings = S

local D = ns.CompletoQuestData
local Q = {}
ns.Completo = { Quests = Q }

-- The client's race IDs to their bit in Wowhead's race masks (Forever's own two races too).
local RACE_BITS = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7, [95] = 32, [96] = 33 }
local NAME, LEVEL, REQ_LEVEL, SIDE, RACES, CLASSES, MAP, X, Y = 1, 2, 3, 4, 5, 6, 7, 8, 9
local ALLIANCE, HORDE = 1, 2

local function HasBit(mask, bit)
    return math.floor(mask / 2 ^ bit) % 2 == 1
end

-------------------------------------------------------------------------------
--  Which quests are yours: your faction, race and class. Worked out once, the first time
--  the window draws; none of it changes while you play.
-------------------------------------------------------------------------------
local mine           -- questID -> true
local zoneOf         -- questID -> its zone (a D.Zones entry)
local chains         -- your chains: { steps = { {ids}, ... }, name, level, id }
local chainOf        -- questID -> its chain

local function ForMe(quest, side, raceBit, classBit)
    if quest[SIDE] == ALLIANCE and side ~= ALLIANCE then return false end
    if quest[SIDE] == HORDE and side ~= HORDE then return false end
    if quest[RACES] > 0 and raceBit and not HasBit(quest[RACES], raceBit) then return false end
    if quest[CLASSES] > 0 and classBit and not HasBit(quest[CLASSES], classBit) then return false end
    return true
end

local function Prepare()
    if mine then return end
    mine, zoneOf, chains, chainOf = {}, {}, {}, {}
    local side = UnitFactionGroup("player") == "Horde" and HORDE or ALLIANCE
    local raceBit = RACE_BITS[select(3, UnitRace("player"))]
    local classID = select(3, UnitClass("player"))
    local classBit = classID and classID - 1
    for id, quest in pairs(D.Quests) do
        if ForMe(quest, side, raceBit, classBit) then mine[id] = true end
    end
    for _, zone in ipairs(D.Zones) do
        for _, id in ipairs(zone.quests) do zoneOf[id] = zone end
    end
    -- A chain keeps the steps you can do; one left with a single step is no chain for you.
    for _, steps in ipairs(D.Chains) do
        local own = {}
        for _, step in ipairs(steps) do
            local ids = {}
            for _, id in ipairs(step) do
                if mine[id] then ids[#ids + 1] = id end
            end
            if #ids > 0 then own[#own + 1] = ids end
        end
        if #own > 1 then
            local first = D.Quests[own[1][1]]
            local chain = { steps = own, name = first[NAME], level = first[LEVEL], id = #chains + 1 }
            chains[#chains + 1] = chain
            for _, ids in ipairs(own) do
                for _, id in ipairs(ids) do chainOf[id] = chain end
            end
        end
    end
end

-------------------------------------------------------------------------------
--  What you have done: read in one call when the window draws (Q.Refresh), else one
--  quest at a time.
-------------------------------------------------------------------------------
local done = {}

function Q.Refresh()
    Prepare()
    wipe(done)
    local all = C_QuestLog.GetAllCompletedQuestIDs and C_QuestLog.GetAllCompletedQuestIDs()
    if all then
        for i = 1, #all do done[all[i]] = true end
    else
        for id in pairs(mine) do
            if C_QuestLog.IsQuestFlaggedCompleted(id) then done[id] = true end
        end
    end
end

function Q.Done(id) return done[id] == true end

function Q.InLog(id)
    return C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end

function Q.Mine(id) return mine[id] == true end
function Q.Name(id) return D.Quests[id][NAME] end
function Q.Level(id) return D.Quests[id][LEVEL] end
function Q.RequiredLevel(id) return D.Quests[id][REQ_LEVEL] end
function Q.Zone(id) return zoneOf[id] end
function Q.Chain(id) return chainOf[id] end
function Q.Zones() return D.Zones end

function Q.Spot(id)
    local quest = D.Quests[id]
    if quest[MAP] then return quest[MAP], quest[X], quest[Y] end
end

-- A step is done when any of its versions is: you only ever do the one for you.
function Q.StepDone(step)
    for _, id in ipairs(step) do
        if done[id] then return true end
    end
    return false
end

---@return number at the step you are on (#steps + 1 once all are done)
---@return number steps
function Q.ChainAt(chain)
    local steps = chain.steps
    for i = #steps, 1, -1 do
        if Q.StepDone(steps[i]) then return i + 1, #steps end
    end
    return 1, #steps
end

-- Where a quest stands for you: "done", "log" (in your quest log), "low" (your level is under
-- what it needs), "later" (an earlier step of its chain is not done yet) or "open".
function Q.State(id)
    if done[id] then return "done" end
    if Q.InLog(id) then return "log" end
    local chain = chainOf[id]
    if chain then
        local at = Q.ChainAt(chain)
        local steps = chain.steps
        if at <= #steps then
            local mineAt = false
            for _, other in ipairs(steps[at]) do
                if other == id then mineAt = true end
            end
            if not mineAt then return "later" end
        end
    end
    if UnitLevel("player") < Q.RequiredLevel(id) then return "low" end
    return "open"
end

---@return number done
---@return number total your quests in the zone
---@return number lowest quest level
---@return number highest quest level
function Q.ZoneProgress(zone)
    local n, total, low, high = 0, 0, nil, nil
    for _, id in ipairs(zone.quests) do
        if mine[id] then
            total = total + 1
            if done[id] then n = n + 1 end
            local level = D.Quests[id][LEVEL]
            if level > 0 then
                low = math.min(low or level, level)
                high = math.max(high or level, level)
            end
        end
    end
    return n, total, low, high
end

function Q.Progress()
    local n, total = 0, 0
    for _, zone in ipairs(D.Zones) do
        local zn, zt = Q.ZoneProgress(zone)
        n, total = n + zn, total + zt
    end
    return n, total
end

-- The zone's chains (any step in it), and its quests in no chain, lowest level first.
-- Tables reused until the next call.
local zoneChains, zoneSingles, seenChain = {}, {}, {}

local function ByLevel(a, b)
    local la = type(a) == "table" and a.level or D.Quests[a][LEVEL]
    local lb = type(b) == "table" and b.level or D.Quests[b][LEVEL]
    if la ~= lb then return la < lb end
    local na = type(a) == "table" and a.name or D.Quests[a][NAME]
    local nb = type(b) == "table" and b.name or D.Quests[b][NAME]
    return na < nb
end

function Q.ZoneLists(zone)
    wipe(zoneChains)
    wipe(zoneSingles)
    wipe(seenChain)
    for _, id in ipairs(zone.quests) do
        if mine[id] then
            local chain = chainOf[id]
            if chain then
                if not seenChain[chain] then
                    seenChain[chain] = true
                    zoneChains[#zoneChains + 1] = chain
                end
            else
                zoneSingles[#zoneSingles + 1] = id
            end
        end
    end
    table.sort(zoneChains, ByLevel)
    table.sort(zoneSingles, ByLevel)
    return zoneChains, zoneSingles
end

-- The zone you are in, if it has quests: walks up from the map you are on (a cave, a town).
function Q.CurrentZone()
    local map = C_Map.GetBestMapForUnit("player")
    while map do
        for _, zone in ipairs(D.Zones) do
            if zone.map == map then return zone end
        end
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID ~= 0 and info.parentMapID or nil
    end
end

function Q.Waypoint(id)
    local map, x, y = Q.Spot(id)
    if map then ns.PlaceWaypoint(Q.Name(id), map, x, y) end
end

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local page = Settings.Page("Completo/Quests", S)

local function Headline()
    Q.Refresh()
    local n, total = Q.Progress()
    return ("%d of %d zone quests done"):format(n, total)
end

local function Detail()
    local zone = Q.CurrentZone()
    if not zone then return "Every quest of every zone, and where you are in each chain." end
    local n, total = Q.ZoneProgress(zone)
    return ("%s: %d of %d."):format(zone.name, n, total)
end

page:Window({
    text = "Open Quests",
    open = function() ns.OpenCompletoWindow("quests") end,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "quests", name = "Quests", order = 10,
    help = "What a zone's page in the Completo window lists.",
    rows = {
        { key = "hideDone", label = "Hide Done", toggle = true,
          help = "Leave out the quests and chains you have finished." },
    },
})

page:Card({
    id = "window", name = "Window", order = 90,
    help = "Completo's own window, with every zone and its quests.",
    rows = {
        { key = "windowAlpha", label = "Window Opacity", slider = { ns.Shared.Style.OPACITY_MIN, 100, 5 },
          unit = "%", scale = 0.01, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
