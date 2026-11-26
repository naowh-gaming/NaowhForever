-- SettingsPage.lua: the Dungeon Journal's settings page, declared as cards, and its entrance pins' rows on QoL > Map & Pins.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local Quests = J.Quests
local Settings = ns.Shared and ns.Shared.Settings

local OPACITY_RANGE, SCALE_RANGE = J.Style.OPACITY_RANGE, J.Style.SCALE_RANGE
local PIN_SIZE_RANGE = ns.Shared.Style.PIN_SIZE_RANGE
local TO_ENTRANCE_SCALE = 1 / ns.Shared.Style.PIN_SIZE_DEFAULT
local TO_FRACTION = J.Style.PERCENT_SCALE
local PERCENT = J.C.PERCENT
local ROUND_HALF = J.C.ROUND_HALF
local ORDER_FIRST, ORDER_SECOND, ORDER_THIRD, ORDER_FOURTH, ORDER_LAST = 10, 15, 20, 30, 90
local MAP_SIZE_RANGE = { 100, 200, 10 }

local TEXT_JOURNAL_OFF = ns.L("Turn on the Dungeon Journal")
local TEXT_AUTO_OFF = ns.L("Needs %s", ns.L("Open Tracker in Dungeons"))
local TEXT_NEW_LAYOUT_OFF = ns.L("Needs %s", ns.L("New Layout"))
local TEXT_BIS_OFF = ns.L("Needs the BiS List")
local TEXT_ENTRANCES_OFF = ns.L("Turn on Dungeon and Raid Entrances")
local TEXT_EVERY_DUNGEON = ns.L("Every dungeon and raid: what drops, your quests, and more.")
local TEXT_YOU_ARE_IN = ns.L("You are in %s.")
local TEXT_FOR_YOUR_LEVEL = ns.L("%s is for your level (%s).")
local TEXT_TO_PICK_UP = ns.L("%d to pick up")
local TEXT_IN_LOG = ns.L("%d in your log")
local TEXT_YOUR_QUESTS = ns.L("Your quests there: %s.")
local TEXT_LIST = ", "
local TEXT_ONE_FILTER = ns.L(", 1 filter on")
local TEXT_FILTERS = ns.L(", %d filters on")
local TEXT_OPACITY = ns.L("%d%% opacity")
local TEXT_OFF = ns.L("Off")
local FACTION_VALUES = { both = "Both Factions", Alliance = "Alliance Ground", Horde = "Horde Ground" }
local FACTION_ORDER = { "both", "Alliance", "Horde" }
local MAP_SUMMARY = { both = ns.L("Dungeons and zones"), panel = ns.L("In dungeons"), factions = ns.L("In zones"), none = ns.L("Nothing beside the map") }
local SHARE_SUMMARY = { both = ns.L("Asks and accepts shared quests"), ask = ns.L("Asks for shared quests"),
    accept = ns.L("Accepts shared quests") }
local TRACKER_EVERYWHERE, TRACKER_INSIDE, TRACKER_OUTSIDE = ns.L("everywhere"), ns.L("in dungeons"), ns.L("outside dungeons")
local TRACKER_EVERYWHERE_LOW, TRACKER_INSIDE_LOW = ns.L("outside, and in dungeons below max level"),
    ns.L("in dungeons below max level")
local TEXT_TRACKER, TEXT_AND_TRACKER = ns.L("Tracker "), ns.L(", tracker ")

local function ForYou()
    local here = J.Current()
    if here then return here[1], true end
    local level = UnitLevel("player")
    for _, dungeon in ipairs(J.Dungeons()) do
        local levels = not dungeon.raid and J.Levels(dungeon)
        if levels and level >= levels[1] and level <= levels[2] then return dungeon, false end
    end
end

local function Headline()
    local dungeon, inside = ForYou()
    if not dungeon then return TEXT_EVERY_DUNGEON end
    local name = ns.Color("accentSoft", dungeon.name)
    if inside then return TEXT_YOU_ARE_IN:format(name) end
    return TEXT_FOR_YOUR_LEVEL:format(name, J.LevelRange(dungeon))
end

local function Detail()
    local dungeon = ForYou()
    if not (dungeon and dungeon.quests) then return end
    local toPickUp, inLog = Quests.Count(dungeon.quests)
    if toPickUp + inLog == 0 then return end
    local parts = {}
    if toPickUp > 0 then parts[#parts + 1] = TEXT_TO_PICK_UP:format(toPickUp) end
    if inLog > 0 then parts[#parts + 1] = TEXT_IN_LOG:format(inLog) end
    return TEXT_YOUR_QUESTS:format(table.concat(parts, TEXT_LIST))
end

local function JournalOn()
    return S.Get("enabled") == true
end

local function NewLayoutOn()
    return JournalOn() and S.Get("newLayout") == true
end

local function NewLayoutWhy()
    return JournalOn() and TEXT_NEW_LAYOUT_OFF or TEXT_JOURNAL_OFF
end

local function AutoOn()
    return JournalOn() and S.Get("trackerAuto") == true
end

local function AutoWhy()
    return JournalOn() and TEXT_AUTO_OFF or TEXT_JOURNAL_OFF
end

local function JournalWhy()
    if not JournalOn() then return TEXT_JOURNAL_OFF end
end

local function PadFree()
    return JournalOn() and not ns.GamepadStandDown()
end

local function PadWhy()
    return ns.GamepadWhy() or TEXT_JOURNAL_OFF
end

local function EntrancesOn()
    return JournalOn() and S.Get("mapEntrances") == true
end

local function BisOn()
    return Loot.BisOn()
end

local function FactionGet()
    local alliance, horde = S.Get("showAlliance"), S.Get("showHorde")
    if alliance and horde then return "both" end
    return alliance and "Alliance" or "Horde"
end

local function FactionSet(value)
    if value == "Horde" then
        S.Set("showHorde", true)
        S.Set("showAlliance", false)
        return
    end
    S.Set("showAlliance", true)
    S.Set("showHorde", value ~= "Alliance")
end

local function LevelRow(key, label, help)
    local function Get()
        local level = S.Get(key)
        return level > 0 and tostring(level) or ""
    end
    local function Set(text)
        S.Set(key, math.max(0, math.floor(tonumber(text) or 0)))
    end
    return { key = key, label = label, text = true, get = Get, set = Set, help = help }
end

local function OptionRow(option)
    local row = { key = option.key, label = option.label, toggle = true, help = option.tooltip }
    if option.needsBis then
        row.needs, row.why, row.help = BisOn, TEXT_BIS_OFF, option.tooltip .. " " .. J.NEEDS_BIS
    end
    return row
end

local function ListRows()
    local rows = {}
    for _, option in ipairs(J.OPTION_GROUPS[1].options) do
        if option.to then
            rows[#rows + 1] = LevelRow(option.key, "Loot From Level", "Only the loot from this required level up; empty is no limit.")
            rows[#rows + 1] = LevelRow(option.to, "Loot To Level", "Only the loot up to this required level; empty is no limit.")
        else
            rows[#rows + 1] = OptionRow(option)
        end
    end
    rows[#rows + 1] = { label = "Dungeons Listed", choice = { FACTION_VALUES, FACTION_ORDER },
        get = FactionGet, set = FactionSet,
        help = "Whose city dungeons the list shows. The other dungeons and the raids are always listed. "
            .. "Also the switch beside the Journal's search." }
    return rows
end

local function ListSummary(store)
    local hiding = 0
    for _, option in ipairs(J.OPTION_GROUPS[1].options) do
        if option.to and (store.Get(option.key) > 0 or store.Get(option.to) > 0)
            or option.hides ~= nil and store.Get(option.key) == option.hides then
            hiding = hiding + 1
        end
    end
    return ns.L(FACTION_VALUES[FactionGet()]) .. (hiding == 1 and TEXT_ONE_FILTER or TEXT_FILTERS:format(hiding))
end

local function MapSummary(store)
    local panel, factions = store.Get("mapPanel"), store.Get("mapFactions")
    if panel and factions then return MAP_SUMMARY.both end
    if panel then return MAP_SUMMARY.panel end
    if factions then return MAP_SUMMARY.factions end
    return MAP_SUMMARY.none
end

local function ShareSummary(store)
    local ask, accept = store.Get("shareRequests"), store.Get("acceptShared")
    if ask and accept then return SHARE_SUMMARY.both end
    if ask then return SHARE_SUMMARY.ask end
    if accept then return SHARE_SUMMARY.accept end
    return TEXT_OFF
end

local function TrackerWhere(store)
    local outside = store.Get("trackerOutside")
    if store.Get("trackerAuto") and store.Get("trackerSkipMaxLevel") then
        return outside and TRACKER_EVERYWHERE_LOW or TRACKER_INSIDE_LOW
    end
    if store.Get("trackerAuto") then return outside and TRACKER_EVERYWHERE or TRACKER_INSIDE end
    return outside and TRACKER_OUTSIDE
end

local function QuestsSummary(store)
    local text = ShareSummary(store)
    local where = TrackerWhere(store)
    if not where then return text end
    return text == TEXT_OFF and TEXT_TRACKER .. where or text .. TEXT_AND_TRACKER .. where
end

local function OpacitySummary(key)
    return function(store)
        return TEXT_OPACITY:format(math.floor((store.Get(key) or 1) * PERCENT + ROUND_HALF))
    end
end

local function OpenJournal()
    ns.OpenJournalWindow()
end

local function OpenTracker()
    J.TurnOn()
    J.QuestTracker.Show(ForYou() or J.Dungeons()[1])
end

local function OnSettingChanged(key)
    if key == "enabled" then ns.UI:RefreshPage(true) end
end

local function Toggle(key, label, help, search)
    return { key = key, label = label, toggle = true, needs = JournalOn, why = TEXT_JOURNAL_OFF, help = help,
        search = search }
end

local function DeclareJournal()
    local page = Settings.Page("Dungeon Journal/Journal", S)
    page:Window({ text = "Open Dungeon Journal", open = OpenJournal, headline = Headline, detail = Detail })
    page:Card({
        id = "lists", name = "What It Lists", order = ORDER_FIRST,
        help = "What the Journal lists on a boss. The same switches as the Filters icon on its title bar.",
        summary = ListSummary,
        rows = ListRows(),
    })
    page:Card({
        id = "pages", name = "Dungeon Pages", order = ORDER_SECOND,
        help = "What a dungeon's page shows besides its loot.",
        rows = {
            Toggle("newLayout", "New Layout", "Tries the Journal's new look: every dungeon as a card, then its map beside all of its loot."),
            { key = "mapSize", label = "Map Size", slider = MAP_SIZE_RANGE, unit = "%", scale = TO_FRACTION,
              needs = NewLayoutOn, why = NewLayoutWhy,
              help = "How big the map is on a dungeon's page. The window grows to fit it, so the loot beside it keeps its room." },
            Toggle("bossPortraits", "Boss Portraits", "Shows each boss's face beside its name."),
            Toggle("dungeonArt", "Dungeon Art", "Shows the dungeon's loading screen behind its name."),
            Toggle("showKeys", "Keys and Attunements", "Shows the keys a dungeon needs, and whether you have them."),
            Toggle("lootFinder", "Loot Finder", "A bag on the title bar finds loot from every dungeon by slot, armor and stats.",
                "search find item slot armor stat resistance"),
            Toggle("crafting", "Crafting", "A hammer on the title bar lists every profession's recipes, with their skill and source.",
                "profession recipe craft enchant consumable gear"),
            Toggle("questHelp", "Quest Help", "Warns before a quest is lost, and shows what quests and summons need."),
        },
    })
    page:Card({
        id = "tooltips", name = "Item Tooltips", order = ORDER_THIRD,
        help = "What the Journal adds to an item's tooltip anywhere in the game.",
        search = "drops from source boss dungeon chance",
        rows = {
            Toggle("itemSources", "Where It Drops",
                "Adds the bosses that drop an item, their dungeon and the chance, to its tooltip."),
        },
    })
    page:Card({
        id = "favourites", name = "Favourites", order = ORDER_THIRD,
        help = "A wishlist of items from any dungeon or faction.",
        rows = {
            Toggle("favourites", "Favourites",
                "Right-click an item to star it; the star on the title bar lists them all."),
        },
    })
    page:Card({
        id = "rareAlert", name = "Rare Alert", order = ORDER_THIRD, switch = "rareAlert", switchWhy = JournalWhy,
        help = "A toast and a chime when you come across one of the dungeon's rares; its button targets it.",
        rows = {
            { key = "rareAlertSound", label = "Play a Sound", toggle = true,
              help = "Chimes now and then until you target the rare or close the toast." },
        },
    })
    page:Card({
        id = "runPanel", name = "Run Panel", order = ORDER_THIRD, switch = "runPanel", switchWhy = JournalWhy,
        help = "Your run's time, gold, XP and each boss against your best run, in a panel inside dungeons.",
        search = "run log timer splits best time gold xp trash lockouts instances per hour history runs tab",
        summary = OpacitySummary("runAlpha"),
        rows = {
            { key = "runCompact", label = "Compact", toggle = true, help = "Shows the run on one line." },
            { key = "runAlpha", label = "Opacity", slider = OPACITY_RANGE, unit = "%", scale = TO_FRACTION,
              help = "How solid the Run Panel is." },
            { key = "runScale", label = "Window Scale", slider = SCALE_RANGE, unit = "%",
              scale = TO_FRACTION, help = "How big the Run Panel is." },
        },
    })
    page:Card({
        id = "keys", name = "Key Binding", order = ORDER_FOURTH,
        help = "The key that opens the Journal.",
        search = "up down arrow keys ctrl+f ctrl f search recent reset kills loot",
        rows = {
            { label = "Open Dungeon Journal", binding = "NAOWHFOREVER_JOURNAL",
              help = "Press it to open or close the Dungeon Journal." },
        },
    })
end

local function DeclareTracker()
    local tracker = Settings.Page("Dungeon Journal/Quest Tracker", S)
    tracker:Window({ text = "Open Quest Tracker", open = OpenTracker, headline = Headline, detail = Detail })
    tracker:Card({
        id = "quests", name = "Quests", order = ORDER_FIRST,
        help = "The quest tracker, and sharing dungeon quests with your group.",
        summary = QuestsSummary,
        rows = {
            Toggle("trackerAuto", "Open Tracker in Dungeons",
                "Opens the quest tracker when you enter a dungeon with quests for you."),
            { key = "trackerSkipMaxLevel", label = "Hide at Max Level", toggle = true, needs = AutoOn, why = AutoWhy,
              help = "Leaves the quest tracker closed in dungeons once you are max level." },
            Toggle("trackerOutside", "Show Outside Dungeons",
                "Opens the quest tracker out in the world, on the dungeon your quests are for."),
            { key = "hideGameTracker", label = "Hide the Game's Quest Tracker", toggle = true, needs = PadFree,
              why = PadWhy, help = "Fades out the game's quest tracker while this one is open in a dungeon." },
            Toggle("shareRequests", "Quest Share Requests",
                "Ask your group to share a dungeon quest you don't have, from its group icon."),
            Toggle("acceptShared", "Accept Shared Dungeon Quests",
                "Accepts dungeon quests your group shares with you straight away.",
                "hold skip modifier qol accept quests"),
            Toggle("trackerLogOnlyMaxLevel", "Only My Quests at Max Level",
                "Once you are max level, the quest tracker lists only the dungeon's quests in your log."),
        },
    })
    tracker:Card({
        id = "trackerwindow", name = "Window", order = ORDER_LAST,
        help = "The Dungeon Quest Tracker's window.",
        summary = OpacitySummary("trackerAlpha"),
        rows = {
            { key = "trackerAlpha", label = "Opacity", slider = OPACITY_RANGE, unit = "%", scale = TO_FRACTION,
              help = "How solid the Dungeon Quest Tracker is." },
            { key = "trackerScale", label = "Window Scale", slider = SCALE_RANGE, unit = "%",
              scale = TO_FRACTION, help = "How big the Dungeon Quest Tracker is." },
        },
    })
end

local function DeclareMap()
    local map = Settings.Page("Dungeon Journal/Map", S)
    map:Card({
        id = "map", name = "Beside the World Map", order = ORDER_FIRST, switchWhy = ns.GamepadWhy,
        help = "The Journal beside the world map: bosses and loot in dungeons, factions outside.",
        search = "dungeon page map link pin fold map and bosses only",
        summary = MapSummary,
        rows = {
            Toggle("mapPanel", "Bosses and Loot in Dungeons",
                "Shows a dungeon's bosses and loot beside the world map while you are inside.",
                "dungeon map on the world map quest log fold"),
            Toggle("mapFactions", "Factions Beside the Map",
                "Shows the factions earned where you are beside the world map."),
            Toggle("mapQuestPins", "Quest Pins",
                "Marks the quest givers, hand-ins and quest objects inside a dungeon on its map.",
                "quest giver turn in hand in npc object exclamation question mark dungeon map"),
        },
    })
    map:Card({
        id = "lootkey", name = "Boss Loot at Cursor", order = ORDER_THIRD,
        help = "A key that shows a boss's loot at your cursor.",
        rows = {
            { label = "Boss Loot at Cursor", binding = "NAOWHFOREVER_BOSSLOOT",
              help = "Press it over a boss, or with one targeted, to see what it drops." },
        },
    })
end

local function DeclareMapPins()
    local entrances = Toggle("mapEntrances", "Dungeon and Raid Entrances", "A door on each dungeon and raid "
        .. "entrance on the world map, for the sides the Journal lists. Hover it for the levels and click for "
        .. "a waypoint, or for its map and journal when that is on.")
    entrances.store, entrances.always = S, true
    local entranceJournal = Toggle("entranceJournal", "Click entrance to open the dungeon map",
        "Click an entrance to open its dungeon map and journal, and right-click it for a waypoint; needs Bosses "
        .. "and Loot in Dungeons.")
    entranceJournal.store, entranceJournal.always = S, true
    entranceJournal.needs, entranceJournal.why = EntrancesOn, TEXT_ENTRANCES_OFF
    table.insert(ns.Shared.MapPins, {
        title = ns.L("Dungeons & Raids"), store = S, switch = "mapEntrances",
        rows = {
            entrances,
            entranceJournal,
            { key = "mapEntranceScale", label = "Entrance Icon Size", slider = PIN_SIZE_RANGE,
              scale = TO_ENTRANCE_SCALE, store = S, always = true, needs = EntrancesOn,
              why = TEXT_ENTRANCES_OFF, help = "How big the entrance icons are. They are largest on a zone's map, "
                  .. "smaller on a continent's and the world's." },
        },
    })
end

S.OnChange(OnSettingChanged)
if Settings then
    DeclareJournal()
    DeclareTracker()
    DeclareMap()
    DeclareMapPins()
end
