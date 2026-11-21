-- Run with Lua 5.1 from the repository root: a Greater Blessing needs a Symbol of Kings, unless the
-- Reagent Economy Legacy talent drops the reagent.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local symbols, known = 0, {}
local B = {}
local env = setmetatable({
    NaowhForever = { Blessings = B },
    C_Item = { GetItemCount = function(item) return item == 21177 and symbols or 0 end },
    C_SpellBook = { IsSpellKnown = function(spell) return known[spell] or false end },
}, { __index = _G })
env._G = env
for _, file in ipairs({ "NaowhForever_Combat/Blessings/Data/Spells.lua", "NaowhForever_Combat/Blessings/Lookup.lua" }) do
    local chunk = assert(loadfile(file))
    setfenv(chunk, env)
    chunk("NaowhForever", env.NaowhForever)
end

check("no Symbols and no talent, no Greater Blessing", not B.CanCastGreater())
symbols = 3
check("Symbols in the bags allow one", B.CanCastGreater())
symbols = 0
known[B.REAGENT_ECONOMY] = true
check("Reagent Economy allows one without Symbols", B.CanCastGreater())

print(("test-blessing-greater: %d checks passed"):format(checks))
