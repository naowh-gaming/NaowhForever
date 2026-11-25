-- Regression test for Discovery's Attunements (NaowhForever_Discovery/Data/Attunements.lua and the
-- rules in NaowhForever_Discovery/Attunements.lua): each key's quests in order, read from the Quest
-- List's own data for each faction, the step you are on from the quest log, and where a quest starts.
-- Then its tracker on the shared tracker window (a row for each key you can work on) and its map
-- pins (each key's next quest, on its giver's map, only while on).
--   lua5.1 Tools/regression/test-attunements.lua

local checks = 0
local function Check(ok, label)
    checks = checks + 1
    assert(ok, label)
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local NOTHING = function() end
local NAME, REQ_LEVEL, SIDE, MAP, X, Y, GIVER = 1, 3, 4, 7, 8, 9, 10
local BOTH = 3
local SIDES = { A = 1, H = 2 }

local D = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, CompletoQuestData = D }
_G.NaowhForever = ns
assert(loadstring(Read("NaowhForever_DiscoveryData/Quests.lua")))()
assert(loadstring(Read("NaowhForever_Discovery/Data/Attunements.lua")))()

local side, class, level, zone = "A", "WARRIOR", 60, 1428
local completed, inLog, carried, waypoints = {}, {}, {}, {}
local refreshes = 0
local Q = {}
function Q.Refresh() refreshes = refreshes + 1 end
function Q.Mine(id)
    local quest = D.Quests[id]
    return quest ~= nil and (quest[SIDE] == BOTH or quest[SIDE] == SIDES[side])
end
function Q.Requires(id) return D.Requires[id] or {} end
function Q.Name(id) return D.Quests[id][NAME] end
function Q.Giver(id) return D.Quests[id][GIVER] end
function Q.RequiredLevel(id) return D.Quests[id][REQ_LEVEL] end
function Q.Spot(id)
    local quest = D.Quests[id]
    if quest[MAP] then return quest[MAP], quest[X], quest[Y] end
end
ns.Completo = { Quests = Q }
local Library = {
    Side = function() return side end,
    ZoneName = function(map) return "map " .. map end,
    PlayerZone = function() return zone end,
    Waypoint = function(title, map, _, _, note) waypoints[#waypoints + 1] = title .. note .. map end,
}
ns.Discovery = { Library = Library }

local GAME = {
    C_QuestLog = {
        IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
        IsOnQuest = function(id) return inLog[id] == true end,
        GetTitleForQuestID = function() return nil end,
    },
    C_Item = {
        GetItemCount = function(item) return carried[item] and 1 or 0 end,
        GetItemNameByID = function(item) return "Item " .. item end,
        GetItemIconByID = function(item) return item end,
    },
    UnitLevel = function() return level end,
    UnitClass = function() return class, class, 1 end,
    IsLoggedIn = function() return true end,
}

local function Load(path, extra)
    local globals = { NaowhForever = ns }
    for k, v in pairs(GAME) do globals[k] = v end
    for k, v in pairs(extra or {}) do globals[k] = v end
    local env = setmetatable(globals, { __index = _G })
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
    return env
end

local function Rules()
    Load("NaowhForever_Discovery/Attunements.lua")
    return ns.Discovery.Attune
end

-------------------------------------------------------------------------------
--  The data and the rules
-------------------------------------------------------------------------------
local list = ns.Attunements.list
local byDungeon = {}
local keys = {}
for _, entry in ipairs(list) do
    byDungeon[entry.dungeon] = entry
    if not entry.class then keys[#keys + 1] = entry end
end
Check(#list == 7, "seven: Maraudon, Blackrock Depths, Scholomance, Molten Core, Upper Blackrock Spire, Onyxia's Lair, Tier 0.5")
Check(byDungeon["Molten Core"].item == nil and byDungeon["Molten Core"].quest == 7848,
    "Molten Core's is a quest and no key")
Check(byDungeon["Molten Core"].raid == true and byDungeon["Onyxia's Lair"].raid == true,
    "Molten Core and Onyxia's Lair are raids")
local journaled = 0
for _, entry in ipairs(list) do
    local f = io.open("NaowhForever_DungeonJournal/Data/Dungeons/" .. entry.dungeon:gsub("[^%w]", "") .. ".lua", "rb")
    if f then
        journaled = journaled + 1
        local raid = f:read("*a"):find("\n%s*raid = %d+,") ~= nil
        f:close()
        Check(raid == (entry.raid == true), entry.dungeon .. ": a raid here only when the Dungeon Journal says it is one")
    end
end
Check(journaled == #list - 2, "every one but Molten Core and Tier 0.5 is in the Dungeon Journal to check against")

local STEPS = {
    A = { ["Maraudon"] = 2, ["Blackrock Depths"] = 2, ["Scholomance"] = 8, ["Molten Core"] = 1,
        ["Upper Blackrock Spire"] = 2, ["Onyxia's Lair"] = 16 },
    H = { ["Maraudon"] = 2, ["Blackrock Depths"] = 2, ["Scholomance"] = 8, ["Molten Core"] = 1,
        ["Upper Blackrock Spire"] = 2, ["Onyxia's Lair"] = 14 },
}
local LAST = { A = { ["Scholomance"] = 5505, ["Onyxia's Lair"] = 6502 }, H = { ["Scholomance"] = 5511, ["Onyxia's Lair"] = 6602 } }

for _, s in ipairs({ "A", "H" }) do
    side = s
    local Attune = Rules()
    for _, entry in ipairs(keys) do
        local steps = Attune.Steps(entry)
        local label = s .. " " .. entry.dungeon
        Check(#steps == STEPS[s][entry.dungeon], label .. ": " .. STEPS[s][entry.dungeon] .. " quests")
        Check(steps[#steps] == (LAST[s][entry.dungeon] or entry.quest), label .. ": ends in the quest that gives it")
        local seen = {}
        for i, id in ipairs(steps) do
            Check(Q.Mine(id) and not seen[id], label .. ": step " .. i .. " is this faction's, once")
            seen[id] = true
            Check(Q.Spot(id) ~= nil or ns.Attunements.inside[id] ~= nil, label .. ": step " .. i .. " says where it starts")
            for _, element in ipairs(Q.Requires(id)) do
                if type(element) == "number" and Q.Mine(element) then
                    Check(seen[element], label .. ": step " .. i .. " comes after what it needs")
                end
            end
        end
    end
end

side = "A"
local Attune = Rules()
local ony = byDungeon["Onyxia's Lair"]
refreshes = 0
local steps = Attune.Steps(ony)
Check(Attune.Steps(ony) == steps and refreshes == 1, "a key's steps are worked out once, after the Quest List knows your quests")
Check(steps[1] == 4182 and steps[12] == 4322 and steps[16] == 6502, "the Alliance's runs from Dragonkin Menace through Jail Break!")
Check(Attune.At(ony) == 1 and Attune.State(steps[1], 1, 1) == "now", "nothing done: the first quest is next")
level = 40
Check(Attune.State(steps[1], 1, 1) == "low", "under its level it says so")
Check(Attune.Next(ony) == nil and Attune.Next(byDungeon["Maraudon"]) == nil and not Attune.Open(),
    "and a key not started that you are too low for is not one to work on")
level = 41
Check(Attune.Next(byDungeon["Maraudon"]) == 7044 and Attune.Open(), "at its level it is")
level = 60
inLog[4182] = true
Check(Attune.State(steps[1], 1, 1) == "log", "in your log")
inLog[4182] = nil
completed[4322] = true
Check(Attune.At(ony) == 13, "Jail Break! handed in: on step 13, whatever the flags before it say")
Check(Attune.State(steps[3], 3, 13) == "done" and Attune.State(steps[13], 13, 13) == "now"
    and Attune.State(steps[14], 14, 13) == "later", "the steps before are done, the ones after later")
local quest, at = Attune.Next(ony)
Check(quest == 6402 and at == 13, "its next quest is Stormwind Rendezvous")
level = 40
Check(Attune.Next(ony) == 6402, "a key you have started stays one to work on")
level = 60
completed[6502] = true
Check(Attune.At(ony) == 17 and Attune.Next(ony) == nil, "the amulet's quest done: past the last step, nothing next")
completed[6502] = nil
Check(not Attune.Have(ony), "no amulet in your bags or bank")
carried[16309] = true
Check(Attune.Have(ony) and Attune.Next(ony) == nil, "the amulet carried: nothing next either")
carried[16309] = nil
Check(not Attune.Have(byDungeon["Molten Core"]), "an attunement with no key is never carried")

Check(Attune.Title(ony) == "Item 16309" and Attune.Title(byDungeon["Molten Core"]) == "Attunement to the Core",
    "a key is named for its item, an attunement for its quest")
Check(Attune.Icon(ony) == 16309 and Attune.Icon(byDungeon["Molten Core"]) == 18412,
    "a key's icon is its own, Molten Core's the Core Fragment's")
Check(Attune.Where(4182) == "Helendis Riverhorn, map 1428 (85.8, 68.9)", "a quest's line: who gives it, the zone and the spot")
Check(Attune.Where(4322) == "Marshal Windsor, inside Blackrock Depths"
    and Attune.Where(7046) == "Celebras the Redeemed, inside Maraudon",
    "a quest given inside a dungeon names who gives it and the dungeon")
Check(Attune.Where(4264) == "Inside Blackrock Depths", "one an item there starts names the dungeon")
Check(Attune.Name(4322) == "Jail Break!", "a quest the client has no title for keeps the data's name")
Attune.Waypoint(4182)
Check(waypoints[1] == "Dragonkin Menace (Helendis Riverhorn)1428", "the waypoint goes to who gives it")

side = "H"
Check(Rules().Steps(ony)[1] == 4903 and Rules().Steps(ony)[14] == 6602, "the Horde's runs from Warlord's Command to Rexxar")
side = "A"
Rules()

-------------------------------------------------------------------------------
--  Tier 0.5: its steps by hand, each class's own, for both factions
-------------------------------------------------------------------------------
local tier = byDungeon["Tier 0.5"]
local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local NAMES = { [1] = "An Earnest Proposition", [8] = "Just Compensation", [17] = "Anthion's Parting Words",
    [29] = "Saving the Best for Last" }
local KEYS = { [1] = "proposition", [8] = "compensation", [17] = "parting", [29] = "best" }
local CLASS = 6
local CLASS_BITS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128,
    WARLOCK = 256, DRUID = 1024 }
local counted = {}
Check(tier.class == true and not tier.raid, "Tier 0.5 is on the Class page")
for _, s in ipairs({ "A", "H" }) do
    for _, c in ipairs(CLASSES) do
        side, class = s, c
        local rules = Rules()
        local tierSteps = rules.Steps(tier)
        local label = s .. " " .. c .. " Tier 0.5"
        Check(#tierSteps == 29, label .. ": 29 steps")
        for i, step in ipairs(tierSteps) do
            for _, id in ipairs(type(step) == "table" and step or { step }) do
                local row = D.Quests[id]
                Check(row and (row[SIDE] == BOTH or row[SIDE] == SIDES[s]), label .. ": step " .. i .. " is this faction's")
                Check(Q.Spot(id) ~= nil or ns.Attunements.inside[id] ~= nil, label .. ": step " .. i .. " says where it starts")
                if NAMES[i] then Check(row[NAME] == NAMES[i], label .. ": step " .. i .. " is " .. NAMES[i]) end
            end
        end
        for i, key in pairs(KEYS) do
            local own, classic = unpack(ns.Attunements.classQuests[s][c][key])
            Check(tierSteps[i] == own and D.Quests[own][CLASS] == CLASS_BITS[c],
                label .. ": step " .. i .. " is Forever's own quest, the Quest List's for this class alone")
            Check(not counted[own], label .. ": Forever's own " .. key .. " quest is this class's alone")
            counted[own] = true
            completed[own] = true
            Check(rules.At(tier) == i + 1, label .. ": Forever's " .. NAMES[i] .. " handed in counts for step " .. i)
            completed[own] = nil
            if classic then
                Check(D.Quests[classic] == nil, label .. ": the classic " .. key .. " quest is out of the Quest List")
                completed[classic] = true
                Check(rules.At(tier) == i + 1, label .. ": the classic " .. NAMES[i] .. " handed in counts too")
                completed[classic] = nil
            end
        end
        Check(rules.Title(tier) == "Saving the Best for Last", label .. ": named for its last quest")
    end
end

side, class = "A", "SHAMAN"
Attune = Rules()
steps = Attune.Steps(tier)
Check(steps[1] == 97447 and Attune.State(97447, 1, 1) == "now", "a shaman's first step is Forever's shaman quest at Deliana")
Check(Attune.Where(97447) == "Deliana, map 1455 (43.4, 51.4)", "where Forever's Deliana stands")
inLog[97447] = true
Check(Attune.State(97447, 1, 1) == "log", "Forever's shaman quest in the log shows it in the log")
inLog[97447] = nil
Check(#steps[20] == 4 and steps[20][1] == 8962, "Bodley's relics are one step, one of four")
completed[8963] = true
Check(Attune.At(tier) == 21, "any one of them handed in finishes the step")
inLog[8967] = true
quest, at = Attune.Next(tier)
Check(quest == 8967 and at == 21, "the next quest of a one-of step is the one in your log")
inLog[8967] = nil
Check(Attune.Next(tier) == 8966, "or the first of them")
completed[8963] = nil
level = 57
Check(Attune.Next(tier) == nil, "not started, under level 58: not one to work on")
level = 60
Check(Attune.Where(9015) == "Falrin Treeshaper, inside Dire Maul", "a step given inside a dungeon names who gives it there")
Check(Attune.Note(8961):find("Ash of Asharell", 1, true) and Attune.Note(8962) == nil,
    "Three Kings of Flame says Forever asks for the Ash of Asharell")
side, class = "A", "WARRIOR"
Rules()

-------------------------------------------------------------------------------
--  The tracker
-------------------------------------------------------------------------------
local settings = { enabled = true, attuneTracker = false, attuneTrackerScale = 1, attuneTrackerAlpha = 1,
    attuneMapPins = false, attuneMapPinSize = 20 }
local S = {}
function S.Get(key) return settings[key] end
function S.Set(key, value) settings[key] = value end
local function hooksecurefunc(t, name, fn)
    local orig = t[name]
    t[name] = function(...)
        if orig then orig(...) end
        fn(...)
    end
end
function ns.OnApply(fn) hooksecurefunc(ns, "Apply", fn) end
local FRAME = {}
FRAME.__index = FRAME
function FRAME:SetScript(_, fn) self.onEvent = fn end
function FRAME:RegisterEvent(event) self.events[event] = true end
function FRAME:UnregisterEvent(event) self.events[event] = nil end
function FRAME:UnregisterAllEvents() for event in pairs(self.events) do self.events[event] = nil end end
local frames = {}
local function CreateFrame()
    local frame = setmetatable({ events = {} }, FRAME)
    frames[#frames + 1] = frame
    return frame
end
local timers = {}
local GREY, WHITE, BLUE = { r = 0.5, g = 0.5, b = 0.5 }, { r = 1, g = 1, b = 1 }, { r = 0, g = 0.5, b = 1 }
ns.THEME = { muted = GREY, fg = WHITE, accent = BLUE, accentSoft = BLUE }
ns.UI = {}
ns.DiscoverySettings = S

local bar = { SetMinMaxValues = NOTHING, SetValue = NOTHING, SetStatusBarColor = NOTHING, text = {} }
function bar.text:SetText(text) self.shown = text end
local PANEL = { SetScale = NOTHING, Place = NOTHING, Paint = NOTHING, Fit = NOTHING }
PANEL.__index = PANEL
function PANEL:Show() self.shown = true end
function PANEL:Hide() self.shown = false end
function PANEL:SetRows(entries) self.entries = entries; return 0 end
local panel, title, mover
ns.Shared = { Style = { ICON_CROP = 0.08, ICON_CROP_HIGH = 0.92 }, Parts = { TrackerPanel = function(name, opts)
    title = name
    panel = setmetatable({ opts = opts, bar = bar, shown = true }, PANEL)
    panel.mover = opts.mover(panel, NOTHING)
    return panel
end }, OpenMap = dofile("Tools/regression/shared_openmap.lua") }
ns.UI.AttachMover = function(_, label, _, page)
    mover = { label, page, Show = NOTHING, Hide = NOTHING }
    return mover
end
local opened
ns.OpenDiscoveryWindow = function(tab) opened = tab end
ns.Discovery.Settings = S
local UI = { hooksecurefunc = hooksecurefunc, CreateFrame = CreateFrame,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end } }

Load("NaowhForever_Discovery/Constants.lua")
Load("NaowhForever_Discovery/View/Style.lua")
Load("NaowhForever_Discovery/UI/AttuneTracker.lua", UI)
ns.Apply()
Check(panel == nil and #frames == 0, "off, nothing is built and nothing listens")
S.Set("attuneTracker", true)
Check(panel ~= nil and title == "ATTUNEMENTS" and panel.shown, "on, it is built on the shared tracker window")
Check(frames[1].events.QUEST_TURNED_IN and frames[1].events.PLAYER_LEVEL_UP, "and listens for quests and levels")
local opts = panel.opts
Check(opts.settings.page == "Discovery/Attunements" and opts.settings.card == "attunetracker"
    and mover[1] == "Attunements" and mover[2] == "Discovery/Attunements", "its cog and its mover on its settings tab")
opts.onTitle()
Check(opened == "attune", "its title opens the Attunements tab")

local rows = panel.entries
Check(#rows == 7, "a row for each key you can work on")
Check(rows[1].text == "Maraudon  0 / 2" and rows[1].sub == "Legends of Maraudon\nCavindra, map 1443 (32.1, 64.0)",
    "a row: the dungeon, how far you are, and the next quest with who gives it")
Check(rows[6].text == "Onyxia's Lair  12 / 16" and rows[6].sub:find("Stormwind Rendezvous", 1, true),
    "a key under way counts its steps done")
Check(rows[7].text == "Tier 0.5  0 / 29" and rows[7].sub == "An Earnest Proposition\nDeliana, map 1455 (43.4, 51.4)",
    "Tier 0.5 has a row too, its first quest at Forever's Deliana")
Check(bar.text.shown == "12 / 60  steps", "the bar counts every step of the keys shown")
rows[1].waypoint(rows[1])
Check(waypoints[#waypoints] == "Legends of Maraudon (Cavindra)1443", "a row's pin is a waypoint to who gives the quest")
completed[7044] = true
frames[1].onEvent(frames[1], "QUEST_TURNED_IN")
Check(#timers == 1, "a quest handed in redraws it once, a moment later")
frames[1].onEvent(frames[1], "QUEST_ACCEPTED")
Check(#timers == 1, "however many events come with it")
timers[1]()
Check(panel.entries[1].text == "Maraudon  1 / 2" and panel.entries[1].waypoint == nil
    and panel.entries[1].sub == "The Scepter of Celebras\nCelebras the Redeemed, inside Maraudon",
    "the next quest inside the dungeon: no pin, the dungeon named")
level = 45
ns.Apply()
Check(#panel.entries == 2, "under a key's level it is left out, unless you have started it")
panel.opts.onClose()
ns.Apply()
Check(panel.shown == false and settings.attuneTracker == true, "its X hides it in this zone, the setting left on")
zone = 1453
ns.Apply()
Check(panel.shown == true, "in the next zone it is back")
level = 30
completed[7044], completed[4322] = nil, nil
ns.Apply()
Check(panel.shown == false, "with nothing to work on it hides")
level = 60
S.Set("attuneTracker", false)
Check(next(frames[1].events) == nil and panel.shown == false, "off again, it stops listening")

-------------------------------------------------------------------------------
--  The map pins
-------------------------------------------------------------------------------
local redraws, pins = 0, {}
local mapID = 1443
local map = {
    RemoveAllPinsByTemplate = function() redraws = redraws + 1 end,
    GetMapID = function() return mapID end,
    AcquirePin = function(_, _, entry) pins[#pins + 1] = entry end,
}
local added = 0
local MAP_GLOBALS = {
    hooksecurefunc = hooksecurefunc, CreateFrame = CreateFrame,
    CreateFromMixins = function(...)
        local out = {}
        for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do out[k] = v end end
        return out
    end,
    MapCanvasPinMixin = {},
    MapCanvasDataProviderMixin = { GetMap = function() return map end },
    WorldMapFrame = { AddDataProvider = function() added = added + 1 end, IsShown = function() return true end },
}
local before = #frames
Load("NaowhForever_Discovery/UI/AttunePins.lua", MAP_GLOBALS)
local boot = frames[#frames]
Check(#frames == before + 1 and boot.events.PLAYER_LOGIN, "loaded, only its login check")
boot.onEvent(boot, "PLAYER_LOGIN")
Check(added == 0 and #frames == before + 1 and redraws == 0, "off at login: no pins on the map, nothing listening")
S.Set("attuneMapPins", true)
Check(added == 1 and #pins == 1 and pins[1].quest == 7044 and pins[1].key == byDungeon["Maraudon"],
    "on: Desolace has Maraudon's next quest, at Cavindra")
mapID, pins = 1428, {}
S.Set("attuneMapPinSize", 24)
Check(#pins == 3, "Burning Steppes has three: the Shadowforge Key's, Molten Core's and the amulet's first")
local events = frames[#frames]
completed[3801] = true
events.onEvent(events, "QUEST_TURNED_IN")
local was = redraws
Check(events.events.QUEST_LOG_UPDATE, "a quest handed in waits for the quest log")
pins = {}
events.onEvent(events, "QUEST_LOG_UPDATE")
Check(redraws == was + 1 and not events.events.QUEST_LOG_UPDATE and #pins == 3 and pins[1].quest == 3802,
    "then redraws once, the key's pin now its next quest")
pins = {}
S.Set("attuneMapPins", false)
Check(#pins == 0 and next(events.events) == nil, "off: no pins, nothing listening")

-- Each new file is loaded, in the order its rules need.
local xml = Read("NaowhForever_Discovery/Discovery.xml")
local function At(file) return (xml:find(file, 1, true)) end
local data, rules, row, window = At("Data\\Attunements.lua"), At("\"Attunements.lua"), At("View\\AttuneRow.lua"),
    At("UI\\Window.lua")
Check(data and rules and row and window and data < rules and rules < row and row < window,
    "Discovery.xml loads the data, the rules, the row, then the window")
Check(At("UI\\AttuneTracker.lua") and At("UI\\AttunePins.xml") and At("UI\\AttuneSettings.lua"),
    "and the tracker, the pins and the settings page")

print("PASS attunements: " .. checks .. " checks")
