-- QuestPanel.lua: a quest in your log, in the side panel: objectives, description, rewards and its buttons.
local ns = _G.NaowhForever

local GetCoinTextureString = C_CurrencyInfo.GetCoinTextureString
local GetItemCount, GetItemIconByID, IsItemDataCachedByID = C_Item.GetItemCount, C_Item.GetItemIconByID,
    C_Item.IsItemDataCachedByID

local T = ns.THEME
local SharedItems = ns.Shared.Items
local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local Quests = J.Quests
local View = J.View
local Parts = View.Parts
local Plain = Parts.Plain
local QUEST = J.C.QUEST
local St = J.Style
local SECTION_SPACE, PLACE_DOT, QUEST_CODE, QUESTION_ICON = St.SECTION_SPACE, St.PLACE_DOT, St.QUEST_CODE,
    St.QUESTION_ICON

local REDRAW_DELAY = 0.15
local ITEM_ID_RETURN = 6
local ACTION_W, ACTION_H, ACTION_GAP, ACTION_PAD = 98, 22, 6, 8
local TURN_IN_WHO = 4

local TEXT_QUEST = ns.L("QUEST")
local TEXT_HAND_IN = ns.L("Hand in: ")
local TEXT_OBJECTIVES = ns.L("Objectives")
local TEXT_ITEMS = ns.L("Items It Needs")
local TEXT_DROPS = ns.L("Drops from %s")
local TEXT_COUNT = "%d/%d"
local TEXT_CODE_END = "|r"
local TEXT_DESCRIPTION = ns.L("Description")
local TEXT_REWARDS = ns.L("Rewards")
local TEXT_CHOOSE = ns.L("Choose one of these:")
local TEXT_ALSO = ns.L("And also:")
local TEXT_EXPERIENCE = ns.L(" experience")
local TEXT_REWARD_LINE = "|T%d:0|t %s%s|r"
local TEXT_BLANK = " "
local TEXT_TRACK, TEXT_UNTRACK = ns.L("Track"), ns.L("Untrack")
local TEXT_ABANDON = ns.L("Abandon %s?")
local TEXT_CHAIN = ns.L("Chain")

local EMPTY = {}
local panel, view
local shownID
local queued = false
local choices, rewards, gains = {}, {}, {}
local waiting, asked = {}, {}
local tipFilters = {}
local tipOwner

local function FindQuest(id)
    for _, dungeon in ipairs(J.Dungeons()) do
        local data = dungeon.quests
        for _, quest in ipairs(data and data.quests or EMPTY) do
            if Quests.LoggedID(quest) == id then return quest, dungeon end
        end
    end
end

local function HandIn(id, quest)
    local turnIn = J.QuestTurnIns[id]
    if turnIn then return TEXT_HAND_IN .. turnIn[TURN_IN_WHO] end
    return quest and Plain(quest[QUEST.WHERE])
end

local function ReadItems(out, count, get)
    wipe(out)
    for i = 1, count do
        local itemID = select(ITEM_ID_RETURN, get(i))
        if itemID then out[#out + 1] = itemID end
    end
end

local function Read(id)
    local previous = C_QuestLog.GetSelectedQuest()
    C_QuestLog.SetSelectedQuest(id)
    local description = GetQuestLogQuestText()
    ReadItems(choices, GetNumQuestLogChoices(id, true) or 0, GetQuestLogChoiceInfo)
    ReadItems(rewards, GetNumQuestLogRewards() or 0, GetQuestLogRewardInfo)
    local xp, money = GetQuestLogRewardXP() or 0, GetQuestLogRewardMoney() or 0
    if previous and previous ~= id then C_QuestLog.SetSelectedQuest(previous) end
    return description, xp, money
end

local function Items(list)
    for i = 1, #list do
        local itemID = list[i]
        view:Add("item", itemID, nil, view:ItemRank(itemID), view:ItemUpgrade(itemID))
    end
end

local function DrawObjectives(id)
    local objectives = C_QuestLog.GetQuestObjectives(id) or EMPTY
    if #objectives == 0 then return end
    view:Section(TEXT_OBJECTIVES, #objectives)
    for i = 1, #objectives do view:Add("objective", objectives[i]) end
    view:Space(SECTION_SPACE)
end

local function DrawItems(id)
    local items = S.Get("questHelp") and J.QuestItems[id]
    if not items then return end
    view:Section(TEXT_ITEMS, #items)
    for i = 1, #items do
        local itemID, need, npc = items[i][1], items[i][2], items[i][3]
        local have = GetItemCount(itemID)
        local boss = npc and J.Boss(npc)
        local count = TEXT_COUNT:format(have, need)
        if have >= need then count = QUEST_CODE.ready .. count .. TEXT_CODE_END end
        view:Add("questItem", itemID, boss and TEXT_DROPS:format(boss.name) or "", count)
    end
    view:Space(SECTION_SPACE)
end

local function DrawDescription(description)
    if not description or description == "" then return end
    view:Section(TEXT_DESCRIPTION)
    view:Note(description)
    view:Space(SECTION_SPACE)
end

local function RewardsFit(quest, filters)
    local level = quest and (Quests.MinLevel(quest) or Quests.Level(quest))
    return not level or Loot.LevelFits(level, filters)
end

local function DrawRewards(choose, get, xp, money, quest)
    if not RewardsFit(quest, view.filters) then choose, get = EMPTY, EMPTY end
    if #choose == 0 and #get == 0 and xp <= 0 and money <= 0 then return end
    view:Section(TEXT_REWARDS, #choose + #get)
    if #choose > 1 then view:Note(TEXT_CHOOSE) end
    Items(choose)
    if #get > 0 and #choose > 0 then view:Note(TEXT_ALSO) end
    Items(get)
    wipe(gains)
    if xp > 0 then gains[#gains + 1] = BreakUpLargeNumbers(xp) .. TEXT_EXPERIENCE end
    if money > 0 then gains[#gains + 1] = GetCoinTextureString(money) end
    if #gains > 0 then view:Note(table.concat(gains, PLACE_DOT)) end
end

local function PaintButtons(id, buttons)
    ns.SetButtonText(buttons.Track, QuestUtils_IsQuestWatched(id) and TEXT_UNTRACK or TEXT_TRACK)
    buttons.Share:SetEnabled(IsInGroup() and C_QuestLog.IsPushableQuest(id) == true)
    buttons.Abandon:SetEnabled(C_QuestLog.CanAbandonQuest(id) == true)
end

local function Draw()
    local id = shownID
    if not (id and C_QuestLog.GetLogIndexForQuestID(id)) then
        panel:Hide()
        return
    end
    local quest, dungeon = FindQuest(id)
    panel.title:SetText(dungeon and dungeon.name:upper() or TEXT_QUEST)
    local description, xp, money = Read(id)
    view:Begin(nil, nil, nil)
    view.showChance = false
    view:Add("questTitle", C_QuestLog.GetTitleForQuestID(id) or (quest and quest[QUEST.NAME]) or "",
        quest and Quests.Level(quest), C_QuestLog.IsComplete(id), HandIn(id, quest))
    DrawObjectives(id)
    DrawItems(id)
    DrawDescription(description)
    DrawRewards(choices, rewards, xp, money, quest)
    view:Finish()
    PaintButtons(id, panel.buttons)
end

local function Flush()
    queued = false
    if panel:IsShown() then Draw() end
end

local function OnEvent()
    if queued then return end
    queued = true
    C_Timer.After(REDRAW_DELAY, Flush)
end

local function OnShow(self)
    self:RegisterEvent("QUEST_LOG_UPDATE")
end

local function OnHide(self)
    self:UnregisterAllEvents()
end

local function ShareQuest(id)
    local index = C_QuestLog.GetLogIndexForQuestID(id)
    if index then QuestLogPushQuest(index) end
end

local function TrackQuest(id)
    if QuestUtils_IsQuestWatched(id) then
        C_QuestLog.RemoveQuestWatch(id)
    else
        C_QuestLog.AddQuestWatch(id)
    end
end

local function WaypointQuest(id)
    local quest = FindQuest(id)
    if quest then Quests.Waypoint(quest) end
end

local function AbandonQuest(id)
    local name = C_QuestLog.GetTitleForQuestID(id) or ""
    ns.Confirm(TEXT_ABANDON:format(name), function()
        local previous = C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(id)
        C_QuestLog.SetAbandonQuest()
        C_QuestLog.AbandonQuest()
        if previous and previous ~= id then C_QuestLog.SetSelectedQuest(previous) end
        if panel and shownID == id then panel:Hide() end
    end)
end

local function Share()
    ShareQuest(shownID)
end

local function Track()
    TrackQuest(shownID)
    Draw()
end

local function Waypoint()
    WaypointQuest(shownID)
end

local function Abandon()
    AbandonQuest(shownID)
end

local ACTIONS = { { "Share", Share }, { "Track", Track }, { "Waypoint", Waypoint }, { "Abandon", Abandon } }
local ROW_ACTIONS = { { "Share", ShareQuest }, { "Track", TrackQuest }, { "Waypoint", WaypointQuest },
    { "Abandon", AbandonQuest } }

local function RowAction(button)
    local row = button:GetParent()
    button.act(row.id)
    PaintButtons(row.id, row.buttons)
end

View.Kinds.questActions = {
    New = function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row.buttons = {}
        for i, action in ipairs(ROW_ACTIONS) do
            local button = ns.Button(row, action[1], ACTION_W, ACTION_H, nil)
            button.act = action[2]
            button:SetScript("OnClick", RowAction)
            button:SetPoint("TOPLEFT", (i - 1) * (ACTION_W + ACTION_GAP), 0)
            row.buttons[action[1]] = button
        end
        return row
    end,
    Set = function(row, id)
        row.id = id
        PaintButtons(id, row.buttons)
        return ACTION_H + ACTION_PAD
    end,
}

local function Build()
    panel = Parts.SidePanel(ACTIONS)
    view = panel.view
    view.Redraw = Draw
    panel:SetScript("OnEvent", OnEvent)
    panel:SetScript("OnShow", OnShow)
    panel:SetScript("OnHide", OnHide)
end

local function KnownRewards(quest)
    local known = J.QuestRewards[quest[QUEST.ID]]
    if known or not quest.steps then return known end
    local last = quest.steps[#quest.steps]
    return J.QuestRewards[type(last) == "table" and last[1] or last]
end

local QuestPanel = {}
View.QuestPanel = QuestPanel

function QuestPanel.DrawInto(target, entry)
    local own, id = view, entry.loggedID
    view = target
    local chance = view.showChance
    view.showChance = false
    if id then
        local description, xp, money = Read(id)
        view:Add("questActions", id)
        DrawObjectives(id)
        DrawItems(id)
        DrawDescription(description)
        DrawRewards(choices, rewards, xp, money, entry.quest)
    else
        local known = KnownRewards(entry.quest)
        if known then DrawRewards(known.choose or EMPTY, known.get or EMPTY, 0, 0, entry.quest) end
    end
    local chain = Quests.Chain(entry.quest)
    if chain then
        view:Section(TEXT_CHAIN, #chain)
        for i, step in ipairs(chain) do view:Add("keyStep", i, step) end
    end
    view.showChance = chance
    view = own
end

function QuestPanel.HasRewards(entry)
    return KnownRewards(entry.quest) ~= nil
end

local function RewardLine(id)
    GameTooltip:AddLine(TEXT_REWARD_LINE:format(GetItemIconByID(id) or QUESTION_ICON, SharedItems.QualityHex(id),
        SharedItems.Name(id)))
end

local function RedrawTip()
    if tipOwner and GameTooltip:IsOwned(tipOwner) then tipOwner:GetScript("OnEnter")(tipOwner) end
end

local function AddUncached(list)
    for i = 1, #list do
        local id = list[i]
        if not asked[id] and not IsItemDataCachedByID(id) then
            asked[id] = true
            waiting[#waiting + 1] = id
        end
    end
end

local function WaitForItems(choose, get)
    wipe(waiting)
    AddUncached(choose)
    AddUncached(get)
    if #waiting > 0 then SharedItems.OnLoaded(waiting, RedrawTip) end
end

function QuestPanel.AddRewardLines(entry)
    if not RewardsFit(entry.quest, Loot.ReadFilters(tipFilters)) then return end
    local choose, get
    if entry.loggedID then
        Read(entry.loggedID)
        choose, get = choices, rewards
    else
        local known = KnownRewards(entry.quest)
        if not known then return end
        choose, get = known.choose or EMPTY, known.get or EMPTY
    end
    if #choose == 0 and #get == 0 then return end
    local accent = T.accentSoft
    GameTooltip:AddLine(TEXT_BLANK)
    GameTooltip:AddLine(#choose > 1 and TEXT_CHOOSE or TEXT_REWARDS, accent.r, accent.g, accent.b)
    for i = 1, #choose do RewardLine(choose[i]) end
    if #choose > 0 and #get > 0 then GameTooltip:AddLine(TEXT_ALSO, accent.r, accent.g, accent.b) end
    for i = 1, #get do RewardLine(get[i]) end
    tipOwner = GameTooltip:GetOwner()
    WaitForItems(choose, get)
end

function QuestPanel.Show(questID, from)
    if not panel then Build() end
    if panel:IsShown() and shownID == questID then
        panel:Hide()
        return
    end
    shownID = questID
    Parts.ShowBeside(panel, from)
    Draw()
end
