-- Run with Lua 5.1 from the repository root: a Blessings class button lights up (glow, red) only
-- for members in range who are missing their blessing or running out. Someone across the zone
-- without it, with everyone nearby blessed, must not light it.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local f = assert(io.open("Blessings/NaowhForever_Blessings.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local first = assert(source:find("local function InRange(member, spell)", 1, true))
local survey = assert(source:find("local function Survey(members)", first, true))
local last = assert(source:find("\nend\n", survey, true))
local chunk = source:sub(first, last + 4) .. "return Survey"

-- unit -> { has buff, seconds left, IsSpellInRange answer }
local state = {}
local env = {
    EXPIRING = 300,
    Secret = function() return false end,
    Assigned = function() return "might" end,
    CastSpell = function() return 19740 end,
    BuffState = function(unit) return state[unit][1], state[unit][2] end,
    UnitGUID = function(unit) return unit == "player" and "me" or unit end,
    UnitIsConnected = function() return true end,
    UnitIsDeadOrGhost = function() return false end,
    UnitIsVisible = function() return true end,
    C_Spell = { IsSpellInRange = function(_, unit) return state[unit][3] end },
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local Survey = fn()

local members = { { unit = "party1", guid = "party1" }, { unit = "party2", guid = "party2" } }

state = { party1 = { true, 3000, true }, party2 = { false, nil, false } }
local target, _, missing, _, reachable, missingNear, expiringNear = Survey(members)
check("one missing, but out of range: counted as missing", missing == 1)
check("nobody in range is missing it", missingNear == 0 and expiringNear == 0)
check("the blessed one in range is still a target", reachable and target == members[1])

state = { party1 = { true, 3000, true }, party2 = { false, nil, nil } }
_, _, missing, _, _, missingNear = Survey(members)
check("a member the game cannot range-check is not in range", missing == 1 and missingNear == 0)

state = { party1 = { true, 3000, true }, party2 = { false, nil, true } }
target, _, _, _, _, missingNear = Survey(members)
check("missing and in range: lights the button and is the target", missingNear == 1 and target == members[2])

state = { party1 = { true, 120, true }, party2 = { true, 3000, true } }
_, _, _, _, _, missingNear, expiringNear = Survey(members)
check("running out in range counts as expiring, not missing", missingNear == 0 and expiringNear == 1)

print(("test-blessing-range: %d checks passed"):format(checks))
