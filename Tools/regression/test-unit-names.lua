-- The Names Over Heads card (NaowhForever_QoL/Interface/UnitNames.lua) against a fake of the game's settings.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end
local source = Read("NaowhForever_QoL/Interface/UnitNames.lua")

local function Load(cvars, account)
    local card, apply
    account = account or {}
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = {}, Shared = { Settings = {
        Page = function() return { Card = function(_, c) card = c end } end,
    } } }
    ns.AccountSettings = function() return account end
    ns.OnApply = function(fn) apply = fn end
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_CVar = {
            GetCVar = function(name) return cvars[name] end,
            GetCVarBool = function(name) return cvars[name] == "1" end,
            SetCVar = function(name, value) cvars[name] = value end,
        },
    }, { __index = _G })
    local chunk = assert(loadstring(source, "UnitNames"))
    setfenv(chunk, env)
    chunk()
    return card, apply
end

local function Row(card, label)
    for _, row in ipairs(card.rows()) do
        if row.label == label then return row end
    end
end

local count = 0
local function Case(name, fn) fn(); count = count + 1 end

Case("a setting the client lacks gets no row", function()
    local card = Load({ UnitNamePlayerGuild = "1", UnitNamePlayerPVPTitle = "0" })
    local rows = card.rows()
    assert(#rows == 2 and rows[1].label == "Player Titles" and rows[2].label == "Guild Names", #rows)
    assert(card.summary() == "1 of 2 shown", card.summary())
end)
Case("a row reads and writes the game's setting", function()
    local cvars = { UnitNamePlayerGuild = "1", UnitNameGuildTitle = "1", UnitNamePlayerPVPTitle = "1" }
    local card = Load(cvars)
    local guild = card.rows()[2]
    assert(guild.get() == true)
    guild.set(false)
    assert(cvars.UnitNamePlayerGuild == "0" and guild.get() == false)
    guild.set(true)
    assert(cvars.UnitNamePlayerGuild == "1")
    assert(card.rows()[2] == guild, "the same row each time the page draws")
end)

Case("a guild row keeps nothing of its own", function()
    local account = {}
    local card = Load({ UnitNamePlayerGuild = "1" }, account)
    Row(card, "Guild Names").set(false)
    assert(account.unitNames == nil)
end)
Case("a totem row is kept and put back after the game turns it on again", function()
    local cvars = { UnitNameFriendlyTotemName = "1", UnitNameFriendlyGuardianName = "1", UnitNameEnemyPetName = "1" }
    local account = {}
    local card, apply = Load(cvars, account)
    Row(card, "Friendly Totems").set(false)
    Row(card, "Friendly Guardians").set(false)
    assert(account.unitNames.UnitNameFriendlyTotemName == "0" and account.unitNames.UnitNameFriendlyGuardianName == "0")
    cvars.UnitNameFriendlyTotemName, cvars.UnitNameFriendlyGuardianName = "1", "1"
    apply()
    assert(cvars.UnitNameFriendlyTotemName == "0" and cvars.UnitNameFriendlyGuardianName == "0")
    assert(cvars.UnitNameEnemyPetName == "1", "an untouched row stays the game's")
    assert(card.summary() == "1 of 3 shown", card.summary())
end)
Case("nothing changed, nothing put back", function()
    local set = 0
    local game = { UnitNameFriendlyTotemName = "0" }
    local cvars = setmetatable({}, { __index = game, __newindex = function(_, k, v) set = set + 1; game[k] = v end })
    local _, apply = Load(cvars, { unitNames = { UnitNameFriendlyTotemName = "0" } })
    apply()
    assert(set == 0)
end)

Case("put back once a session, so a later change elsewhere stands", function()
    local cvars = { UnitNameFriendlyTotemName = "1" }
    local _, apply = Load(cvars, { unitNames = { UnitNameFriendlyTotemName = "0" } })
    apply()
    assert(cvars.UnitNameFriendlyTotemName == "0")
    cvars.UnitNameFriendlyTotemName = "1"
    apply()
    assert(cvars.UnitNameFriendlyTotemName == "1")
end)
Case("a kept setting the client lacks is left alone", function()
    local cvars = {}
    local _, apply = Load(cvars, { unitNames = { UnitNameEnemyGuardianName = "0" } })
    apply()
    assert(cvars.UnitNameEnemyGuardianName == nil)
end)

print("test-unit-names: " .. count .. " cases passed")
