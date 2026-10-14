-- Run with Lua 5.1 from the repository root: the profession window's search matches a learned
-- recipe by its name or by any reagent's name, as Blizzard's search does. A reagent whose name
-- has not loaded yet is asked for and matches once it arrives. Loads Entries.lua against stubs.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local RECIPES = {
    [1] = { recipeID = 1, name = "Copper Bracers", learned = true, categoryID = 0 },
    [2] = { recipeID = 2, name = "Rough Sharpening Stone", learned = true, categoryID = 0 },
}
local REAGENTS = {
    [1] = { { itemID = 2840, need = 2 } },
    [2] = { { itemID = 2835, need = 1 } },
}
local names = { [2840] = "Copper Bar" }
local requested = {}

local W = { query = "", linked = true }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L }
ns.Professions = {
    State = W,
    Settings = { Get = function() end, Set = function() end },
    Filters = { Passes = function() return true end },
    Recipes = {
        Reagents = function(id) return REAGENTS[id] or {} end,
        ItemName = function(itemID)
            if not names[itemID] then requested[itemID] = true end
            return names[itemID]
        end,
    },
}

local env = setmetatable({
    NaowhForever = ns,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_TradeSkillUI = {
        GetAllRecipeIDs = function() return { 1, 2 } end,
        GetRecipeInfo = function(id) return RECIPES[id] end,
        GetCategoryInfo = function() end,
    },
}, { __index = _G })
env._G = env

Load({ "NaowhForever_Professions/Entries.lua" }, env)
local Entries = ns.Professions.Entries
Entries.Collect()

local function Shown()
    local out = {}
    for _, e in ipairs(Entries.list) do
        if e.recipe then out[e.recipe.recipeID] = true end
    end
    return out
end

local function Search(text)
    W.query = text:lower()
    Entries.Build()
    return Shown()
end

local shown = Search("")
check("an empty search shows every learned recipe", shown[1] and shown[2])

shown = Search("bracers")
check("a recipe name still matches", shown[1] and not shown[2])

shown = Search("copper bar")
check("a reagent's name finds the recipe that uses it", shown[1] and not shown[2])

shown = Search("COPPER")
check("matching ignores case", shown[1] and not shown[2])

shown = Search("coarse stone")
check("a reagent whose name has not loaded does not match yet", not shown[2])
check("and its name is asked for", requested[2835])

names[2835] = "Coarse Stone"
shown = Search("coarse stone")
check("once the name loads the recipe matches", shown[2] and not shown[1])

print(("test-profession-reagent-search: %d checks passed"):format(checks))
