-- AuraBuffs.lua: the AuraBuffs module's settings (ns.AuraBuffSettings), its table (ns.AuraBuffs) and API.
local ns = _G.NaowhForever

local F = ns.FEATURES.auraBuffs

local S = ns.UI.ModuleSettings("auraBuffs", {
    enabled = F.enabled, consumableEntries = {},
    campBuffTextSize = 16, campBuffSide = "right", campShowMissing = true,
    food = true, elixirs = true, flasks = true,
    consumablesWhere = "instance", consumablesMinutes = 2,
    onlyIfCarried = true, hideResting = true,
    scrolls = true, scrollsSkipActive = false,
    raidBuffs = F.raidBuffs, raidBuffsOwn = true,
    raidBuffPicks = { intellect = true, stamina = true, spirit = true, wild = true, blessing = false },
    iconSize = 36, buffsFont = "", buffsFontSize = 14, buffsOutline = "OUTLINE",
    buffsPos = { point = "TOP", relPoint = "TOP", x = 0, y = -232 },

    campfire = F.campfire, campTimer = true, campBuffs = true,
    campSound = true, campSoundKey = "none", campIconSize = 110, campNearbyAlert = F.campNearbyAlert,
    campShowUnder = true, campShowUnderMinutes = 2, campNearbyMinutes = 2, campStyle = "round",
    campAlertScale = 1.4, campAlertFade = true,
    campAlertFont = "", campAlertOutline = "", campAlertBackground = "none",
    campSimpleWidth = 360, campSimpleHeight = 26, campSimpleTextSize = 12, campBonusIcons = false,
    campHiddenBonuses = {}, campFont = "", campOutline = "", campBarOutline = "NONE",
    campPos = { point = "CENTER", relPoint = "BOTTOMRIGHT", x = -223, y = 61 },

    lowHealth = F.lowHealth, lowHealthBelow = 35, lowHealthItem = "auto",
    lowHealthIconSize = 48, lowHealthGlow = true,
    lowHealthFont = "", lowHealthFontSize = 16, lowHealthOutline = "OUTLINE",
    lowHealthSound = true, lowHealthSoundKey = "none",
    lowHealthPos = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 249 },
    campBuffMode = false, windowAlpha = 1,
})

local ENTRIES = "consumableEntries"
local MIN_ID, MAX_ID = 1, 2147483647
local MIN_IDS = 2
local CATEGORY_NAMES = { food = "Food", flask = "Flask", scroll = "Scroll",
    battle = "Battle Elixir", guardian = "Guardian Elixir" }
local CATEGORY_ORDER = { "food", "flask", "scroll", "battle", "guardian" }

local GetSetting, SetSetting = S.Get, S.Set

function S.Get(key)
    if key == ENTRIES and ns.DB then
        local data = ns.DB().utilityReminders
        return data and data.consumables or {}
    end
    return GetSetting(key)
end

function S.Set(key, value)
    if key ~= ENTRIES or not ns.DB then
        SetSetting(key, value)
        return
    end
    local db = ns.DB()
    db.utilityReminders = db.utilityReminders or {}
    db.utilityReminders.consumables = value
end

ns.AuraBuffSettings = S

local A = {
    Settings = S,
    PAGE = "AuraBuffs/Settings",
    CATEGORY_NAMES = CATEGORY_NAMES,
    CATEGORY_ORDER = CATEGORY_ORDER,
}
ns.AuraBuffs = A

function A.Enabled()
    return S.Get("enabled") and true or false
end

function A.Needs(key)
    return function() return S.Get("enabled") and S.Get(key) and true or false end
end

function ns.ParseConsumableEntry(category, text)
    if not CATEGORY_NAMES[category] or type(text) ~= "string" then return end
    local ids = {}
    for token in text:gmatch("[^,%s]+") do
        if not token:match("^%d+$") then return end
        local id = tonumber(token)
        if id < MIN_ID or id > MAX_ID then return end
        ids[#ids + 1] = id
    end
    if #ids < MIN_IDS then return end
    local entry = { category = category, itemID = table.remove(ids, 1), auras = ids }
    return entry
end

function ns.CampBuffMode()
    local mode = S.Get("campBuffMode")
    if mode then return mode end
    return S.Get("campBuffs") and "always" or "off"
end
