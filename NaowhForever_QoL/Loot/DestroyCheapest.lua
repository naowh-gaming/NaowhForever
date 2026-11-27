-- DestroyCheapest.lua: when bags are full, the state the scan, the popup and the delete share.
local ns = _G.NaowhForever

local GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots

local S = ns.QoLSettings
local Coins = ns.Shared.Parts.Coins

local D = {}
ns.DestroyCheapest = D

local PLAIN = ns.QoLConstants.PLAIN_BAG
local REAGENT_BAG_INDEX = Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
local TRANSFER_FRAMES = {
    "BankFrame", "EUI_BankFrame", "MailFrame", "TradeFrame",
    "MerchantFrame", "GuildBankFrame", "QuestFrame",
}
D.TRANSFER_FRAMES = TRANSFER_FRAMES

D.STALE_DAYS = 7
D.STALE_RANGE = { 1, 30, 1 }
D.STACK_COLUMNS = 2
D.TEXT = {
    BLANK_DESTROY = ns.L("Nothing safe to destroy"),
    DESTROY = ns.L("Destroy"),
    LOOT = ns.L("You get"),
    WAITING = ns.L("Waiting for the bags to update."),
    DIALOG = ns.L("Confirm the delete in the game window. Cancel puts it back."),
    STUCK = ns.L("That item is still on your cursor. Click its bag slot to put it back."),
    NOT_WORTH = ns.L("Not worth it: this loot is worth less than the item that would be destroyed."),
    NONE = ns.L("Nothing here is safe to destroy. Quest items, books, recipes, tools, set pieces and turned-off qualities stay."),
    HOLDING = ns.L("put down what you are holding first."),
    MOVED = ns.L("that item changed in your bags. The list has been refreshed."),
    COMBAT = ns.L("leave combat, then destroy it."),
    DESTROYED = ns.L("destroyed %s (%s)."),
    LOOT_AGAIN = ns.L("made room. Loot it again."),
    LOOT_COMBAT = ns.L("made room. Loot it again once combat ends."),
    ROOM = ns.L("made room."),
    AGAIN = ns.L("Loot it again after making room."),
    BLOCKED = ns.L("the game did not delete that, so it is back in your bags."),
    RETURNED = ns.L("that item is back in your bags."),
    IGNORED = ns.L("will not suggest %s again."),
    MARKET = ns.L("AH %s"),
    MARKET_OLD = ns.L("AH %s (%s)"),
    COUNT = ns.L("%d/%d"),
    LIST_HEAD = ns.L("Ignored Items (%d)"),
    LIST_EMPTY = ns.L("Nothing ignored yet. Ignore Item on the popup adds the one you are looking at."),
    LIST_NONE = ns.L("No ignored item matches your search."),
    ITEM = ns.L("Item "),
    CLEAR_ASK = "Offer every item you ignored again?",
    CONFIRM = "Click again to destroy",
    ANYWAY = "Destroy Anyway",
    DESTROY_LOOT = "Destroy & Loot",
    DESTROY_ONLY = "Destroy",
    INCOMING = ns.L("Incoming"),
    VENDOR_TAG = ns.L("Vendor:"),
    VENDOR_EST_TAG = ns.L("Vendor est."),
    AH_TAG = ns.L("AH est."),
    UNAVAILABLE = ns.L("unavailable"),
    COL_EACH = ns.L("Individual"),
    COL_STACK = ns.L("Stack"),
    COL_TOTAL = ns.L("Total"),
    CMP_VENDOR = ns.L("Vendor"),
    CMP_AH = ns.L("AH est."),
    WORD_PROFIT = ns.L("Profit"),
    WORD_DEFICIT = ns.L("Deficit"),
}

D.picks, D.pool, D.used = {}, {}, 0
D.loots, D.lootPool, D.lootUsed = {}, {}, 0
D.index, D.lootIndex = 1, 1
D.waitingInfo, D.requested = {}, {}
D.pendingLoads, D.loadCount = {}, 0
D.setItems = {}
D.transferHooks = {}
D.watch = CreateFrame("Frame")
local priceCells, compareGaps = {}, {}

function D.On()
    return S.Get("enabled") and S.Get("destroyCheapest")
end

function D.IsPlain(bag)
    if bag == REAGENT_BAG_INDEX then return false end
    local _, family = GetContainerNumFreeSlots(bag)
    return family == nil or family == PLAIN
end

function D.ReagentBagIndex()
    return REAGENT_BAG_INDEX
end

function D.ReagentFree()
    local free = GetContainerNumFreeSlots(REAGENT_BAG_INDEX)
    if type(free) ~= "number" then return end
    return free
end

function D.PlainFree()
    local free = 0
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    for bag = BACKPACK_CONTAINER, last do
        if D.IsPlain(bag) then
            local n = GetContainerNumFreeSlots(bag)
            free = free + (n or 0)
        end
    end
    return free
end

function D.BagsFull(a, b)
    return b == ERR_INV_FULL or b == ERR_BAG_FULL or a == ERR_INV_FULL or a == ERR_BAG_FULL
end

function D.LootShown()
    return LootFrame:IsShown()
end

function D.TransferShown()
    if not S.Get("destroyCheapestTransfers") then return false end
    for i = 1, #TRANSFER_FRAMES do
        local frame = _G[TRANSFER_FRAMES[i]]
        if frame and frame.IsShown and frame:IsShown() then return true end
    end
    return false
end

function D.CursorHolds(itemID)
    local kind, id = GetCursorInfo()
    return kind == "item" and id == itemID
end

function D.Ignored(itemID)
    local db = S.DB()
    local own = db and db.destroyCheapestIgnore
    return own and own[itemID] ~= nil or false
end

function D.IgnoreAdd(itemID)
    local db = S.DB()
    local list = db.destroyCheapestIgnore
    if type(list) ~= "table" then
        list = {}
        db.destroyCheapestIgnore = list
    end
    list[itemID] = time()
end

function D.Opened()
    return D.popup and D.popup:IsShown()
end

function D.RankQty()
    return S.Get("destroyCheapestRankQty") == "unit" and "unit" or "batch"
end

function D.EnsureMarket(e)
    if type(e) ~= "table" or e.marketChecked or not e.itemID then return end
    e.marketChecked = true
    local price, age, fresh = D.Quote(e.itemID)
    e.marketKnown = type(price) == "number" and price > 0
    if not e.marketKnown then return end
    e.marketUnit, e.marketAge, e.marketFresh = price, age, fresh
    e.market = price * (e.count or 1)
end

local function MarketOn()
    return S.Get("destroyCheapestMarket") == true or S.Get("destroyCheapestMarketRank") == true
end

function D.PriceCells(e)
    local cells = wipe(priceCells)
    cells.vendorLabel = D.TEXT.VENDOR_TAG
    cells.ahLabel = D.TEXT.AH_TAG
    cells.showStack = false
    cells.vendorTone = "muted"
    cells.ahTone = "muted"
    cells.vendorEach = D.TEXT.UNAVAILABLE
    cells.ahEach = D.TEXT.UNAVAILABLE
    if type(e) ~= "table" then return cells end
    if MarketOn() then D.EnsureMarket(e) end
    local count = e.count
    if type(count) == "number" and count > 1 then cells.showStack = true end
    if e.vendorEstimated == true then cells.vendorLabel = D.TEXT.VENDOR_EST_TAG end
    if e.vendorKnown == true and type(e.vendorUnit) == "number" then
        cells.vendorEach = Coins(e.vendorUnit)
        cells.vendorTone = e.vendorUnit > 0 and "fg" or "muted"
        if cells.showStack then cells.vendorStack = Coins(e.vendorUnit * count) end
    end
    local market = e.marketKnown == true and type(e.marketUnit) == "number" and e.marketUnit > 0
    if market then
        cells.ahEach = Coins(e.marketUnit)
        cells.ahTone = e.marketFresh == true and "fg" or "muted"
        if cells.showStack then cells.ahStack = Coins(e.marketUnit * count) end
    end
    return cells
end

local function CountOf(row)
    local count = row.count
    if type(count) ~= "number" or count < 1 then return end
    return count
end

local function VendorUnitOf(row)
    if row.vendorKnown == true and type(row.vendorUnit) == "number" then return row.vendorUnit end
end

local function MarketUnitOf(row)
    if row.marketKnown == true and row.marketFresh == true
        and type(row.marketUnit) == "number" and row.marketUnit > 0 then
        return row.marketUnit
    end
end

function D.CompareGaps(pick, loot)
    local out = wipe(compareGaps)
    out.columns = 1
    if type(pick) ~= "table" or type(loot) ~= "table" then return out end
    if MarketOn() then
        D.EnsureMarket(pick)
        D.EnsureMarket(loot)
    end
    local pickCount, lootCount = CountOf(pick), CountOf(loot)
    local pickVendor, lootVendor = VendorUnitOf(pick), VendorUnitOf(loot)
    if pickVendor ~= nil and lootVendor ~= nil then
        out.vendorEach = lootVendor - pickVendor
        if pickCount and lootCount then
            out.vendorStack = (lootVendor * lootCount) - (pickVendor * pickCount)
        end
    end
    local pickMarket, lootMarket = MarketUnitOf(pick), MarketUnitOf(loot)
    if pickMarket ~= nil and lootMarket ~= nil then
        out.ahEach = lootMarket - pickMarket
        if pickCount and lootCount then
            out.ahStack = (lootMarket * lootCount) - (pickMarket * pickCount)
        end
    end
    if pickCount and lootCount and not (pickCount == 1 and lootCount == 1) then
        out.columns = D.STACK_COLUMNS
        out.stackLabel = lootCount == 1 and D.TEXT.COL_TOTAL or D.TEXT.COL_STACK
    end
    return out
end

function D.GapTone(delta)
    if type(delta) ~= "number" then return "neutral" end
    if delta > 0 then return "good" end
    if delta < 0 then return "bad" end
    return "neutral"
end

function D.SignedCoin(delta)
    if type(delta) ~= "number" then return end
    if delta > 0 then return "+" .. Coins(delta) end
    if delta < 0 then return "-" .. Coins(-delta) end
    return Coins(0)
end
