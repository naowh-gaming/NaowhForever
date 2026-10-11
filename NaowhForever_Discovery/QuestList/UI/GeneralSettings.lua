-- GeneralSettings.lua: the Quest List's window and key on its settings page (Discovery/Quest List), declared as cards.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Settings = ns.Shared.Settings
local Style = Completo.Style

local PAGE = "Discovery/Quest List"
local WINDOW_SCALE = Style.SCALE_RANGE
local OPACITY_RANGE = Style.OPACITY_RANGE
local PERCENT_SCALE = Style.PERCENT_SCALE
local ORDER_KEYS, ORDER_WINDOW = 30, 90

local page = Settings.Page(PAGE, S)

page:Card({
    id = "keys", name = "Key Binding", order = ORDER_KEYS,
    help = "The key that opens the Quest List window.",
    rows = {
        { label = "Open Quest List", binding = "NAOWHFOREVER_COMPLETO",
          help = "Press it to open or close the Quest List. Shift-L unless something else had it." },
    },
})

page:Card({
    id = "window", name = "Window", order = ORDER_WINDOW,
    help = "The Quest List's own window. Drag its bottom right corner to size it.",
    rows = {
        { key = "windowScale", label = "Window Scale", slider = WINDOW_SCALE, unit = "%", scale = PERCENT_SCALE,
          help = "How big the window and everything in it is. Drag its corner to make it bigger instead." },
        { key = "windowAlpha", label = "Window Opacity", slider = OPACITY_RANGE,
          unit = "%", scale = PERCENT_SCALE, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
