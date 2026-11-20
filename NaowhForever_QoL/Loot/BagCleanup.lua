-- BagCleanup.lua: Bag Clean-up, the everyday Bags & Junk settings on one card.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Group = ns.Shared.Settings.Group

local FREE_BELOW_RANGE = { 0, 30, 1 }
local MAX_VALUE = {
    { [0] = "Any Value", [1000] = "10 Silver", [5000] = "50 Silver", [10000] = "1 Gold", [50000] = "5 Gold" },
    { 0, 1000, 5000, 10000, 50000 },
}

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "bagCleanup", name = "Bag Clean-up", order = 58, open = true,
    help = "The everyday bag settings in one place; the cards below have every detail.",
    rows = {
        Group("At Vendors and the Bank"),
        { key = "sellJunk", label = "Auto Sell Junk", toggle = true,
          help = "Sells grey items when you open a vendor." },
        { key = "scrapMarker", label = "Mark Junk to Sell", toggle = true,
          help = "Mark items as junk, and they sell at the next vendor." },
        { key = "bankMarker", label = "Mark Items for the Bank", toggle = true,
          help = "Mark items to deposit them when you open your bank." },
        Group("When Bags Fill Up"),
        { key = "bagSpace", label = "Cheapest Items Row", toggle = true,
          help = "A row of the cheapest items in your bags, to delete or sell." },
        { key = "bagSpaceFreeBelow", label = "Only With Free Slots Below", slider = FREE_BELOW_RANGE, needs = "bagSpace",
          help = "Shows the row only once your bags are this full. 0 shows it all the time." },
        { key = "destroyCheapest", label = "Offer to Destroy When Full", toggle = true,
          help = "When loot does not fit, offers the cheapest safe item to destroy." },
        { key = "bagCleanupMaxValue", label = "Keep Items Worth More Than", choice = MAX_VALUE,
          help = "Items worth more than this are never offered to delete." },
    },
})
