-- Run with Lua 5.1 from the repository root: the Group Finder. Loads the files its
-- GroupFinder.xml lists, in order, against stubs (with the real Naowh Score and the Dungeon
-- Journal's real kill and quest rules beside them), then checks the module is registered and
-- off by default, that nothing is made or registered while it is off, the card and its
-- messages (round trip, size, malformed input, opt-outs), the whispers (rate limit, self,
-- ignored and flooding senders, expiry with stale timers, the "No player named" filter), the
-- listings (activity to dungeon, chat lockdown), the probe, and what the hot paths cost.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)
local NOTHING = function() end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local TOC = "NaowhForever_GroupFinder/NaowhForever_GroupFinder.toc"
local toc = Read(TOC):gsub("\r\n", "\n")
local journalToc = Read("NaowhForever_DungeonJournal/NaowhForever_DungeonJournal.toc"):gsub("\r\n", "\n")
local function Line(text, field) return text:match("\n?## " .. field .. ":%s*([^\n]*)") end
check("the TOC has the modules' Interface line", Line(toc, "Interface") == Line(journalToc, "Interface"))
check("the TOC carries the modules' version", Line(toc, "Version") == Line(journalToc, "Version"))
check("the TOC is titled Group Finder", Line(toc, "Title") == "|cff0091edNaowh|r Forever: Group Finder")
check("the TOC needs the core and the BiS module (the Naowh Score)",
    Line(toc, "Dependencies") == "NaowhForever, NaowhForever_BiS")
check("the Journal is an optional dependency", Line(toc, "OptionalDeps") == "NaowhForever_DungeonJournal")
check("the TOC is in the NaowhUI group", Line(toc, "Group") == "NaowhUI")
check("the TOC has the addon's icon", Line(toc, "IconTexture") == Line(journalToc, "IconTexture"))
check("the TOC loads only its XML", toc:find("\nGroupFinder.xml\n", 1, true) ~= nil)
check("the packager moves the module out", Read(".pkgmeta"):find(
    "NaowhForever/NaowhForever_GroupFinder: NaowhForever_GroupFinder", 1, true) ~= nil)
local window = Read("Core/NaowhForever_Window.lua")
check("the window lists the module as its own addon, needing BiS", window:find(
    '{ name = "Group Finder", group = "ADVENTURE", navIcon = "search", settings = "GroupFinderSettings",\r\n'
    .. '      addon = "NaowhForever_GroupFinder", needs = { "NaowhForever_BiS" },', 1, true) ~= nil)
check("/nf groupfinder reaches the module", window:find('cmd == "groupfinder"', 1, true) ~= nil
    and window:find("ns.GroupFinderCommand(strtrim(msg)", 1, true) ~= nil)

local files = TocFiles("^NaowhForever_GroupFinder/.*%.lua$")
check("the module loads its files through its XML", #files == 6 and files[1]:find("GroupFinder.lua$") ~= nil)

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local ME = "Player-4613-006EB819"
local ME_PATTERN = ME:gsub("%-", "%%-")
local RESULT = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, AddOnMessageLockdown = 11,
    TargetOffline = 12 }

local GEAR, LINKS = {}, {}
for slot = 1, 18 do
    LINKS[slot] = "item:" .. slot
    GEAR[LINKS[slot]] = { 25, 3, "INVTYPE_CHEST" }
end

local function Boss(name, encounter, extra)
    local boss = { name = name, encounters = encounter and { encounter } or nil }
    for k, v in pairs(extra or {}) do boss[k] = v end
    return boss
end
local QUESTS = {
    { 168, "Collecting Memories", 14, "A" }, { 167, "Oh Brother", 15, "A" }, { 2040, "Underground Assault", 15, "A" },
    { 166, "The Defias Brotherhood", 22, "A" }, { 214, "Red Silk Bandanas", 17, "A" }, { 373, "The Unsent Letter", 22, "A" },
    { 5761, "Slaying the Beast", 9, "H" }, { 1654, "The Test of Righteousness", 22, "A", class = "PALADIN" },
    { 98815, "A Forever Quest", 20, "B" },
}
local DEADMINES = { key = "Deadmines", name = "The Deadmines", quests = { map = 36, quests = QUESTS }, wings = {
    { bosses = { Boss("Rhahk'Zor", 2741), Boss("Miner Johnson", nil, { rare = true }), Boss("Sneed's Shredder", 2742, { with = "Sneed" }),
        Boss("Sneed", 2742), Boss("Gilnid", 2743), Boss("Mr. Smite", 2745) } },
    { bosses = { Boss("Captain Greenskin", 2746), Boss("Edwin VanCleef", 2747), Boss("Cookie", 2748), Boss("Extra", 2749) } },
} }
local function Dungeon(key, name, map)
    return { key = key, name = name, quests = { map = map, quests = {} }, wings = {} }
end
local DUNGEONS = { DEADMINES,
    Dungeon("ScarletMonasteryGraveyard", "Scarlet Monastery - Graveyard", 189),
    Dungeon("ScarletMonasteryLibrary", "Scarlet Monastery - Library", 189),
    Dungeon("DireMaul", "Dire Maul", 429),
    Dungeon("ExcavationSite", "Excavation Site: Wetlands", 2998),
    Dungeon("SunkenTemple", "Sunken Temple", 109),
    Dungeon("LowerBlackrockSpire", "Lower Blackrock Spire", 229),
    Dungeon("UpperBlackrockSpire", "Upper Blackrock Spire", 229),
}
local BY_KEY = {}
for _, dungeon in ipairs(DUNGEONS) do BY_KEY[dungeon.key] = dungeon end

local ACTIVITIES = {
    [1] = { fullName = "The Deadmines", mapID = 36 },
    [2] = { fullName = "Scarlet Monastery - Graveyard", mapID = 189 },
    [3] = { fullName = "Dire Maul - East", mapID = 429 },
    [4] = { fullName = "Excavation Site", mapID = 2998 },
    [5] = { fullName = "The Temple of Atal'Hakkar", mapID = 109 },
    [6] = { fullName = "Blackrock Spire", mapID = 229 },
    [7] = { fullName = "Stormwind Stockade", mapID = 34 },
    [8] = { fullName = "Scarlet Monastery", mapID = 189 },
}

local RESULTS, INFOS, PLAYERS = {}, {}, {}
for id = 1, 50 do
    RESULTS[id] = id
    INFOS[id] = { searchResultID = id, leaderName = "Leader" .. id, numMembers = id % 5 + 1, age = id * 30,
        isDelisted = false, activityIDs = { (id - 1) % 5 + 1 }, partyGUID = "Party-" .. id }
    PLAYERS[id] = {}
    for m = 1, 5 do
        PLAYERS[id][m] = { name = "Member" .. id .. "-" .. m, level = 20 + m, classFilename = "WARRIOR",
            assignedRole = m == 1 and "TANK" or "DAMAGER", isLeader = m == 1, lfgRoles = {} }
    end
end

local function Fixture(values)
    local state = {
        now = 1000, frames = 0, events = {}, prefixes = {}, sent = {}, timers = {}, printed = {},
        filters = {}, ignored = {}, locked = false, result = 0, infoCalls = 0,
        onQuest = {}, complete = {}, done = {}, level = 20,
        kills = { [2741] = { n = 3 }, [2742] = { n = 2 }, [2743] = { n = 0 }, [2746] = { n = 120 }, [2747] = { n = 1 } },
        bis = true, roles = { tank = true, healer = false, dps = true },
    }
    local settings = {}
    for k, v in pairs(values or {}) do settings[k] = v end
    local function ModuleSettings(_, defaults)
        state.defaults = defaults
        local listeners, S = {}, {}
        function S.Get(key)
            local v = settings[key]
            if v == nil then return defaults[key] end
            return v
        end
        function S.Raw(key) return settings[key] end
        function S.Set(key, value)
            settings[key] = value
            for i = 1, #listeners do listeners[i](key, value) end
        end
        function S.OnChange(fn) listeners[#listeners + 1] = fn end
        return S
    end
    local frameMethods = {
        SetScript = function(frame, _, fn) frame.onEvent = fn end,
        RegisterEvent = function(frame, event)
            if frame.events[event] then return end
            frame.events[event] = true
            state.events[event] = (state.events[event] or 0) + 1
        end,
        UnregisterAllEvents = function(frame)
            for event in pairs(frame.events) do
                frame.events[event] = nil
                state.events[event] = state.events[event] - 1
                if state.events[event] == 0 then state.events[event] = nil end
            end
        end,
    }
    state.frameList = {}
    local cards = {}
    local pages = {}
    local journalSettings = { Get = function() return false end, OnChange = NOTHING }
    local Journal = {
        Settings = journalSettings, Team = {}, QuestPrereqs = {}, QuestMinLevel = {}, QuestChains = {},
        QuestChainNames = {}, QuestChainStarts = {}, QuestWhere = {}, QuestTurnIns = {}, QuestData = {},
        Get = function(key) return BY_KEY[key] end,
        Dungeons = function() return DUNGEONS end,
        Suggested = function() return DEADMINES end,
        CharacterData = function(key)
            if key == "journalKills" then return state.kills end
        end,
    }
    local BIS_LIST = { slots = {} }
    local SPEC = { key = "fury-warrior", name = "Fury Warrior" }
    local ns = {
        Apply = NOTHING,
        THEME = {},
        Journal = Journal,
        Print = function(text) state.printed[#state.printed + 1] = text end,
        UI = { ModuleSettings = ModuleSettings, RefreshPage = NOTHING },
        Shared = { Settings = {
            Page = function(key, store)
                local page = { key = key, store = store }
                function page.Card(_, spec) cards[#cards + 1] = spec end
                pages[key] = page
                return page
            end,
        } },
        BiS = {
            On = function() return state.bis end,
            Lists = { List = function() return BIS_LIST end, CurrentSpec = function() return SPEC end },
            Rankings = { Had = function(list)
                local have, total = 0, 0
                for slot = 1, 17 do
                    if list then total = total + 1 end
                    if slot % 2 == 0 then have = have + 1 end
                end
                return have, total - 3
            end },
        },
    }
    state.cards, state.pages, state.ns = cards, pages, ns
    local env
    env = setmetatable({
        NaowhForever = ns,
        Enum = { SendAddonMessageResult = RESULT },
        issecretvalue = function(v) return rawequal(v, SECRET) end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        hooksecurefunc = function(t, name, fn)
            local original = t[name]
            t[name] = function(...) original(...); fn(...) end
        end,
        CreateFrame = function()
            state.frames = state.frames + 1
            local frame = setmetatable({ events = {} }, { __index = frameMethods })
            state.frameList[#state.frameList + 1] = frame
            return frame
        end,
        GetTime = function() return state.now end,
        C_Timer = { After = function(delay, fn) state.timers[#state.timers + 1] = { at = state.now + delay, fn = fn } end },
        C_ChatInfo = {
            RegisterAddonMessagePrefix = function(prefix) state.prefixes[#state.prefixes + 1] = prefix end,
            SendAddonMessage = function(prefix, text, channel, target)
                if state.result ~= RESULT.AddonMessageThrottle and state.result ~= RESULT.AddOnMessageLockdown then
                    state.sent[#state.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
                end
                return state.result
            end,
            InChatMessagingLockdown = function() return state.locked end,
        },
        ChatFrameUtil = {
            AddMessageEventFilter = function(event, fn) state.filters[event] = fn end,
            RemoveMessageEventFilter = function(event, fn)
                if state.filters[event] == fn then state.filters[event] = nil end
            end,
        },
        ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing.",
        C_FriendList = { IsIgnored = function(name) return state.ignored[name] == true end },
        C_LFGListRoles = { GetRoles = function() return state.roles end },
        C_LFGList = {
            GetSearchResults = function() return #RESULTS, RESULTS end,
            GetSearchResultInfo = function(id)
                state.infoCalls = state.infoCalls + 1
                return INFOS[id]
            end,
            GetSearchResultPlayerInfo = function(id, m) return PLAYERS[id] and PLAYERS[id][m] end,
            GetActivityInfoTable = function(id) return ACTIVITIES[id] end,
        },
        C_AddOns = { IsAddOnLoaded = function() return true end },
        C_QuestLog = {
            IsOnQuest = function(id) return state.onQuest[id] == true end,
            IsComplete = function(id) return state.complete[id] == true end,
            IsQuestFlaggedCompleted = function(id) return state.done[id] == true end,
            GetTitleForQuestID = function() return nil end,
        },
        C_Item = {
            GetDetailedItemLevelInfo = function(link) local item = GEAR[link] return item and item[1] end,
            GetItemInfo = function(link) local item = GEAR[link] if item then return "x", link, item[2] end end,
            GetItemInfoInstant = function(link) local item = GEAR[link] if item then return 1, "", "", item[3] end end,
        },
        GetInventoryItemLink = function(_, slot) return LINKS[slot] end,
        UnitGUID = function(unit) if unit == "player" then return ME end end,
        UnitName = function() return "Die Man" end,
        UnitClass = function() return "Warrior", "WARRIOR", 1 end,
        UnitLevel = function() return state.level end,
        UnitFactionGroup = function() return "Alliance" end,
        GetClassInfo = function(id) return id == 1 and "Warrior" or "Class" .. id end,
    }, { __index = _G })
    env._G = env
    Load({ "NaowhForever_BiS/NaowhScore/Data/Formula.lua", "NaowhForever_BiS/NaowhScore/Score.lua",
        "NaowhForever_DungeonJournal/Quests.lua", "NaowhForever_DungeonJournal/Kills.lua" }, env)
    Load(files, env)
    ns.Apply()
    state.GF = ns.GroupFinder
    state.S = ns.GroupFinderSettings
    function state.Advance(seconds)
        local target = state.now + seconds
        while true do
            local first
            for i, timer in ipairs(state.timers) do
                if timer.at <= target and (not first or timer.at < state.timers[first].at) then first = i end
            end
            if not first then break end
            local timer = table.remove(state.timers, first)
            if timer.at > state.now then state.now = timer.at end
            timer.fn()
        end
        state.now = target
    end
    function state.Frame(event)
        for _, frame in ipairs(state.frameList) do
            if frame.events[event] then return frame end
        end
    end
    return state
end

local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

do
    local state = Fixture()
    local GF = state.GF
    check("the module is off by default", state.defaults.enabled == false and GF.On() == false)
    check("the card shares everything once it is on", state.defaults.shareScore == true
        and state.defaults.shareKills == true and state.defaults.shareQuests == true and state.defaults.shareBis == true)
    check("off: no frame made", state.frames == 0)
    check("off: no event registered", Count(state.events) == 0)
    check("off: no prefix registered", #state.prefixes == 0)
    check("off: no chat filter", next(state.filters) == nil)
    check("off: no timer", #state.timers == 0)
    check("off: nothing sent", GF.Comms.Ping("Bob") == nil and #state.sent == 0)
    check("off: the comms are not listening", GF.Comms.On() == false)
    check("off: a filter call left behind hides nothing",
        GF.Comms.Filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Bob' is currently playing.") == false)

    state.S.Set("enabled", true)
    check("on: the prefix registered once", #state.prefixes == 1 and state.prefixes[1] == "NaowhLFG")
    check("on: addon messages heard", state.events.CHAT_MSG_ADDON == 1)
    check("on: Forever's search results heard", state.events.LFG_LIST_SEARCH_RESULTS_RECEIVED == 1
        and state.events.LFG_LIST_SEARCH_RESULT_UPDATED == 1)
    check("on: the 'No player named' filter installed", state.filters.CHAT_MSG_SYSTEM == GF.Comms.Filter)
    local made = state.frames
    state.S.Set("enabled", false)
    check("off again: every event unregistered", Count(state.events) == 0)
    check("off again: the filter removed", state.filters.CHAT_MSG_SYSTEM == nil)
    state.S.Set("enabled", true)
    check("on again: the frames are reused", state.frames == made)
    check("on again: the prefix is not registered twice", #state.prefixes == 1)
    state.ns.Apply()
    check("a profile reload keeps one registration each", state.events.CHAT_MSG_ADDON == 1)

    check("the settings page declares one card", #state.cards == 1 and state.pages["Group Finder/Settings"] ~= nil)
    local card = state.cards[1]
    check("the card has four switches", #card.rows == 4)
    for _, row in ipairs(card.rows) do
        check(row.label .. "'s help is one short sentence", #row.help < 100 and select(2, row.help:gsub("%.", "")) == 1)
        check(row.label .. " waits for the module", row.needs ~= nil)
    end
    check("the card's help is one short sentence", #card.help < 100 and select(2, card.help:gsub("%.", "")) == 1)
end

local function Same(a, b)
    if a.class ~= b.class or a.level ~= b.level or a.roles ~= b.roles or a.spec ~= b.spec or a.score ~= b.score
        or a.bisHave ~= b.bisHave or a.bisTotal ~= b.bisTotal or a.dungeon ~= b.dungeon
        or a.hasKills ~= b.hasKills or a.hasQuests ~= b.hasQuests or a.nKills ~= b.nKills
        or a.nHave ~= b.nHave or a.nNeed ~= b.nNeed then
        return false
    end
    for _, list in ipairs({ "kills", "have", "need" }) do
        if #a[list] ~= #b[list] then return false end
        for i = 1, #a[list] do
            if a[list][i] ~= b[list][i] then return false end
        end
    end
    return true
end

local SIZES = {}
do
    local state = Fixture({ enabled = true })
    local Card = state.GF.Card
    state.onQuest[168], state.onQuest[2040], state.complete[2040] = true, true, true
    state.done[167] = true
    state.ns.Journal.QuestMinLevel[373] = 30
    local mine = Card.Mine("Deadmines")
    check("your card: GUID, class, level", mine.guid == ME and mine.class == 1 and mine.level == 20)
    check("your card: the game's saved roles", mine.roles == Card.TANK + Card.DAMAGE)
    check("your card: the BiS list's spec", mine.spec == "fury-warrior")
    check("your card: the Naowh Score in tenths", mine.score == 189)
    check("your card: BiS have and total", mine.bisHave == 8 and mine.bisTotal == 14)
    check("your card: kills of each counted boss, in order, capped",
        mine.hasKills and mine.nKills == 8 and table.concat(mine.kills, ",") == "3,2,0,0,99,1,0,0")
    check("your card: quests in your log, and those you still need, for you only",
        mine.hasQuests and table.concat(mine.have, ",") == "168,2040" and table.concat(mine.need, ",") == "166,214,98815")

    local reply = Card.Reply(42, mine)
    SIZES.reply = #reply
    check("a card reply is one line", reply == "1 C " .. ME .. " 42 1 20 TD fury-warrior 189 8/14 Deadmines "
        .. "3,2,0,0,99,1,0,0 168,2040/166,214,98815")
    local back = Card.New()
    local _
    local kind, guid, id, note = Card.Decode(reply, back)
    check("a card reply reads back", kind == "C" and guid == ME and id == 42 and note == nil and Same(back, mine))

    local apply = Card.Application(7, mine, Card.CleanNote("  Tank,   |cffff0000quests|r welcome  "))
    SIZES.apply = #apply
    kind, guid, id, note = Card.Decode(apply, back)
    check("an application reads back with its note", kind == "A" and guid == ME and id == 7 and Same(back, mine))
    check("the note keeps no escape codes", note == "Tank, quests welcome")

    local ask = Card.Ask(9, "Deadmines")
    SIZES.ask = #ask
    kind, guid, id, note = Card.Decode(ask, back)
    check("a card request reads back", ask == "1 Q " .. ME .. " 9 Deadmines" and kind == "Q" and guid == ME and id == 9
        and note == "Deadmines")
    kind, _, id, note = Card.Decode(Card.Ask(10), back)
    check("a card request without a dungeon", kind == "Q" and id == 10 and note == nil)
    for _, short in ipairs({ "K", "X", "D" }) do
        local text = Card.Short(short, 77)
        SIZES[short] = #text
        kind, guid, id = Card.Decode(text, back)
        check(short .. " reads back", kind == short and guid == ME and id == 77)
    end

    check("a note is cleaned: printable ASCII, one space between words, 60 bytes at most",
        Card.CleanNote("a\tb\226\128\148c  d|Hitem:6948|h[Hearthstone]|h |TInterface\\Icons\\x:0|t!") == "a bc d[Hearthstone] !"
        and #Card.CleanNote(string.rep("word ", 30)) <= Card.NOTE_MAX
        and Card.CleanNote(nil) == "")

    local big = Card.New()
    big.guid = "Player-99999-ABCDEF0123456789"
    big.class, big.level, big.roles, big.spec, big.score = 11, 60, 7, "restoration-shaman-healer-pvp-ab", 99999
    big.bisHave, big.bisTotal, big.dungeon = 40, 40, "ScarletMonasteryCathedralAndMoreWingsXY"
    big.hasKills, big.nKills, big.hasQuests, big.nHave, big.nNeed = true, Card.MAX_KILLS, true, Card.MAX_QUESTS, Card.MAX_QUESTS
    for i = 1, Card.MAX_KILLS do big.kills[i] = Card.KILL_CAP end
    for i = 1, Card.MAX_QUESTS do big.have[i], big.need[i] = 900000 + i, 990000 + i end
    local longNote = Card.CleanNote(string.rep("x", 80))
    local biggest = Card.Application(Card.ID_MAX, big, longNote)
    check("an application at every limit still fits in one message", biggest and #biggest <= Card.MAX_BYTES)
    kind, _, _, note = Card.Decode(biggest, back)
    check("it reads back with its note, its quests and then its kills left off to fit", kind == "A"
        and note == longNote and back.hasQuests and back.nHave == 0 and back.nNeed == 0 and not back.hasKills)

    big.guid, big.spec, big.score, big.dungeon = "Player-4613-006EB819", "beast-mastery-hunter", 612, "DireMaul"
    big.nKills = 19
    for i = 20, Card.MAX_KILLS do big.kills[i] = nil end
    for i = 1, Card.MAX_QUESTS do big.have[i], big.need[i] = 98800 + i, 98900 + i end
    biggest = Card.Application(Card.ID_MAX, big, longNote)
    SIZES.biggest = #biggest
    kind, _, _, note = Card.Decode(biggest, back)
    check("the biggest real application (Dire Maul's 19 bosses, a full note) keeps every kill",
        kind == "A" and note == longNote and back.nKills == 19 and back.nHave > 0 and back.nHave < Card.MAX_QUESTS)
    local fullReply = Card.Reply(Card.ID_MAX, big)
    check("the biggest reply fits", #fullReply <= Card.MAX_BYTES and Card.Decode(fullReply, back) == "C")

    local GOOD = "1 C " .. ME .. " 42 1 20 TD fury-warrior 154 8/14 Deadmines 3,2,0 168/166"
    check("a well-formed reply passes", Card.Decode(GOOD, back) == "C")
    local BAD = {
        "", "1", "2 C " .. ME .. " 42 1 20 TD - - - - - -", "1 Z " .. ME .. " 42",
        "1 C Creature-0-1-2-3-4 42 1 20 TD - - - - - -", "1 K " .. ME .. " 0", "1 K " .. ME .. " 12345",
        "1 K " .. ME .. " 4 extra", "1 K " .. ME .. " 4 ", "1 K  " .. ME .. " 4", "1 K " .. ME .. " -4",
        GOOD .. " extra", GOOD .. " ",
        GOOD:gsub(" TD ", " DT "), GOOD:gsub(" TD ", " TT "), GOOD:gsub(" TD ", " X "),
        GOOD:gsub(" 42 1 20 ", " 42 1 0 "), GOOD:gsub(" 42 1 20 ", " 42 1 101 "), GOOD:gsub(" 42 1 20 ", " 42 0 20 "),
        GOOD:gsub(" 8/14 ", " 15/14 "), GOOD:gsub(" 8/14 ", " 8/0 "), GOOD:gsub(" 8/14 ", " 8-14 "),
        GOOD:gsub(" 154 ", " 15.4 "), GOOD:gsub("fury%-warrior", "Fury"), GOOD:gsub(" Deadmines ", " deadmines "),
        GOOD:gsub(" Deadmines ", " - "), GOOD:gsub(" 3,2,0 ", " 3,,0 "), GOOD:gsub(" 3,2,0 ", " 3,2, "),
        GOOD:gsub(" 3,2,0 ", " 100 "), GOOD:gsub(" 3,2,0 ", " " .. string.rep("1,", 30) .. "1 "),
        GOOD:gsub(" 168/166$", " 168"), GOOD:gsub(" 168/166$", " 168/1/66"), GOOD:gsub(" 168/166$", " 0/166"),
        GOOD:gsub(" 168/166$", " 1,2,3,4,5,6,7,8,9/"),
        "1 A " .. ME .. " 42 1 20 TD - - - Deadmines 3 / note|cff", "1 A " .. ME .. " 42 1 20 TD - - - - - - "
            .. string.rep("n", 61),
        "1 Q " .. ME .. " 4 Deadmines extra", "1 Q " .. ME .. " 4 dead",
        string.rep("1", 256),
    }
    for i, text in ipairs(BAD) do
        check("malformed message " .. i .. " is rejected", Card.Decode(text, back) == nil)
    end
    check("a number is not a message", Card.Decode(12, back) == nil)
    check("a reply needs a card to fill", Card.Decode(GOOD, nil) == nil)

    state.S.Set("shareScore", false)
    state.S.Set("shareKills", false)
    local partial = Card.Mine("Deadmines")
    check("opted out of score and kills: neither is on the card", partial.score == nil and not partial.hasKills)
    local text = Card.Reply(1, partial)
    check("opted out fields go as -", text:find(" fury%-warrior %- 8/14 Deadmines %- 168,2040/166,214,98815$") ~= nil)
    Card.Decode(text, back)
    check("and read back as not shared", back.score == nil and back.hasKills == false and back.hasQuests == true)
    state.S.Set("shareQuests", false)
    state.S.Set("shareBis", false)
    text = Card.Reply(1, Card.Mine("Deadmines"))
    check("all four off: class, level, roles and spec only", text == "1 C " .. ME .. " 1 1 20 TD fury-warrior - - Deadmines - -")
    Card.Decode(text, back)
    check("and none of them read back", back.score == nil and back.bisTotal == nil and not back.hasKills and not back.hasQuests)
    state.bis = false
    text = Card.Reply(1, Card.Mine(nil, 0))
    check("BiS module off and no dungeon: no spec, no dungeon, no roles",
        text == "1 C " .. ME .. " 1 1 20 - - - - - - -")
    check("an unknown dungeon is left off", Card.Mine("Nowhere").dungeon == nil)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms, Card = GF.Comms, GF.Card
    local fired = {}
    for _, what in ipairs({ "card", "noreply", "offline", "applicant", "received", "withdrawn", "expired",
        "applicantExpired" }) do
        GF.Listen(what, function(a) fired[#fired + 1] = what; fired[what] = a end)
    end

    for i = 1, 15 do Comms.Ping("Player" .. i) end
    check("a burst of ten goes at once", #state.sent == Comms.BURST)
    check("the rest wait in the queue", Comms.Queued() == 5)
    check("every one is a whisper on the prefix", state.sent[1].channel == "WHISPER" and state.sent[1].prefix == "NaowhLFG"
        and state.sent[1].target == "Player1")
    state.Advance(1)
    check("then one a second", #state.sent == Comms.BURST + 1)
    state.Advance(4)
    check("until the queue is empty", #state.sent == 15 and Comms.Queued() == 0)
    check("the same whisper twice while it waits is queued once", Comms.Send("Bob", "1 K x 1")
        and Comms.Send("Bob", "1 K x 1") and Comms.Queued() == 1)
    state.Advance(20)
    check("and goes once", #state.sent == 16)

    state.locked = true
    Comms.Send("Bob", "1 K x 2")
    check("nothing goes in chat lockdown", #state.sent == 16 and Comms.Queued() == 1)
    state.locked = false
    state.Advance(2)
    check("it goes once the lockdown ends", #state.sent == 17)
    state.result = RESULT.AddonMessageThrottle
    Comms.Send("Bob", "1 K x 3")
    check("the game's throttle keeps it queued", Comms.Queued() == 1)
    state.result = 0
    state.Advance(1)
    check("and it goes a second later", Comms.Queued() == 0 and #state.sent == 18)
    for i = 1, Comms.QUEUE_MAX + 5 do
        state.locked = true
        Comms.Send("Q" .. i, "1 K x " .. i)
    end
    check("the queue is bounded", Comms.Queued() == Comms.QUEUE_MAX)
    state.locked = false
    state.Advance(60)
    check("and drains", Comms.Queued() == 0)
    state.Advance(Comms.BURST / Comms.RATE)

    local before = #state.sent
    Comms.OnMessage(Card.Ask(5, "Deadmines"), "Die Man")
    check("a message from yourself is dropped", Comms.dropped.self == 1 and #state.sent == before)
    Comms.OnMessage(Card.Ask(5, "Deadmines"), "Someone Else-Realm")
    check("a message with your own GUID is dropped", Comms.dropped.self == 2 and #state.sent == before)
    state.ignored["Rude Guy"] = true
    Comms.OnMessage("1 Q Player-1-00000001 5 -", "Rude Guy-Realm")
    check("an ignored player is dropped", Comms.dropped.ignored == 1 and #state.sent == before)
    Comms.OnMessage("1 Q nonsense", "Bob")
    check("a malformed message is dropped", Comms.dropped.malformed == 1 and #state.sent == before)

    Comms.OnMessage("1 Q Player-1-00000001 5 Deadmines", "Bob")
    check("a card request is answered with your card for that dungeon", #state.sent == before + 1
        and state.sent[#state.sent].target == "Bob"
        and state.sent[#state.sent].text:find("^1 C " .. ME_PATTERN .. " 5 1 20 TD fury%-warrior %d+ 8/14 Deadmines ") ~= nil)
    for _ = 1, Comms.SENDER_MAX + 3 do Comms.OnMessage("1 Q Player-1-00000002 6 -", "Spammer") end
    check("a sender over its cap is dropped", Comms.dropped.flood == 3)
    state.Advance(Comms.SENDER_WINDOW + 1)
    Comms.OnMessage("1 Q Player-1-00000002 6 -", "Spammer")
    check("and heard again after its window", Comms.dropped.flood == 3)

    local nonce = Comms.Ping("Carol", "Deadmines")
    local asked = state.sent[#state.sent].text
    check("a ping asks for a card", asked == "1 Q " .. ME .. " " .. nonce .. " Deadmines")
    Comms.OnMessage("1 C Player-1-00000003 " .. (nonce + 1) .. " 1 20 TD - - - - - -", "Carol")
    check("a card nobody asked for is dropped", Comms.dropped.unasked == 1 and fired.card == nil)
    state.now = state.now + 0.25
    Comms.OnMessage("1 C Player-1-00000003 " .. nonce .. " 5 31 H - 264 3/9 Deadmines 1,0,2 /166", "Carol-OtherRealm")
    check("the answer to a ping comes back as a card, kept by name", fired.card ~= nil
        and Comms.CardOf("carol").level == 31 and Comms.CardOf("Carol").guid == "Player-1-00000003")
    check("the ping is done with", #Comms.pings == 0)
    check("the probe can describe it", GF.Describe(Comms.CardOf("Carol")):find("score 26.4; BiS 3/9; Deadmines; kills 1,0,2; quests 0 in log, 1 needed") ~= nil)

    local id = Comms.Apply("Dave", "Deadmines", Card.HEALER, "Can heal, need 2 quests")
    local sentApp = state.sent[#state.sent].text
    check("an application whispers your card with your roles and note", sentApp:find("^1 A " .. ME_PATTERN .. " " .. id
        .. " 1 20 H fury%-warrior %d+ 8/14 Deadmines .- Can heal, need 2 quests$") ~= nil)
    Comms.OnMessage("1 K Player-1-00000004 " .. id, "Dave")
    check("the leader's K marks it received", fired.received ~= nil and Comms.sent[1].acked == true)
    Comms.OnMessage("1 D Player-1-00000004 " .. id, "Dave")
    check("a decline is silent: no event, it just expires", Comms.sent[1].declined == true and fired.expired == nil)

    Comms.OnMessage("1 A Player-1-00000005 12 3 25 D - 201 - Deadmines 2,2 / Hi there", "Erin")
    local applicant = Comms.applicants[1]
    check("an application is kept with its card and note", fired.applicant == applicant and applicant.note == "Hi there"
        and applicant.card.class == 3 and applicant.card.score == 201 and applicant.guid == "Player-1-00000005")
    check("and acknowledged with K", state.sent[#state.sent].text == "1 K " .. ME .. " 12"
        and state.sent[#state.sent].target == "Erin")
    Comms.OnMessage("1 X Player-1-00000005 12", "Erin")
    check("a withdrawal takes the applicant off", fired.withdrawn ~= nil and #Comms.applicants == 0)
    Comms.OnMessage("1 A Player-1-00000006 13 3 25 D - - - - - -", "Finn")
    check("declining whispers D and takes the applicant off", Comms.Decline("finn") and #Comms.applicants == 0
        and state.sent[#state.sent].text == "1 D " .. ME .. " 13")
    check("withdrawing your application whispers X", Comms.Withdraw(id) and #Comms.sent == 0
        and state.sent[#state.sent].text == "1 X " .. ME .. " " .. id)

    local frame = state.Frame("CHAT_MSG_ADDON")
    before = #state.sent
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", "1 Q Player-1-00000007 1 -", "WHISPER", SECRET)
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", SECRET, "WHISPER", "Gil")
    frame:onEvent("CHAT_MSG_ADDON", SECRET, "1 Q Player-1-00000007 1 -", "WHISPER", "Gil")
    check("secret arguments are never read", Comms.dropped.secret == 2 and #state.sent == before)
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", "1 Q Player-1-00000007 1 -", "PARTY", "Gil")
    frame:onEvent("CHAT_MSG_ADDON", "OtherAddon", "1 Q Player-1-00000007 1 -", "WHISPER", "Gil")
    check("only whispers on the prefix are heard", #state.sent == before)
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", "1 Q Player-1-00000007 1 -", "WHISPER", "Gil")
    check("a whisper on the prefix is answered", #state.sent == before + 1 and state.sent[#state.sent].target == "Gil")
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms = GF.Comms
    local fired = {}
    GF.Listen("noreply", function(ping) fired[#fired + 1] = "noreply " .. ping.name end)
    GF.Listen("expired", function(app) fired[#fired + 1] = "expired " .. app.name end)
    Comms.Apply("Leader", "Deadmines", 1, "")
    check("an application schedules the sweep", #state.timers == 1)
    local stale = state.timers[1]
    Comms.Ping("Pinged")
    check("a sooner ping schedules a sooner sweep", #state.timers == 2 and state.timers[2].at < stale.at)
    table.remove(state.timers, 1)
    state.now = stale.at
    stale.fn()
    check("the superseded sweep does nothing", #fired == 0 and #Comms.sent == 1 and #Comms.pings == 1)
    check("and says it was stale", Comms.Sweep(-1) == false)
    state.now = 1000
    state.Advance(Comms.PING_WAIT)
    check("the ping expires with no answer", fired[1] == "noreply Pinged" and #Comms.pings == 0)
    check("and the next sweep waits for the application", #state.timers == 1)
    local later = state.timers[1]
    state.S.Set("enabled", false)
    table.remove(state.timers, 1)
    state.now = later.at
    later.fn()
    check("turning it off makes a pending sweep stale", #fired == 1)
    state.S.Set("enabled", true)
    state.now = 1000
    Comms.Apply("Leader", "Deadmines", 1, "")
    state.Advance(Comms.APP_TTL)
    check("an application expires after its time", fired[#fired] == "expired Leader" and #Comms.sent == 0)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms = GF.Comms
    local offline
    GF.Listen("offline", function(ping) offline = ping.name end)
    local filter = state.filters.CHAT_MSG_SYSTEM
    Comms.Ping("Hal Brand")
    check("the line for a name just whispered is hidden",
        filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Hal Brand' is currently playing.") == true)
    check("and its ping ends as offline", offline == "Hal Brand" and #Comms.pings == 0)
    check("the line for anyone else stays",
        filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Ivy' is currently playing.") == false)
    check("other system lines stay", filter(nil, "CHAT_MSG_SYSTEM", "You are now AFK.") == false)
    check("a secret line is not read", filter(nil, "CHAT_MSG_SYSTEM", SECRET) == false)
    state.Advance(Comms.NOT_FOUND_WINDOW + 1)
    check("the name's line shows again after a moment",
        filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Hal Brand' is currently playing.") == false)
    Comms.Ping("Jo")
    state.S.Set("enabled", false)
    check("off: the filter is gone and hides nothing", state.filters.CHAT_MSG_SYSTEM == nil
        and filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Jo' is currently playing.") == false)
    state.S.Set("enabled", true)
    state.result = RESULT.TargetOffline
    offline = nil
    Comms.Ping("Kim")
    check("the game's own offline answer ends the ping too", offline == "Kim" and #Comms.pings == 0)
end

do
    local state = Fixture({ enabled = true })
    local Listings = state.GF.Listings
    check("an activity named as the dungeon", Listings.DungeonOf(1) == "Deadmines")
    check("a Scarlet Monastery wing by its name", Listings.DungeonOf(2) == "ScarletMonasteryGraveyard")
    check("a dungeon's part by its prefix", Listings.DungeonOf(3) == "DireMaul")
    check("a shorter name when only one dungeon fits", Listings.DungeonOf(4) == "ExcavationSite")
    check("another name by its instance", Listings.DungeonOf(5) == "SunkenTemple")
    check("an instance two dungeons share is not guessed", Listings.DungeonOf(6) == nil)
    check("a name that fits several wings is not guessed", Listings.DungeonOf(8) == nil)
    check("a dungeon the Journal lacks is none", Listings.DungeonOf(7) == nil and Listings.DungeonOf(99) == nil)

    local n = Listings.Read()
    check("fifty listings read", n == 50 and Listings.state == "ready")
    local entry = Listings.entries[4]
    check("a listing's leader, dungeon, size and age", entry.leader == "Leader4" and entry.dungeon == "ExcavationSite"
        and entry.numMembers == 5 and entry.age == 120 and entry.delisted == false and entry.party == "Party-4")
    check("its members, up to five", entry.nMembers == 5 and entry.members[1].role == "TANK"
        and entry.members[1].leader and entry.members[2].level == 22 and entry.members[1].class == "WARRIOR")
    local calls = state.infoCalls
    check("a second read without a new search reads nothing", Listings.Read() == 50 and state.infoCalls == calls)

    state.locked = true
    calls = state.infoCalls
    check("chat lockdown: nothing read", Listings.Read(true) == 0 and Listings.state == "locked" and state.infoCalls == calls)
    state.locked = false
    INFOS[2].leaderName = SECRET
    check("a listing with a secret leader is skipped", Listings.Read() == 49)
    INFOS[2].leaderName = "Leader2"
    local heard, updated
    state.GF.Listen("listings", function() heard = true end)
    state.GF.Listen("listing", function(e) updated = e end)
    local frame = state.Frame("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("a new search is heard and read on the next ask", heard and Listings.searched and Listings.Read() == 50)
    INFOS[1].age = 999
    frame:onEvent("LFG_LIST_SEARCH_RESULT_UPDATED", 1)
    check("an updated listing is read again alone", updated == Listings.entries[1] and Listings.entries[1].age == 999)
    frame:onEvent("LFG_LIST_SEARCH_RESULT_UPDATED", SECRET)
    check("a secret update is ignored", updated == Listings.entries[1])
    INFOS[1].age = 30
    state.S.Set("enabled", false)
    check("off: listings forgotten", Listings.n == 0 and Listings.state == "none" and next(state.events) == nil)
end

do
    local state = Fixture()
    local ns = state.ns
    ns.GroupFinderCommand("probe")
    check("the probe prints its lines", #state.printed >= 8 and state.printed[1] == "Group Finder probe:")
    for _, line in ipairs(state.printed) do check("the probe prints plain ASCII: " .. line, not line:find("[\128-\255]")) end
    check("it reads the last search", table.concat(state.printed, "\n"):find("Listings from your last search: 50", 1, true) ~= nil)
    check("it shows how an activity maps", table.concat(state.printed, "\n"):find(
        "1. Leader1: activity 1 \"The Deadmines\" map 36 -> Deadmines", 1, true) ~= nil)
    check("probing while off registers nothing", #state.prefixes == 0 and state.frames == 0)
    ns.GroupFinderCommand("ping Bob")
    check("ping needs the module on", state.printed[#state.printed]:find("off") ~= nil and #state.sent == 0)
    state.S.Set("enabled", true)
    ns.GroupFinderCommand("ping Die Man")
    check("ping refuses yourself", #state.sent == 0)
    ns.GroupFinderCommand("ping Lea Sunfall")
    check("ping whispers a Q to a name with a space", #state.sent == 1 and state.sent[1].target == "Lea Sunfall"
        and state.sent[1].text:find("^1 Q ") ~= nil)
    local nonce = tonumber(state.sent[1].text:match("^1 Q %S+ (%d+)"))
    state.now = state.now + 0.08
    state.GF.Comms.OnMessage("1 C Player-1-00000009 " .. nonce .. " 8 24 D - 211 - Deadmines 1 -", "Lea Sunfall")
    check("and prints the answer and the round trip", state.printed[#state.printed]:find(
        "Lea Sunfall answered in 80 ms: Class8 24; roles damage; score 21.1; BiS not shared; Deadmines; kills 1.", 1, true) ~= nil)
    ns.GroupFinderCommand("ping Nobody")
    state.Advance(state.GF.Comms.PING_WAIT)
    check("no answer is said after its wait", state.printed[#state.printed]:find("no answer from Nobody", 1, true) ~= nil)
    ns.GroupFinderCommand("")
    check("anything else prints the usage", state.printed[#state.printed]:find("probe", 1, true) ~= nil)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Card, Listings = GF.Card, GF.Listings
    state.onQuest[168], state.onQuest[2040] = true, true
    local reply
    Measure("your card built and written", 0.1, function() reply = Card.Reply(42, Card.Mine("Deadmines")) end)
    local card = Card.New()
    Measure("a card read", 0.05, function() Card.Decode(reply, card) end)
    Measure("fifty listings read", 0.5, function() Listings.Read(true) end)
end

print(("Message sizes: Q %d, C %d, A %d (with a note), K %d, the biggest A %d bytes of %d."):format(
    SIZES.ask, SIZES.reply, SIZES.apply, SIZES.K, SIZES.biggest, 255))
print(("test-group-finder: %d checks passed"):format(checks))
