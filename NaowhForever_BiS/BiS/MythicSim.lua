-- MythicSim.lua: your character as MythicSim's Forever sim reads it, to paste on its site (B.MythicSim).
local ns = _G.NaowhForever

local B = ns.BiS

local EXPORTER = "NaowhForever"
local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local LINK_ID, LINK_ENCHANT, LINK_SUFFIX = 1, 2, 7
local SQUARE = 600
local MAX_COL, MAX_ROW = 3, 10
local MAX_DIGIT = 9
local MAX_AURAS = 40
local SPELL_SCHOOLS = { 2, 3, 4, 5, 6, 7 }
local STATS = 5
local MANA = 0
local PROFESSIONS = {
    [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [182] = "Herbalism",
    [186] = "Mining", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting", [393] = "Skinning",
}
local RACE_NAMES = { Scourge = "Undead" }
local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local NONE = {}

local function String(text)
    return '"' .. tostring(text or ""):gsub('[%c"\\]', function(c)
        return ESCAPES[c] or ("\\u%04x"):format(c:byte())
    end) .. '"'
end

local function Number(v)
    v = tonumber(v) or 0
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    if v == math.floor(v) then return ("%d"):format(v) end
    return (("%.4f"):format(v):gsub("0+$", ""))
end

local function Numbers(list)
    local out = {}
    for i = 1, #list do out[i] = Number(list[i]) end
    return "[" .. table.concat(out, ",") .. "]"
end

local function Field(name, value)
    return String(name) .. ":" .. value
end

local function Item(link)
    local payload = link and link:match("item:([%-%d:]+)")
    if not payload then return nil end
    local fields = {}
    for field in (payload .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = tonumber(field) or 0 end
    local id = fields[LINK_ID]
    if not id or id <= 0 then return nil end
    local out = { Field("id", id) }
    local enchant, suffix = fields[LINK_ENCHANT] or 0, fields[LINK_SUFFIX] or 0
    if enchant ~= 0 then out[#out + 1] = Field("enchant", enchant) end
    if suffix ~= 0 then out[#out + 1] = Field("random_suffix", suffix) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function Gear()
    local items = {}
    for _, slot in ipairs(SLOTS) do
        local item = Item(GetInventoryItemLink("player", slot))
        if item then items[#items + 1] = item end
    end
    return items
end

local function Bags()
    local items = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local link = C_Container.GetContainerItemLink(bag, slot)
            local item = link and C_Item.IsEquippableItem(link) and Item(link)
            if item then items[#items + 1] = item end
        end
    end
    return items
end

local function TabOf(info, tabs)
    for _, group in ipairs(info.groupIDs or NONE) do
        if tabs[group] then return tabs[group] end
    end
end

local function Square(a, b)
    if a.row ~= b.row then return a.row < b.row end
    return a.col < b.col
end

local function TalentTabs()
    local configID = C_ClassTalents.GetActiveConfigID()
    local config = configID and C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return nil end
    local tabs, out = {}, {}
    for i, group in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or NONE) do
        tabs[group.groupID], out[i] = i, {}
    end
    local nodes, top, left = {}, nil, {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        local tab = info and TabOf(info, tabs)
        if tab then
            nodes[#nodes + 1] = { info = info, tab = tab }
            top = math.min(top or info.posY, info.posY)
            left[tab] = math.min(left[tab] or info.posX, info.posX)
        end
    end
    local squares = {}
    for _, node in ipairs(nodes) do
        local info = node.info
        node.row = math.floor((info.posY - top) / SQUARE + 0.5)
        node.col = math.floor((info.posX - left[node.tab]) / SQUARE + 0.5)
        if info.isVisible and (info.maxRanks or 0) > 0 and node.row <= MAX_ROW and node.col <= MAX_COL then
            local key = node.tab .. ":" .. node.row .. ":" .. node.col
            local seen = squares[key]
            if not seen or info.ID > seen.info.ID then squares[key] = node end
        end
    end
    for _, node in pairs(squares) do
        local tab = out[node.tab]
        tab[#tab + 1] = node
    end
    for _, tab in ipairs(out) do table.sort(tab, Square) end
    return out, configID
end

local function NodeSpell(configID, info)
    local entryID = info.entryIDs and info.entryIDs[1]
    local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
    local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    return definition and definition.spellID or 0
end

local function Talents()
    local tabs, configID = TalentTabs()
    if not tabs then return "", 0, nil end
    local strings, spells, points = {}, {}, 0
    for i, tab in ipairs(tabs) do
        local digits, ranks = {}, {}
        for j, node in ipairs(tab) do
            local rank = math.min(node.info.activeRank or 0, node.info.maxRanks, MAX_DIGIT)
            digits[j] = tostring(rank)
            ranks[j] = "[" .. NodeSpell(configID, node.info) .. "," .. rank .. "]"
            points = points + rank
        end
        strings[i] = table.concat(digits)
        spells[i] = "[" .. table.concat(ranks, ",") .. "]"
    end
    return table.concat(strings, "-"), points, "[" .. table.concat(spells, ",") .. "]"
end

local function Professions()
    local out = {}
    for _, index in pairs({ GetProfessions() }) do
        local _, _, level, _, _, _, line = GetProfessionInfo(index)
        local name = PROFESSIONS[line]
        if name then out[#out + 1] = { name = name, level = level } end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    for i, p in ipairs(out) do out[i] = "{" .. Field("name", String(p.name)) .. "," .. Field("level", p.level) .. "}" end
    return out
end

local function Auras()
    local ids = {}
    for i = 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        ids[#ids + 1] = aura.spellId
    end
    return ids
end

local function PerSchool(get)
    local out = {}
    for i, school in ipairs(SPELL_SCHOOLS) do out[i] = get(school) end
    return out
end

local function Sheet()
    local base, total, buffs, debuffs = {}, {}, {}, {}
    for i = 1, STATS do
        local stat, effective, plus, minus = UnitStat("player", i)
        base[i], total[i], buffs[i], debuffs[i] = stat - plus - minus, effective, plus, minus
    end
    local armorBase, armor = UnitArmor("player")
    return "{" .. table.concat({
        Field("level", UnitLevel("player")),
        Field("base", Numbers(base)),
        Field("attributes", Numbers(total)),
        Field("attributeBuffs", Numbers(buffs)),
        Field("attributeDebuffs", Numbers(debuffs)),
        Field("health", Number(UnitHealthMax("player"))),
        Field("mana", Number(UnitPowerMax("player", MANA))),
        Field("meleeCrit", Number(GetCritChance())),
        Field("rangedCrit", Number(GetRangedCritChance())),
        Field("spellCrit", Numbers(PerSchool(GetSpellCritChance))),
        Field("spellPower", Numbers(PerSchool(GetSpellBonusDamage))),
        Field("healingPower", Number(GetSpellBonusHealing())),
        Field("meleeHit", Number(GetHitModifier())),
        Field("spellHit", Number(GetSpellHitModifier())),
        Field("dodge", Number(GetDodgeChance())),
        Field("parry", Number(GetParryChance())),
        Field("block", Number(GetBlockChance())),
        Field("attackPower", Numbers({ UnitAttackPower("player") })),
        Field("rangedAttackPower", Numbers({ UnitRangedAttackPower("player") })),
        Field("armor", Numbers({ armorBase, armor })),
        Field("manaRegen", Numbers({ GetManaRegen() })),
        Field("auras", Numbers(Auras())),
    }, ",") .. "}"
end

local function KnownSpells()
    local ids, seen = {}, {}
    local bank, spell = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
            local id = item and item.itemType == spell and item.spellID
            if id and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids)
    return ids
end

local M = {}
B.MythicSim = M

function M.Available()
    return not (C_Secrets.ShouldUnitStatsBeSecret() or C_Secrets.ShouldAurasBeSecret())
end

function M.Export()
    local name, realm = UnitFullName("player")
    local _, raceToken, raceID = UnitRace("player")
    local _, class = UnitClass("player")
    local version, build, _, interface = GetBuildInfo()
    local talents, points, spells = Talents()
    local meta = {
        Field("exporter", String(EXPORTER)),
        Field("addonVersion", String(ns.CODE_BUILD)),
        Field("clientVersion", String(version)),
        Field("clientBuild", String(build)),
        Field("interface", Number(interface)),
        Field("talentSource", String(spells and "traits" or "none")),
        Field("locale", String(GetLocale())),
        Field("raceId", Number(raceID)),
    }
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" or faction == "Horde" then meta[#meta + 1] = Field("faction", String(faction)) end
    meta[#meta + 1] = Field("talentPoints", points)
    if spells then meta[#meta + 1] = Field("talentSpells", spells) end
    meta[#meta + 1] = Field("sheet", Sheet())
    meta[#meta + 1] = Field("knownSpells", Numbers(KnownSpells()))
    return "{" .. table.concat({
        Field("version", String(ns.CODE_BUILD)),
        Field("name", String(name)),
        Field("realm", String(realm or ns.RealmName())),
        Field("race", String(RACE_NAMES[raceToken] or raceToken)),
        Field("class", String(class:lower())),
        Field("level", UnitLevel("player")),
        Field("talents", String(talents)),
        Field("professions", "[" .. table.concat(Professions(), ",") .. "]"),
        Field("gear", "{" .. Field("items", "[" .. table.concat(Gear(), ",") .. "]") .. "}"),
        Field("mythicsim", "{" .. table.concat(meta, ",") .. "}"),
        Field("bags", "[" .. table.concat(Bags(), ",") .. "]"),
    }, ",\n") .. "}"
end
