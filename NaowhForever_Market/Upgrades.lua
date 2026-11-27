-- Upgrades.lua: the gear in your scans that would make you stronger than what you wear, at or under your price (Market.Upgrades).
local ns = _G.NaowhForever

local GetItemInfo, IsItemDataCachedByID = C_Item.GetItemInfo, C_Item.IsItemDataCachedByID

local Market = ns.Market
local S = Market.Settings
local Items = ns.Shared.Items

local REQUIRED_LEVEL = 5
local WARM_CHUNK = 200
local LOADED_DELAY = 0.5

local gains, levels, asked = {}, {}, {}
local listed, notify, pending

local Upgrades = { gains = gains, levels = levels }
Market.Upgrades = Upgrades

function Upgrades.On()
    return Market.On() and S.Get("cheapUpgrades") == true
end

local function Weights()
    local SW = ns.StatWeights
    local key = SW and SW.ActiveSpec()
    local weights = key and SW.For(key)
    if not weights then return nil end
    return SW, weights, SW.Power(weights)
end

local function Loaded()
    pending = false
    if notify then notify() end
end

local function ItemLoaded()
    if pending then return end
    pending = true
    C_Timer.After(LOADED_DELAY, Loaded)
end

local function Warm(ids)
    local first = 1
    local function Batch()
        local last = math.min(first + WARM_CHUNK - 1, #ids)
        local chunk = {}
        for i = first, last do chunk[#chunk + 1] = ids[i] end
        first = last + 1
        Items.OnLoaded(chunk, ItemLoaded)
        if first <= #ids then C_Timer.After(0, Batch) end
    end
    Batch()
end

function Upgrades.Order(a, b)
    local ga, gb = gains[a], gains[b]
    if ga ~= gb then return ga > gb end
    local pa, pb = listed[a], listed[b]
    if pa ~= pb then return pa < pb end
    return a < b
end

function Upgrades.ByLevel(a, b)
    local la, lb = levels[a], levels[b]
    if la ~= lb then return la > lb end
    return Upgrades.Order(a, b)
end

function Upgrades.Price(id)
    return listed and listed[id]
end

function Upgrades.Find(onLoaded)
    wipe(gains)
    wipe(levels)
    notify = onLoaded
    listed = ns.AuctionPriceList and ns.AuctionPriceList()
    if not listed then return "scan" end
    local SW, weights, power = Weights()
    if not weights then return "weights" end
    local most, level = S.Get("upgradesMax"), UnitLevel("player")
    local cold
    for id, price in pairs(listed) do
        if price <= most and Items.SlotsFor(id) then
            if not IsItemDataCachedByID(id) then
                if not asked[id] then
                    asked[id] = true
                    cold = cold or {}
                    cold[#cold + 1] = id
                end
            else
                local required = select(REQUIRED_LEVEL, GetItemInfo(id)) or 0
                if required <= level then
                    gains[id] = SW.BestGain(id, nil, weights, power)
                    levels[id] = required
                end
            end
        end
    end
    if cold then Warm(cold) end
end
