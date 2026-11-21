-- Offline checks for the trinket rules (NaowhForever_Combat/GearSets/Trinkets.lua): each slot's queue, best first,
-- and the trinket-ready alert.
-- Run from the repo root: lua Tools/regression/test-trinket-queue.lua

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local TOP, BOTTOM = 13, 14
local EARTHSTRIKE, BADGE, CARROT = 21180, 21670, 11122

local function Fixture()
    local g = {
        now = 1000, combat = false, dead = false, casting = false, secret = false, auras = {},
        worn = {}, bags = {}, cooldowns = {}, slotCooldowns = {}, equips = {}, printed = {}, played = {},
        timers = {}, account = {}, frames = {},
        settings = { gearSets = true, trinketQueue = false, trinketReady = false, trinketReadySound = "none" },
    }
    local S = { Get = function(k) return g.settings[k] end }
    function S.Set(k, v) g.settings[k] = v end
    local ns = {
        QoLSettings = S, L = function(s) return s end,
        Print = function(s) g.printed[#g.printed + 1] = s end,
        AccountSettings = function() return g.account end,
        CharKey = function() return "Me-Realm" end,
        OnApply = function() end,
        UI = { SoundPathFor = function(key) return key ~= "none" and key or nil end,
            _PlayLSMSound = function(path) if path then g.played[#g.played + 1] = path end end },
        GearSets = { C = { TRINKET_SLOTS = { TOP, BOTTOM } }, On = function() return g.settings.gearSets end },
    }
    local function Timer(delay, fn)
        local t = { at = g.now + delay, fn = fn }
        function t.Cancel() t.cancelled = true end
        g.timers[#g.timers + 1] = t
        return t
    end
    local function Frame()
        local f = { events = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(_, fn) self.onEvent = fn end
        g.frames[#g.frames + 1] = f
        return f
    end
    local bagList = {}
    local env = setmetatable({
        _G = { NaowhForever = ns },
        BACKPACK_CONTAINER = 0, NUM_BAG_SLOTS = 0,
        CreateFrame = Frame,
        hooksecurefunc = function(t, key, fn)
            local orig = t[key]
            t[key] = function(...) orig(...); fn(...) end
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        GetTime = function() return g.now end,
        InCombatLockdown = function() return g.combat end,
        UnitIsDeadOrGhost = function() return g.dead end,
        UnitCastingInfo = function() return g.casting or nil end,
        UnitChannelInfo = function() return nil end,
        GetCursorInfo = function() return nil end,
        IsInventoryItemLocked = function() return false end,
        GetInventoryItemID = function(_, slot) return g.worn[slot] end,
        GetInventoryItemLink = function(_, slot) return "[" .. tostring(g.worn[slot]) .. "]" end,
        GetInventoryItemCooldown = function(_, slot)
            local cd = g.slotCooldowns[slot]
            if cd then return cd[1], cd[2], 1 end
            return 0, 0, 1
        end,
        C_Timer = { NewTimer = Timer },
        C_Secrets = { ShouldAurasBeSecret = function() return g.secret end },
        C_UnitAuras = { GetAuraDataBySpellName = function(unit, name, filter)
            assert(not g.secret, "an aura read while auras are secret")
            assert(unit == "player" and filter == "HELPFUL")
            return g.auras[name]
        end },
        C_Item = {
            GetItemSpell = function(id) return "Use " .. id, id + 1 end,
            EquipItemByName = function(id, slot)
                assert(not g.combat, "a trinket swapped in combat")
                g.equips[#g.equips + 1] = { id, slot }
                g.bags[id], g.worn[slot] = nil, id
            end,
        },
        C_Container = {
            GetItemCooldown = function(id)
                local cd = g.cooldowns[id]
                if cd then return cd[1], cd[2], 1 end
                return 0, 0, 1
            end,
            GetContainerNumSlots = function()
                for k in pairs(bagList) do bagList[k] = nil end
                for id in pairs(g.bags) do bagList[#bagList + 1] = id end
                return #bagList
            end,
            GetContainerItemID = function(_, slot) return bagList[slot] end,
        },
    }, { __index = _G })
    local chunk = assert(loadfile("NaowhForever_Combat/GearSets/Trinkets.lua"))
    setfenv(chunk, env)
    chunk()
    g.Q = ns.GearSets.Trinkets
    function g.Set(k, v) S.Set(k, v) end
    function g.fire(event, arg)
        for _, f in ipairs(g.frames) do
            if f.events[event] and f.onEvent then f.onEvent(f, event, arg) end
        end
    end
    function g.advance(seconds)
        g.now = g.now + seconds
        local fired = true
        while fired do
            fired = false
            for _, t in ipairs(g.timers) do
                if not t.cancelled and not t.done and t.at <= g.now then
                    t.done, fired = true, true
                    t.fn(t)
                end
            end
        end
    end
    function g.listening()
        for _, f in ipairs(g.frames) do
            if next(f.events) and not f.events.PLAYER_LOGIN then return true end
        end
        return false
    end
    g.fire("PLAYER_LOGIN")
    return g
end

do
    local g = Fixture()
    check("off: no events of its own", not g.listening())
    g.worn[TOP] = EARTHSTRIKE
    g.bags[BADGE] = true
    g.Q.Toggle(TOP, EARTHSTRIKE)
    g.Q.Toggle(TOP, BADGE)
    check("queued trinkets keep their order", g.Q.Rank(TOP, EARTHSTRIKE) == 1 and g.Q.Rank(TOP, BADGE) == 2)
    check("queueing with the queue off swaps nothing", #g.equips == 0)
    g.Set("trinketQueue", true)
    check("on: it listens", g.listening())
    check("the best one is worn and ready, so nothing moves", #g.equips == 0)
    g.cooldowns[EARTHSTRIKE] = { g.now, 120 }
    g.fire("BAG_UPDATE_COOLDOWN")
    check("used: the next ready one goes on", g.equips[1][1] == BADGE)
    g.Set("trinketQueue", false)
    check("off again: it stops listening", not g.listening())
end

do
    local g = Fixture()
    g.settings.trinketQueue = true
    g.worn[TOP], g.bags[BADGE] = EARTHSTRIKE, true
    g.Q.Toggle(TOP, EARTHSTRIKE)
    g.Q.Toggle(TOP, BADGE)
    g.cooldowns[EARTHSTRIKE] = { g.now, 120 }
    g.auras["Use " .. EARTHSTRIKE] = { expirationTime = g.now + 20 }
    g.fire("PLAYER_LOGIN")
    check("its buff still up: it waits", #g.equips == 0)
    g.auras["Use " .. EARTHSTRIKE] = nil
    g.advance(20)
    check("buff gone and on cooldown: the next ready one goes on", g.equips[1][1] == BADGE and g.equips[1][2] == TOP)
    g.bags[EARTHSTRIKE] = true
    g.cooldowns[BADGE] = { g.now, 120 }
    g.fire("BAG_UPDATE_COOLDOWN")
    check("the first one is not ready yet, so the badge stays", #g.equips == 1)
    g.advance(70)
    check("30 seconds before the first is ready it goes back on", g.equips[2][1] == EARTHSTRIKE)
end

do
    local g = Fixture()
    g.settings.trinketQueue = true
    g.worn[TOP] = CARROT
    g.bags[BADGE] = true
    g.Q.Toggle(TOP, BADGE)
    g.fire("PLAYER_LOGIN")
    check("a trinket not in the queue is left on", #g.equips == 0)
    g.worn[TOP] = nil
    g.bags[CARROT] = true
    g.fire("PLAYER_EQUIPMENT_CHANGED", TOP)
    check("an empty slot takes the first ready one", g.equips[1][1] == BADGE)
end

do
    local g = Fixture()
    g.settings.trinketQueue = true
    g.bags[BADGE] = true
    g.Q.Toggle(TOP, BADGE)
    g.Q.Toggle(BOTTOM, BADGE)
    g.fire("PLAYER_LOGIN")
    check("one trinket goes into one slot only", #g.equips == 1 and g.equips[1][2] == TOP)
end

do
    local g = Fixture()
    g.settings.trinketQueue = true
    g.bags[BADGE] = true
    g.combat = true
    g.Q.Toggle(TOP, BADGE)
    g.fire("PLAYER_LOGIN")
    g.fire("BAG_UPDATE_COOLDOWN")
    check("nothing moves in combat", #g.equips == 0)
    g.combat, g.casting = false, true
    g.fire("PLAYER_REGEN_ENABLED")
    check("nor while casting", #g.equips == 0)
    g.casting = false
    g.advance(1)
    check("it tries again when the cast is done", #g.equips == 1)
    g.Q.Toggle(TOP, BADGE)
    check("taking it out of the queue", g.Q.Rank(TOP, BADGE) == nil)
end

do
    local g = Fixture()
    g.settings.trinketQueue = true
    g.worn[TOP], g.bags[BADGE] = EARTHSTRIKE, true
    g.Q.Toggle(TOP, EARTHSTRIKE)
    g.Q.Toggle(TOP, BADGE)
    g.cooldowns[EARTHSTRIKE] = { g.now, 120 }
    g.secret = true
    g.fire("PLAYER_LOGIN")
    check("auras secret: no aura read and no swap", #g.equips == 0)
end

do
    local g = Fixture()
    g.settings.trinketReady, g.settings.trinketReadySound = true, "ding"
    g.worn[TOP] = EARTHSTRIKE
    g.fire("PLAYER_LOGIN")
    g.slotCooldowns[TOP] = { g.now, 120 }
    g.fire("BAG_UPDATE_COOLDOWN")
    g.advance(119)
    check("not ready yet: no word", #g.printed == 0)
    g.advance(1)
    check("ready: it says so in chat", g.printed[1] == "[21180] is ready." and #g.printed == 1)
    check("and plays the sound", g.played[1] == "ding")
    g.slotCooldowns[TOP] = { g.now, 1.5 }
    g.fire("BAG_UPDATE_COOLDOWN")
    g.advance(2)
    check("the global cooldown alone says nothing", #g.printed == 1)
    g.slotCooldowns[TOP] = { g.now, 60 }
    g.fire("BAG_UPDATE_COOLDOWN")
    g.worn[TOP] = BADGE
    g.slotCooldowns[TOP] = nil
    g.fire("PLAYER_EQUIPMENT_CHANGED", TOP)
    g.advance(60)
    check("a trinket swapped off before it is ready says nothing", #g.printed == 1)
    g.Set("trinketReady", false)
    check("alert off: it stops listening", not g.listening())
end

print(("PASS trinket queue: %d checks"):format(checks))
