-- SkillThresholds.lua: the selected recipe's difficulty boundaries and current-skill marker.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local R = P.Recipes
local W = P.State
local Parts = ns.Shared.Parts
local Style = P.Style

local HALF = 0.5

local catalogue

local Thresholds = {}
P.SkillThresholds = Thresholds

function Thresholds.Read(info)
    if not S.Get("enabled") or not S.Get("skillThresholds") or W.linked then return nil end
    if not catalogue then catalogue = P.LoadSkillThresholdData() end
    local bounds = catalogue.values[info.recipeID]
    if not bounds then return nil end
    local first, yellow, grey = bounds[1], bounds[2], bounds[3]
    if type(info.maxTrivialLevel) == "number" and info.maxTrivialLevel > 0 then grey = info.maxTrivialLevel end
    if first > yellow or yellow >= grey then return nil end
    return first, yellow, math.floor((yellow + grey) * HALF), grey
end

local function Skill()
    local live = Professions and Professions.GetProfessionInfo and Professions.GetProfessionInfo()
    if live and live.skillLevel then return live.skillLevel + (live.skillModifier or 0) end
    local profession = R.Profession()
    return profession and profession.skill
end

function Thresholds.Render(parent, info)
    local first, yellow, green, grey = Thresholds.Read(info)
    local line = parent.skillThresholds
    if not first then
        if line then line:Hide() end
        return nil
    end
    if not line then
        line = Parts.ThresholdLine(parent)
        line:SetPoint("TOPLEFT", parent.icon, "BOTTOMLEFT", 0, -Style.SKILL_BAR_GAP)
        line:SetWidth(Style.PANE_INNER_W)
        parent.skillThresholds = line
    end
    line:Fill(first, yellow, green, grey, Skill(), Style.DIFFICULTY_RGB)
    line:Show()
    return line
end
