-- AutoLoad.lua: sets this class loads on its own: entering a dungeon or raid, joining a battleground (put back on leaving), and reaching a level (ns.ActionBars.AutoLoad).
local ns = _G.NaowhForever

local A = ns.ActionBars
local S = A.Settings
local Backups = A.Backups

local STORE = "barSetAutoLoad"
local ZONES = { party = "dungeon", raid = "dungeon", pvp = "battleground" }

local TEXT_ENTERING = ns.L("Loading %s for this instance.")
local TEXT_LEAVING = ns.L("Leaving the instance: putting back the bars you had before %s.")
local TEXT_LEVEL = ns.L("Level %d: loading %s.")

local events

local function Rules()
    local all = S.Get("autoLoad") or {}
    return all[A.Class()] or {}
end

local function SetRule(key, value)
    local all = {}
    for class, rules in pairs(S.Get("autoLoad") or {}) do all[class] = rules end
    local rules = {}
    for k, v in pairs(all[A.Class()] or {}) do rules[k] = v end
    rules[key] = value
    all[A.Class()] = rules
    S.Set("autoLoad", all)
end

local function Named(key)
    local name = Rules()[key]
    return name and name ~= "" and A.Find(name) or nil
end

local function State()
    return ns.Shared.CharacterData(STORE, true)
end

local function BackupIndex(saved)
    for i, backup in ipairs(Backups.List()) do
        if backup.saved == saved then return i end
    end
end

local function Leave(state)
    local index = state.loaded and Rules().back ~= false and BackupIndex(state.backup)
    if index then
        ns.Print(TEXT_LEAVING:format(state.loaded))
        A.RestoreBackup(index)
    end
    state.zone, state.loaded, state.backup = nil, nil, nil
end

local function Enter(state, zone)
    state.zone = zone
    local key = Named(zone)
    if not key then return end
    ns.Print(TEXT_ENTERING:format(key))
    if A.ImportSet(key) then
        state.loaded, state.backup = key, Backups.List()[1].saved
    end
end

local function CheckZone()
    local _, kind = IsInInstance()
    local zone = ZONES[kind]
    local state = State()
    if zone == state.zone then return end
    if state.zone then Leave(state) end
    if zone then Enter(state, zone) end
end

local function CheckLevel(level)
    local key, at = Named("levelSet"), Rules().level or 0
    local state = State()
    if not key or at <= 0 or level < at or state.levelDone == at .. key then return end
    state.levelDone = at .. key
    ns.Print(TEXT_LEVEL:format(level, key))
    A.ImportSet(key)
end

local function Run()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    CheckZone()
    CheckLevel(UnitLevel("player"))
end

local function Watch()
    local on = A.On() and (Named("dungeon") or Named("battleground") or Named("levelSet")) ~= nil
    if on and not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", Run)
    end
    if not events then return end
    if on then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_LEVEL_UP")
    else
        events:UnregisterAllEvents()
    end
end

function A.RenameRules(old, new)
    for _, key in ipairs({ "dungeon", "battleground", "levelSet" }) do
        if Rules()[key] == old then SetRule(key, new) end
    end
end

S.OnChange(function(key)
    if key == "enabled" or key == "autoLoad" then Watch() end
end)

A.AutoLoad = { Rule = function(key) return Rules()[key] end, SetRule = SetRule, Watch = Watch, Run = Run }
