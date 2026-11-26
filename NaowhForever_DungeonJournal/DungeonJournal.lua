-- DungeonJournal.lua: the Dungeon Journal's settings, its dungeon and faction registry and its public API (ns.Journal).
local ns = _G.NaowhForever

local F = ns.FEATURES.journal

local ENGLISH = "enUS"
local INSTANCE_ID = 8
local BYTE = 255
local ZONE = Enum.UIMapType.Zone
local COLORED = "|cff%02x%02x%02x%s|r"
local FACTION_TABS = { "reputation", "pvp" }
local WING_MAPS = {
    [302] = "ScarletMonasteryGraveyard",
    [303] = "ScarletMonasteryLibrary",
    [304] = "ScarletMonasteryArmory",
    [305] = "ScarletMonasteryCathedral",
}
local SUBZONES = {
    ["Chamber of Atonement"] = "ScarletMonasteryGraveyard",
    ["Forlorn Cloister"] = "ScarletMonasteryGraveyard",
    ["Honor's Tomb"] = "ScarletMonasteryGraveyard",
    ["Huntsman's Cloister"] = "ScarletMonasteryLibrary",
    ["Gallery of Treasures"] = "ScarletMonasteryLibrary",
    ["Athenaeum"] = "ScarletMonasteryLibrary",
    ["Training Grounds"] = "ScarletMonasteryArmory",
    ["Footman's Armory"] = "ScarletMonasteryArmory",
    ["Crusader's Armory"] = "ScarletMonasteryArmory",
    ["Hall of Champions"] = "ScarletMonasteryArmory",
    ["Chapel Gardens"] = "ScarletMonasteryCathedral",
    ["Crusader's Chapel"] = "ScarletMonasteryCathedral",
    ["Chamber of Battle"] = "LowerBlackrockSpire",
    ["Halycon's Lair"] = "LowerBlackrockSpire",
    ["Mok'Doom"] = "LowerBlackrockSpire",
    ["Skitterweb Tunnels"] = "LowerBlackrockSpire",
    ["The Storehouse"] = "LowerBlackrockSpire",
    ["Tazz'Alaor"] = "LowerBlackrockSpire",
    ["Tazz'Alor"] = "LowerBlackrockSpire",
    ["Blackrock Stadium"] = "UpperBlackrockSpire",
    ["Dragonspire Hall"] = "UpperBlackrockSpire",
    ["Hall of Binding"] = "UpperBlackrockSpire",
    ["Spire Throne"] = "UpperBlackrockSpire",
    ["The Furnace"] = "UpperBlackrockSpire",
    ["The Molten Span"] = "UpperBlackrockSpire",
    ["The Rookery"] = "UpperBlackrockSpire",
    ["Warpwood Quarter"] = "DireMaulEast",
    ["The Shrine of Eldretharr"] = "DireMaulEast",
    ["The Hidden Reach"] = "DireMaulEast",
    ["The Conservatory"] = "DireMaulEast",
    ["Capital Gardens"] = "DireMaulWest",
    ["Court of the Highborne"] = "DireMaulWest",
    ["Prison of Immol'thar"] = "DireMaulWest",
    ["Gordok Commons"] = "DireMaulNorth",
    ["Halls of Destruction"] = "DireMaulNorth",
    ["Gordok's Seat"] = "DireMaulNorth",
}
local SPLITS = { DireMaul = { english = "Dire Maul", into = { "DireMaulEast", "DireMaulWest", "DireMaulNorth" } } }
local SPLIT_DONE_KEY = "journalSplitDone"
local RECORD_STORES = { "journalRuns", "journalLoot" }
local TRASH_KEY, PINS_KEY, BIS_KEY = "journalTrash", "journalMapPins", "bisLists"
local ENTRANCE_KEY = "entrance"
local MOVED_WING = 1

local FloorHere

local TEXT_TURNED_ON = ns.L("Dungeon Journal turned on. Turn it off in its settings page.")
local TEXT_ENTRANCE = ns.L(" (entrance)")

local S = ns.UI.ModuleSettings("journal", {
    enabled = F.enabled,
    mapPanel = F.mapPanel,
    mapFactions = F.mapFactions,
    mapEntrances = F.mapEntrances,
    entranceJournal = F.entranceJournal,
    itemSources = F.itemSources,
    favourites = F.favourites,
    rareAlert = F.rareAlert,
    mapQuestPins = F.mapQuestPins,
    lootFinder = F.lootFinder,
    crafting = F.crafting,
    newLayout = F.newLayout,
    runPanel = F.runPanel,
    runCompact = false,
    runAlpha = 1,
    runScale = 1,
    mapSize = 1,
    mapEntranceScale = 1,
    usableOnly = true,
    myRecipes = true,
    openUnreleased = false,
    upgradesOnly = false,
    showCosmetic = true,
    lootMinLevel = 0,
    lootMaxLevel = 0,
    bossPortraits = false,
    dungeonArt = true,
    showKeys = true,
    rareAlertSound = true,
    questHelp = true,
    questsOpen = true,
    showDoneQuests = false,
    showLowQuests = false,
    bossTipOpen = true,
    bossQuestsOpen = true,
    bossAbilitiesOpen = true,
    repQuestsOpen = true,
    missingBisOnly = false,
    hideCompleted = false,
    trackerAlpha = 1,
    trackerScale = 1,
    listHidden = false,
    closedGroup1 = false,
    closedGroup2 = false,
    closedGroup3 = true,
    closedGroup4 = false,
    showAlliance = true,
    showHorde = true,
    shareRequests = true,
    acceptShared = false,
    trackerAuto = true,
    trackerSkipMaxLevel = false,
    hideGameTracker = false,
    trackerOutside = false,
})
ns.JournalSettings = S

local J = { Settings = S }
ns.Journal = J

J.OPTION_GROUPS = {
    { title = ns.L("What it lists"), options = {
        { key = "usableOnly", label = "My Class Only", hides = true,
          tooltip = "Only the loot your class can use. Off, the rest is listed faded." },
        { key = "myRecipes", label = "My Professions Only", hides = true,
          tooltip = "Only the recipes for the professions you have. Off, every recipe is listed." },
        { key = "missingBisOnly", label = "Missing BiS Only", hides = true, needsBis = true,
          tooltip = "Only the loot you still need from your BiS list: higher on it than what "
              .. "you wear, and not in your bags or bank." },
        { key = "upgradesOnly", label = "Upgrades Only", hides = true,
          tooltip = "Only the gear that beats what you wear: a higher pick on your BiS list, or a higher "
              .. "item level you can wear." },
        { key = "showCosmetic", label = "Show Cosmetic Items", hides = false,
          tooltip = "Cosmetic items too: looks for transmog that any class can wear, with no stats." },
        { key = "lootMinLevel", to = "lootMaxLevel", label = "Level Range",
          tooltip = "Only the loot for these required levels; an empty box is no limit." },
        { key = "hideCompleted", label = "Hide Completed Dungeons", hides = true,
          tooltip = "Leaves the dungeons whose quests you have all handed in off the list." },
        { key = "showDoneQuests", label = "Show Done Quests",
          tooltip = "Dungeon Quests also lists the ones you have handed in, with where they start." },
        { key = "showLowQuests", label = "Show Low-Level Quests",
          tooltip = "Dungeon Quests also lists the ones that have gone grey for your level." },
    } },
    { title = ns.L("Dungeons Listed"), newLayout = true, options = {
        { key = "showAlliance", label = "Alliance", hides = false, other = "showHorde",
          tooltip = "Lists the dungeons inside Alliance cities. The rest and the raids are always listed." },
        { key = "showHorde", label = "Horde", hides = false, other = "showAlliance",
          tooltip = "Lists the dungeons inside Horde cities. The rest and the raids are always listed." },
    } },
}
J.NEEDS_BIS = ns.L("Needs the BiS List module, which is off.")
J.NOT_YET = ns.L("Not in Forever yet")
J.CLOSED_NOTE = "Not open on Forever yet."
J.FACT = { CLASS = 1, SUBCLASS = 2, ITEM_LEVEL = 3, REQUIRED = 4, QUALITY = 5, ICON = 6, NAME = 7 }
J.RANK = { key = "PvPRank", name = ns.L("PvP Rank"), tab = "pvp", rank = true }
J.TABS = FACTION_TABS
J.NotYet = {}
J.CharacterData = ns.Shared.CharacterData

local ordered, byKey, byEnglish = {}, {}, {}
local newBosses = {}
local byNpc, dungeonOf
local byMap, byName
local factions = { reputation = {}, pvp = {} }
local byZone, byBattleground
local inFront = {}
local lastWing = {}
local EMPTY = {}

local function Localize(dungeon)
    local name = ns.L(dungeon.name)
    if name == dungeon.name and dungeon.instance then name = GetRealZoneText(dungeon.instance) end
    dungeon.name = name
    if dungeon.area then dungeon.zone = C_Map.GetAreaInfo(dungeon.area) end
    local names = J.Names
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do
            boss.name = boss.npc and names.npcs[boss.npc] or boss.chest and names.objects[boss.chest] or boss.name
        end
    end
end

local function SplitOpacity()
    local was = S.Raw("windowAlpha")
    if was ~= nil and S.Raw("trackerAlpha") == nil then S.Set("trackerAlpha", was) end
end

local function AddTo(index, id, faction)
    local list = index[id] or {}
    list[#list + 1] = faction
    index[id] = list
end

local function FactionQuests(faction)
    local quests = {}
    for _, turnin in ipairs(faction.turnins or EMPTY) do
        for _, q in ipairs(turnin.quests) do
            quests[#quests + 1] = { q[1], turnin.name, turnin.level, q[2], true, q[3], q[4], q[5], q[6],
                turnin = turnin }
        end
    end
    for _, quest in ipairs(faction.quests or EMPTY) do
        quests[#quests + 1] = quest
        J.QuestRewards[quest[1]] = quest.rewards
        J.QuestChainNames[quest[1]] = quest[2]
    end
    for _, chain in ipairs(faction.chains or EMPTY) do
        for _, id in ipairs(chain) do J.QuestChains[id] = chain end
    end
    return { quests = quests }
end

local function LinkDungeons(faction)
    for _, key in ipairs(faction.dungeons or {}) do
        local dungeon = byKey[key]
        if dungeon then
            faction.linked[#faction.linked + 1] = dungeon
            dungeon.factions = dungeon.factions or {}
            dungeon.factions[#dungeon.factions + 1] = faction
        end
    end
end

local function JoinFaction(faction)
    faction.linked = {}
    if faction.turnins or faction.quests then faction.questData = FactionQuests(faction) end
    if not faction.unreleased then
        for _, id in ipairs(faction.maps or {}) do AddTo(byZone, id, faction) end
        if faction.instance then AddTo(byBattleground, faction.instance, faction) end
    end
    LinkDungeons(faction)
end

local function JoinQuests()
    local quests = {}
    for _, entry in ipairs(J.QuestData) do quests[entry.name] = entry end
    for _, dungeon in ipairs(ordered) do
        local entry = quests[dungeon.english]
        dungeon.quests = entry
        byName[dungeon.name] = { dungeon }
        if entry and entry.map then AddTo(byMap, entry.map, dungeon) end
    end
end

local function Join()
    byMap, byName, byZone, byBattleground = {}, {}, {}, {}
    for _, tab in ipairs(FACTION_TABS) do
        for _, faction in ipairs(factions[tab]) do JoinFaction(faction) end
    end
    JoinQuests()
end

local function Joined()
    if not byMap then Join() end
end

local function IndexBosses()
    byNpc, dungeonOf = {}, {}
    for _, dungeon in ipairs(ordered) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.npc then byNpc[boss.npc], dungeonOf[boss] = boss, dungeon end
            end
        end
    end
end

local function InFront(key, list)
    local front = inFront[key]
    if front then return front end
    front = { byKey[key] }
    for _, dungeon in ipairs(list) do
        if dungeon.key ~= key then front[#front + 1] = dungeon end
    end
    inFront[key] = front
    return front
end

local function ZoneHere()
    local id = C_Map.GetBestMapForUnit("player")
    local info = id and C_Map.GetMapInfo(id)
    while info and info.mapType > ZONE and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info and info.mapType == ZONE and info.mapID
end

local function FactionsAtHere()
    local inInstance, kind = IsInInstance()
    if not inInstance then
        local zone = ZoneHere()
        return zone and byZone[zone]
    end
    if kind ~= "pvp" then return nil end
    return byBattleground[select(INSTANCE_ID, GetInstanceInfo())]
end

function J.Colored(color, text)
    return COLORED:format(color.r * BYTE, color.g * BYTE, color.b * BYTE, text)
end

function J.Facts(itemID)
    return J.Items[itemID] or J.NotYet[itemID]
end

function J.IsNotYet(itemID)
    return J.NotYet[itemID] ~= nil
end

function J.AddDungeon(key, dungeon)
    dungeon.key = key
    dungeon.english = dungeon.name
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do boss.english = boss.name end
    end
    if ns.LOCALE ~= ENGLISH then Localize(dungeon) end
    ordered[#ordered + 1] = dungeon
    byKey[key], byEnglish[dungeon.english] = dungeon, dungeon
    if not dungeon.new then return end
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do newBosses[boss] = true end
    end
end

function J.IsForeverBoss(boss)
    if boss.trash or boss.chest then return false end
    return newBosses[boss] == true or ns.Shared.Parts.IsForever("npcs", boss.npc)
end

function J.AddFaction(key, faction)
    faction.key = key
    if ns.LOCALE ~= ENGLISH then
        faction.name = J.Names.factions[faction.id] or faction.name
        faction.zone = J.PlaceName(faction.zone)
    end
    for _, tier in ipairs(faction.tiers) do tier.faction = faction end
    local list = factions[faction.tab]
    list[#list + 1] = faction
end

function J.Dungeons()
    Joined()
    return ordered
end

function J.Get(key)
    Joined()
    return byKey[key]
end

function J.PlaceName(english)
    local dungeon = byEnglish[english]
    if dungeon then return dungeon.name end
    return J.Names and J.Names.places[english] or english
end

function J.Factions(tab)
    Joined()
    return factions[tab]
end

function J.Levels(dungeon)
    return dungeon.quests and dungeon.quests.levels
end

function J.Boss(npc)
    if not byNpc then IndexBosses() end
    local boss = byNpc[npc]
    if boss then return boss, dungeonOf[boss] end
end

function FloorHere()
    local id = C_Map.GetBestMapForUnit("player")
    local group = id and C_Map.GetMapGroupID and C_Map.GetMapGroupID(id)
    local members = group and C_Map.GetMapGroupMembersInfo(group)
    for i = 1, members and #members or 0 do
        if members[i].mapID == id then return members[i].name end
    end
end

local function WingOfEncounters(kills)
    if type(kills) ~= "table" then return end
    for _, dungeon in ipairs(ordered) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.encounters and kills[boss.encounters[1]] then return dungeon.key end
            end
        end
    end
end

local function WingOfBoss(english)
    for _, dungeon in ipairs(ordered) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.english == english and not boss.trash then return dungeon.key end
            end
        end
    end
end

local function Tables(t)
    return type(t) == "table" and t or EMPTY
end

local function MoveRecords(account, old, into)
    local totals = type(account[TRASH_KEY]) == "table" and account[TRASH_KEY] or nil
    for _, store in ipairs(RECORD_STORES) do
        for _, list in pairs(Tables(account[store])) do
            for _, record in pairs(Tables(list)) do
                if type(record) == "table" and record.dungeon == old then
                    local wing = type(record.wing) == "number" and into[record.wing]
                    record.dungeon = WingOfEncounters(record.kills) or WingOfBoss(record.boss) or wing or into[1]
                    if record.wing then record.wing = MOVED_WING end
                    local trash = record.done and tonumber(record.trash)
                    if totals and trash and trash > (totals[record.dungeon] or 0) then totals[record.dungeon] = trash end
                end
            end
        end
    end
    if totals then totals[old] = nil end
end

local function MovePins(account, old, into)
    local all = account[PINS_KEY]
    local placed = type(all) == "table" and all[old]
    if type(placed) ~= "table" then return end
    for key, spot in pairs(placed) do
        for _, wingKey in ipairs(into) do
            local map = J.Maps[wingKey]
            if map and (map.pins[key] or key == ENTRANCE_KEY and map.entrance) then
                all[wingKey] = all[wingKey] or {}
                if all[wingKey][key] == nil then all[wingKey][key] = spot end
            end
        end
    end
    all[old] = nil
end

local function Rerouted(route, old, names)
    if type(route) ~= "table" then return route end
    local out, seen = {}, {}
    for _, name in ipairs(route) do
        if name == old then
            for _, wingName in ipairs(names) do
                if not seen[wingName] then out[#out + 1], seen[wingName] = wingName, true end
            end
        elseif not seen[name] then
            out[#out + 1], seen[name] = name, true
        end
    end
    return out
end

local function MoveRoutes(account, old, names)
    for _, store in pairs(Tables(account[BIS_KEY])) do
        for _, list in pairs(Tables(type(store) == "table" and store.lists)) do
            if type(list) == "table" then
                list.route = Rerouted(list.route, old, names)
                for _, parked in pairs(Tables(list.bySpec)) do
                    if type(parked) == "table" then parked.route = Rerouted(parked.route, old, names) end
                end
            end
        end
    end
end

local function MoveSplitKeys()
    local account = ns.AccountSettings()
    local done = type(account[SPLIT_DONE_KEY]) == "table" and account[SPLIT_DONE_KEY] or {}
    account[SPLIT_DONE_KEY] = done
    for old, split in pairs(SPLITS) do
        if not done[old] then
            local names = {}
            for i, key in ipairs(split.into) do names[i] = byKey[key] and byKey[key].english or key end
            MoveRecords(account, old, split.into)
            MovePins(account, old, split.into)
            MoveRoutes(account, split.english, names)
            done[old] = true
        end
    end
end

function J.Current()
    local inInstance, kind = IsInInstance()
    if not (inInstance and (kind == "party" or kind == "raid")) then
        wipe(lastWing)
        return
    end
    Joined()
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    local list = byMap[id] or byName[name]
    if not list or not list[2] then return list end
    local subzone = GetSubZoneText()
    local floor = FloorHere()
    local key = WING_MAPS[C_Map.GetBestMapForUnit("player")]
        or SUBZONES[J.Names and J.Names.subzones[subzone] or subzone]
        or floor and SUBZONES[J.Names and J.Names.subzones[floor] or floor]
        or lastWing[id]
    lastWing[id] = key
    if not key or list[1].key == key then return list end
    return InFront(key, list)
end

function J.FactionsHere(out)
    wipe(out)
    Joined()
    local list = FactionsAtHere()
    if not list then return out end
    local side = UnitFactionGroup("player")
    for i = 1, #list do
        local faction = list[i]
        if not faction.side or faction.side == side then out[#out + 1] = faction end
    end
    return out
end

function J.Suggested()
    local here = J.Current()
    if here then return here[1] end
    local level = UnitLevel("player")
    for _, dungeon in ipairs(J.Dungeons()) do
        local levels = J.Levels(dungeon)
        if levels and level >= levels[1] and level <= levels[2] then return dungeon end
    end
    return ordered[1]
end

function J.LevelRange(dungeon)
    local levels = J.Levels(dungeon)
    if not levels then return nil end
    if levels[1] == levels[2] then return tostring(levels[1]) end
    return levels[1] .. "-" .. levels[2]
end

function J.ColoredLevelRange(dungeon)
    local range = J.LevelRange(dungeon)
    if not range then return nil end
    local levels, mine = J.Levels(dungeon), UnitLevel("player")
    local level = mine < levels[1] and levels[1] or mine > levels[2] and levels[2] or mine
    return J.Colored(GetQuestDifficultyColor(level), range)
end

function J.Numbered(boss)
    return not (boss.rare or boss.optional or boss.quest or boss.chest or boss.trash)
end

function J.BossTag(boss)
    return boss.rare and "RARE" or boss.optional and "OPTIONAL" or boss.quest and "QUEST"
        or boss.chest and "CHEST" or nil
end

function J.Tip(boss)
    return boss.npc and J.Tips[boss.npc] or nil
end

function J.FactionShown(dungeon)
    if dungeon.raid or not (dungeon.entrance and ns.TownCapitals[dungeon.entrance.map]) then return true end
    local territory = dungeon.territory
    if territory == "Alliance" then return S.Get("showAlliance") end
    if territory == "Horde" then return S.Get("showHorde") end
    return true
end

function J.HasBosses(dungeon)
    return #dungeon.wings > 0
end

function J.NpcID(guid)
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

function J.ShowEntrance(dungeon)
    local entrance = dungeon.entrance
    if not entrance then return false end
    ns.PlaceWaypoint(dungeon.name, entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE, nil, true)
    ns.Shared.Places.ShowMap(entrance.map)
    return true
end

function J.TurnOn()
    if S.Get("enabled") then return end
    S.Set("enabled", true)
    ns.Print(TEXT_TURNED_ON)
end

ns.OnApply(SplitOpacity)
ns.OnApply(MoveSplitKeys)
