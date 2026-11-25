-- UnitNames.lua: the Names Over Heads card, the guild, title and pet names shown over units, in the game's own settings.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Settings = ns.Shared.Settings

local ON, OFF = "1", "0"
local KEPT = "unitNames"
local SUMMARY = ns.L("%d of %d shown")
local NAMES = {
    { cvar = "UnitNamePlayerPVPTitle", label = "Player Titles", help = "Titles like Private or Scout with player names." },
    { cvar = "UnitNamePlayerGuild", label = "Guild Names", help = "The guild name under a player's name." },
    { cvar = "UnitNameGuildTitle", label = "Guild Titles", help = "The player's guild rank beside their guild name." },
    { cvar = "UnitNameFriendlyPetName", label = "Friendly Pets", help = "Names over friendly players' pets.", keep = true },
    { cvar = "UnitNameFriendlyGuardianName", label = "Friendly Guardians", help = "Names over guardians friendly players summon.", keep = true },
    { cvar = "UnitNameFriendlyTotemName", label = "Friendly Totems", help = "Names over friendly players' totems.", keep = true },
    { cvar = "UnitNameEnemyPetName", label = "Enemy Pets", help = "Names over enemy players' pets.", keep = true },
    { cvar = "UnitNameEnemyGuardianName", label = "Enemy Guardians", help = "Names over guardians enemy players summon.", keep = true },
    { cvar = "UnitNameEnemyTotemName", label = "Enemy Totems", help = "Names over enemy players' totems.", keep = true },
}

local rows = {}
local restored

local function Exists(name)
    return C_CVar.GetCVar(name.cvar) ~= nil
end

local function Kept()
    local account = ns.AccountSettings()
    if type(account[KEPT]) ~= "table" then account[KEPT] = {} end
    return account[KEPT]
end

local function Row(name)
    return { label = name.label, toggle = true, help = name.help,
        get = function() return C_CVar.GetCVarBool(name.cvar) end,
        set = function(on)
            local value = on and ON or OFF
            C_CVar.SetCVar(name.cvar, value)
            if name.keep then Kept()[name.cvar] = value end
        end }
end

local function Rows()
    wipe(rows)
    for _, name in ipairs(NAMES) do
        if Exists(name) then
            name.row = name.row or Row(name)
            rows[#rows + 1] = name.row
        end
    end
    return rows
end

local function Summary()
    local shown, total = 0, 0
    for _, name in ipairs(NAMES) do
        if Exists(name) then
            total = total + 1
            if C_CVar.GetCVarBool(name.cvar) then shown = shown + 1 end
        end
    end
    return SUMMARY:format(shown, total)
end

local function PutBack()
    if restored then return end
    restored = true
    local kept = ns.AccountSettings()[KEPT]
    if not kept then return end
    for cvar, value in pairs(kept) do
        local current = C_CVar.GetCVar(cvar)
        if current ~= nil and current ~= value then C_CVar.SetCVar(cvar, value) end
    end
end

ns.OnApply(PutBack)

Settings.Page("QoL/Interface", S):Card({
    id = "unitNames", name = "Names Over Heads", order = 25,
    help = "Which titles, guilds and pet names show over players' heads.",
    summary = Summary,
    rows = Rows,
})
