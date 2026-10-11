-- Style.lua: what only Naowh's Forge draws: its colors, fonts and sizes, on top of the house look (ns.Macros.Style).
local ns = _G.NaowhForever
local Shared = ns.Shared

ns.Macros.Style = setmetatable({
    PAD = 14,
    INSPECTOR_W = 320,
    ROW_ICON = 30,
    ICON_EDGES = 2,
    BUTTON_H = 26,
    ICON_TEXT_GAP = 10,
    MACRO_CARD_PAD = 12,
    SCROLLBAR_ROOM = 12,

    TAG_SIZE = 10,
    NOTE_SIZE = 12,
    TEXT_SIZE = 13,
    CARD_TITLE_SIZE = 16,
}, { __index = Shared.Style })
