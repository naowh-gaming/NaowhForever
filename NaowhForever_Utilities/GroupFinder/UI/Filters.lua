-- Filters.lua: the panel's Filters view: your saved filters, open spots, what the group has, the leader, playstyle, players on their own by class and level, declined groups and a typed filter; listings that miss one stay in the game's list, dimmed (ns.GroupFinder.UI.Filters).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Filter = GF.Filter
local UI = GF.UI
local St = UI.Style
local T = ns.THEME
local S = GF.Settings
local Style = ns.Shared.Style

local SCORE_STEP, SCORE_MAX = 5, 300
local WORDS_MENU_H = 320
local TEXT_SEARCH = "Search"
local TEXT_SEARCH_HINT = "Leader, dungeon or note"
local TEXT_OPEN = "Open spot for"
local TEXT_PARTY = "Room for my whole party"
local TEXT_HAS = "Group has"
local TEXT_HAS_HINT = ns.L("click again for lacks")
local TEXT_LEADER = "Leader"
local TEXT_MIN = "Minimum Gear Score"
local TEXT_DECLINED = "Hide groups that declined me"
local TEXT_ADVANCED = "Advanced filter"
local TEXT_WORDS = "Words"
local TEXT_EXPR_HINT = "healerOpen > 0 and age < 10"
local TEXT_FILTERING = ns.L("Filtering with this.")
local TEXT_ON = ns.L("%d filters on")
local TEXT_ONE = ns.L("1 filter on")
local TEXT_NONE = ns.L("No filters on")
local TEXT_RESET = "Reset"
local TEXT_ADD_CLASS = ns.L("+ Class")
local TEXT_ANY = ns.L("Any")
local HAS_LABEL = { myClass = ns.L("My class"), bloodlust = ns.L("Bloodlust"), battleRes = ns.L("Battle res"),
    friend = ns.L("Friend or guild") }
local TEXT_SCORE = "%.1f"
local TEXT_MY_FILTERS = "My filters"
local TEXT_SAVE = "Save new filter"
local TEXT_SAVE_PROMPT = "Name your filter:"
local TEXT_NO_PRESETS = ns.L("No saved filters yet")
local TEXT_DELETE = ns.L("Delete")
local TEXT_FULL = ns.L("My filters holds up to %d filters. Delete one to save a new filter.")
local TEXT_SOLO = "Players on their own"
local TEXT_SOLO_HINT = ns.L("players listed alone")
local TEXT_LEVEL_MIN = "Lowest level"
local TEXT_LEVEL_MAX = "Highest level"
local LEVEL_STEP = 1
local names = {}

local Filters = {}
UI.Filters = Filters

local view

local function Changed()
    Filter.Changed()
end

local function ToggleRole(role)
    Filter.roles[role] = not Filter.roles[role] or nil
    Changed()
end

local function ClassMenu(owner)
    ns.DropdownMenu(owner, function(root)
        for _, class in ipairs(Filter.CLASSES) do
            root:CreateButton(LOCALIZED_CLASS_NAMES_MALE[class], function() Filter.AddClass(class) end)
        end
    end)
end

local function AppendWord(word)
    local text = Filter.expr
    if text ~= "" and not text:find("%s$") then text = text .. " " end
    Filter.expr = (text .. word):sub(1, Filter.EXPR_MAX)
    view.expr:SetText(Filter.expr)
    Changed()
end

local function WordsMenu(owner)
    ns.DropdownMenu(owner, function(root)
        for _, word in ipairs(Filter.WORDS) do
            root:CreateButton(word, function() AppendWord(word) end)
        end
        root:CreateDivider()
        for _, op in ipairs(Filter.OPERATORS) do
            root:CreateButton(op, function() AppendWord(op) end)
        end
    end, WORDS_MENU_H)
end

local function PresetMenu(owner)
    Filter.PresetNames(names)
    ns.DropdownMenu(owner, function(root)
        if #names == 0 then
            root:CreateTitle(TEXT_NO_PRESETS)
            return
        end
        for _, name in ipairs(names) do
            root:CreateButton(name, function() Filter.LoadPreset(name) end)
        end
        root:CreateDivider()
        local delete = root:CreateButton(TEXT_DELETE)
        for _, name in ipairs(names) do
            delete:CreateButton(name, function() Filter.DeletePreset(name) end)
        end
    end)
end

local function SavePreset()
    ns.PromptText(TEXT_SAVE_PROMPT, "", Filter.PRESET_NAME_MAX, function(name)
        local ok, why = Filter.SavePreset(name)
        if not ok and why == "full" then ns.Print(TEXT_FULL:format(Filter.PRESETS_MAX)) end
    end)
end

local function LevelStepper(label, key)
    local stepper = UI.Stepper(view, label, function() return Filter[key] end, function(v)
        Filter[key] = v
        if Filter.levelMin > 0 and Filter.levelMax > 0 and Filter.levelMin > Filter.levelMax then
            if key == "levelMin" then Filter.levelMax = v else Filter.levelMin = v end
        end
        Changed()
    end, LEVEL_STEP, 0, GetMaxLevelForPlayerExpansion())
    stepper.Refresh = function()
        stepper.value:SetText(Filter[key] > 0 and tostring(Filter[key]) or TEXT_ANY)
    end
    return stepper
end

local function HasChip(key)
    local chip = UI.Chip(view.hasRow, function() Filter.Cycle(key) end)
    chip.key = key
    return chip
end

local function Build(parent)
    view = CreateFrame("Frame", nil, parent)
    view.stack = UI.Stack(view)
    view.presetRow = CreateFrame("Frame", nil, view)
    view.presets = ns.Shared.Parts.Link(view.presetRow, function() PresetMenu(view.presets) end, true)
    ns.Shared.Parts.SetLink(view.presets, TEXT_MY_FILTERS)
    view.presets:SetPoint("LEFT")
    view.save = ns.Shared.Parts.Link(view.presetRow, SavePreset)
    ns.Shared.Parts.SetLink(view.save, TEXT_SAVE)
    view.save:SetPoint("RIGHT")
    view.searchKicker = UI.Kicker(view, TEXT_SEARCH)
    view.search = UI.EditLine(view, TEXT_SEARCH_HINT, Filter.EXPR_MAX, function(text)
        if view.filling or text == Filter.q then return end
        Filter.q = text
        Filter.Changed()
        Filters.RefreshStatus()
    end)
    view.openKicker = UI.Kicker(view, TEXT_OPEN)
    view.roleRow = CreateFrame("Frame", nil, view)
    view.roles = {}
    for i, role in ipairs(UI.ROLES) do
        local button = ns.Button(view.roleRow, UI.ROLE_LABEL[role], St.ROLE_BUTTON, St.BUTTON_H,
            function() ToggleRole(role) end)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAtlas(St.ROLE_MICRO[role])
        button.icon:SetSize(St.SQUARE_ICON, St.SQUARE_ICON)
        button.icon:SetPoint("RIGHT", button.label, "LEFT", -St.GAP / 2, 0)
        button.role = role
        view.roles[i] = button
    end
    view.party = UI.Check(view, TEXT_PARTY, function() return Filter.partyFit end, function(v)
        Filter.partyFit = v
        Changed()
    end)
    view.hasHead = CreateFrame("Frame", nil, view)
    UI.Kicker(view.hasHead, TEXT_HAS):SetPoint("LEFT")
    local hint = ns.Font(view.hasHead, St.SUB_SIZE, nil, T.muted)
    hint:SetPoint("RIGHT")
    hint:SetText(TEXT_HAS_HINT)
    view.hasRow = CreateFrame("Frame", nil, view)
    view.hasChips, view.classChips = {}, {}
    for _, key in ipairs(Filter.HAS_KEYS) do view.hasChips[#view.hasChips + 1] = HasChip(key) end
    view.addClass = UI.Chip(view.hasRow, function() ClassMenu(view.addClass) end)
    view.leaderKicker = UI.Kicker(view, TEXT_LEADER)
    view.min = UI.Stepper(view, TEXT_MIN, function() return Filter.minScore end, function(v)
        Filter.minScore = v
        Changed()
    end, SCORE_STEP, 0, SCORE_MAX)
    view.min.Refresh = function()
        view.min.value:SetText(Filter.minScore > 0 and TEXT_SCORE:format(Filter.minScore / UI.TENTHS) or TEXT_ANY)
    end
    view.styleRow = CreateFrame("Frame", nil, view)
    view.styleChips = {}
    for i = 1, #UI.STYLES do
        local chip = UI.Chip(view.styleRow, function()
            Filter.styles[i] = not Filter.styles[i] or nil
            Changed()
        end)
        chip.style = i
        view.styleChips[i] = chip
    end
    view.soloHead = CreateFrame("Frame", nil, view)
    UI.Kicker(view.soloHead, TEXT_SOLO):SetPoint("LEFT")
    local soloHint = ns.Font(view.soloHead, St.SUB_SIZE, nil, T.muted)
    soloHint:SetPoint("RIGHT")
    soloHint:SetText(TEXT_SOLO_HINT)
    view.soloRow = CreateFrame("Frame", nil, view)
    view.soloChips = {}
    for i, class in ipairs(Filter.CLASSES) do
        local chip = UI.Chip(view.soloRow, function()
            Filter.soloClasses[class] = not Filter.soloClasses[class] or nil
            Changed()
        end)
        chip.class = class
        view.soloChips[i] = chip
    end
    view.levelMin = LevelStepper(TEXT_LEVEL_MIN, "levelMin")
    view.levelMax = LevelStepper(TEXT_LEVEL_MAX, "levelMax")
    view.declined = UI.Check(view, TEXT_DECLINED, function() return S.Get("hideDeclined") end, function(v)
        S.Set("hideDeclined", v)
        Changed()
    end)
    view.exprHead = CreateFrame("Frame", nil, view)
    UI.Kicker(view.exprHead, TEXT_ADVANCED):SetPoint("LEFT")
    view.words = ns.Shared.Parts.Link(view.exprHead, function() WordsMenu(view.words) end, true)
    ns.Shared.Parts.SetLink(view.words, TEXT_WORDS)
    view.words:SetPoint("RIGHT")
    view.expr = UI.EditLine(view, TEXT_EXPR_HINT, Filter.EXPR_MAX, function(text)
        if view.filling then return end
        Filter.expr = text
        Filter.Changed()
        Filters.RefreshStatus()
    end)
    view.exprState = ns.Font(view, St.SUB_SIZE)
    view.exprState:SetJustifyH("LEFT")
    view.foot = CreateFrame("Frame", nil, view)
    view.count = ns.Font(view.foot, St.SUB_SIZE, nil, T.muted)
    view.count:SetPoint("LEFT")
    view.reset = ns.Button(view.foot, TEXT_RESET, St.APPLY_W, St.SMALL_BUTTON_H, function()
        Filter.Reset()
        view.filling = true
        view.expr:SetText("")
        view.search:SetText("")
        view.filling = false
    end)
    view.reset:SetPoint("RIGHT")
    return view
end

function Filters.RefreshStatus()
    local fn, err = Filter.Expression()
    if err then
        view.exprState:SetText(err)
        view.exprState:SetTextColor(Style.RED_RGB.r, Style.RED_RGB.g, Style.RED_RGB.b)
    elseif fn then
        view.exprState:SetText(TEXT_FILTERING)
        view.exprState:SetTextColor(Style.HAVE_RGB.r, Style.HAVE_RGB.g, Style.HAVE_RGB.b)
    else
        view.exprState:SetText("")
    end
    local n = Filter.Count()
    view.count:SetText(n == 0 and TEXT_NONE or n == 1 and TEXT_ONE or TEXT_ON:format(n))
end

function Filters.Refresh()
    if not (view and view:IsShown()) then return end
    local stack, width = view.stack, view:GetWidth()
    stack:Reset()
    stack:Put(view.presetRow, St.LINE_H, St.GAP)
    stack:Put(view.searchKicker, St.KICKER_SIZE + 2, St.GAP)
    if view.search:GetText() ~= Filter.q and not view.search:HasFocus() then
        view.filling = true
        view.search:SetText(Filter.q)
        view.filling = false
    end
    stack:Put(view.search, St.EDIT_H, St.PANEL_GAP)
    stack:Put(view.openKicker, St.KICKER_SIZE + 2, St.GAP)
    local w = math.floor((width - 2 * St.GAP) / #view.roles)
    for i, button in ipairs(view.roles) do
        button:SetSize(w, St.BUTTON_H)
        button:ClearAllPoints()
        button:SetPoint("LEFT", view.roleRow, "LEFT", (i - 1) * (w + St.GAP), 0)
        local on = Filter.roles[button.role] == true
        UI.Pick(button, on)
        button.icon:SetDesaturated(not on)
    end
    stack:Put(view.roleRow, St.BUTTON_H, St.GAP)
    view.party.toggle._refreshValue()
    stack:Put(view.party, St.TOGGLE_H, St.PANEL_GAP)
    stack:Put(view.hasHead, St.KICKER_SIZE + 2, St.GAP)
    local chips = view.flow or {}
    view.flow = chips
    wipe(chips)
    for _, chip in ipairs(view.hasChips) do
        UI.SetChip(chip, HAS_LABEL[chip.key], Filter.has[chip.key])
        chips[#chips + 1] = chip
    end
    for i, class in ipairs(Filter.classes) do
        local chip = view.classChips[i] or UI.Chip(view.hasRow)
        view.classChips[i] = chip
        chip._onClick = function() Filter.Cycle(class) end
        UI.SetChip(chip, LOCALIZED_CLASS_NAMES_MALE[class], Filter.has[class])
        chip:Show()
        chips[#chips + 1] = chip
    end
    for i = #Filter.classes + 1, #view.classChips do view.classChips[i]:Hide() end
    UI.SetChip(view.addClass, TEXT_ADD_CLASS)
    chips[#chips + 1] = view.addClass
    stack:Put(view.hasRow, UI.Flow(view.hasRow, chips, width), St.PANEL_GAP)
    stack:Put(view.leaderKicker, St.KICKER_SIZE + 2, St.GAP)
    if not ns.CHINA then
        view.min.Refresh()
        stack:Put(view.min, St.SMALL_BUTTON_H, St.GAP)
    end
    for i, chip in ipairs(view.styleChips) do
        UI.SetChip(chip, UI.STYLES[i], Filter.styles[i] and Filter.HAS or nil)
    end
    stack:Put(view.styleRow, UI.Flow(view.styleRow, view.styleChips, width), St.PANEL_GAP)
    stack:Put(view.soloHead, St.KICKER_SIZE + 2, St.GAP)
    for _, chip in ipairs(view.soloChips) do
        UI.SetChip(chip, LOCALIZED_CLASS_NAMES_MALE[chip.class], Filter.soloClasses[chip.class] and Filter.HAS or nil)
    end
    stack:Put(view.soloRow, UI.Flow(view.soloRow, view.soloChips, width), St.GAP)
    view.levelMin.Refresh()
    stack:Put(view.levelMin, St.SMALL_BUTTON_H, St.GAP / 2)
    view.levelMax.Refresh()
    stack:Put(view.levelMax, St.SMALL_BUTTON_H, St.PANEL_GAP)
    view.declined.toggle._refreshValue()
    stack:Put(view.declined, St.TOGGLE_H, St.PANEL_GAP)
    stack:Put(view.exprHead, St.KICKER_SIZE + 2, St.GAP)
    if view.expr:GetText() ~= Filter.expr then
        view.filling = true
        view.expr:SetText(Filter.expr)
        view.filling = false
    end
    stack:Put(view.expr, St.EDIT_H, St.GAP)
    stack:Put(view.exprState, St.LINE_H, St.PANEL_GAP)
    stack:Put(view.foot, St.SMALL_BUTTON_H, 0)
    Filters.RefreshStatus()
    return stack:Finish()
end

function Filters.Build(parent)
    return Build(parent)
end
