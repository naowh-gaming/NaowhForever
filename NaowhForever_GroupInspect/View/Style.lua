-- Style.lua: Group Inspect's look, its window's sizes and the words its views share (GI.UI).
local ns = _G.NaowhForever

local GI = ns.GroupInspect

local UI = {}
GI.UI = UI
local St = setmetatable({
    WINDOW_W = 1100,
    WINDOW_H = 612,
    TOOLBAR_GAP = 12,
    PARTY_W = 203,
    PARTY_WIDE_W = 256,
    PARTY_GAP = 10,
    PARTY_MAX = 5,
    PARTY_PAD = 10,
    BAND_H = 3,
    CLASS_ICON = 32,
    ROW_CLASS_ICON = 20,
    NAME_SIZE = 15,
    NAME_MIN = 11,
    ROW_NAME_SIZE = 13,
    ROW_NAME_MIN = 10,
    SUB_SIZE = 11,
    KICKER_SIZE = 10,
    LINE_SIZE = 12,
    LINE_H = 16,
    SECTION_GAP = 12,
    KICKER_GAP = 6,
    PILL_SIZE = 9,
    BADGE = 14,
    BADGE_GAP = 4,
    ROLE_ICON = 16,
    ROW_ROLE_ICON = 14,
    SLOT = 27,
    SLOT_GAP = 4,
    WIDE_SLOT = 33,
    WIDE_SLOT_GAP = 5,
    STRIP_WEAPON_GAP = 8,
    STRIP_SLOT = 20,
    STRIP_GAP = 3,
    EMPTY_ALPHA = 0.45,
    AWAY_ALPHA = 0.55,
    ROW_H = 32,
    COLUMNS_H = 20,
    CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
    CLASS_CROP = 0.02,
    ROLE_ATLAS = { TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder", HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
        DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder" },
}, { __index = ns.Shared.Style })
UI.Style = St

local HEADER, PAD, FOOTER, INSET = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.CONTENT_INSET
local SCROLLBAR, TAB_H = St.SCROLLBAR, St.TAB_H
local SCROLL_GAP, TOOLBAR_DROP = 4, 4

UI.PAGE = "Group Inspect/Settings"
UI.WAITING = "..."
UI.CONTENT_W = St.WINDOW_W - 2 * INSET
UI.LIST_W = UI.CONTENT_W - SCROLLBAR - SCROLL_GAP
UI.TOOLBAR_TOP = HEADER + PAD + TOOLBAR_DROP
UI.CONTENT_TOP = UI.TOOLBAR_TOP + TAB_H + St.TOOLBAR_GAP
UI.CONTENT_H = St.WINDOW_H - UI.CONTENT_TOP - FOOTER - PAD

UI.CLASS_NAMES = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue",
    PRIEST = "Priest", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
UI.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
UI.ARMOR = { MAGE = "Cloth", PRIEST = "Cloth", WARLOCK = "Cloth", ROGUE = "Leather", DRUID = "Leather",
    HUNTER = "Mail", SHAMAN = "Mail", WARRIOR = "Plate", PALADIN = "Plate" }
UI.ROLE_WORDS = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }
UI.STATS = {
    { key = "STR", name = "Strength", short = "STR" }, { key = "AGI", name = "Agility", short = "AGI" },
    { key = "STA", name = "Stamina", short = "STA" }, { key = "INT", name = "Intellect", short = "INT" },
    { key = "SPI", name = "Spirit", short = "SPI" }, { key = "AP", name = "Attack Power", card = "Atk Power", short = "AP" },
    { key = "SP", name = "Spell Power", short = "SP" }, { key = "CRIT", name = "Crit", short = "Crit", percent = true },
    { key = "HIT", name = "Hit", short = "Hit", percent = true }, { key = "ARMOR", name = "Armor", short = "Armor" },
}
