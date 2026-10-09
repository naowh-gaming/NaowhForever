-- GeneralSettings.lua: Completo's General settings page (Completo/General), what is Completo's as a whole, declared as cards.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local R = Completo.Rares
local Settings = ns.Shared.Settings
local Style = Completo.Style

local PAGE = "Completo/General"
local WINDOW_SCALE = { 50, 150, 5 }
local PERCENT_STEP = 5
local PERCENT_SCALE = 0.01
local TEXT_PROGRESS = "%d of %d quests done, %d of %d rares killed"
local TEXT_ABOUT = "Everything there is to do, and how much of it you have done."

local page = Settings.Page(PAGE, S)

local function Headline()
    Q.Refresh()
    local n, total = Q.Progress()
    local killed, rares = R.Progress()
    return TEXT_PROGRESS:format(n, total, killed, rares)
end

local function Detail()
    return TEXT_ABOUT
end

local function OpenOverview()
    ns.OpenCompletoWindow("overview")
end

page:Window({
    text = "Open Completo",
    open = OpenOverview,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "keys", name = "Key Binding", order = 30,
    help = "The key that opens the Completo window.",
    rows = {
        { label = "Open Completo", binding = "NAOWHFOREVER_COMPLETO",
          help = "Press it to open or close Completo. Shift-L unless something else had it." },
    },
})

page:Card({
    id = "window", name = "Window", order = 90,
    help = "Completo's own window. Drag its bottom right corner to size it.",
    rows = {
        { key = "windowScale", label = "Window Scale", slider = WINDOW_SCALE, unit = "%", scale = PERCENT_SCALE,
          help = "How big the window and everything in it is. Drag its corner to make it bigger instead." },
        { key = "windowAlpha", label = "Window Opacity", slider = { Style.OPACITY_MIN, 100, PERCENT_STEP },
          unit = "%", scale = PERCENT_SCALE, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
