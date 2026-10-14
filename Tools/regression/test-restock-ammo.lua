-- Run with Lua 5.1 from the repository root: the Restock Reminder's Hunter Ammo option reads the
-- equipped ammo against its own warning amount, and only for a hunter with the option on.
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Loot/Restock.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

local ARROWS = 2512
local function Fixture(class, settings, have, wanted)
    local env = {
        PLAYER_CLASS = class, AMMO_SLOT = 0, TEXT_SHORT = "%s  %d / %d",
        S = { Get = function(key) return settings[key] end },
        ItemName = function(id) return "item" .. id end,
        Wanted = function() return wanted or {} end,
        GetInventoryItemID = function()
            assert(class == "HUNTER" and settings.restockHunterAmmo, "inactive ammo must not be read")
            return ARROWS
        end,
        C_Item = { GetItemCount = function() return have end },
    }
    setmetatable(env, { __index = _G })
    local code = Slice("local function HunterAmmoOn()", "\nlocal function ItemName(")
        .. Slice("local function ReagentLines(", "\nlocal function BagLines(")
        .. "\nreturn ReagentLines, HunterAmmoLines"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    local Reagents, Ammo = chunk()
    local lines = {}
    Reagents(lines)
    Ammo(lines)
    return table.concat(lines, "|")
end
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("every class can configure the localized Hunter-only reminder", function()
    for _, class in ipairs({ "HUNTER", "WARRIOR", "ROGUE", "MAGE", "PRIEST", "WARLOCK",
        "PALADIN", "SHAMAN", "DRUID" }) do
        local env = {
            ns = { L = function(text) return "localized:" .. text end },
            Group = function(title) return { group = title } end,
            AMMO_RANGE = { 50, 4000, 50 },
            restockRows = {}, seenReagents = {}, FIXED = {}, FAMILIES = {}, LOOK = {},
            UnitClass = function() return class, class end,
            wipe = function(t) for key in pairs(t) do t[key] = nil end end,
        }
        setmetatable(env, { __index = _G })
        local code = Slice("local HUNTER = {", "\nlocal CARRY_GROUP =")
            .. Slice("local function RestockRows()", "\nlocal function RestockSummary(")
            .. "\nreturn RestockRows()"
        local chunk = assert(loadstring(code)); setfenv(chunk, env)
        local rows = chunk()
        assert(rows[1].group == "localized:Hunter Ammo (Hunters only)", class)
        assert(rows[2].key == "restockHunterAmmo" and rows[2].toggle, class)
        assert(rows[3].key == "restockHunterAmmoBelow" and rows[3].slider == env.AMMO_RANGE, class)
        assert(rows[3].needs == "restockHunterAmmo", class)
    end
end)
Case("ammo inventory events are registered only for an enabled Hunter reminder", function()
    for _, class in ipairs({ "HUNTER", "WARRIOR" }) do
        for _, on in ipairs({ true, false }) do
            for _, restock in ipairs({ true, false }) do
                local registered, unitRegistered = {}, {}
                local settings = { enabled = true, restock = restock, restockHunterAmmo = on }
                local env = {
                    PLAYER_CLASS = class, TARGETS = {}, pendingItems = {}, DRINK_ITEM = 159,
                    S = { Get = function(key) return settings[key] end },
                    On = function() return settings.restock end,
                    HideAlert = function() end, Check = function() end, IsResting = function() return false end,
                    C_Item = { RequestLoadItemDataByID = function() end },
                    events = {
                        UnregisterAllEvents = function() end,
                        RegisterEvent = function(_, event) registered[event] = true end,
                        RegisterUnitEvent = function(_, event, unit) unitRegistered[event] = unit end,
                    },
                }
                setmetatable(env, { __index = _G })
                local code = Slice("local function HunterAmmoOn()", "\nlocal function ItemName(")
                    .. Slice("local function Apply()", "\nlocal function ShowSample()") .. "\nApply()"
                local chunk = assert(loadstring(code)); setfenv(chunk, env); chunk()
                local expected = class == "HUNTER" and on and restock
                assert(unitRegistered.UNIT_INVENTORY_CHANGED == (expected and "player" or nil))
                if not restock then assert(next(registered) == nil and next(unitRegistered) == nil) end
            end
        end
    end
end)

local ON = { restockHunterAmmo = true, restockHunterAmmoBelow = 500 }
Case("at or below its own amount, the equipped ammo is reminded", function()
    assert(Fixture("HUNTER", ON, 500) == "item2512  500 / 500")
    assert(Fixture("HUNTER", ON, 120) == "item2512  120 / 500")
end)
Case("above its own amount, nothing", function()
    assert(Fixture("HUNTER", ON, 501) == "")
end)
Case("it replaces the carry target for that ammo, not for other reagents", function()
    local wanted = { [ARROWS] = 1000, [999] = 20 }
    assert(Fixture("HUNTER", ON, 600, wanted) == "")
    assert(Fixture("HUNTER", { restockHunterAmmo = false }, 600, wanted) == "item2512  600 / 1000")
end)
Case("off, or not a hunter, adds nothing", function()
    assert(Fixture("HUNTER", { restockHunterAmmo = false, restockHunterAmmoBelow = 500 }, 10) == "")
    assert(Fixture("WARRIOR", ON, 10) == "")
end)
print(count .. " restock ammo regressions passed")
