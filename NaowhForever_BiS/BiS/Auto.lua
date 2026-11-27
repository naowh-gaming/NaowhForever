-- Auto.lua: the Auto list: your best gear for your level, from what you wear and the gear you can get (B.Auto).
local ns = _G.NaowhForever

local GetInventoryItemID, GetInventoryItemLink = GetInventoryItemID, GetInventoryItemLink
local RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID

local B = ns.BiS
local C = B.C
local R = B.Rankings
local L = B.Lists
local Items = ns.Shared.Items
local SW = ns.StatWeights
local S = B.Settings

local MAIN_HAND, OFF_HAND = C.MAIN_HAND, C.OFF_HAND
local PICKS = 3
local REFRESH_DELAY = 0.5
local PAIR = Items.PAIR
local AFTER = { [12] = 11, [14] = 13, [OFF_HAND] = MAIN_HAND }
local TRINKETS = { [13] = true, [14] = true }
local EVENTS = { "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED" }
local LOADED = "GET_ITEM_INFO_RECEIVED"
local NONE = {}

local pool, pending = {}, {}
local base, scores, ranked, chosen, current = {}, {}, {}, {}, {}
local scoredKey, scoredWeights, scoredTop, poolWaiting
local simRank = {}
local sortBy
local waiting = false
local watching
local queued = false
local events, OnEvent

local function ByScore(a, b)
    if sortBy[a] ~= sortBy[b] then return sortBy[a] > sortBy[b] end
    return a < b
end

local function BySim(a, b)
    local ra, rb = simRank[a], simRank[b]
    if ra and rb then return ra < rb end
    if ra or rb then return ra ~= nil end
    return ByScore(a, b)
end

local function AddAll(ids)
    for i = 1, #ids do pool[ids[i]] = true end
end

local function Gather(spec)
    wipe(pool)
    wipe(simRank)
    for i, id in ipairs(spec.trinkets or NONE) do
        if not R.OtherSideQuest(id) and not R.Hidden(id) then pool[id], simRank[id] = true, i end
    end
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        AddAll(R.Candidates(gear[1], spec))
        AddAll(R.DungeonDrops(gear[1], NONE, true))
    end
    for _, level in ipairs(ns.BiSLeveling.levels) do
        for _, id in pairs(R.LevelPicks(spec.key, level) or NONE) do
            if not R.OtherClassQuest(id) and not R.Hidden(id) then pool[id] = true end
        end
    end
end

local function Wait(id)
    waiting, pending[id] = true, true
    RequestLoadItemDataByID(id)
end

local function Score(id, slot, weights, top)
    if not R.Wieldable(id, slot) then return nil end
    local required = R.ReqLevel(id)
    local usable = required and required <= top and SW.Usable(id)
    if required and (required > top or usable == false) then return nil end
    local stats = usable and SW.Stats(id)
    if not stats then return Wait(id) end
    return SW.Worth(stats, weights, SW.DpsShare(slot))
end

local function ScorePool(weights, top)
    for _, gear in ipairs(Items.GEAR_SLOTS) do base[gear[1]] = wipe(base[gear[1]] or {}) end
    for id in pairs(pool) do
        local slots = Items.SlotsFor(id) or NONE
        for i = 1, #slots do
            local worth = Score(id, slots[i], weights, top)
            if worth then base[slots[i]][id] = worth end
        end
    end
end

local function AddWorn(byID, from, slot, weights)
    local id = GetInventoryItemID("player", from)
    if not id then return end
    local stats = SW.Stats(GetInventoryItemLink("player", from))
    if not stats then return Wait(id) end
    local worth = SW.Worth(stats, weights, SW.DpsShare(slot))
    if not byID[id] or worth > byID[id] then byID[id] = worth end
end

local function Rank(slot, weights)
    local byID = wipe(scores[slot] or {})
    scores[slot] = byID
    for id, worth in pairs(base[slot]) do byID[id] = worth end
    AddWorn(byID, slot, slot, weights)
    if PAIR[slot] then AddWorn(byID, PAIR[slot], slot, weights) end
    local order = wipe(ranked[slot] or {})
    ranked[slot] = order
    for id in pairs(byID) do order[#order + 1] = id end
    sortBy = byID
    table.sort(order, TRINKETS[slot] and BySim or ByScore)
end

local function PairWeapons()
    local main, off, offScores = ranked[MAIN_HAND], ranked[OFF_HAND], scores[OFF_HAND]
    local byID = scores[MAIN_HAND]
    for _, id in ipairs(main) do
        local other = off[1] == id and off[2] or off[1]
        if other and not Items.IsTwoHand(id) then byID[id] = byID[id] + offScores[other] end
    end
    sortBy = byID
    table.sort(main, ByScore)
end

local function Take(order, skip, out)
    wipe(out)
    for i = 1, #order do
        if order[i] ~= skip then out[#out + 1] = order[i] end
        if #out == PICKS then break end
    end
    return out
end

local function Same(list, slot, picks)
    local old = B.Picks(list, slot, current)
    if #old ~= #picks then return false end
    for i = 1, #picks do
        if old[i] ~= picks[i] then return false end
    end
    return true
end

local function Frame()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    return events
end

local function Listen()
    if waiting then
        Frame():RegisterEvent(LOADED)
    elseif events then
        events:UnregisterEvent(LOADED)
    end
end

local Auto = {}
B.Auto = Auto

function Auto.Build(spec)
    local weights = SW.For(spec.key)
    if not weights then
        waiting = false
        return Listen()
    end
    local top = UnitLevel("player") + S.Get("bisAutoAhead")
    if spec.key ~= scoredKey or weights ~= scoredWeights or top ~= scoredTop then
        waiting = false
        wipe(pending)
        Gather(spec)
        ScorePool(weights, top)
        scoredKey, scoredWeights, scoredTop, poolWaiting = spec.key, weights, top, waiting
    end
    waiting = poolWaiting
    for _, gear in ipairs(Items.GEAR_SLOTS) do Rank(gear[1], weights) end
    PairWeapons()
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local slot = gear[1]
        local before = AFTER[slot] and chosen[AFTER[slot]][1]
        chosen[slot] = Take(ranked[slot], before, chosen[slot] or {})
    end
    local main = chosen[MAIN_HAND][1]
    if main and Items.IsTwoHand(main) then wipe(chosen[OFF_HAND]) end
    Listen()
    return chosen, waiting
end

function Auto.Fill(list)
    local picks = Auto.Build(L.CurrentSpec())
    if not picks then return false end
    local changed = false
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local slot = gear[1]
        if not (list.kept and list.kept[slot]) and not Same(list, slot, picks[slot]) then
            B.Store(list, slot, picks[slot])
            changed = true
        end
    end
    return changed
end

local function Refresh()
    queued = false
    local list = watching and L.List()
    if list and list.auto and Auto.Fill(list) then L.Changed() end
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(REFRESH_DELAY, Refresh)
end

function OnEvent(_, event, itemID, success)
    if event == LOADED then
        if not (pending[itemID] and success) then return end
        scoredKey = nil
    end
    Queue()
end

local function Watch()
    local list = B.On() and L.List()
    local id = list and list.auto and list.id or nil
    if id == watching then return end
    watching = id
    for _, event in ipairs(EVENTS) do
        if id then Frame():RegisterEvent(event) elseif events then events:UnregisterEvent(event) end
    end
    if id then Queue() end
end

local function OnWeights()
    if watching then Queue() end
end

local function OnSetting(key)
    if key == "bis" then
        Watch()
    elseif key == "bisPvP" then
        scoredKey = nil
        if watching then Queue() end
    elseif key == "bisAutoAhead" and watching then
        Queue()
    end
end

B.OnListChange(Watch)
SW.OnChange(OnWeights)
S.OnChange(OnSetting)
ns.OnApply(Watch)
