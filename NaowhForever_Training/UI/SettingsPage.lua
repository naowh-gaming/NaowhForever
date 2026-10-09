-- SettingsPage.lua: the Training Planner settings page (Training Planner/Settings), declared as cards.
local ns = _G.NaowhForever

local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Settings = ns.Shared.Settings

local PERCENT = 100
local OPACITY_MAX, OPACITY_STEP = 100, 5
local TEXT_OFF = "Turn on the Training Planner"
local TEXT_OPEN = "Open Training Planner"
local TEXT_TRAIN_NOW = "%d %s to train now, %s"
local TEXT_SPELL, TEXT_SPELLS = "spell", "spells"
local TEXT_NEW_AT = "New spells at level "
local TEXT_KNOW_ALL = "You know every spell your class trains"
local TEXT_DETAIL = "%s left to pay on the road to 60. %d talent %s for your class."
local TEXT_BUILD, TEXT_BUILDS = "build", "builds"
local TEXT_BOTH, TEXT_TOAST, TEXT_PANEL, TEXT_NOTHING =
    "Level-up toast and trainer panel", "Level-up toast", "Trainer panel", "Nothing on the way"
local TEXT_WINDOW = "%d%% opacity%s"
local TEXT_MINI_SHOWN = ", mini bar shown"
local TEXT_GLOW_RANKS, TEXT_GLOW, TEXT_RANKS, TEXT_LISTS =
    "Glows new abilities, offers rank swaps", "Glows new abilities", "Offers rank swaps", "Lists what you learned"

local function Headline(plan)
    if #plan.now > 0 then
        return TEXT_TRAIN_NOW:format(#plan.now, #plan.now == 1 and TEXT_SPELL or TEXT_SPELLS,
            Training.Coins(Training.Total(plan.now)))
    end
    if plan.soon[1] or plan.later[1] then return TEXT_NEW_AT .. (plan.soon[1] or plan.later[1])[1] end
    return TEXT_KNOW_ALL
end

local function CardLines()
    local plan = Training.Plan()
    local _, _, classID = UnitClass("player")
    local builds = #Training.Builds(classID)
    return Headline(plan), TEXT_DETAIL:format(Training.Coins(Training.ToSixty(plan)), builds,
        builds == 1 and TEXT_BUILD or TEXT_BUILDS)
end

local function CardHeadline()
    local headline = CardLines()
    return headline
end

local function CardDetail()
    local _, detail = CardLines()
    return detail
end

local function OpenPlanner()
    ns.OpenTrainingWindow()
end

local function OnTheWaySummary(store)
    local toast, panel = store.Get("levelUpToast"), store.Get("trainerPanel")
    if toast and panel then return TEXT_BOTH end
    if toast then return TEXT_TOAST end
    if panel then return TEXT_PANEL end
    return TEXT_NOTHING
end

local function WindowSummary(store)
    return TEXT_WINDOW:format(math.floor((store.Get("windowAlpha") or 1) * PERCENT + 0.5),
        store.Get("miniShown") and TEXT_MINI_SHOWN or "")
end

local function TrainerSummary(store)
    local glow, ranks = store.Get("trainerGlow"), store.Get("trainerRanks")
    if glow and ranks then return TEXT_GLOW_RANKS end
    if glow then return TEXT_GLOW end
    if ranks then return TEXT_RANKS end
    return TEXT_LISTS
end

local page = Settings.Page("Training Planner/Settings", S)

page:Window({
    text = TEXT_OPEN,
    open = OpenPlanner,
    headline = CardHeadline,
    detail = CardDetail,
})

page:Card({
    id = "onTheWay", name = "On the Way", order = 10,
    help = "The Training Planner's help while you level: a toast when you level up with spells to train, "
        .. "and a panel beside your class trainer.",
    summary = OnTheWaySummary,
    rows = {
        { key = "levelUpToast", label = "Level-Up Toast", toggle = true, needs = Training.On,
          why = TEXT_OFF,
          help = "When you level up with new spells to train, a toast says how many and what they cost, with "
              .. "buttons to open the planner and to put a waypoint on your nearest trainer. Move it in the "
              .. "HUD Editor." },
        { key = "trainerPanel", label = "Panel at the Trainer", toggle = true,
          needs = Training.On, why = TEXT_OFF,
          help = "Beside your class trainer, the spells you can learn now, ticked, with their total and Learn "
              .. "All I Can Afford. Untick one to leave it." },
    },
})

page:Card({
    id = "window", name = "Window", order = 20,
    help = "The planner's own window, and a mini bar to leave up while you level.",
    summary = WindowSummary,
    rows = {
        { key = "miniShown", label = "Mini Bar", toggle = true, needs = Training.On,
          why = TEXT_OFF,
          help = "A small bar with your next trainer visit and your gold, to leave up while you level. Move it "
              .. "by dragging." },
        { key = "windowAlpha", label = "Window Opacity", slider = { Style.OPACITY_MIN, OPACITY_MAX, OPACITY_STEP },
          unit = "%", scale = 1 / PERCENT, help = "How solid the planner's window is, in percent. Also on its title bar." },
    },
})

page:Card({
    id = "trainer", name = "Trainer Popup", order = 30, switch = "trainerPopup", store = ns.QoLSettings,
    help = "After visiting a trainer, a small window lists the abilities you just learned. Abilities from a "
        .. "tome or a quest show a moment after you learn them. Drag one from the window onto your bars.",
    summary = TrainerSummary,
    rows = {
        { key = "trainerGlow", label = "Glow New Abilities", toggle = true,
          help = "Lights up the new abilities on your action bars until you use them." },
        { key = "trainerRanks", label = "Offer to Replace Lower Ranks", toggle = true,
          help = "Adds a button to the popup that swaps every lower rank on your bars for the highest rank "
              .. "you know. Keyboard and controller bars land in the same slot. Right-click a spell in the "
              .. "popup to keep its lower ranks, for downranking. Rank swaps only happen out of combat." },
        { label = "Check My Bars Now", buttonText = "Check Bars", always = true,
          button = function() ns.TrainerRankCheck() end,
          help = "Looks for lower ranks on your bars now, as after a trainer visit (also /naowh ranks). Out of "
              .. "combat only." },
        { label = "Forget Kept Spells", buttonText = "Forget Kept", always = true,
          button = function() ns.TrainerForgetKept() end,
          help = "Forgets the spells you chose to keep at lower ranks, so the popup offers to swap them again." },
    },
})
