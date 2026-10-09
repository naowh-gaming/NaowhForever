-- QuestsSettings.lua: Completo's Quests settings page (Completo/Quests), declared as cards.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Settings = ns.Shared.Settings
local Style = Completo.Style

local PAGE = "Completo/Quests"
local PIN_SIZE = { 12, 32, 1 }
local WINDOW_SCALE = { 50, 150, 5 }
local PERCENT_STEP = 5
local PERCENT_SCALE = 0.01
local TEXT_OFF = "Turn on Completo"
local TEXT_PROGRESS = "%d of %d zone quests done"
local TEXT_ZONE = "%s: %d of %d."
local TEXT_EVERY_QUEST = "Every quest of every zone, and where you are in each chain."
local TEXT_CHAINS = "Quest chains"
local TEXT_QUESTS = "Quests"
local TEXT_LOW_TOO = " you can pick up, low level ones too"
local TEXT_STILL_XP = " that still give experience"

local page = Settings.Page(PAGE, S)

local function On() return S.Get("enabled") == true end

local function Headline()
    Q.Refresh()
    return TEXT_PROGRESS:format(Q.Progress())
end

local function Detail()
    local zone = Q.CurrentZone()
    if not zone then return TEXT_EVERY_QUEST end
    local n, total = Q.ZoneProgress(zone)
    return TEXT_ZONE:format(zone.name, n, total)
end

local function OpenQuests()
    ns.OpenCompletoWindow("quests")
end

local function MapSummary(store)
    local what = store.Get("mapChainsOnly") and TEXT_CHAINS or TEXT_QUESTS
    return what .. (store.Get("mapGrey") and TEXT_LOW_TOO or TEXT_STILL_XP)
end

page:Window({
    text = "Open Quests",
    open = OpenQuests,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "quests", name = "Quests", order = 10,
    help = "What a zone's page in the Completo window lists.",
    rows = {
        { key = "hideDone", label = "Hide Done", toggle = true,
          help = "Leave out the quests and chains you have finished." },
    },
})

page:Card({
    id = "mapPins", name = "Map Pins", order = 20, switch = "mapPins",
    help = "A yellow ! on the world map at every quest giver with a quest you can pick up that still gives "
        .. "experience. Hover it for the quests; click it for a waypoint.",
    summary = MapSummary,
    rows = {
        { key = "mapGrey", label = "Low Level Quests", toggle = true, needs = On, why = TEXT_OFF,
          help = "Also a grey ! for quests you can still pick up that no longer give experience." },
        { key = "mapChainsOnly", label = "Chains Only", toggle = true, needs = On, why = TEXT_OFF,
          help = "Only quest chains: the first quest of each one, and the next step of those you are on." },
        { key = "mapPinSize", label = "Pin Size", slider = PIN_SIZE, needs = On, why = TEXT_OFF,
          help = "How big the pins are on the map." },
    },
})

page:Card({
    id = "keys", name = "Key Binding", order = 30,
    help = "The key that opens the Completo window.",
    rows = {
        { label = "Open Completo", binding = "NAOWHFOREVER_COMPLETO",
          help = "Press it to open or close Completo. Shift-L unless something else had it." },
    },
})

page:Card({
    id = "window", name = "Window", order = 90,
    help = "Completo's own window. Drag its bottom right corner to size it.",
    rows = {
        { key = "windowScale", label = "Window Scale", slider = WINDOW_SCALE, unit = "%", scale = PERCENT_SCALE,
          help = "How big the window and everything in it is. Drag its corner to make it bigger instead." },
        { key = "windowAlpha", label = "Window Opacity", slider = { Style.OPACITY_MIN, 100, PERCENT_STEP },
          unit = "%", scale = PERCENT_SCALE, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
