-- KeyLinks.lua: a dungeon's keys or what calls a boss: a link to each, a mark on the ones you carry, and what each opens, where it comes from and its quest chain on hover.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Quests = J.Quests
local Loot = J.Loot
local Have = Loot.Have
local Refused = ns.Shared.Items.Refused
local Kinds = J.View.Kinds
local Tip = ns.Shared.Parts.Tip
local SharedParts = ns.Shared.Parts
local St = J.Style
local TEXT_SIZE, SMALL_SIZE, DONE_MARK = St.TEXT_SIZE, St.SMALL_SIZE, St.DONE_MARK

local LINKS_H, LINK_GAP, FIRST_GAP, MARK_GAP = 22, 14, 8, 4
local CARD_ICON, CARD_H, CARD_GAP, CARD_LINE = 30, 40, 9, 2
local STEP_H, STEP_INDENT = 20, CARD_ICON + 9
local QUEST_NAME = J.C.QUEST.NAME
local SIDE = { Alliance = "A", Horde = "H" }

local TEXT_KEYS = ns.L("Keys")
local TEXT_ITEM = ns.L("Item ")
local TEXT_OPENS = {
    enter = ns.L("Needed to get in."),
    doors = ns.L("Opens doors inside."),
    shortcut = ns.L("Opens a shortcut."),
    summon = ns.L("Calls this boss."),
}
local TEXT_FROM_QUEST = ns.L("From the quest %s.")
local TEXT_FROM_BOSS = ns.L("From %s.")
local TEXT_FROM_DROP = ns.L("Drops from %s in %s.")
local TEXT_CHAIN_STEP = ns.L("Its chain: step %d of %d, %s.")
local TEXT_IN_LOG = ns.L(" (in your log)")
local TEXT_CHAIN_DONE = ns.L("Its chain is done.")
local TEXT_CHAIN_HINT = ns.L("Click: the whole chain")
local TEXT_HAVE = ns.L("You have it.")
local TEXT_MISSING = ns.L("You don't have it yet.")
local TEXT_STEP = "%d.  %s"
local TEXT_NOT_DONE = ns.L("Not done")
local STEP_STATE = { active = ns.L("In log"), done = ns.L("Finished") }
local TEXT_COLOR_END = "|r"

local function QuestOf(key)
    local quest = key.quest
    if type(quest) == "table" then return quest[SIDE[UnitFactionGroup("player")]] end
    return quest
end

local function SourceText(key)
    if key.drop then return TEXT_FROM_DROP:format(key.drop, C_Map.GetMapInfo(key.zone).name) end
    local id = QuestOf(key)
    if id then
        local record = J.Quests.ByID(id)
        local name = C_QuestLog.GetTitleForQuestID(id) or record and record[QUEST_NAME]
        return name and TEXT_FROM_QUEST:format(name)
    end
    local boss = key.boss and J.Boss(key.boss)
    return boss and TEXT_FROM_BOSS:format(boss.name)
end

local function ChainQuest(key)
    local id = S.Get("questHelp") and QuestOf(key)
    local record = id and Quests.ByID(id)
    if record and Quests.Chain(record) then return record end
end

local function ChainLines(record)
    local chain = Quests.Chain(record)
    local at = 1
    for i = #chain, 1, -1 do
        if Quests.StepState(chain[i]) == "done" then
            at = i + 1
            break
        end
    end
    if at > #chain then
        GameTooltip:AddLine(TEXT_CHAIN_DONE, St.HAVE_RGB.r, St.HAVE_RGB.g, St.HAVE_RGB.b)
        return
    end
    local state, id = Quests.StepState(chain[at])
    local name = Quests.StepName(id) .. (state == "active" and TEXT_IN_LOG or "")
    GameTooltip:AddLine(TEXT_CHAIN_STEP:format(at, #chain, name), 1, 1, 1, true)
end

local function KeyEnter(link)
    local key = link.key
    if not Tip(link, "ANCHOR_RIGHT") then return end
    GameTooltip_SuppressAutomaticCompareItem(GameTooltip)
    GameTooltip:SetItemByID(key.item)
    GameTooltip:AddLine(TEXT_OPENS[key.opens or "enter"], 1, 1, 1)
    local source = SourceText(key)
    if source then GameTooltip:AddLine(source, T.muted.r, T.muted.g, T.muted.b) end
    if Have(key.item) then
        GameTooltip:AddLine(TEXT_HAVE, St.HAVE_RGB.r, St.HAVE_RGB.g, St.HAVE_RGB.b)
    else
        GameTooltip:AddLine(TEXT_MISSING, T.muted.r, T.muted.g, T.muted.b)
    end
    local record = ChainQuest(key)
    if record then
        ChainLines(record)
        GameTooltip:AddLine(TEXT_CHAIN_HINT, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    end
    GameTooltip:Show()
end

local function KeyClicked(link)
    local record = ChainQuest(link.key)
    if record and not IsModifiedClick() then return J.View.OpenChain(link, record) end
    local _, itemLink = C_Item.GetItemInfo(link.key.item)
    if itemLink then HandleModifiedItemClick(itemLink) end
end

local function LinkAt(row, i)
    local link = row.links[i]
    if link then return link end
    link = SharedParts.Link(row, KeyClicked)
    link:HookScript("OnEnter", KeyEnter)
    link:HookScript("OnLeave", GameTooltip_Hide)
    link.mark = ns.Font(row, SMALL_SIZE, nil, T.fg)
    link.mark:SetPoint("LEFT", link, "RIGHT", MARK_GAP, 0)
    row.links[i] = link
    return link
end

Kinds.keys = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.label = ns.Font(row, TEXT_SIZE, nil, T.muted)
        row.label:SetPoint("LEFT", row, "TOPLEFT", 0, -LINKS_H / 2)
        row.links = {}
        return row
    end,
    Set = function(row, keys, label)
        local view = row:GetParent()
        row.label:SetText(label or TEXT_KEYS)
        local indent = math.ceil(row.label:GetStringWidth()) + FIRST_GAP
        local x, line, waiting = indent, 0, false
        for i, key in ipairs(keys) do
            local link = LinkAt(row, i)
            link.key = key
            local name = Loot.Name(key.item) or C_Item.GetItemInfo(key.item)
            if not (name or Refused(key.item)) then
                view.waitingFor[key.item] = true
                waiting = true
            end
            SharedParts.SetLink(link, name or TEXT_ITEM .. key.item)
            link.mark:SetText(Have(key.item) and DONE_MARK or "")
            local w = link:GetWidth() + MARK_GAP + math.ceil(link.mark:GetStringWidth())
            if x > indent and x + w > row:GetWidth() then x, line = indent, line + 1 end
            link:ClearAllPoints()
            link:SetPoint("LEFT", row, "TOPLEFT", x, -(line * LINKS_H + LINKS_H / 2))
            link:Show()
            link.mark:Show()
            x = x + w + LINK_GAP
        end
        for i = #keys + 1, #row.links do
            row.links[i]:Hide()
            row.links[i].mark:Hide()
        end
        return (line + 1) * LINKS_H, waiting
    end,
}

local function StepClicked(row)
    Quests.StepWaypoint(row.step, row.state, row.id, row.stepName)
end

local function StepEnter(row)
    row.text:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
end

local function StepLeave(row)
    row.text:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
end

Kinds.keyCard = {
    New = function(view)
        local row = CreateFrame("Button", nil, view)
        row.icon = SharedParts.ItemIcon(row, CARD_ICON)
        row.icon:SetPoint("LEFT")
        row.have = ns.Font(row, SMALL_SIZE)
        row.have:SetPoint("TOPRIGHT", 0, -CARD_LINE * 2)
        row.name = ns.Font(row, TEXT_SIZE)
        row.name:SetPoint("BOTTOMLEFT", row.icon, "RIGHT", CARD_GAP, CARD_LINE)
        row.name:SetPoint("RIGHT", row.have, "LEFT", -CARD_GAP, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.line = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.line:SetPoint("TOPLEFT", row.icon, "RIGHT", CARD_GAP, -CARD_LINE)
        row.line:SetPoint("RIGHT")
        row.line:SetJustifyH("LEFT")
        row.line:SetWordWrap(false)
        row:SetScript("OnEnter", KeyEnter)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row:SetScript("OnClick", KeyClicked)
        return row
    end,
    Set = function(row, key)
        local view = row:GetParent()
        row.key = key
        local name = Loot.Name(key.item) or C_Item.GetItemInfo(key.item)
        local waiting = not (name or Refused(key.item))
        if waiting then view.waitingFor[key.item] = true end
        row.icon.texture:SetTexture(C_Item.GetItemIconByID(key.item))
        row.name:SetText(ns.Shared.Items.QualityHex(key.item) .. (name or TEXT_ITEM .. key.item) .. TEXT_COLOR_END)
        local source = SourceText(key)
        row.line:SetText(TEXT_OPENS[key.opens or "enter"] .. (source and " " .. source or ""))
        local have = Have(key.item)
        local color = have and St.HAVE_RGB or T.muted
        row.have:SetText(have and TEXT_HAVE or TEXT_MISSING)
        row.have:SetTextColor(color.r, color.g, color.b)
        return CARD_H, waiting
    end,
}

Kinds.keyStep = {
    New = function(view)
        local row = CreateFrame("Button", nil, view)
        row.status = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.status:SetPoint("RIGHT")
        row.text = ns.Font(row, SMALL_SIZE)
        row.text:SetPoint("LEFT", STEP_INDENT, 0)
        row.text:SetPoint("RIGHT", row.status, "LEFT", -CARD_GAP, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", StepClicked)
        row:SetScript("OnEnter", StepEnter)
        row:SetScript("OnLeave", StepLeave)
        return row
    end,
    Set = function(row, i, step)
        local state, id = Quests.StepState(step)
        local name = Quests.StepName(id)
        row.step, row.state, row.id, row.stepName = step, state, id, name
        row.text:SetText(TEXT_STEP:format(i, name))
        row.text:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
        row.text:SetAlpha(state == "done" and St.UNUSABLE or 1)
        local color = state == "done" and St.HAVE_RGB or state == "active" and T.fg or T.muted
        row.status:SetText(STEP_STATE[state] or TEXT_NOT_DONE)
        row.status:SetTextColor(color.r, color.g, color.b)
        row:EnableMouse(state ~= "done" and (state == "active" or Quests.StepHasSpot(step, id)))
        return STEP_H
    end,
}

J.View.KeyChain = ChainQuest
