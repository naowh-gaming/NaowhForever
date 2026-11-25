-- QuestDetailRows.lua: the quest panel's rows: the quest's title and state, the reputation it needs, an objective with its bar, and an item it asks for.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Rep = J.Reputation
local Kinds = J.View.Kinds
local St = J.Style
local HAVE_RGB, CHECK, QUEST_CODE, INDENT = St.HAVE_RGB, St.CHECK, St.QUEST_CODE, St.INDENT
local QUEST_LEVEL_W, CHANCE_BAR_W, PLACE_DOT = St.QUEST_LEVEL_W, St.CHANCE_BAR_W, St.PLACE_DOT
local HEADING_SIZE, TEXT_SIZE, SMALL_SIZE = St.HEADING_SIZE, St.TEXT_SIZE, St.SMALL_SIZE

local TITLE_SIZE = 16
local TITLE_TOP, TITLE_GAP, TITLE_BOTTOM = 4, 4, 10
local NAME_NUDGE = 1
local OBJECTIVE_H, OBJECTIVE_BAR_H, OBJECTIVE_BAR_BOTTOM = 26, 3, 4
local COUNT_TOP, COUNT_ROOM = 4, 12
local LEADING_COUNT = "^%d+%s*/%s*%d+%s+"
local REP_TOP, REP_LINE_GAP, REP_LINE_H, REP_BOTTOM = 2, 5, 14, 10
local REP_BAR_W, REP_BAR_H, REP_BAR_GAP = 120, 4, 8

local TEXT_COMPLETE = ns.L("Complete|r")
local TEXT_IN_LOG = ns.L("In log|r")
local TEXT_COUNT = "%s/%s"
local TEXT_NOT_MET = ns.L("Not met yet")
local TEXT_REP_VALUE = "  %s / %s"
local TEXT_CODE_END = "|r"
local CHECK_ICON = "|T" .. CHECK .. ":0|t "

local function StateText(complete)
    return complete and QUEST_CODE.ready .. TEXT_COMPLETE or QUEST_CODE.active .. TEXT_IN_LOG
end

Kinds.questTitle = {
    New = function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row.level = ns.Font(row, HEADING_SIZE)
        row.level:SetPoint("TOPLEFT", 0, -TITLE_TOP)
        row.level:SetWidth(QUEST_LEVEL_W)
        row.level:SetJustifyH("LEFT")
        row.name = ns.Font(row, TITLE_SIZE, nil, T.fg)
        row.name:SetPoint("TOPLEFT", QUEST_LEVEL_W, -TITLE_TOP + NAME_NUDGE)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(true)
        row.where = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -TITLE_GAP)
        row.where:SetJustifyH("LEFT")
        row.where:SetWordWrap(true)
        return row
    end,
    Set = function(row, name, level, complete, where)
        local width = row:GetWidth() - QUEST_LEVEL_W
        local color = level and GetQuestDifficultyColor(level) or T.fg
        row.level:SetText(level or "")
        row.level:SetTextColor(color.r, color.g, color.b)
        row.name:SetWidth(width)
        row.name:SetText(name)
        local state = StateText(complete)
        row.where:SetWidth(width)
        row.where:SetText(where and state .. PLACE_DOT .. where or state)
        return TITLE_TOP + math.ceil(row.name:GetStringHeight()) + TITLE_GAP
            + math.ceil(row.where:GetStringHeight()) + TITLE_BOTTOM
    end,
}

local function PaintStanding(row, id)
    local reaction, value, max = Rep.StandingByID(id)
    row.track:SetShown(reaction ~= nil)
    row.fill:SetShown(reaction ~= nil and value > 0)
    if not reaction then
        row.standing:SetText(ns.Color("muted", TEXT_NOT_MET))
        return
    end
    local color = Rep.Color(reaction)
    local far = reaction < Rep.EXALTED and TEXT_REP_VALUE:format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max))
    row.standing:SetText(J.Colored(color, Rep.Label(reaction)) .. (far and ns.Color("muted", far) or ""))
    row.fill:SetVertexColor(color.r, color.g, color.b, 1)
    row.fill:SetWidth(math.max(1, REP_BAR_W * math.min(1, value / max)))
end

Kinds.questRep = {
    New = function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row.need = ns.Font(row, TEXT_SIZE)
        row.need:SetPoint("TOPLEFT", 0, -REP_TOP)
        row.need:SetJustifyH("LEFT")
        row.need:SetWordWrap(true)
        row.standing = ns.Font(row, SMALL_SIZE)
        row.standing:SetPoint("TOPLEFT", row.need, "BOTTOMLEFT", 0, -REP_LINE_GAP)
        row.track = ns.Solid(row, "BORDER", T.line, 1)
        row.track:SetSize(REP_BAR_W, REP_BAR_H)
        row.track:SetPoint("LEFT", row.standing, "RIGHT", REP_BAR_GAP, 0)
        row.fill = row:CreateTexture(nil, "ARTWORK")
        row.fill:SetColorTexture(1, 1, 1, 1)
        row.fill:SetPoint("TOPLEFT", row.track)
        row.fill:SetPoint("BOTTOMLEFT", row.track)
        return row
    end,
    Set = function(row, need)
        local text = Rep.NeedText(need)
        row.need:SetWidth(row:GetWidth())
        row.need:SetText(Rep.Meets(need) and J.Colored(HAVE_RGB, text) or QUEST_CODE.tooHigh .. text .. TEXT_CODE_END)
        PaintStanding(row, need[1])
        return REP_TOP + math.ceil(row.need:GetStringHeight()) + REP_LINE_GAP + REP_LINE_H + REP_BOTTOM
    end,
}

Kinds.objective = {
    New = function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row.text = ns.Font(row, TEXT_SIZE)
        row.text:SetPoint("LEFT", INDENT, 0)
        row.text:SetPoint("RIGHT", -(CHANCE_BAR_W + COUNT_ROOM), 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.count = ns.Font(row, SMALL_SIZE)
        row.count:SetPoint("TOPRIGHT", 0, -COUNT_TOP)
        row.track = ns.Solid(row, "BORDER", T.line, 1)
        row.track:SetPoint("BOTTOMRIGHT", 0, OBJECTIVE_BAR_BOTTOM)
        row.track:SetSize(CHANCE_BAR_W, OBJECTIVE_BAR_H)
        row.bar = ns.Solid(row, "ARTWORK", T.accent, 1)
        row.bar:SetPoint("LEFT", row.track)
        row.bar:SetHeight(OBJECTIVE_BAR_H)
        return row
    end,
    Set = function(row, objective)
        local done = objective.finished
        local have, need = objective.numFulfilled or 0, objective.numRequired or 0
        local text = (objective.text or ""):gsub(LEADING_COUNT, "")
        local color = done and HAVE_RGB or T.fg
        row.text:SetText((done and CHECK_ICON or "") .. text)
        row.text:SetTextColor(color.r, color.g, color.b)
        row.count:SetText(need > 0 and TEXT_COUNT:format(have, need) or "")
        row.count:SetTextColor(color.r, color.g, color.b)
        local fill = need > 0 and math.min(have / need, 1) or (done and 1 or 0)
        local bar = done and HAVE_RGB or T.accent
        row.bar:SetColorTexture(bar.r, bar.g, bar.b, 1)
        row.bar:SetWidth(math.max(1, CHANCE_BAR_W * fill))
        row.bar:SetShown(fill > 0)
        row.track:SetShown(need > 0 or done)
        return OBJECTIVE_H
    end,
}

Kinds.questItem = ns.Shared.Kinds.item
