-- Offline checks for the Gear & Trinkets rules (NaowhForever_Combat/GearSets/GearSets.lua): which set the
-- automatic swaps want, what goes back afterwards, and what waits for combat to end.
-- Run from the repo root: lua Tools/regression/test-gear-swaps.lua

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local SETS = { Mount = 1, Drink = 2, Bear = 3, Dungeon = 4, Town = 5, Raid = 6, Main = 7 }
local BEAR_FORM = 5487

local function Fixture()
    local g = {
        combat = false, secret = false, mounted = false, resting = false, drinking = false, dead = false,
        feign = false, instance = "none", form = 0, worn = {}, bags = {}, equipped = nil, used = {}, equips = {},
        takenOff = {}, printed = {}, account = {},
        bank = {}, bankOpen = false, used_bank = {}, helm = nil, cloak = nil,
        settings = { gearLooks = {}, gearSets = true, gearMounted = "", gearResting = "", gearDrinking = "", gearDungeon = "",
            gearRaid = "", gearBattleground = "", gearForms = {}, gearCombatWeapons = false, gearClickOff = false },
        setItems = {},
    }
    local S = { Get = function(k) return g.settings[k] end, Set = function(k, v) g.settings[k] = v end }
    local ns = {
        QoLSettings = S, L = function(s) return s end,
        Print = function(s) g.printed[#g.printed + 1] = s end,
        AccountSettings = function() return g.account end,
        CharKey = function() return "Me-Realm" end,
        IsDrinking = function() return g.drinking end,
        Shared = { Items = { IsTwoHand = function(link) return link == "two-hander" end } },
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        BACKPACK_CONTAINER = 0, NUM_BAG_SLOTS = 1,
        C_AddOns = { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end },
        C_Secrets = { ShouldAurasBeSecret = function() return g.secret end },
        C_EquipmentSet = {
            GetEquipmentSetIDs = function()
                local ids = {}
                for _, id in pairs(SETS) do ids[#ids + 1] = id end
                return ids
            end,
            GetEquipmentSetInfo = function(id)
                for name, setID in pairs(SETS) do
                    if setID == id then return name, 0, id, g.equipped == id, 1, 1, 0, 0 end
                end
            end,
            GetEquipmentSetID = function(name) return SETS[name] end,
            UseEquipmentSet = function(id)
                assert(not g.combat, "a set equipped in combat")
                g.used[#g.used + 1] = id
                g.equipped = id
            end,
            GetItemIDs = function(id) return g.setItems[id] or {} end,
            GetIgnoredSlots = function() return {} end,
        },
        Enum = { BagIndex = { CharacterBankTab_1 = 6, CharacterBankTab_9 = 6 }, BankType = { Character = 0 } },
        C_Bank = { CanUseBank = function() return g.bankOpen end },
        ShowHelm = function(v) g.helm = v end,
        ShowCloak = function(v) g.cloak = v end,
        CopyTable = function(t)
            local function Copy(v)
                if type(v) ~= "table" then return v end
                local out = {}
                for k, inner in pairs(v) do out[k] = Copy(inner) end
                return out
            end
            return Copy(t)
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_Container = {
            GetContainerNumSlots = function() return #g.bank end,
            GetContainerItemID = function(_, slot) return g.bank[slot] end,
            UseContainerItem = function(_, slot)
                assert(not g.combat and g.bankOpen, "a bank item moved away from the bank")
                g.used_bank[#g.used_bank + 1] = slot
            end,
            GetContainerNumFreeSlots = function(bag) return bag == 0 and 1 or 0, 0 end,
            ContainerIDToInventoryID = function(bag) return bag + 30 end,
        },
        C_Item = {
            GetItemInfo = function(id) return g.names and g.names[id] end,
            GetItemCount = function(item) return g.bags[item] and 1 or 0 end,
            EquipItemByName = function(item, slot)
                assert(not g.combat or slot >= 16, "armor equipped in combat")
                g.equips[#g.equips + 1] = { item, slot }
                g.worn[slot] = item
            end,
        },
        InCombatLockdown = function() return g.combat end,
        UnitIsDeadOrGhost = function() return g.dead end,
        UnitIsFeignDeath = function() return g.feign end,
        UnitOnTaxi = function() return g.taxi end,
        IsMounted = function() return g.mounted end,
        IsResting = function() return g.resting end,
        IsInInstance = function() return g.instance ~= "none", g.instance end,
        GetShapeshiftForm = function() return g.form end,
        GetShapeshiftFormInfo = function(i) if i == 1 then return 0, g.form == 1, true, BEAR_FORM end end,
        GetInventoryItemLink = function(_, slot) return g.worn[slot] end,
        GetInventoryItemID = function(_, slot) return g.worn[slot] end,
        PickupInventoryItem = function(slot) g.takenOff[#g.takenOff + 1] = slot; g.worn[slot] = nil end,
        PutItemInBackpack = function() end,
        PutItemInBag = function() end,
    }, { __index = _G })
    local chunk = assert(loadfile("NaowhForever_Combat/GearSets/GearSets.lua"))
    setfenv(chunk, env)
    chunk()
    g.G = ns.GearSets
    g.ns = ns
    return g
end

local function Saved(g) return g.account.gearReturn and g.account.gearReturn["Me-Realm"] end

do
    local g = Fixture()
    g.settings.gearMounted, g.settings.gearResting = "Mount", "Town"
    g.equipped = SETS.Main
    g.resting = true
    g.G.AutoSwap()
    check("resting puts the town set on", g.equipped == SETS.Town and Saved(g) == SETS.Main)
    g.mounted = true
    g.G.AutoSwap()
    check("mounted beats resting, and the set to go back to stays", g.equipped == SETS.Mount and Saved(g) == SETS.Main)
    g.mounted, g.resting = false, false
    g.G.AutoSwap()
    check("leaving both puts the first set back", g.equipped == SETS.Main and Saved(g) == nil)
    g.mounted, g.taxi = true, true
    g.G.AutoSwap()
    check("a flight path is not riding", g.equipped == SETS.Main)
end

do
    local g = Fixture()
    g.settings.gearDrinking, g.settings.gearDungeon = "Drink", "Dungeon"
    g.instance = "party"
    g.G.AutoSwap()
    check("a dungeon puts its set on", g.equipped == SETS.Dungeon)
    g.drinking = true
    g.G.AutoSwap()
    check("drinking beats the dungeon set", g.equipped == SETS.Drink)
    g.drinking = false
    g.G.AutoSwap()
    check("standing up goes back to the dungeon set", g.equipped == SETS.Dungeon)
    g.instance = "raid"
    g.G.AutoSwap()
    check("a raid with no set of its own takes the dungeon set off", Saved(g) == nil)
end

do
    local g = Fixture()
    g.settings.gearDrinking = "Drink"
    g.drinking, g.secret = true, true
    g.G.AutoSwap()
    check("auras are not read while they are secret", g.equipped == nil)
    g.secret = false
    g.G.AutoSwap()
    check("and are once they are readable", g.equipped == SETS.Drink)
    g.secret, g.drinking = true, false
    g.G.AutoSwap()
    check("the last readable answer holds while they are secret", g.equipped == SETS.Drink)
end

do
    local g = Fixture()
    g.settings.gearForms = { [BEAR_FORM] = "Bear" }
    g.settings.gearRaid = "Raid"
    g.instance = "raid"
    g.G.AutoSwap()
    check("caster form in a raid wears the raid set", g.equipped == SETS.Raid)
    g.form = 1
    g.G.AutoSwap()
    check("bear form wears the bear set", g.equipped == SETS.Bear)
    check("the form's spell ID is what picks it", g.G.FormSpell(1) == BEAR_FORM)
end

do
    local g = Fixture()
    g.settings.gearResting = "Town"
    g.worn = { [1] = "hat", [16] = "two-hander" }
    g.bags = { hat = true, ["two-hander"] = true }
    g.resting = true
    g.G.AutoSwap()
    local saved = Saved(g)
    check("no set worn: the items themselves are kept", type(saved) == "table" and saved[1] == "hat"
        and saved[17] == false)
    g.worn = { [1] = "helm", [2] = "necklace", [16] = "sword", [17] = "shield" }
    g.resting = false
    g.G.AutoSwap()
    check("the kept hat and two-hander go back on", g.worn[1] == "hat" and g.worn[16] == "two-hander")
    check("an empty neck is taken off into the bags", g.takenOff[1] == 2 and g.worn[2] == nil)
    check("the off hand is left for the two-hander to replace", g.worn[17] == "shield" and #g.takenOff == 1)
    check("and nothing is kept after", Saved(g) == nil)
end

do
    local g = Fixture()
    g.settings.gearMounted = "Mount"
    g.combat = true
    g.G.EquipByHand(SETS.Main)
    check("a set asked for in combat waits", #g.used == 0 and g.printed[1] == "Gear set equips when combat ends.")
    g.combat = false
    g.G.AutoSwap()
    g.G.EquipPending()
    check("and goes on when it ends", g.used[1] == SETS.Main and #g.used == 1)
end

do
    local g = Fixture()
    g.setItems[SETS.Main] = { [1] = 101, [16] = 102, [17] = 0, [18] = 103 }
    g.names = { [101] = "Helm", [102] = "Axe of Doom", [103] = "Bow" }
    check("the combat macro equips only the set's weapon slots, by name, in combat only",
        g.G.CombatMacro(SETS.Main) == "/equipslot [combat]16 Axe of Doom\n/equipslot [combat]18 Bow")
    g.names[102], g.names[103] = nil, nil
    check("a weapon not yet known to the client is left out", g.G.CombatMacro(SETS.Main) == nil)
    check("a set with no weapons has no macro", g.G.CombatMacro(SETS.Town) == nil)
    g.combat = true
    g.names = { [102] = "Axe of Doom" }
    g.bags = { [102] = true }
    g.settings.gearCombatWeapons = true
    g.G.EquipByHand(SETS.Main)
    check("in combat the addon itself equips nothing, the set waits", #g.equips == 0 and #g.used == 0)
end

do
    local g = Fixture()
    g.settings.gearCombatWeapons = true
    g.setItems[SETS.Main] = { [16] = 102 }
    g.bags = { [102] = true }
    g.dead, g.combat = true, true
    g.G.EquipByHand(SETS.Main)
    check("dead: nothing goes on, not even weapons", #g.equips == 0 and #g.used == 0
        and g.printed[1] == "Gear set equips when you are alive again.")
    g.combat = false
    g.G.EquipPending()
    check("still dead after combat: it keeps waiting", #g.used == 0)
    g.dead = false
    g.G.EquipPending()
    check("alive again: it goes on", g.used[1] == SETS.Main)
    g.dead, g.feign = true, true
    g.G.EquipByHand(SETS.Town)
    check("Feign Death is not death", g.used[2] == SETS.Town)
end

do
    local g = Fixture()
    g.equipped = SETS.Main
    g.G.EquipByHand(SETS.Town)
    g.G.EquipByHand(SETS.Town)
    check("Click Again to Take Off off: a second click changes nothing", #g.used == 2 and g.equipped == SETS.Town)
    g.settings.gearClickOff = true
    g.G.EquipByHand(SETS.Town)
    check("on: clicking the set you wear puts the one before it back", g.used[3] == SETS.Main)
    g.G.EquipByHand(SETS.Main)
    check("and with nothing left to put back it says so", #g.used == 3 and #g.printed == 1)
    g.G.Wear(SETS.Main)
    check("the window's Equip never takes a set off", g.used[4] == SETS.Main)
end

do
    local g = Fixture()
    g.worn = { [1] = "hat" }
    g.bags = { hat = true }
    g.G.Wear(SETS.Town)
    g.worn[1] = "helm"
    g.G.TakeOff()
    check("no set before: the items themselves go back", g.worn[1] == "hat")
end

do
    local g = Fixture()
    local Run = g.ns.GearSetsCommand
    g.equipped = SETS.Main
    Run("equip Town")
    check("/nfgear equip puts the set on", g.used[1] == SETS.Town)
    Run("toggle Town")
    check("/nfgear toggle on a worn set takes it off", g.used[2] == SETS.Main)
    Run("toggle Town, Raid")
    check("/nfgear toggle a, b puts a on when a is off", g.used[3] == SETS.Town)
    Run("TOGGLE Town ,  Raid ")
    check("and b when a is on, whatever the case and spaces", g.used[4] == SETS.Raid)
    Run("off")
    check("/nfgear off puts back what came before", g.used[5] == SETS.Town)
    Run("equip Nope")
    check("an unknown set is named", g.printed[#g.printed] == "No gear set called Nope.")
    Run("dance")
    check("an unknown word shows how to use it", g.printed[#g.printed]:find("^/nfgear") ~= nil)
    g.settings.gearSets = false
    Run("equip Town")
    check("switched off: nothing happens", #g.used == 5)
end

do
    local g = Fixture()
    g.setItems[SETS.Raid] = { [1] = 101, [11] = 201, [12] = 201, [16] = 102 }
    g.worn = { [16] = 102 }
    g.bags = { [201] = true }
    g.bank = { 300, 101, 201, 201 }
    g.G.FromBank(SETS.Raid)
    check("bank closed: it says to open it", #g.used_bank == 0 and g.printed[1] == "Open your bank first.")
    g.bankOpen = true
    g.G.FromBank(SETS.Raid)
    check("open: only what the set still needs comes out", #g.used_bank == 2 and g.used_bank[1] == 2
        and g.used_bank[2] == 3)
    check("and it says how many", g.printed[2] == "Took 2 of Raid's items out of your bank.")
end

do
    local g = Fixture()
    g.G.ShowLooks(SETS.Raid)
    check("no look picked: helm and cloak are left alone", g.helm == nil and g.cloak == nil)
    g.G.SetLook("Raid", "helm", false)
    g.G.ShowLooks(SETS.Raid)
    check("Hide on the helm hides it, the cloak still left alone", g.helm == false and g.cloak == nil)
    g.G.SetLook("Raid", "cloak", true)
    g.G.SetLook("Raid", "helm", nil)
    check("Leave As It Is clears just that part", g.G.Look("Raid", "helm") == nil and g.G.Look("Raid", "cloak") == true)
    g.G.SetLook("Raid", "cloak", nil)
    check("and the set's entry goes once both are left", g.settings.gearLooks.Raid == nil)
end

print(("PASS gear swaps: %d checks"):format(checks))
