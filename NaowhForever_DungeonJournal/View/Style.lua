-- Style.lua: what only the Dungeon Journal draws: its colors, icons and sizes (J.Style).
local ns = _G.NaowhForever

local J = ns.Journal
local Shared = ns.Shared

local MEDIA = ns.MEDIA
local BYTE = J.C.BYTE
local TINTED_MARK = "|T%s:0:0:0:0:64:64:0:64:0:64:%d:%d:%d|t"

local function Tinted(texture, color)
    return TINTED_MARK:format(texture, color.r * BYTE, color.g * BYTE, color.b * BYTE)
end

local St = setmetatable({
    TERRITORY_CODE = { Alliance = "|cff4a9eff", Horde = "|cffff4d4d", Contested = "|cffe6cc80" },
    COIN_ICON = { g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:-1|t",
                  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:-1|t" },
    QUEST_CODE = {
        prereq = "|cffff9933", prereqLog = "|cffffd100", low = "|cffff4d4d", pickup = "|cffd8dbe0",
        tooHigh = "|cffff4d4d", next = "|cffff9933", active = "|cffffd100", ready = "|cff19ff19",
        done = "|cff9ca3af", lost = "|cff9ca3af",
    },

    OVERLAY_RGB = { r = 0, g = 0, b = 0 },
    ENTRANCE_KIND_RGB = { r = 0.61, g = 0.64, b = 0.69 },
    GOLD_NAME_RGB = { r = 1, g = 0.82, b = 0 },
    FAVOURITE_RGB = { r = 1, g = 0.82, b = 0 },
    ENTRANCE_HINT_RGB = { r = 0.3, g = 0.71, b = 0.96 },
    RARE_RGB = { r = 0xc8 / 255, g = 0xd0 / 255, b = 0xdc / 255 },
    SKULL_LEVEL_RGB = { r = 1, g = 0.1, b = 0.1 },

    CONTESTED = MEDIA .. "swords",
    FACTION_ATLAS = { Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon",
                      Horde = "UI-HUD-UnitFrame-Player-PVP-HordeIcon" },
    SKULL = MEDIA .. "skull",
    CLOCK = MEDIA .. "clock",
    PEOPLE = MEDIA .. "people",
    FAVOURITE = MEDIA .. "star_outline",
    BANG = "Interface/GossipFrame/AvailableQuestIcon",
    QUESTION = "Interface/GossipFrame/ActiveQuestIcon",
    QUESTION_ICON = 134400,
    KILL_DATE = "%a %d %b %Y, %H:%M",

    SMALL_SIZE = 12,
    TINY_SIZE = 10,
    HEADING_SIZE = 13,
    CURSOR_TIP_X = 16,

    COMPACT_W = 560,

    TITLE_SIZE = 20,
    TITLE_H = 20,
    TITLE_GAP = 5,
    WHERE_H = 14,
    HEADER_PAD = 14,
    STAT_ICON = 14,
    STAT_GAP = 16,
    STAT_SPACE = 3,
    STAT_LINE_H = 22,

    QUEST_LEVEL_W = 24,
    QUEST_RIGHT = 12,
    QUEST_TOP = 6,
    QUEST_LINE_GAP = 3,
    QUEST_BOTTOM = 8,
    MARK = 16,
    CHAIN_SLOT = 40,
    PARTY_SLOT = 32,

    BADGE = 20,
    BADGE_ALPHA = 0.8,
    TIP_ICON = 14,
    FADED = 0.25,
    ITEM_HOVER = 0.05,
    FOREVER_H = 10,
    UNUSABLE = 0.55,

    CHANCE_W = 40,
    CHANCE_BAR_W = 36,
    CHANCE_HIGH = 25,
    CHANCE_FAIR = 10,

    TRACK_LABEL_H = 18,
    TRACK_BAR_TOP = 4,
    TRACK_PAD = 14,
    SEG_H = 6,
    SEG_LABEL_TOP = 5,
    SEG_LABEL_H = 14,
    UNREACHED = 0.55,
    RULE_ALPHA = 0.7,

    BOSS_PAGE_GAP = 6,
    DENSE_H = 30,
    DENSE_TALL_H = 44,
    DENSE_ICON = 26,
    DENSE_CHANCE_TOP = 5,
    DENSE_BAR_BOTTOM = 6,

    CHIP_H = 20,
    CHIP_PAD = 8,
    CHIP_GAP = 6,
    BACK_TEXT_PAD = 4,
    CHEST_ICON = "Interface\\Icons\\INV_Box_02",

    MAP_PIN = 46,
    MAP_FLOOR_H = 22,

    WINDOW_W = 1160,
    WINDOW_H = 800,
    LIST_W = 340,
    LIST_ROW = 24,
    TERRITORY_ICON = 14,
    TERRITORY_GAP = 6,
    FACTION_W = 26,
    FACTION_ICON = 18,
    FACTION_OFF = 0.35,
    FACTION_GAP = 6,
    LIST_NAME_SIZE = 13,
    LIST_COUNT_SIZE = 12,
    LIST_BAR = 4,
    LIST_BAR_GAP = 2,
    GROUP_H = 22,
    LIST_STANDING_W = 30,

    ROLE_ATLAS = { T = "UI-LFG-RoleIcon-Tank-Micro", H = "UI-LFG-RoleIcon-Healer-Micro",
        D = "UI-LFG-RoleIcon-DPS-Micro" },
    ROLE_NAME = { T = ns.L("Tank"), H = ns.L("Healer"), D = ns.L("Damage") },
}, { __index = Shared.Style })

St.DONE_MARK = Tinted(St.CHECK, St.HAVE_RGB)
St.STAR_TAG = Tinted(St.STAR, St.BIS_RGB) .. " "
J.Style = St
