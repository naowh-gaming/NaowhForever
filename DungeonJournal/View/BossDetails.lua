-------------------------------------------------------------------------------
--  View/BossDetails.lua -- the rows under a boss's loot on its own page (ViewMixin:
--  DrawBossLoot), each list in a card of its own:
--
--  - tip: Naowh's tip (Data/Tips.lua), written out beside the Naowh mark (a loot icon's
--    size), at the top of the page; the chat bubble on its right shares it (Say, Party,
--    Raid, Guild, your target).
--  - bossQuest: a dungeon quest that needs the boss (Data/BossQuests.lua): its name in the
--    quest log's colour for where it stands for you, and on the right that state in words,
--    a tick once it is done. Its tooltip says where it starts.
--  - ability: one of its abilities (Data/Abilities.lua): its icon in a black border, its
--    name, and under it, muted and wrapped, what the game says it does. Its tooltip is the
--    game's. A spell the client has not loaded yet draws again once it has, as an item's
--    name does.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local T = ns.THEME
local J = ns.Journal

local GetSpellName = C_Spell.GetSpellName
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellDescription = C_Spell.GetSpellDescription
local IsSpellDataCached = C_Spell.IsSpellDataCached

local Quests = J.Quests

local St = J.Style
local CARD_PAD, QUEST_CODE, HAVE_RGB, CHECK = St.CARD_PAD, St.QUEST_CODE, St.HAVE_RGB, St.CHECK

local View = J.View
local Kinds, Parts = View.Kinds, View.Parts

local ICON = St.ICON      -- as big as a loot icon
local TEXT_GAP = 8        -- the icon to its name and description
local NAME_DESC_GAP = 2
local ROW_PAD = 5         -- above and under each ability
local QUESTION = 134400   -- the game's question mark, for a spell with no icon
local MARK = 14           -- the Naowh mark beside the tip; a done quest's tick
local QUEST_H = 22
local STATE_W = 120       -- a quest's state, on the right
local SHARE = 18          -- the tip's share button
local TIP_MARK = St.ICON  -- the Naowh mark beside the tip, as big as a loot icon
local BUBBLE = "Interface\\GossipFrame\\GossipGossipIcon"

-------------------------------------------------------------------------------
--  Naowh's tip
-------------------------------------------------------------------------------
local function ShareEnter(button)
    button.icon:SetVertexColor(1, 1, 1)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Share Naowh's tip", 1, 1, 1)
    GameTooltip:AddLine("Say, Party, Raid, Guild or your target.", T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function ShareLeave(button)
    button.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Hide()
end

local function ShareClicked(button)
    Parts.ShareTip(button, button.boss, button.tip)
end

Kinds.tip = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetTexture(St.LOGO_SMALL, nil, nil, "TRILINEAR")
        row.mark:SetSize(TIP_MARK, TIP_MARK)
        row.mark:SetPoint("TOPLEFT", 0, -ROW_PAD)
        local share = CreateFrame("Button", nil, row)
        share:SetSize(SHARE, SHARE)
        share:SetPoint("RIGHT", 0, 0)
        share.icon = share:CreateTexture(nil, "ARTWORK")
        share.icon:SetTexture(BUBBLE)
        share.icon:SetAllPoints()
        share.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
        share:SetScript("OnEnter", ShareEnter)
        share:SetScript("OnLeave", ShareLeave)
        share:SetScript("OnClick", ShareClicked)
        row.share = share
        row.text = ns.Font(row, 12, nil, T.fg)
        row.text:SetPoint("TOPLEFT", row.mark, "TOPRIGHT", TEXT_GAP, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(true)
        return row
    end,
    ---@param boss JournalBoss
    ---@param tip string
    Set = function(row, boss, tip)
        row.share.boss, row.share.tip = boss, tip
        row.text:SetWidth(row:GetWidth() - TIP_MARK - TEXT_GAP * 2 - SHARE)
        row.text:SetText(tip)
        -- Beside the mark, in the middle of it while it is the taller.
        local text = row.text:GetStringHeight()
        row.text:SetPoint("TOPLEFT", row.mark, "TOPRIGHT", TEXT_GAP, -math.max(0, (TIP_MARK - text) / 2))
        return math.ceil(math.max(TIP_MARK, text)) + ROW_PAD * 2
    end,
}

-------------------------------------------------------------------------------
--  The quests that need it
-------------------------------------------------------------------------------
local STATE = {
    prereq = "Do first", prereqLog = "Do first", low = "Level %d to pick up", pickup = "To pick up",
    next = "Next step", active = "In log", ready = "Complete", done = "Done",
}

local function QuestEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(Quests.Name(row.quest), 1, 1, 1)
    GameTooltip:AddLine(row.quest[6], T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function QuestLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

Kinds.bossQuest = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.hover = ns.Solid(row, "BACKGROUND", T.fg, 0.05)
        row.hover:SetPoint("TOPLEFT", -CARD_PAD + 1, 0)
        row.hover:SetPoint("BOTTOMRIGHT", CARD_PAD - 1, 0)
        row.hover:Hide()
        row.state = ns.Font(row, 11, nil, T.muted)
        row.state:SetPoint("RIGHT", 0, 0)
        row.state:SetJustifyH("RIGHT")
        row.tick = row:CreateTexture(nil, "ARTWORK")
        row.tick:SetTexture(CHECK)
        row.tick:SetSize(MARK, MARK)
        row.tick:SetPoint("RIGHT", row.state, "LEFT", -4, 0)
        row.name = ns.Font(row, 12)
        row.name:SetPoint("LEFT", 0, 0)
        row.name:SetPoint("RIGHT", -STATE_W, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row:EnableMouse(true)
        row:SetScript("OnEnter", QuestEnter)
        row:SetScript("OnLeave", QuestLeave)
        return row
    end,
    ---@param quest JournalQuest
    Set = function(row, quest)
        row.quest = quest
        local kind = Quests.Kind(quest)
        row.name:SetText((QUEST_CODE[kind] or "") .. Quests.Name(quest) .. "|r")
        local state = STATE[kind]
        if kind == "low" then state = state:format(Quests.MinLevel(quest) or 0) end
        row.state:SetText(state)
        local done = kind == "done"
        row.tick:SetShown(done)
        if done then
            row.state:SetTextColor(HAVE_RGB.r, HAVE_RGB.g, HAVE_RGB.b)
        else
            row.state:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        end
        return QUEST_H
    end,
}

-------------------------------------------------------------------------------
--  Its abilities
-------------------------------------------------------------------------------

local function AbilityEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(row.spell)
    GameTooltip:Show()
end

local function AbilityLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

-- A spell loaded after its row was drawn: the view draws again, once for a burst of them.
local function Loaded(view)
    return function()
        if view:IsVisible() then view:QueueRedraw() end
    end
end

Kinds.ability = {
    New = function(view)
        local row = CreateFrame("Button", nil, view)
        -- The hover reaches out to the card's edges, as an item's does.
        row.hover = ns.Solid(row, "BACKGROUND", T.fg, 0.05)
        row.hover:SetPoint("TOPLEFT", -CARD_PAD + 1, 0)
        row.hover:SetPoint("BOTTOMRIGHT", CARD_PAD - 1, 0)
        row.hover:Hide()
        local frame = Parts.ItemIcon(row, ICON)
        frame:SetPoint("TOPLEFT", 0, -ROW_PAD)
        row.icon, row.iconFrame = frame.texture, frame
        row.name = ns.Font(row, 12, nil, T.fg)
        row.name:SetPoint("TOPLEFT", frame, "TOPRIGHT", TEXT_GAP, 0)
        row.name:SetPoint("RIGHT")
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.desc = ns.Font(row, 11, nil, T.muted)
        row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -NAME_DESC_GAP)
        row.desc:SetJustifyH("LEFT")
        row.desc:SetWordWrap(true)
        row:SetScript("OnEnter", AbilityEnter)
        row:SetScript("OnLeave", AbilityLeave)
        row.loaded = Loaded(view)
        return row
    end,
    ---@param spell number its spell ID
    Set = function(row, spell)
        row.spell = spell
        row.icon:SetTexture(GetSpellTexture(spell) or QUESTION)
        row.name:SetText(GetSpellName(spell) or ("Spell " .. spell))
        local desc = GetSpellDescription and GetSpellDescription(spell) or ""
        if desc == "" and IsSpellDataCached and not IsSpellDataCached(spell) and Spell then
            Spell:CreateFromSpellID(spell):ContinueOnSpellLoad(row.loaded)
        end
        row.desc:SetWidth(row:GetWidth() - ICON - TEXT_GAP)
        row.desc:SetText(desc)
        row.desc:SetShown(desc ~= "")
        local text = row.name:GetStringHeight()
        if desc ~= "" then text = text + NAME_DESC_GAP + row.desc:GetStringHeight() end
        -- Beside the icon, in the middle of it while it is the taller, as an item's lines are.
        row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", TEXT_GAP, -math.max(0, (ICON - text) / 2))
        return math.ceil(math.max(ICON, text)) + ROW_PAD * 2
    end,
}
