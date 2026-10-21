-- Toast.lua: the Level-Up Toast: on a level-up with spells to train, how many, what they cost, and buttons.
local ns = _G.NaowhForever

local Training = ns.Training
local S = Training.Settings
local Parts = ns.Shared.Parts

local FRAME_NAME = "NaowhForeverTrainingToast"
local SPELL = Training.C.ENTRY_SPELL
local TOAST_W, TOAST_ICONS = 440, 10
local OPEN_W, WAYPOINT_W, DISMISS_W = 140, 100, 90
local TOAST_SECONDS = 20
local LEARN_SETTLE = 1
local TEXT_LEVEL = ns.L("Level ")
local TEXT_ONE_SPELL, TEXT_SPELLS = ns.L("1 spell"), ns.L(" spells")
local TEXT_LINE = ns.L("%s to train, %s in all. %s")
local TEXT_AFFORD_ALL = ns.L("You can afford every one.")
local TEXT_AFFORD_SOME = ns.L("You can afford %d of them.")
local TEXT_OPEN, TEXT_WAYPOINT, TEXT_DISMISS = ns.L("Open Planner"), ns.L("Waypoint"), ns.L("Dismiss")

local toast
local textures = {}
local events = CreateFrame("Frame")

local function On()
    return Training.On() and S.Get("levelUpToast")
end

local function OpenPlanner()
    toast:Hide()
    ns.OpenTrainingWindow()
end

local function Waypoint()
    Training.WaypointToTrainer()
end

local function Dismiss()
    toast:Hide()
end

local function Build()
    toast = Parts.Toast({ name = FRAME_NAME, width = TOAST_W, icons = TOAST_ICONS, store = S, posKey = "toastPos", on = On,
        buttons = {
            { text = TEXT_OPEN, width = OPEN_W, click = OpenPlanner, accent = true },
            { text = TEXT_WAYPOINT, width = WAYPOINT_W, click = Waypoint },
            { text = TEXT_DISMISS, width = DISMISS_W, click = Dismiss },
        } })
end

local function Affordable(plan)
    local afford, budget = 0, GetMoney()
    for _, entry in ipairs(plan.now) do
        local price = Training.Price(entry)
        if price <= budget then
            afford = afford + 1
            budget = budget - price
        end
    end
    return afford
end

local function Fill(level, plan)
    local cost = Training.Total(plan.now)
    local afford = Affordable(plan)
    local count = #plan.now == 1 and TEXT_ONE_SPELL or (#plan.now .. TEXT_SPELLS)
    wipe(textures)
    for i = 1, math.min(#plan.now, TOAST_ICONS) do textures[i] = C_Spell.GetSpellTexture(plan.now[i][SPELL]) end
    Parts.FillToast(toast, TEXT_LEVEL .. level, TEXT_LINE:format(count, Training.Coins(cost),
        afford == #plan.now and TEXT_AFFORD_ALL or TEXT_AFFORD_SOME:format(afford)), textures)
end

local function Show(level)
    local plan = Training.Plan(level)
    if #plan.now == 0 then return end
    if not toast then Build() end
    Fill(level, plan)
    Parts.ShowToast(toast, TOAST_SECONDS)
end

local function OnLevelUp(_, _, level)
    C_Timer.After(LEARN_SETTLE, function() if On() then Show(level) end end)
end

local function Apply()
    events:UnregisterAllEvents()
    if toast and not On() then toast:Hide() end
    if On() then events:RegisterEvent("PLAYER_LEVEL_UP") end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "levelUpToast" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

events:SetScript("OnEvent", OnLevelUp)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
