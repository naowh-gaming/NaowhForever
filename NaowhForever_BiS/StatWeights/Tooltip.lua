-- Tooltip.lua: the upgrade line on gear tooltips, while Stat Weights is on.
local ns = _G.NaowhForever

local SW = ns.StatWeights
local S = SW.Settings
local Items = ns.Shared.Items
local UpgradeLine = ns.Shared.Parts.UpgradeLine

local TEXT_MANA = ns.L("% mana|r")

local installed = false

local function ManaLine(tooltip, id, link, spec)
    if not (spec.healer and S.Get("manaUpgrades")) then return end
    local mana = SW.ManaWeights()
    if not mana then return end
    local gain, partner = SW.BestGain(id, link, mana, SW.Power(mana))
    if gain then tooltip:AddLine(UpgradeLine(gain, spec.name, TEXT_MANA, partner)) end
end

local function TooltipLink(tooltip)
    if not tooltip.GetItem then return nil end
    local link = select(2, tooltip:GetItem())
    if link and issecretvalue(link) then return nil end
    return link
end

local function SpecLine(tooltip, id, link, spec)
    local weights = SW.For(spec.key)
    local best, partner = SW.BestGain(id, link, weights, SW.Power(weights))
    if best then tooltip:AddLine(UpgradeLine(best, spec.name, nil, partner)) end
end

local function OnItem(tooltip, data)
    if not SW.On() or tooltip:IsForbidden() then return end
    local id = data and data.id
    if not id or issecretvalue(id) then return end
    local key = Items.SlotsFor(id) and SW.ActiveSpec()
    local spec = key and SW.Spec(key)
    if not spec then return end
    local link = TooltipLink(tooltip)
    SpecLine(tooltip, id, link, spec)
    ManaLine(tooltip, id, link, spec)
    if not S.Get("allSpecs") then return end
    for _, other in ipairs(SW.ClassSpecs()) do
        if other.key ~= key then SpecLine(tooltip, id, link, other) end
    end
end

local function Install()
    if installed or not SW.On() then return end
    installed = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
end

local function OnSetting(key)
    if key == "enabled" then Install() end
end

S.OnChange(OnSetting)
ns.OnApply(Install)
