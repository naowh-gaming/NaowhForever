-- Style.lua: the Group Finder's look, its window's sizes and the words its views share (ns.GroupFinder.UI).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end

local UI = {}
GF.UI = UI
local St = setmetatable({
    WINDOW_W = 560,
    WINDOW_H = 600,
    ROW_H = 64,
    ROW_PAD = 12,
    BAND_W = 3,
    LINE_1 = 10,
    LINE_2 = 28,
    LINE_3 = 45,
    TITLE_SIZE = 13,
    LINE_SIZE = 12,
    SUB_SIZE = 11,
    SCORE_SIZE = 16,
    CLASS_ICON = 14,
    ROLE_ICON = 15,
    ROLE_GAP = 3,
    SLOTS_SHOWN = 5,
    TEXT_GAP = 6,
    DETAIL_GAP = 14,
    DELISTED_ALPHA = 0.45,
    SCROLL_GAP = 4,
    ROLE_ATLAS = { TANK = "groupfinder-icon-role-large-tank", HEALER = "groupfinder-icon-role-large-heal",
        DAMAGER = "groupfinder-icon-role-large-dps" },
    EMPTY_SLOT = "groupfinder-icon-emptyslot",
}, { __index = ns.Shared.Style })
UI.Style = St

local HEADER, PAD, FOOTER, INSET = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.CONTENT_INSET

UI.WAITING = "..."
UI.CONTENT_TOP = HEADER + PAD
UI.LIST_W = St.WINDOW_W - 2 * INSET - St.SCROLLBAR - St.SCROLL_GAP
UI.FOOTER_ROOM = FOOTER + PAD
