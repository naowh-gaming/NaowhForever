-- DestroyCheapestScan.lua: which bag and loot items are safe to offer, and what they are worth.
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local D = ns.DestroyCheapest
local S = ns.QoLSettings

local FISHING = Enum.ItemWeaponSubclass.Fishingpole
local BIND_ON_ACQUIRE = Enum.ItemBind.OnAcquire
local BIND_QUEST = Enum.ItemBind.Quest
local LOOT_NONE, LOOT_ITEM, LOOT_MONEY, LOOT_CURRENCY = 0, 1, 2, 3
local CLASS = { CONSUMABLE = 0, WEAPON = 2, ARMOR = 4, PROJECTILE = 6, RECIPE = 9, QUIVER = 11, QUEST = 12, KEY = 13, TRADE = 7 }
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
local QUALITY_NAME = {
    [0] = "poor", [1] = "common", [2] = "uncommon", [3] = "rare",
    [4] = "epic", [5] = "legendary", [6] = "artifact", [7] = "heirloom",
}
local TOOLS = {
    [6948] = true, [5060] = true, [2901] = true, [7005] = true, [6256] = true, [5956] = true, [6219] = true,
    [10498] = true, [9149] = true, [6217] = true, [6218] = true, [6338] = true, [6339] = true,
    [11128] = true, [11130] = true, [11144] = true, [11145] = true, [16206] = true, [16207] = true,
}
local TRACE_CAP = 100
local FAIL_CAP = 2

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

local function QualityOn(quality)
    local key = QUALITY_KEY[quality]
    if not key then return false end
    return D.Opt(key) == true
end

local function ConsumableOn()
    return D.Opt("destroyCheapestConsumable") == true
end

local function ShowAll()
    return D.Opt("destroyCheapestAll") == true
end

local function QuestMarked(isQuest, questID)
    if isQuest == true then return true end
    if type(questID) == "number" and questID > 0 then return true end
    if type(isQuest) == "number" and isQuest > 0 and questID == nil then return true end
    return false
end

local function QuestSlot(bag, slot)
    local api = C_Container.GetContainerItemQuestInfo
    if not api then return false end
    local a, b = api(bag, slot)
    if type(a) == "table" then return QuestMarked(a.isQuestItem, a.questID) end
    return QuestMarked(a, b)
end

local function ReadSets()
    if D.keepSets then
        D.PerfAdd("setHits")
        return
    end
    D.PerfAdd("setBuilds")
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

function D.Exclusion(bag, slot, info, quality, unit, known, classID, subclassID, bindType, setID)
    if D.Ignored(info.itemID) then return "ignored" end
    if QuestSlot(bag, slot) then return "quest" end
    if BIND_QUEST and bindType == BIND_QUEST then return "quest-bind" end
    if type(classID) ~= "number" then return "unloaded" end
    if KEEP_CLASS[classID] then return "protected-class" end
    if setID and setID > 0 then return "item-set" end
    if classID == CLASS.WEAPON and subclassID == FISHING then return "fishing" end
    if TOOLS[info.itemID] or D.LibraryCached(info.itemID) then return "tool" end
    if InSet(bag, slot, info.itemID) then return "equipment-set" end
    if D.BisCached(info.itemID) then return "bis" end
    if BoundGear(classID, info, bindType) and D.Opt("destroyCheapestBoundGear") ~= true then
        return "bound-gear"
    end
    if not known then return "vendor-unknown" end
    if ShowAll() then return nil end
    if quality == nil or quality < 0 or not QualityOn(quality) then return "quality" end
    if unit <= 0 then
        if classID == CLASS.CONSUMABLE and ConsumableOn() then return nil end
        if D.Opt("destroyCheapestZeroVendor") == true then return nil end
        return "vendor-zero"
    end
    return nil
end

function D.UseMarket()
    return D.Opt("destroyCheapestMarket") == true
end

local function RankMarket()
    return D.Opt("destroyCheapestMarketRank") == true
end

local function StaleOn()
    return D.Opt("destroyCheapestMarketStale") == true
end

local function StaleLimit()
    local days = D.Opt("destroyCheapestMarketDays")
    if type(days) ~= "number" or days < 1 then days = D.STALE_DAYS end
    return ns.QoLConstants.SECONDS_PER_DAY * days
end

local AH = { ok = {}, price = {}, age = {}, fresh = {} }
local INFO = { name = {}, quality = {}, sell = {}, class = {}, sub = {}, bind = {}, set = {} }
local CLASS_OF = { class = {}, sub = {} }
D.ahCache, D.infoCache, D.classCache = AH, INFO, CLASS_OF

local function WipeAll(group)
    for _, t in pairs(group) do wipe(t) end
end

local function Count(name)
    local perf = D.perf
    if perf then perf[name] = (perf[name] or 0) + 1 end
end

function D.Quote(itemID)
    if not (itemID and ns.AuctionPrice) then return end
    if D.caching and AH.ok[itemID] ~= nil then
        local perf = D.perf
        if perf then perf.quoteHits = (perf.quoteHits or 0) + 1 end
        if not AH.ok[itemID] then return end
        return AH.price[itemID], AH.age[itemID], AH.fresh[itemID]
    end
    Count("quotes")
    local price, at = ns.AuctionPrice(itemID)
    local age, fresh
    local okPrice = type(price) == "number" and price > 0
    if okPrice then
        if type(at) == "number" then
            age = GetServerTime() - at
            if age < 0 then age = 0 end
        end
        if not StaleOn() then
            fresh = true
        elseif not age then
            fresh = false
        else
            fresh = age <= StaleLimit()
        end
    end
    if D.caching then
        AH.ok[itemID] = okPrice
        AH.price[itemID] = okPrice and price or nil
        AH.age[itemID] = age
        AH.fresh[itemID] = fresh
    end
    if not okPrice then return end
    return price, age, fresh
end

function D.SeedIgnore()
    local db = S.DB()
    if type(db) ~= "table" or db.destroyCheapestIgnoreSeeded == true then return end
    local list = db.destroyCheapestIgnore
    if type(list) ~= "table" then
        list = {}
        db.destroyCheapestIgnore = list
    end
    for id in pairs(TOOLS) do
        if type(id) == "number" and list[id] == nil then list[id] = 0 end
    end
    db.destroyCheapestIgnoreSeeded = true
end

function D.ItemIsReagent(itemID, classID)
    if type(itemID) == "number" and C_Item and type(C_Item.IsReagent) == "function" then
        local ok, result = pcall(C_Item.IsReagent, itemID)
        if ok and type(result) == "boolean" then return result end
    end
    return classID == CLASS.TRADE
end

function D.ItemValue(e)
    if type(e) ~= "table" then return nil, "unknown" end
    local count = e.count or 1
    if type(count) ~= "number" or count < 1 then count = 1 end
    local unitRank = D.RankQty() == "unit"
    local byMarket = RankMarket()
    local qty = 1
    if not unitRank then qty = count end
    if byMarket and e.marketFresh == true then
        if type(e.marketUnit) == "number" and e.marketUnit > 0 then
            return e.marketUnit * qty, "ah"
        end
        if e.marketUnit == nil and type(e.market) == "number" and e.market > 0 then
            if unitRank then return e.market / count, "ah" end
            return e.market, "ah"
        end
    end
    if e.vendorKnown == true and type(e.vendorUnit) == "number" then
        local source = "vendor"
        if byMarket then source = "vendor-fallback" end
        return e.vendorUnit * qty, source
    end
    return nil, "unknown"
end

function D.ApplyMarket(e, itemID, count)
    e.market, e.marketUnit, e.marketTotal = nil, nil, nil
    e.marketAge, e.marketFresh, e.marketKnown = nil, nil, false
    e.marketChecked = true
    local trace = D.traceOn == true
    if not (itemID and (RankMarket() or D.UseMarket() or trace)) then return end
    local price, age, fresh = D.Quote(itemID)
    if not price then return end
    local n = count or 1
    e.marketKnown = true
    e.marketUnit = price
    e.marketTotal = price * n
    e.market = e.marketTotal
    e.marketAge, e.marketFresh = age, fresh
end

local function ClearMarket(e)
    e.market, e.marketUnit, e.marketTotal = nil, nil, nil
    e.marketAge, e.marketFresh, e.marketKnown = nil, nil, false
    e.marketChecked = false
end

function D.EnsureMarket(e)
    if type(e) ~= "table" or e.marketChecked or not e.itemID then return end
    if not (RankMarket() or D.UseMarket()) then return end
    D.ApplyMarket(e, e.itemID, e.count or 1)
end

local function RankValue(e)
    return (D.ItemValue(e))
end

local function Cheaper(a, b)
    local ar, br = a.rank, b.rank
    if ar == nil then ar = a.value end
    if br == nil then br = b.value end
    if ar == nil or br == nil then
        if ar ~= br then return ar ~= nil end
    elseif ar ~= br then
        return ar < br
    end
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

local function ReadQuality(fromSlot, fromItem)
    fromSlot, fromItem = Plain(fromSlot), Plain(fromItem)
    if type(fromSlot) == "number" and fromSlot >= 0 then return fromSlot end
    if type(fromItem) == "number" and fromItem >= 0 then return fromItem end
end

local function InfoOf(query)
    if query == nil or query == "" then return end
    local caching = D.caching
    if caching and INFO.name[query] ~= nil then
        local perf = D.perf
        if perf then perf.infoHits = (perf.infoHits or 0) + 1 end
        return INFO.name[query], INFO.quality[query], INFO.sell[query], INFO.class[query],
            INFO.sub[query], INFO.bind[query], INFO.set[query]
    end
    Count("infos")
    local name, _, quality, _, _, _, _, _, _, _, sell, classID, subclassID, bindType, _, setID =
        GetItemInfo(query)
    if name == nil then return end
    quality, sell, bindType, setID = Plain(quality), Plain(sell), Plain(bindType), Plain(setID)
    if caching then
        INFO.name[query], INFO.quality[query], INFO.sell[query] = name, quality, sell
        INFO.class[query], INFO.sub[query], INFO.bind[query], INFO.set[query] = classID, subclassID, bindType, setID
    end
    return name, quality, sell, classID, subclassID, bindType, setID
end

local function Classes(info, infoClass, infoSub)
    local query = info.hyperlink or info.itemID
    local classID, subclassID, _
    if query ~= nil then
        local caching = D.caching
        if caching and CLASS_OF.class[query] ~= nil then
            classID, subclassID = CLASS_OF.class[query], CLASS_OF.sub[query]
        else
            _, _, _, _, _, classID, subclassID = GetItemInfoInstant(query)
            if caching and type(classID) == "number" then
                CLASS_OF.class[query], CLASS_OF.sub[query] = classID, subclassID
            end
        end
    end
    if type(classID) ~= "number" then classID = Plain(infoClass) end
    if type(subclassID) ~= "number" then subclassID = Plain(infoSub) end
    return classID, subclassID
end

local function Worn(unit, bag, slot, classID)
    if D.Opt("destroyCheapestDurability") ~= true then return unit, false end
    if type(unit) ~= "number" or unit <= 0 or type(bag) ~= "number" then return unit, false end
    if classID ~= CLASS.WEAPON and classID ~= CLASS.ARMOR then return unit, false end
    local api = C_Container.GetContainerItemDurability
    if type(api) ~= "function" then return unit, false end
    local cur, maxDur = api(bag, slot)
    cur, maxDur = Plain(cur), Plain(maxDur)
    if not cur or not maxDur or maxDur <= 0 or cur < 0 or cur >= maxDur then return unit, false end
    return math.floor(unit * cur / maxDur), true
end

local function ResolveItem(info)
    local link = info.hyperlink
    local hasLink = type(link) == "string" and link ~= ""
    local name, quality, sell, classID, subclassID, bindType, setID
    if hasLink then
        name, quality, sell, classID, subclassID, bindType, setID = InfoOf(link)
        if name ~= nil then
            if sell == nil then
                return nil, false, "unknown", name, quality, classID, subclassID, bindType, setID
            end
            return sell, true, "link", name, quality, classID, subclassID, bindType, setID
        end
        if not D.loadDone[D.LoadKey(info.itemID, link)] then
            return nil, false, "unloaded"
        end
        local baseName, baseQuality, _, bClass, bSub, bBind, bSet = InfoOf(info.itemID)
        local note = "unknown"
        if baseName ~= nil then note = "unknown base-id " .. tostring(info.itemID) end
        return nil, false, note, baseName, baseQuality, bClass, bSub, bBind, bSet
    end
    name, quality, sell, classID, subclassID, bindType, setID = InfoOf(info.itemID)
    if name == nil then return nil, false, "unloaded" end
    if sell == nil then
        return nil, false, "unknown", name, quality, classID, subclassID, bindType, setID
    end
    return sell, true, "item", name, quality, classID, subclassID, bindType, setID
end

function D.VendorQuote(info, bag, slot)
    if info.hasNoValue == true then
        local name, quality, _, classID, subclassID, bindType, setID = InfoOf(info.hyperlink)
        if name == nil then
            name, quality, _, classID, subclassID, bindType, setID = InfoOf(info.itemID)
        end
        local loadKey = D.LoadKey(info.itemID, info.hyperlink)
        if name == nil and not D.loadDone[loadKey] then
            return nil, false, "unloaded", nil, ReadQuality(info.quality, nil), nil, nil, nil, nil, false
        end
        local iClass, iSub = Classes(info, classID, subclassID)
        return 0, true, "slot", name, ReadQuality(info.quality, quality), iClass, iSub, bindType, setID, false
    end
    local unit, known, source, name, quality, classID, subclassID, bindType, setID = ResolveItem(info)
    local iClass, iSub = Classes(info, classID, subclassID)
    local estimated = false
    if known and type(unit) == "number" then
        local worn
        unit, worn = Worn(unit, bag, slot, iClass)
        if worn then
            source = source .. "+wear-est"
            estimated = true
        end
    end
    return unit, known, source, name, ReadQuality(info.quality, quality), iClass, iSub, bindType, setID, estimated
end

local function StackCount(info)
    if info.stackCount == nil then return 1 end
    local n = Plain(info.stackCount)
    if not n or n < 1 then return nil end
    return math.floor(n)
end


local function Snapshot(t)
    local keys, n = {}, 0
    for k in pairs(t) do
        n = n + 1
        keys[n] = k
    end
    return keys, n
end

function D.SameSlot(meta, info)
    if type(meta) ~= "table" or type(info) ~= "table" then return false end
    if info.itemID ~= meta.itemID then return false end
    if type(meta.link) == "string" and meta.link ~= "" and info.hyperlink ~= meta.link then return false end
    if meta.count ~= nil and StackCount(info) ~= meta.count then return false end
    if meta.quality ~= nil and Plain(info.quality) ~= meta.quality then return false end
    return true
end

local function SlotStill(key)
    local meta = D.waitingInfo[key]
    if type(meta) ~= "table" then meta = D.loadWatch[key] end
    if type(meta) ~= "table" then return false end
    if meta.gen ~= D.loadGen then return false end
    if meta.lootSerial ~= nil and meta.lootSerial ~= (D.lootSerial or 0) then return false end
    if type(meta.bag) ~= "number" then return true end
    return D.SameSlot(meta, GetContainerItemInfo(meta.bag, meta.slot))
end

local function DropWait(key)
    D.waitingInfo[key] = nil
    D.linkQueued[key] = nil
    D.requested[key] = nil
    D.loadWatch[key] = nil
end

function D.LibraryCached(itemID)
    if not (ns.IsLibraryBook and itemID) then return false end
    if D.caching and D.libCache then
        local hit = D.libCache[itemID]
        if hit ~= nil then return hit end
    end
    local found = ns.IsLibraryBook(itemID) and true or false
    if D.caching and D.libCache then D.libCache[itemID] = found end
    return found
end

function D.BisCached(itemID)
    if not (ns.IsBisItem and itemID) then return false end
    if D.caching and D.bisCache then
        local hit = D.bisCache[itemID]
        if hit ~= nil then return hit end
    end
    local found = (ns.IsBisItem and ns.IsBisItem(itemID)) and true or false
    if D.caching and D.bisCache then D.bisCache[itemID] = found end
    return found
end

D.libCache, D.bisCache = {}, {}

function D.WipeCaches()
    WipeAll(INFO)
    WipeAll(AH)
    WipeAll(CLASS_OF)
    wipe(D.libCache)
    wipe(D.bisCache)
end

function D.BeginCache()
    D.caching = true
    D.WipeCaches()
end

function D.EndCache()
    D.caching = false
    D.WipeCaches()
end

function D.ScheduleRefresh()
    D.keepSets = false
    if D.pending then return end
    if D.opening or D.refreshing or D.scanning or D.reading then
        D.scanAgain = true
        return
    end
    if not (D.Opened() or D.traceForce) then return end
    if D.refreshQueued then
        D.PerfAdd("coalesced")
        return
    end
    D.refreshQueued = true
    D.PerfAdd("scheduled")
    local gen = D.openGen
    local function Run()
        D.refreshQueued = false
        if gen ~= D.openGen then return end
        if D.pending then return end
        if not (D.Opened() or D.traceForce) then return end
        if D.Refresh then D.Refresh() end
    end
    if C_Timer and C_Timer.After and not D.refreshNow then
        C_Timer.After(0, Run)
    else
        Run()
    end
end

local function AfterLoad()
    if D.inlineLoad then return end
    D.ScheduleRefresh()
end

function D.FinishLoad(key)
    if type(key) ~= "string" or key == "" then return end
    if D.IsLinkKey(key) and GetItemInfo(D.KeyBody(key)) == nil then return end
    if not D.IsLinkKey(key) then
        local itemID = tonumber(D.KeyBody(key))
        if GetItemInfo(itemID) == nil then return end
    end
    if D.loadDone[key] then
        D.waitingInfo[key] = nil
        D.linkQueued[key] = nil
        return
    end
    D.loadDone[key] = true
    D.waitingInfo[key] = nil
    D.linkQueued[key] = nil
    D.loadWatch[key] = nil
    AfterLoad()
end

function D.FailLoad(key)
    if type(key) ~= "string" or key == "" or D.loadDone[key] then return end
    D.loadFails[key] = (D.loadFails[key] or 0) + 1
    D.linkQueued[key] = nil
    if type(D.waitingInfo[key]) == "table" then D.loadWatch[key] = D.waitingInfo[key] end
    D.waitingInfo[key] = nil
    if D.loadFails[key] < FAIL_CAP then return end
    D.requested[key] = nil
    D.loadWatch[key] = nil
    D.loadDone[key] = true
    AfterLoad()
end

local function MetaFor(itemID, link, bag, slot, count, quality)
    return {
        itemID = itemID,
        link = (type(link) == "string" and link ~= "") and link or nil,
        bag = bag, slot = slot, count = count, quality = Plain(quality),
        gen = D.loadGen or 0,
    }
end

function D.OnItemData(itemID, success)
    if type(itemID) ~= "number" then return end
    local idKey = D.LoadKey(itemID, nil)
    if success == false then
        local keys, n = Snapshot(D.waitingInfo)
        for key in pairs(D.loadWatch) do
            local seen = false
            for i = 1, n do
                if keys[i] == key then seen = true end
            end
            if not seen then
                n = n + 1
                keys[n] = key
            end
        end
        for i = 1, n do
            local key = keys[i]
            local meta = D.waitingInfo[key]
            if type(meta) ~= "table" then meta = D.loadWatch[key] end
            local mine = key == idKey or (type(meta) == "table" and meta.itemID == itemID)
            if not mine and D.IsLinkKey(key) then
                mine = tonumber(key:match("item:(%d+)")) == itemID
            end
            if mine then
                if type(meta) == "table" and meta.gen ~= D.loadGen then
                    DropWait(key)
                elseif type(meta) == "table" and type(meta.bag) == "number" and not SlotStill(key) then
                    DropWait(key)
                else
                    D.FailLoad(key)
                end
            end
        end
        if D.requested[idKey] and not D.loadDone[idKey] then D.FailLoad(idKey) end
        return
    end
    if D.waitingInfo[idKey] or D.requested[idKey] then
        if not SlotStill(idKey) then
            DropWait(idKey)
        elseif not D.linkQueued[idKey] and GetItemInfo(itemID) ~= nil then
            D.FinishLoad(idKey)
        end
    end
    local keys, n = Snapshot(D.waitingInfo)
    for i = 1, n do
        local key = keys[i]
        local meta = D.waitingInfo[key]
        if D.IsLinkKey(key) and type(meta) == "table" and meta.itemID == itemID then
            if meta.gen ~= D.loadGen or not SlotStill(key) then
                DropWait(key)
            elseif GetItemInfo(meta.link) ~= nil then
                D.FinishLoad(key)
            end
        end
    end
end

local function RequestItem(itemID, link, bag, slot, count, quality)
    local key = D.LoadKey(itemID, link)
    if not itemID or D.loadDone[key] then return end
    if (D.loadFails[key] or 0) >= FAIL_CAP then return end
    if D.waitingInfo[key] or D.requested[key] or D.linkQueued[key] then return end
    local meta = MetaFor(itemID, link, bag, slot, count, quality)
    if type(bag) ~= "number" then meta.lootSerial = D.lootSerial or 0 end
    D.waitingInfo[key] = meta
    D.requested[key] = true
    local hasLink = meta.link ~= nil
    if hasLink and Item and Item.CreateFromItemLink then
        local ok, item = pcall(function() return Item:CreateFromItemLink(link) end)
        local empty = ok and item and item.IsItemEmpty and item:IsItemEmpty()
        if ok and item and item.ContinueOnItemLoad and not empty then
            D.linkQueued[key] = true
            local gen = meta.gen
            local lootSerial = meta.lootSerial
            item:ContinueOnItemLoad(function()
                if gen ~= D.loadGen then return end
                if lootSerial ~= nil and lootSerial ~= (D.lootSerial or 0) then
                    DropWait(key)
                    return
                end
                if type(meta.bag) == "number" then
                    local info = GetContainerItemInfo(meta.bag, meta.slot)
                    if not D.SameSlot(meta, info) then
                        DropWait(key)
                        return
                    end
                end
                if GetItemInfo(link) ~= nil then D.FinishLoad(key) else D.FailLoad(key) end
            end)
        end
    end
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    D.loadCount = D.loadCount + 1
    D.pendingLoads[D.loadCount] = itemID
    if not hasLink and GetItemInfo(itemID) ~= nil then D.FinishLoad(key) end
end

local function CompleteItem(itemID)
    local idKey = D.LoadKey(itemID, nil)
    local waiting = false
    if (D.waitingInfo[idKey] or D.requested[idKey]) and not D.loadDone[idKey] then
        if not SlotStill(idKey) then
            DropWait(idKey)
        elseif D.linkQueued[idKey] or GetItemInfo(itemID) == nil then
            waiting = true
        else
            D.FinishLoad(idKey)
        end
    end
    local keys, n = Snapshot(D.waitingInfo)
    for i = 1, n do
        local key = keys[i]
        local meta = D.waitingInfo[key]
        if D.IsLinkKey(key) and type(meta) == "table" and meta.itemID == itemID and not D.loadDone[key] then
            if meta.gen ~= D.loadGen or not SlotStill(key) then
                DropWait(key)
            elseif D.linkQueued[key] or GetItemInfo(meta.link) == nil then
                waiting = true
            else
                D.FinishLoad(key)
            end
        end
    end
    return not waiting
end

local function GiveUp(itemID)
    local idKey = D.LoadKey(itemID, nil)
    if D.requested[idKey] and not D.loadDone[idKey] and not D.linkQueued[idKey] then
        D.FailLoad(idKey)
    end
    local keys, n = Snapshot(D.waitingInfo)
    for i = 1, n do
        local key = keys[i]
        local meta = D.waitingInfo[key]
        local mine = type(meta) == "table" and meta.itemID == itemID
        if mine and not D.loadDone[key] and not D.linkQueued[key] then D.FailLoad(key) end
    end
end

function D.FlushLoads()
    if D.loadCount == 0 then return end
    local batch, n = {}, D.loadCount
    for i = 1, n do
        batch[i] = D.pendingLoads[i]
        D.pendingLoads[i] = nil
    end
    D.loadCount = 0
    local pending, pendingN, seen = {}, 0, {}
    for i = 1, n do
        local id = batch[i]
        if not seen[id] then
            seen[id] = true
            if not CompleteItem(id) then
                pendingN = pendingN + 1
                pending[pendingN] = id
            end
        end
    end
    if pendingN == 0 then return end
    local gen = D.loadGen or 0
    local function Settle()
        if gen ~= D.loadGen then return end
        for i = 1, pendingN do
            if not CompleteItem(pending[i]) then GiveUp(pending[i]) end
        end
    end
    local items = ns.Shared and ns.Shared.Items
    if not (items and items.OnLoaded) then
        Settle()
        return
    end
    items.OnLoaded(pending, Settle)
end

local function Trace(bag, slot, itemID, name, quality, count, unit, known, source, marketUnit, marketTotal, reason, link, bound, rawQuality)
    if not D.traceOn then return end
    if D.traceCapped or (D.tracePrints or 0) >= TRACE_CAP then
        if not D.traceCapped then
            D.traceCapped = true
            ns.Print("destroy cheapest: further rows are counted in the summary only.")
        end
        return
    end
    local why = reason or "offer"
    local key = tostring(bag) .. ":" .. tostring(slot) .. ":" .. tostring(itemID) .. ":" .. why
        .. ":" .. tostring(unit) .. ":" .. tostring(known) .. ":" .. tostring(count)
    if D.traceSeen[key] then return end
    D.traceSeen[key] = true
    D.tracePrints = (D.tracePrints or 0) + 1
    local vendor
    if not known then
        vendor = "unknown (" .. tostring(source or "none") .. ")"
    else
        vendor = tostring(unit) .. " copper " .. tostring(source) .. ", stack "
            .. tostring((unit or 0) * (count or 1)) .. " copper"
    end
    local ah = "unknown"
    if type(marketUnit) == "number" then
        ah = tostring(marketUnit) .. " copper, stack "
            .. tostring(marketTotal or (marketUnit * (count or 1))) .. " copper"
    end
    local state = "offer"
    if why ~= "offer" then state = "skip " .. why end
    ns.Print(string.format(
        "destroy cheapest: bag %s slot %s item %s [%s] x%s %s | vendor %s | AH est. %s | %s | link %s | bound %s | slot quality %s",
        tostring(bag), tostring(slot), tostring(itemID), QUALITY_NAME[quality] or "?",
        tostring(count or "?"), name or "", vendor, ah, state,
        tostring(link or ""), tostring(bound), tostring(rawQuality)))
end

local function TraceSlot(bag, slot, info, name, quality, count, unit, known, source, marketUnit, marketTotal, reason)
    if not D.traceOn then return end
    Trace(bag, slot, info and info.itemID, name, quality, count, unit, known, source, marketUnit, marketTotal, reason,
        info and info.hyperlink, info and info.isBound, info and info.quality)
end

local function FillPick(e, bag, slot, info, name, quality, count, unit, source, classID, estimated)
    e.bag, e.slot, e.itemID = bag, slot, info.itemID
    e.link, e.icon, e.name = info.hyperlink, info.iconFileID, name or ("item " .. info.itemID)
    e.count, e.quality = count, quality
    e.classID = classID
    e.vendorUnit = unit
    e.vendor = unit
    e.vendorKnown = true
    e.vendorEstimated = estimated == true
    e.vendorSource = source
    e.vendorTotal = unit * count
    e.value = e.vendorTotal
    if RankMarket() or D.traceOn then
        D.ApplyMarket(e, info.itemID, count)
    else
        ClearMarket(e)
    end
    e.rank = RankValue(e)
end

local scanStats = { skip = 0 }

local function ScanSlot(bag, slot, stats)
    local info = GetContainerItemInfo(bag, slot)
    if not (info and info.itemID) then return end
    if info.isLocked then
        stats.skip = stats.skip + 1
        TraceSlot(bag, slot, info, nil, info.quality, info.stackCount, nil, false, nil, nil, nil, "locked")
        return
    end
    local count = StackCount(info)
    if not count then
        stats.skip = stats.skip + 1
        TraceSlot(bag, slot, info, nil, info.quality, nil, nil, false, nil, nil, nil, "count-hidden")
        return
    end
    local unit, known, source, name, quality, classID, subclassID, bindType, setID, estimated =
        D.VendorQuote(info, bag, slot)
    if source == "unloaded" then
        local loadKey = D.LoadKey(info.itemID, info.hyperlink)
        local wasDone = D.loadDone[loadKey]
        D.inlineLoad = true
        local loadedOk, loadedErr = pcall(RequestItem, info.itemID, info.hyperlink, bag, slot, count, info.quality)
        D.inlineLoad = false
        if not loadedOk then error(loadedErr) end
        if not D.loadDone[loadKey] or wasDone then
            stats.skip = stats.skip + 1
            TraceSlot(bag, slot, info, name, quality, count, nil, false, source, nil, nil,
                wasDone and "no-data" or "loading")
            return
        end
        unit, known, source, name, quality, classID, subclassID, bindType, setID, estimated =
            D.VendorQuote(info, bag, slot)
        if source == "unloaded" then
            stats.skip = stats.skip + 1
            TraceSlot(bag, slot, info, name, quality, count, nil, false, source, nil, nil, "no-data")
            return
        end
    end
    if not name then
        stats.skip = stats.skip + 1
        TraceSlot(bag, slot, info, nil, quality, count, unit, known, source, nil, nil, "no-name")
        return
    end
    local reason = D.Exclusion(bag, slot, info, quality, unit, known, classID, subclassID, bindType, setID)
    if reason then
        stats.skip = stats.skip + 1
        TraceSlot(bag, slot, info, name, quality, count, unit, known, source, nil, nil, reason)
        return
    end
    local e = Take()
    FillPick(e, bag, slot, info, name, quality, count, unit, source, classID, estimated)
    D.picks[#D.picks + 1] = e
    if D.traceOn then
        TraceSlot(bag, slot, info, name, quality, count, unit, known, source, e.marketUnit, e.marketTotal, nil)
    end
end

local function ScanPass()
    local keepBag, keepSlot, keepID
    local current = D.picks[D.index]
    if current then keepBag, keepSlot, keepID = current.bag, current.slot, current.itemID end
    for i = #D.picks, 1, -1 do D.picks[i] = nil end
    D.used = 0
    wipe(D.waitingInfo)
    ReadSets()
    local stats = scanStats
    stats.skip = 0
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    local everyBag = ShowAll()
    local tracing = D.traceOn == true
    local offerReagent = D.OfferReagentBag()
    for bag = BACKPACK_CONTAINER, last do
        local reagent = D.IsReagentBag(bag)
        local plain = not reagent and D.IsPlain(bag)
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            if (not reagent and (everyBag or plain)) or (reagent and offerReagent) then
                ScanSlot(bag, slot, stats)
            elseif tracing then
                local info = GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    stats.skip = stats.skip + 1
                    TraceSlot(bag, slot, info, nil, info.quality, info.stackCount, nil, false, nil, nil, nil,
                        reagent and "reagent-bag" or "specialty-bag")
                end
            end
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
    if tracing then
        local key = "sum:" .. #D.picks .. ":" .. stats.skip
        if not D.traceSeen[key] then
            D.traceSeen[key] = true
            ns.Print(string.format(
                "destroy cheapest: offered %d, skipped %d. Prices are copper. AH est. is not a guaranteed sale.",
                #D.picks, stats.skip))
        end
    end
end

function D.IsSecret(value)
    return issecretvalue and issecretvalue(value) and true or false
end

function D.LootCode(enumName, globalName, fallback)
    local enum = Enum and Enum.LootSlotType
    local value = type(enum) == "table" and enum[enumName] or nil
    if type(value) == "number" and not D.IsSecret(value) then return value end
    value = _G[globalName]
    if type(value) == "number" and not D.IsSecret(value) then return value end
    return fallback
end

function D.LootCount()
    if type(GetNumLootItems) ~= "function" then return nil, true end
    local ok, value = pcall(GetNumLootItems)
    if not ok or D.IsSecret(value) or type(value) ~= "number" then return nil, true end
    if value < 0 then return 0, false end
    return math.floor(value), false
end

local function Bare(value)
    if D.IsSecret(value) then return nil, true end
    return value, false
end

local function StackOf(qty)
    if qty == nil then return 1 end
    local n = Plain(qty)
    if not n or n < 1 then return nil end
    return math.floor(n)
end

function D.LootSlotFact(i, into)
    local has, hasSecret
    if type(LootSlotHasItem) == "function" then
        local ok, value = pcall(LootSlotHasItem, i)
        if not ok then return nil, "has-error" end
        if D.IsSecret(value) then hasSecret = true else has = value and true or false end
    end
    local slotType, typeSecret
    if type(GetLootSlotType) == "function" then
        local ok, value = pcall(GetLootSlotType, i)
        if not ok then return nil, "type-error" end
        if D.IsSecret(value) then typeSecret = true
        elseif type(value) == "number" then slotType = value end
    end
    local texture, name, qty, currencyID, quality, isQuest, questID, isCoin
    local infoSecret = false
    if type(GetLootSlotInfo) == "function" then
        local ok, a, b, c, d, e, _, g, h, _, j = pcall(GetLootSlotInfo, i)
        if not ok then return nil, "info-error" end
        local secret
        texture, secret = Bare(a)
        infoSecret = infoSecret or secret
        name, secret = Bare(b)
        infoSecret = infoSecret or secret
        qty, secret = Bare(c)
        infoSecret = infoSecret or secret
        currencyID, secret = Bare(d)
        infoSecret = infoSecret or secret
        quality, secret = Bare(e)
        infoSecret = infoSecret or secret
        isQuest, secret = Bare(g)
        infoSecret = infoSecret or secret
        questID, secret = Bare(h)
        infoSecret = infoSecret or secret
        isCoin, secret = Bare(j)
        infoSecret = infoSecret or secret
    end
    local link, linkSecret
    if type(GetLootSlotLink) == "function" then
        local ok, value = pcall(GetLootSlotLink, i)
        if not ok then return nil, "link-error" end
        link, linkSecret = Bare(value)
    end
    if type(link) ~= "string" or link == "" then link = nil end
    if type(name) ~= "string" or name == "" then name = nil end
    local itemCode = D.LootCode("Item", "LOOT_SLOT_ITEM", LOOT_ITEM)
    local moneyCode = D.LootCode("Money", "LOOT_SLOT_MONEY", LOOT_MONEY)
    local currencyCode = D.LootCode("Currency", "LOOT_SLOT_CURRENCY", LOOT_CURRENCY)
    local noneCode = D.LootCode("None", "LOOT_SLOT_NONE", LOOT_NONE)
    local coin = isCoin == true or (not typeSecret and slotType == moneyCode)
    if coin then return nil, "money" end
    local currency = (type(currencyID) == "number" and currencyID > 0)
        or (not typeSecret and slotType == currencyCode)
    if currency and slotType ~= itemCode then return nil, "currency" end
    if not typeSecret and slotType == noneCode and has ~= true then return nil, "empty" end
    local typedItem = not typeSecret and slotType == itemCode
    if has == false and not typedItem and link == nil and name == nil then return nil, "empty" end
    if not typedItem and link == nil and name == nil then
        if hasSecret or typeSecret or infoSecret or linkSecret or has == true then
            return nil, (hasSecret or typeSecret or infoSecret or linkSecret) and "secret" or "untyped"
        end
        return nil, "empty"
    end
    local itemID, classID
    if link and type(GetItemInfoInstant) == "function" then
        local ok, id, _, _, _, _, class = pcall(GetItemInfoInstant, link)
        if ok and type(id) == "number" and not D.IsSecret(id) then itemID = id end
        if ok and type(class) == "number" and not D.IsSecret(class) then classID = class end
    end
    local count = StackOf(qty) or 1
    local fact = into or {}
    fact.item, fact.slot, fact.link, fact.icon, fact.name = true, i, link, texture, name
    fact.itemID, fact.classID, fact.count, fact.quality = itemID, classID, count, quality
    fact.quest = QuestMarked(isQuest, questID)
    fact.pending = link == nil or itemID == nil or infoSecret or linkSecret
    fact.qtySecret = D.IsSecret(qty) or (qty ~= nil and type(qty) ~= "number")
    if type(qty) ~= "number" then fact.qtySecret = qty ~= nil or infoSecret end
    return fact, "item"
end

function D.EndLoot(reason)
    local had = #D.loots > 0 or D.lootGap ~= nil
    for i = #D.loots, 1, -1 do D.loots[i] = nil end
    D.lootUsed = 0
    D.lootIndex = 1
    D.lootGap = nil
    D.lootHideReason = reason or "ended"
    if had then D.lootSerial = (D.lootSerial or 0) + 1 end
end

function D.LootGapText()
    if D.lootGap == "secret" or D.lootGap == "pending" then return D.TEXT.INCOMING_PENDING end
    return D.TEXT.INCOMING_UNAVAILABLE
end

function D.CopyLootRow(e)
    local row = {}
    row.slot, row.link, row.icon, row.name = e.slot, e.link, e.icon, e.name
    row.itemID, row.classID, row.count, row.quality = e.itemID, e.classID, e.count, e.quality
    row.quest, row.pending = e.quest, e.pending
    row.vendor, row.vendorUnit, row.vendorTotal, row.value = e.vendor, e.vendorUnit, e.vendorTotal, e.value
    row.vendorKnown, row.vendorEstimated, row.vendorSource = e.vendorKnown, e.vendorEstimated, e.vendorSource
    row.market, row.marketUnit, row.marketTotal = e.market, e.marketUnit, e.marketTotal
    row.marketKnown, row.marketFresh, row.marketAge, row.marketChecked =
        e.marketKnown, e.marketFresh, e.marketAge, e.marketChecked
    return row
end

local reagentFact = {}

function D.OfferReagentBag()
    if D.Opt("destroyCheapestReagentBag") ~= true then return false end
    if D.PlainFree() > 0 or D.ReagentFree() > 0 then return false end
    local loot = D.loots and (D.loots[D.lootIndex] or D.loots[1])
    if loot and D.ItemIsReagent(loot.itemID, loot.classID) then return true end
    if loot and (loot.itemID or loot.classID) then return false end
    if not D.LootShown() then return false end
    local n = D.LootCount()
    if type(n) ~= "number" then return false end
    for i = 1, n do
        local fact = D.LootSlotFact(i, reagentFact)
        if fact and fact.item then
            return D.ItemIsReagent(fact.itemID, fact.classID) == true
        end
    end
    return false
end

function D.Scan()
    if D.scanning then
        D.scanAgain = true
        return
    end
    D.ForgetOpts()
    D.scanning = true
    D.PerfAdd("scans")
    D.traceOn = D.traceForce == true
    local ownCache = not D.caching
    if ownCache then D.BeginCache() end
    local ok, err = pcall(ScanPass)
    if ownCache then D.EndCache() end
    D.traceOn = false
    D.scanning = false
    D.ForgetOpts()
    if not ok then error(err) end
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
    local ok, _, _, _, _, _, locked = pcall(GetLootSlotInfo, slot)
    if not ok or D.IsSecret(locked) then return false end
    return not locked
end

function D.StoreLoot(fact)
    local e = LootTake()
    local count = fact.count or 1
    local itemID, classID = fact.itemID, fact.classID
    local info = {
        itemID = itemID, hyperlink = fact.link, quality = fact.quality, stackCount = count,
    }
    local unit, known, source, resolvedName, _, quotedClass, _, _, _, estimated = D.VendorQuote(info, nil, nil)
    if quotedClass and not classID then classID = quotedClass end
    if source == "unloaded" then RequestItem(itemID, fact.link, nil, fact.slot, count, fact.quality) end
    e.slot, e.link, e.icon = fact.slot, fact.link, fact.icon
    e.name = fact.name or resolvedName or (itemID and ("item " .. itemID)) or D.TEXT.INCOMING_PENDING
    e.itemID = itemID
    e.classID = classID
    e.quality = ReadQuality(fact.quality, nil)
    e.quest = fact.quest == true
    e.pending = fact.pending == true or source == "unloaded" or fact.qtySecret == true
    if fact.qtySecret then
        e.count = nil
        known = false
    else
        e.count = count
    end
    if known == true and type(unit) == "number" and not fact.qtySecret then
        e.vendor, e.vendorUnit = unit, unit
        e.vendorTotal = unit * count
        e.value = unit > 0 and e.vendorTotal or nil
        e.vendorKnown = true
        e.vendorEstimated = estimated == true
    else
        e.vendor, e.vendorUnit, e.vendorTotal, e.value = nil, nil, nil, nil
        e.vendorKnown = false
        e.vendorEstimated = false
    end
    e.vendorSource = source
    if itemID and not fact.qtySecret then
        D.ApplyMarket(e, itemID, count)
    else
        e.market, e.marketUnit, e.marketTotal = nil, nil, nil
        e.marketAge, e.marketFresh, e.marketKnown, e.marketChecked = nil, nil, false, true
    end
    return e
end

local function Verdict(_, reason)
    D.lootHideReason = reason
end

local function PutBack(copy, keepIndex)
    for i = #D.loots, 1, -1 do D.loots[i] = nil end
    D.lootUsed = 0
    for i = 1, #copy do
        local e = LootTake()
        wipe(e)
        local src = copy[i]
        for key, value in pairs(src) do e[key] = value end
        D.loots[#D.loots + 1] = e
    end
    D.lootIndex = 1
    D.lootGap = nil
    if type(keepIndex) == "number" and D.loots[keepIndex] then D.lootIndex = keepIndex end
end

local function ReadLootNow()
    local before = #D.loots
    local keepSlot = D.loots[D.lootIndex] and D.loots[D.lootIndex].slot
    local copy, keepIndex = {}, D.lootIndex
    for i = 1, before do copy[i] = D.CopyLootRow(D.loots[i]) end
    if not D.LootShown() then
        D.EndLoot("no-loot-frame")
        Verdict("cleared", "no-loot-frame")
        return
    end
    local n, unreadable = D.LootCount()
    if unreadable then
        if before > 0 then
            Verdict("kept", "secret-count")
            return
        end
        D.lootGap = "secret"
        Verdict("empty", "secret-count")
        return
    end
    for i = #D.loots, 1, -1 do D.loots[i] = nil end
    D.lootUsed = 0
    D.lootIndex = 1
    D.lootGap = nil
    local sawSecret, sawUntyped, sawMoney = false, false, false
    for i = 1, n do
        local fact, reason = D.LootSlotFact(i)
        if fact and fact.item then
            local e = D.StoreLoot(fact)
            D.loots[#D.loots + 1] = e
            if e.slot == keepSlot then D.lootIndex = #D.loots end
        elseif reason == "secret" or reason == "has-error" or reason == "type-error"
            or reason == "info-error" or reason == "link-error" then
            sawSecret = true
        elseif reason == "untyped" then
            sawUntyped = true
        elseif reason == "money" or reason == "currency" then
            sawMoney = true
        end
    end
    if #D.loots > 0 then
        local action = "captured"
        if before > 0 then
            local nowLink = D.loots[D.lootIndex] and D.loots[D.lootIndex].link
            local oldLink = copy[keepIndex] and copy[keepIndex].link
            action = nowLink ~= oldLink and "replaced" or "refreshed"
        end
        Verdict(action, "item")
        return
    end
    if (sawSecret or unreadable) and before > 0 then
        PutBack(copy, keepIndex)
        Verdict("kept", "secret-slot")
        return
    end
    if sawUntyped or sawSecret then
        D.lootGap = sawSecret and "secret" or "untyped"
        Verdict(before > 0 and "cleared" or "empty", D.lootGap)
        return
    end
    if n == 0 or not sawMoney then
        D.lootGap = "no-slot"
        Verdict(before > 0 and "cleared" or "empty", "no-slot")
        return
    end
    Verdict(before > 0 and "cleared" or "empty", "money")
end

function D.ReadLoot()
    D.reading = true
    local ok, err = pcall(ReadLootNow)
    D.reading = false
    if not ok then error(err) end
    if D.refreshing or D.opening then return end
    if D.scanAgain and not D.scanning and (D.Opened() or D.traceForce) then
        D.scanAgain = false
        if D.Refresh then D.Refresh() else D.Scan() end
    end
end

function D.HoldForAnyway(pick)
    if type(pick) ~= "table" then return false end
    if pick.classID ~= CLASS.CONSUMABLE then return false end
    if pick.vendorKnown ~= true or type(pick.vendorUnit) ~= "number" or pick.vendorUnit > 0 then return false end
    D.EnsureMarket(pick)
    if pick.marketKnown ~= true or type(pick.market) ~= "number" or pick.market <= 0 then return false end
    return true
end

function D.Compare(pick, loot)
    if D.HoldForAnyway(pick) then return false, "risky" end
    if not loot then return true, nil end
    if loot.quest == true then return true, "quest" end
    local pv = D.ItemValue(pick)
    local lv, ls = D.ItemValue(loot)
    if ls == nil then ls = "unknown" end
    if pv == nil or lv == nil then return false, "unknown" end
    if ls ~= "ah" and loot.vendorKnown == true and type(loot.vendorUnit) == "number" and loot.vendorUnit <= 0 then
        return false, "zero"
    end
    if lv >= pv then return true, "favorable" end
    return false, "low"
end

function D.WorthIt(pick, loot)
    return (D.Compare(pick, loot)) == true
end

function D.BlockReason(pick, loot)
    local worth, reason = D.Compare(pick, loot)
    if worth or reason == "quest" or reason == "favorable" then return nil end
    return reason
end

function D.Matches(pick)
    if type(pick) ~= "table" then return false end
    local info = GetContainerItemInfo(pick.bag, pick.slot)
    if not info or info.isLocked or info.itemID ~= pick.itemID then return false end
    if pick.link and info.hyperlink ~= pick.link then return false end
    local count = StackCount(info)
    if count ~= pick.count then return false end
    if D.IsReagentBag(pick.bag) then
        if not D.OfferReagentBag() then return false end
    elseif not D.IsPlain(pick.bag) and S.Get("destroyCheapestAll") ~= true then
        return false
    end
    local wasCaching = D.caching
    D.caching = false
    local unit, known, source, _, quality, classID, subclassID, bindType, setID =
        D.VendorQuote(info, pick.bag, pick.slot)
    local blocked = D.Exclusion(pick.bag, pick.slot, info, quality, unit, known, classID, subclassID, bindType, setID)
    D.caching = wasCaching
    if not known or source == "unloaded" then return false end
    if type(source) == "string" and source:find("unknown", 1, true) == 1 then return false end
    if blocked then return false end
    local shown = pick.vendorTotal
    if shown == nil then shown = pick.value end
    return unit * count == shown
end

function D.TraceBags()
    if D.pending then
        ns.Print(D.TEXT.WAITING)
        return
    end
    D.ResetLoads()
    D.ClearTrace()
    D.traceForce = true
    D.Scan()
    D.FlushLoads()
    local waiting = next(D.waitingInfo) ~= nil
    D.traceForce = false
    if waiting then ns.Print(D.TEXT.TRACE_AGAIN) end
end
