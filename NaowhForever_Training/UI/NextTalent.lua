-- NextTalent.lua: turns the next-talent glow and side panel on and off, and redraws them while a talent window is open.
local ns = _G.NaowhForever

local Training = ns.Training
local S = Training.Settings
local Next = Training.Next

local WINDOW_ADDONS = { "Blizzard_PlayerSpells", "EllesmereUIForeverEssentials" }
local EVENTS = {
    "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_NODE_ENTRY_UPDATED",
    "TRAIT_TREE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_TALENT_UPDATE",
}
local SPELL_EVENT = "SPELL_DATA_LOAD_RESULT"
local MAX_RETRIES = 10
local GLOW_KEY = "nextTalentGlow"
local DRAWER_KEY = "nextTalentDrawer"
local TEXT_TITLE = ns.L("Next Talent")

local view = { title = TEXT_TITLE, openKey = DRAWER_KEY }

local events
local installed = false
local queued = false
local listeningForTalents = false
local listeningForSpellNames = false
local ellesmereHooked = false
local retries = 0
local hooked = {}
local Refresh

local function On()
    return Training.On() and S.Get("nextTalent") and not ns.GamepadStandDown()
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, Refresh)
end

local function Schedule()
    if not installed or not On() then return end
    retries = 0
    Queue()
end

local function ListenForTalents(windowOpen)
    if windowOpen == listeningForTalents then return end
    listeningForTalents = windowOpen
    if windowOpen then
        for _, event in ipairs(EVENTS) do
            events:RegisterEvent(event)
        end
    else
        events:UnregisterAllEvents()
        listeningForSpellNames = false
    end
end

local function ListenForSpellNames(wanted)
    if wanted == listeningForSpellNames then return end
    listeningForSpellNames = wanted
    if wanted then
        events:RegisterEvent(SPELL_EVENT)
    else
        events:UnregisterEvent(SPELL_EVENT)
    end
end

local function Hook(page)
    if hooked[page] then return end
    hooked[page] = true
    page:HookScript("OnShow", Schedule)
    page:HookScript("OnHide", Schedule)
end

local function OnEllesmereEscape(frame)
    if not frame then return end
    if frame == EUI_ClassicTalents then Hook(frame) end
end

local function HookEllesmere()
    if ellesmereHooked then return end
    if not EllesmereUI or not EllesmereUI.RegisterEscapeClose then return end
    ellesmereHooked = true
    hooksecurefunc(EllesmereUI, "RegisterEscapeClose", OnEllesmereEscape)
end

local function OnWindowAddOnLoaded()
    Next.EachTalentPage(Hook)
    HookEllesmere()
    Schedule()
end

local function ClearView()
    Next.HideDrawer(view, false)
    Next.PlaceMark(view.mark, nil)
    view.open = false
end

local function UpdateDrawer(window, model)
    Next.PaintButton(view)
    if not S.Get(DRAWER_KEY) then
        Next.HideDrawer(view, false)
        return
    end
    local summary = Next.DrawerSummary(model)
    if summary ~= view.paintedSummary then
        view.paintedSummary = summary
        Next.PaintDrawer(view, model)
    end
    Next.ShowDrawer(view, window)
end

local function UpdateMark(window, model)
    if model.count == 0 or not S.Get(GLOW_KEY) then
        Next.PlaceMark(view.mark, nil)
        return
    end
    local nextTalent = model.rows[1]
    local button = Next.ButtonFor(view.mark, window, nextTalent.node)
    Next.PlaceMark(view.mark, button, nextTalent.ready)
    if not button then view.buttonMissing = true end
end

local function UpdateView()
    view.buttonMissing = false
    view.namesLoading = false
    local window = Next.ClassWindow()
    if not window then
        ClearView()
        return
    end
    view.open = true
    Hook(window.content)
    if view.docked ~= window.content then
        view.docked = window.content
        view.paintedSummary = nil
        Next.HideDrawer(view, false)
        Next.Dock(view, window)
    end
    local model = Next.ClassModel()
    view.namesLoading = model.namesLoading
    UpdateDrawer(window, model)
    UpdateMark(window, model)
end

function Refresh()
    queued = false
    if not installed or not On() then return end
    UpdateView()
    ListenForTalents(view.open)
    ListenForSpellNames(view.open and view.namesLoading)
    if view.buttonMissing and retries < MAX_RETRIES then
        retries = retries + 1
        Queue()
    end
end

local function Quiet()
    if events then events:UnregisterAllEvents() end
    listeningForTalents = false
    listeningForSpellNames = false
    Next.HideDrawer(view, true)
    if view.mark then Next.PlaceMark(view.mark, nil) end
    view.open = false
    view.docked = nil
    view.paintedSummary = nil
end

local function Install()
    installed = true
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", Schedule)
    view.mark = Next.NewMark()
    for _, name in ipairs(WINDOW_ADDONS) do
        EventUtil.ContinueOnAddOnLoaded(name, OnWindowAddOnLoaded)
    end
end

local function Apply()
    if not On() then
        Quiet()
        return
    end
    if not installed then Install() end
    Schedule()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "nextTalent" then
        Apply()
    elseif key == GLOW_KEY or key == DRAWER_KEY then
        Schedule()
    end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

Next.Redraw = Schedule
Training.OnChange(Schedule)
S.OnChange(OnSettingChanged)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
