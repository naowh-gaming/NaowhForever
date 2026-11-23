-- Run with Lua 5.1 from the repository root: the profession window's search matches a learned
-- recipe by its name or by any reagent's name, as Blizzard's search does, and an unlearned recipe
-- the same way from the shipped reagent data. A reagent whose name has not loaded yet is asked for
-- once and matches once it arrives, and a recipe's reagents are read from the game once, even when
-- it needs none. Loads Recipes.lua and Entries.lua against stubs.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local RECIPES = {
    [1] = { recipeID = 1, name = "Copper Bracers", learned = true, categoryID = 0 },
    [2] = { recipeID = 2, name = "Rough Sharpening Stone", learned = true, categoryID = 0 },
    [3] = { recipeID = 3, name = "Smelt Copper", learned = true, categoryID = 0 },
}
local SLOTS = {
    [1] = { { reagents = { { itemID = 2840 } }, quantityRequired = 2 } },
    [2] = { { reagents = { { itemID = 2835 } }, quantityRequired = 1 } },
    [3] = {},
}
local names = { [2840] = "Copper Bar", [12203] = "Red Wolf Meat", [2692] = "Hot Spices" }
local SPELLS = { [15856] = "Hot Wolf Ribs", [15853] = "Lean Wolf Steak", [818] = "Basic Campfire" }
local UNLEARNED = { { spell = 15856 }, { spell = 15853 }, { spell = 818 } }
local requests, schematics = {}, {}

local W = { query = "", linked = true }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L }
ns.Professions = {
    State = W,
    Settings = { Get = function() end, Set = function() end },
    Filters = { Passes = function() return true end },
    RecipeReagents = { [15856] = { 12203, 1, 2692, 1 }, [15853] = { 12204, 1, 2692, 1 } },
}
ns.RecipeFinder = { Unlearned = function() return UNLEARNED end, Status = function() return "ready" end }

local env = setmetatable({
    NaowhForever = ns,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_Item = {
        GetItemNameByID = function(itemID) return names[itemID] end,
        RequestLoadItemDataByID = function(itemID) requests[itemID] = (requests[itemID] or 0) + 1 end,
    },
    C_TradeSkillUI = {
        GetAllRecipeIDs = function() return { 1, 2, 3 } end,
        GetRecipeInfo = function(id) return RECIPES[id] end,
        GetCategoryInfo = function() end,
        GetRecipeSchematic = function(id)
            schematics[id] = (schematics[id] or 0) + 1
            return { reagentSlotSchematics = SLOTS[id] }
        end,
    },
    C_Spell = { GetSpellName = function(spell) return SPELLS[spell] end },
}, { __index = _G })
env._G = env

Load({ "NaowhForever_Professions/Recipes.lua", "NaowhForever_Professions/Entries.lua" }, env)
local Entries = ns.Professions.Entries
local waiting = ns.Professions.Recipes.waiting
Entries.Collect()

local function Search(text)
    W.query = text:lower()
    Entries.Build()
    local out = {}
    for _, e in ipairs(Entries.list) do
        if e.recipe then out[e.recipe.recipeID] = true end
    end
    return out
end

local shown = Search("")
check("an empty search shows every learned recipe", shown[1] and shown[2] and shown[3])

shown = Search("bracers")
check("a recipe name still matches", shown[1] and not shown[2])

shown = Search("copper bar")
check("a reagent's name finds the recipe that uses it", shown[1] and not shown[2])

shown = Search("COPPER")
check("matching ignores case", shown[1] and shown[3] and not shown[2])

shown = Search("coarse stone")
check("a reagent whose name has not loaded does not match yet", not shown[2])
check("and its name is asked for", requests[2835] == 1)
Search("coarse ston")
Search("coarse sto")
check("typing on does not ask again while it is on its way", requests[2835] == 1)

waiting[2835] = nil
names[2835] = "Coarse Stone"
shown = Search("coarse stone")
check("once the name loads the recipe matches", shown[2] and not shown[1])

check("each recipe's reagents are read from the game once", schematics[1] == 1 and schematics[2] == 1)
check("a recipe with no reagents is read once too", schematics[3] == 1)

local function SearchUnlearned(text)
    W.query = text:lower()
    Entries.Build()
    local out = {}
    for _, e in ipairs(Entries.list) do
        if e.unlearned then out[e.unlearned.spell] = true end
    end
    return out
end

W.linked = false
Entries.Collect()
shown = SearchUnlearned("ribs")
check("an unlearned recipe still matches by name", shown[15856] and not shown[15853])

shown = SearchUnlearned("red")
check("an unlearned recipe matches by a reagent's name", shown[15856] and not shown[15853] and not shown[818])

shown = SearchUnlearned("heavy kodo")
check("an unlearned reagent whose name has not loaded does not match yet", not shown[15853])
check("and its name is asked for", requests[12204] == 1)

names[12204] = "Heavy Kodo Meat"
shown = SearchUnlearned("heavy kodo")
check("once the name loads the unlearned recipe matches", shown[15853] and not shown[15856])

shown = SearchUnlearned("basic")
check("an unlearned recipe without reagent data matches by name only", shown[818])

print(("test-profession-reagent-search: %d checks passed"):format(checks))
