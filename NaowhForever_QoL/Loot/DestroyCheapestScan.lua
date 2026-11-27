-- DestroyCheapestScan.lua: which bag and loot items are safe to offer, and what they are worth.
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local D = ns.DestroyCheapest
local S = ns.QoLSettings

local SELL = ns.QoLConstants.SELL_PRICE
local FISHING = Enum.ItemWeaponSubclass.Fishingpole
local BIND_ON_ACQUIRE = Enum.ItemBind.OnAcquire
local BIND_QUEST = Enum.ItemBind.Quest
local CLASS = { CONSUMABLE = 0, WEAPON = 2, ARMOR = 4, PROJECTILE = 6, RECIPE = 9, QUIVER = 11, QUEST = 12, KEY = 13 }
local KEEP_CLASS = {
    [CLASS.PROJECTILE] = true, [CLASS.RECIPE] = true,
    [CLASS.QUIVER] = true, [CLASS.QUEST] = true, [CLASS.KEY] = true,
}
local QUALITY_KEY = {
    [0] = "destroyCheapestPoor", [1] = "destroyCheapestCommon",
    [2] = "destroyCheapestUncommon", [3] = "destroyCheapestRare",
    [4] = "destroyCheapestEpic", [5] = "destroyCheapestLegendary",
    [6] = "destroyCheapestArtifact", [7] = "destroyCheapestHeirloom",
}
local TOOLS = {
    [6948] = true, [5060] = true, [2901] = true, [7005] = true, [6256] = true, [5956] = true, [6219] = true,
    [10498] = true, [9149] = true, [6217] = true, [6218] = true, [6338] = true, [6339] = true,
    [11128] = true, [11130] = true, [11144] = true, [11145] = true, [16206] = true, [16207] = true,
}

local maxValue = 0

local function QualityOn(quality)
    local key = QUALITY_KEY[quality]
    if not key then return false end
    return S.Get(key) == true
end

local function ConsumableOn()
    return S.Get("destroyCheapestConsumable") == true
end

local function ShowAll()
    return S.Get("destroyCheapestAll") == true
end

local function ZeroVendorOn()
    return S.Get("destroyCheapestZeroVendor") == true
end

local function BoundGearOn()
    return S.Get("destroyCheapestBoundGear") == true
end

local function QuestSlot(bag, slot)
    local api = C_Container.GetContainerItemQuestInfo
    if not api then return false end
    local q = api(bag, slot)
    if type(q) == "table" then return (q.isQuestItem or q.questID) and true or false end
    return q and true or false
end

local function ReadSets()
    local setItems = D.setItems
    wipe(setItems)
    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetItemIDs) then return end
    local ids = C_EquipmentSet.GetEquipmentSetIDs()
    if not ids then return end
    for i = 1, #ids do
        local items = C_EquipmentSet.GetItemIDs(ids[i])
        if items then
            for _, itemID in pairs(items) do
                if type(itemID) == "number" and itemID > 0 then setItems[itemID] = true end
            end
        end
    end
end

local function InSet(bag, slot, itemID)
    local api = C_Container.GetContainerItemEquipmentSetInfo
    if api and api(bag, slot) then return true end
    return D.setItems[itemID] or false
end

local function BoundGear(classID, info, bindType)
    if classID ~= CLASS.WEAPON and classID ~= CLASS.ARMOR then return false end
    if info.isBound then return true end
    return bindType == BIND_ON_ACQUIRE
end

local function Kept(bag, slot, info, quality, vendor, classID, subclassID, bindType, setID)
    if D.Ignored(info.itemID) then return true end
    if KEEP_CLASS[classID] then return true end
    if setID and setID > 0 then return true end
    if classID == CLASS.WEAPON and subclassID == FISHING then return true end
    if TOOLS[info.itemID] or ns.IsLibraryBook(info.itemID) then return true end
    if InSet(bag, slot, info.itemID) then return true end
    if ns.IsBisItem and ns.IsBisItem(info.itemID) then return true end
    if QuestSlot(bag, slot) then return true end
    if BIND_QUEST and bindType == BIND_QUEST then return true end
    if BoundGear(classID, info, bindType) and not BoundGearOn() then return true end
    if ShowAll() then return false end
    if quality == nil or quality < 0 or not QualityOn(quality) then return true end
    if not vendor or vendor <= 0 then
        if (classID ~= CLASS.CONSUMABLE or not ConsumableOn()) and not ZeroVendorOn() then return true end
    end
    return false
end

local function MaxValue()
    if ShowAll() then return 0 end
    local cap = S.Get("bagCleanupMaxValue")
    if type(cap) ~= "number" then return 0 end
    return cap
end

local function OverCap(worth, cap)
    return cap > 0 and type(worth) == "number" and worth > cap
end

function D.UseMarket()
    return S.Get("destroyCheapestMarket") == true
end

local function RankMarket()
    return S.Get("destroyCheapestMarketRank") == true
end

local function StaleOn()
    return S.Get("destroyCheapestMarketStale") == true
end

local function StaleLimit()
    local days = S.Get("destroyCheapestMarketDays")
    if type(days) ~= "number" or days < 1 then days = D.STALE_DAYS end
    return ns.QoLConstants.SECONDS_PER_DAY * days
end

function D.Quote(itemID)
    if not (itemID and ns.AuctionPrice) then return end
    local price, at = ns.AuctionPrice(itemID)
    if type(price) ~= "number" or price <= 0 then return end
    local age
    if type(at) == "number" then
        age = GetServerTime() - at
        if age < 0 then age = 0 end
    end
    if not StaleOn() then return price, age, true end
    if not age then return price, nil, false end
    return price, age, age <= StaleLimit()
end

local function ApplyMarket(e, itemID, count)
    e.market, e.marketUnit, e.marketKnown = nil, nil, nil
    e.marketAge, e.marketFresh, e.marketChecked = nil, nil, nil
    if not (RankMarket() and itemID) then return end
    e.marketChecked = true
    local price, age, fresh = D.Quote(itemID)
    e.marketKnown = type(price) == "number" and price > 0
    if not e.marketKnown then return end
    e.market, e.marketUnit = price * (count or 1), price
    e.marketAge, e.marketFresh = age, fresh
end

local function RankValue(e)
    if type(e) ~= "table" then return end
    local count = D.RankQty() == "unit" and 1 or (e.count or 1)
    if RankMarket() and e.marketFresh and type(e.marketUnit) == "number" then
        return e.marketUnit * count
    end
    if e.vendorKnown and type(e.vendorUnit) == "number" then return e.vendorUnit * count end
    return e.value
end

local function CapValue(e)
    if type(e) ~= "table" then return end
    local count = e.count or 1
    if RankMarket() and e.marketFresh and type(e.marketUnit) == "number" then
        return e.marketUnit * count
    end
    if e.vendorKnown and type(e.vendorUnit) == "number" then return e.vendorUnit * count end
    return e.value
end

local function Cheaper(a, b)
    local ar, br = a.rank or a.value, b.rank or b.value
    if ar ~= br then return ar < br end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

local function Take()
    D.used = D.used + 1
    local e = D.pool[D.used]
    if not e then
        e = {}
        D.pool[D.used] = e
    end
    return e
end

local function ReadQuality(fromBag, fromItem)
    local quality = fromBag
    if type(quality) ~= "number" then quality = fromItem end
    if type(fromItem) == "number" and type(quality) == "number" and fromItem > quality then
        quality = fromItem
    end
    if type(quality) ~= "number" or quality < 0 then return end
    return quality
end

local function WornVendor(vendor, bag, slot, classID)
    if S.Get("destroyCheapestDurability") ~= true then return vendor, false end
    if type(vendor) ~= "number" or vendor <= 0 then return vendor, false end
    if classID ~= CLASS.WEAPON and classID ~= CLASS.ARMOR then return vendor, false end
    local api = C_Container.GetContainerItemDurability
    if not api then return vendor, false end
    local current, maximum = api(bag, slot)
    if type(current) ~= "number" or type(maximum) ~= "number"
        or maximum <= 0 or current < 0 or current >= maximum then
        return vendor, false
    end
    return math.floor(vendor * current / maximum), true
end

local function ItemFacts(info, bag, slot)
    local query = info.hyperlink or info.itemID
    local name, _, itemQuality, _, _, _, _, _, _, _, vendor, infoClass, infoSub, bindType, _, setID =
        GetItemInfo(query)
    local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(query)
    if type(classID) ~= "number" then classID = infoClass end
    if type(subclassID) ~= "number" then subclassID = infoSub end
    local estimated
    vendor, estimated = WornVendor(vendor, bag, slot, classID)
    return name, ReadQuality(info.quality, itemQuality), vendor, classID, subclassID, bindType, setID, estimated
end

local function Queue(itemID)
    if not itemID or D.requested[itemID] then
        if itemID then D.waitingInfo[itemID] = true end
        return
    end
    D.requested[itemID] = true
    D.waitingInfo[itemID] = true
    D.loadCount = D.loadCount + 1
    D.pendingLoads[D.loadCount] = itemID
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
end

function D.FlushLoads()
    if D.loadCount == 0 then return end
    local batch, n = {}, D.loadCount
    for i = 1, n do
        batch[i] = D.pendingLoads[i]
        D.pendingLoads[i] = nil
    end
    D.loadCount = 0
    local items = ns.Shared and ns.Shared.Items
    if not (items and items.OnLoaded) then return end
    items.OnLoaded(batch, function()
        if D.pending or not D.Opened() then return end
        if D.scanning then
            D.scanAgain = true
            return
        end
        D.Refresh()
    end)
end

local function Offerable(bag, slot, info)
    local name, quality, vendor, classID, subclassID, bindType, setID, estimated = ItemFacts(info, bag, slot)
    local showAll = ShowAll()
    if name == nil or (quality == nil and not showAll) then return nil end
    if vendor == nil then
        if not showAll and (classID ~= CLASS.CONSUMABLE or not ConsumableOn()) then return nil end
        vendor = 0
    end
    if Kept(bag, slot, info, quality, vendor, classID, subclassID, bindType, setID) then return false end
    return true, name, quality, vendor, classID, estimated
end

local function ScanSlot(bag, slot)
    local info = GetContainerItemInfo(bag, slot)
    if not (info and info.itemID) or info.isLocked then return end
    local offer, name, quality, vendor, classID, estimated = Offerable(bag, slot, info)
    if offer == nil then return Queue(info.itemID) end
    if not offer then return end
    local e = Take()
    local count = info.stackCount or 1
    e.bag, e.slot, e.itemID = bag, slot, info.itemID
    e.link, e.icon, e.name = info.hyperlink, info.iconFileID, name
    e.count, e.quality, e.value = count, quality, vendor * count
    e.classID = classID
    e.vendor, e.vendorUnit, e.vendorKnown = vendor, vendor, true
    e.vendorEstimated = estimated == true
    e.vendorTotal = e.value
    ApplyMarket(e, info.itemID, count)
    e.rank = RankValue(e)
    if OverCap(CapValue(e), maxValue) then
        D.used = D.used - 1
        return
    end
    D.picks[#D.picks + 1] = e
end

function D.Scan()
    if D.scanning then
        D.scanAgain = true
        return
    end
    D.scanning = true
    local keepBag, keepSlot, keepID
    local current = D.picks[D.index]
    if current then keepBag, keepSlot, keepID = current.bag, current.slot, current.itemID end
    for i = #D.picks, 1, -1 do D.picks[i] = nil end
    D.used = 0
    wipe(D.waitingInfo)
    ReadSets()
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    local everyBag = ShowAll()
    maxValue = MaxValue()
    for bag = BACKPACK_CONTAINER, last do
        if everyBag or D.IsPlain(bag) then
            for slot = 1, GetContainerNumSlots(bag) or 0 do ScanSlot(bag, slot) end
        end
    end
    table.sort(D.picks, Cheaper)
    D.index = 1
    if keepID then
        for i = 1, #D.picks do
            local e = D.picks[i]
            if e.itemID == keepID and e.bag == keepBag and e.slot == keepSlot then
                D.index = i
                break
            end
        end
    end
    D.scanning = false
    if D.scanAgain then
        D.scanAgain = false
        D.Scan()
    end
end

local function LootTake()
    D.lootUsed = D.lootUsed + 1
    local e = D.lootPool[D.lootUsed]
    if not e then
        e = {}
        D.lootPool[D.lootUsed] = e
    end
    return e
end

function D.SlotOpen(slot)
    if not D.LootShown() then return false end
    if not LootSlotHasItem(slot) then return false end
    local _, _, _, _, _, locked = GetLootSlotInfo(slot)
    return not locked
end

function D.ReadLoot()
    local keep = D.loots[D.lootIndex]
    local keepSlot = keep and keep.slot
    for i = #D.loots, 1, -1 do D.loots[i] = nil end
    D.lootUsed = 0
    D.lootIndex = 1
    if not D.LootShown() then return end
    for i = 1, GetNumLootItems() or 0 do
        if LootSlotHasItem(i) and GetLootSlotType(i) == LOOT_SLOT_ITEM then
            local texture, name, qty, currencyID, quality, _, isQuest, questID, _, isCoin = GetLootSlotInfo(i)
            if texture and not isCoin and not currencyID then
                local link = GetLootSlotLink(i)
                local vendor = link and select(SELL, GetItemInfo(link))
                if link and vendor == nil then Queue(GetItemInfoInstant(link)) end
                local e = LootTake()
                e.slot, e.link, e.icon, e.name = i, link, texture, name
                e.itemID = link and GetItemInfoInstant(link) or nil
                e.count, e.quality = qty or 1, quality
                e.quest = (isQuest or questID) and true or false
                e.vendor = vendor
                e.vendorUnit, e.vendorKnown, e.vendorEstimated = vendor, vendor ~= nil, nil
                e.vendorTotal = vendor and vendor * e.count or nil
                e.value = e.vendorTotal
                ApplyMarket(e, e.itemID, e.count)
                D.loots[#D.loots + 1] = e
                if e.slot == keepSlot then D.lootIndex = #D.loots end
            end
        end
    end
end

function D.Matches(pick)
    if type(pick) ~= "table" then return false end
    local info = GetContainerItemInfo(pick.bag, pick.slot)
    if not (info and info.itemID == pick.itemID) or info.isLocked then return false end
    if info.hyperlink ~= pick.link or (info.stackCount or 1) ~= pick.count then return false end
    if not ShowAll() and not D.IsPlain(pick.bag) then return false end
    local offer, _, _, vendor = Offerable(pick.bag, pick.slot, info)
    if not offer or vendor * pick.count ~= pick.value then return false end
    local worth = pick.value
    if RankMarket() then
        local price, _, fresh = D.Quote(pick.itemID)
        if price and fresh then worth = price * pick.count end
    end
    return not OverCap(worth, MaxValue())
end

function D.WorthIt(pick, loot)
    if not loot or loot.quest then return true end
    if pick.vendorKnown and pick.vendorUnit <= 0 and D.UseMarket() then
        D.EnsureMarket(pick)
        if pick.marketKnown and type(pick.marketUnit) == "number" and pick.marketUnit > 0 then return false end
    end
    local offer = RankValue(pick)
    local gain = RankValue(loot)
    if type(offer) ~= "number" or type(gain) ~= "number" then return false end
    return gain >= offer
end
