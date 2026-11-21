-- GearSets.lua: the gear sets' rules and API (ns.GearSets): your sets, equipping them, putting back what you wore, automatic swaps.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local FIRST_SLOT, LAST_SLOT = 1, 19
local MAIN_HAND, OFF_HAND = 16, 17
local COMBAT_SLOTS = { 16, 17, 18 }
local FORM_SPELL = 4
local RETURN, BEFORE = "gearReturn", "gearBefore"
local SET_EQUIPPED = 4
local EQUIP_SLOT = "/equipslot [combat]%d %s"
local TEXT_AFTER_COMBAT = ns.L("Gear set equips when combat ends.")
local TEXT_AFTER_DEATH = ns.L("Gear set equips when you are alive again.")
local TEXT_MISSING = ns.L("%s is not in your bags, so it was not put back.")
local TEXT_NO_ROOM = ns.L("No room in your bags to take off %s.")
local TEXT_NOTHING = ns.L("Nothing to put back: no set was put on since you last took one off.")
local TEXT_NO_SET = ns.L("No gear set called %s.")
local TEXT_USAGE = ns.L("/nfgear equip <set>, /nfgear toggle <set>[, <other set>] or /nfgear off")
local TEXT_SWITCHED_OFF = ns.L("%s is switched off. Turn it on under Settings > Modules.")
local TEXT_MODULE = ns.L("Gear & Trinkets")
local SWAP_KEYS = { "gearMounted", "gearDrinking", "gearDungeon", "gearRaid", "gearBattleground", "gearResting",
    "fishingGearSet" }
local INSTANCE_KEYS = { party = "gearDungeon", raid = "gearRaid", pvp = "gearBattleground" }
local TEXT_OPEN_BANK = ns.L("Open your bank first.")
local TEXT_NOT_IN_BANK = ns.L("Nothing of %s is waiting in your bank.")
local TEXT_FROM_BANK = ns.L("Took %d of %s's items out of your bank.")
local OLD_ADDON = "NaowhForever_GearSets"
local OLD_COPY = C_AddOns.DoesAddOnExist(OLD_ADDON) and C_AddOns.GetAddOnEnableState(OLD_ADDON) > 0

local pending
local autoSet
local drinking = false
local free = {}
local macroLines = {}
local wanted = {}

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

local function IsWorn(setID)
    return select(SET_EQUIPPED, C_EquipmentSet.GetEquipmentSetInfo(setID)) == true
end

local function Whole(setID)
    for _, ignored in pairs(C_EquipmentSet.GetIgnoredSlots(setID)) do
        if ignored then return false end
    end
    return true
end

local function Wearing()
    local set = EquippedSet()
    if set and Whole(set) then return set end
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

local function Dead()
    return UnitIsDeadOrGhost("player") and not UnitIsFeignDeath("player")
end

local function Equip(target, quiet)
    if not target then return end
    if type(target) == "number" and not C_EquipmentSet.GetEquipmentSetInfo(target) then return end
    local combat, dead = InCombatLockdown(), Dead()
    if combat or dead then
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
    return IsMounted() and not UnitOnTaxi("player") and Wanted("gearMounted") or drink and Drinking() and drink or FormSet() or InstanceSet()
        or IsResting() and Wanted("gearResting") or nil
end

local G = { SWAP_KEYS = SWAP_KEYS, OLD_COPY = OLD_COPY }
ns.GearSets = G

G.Sets = Sets
G.FormSpell = FormSpell

function G.On()
    return S.Get("gearSets") and not OLD_COPY
end

function G.Wear(setID)
    local saved, key = Store(RETURN)
    saved[key] = nil
    if not IsWorn(setID) then
        local before, beforeKey = Store(BEFORE)
        before[beforeKey] = Wearing()
    end
    Equip(setID)
end

function G.TakeOff()
    local before, key = Store(BEFORE)
    local target = before[key]
    if not target then return ns.Print(TEXT_NOTHING) end
    before[key] = nil
    Equip(target)
end

function G.FromBank(setID)
    local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
    if InCombatLockdown() or not C_Bank.CanUseBank(Enum.BankType.Character) then return ns.Print(TEXT_OPEN_BANK) end
    wipe(wanted)
    local ignored = C_EquipmentSet.GetIgnoredSlots(setID)
    for slot, id in pairs(C_EquipmentSet.GetItemIDs(setID)) do
        if id > 0 and not ignored[slot] and GetInventoryItemID("player", slot) ~= id then
            wanted[id] = (wanted[id] or 0) + 1
        end
    end
    for id, count in pairs(wanted) do wanted[id] = count - C_Item.GetItemCount(id) end
    local moved = 0
    for bag = Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_9 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and (wanted[id] or 0) > 0 then
                wanted[id] = wanted[id] - 1
                moved = moved + 1
                C_Container.UseContainerItem(bag, slot)
            end
        end
    end
    if moved == 0 then return ns.Print(TEXT_NOT_IN_BANK:format(name)) end
    ns.Print(TEXT_FROM_BANK:format(moved, name))
end

function G.Look(name, part)
    local look = S.Get("gearLooks")[name]
    return look and look[part]
end

function G.SetLook(name, part, show)
    local looks = CopyTable(S.Get("gearLooks"))
    local look = looks[name] or {}
    look[part] = show
    looks[name] = next(look) and look or nil
    S.Set("gearLooks", looks)
end

function G.ShowLooks(setID)
    local look = S.Get("gearLooks")[C_EquipmentSet.GetEquipmentSetInfo(setID)]
    if not look then return end
    if look.helm ~= nil then ShowHelm(look.helm) end
    if look.cloak ~= nil then ShowCloak(look.cloak) end
end

function G.CombatMacro(setID)
    wipe(macroLines)
    local ids, ignored = C_EquipmentSet.GetItemIDs(setID), C_EquipmentSet.GetIgnoredSlots(setID)
    for _, slot in ipairs(COMBAT_SLOTS) do
        local id = not ignored[slot] and ids[slot]
        local name = id and id > 0 and C_Item.GetItemInfo(id)
        if name then macroLines[#macroLines + 1] = EQUIP_SLOT:format(slot, name) end
    end
    if #macroLines == 0 then return nil end
    return table.concat(macroLines, "\n")
end

function G.EquipByHand(setID)
    if S.Get("gearClickOff") and IsWorn(setID) then return G.TakeOff() end
    G.Wear(setID)
end

function G.EquipPending()
    local target = pending
    if not target then return end
    Equip(target, true)
    if pending then return end
    local saved, key = Store(RETURN)
    if saved[key] == target then saved[key] = nil end
end

function G.AutoSwap()
    local want = WantedAuto()
    if want == autoSet then return end
    local saved, key = Store(RETURN)
    local returning = pending ~= nil and pending == saved[key]
    if pending == autoSet then pending = nil end
    if want then
        if not autoSet and not returning and EquippedSet() ~= want then saved[key] = Wearing() end
        autoSet = want
        Equip(want, true)
    else
        autoSet = nil
        Equip(saved[key], true)
        if pending ~= saved[key] then saved[key] = nil end
    end
end

local function Named(name)
    local id = SetByName(name)
    if not id then ns.Print(TEXT_NO_SET:format(name)) end
    return id
end

function ns.GearSetsCommand(msg)
    if not G.On() then return ns.Print(TEXT_SWITCHED_OFF:format(TEXT_MODULE)) end
    local verb, rest = msg:match("^(%S+)%s*(.-)%s*$")
    verb = verb:lower()
    local first, second = rest:match("^(.-)%s*,%s*(.+)$")
    first = first or rest
    if verb == "off" then return G.TakeOff() end
    if first == "" or not (verb == "equip" or verb == "toggle") then return ns.Print(TEXT_USAGE) end
    local id = Named(first)
    if not id then return end
    if verb == "equip" then return G.Wear(id) end
    if not IsWorn(id) then return G.Wear(id) end
    if not second then return G.TakeOff() end
    local other = Named(second)
    if other then G.Wear(other) end
end
