-- Runs.lua: this character's dungeon runs: time, splits, gold, XP, trash, deaths, loot and Need rolls, and the bests they set (J.Runs).
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Kills = J.Kills
local Looted = J.Looted
local Team = J.Team

local KEEP = 50
local HOUR = 3600
local GOLD, SILVER = 10000, 100
local RUNS_KEY = "journalRuns"
local TRASH_KEY = "journalTrash"
local ROLL_KEY = "%d:%d"
local MAGIC = "([%(%)%.%%%+%-%*%?%[%]%^%$])"
local NUMBER = "%%%%d"
local EVENTS = { "CHAT_MSG_MONEY", "PLAYER_XP_UPDATE", "PLAYER_DEAD", "PARTY_KILL", "PLAYER_TARGET_CHANGED",
    "NAME_PLATE_UNIT_ADDED" }

local frame
local open
local seen = {}
local listeners = {}
local goldPattern, silverPattern, copperPattern
local lastXP, lastMax

local function On()
    return S.Get("enabled") and S.Get("runPanel")
end

local function Mine(create)
    return J.CharacterData(RUNS_KEY, create)
end

local function Changed(kind)
    for i = 1, #listeners do listeners[i](kind) end
end

local function Counts(boss)
    return J.Numbered(boss) and Kills.Counted(boss) and not boss.with
end

local function CoinPattern(phrase)
    return (phrase:gsub(MAGIC, "%%%1"):gsub(NUMBER, "(%%d+)"))
end

local function Copper(text)
    if type(text) ~= "string" or issecretvalue(text) then return 0 end
    if not goldPattern then
        goldPattern = CoinPattern(GOLD_AMOUNT)
        silverPattern = CoinPattern(SILVER_AMOUNT)
        copperPattern = CoinPattern(COPPER_AMOUNT)
    end
    return (tonumber(text:match(goldPattern)) or 0) * GOLD + (tonumber(text:match(silverPattern)) or 0) * SILVER
        + (tonumber(text:match(copperPattern)) or 0)
end

local function BaseXP()
    local xp, max = UnitXP("player"), UnitXPMax("player")
    if issecretvalue(xp) or issecretvalue(max) then return end
    lastXP, lastMax = xp, max
end

local function AddXP()
    local xp, max = UnitXP("player"), UnitXPMax("player")
    if issecretvalue(xp) or issecretvalue(max) then return end
    if not lastXP then return BaseXP() end
    local gained = xp >= lastXP and xp - lastXP or math.max(0, lastMax - lastXP) + xp
    lastXP, lastMax = xp, max
    if gained <= 0 then return end
    open.xp = open.xp + gained
    Changed("stats")
end

local function TrashTotals()
    local account = ns.AccountSettings()
    local totals = account[TRASH_KEY]
    if type(totals) ~= "table" then
        totals = {}
        account[TRASH_KEY] = totals
    end
    return totals
end

local function Empty(run)
    return next(run.kills) == nil and run.trash == 0 and run.copper == 0 and #run.loot == 0
end

local function Close(run)
    run.ended = run.last
    run.leftAt = nil
    if not Empty(run) then return end
    local mine = Mine(false)
    for i = mine and #mine or 0, 1, -1 do
        if mine[i] == run then return table.remove(mine, i) end
    end
end

local function Begin(dungeon, start, partial)
    local mine = Mine(true)
    if not mine then return end
    if open and not open.ended then Close(open) end
    if #mine >= KEEP then table.remove(mine, 1) end
    open = { dungeon = dungeon.key, start = start, last = start, entered = start, partial = partial or nil, kills = {},
        copper = 0, xp = 0, deaths = 0, trash = 0, out = 0, needWon = 0, needLost = 0, rolled = {}, loot = {} }
    mine[#mine + 1] = open
    wipe(seen)
    BaseXP()
end

local function Finish(dungeon, now)
    for i, wing in ipairs(dungeon.wings) do
        local any = false
        for _, boss in ipairs(wing.bosses) do
            if Counts(boss) then
                if not open.kills[boss.encounters[1]] then
                    any = false
                    break
                end
                any = true
            end
        end
        if any then
            open.done, open.wing = now - open.start, i
            local totals = TrashTotals()
            if open.trash > (totals[open.dungeon] or 0) then totals[open.dungeon] = open.trash end
            return true
        end
    end
    return false
end

local function OnKill(boss, now, dungeon)
    if not (On() and dungeon) then return end
    local start = Kills.RunStart()
    if not start then return end
    if not open or open.ended or open.start ~= start then Begin(dungeon, start, start == now) end
    if not open then return end
    if next(open.kills) and dungeon.key ~= open.dungeon then
        local entered = open.entered or start
        local partial = entered == open.start
        Kills.NewRun(entered)
        Begin(dungeon, entered, partial)
    end
    if not next(open.kills) then open.dungeon = dungeon.key end
    local id = boss.encounters[1]
    if not open.kills[id] then open.kills[id] = now - open.start end
    open.last = now
    open.team = Team.Now()
    if not open.done and dungeon.key == open.dungeon and Finish(dungeon, now) then
        Changed("done")
    else
        Changed("kill")
    end
end

local function OnLoot(item)
    if not (On() and open) or open.ended or item.at < open.start then return end
    open.loot[#open.loot + 1] = item
    Changed("stats")
end

local function OnRoll(encounterID, lootListKey)
    if issecretvalue(encounterID) or issecretvalue(lootListKey) then return end
    local drop = C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)
    if not drop or not (drop.winner or drop.allPassed) then return end
    local key = ROLL_KEY:format(encounterID, lootListKey)
    if open.rolled[key] then return end
    local infos = drop.rollInfos
    for i = 1, type(infos) == "table" and #infos or 0 do
        local info = infos[i]
        if info.isSelf and info.state and info.state <= Enum.EncounterLootDropRollState.NeedOffSpec then
            open.rolled[key] = true
            if info.isWinner then open.needWon = open.needWon + 1 else open.needLost = open.needLost + 1 end
            Changed("stats")
            return
        end
    end
end

local function OnTrash(guid)
    if issecretvalue(guid) or seen[guid] then return end
    local npc = J.NpcID(guid)
    if not npc or J.Boss(npc) then return end
    seen[guid] = true
    open.trash = open.trash + 1
    Changed("stats")
end

local function NoteCopy(guid)
    local _, copy = ns.Shared.LayerOf(guid)
    if not copy or copy == open.copy then return end
    if not open.copy then
        open.copy = copy
        return
    end
    local start = open.entered or time()
    Kills.NewRun(start)
    Begin(J.Get(open.dungeon), start)
    open.copy = copy
    Changed("run")
end

local function OnEvent(_, event, arg1, arg2)
    if not open or open.ended then return end
    if event == "CHAT_MSG_MONEY" then
        local copper = Copper(arg1)
        if copper > 0 then
            open.copper = open.copper + copper
            Changed("stats")
        end
    elseif event == "PLAYER_XP_UPDATE" then
        AddXP()
    elseif event == "PLAYER_DEAD" then
        open.deaths = open.deaths + 1
        Changed("stats")
    elseif event == "PARTY_KILL" then
        NoteCopy(arg2)
        OnTrash(arg2)
    elseif event == "PLAYER_TARGET_CHANGED" then
        NoteCopy(UnitGUID("target"))
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        NoteCopy(UnitGUID(arg1))
    else
        OnRoll(arg1, arg2)
    end
end

local function Listen(inside)
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEvent)
    end
    if not inside then return frame:UnregisterAllEvents() end
    for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
    if C_LootHistory then frame:RegisterEvent("LOOT_HISTORY_UPDATE_DROP") end
end

local function Stored()
    local mine = Mine(false)
    local last = mine and mine[#mine]
    if type(last) == "table" and not last.ended then return last end
end

local function OnRun(here, login)
    if not On() then return end
    open = open or Stored()
    local now = time()
    if not here then
        if open and login then
            Close(open)
            open = nil
        elseif open and not open.leftAt then
            open.leftAt = now
        end
        if frame then Listen(false) end
        Changed("run")
        return
    end
    local start = Kills.RunStart()
    if open and open.start == start then
        if open.leftAt then
            open.out = open.out + now - open.leftAt
            open.leftAt = nil
            open.entered = now
        end
        if not lastXP then BaseXP() end
    elseif start then
        Begin(here[1], start)
    end
    Listen(true)
    Changed("run")
end

local Runs = { KEEP = KEEP }
J.Runs = Runs

function Runs.On()
    return On()
end

function Runs.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function Runs.Open()
    if open and not open.ended then return open end
end

function Runs.List()
    return Mine(false)
end

function Runs.Inside()
    return open ~= nil and not open.ended and not open.leftAt
end

function Runs.Counts(boss)
    return Counts(boss)
end

function Runs.Elapsed(run, now)
    if run.done then return run.done end
    return (run.ended or now or time()) - run.start
end

function Runs.PerHour(amount, seconds)
    if seconds <= 0 then return 0 end
    return math.floor(amount * HOUR / seconds)
end

function Runs.Split(run, boss)
    return boss.encounters and run.kills[boss.encounters[1]]
end

local function Compared(run, dungeonKey, except)
    return run ~= except and run.dungeon == dungeonKey and not run.partial
end

function Runs.BestSplit(dungeonKey, boss, except)
    local id = boss.encounters and boss.encounters[1]
    local mine, best = Mine(false), nil
    for i = 1, mine and #mine or 0 do
        local run = mine[i]
        local at = Compared(run, dungeonKey, except) and run.kills[id]
        if at and (not best or at < best) then best = at end
    end
    return best
end

function Runs.AverageSplit(dungeonKey, boss, except)
    local id = boss.encounters and boss.encounters[1]
    local mine, total, n = Mine(false), 0, 0
    for i = 1, mine and #mine or 0 do
        local run = mine[i]
        local at = Compared(run, dungeonKey, except) and run.kills[id]
        if at then total, n = total + at, n + 1 end
    end
    if n > 0 then return math.floor(total / n) end
end

function Runs.BestTime(dungeonKey, wing, except)
    local mine, best = Mine(false), nil
    for i = 1, mine and #mine or 0 do
        local run = mine[i]
        local done = Compared(run, dungeonKey, except) and (not wing or run.wing == wing) and run.done
        if done and (not best or done < best) then best = done end
    end
    return best
end

function Runs.IsBest(run)
    if not run.done or run.partial then return false end
    local best = Runs.BestTime(run.dungeon, run.wing, run)
    return not best or run.done <= best
end

function Runs.Summary(dungeonKey, out)
    out.runs, out.finished, out.best, out.time, out.copper, out.xp = 0, 0, nil, nil, nil, nil
    local mine, took, copper, xp = Mine(false), 0, 0, 0
    for i = 1, mine and #mine or 0 do
        local run = mine[i]
        if Compared(run, dungeonKey) then
            out.runs = out.runs + 1
            copper, xp = copper + run.copper, xp + run.xp
            if run.done then
                out.finished = out.finished + 1
                took = took + run.done
                if not out.best or run.done < out.best then out.best = run.done end
            end
        end
    end
    if out.runs > 0 then out.copper, out.xp = math.floor(copper / out.runs), math.floor(xp / out.runs) end
    if out.finished > 0 then out.time = math.floor(took / out.finished) end
    return out
end

function Runs.TrashTotal(dungeonKey)
    return TrashTotals()[dungeonKey]
end

function Runs.Dungeon(run)
    return J.Get(run.dungeon)
end

function Runs.Delete(run)
    local mine = Mine(false)
    for i = mine and #mine or 0, 1, -1 do
        if mine[i] == run then
            table.remove(mine, i)
            if open == run then open = nil end
            Changed("run")
            return
        end
    end
end

local function Sync()
    if On() then
        if IsLoggedIn() then OnRun(J.Current(), false) end
    elseif frame then
        Listen(false)
        open = nil
        Changed("run")
    end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "runPanel" then Sync() end
end

Kills.OnKill(OnKill)
Kills.OnRun(OnRun)
Looted.OnAdd(OnLoot)
S.OnChange(OnSettingChanged)
ns.OnApply(Sync)
