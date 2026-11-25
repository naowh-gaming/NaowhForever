-- Run with Lua 5.1 from the repository root: Collect Mail, the inbox button that takes all mail or only sold, bought or expired auctions.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local t = World.Setup()
local ns, env = t.ns, t.env
local S = ns.MarketSettings
local inbox, taken, printed = {}, {}, {}
local pending, freeSlots, menu = false, 10, nil

env.ATTACHMENTS_MAX_RECEIVE = 2
env.AUCTION_SOLD_MAIL_SUBJECT = "Auction successful: %s"
env.AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
env.AUCTION_REMOVED_MAIL_SUBJECT = "Auction cancelled: %s"
env.AUCTION_OUTBID_MAIL_SUBJECT = "Outbid on %s"
env.GetInboxNumItems = function() return #inbox end
env.GetInboxHeaderInfo = function(i)
    local m = inbox[i]
    local count = 0
    for a = 1, env.ATTACHMENTS_MAX_RECEIVE do if m.items[a] then count = count + 1 end end
    return nil, nil, m.sender, m.subject, m.money, m.cod or 0, 30, count, nil, nil, nil, nil, m.gm
end
env.GetInboxInvoiceInfo = function(i) return inbox[i].invoice end
env.GetInboxItem = function(i, a) local id = inbox[i].items[a] if id then return "Item", id, 1, 1 end end
local function Empty(i)
    local m = inbox[i]
    if m.money == 0 and not next(m.items) then table.remove(inbox, i) end
end
env.TakeInboxMoney = function(i)
    taken[#taken + 1] = inbox[i].subject .. " gold"
    inbox[i].money = 0
    Empty(i)
end
env.TakeInboxItem = function(i, a)
    taken[#taken + 1] = inbox[i].subject .. " item " .. inbox[i].items[a]
    inbox[i].items[a] = nil
    Empty(i)
end
env.C_Mail = { IsCommandPending = function() return pending end }
env.C_Container.CalculateTotalNumberOfFreeBagSlots = function() return freeSlots end
env.InboxFrame = {}
env.MailFrame = { IsShown = function() return false end }

local frames, ticker = {}, nil
local make = env.CreateFrame
env.CreateFrame = function(...)
    local f = make(...)
    f.shown = true
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    local set = f.SetScript
    function f:SetScript(name, fn)
        if name == "OnUpdate" then ticker = self end
        set(self, name, fn)
    end
    frames[#frames + 1] = f
    return f
end
local button
function ns.Button(parent, text, _, _, onClick)
    button = { parent = parent, onClick = onClick, label = { text = text } }
    function button.label:SetText(s) self.text = s end
    function button:SetPoint() end
    function button:SetShown(v) self.shown = v end
    function button:SetScript(name, fn) self[name] = fn end
    return button
end
function ns.Tooltip() end
function ns.Print(msg) printed[#printed + 1] = msg end
function ns.ContextMenu(_, gen) menu = gen end
ns.L = function(s) return s end

Load({ "NaowhForever_Market/Ledger.lua", "NaowhForever_Market/UI/Collect.lua" }, env)

local function Fill()
    env.wipe(inbox)
    env.wipe(taken)
    inbox[1] = { subject = "Auction successful: Linen", money = 500, items = {}, invoice = "seller" }
    inbox[2] = { subject = "Auction expired: Ore", money = 0, items = { 2770 } }
    inbox[3] = { subject = "Hello", sender = "Alt", money = 100, items = { 2589, 2592 } }
    inbox[4] = { subject = "Auction won: Sword", money = 0, items = { 2488 }, invoice = "buyer" }
    inbox[5] = { subject = "Auction cancelled: Bolt", money = 0, items = { 2996 } }
    inbox[6] = { subject = "Pay me", money = 0, items = { 765 }, cod = 50 }
    inbox[7] = { subject = "Restored", money = 0, items = { 118 }, gm = true }
end

local function Menu()
    local rows = {}
    local root = {}
    function root:CreateTitle() end
    function root:CreateButton(text, fn) rows[#rows + 1] = { text = text, fn = fn } end
    menu(nil, root)
    return rows
end

local function Ticker() return ticker end

local function Run(limit)
    for _ = 1, limit or 50 do
        if not Ticker().shown then return end
        Ticker().onEvent(Ticker(), 1)
    end
end

ns.Apply()
Check("off, its default, no frame is made and no event is listened to", not S.Get("mailCollect")
    and not ticker and not t.Listening("MAIL_SHOW"))

S.Set("enabled", true)
S.Set("mailCollect", true)
ns.Apply()
t.Fire("MAIL_SHOW")
Check("on, opening the mailbox puts a Collect button on the inbox", button and button.parent == env.InboxFrame
    and button.label.text == "Collect" and Ticker() and not Ticker().shown)
local made = #frames
t.Fire("MAIL_SHOW")
ns.Apply()
Check("only once", #frames == made)

Fill()
button.onClick()
local rows = Menu()
Check("the menu counts what each would open, leaving C.O.D. and GM mail out", #rows == 4
    and rows[1].text == "All Mail (5)" and rows[2].text == "Sold Auctions (1)"
    and rows[3].text == "Bought Auctions (1)" and rows[4].text == "Expired and Cancelled (2)")

rows[2].fn()
Check("Sold starts collecting and the button reads Stop", Ticker().shown and button.label.text == "Stop")
Run()
Check("Sold takes only the sold auction's gold", #taken == 1 and taken[1] == "Auction successful: Linen gold"
    and not Ticker().shown and button.label.text == "Collect")

rows = Menu()
rows[4].fn()
Run()
Check("Expired and Cancelled takes both, and nothing else", #taken == 3
    and taken[2] == "Auction expired: Ore item 2770" and taken[3] == "Auction cancelled: Bolt item 2996")

rows = Menu()
rows[3].fn()
Run()
Check("Bought takes the won auction", #taken == 4 and taken[4] == "Auction won: Sword item 2488")

rows = Menu()
rows[1].fn()
Run()
Check("All Mail takes the rest, gold first, and leaves C.O.D. and GM mail", #taken == 7
    and taken[5] == "Hello gold" and taken[6] == "Hello item 2589" and taken[7] == "Hello item 2592"
    and #inbox == 2 and not Ticker().shown)

Fill()
rows = Menu()
rows[1].fn()
pending = true
Run(3)
Check("nothing is taken while a mail command is pending", #taken == 0)
pending = false
Ticker().onEvent(Ticker(), 1)
Check("and it carries on after", #taken == 1)
button.onClick()
Check("clicking Stop stops it", not Ticker().shown and button.label.text == "Collect")

Fill()
rows = Menu()
rows[1].fn()
t.Fire("MAIL_FAILED", 2770)
Run()
Check("an item that failed is skipped", #inbox == 3 and inbox[1].items[1] == 2770)

Fill()
freeSlots = 0
rows = Menu()
rows[1].fn()
Run()
Check("with full bags gold is still taken, and items stay", #taken == 2 and taken[2] == "Hello gold"
    and printed[#printed] == "Your bags are full, so some items stayed in the mail.")
freeSlots = 10

Fill()
rows = Menu()
rows[1].fn()
t.Fire("MAIL_CLOSED")
Check("closing the mailbox stops it", not Ticker().shown)
rows[1].fn()
button.OnHide()
Check("switching to the Send tab hides the button and stops it", not Ticker().shown)
rows[1].fn()
t.Fire("MAIL_FAILED")
Check("a failure with no item stops it", not Ticker().shown)

S.Set("mailCollect", false)
ns.Apply()
Check("turned off, the button hides and no event is listened to", button.shown == false
    and not t.Listening("MAIL_SHOW") and not t.Listening("MAIL_CLOSED"))

local source = io.open("NaowhForever_Market/UI/Collect.lua", "rb"):read("*a")
Check("it never sets or hooks a script on Blizzard's frames", not source:find("HookScript", 1, true)
    and not source:find("InboxFrame:SetScript", 1, true))

print("market collect: " .. checks .. " checks passed")
