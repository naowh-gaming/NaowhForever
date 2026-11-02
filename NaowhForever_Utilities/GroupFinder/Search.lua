-- Search.lua: a search of Forever's group finder from the Browse screen, for the activities that suit your level (ns.GroupFinder.Search).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local S = GF.Settings

local SEARCH_WAIT = 15
local NO_FILTER, NO_PREFERRED = 0, 0

local Search = { state = "idle", SEARCH_WAIT = SEARCH_WAIT }
GF.Search = Search

local wanted = {}
local generation = 0

local function Listed(entry, id)
    if not entry then return false end
    for _, listed in ipairs(entry.activityIDs) do
        if listed == id then return true end
    end
    return false
end

local function Suits(info, level)
    local low, high = info.minLevelSuggestion, info.maxLevelSuggestion
    return not ((low > 0 and low > level) or (high > 0 and high < level))
end

local function Fill(categoryID, level, entry)
    wipe(wanted)
    local suited = false
    for _, id in ipairs(C_LFGList.GetAvailableActivities(categoryID)) do
        local info = C_LFGList.GetActivityInfoTable(id)
        local suits = info ~= nil and Suits(info, level)
        suited = suited or suits
        if suits or Listed(entry, id) then wanted[#wanted + 1] = id end
    end
    return suited
end

local function Category()
    local level, entry = UnitLevel("player"), C_LFGList.GetActiveEntryInfo()
    local categories = C_LFGList.GetAvailableCategories()
    for i = 1, #categories do
        if Fill(categories[i], level, entry) then return categories[i] end
    end
end

Search.Category = Category

local function Settle(state)
    generation = generation + 1
    Search.state = state
    GF.Fire("search", state)
end

function Search.Run()
    if not GF.On() or Search.state == "searching" then return false end
    local category = Category()
    if not category then
        Settle("unavailable")
        return false
    end
    C_LFGList.Search(category, NO_FILTER, NO_PREFERRED, nil, false, nil, wanted)
    Settle("searching")
    local gen = generation
    C_Timer.After(SEARCH_WAIT, function()
        if gen == generation then Settle("failed") end
    end)
    return true
end

GF.Listen("listings", function(failed)
    Settle(failed and "failed" or "done")
end)

S.OnChange(function(key)
    if key == "enabled" and not GF.On() then
        generation = generation + 1
        Search.state = "idle"
    end
end)
