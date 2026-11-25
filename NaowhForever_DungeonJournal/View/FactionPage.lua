-- FactionPage.lua: a faction's page and the PvP rank's: your standing, its quests, a card of rewards per standing or rank, and the Marks of Honor.
local ns = _G.NaowhForever

local GetItemCount, GetItemIconByID = C_Item.GetItemCount, C_Item.GetItemIconByID
local IsEquippedItem = C_Item.IsEquippedItem
local GetCoinTextureString = C_CurrencyInfo.GetCoinTextureString
local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local GetQuestDifficultyLevel = C_QuestLog.GetQuestDifficultyLevel

local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local Quests = J.Quests
local Rep = J.Reputation
local ViewMixin = J.View.Mixin
local St = J.Style
local QUEST = J.C.QUEST
local SECTION_SPACE, PLACE_DOT = St.SECTION_SPACE, St.PLACE_DOT
local REP_CODE = St.QUEST_CODE.done

local BOSS_LOOT_GAP = 4
local GEAR, RECIPES, OTHER = 1, 2, 3
local KIND_TITLES = { "Gear", "Recipes", "Other" }
local BOTH = "B"
local PRICE_COLUMN, NO_COLUMN = "price", "none"
local SPEND_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local ASIDE_W, ASIDE_GAP, SPLIT_COLUMNS, CARD_SPACE = 340, 18, 2, 8
local WSG, AB, AV, DI = 489, 529, 30, 2997

local TEXT_RANK = ns.L("Rank ")
local TEXT_EARNED_IN = ns.L("Earned in")
local TEXT_REWARDS = ns.L("Rewards")
local TEXT_QUARTERMASTER = ns.L("Quartermaster")
local TEXT_RANK_VENDOR = ns.L("Rank Vendor")
local TEXT_BATTLEGROUNDS = ns.L("Battlegrounds")
local TEXT_QUESTS = ns.L("Quests")
local TEXT_IN_LOG = ns.L("In your quest log")
local TEXT_QUEST = ns.L("Quest ")
local TEXT_REP = ns.L("  %s+%s rep|r")
local TEXT_NO_RANK = ns.L("The game has no PvP rank for you yet. It shows once the season has started.")
local TEXT_RANK_REWARDS = ns.L("Rank Rewards")
local TEXT_NO_RANK_REWARDS = ns.L("The game lists no rank rewards for this season yet.")
local TEXT_YOU_HAVE = ns.L("you have ")
local TEXT_SPEND_ONE = ns.L("Unlocked and not yours yet: %d reward, %s")
local TEXT_SPEND = ns.L("Unlocked and not yours yet: %d rewards, %s")
local TEXT_CODE_END = "|r"
local TEXT_STANDING = "  %s"
local TEXT_MARKS = ns.L("Marks of Honor")
local TEXT_MARKS_NOTE = ns.L("Each battleground gives its own mark, which buys Premier PvP gear with Honor.")
local MARKS = {
    { item = 20558, battleground = WSG, buys = ns.L("Legs, wrists and hands.") },
    { item = 20559, battleground = AB, buys = ns.L("Chest, shoulders, waist and the rank 3 cloaks.") },
    { item = 20560, battleground = AV, buys = ns.L("Head and the two-handed rank 14 weapons.") },
    { item = 274895, battleground = DI, buys = ns.L("Feet, the rank 4 insignia and the other rank 14 weapons.") },
}
local WHY = {
    recipes = { one = ns.L("%d is a recipe for professions you do not have (My Professions Only)"),
        many = ns.L("%d are recipes for professions you do not have (My Professions Only)") },
    class = { one = ns.L("%d is not for your class (My Class Only)"),
        many = ns.L("%d are not for your class (My Class Only)") },
    cosmetic = { one = ns.L("%d is cosmetic (Show Cosmetic Items, off)"),
        many = ns.L("%d are cosmetic (Show Cosmetic Items, off)") },
    bis = { one = ns.L("%d is not BiS you are missing (Missing BiS Only)"),
        many = ns.L("%d are not BiS you are missing (Missing BiS Only)") },
    upgrades = { one = ns.L("%d is not an upgrade over what you wear (Upgrades Only)"),
        many = ns.L("%d are not an upgrade over what you wear (Upgrades Only)") },
    level = { one = ns.L("%d is outside your level range (Level Range)"),
        many = ns.L("%d are outside your level range (Level Range)") },
}
local WHY_ORDER = { "recipes", "class", "cosmetic", "level", "bis", "upgrades" }
local TEXT_NO_REWARDS = ns.L("WoW Forever's build %s has no rewards for it yet: they show here once a build has them.")
local TEXT_NOTHING_HERE = ns.L("Nothing here for you: of its rewards, %s. Turn %s off in Filters to see them.")
local TEXT_THAT_FILTER, TEXT_THOSE_FILTERS = ns.L("that filter"), ns.L("those filters")
local TEXT_LIST = ", "

local EMPTY = {}

local function RewardKind(itemID)
    if Loot.Wearable(itemID) then return GEAR end
    if Loot.Recipe(itemID) then return RECIPES end
    return OTHER
end

local function ToggleRecipes(row)
    local view = row:GetParent()
    view.openRecipes[row.tier] = not view.openRecipes[row.tier]
    view:Redraw()
end

local function OpenRepQuests()
    S.Set("repQuestsOpen", not S.Get("repQuestsOpen"))
end

local function HiddenBy(filters, id)
    if filters.usableOnly and not Loot.Usable(id) then return "class" end
    if not filters.showCosmetic and Loot.Cosmetic(id) then return "cosmetic" end
    local facts = J.Facts(id)
    if facts and not Loot.LevelFits(facts[J.FACT.REQUIRED], filters) then return "level" end
    if filters.myRecipes and Loot.Recipe(id) and not Loot.RecipeYours(Loot.Recipe(id), filters) then return "recipes" end
    if filters.missingBis and not Loot.Missing(id) then return "bis" end
    if filters.upgradesOnly and not Loot.Upgrade(id) then return "upgrades" end
end

function ViewMixin:CountKinds(items, query)
    local counts = self.kindCounts
    counts[GEAR], counts[RECIPES], counts[OTHER] = 0, 0, 0
    for i = 1, #items do
        if self:Listed(items[i], query) then
            local kind = RewardKind(items[i])
            counts[kind] = counts[kind] + 1
        end
    end
    return counts
end

function ViewMixin:DrawRewards(tier, kind, query, reached, reaction, value, max)
    local faction, items = tier.faction, tier.items
    for i = 1, #items do
        local id = items[i]
        if RewardKind(id) == kind and self:Listed(id, query) then
            local item = self:Add("item", id, nil, self:ItemRank(id), self:ItemUpgrade(id), Rep.Price(faction, id))
            item.boss = nil
            if not reached then
                item.needs = tier.standing
                item.toGo, item.exact = Rep.ToGo(tier.standing, reaction, value, max)
            end
        end
    end
end

function ViewMixin:DrawTier(tier, shown, query, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local reaction, value, max = Rep.Standing(tier.faction)
    local reached = reaction ~= nil and reaction >= tier.standing
    local right
    if reaction and tier.standing == reaction + 1 then right = Rep.ToGoText(max - value, true) end
    self:Add("tier", Rep.Label(tier.standing), Rep.Color(tier.standing), reached, right, shown)
    if shown > 0 then self:Space(BOSS_LOOT_GAP) end
    self.column = PRICE_COLUMN
    local counts = self:CountKinds(tier.items, query)
    for kind = GEAR, OTHER do
        if counts[kind] > 0 then
            local folds = kind == RECIPES and counts[GEAR] > 0 and not query
            local open = not folds or self.openRecipes[tier] == true
            local group = self:Add("group", kind, KIND_TITLES[kind], counts[kind], folds and open, folds and ToggleRecipes)
            group.tier = tier
            if open then self:DrawRewards(tier, kind, query, reached, reaction, value, max) end
        end
    end
    self.column = nil
    return self:CloseCard(card, top)
end

function ViewMixin:DrawRankCard(entry, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local info, rank = self.rankInfo, entry.rank
    local right
    if rank == info.renownLevel + 1 then
        right = Rep.ToGoText(info.renownLevelThreshold - info.renownReputationEarned, true)
    end
    local rewards, sold = entry.rewards, Rep.RankItems(rank)
    self:Add("tier", TEXT_RANK .. rank .. PLACE_DOT .. Rep.RankTitle(rank), ns.THEME.fg, info.renownLevel >= rank,
        right, #rewards + self:ListCount(sold))
    self:Space(BOSS_LOOT_GAP)
    self.column = NO_COLUMN
    for i = 1, #rewards do
        local reward = rewards[i]
        if reward.itemID then
            self:AddItem(reward.itemID, nil, nil)
        else
            self:Add("reward", reward)
        end
    end
    for i = 1, #sold do
        if self:Listed(sold[i]) then self:AddItem(sold[i], nil, nil) end
    end
    self.column = nil
    return self:CloseCard(card, top)
end

function ViewMixin:GatherTiers(faction)
    local tiers, total = faction.tiers, 0
    for i = 1, #tiers do
        local shown = self:ListCount(tiers[i].items)
        if shown > 0 then
            total = total + shown
            self:Gather(tiers[i], nil, shown)
        end
    end
    return total
end

function ViewMixin:DrawSplitGrid(width)
    local loose = self.gridLoose
    self.gridWidth, self.gridLoose = width, true
    self:DrawGrid(nil, SPLIT_COLUMNS)
    self.gridWidth, self.gridLoose = nil, loose
    self:Column(0, width, self.cursor)
end

function ViewMixin:DrawFactionAside(faction, x, top)
    self:Column(x, ASIDE_W, top)
    if Rep.Quartermaster(faction) then
        self:Section(TEXT_QUARTERMASTER)
        self:Space(SECTION_SPACE)
        self:Add("vendor", faction)
        self:Space(SECTION_SPACE)
    end
    if self.navigate and faction.linked and #faction.linked > 0 then
        self:Section(TEXT_EARNED_IN, #faction.linked)
        self:Add("links", "", faction.linked)
        self:Space(SECTION_SPACE)
    end
    self:DrawRepQuests(faction)
    return self.cursor
end

function ViewMixin:DrawFactionSplit(faction, reaction)
    local width, top = self:GetWidth(), self.cursor
    local mainW = width - ASIDE_W - ASIDE_GAP
    local sideBottom = self:DrawFactionAside(faction, mainW + ASIDE_GAP, top)
    self:Column(0, mainW, top)
    self:DrawSpend(faction, reaction)
    local total = self:GatherTiers(faction)
    self:Section(TEXT_REWARDS, total)
    self:Space(SECTION_SPACE)
    self:DrawSplitGrid(mainW)
    if total == 0 then self:Note(self:HiddenWhy(faction)) end
    self:DrawBisNote()
    self:Column(0, width, math.max(sideBottom, self.cursor))
    self:Finish()
end

function ViewMixin:DrawFaction(faction)
    self:Begin(nil, nil, nil, faction)
    self:Add("page", faction)
    local reaction, value, max = Rep.Standing(faction)
    local counts = wipe(self.trackCounts)
    for _, tier in ipairs(faction.tiers) do counts[tier.standing] = self:ListCount(tier.items) end
    self:Add("track", reaction, value, max, counts)
    if self.factionAside then return self:DrawFactionSplit(faction, reaction) end
    self:DrawSpend(faction, reaction)
    if self.navigate and faction.linked and #faction.linked > 0 then
        self:Add("links", TEXT_EARNED_IN, faction.linked)
        self:Space(SECTION_SPACE)
    end
    self:DrawRepQuests(faction)
    local total = self:GatherTiers(faction)
    self:Section(TEXT_REWARDS, total)
    self:Space(SECTION_SPACE)
    self:DrawGrid()
    if total == 0 then self:Note(self:HiddenWhy(faction)) end
    self:DrawBisNote()
    self:Finish()
end

function ViewMixin:HiddenWhy(faction)
    local filters, hidden = self.filters, self.hiddenWhy
    hidden.class, hidden.cosmetic, hidden.recipes, hidden.bis, hidden.upgrades, hidden.level = 0, 0, 0, 0, 0, 0
    for _, tier in ipairs(faction.tiers) do
        for _, id in ipairs(tier.items) do
            local by = HiddenBy(filters, id)
            if by then hidden[by] = hidden[by] + 1 end
        end
    end
    local why = wipe(self.whyParts or {})
    self.whyParts = why
    for _, by in ipairs(WHY_ORDER) do
        local n = hidden[by]
        if n > 0 then why[#why + 1] = WHY[by][n == 1 and "one" or "many"]:format(n) end
    end
    if #why == 0 then return TEXT_NO_REWARDS:format(J.DATA_BUILD or "") end
    return TEXT_NOTHING_HERE:format(table.concat(why, TEXT_LIST), #why == 1 and TEXT_THAT_FILTER or TEXT_THOSE_FILTERS)
end

function ViewMixin:UnlockedCost(faction, reaction)
    local count, copper = 0, 0
    for _, tier in ipairs(faction.tiers) do
        if tier.standing <= reaction then
            for _, id in ipairs(tier.items) do
                local price = Rep.Price(faction, id)
                if price and self:ItemShown(id) and GetItemCount(id, true) == 0 and not IsEquippedItem(id)
                    and not (Loot.Recipe(id) and self:RecipeKnown(id)) then
                    count, copper = count + 1, copper + price
                end
            end
        end
    end
    return count, copper
end

function ViewMixin:DrawSpend(faction, reaction)
    if not reaction then return end
    local count, copper = self:UnlockedCost(faction, reaction)
    if count == 0 then return end
    local money = GetMoney()
    local have = TEXT_YOU_HAVE .. GetCoinTextureString(money)
    self.watchMoney = true
    self:Add("line", SPEND_ICON, (count == 1 and TEXT_SPEND_ONE or TEXT_SPEND):format(count,
        GetCoinTextureString(copper)), money < copper and St.RED_CODE .. have .. TEXT_CODE_END or have)
end

function ViewMixin:LogQuestData(log)
    local data = self.repLogData
    local quests = data.quests
    for i = 1, #log do
        local id = log[i]
        local quest = quests[i] or {}
        quests[i] = quest
        quest[QUEST.ID], quest[QUEST.NAME], quest[QUEST.LEVEL] = id, GetTitleForQuestID(id) or (TEXT_QUEST .. id),
            GetQuestDifficultyLevel(id)
        quest[QUEST.SIDE], quest[QUEST.SHAREABLE], quest[QUEST.WHERE] = BOTH, true, TEXT_IN_LOG
    end
    for i = #log + 1, #quests do quests[i] = nil end
    return data
end

local function MarkHandIns(handIns)
    for i = 1, #handIns do
        local entry = handIns[i]
        local quest = entry.quest
        local turnin = quest.turnin
        entry.turnin = turnin
        if turnin then
            entry.held = Rep.TurnInsHeld(turnin)
            if entry.held > 0 and not entry.inLog then entry.kind = "ready" end
        end
        entry.name = entry.name .. TEXT_REP:format(REP_CODE, turnin and turnin.rep or quest.rep)
        if quest.standing then
            entry.name = entry.name .. TEXT_STANDING:format(J.Colored(Rep.Color(quest.standing),
                Rep.Label(quest.standing)))
        end
    end
end

function ViewMixin:DrawRepQuests(faction)
    local log, signature = Rep.LogQuests(faction, self.repLog)
    self.repSignature, self.watchQuestLog = signature, true
    local logged = Quests.List(self:LogQuestData(log), self.repLogList, self.repLogPool)
    local handIns = faction.questData and Quests.List(faction.questData, self.repList, self.repPool) or EMPTY
    MarkHandIns(handIns)
    local count = #logged + #handIns
    if count == 0 then return end
    local open = S.Get("repQuestsOpen")
    self:SectionToggle(TEXT_QUESTS, count, open, OpenRepQuests)
    if open then
        for i = 1, #logged do self:Add("quest", logged[i], i) end
        for i = 1, #handIns do self:Add("quest", handIns[i], #logged + i) end
    end
    self.questsDrawn = true
    self:Space(SECTION_SPACE)
end

function ViewMixin:DrawMarks()
    self:Section(TEXT_MARKS, #MARKS)
    self:Space(SECTION_SPACE)
    self:Note(TEXT_MARKS_NOTE)
    for _, mark in ipairs(MARKS) do
        self:Add("line", GetItemIconByID(mark.item), GetRealZoneText(mark.battleground), GetItemCount(mark.item, true),
            mark.item)
        self:Note(mark.buys)
    end
    self:Space(SECTION_SPACE)
end

function ViewMixin:GatherRanks(top)
    local entries, count = self.rankEntries, 0
    for rank = 1, top do
        local rewards = Rep.RankRewards(rank)
        if rewards and #rewards > 0 then
            count = count + 1
            local entry = entries[count]
            if not entry then
                entry = {}
                entries[count] = entry
            end
            entry.rank, entry.rewards = rank, rewards
            self:Gather(entry, nil, #rewards)
        end
    end
    return count
end

function ViewMixin:DrawRankAside(x, top)
    self:Column(x, ASIDE_W, top)
    if Rep.RankVendor() then
        self:Section(TEXT_RANK_VENDOR)
        self:Space(SECTION_SPACE)
        self:Add("vendor", J.RANK)
        self:Space(SECTION_SPACE)
    end
    local factions, shown = J.Factions(J.RANK.tab), 0
    for _, faction in ipairs(factions) do
        if Rep.Shown(faction) then shown = shown + 1 end
    end
    self:Section(TEXT_BATTLEGROUNDS, shown)
    self:Space(SECTION_SPACE)
    for _, faction in ipairs(factions) do
        if Rep.Shown(faction) then
            self:Add("factionCard", faction)
            self:Space(CARD_SPACE)
        end
    end
    self:DrawMarks()
    return self.cursor
end

function ViewMixin:DrawRankSplit(info)
    local width, top = self:GetWidth(), self.cursor
    local mainW = width - ASIDE_W - ASIDE_GAP
    local sideBottom = self:DrawRankAside(mainW + ASIDE_GAP, top)
    self:Column(0, mainW, top)
    local count = self:GatherRanks(info.maxLevel)
    self:Section(TEXT_RANK_REWARDS, count)
    self:Space(SECTION_SPACE)
    self:DrawSplitGrid(mainW)
    if count == 0 then self:Note(TEXT_NO_RANK_REWARDS) end
    self:Column(0, width, math.max(sideBottom, self.cursor))
    self:Finish()
end

function ViewMixin:DrawRank()
    self:Begin(nil, nil, nil, J.RANK)
    local info = Rep.Rank()
    self.rankInfo = info
    self:Add("page", J.RANK, info)
    if not info then
        self:Note(TEXT_NO_RANK)
        self:Finish()
        return
    end
    self:Add("rankTrack", info)
    if self.factionAside then return self:DrawRankSplit(info) end
    local count = self:GatherRanks(info.maxLevel)
    self:Section(TEXT_RANK_REWARDS, count)
    self:Space(SECTION_SPACE)
    self:DrawGrid()
    if count == 0 then self:Note(TEXT_NO_RANK_REWARDS) end
    self:DrawMarks()
    self:Finish()
end
