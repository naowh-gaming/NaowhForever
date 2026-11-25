-- Run with Lua 5.1 from the repository root: The Market's Ledger, recording gold from vendors, the auction house, mail and the rest.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local t = World.Setup({ money = 1000 })
local ns, env = t.ns, t.env
local clock = 100
local inbox, merchant, auctions = {}, {}, {}
local loggedIn = true

ns.Shared.CharacterData = function(key, create)
    local all = t.account[key]
    if not all and create then
        all = {}
        t.account[key] = all
    end
    if all and not all["Player-1"] and create then all["Player-1"] = {} end
    return all and all["Player-1"]
end
env.Enum.ItemQuality = { Poor = 0 }
env.ATTACHMENTS_MAX_RECEIVE = 2
env.AUCTION_SOLD_MAIL_SUBJECT = "Auction successful: %s"
env.AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
env.AUCTION_REMOVED_MAIL_SUBJECT = "Auction cancelled: %s"
env.AUCTION_OUTBID_MAIL_SUBJECT = "Outbid on %s"
env.GetInboxNumItems = function() return #inbox end
env.GetTime = function() return clock end
env.IsLoggedIn = function() return loggedIn end
local SECRET = {}
local npcName = "Bob"
env.issecretvalue = function(v) return v == SECRET end
env.UnitName = function(unit) return unit == "npc" and npcName or "Me" end
env.GetTitleText = function() return "Wanted" end
env.C_Container.UseContainerItem = function() end
env.C_MerchantFrame = {
    GetItemInfo = function(i) return merchant[i] end,
    SellAllJunkItems = function() end,
    GetBuybackItemID = function() return 6000 end,
}
env.GetMerchantItemID = function(i) return merchant[i] and merchant[i].itemID end
env.BuyMerchantItem = function() end
env.BuybackItem = function() end
env.GetBuybackItemInfo = function() return "Old Boots", 1, 75, 1 end
env.C_AuctionHouse.GetAuctionInfoByID = function(id) return auctions[id] end
env.GetInboxHeaderInfo = function(i)
    local m = inbox[i]
    return nil, nil, m.sender, m.subject, m.money, 0, m.days
end
env.GetInboxInvoiceInfo = function(i)
    local v = inbox[i].invoice
    if not v then return end
    return v.kind, v.name, v.buyer, v.bid or 0, v.buyout or 0, 0, 0, 0, 0, 0, v.count
end
env.GetInboxItemLink = function(i, a) local item = inbox[i].items and inbox[i].items[a] return item and "item:" .. item.id end
env.GetInboxItem = function(i, a) local item = inbox[i].items[a] return "Item", item.id, 1, item.count end
env.TakeInboxMoney = function() end
env.TakeInboxItem = function() end
env.AutoLootMailItem = function() end
env.SendMail = function() end
env.GetSendMailMoney = function() return 500 end
Load({ "NaowhForever_Market/Ledger.lua" }, env)

local M = t.M
local Ledger, S = M.Ledger, ns.MarketSettings

local function Data() return t.account.marketLedger and t.account.marketLedger["Player-1"] end
local function Rows() local d = Data() return d and #d.at or 0 end
local function Last(n)
    local d = Data()
    local i = #d.at - (n or 0)
    return { kind = d.kind[i], item = d.item[i], qty = d.qty[i], amount = d.amount[i], who = d.who[i], at = d.at[i] }
end
local function Gold(delta)
    t.money = t.money + delta
    t.Fire("PLAYER_MONEY")
end

t.now = 1000
ns.Apply()
Gold(10)
Check("with Record Gold off nothing is kept", t.account.marketLedger == nil)
Check("and nothing is hooked", #t.hooks == 0)

S.Set("enabled", true)
S.Set("ledger", true)
loggedIn = false
ns.Apply()
Check("before logging in it waits", t.account.marketLedger == nil)
loggedIn = true
ns.Apply()
local hooks = #t.hooks
Check("turning it on hooks the game's calls once", hooks == 10)
ns.Apply()
Check("and applying again hooks nothing more", #t.hooks == hooks)
Check("its gold is noted when it starts", Data().gold[1] == 1010 and Data().name == "Me" and Data().class == "MAGE")

t.Fire("MERCHANT_SHOW")
t.bags[0] = { World.Stack(2589, 5) }
t.vendor[2589] = 10
env.C_Container.UseContainerItem(0, 1)
Gold(50)
local row = Last()
Check("a stack sold to a vendor is a vendor sale with its merchant", row.kind == "vendor" and row.item == 2589
    and row.qty == 5 and row.amount == 50 and row.who == "Bob")
Check("and it is a sale", Ledger.View(row.kind, row.amount) == "sales")

env.C_Container.UseContainerItem(0, 1)
clock = clock + 11
Gold(5)
Check("a sale the gold never came for is forgotten, and gold at a merchant no call explains is a vendor sale",
    Last().kind == "vendor" and Last().item == 0 and Last().amount == 5)

Gold(-30)
Check("gold spent at a merchant no call explains is repairs", Last().kind == "repair" and Last().amount == -30)

merchant[1] = { price = 100, stackCount = 5, itemID = 159 }
env.BuyMerchantItem(1, 2)
Gold(-40)
row = Last()
Check("buying part of a vendor's stack costs its share", row.kind == "vendor" and row.item == 159 and row.qty == 2
    and row.amount == -40 and Ledger.View(row.kind, row.amount) == "purchases")

env.BuybackItem(1)
Gold(-75)
Check("a buyback is a vendor purchase", Last().kind == "vendor" and Last().item == 6000 and Last().amount == -75)

t.bags[1] = { World.Stack(3000, 2, { quality = 0 }), World.Stack(3001, 1, { quality = 1 }) }
t.vendor[3000], t.vendor[3001] = 7, 9
env.C_MerchantFrame.SellAllJunkItems()
Gold(14)
Check("Sell All Junk records the junk only", Last().item == 3000 and Last().amount == 14 and Last().qty == 2)

env.C_Container.UseContainerItem(0, 1)
env.C_Container.UseContainerItem(0, 1)
local before = Rows()
Gold(100)
Check("two sales paid at once are each recorded", Rows() == before + 2 and Last().amount == 50 and Last(1).amount == 50)

t.Fire("MERCHANT_CLOSED")
clock = clock + 1
Gold(-3)
Check("just after the merchant closes it still counts", Last().kind == "repair")
clock = clock + 5
Gold(-3)
Check("later, gold no window explains is Other", Last().kind == "other" and Last().who == "")
env.C_Container.UseContainerItem(0, 1)
Gold(50)
Check("using an item away from a merchant is not a sale", Last().kind == "other")

npcName = SECRET
t.Fire("MERCHANT_SHOW")
Gold(-3)
Check("a merchant whose name is secret is kept without it", Last().kind == "repair" and Last().who == "")
npcName = "Bob"
env.GetTitleText = function() return SECRET end
t.Fire("QUEST_COMPLETE")
Gold(7)
Check("and so is a quest whose title is secret", Last().kind == "quest" and Last().who == "")
env.GetTitleText = function() return "Wanted" end
t.Fire("QUEST_FINISHED")
t.Fire("MERCHANT_CLOSED")
clock = clock + 10
npcName = "Bob"

t.Fire("AUCTION_HOUSE_SHOW")
auctions[77] = { itemKey = { itemID = 4306 }, quantity = 1, buyoutAmount = 500 }
env.C_AuctionHouse.PlaceBid(77, 500)
Gold(-500)
Check("an auction bought is a purchase of its item", Last().kind == "auction" and Last().item == 4306
    and Last().amount == -500)
env.C_AuctionHouse.ConfirmCommoditiesPurchase(2770, 20)
Gold(-1234)
Check("a commodity bought takes the price it really cost", Last().item == 2770 and Last().qty == 20
    and Last().amount == -1234)
Gold(-60)
Check("other gold spent at the auction house is its fees", Last().kind == "deposit")
auctions[78] = { itemKey = { itemID = 9 }, quantity = 1, buyoutAmount = 500 }
before = Rows()
env.C_AuctionHouse.PlaceBid(78, 100)
Gold(-100)
Check("a bid under the buyout is not a purchase, nor a fee", Rows() == before)
auctions[79] = { itemKey = { itemID = 9 }, quantity = 1 }
env.C_AuctionHouse.PlaceBid(79, 80)
Gold(-80)
Check("nor is a bid on an auction with no buyout", Rows() == before)
env.C_AuctionHouse.PlaceBid(78, 500)
Gold(-500)
Check("paying the buyout is", Last().kind == "auction" and Last().item == 9 and Last().amount == -500)
t.Fire("AUCTION_HOUSE_CLOSED")
clock = clock + 5

t.Fire("MAIL_SHOW")
inbox[1] = { sender = "Auction House", subject = "Auction successful: Linen Cloth", money = 950, days = 29,
    invoice = { kind = "seller", name = "Linen Cloth", buyer = "Bidder", count = 3 } }
env.TakeInboxMoney(1)
env.TakeInboxMoney(1)
before = Rows()
Gold(950)
row = Last()
Check("an auction's gold from the mail is a sale, kept by name when the item is not cached", Rows() == before + 1
    and row.kind == "auction" and row.item == "Linen Cloth" and row.qty == 3 and row.who == "Bidder"
    and row.amount == 950)
Gold(950)
Check("taking it twice expects it once", Last().kind == "mail")
env.TakeInboxMoney(1)
Gold(950)
Check("once its gold came, the same mail again is a sale of its own", Last().kind == "auction"
    and Last().who == "Bidder")

inbox[2] = { sender = "Auction House", subject = "Auction successful: Item 2589", money = 40, days = 29 }
env.AutoLootMailItem(2)
Gold(40)
Check("a sale mail without an invoice is read from its subject", Last().kind == "auction" and Last().item == 2589
    and Last().qty == 1)

inbox[3] = { sender = "Auction House", subject = "Auction expired: Item 5", money = 0, days = 29,
    items = { { id = 5, count = 4 } } }
before = Rows()
env.TakeInboxItem(3, 1)
env.TakeInboxItem(3, 1)
t.Fire("MAIL_INBOX_UPDATE")
Check("an item still in the mail, as with full bags, is not recorded", Rows() == before)
t.Fire("MAIL_CLOSED")
t.Fire("MAIL_SHOW")
t.Fire("MAIL_INBOX_UPDATE")
Check("nor after the mailbox closes", Rows() == before)
env.TakeInboxItem(3, 1)
env.TakeInboxItem(3, 1)
inbox[3].items[1] = nil
t.Fire("MAIL_INBOX_UPDATE")
t.Fire("MAIL_INBOX_UPDATE")
Check("an expired auction's item that left the mail is Failed, once", Rows() == before + 1
    and Last().kind == "expired" and Last().item == 5 and Last().qty == 4 and Ledger.View("expired", 0) == "failed")
inbox[4] = { sender = "Auction House", subject = "Auction cancelled: Item 6", money = 0, days = 29,
    items = { { id = 6, count = 1 }, { id = 7, count = 2 } } }
env.AutoLootMailItem(4)
inbox[4].items = {}
t.Fire("MAIL_INBOX_UPDATE")
Check("Open All takes every attachment of a cancelled auction", Rows() == before + 3
    and (Last().item == 7 or Last(1).item == 7) and Last().kind == "cancelled" and Last(1).kind == "cancelled")

inbox[5] = { sender = "Auction House", subject = "Outbid on Item 9", money = 100, days = 29 }
before = Rows()
env.TakeInboxMoney(5)
Gold(100)
Check("an outbid refund is not income", Rows() == before)
inbox[6] = { sender = "Auction House", subject = "Auction won: Item 9", money = 0, days = 29,
    invoice = { kind = "buyer", name = "Item 9", buyer = "Seller", bid = 100, buyout = 500 },
    items = { { id = 9, count = 1 } } }
env.AutoLootMailItem(6)
inbox[6].items = {}
t.Fire("MAIL_INBOX_UPDATE")
Check("an auction won on a bid is a purchase at the bid, from its mail", Rows() == before + 1
    and Last().kind == "auction" and Last().item == 9 and Last().amount == -100 and Last().who == "Seller")
inbox[7] = { sender = "Auction House", subject = "Auction won: Item 9", money = 0, days = 29,
    invoice = { kind = "buyer", name = "Item 9", buyer = "Seller", bid = 500, buyout = 500 },
    items = { { id = 9, count = 1 } } }
env.AutoLootMailItem(7)
inbox[7].items = {}
t.Fire("MAIL_INBOX_UPDATE")
Check("one bought out was counted when bought, not again from its mail", Rows() == before + 1)
inbox[5] = { sender = "Alt", subject = "gold", money = 100, days = 3 }
env.AutoLootMailItem(5)
Gold(100)
Check("gold from a player is Mail with who sent it", Last().kind == "mail" and Last().who == "Alt")
Gold(-30)
Check("gold spent at the mailbox is postage", Last().kind == "postage")
env.SendMail("Alt", "gold", "")
Gold(-530)
Check("gold sent by mail is Mail to who it went to, and the rest postage", Last().kind == "postage"
    and Last().amount == -30 and Last(1).kind == "mail" and Last(1).amount == -500 and Last(1).who == "Alt")
t.Fire("MAIL_CLOSED")
clock = clock + 5

t.Fire("QUEST_COMPLETE")
Gold(200)
Check("a quest's gold names the quest", Last().kind == "quest" and Last().who == "Wanted")
t.Fire("QUEST_FINISHED")
clock = clock + 5

local data = Data()
local samples = #data.goldAt
t.now = t.now + 60
Gold(1)
Check("gold changes close together keep one sample", #data.goldAt == samples)
t.now = t.now + 3600
Gold(1)
t.now = t.now + 3600
Gold(1)
Check("further apart each is kept", #data.goldAt == samples + 2 and data.gold[#data.gold] == t.money)

local chars = Ledger.Characters({})
Check("the account's characters are listed", #chars == 1 and chars[1].guid == "Player-1")
local sum = Ledger.Summary(chars, 0)
Check("sales add up vendor and auction sales", sum.sales == 50 + 5 + 14 + 100 + 950 + 950 + 40)
Check("purchases add up what was bought", sum.purchases == 40 + 75 + 500 + 1234 + 500 + 100)
Check("the top sale is the item that earned most", sum.topSale == "Linen Cloth")
Check("the top purchase too", sum.topPurchase == 2770)
Check("earned and spent take in the rest", sum.earned == sum.sales + sum.otherIn
    and sum.spent == sum.purchases + sum.otherOut and sum.otherOut > 0 and sum.otherIn > 0)

local out = {}
Ledger.Collect(out, chars, "failed", 0)
Check("a view's rows are numbers", #out == 3 and type(out[1]) == "number")
local d, i = Ledger.Row(chars, out[1])
Check("and read back to their character and row", d == data and d.kind[i] == "cancelled")
Ledger.Collect(out, chars, "sales", 0, function(rd, ri) return rd.item[ri] == 2589 end)
Check("a match narrows a view", #out == 4)
Ledger.Collect(out, chars, "sales", t.now + 1)
Check("rows before the range are left out", #out == 0)

local series = Ledger.Gold(chars, 0, t.now, 3, {})
local alt = { goldAt = { t.now - 60 }, gold = { 99999 }, at = {} }
local both = { chars[1], { guid = "Player-2", data = alt } }
Check("the last day's change leaves out a character with no gold a day ago",
    Ledger.Change(both, t.now - 86400, t.now) == Ledger.Change(chars, t.now - 86400, t.now))
Check("and is nil when no one had gold then", Ledger.Change(chars, 0, t.now) == nil)
Check("before the first sample there is no gold", series[1] == false)
Check("the last point is the gold now", series[3] == t.money)

M.C.LEDGER_KEEP = 5
S.Set("ledger", false)
ns.Apply()
before = Rows()
Gold(5)
Check("turned off, nothing more is recorded", Rows() == before)
t.Fire("MERCHANT_SHOW")
env.C_Container.UseContainerItem(0, 1)
local whoCount = #Data().at
local kept = { Data().who[whoCount - 1], Data().who[whoCount] }
Data().who[whoCount - 2] = nil
S.Set("ledger", true)
ns.Apply()
Check("a name saved as nil in the middle is filled, and trimming keeps the names on their rows",
    #Data().who == 5 and Data().who[3] == "" and Data().who[4] == kept[1] and Data().who[5] == kept[2])
Check("gold samples are kept to the same limit", #Data().goldAt <= 5 and #Data().gold == #Data().goldAt)
Check("turned back on, only the newest rows are kept", Rows() == 5 and Data().kind[1] == "postage"
    and Data().amount[5] == 1)
Gold(50)
Check("and a call made while it was off is not counted", Last().kind ~= "vendor" or Last().item ~= 2589)

print("market ledger: " .. checks .. " checks passed")
