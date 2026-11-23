-- Worth.lua: what an item is worth to your weights, and how much stronger it makes you (SW.Gain, SW.BestGain).
local ns = _G.NaowhForever

local GetItemStats = C_Item.GetItemStats
local IsItemDataCachedByID = C_Item.IsItemDataCachedByID
local GetItemInfo, GetItemInfoInstant = C_Item.GetItemInfo, C_Item.GetItemInfoInstant

local SW = ns.StatWeights
local Items = ns.Shared.Items
local GAME_KEYS, PER_PERCENT = SW.GAME_KEYS, SW.PER_PERCENT

local MAIN_HAND, OFF_HAND = 16, 17
local CACHE_MAX = 600
local SPEED = 2.6
local MIN_GAIN = 0.5
local PERCENT = SW.PERCENT
local ANY_SUBCLASS = 0
local CLOAK = "INVTYPE_CLOAK"
local HUNTER = "HUNTER"
local ITEM_EVENT = "GET_ITEM_INFO_RECEIVED"
local BAG_EVENTS = { "BAG_UPDATE", "BAG_UPDATE_DELAYED" }
local PARTNERS_ONLY = { BAG_UPDATE = true, BAG_UPDATE_DELAYED = true, GET_ITEM_INFO_RECEIVED = true }
local DPS = "dps"
local FACT_CLASS, FACT_SUBCLASS, FACT_REQUIRED = 1, 2, 4
local DPS_SHARE = { [16] = 1, [17] = 0.5 }
local OTHER_HAND = { [16] = 17, [17] = 16 }
local DUAL_WIELD = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }
local HUNTER_DPS_SHARE = { [18] = 1 }
local PRIMARY = { "str", "agi", "sta", "int", "spi" }
local PRIMARY_KEY = { str = true, agi = true, sta = true, int = true, spi = true }
local GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local HIT, SPELL_HIT = "hit", "shit"
local HIT_KINDS = { HIT, SPELL_HIT }
local HIT_CAP = { [HIT] = 8, [SPELL_HIT] = 17 }
local DUAL_WIELD_HIT_CAP = 27
local HIT_RATING, SPELL_HIT_RATING = "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT"

local statsOf, cached = {}, 0
local hitGear, hitNow = { [HIT] = 0, [SPELL_HIT] = 0 }, { [HIT] = 0, [SPELL_HIT] = 0 }
local lastMain, lastOff
local lastPower = setmetatable({}, { __mode = "k" })
local partners = setmetatable({}, { __mode = "k" })
local forgetter, bagsWatched
local facts = {}
local myClass

local function Forget(self, event)
    wipe(partners)
    if event == ITEM_EVENT then self:UnregisterEvent(event) end
    if PARTNERS_ONLY[event] then return end
    wipe(lastPower)
    lastMain, lastOff = nil, nil
end

local function Remembering()
    if forgetter then return end
    forgetter = CreateFrame("Frame")
    forgetter:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    forgetter:RegisterEvent("PLAYER_LEVEL_UP")
    forgetter:SetScript("OnEvent", Forget)
end

local function Stats(item)
    local stats = statsOf[item]
    if stats then return stats end
    local id = type(item) == "number" and item or GetItemInfoInstant(item)
    if id and not IsItemDataCachedByID(id) then return nil end
    stats = GetItemStats(type(item) == "number" and "item:" .. item or item) or {}
    if cached >= CACHE_MAX then
        wipe(statsOf)
        cached = 0
    end
    statsOf[item], cached = stats, cached + 1
    return stats
end

local function Worth(stats, weights, dpsShare, skipPrimary)
    local worth = 0
    for key, value in pairs(stats) do
        local mine = GAME_KEYS[key]
        local per = PER_PERCENT[key]
        if per then value = value / per end
        if type(mine) == "table" then
            for i = 1, #mine do worth = worth + (weights[mine[i]] or 0) * value end
        elseif mine == DPS then
            worth = worth + (weights.dps or 0) * value * (dpsShare or 0)
        elseif mine and not (skipPrimary and PRIMARY_KEY[mine]) then
            worth = worth + (weights[mine] or 0) * value
        end
    end
    return worth
end

local function DpsShare(slot)
    local shares = select(2, UnitClass("player")) == HUNTER and HUNTER_DPS_SHARE or DPS_SHARE
    return shares[slot] or 0
end

local function WornWorth(slot, weights)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0 end
    local worn = Stats(link)
    return worn and Worth(worn, weights, DpsShare(slot))
end

local function Usable(id, link)
    local canUse = ns.ClassCanUse
    if not canUse then return true end
    local _, _, _, equipLoc, _, itemClass, subclass = GetItemInfoInstant(id)
    local _, _, _, _, required = GetItemInfo(link or id)
    if not (itemClass and required) then return nil end
    myClass = myClass or select(2, UnitClass("player"))
    if equipLoc == CLOAK then subclass = ANY_SUBCLASS end
    facts[FACT_CLASS], facts[FACT_SUBCLASS], facts[FACT_REQUIRED] = itemClass, subclass, required
    return canUse(myClass, facts)
end

local function Wearing(id, slots)
    for i = 1, #slots do
        if Items.Wearing(slots[i], id) then return true end
    end
    return false
end

local function NeedsDualWield(id, slot)
    local _, _, _, equipLoc = GetItemInfoInstant(id)
    return slot == OFF_HAND and DUAL_WIELD[equipLoc] == true
end

local function HitOf(stats, kind)
    local hit = (stats[HIT_RATING] or 0) / PER_PERCENT[HIT_RATING]
    if kind == SPELL_HIT then hit = hit + (stats[SPELL_HIT_RATING] or 0) / PER_PERCENT[SPELL_HIT_RATING] end
    return hit
end

local function WornHit(slot, kind)
    local link = slot and GetInventoryItemLink("player", slot)
    local worn = link and Stats(link)
    return worn and HitOf(worn, kind) or 0
end

local function HitCap(kind, off)
    myClass = myClass or select(2, UnitClass("player"))
    if kind == HIT and myClass ~= HUNTER and off and NeedsDualWield(off, OFF_HAND) then return DUAL_WIELD_HIT_CAP end
    return HIT_CAP[kind]
end

local function CountedHit(from, delta, cap, capAfter)
    return math.min(from + delta, capAfter or cap) - math.min(from, cap)
end

local function ReadHit()
    if C_Secrets.ShouldUnitStatsBeSecret() then return end
    hitGear[HIT], hitGear[SPELL_HIT] = 0, 0
    for _, slot in ipairs(GEAR_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        local stats = link and Stats(link)
        if stats then
            for _, kind in ipairs(HIT_KINDS) do hitGear[kind] = hitGear[kind] + HitOf(stats, kind) end
        end
    end
    myClass = myClass or select(2, UnitClass("player"))
    if myClass == HUNTER then
        hitNow[HIT] = GetCombatRatingBonus(CR_HIT_RANGED) + GetRangedHitModifier()
    else
        hitNow[HIT] = GetCombatRatingBonus(CR_HIT_MELEE) + GetHitModifier()
    end
    hitNow[SPELL_HIT] = GetCombatRatingBonus(CR_HIT_SPELL) + GetSpellHitModifier()
end

local function HitBeyondCap(weights, stats, item, slot, also)
    local off = GetInventoryItemID("player", OFF_HAND)
    local offAfter = off
    if slot == OFF_HAND then
        offAfter = item
    elseif also == OFF_HAND then
        offAfter = nil
    end
    local fix = 0
    for _, kind in ipairs(HIT_KINDS) do
        local weight = weights[kind] or 0
        if weight ~= 0 then
            local delta = HitOf(stats, kind) - WornHit(slot, kind) - WornHit(also, kind)
            local counted = CountedHit(hitNow[kind], delta, HitCap(kind, off), HitCap(kind, offAfter))
            fix = fix + weight * (counted - delta)
        end
    end
    return fix
end

local function Offer(hand, id, link, worth)
    if not hand.worth or worth > hand.worth then
        if hand.id ~= id then hand.nextLink, hand.nextWorth = hand.link, hand.worth end
        hand.id, hand.link, hand.worth = id, link, worth
    elseif id ~= hand.id and (not hand.nextWorth or worth > hand.nextWorth) then
        hand.nextLink, hand.nextWorth = link, worth
    end
end

local function OfferBagItem(found, bag, bagSlot, weights, dualWield)
    local id = C_Container.GetContainerItemID(bag, bagSlot)
    local slots = id and Items.SlotsFor(id)
    if not (slots and OTHER_HAND[slots[1]]) or Items.IsTwoHand(id) then return end
    local link = C_Container.GetContainerItemLink(bag, bagSlot)
    local usable = Usable(id, link)
    if usable == false then return end
    local stats = usable and Stats(link)
    if not stats then
        found.partial = true
        return
    end
    for i = 1, #slots do
        local slot = slots[i]
        if dualWield or not NeedsDualWield(id, slot) then
            Offer(found[slot], id, link, Worth(stats, weights, DpsShare(slot)))
        end
    end
end

local function Partners(weights)
    local found = partners[weights]
    local dualWield = CanDualWield()
    if found and found.dualWield == dualWield then return found end
    found = { [MAIN_HAND] = {}, [OFF_HAND] = {}, dualWield = dualWield }
    for bag = 0, NUM_BAG_SLOTS do
        for bagSlot = 1, C_Container.GetContainerNumSlots(bag) do
            OfferBagItem(found, bag, bagSlot, weights, dualWield)
        end
    end
    partners[weights] = found
    Remembering()
    if not bagsWatched then
        bagsWatched = true
        for _, event in ipairs(BAG_EVENTS) do forgetter:RegisterEvent(event) end
    end
    if found.partial then forgetter:RegisterEvent(ITEM_EVENT) end
    return found
end

local function WithPartner(gain, id, slot, weights, power)
    if NeedsDualWield(id, slot) and not CanDualWield() then return gain end
    local hand = Partners(weights)[OTHER_HAND[slot]]
    local link, worth = hand.link, hand.worth
    if hand.id == id then link, worth = hand.nextLink, hand.nextWorth end
    if not (worth and worth > 0) then return gain end
    return gain + PERCENT * worth / power, link
end

SW.MIN_GAIN = MIN_GAIN
SW.Stats = Stats
SW.Worth = Worth
SW.DpsShare = DpsShare
SW.Usable = Usable

function SW.SwingDamage(weights, slot)
    local main, off = lastMain, lastOff
    if not C_Secrets.ShouldUnitStatsBeSecret() then
        main, off = UnitAttackSpeed("player")
        lastMain, lastOff = main, off
        Remembering()
    end
    local speed = (slot == OFF_HAND and off or main) or SPEED
    return (weights.dps or 0) * DpsShare(slot) / (speed > 0 and speed or SPEED)
end

function SW.Power(weights)
    if C_Secrets.ShouldUnitStatsBeSecret() then return lastPower[weights] end
    local power = 0
    for i, key in ipairs(PRIMARY) do power = power + (weights[key] or 0) * select(2, UnitStat("player", i)) end
    for _, slot in ipairs(GEAR_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        local stats = link and Stats(link)
        if stats then power = power + Worth(stats, weights, DpsShare(slot), true) end
    end
    ReadHit()
    local off = GetInventoryItemID("player", OFF_HAND)
    for _, kind in ipairs(HIT_KINDS) do
        local gear = hitGear[kind]
        power = power + (weights[kind] or 0) * (CountedHit(hitNow[kind] - gear, gear, HitCap(kind, off)) - gear)
    end
    lastPower[weights] = power
    Remembering()
    return power
end

function SW.Gain(item, slot, weights, power, also)
    if not (weights and power and power > 0) then return nil end
    local stats = Stats(item)
    local worn = WornWorth(slot, weights)
    local other = 0
    if also then other = WornWorth(also, weights) end
    if not (stats and worn and other) then return nil end
    local worth = Worth(stats, weights, DpsShare(slot)) + HitBeyondCap(weights, stats, item, slot, also)
    return PERCENT * (worth - worn - other) / power
end

function SW.CountedHitRating(gameKey, rating, weights)
    if gameKey ~= HIT_RATING and gameKey ~= SPELL_HIT_RATING then return rating end
    local kind = SPELL_HIT
    if gameKey == HIT_RATING and (weights[HIT] or 0) >= (weights[SPELL_HIT] or 0) then kind = HIT end
    ReadHit()
    local per = PER_PERCENT[gameKey]
    return per * CountedHit(hitNow[kind], rating / per, HitCap(kind, GetInventoryItemID("player", OFF_HAND)))
end

function SW.BestGain(id, link, weights, power)
    local slots = Items.SlotsFor(id)
    if not (slots and weights) then return nil end
    if Wearing(id, slots) or not Usable(id, link) then return nil end
    local twoHand = Items.IsTwoHand(id)
    local main = GetInventoryItemID("player", MAIN_HAND)
    local wornTwoHand = main ~= nil and Items.IsTwoHand(main)
    local best, partner
    for i = 1, #slots do
        local slot = slots[i]
        local also
        if slot == MAIN_HAND and twoHand then
            also = OFF_HAND
        elseif slot == OFF_HAND and wornTwoHand then
            also = MAIN_HAND
        end
        local gain = SW.Gain(link or id, slot, weights, power, also)
        local with
        if gain and wornTwoHand and not twoHand and OTHER_HAND[slot] then
            gain, with = WithPartner(gain, id, slot, weights, power)
        end
        if gain and (not best or gain > best) then best, partner = gain, with end
    end
    if not (best and best >= MIN_GAIN) then return nil end
    return best, partner
end
