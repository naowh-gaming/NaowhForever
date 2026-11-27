-- QuestsSettings.lua: the Quest List's quest cards (Discovery/Quest List), and its quest pins' rows on QoL > Map & Pins.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Style = Completo.Style
local Settings = ns.Shared.Settings

local PAGE = "Discovery/Quest List"
local PIN_SIZE = ns.Shared.Style.PIN_SIZE_RANGE
local ORDER_QUESTS = 10
local ORDER_TOOLTIPS = 11
local ORDER_NAMEPLATES = 12
local ORDER_PARTY = 13
local TEXT_OFF = ns.L("Turn on Discovery")
local TEXT_PINS_OFF = ns.L("Turn on Quest Givers")
local TEXT_DUNGEON_OFF = ns.L("Turn on Color Dungeon Quests")
local TEXT_OBJECTIVES_OFF = ns.L("Turn on Quest Objectives")
local TEXT_SHOWN_OFF = ns.L("Turn on Quest Givers or Quest Objectives")
local TEXT_MINIMAP_OFF = ns.L("Turn on Quests on Minimap")
local TEXT_NONE_HIDDEN = ns.L("No quests are hidden")
local TEXT_PROGRESS = ns.L("%d of %d zone quests done")
local TEXT_ZONE = ns.L("%s: %d of %d.")
local TEXT_EVERY_QUEST = ns.L("Every quest of every zone, and where you are in each chain.")

local page = Settings.Page(PAGE, S)

local function On() return S.Get("enabled") == true end
local function PinsOn() return On() and S.Get("mapPins") == true end
local function DungeonOn() return PinsOn() and S.Get("mapDungeon") == true end
local function ObjectivesOn() return On() and S.Get("mapObjectives") == true end
local function AnyShown() return On() and (S.Get("mapPins") == true or S.Get("mapObjectives") == true) end
local function MinimapOn() return AnyShown() and S.Get("minimapQuests") == true end
local function AnyHidden() return On() and Q.HiddenCount() > 0 end

local function ShowHidden()
    Q.ShowHidden()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function DungeonColor()
    local c = S.Get("mapDungeonColor") or Style.DUNGEON_RGB
    return c.r, c.g, c.b, 1
end

local function SetDungeonColor(r, g, b)
    S.Set("mapDungeonColor", { r = r, g = g, b = b })
end

local function Headline()
    Q.Update()
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

page:Window({
    text = "Open Quest List",
    open = OpenQuests,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "quests", name = "Quests", order = ORDER_QUESTS,
    help = "What a zone's page in the Quest List window lists.",
    rows = {
        { key = "hideDone", label = "Hide Done", toggle = true,
          help = "Leave out the quests and chains you have finished." },
        { key = "history", label = "Keep Quest History", toggle = true,
          help = "Keeps a dated record of the quests you take, hand in and drop, in its own tab." },
    },
})

page:Card({
    id = "unitTips", name = "Quest Tooltips", order = ORDER_TOOLTIPS, switch = "unitTips",
    help = "Creature, object and item tooltips name the quests in your log they are for, with your progress.",
})

page:Card({
    id = "nameplateQuests", name = "Quest Nameplates", order = ORDER_NAMEPLATES, switch = "nameplateQuests",
    help = "A quest icon over the nameplate of each creature your quests still need.",
})

page:Card({
    id = "partyProgress", name = "Share Quest Progress", order = ORDER_PARTY, switch = "partyProgress",
    help = "Swaps quest progress with your party's Naowh Forever, shown on quest pins and tooltips.",
})

table.insert(ns.Shared.MapPins, {
    title = ns.L("Quests"), store = S, switch = "mapPins",
    rows = {
        { key = "mapPins", label = "Quest Givers", toggle = true, store = S, always = true, needs = On, why = TEXT_OFF,
          help = "A yellow ! on the world map at every quest giver with a quest you can pick up that still gives "
              .. "experience. Hover it for the quests; click it for a waypoint." },
        { key = "mapGrey", label = "Low Level Quests", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF,
          help = "Also a grey ! for quests you can still pick up that no longer give experience." },
        { key = "mapChainsOnly", label = "Chains Only", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF,
          help = "Only quest chains: the first quest of each one, and the next step of those you are on." },
        { key = "mapPvP", label = "PvP Quests", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF, help = "Quest givers with a Warsong Gulch, Arathi Basin or Alterac Valley quest." },
        { key = "mapDungeon", label = "Color Dungeon Quests", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF, help = "A ! in its own color for quest givers with a dungeon or raid quest." },
        { key = "mapDungeonColor", label = "Dungeon Quest Color", colour = true, store = S, always = true,
          needs = DungeonOn, why = TEXT_DUNGEON_OFF, get = DungeonColor, set = SetDungeonColor,
          help = "The color of the ! for dungeon and raid quests." },
        { key = "mapPinSize", label = "Quest Pin Size", slider = PIN_SIZE, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF, help = "How big the quest pins are on the map." },
        { key = "mapObjectives", label = "Quest Objectives", toggle = true, store = S, always = true, needs = On,
          why = TEXT_OFF, help = "Marks where your quests' objectives are, and a ? where a finished quest is handed in." },
        { key = "mapObjectivesTracked", label = "Tracked Quests Only", toggle = true, store = S, always = true,
          needs = ObjectivesOn, why = TEXT_OBJECTIVES_OFF, help = "Only the objectives of the quests you track." },
        { key = "mapObjectivePaths", label = "Patrol Paths", toggle = true, store = S, always = true,
          needs = ObjectivesOn, why = TEXT_OBJECTIVES_OFF, help = "Small marks along the way a wandering quest creature walks." },
        { key = "mapObjectivePinSize", label = "Objective Pin Size", slider = PIN_SIZE, store = S, always = true,
          needs = ObjectivesOn, why = TEXT_OBJECTIVES_OFF, help = "How big the objective pins are on the map." },
        { key = "minimapQuests", label = "Quests on Minimap", toggle = true, store = S, always = true,
          needs = AnyShown, why = TEXT_SHOWN_OFF, help = "Shows the quest givers and objectives near you on the minimap too." },
        { key = "minimapQuestSize", label = "Minimap Quest Pin Size", slider = PIN_SIZE, store = S, always = true,
          needs = MinimapOn, why = TEXT_MINIMAP_OFF, help = "How big the quest pins are on the minimap." },
        { label = "Hidden Quests", buttonText = "Show All", button = ShowHidden, store = S, always = true,
          needs = AnyHidden, why = TEXT_NONE_HIDDEN, help = "Puts the quests you hid with a right-click back on the map." },
    },
})
