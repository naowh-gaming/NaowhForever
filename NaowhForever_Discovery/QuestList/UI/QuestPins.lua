-- QuestPins.lua: a ! on the world map at each quest giver with a quest you can pick up.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Style = Completo.Style
local OpenMap = ns.Shared.OpenMap

local TEMPLATE = "NaowhForeverQuestGiverPinTemplate"
local BANG_ATLAS, GREY_ATLAS, REPEAT_ATLAS = "QuestNormal", "TrivialQuests", "QuestDaily"
local BANG_FILE = "Interface\\GossipFrame\\AvailableQuestIcon"
local PERCENT = Completo.C.PERCENT
local QUEST_PIN_SCALE = 0.5
local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE", "CALENDAR_UPDATE_EVENT_LIST" }
local OWN_KEYS = { enabled = true, mapPins = true, mapGrey = true, mapChainsOnly = true, mapPinSize = true,
    mapDungeon = true, mapDungeonColor = true }
local TEXT_GIVER = ns.L("Quest giver")
local TEXT_DROPS = ns.L("Drops %s, which begins:")
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_REPEATABLE = ns.L("Repeatable, ")
local TEXT_DUNGEON = ns.L("Dungeon, ")
local TEXT_WAYPOINT = ns.L("Click for a waypoint (again to remove it).")
local TEXT_HIDE = ns.L("Hide %s")
local TEXT_HIDE_HINT = ns.L("Right-click to hide a quest from the map.")
local TEXT_SHIFT_HINT = ns.L("Hold Shift for rewards and the rest of the chain.")
local TEXT_NEXT = ns.L("Next in chain:")
local TEXT_BREADCRUMBS = ns.L("Also sent here by:")
local TEXT_XP = ns.L("%s XP")
local TEXT_REPUTATION = ns.L("%+d %s")
local TEXT_INSTANCE = ns.L("Instance: %s")
local INDENT = "    "
local SHIFT_KEYS = { LSHIFT = true, RSHIFT = true }
local GAIN_RGB = { r = 0.86, g = 0.86, b = 0.86 }
local REPUTATION_RGB = { r = 0.5, g = 0.75, b = 1 }
local XP_SEP = "   "
local GAINS_XP, GAINS_MONEY, GAINS_REPUTATION = 1, 2, 3
local XP_FULL_LEVELS = 5
local XP_TENTHS, XP_TENTHS_LOST_PER_LEVEL, XP_MIN_TENTHS = 10, 2, 5
local XP_ROUNDING = { { 100, 5 }, { 500, 10 }, { 1000, 25 } }
local XP_ROUNDING_TOP = 50

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added, events, shiftWatch, hovered

local function ScaleQuestPin(pin)
    ns.Shared.ScalePin(pin, QUEST_PIN_SCALE)
end

NaowhForeverQuestGiverPinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverQuestGiverPinMixin.ApplyCurrentScale = ScaleQuestPin

local function On()
    return S.Get("enabled") and S.Get("mapPins")
end

local function SetMark(icon, giver)
    icon:SetVertexColor(1, 1, 1)
    icon:SetDesaturated(false)
    local tint
    local dungeon = giver.dungeon and S.Get("mapDungeon")
    if giver.repeatable and not dungeon then
        if icon:SetAtlas(REPEAT_ATLAS) then return end
        tint = Style.REPEAT_RGB
    elseif giver.grey then
        if icon:SetAtlas(GREY_ATLAS) then return end
        tint = Style.GREY_RGB
    elseif dungeon then
        tint = S.Get("mapDungeonColor") or Style.DUNGEON_RGB
    end
    if not icon:SetAtlas(BANG_ATLAS) then icon:SetTexture(BANG_FILE) end
    if not tint then return end
    icon:SetDesaturated(true)
    icon:SetVertexColor(tint.r, tint.g, tint.b)
end

local function AddQuestLine(id, indent)
    local c = Q.Trivial(id) and Style.GREY_RGB or GetQuestDifficultyColor(Q.Level(id))
    local level = TEXT_LEVEL:format(Q.Level(id))
    if Q.Repeatable(id) then level = TEXT_REPEATABLE .. level end
    if Q.Dungeon(id) and not Q.Battleground(id) then level = TEXT_DUNGEON .. level end
    GameTooltip:AddDoubleLine((indent or "") .. Q.Name(id), level, c.r, c.g, c.b, c.r, c.g, c.b)
end

local function NextSteps(id)
    local chain = Q.Chain(id)
    if not chain then return end
    local at, steps = Q.ChainStep(id)
    if at < steps then return chain.steps, at + 1 end
end

local function OpenBreadcrumbs(id)
    local open
    for _, other in ipairs(Q.Breadcrumbs(id)) do
        if Q.Available(other) and not Q.Hidden(other) then
            open = open or {}
            open[#open + 1] = other
        end
    end
    return open
end

local function XPAtLevel(xp, questLevel)
    local level = UnitLevel("player")
    if level >= GetMaxLevelForPlayerExpansion() then return 0 end
    local over = level - questLevel - XP_FULL_LEVELS
    if questLevel <= 0 or over <= 0 then return xp end
    xp = math.floor(xp * math.max(XP_TENTHS - XP_TENTHS_LOST_PER_LEVEL * over, XP_MIN_TENTHS) / XP_TENTHS)
    local step = XP_ROUNDING_TOP
    for _, rounding in ipairs(XP_ROUNDING) do
        if xp <= rounding[1] then
            step = rounding[2]
            break
        end
    end
    return step * math.floor((xp + math.floor(step / 2)) / step)
end

local function HasGains(id)
    local gains = Q.Gains(id)
    return Q.Instance(id) ~= nil or gains ~= nil and (#gains >= GAINS_REPUTATION or gains[GAINS_MONEY] > 0
        or XPAtLevel(gains[GAINS_XP], Q.Level(id)) > 0)
end

local function AddGains(id)
    local gains = Q.Gains(id)
    if gains then
        local xp = XPAtLevel(gains[GAINS_XP], Q.Level(id))
        local parts = {}
        if xp > 0 then parts[#parts + 1] = TEXT_XP:format(BreakUpLargeNumbers(xp)) end
        if gains[GAINS_MONEY] > 0 then parts[#parts + 1] = C_CurrencyInfo.GetCoinTextureString(gains[GAINS_MONEY]) end
        if #parts > 0 then
            GameTooltip:AddLine(INDENT .. table.concat(parts, XP_SEP), GAIN_RGB.r, GAIN_RGB.g, GAIN_RGB.b)
        end
        for i = GAINS_REPUTATION, #gains, 2 do
            local faction = C_Reputation.GetFactionDataByID(gains[i])
            if faction then
                GameTooltip:AddLine(INDENT .. TEXT_REPUTATION:format(gains[i + 1], faction.name),
                    REPUTATION_RGB.r, REPUTATION_RGB.g, REPUTATION_RGB.b)
            end
        end
    end
    local area = Q.Instance(id)
    local name = area and C_Map.GetAreaInfo(area)
    if name then GameTooltip:AddLine(INDENT .. TEXT_INSTANCE:format(name), GAIN_RGB.r, GAIN_RGB.g, GAIN_RGB.b) end
end

local function AddMore(id)
    local any = HasGains(id)
    if IsShiftKeyDown() then AddGains(id) end
    local open = OpenBreadcrumbs(id)
    if open then
        any = true
        if IsShiftKeyDown() then
            GameTooltip:AddLine(INDENT .. TEXT_BREADCRUMBS, Style.Hint())
            for _, other in ipairs(open) do AddQuestLine(other, INDENT .. INDENT) end
        end
    end
    local steps, from = NextSteps(id)
    if steps then
        any = true
        if IsShiftKeyDown() then
            GameTooltip:AddLine(INDENT .. TEXT_NEXT, Style.Hint())
            for i = from, #steps do
                local step = steps[i]
                if step.any then
                    AddQuestLine(step[1], INDENT .. INDENT)
                else
                    for _, other in ipairs(step) do AddQuestLine(other, INDENT .. INDENT) end
                end
            end
        end
    end
    return any
end

local function ShiftChanged(_, _, key)
    if not SHIFT_KEYS[key] then return end
    if hovered and GameTooltip:IsShown() and GameTooltip:GetOwner() == hovered then
        NaowhForeverQuestGiverPinMixin.OnMouseEnter(hovered)
    else
        hovered = nil
        shiftWatch:UnregisterEvent("MODIFIER_STATE_CHANGED")
    end
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function OnQuestEvent()
    Q.Stale()
    Redraw()
end

local function HideButton(root, id)
    root:CreateButton(TEXT_HIDE:format(Q.Title(id) or id), function() Q.SetHidden(id, true) end)
end

function Completo.HideMenu(owner, quests)
    ns.ContextMenu(owner, function(_, root)
        for _, id in ipairs(quests) do HideButton(root, id) end
    end)
end

Completo.TEXT_HIDE_HINT = TEXT_HIDE_HINT

function NaowhForeverQuestGiverPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function NaowhForeverQuestGiverPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverQuestGiverPinMixin:Paint(giver, size)
    self.quests = self.quests or {}
    wipe(self.quests)
    for i, id in ipairs(giver.quests) do self.quests[i] = id end
    self.grey = giver.grey
    self:SetSize(size, size)
    SetMark(self.Icon, giver)
end

function NaowhForeverQuestGiverPinMixin:OnAcquired(giver, x, y)
    ns.Shared.PinClicks(self)
    self:Paint(giver, S.Get("mapPinSize"))
    self:SetPosition(x, y)
    self:ApplyCurrentScale()
end

function NaowhForeverQuestGiverPinMixin:OnMouseEnter()
    local first = self.quests[1]
    local gold = Style.GOLD_RGB
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Q.Giver(first) or TEXT_GIVER, 1, 1, 1)
    local item = Q.Item(first)
    if item then
        local name = C_Item.GetItemNameByID(item) or Q.Name(first)
        GameTooltip:AddLine(TEXT_DROPS:format(name), gold.r, gold.g, gold.b)
    end
    local more = false
    for _, id in ipairs(self.quests) do
        AddQuestLine(id)
        if AddMore(id) then more = true end
    end
    GameTooltip:AddLine(TEXT_WAYPOINT, Style.Hint())
    GameTooltip:AddLine(TEXT_HIDE_HINT, Style.Hint())
    if more and not IsShiftKeyDown() then GameTooltip:AddLine(TEXT_SHIFT_HINT, Style.Hint()) end
    GameTooltip:Show()
    if not more then return end
    if not shiftWatch then
        shiftWatch = CreateFrame("Frame")
        shiftWatch:SetScript("OnEvent", ShiftChanged)
    end
    hovered = self
    shiftWatch:RegisterEvent("MODIFIER_STATE_CHANGED")
end

function NaowhForeverQuestGiverPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function NaowhForeverQuestGiverPinMixin:OnClick(button)
    if button == "RightButton" then return Completo.HideMenu(self, self.quests) end
    if button ~= "LeftButton" then return end
    local first = self.quests[1]
    local map, x, y = Q.Spot(first)
    if map then ns.ToggleWaypoint(Q.Giver(first) or Q.Name(first), map, x, y) end
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    local maps, any = OpenMap.Maps(map), false
    for _, mapID in ipairs(maps) do any = any or Q.HasGivers(mapID) end
    if not any then return end
    Q.Update()
    for _, mapID in ipairs(maps) do
        for _, giver in ipairs(Q.Givers(mapID, S.Get("mapGrey"), S.Get("mapChainsOnly"))) do
            local x, y = OpenMap.Spot(map, mapID, giver.x / PERCENT, giver.y / PERCENT)
            if x then map:AcquirePin(TEMPLATE, giver, x, y) end
        end
    end
end

local function Apply()
    if On() then
        if not added then
            WorldMapFrame:AddDataProvider(provider)
            added = true
        end
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnQuestEvent)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    elseif events then
        events:UnregisterAllEvents()
    end
    Redraw()
end

local function OnSet(key)
    if OWN_KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(Q, "SetHidden", Redraw)
hooksecurefunc(Q, "ShowHidden", Redraw)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
