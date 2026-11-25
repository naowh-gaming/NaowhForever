-- Loads Find.lua against stubbed town data, positions and a recording view, and checks what the Find
-- window draws: the nearest of each service with nothing typed, matches nearest first, only your
-- faction's and class's, the Discovery quests and rares when it is on, and the waypoint a click places.
-- Also loads Discovery's QuestList/Find.lua against stubbed quest and rare rules.
-- Run from the repo root: lua Tools/regression/test-find.lua
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a")
    f:close()
    return source
end

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Noop() end
local function Stub()
    return setmetatable({}, { __index = function() return Noop end })
end

local rows, searchFn, windowSpec, shown, placed, searchText, launcher
local view = {}
function view:Clear() rows = {} end
function view:Section(title, count) rows[#rows + 1] = { "section", title, count } end
function view:Note(text) rows[#rows + 1] = { "note", text } end
function view:NeedsModule(title, text, addon) rows[#rows + 1] = { "needs", title, addon, text } end
function view:Add(kind, hit) rows[#rows + 1] = { kind, hit } end
function view:Space() end
function view:Fit(events) self.events = events end
function view:SetWidth() end

local window = Stub()
window.backdrop = Stub()
function window:Show() shown = true end
function window:Hide() shown = false end
function window:IsShown() return shown end

local search = Stub()
function search:GetText() return searchText end
function search:SetText(text)
    if text ~= searchText then
        searchText = text
        searchFn(text)
    end
end

local kinds
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    QoLSettings = {},
    UIScale = function() return 1 end,
    UI = { SlimScroll = Stub },
    THEME = { fg = {}, muted = {} },
    Font = Stub,
    Solid = Stub,
    PlaceWaypoint = function(...) placed = { ... } end,
    RegisterMinimapFeature = function(feature) launcher = feature end,
    TownCategories = {
        bank = { "townBank", "Interface\\Icons\\INV_Misc_Bag_10", "Banker" },
        inn = { "townInn", "Interface\\Icons\\INV_Misc_Rune_01", "Innkeeper" },
        class = { "townClass", nil, "Class Trainer" },
        stable = { "townStable", "Interface\\Icons\\Ability_Hunter_BeastTaming", "Stable Master" },
        mail = { "townMail", "Interface\\Icons\\INV_Letter_15", "Send and collect mail" },
        spirit = { "townSpiritHealers", "Interface\\Icons\\Spell_Holy_GuardianSpirit", "Spirit Healer" },
        vendor = { "townVendors", "Interface\\Icons\\INV_Misc_Bag_07", "Vendor" },
    },
    TownNPCs = {
        [10] = {
            { 10, 0, "bank", "Near Banker", "Banker", nil, "AH" },
            { 50, 0, "bank", "Far Banker", "Banker", nil, "A" },
            { 1, 0, "bank", "Horde Banker", "Banker", nil, "H" },
            { 20, 0, "inn", "Innkeeper Ada", "Innkeeper", nil, "AH" },
            { 30, 0, "class", "Wil", "Warrior Trainer", "WARRIOR", "A" },
            { 2, 0, "class", "Mae", "Mage Trainer", "MAGE", "A" },
            { 3, 0, "stable", "Stan", "Stable Master", nil, "A" },
            { 40, 0, "vendor", "Olga", "Bowyer", nil, "A" },
        },
        [20] = {
            { 0, 0, "bank", "Other Continent Banker", "Banker", nil, "AH" },
        },
    },
    TownMailboxes = { [10] = { { 5, 0, "mail", "Mailbox", "", nil, "AH" } } },
    TownSpiritHealers = { [10] = { { 60, 0, "spirit", "Spirit Healer", "Graveyard", nil, "AH" } } },
    Shared = {
        Style = { WINDOW_HEADER = 52, WINDOW_PAD = 12, WINDOW_FOOTER = 20, SCROLLBAR = 16, SEARCH_H = 24,
            CONTENT_INSET = 22, ICON = 24, ITEM_H = 30, GAP = 4, HOVER = 0.1, TEXT_SIZE = 12, SMALL_SIZE = 11 },
        Parts = {
            Window = function() return window end,
            TitleBar = Noop,
            FooterBrand = Noop,
            SearchBox = function(_, _, fn) searchFn = fn return search end,
            ItemIcon = function() local icon = Stub() icon.texture = Stub() return icon end,
        },
        View = {
            NewKinds = function() kinds = {} return kinds end,
            New = function(_, _, mixin)
                for k, v in pairs(mixin) do view[k] = v end
                return view
            end,
        },
        Settings = { Page = function() return { Window = function(_, spec) windowSpec = spec end } end },
    },
}

local function Vector(x, y)
    return { GetXY = function() return x, y end }
end

-- Map 10 is 1000 yards wide on continent 0, map 20 on continent 1; the player stands at the map's 0, 0.
local here = { 0, 0 }
local env = setmetatable({
    _G = { NaowhForever = ns },
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    CreateVector2D = Vector,
    C_Map = {
        GetWorldPosFromMapPos = function(map, v)
            local x, y = v:GetXY()
            return map == 10 and 0 or 1, Vector(x * 1000, y * 1000)
        end,
        GetMapInfo = function(map) return { name = "Zone " .. map } end,
    },
    UnitPosition = function() return here[1], here[2], 0, 0 end,
    UnitFactionGroup = function() return "Alliance" end,
    UnitClass = function() return "Warrior", "WARRIOR" end,
    CreateFrame = function()
        local frame = Stub()
        frame.scripts = {}
        function frame:SetScript(name, fn) self.scripts[name] = fn end
        return frame
    end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/Find.lua"), "Find"))
setfenv(chunk, env)
chunk()

check("the settings page offers to open it", windowSpec and windowSpec.text == "Open Find")
check("nothing is built before it is opened", searchFn == nil)
check("a launcher for the minimap and the Top Bar toggles it", launcher and launcher.id == "Find" and launcher.open == ns.ToggleFind)

local function Names()
    local out = {}
    for _, row in ipairs(rows) do
        if row[1] == "place" then out[#out + 1] = row[2].name end
    end
    return table.concat(out, ", ")
end

ns.OpenFind()
check("nothing typed: a hint, then the nearest of each service", rows[1][1] == "note" and rows[2][2] == "Nearest")
check("the nearest of each, in the services' order, yours only",
    Names() == "Innkeeper Ada, Mailbox, Near Banker, Wil, Spirit Healer")
check("a row has its title and zone, and how far it is",
    rows[5][2].detail == "Banker, Zone 10" and rows[5][2].dist == 100)
check("a mailbox, with no title, has its service", rows[4][2].detail == "Send and collect mail, Zone 10")
check("it redraws on entering a zone and on stopping", view.events[1] == "ZONE_CHANGED_NEW_AREA"
    and view.events[2] == "PLAYER_STOPPED_MOVING")

searchFn("  BANK ")
check("a search by service, nearest first, the other continent last",
    rows[1][2] == "Town Services" and Names() == "Near Banker, Far Banker, Other Continent Banker")
check("the other continent has no distance", rows[4][2].dist == math.huge)
check("Discovery off: offers to turn it on", rows[#rows][1] == "needs" and rows[#rows][3] == "NaowhForever_Discovery")
searchFn("bowyer")
check("a search by title", Names() == "Olga")
searchFn("mage")
check("another class's trainer is left out", Names() == "" and rows[1][2]:find("Nothing matches"))
searchFn("stable")
check("a stable master only for hunters", Names() == "")

local row = kinds.place.New({})
kinds.place.Set(row, { name = "Near Banker", detail = "Banker, Zone 10", map = 10, x = 10, y = 0, dist = 100 })
row.scripts.OnClick(row)
check("a click places the waypoint", placed[1] == "Near Banker" and placed[2] == 10 and placed[3] == 10)

ns.FindQuestsAndRares = function(text, add)
    if text ~= "hog" then return true end
    add("quest", "WANTED: Hogger", "Wanted Poster", 10, 70, 0)
    add("quest", "Hogs Nearby", nil, 10, 15, 0)
    add("rare", "Hogger", "11", 10, 80, 0)
    return true
end
searchFn("hog")
check("Discovery on: quests and rares, each nearest first",
    rows[1][2] == "Quests" and Names() == "Hogs Nearby, WANTED: Hogger, Hogger" and rows[4][2] == "Rares")
check("and no offer to turn it on", rows[#rows][1] ~= "needs")
check("a quest's giver goes before its zone", rows[3][2].detail == "Wanted Poster, Zone 10")
check("a quest or rare has its own icon", rows[2][2].icon:find("Note") and rows[5][2].icon:find("Sniper"))

for i = 1, 60 do ns.TownNPCs[10][#ns.TownNPCs[10] + 1] = { i, 0, "vendor", "Seller " .. i, "Vendor", nil, "A" } end
searchFn("seller")
local placesShown = 0
for _, r in ipairs(rows) do if r[1] == "place" then placesShown = placesShown + 1 end end
check("a long list stops at 50 and says so", placesShown == 50 and rows[1][3] == 60
    and rows[52][2]:find("first 50 of 60"))

ns.ToggleFind()
check("the toggle closes an open window", shown == false)
ns.OpenFind("near")
check("/nf find with a name opens it searching that", shown == true and Names() == "Near Banker")
local redraws = 0
local redraw = view.Redraw
view.Redraw = function(self) redraws = redraws + 1 return redraw(self) end
ns.OpenFind("bowyer")
check("a new name draws once", redraws == 1 and Names() == "Olga")
ns.OpenFind("bowyer")
check("and the same name again still draws it", redraws == 2 and Names() == "Olga")
view.Redraw = redraw

here = { nil, nil }
ns.OpenFind("")
search:SetText("")
check("nowhere to measure from (an instance): no nearest, the hint only", #rows == 1 and rows[1][1] == "note")

-- Discovery's half: every quest and rare that matches, at its spot, for Find to sort.
local hits = {}
local completoOn = true
local Q = {
    Refresh = Noop,
    Update = Noop,
    Done = function(id) return id == 3 end,
    Search = function(text, limit)
        assert(text == "hog" and limit == math.huge)
        return { { ids = { 1, 2, 3 } } }, 3
    end,
    Spot = function(id) if id ~= 2 then return 10, 70, 0 end end,
    Title = function() return "WANTED: Hogger" end,
    Giver = function(id) return id == 4 and "Hogwarden Elm" or "Wanted Poster" end,
    Item = function(id) return id == 5 and 1234 or nil end,
    Mine = function(id) return id ~= 2 end,
}
local R = {
    Search = function() return { { ids = { 448 } } }, 1 end,
    Spot = function() return 10, 80, 0 end,
    Name = function() return "Hogger" end,
    LevelText = function() return "11" end,
}
local discovery = { L = dofile("Tools/regression/locale_stub.lua").L, Completo = { Quests = Q, Rares = R },
    CompletoSettings = { Get = function(k) return k == "enabled" and completoOn end },
    CompletoQuestData = {
        Quests = { [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {} },
        HandIns = { [1] = { "Marshal Hogan", 10, 20, 30 }, [2] = { "Hogan the Horde's", 10, 21, 31 },
            [3] = { "Hogwash the Done", 10, 22, 32 } },
        Objectives = { [2] = { { 1, 0, { 1, "Hogger", 10, 40, 50, 41, 51 } } },
            [9] = { { 1, 1, { 2, "Hog Pen", 10, 60, 60 }, { 1, "Hogger", 10, 40, 50 } } } },
    } }
local denv = setmetatable({ _G = { NaowhForever = discovery } }, { __index = _G })
local dchunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Find.lua"), "DiscoveryFind"))
setfenv(dchunk, denv)
dchunk()
local function Collect(...) hits[#hits + 1] = { ... } end
check("Discovery on says so", discovery.FindQuestsAndRares("hog", Collect) == true)
local places = {}
for i = #hits, 1, -1 do
    if hits[i][1] == "npc" then places[hits[i][2]] = table.remove(hits, i) end
end
check("Discovery hands over every match with a spot, less those done", #hits == 2 and hits[1][1] == "quest" and hits[1][2] == "WANTED: Hogger"
    and hits[1][3] == "Wanted Poster" and hits[1][4] == 10)
check("a rare at its spot, with its level", hits[2][1] == "rare" and hits[2][2] == "Hogger" and hits[2][3] == "11"
    and hits[2][5] == 80)
check("the creatures and objects quests send you to: a hand-in NPC, an objective's",
    places["Marshal Hogan"] and places["Marshal Hogan"][3] == "Takes WANTED: Hogger" and places["Marshal Hogan"][5] == 20
    and places.Hogger and places["Hog Pen"])
check("quest givers are the Quests section's, not listed again", places["Hogwarden Elm"] == nil)
check("one per name and map, for whichever of its quests is yours", places.Hogger[5] == 40
    and places.Hogger[3] == "For WANTED: Hogger")
check("not for a quest you have done", places["Hogwash the Done"] == nil)
check("an object has the object icon, a creature the creature one",
    places["Hog Pen"][7]:find("Gear") and places.Hogger[7]:find("Head"))
check("not another side's NPC, nor the drop an item quest begins from",
    places["Hogan the Horde's"] == nil and places["Wanted Poster"] == nil)

hits = {}
completoOn = false
check("Discovery switched off hands over nothing, and says so",
    discovery.FindQuestsAndRares("hog", Collect) == false and #hits == 0)

print(("PASS find: %d checks"):format(checks))
