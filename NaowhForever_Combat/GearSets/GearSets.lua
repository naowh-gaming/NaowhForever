-- GearSets.lua: the gear sets' rules and API (ns.GearSets): your sets, equipping them, putting back what you wore, automatic swaps.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local FIRST_SLOT, LAST_SLOT = 1, 19
local MAIN_HAND, OFF_HAND = 16, 17
local COMBAT_SLOTS = { 16, 17, 18 }
local FORM_SPELL = 4
local RETURN = "gearReturn"
local TEXT_AFTER_COMBAT = ns.L("Gear set equips when combat ends.")
local TEXT_AFTER_DEATH = ns.L("Gear set equips when you are alive again.")
local TEXT_MISSING = ns.L("%s is not in your bags, so it was not put back.")
local TEXT_NO_ROOM = ns.L("No room in your bags to take off %s.")
local SWAP_KEYS = { "gearMounted", "gearDrinking", "gearDungeon", "gearRaid", "gearBattleground", "gearResting",
    "fishingGearSet" }
local INSTANCE_KEYS = { party = "gearDungeon", raid = "gearRaid", pvp = "gearBattleground" }
local OLD_ADDON = "NaowhForever_GearSets"
local OLD_COPY = C_AddOns.DoesAddOnExist(OLD_ADDON) and C_AddOns.GetAddOnEnableState(OLD_ADDON) > 0

local pending
local autoSet
local drinking = false
local free = {}

local function ByName(a, b) return a.name < b.name end

local function Sets()
    local sets = {}
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name, icon, setID, isEquipped, numItems, _, _, numLost = C_EquipmentSet.GetEquipmentSetInfo(id)
        if name then
            sets[#sets + 1] = { id = setID, name = name, icon = icon, equipped = isEquipped,
                items = numItems, lost = numLost }
        end
    end
    table.sort(sets, ByName)
    return sets
end

local function EquippedSet()
    for _, set in ipairs(Sets()) do
        if set.equipped then return set.id end
    end
end

local function SetByName(name)
    if not name or name == "" then return end
    return C_EquipmentSet.GetEquipmentSetID(name)
end

local function Wearing()
    local set = EquippedSet()
    if set then return set end
    local items = {}
    for slot = FIRST_SLOT, LAST_SLOT do items[slot] = GetInventoryItemLink("player", slot) or false end
    return items
end

local function CountFree()
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local count, family = C_Container.GetContainerNumFreeSlots(bag)
        free[bag] = family == 0 and count or 0
    end
end

local function TakeOff(slot)
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        if free[bag] > 0 then
            free[bag] = free[bag] - 1
            PickupInventoryItem(slot)
            if bag == BACKPACK_CONTAINER then
                PutItemInBackpack()
            else
                PutItemInBag(C_Container.ContainerIDToInventoryID(bag))
            end
            return
        end
    end
    ns.Print(TEXT_NO_ROOM:format(GetInventoryItemLink("player", slot)))
end

local function PutBack(items)
    CountFree()
    local twoHand = items[MAIN_HAND] and ns.Shared.Items.IsTwoHand(items[MAIN_HAND])
    for slot = FIRST_SLOT, LAST_SLOT do
        local link, worn = items[slot], GetInventoryItemLink("player", slot)
        if link == false then
            if worn and not (slot == OFF_HAND and twoHand) then TakeOff(slot) end
        elseif link and link ~= worn then
            if C_Item.GetItemCount(link) > 0 then
                C_Item.EquipItemByName(link, slot)
            else
                ns.Print(TEXT_MISSING:format(link))
            end
        end
    end
end

local function WeaponsNow(target)
    local ids, ignored
    if type(target) == "number" then
        ids, ignored = C_EquipmentSet.GetItemIDs(target), C_EquipmentSet.GetIgnoredSlots(target)
    end
    for _, slot in ipairs(COMBAT_SLOTS) do
        if ids then
            local id = not ignored[slot] and ids[slot]
            if id and id > 0 and GetInventoryItemID("player", slot) ~= id and C_Item.GetItemCount(id) > 0 then
                C_Item.EquipItemByName(id, slot)
            end
        else
            local link = target[slot]
            if link and GetInventoryItemLink("player", slot) ~= link and C_Item.GetItemCount(link) > 0 then
                C_Item.EquipItemByName(link, slot)
            end
        end
    end
end

local function Dead()
    return UnitIsDeadOrGhost("player") and not UnitIsFeignDeath("player")
end

local function Equip(target, quiet)
    if not target then return end
    if type(target) == "number" and not C_EquipmentSet.GetEquipmentSetInfo(target) then return end
    local combat, dead = InCombatLockdown(), Dead()
    if combat or dead then
        if combat and not dead and S.Get("gearCombatWeapons") then WeaponsNow(target) end
        pending = target
        if not quiet then ns.Print(dead and TEXT_AFTER_DEATH or TEXT_AFTER_COMBAT) end
        return
    end
    pending = nil
    if type(target) == "table" then
        PutBack(target)
    else
        C_EquipmentSet.UseEquipmentSet(target)
    end
end

local function Store(name)
    local account = ns.AccountSettings()
    account[name] = account[name] or {}
    return account[name], ns.CharKey(account[name])
end

local function Wanted(key)
    return SetByName(S.Get(key))
end

local function Drinking()
    if not (InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()) then drinking = ns.IsDrinking() end
    return drinking
end

local function FormSpell(index)
    return (select(FORM_SPELL, GetShapeshiftFormInfo(index)))
end

local function FormSet()
    local forms = S.Get("gearForms")
    if not next(forms) then return end
    local index = GetShapeshiftForm()
    if index == 0 then return end
    local spellID = FormSpell(index)
    return spellID and SetByName(forms[spellID])
end

local function InstanceSet()
    local key = INSTANCE_KEYS[select(2, IsInInstance())]
    return key and Wanted(key)
end

local function WantedAuto()
    local drink = Wanted("gearDrinking")
    return IsMounted() and Wanted("gearMounted") or drink and Drinking() and drink or FormSet() or InstanceSet()
        or IsResting() and Wanted("gearResting") or nil
end

local G = { SWAP_KEYS = SWAP_KEYS, OLD_COPY = OLD_COPY }
ns.GearSets = G

G.Sets = Sets
G.FormSpell = FormSpell

function G.On()
    return S.Get("gearSets") and not OLD_COPY
end

function G.EquipByHand(setID)
    local saved, key = Store(RETURN)
    saved[key] = nil
    Equip(setID)
end

function G.EquipPending()
    if pending then Equip(pending, true) end
end

function G.AutoSwap()
    local want = WantedAuto()
    if want == autoSet then return end
    local saved, key = Store(RETURN)
    if pending == autoSet then pending = nil end
    if want then
        if not autoSet and EquippedSet() ~= want then saved[key] = Wearing() end
        autoSet = want
        Equip(want, true)
    else
        autoSet = nil
        Equip(saved[key], true)
        saved[key] = nil
    end
end
