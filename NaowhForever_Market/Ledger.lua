-- Ledger.lua: what each character earns and spends, and its gold over time, from vendors, the auction house, mail and every other change in its gold (Market.Ledger).
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local Market = ns.Market
local S = Market.Settings
local C = Market.C

local STORE = "marketLedger"
local SELL_PRICE = 11
local INVOICE_COUNT = 11
local FIRST_BAG = 0
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local JUNK = Enum.ItemQuality.Poor
local SALE_INVOICE, BUY_INVOICE = "seller", "buyer"
local COLUMNS = { "at", "kind", "item", "qty", "amount", "who" }
local OPENS = { MERCHANT_SHOW = "merchant", AUCTION_HOUSE_SHOW = "auction", MAIL_SHOW = "mail", TRADE_SHOW = "trade",
    TAXIMAP_OPENED = "taxi", TRAINER_SHOW = "trainer", LOOT_OPENED = "loot", QUEST_COMPLETE = "quest" }
local CLOSES = { MERCHANT_CLOSED = "merchant", AUCTION_HOUSE_CLOSED = "auction", MAIL_CLOSED = "mail",
    TRADE_CLOSED = "trade", TAXIMAP_CLOSED = "taxi", TRAINER_CLOSED = "trainer", LOOT_CLOSED = "loot",
    QUEST_FINISHED = "quest" }
local EARNED = { merchant = "vendor", mail = "mail", trade = "trade", loot = "loot", quest = "quest" }
local SPENT = { merchant = "repair", auction = "deposit", mail = "postage", trade = "trade", taxi = "flight",
    trainer = "training", quest = "quest" }
local OTHER = "other"
local SALES = { auction = true, vendor = true }
local FAILED = { expired = true, cancelled = true }
local VIEWS = { sales = true, purchases = true, other = true, failed = true }

local events, hooked, recording, last
local place, placeWho, placeEnds
local pending, taken, takes = {}, {}, {}
local items, spentOn, scratch, cursor = {}, {}, {}, {}
local mailPatterns

local Ledger = { VIEWS = VIEWS }
Market.Ledger = Ledger

local function Data(create)
    local data = ns.Shared.CharacterData(STORE, create)
    if data and not data.at then
        for _, column in ipairs(COLUMNS) do data[column] = {} end
        data.goldAt, data.gold = {}, {}
    end
    return data
end

local function Drop(list, drop)
    local n = #list
    for i = 1, n - drop do list[i] = list[i + drop] end
    for i = n - drop + 1, n do list[i] = nil end
end

local function Trim(data)
    local drop = #data.at - C.LEDGER_KEEP
    if drop > 0 then
        for _, column in ipairs(COLUMNS) do Drop(data[column], drop) end
    end
    drop = #data.goldAt - C.LEDGER_KEEP
    if drop > 0 then
        Drop(data.goldAt, drop)
        Drop(data.gold, drop)
    end
end

local function Add(kind, item, qty, amount, who)
    local data = Data(true)
    local n = #data.at + 1
    data.at[n], data.kind[n], data.item[n] = time(), kind, item or 0
    data.qty[n], data.amount[n], data.who[n] = qty or 0, amount, who or ""
    if Ledger.onChange then Ledger.onChange() end
end

local function NoteGold(money)
    local data = Data(true)
    local at, gold, now = data.goldAt, data.gold, time()
    local n = #at
    if n > 1 and now - at[n - 1] < C.LEDGER_GOLD_STEP then
        at[n], gold[n] = now, money
    elseif gold[n] ~= money then
        at[n + 1], gold[n + 1] = now, money
    end
end

local function Here()
    if place and (not placeEnds or GetTime() <= placeEnds) then return place end
end

local function Expect(kind, item, qty, amount, sign, who, key)
    if key then
        if taken[key] then return end
        taken[key] = true
    end
    pending[#pending + 1] = { at = GetTime(), kind = kind, item = item, qty = qty, amount = amount, sign = sign,
        who = who, key = key }
end

local function Settle(i)
    local p = table.remove(pending, i)
    if p.key then taken[p.key] = nil end
    return p
end

local function OnMoney()
    local money = GetMoney()
    local left = money - last
    last = money
    NoteGold(money)
    if left == 0 then return end
    local now, i = GetTime(), 1
    while i <= #pending do
        local p = pending[i]
        if now - p.at > C.LEDGER_PENDING then
            Settle(i)
        elseif left ~= 0 and (p.sign > 0) == (left > 0) then
            local take = p.amount
            if not take or math.abs(take) > math.abs(left) then take = left end
            if p.kind then Add(p.kind, p.item, p.qty, take, p.who) end
            left = left - take
            Settle(i)
        else
            i = i + 1
        end
    end
    if left == 0 then return end
    local here = Here()
    local kind = (left > 0 and EARNED or SPENT)[here] or OTHER
    Add(kind, 0, 0, left, here and placeWho)
end

local function ItemOf(name)
    if not name then return 0 end
    return GetItemInfoInstant(name) or name
end

local function MailPattern(format)
    if not format then return end
    return "^" .. format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
end

local function Patterns()
    if not mailPatterns then
        mailPatterns = { sold = MailPattern(AUCTION_SOLD_MAIL_SUBJECT),
            expired = MailPattern(AUCTION_EXPIRED_MAIL_SUBJECT), cancelled = MailPattern(AUCTION_REMOVED_MAIL_SUBJECT),
            outbid = MailPattern(AUCTION_OUTBID_MAIL_SUBJECT) }
    end
    return mailPatterns
end

local function Subject(subject, which)
    local pattern = Patterns()[which]
    return subject and pattern and subject:match(pattern)
end

local function MailKey(index)
    local _, _, sender, subject, money = GetInboxHeaderInfo(index)
    return table.concat({ tostring(sender), tostring(subject), tostring(money) }, "|"), sender, subject, money
end

local function MailMoney(index)
    local key, sender, subject, money = MailKey(index)
    if not money or money <= 0 then return end
    local invoice, name, buyer = GetInboxInvoiceInfo(index)
    if invoice == SALE_INVOICE or Subject(subject, "sold") then
        local count = select(INVOICE_COUNT, GetInboxInvoiceInfo(index))
        Expect("auction", ItemOf(name or Subject(subject, "sold")), count or 1, money, 1, buyer, key)
    elseif Subject(subject, "outbid") then
        Expect(nil, 0, 0, money, 1, nil, key)
    else
        Expect("mail", 0, 0, money, 1, sender, key)
    end
end

local function Copies(sender, subject, link)
    local n = 0
    for index = 1, GetInboxNumItems() do
        local _, _, from, about = GetInboxHeaderInfo(index)
        if from == sender and about == subject then
            for attachment = 1, ATTACHMENTS_MAX_RECEIVE do
                if GetInboxItemLink(index, attachment) == link then n = n + 1 end
            end
        end
    end
    return n
end

local function MailItem(index, attachment, kind, amount, who)
    local link = GetInboxItemLink(index, attachment)
    if not link then return end
    local _, _, sender, subject = GetInboxHeaderInfo(index)
    local key = table.concat({ tostring(sender), tostring(subject), link }, "|")
    if takes[key] then return end
    local _, _, _, count = GetInboxItem(index, attachment)
    takes[key] = { kind = kind, item = GetItemInfoInstant(link) or 0, qty = count or 1, amount = amount, who = who,
        sender = sender, subject = subject, link = link, copies = Copies(sender, subject, link) }
end

local function WonByBid(index)
    local invoice, _, seller, bid, buyout = GetInboxInvoiceInfo(index)
    if invoice == BUY_INVOICE and bid and bid > 0 and (not buyout or buyout == 0 or bid < buyout) then
        return -bid, seller
    end
end

local function MailItems(index, only)
    local _, _, _, subject = GetInboxHeaderInfo(index)
    local kind = Subject(subject, "expired") and "expired" or Subject(subject, "cancelled") and "cancelled"
    local amount, who = 0, ""
    if not kind then
        amount, who = WonByBid(index)
        if not amount then return end
        kind = "auction"
    end
    if only then return MailItem(index, only, kind, amount, who) end
    for attachment = 1, ATTACHMENTS_MAX_RECEIVE do MailItem(index, attachment, kind, amount, who) end
end

local function OnInbox()
    for key, take in pairs(takes) do
        if Copies(take.sender, take.subject, take.link) < take.copies then
            Add(take.kind, take.item, take.qty, take.amount, take.who)
            takes[key] = nil
        end
    end
end

local function OnTakeMoney(index)
    if recording and Here() == "mail" then MailMoney(index) end
end

local function OnTakeItem(index, attachment)
    if recording and Here() == "mail" then MailItems(index, attachment) end
end

local function OnSend(recipient)
    if not (recording and Here() == "mail") then return end
    local money = GetSendMailMoney()
    if money > 0 then Expect("mail", 0, 0, -money, -1, recipient) end
end

local function OnAutoLoot(index)
    if not (recording and Here() == "mail") then return end
    MailMoney(index)
    MailItems(index)
end

local function SellValue(info)
    if not info or info.hasNoValue then return end
    local price = select(SELL_PRICE, GetItemInfo(info.itemID))
    if price and price > 0 then return price * info.stackCount end
end

local function OnUse(bag, slot)
    if not (recording and Here() == "merchant" and not placeEnds) then return end
    local info = GetContainerItemInfo(bag, slot)
    local value = SellValue(info)
    if value then Expect("vendor", info.itemID, info.stackCount, value, 1, placeWho) end
end

local function OnSellJunk()
    if not (recording and Here() == "merchant") then return end
    for bag = FIRST_BAG, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            local value = info and info.quality == JUNK and SellValue(info)
            if value then Expect("vendor", info.itemID, info.stackCount, value, 1, placeWho) end
        end
    end
end

local function OnBuy(index, quantity)
    if not (recording and Here() == "merchant") then return end
    local info = C_MerchantFrame.GetItemInfo(index)
    if not info or info.price <= 0 then return end
    local stack = math.max(1, info.stackCount)
    local qty = quantity or stack
    Expect("vendor", GetMerchantItemID(index) or 0, qty, -math.ceil(info.price * qty / stack), -1, placeWho)
end

local function OnBuyback(index)
    if not (recording and Here() == "merchant") then return end
    local _, _, price, quantity = GetBuybackItemInfo(index)
    if price and price > 0 then
        Expect("vendor", C_MerchantFrame.GetBuybackItemID(index) or 0, quantity or 1, -price, -1, placeWho)
    end
end

local function OnBid(auctionID, amount)
    if not (recording and amount and amount > 0) then return end
    local info = C_AuctionHouse.GetAuctionInfoByID(auctionID)
    if info and not (info.buyoutAmount and amount >= info.buyoutAmount) then
        return Expect(nil, 0, 0, -amount, -1)
    end
    Expect("auction", info and info.itemKey.itemID or 0, info and info.quantity or 1, -amount, -1)
end

local function OnCommodity(itemID, quantity)
    if recording then Expect("auction", itemID, quantity, nil, -1) end
end

local function Hook()
    if hooked then return end
    hooked = true
    hooksecurefunc(C_Container, "UseContainerItem", OnUse)
    hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", OnSellJunk)
    hooksecurefunc(_G, "BuyMerchantItem", OnBuy)
    hooksecurefunc(_G, "BuybackItem", OnBuyback)
    hooksecurefunc(C_AuctionHouse, "PlaceBid", OnBid)
    hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", OnCommodity)
    hooksecurefunc(_G, "TakeInboxMoney", OnTakeMoney)
    hooksecurefunc(_G, "TakeInboxItem", OnTakeItem)
    hooksecurefunc(_G, "AutoLootMailItem", OnAutoLoot)
    hooksecurefunc(_G, "SendMail", OnSend)
end

local function OnEvent(_, event)
    if event == "PLAYER_MONEY" then return OnMoney() end
    if event == "MAIL_INBOX_UPDATE" then return OnInbox() end
    local opened = OPENS[event]
    if opened then
        place, placeEnds = opened, nil
        placeWho = UnitName("npc") or ""
        if opened == "quest" then placeWho = GetTitleText() or placeWho end
    elseif CLOSES[event] == place then
        placeEnds = GetTime() + C.LEDGER_GRACE
        if place == "mail" then
            OnInbox()
            wipe(takes)
        end
    end
end

function Ledger.On()
    return Market.On() and S.Get("ledger")
end

local function Start()
    local data = Data(true)
    data.name, data.realm = UnitName("player"), ns.RealmName()
    data.class = select(2, UnitClass("player"))
    Trim(data)
    last = GetMoney()
    NoteGold(last)
    recording = true
end

local function Apply()
    local on = Ledger.On() and IsLoggedIn()
    if not on then
        recording = false
        place = nil
        if events then events:UnregisterAllEvents() end
        wipe(pending)
        wipe(taken)
        wipe(takes)
        return
    end
    if recording then return end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    Hook()
    events:RegisterEvent("PLAYER_MONEY")
    events:RegisterEvent("MAIL_INBOX_UPDATE")
    for event in pairs(OPENS) do events:RegisterEvent(event) end
    for event in pairs(CLOSES) do events:RegisterEvent(event) end
    Start()
end

function Ledger.View(kind, amount)
    if FAILED[kind] then return "failed" end
    if SALES[kind] then return amount > 0 and "sales" or "purchases" end
    return "other"
end

function Ledger.Characters(out)
    wipe(out)
    for guid, data in pairs(ns.AccountSettings()[STORE] or {}) do
        if type(data) == "table" and data.at then out[#out + 1] = { guid = guid, data = data } end
    end
    return out
end

function Ledger.Row(chars, row)
    local c = math.floor(row / C.LEDGER_ROW_SHIFT)
    return chars[c].data, row - c * C.LEDGER_ROW_SHIFT, chars[c]
end

function Ledger.Collect(out, chars, view, from, match)
    wipe(out)
    for c, char in ipairs(chars) do
        local data = char.data
        local at, kind, amount = data.at, data.kind, data.amount
        for i = #at, 1, -1 do
            if at[i] < from then break end
            if Ledger.View(kind[i], amount[i]) == view and (not match or match(data, i)) then
                out[#out + 1] = c * C.LEDGER_ROW_SHIFT + i
            end
        end
    end
    return out
end

local function Top(list)
    local best, most
    for item, total in pairs(list) do
        if item ~= 0 and (not most or total > most) then best, most = item, total end
    end
    return best, most
end

function Ledger.Summary(chars, from)
    local sum = scratch
    sum.sales, sum.purchases, sum.otherIn, sum.otherOut = 0, 0, 0, 0
    local sold, bought = wipe(items), wipe(spentOn)
    for _, char in ipairs(chars) do
        local data = char.data
        local at, kind, item, amount = data.at, data.kind, data.item, data.amount
        for i = #at, 1, -1 do
            if at[i] < from then break end
            local view, value = Ledger.View(kind[i], amount[i]), amount[i]
            if view == "sales" then
                sum.sales = sum.sales + value
                sold[item[i]] = (sold[item[i]] or 0) + value
            elseif view == "purchases" then
                sum.purchases = sum.purchases - value
                bought[item[i]] = (bought[item[i]] or 0) - value
            elseif view == "other" then
                if value > 0 then sum.otherIn = sum.otherIn + value else sum.otherOut = sum.otherOut - value end
            end
        end
    end
    sum.topSale = Top(sold)
    sum.topPurchase = Top(bought)
    sum.earned = sum.sales + sum.otherIn
    sum.spent = sum.purchases + sum.otherOut
    return sum
end

local function Earlier(a, b)
    if not a then return b end
    if not b then return a end
    return math.min(a, b)
end

function Ledger.First(chars)
    local first
    for _, char in ipairs(chars) do first = Earlier(first, Earlier(char.data.goldAt[1], char.data.at[1])) end
    return first
end

local function GoldAt(data, when, from)
    local at = data.goldAt
    local i = from
    while at[i + 1] and at[i + 1] <= when do i = i + 1 end
    return i
end

function Ledger.Gold(chars, from, to, count, out)
    wipe(out)
    local step = (to - from) / (count - 1)
    local at = wipe(cursor)
    for c in ipairs(chars) do at[c] = 0 end
    for i = 1, count do
        local when, total = from + (i - 1) * step, nil
        for c, char in ipairs(chars) do
            at[c] = GoldAt(char.data, when, at[c])
            local gold = at[c] > 0 and char.data.gold[at[c]]
            if gold then total = (total or 0) + gold end
        end
        out[i] = total or false
    end
    return out
end

function Ledger.Change(chars, from, to)
    local change
    for _, char in ipairs(chars) do
        local data = char.data
        local before = GoldAt(data, from, 0)
        if before > 0 then
            change = (change or 0) + data.gold[GoldAt(data, to, before)] - data.gold[before]
        end
    end
    return change
end

Market.Settings.OnChange(function(key)
    if key == "enabled" or key == "ledger" then Apply() end
end)
ns.OnApply(Apply)
