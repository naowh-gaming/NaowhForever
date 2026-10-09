-- WindowPages.lua: the AuraBuffs window's two pages: the consumables to watch, and the debuff sounds.
local ns = _G.NaowhForever

local UI = ns.UI
local A = ns.AuraBuffs
local S = A.Settings
local CATEGORY_NAMES, CATEGORY_ORDER = A.CATEGORY_NAMES, A.CATEGORY_ORDER

local PROMPT_WIDTH = 240

local TEXT_PROMPT = "Item ID, then buff spell ID(s), separated by commas"
local TEXT_INVALID = "Enter an item ID followed by at least one buff spell ID."
local TEXT_CONSUMABLES = "Add an item ID and its buff spell ID(s), or import a profile with reminders. "
    .. "Nothing is added automatically. Hover a reminder to choose a configured item from your bags. "
    .. "Reminders pause in combat; item menus work outside combat. When and where they show is on "
    .. "AuraBuffs > Settings."
local TEXT_IDS = "Item ID + buff spell IDs"
local TEXT_DEBUFFS = "A sound when a poison, disease or curse lands on you, even in "
    .. "combat. Add each debuff by its aura spell ID. Sound only, no on-screen glow. "
    .. "Dwarves can pick the Stoneform voice, which only speaks while Stoneform is "
    .. "ready."
local TEXT_NO_SOUNDS = "Turn on Smart Reminders under Settings > Modules to add debuff sounds."

local function Entries()
    return S.Get("consumableEntries") or {}
end

local function SaveEntry(category, index, text)
    local entry = ns.ParseConsumableEntry(category, text)
    if not entry then ns.Print(TEXT_INVALID) return end
    local copy = {}
    for i, value in ipairs(Entries()) do copy[i] = value end
    copy[index or #copy + 1] = entry
    S.Set("consumableEntries", copy)
    UI:RefreshPage(true)
end

local function EditEntry(category, index)
    local existing = index and Entries()[index]
    local initial = existing and (existing.itemID .. ", " .. table.concat(existing.auras, ", ")) or ""
    ns.PromptText(TEXT_PROMPT, initial, PROMPT_WIDTH, function(text) SaveEntry(category, index, text) end)
end

local function RemoveEntry(index)
    local copy = {}
    for i, value in ipairs(Entries()) do
        if i ~= index then copy[#copy + 1] = value end
    end
    S.Set("consumableEntries", copy)
    UI:RefreshPage(true)
end

local function EntryRow(parent, y, category, index, entry)
    local W = UI.Widgets
    local name = C_Item.GetItemNameByID(entry.itemID) or ("Item " .. entry.itemID)
    local _, h = W:DualRow(parent, y,
        { type = "button", text = name, buttonText = "Edit",
            onClick = function() EditEntry(category, index) end },
        { type = "button", text = "Buffs: " .. table.concat(entry.auras, ", "), buttonText = "Remove",
            onClick = function() RemoveEntry(index) end })
    return y - h
end

local function Category(parent, y, category)
    local W = UI.Widgets
    local _, h = W:SectionHeader(parent, CATEGORY_NAMES[category]:upper(), y)
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Add " .. CATEGORY_NAMES[category], buttonText = "Add",
            onClick = function() EditEntry(category) end },
        { type = "label", text = TEXT_IDS })
    y = y - h
    for index, entry in ipairs(Entries()) do
        if entry.category == category then y = EntryRow(parent, y, category, index, entry) end
    end
    return y
end

function ns.BuildAuraBuffConsumables(parent, y)
    local _, h = UI.Widgets:Note(parent, TEXT_CONSUMABLES, y)
    y = y - h
    for _, category in ipairs(CATEGORY_ORDER) do y = Category(parent, y, category) end
    return y
end

function ns.BuildPoisonDispelPage(parent, y)
    local W = UI.Widgets
    local _, h = W:Note(parent, TEXT_DEBUFFS, y)
    y = y - h
    if not ns.BuildDebuffsPage then
        _, h = W:Note(parent, TEXT_NO_SOUNDS, y)
        return y - h
    end
    return ns.BuildDebuffsPage(parent, y)
end
