-- History.lua: Quest History, a dated record of the quests you take, hand in and drop and the levels you reach (Completo.History).
local ns = _G.NaowhForever

local GetTitle = C_QuestLog.GetTitleForQuestID
local GetDifficultyLevel = C_QuestLog.GetQuestDifficultyLevel

local Completo = ns.Completo
local S = Completo.Settings

local STORE = "completoHistory"
local KEEP = 5000
local TAKEN, HANDED_IN, DROPPED, LEVEL = 1, 2, 3, 4
local WHEN, KIND, ID, TITLE, AT_LEVEL, XP, MONEY = 1, 2, 3, 4, 5, 6, 7
local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }

local events, hooked, dropping
local listeners = {}

local History = { TAKEN = TAKEN, HANDED_IN = HANDED_IN, DROPPED = DROPPED, LEVEL = LEVEL,
    WHEN = WHEN, KIND = KIND, ID = ID, TITLE = TITLE, AT_LEVEL = AT_LEVEL, XP = XP, MONEY = MONEY }
Completo.History = History

local function On()
    return S.Get("enabled") and S.Get("history")
end

local function Store()
    local account = ns.AccountSettings()
    account[STORE] = account[STORE] or {}
    local char = Completo.CharKey(account[STORE])
    account[STORE][char] = account[STORE][char] or {}
    return account[STORE][char]
end

local function Add(kind, id, title, level, xp, money)
    local list = Store()
    list[#list + 1] = { time(), kind, id, title, level, xp, money }
    while #list > KEEP do table.remove(list, 1) end
    for _, fn in ipairs(listeners) do fn() end
end

local function AddQuest(kind, quest, xp, money)
    Add(kind, quest, GetTitle(quest) or "", GetDifficultyLevel(quest), xp, money)
end

local function OnEvent(_, event, a, b, c)
    if event == "QUEST_ACCEPTED" then
        AddQuest(TAKEN, a)
    elseif event == "QUEST_TURNED_IN" then
        AddQuest(HANDED_IN, a, b, c)
    else
        Add(LEVEL, a)
    end
end

local function OnSetAbandon()
    dropping = C_QuestLog.GetAbandonQuest()
end

local function OnAbandon()
    if On() and dropping and dropping > 0 then AddQuest(DROPPED, dropping) end
    dropping = nil
end

function History.List()
    return Store()
end

function History.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if not hooked then
        hooked = true
        hooksecurefunc(C_QuestLog, "SetAbandonQuest", OnSetAbandon)
        hooksecurefunc(C_QuestLog, "AbandonQuest", OnAbandon)
    end
end

S.OnChange(function(key)
    if key == "enabled" or key == "history" then Apply() end
end)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)
