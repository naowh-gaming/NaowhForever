-- SettingsPage.lua: the AuraBuffs/Settings page's banner and Window card; each reminder adds its own card.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local PERCENT, ROUND = 100, 0.5
local SOUND_TRIGGER = "auraSound"

local TEXT_OFF = "AuraBuffs is off"
local TEXT_NOTHING = "No consumables to watch yet"
local TEXT_DETAIL = "Add the consumables to watch, and debuffs that play a sound, in the AuraBuffs window."

local function DebuffSounds()
    local I = ns.Integrations
    local rules = I and I.Rules and I.Rules(false)
    local n = 0
    for _, rule in pairs(rules or {}) do
        if type(rule) == "table" and rule.trigger and rule.trigger.type == SOUND_TRIGGER then n = n + 1 end
    end
    return n
end

local function Headline()
    if not S.Get("enabled") then return TEXT_OFF end
    local n = #(S.Get("consumableEntries") or {})
    if n == 0 then return TEXT_NOTHING end
    return ("%d %s to watch"):format(n, n == 1 and "consumable" or "consumables")
end

local function Detail()
    local n = DebuffSounds()
    if n == 0 then return TEXT_DETAIL end
    return ("%d %s play a sound. Edit both lists in the AuraBuffs window."):format(n,
        n == 1 and "debuff" or "debuffs")
end

local function WindowSummary(store)
    return ("%d%% opacity"):format(math.floor((store.Get("windowAlpha") or 1) * PERCENT + ROUND))
end

local function OpenWindow()
    ns.OpenAuraBuffsWindow()
end

local page = Settings.Page(A.PAGE, S)

page:Window({
    text = "Open AuraBuffs",
    open = OpenWindow,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "window", name = "Window", order = 50,
    help = "The AuraBuffs window: the consumables to watch and the debuffs that play a sound.",
    summary = WindowSummary,
    rows = {
        { key = "windowAlpha", label = "Window Opacity", slider = { ns.Shared.Style.OPACITY_MIN, 100, 5 }, unit = "%",
          scale = 0.01, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
