-- Run with Lua 5.1 from the repository root: Completo's Rares. A rare friendly to your faction
-- is not yours; a zone counts the ones you killed; a targeted rare dying counts once when it was
-- yours and not when someone else tapped it; a looted corpse counts; Shift-click ticks one off.
-- Rare Alerts: a rare's nameplate brings the alert and a skull, once per rare in a while; not
-- for a dead or friendly one, nor one you killed unless Killed Rares Too; no skull where it has
-- a mark or in a raid without lead or assist; nothing is registered while it is off.

local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local function Strsplit(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
    return unpack(out)
end

local function Region()
    local r = { shown = true, text = "" }
    function r:SetText(t) self.text = t or "" end
    function r:GetStringWidth() return #self.text * 7 end
    function r:GetStringHeight() return 14 end
    function r:SetShown(on) self.shown = on and true or false end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    for _, k in ipairs({ "SetPoint", "SetJustifyH", "SetSize", "SetMovable", "SetClampedToScreen",
        "EnableMouse", "SetScript", "ClearAllPoints" }) do
        r[k] = r[k] or function() end
    end
    return r
end

local function Fixture(settings, units)
    local env = { pairs = pairs, ipairs = ipairs, type = type, math = math, table = table, select = select,
        tostring = tostring, tonumber = tonumber, string = string, wipe = function(t)
            for k in pairs(t) do t[k] = nil end
            return t
        end }
    env.strsplit = Strsplit
    local now = 1000
    env.time = function() return now end
    env.GetTime = function() return now end
    env.Advance = function(s) now = now + s end
    local frames = {}
    env.CreateFrame = function()
        local f = Region()
        f.events, f.unitEvents = {}, {}
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterUnitEvent(e, unit) self.events[e] = true; self.unitEvents[e] = unit end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(k, fn) self[k] = fn end
        f.CreateAnimationGroup = function()
            local none = function() end
            local g = { playing = false, SetLooping = none, SetScript = none }
            g.Play = function(group) group.playing = true end
            g.Stop = function(group) group.playing = false end
            g.CreateAnimation = function()
                return { SetFromAlpha = none, SetToAlpha = none, SetDuration = none }
            end
            return g
        end
        frames[#frames + 1] = f
        return f
    end
    -- Every frame listening for the event hears it.
    env.Fire = function(event, ...)
        for _, f in ipairs(frames) do
            if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
        end
    end
    env.Listening = function(event)
        for _, f in ipairs(frames) do
            if f.events[event] then return true end
        end
        return false
    end
    env.hooksecurefunc = function(t, key, fn)
        local orig = t[key]
        t[key] = function(...) orig(...); fn(...) end
    end
    env.UnitName = function(unit) return units[unit] and units[unit].name or "Grim" end
    env.GetRealmName = function() return "Realm" end
    env.UnitFactionGroup = function() return "Horde" end
    env.UnitGUID = function(unit) return units[unit] and units[unit].guid end
    env.UnitExists = function(unit) return units[unit] ~= nil end
    env.UnitIsDead = function(unit) return units[unit] and units[unit].dead or false end
    env.UnitIsTapDenied = function(unit) return units[unit] and units[unit].denied or false end
    env.UnitClassification = function(unit) return units[unit] and units[unit].kind or "normal" end
    env.UnitCanAttack = function(_, unit) return not (units[unit] and units[unit].friend) end
    env.UnitLevel = function(unit) return units[unit] and units[unit].level or 20 end
    env.IsInGroup = function() return units.group ~= nil end
    env.IsInRaid = function() return units.group == "raid" end
    env.UnitIsGroupLeader = function() return false end
    env.UnitIsGroupAssistant = function() return false end
    env.marks = {}
    env.GetRaidTargetIndex = function(unit) return units[unit] and units[unit].mark end
    env.SetRaidTarget = function(unit, index)
        env.marks[#env.marks + 1] = { unit, index }
        units[unit].mark = index
    end
    env.loot = {}
    env.GetNumLootItems = function() return #env.loot end
    env.GetLootSourceInfo = function(slot) return env.loot[slot], 1 end
    env.sounds = 0
    env.PlaySound = function() env.sounds = env.sounds + 1 end
    env.SOUNDKIT = { RAID_WARNING = 8959 }
    env.C_Timer = { NewTimer = function() return { Cancel = function() end } end }
    env.C_Map = { GetBestMapForUnit = function() return 1440 end, GetMapInfo = function() end }
    local account = {}
    local ns = { THEME = { accent = {}, muted = {} }, Apply = function() end,
        ShowRaidReminderAnchorConfig = function() end, HideRaidReminderAnchorConfig = function() end }
    ns.AccountSettings = function() return account end
    ns.Font = function() return Region() end
    ns.AlertStack = function(frame) ns.alert = frame end
    ns.UI = { SoundPathFor = function() return nil end, _PlayLSMSound = function() end }
    ns.CompletoSettings = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end }
    ns.Completo = {}
    -- Ashenvale: Mist Howler; Darkslayer Mordenthal, friendly to the Horde; Ursol'lok.
    ns.CompletoRareData = {
        Zones = { { map = 1440, name = "Ashenvale", continent = 1, rares = { 10644, 3736, 12037 } } },
        Rares = {
            [3736] = { "Darkslayer Mordenthal", 23, 23, 0, -1, 1, 1440, { 60.0, 70.0 } },
            [10644] = { "Mist Howler", 22, 22, 0, -1, -1, 1440, { 50.0, 40.0, 52.0, 44.0 } },
            [12037] = { "Ursol'lok", 31, 31, 0, -1, -1, 1440, {} },
        },
    }
    env.NaowhForever = ns
    env._G = env
    Load({ "NaowhForever_Completo/NaowhForever_CompletoRares.lua",
        "NaowhForever_Completo/NaowhForever_CompletoRareAlert.lua" }, env)
    env.Fire("PLAYER_LOGIN")
    return ns, env, account
end

local function Guid(npc, spawn) return ("Creature-0-1-2-3-%d-%s"):format(npc, spawn or "0001") end

-- Kills
do
    local units = {}
    local ns, env, account = Fixture({ enabled = true }, units)
    local R = ns.Completo.Rares
    local zone = R.Zones()[1]
    Check(R.NpcOf(Guid(10644)) == 10644, "the npcID comes from the GUID")
    Check(R.NpcOf("Player-1-0001") == nil, "a player is no creature")
    Check(not R.Mine(3736) and R.Mine(10644), "a rare friendly to the Horde is not a Horde rare")
    local n, total, low, high = R.ZoneProgress(zone)
    Check(n == 0 and total == 2 and low == 22 and high == 31, "the zone counts its two rares for the Horde")

    units.target = { guid = Guid(10644), name = "Mist Howler" }
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(env.Listening("UNIT_HEALTH"), "a targeted rare is watched")
    units.target.dead = true
    env.Fire("UNIT_HEALTH", "target")
    Check(R.Killed(10644) and R.Record(10644).n == 1, "the targeted rare dying counts")
    Check(not env.Listening("UNIT_HEALTH"), "a dead rare is no longer watched")
    env.loot = { Guid(10644) }
    env.Fire("LOOT_READY")
    Check(R.Record(10644).n == 1, "looting the same corpse does not count it again")
    Check(account.completoRareKills["Grim-Realm"][10644] ~= nil, "kills are kept per character")

    units.target = { guid = Guid(10644, "0002"), name = "Mist Howler" }
    env.Fire("PLAYER_TARGET_CHANGED")
    units.target.dead, units.target.denied = true, true
    env.Fire("UNIT_HEALTH", "target")
    Check(R.Record(10644).n == 1, "a rare someone else tapped does not count")

    env.loot = { Guid(12037) }
    env.Fire("LOOT_READY")
    Check(R.Killed(12037), "a looted rare counts")
    Check(select(1, R.ZoneProgress(zone)) == 2, "the zone counts both kills")

    local heard = 0
    R.OnChange(function() heard = heard + 1 end)
    R.SetKilled(12037, false)
    Check(not R.Killed(12037) and heard == 1, "Shift-click unticks a rare, and says so")
    R.SetKilled(12037, true)
    Check(R.Killed(12037) and R.Record(12037).n == 0, "ticked off by hand: killed, no kill counted")

    local found, count = R.Search("howl", 10)
    Check(count == 1 and found[1].ids[1] == 10644, "the search finds a rare by name")
    Check(R.CurrentZone() == zone, "the zone you are in")
    local map, x, y = R.Spot(10644)
    Check(map == 1440 and x == 50 and y == 40, "the waypoint goes to its first spot off its map")
end

-- Rare Alerts
do
    local units = {}
    local settings = { enabled = true, rareAlert = false, rareMark = true, rareSound = true,
        rareAlertKilled = false }
    local ns, env = Fixture(settings, units)
    local R = ns.Completo.Rares
    Check(not env.Listening("NAME_PLATE_UNIT_ADDED"), "nothing is registered while Rare Alerts is off")
    ns.CompletoSettings.Set("rareAlert", true)
    Check(env.Listening("NAME_PLATE_UNIT_ADDED"), "on: nameplates are watched")

    units.nameplate1 = { guid = Guid(10644), name = "Mist Howler", kind = "rare", level = 22 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(ns.alert and ns.alert:IsShown(), "a rare's nameplate brings the alert")
    Check(ns.alert.text.text:find("Mist Howler", 1, true), "the alert names it")
    Check(ns.alert.note.text == "Not killed yet", "and says it is not killed yet")
    Check(#env.marks == 1 and env.marks[1][2] == 8, "a skull goes on it")
    Check(env.sounds == 1, "a sound plays")

    ns.alert:Hide()
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(not ns.alert:IsShown() and #env.marks == 1, "its nameplate coming back does not alert or mark again")
    env.Advance(301)
    units.nameplate1.mark = 2
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(ns.alert:IsShown() and #env.marks == 1, "a while later it alerts again, the mark left alone")

    R.SetKilled(10644, true)
    Check(not ns.alert:IsShown(), "the alert goes once its rare is killed")

    units.nameplate2 = { guid = Guid(10644, "0003"), name = "Mist Howler", kind = "rare", level = 22 }
    env.Advance(301)
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Check(not ns.alert:IsShown(), "a rare you killed does not alert")
    Check(#env.marks == 2, "but it still gets a skull")
    settings.rareAlertKilled = true
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Check(ns.alert:IsShown() and ns.alert.note.text == "Killed before", "with Killed Rares Too it does")

    ns.alert:Hide()
    units.nameplate3 = { guid = Guid(5555), name = "Not A Rare", kind = "normal" }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    units.nameplate4 = { guid = Guid(6666), name = "Dead Rare", kind = "rareelite", dead = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    units.nameplate5 = { guid = Guid(7777), name = "Friendly Rare", kind = "rare", friend = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
    Check(not ns.alert:IsShown(), "no alert for a normal mob, a dead rare or a friendly one")

    units.group = "raid"
    units.target = { guid = Guid(8888), name = "Raid Rare", kind = "rareelite", level = 40 }
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(ns.alert:IsShown() and ns.alert.note.text == "", "a rare not in the data alerts too, without a kill note")
    Check(#env.marks == 2, "in a raid without lead or assist, no skull")

    ns.CompletoSettings.Set("rareAlert", false)
    Check(not env.Listening("NAME_PLATE_UNIT_ADDED") and not ns.alert:IsShown(), "switched off: unregistered, alert gone")
end

print(("test-completo-rares: %d checks passed"):format(checks))
