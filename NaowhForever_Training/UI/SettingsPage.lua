-- SettingsPage.lua: the Training Planner settings page (Training Planner/Settings), declared as cards.
local ns = _G.NaowhForever

local Training = ns.Training
local S = Training.Settings
local Settings = ns.Shared.Settings

local ORDER_ON_THE_WAY, ORDER_KEYS, ORDER_WINDOW, ORDER_BUILDS, ORDER_SKILLS = 10, 15, 20, 30, 40
local ORDER_NEXT_TALENT = 35
local BUILDS_TAB = "builds"
local TEXT_OFF = ns.L("Turn on the Training Planner")
local TEXT_BUILDS_SEARCH = ns.L("talents talent points follow import export share auto spend")
local TEXT_NEXT_SEARCH = ns.L("talents talent window next talent glow highlight build ellesmere")
local TEXT_OPEN = "Open Training Planner"
local TEXT_TRAIN_NOW = ns.L("%d %s to train now, %s")
local TEXT_SPELL, TEXT_SPELLS = ns.L("spell"), ns.L("spells")
local TEXT_NEW_AT = ns.L("New spells at level ")
local TEXT_KNOW_ALL = ns.L("You know every spell your class trains")
local TEXT_DETAIL = ns.L("%s left to pay on the road to 60. %d talent %s for your class.")
local TEXT_BUILD, TEXT_BUILDS = ns.L("build"), ns.L("builds")
local TEXT_BOTH, TEXT_TOAST, TEXT_PANEL, TEXT_NOTHING =
    ns.L("Level-up toast and trainer panel"), ns.L("Level-up toast"), ns.L("Trainer panel"), ns.L("Nothing on the way")
local TEXT_FOLLOWING = ns.L("Following: %s")
local TEXT_NOT_FOLLOWING = ns.L("Not following a build")

local function PadFree()
    return Training.On() and not ns.GamepadStandDown()
end

local function PadWhy()
    return ns.GamepadWhy() or TEXT_OFF
end

local function NextTalentWhy()
    if not Training.On() then return TEXT_OFF end
    return ns.GamepadWhy()
end

local function NotWarlock()
    return not Training.Grimoires.Warlock()
end

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

local function OpenBuildsWindow()
    ns.OpenTrainingWindow(nil, BUILDS_TAB)
end

local function OpenBuilds()
    ns.OpenFromOptions(OpenBuildsWindow)
end

local function NotFollowing()
    return Training.Followed() == nil
end

local function StopFollowing()
    local _, classID = Training.Followed()
    Training.Follow(classID, nil)
    ns.UI:RefreshPage(true)
end

local function BuildsSummary()
    local build = Training.Followed()
    return build and TEXT_FOLLOWING:format(build.name) or TEXT_NOT_FOLLOWING
end

local function OnTheWaySummary(store)
    local toast, panel = store.Get("levelUpToast"), store.Get("trainerPanel")
    if toast and panel then return TEXT_BOTH end
    if toast then return TEXT_TOAST end
    if panel then return TEXT_PANEL end
    return TEXT_NOTHING
end

local page = Settings.Page("Training Planner/Settings", S)

page:Window({
    text = TEXT_OPEN,
    open = OpenPlanner,
    headline = CardHeadline,
    detail = CardDetail,
})

page:Card({
    id = "onTheWay", name = "On the Way", order = ORDER_ON_THE_WAY,
    help = "The Training Planner's help while you level: a toast when you level up with spells to train, "
        .. "and a panel beside your class trainer.",
    search = "/nf trainer nf trainer waypoint class trainer",
    summary = OnTheWaySummary,
    rows = {
        { key = "levelUpToast", label = "Level-Up Toast", toggle = true, needs = Training.On,
          why = TEXT_OFF,
          help = "When you level up with new spells to train, a toast says how many and what they cost, with "
              .. "buttons to open the planner and to put a waypoint on your nearest trainer. Move it in the "
              .. "HUD Editor." },
        { key = "trainerPanel", label = "Panel at the Trainer", toggle = true,
          needs = PadFree, why = PadWhy,
          help = "Beside your class trainer, the spells you can learn now, ticked, with their total and Learn "
              .. "Selected. Untick one to leave it.",
          search = "put the new ranks on my bars swap ranks /nf ranks nf ranks" },
        { key = "demonBooks", label = "Demon Books", toggle = true, needs = Training.On, why = TEXT_OFF,
          hidden = NotWarlock,
          help = "Your demons' books in the planner, and marks at the demon trainer for the ones they know.",
          search = "warlock grimoire grimoires pet imp voidwalker succubus incubus felhunter demon trainer" },
    },
})

page:Card({
    id = "keys", name = "Key Binding", order = ORDER_KEYS,
    help = "The key that opens the Training Planner.",
    rows = {
        { label = TEXT_OPEN, binding = "NAOWHFOREVER_TRAINING",
          help = "Press this key to open the Training Planner, and again to close it." },
    },
})

page:Card({
    id = "window", name = "Window", order = ORDER_WINDOW,
    help = "The planner's own window, and a mini bar to leave up while you level.",
    search = "right-click right click skip spell",
    rows = {
        { key = "miniShown", label = "Mini Bar", toggle = true, needs = Training.On,
          why = TEXT_OFF,
          help = "A small bar with your next trainer visit and your gold, to leave up while you level. Move it "
              .. "by dragging." },
        { key = "spellbook", label = "Spellbook Tab", toggle = true, needs = PadFree, why = PadWhy,
          help = "A Trainable tab under your spellbook that lists the spells you can train.",
          search = "spell book trainable" },
    },
})

page:Card({
    id = "skills", name = "Weapon Skills", order = ORDER_SKILLS,
    help = "Your weapon skills in a small panel to leave up while you level.",
    search = "weapon skill weapon master sword mace axe dagger bow gun staff polearm",
    rows = {
        { key = "weaponsShown", label = "Weapon Skills Panel", toggle = true, needs = Training.On, why = TEXT_OFF,
          help = "Shows your weapon skill levels and where to learn the ones you lack." },
        { key = "weaponsAll", label = "Show All Known Skills", toggle = true, needs = Training.On, why = TEXT_OFF,
          help = "Lists every weapon skill you know, not only the weapons you carry." },
        { key = "weaponsUnlearned", label = "Show Unlearned Skills", toggle = true, needs = Training.On,
          why = TEXT_OFF,
          help = "Lists the weapon skills you can still learn, with where and what they cost." },
    },
})

page:Card({
    id = "builds", name = "Talent Builds", order = ORDER_BUILDS,
    help = "Save, make, share and follow talent builds in the planner's Builds tab.",
    search = TEXT_BUILDS_SEARCH,
    summary = BuildsSummary,
    rows = {
        { label = "Builds", buttonText = "Open Builds", button = OpenBuilds,
          help = "Opens the planner on its Builds tab." },
        { label = "Followed Build", buttonText = "Stop", button = StopFollowing, hidden = NotFollowing,
          help = "Stops spending your talent points on the build you follow." },
    },
})

page:Card({
    id = "nextTalent", name = "Next Talent", order = ORDER_NEXT_TALENT, switch = "nextTalent",
    switchWhy = NextTalentWhy,
    help = "Lights the next talent of a build on your talent window, with a panel to pick the build.",
    search = TEXT_NEXT_SEARCH,
    rows = {
        { key = "nextTalentGlow", label = "Glow on the Next Talent", toggle = true,
          help = "A glow around the next talent's button that pulses while you have a point to spend." },
        { key = "nextTalentDrawer", label = "Talent Window Panel", toggle = true,
          help = "A panel beside the talent window to pick a build and see its next talents." },
    },
})
