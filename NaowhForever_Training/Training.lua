-- Training.lua: the Training Planner's settings, its module table (ns.Training) and what it keeps account-wide.
local ns = _G.NaowhForever

local UI = ns.UI
local CharacterData = ns.Shared.CharacterData

local F = ns.FEATURES.training

local S = UI.ModuleSettings("training", { enabled = F.enabled, levelUpToast = F.levelUpToast,
    trainerPanel = F.trainerPanel, spellbook = F.spellbook, spellbookOpen = true, showLearned = true,
    miniShown = false })
ns.TrainingSettings = S

local Training = { Settings = S }
ns.Training = Training

local SPELL, COST = 2, 3
local PRICES = "trainingCharPrices"

local charKey
local listeners = {}

local function On()
    return S.Get("enabled")
end

local function Account(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    return account[key]
end

local function CharKey()
    if charKey then return charKey end
    local name = UnitName("player")
    local key = name .. "-" .. GetRealmName()
    if name ~= UNKNOWNOBJECT then charKey = key end
    return key
end

local function Prices()
    return CharacterData(PRICES, true)
end

local function Ignored()
    local all = Account("trainingIgnored")
    local key = CharKey()
    all[key] = all[key] or {}
    return all[key]
end

local function ClassSpells()
    local _, _, classID = UnitClass("player")
    return ns.TrainingData[classID] or {}
end

local function Price(entry)
    local spell = entry[SPELL]
    local mine, old = CharacterData(PRICES), ns.AccountSettings().trainingPrices
    return mine and mine[spell] or old and old[spell] or entry[COST]
end

local function Changed()
    for i = 1, #listeners do listeners[i]() end
    UI:RefreshPage(true)
end

function Training.OnChange(fn)
    listeners[#listeners + 1] = fn
end

Training.On = On
Training.Account = Account
Training.CharKey = CharKey
Training.Prices = Prices
Training.Ignored = Ignored
Training.ClassSpells = ClassSpells
Training.Price = Price
Training.Changed = Changed
