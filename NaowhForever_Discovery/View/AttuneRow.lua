-- AttuneRow.lua: a quest of an attunement: its number or tick, its name, who gives it and where, where it stands, a waypoint pin.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local Parts = ns.Shared.Parts
local Style = Discovery.Style
local Attune = Discovery.Attune
local V = Discovery.View

local WORDS = { done = ns.L("Done"), log = ns.L("In your log"), now = ns.L("Next"), later = ns.L("Later"),
    low = ns.L("Needs level %d") }
local STATE_RGB = { log = Style.HAVE_RGB, now = Style.HAVE_RGB, low = Style.MISSING_RGB }
local TEXT_SHARE = ns.L("Share where it is")
local TEXT_HINT = ns.L("Pin: waypoint    Right-click it: Share")

local function QuestPin(button, mouse)
    local id = button:GetParent().quest
    if mouse == "RightButton" then
        local Q = ns.Completo.Quests
        local map, x, y = Q.Spot(id)
        return Parts.SharePlace(button, TEXT_SHARE, Attune.Name(id), map, x, y, Q.Giver(id))
    end
    Attune.Waypoint(id)
end

local function QuestEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local m = T.muted
    GameTooltip:SetText(Attune.Name(row.quest), 1, 1, 1)
    GameTooltip:AddLine(Attune.Where(row.quest), m.r, m.g, m.b, true)
    local note = Attune.Note(row.quest)
    if note then GameTooltip:AddLine(note, 1, 1, 1, true) end
    if row.pin:IsShown() then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_HINT, V.Soft())
    end
    GameTooltip:Show()
end

local function NewQuest(parent)
    return V.NewRow(parent, QuestPin, QuestEnter)
end

local function Status(id, state)
    if state == "low" then return WORDS.low:format(ns.Completo.Quests.RequiredLevel(id)) end
    return WORDS[state]
end

local function SetQuest(row, id, number, state, stripe)
    row.quest = id
    V.Reset(row, stripe)
    local done = state == "done"
    row.pin:SetShown(not done and ns.Completo.Quests.Spot(id) ~= nil)
    row.tick:SetShown(done)
    row.level:SetShown(not done)
    row.level:SetText(number)
    V.Paint(row.level, T.muted)
    row.status:SetText(Status(id, state))
    V.Paint(row.status, STATE_RGB[state] or T.muted)
    row.bag:Hide()
    local textW = V.TextWidth(row)
    row.title:SetWidth(textW)
    row.title:SetText(Attune.Name(id))
    V.Paint(row.title, done and T.muted or T.fg)
    row.where:SetWidth(textW)
    row.where:SetText(Attune.Where(id))
    return V.Height(row)
end

V.Kinds.attune = { New = NewQuest, Set = SetQuest }
