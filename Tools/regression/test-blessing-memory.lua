-- Run with Lua 5.1 from the repository root: where the game hides other players' auras
-- (battlegrounds and arenas) the bar remembers the blessings you cast and counts them down. A cast
-- counts once it lands, a Greater one for the whole class, a death forgets it, an aura has no end,
-- and elsewhere an unreadable aura stays unknown instead of missing.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local now, kind, secret = 1000, "pvp", true
local dead = {}
local classOf = { a = "MAGE", b = "MAGE", c = "WARRIOR", me = "PALADIN" }
local roster = {}
for _, unit in ipairs({ "a", "b", "c", "me" }) do
    roster[#roster + 1] = { unit = unit, guid = "G-" .. unit, class = classOf[unit] }
end
local B = {
    Secret = function(v) return v == "SECRET" end,
    BY_KEY = { kings = { blessing = true }, salvation = { salvation = true }, devotion = {} },
    FAMILY = { [20217] = "kings", [25898] = "kings", [1038] = "salvation", [465] = "devotion" },
    GREATER = { [25898] = true },
    Roster = function() return roster end,
}
local env = setmetatable({
    NaowhForever = { Blessings = B },
    IsInInstance = function() return true, kind end,
    UnitGUID = function(unit) return "G-" .. unit end,
    UnitIsUnit = function(a, b) return a == b end,
    UnitIsDeadOrGhost = function(unit) return dead[unit] or false end,
    GetTime = function() return now end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_Combat/Blessings/Memory.lua"))
setfenv(chunk, env)
chunk("NaowhForever", env.NaowhForever)

check("battlegrounds and arenas hide auras", B.HiddenAuras())
kind = "party"
check("a dungeon does not", not B.HiddenAuras())
kind = "pvp"

check("nothing remembered at first", B.Remembered("a", "kings") == false)
B.NoteCast("a", 20217)
check("a cast that has not landed is not remembered", B.Remembered("a", "kings") == false)
B.CastDone(1038)
check("another spell landing does not count", B.Remembered("a", "kings") == false)
B.CastDone(20217)
local has, left = B.Remembered("a", "kings")
check("a single blessing is remembered for an hour", has and left == 3600)
check("only the one who got it", B.Remembered("b", "kings") == false)
now = now + 600
has, left = B.Remembered("a", "kings")
check("and counts down", has and left == 3000)
now = now + 3000
check("then it runs out", B.Remembered("a", "kings") == false)

now = 1000
B.NoteCast("a", 25898)
B.CastDone(25898)
check("a Greater blessing is remembered for the whole class", B.Remembered("a", "kings") and B.Remembered("b", "kings"))
check("and not for other classes", B.Remembered("c", "kings") == false)
dead.b = true
check("a death forgets it", B.Remembered("b", "kings") == false)
dead.b = false
check("and it stays forgotten", B.Remembered("b", "kings") == false)

B.NoteCast("c", 1038)
B.CastDone(1038)
check("Salvation is remembered like a blessing", select(2, B.Remembered("c", "salvation")) == 3600)

B.NoteCast("me", 465)
B.CastDone(465)
has, left = B.Remembered("me", "devotion")
check("an aura has no end", has and left == nil)
now = now + 100000
check("and is still there", B.Remembered("me", "devotion") == true)

B.NoteCast("a", 20217)
now = now + 6
B.CastDone(20217)
check("a cast that lands long after the click is not matched", B.Remembered("a", "kings") == false)

B.NoteCast("a", 20217)
kind = "party"
B.NoteCast("b", 20217)
B.CastDone(20217)
check("outside a battleground clicks are not noted", B.Remembered("b", "kings") == false)
kind = "pvp"
B.NoteCast("a", 20217)
B.ForgetCasts()
B.CastDone(20217)
check("leaving forgets everything", B.Remembered("a", "kings") == false and B.Remembered("c", "salvation") == false)
B.NoteCast("zzz", 20217)
B.CastDone(20217)
check("a unit that is not in the group is ignored", B.Remembered("zzz", "kings") == false)

-- Buffs.lua asks the memory only where auras are hidden.
local f = assert(io.open("NaowhForever_Combat/Blessings/Buffs.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local first = assert(source:find("local function BuffState(unit, key)", 1, true))
local last = assert(source:find("local function InRange(member, spell)", first, true))
local state = setmetatable({
    B = B, Secret = B.Secret, FAMILY = B.FAMILY, MAX_AURAS = 40, memoAt = nil, memo = {}, scratch = {},
    Found = function(v) if v == true then return true end return true, v - now end,
    C_Secrets = { ShouldAurasBeSecret = function() return secret end },
    C_UnitAuras = { GetAuraDataByIndex = function() return nil end },
}, { __index = env })
local fn = assert(loadstring(source:sub(first, last - 1) .. "return BuffState"))
setfenv(fn, state)
local BuffState = fn()
now = 1000
B.NoteCast("a", 20217)
B.CastDone(20217)
check("hidden auras in a battleground: what you cast", select(1, BuffState("a", "kings")) == true)
check("and what you did not is missing", BuffState("b", "kings") == false)
kind = "party"
check("hidden elsewhere: unknown, not missing", BuffState("b", "kings") == nil)
secret = false
check("readable auras are read", BuffState("b", "kings") == false)

print(("test-blessing-memory: %d checks passed"):format(checks))
