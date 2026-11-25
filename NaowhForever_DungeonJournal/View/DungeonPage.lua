-- DungeonPage.lua: a dungeon's page: its header, its keys, your quests, each wing's boss cards, its trash and the folded bosses.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Quests = J.Quests
local View = J.View
local ViewMixin = View.Mixin
local St = J.Style
local SECTION_SPACE = St.SECTION_SPACE

local BOSS_LOOT_GAP = 4
local TRASH_TOP, TRASH_GAP = 6, 16
local EMPTY_BODY = 28
local DETAIL_TOP = 8
local SKIPPED_TITLE = { missingBisOnly = ns.L("Nothing you're missing"), upgradesOnly = ns.L("Nothing that beats your gear"),
    usableOnly = ns.L("Nothing for your class"), lootMinLevel = ns.L("Nothing in your level range") }

local TEXT_QUESTS = ns.L("Dungeon Quests")
local TEXT_TRACKER = ns.L("Tracker")
local TEXT_SHARE_ALL = ns.L("Share All")
local TEXT_NO_QUESTS = ns.L("No quests here.")
local TEXT_REPUTATION = ns.L("Reputation")
local TEXT_NO_BOSSES = ns.L("No boss data for this dungeon yet. It fills in with a later version of the addon.")
local TEXT_BOSSES = ns.L("Bosses")
local TEXT_MAP = "Map"
local TEXT_COMING_SOON = "Coming soon"
local TEXT_NO_MAP = ns.L("No map of this dungeon yet.")
local TEXT_KEYS_TITLE = "Keys and Attunements"
local TEXT_SUMMARY = ns.L("%d |4item:items;")
local TEXT_UPGRADES = ns.L("%d |4upgrade:upgrades; for you")
local TEXT_HIDE_OTHERS = "Hide Other Classes' Items"
local TEXT_SHOW_OTHERS = "Show Other Classes' Items"
local TEXT_TRASH = "Trash"

local EMPTY = {}
local chipLabels = {}

local function OpenQuests()
    S.Set("questsOpen", not S.Get("questsOpen"))
end

local function OpenTracker(dungeon)
    ns.OpenQuestTracker(dungeon)
end

local function ShareAll(dungeon)
    J.Sharing.ShareAll(dungeon)
end

local function Inside(dungeon)
    local here = J.Current()
    for i = 1, here and #here or 0 do
        if here[i] == dungeon then return true end
    end
    return false
end

local function NextBoss(dungeon)
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do
            if J.Numbered(boss) and not J.Kills.ThisRun(boss) then return boss end
        end
    end
end

local function OpenMap(dungeon, link)
    J.OpenDungeonMap(dungeon, link)
end

local function ChipLabel(boss, number, wing)
    local label = chipLabels[boss]
    if not label then
        label = (wing and wing .. " " or "") .. (number and number .. " " or "") .. boss.name
        chipLabels[boss] = label
    end
    return label
end

function ViewMixin:DrawBoss(boss, number, shown, query, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local loot, chance = boss.loot or EMPTY, boss.chance
    local hidden = not query and #loot - shown or 0
    local run = self.inside and (J.Kills.ThisRun(boss) and "killed" or boss == self.nextBoss and "next") or nil
    local header = self:Add("boss", boss, number, shown, hidden, run)
    header.card = card
    local quests = self:BossQuests(boss)
    if quests then self:Add("questChips", quests) end
    self:DrawSummons(boss)
    if shown > 0 then self:Space(BOSS_LOOT_GAP) end
    local kept, faded = 0, 0
    for i = 1, #loot do
        local id = loot[i]
        if self:Listed(id, query) then
            local item = self:AddItem(id, chance and chance[i], boss)
            if item.keep then kept = kept + 1 else faded = faded + 1 end
        end
    end
    header.canPin = kept > 0 and faded > 0
    header:EnableMouse(true)
    card.note:SetText(View.Parts.BossEmptyText(shown, boss))
    card.note:SetShown(shown == 0)
    if shown == 0 then self:Space(EMPTY_BODY) end
    return self:CloseCard(card, top)
end

function ViewMixin:DrawTrash(boss, shown, query, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local loot, chance = boss.loot or EMPTY, boss.chance
    local left, width = self.left, self.width
    local columnW = math.floor((width - TRASH_GAP) / 2)
    self:Space(TRASH_TOP)
    local start, bottom, n, half = self.cursor, self.cursor, 0, math.ceil(shown / 2)
    self.width = columnW
    for i = 1, #loot do
        local id = loot[i]
        if self:Listed(id, query) then
            n = n + 1
            if n == half + 1 then
                bottom, self.cursor, self.left = self.cursor, start, left + columnW + TRASH_GAP
            end
            self:AddItem(id, chance and chance[i], boss)
        end
    end
    self.cursor = math.max(self.cursor, bottom)
    self.left, self.width = left, width
    return self:CloseCard(card, top)
end

function ViewMixin:DrawQuests(list)
    local open = S.Get("questsOpen")
    self:Add("section", TEXT_QUESTS, #list, open, OpenQuests, TEXT_TRACKER, OpenTracker, self.dungeon, nil, nil,
        IsInGroup() and TEXT_SHARE_ALL or nil, ShareAll)
    if open then
        for i = 1, #list do self:Add("quest", list[i], i) end
    end
    self:Space(SECTION_SPACE)
end

function ViewMixin:QuestList(dungeon)
    if not dungeon.quests then return EMPTY end
    local withDone = not (self.tracker or self.tight) and S.Get("showDoneQuests")
    local list = Quests.List(dungeon.quests, self.questList, self.questPool, withDone, S.Get("showLowQuests"))
    self.questSignature = Quests.Signature(dungeon.quests)
    self.questsDrawn = true
    return list
end

local function ToggleUsable()
    S.Set("usableOnly", not S.Get("usableOnly"))
end

function ViewMixin:DrawLootSummary(dungeon)
    local items, bosses, upgrades = 0, 0, 0
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do
            if not (boss.trash or boss.chest) then bosses = bosses + 1 end
            for _, id in ipairs(boss.loot or EMPTY) do
                if self:Listed(id) then
                    items = items + 1
                    if self:ItemUpgrade(id) then upgrades = upgrades + 1 end
                end
            end
        end
    end
    local text = bosses .. St.PLACE_DOT .. TEXT_SUMMARY:format(items)
    if upgrades > 0 then text = text .. St.PLACE_DOT .. St.UPGRADE_CODE .. TEXT_UPGRADES:format(upgrades) .. "|r" end
    return text
end

function ViewMixin:DrawQuestDetail(entry)
    local top = self.cursor
    local card = self:OpenCard(0, self:GetWidth())
    self:Space(DETAIL_TOP)
    View.QuestPanel.DrawInto(self, entry)
    self:CloseCard(card, top)
    self:Space(BOSS_LOOT_GAP)
end

function ViewMixin:DrawAside(dungeon)
    self:Begin(dungeon, nil)
    local list = self:QuestList(dungeon)
    self:Add("section", TEXT_QUESTS, #list, nil, nil, TEXT_TRACKER, OpenTracker, dungeon, nil, nil,
        IsInGroup() and TEXT_SHARE_ALL or nil, ShareAll)
    if #list == 0 then self:Note(dungeon.quests and Quests.NoneWhy(dungeon.quests) or TEXT_NO_QUESTS) end
    for i = 1, #list do
        self:Add("quest", list[i], i)
        if list[i].quest == self.openQuest then self:DrawQuestDetail(list[i]) end
    end
    self:Finish()
end

function ViewMixin:DrawHead(dungeon)
    self:Begin(dungeon, nil)
    self:QuestList(dungeon)
    self:Add("header", dungeon)
    if dungeon.note then self:Note(dungeon.note) end
    if dungeon.closed then self:Note(J.CLOSED_NOTE) end
    self:Finish()
end

function ViewMixin:DrawKeysPage(dungeon)
    self:Begin(dungeon, nil)
    local keys = J.Keys[dungeon.key]
    self:Section(TEXT_KEYS_TITLE, keys and #keys or 0)
    self:Space(SECTION_SPACE)
    for _, key in ipairs(keys or EMPTY) do
        self:Add("keyCard", key)
        local record = J.View.KeyChain(key)
        local chain = record and Quests.Chain(record)
        for i, step in ipairs(chain or EMPTY) do self:Add("keyStep", i, step) end
        self:Space(SECTION_SPACE)
    end
    self:Finish()
end

function ViewMixin:DrawTracker(dungeon)
    self:Begin(dungeon, nil)
    self.tight = true
    local list = self:QuestList(dungeon)
    if #list == 0 then self:Note(Quests.NoneWhy(dungeon.quests) or TEXT_NO_QUESTS) end
    for i = 1, #list do self:Add("quest", list[i], i) end
    self:Finish()
end

function ViewMixin:DrawDungeonQuests(dungeon, list)
    if #list > 0 then return self:DrawQuests(list) end
    if not dungeon.quests then return end
    local why = Quests.NoneWhy(dungeon.quests)
    if not why then return end
    self:Section(TEXT_QUESTS, 0)
    self:Note(why)
    self:Space(SECTION_SPACE)
end

function ViewMixin:GatherWing(wing)
    local skipped, skippedBoss, trash = self.skipped, self.skippedBoss, self.trash
    local number, cards = 0, 0
    for _, boss in ipairs(wing.bosses) do
        local ordered = J.Numbered(boss)
        if ordered then number = number + 1 end
        local kill = ordered and number or nil
        local shown = self:ShownCount(boss)
        if shown == 0 and boss.loot then
            skipped[#skipped + 1] = ChipLabel(boss, kill, wing.name)
            skippedBoss[#skippedBoss + 1] = boss
        elseif boss.trash then
            trash[#trash + 1] = boss
            self.trashShown = self.trashShown + shown
        else
            self:Gather(boss, kill, shown)
            if not (boss.trash or boss.chest) then cards = cards + 1 end
        end
    end
    return cards
end

function ViewMixin:WingTitle(dungeon, title, first, count)
    local summary = first and self.summary
    if summary then
        self:Add("section", title, summary, nil, nil, S.Get("usableOnly") and TEXT_SHOW_OTHERS or TEXT_HIDE_OTHERS,
            ToggleUsable)
    elseif first and (not self.onWorldMap or J.DungeonMapAway()) then
        if J.Maps[dungeon.key] then
            self:Add("section", title, count, nil, nil, TEXT_MAP, OpenMap, dungeon)
        else
            self:Add("section", title, count, nil, nil, TEXT_MAP, nil, nil, TEXT_COMING_SOON, TEXT_NO_MAP)
        end
    else
        self:Section(title, count)
    end
    self:Space(SECTION_SPACE)
end

function ViewMixin:DrawWings(dungeon)
    for i, wing in ipairs(dungeon.wings) do
        local cards = self:GatherWing(wing)
        local title = wing.name or (i == 1 and TEXT_BOSSES)
        if title then self:WingTitle(dungeon, title, i == 1, cards > 0 and cards or nil) end
        self:DrawGrid()
    end
end

function ViewMixin:DrawTrashCards()
    local trash = self.trash
    if #trash == 0 then return end
    self:Section(TEXT_TRASH, self.trashShown)
    self:Space(SECTION_SPACE)
    for k = 1, #trash do self:Gather(trash[k], nil, self:ShownCount(trash[k])) end
    self.trashColumns = #trash == 1
    self:DrawGrid(#trash == 1 and 1 or nil)
    self.trashColumns = false
end

function ViewMixin:DrawSkipped()
    local skipped = self.skipped
    if #skipped == 0 then return end
    self:Space(BOSS_LOOT_GAP)
    local filters = self.filters
    local key = filters.missingBis and "missingBisOnly" or filters.upgradesOnly and "upgradesOnly"
        or (filters.minLevel > 0 or filters.maxLevel > 0) and "lootMinLevel" or "usableOnly"
    self:Add("skipped", SKIPPED_TITLE[key], key, self.skippedBoss, skipped)
    self:Space(BOSS_LOOT_GAP)
end

function ViewMixin:Draw(dungeon)
    self:Begin(dungeon, nil)
    self.dense = self.lootDense == true
    local list = self:QuestList(dungeon)
    if not self.headAside then
        self:Add("header", dungeon)
        if dungeon.note then self:Note(dungeon.note) end
        if dungeon.closed then self:Note(J.CLOSED_NOTE) end
    end
    local keys = not self.keysAside and S.Get("showKeys") and J.Keys[dungeon.key]
    if keys then
        self:Add("keys", keys)
        self:Space(SECTION_SPACE)
    end
    if self.navigate and dungeon.factions then
        self:Add("links", TEXT_REPUTATION, dungeon.factions)
        self:Space(SECTION_SPACE)
        self.factionLinks = true
    end
    if not self.questsAside then self:DrawDungeonQuests(dungeon, list) end
    if not J.HasBosses(dungeon) then self:Note(TEXT_NO_BOSSES) end
    wipe(self.skipped)
    wipe(self.skippedBoss)
    wipe(self.trash)
    self.trashShown = 0
    self.inside = Inside(dungeon)
    self.nextBoss = self.inside and NextBoss(dungeon) or nil
    self.summary = self.lootDense and not self.onWorldMap and J.HasBosses(dungeon)
        and self:DrawLootSummary(dungeon) or nil
    self:DrawWings(dungeon)
    self:DrawTrashCards()
    self:DrawBisNote()
    self:DrawSkipped()
    self:Finish()
end
