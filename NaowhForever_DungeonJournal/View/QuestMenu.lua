-- QuestMenu.lua: a quest's right-click menu and the menu of its chain.
local ns = _G.NaowhForever

local J = ns.Journal
local Quests = J.Quests
local View = J.View
local Parts = View.Parts
local QUEST = J.C.QUEST
local T = ns.THEME
local QUEST_CODE = J.Style.QUEST_CODE

local CHAIN_STATE = {
    active = QUEST_CODE.active .. ns.L("In log|r"), done = QUEST_CODE.done .. ns.L("Finished|r"),
    todo = QUEST_CODE.done .. ns.L("Not done|r"),
}

local TEXT_CHAIN_TITLE = ns.L("%s: step %d of %d")
local TEXT_CHAIN_HINT = ns.L("Click a step for a waypoint.")
local TEXT_STEP = "%d.  %s  %s"
local TEXT_STEP_DONE = "%d.  %s|r  "
local TEXT_DUNGEON_QUEST = ns.L("(dungeon quest)")
local TEXT_INSIDE = "  %s %s"
local INSIDE_MARK = Parts.Inline(J.Style.SKULL, T.muted)
local TEXT_TRACK = ns.L("Track in Quest Log")
local TEXT_NO_CHAT = ns.L("Join a group, or open your chat box first.")
local TEXT_CHAT_LOCKED = ns.L("Chat is locked right now.")
local TEXT_PARTY, TEXT_CHAT = ns.L("Party"), "Chat"
local TEXT_LINK_IN = ns.L("Link in ")
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_SHOW_CHAIN = ns.L("Show Chain")
local TEXT_COPY_WOWHEAD = ns.L("Copy Wowhead Link")
local TEXT_QUEST_ID = ns.L("Quest ID")

local function StepLine(i, state, id, name, own)
    local text = TEXT_STEP:format(i, name, CHAIN_STATE[state])
    if state == "done" then text = QUEST_CODE.done .. TEXT_STEP_DONE:format(i, name) .. CHAIN_STATE.done end
    if i == own then text = text .. "  " .. ns.Color("accentSoft", TEXT_DUNGEON_QUEST) end
    local inside = Quests.Inside(id)
    if inside then text = text .. ns.Color("muted", TEXT_INSIDE:format(INSIDE_MARK, inside)) end
    return text
end

local function AddStep(root, i, step, own)
    local state, id = Quests.StepState(step)
    local name = Quests.StepName(id)
    local text = StepLine(i, state, id, name, own)
    if state ~= "done" and (state == "active" or Quests.StepHasSpot(step, id)) then
        root:CreateButton(text, function() Quests.StepWaypoint(step, state, id, name) end)
    else
        root:CreateTitle(text, WHITE_FONT_COLOR)
    end
end

local function OpenChain(owner, quest)
    local chain, own = Quests.Chain(quest)
    if not chain then return end
    local logged = Quests.LoggedID(quest)
    GameTooltip:Hide()
    ns.ContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_CHAIN_TITLE:format(Quests.Name(quest), own, #chain))
        root:CreateTitle(ns.Color("muted", TEXT_CHAIN_HINT))
        for i, step in ipairs(chain) do AddStep(root, i, step, own) end
        if not logged then return end
        root:CreateDivider()
        root:CreateButton(TEXT_TRACK, function() Quests.Track(logged) end)
    end)
end

View.OpenChain = OpenChain

local function LinkChannel()
    if IsInGroup() then return Parts.PartyChat(), TEXT_PARTY end
    return nil, TEXT_CHAT
end

local function ChatBoxOpen()
    return ChatFrameUtil.GetActiveWindow() ~= nil
end

local function NoChatTip(tooltip)
    GameTooltip_SetTitle(tooltip, TEXT_NO_CHAT)
end

local function LinkInChat(id)
    local link = GetQuestLink(id)
    if not link or ChatFrameUtil.InsertLink(link) then return end
    local channel = LinkChannel()
    if not channel then return end
    if C_ChatInfo.InChatMessagingLockdown() then
        ns.Print(TEXT_CHAT_LOCKED)
        return
    end
    C_ChatInfo.SendChatMessage(link, channel)
end

local function AddLinkButton(root, linkID)
    local channel, where = LinkChannel()
    local linkable = GetQuestLink(linkID) ~= nil
    local reachable = channel ~= nil or ChatBoxOpen()
    local link = root:CreateButton(TEXT_LINK_IN .. where, function() LinkInChat(linkID) end)
    link:SetEnabled(linkable and reachable)
    if not linkable then
        link:SetTooltip(function(tooltip)
            GameTooltip_SetTitle(tooltip, ns.L("Only quests in your quest log can be linked."))
        end)
    elseif not reachable then
        link:SetTooltip(NoChatTip)
    end
end

local function OpenQuestMenu(owner, entry)
    local quest, logged, name, canWaypoint = entry.quest, entry.loggedID, entry.name, entry.canWaypoint
    local linkID = logged or quest[QUEST.ID]
    local shareable = logged ~= nil and IsInGroup() and C_QuestLog.IsPushableQuest(logged)
    ns.ContextMenu(owner, function(_, root)
        root:CreateTitle(name)
        root:CreateButton(SHARE_QUEST, function()
            QuestLogPushQuest(C_QuestLog.GetLogIndexForQuestID(logged))
        end):SetEnabled(shareable)
        AddLinkButton(root, linkID)
        root:CreateDivider()
        if canWaypoint then root:CreateButton(TEXT_WAYPOINT, function() Quests.Waypoint(quest) end) end
        if Quests.Chain(quest) then root:CreateButton(TEXT_SHOW_CHAIN, function() OpenChain(owner, quest) end) end
        if logged then root:CreateButton(TEXT_TRACK, function() Quests.Track(logged) end) end
        root:CreateDivider()
        root:CreateButton(TEXT_COPY_WOWHEAD, function()
            ns.ShowCopyCard("quest", TEXT_QUEST_ID, quest[QUEST.ID], name)
        end)
    end)
end

Parts.QuestMenu = OpenQuestMenu
