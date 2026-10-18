-- Memory.lua: the blessings you cast where the game hides other players' auras (battlegrounds and arenas).
local ns = _G.NaowhForever

local B = ns.Blessings
local Secret = B.Secret
local BY_KEY, FAMILY, GREATER = B.BY_KEY, B.FAMILY, B.GREATER

local BLESSING_TIME = 3600
local CAST_WINDOW = 5
local HIDING = { pvp = true, arena = true }

local seen = {}
local pending

function B.HiddenAuras()
    local _, kind = IsInInstance()
    return HIDING[kind] == true
end

local function Lasts(key)
    local entry = BY_KEY[key]
    return (entry.blessing or entry.salvation) and BLESSING_TIME or math.huge
end

function B.Remembered(unit, key)
    local guid = UnitGUID(unit)
    local mine = guid and not Secret(guid) and seen[guid]
    local ends = mine and mine[key]
    if not ends then return false end
    local dead = UnitIsDeadOrGhost(unit)
    if not Secret(dead) and dead then
        seen[guid] = nil
        return false
    end
    local left = ends - GetTime()
    if left <= 0 then
        mine[key] = nil
        return false
    end
    return true, left ~= math.huge and left or nil
end

function B.NoteCast(unit, spell)
    if not (unit and spell and B.HiddenAuras()) then return end
    local key = FAMILY[spell]
    if not key then return end
    local roster = B.Roster()
    local target
    for _, member in ipairs(roster) do
        local same = UnitIsUnit(unit, member.unit)
        if not Secret(same) and same then target = member break end
    end
    if not target then return end
    local guids = {}
    for _, member in ipairs(roster) do
        if member.guid == target.guid or (GREATER[spell] and member.class == target.class) then
            guids[#guids + 1] = member.guid
        end
    end
    pending = { key = key, spell = spell, guids = guids, at = GetTime() }
end

function B.CastDone(spell)
    local cast = pending
    if not (cast and cast.spell == spell and GetTime() - cast.at < CAST_WINDOW) then return end
    pending = nil
    local ends = GetTime() + Lasts(cast.key)
    for _, guid in ipairs(cast.guids) do
        seen[guid] = seen[guid] or {}
        seen[guid][cast.key] = ends
    end
end

function B.ForgetCasts()
    pending = nil
    wipe(seen)
end
