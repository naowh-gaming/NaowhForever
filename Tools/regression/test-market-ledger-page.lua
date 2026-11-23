-- Run with Lua 5.1 from the repository root: The Market's Ledger page on the Ledger's real rules: Summary's gold line and
-- cards, each list with its rows, sorting, a name filter and its foot line, two characters, and the narrow dock.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local DAY = 86400
local NOW = 400 * DAY
local NAMES = { [2589] = "Linen Cloth", [4306] = "Silk Cloth" }
local WHITE = { r = 1, g = 1, b = 1 }

local t = World.Setup()
local env, ns, M = t.env, t.ns, t.M
t.now = NOW

local width = 1100
local function Frame(kind, parent)
    local f = { kind = kind, parent = parent, shown = true, scripts = {} }
    return setmetatable(f, { __index = function(_, k)
        if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, on) self.shown = on and true or false end end
        if k == "SetText" then return function(self, text) self.text = text end end
        if k == "GetText" then return function(self) return self.text end end
        if k == "SetScript" or k == "HookScript" then return function(self, name, fn) self.scripts[name] = fn end end
        if k == "GetScript" then return function(self, name) return self.scripts[name] end end
        if k == "GetWidth" then return function() return width end end
        if k == "GetHeight" then return function() return 240 end end
        if k == "GetLeft" then return function() return 0 end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        if k == "GetVerticalScroll" or k == "GetStringWidth" then return function() return 0 end end
        if k == "CreateTexture" or k == "CreateLine" then return function(self) return Frame("Texture", self) end end
        if type(k) == "string" and k:find("^%u") then return function() end end
    end })
end

local events = env.CreateFrame
env.CreateFrame = function(kind, _, parent)
    if not parent then return events() end
    return Frame(kind, parent)
end
env.GameTooltip = Frame("GameTooltip")
env.strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
env.date = function(format, when) return format .. "@" .. when end
env.BreakUpLargeNumbers = tostring
env.GetCursorPosition = function() return 0, 0 end
env.GetTime = function() return 0 end
env.IsLoggedIn = function() return false end
env.Enum.ItemQuality = { Poor = 0 }
env.C_MerchantFrame = {}

local tabs, dropdowns, fonts, boxes = {}, {}, {}, {}
ns.THEME = { fg = WHITE, muted = WHITE, accent = WHITE, line = WHITE, accentSoft = WHITE }
ns.Lower = string.lower
ns.Font = function(parent)
    local f = Frame("FontString", parent)
    fonts[#fonts + 1] = f
    return f
end
ns.Solid = function(parent) return Frame("Texture", parent) end
ns.Border = function() end
ns.Color = function(_, text) return text end
ns.UI.SlimScroll = function(parent) return Frame("ScrollFrame", parent) end
ns.UI.BuildDropdownControl = function(parent, _, _, values, order, get, set)
    local d = Frame("Button", parent)
    d._values, d._order, d._get, d._set = values, order, get, set
    d._refreshLabel = function() d.text = values[get()] end
    dropdowns[#dropdowns + 1] = d
    return d
end
ns.Shared.Items = { Name = function(id) return NAMES[id] or ("Item " .. id) end, OnLoaded = function() end,
    QualityHex = function() return "|cffffffff" end }
ns.Shared.Ago = function(at) return (NOW - at) .. "s ago" end
ns.Shared.Parts = {
    Coins = function(copper) return copper .. "c" end,
    Tabs = function(parent, _, items, onPick)
        local bar = Frame("Frame", parent)
        bar.items, bar.onPick = items, onPick
        tabs[#tabs + 1] = bar
        return bar
    end,
    PaintTabs = function(bar, key) bar.painted = key end,
    SearchBox = function(parent, _, onSearch)
        local box = Frame("EditBox", parent)
        box.onSearch = onSearch
        boxes[#boxes + 1] = box
        return box
    end,
    RowBands = function(row) row.stripe, row.hover = Frame("Texture", row), Frame("Texture", row) end,
    ItemIcon = function(parent)
        local icon = Frame("Frame", parent)
        icon.texture = Frame("Texture", icon)
        return icon
    end,
}
M.Style = setmetatable({ RED_RGB = WHITE, HAVE_RGB = WHITE, WARN_RGB = WHITE, GOLD_RGB = WHITE, BORDER_RGB = WHITE,
    TEXT_SIZE = 12, SMALL_SIZE = 11, GAP = 6, PANEL_FILL = 0.025, SCROLLBAR = 16, SEARCH_H = 24, TAB_H = 26,
    ROUND = "" }, { __index = function() return 1 end })
M.Pages = {}
Load({ "NaowhForever_Market/Ledger.lua", "NaowhForever_Market/View/Chart.lua", "NaowhForever_Market/View/Columns.lua",
    "NaowhForever_Market/UI/Ledger.lua" }, env)

local function Character(guid, name, rows, gold)
    local data = { name = name, class = "MAGE", realm = "Realm", at = {}, kind = {}, item = {}, qty = {}, amount = {},
        who = {}, goldAt = {}, gold = {} }
    for i, r in ipairs(rows) do
        data.at[i], data.kind[i], data.item[i], data.qty[i], data.amount[i], data.who[i] =
            r[1], r[2], r[3], r[4], r[5], r[6]
    end
    for i, g in ipairs(gold) do data.goldAt[i], data.gold[i] = g[1], g[2] end
    t.account.marketLedger = t.account.marketLedger or {}
    t.account.marketLedger[guid] = data
end

Character("Player-1", "Me", {
    { NOW - 40 * DAY, "vendor", 2589, 5, 500, "Bob" },
    { NOW - 2 * DAY, "auction", 4306, 2, 3000, "Bidder" },
    { NOW - DAY, "vendor", 2589, 1, 100, "Bob" },
    { NOW - DAY, "auction", 2589, 10, -800, "" },
    { NOW - 3600, "repair", 0, 0, -250, "Bob" },
    { NOW - 600, "quest", 0, 0, 900, "Wanted" },
    { NOW - 60, "expired", 4306, 1, 0, "" },
}, { { NOW - 3 * DAY, 1000 }, { NOW - 2 * DAY, 4000 }, { NOW - 3600, 3900 } })
Character("Player-2", "Alt", {
    { NOW - DAY, "auction", 4306, 1, 2000, "Someone" },
}, { { NOW - 5 * DAY, 500 }, { NOW - 3600, 2500 } })

local S = ns.MarketSettings
local Page = M.Pages.ledger
local parent = Frame("Frame")
Page.Build(parent)
Page.Show()
local views, range, character = tabs[1], dropdowns[1], dropdowns[2]
local search

local function Shown(text)
    for _, f in ipairs(fonts) do
        if f.text == text then return true end
    end
    return false
end

Check("it opens on Summary over the last 30 days", views.painted == "summary" and range.text == "Last 30 Days")
Check("every character is offered, all of them first", #character._order == 3 and character._order[1] == ""
    and character._values["Player-2"] == "Alt" and character.text == "All Characters")
Check("Sales adds up both characters' sales in the range", Shown("5100c"))
Check("Purchases, what was bought", Shown("800c"))
Check("Other, what was earned and spent elsewhere", Shown("900c") and Shown("250c"))
Check("Profit, all earned less all spent", Shown("4950c"))
Check("Gold, both characters' gold now", Shown("6400c"))
Check("the top sale is the item that earned most", Shown("|cffffffffSilk Cloth|r"))

character._set("Player-1")
Page.Draw()
Check("one character's summary is its own", Shown("3100c") and Shown("3900c"))
character._set("")
range._set("all")

views.onPick("sales")
Check("Sales lists its rows", views.painted == "sales" and Shown("|cffffffffLinen Cloth|r") and Shown("Bidder"))
Check("with what they came to", Shown("9 items sold for 5600c"))
for _, f in ipairs(boxes) do search = search or f end
search.onSearch("linen")
Check("a name filter narrows the list", Shown("6 items sold for 600c"))
search.onSearch("bidder")
Check("and finds who bought it too", Shown("2 items sold for 3000c"))
search.onSearch("")

local kind = dropdowns[3]
Check("Type starts on All Types and offers only the types Sales has", kind.text == "All Types"
    and table.concat(kind._order, ",") == ",auction,vendor")
kind._set("auction")
Check("Auction narrows Sales to the auction house", Shown("3 items sold for 5000c") and kind.text == "Auction")
kind._set("vendor")
Check("Vendor, to vendors", Shown("6 items sold for 600c"))
search.onSearch("bidder")
Check("the type and the name filter work together", Shown("0 items sold for 0c"))
search.onSearch("")
views.onPick("other")
Check("each tab keeps its own type, Other still all of them", kind.text == "All Types"
    and table.concat(kind._order, ",") == ",quest,repair" and Shown("Earned 900c, spent 250c"))
kind._set("repair")
Check("Repair alone", Shown("Earned 0c, spent 250c"))
views.onPick("sales")
Check("back on Sales, Vendor is still picked", kind.text == "Vendor" and Shown("6 items sold for 600c"))
search.onSearch("nothing")
Check("a picked type stays offered when nothing shown has it", Shown("0 items sold for 0c")
    and table.concat(kind._order, ",") == ",vendor" and kind.text == "Vendor"
    and Shown("None of this type here: pick All Types to see the rest."))
search.onSearch("")
kind._set("")
Check("All Types again", Shown("9 items sold for 5600c"))
views.onPick("other")
kind._set("")

views.onPick("purchases")
Check("Purchases", Shown("10 items bought for 800c"))
views.onPick("other")
Check("Other, with repairs and quests", Shown("Earned 900c, spent 250c") and Shown("Repair") and Shown("Wanted"))
views.onPick("failed")
Check("Failed", Shown("1 items came back"))

views.onPick("sales")
for _, key in ipairs({ "when", "total", "each", "qty", "type", "who", "character", "item" }) do
    S.Set("sortLedger", key .. ":up")
    Page.Draw()
    S.Set("sortLedger", key .. ":down")
    Page.Draw()
end
Check("every column sorts both ways", views.painted == "sales")

parent.scripts.OnSizeChanged = nil
S.Set("ledger", false)
Page.Draw()
Check("off, it says so and keeps what it has", Shown(
    "The Ledger is off: turn it on in The Market's settings to record what you earn and spend.")
    and Shown("9 items sold for 5600c"))

range._set("1d")
views.onPick("summary")
Check("a day's range", range.text == "Last Day")
Page.Hide()
Check("hidden, it stops listening for new rows", M.Ledger.onChange == nil)

print("market ledger page: " .. checks .. " checks passed")
