-- Sim on MythicSim: the character JSON MythicSim's Forever sim reads. Gear in the sim's slot order,
-- enchants and random suffixes; bags' equippable items; talents a digit each by tab, row and column,
-- with off-grid, hidden and replaced nodes left out and a rank over 9 written as 9; English profession names; the game's Scourge
-- as Undead; and no export while the game keeps your stats secret.
local Load = dofile("Tools/regression/load_files.lua")
local FILES = { "NaowhForever_BiS/BiS/MythicSim.lua" }

-- Three tabs side by side, 600 apart, as the game lays out a class's tree.
local function Node(id, group, x, y, rank, o)
    o = o or {}
    return { ID = id, groupIDs = { 900, group }, posX = x, posY = y, activeRank = rank,
        maxRanks = o.max or 5, isVisible = o.hidden ~= true, entryIDs = { id * 10 } }
end

local NODES = {
    Node(1, 11, 1020, 2130, 5), Node(2, 11, 1620, 2130, 0), Node(3, 11, 1020, 2730, 2),
    Node(4, 11, 1620, 2720, 3),
    Node(5, 11, 2220, 2730, 1, { hidden = true }),
    Node(6, 11, 102800, 2130, 1),
    Node(7, 12, 5020, 2130, 4), Node(8, 12, 5020, 2130, 1), Node(9, 12, 5620, 2130, 0, { max = 0 }),
    Node(10, 13, 9080, 2130, 12, { max = 12 }), Node(11, 13, 9080, 21300, 1),
}

local function Fixture(o)
    o = o or {}
    local ns = { BiS = {}, CODE_BUILD = "1.2.34", RealmName = function() return "Forever" end }
    local nodes = {}
    for _, node in ipairs(NODES) do nodes[node.ID] = node end
    local links = { [1] = "|cffa335ee|Hitem:12345:1900:0:0:0:0:0:0:60|h[Helm]|h|r",
        [11] = "|Hitem:222::::::-39:0|h", [16] = "|Hitem:333:2564::::::|h", [4] = "|Hitem:9:::::::|h" }
    local bag = { [0] = { "|Hitem:444:::::::|h", "|Hitem:555:::::::|h" }, [1] = {} }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        NUM_BAG_SLOTS = 1,
        Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 } },
        C_Secrets = { ShouldUnitStatsBeSecret = function() return o.secret == true end,
            ShouldAurasBeSecret = function() return false end },
        GetInventoryItemLink = function(_, slot) return links[slot] end,
        C_Container = { GetContainerNumSlots = function(b) return #bag[b] end,
            GetContainerItemLink = function(b, s) return bag[b][s] end },
        C_Item = { IsEquippableItem = function(link) return link:find("444") ~= nil end },
        C_ClassTalents = { GetActiveConfigID = function() return 7 end },
        C_Traits = {
            GetConfigInfo = function() return { treeIDs = { 70 } } end,
            GetGroupDisplayInfoByTreeID = function() return { { groupID = 11 }, { groupID = 12 }, { groupID = 13 } } end,
            GetTreeNodes = function()
                local ids = {}
                for i = #NODES, 1, -1 do ids[#ids + 1] = NODES[i].ID end
                return ids
            end,
            GetNodeInfo = function(_, id) return nodes[id] end,
            GetEntryInfo = function(_, entry) return { definitionID = entry + 1 } end,
            GetDefinitionInfo = function(definition) return { spellID = definition * 100 } end,
        },
        GetProfessions = function() return 3, nil, 5 end,
        GetProfessionInfo = function(index)
            if index == 3 then return "Bergbau", 0, 150, 300, 0, 0, 186 end
            return "Kochkunst", 0, 75, 75, 0, 0, 185
        end,
        C_UnitAuras = { GetAuraDataByIndex = function(_, i) if i <= 2 then return { spellId = 1000 + i } end end },
        UnitStat = function(_, i) return 100 + i, 100 + i, 10, 0 end,
        UnitArmor = function() return 1000, 1200 end,
        UnitHealthMax = function() return 4000 end,
        UnitPowerMax = function() return 3000 end,
        GetCritChance = function() return 5.25 end,
        GetRangedCritChance = function() return 4 end,
        GetSpellCritChance = function(school) return school end,
        GetSpellBonusDamage = function() return 0 end,
        GetSpellBonusHealing = function() return 0 end,
        GetHitModifier = function() return 1 end,
        GetSpellHitModifier = function() return 0 end,
        GetDodgeChance = function() return 5 end,
        GetParryChance = function() return 5 end,
        GetBlockChance = function() return 0 end,
        UnitAttackPower = function() return 1200, 100, 0 end,
        UnitRangedAttackPower = function() return 50, 0, 0 end,
        GetManaRegen = function() return 0.5, 0.25 end,
        C_SpellBook = {
            GetNumSpellBookSkillLines = function() return 1 end,
            GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 3 } end,
            GetSpellBookItemInfo = function(i)
                return ({ { itemType = 1, spellID = 78 }, { itemType = 2, spellID = 99 }, { itemType = 1, spellID = 6 } })[i]
            end,
        },
        UnitFullName = function() return 'Na"owh', nil end,
        GetRealmName = function() return "Forever" end,
        UnitRace = function() return "Undead", o.race or "Scourge", 5 end,
        UnitClass = function() return "Warrior", "WARRIOR" end,
        UnitLevel = function() return 60 end,
        UnitFactionGroup = function() return "Horde" end,
        GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end,
        GetLocale = function() return "deDE" end,
    }, { __index = _G })
    Load(FILES, env)
    return ns.BiS.MythicSim
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end
local function Has(text, part) assert(text:find(part, 1, true), "missing " .. part .. " in\n" .. text) end

Case("gear goes in the sim's slot order, with enchants and random suffixes", function()
    local out = Fixture().Export()
    Has(out, '"gear":{"items":[{"id":12345,"enchant":1900},{"id":222,"random_suffix":-39},{"id":333,"enchant":2564}]}')
    assert(not out:find('"id":9,', 1, true), "slot 4, the shirt, is not exported")
end)

Case("bags carry only equippable items", function()
    Has(Fixture().Export(), '"bags":[{"id":444}]')
end)

Case("talents read by tab, row and column; hidden, off-grid and replaced nodes left out", function()
    local out = Fixture().Export()
    Has(out, '"talents":"5023-1-9"')
    Has(out, '"talentPoints":20')
    Has(out, '"talentSpells":[[[1100,5],[2100,0],[3100,2],[4100,3]],[[8100,1]],[[10100,9]]]')
end)

Case("professions by their English names, unknown skill lines left out", function()
    Has(Fixture().Export(), '"professions":[{"name":"Mining","level":150}]')
end)

Case("identity, the sheet and the spells you know", function()
    local out = Fixture().Export()
    Has(out, '"name":"Na\\"owh"')
    Has(out, '"realm":"Forever"')
    Has(out, '"race":"Undead"')
    Has(out, '"class":"warrior"')
    Has(out, '"exporter":"NaowhForever"')
    Has(out, '"raceId":5,"faction":"Horde"')
    Has(out, '"base":[91,92,93,94,95]')
    Has(out, '"meleeCrit":5.25')
    Has(out, '"spellCrit":[2,3,4,5,6,7]')
    Has(out, '"manaRegen":[0.5,0.25]')
    Has(out, '"auras":[1001,1002]')
    Has(out, '"knownSpells":[6,78]')
    assert(Fixture({ race = "Orc" }).Export():find('"race":"Orc"', 1, true))
end)

Case("no export while the game keeps your stats secret", function()
    assert(Fixture().Available() == true)
    assert(Fixture({ secret = true }).Available() == false)
end)

print(("test-bis-mythicsim: %d cases passed"):format(count))
