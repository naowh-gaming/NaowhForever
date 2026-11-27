-- Run with Lua 5.1 from the repository root: Up Next on The Market's Sell page. On the narrow panel its rows are one
-- line, the price each moving to the row's tooltip; given the width, Up Next is a column of its own beside the form, its
-- rows two lines again, and narrowing the page puts it back under the form.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local Page = dofile("Tools/regression/market_sell_page.lua")
local Stack, COMMODITY = Page.Stack, Page.COMMODITY

local ORE, CLOTH = 2770, 2589
local HINT = "Right-click to favourite or hide it."

local t = Page.Setup({ bags = { [0] = { Stack(ORE, 20), Stack(CLOTH, 10) } },
    status = { [ORE] = COMMODITY, [CLOTH] = COMMODITY }, scan = { [ORE] = 500, [CLOTH] = 100 },
    vendor = { [ORE] = 5, [CLOTH] = 3 } })

local function Resize(width)
    t.pageFrame.width = width
    t.pageFrame.scripts.OnSizeChanged(t.pageFrame)
end

local function Hover(row)
    t.tips = {}
    row.scripts.OnEnter(row)
    return t.tips
end

t.page.Show()
local rows = t.Rows()
Check("on the narrow panel, Up Next's rows are one line", #rows == 2 and rows[1].height == 22
    and not rows[1].sub.shown and rows[1].icon.height == 16)
local tips = Hover(rows[1])
Check("and a row's price each moves to its tooltip, over the hint", rows[1].sub.text ~= nil
    and tips[1] == rows[1].sub.text and tips[2] == HINT)
Check("the game's item comparison waits for Shift", t.env.GameTooltip.suppressAutomaticCompareItem == true)

Resize(648)
rows = t.Rows()
Check("given the width, Up Next is a column with two-line rows", #rows == 2 and rows[1].height == 34
    and rows[1].sub.shown and rows[1].icon.height == 24)
tips = Hover(rows[1])
Check("and its tooltip is back to the hint alone", #tips == 1 and tips[1] == HINT)

Resize(360)
rows = t.Rows()
Check("narrowed again, Up Next goes back under the form", rows[1].height == 22 and not rows[1].sub.shown)

print("market sell columns: " .. checks .. " checks passed")
