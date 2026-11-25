-- SettingsPage.lua: the Stat Weights card on the BiS List's settings page.
local ns = _G.NaowhForever

local SW = ns.StatWeights
local S = SW.Settings

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local AUTO = "auto"
local ORDER_STAT_WEIGHTS = 40
local TEXT_AUTOMATIC = ns.L("Automatic")
local TEXT_AUTOMATIC_FOR = ns.L("Automatic (%s)")
local TEXT_ON_TOOLTIPS = ns.L(", upgrades on tooltips")
local FIGHT_LENGTHS = {
    { 60, ns.L("1 minute") }, { 120, ns.L("2 minutes") }, { 180, ns.L("3 minutes") }, { 300, ns.L("5 minutes") },
}

local function SpecChoices()
    local talents = SW.TalentSpec()
    local values, order = { [AUTO] = talents and TEXT_AUTOMATIC_FOR:format(SW.Spec(talents).name)
        or TEXT_AUTOMATIC }, { AUTO }
    for _, spec in ipairs(SW.ClassSpecs()) do
        values[spec.key] = spec.name
        order[#order + 1] = spec.key
    end
    return values, order
end

local function SpecGet() return SW.PickedSpec() or AUTO end
local function SpecSet(key) SW.PickSpec(key ~= AUTO and key or nil) end

local function LengthChoices()
    local values, order = {}, {}
    for _, length in ipairs(FIGHT_LENGTHS) do
        local key = tostring(length[1])
        values[key] = length[2]
        order[#order + 1] = key
    end
    return values, order
end

local function LengthGet() return tostring(S.Get("fightLength")) end
local function LengthSet(key) S.Set("fightLength", tonumber(key)) end

local function Summary(store)
    local spec = SW.Spec(SW.ActiveSpec())
    local name = spec and spec.name or ""
    return store.Get("enabled") and (name .. TEXT_ON_TOOLTIPS) or name
end

Settings.Page("BiS List/Settings"):Card({
    id = "statWeights", name = "Stat Weights", order = ORDER_STAT_WEIGHTS, store = S, watch = { SW },
    help = "What each stat is worth to your spec: the BiS List's upgrade percents and enchants come from "
        .. "them. Change the weights in the Stat Weights window, from the scales on the BiS List's title bar.",
    summary = Summary,
    rows = {
        { key = "enabled", label = "Upgrades on Tooltips", toggle = true,
          help = "On gear that is an upgrade for your spec, a line saying by how much (\"+9% upgrade\"). The "
              .. "BiS List uses these weights either way." },
        { key = "allSpecs", label = "All Specs on Tooltips", toggle = true,
          help = "The upgrade line for each of your class's specs, not only yours: yours first, then the others "
              .. "it is an upgrade for." },
        { key = "upgradeMarks", label = "Upgrade Marks", toggle = true,
          help = "An upgrade arrow and percent on quest rewards, merchants, loot and the auction house." },
        { key = "healerMana", label = "Healer Mana", toggle = true,
          help = "For a healer, works out Intellect and Spirit from your own mana regen and pool." },
        { key = "manaUpgrades", label = "Mana Upgrades", toggle = true,
          help = "For a healer, a second tooltip line when gear gives you more mana over a fight." },
        { label = "Fight Length", choice = LengthChoices, get = LengthGet, set = LengthSet,
          help = "How long a healer's mana must last: longer fights favour regen over Intellect." },
        { label = "Your Spec", choice = SpecChoices, get = SpecGet, set = SpecSet,
          help = "The spec your gear is weighed for. Automatic follows your talents: the tree with the most "
              .. "points (a druid's Feral is weighed for damage; pick Feral Tank for a bear)." },
        { label = "Your Weights", button = function() ns.OpenFromOptions(ns.OpenStatWeightsWindow) end,
          buttonText = "Edit Weights",
          help = "Opens the Stat Weights window: each stat's worth to your spec, and your best upgrades by them." },
    },
})
