-- DestroyCheapest.lua: when bags are full, the state the scan, the popup and the delete share.
local ns = _G.NaowhForever

local GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots

local S = ns.QoLSettings

local D = {}
ns.DestroyCheapest = D

local PLAIN = ns.QoLConstants.PLAIN_BAG
local TRANSFER_FRAMES = {
    "BankFrame", "EUI_BankFrame", "MailFrame", "TradeFrame",
    "MerchantFrame", "GuildBankFrame", "QuestFrame",
}
D.TRANSFER_FRAMES = TRANSFER_FRAMES

local REAGENT_BAG_INDEX = 5
local SHRUNK_LOOT_SCALE = 0.05
local LOOT_RECENT_SECONDS = 3
local LINK_KEY, ID_KEY = "l:", "i:"

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
    NONE = ns.L("Nothing here is safe to destroy. Quest items, books, recipes, tools, set pieces, bound armor and turned-off qualities stay."),
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
    FOR_STACK = ns.L("%s for %d"),
    TRACE_AGAIN = ns.L("Some items were still loading. Press Trace Bags again once their names appear."),
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
    INCOMING_UNAVAILABLE = ns.L("Incoming item unavailable. The loot slot could not be read."),
    INCOMING_PENDING = ns.L("Item data is still loading."),
    QUEST_ROOM = "Make Room for Quest",
    ANYWAY_UNKNOWN = "Value Unknown",
    ANYWAY_ZERO = "No Vendor Value",
    ANYWAY_RISKY = "Auction Only",
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
    STATUS_MORE = ns.L("Incoming item is worth more."),
    STATUS_LESS = ns.L("Incoming item is worth less."),
    STATUS_EQUAL = ns.L("Equal value."),
    STATUS_QUEST = ns.L("Quest item: make room."),
    STATUS_UNKNOWN = ns.L("Value unknown."),
    STATUS_ZERO = ns.L("No vendor value."),
    STATUS_RISKY = ns.L("Auction estimate only."),
    STATUS_AH = ns.L("Auction estimate unavailable."),
    STATUS_UNAVAILABLE = ns.L("Incoming item unavailable."),
}

D.picks, D.pool, D.used = {}, {}, 0
D.loots, D.lootPool, D.lootUsed = {}, {}, 0
D.index, D.lootIndex = 1, 1
D.waitingInfo, D.requested = {}, {}
D.loadDone, D.linkQueued, D.traceSeen = {}, {}, {}
D.loadFails, D.loadWatch = {}, {}
D.loadGen = 0
D.pendingLoads, D.loadCount = {}, 0
D.setItems = {}
D.transferHooks = {}
D.watch = CreateFrame("Frame")

function D.ResetPerf()
    D.perf = {
        scans = 0, refreshes = 0, paints = 0, paintSkips = 0,
        quotes = 0, quoteHits = 0, infos = 0, infoHits = 0,
        setBuilds = 0, setHits = 0, bagEvents = 0, scheduled = 0, coalesced = 0,
    }
end
D.ResetPerf()

function D.PerfAdd(name)
    local perf = D.perf
    if not perf then return end
    perf[name] = (perf[name] or 0) + 1
end

local NONE = {}
local memo = {}
D.scanOpts = memo

function D.Opt(key)
    if not (D.scanning or D.painting) then return S.Get(key) end
    local v = memo[key]
    if v == nil then
        v = S.Get(key)
        if v == nil then v = NONE end
        memo[key] = v
    end
    if v == NONE then return nil end
    return v
end

function D.ForgetOpts()
    wipe(memo)
end

function D.On()
    return S.Get("enabled") and S.Get("destroyCheapest")
end

function D.ReagentBagIndex()
    local index = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if type(index) == "number" and not (issecretvalue and issecretvalue(index)) then
        return index
    end
    return REAGENT_BAG_INDEX
end

function D.IsReagentBag(bag)
    if bag == REAGENT_BAG_INDEX then return true end
    return bag == D.ReagentBagIndex()
end

function D.IsPlain(bag)
    if D.IsReagentBag(bag) then return false end
    local _, family = GetContainerNumFreeSlots(bag)
    if issecretvalue and issecretvalue(family) then return true end
    return family == nil or family == PLAIN
end

function D.PlainFree()
    local free = 0
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    for bag = BACKPACK_CONTAINER, last do
        if D.IsPlain(bag) then
            local n = GetContainerNumFreeSlots(bag)
            if type(n) == "number" and not (issecretvalue and issecretvalue(n)) then
                free = free + n
            end
        end
    end
    return free
end

function D.ReagentFree()
    local n = GetContainerNumFreeSlots(D.ReagentBagIndex())
    if type(n) ~= "number" or (issecretvalue and issecretvalue(n)) then return 0 end
    return n
end

local function SameText(value, constant)
    if type(constant) ~= "string" or type(value) ~= "string" then return false end
    if issecretvalue and (issecretvalue(value) or issecretvalue(constant)) then return false end
    return value == constant
end

function D.ErrorName(a, b)
    if type(GetGameMessageInfo) ~= "function" then return nil end
    local function one(value)
        if type(value) ~= "number" then return nil end
        if issecretvalue and issecretvalue(value) then return nil end
        local ok, name = pcall(GetGameMessageInfo, value)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return one(a) or one(b)
end

function D.BagsFull(a, b)
    local name = D.ErrorName(a, b)
    if name == "ERR_INV_FULL" or name == "ERR_BAG_FULL" then return true end
    if SameText(a, ERR_INV_FULL) or SameText(a, ERR_BAG_FULL)
        or SameText(b, ERR_INV_FULL) or SameText(b, ERR_BAG_FULL) then
        return true
    end
    local secret = issecretvalue and ((a ~= nil and issecretvalue(a)) or (b ~= nil and issecretvalue(b)))
    return secret and D.PlainFree() == 0 and (D.LootLive() or D.LootRecent()) or false
end

function D.LootShown()
    return LootFrame:IsShown()
end

function D.LootVisible()
    if not D.LootShown() then return false end
    if not (LootFrame and LootFrame.GetEffectiveScale) then return true end
    local scale = LootFrame:GetEffectiveScale()
    if issecretvalue and issecretvalue(scale) then return true end
    if type(scale) ~= "number" then return true end
    return scale >= SHRUNK_LOOT_SCALE
end

function D.LootLive()
    if D.LootShown() then return true end
    if not GetNumLootItems then return false end
    local n = GetNumLootItems()
    if issecretvalue and issecretvalue(n) then return false end
    return type(n) == "number" and n > 0
end

function D.NoteLoot()
    if GetTime then D.lootAt = GetTime() end
end

function D.LootRecent()
    local at = D.lootAt
    if type(at) ~= "number" or not GetTime then return false end
    local now = GetTime()
    if type(now) ~= "number" then return false end
    return now >= at and (now - at) <= LOOT_RECENT_SECONDS
end

function D.WhyNotOpen(a, b)
    if not D.On() then return "feature-off" end
    if D.pending then return "pending" end
    if not D.BagsFull(a, b) then return "not-full-error" end
    if D.PlainFree() > 0 then return "plain-free" end
    if ns.GamepadStandDown and ns.GamepadStandDown() then return "gamepad" end
    if D.LootLive() or D.LootRecent() or D.TransferShown() then return nil end
    return "no-context"
end

function D.WantOpen(a, b)
    return D.WhyNotOpen(a, b) == nil
end

function D.KeepOpen()
    if D.PlainFree() > 0 then return false end
    if D.LootShown() or D.TransferShown() then return true end
    return false
end

function D.TransferShown()
    if not D.Opt("destroyCheapestTransfers") then return false end
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

local IGNORE_KEY = "\1ignore"

function D.Ignored(itemID)
    local own
    if D.scanning or D.painting then
        own = memo[IGNORE_KEY]
        if own == nil then
            local db = S.DB()
            own = db and db.destroyCheapestIgnore or NONE
            memo[IGNORE_KEY] = own
        end
        if own == NONE then own = nil end
    else
        local db = S.DB()
        own = db and db.destroyCheapestIgnore
    end
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

function D.PriceMode()
    local mode = D.Opt("destroyCheapestPriceMode")
    if mode == "unit" or mode == "both" then return mode end
    return "stack"
end

function D.RankQty()
    if D.Opt("destroyCheapestRankQty") == "unit" then return "unit" end
    return "batch"
end

function D.Coin(copper)
    local parts = ns.Shared and ns.Shared.Parts
    local coins = parts and parts.Coins
    if coins then return coins(copper) end
    return tostring(copper)
end

local TEXT = D.TEXT

function D.LoadKey(itemID, link)
    if type(link) == "string" and link ~= "" then return LINK_KEY .. link end
    return ID_KEY .. tostring(itemID or "")
end

function D.IsLinkKey(key)
    return type(key) == "string" and key:sub(1, #LINK_KEY) == LINK_KEY
end

function D.KeyBody(key)
    return key:sub(#LINK_KEY + 1)
end

local function Priced(e)
    if D.EnsureMarket then D.EnsureMarket(e) end
end

function D.GapTone(delta)
    if type(delta) ~= "number" then return "neutral" end
    if delta > 0 then return "good" end
    if delta < 0 then return "bad" end
    return "neutral"
end

function D.SignedCoin(delta)
    if type(delta) ~= "number" then return nil end
    if delta > 0 then return "+" .. D.Coin(delta) end
    if delta < 0 then return "-" .. D.Coin(-delta) end
    return D.Coin(0)
end

function D.PriceCells(e)
    local cells = {
        vendorLabel = TEXT.VENDOR_TAG,
        ahLabel = TEXT.AH_TAG,
        showStack = false,
        vendorTone = "muted",
        ahTone = "muted",
        vendorEach = TEXT.UNAVAILABLE,
        ahEach = TEXT.UNAVAILABLE,
    }
    if type(e) ~= "table" then return cells end
    Priced(e)
    local count = e.count
    if type(count) == "number" and count > 1 then cells.showStack = true end
    if e.vendorEstimated == true then cells.vendorLabel = TEXT.VENDOR_EST_TAG end
    if e.vendorKnown == true and type(e.vendorUnit) == "number" then
        cells.vendorEach = D.Coin(e.vendorUnit)
        cells.vendorTone = e.vendorUnit > 0 and "fg" or "muted"
        if cells.showStack then cells.vendorStack = D.Coin(e.vendorUnit * count) end
    end
    local fresh = e.marketKnown == true and e.marketFresh == true
        and type(e.marketUnit) == "number" and e.marketUnit > 0
    if fresh then
        cells.ahEach = D.Coin(e.marketUnit)
        cells.ahTone = "fg"
        if cells.showStack then cells.ahStack = D.Coin(e.marketUnit * count) end
    end
    return cells
end

local function CountOf(row)
    local n = row.count
    if type(n) ~= "number" or n < 1 then return nil end
    return n
end

local function VendorUnitOf(row)
    if row.vendorKnown == true and type(row.vendorUnit) == "number" then return row.vendorUnit end
end

local function AhUnitOf(row)
    if row.marketKnown == true and row.marketFresh == true
        and type(row.marketUnit) == "number" and row.marketUnit > 0 then
        return row.marketUnit
    end
end

function D.CompareGaps(pick, loot)
    local out = { columns = 1 }
    if type(pick) ~= "table" or type(loot) ~= "table" then return out end
    Priced(pick)
    Priced(loot)
    local countOf, vendorUnit, ahUnit = CountOf, VendorUnitOf, AhUnitOf
    local pc, lc = countOf(pick), countOf(loot)
    local pu, lu = vendorUnit(pick), vendorUnit(loot)
    if pu ~= nil and lu ~= nil then
        out.vendorEach = lu - pu
        if pc and lc then out.vendorStack = (lu * lc) - (pu * pc) end
    end
    local pau, lau = ahUnit(pick), ahUnit(loot)
    if pau ~= nil and lau ~= nil then
        out.ahEach = lau - pau
        if pc and lc then out.ahStack = (lau * lc) - (pau * pc) end
    end
    if pc and lc and not (lc == 1 and pc == 1) then
        out.columns = D.STACK_COLUMNS
        if lc == 1 then out.stackLabel = TEXT.COL_TOTAL else out.stackLabel = TEXT.COL_STACK end
    end
    return out
end

local function StatusSuffix(pick, loot)
    if D.Opt("destroyCheapestMarketRank") ~= true or type(D.ItemValue) ~= "function" then return "" end
    local _, ps = D.ItemValue(pick)
    local _, ls = D.ItemValue(loot)
    if ps == "ah" and ls == "ah" then return "" end
    return " " .. TEXT.STATUS_AH
end

function D.StatusLine(pick, loot)
    if type(pick) ~= "table" then return nil, "neutral" end
    if type(loot) ~= "table" then
        if D.LootShown and D.LootShown() and D.lootGap then
            return TEXT.STATUS_UNAVAILABLE, "neutral"
        end
        return nil, "neutral"
    end
    local worth, reason = true, nil
    if D.Compare then worth, reason = D.Compare(pick, loot) end
    if reason == "quest" then return TEXT.STATUS_QUEST, "good" end
    if reason == "unknown" then return TEXT.STATUS_UNKNOWN .. StatusSuffix(pick, loot), "neutral" end
    if reason == "zero" then return TEXT.STATUS_ZERO .. StatusSuffix(pick, loot), "bad" end
    if reason == "risky" then return TEXT.STATUS_RISKY, "neutral" end
    local pv, lv
    if type(D.ItemValue) == "function" then
        pv = D.ItemValue(pick)
        lv = D.ItemValue(loot)
    end
    local equal = type(pv) == "number" and type(lv) == "number" and lv == pv
    if reason == "low" then return TEXT.STATUS_LESS .. StatusSuffix(pick, loot), "bad" end
    if reason == "favorable" or worth then
        if equal then return TEXT.STATUS_EQUAL .. StatusSuffix(pick, loot), "neutral" end
        return TEXT.STATUS_MORE .. StatusSuffix(pick, loot), "good"
    end
    return nil, "neutral"
end

function D.ResetLoads()
    wipe(D.requested)
    wipe(D.waitingInfo)
    wipe(D.loadDone)
    wipe(D.linkQueued)
    wipe(D.loadFails)
    wipe(D.loadWatch)
    D.loadCount = 0
    D.loadGen = (D.loadGen or 0) + 1
    D.keepSets = false
    D.caching = false
    D.inlineLoad = false
    D.refreshQueued = false
    if D.WipeCaches then D.WipeCaches() end
end

function D.ClearTrace()
    wipe(D.traceSeen)
    D.tracePrints = 0
    D.traceCapped = false
    D.traceOn = false
end
