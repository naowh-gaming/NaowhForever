-- Mouse ring sweep handoff between the GCD and a hard cast, in Forever's event order: the GCD
-- starts with UNIT_SPELLCAST_SENT and UNIT_SPELLCAST_START follows a round trip later.
local f = assert(io.open(arg[1] or "QoL/NaowhForever_MouseRing.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()

local GCD_COLOR = { r = 0, g = 0, b = 1 }
local CAST_COLOR = { r = 1, g = 0, b = 0 }

local function Widget(kind, parent)
    local w = { kind = kind, parent = parent, shown = true, scripts = {}, events = {}, textures = {} }
    setmetatable(w, { __index = function(_, k)
        if k:match("^%u") then return function() end end
    end })
    function w:RegisterEvent(e) self.events[e] = true end
    function w:RegisterUnitEvent(e) self.events[e] = true end
    function w:UnregisterAllEvents() self.events = {} end
    function w:SetScript(name, fn) self.scripts[name] = fn end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:SetShown(v) self.shown = v and true or false end
    function w:IsShown() return self.shown end
    function w:GetFrameLevel() return 1 end
    function w:SetVertexColor(r, g, b, a) self.color = { r = r, g = g, b = b, a = a } end
    function w:CreateTexture()
        local t = Widget("Texture", self)
        self.textures[#self.textures + 1] = t
        return t
    end
    function w:CreateMaskTexture() return Widget("MaskTexture", self) end
    return w
end

local function Session(settings)
    local s = { now = 100, timers = {}, frames = {}, gcd = nil, cast = nil, castTimes = {} }
    local values = {
        enabled = true, mouseRing = true, mouseShowOOC = true, mouseGCD = true, mouseCastSwipe = true,
        mouseSwipeDelay = 0, mouseGCDAlpha = 1, mouseOpacityCombat = 1, mouseOpacityOOC = 1,
        mouseSize = 48, mouseShape = "ring.tga", mouseGCDColor = GCD_COLOR, mouseCastColor = CAST_COLOR,
        mouseReadyColor = { r = 0, g = 1, b = 0 }, mouseColor = { r = 1, g = 0.6, b = 0 },
    }
    for k, v in pairs(settings or {}) do values[k] = v end
    local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }
    local page = { Card = function() end }
    local ns = {
        QoLSettings = S, UI = {}, THEME = {},
        Shared = { Settings = { Group = function() return {} end, Page = function() return page end } },
        GCDSpell = function() return 61304 end,
        MeleeRangeSpell = function() return nil end,
        Apply = function() end,
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        UIParent = Widget("Frame"),
        CreateFrame = function(kind, name, parent)
            local w = Widget(kind, parent)
            w.name = name
            s.frames[#s.frames + 1] = w
            return w
        end,
        hooksecurefunc = function(t, name, post)
            local orig = t[name]
            t[name] = function(...) orig(...); post(...) end
        end,
        GetTime = function() return s.now end,
        GetCursorPosition = function() return 0, 0 end,
        IsMouseButtonDown = function() return false end,
        UnitCastingInfo = function()
            if s.cast then return "Cast", nil, nil, s.cast[1] * 1000, s.cast[2] * 1000 end
        end,
        UnitChannelInfo = function() end,
        UnitAffectingCombat = function() return true end,
        IsInInstance = function() return false end,
        UnitIsAFK = function() return false end,
        UnitExists = function() return false end,
        UnitClass = function() return "Paladin", "PALADIN" end,
        RAID_CLASS_COLORS = { PALADIN = { r = 1, g = 0.5, b = 0.7 } },
        C_Spell = {
            GetSpellCooldown = function()
                if s.gcd and s.now < s.gcd[1] + s.gcd[2] then
                    return { startTime = s.gcd[1], duration = s.gcd[2], isOnGCD = true, modRate = 1 }
                end
                return { startTime = 0, duration = 0, isOnGCD = false, modRate = 1 }
            end,
            GetSpellInfo = function(id) return { castTime = s.castTimes[id] or 0 } end,
        },
        C_Timer = {
            NewTimer = function(_, fn)
                local t = { fn = fn }
                function t:Cancel() self.cancelled = true end
                s.timers[#s.timers + 1] = t
                return t
            end,
        },
    }, { __index = _G })
    local chunk
    if setfenv then
        chunk = assert(loadstring(source)); setfenv(chunk, env)
    else
        chunk = assert(load(source, "=MouseRing", "t", env))
    end
    chunk()

    local boot, events
    for _, w in ipairs(s.frames) do
        if w.events.PLAYER_LOGIN then boot = w end
    end
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    for _, w in ipairs(s.frames) do
        if w.events.UNIT_SPELLCAST_START then events = w end
    end
    local container, sweepFrame
    for _, w in ipairs(s.frames) do
        if w.name == "NaowhForeverMouseRing" then container = w end
        if container and w.parent == container then sweepFrame = w end
    end
    local ready = container.textures[3]
    local right = sweepFrame.textures[1]

    function s.Fire(event, ...) events.scripts.OnEvent(events, event, ...) end
    function s.Advance(to)
        s.now = to
        local due = s.timers
        s.timers = {}
        for _, t in ipairs(due) do
            if not t.cancelled then t.fn() end
        end
        sweepFrame.scripts.OnUpdate(sweepFrame)
    end
    -- What the ring shows: the sweep's colour, "ready", or "plain".
    function s.Showing()
        if sweepFrame.shown and right.shown and right.color.a > 0 then
            return right.color.r == 1 and "cast" or "gcd"
        end
        return ready.shown and "ready" or "plain"
    end
    -- A press: the GCD starts with the send, the server's START arrives a round trip later.
    function s.Press(spellID, castTime)
        s.castTimes[spellID] = castTime
        s.Fire("UNIT_SPELLCAST_SENT", "player", "", "guid", spellID)
        s.gcd = s.gcd and s.now < s.gcd[1] + s.gcd[2] and s.gcd or { s.now, 1.5 }
        s.Fire("SPELL_UPDATE_COOLDOWN")
    end
    return s
end

local failures = 0
local function Check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s: showing %s, want %s"):format(label, tostring(got), tostring(want)))
    end
end

do -- The report: a 1 s Holy Light under a 1.5 s GCD never shows the GCD sweep.
    local s = Session()
    s.Press(635, 1000)
    s.Advance(100.01)
    Check("hard cast before START", s.Showing(), "plain")
    s.now = 100.1
    s.cast = { 100.1, 101.1 }
    s.Fire("UNIT_SPELLCAST_START", "player")
    s.Advance(100.11)
    Check("hard cast after START", s.Showing(), "cast")
    s.Advance(100.9)
    Check("hard cast midway", s.Showing(), "cast")
    s.now = 101.1
    s.cast = nil
    s.Fire("UNIT_SPELLCAST_STOP", "player")
    s.Advance(101.11)
    Check("rest of the cast's GCD", s.Showing(), "plain")
    s.Advance(101.6)
    Check("cast's GCD over", s.Showing(), "ready")
end

do -- An instant still sweeps its GCD.
    local s = Session()
    s.Press(20271, 0)
    s.Advance(100.01)
    Check("instant", s.Showing(), "gcd")
    s.Advance(101.6)
    Check("instant's GCD over", s.Showing(), "ready")
end

do -- Cast Sweep off: the GCD sweeps through the cast as before.
    local s = Session({ mouseCastSwipe = false })
    s.Press(635, 1000)
    s.Advance(100.01)
    s.now = 100.1
    s.cast = { 100.1, 101.1 }
    s.Fire("UNIT_SPELLCAST_START", "player")
    s.Advance(100.11)
    Check("cast sweep off", s.Showing(), "gcd")
end

do -- A hard cast queued late in an instant's GCD leaves that GCD's sweep alone.
    local s = Session()
    s.Press(20271, 0)
    s.Advance(101.2)
    s.Press(635, 1000)
    s.Advance(101.25)
    Check("queued cast during instant GCD", s.Showing(), "gcd")
end

do -- A hard cast that fails at once does not hide the next instant's GCD.
    local s = Session()
    s.castTimes[635] = 1000
    s.Fire("UNIT_SPELLCAST_SENT", "player", "", "guid", 635)
    s.Fire("UNIT_SPELLCAST_FAILED", "player")
    s.Advance(100.5)
    s.Press(20271, 0)
    s.Advance(100.51)
    Check("instant after a failed cast", s.Showing(), "gcd")
end

if failures > 0 then os.exit(1) end
print("mouse ring sweep: ok")
