-- Run with Lua 5.1 from the repository root: the profession window's Filter choices and sort are kept per profession.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local function Noop() end

local BLACKSMITHING, COOKING = 164, 185
local TRIVIAL, EASY = 3, 2
local db = {}
local defaults = { recipeFinder = true, sortSkillUps = false, sortProfit = false, filterSkillUp = false,
    filterFavorite = false }

local S = {}
function S.DB() return db end
function S.Get(key)
    if db[key] == nil then return defaults[key] end
    return db[key]
end
function S.Set(key, value) db[key] = value end

local W = {}
local P = {
    Settings = S,
    State = W,
    Recipes = { OutputItem = function() return 1 end, Craftable = function() return 1 end, Request = Noop },
    Prices = { ProfitShown = function() return true end, RecipeProfit = function() return 1 end },
    Favorites = { Is = function() return false end },
    Auctions = { Ready = function() return true end, Count = function() return 0 end },
}
local env = setmetatable({
    NaowhForever = { L = function(text) return text end, Professions = P },
    C_Item = { GetItemInfo = Noop },
}, { __index = _G })
env._G = env
Load({ "NaowhForever_Professions/Filters.lua" }, env)
local F = P.Filters
local trivial = { recipeID = 1, relativeDifficulty = TRIVIAL }
local easy = { recipeID = 2, relativeDifficulty = EASY }

F.Set("filterSkillUp", true)
Check("with no profession open a filter is the shared setting", db.filterSkillUp == true and F.Get("filterSkillUp"))

W.profID = BLACKSMITHING
Check("a profession's first read starts from the shared filters", F.Get("filterSkillUp") and F.Active() == 1)
Check("and hides a recipe that gives no skill-up", not F.Passes(trivial) and F.Passes(easy))
F.Set("filterSkillUp", false)
F.Set("filterFavorite", true)
F.Set("sortSkillUps", true)

W.profID = COOKING
Check("another profession keeps its own filters", F.Get("filterSkillUp") and not F.Get("filterFavorite"))
Check("and its own sort", not F.Get("sortSkillUps"))
Check("so Cooking still hides what gives no skill-up", not F.Passes(trivial))
F.Set("sortProfit", true)
Check("Highest Profit is kept for the open profession", F.Get("sortProfit") and db.sortProfit == nil)
for _, f in ipairs(F.LIST) do F.Set(f.key, false) end
Check("Reset clears only the open profession's filters", F.Active() == 0 and F.Passes(trivial))

W.profID = BLACKSMITHING
Check("switching back finds Blacksmithing as it was left",
    not F.Get("filterSkillUp") and F.Get("filterFavorite") and F.Get("sortSkillUps") and F.Active() == 1)
Check("the shared settings are left alone", db.filterSkillUp == true and db.filterFavorite == nil)
Check("Blacksmithing keeps its own sort, not Cooking's Highest Profit", not F.Get("sortProfit"))

local ALCHEMY = 171
db.professionFilters[ALCHEMY] = { sortSkillUps = true, filterFavorite = false }
W.profID = ALCHEMY
Check("a profession saved before Highest Profit existed reads it as off",
    not F.Get("sortProfit") and F.Get("sortSkillUps"))

print("profession filters: " .. checks .. " checks passed")
