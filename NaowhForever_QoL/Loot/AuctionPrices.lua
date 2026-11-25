-- AuctionPrices.lua: Auction Prices, the lowest buyout per item, how many are listed and the median price, from a fast or page by page scan, the listings you see or the release's prices, per realm and faction.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Items = ns.Shared.Items

local SCAN_COOLDOWN = 900
local CHUNK = 1000
local TIMEOUT = 60
local BROWSE_TIMEOUT = 30
local AUTO_DELAY = 1
local AUTO_RANGE = { 5, 120, 5 }
local BROWSE_EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "AUCTION_HOUSE_BROWSE_FAILURE", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }
local BROWSE_QUERY = {
    searchString = "",
    sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
        { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } },
    filters = { Enum.AuctionHouseFilter.PoorQuality, Enum.AuctionHouseFilter.CommonQuality,
        Enum.AuctionHouseFilter.UncommonQuality, Enum.AuctionHouseFilter.RareQuality,
        Enum.AuctionHouseFilter.EpicQuality, Enum.AuctionHouseFilter.LegendaryQuality },
}
local AGE_TICK = 60
local SECONDS_PER_MINUTE, SECONDS_PER_HOUR = ns.QoLConstants.SECONDS_PER_MINUTE, ns.QoLConstants.SECONDS_PER_HOUR
local SECONDS_PER_DAY = ns.QoLConstants.SECONDS_PER_DAY
local PERCENT = ns.QoLConstants.PERCENT
local BUTTON_W, BUTTON_H = 120, 24
local BUTTON_GAP, BUTTON_DROP = 8, 4
local AGE_SIZE = 11
local COIN_SIZE = 12
local WHITE = ns.QoLConstants.WHITE_RGB
local REALM_JOIN = "-"
local BLACKWATER = "Blackwater"
local FRIENDLY = "friendly"
local TSM_SOURCE = "dbminbuyout"
local TSM_ITEM = "i:"
local AUCTIONATOR = "Auctionator"
local CALLER = "NaowhForever"
local function Tag() return ns.Color("accent", "Naowh AH") end
local TEXT_SCAN = ns.L("Scan Prices")
local TEXT_SCANNING = ns.L("Scanning...")
local TEXT_PROGRESS = ns.L("Scanning %d%%")
local TEXT_ITEMS = ns.L("%d items")
local TEXT_NO_SCAN = ns.L("No scan yet for this realm and faction")
local TEXT_NO_SCAN_SHORT = ns.L("No scan yet")
local TEXT_SCAN_LINE = ns.L("Last scan %s ago: %s items priced")
local TEXT_AGE = ns.L("Last scan %s ago%s")
local TEXT_EMPTY = ns.L("The auction house returned no listings. Try again in a moment.")
local TEXT_PAGED = ns.L("the fast scan is free again in %dm, so this one reads the auction house page by page.")
local TEXT_TIMEOUT = ns.L("no answer from the auction house to the fast scan, so this one reads it page by page.")
local TEXT_NO_ANSWER = ns.L("scan stopped: no answer from the auction house. Try again in a moment.")
local TEXT_REPLACED = ns.L("scan stopped: another search took its place.")
local TEXT_CLOSED = ns.L("scan stopped: the auction house closed.")
local TEXT_STARTED = ns.L("please wait while the auction house scan completes.")
local TEXT_TIP = ns.L("Keeps the lowest buyout of every item on the auction house, shown on item tooltips. "
    .. "Blizzard allows one fast scan every 15 minutes; between them it reads page by page.\n\n")
local TEXT_EACH = ns.L(" |cff808080each, %s ago|r")
local TEXT_EACH_TSM = ns.L(" |cff808080each, TSM|r")
local TEXT_EACH_AUCTIONATOR = ns.L(" |cff808080each, Auctionator|r")
local TEXT_FILLING = "%d %s"
local TEXT_CHEAPEST = ns.L("cheapest")
local TEXT_REQUESTED = ns.L("Requested: %s")
local MINUTES, HOURS, DAYS = "m", "h", "d"
local TEXT_FEED_LINE = ns.L("Prices from %s ago: %s items priced")
local TEXT_FEED_AGE = ns.L("Prices from %s ago")
local TEXT_TOOLTIP_TAG = ns.L("Market Price")
local TEXT_VENDOR_TAG = ns.L("Sold by Vendors")
local TEXT_VENDOR_LIMITED = ns.L("Sold by Vendors (limited stock)")
local FEED_ADDON = "NaowhForever_AuctionData"
local FEED_BASE = 36
-- tonumber with a base goes through strtoul, which is 32-bit on Windows, so longer numbers are read in two parts.
local FEED_DIGITS = 6
local MATCH_MIN = 20
local MATCH_SPREAD = 0.01
local CLASS_INDEX = 6
local GEAR = { [Enum.ItemClass.Weapon] = true, [Enum.ItemClass.Armor] = true }
local LINK_SUFFIX = "item:%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:(%-?%d*)"
local LINK_NAME = "|h%[(.-)%]|h"
local NO_SUFFIX = "0"

local button, scanning, scanGen = nil, nil, 0
local ownScan, houseOpen, hooked, earlyAt
local browsing, browseHooked, browseSent, browseSending, browseWaiting
local browseCount = 0
local tooltipHooked, auctionatorHooked
local faction
local atNeutral = false
local houseKeys = {}
local priced, pricedAt
local feedPriced, feedPricedFor
local ageTicker
local feedTried, feedHouses, feedMiddles, feedTime
local feeds = {}
local merged, mergedFeed, mergedAt
local decoded, decodedListed, decodedMedians = {}, {}, {}
local seenIDs, seenCount = {}, 0
local seenHouse, seenNow

local function Side(other)
    faction = faction or UnitFactionGroup("player")
    if not faction then return end
    if atNeutral ~= (other == true) then return BLACKWATER end
    return faction
end

local function Key(other)
    local side = Side(other)
    local key = side and houseKeys[side]
    if not key then
        key = ns.RealmName() .. REALM_JOIN .. (side or "")
        if side then houseKeys[side] = key end
    end
    return key
end

local function House(create, other)
    local account = ns.AccountSettings()
    account.ahPrices = account.ahPrices or {}
    local key = Key(other)
    if create and not account.ahPrices[key] then account.ahPrices[key] = { prices = {} } end
    return account.ahPrices[key]
end

local function FeedHouses(side)
    if not side then return end
    if not feedTried then
        feedTried = true
        C_AddOns.LoadAddOn(FEED_ADDON)
        local feed = ns.AuctionFeed
        ns.AuctionFeed = nil
        local region = feed and feed.regions[GetCurrentRegion()]
        for id, house in pairs(region or {}) do
            local tag = house.faction
            if (tag == faction or tag == BLACKWATER) and house.prices ~= "" then
                feedHouses = feedHouses or {}
                feedHouses[tag] = feedHouses[tag] or {}
                feedHouses[tag][id] = house.prices
            end
        end
        for tag, prices in pairs(feed and feed.middles and feed.middles[GetCurrentRegion()] or {}) do
            if tag == faction or tag == BLACKWATER then
                feedMiddles = feedMiddles or {}
                feedMiddles[tag] = prices
            end
        end
        feedTime = feed and feed.time
    end
    return feedHouses and feedHouses[side]
end

local function Number(text)
    if #text <= FEED_DIGITS then return tonumber(text, FEED_BASE) end
    return tonumber(text:sub(1, -FEED_DIGITS - 1), FEED_BASE) * FEED_BASE ^ FEED_DIGITS
        + tonumber(text:sub(-FEED_DIGITS), FEED_BASE)
end

local function Decode(houses, id)
    if not decoded[id] then
        local prices, listed, medians, item = {}, {}, {}, 0
        for step, price, count, median in houses[id]:gmatch("(%w+):(%w+):?(%w*):?(%w*)") do
            item = item + Number(step)
            prices[item] = Number(price)
            if count ~= "" then listed[item] = Number(count) end
            if median ~= "" then medians[item] = Number(median) end
        end
        decoded[id], decodedListed[id], decodedMedians[id] = prices, listed, medians
    end
    return decoded[id], decodedListed[id], decodedMedians[id]
end

local function Matches(own, feed)
    local count = 0
    for item, price in pairs(own) do
        local other = feed[item]
        if other and math.abs(other - price) <= price * MATCH_SPREAD then count = count + 1 end
    end
    return count
end

local function MatchHouse(house, houses)
    local best, most = false, MATCH_MIN - 1
    for id in pairs(houses) do
        local count = Matches(house.prices, Decode(houses, id))
        if count > most then best, most = id, count end
    end
    return best
end

local function Forget(houses, keep)
    for id in pairs(houses) do
        if id ~= keep then decoded[id], decodedListed[id], decodedMedians[id] = nil, nil, nil end
    end
end

local function FeedPrices(other)
    local side = Side(other)
    local houses = FeedHouses(side)
    if not houses then return end
    local feed = feeds[side]
    if not feed then
        feed = {}
        feeds[side] = feed
    end
    if feed.matched == nil then
        local house = House(false, other)
        feed.matched = house and house.time and MatchHouse(house, houses) or false
        if feed.matched then Forget(houses, feed.matched) end
    end
    if feed.matched then return Decode(houses, feed.matched) end
    if feedMiddles and feedMiddles[side] then return Decode(feedMiddles, side) end
end

local function Matched(other)
    local feed = feeds[Side(other)]
    return feed and feed.matched
end

-- The middle of every house may be other realms', so it never outranks a scan of your own.
local function FeedFirst(at, other)
    return not at or Matched(other) and at < feedTime
end

local function Lookup(itemID, other)
    local house = House(false, other)
    local feed, listed = FeedPrices(other)
    local own = house and house.prices[itemID]
    local at = own and (house.seen and house.seen[itemID] or house.time)
    if feed and feed[itemID] and FeedFirst(at, other) then
        return feed[itemID], feedTime, listed[itemID], Matched(other) and true or false
    end
    if at then return own, at, house.listed and house.listed[itemID], true end
end

local function SuffixName(link)
    local suffix = link:match(LINK_SUFFIX)
    if suffix and suffix ~= "" and suffix ~= NO_SUFFIX then return link:match(LINK_NAME) end
end

local function SuffixLookup(itemID, name)
    local house = House(false)
    local names = house and house.suffixes and house.suffixes[itemID]
    local price = names and names[name]
    if not price then return end
    local seen = house.suffixSeen and house.suffixSeen[itemID]
    return price, seen and seen[name] or house.time
end

local function KeepSuffix(suffixes, itemID, name, price)
    local names = suffixes[itemID]
    if not names then
        names = {}
        suffixes[itemID] = names
    end
    if not names[name] or price < names[name] then names[name] = price end
end

local function TsmLoaded()
    return TSM_API ~= nil
end

local function TsmPrice(itemID)
    if not (TSM_API and S.Get("ahTsm")) then return end
    local ok, value = pcall(TSM_API.GetCustomPriceValue, TSM_SOURCE, TSM_ITEM .. itemID)
    if ok then return value end
end

local function AuctionatorLoaded()
    return C_AddOns.IsAddOnLoaded(AUCTIONATOR)
end

local function OnAuctionatorUpdate()
    if not S.Get("ahAuctionator") then return end
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
    if ns.MarketRefresh then ns.MarketRefresh() end
end

local function AuctionatorPrice(itemID)
    if not (S.Get("ahAuctionator") and AuctionatorLoaded()) then return end
    if not auctionatorHooked then
        auctionatorHooked = true
        pcall(Auctionator.API.v1.RegisterForDBUpdate, CALLER, OnAuctionatorUpdate)
    end
    local ok, value = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, CALLER, itemID)
    if ok then return value end
end

function ns.AuctionSuffixPrice(itemID, link)
    local name = itemID and link and SuffixName(link)
    if name then return SuffixLookup(itemID, name) end
end

function ns.AuctionPrice(itemID, link)
    if not itemID then return end
    local suffixPrice, suffixAt = ns.AuctionSuffixPrice(itemID, link)
    if suffixPrice then return suffixPrice, suffixAt end
    local addon = TsmPrice(itemID) or AuctionatorPrice(itemID)
    if addon then return addon end
    local price, at = Lookup(itemID)
    return price, at
end

function ns.AuctionListed(itemID)
    if not itemID then return end
    return (select(3, Lookup(itemID)))
end

function ns.AuctionOtherPrice(itemID)
    if not itemID then return end
    local price, at, _, known = Lookup(itemID, true)
    return price, at, known
end

function ns.AuctionOtherHouse()
    return Side(true)
end

function ns.AuctionHouseKey()
    return Key()
end

function ns.AuctionScanTime()
    local house, feed = House(), FeedPrices()
    if feed and FeedFirst(house and house.time) then return feedTime end
    return house and house.time
end

function ns.AuctionPriceList()
    local house, feed = House(), FeedPrices()
    local scanned = house and house.time
    if not feed then return house and house.prices, scanned end
    local seen = house and house.seen
    if not (scanned or seen) then return feed, feedTime end
    if mergedFeed ~= feed or mergedAt ~= (scanned or 0) then
        local own = house.prices
        local first, second = own, feed
        if FeedFirst(scanned) then first, second = feed, own end
        merged = {}
        for id, price in pairs(second) do merged[id] = price end
        for id, price in pairs(first) do merged[id] = price end
        if seen and first == feed then
            for id, at in pairs(seen) do
                if not FeedFirst(at) then merged[id] = own[id] end
            end
        end
        mergedFeed, mergedAt = feed, scanned or 0
    end
    return merged, math.max(scanned or 0, feedTime)
end

function ns.AuctionMedianList()
    local house = House()
    local _, _, feed = FeedPrices()
    local own = house and house.medians
    if feed and next(feed) and FeedFirst(own and house.medianTime) then return feed, feedTime end
    if own then return own, house.medianTime end
end

local function SeenHouse()
    if not seenHouse then
        seenHouse, seenNow = House(true), GetServerTime()
        seenHouse.seen = seenHouse.seen or {}
    end
    return seenHouse
end

function ns.AuctionSeen(itemID, price, listed, exact)
    local house = SeenHouse()
    local old = house.prices[itemID]
    if not exact and old and old <= price then return end
    house.seen[itemID] = seenNow
    local counts = house.listed
    local counted = exact and listed and not (counts and counts[itemID] == listed)
    if counted then
        if not counts then
            counts = {}
            house.listed = counts
        end
        counts[itemID] = listed
    end
    local shown = merged and not FeedFirst(seenNow) and merged[itemID] ~= price
    if shown then merged[itemID] = price end
    if old == price and not (counted or shown) then return end
    house.prices[itemID] = price
    seenCount = seenCount + 1
    seenIDs[seenCount] = itemID
end

function ns.AuctionSeenSuffix(itemID, name, price, exact)
    local house = SeenHouse()
    house.suffixes, house.suffixSeen = house.suffixes or {}, house.suffixSeen or {}
    local names, dates = house.suffixes[itemID], house.suffixSeen[itemID]
    if not names then
        names = {}
        house.suffixes[itemID] = names
    end
    if not exact and names[name] and names[name] <= price then return end
    if not dates then
        dates = {}
        house.suffixSeen[itemID] = dates
    end
    names[name], dates[name] = price, seenNow
end

function ns.AuctionSeenDone()
    local count = seenCount
    seenHouse, seenCount = nil, 0
    if count == 0 then return end
    if ns.MarketPricesSeen then ns.MarketPricesSeen(seenIDs, count) end
    if ns.AuctionPricesChanged then ns.AuctionPricesChanged() end
end

local function Age(seconds)
    if seconds < SECONDS_PER_HOUR then return math.max(1, math.floor(seconds / SECONDS_PER_MINUTE)) .. MINUTES end
    if seconds < SECONDS_PER_DAY then return math.floor(seconds / SECONDS_PER_HOUR) .. HOURS end
    return math.floor(seconds / SECONDS_PER_DAY) .. DAYS
end
ns.AuctionAge = Age

local function Priced(house)
    if pricedAt ~= house.time then
        priced = 0
        for _ in pairs(house.prices) do priced = priced + 1 end
        pricedAt = house.time
    end
    return priced
end

local function ScanLine()
    local house = House()
    if not (house and house.time) then return TEXT_NO_SCAN end
    return TEXT_SCAN_LINE:format(Age(GetServerTime() - house.time), BreakUpLargeNumbers(Priced(house)))
end

local function FeedLine(prices)
    if feedPricedFor ~= prices then
        feedPriced = 0
        for _ in pairs(prices) do feedPriced = feedPriced + 1 end
        feedPricedFor = prices
    end
    return TEXT_FEED_LINE:format(Age(GetServerTime() - feedTime), BreakUpLargeNumbers(feedPriced))
end

function ns.AuctionScanSummary()
    local house, feed = House(), FeedPrices()
    if feed and FeedFirst(house and house.time) then return FeedLine(feed) .. "." end
    return ScanLine() .. "."
end

local function Label(text)
    if button then button.label:SetText(text) end
end

local function Wait()
    local house = House()
    local last = house and house.requested
    return last and SCAN_COOLDOWN - (GetServerTime() - last)
end
ns.AuctionScanWait = Wait

local function ShowAge()
    if not (button and button.age) then return end
    local house = House()
    if not (house and house.time) then return button.age:SetText(TEXT_NO_SCAN_SHORT) end
    button.age:SetText(TEXT_AGE:format(Age(GetServerTime() - house.time), ""))
end

local events = CreateFrame("Frame")

local function EndBrowse()
    browsing, browseWaiting = nil, nil
    for _, event in ipairs(BROWSE_EVENTS) do events:UnregisterEvent(event) end
end

local function Stop(message)
    scanning = nil
    scanGen = scanGen + 1
    events:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    EndBrowse()
    Label(TEXT_SCAN)
    if message and ownScan then ns.Print(Tag() .. ": " .. message) end
    ownScan = nil
end

local function ReadListing(prices, listed, suffixes, amounts, i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID =
        C_AuctionHouse.GetReplicateItemInfo(i)
    if not (itemID and buyout and buyout > 0 and count and count > 0) then return end
    local each = math.floor(buyout / count)
    if not prices[itemID] or each < prices[itemID] then prices[itemID] = each end
    listed[itemID] = (listed[itemID] or 0) + 1
    local counts = amounts[itemID]
    if not counts then
        counts = {}
        amounts[itemID] = counts
    end
    counts[each] = (counts[each] or 0) + count
    if not GEAR[select(CLASS_INDEX, C_Item.GetItemInfoInstant(itemID))] then return end
    local link = C_AuctionHouse.GetReplicateItemLink(i)
    local name = link and SuffixName(link)
    if name then KeepSuffix(suffixes, itemID, name, each) end
end

-- Weighted by quantity: the price of the middle one of everything listed.
local function Medians(amounts)
    local medians, sorted = {}, {}
    for itemID, counts in pairs(amounts) do
        local total, seen = 0, 0
        wipe(sorted)
        for price, count in pairs(counts) do
            sorted[#sorted + 1] = price
            total = total + count
        end
        table.sort(sorted)
        for i = 1, #sorted do
            seen = seen + counts[sorted[i]]
            if seen * 2 >= total then
                medians[itemID] = sorted[i]
                break
            end
        end
    end
    return medians
end

local function Finish(prices, listed, suffixes, amounts)
    local house = House(true)
    house.prices, house.listed, house.time, house.seen = prices, listed, GetServerTime(), nil
    if next(amounts) then house.medians, house.medianTime = Medians(amounts), house.time end
    house.suffixes, house.suffixSeen = next(suffixes) and suffixes or nil, nil
    local feed = feeds[Side()]
    if feed then feed.matched = nil end
    Stop()
    ShowAge()
    ns.Print(Tag() .. ": " .. ns.AuctionScanSummary())
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
    if ns.MarketRefresh then ns.MarketRefresh() end
    if ns.AuctionPricesChanged then ns.AuctionPricesChanged() end
end

local function ReadRow(prices, listed, suffixes, _, i, rows)
    local row = rows[i + 1]
    local price = row.minPrice
    if price <= 0 then return end
    local key = row.itemKey
    local itemID = key.itemID
    if not prices[itemID] or price < prices[itemID] then prices[itemID] = price end
    listed[itemID] = (listed[itemID] or 0) + row.totalQuantity
    if key.itemSuffix == 0 then return end
    local info = C_AuctionHouse.GetItemKeyInfo(key)
    if info then KeepSuffix(suffixes, itemID, info.itemName, price) end
end

local function ReadAll(total, ReadOne, rows)
    scanning = true
    scanGen = scanGen + 1
    if total == 0 then return Stop(TEXT_EMPTY) end
    local prices, listed, suffixes, amounts, index, gen = {}, {}, {}, {}, 0, scanGen
    local function Step()
        if gen ~= scanGen then return end
        local last = math.min(index + CHUNK, total) - 1
        for i = index, last do ReadOne(prices, listed, suffixes, amounts, i, rows) end
        index = last + 1
        if index < total then
            Label(TEXT_PROGRESS:format(math.floor(index * PERCENT / total)))
            C_Timer.After(0, Step)
            return
        end
        Finish(prices, listed, suffixes, amounts)
    end
    Step()
end

local function Read()
    events:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    EndBrowse()
    House(true).requested = GetServerTime()
    ReadAll(C_AuctionHouse.GetNumReplicateItems(), ReadListing)
end

local function OnBrowseTimeout(gen)
    if gen == scanGen and browsing then Stop(TEXT_NO_ANSWER) end
end

local function Ask()
    scanGen = scanGen + 1
    local gen = scanGen
    C_Timer.After(BROWSE_TIMEOUT, function() OnBrowseTimeout(gen) end)
    browseWaiting = not C_AuctionHouse.IsThrottledMessageSystemReady()
    if browseWaiting then return end
    if browseSent then return C_AuctionHouse.RequestMoreBrowseResults() end
    browseSent, browseSending = true, true
    C_AuctionHouse.SendBrowseQuery(BROWSE_QUERY)
    browseSending = nil
end

local function OnBrowsed(added)
    if browseSending or not browseSent then return end
    if C_AuctionHouse.HasFullBrowseResults() then
        EndBrowse()
        local rows = C_AuctionHouse.GetBrowseResults()
        return ReadAll(#rows, ReadRow, rows)
    end
    browseCount = added and browseCount + #added or #C_AuctionHouse.GetBrowseResults()
    Label(TEXT_ITEMS:format(browseCount))
    Ask()
end

local function OnOtherBrowse()
    if browseSending then return end
    browseSent = nil
    if browsing then Stop(TEXT_REPLACED) end
end

function ns.AuctionScanBrowsed()
    return browseSent == true
end

local function Browse(message)
    if not browseHooked then
        browseHooked = true
        hooksecurefunc(C_AuctionHouse, "SendBrowseQuery", OnOtherBrowse)
        hooksecurefunc(C_AuctionHouse, "SearchForFavorites", OnOtherBrowse)
        hooksecurefunc(C_AuctionHouse, "SearchForItemKeys", OnOtherBrowse)
    end
    scanning, ownScan, browsing = true, true, true
    browseSent, browseCount = nil, 0
    Label(TEXT_SCANNING)
    ns.Print(Tag() .. ": " .. message)
    for _, event in ipairs(BROWSE_EVENTS) do events:RegisterEvent(event) end
    Ask()
end

local function OnTimeout(gen)
    if gen ~= scanGen or not scanning then return end
    local own = ownScan
    Stop()
    events:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    if own then Browse(TEXT_TIMEOUT) end
end

local function Scan()
    if scanning then return end
    local wait = Wait()
    if wait and wait > 0 then return Browse(TEXT_PAGED:format(math.ceil(wait / SECONDS_PER_MINUTE))) end
    scanning, ownScan = true, true
    scanGen = scanGen + 1
    local gen = scanGen
    House(true).requested = GetServerTime()
    Label(TEXT_SCANNING)
    ns.Print(Tag() .. ": " .. TEXT_STARTED)
    events:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    C_AuctionHouse.ReplicateItems()
    C_Timer.After(TIMEOUT, function() OnTimeout(gen) end)
end

ns.AuctionScan = Scan

local function OnReplicate()
    if scanning and not browsing or not S.Get("ahCapture") then return end
    if not houseOpen then
        earlyAt = GetTime()
        return
    end
    House(true).requested = GetServerTime()
    events:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    if browsing then return end
    scanning = true
    scanGen = scanGen + 1
    local gen = scanGen
    C_Timer.After(TIMEOUT, function() OnTimeout(gen) end)
end

local function AutoScan()
    if not (houseOpen and ns.AuctionHouseShown() and S.Get("ahAutoScan")) or scanning or ns.GamepadStandDown() then return end
    local house = House()
    local at = house and house.time
    if at and GetServerTime() - at < S.Get("ahAutoScanMinutes") * SECONDS_PER_MINUTE then return end
    Scan()
end

local function AutoOn()
    return S.Get("ahAutoScan") == true
end

local function HookReplicate()
    if hooked or not S.Get("ahCapture") then return end
    hooked = true
    hooksecurefunc(C_AuctionHouse, "ReplicateItems", OnReplicate)
end

local function ButtonTip()
    return TEXT_TIP .. ns.AuctionScanSummary()
end

local function LastTab(frame)
    local market = ns.MarketAuctionTabs and ns.MarketAuctionTabs()
    if market then return market end
    local lib = LibStub and LibStub("LibAHTab-1-0", true)
    local tabs = lib and lib.internalState and lib.internalState.Tabs
    if tabs and #tabs > 0 then return tabs[#tabs] end
    return frame.AuctionsTab
end

local function Anchor()
    local frame = _G.AuctionHouseFrame
    if not (button and frame) then return end
    button:ClearAllPoints()
    local tab = LastTab(frame)
    if tab then
        button:SetPoint("LEFT", tab, "RIGHT", BUTTON_GAP, 0)
    else
        button:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -BUTTON_GAP, -BUTTON_DROP)
    end
end

local function BuildButton(frame)
    button = ns.Button(frame, TEXT_SCAN, BUTTON_W, BUTTON_H, Scan)
    ns.Tooltip(button, TEXT_SCAN, ButtonTip)
    button.age = ns.Font(button, AGE_SIZE, nil, ns.THEME.muted)
    button.age:SetPoint("LEFT", button, "RIGHT", BUTTON_GAP, 0)
end

local function ShowButton()
    local frame = _G.AuctionHouseFrame
    if not frame or ns.GamepadStandDown() then return end
    if not button then BuildButton(frame) end
    Anchor()
    C_Timer.After(0, Anchor)
    button:SetShown(S.Get("ahPrices"))
    ShowAge()
    if S.Get("ahPrices") and not ageTicker then ageTicker = C_Timer.NewTicker(AGE_TICK, ShowAge) end
end

local function Visit(neutral)
    if neutral == atNeutral then return end
    atNeutral = neutral
    merged, mergedFeed, pricedAt = nil, nil, nil
end

local function OnClosed()
    houseOpen, browseSent = nil, nil
    Stop(scanning and TEXT_CLOSED)
    Visit(false)
    if ageTicker then
        ageTicker:Cancel()
        ageTicker = nil
    end
end

local function OnEvent(_, event, added)
    if event == "AUCTION_HOUSE_SHOW" then
        houseOpen = true
        Visit(UnitExists("npc") and UnitFactionGroup("npc") ~= UnitFactionGroup("player")
            and C_PvP.GetZonePVPInfo() ~= FRIENDLY)
        if earlyAt == GetTime() then OnReplicate() end
        earlyAt = nil
        ShowButton()
        if S.Get("ahAutoScan") then C_Timer.After(AUTO_DELAY, AutoScan) end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        OnClosed()
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        Read()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if browseWaiting then Ask() end
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        Stop(TEXT_NO_ANSWER)
    else
        OnBrowsed(event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" and added)
    end
end

local function Cheapest(bundles)
    local cheapest
    for i = 1, #bundles do
        local price = ns.AuctionPrice(bundles[i][1])
        local total = price and price * bundles[i][2]
        if total and (not cheapest or total < cheapest) then cheapest = total end
    end
    return cheapest
end

local function AddBundles(tooltip, bundles, cheapest)
    for i = 1, #bundles do
        local item, count = bundles[i][1], bundles[i][2]
        local price = ns.AuctionPrice(item)
        local total = price and price * count
        if total then
            local coins, color = C_CurrencyInfo.GetCoinTextureString(total, COIN_SIZE), WHITE
            if total == cheapest then
                coins, color = coins .. " " .. ns.Color("muted", TEXT_CHEAPEST), ns.THEME.accent
            end
            tooltip:AddDoubleLine(TEXT_FILLING:format(count, Items.Name(item)), coins,
                color.r, color.g, color.b, WHITE.r, WHITE.g, WHITE.b)
        end
    end
end

local function AddPrices(tooltip, id)
    local own, crates, writs = S.Get("ahTooltip"), S.Get("ahCrates"), S.Get("ahWrits")
    if not (own or crates or writs) then return end
    local price, priceAt
    local market = ns.Market
    if own and not (market and market.ShowsPrice(tooltip, id)) then
        price, priceAt = ns.AuctionPrice(id, select(2, TooltipUtil.GetDisplayedItem(tooltip)))
    end
    local at = ns.AuctionScanTime() or priceAt
    if not (at or price or S.Get("ahTsm") or S.Get("ahAuctionator")) then return end
    local bundles = crates and ns.WaylaidCrates[id]
    local cheapest = bundles and Cheapest(bundles)
    local requested = writs and ns.WritRequests[id]
    local requestedPrice = requested and ns.AuctionPrice(requested)
    if not (price or cheapest or requestedPrice) then return end
    local age = at and Age(GetServerTime() - (priceAt or at))
    local right
    if price then
        right = C_CurrencyInfo.GetCoinTextureString(price, COIN_SIZE)
            .. (priceAt and TEXT_EACH:format(age) or TsmPrice(id) and TEXT_EACH_TSM or TEXT_EACH_AUCTIONATOR)
    elseif age then
        right = at == feedTime and TEXT_FEED_AGE:format(age) or TEXT_AGE:format(age, "")
    else
        right = ""
    end
    tooltip:AddDoubleLine(ns.Color("accent", TEXT_TOOLTIP_TAG), right, WHITE.r, WHITE.g, WHITE.b, WHITE.r, WHITE.g, WHITE.b)
    if cheapest then AddBundles(tooltip, bundles, cheapest) end
    if requestedPrice then
        tooltip:AddDoubleLine(TEXT_REQUESTED:format(Items.Name(requested)),
            C_CurrencyInfo.GetCoinTextureString(requestedPrice, COIN_SIZE), WHITE.r, WHITE.g, WHITE.b, WHITE.r, WHITE.g, WHITE.b)
    end
end

local function AddVendor(tooltip, id)
    local price = S.Get("ahVendor") and ns.VendorSold[id]
    if not price then return end
    local side = ns.VendorSoldSide[id]
    faction = faction or UnitFactionGroup("player")
    if side and side ~= faction then return end
    local tag = ns.VendorSoldLimited[id] and TEXT_VENDOR_LIMITED or TEXT_VENDOR_TAG
    tooltip:AddDoubleLine(ns.Color("accent", tag), C_CurrencyInfo.GetCoinTextureString(price, COIN_SIZE),
        WHITE.r, WHITE.g, WHITE.b, WHITE.r, WHITE.g, WHITE.b)
end

local function OnItemTooltip(tooltip, data)
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) then return end
    AddPrices(tooltip, id)
    AddVendor(tooltip, id)
end

local function HookTooltip()
    if tooltipHooked or not (S.Get("ahTooltip") or S.Get("ahCrates") or S.Get("ahWrits") or S.Get("ahVendor")) then return end
    tooltipHooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end

local function OnSettingChanged(key)
    if key == "ahPrices" and button then button:SetShown(S.Get("ahPrices")) end
    if key == "ahCapture" then HookReplicate() end
    if key == "ahTooltip" or key == "ahCrates" or key == "ahWrits" or key == "ahVendor" then HookTooltip() end
    if key == "ahTsm" or key == "ahAuctionator" then
        if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
        if ns.MarketRefresh then ns.MarketRefresh() end
        if ns.AuctionPricesChanged then ns.AuctionPricesChanged() end
    end
end

events:SetScript("OnEvent", OnEvent)
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
hooksecurefunc(S, "Set", OnSettingChanged)
ns.OnApply(HookTooltip)
HookReplicate()
HookTooltip()

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "auctionPrices", name = "Auction Prices", order = 30,
    help = "Auction house prices on item tooltips, from your own scans.",
    rows = {
        { key = "ahPrices", label = "Scan Prices Button", toggle = true, note = ScanLine,
          needs = ns.GamepadFree, why = ns.GamepadWhy,
          help = "A Scan Prices button on the auction house. It reads every listing and keeps the "
              .. "lowest buyout for each item, for this realm and faction. Blizzard allows one full "
              .. "scan every 15 minutes." },
        { key = "ahTooltip", label = "Auction House Price", toggle = true,
          help = "Item tooltips show an item's auction house price and how old it is." },
        { key = "ahCrates", label = "Waylaid Crate Prices", toggle = true,
          help = "Waylaid Crate tooltips show what each filling costs on the auction house." },
        { key = "ahWrits", label = "Craftsman's Writ Prices", toggle = true,
          help = "Craftsman's Writ tooltips show the item the writ asks for and what one costs on the auction house." },
        { key = "ahVendor", label = "Sold by Vendors", toggle = true,
          help = "Item tooltips say when a vendor sells the item, and what one costs there." },
        { key = "ahCapture", label = "Capture Other Addons' Scans", toggle = true,
          help = "Also keeps auction house prices from scans other addons start, such as Auctionator or TSM, "
              .. "full or summary, and from the searches you run and the items you post." },
        { key = "ahAutoScan", label = "Scan on Opening", toggle = true,
          needs = ns.GamepadFree, why = ns.GamepadWhy,
          help = "Scans by itself when you open the auction house and your last scan is old." },
        { key = "ahAutoScanMinutes", label = "Scan When Older Than", slider = AUTO_RANGE, unit = " min",
          needs = AutoOn, why = "Needs Scan on Opening",
          help = "How many minutes old your last scan must be to scan on opening." },
        { key = "ahShare", label = "Prices for Other Addons", toggle = true,
          needs = ns.PriceShareFree, why = "Auctionator is installed",
          help = "Addons that read Auctionator's prices get these prices while Auctionator is not installed." },
        { key = "ahAuctionator", label = "Auctionator Prices", toggle = true,
          needs = AuctionatorLoaded, why = "Needs Auctionator",
          help = "Tooltips, The Market and Professions use Auctionator's price for an item, "
              .. "and your own scans and Naowh's prices for an item Auctionator has no price for." },
        { key = "ahTsm", label = "TSM Prices", toggle = true,
          needs = TsmLoaded, why = "Needs TradeSkillMaster",
          help = "Tooltips, The Market and Professions use TradeSkillMaster's lowest buyout for an item, "
              .. "and your own scans and Naowh's prices for an item TSM has no price for." },
    },
})
