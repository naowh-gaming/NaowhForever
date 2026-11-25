-- Quests.lua: the Dungeon Journal's quest rules: where each quest stands, its chain and its waypoint (J.Quests).
local ns = _G.NaowhForever

local IsOnQuest = C_QuestLog.IsOnQuest
local IsComplete = C_QuestLog.IsComplete
local IsDone = C_QuestLog.IsQuestFlaggedCompleted
local GetTitle = C_QuestLog.GetTitleForQuestID

local J = ns.Journal
local S = J.Settings
local QUEST = J.C.QUEST
local PERCENT = J.C.PERCENT
local ID, NAME, LEVEL, SIDE, WHERE = QUEST.ID, QUEST.NAME, QUEST.LEVEL, QUEST.SIDE, QUEST.WHERE
local MAP, X, Y = QUEST.MAP, QUEST.X, QUEST.Y
local TIPS = J.QuestTips

local RANK = { prereq = 1, prereqLog = 2, low = 3, pickup = 4, next = 5, active = 6, ready = 7, lost = 8, done = 9 }
local PIN_RANK = { ready = 1, pickup = 2, tooHigh = 3, active = 4, low = 5, prereq = 6, none = 7 }
local PIN_ROLES = { "finish", "start", "use" }
local FACTION_CODE = { Alliance = "A", Horde = "H" }
local TOO_HIGH = 5
local SIGNATURE_BASE = 10
local SIGNATURE_MOD = 2147483647
local BOTH = "B"
local FOLLOW_UP = "^Follow%-up from (.+)$"
local SIDE_OF = { A = "Alliance", H = "Horde" }
local PARTY = { "party1", "party2", "party3", "party4" }
local RACE_ID = 3
local RACE_BITS = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7, [95] = 32, [96] = 33 }

local TEXT_QUEST_GIVER = ns.L(" (quest giver)")
local TEXT_SPOT = " (%s)"
local TEXT_ENTRANCE = ns.L(" (dungeon entrance)")
local TEXT_TURN_IN = ns.L(" (turn in: %s)")
local TEXT_REQUIRES = ns.L("Requires%s: %s (%d/%d)")
local TEXT_IN_LOG = ns.L(" (in your log)")
local TEXT_NO_START = ns.L("Where %s starts is not known.")
local TEXT_NO_ROUTE = ns.L("The game has no route for %s, and its quest giver's spot is not known.")
local TEXT_TRACKING = ns.L("Tracking %s. Press L to see it in your quest log.")
local TEXT_ALL_DONE = ns.L("Every quest here for you is handed in.")
local TEXT_GREY = ns.L("None to pick up at your level: the rest have gone grey. Show Low-Level Quests lists them.")
local TEXT_NONE_HERE = ns.L("None for you here. The rest: %s.")
local TEXT_COUNT = "%d %s"
local TEXT_JOIN = ", "
local TEXT_LOST_IF = ns.L("Lost if you take %s first.")
local TEXT_LOSES = ns.L("Taking it loses %s for good.")
local TEXT_ONE_VERSION = ns.L("Only one of its versions can be done: taking another loses it.")
local TEXT_STEP_TIP = "%s: %s"

local requested = {}
local paths = {}
local stubs = {}
local stepAfter
local byID, dungeonOf
local noneParts, noneClasses, noneOrder = {}, {}, {}
local closes
local EMPTY = {}

local function StepAny(step, check)
    if type(step) ~= "table" then return check(step) and step or nil end
    for i = 1, #step do
        if check(step[i]) then return step[i] end
    end
end

local function StepDone(step)
    return StepAny(step, IsDone) ~= nil
end

local function OnList(list)
    if not list then return end
    for i = 1, #list do
        local id = StepAny(list[i], IsOnQuest)
        if id then return id end
    end
end

local function NextPrereq(quest)
    local list = J.QuestPrereqs[quest[ID]]
    if not list then return end
    local n = #list
    for i = n, 1, -1 do
        if StepDone(list[i]) then
            if i == n then return end
            return list[i + 1], i + 1, n
        end
    end
    return list[1], 1, n
end

local function FirstDone(quest)
    local done = IsDone(quest[ID])
    local alt = quest.alt
    if not alt then return done end
    for i = 1, #alt do done = done or IsDone(alt[i]) end
    return done
end

local function ChainDone(quest)
    local first = FirstDone(quest)
    local all, any = first, first
    local steps = quest.steps
    if not steps then return all, any end
    for i = 1, #steps do
        local done = StepDone(steps[i])
        all, any = all and done, any or done
    end
    return all, any
end

local function ForSide(side, faction)
    local own = SIDE_OF[side]
    return side == BOTH or (own ~= nil and own == faction)
end

local function ForRace(mask, unit)
    local bit = RACE_BITS[select(RACE_ID, UnitRace(unit))]
    return not bit or math.floor(mask / 2 ^ bit) % 2 == 1
end

local function ForClass(need, class)
    if type(need) ~= "table" then return need == nil or need == class end
    for i = 1, #need do
        if need[i] == class then return true end
    end
    return false
end

local function ForMe(quest, class, faction, unit)
    if not ForClass(quest.class, class) then return false end
    if quest.races and not ForRace(quest.races, unit or "player") then return false end
    return ForSide(quest[SIDE], faction)
end

local function Covers(step, id)
    if type(step) ~= "table" then return step == id end
    for i = 1, #step do
        if step[i] == id then return true end
    end
    return false
end

local function AddStep(steps, seen, step)
    local ids = type(step) == "table" and step or { step }
    for i = 1, #ids do
        if seen[ids[i]] then return end
    end
    for i = 1, #ids do seen[ids[i]] = true end
    steps[#steps + 1] = step
end

local function BuildPath(id)
    local prereqs, series = J.QuestPrereqs[id], J.QuestChains[id]
    if not (prereqs or series) then return false end
    local steps, seen = {}, {}
    for i = 1, prereqs and #prereqs or 0 do AddStep(steps, seen, prereqs[i]) end
    for i = 1, series and #series or 0 do AddStep(steps, seen, series[i]) end
    AddStep(steps, seen, id)
    for i = 1, #steps do
        if Covers(steps[i], id) then return { steps = steps, own = i } end
    end
    return false
end

local function Predecessor(quests, quest, name)
    local found
    for _, other in ipairs(quests) do
        if other ~= quest and other[NAME] == name then
            if other[SIDE] == quest[SIDE] then return other end
            found = found or other
        end
    end
    return found
end

local function LinkFollowUp(id, before)
    local prereqs, series = J.QuestPrereqs, J.QuestChains
    if not prereqs[id] then
        local list = {}
        for i, step in ipairs(prereqs[before] or {}) do list[i] = step end
        list[#list + 1] = before
        prereqs[id] = list
    end
    if series[id] then return end
    local old = series[before]
    local steps = {}
    for i, step in ipairs(old or { before }) do steps[i] = step end
    steps[#steps + 1] = id
    for _, step in ipairs(steps) do
        if type(step) == "number" and (series[step] == nil or series[step] == old) then series[step] = steps end
    end
end

local function LinkFollowUps()
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            local name = type(quest[WHERE]) == "string" and quest[WHERE]:match(FOLLOW_UP)
            local before = name and Predecessor(dungeon.quests, quest, name)
            if before then LinkFollowUp(quest[ID], before[ID]) end
        end
    end
end
LinkFollowUps()

local sidesApplied = false

local function ApplySides()
    if sidesApplied then return end
    local side = FACTION_CODE[UnitFactionGroup("player") or ""]
    if not side then return end
    sidesApplied = true
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            local own = quest.sides and quest.sides[side]
            if own then quest[WHERE], quest[MAP], quest[X], quest[Y] = own[1], own[2], own[3], own[4] end
        end
    end
end
ApplySides()
ns.OnApply(ApplySides)

local function QuestByID(id)
    if not byID then
        byID = {}
        for _, dungeon in ipairs(J.QuestData) do
            for _, quest in ipairs(dungeon.quests) do byID[quest[ID]] = quest end
        end
    end
    return byID[id]
end

local function Taken(id)
    return IsOnQuest(id) or IsDone(id)
end

local function LostTo(quest)
    local list = J.QuestClosedBy[quest[ID]]
    if not (list and S.Get("questHelp")) then return end
    for i = 1, #list do
        if Taken(list[i]) then return list[i] end
    end
end

local function DataName(id)
    local quest = QuestByID(id)
    return quest and quest[NAME] or J.QuestClosedByNames[id]
end

local function Closes(id)
    if not closes then
        closes = {}
        for closed, list in pairs(J.QuestClosedBy) do
            for _, other in ipairs(list) do
                closes[other] = closes[other] or {}
                table.insert(closes[other], closed)
            end
        end
    end
    return closes[id] or EMPTY
end

local function SpotOf(id)
    local quest = QuestByID(id)
    if quest and quest[MAP] then return quest[MAP], quest[X], quest[Y], TEXT_QUEST_GIVER end
    local start = J.QuestChainStarts[id]
    if start then return start[1], start[2], start[3], TEXT_SPOT:format(start[4]) end
end

local function StepSpot(step, id)
    local map, x, y, note = SpotOf(id)
    if map then return map, x, y, note end
    if type(step) ~= "table" then return SpotOf(step) end
    for i = 1, #step do
        map, x, y, note = SpotOf(step[i])
        if map then return map, x, y, note end
    end
end

local function NextSpot(quest)
    local steps, spots = quest.steps, quest.next
    if not (steps and spots) then return end
    for i = 1, #steps do
        if not StepDone(steps[i]) then return spots[i] or nil end
    end
end

local function Where(quest)
    return J.QuestWhere[quest[ID]] or quest[WHERE]
end

local function IndexDungeons()
    dungeonOf = {}
    for _, dungeon in ipairs(J.Dungeons()) do
        local data = dungeon.quests
        for _, q in ipairs(data and data.quests or {}) do dungeonOf[q] = dungeon end
    end
end

local function EntranceOf(quest)
    if not dungeonOf then
        if not J.Dungeons then return nil end
        IndexDungeons()
    end
    local dungeon = dungeonOf[quest]
    return dungeon and dungeon.entrance
end

local function Navigation(id)
    local map, x, y = C_QuestLog.GetNextWaypoint(id)
    if map and x and y and ns.CanPlaceWaypoint(map) then return map, x * PERCENT, y * PERCENT end
end

local function StepTarget(step, state, id)
    if state == "active" then
        local map, x, y = Navigation(id)
        if map then return map, x, y end
    end
    return StepSpot(step, id)
end

local function Route(quest, id)
    local map, x, y = Navigation(id)
    if map then return map, x, y end
    local turnIn = J.QuestTurnIns[id]
    if turnIn and ns.CanPlaceWaypoint(turnIn[1]) then
        return turnIn[1], turnIn[2], turnIn[3], TEXT_TURN_IN:format(turnIn[4])
    end
    if quest[MAP] and ns.CanPlaceWaypoint(quest[MAP]) then return quest[MAP], quest[X], quest[Y], TEXT_QUEST_GIVER end
end

local function ByRank(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.index < b.index
end

local function CountClass(class)
    if not noneClasses[class] then noneOrder[#noneOrder + 1] = class end
    noneClasses[class] = (noneClasses[class] or 0) + 1
end

local function CountOthers(quests, faction)
    wipe(noneClasses)
    wipe(noneOrder)
    local other = 0
    for i = 1, #quests do
        local quest = quests[i]
        local class = quest.class
        if type(class) == "table" then
            for c = 1, #class do CountClass(class[c]) end
        elseif class then
            CountClass(class)
        elseif not ForSide(quest[SIDE], faction) then
            other = other + 1
        end
    end
    return other
end

local Q = {}
J.Quests = Q
Q.ByID = QuestByID

function Q.LoggedID(quest)
    if IsOnQuest(quest[ID]) then return quest[ID] end
    return OnList(quest.alt) or OnList(quest.steps) or OnList(quest.lead)
end
local LoggedID = Q.LoggedID

function Q.MinLevel(quest)
    return J.QuestMinLevel[quest[ID]]
end

function Q.MinRep(quest)
    return J.QuestMinRep[quest[ID]]
end

function Q.Inside(id)
    local area = J.QuestInside[id]
    return area and C_Map.GetAreaInfo(area)
end

function Q.Kind(quest)
    local id = LoggedID(quest)
    if id then return IsComplete(id) and "ready" or "active" end
    local all, any = ChainDone(quest)
    if all then return "done" end
    if any then return "next" end
    if LostTo(quest) then return "lost" end
    local step = NextPrereq(quest)
    if step then return StepAny(step, IsOnQuest) and "prereqLog" or "prereq" end
    local need = Q.MinLevel(quest)
    if need and UnitLevel("player") < need then return "low" end
    return "pickup"
end
local Kind = Q.Kind

function Q.InLog(kind)
    return kind == "active" or kind == "ready"
end
local InLog = Q.InLog

function Q.ToPickUp(kind)
    return kind == "pickup" or kind == "prereq" or kind == "prereqLog" or kind == "low"
end
local ToPickUp = Q.ToPickUp

function Q.Level(quest)
    local id = quest[ID]
    local level = C_QuestLog.GetQuestDifficultyLevel(id)
    if level and level > 0 then return level end
    if not requested[id] then
        requested[id] = true
        C_QuestLog.RequestLoadQuestByID(id)
    end
    return quest[LEVEL]
end
local Level = Q.Level

function Q.Name(quest)
    return GetTitle(quest[ID]) or quest[NAME]
end

local function Grey(quest)
    local level = Level(quest)
    return level ~= nil and GetQuestDifficultyColor(level) == QuestDifficultyColors.trivial
end

local function Listed(quest, kind, class, faction, withDone, withLow)
    return ForMe(quest, class, faction) and (withDone or kind ~= "done")
        and (withLow or not (ToPickUp(kind) and Grey(quest) and not quest.turnin))
end

Q.ForClass = ForClass

function Q.ForMe(quest)
    local _, class = UnitClass("player")
    return ForMe(quest, class, UnitFactionGroup("player"))
end

function Q.ForUnit(quest, unit)
    local need = Q.MinLevel(quest)
    if need and UnitLevel(unit) < need then return false end
    local _, class = UnitClass(unit)
    return ForMe(quest, class, UnitFactionGroup(unit), unit)
end

function Q.Chain(quest)
    local id = quest[ID]
    local path = paths[id]
    if path == nil then
        path = BuildPath(id)
        paths[id] = path
    end
    if path then return path.steps, path.own end
end
local Chain = Q.Chain

function Q.StepState(step)
    local id = StepAny(step, IsOnQuest)
    if id then return "active", id end
    id = StepAny(step, IsDone)
    if id then return "done", id end
    return "todo", type(step) == "table" and step[1] or step
end
local StepState = Q.StepState

function Q.StepName(id)
    local quest = QuestByID(id)
    return GetTitle(id) or J.QuestChainNames[id] or (quest and quest[NAME]) or tostring(id)
end
local StepName = Q.StepName

function Q.StepHasSpot(step, id)
    return StepSpot(step, id) ~= nil
end

local function PrereqLine(quest)
    local step, i, n = NextPrereq(quest)
    if not step then return end
    local state, id = StepState(step)
    local text = TEXT_REQUIRES:format(state == "active" and TEXT_IN_LOG or "", StepName(id), i, n)
    return text, step, state, id
end

local function Destination(quest, kind)
    if kind == "next" then
        local spot = NextSpot(quest)
        if spot then return spot[4], spot[1], spot[2], spot[3] end
    elseif kind == "prereq" or kind == "prereqLog" then
        local text, step, _, id = PrereqLine(quest)
        local map, x, y, note = StepSpot(step, id)
        return map and text .. note or text, map, x, y
    end
    if quest[MAP] then return Where(quest), quest[MAP], quest[X], quest[Y] end
    local entrance = EntranceOf(quest)
    if entrance then return Where(quest), entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE end
    return Where(quest)
end

function Q.StepWaypoint(step, state, id, name)
    local map, x, y, note = StepTarget(step, state, id)
    if not map then
        ns.Print(TEXT_NO_START:format(name))
        return
    end
    ns.PlaceWaypoint(name, map, x, y, note)
end

local function LoggedSpot(quest, logged)
    local name = GetTitle(logged) or quest[NAME]
    local map, x, y, note = Route(quest, logged)
    return name, map, x, y, note, not map and TEXT_NO_ROUTE:format(name) or nil
end

local function PrereqSpot(quest)
    local _, step, state, id = PrereqLine(quest)
    local name = StepName(id)
    local map, x, y, note = StepTarget(step, state, id)
    return name, map, x, y, note, not map and TEXT_NO_START:format(name) or nil
end

function Q.Spot(quest)
    local logged = LoggedID(quest)
    if logged then return LoggedSpot(quest, logged) end
    local kind = Kind(quest)
    if kind == "prereq" or kind == "prereqLog" then return PrereqSpot(quest) end
    local _, map, x, y, note = Destination(quest, kind)
    return Q.Name(quest), map, x, y, note
end

function Q.Waypoint(quest)
    local name, map, x, y, note, why = Q.Spot(quest)
    if map then
        if ns.PlaceWaypoint(name, map, x, y, note) then ns.Shared.Places.ShowMap(map) end
    elseif why then
        ns.Print(why)
    end
end

function Q.Track(id)
    C_QuestLog.AddQuestWatch(id)
    C_QuestLog.SetSelectedQuest(id)
    C_SuperTrack.SetSuperTrackedQuestID(id)
    ns.Print(TEXT_TRACKING:format(GetTitle(id) or id))
end

function Q.UnitOnQuest(unit, quest, loggedID)
    return C_QuestLog.IsUnitOnQuest(unit, quest[ID])
        or (loggedID ~= nil and C_QuestLog.IsUnitOnQuest(unit, loggedID))
end
local UnitOnQuest = Q.UnitOnQuest

function Q.PartyCount(quest, loggedID)
    local count = 0
    for i = 1, math.min(GetNumSubgroupMembers(), #PARTY) do
        if UnitOnQuest(PARTY[i], quest, loggedID) then count = count + 1 end
    end
    return count
end
local PartyCount = Q.PartyCount

function Q.Progress(data)
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local done, total = 0, 0
    local quests = data and data.quests
    for i = 1, quests and #quests or 0 do
        local quest = quests[i]
        local kind = ForMe(quest, class, faction) and Kind(quest)
        if kind and kind ~= "lost" then
            total = total + 1
            if kind == "done" then done = done + 1 end
        end
    end
    return done, total
end

function Q.NoneWhy(data)
    local quests = data and data.quests
    if not quests or #quests == 0 then return nil end
    local done, total = Q.Progress(data)
    if total > 0 then return done == total and TEXT_ALL_DONE or TEXT_GREY end
    local faction = UnitFactionGroup("player")
    local other = CountOthers(quests, faction)
    wipe(noneParts)
    if other > 0 then
        noneParts[1] = TEXT_COUNT:format(other, faction == "Horde" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde"))
    end
    for _, class in ipairs(noneOrder) do
        noneParts[#noneParts + 1] = TEXT_COUNT:format(noneClasses[class], LOCALIZED_CLASS_NAMES_MALE[class] or class)
    end
    return TEXT_NONE_HERE:format(table.concat(noneParts, TEXT_JOIN))
end

local function FillEntry(entry, quest, kind, index, level)
    local where, map = Destination(quest, kind)
    local questLevel = Level(quest)
    entry.quest, entry.kind, entry.index, entry.rank = quest, kind, index, RANK[kind]
    entry.name, entry.level = Q.Name(quest), questLevel
    entry.tooHigh = kind == "pickup" and questLevel ~= nil and questLevel >= level + TOO_HIGH
    entry.where, entry.inLog = where, InLog(kind)
    entry.canWaypoint = kind ~= "lost" and (map ~= nil or kind == "prereqLog" or entry.inLog)
    entry.lostTo = kind == "lost" and LostTo(quest) or nil
    entry.loggedID = LoggedID(quest)
    entry.party = PartyCount(quest, entry.loggedID)
    local chain, step = Chain(quest)
    entry.step, entry.steps = step, chain and #chain
end

function Q.List(data, out, pool, withDone, withLow)
    wipe(out)
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local level = UnitLevel("player")
    for index, quest in ipairs(data.quests) do
        local kind = Kind(quest)
        if Listed(quest, kind, class, faction, withDone, withLow) then
            local n = #out + 1
            local entry = pool[n] or {}
            pool[n] = entry
            FillEntry(entry, quest, kind, index, level)
            out[n] = entry
        end
    end
    table.sort(out, ByRank)
    return out
end

function Q.Signature(data)
    local signature = 0
    for _, quest in ipairs(data.quests) do
        signature = (signature * SIGNATURE_BASE + RANK[Kind(quest)]) % SIGNATURE_MOD
    end
    return signature
end

function Q.Count(data)
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local toPickUp, inLog = 0, 0
    for _, quest in ipairs(data.quests) do
        local kind = Kind(quest)
        if Listed(quest, kind, class, faction) then
            if InLog(kind) then
                inLog = inLog + 1
            elseif ToPickUp(kind) then
                toPickUp = toPickUp + 1
            end
        end
    end
    return toPickUp, inLog
end

local function IndexSteps()
    stepAfter = {}
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            local chain = Chain(quest)
            for i = 2, chain and #chain or 0 do
                local step = chain[i]
                for _, id in ipairs(type(step) == "table" and step or { step }) do
                    stepAfter[id] = stepAfter[id] or chain[i - 1]
                end
            end
        end
    end
end

local function Waiting(id)
    local quest = QuestByID(id)
    if quest then return NextPrereq(quest) ~= nil end
    if not stepAfter then IndexSteps() end
    local before = stepAfter[id]
    return before ~= nil and not StepDone(before)
end

local function PinKind(id, role, level)
    if IsOnQuest(id) then
        if role == "start" then return "none" end
        if IsComplete(id) then return role == "finish" and "ready" or "none" end
        return "active"
    end
    local quest = QuestByID(id)
    if role ~= "start" or IsDone(id) or quest and LostTo(quest) then return "none" end
    if Waiting(id) then return "prereq" end
    local need = J.QuestMinLevel[id]
    if need and level < need then return "low" end
    return "pickup"
end

local function PinName(id)
    if not GetTitle(id) and not requested[id] then
        requested[id] = true
        C_QuestLog.RequestLoadQuestByID(id)
    end
    return StepName(id)
end

local function FillPinEntry(entry, id, kind, level)
    local questLevel = C_QuestLog.GetQuestDifficultyLevel(id)
    entry.tooHigh = kind == "pickup" and questLevel > 0 and questLevel >= level + TOO_HIGH
    entry.kind, entry.rank = kind, PIN_RANK[entry.tooHigh and "tooHigh" or kind]
    entry.level = questLevel > 0 and questLevel or nil
    entry.loggedID = IsOnQuest(id) and id or nil
end

local function AddPinQuest(out, pool, id, role, level)
    local quest = QuestByID(id)
    if quest and not IsOnQuest(id) and not Q.ForMe(quest) then return end
    local kind = PinKind(id, role, level)
    for i = 1, #out do
        local entry = out[i]
        if entry.quest[ID] == id then
            if PIN_RANK[kind] < entry.rank then FillPinEntry(entry, id, kind, level) end
            return
        end
    end
    local n = #out + 1
    local entry = pool[n] or {}
    pool[n] = entry
    if not quest then
        quest = stubs[id] or { id }
        stubs[id] = quest
    end
    entry.quest, entry.index, entry.name, entry.canWaypoint = quest, n, PinName(id), false
    FillPinEntry(entry, id, kind, level)
    out[n] = entry
end

function Q.PinQuests(pin, out, pool)
    wipe(out)
    local faction = FACTION_CODE[UnitFactionGroup("player")]
    local level = UnitLevel("player")
    for r = 1, #PIN_ROLES do
        local list = pin[PIN_ROLES[r]]
        for i = 1, list and #list or 0 do
            local id = list[i]
            if type(id) == "table" then id = id[faction] end
            if id then AddPinQuest(out, pool, id, PIN_ROLES[r], level) end
        end
    end
    table.sort(out, ByRank)
    return out
end

function Q.Open(kind)
    return kind ~= "done" and kind ~= "lost" and not InLog(kind)
end
local Open = Q.Open

local function TippedStep(step)
    if type(step) ~= "table" then return step end
    for i = 1, #step do
        if TIPS[step[i]] then return step[i] end
    end
    return step[1]
end

local function AddTips(quest, out)
    local id = quest[ID]
    if TIPS[id] then out[#out + 1] = TIPS[id] end
    local steps = Chain(quest)
    for i = 1, steps and #steps or 0 do
        local state, step = StepState(steps[i])
        if state ~= "done" then
            if state == "todo" then step = TippedStep(steps[i]) end
            if step ~= id and TIPS[step] then out[#out + 1] = TEXT_STEP_TIP:format(StepName(step), TIPS[step]) end
            return
        end
    end
end

local function LostLines(quest, out)
    local name, versions = quest[NAME], false
    for _, other in ipairs(J.QuestClosedBy[quest[ID]] or EMPTY) do
        local record = QuestByID(other)
        if DataName(other) == name then
            versions = true
        elseif not record or Q.ForMe(record) then
            out[#out + 1] = TEXT_LOST_IF:format(StepName(other))
        end
    end
    if versions then out[#out + 1] = TEXT_ONE_VERSION end
    for _, closed in ipairs(Closes(quest[ID])) do
        local record = QuestByID(closed)
        if record[NAME] ~= name and Q.ForMe(record) and Open(Kind(record)) then
            out[#out + 1] = TEXT_LOSES:format(Q.Name(record))
        end
    end
end

function Q.Warnings(quest, out)
    wipe(out)
    if not S.Get("questHelp") then return out end
    local kind = Kind(quest)
    if kind == "done" or kind == "lost" then return out end
    if Open(kind) then LostLines(quest, out) end
    AddTips(quest, out)
    return out
end
