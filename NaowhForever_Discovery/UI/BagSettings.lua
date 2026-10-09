-- BagSettings.lua: Discovery's Sleeping Bag settings page (Discovery/Sleeping Bag), declared as cards.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local S = Discovery.Settings
local Library = Discovery.Library
local Bag = Discovery.Bag
local Style = Discovery.Style
local Settings = ns.Shared.Settings

local SCALE = { 50, 150, 5 }
local PIN_SIZE = { 12, 32, 1 }
local PERCENT_STEP = 5
local PERCENT_SCALE = 0.01
local TEXT_OFF = "Turn on Discovery"
local TEXT_HAVE_BAG = "You have the Cozy Sleeping Bag"
local TEXT_STEP_OF = "Step %d of %d"
local TEXT_HEADLINE = "Sleeping Bag: step %d of %d"
local TEXT_REST = "Rest in it for a bonus to experience."
local TEXT_STARTS = "It starts at level %d."
local TEXT_NEXT = "Next: %s, %s."

local function On() return S.Get("enabled") == true end

local function BagSummary()
    local _, at = Bag.Current()
    if not at then return TEXT_HAVE_BAG end
    return TEXT_STEP_OF:format(at, #Bag.Steps())
end

local function BagHeadline()
    local _, at = Bag.Current()
    if not at then return TEXT_HAVE_BAG end
    return TEXT_HEADLINE:format(at, #Bag.Steps())
end

local function BagDetail()
    local step = Bag.Current()
    if not step then return TEXT_REST end
    if not Bag.Level() then return TEXT_STARTS:format(ns.SleepingBag.level) end
    return TEXT_NEXT:format(step.object, Library.ZoneName(step.map))
end

local function OpenBag()
    ns.OpenDiscoveryWindow("bag")
end

local bags = Settings.Page("Discovery/Sleeping Bag", S)

bags:Window({
    text = "Open Sleeping Bag",
    open = OpenBag,
    headline = BagHeadline,
    detail = BagDetail,
})

bags:Card({
    id = "bagtracker", name = "Tracker", order = 10, switch = "bagTracker",
    help = "Shows each Sleeping Bag step, with how to reach the next one and a waypoint.",
    summary = BagSummary,
    rows = {
        { key = "bagTrackerScale", label = "Scale", slider = SCALE, unit = "%", scale = PERCENT_SCALE, needs = On,
          why = TEXT_OFF, help = "How big the tracker is." },
        { key = "bagTrackerAlpha", label = "Opacity", slider = { Style.OPACITY_MIN, 100, PERCENT_STEP }, unit = "%",
          scale = PERCENT_SCALE, needs = On, why = TEXT_OFF, help = "How solid the tracker is, in percent." },
    },
})

bags:Card({
    id = "bagmappins", name = "Map Pins", order = 20, switch = "bagMapPins",
    help = "Shows the Sleeping Bag steps still to do on your map; click one for a waypoint.",
    rows = {
        { key = "bagMapPinSize", label = "Pin Size", slider = PIN_SIZE, needs = On, why = TEXT_OFF,
          help = "How big the pins are on the map." },
    },
})
