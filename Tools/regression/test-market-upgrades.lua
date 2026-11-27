-- Run with Lua 5.1 from the repository root: The Market's Cheap Upgrades. Only gear in your scans at or under your
-- price is weighed, never above your level; pieces not cached yet are asked for once; no scan or no weights say so;
-- the list orders by the biggest upgrade, then the cheapest, or by required level, highest first; and pieces
-- arriving redraw once, not once each.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local settings = { enabled = true, cheapUpgrades = true, upgradesMax = 1000 }
local prices
local GEAR = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true }
local required = { [1] = 18, [2] = 10, [3] = 30, [4] = 10, [5] = 10, [6] = 10 }
local cached = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = false, [7] = true }
local GAIN = { [1] = 2.5, [2] = 4, [3] = 9, [4] = 4, [6] = 1 }
local weighed, loadedAsks, timers = {}, {}, {}
local weights = { str = 1 }

local ns = {
    AuctionPriceList = function() return prices end,
    Shared = { Items = {
        SlotsFor = function(id) return GEAR[id] and { 1 } or nil end,
        OnLoaded = function(ids, fn) loadedAsks[#loadedAsks + 1] = { ids = ids, fn = fn } end,
    } },
    Market = {
        On = function() return settings.enabled end,
        Settings = { Get = function(key) return settings[key] end },
    },
}
ns.StatWeights = {
    ActiveSpec = function() return "arms-warrior" end,
    For = function() return weights end,
    Power = function() return 100 end,
    BestGain = function(id, link, w, power)
        weighed[#weighed + 1] = id
        assert(link == nil and w == weights and power == 100)
        return GAIN[id]
    end,
}

local fn = assert(loadfile("NaowhForever_Market/Upgrades.lua"))
setfenv(fn, setmetatable({
    _G = { NaowhForever = ns },
    C_Item = {
        GetItemInfo = function(id) return "Item " .. id, nil, nil, nil, required[id] end,
        IsItemDataCachedByID = function(id) return cached[id] end,
    },
    C_Timer = { After = function(_, f) timers[#timers + 1] = f end },
    UnitLevel = function() return 20 end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G }))
fn()
local Upgrades = ns.Market.Upgrades

local function Sorted(order)
    local list = {}
    for id in pairs(Upgrades.gains) do list[#list + 1] = id end
    table.sort(list, order or Upgrades.Order)
    return list
end

check("on only with The Market and Cheap Upgrades on", Upgrades.On())
settings.cheapUpgrades = false
check("Cheap Upgrades off is off", not Upgrades.On())
settings.cheapUpgrades = true

prices = nil
check("no scan says so", Upgrades.Find() == "scan" and next(Upgrades.gains) == nil)

prices = { [1] = 500, [2] = 900, [3] = 100, [4] = 300, [5] = 200, [6] = 50, [7] = 10, [8] = 5000 }
local redraws = 0
local onLoaded = function() redraws = redraws + 1 end
check("a scan with weights finds", Upgrades.Find(onLoaded) == nil)
local list = Sorted()
check("biggest upgrade first, the cheaper of two equal ones before the other", list[1] == 4 and list[2] == 2
    and list[3] == 1 and #list == 3)
local byLevel = Sorted(Upgrades.ByLevel)
check("by level, the highest required level first, then the biggest upgrade", byLevel[1] == 1 and byLevel[2] == 4
    and byLevel[3] == 2 and Upgrades.levels[1] == 18 and Upgrades.levels[4] == 10)
check("a piece over your level is not weighed", Upgrades.gains[3] == nil)
check("a piece that is no upgrade is left out", Upgrades.gains[5] == nil)
check("an item that is not gear is never weighed", Upgrades.gains[7] == nil)
for _, id in ipairs(weighed) do check("weighed only cached gear in your level: " .. id, id ~= 3 and id ~= 6 and id ~= 7) end
check("a piece not cached yet is asked for", #loadedAsks == 1 and loadedAsks[1].ids[1] == 6)
check("the scan's price is the one shown", Upgrades.Price(4) == 300 and Upgrades.Price(99) == nil)
timers = {}
loadedAsks[1].fn()
loadedAsks[1].fn()
check("pieces arriving together wait for one redraw", #timers == 1 and redraws == 0)
timers[1]()
check("then redraw once", redraws == 1)
loadedAsks[1].fn()
check("a later piece waits for another", #timers == 2)
timers[2]()
check("and redraws again", redraws == 2)
timers = {}

settings.upgradesMax = 400
Upgrades.Find(onLoaded)
list = Sorted()
check("a lower price leaves out what costs more", #list == 1 and list[1] == 4)
check("and a piece asked for once is not asked again", #loadedAsks == 1)

cached[6] = true
settings.upgradesMax = 1000
Upgrades.Find(onLoaded)
check("once cached it is weighed", Upgrades.gains[6] == 1 and Sorted()[4] == 6)

weights = nil
check("no weights says so", Upgrades.Find(onLoaded) == "weights" and next(Upgrades.gains) == nil)
weights = { str = 1 }
ns.StatWeights, ns.StatWeights_ = nil, ns.StatWeights
check("without Stat Weights loaded, no weights", Upgrades.Find(onLoaded) == "weights")
ns.StatWeights = ns.StatWeights_

for id = 100, 100 + 450 do
    GEAR[id], cached[id], prices[id] = true, false, 1
end
loadedAsks = {}
Upgrades.Find(onLoaded)
check("many cold pieces are asked for in chunks across frames", #loadedAsks == 1 and #timers == 1)
timers[1]()
check("the next chunk on the next frame", #loadedAsks == 2 and #timers == 2)
timers[2]()
local asked = 0
for _, ask in ipairs(loadedAsks) do asked = asked + #ask.ids end
check("every cold piece asked for once", #loadedAsks == 3 and asked == 451)

print(("test-market-upgrades: %d checks passed"):format(checks))
