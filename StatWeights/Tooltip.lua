-------------------------------------------------------------------------------
--  StatWeights/Tooltip.lua -- while the module is on, a line on the tooltip of gear that is an
--  upgrade for your spec: "(green arrow) +9% upgrade . Fire" (Shared/Parts.lua's UpgradeLine).
--  Nothing on gear that is not one, or that you wear. A ring or trinket is weighed against the
--  weaker of the two you wear, a two-hander against both hands. Installed the first time the
--  module is turned on.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local SW = ns.StatWeights
local S = SW.Settings
local Items = ns.Shared.Items
local UpgradeLine = ns.Shared.Parts.UpgradeLine

local MIN_GAIN = 0.5   -- percent: less than this is not an upgrade

local function OnItem(tooltip, data)
    if not SW.On() or tooltip:IsForbidden() then return end
    local id = data and data.id
    if not id or issecretvalue(id) then return end
    local slots = Items.SlotsFor(id)
    local key = slots and SW.ActiveSpec()
    local weights = key and SW.For(key)
    if not weights then return end
    for _, slot in ipairs(slots) do
        if Items.Wearing(slot, id) then return end
    end
    local _, link = tooltip:GetItem()
    if not link or issecretvalue(link) then link = id end
    local power = SW.Power(weights)
    local twoHand = Items.IsTwoHand(id)
    local best
    for _, slot in ipairs(slots) do
        local gain = SW.Gain(link, slot, weights, power, twoHand and slot == 16 and 17 or nil)
        if gain and (not best or gain > best) then best = gain end
    end
    if not best or best < MIN_GAIN then return end
    tooltip:AddLine(UpgradeLine(best, SW.Spec(key).name))
end

local installed = false

local function Install()
    if installed or not SW.On() then return end
    installed = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
end

S.OnChange(function(key)
    if key == "enabled" then Install() end
end)
hooksecurefunc(ns, "Apply", Install)
