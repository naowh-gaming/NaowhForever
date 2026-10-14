-- Consumables.lua: the consumables that suit you, by class, mana and level, each kind's best for your level marked (P.Consumables).
local ns = _G.NaowhForever

local P = ns.Professions
local D = P.ConsumableItems

local MIN_LEVEL = 5
local MANA = "mana"
local NO_STAT = ""
local SEP = ":"
local EMPTY = {}

local levels = {}
local best, soonest, lowest = {}, {}, {}
local groups, groupPool, rowPool = {}, {}, {}
local potions

local Consumables = {}
P.Consumables = Consumables

local function Potions()
    if potions then return potions end
    potions = {}
    for _, id in ipairs(ns.HEALING_POTIONS) do potions[#potions + 1] = { id } end
    for _, id in ipairs(ns.MANA_POTIONS) do potions[#potions + 1] = { id, MANA } end
    return potions
end

local function Entries(group)
    if group == "potion" then return Potions() end
    return D.ITEMS[group]
end

local function Level(id)
    local level = levels[id]
    if level then return level end
    level = select(MIN_LEVEL, C_Item.GetItemInfo(id))
    levels[id] = level
    return level
end

local function Line(group, e)
    return group .. SEP .. (e[2] or NO_STAT)
end

local function Fits(e, stats, mana)
    if #e == 1 then return true end
    for i = 2, #e do
        if e[i] == MANA then
            if mana then return true end
        elseif stats[e[i]] then
            return true
        end
    end
    return false
end

local function ByLevel(a, b)
    if a.level ~= b.level then return a.level > b.level end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

local function Measure(group, level, stats, mine, mana)
    for _, e in ipairs(Entries(group)) do
        local lv = Level(e[1])
        if lv and (not mine or Fits(e, stats, mana)) then
            local line = Line(group, e)
            if lv <= level then
                if lv > (best[line] or -1) then best[line] = lv end
            elseif lv < (soonest[line] or math.huge) then
                soonest[line] = lv
            end
            if lv < (lowest[line] or math.huge) then lowest[line] = lv end
        end
    end
end

local function Collect(group, level, stats, mine, mana, n)
    local out = groupPool[group] or { key = group, rows = {} }
    groupPool[group] = out
    local rows = out.rows
    wipe(rows)
    for _, e in ipairs(Entries(group)) do
        local id, lv = e[1], Level(e[1])
        local line = lv and Line(group, e)
        if lv and (not mine or (Fits(e, stats, mana) and (lv <= level or lv == soonest[line]))) then
            local row = rowPool[id] or { id = id }
            rowPool[id] = row
            row.level, row.name = lv, C_Item.GetItemNameByID(id) or NO_STAT
            row.best = lv == best[line] and lowest[line] < lv
            row.later = lv > level
            rows[#rows + 1] = row
        end
    end
    if #rows == 0 then return n end
    table.sort(rows, ByLevel)
    groups[n + 1] = out
    return n + 1
end

function Consumables.Pick(level, class, mine, mana)
    local stats = D.CLASS_STATS[class] or EMPTY
    wipe(best)
    wipe(soonest)
    wipe(lowest)
    for _, group in ipairs(D.GROUPS) do Measure(group, level, stats, mine, mana) end
    local n = 0
    for _, group in ipairs(D.GROUPS) do n = Collect(group, level, stats, mine, mana, n) end
    for i = n + 1, #groups do groups[i] = nil end
    return groups
end

function Consumables.IDs()
    local ids = {}
    for _, group in ipairs(D.GROUPS) do
        for _, e in ipairs(Entries(group)) do ids[#ids + 1] = e[1] end
    end
    return ids
end
