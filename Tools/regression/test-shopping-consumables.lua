-- Run with Lua 5.1 from the repository root: the Shopping List's Consumables picker. What it
-- offers suits your class (stats), mana and level (usable now and the next tier up), each kind's
-- best for your level is marked, "Only for my class" off shows everything, items whose data has
-- not loaded wait, and a pick lands on the list as an other item. The module's real data, rules
-- and list files are loaded and run.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local Load = dofile("Tools/regression/load_files.lua")

local account, levels = {}, {}
local env = {
    UnitName = function() return "Grim" end,
    GetRealmName = function() return "Realm" end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_Item = {
        GetItemNameByID = function(id) return levels[id] and ("item" .. id) end,
        GetItemInfo = function(id)
            if not levels[id] then return nil end
            return "item" .. id, "link", 1, 1, levels[id]
        end,
        RequestLoadItemDataByID = function() end,
    },
    NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L,
        Professions = {},
        HEALING_POTIONS = { 13446, 3928, 929, 118 },
        MANA_POTIONS = { 13444, 6149, 2455 },
        AccountSettings = function() return account end,
    },
}
env._G = env
Load({ "NaowhForever_Professions/Constants.lua", "NaowhForever_Professions/Text.lua",
    "NaowhForever_Professions/Data/CooldownRecipes.lua", "NaowhForever_Professions/Data/ConsumableItems.lua",
    "NaowhForever_Professions/ShoppingPlan.lua", "NaowhForever_Professions/Consumables.lua" },
    setmetatable(env, { __index = _G }))
local P = env.NaowhForever.Professions
local D, C, SL = P.ConsumableItems, P.Consumables, P.Shopping

-- Required levels, as the game answers them once each item has loaded.
local LV = {
    [3391] = 20, [13453] = 45, [250349] = 45, [9206] = 48, [250351] = 55, [250350] = 55,  -- strength elixirs
    [8949] = 27, [9187] = 38, [13452] = 46,                                              -- agility elixirs
    [9179] = 37, [13454] = 47, [250341] = 55, [20007] = 40,                              -- caster and mana
    [13445] = 43, [8951] = 29,                                                           -- armor, for everyone
    [13446] = 45, [3928] = 35, [929] = 15, [118] = 1,                                    -- healing potions
    [13444] = 49, [6149] = 31, [2455] = 5,                                               -- mana potions
    [14530] = 0, [14529] = 0, [1251] = 0,                                                -- bandages
    [12404] = 35, [18262] = 50, [20750] = 40,                                            -- stones, wizard oil
}
local function Loaded() for k in pairs(levels) do levels[k] = nil end for k, v in pairs(LV) do levels[k] = v end end
Loaded()

local function Picked(level, class, mine, mana)
    local by, best, later, order = {}, {}, {}, {}
    for _, group in ipairs(C.Pick(level, class, mine, mana)) do
        order[#order + 1] = group.key
        for _, row in ipairs(group.rows) do
            by[row.id] = group.key
            best[row.id] = row.best
            later[row.id] = row.later
        end
    end
    return by, best, later, order
end

-- The data: every ID once, every stat one a class can want or mana, every class has its stats.
local seen, stats = {}, { mana = true }
for _, s in pairs(D.CLASS_STATS) do for k in pairs(s) do stats[k] = true end end
for _, group in ipairs(D.GROUPS) do
    for _, e in ipairs(D.ITEMS[group] or {}) do
        check("item listed once: " .. e[1], not seen[e[1]])
        seen[e[1]] = true
        for i = 2, #e do check("known stat on " .. e[1] .. ": " .. e[i], stats[e[i]]) end
    end
end
for _, class in ipairs({ "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "PALADIN", "SHAMAN", "DRUID" }) do
    check("stats for " .. class, D.CLASS_STATS[class] ~= nil)
end

-- A level 45 warrior: strength and agility up to 45 and the next tier, nothing for casters or mana.
local by, best, later = Picked(45, "WARRIOR", true, false)
check("warrior: strength elixirs usable now", by[3391] == "elixir" and by[13453] and by[250349])
check("warrior: the next strength tier (48) shows", by[9206] and later[9206])
check("warrior: two tiers up (55) does not", not by[250351] and not by[250350])
check("warrior: the best strength elixirs are the level 45 ones", best[13453] and best[250349] and not best[3391])
check("warrior: agility's next tier (46) shows, marked later", by[13452] and later[13452])
check("warrior: no intellect or spell power", not by[9179] and not by[13454])
check("warrior: no mana potions or mana elixirs", not by[13444] and not by[6149] and not by[20007])
check("warrior: armor elixirs and healing potions", by[13445] and by[8951] and by[13446] and by[118])
check("warrior: the best healing potion is the level 45 one", best[13446] and not best[929])
check("warrior: stones, no wizard oil", by[12404] and by[18262] and not by[20750])
check("warrior: bandages, none marked best (no levels)", by[14530] and by[1251] and not best[14530])

-- A level 45 mage: intellect, spell power and mana; no strength.
by, best = Picked(45, "MAGE", true, true)
check("mage: intellect and spell power", by[9179] and by[13454])
check("mage: mana potions and the next tier", by[6149] and by[13444] and best[6149] and not best[2455])
check("mage: mageblood", by[20007])
check("mage: no strength or agility, no stones", not by[3391] and not by[8949] and not by[12404])
check("mage: wizard oil", by[20750])
check("mage: everyone's items too", by[13445] and by[13446])

-- A class the table does not know sees what suits everyone.
by = Picked(45, "MONK", true, false)
check("unknown class: armor and healing potions only", by[13445] and by[13446] and not by[3391] and not by[9179])

-- Only for my class off: everything, every level, the best still marked.
local order
by, best, later, order = Picked(45, "WARRIOR", false, false)
check("everything: caster and mana items too", by[9179] and by[13444] and by[20750])
check("everything: every tier up", by[250351] and later[250351])
local last = 0
for _, key in ipairs(order) do
    local at
    for i, g in ipairs(D.GROUPS) do if g == key then at = i end end
    check("group order kept: " .. key, at > last)
    last = at
end

-- Rows run from the highest level down.
for _, group in ipairs(C.Pick(60, "WARRIOR", false, false)) do
    for i = 2, #group.rows do
        check("highest level first in " .. group.key, group.rows[i - 1].level >= group.rows[i].level)
    end
end

-- An item whose data has not loaded is left out until it has.
by = Picked(45, "WARRIOR", true, false)
check("unloaded item waits", not by[2454])
LV[2454] = 1
Loaded()
by = Picked(45, "WARRIOR", true, false)
check("loaded later, it shows", by[2454])

-- Every ID the picker can show is asked for, once.
local ids, once = C.IDs(), {}
for _, id in ipairs(ids) do
    check("ID asked for once: " .. id, not once[id])
    once[id] = true
end
check("potions asked for", once[13446] and once[2455])

-- Picks land on the list as other items: added, set, stepped down, taken off at zero.
SL.AddItem(13453, 1)
SL.AddItem(13453, 1)
check("plus adds one each", SL.Manual()[13453] == 2)
SL.SetItem(13453, 5)
check("typed amount sets it", SL.Manual()[13453] == 5)
SL.SetItem(13453, 99999)
check("capped at the most an item can be", SL.Manual()[13453] == P.C.MAX_ITEMS)
SL.SetItem(13453, 1)
SL.SetItem(13453, 0)
check("zero takes it off", SL.Manual()[13453] == nil)
SL.SetItem(13446, 3)
local materials = SL.Materials()
check("a pick is bought at the auction house like any other item",
    #materials == 1 and materials[1].item == 13446 and materials[1].qty == 3)
SL.Drop(13446, 3)
check("what was bought counts against it", #SL.Materials() == 0)
SL.SetItem(13446, 0)
check("taking it off forgets what was bought for it", SL.Have()[13446] == nil)

print(("test-shopping-consumables: %d checks passed"):format(checks))
