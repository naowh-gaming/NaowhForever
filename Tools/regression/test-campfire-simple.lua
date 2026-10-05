-- Run with Lua 5.1 from the repository root: the campfire reminder's two looks, loaded from the
-- real Shared files, AuraBuffs and Campfire against stubs. Round stays the default and the
-- Simple bar is built only once picked; its bonuses come from the camp features' own auras;
-- its time line runs down and steps green, yellow, red; it reads Refresh Camp when the camp is
-- gone; its tooltip lists each bonus, the time left and when to refresh; switching looks keeps
-- its place; and a refresh makes no garbage.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Measure = dofile("Tools/regression/measure.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local CAMP, NEARBY, TENT, KIT, CHAIR = 1229741, 1283391, 1229451, 1230124, 1229519

local function Fixture(settings)
    local state = { now = 1000, auras = {}, frames = {}, named = {}, timers = {}, bars = 0, tips = {},
        tooltipReads = 0, secret = false, combat = false }
    local NOTHING = function() end
    local Frame
    local METHODS = {
        SetScript = function(f, script, fn) f.scripts[script] = fn end,
        GetScript = function(f, script) return f.scripts[script] end,
        HookScript = function(f, script, fn) f.scripts[script] = fn end,
        RegisterEvent = function(f, event) f.events[event] = true end,
        RegisterUnitEvent = function(f, event) f.events[event] = true end,
        UnregisterEvent = function(f, event) f.events[event] = nil end,
        UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
        GetParent = function(f) return rawget(f, "parent") end,
        SetWidth = function(f, w) f.w = w end,
        SetHeight = function(f, h) f.h = h end,
        SetSize = function(f, w, h) f.w, f.h = w, h end,
        GetWidth = function(f) return rawget(f, "w") or 600 end,
        GetHeight = function(f) return rawget(f, "h") or 230 end,
        SetPoint = function(f, a, b, c, d, e) f.p1, f.p2, f.p3, f.p4, f.p5 = a, b, c, d, e end,
        GetCenter = function(f) return rawget(f, "cx"), rawget(f, "cy") end,
        SetText = function(f, text) f.text = text end,
        GetText = function(f) return rawget(f, "text") or "" end,
        SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
        GetStringWidth = function(f) return #(rawget(f, "text") or "") * 6 end,
        SetAlpha = function(f, a) f.alpha = a end,
        SetDesaturated = function(f, on) f.desaturated = on end,
        SetVertexColor = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
        SetGradient = function(f, _, from, to) f.from, f.to = from, to end,
        Show = function(f) f.shown = true end,
        Hide = function(f) f.shown = false end,
        SetShown = function(f, shown) f.shown = shown and true or false end,
        IsShown = function(f) return rawget(f, "shown") ~= false end,
        IsVisible = function(f) return rawget(f, "shown") ~= false end,
        IsMouseOver = function() return false end,
        GetFrameLevel = function(f) return rawget(f, "level") or 1 end,
        SetFrameLevel = function(f, level) f.level = level end,
        GetEffectiveScale = function() return 1 end,
        SetValue = function(f, v) f.value = v end,
        SetTimerDuration = function(f, dur, _, direction) f.dur, f.direction = dur, direction end,
        GetValue = function(f)
            local dur = rawget(f, "dur")
            if not dur then return rawget(f, "value") or 0 end
            local left = math.max(0, dur.start + dur.length - state.now) / dur.length
            return f.direction == 1 and left or 1 - left
        end,
        GetStatusBarTexture = function(f)
            local fill = rawget(f, "fill")
            if not fill then fill = Frame(f); f.fill = fill end
            return fill
        end,
        ClearAllPoints = function() end,
        EnableMouse = function() end,
        CreateTexture = function(f) return Frame(f) end,
        CreateMaskTexture = function(f) return Frame(f) end,
        CreateFontString = function(f) return Frame(f) end,
    }
    setmetatable(METHODS, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return NOTHING end
    end })
    local META = { __index = METHODS }
    function Frame(parent, name)
        local f = setmetatable({ scripts = {}, events = {}, parent = parent }, META)
        state.frames[#state.frames + 1] = f
        if name then state.named[name] = f end
        return f
    end

    local COLOR = { SetRGBA = function(c, r, g, b, a) c.r, c.g, c.b, c.a = r, g, b, a end }
    local COLOR_META = { __index = COLOR }
    local DURATION_META = { __index = { SetTimeFromStart = function(d, start, length)
        d.start, d.length = start, length
    end } }
    local BINDING_META = { __index = function(_, key)
        if key == "SetFontString" then return function(b, fs) b.fontString = fs end end
        if key == "SetEnabled" then return function(b, on) b.enabled = on end end
        if key == "SetFormatter" then return function(b, fmt) b.formatter = fmt end end
        return NOTHING
    end }

    local T = { fg = { r = 0.9, g = 0.9, b = 0.9 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
        accent = { r = 0, g = 0.5, b = 0.9 }, accentSoft = { r = 0.3, g = 0.7, b = 0.9 },
        line = { r = 0.2, g = 0.2, b = 0.2 }, panel = { r = 0.1, g = 0.1, b = 0.1 },
        bg = { r = 0.05, g = 0.05, b = 0.05 }, grey = { r = 0.2, g = 0.2, b = 0.2 } }
    local values = settings or {}
    local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }
    local ns = {
        THEME = T,
        Color = function(_, text) return tostring(text) end,
        Font = function(parent, _, _, color)
            local fs = Frame(parent)
            local c = color or T.fg
            fs.r, fs.g, fs.b = c.r, c.g, c.b
            return fs
        end,
        Solid = function(parent, _, color) local t = Frame(parent); t.color = color; return t end,
        ThemeTint = function(_, literal) return literal end,
        Hairline = function(region) return region end,
        PixelInset = function(region) return region end,
        Border = function(frame) return { _frame = Frame(frame), SetColor = NOTHING } end,
        AccentBorder = function() return { SetColor = NOTHING } end,
        Button = function(parent) return Frame(parent) end,
        UIFontPath = function() return "font" end,
        AccountSettings = function() return {} end,
        Apply = NOTHING, ShowRaidReminderAnchorConfig = NOTHING, HideRaidReminderAnchorConfig = NOTHING,
        UI = {
            Keep = function(parent, key, make)
                local kept = rawget(parent, key)
                if not kept then kept = make(parent); parent[key] = kept end
                return kept
            end,
            AttachMover = function(frame) return Frame(frame) end,
            ModuleSettings = function(_, defaults)
                for key, value in pairs(defaults) do
                    if values[key] == nil then values[key] = value end
                end
                return S
            end,
            _PlayLSMSound = NOTHING, SoundPathFor = NOTHING,
        },
    }
    local tooltip = Frame()
    tooltip.SetOwner = function(_, owner) state.tips = { owner = owner } end
    tooltip.SetText = function(_, text) state.tips[#state.tips + 1] = { text } end
    tooltip.AddLine = function(_, text) state.tips[#state.tips + 1] = { text } end
    tooltip.AddDoubleLine = function(_, left, right) state.tips[#state.tips + 1] = { left, right } end
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function(kind, name, parent)
            if kind == "StatusBar" then state.bars = state.bars + 1 end
            return Frame(parent, name)
        end,
        Mixin = function(target, ...)
            for i = 1, select("#", ...) do
                for k, v in pairs((select(i, ...))) do target[k] = v end
            end
            return target
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        hooksecurefunc = function(t, key, callback)
            local orig = t[key]; t[key] = function(...) orig(...); callback(...) end
        end,
        CreateColor = function(r, g, b, a) return setmetatable({ r = r, g = g, b = b, a = a }, COLOR_META) end,
        GetTime = function() return state.now end,
        InCombatLockdown = function() return state.combat end,
        IsInInstance = function() return false end,
        issecretvalue = function(v) return state.secret and type(v) == "number" and v == 2 end,
        C_Secrets = { ShouldAurasBeSecret = function() return false end },
        C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return state.auras[id] end },
        C_TooltipInfo = { GetUnitBuffByAuraInstanceID = function()
            state.tooltipReads = state.tooltipReads + 1
            return { lines = { { leftText = "Camp Benefits" }, { leftText = "Camp Tent: Rested XP" } } }
        end },
        C_Timer = { After = function(delay, fn)
            state.timers[#state.timers + 1] = { at = state.now + delay, fn = fn }
        end },
        C_DurationUtil = {
            CreateDuration = function() return setmetatable({}, DURATION_META) end,
            CreateDurationTextBinding = function() return setmetatable({}, BINDING_META) end,
        },
        C_StringUtil = { CreateNumericRuleFormatter = function()
            return { SetBreakpoints = function(fmt, points) fmt.points = points end }
        end },
        Enum = {
            StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
            StatusBarInterpolation = { Immediate = 0 },
            NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 },
        },
        C_Item = {},
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        GameTooltip = tooltip,
        GameTooltip_Hide = NOTHING,
        UIParent = Frame(),
    }, { __index = _G })
    env._G = env
    local files = TocFiles("^Shared/.*%.lua$")
    files[#files + 1] = "AuraBuffs/NaowhForever_AuraBuffs.lua"
    files[#files + 1] = "AuraBuffs/NaowhForever_Campfire.lua"
    Load(files, env)
    state.ns, state.S, state.T, state.values = ns, ns.AuraBuffSettings, T, values
    state.Frame = Frame
    function state.fire(event)
        for i = 1, #state.frames do
            local f = state.frames[i]
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
        end
    end
    function state.listener(event)
        for i = 1, #state.frames do
            local f = state.frames[i]
            if f.events[event] and f.scripts.OnEvent then return f, f.scripts.OnEvent end
        end
    end
    function state.advance(seconds)
        state.now = state.now + seconds
        local due = true
        while due do
            due = false
            for i, t in ipairs(state.timers) do
                if t.at <= state.now then
                    table.remove(state.timers, i)
                    t.fn()
                    due = true
                    break
                end
            end
        end
    end
    function state.bar()
        for i = 1, #state.frames do
            local f = state.frames[i]
            if rawget(f, "line") and rawget(f, "labels") and f.parent == state.named.NaowhForeverCampfire then
                return f
            end
        end
    end
    function state.labels(bar)
        local out = {}
        for i = 1, bar.labels.count do out[i] = bar.labels.labels[i].text end
        return table.concat(out, " ")
    end
    function state.tipText()
        local out = {}
        for i, line in ipairs(state.tips) do out[i] = line[1] .. (line[2] and " | " .. line[2] or "") end
        return table.concat(out, "\n")
    end
    return state
end

local function Same(c, want) return c.r == want.r and c.g == want.g and c.b == want.b end

do
    local s = Fixture()
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.auras[TENT] = { points = { 5 } }
    s.auras[KIT] = { points = { 56 } }
    s.auras[CHAIR] = { points = { 2 } }
    s.fire("PLAYER_LOGIN")
    local icon = s.named.NaowhForeverCampfire
    check("the default look is Round", s.S.Get("campStyle") == "round")
    check("Round: no Simple bar built", s.bars == 0 and s.bar() == nil)
    check("Round: the camp icon shows its bonuses, from the features' auras",
        icon.shown and icon.buffs.text == "+Rested\n+STA\n+Crit" and s.tooltipReads == 0)

    do
        local frame, onEvent = s.listener("UNIT_AURA")
        Measure(check)("a Round refresh", 1, function() onEvent(frame, "UNIT_AURA") end)
    end

    s.S.Set("campStyle", "simple")
    local bar = s.bar()
    check("Simple: built once picked, with one time line", bar ~= nil and s.bars == 1)
    check("Simple: the round art hidden, the bar shown", icon.tex.shown == false and icon.timer.shown == false
        and bar.shown ~= false)
    check("Simple: the bonuses listed in a row, in the theme's text colour",
        s.labels(bar) == "+Rested +STA +Crit" and Same(bar.labels.labels[1], s.T.fg))
    local labels = bar.labels.labels
    check("Simple: spread evenly", labels[1].p4
        and math.abs((labels[2].p4 - labels[1].p4) - (labels[3].p4 - labels[2].p4)) < 1e-9)

    local line = bar.line
    local early = line:GetValue()
    check("the time line runs on its own, counting down what is left",
        line.direction == 1 and math.abs(early - 2400 / 3600) < 1e-6)
    check("the time text is bound to the same timer", line.binding.fontString == bar.time
        and line.binding.enabled == true and bar.time.shown ~= false)
    check("green with most of the hour left", Same(line.to, s.ns.Shared.Style.TIME_OK_RGB))
    s.advance(700)
    check("the line has shrunk", line:GetValue() < early)
    check("yellow under 30 minutes", Same(line.to, s.ns.Shared.Style.TIME_LOW_RGB))
    s.tips = {}
    bar.scripts.OnEnter(bar)
    local text = s.tipText()
    check("tooltip: each bonus with its amount", text:find("+56 Stamina | First Aid Kit", 1, true)
        and text:find("+2% Critical Strike | Camp Chair", 1, true)
        and text:find("Rested experience | Camp Tent", 1, true))
    check("tooltip: the time left and when to refresh", text:find("Time left | 29 min", 1, true)
        and text:find("Refresh in 24 min", 1, true))
    s.advance(1500)
    check("red under 5 minutes", Same(line.to, s.ns.Shared.Style.TIME_OUT_RGB))
    s.auras[NEARBY] = {}
    s.tips = {}
    bar.scripts.OnEnter(bar)
    text = s.tipText()
    check("tooltip: refresh now once red, and a campfire in range",
        text:find("Refresh now", 1, true) and text:find("A campfire is in range", 1, true))
    s.auras[NEARBY] = nil
    s.secret = true
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("tooltip: a secret amount is never shown or compared", s.tipText():find("Critical Strike | Camp Chair", 1, true)
        and not s.tipText():find("+2%", 1, true))
    s.secret = false

    do
        local frame, onEvent = s.listener("UNIT_AURA")
        Measure(check)("a Simple refresh", 1, function() onEvent(frame, "UNIT_AURA") end)
    end

    s.auras[CAMP], s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = nil, nil, nil, nil
    s.fire("UNIT_AURA")
    check("down: it reads Refresh Camp", bar.note.text == "Refresh Camp" and bar.note.shown ~= false)
    check("down: the bonuses greyed out, the bar dimmed, the fire grey",
        Same(bar.labels.labels[1], s.T.muted) and bar.bg.alpha < 1 and bar.camp.tex.desaturated == true)
    check("down: no time line", bar.line.shown == false and bar.time.shown == false)
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("down: the tooltip says to refresh now", s.tipText():find("Refresh now", 1, true))

    s.S.Set("campPos", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -40 })
    icon.cx, icon.cy = 300, 500
    s.S.Set("campStyle", "round")
    local pos = s.S.Get("campPos")
    check("switching looks keeps it centred where it was", pos.point == "CENTER" and pos.x == 300 and pos.y == 500)
    check("Round again: the bar hidden, the round art back", bar.shown == false and icon.tex.shown == true
        and icon.label.text == "Refresh Camp")
end

do
    local s = Fixture()
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.S.Set("campStyle", "simple")
    s.fire("PLAYER_LOGIN")
    local bar = s.bar()
    check("no feature auras readable: the tooltip's tags instead", s.labels(bar) == "+Rested" and s.tooltipReads > 0)
    s.auras[CAMP] = nil
    s.auras[1229739] = { duration = 60, expirationTime = s.now + 35 }
    s.fire("UNIT_AURA")
    check("sitting: Resting, with the line in the accent", bar.note.text == "Resting"
        and Same(bar.line.to, s.T.accent) and bar.line.shown ~= false)
end

do
    local s = Fixture({ campfire = false })
    s.fire("PLAYER_LOGIN")
    check("off: nothing built, nothing listened to", s.named.NaowhForeverCampfire == nil and s.bars == 0)
    local listening = false
    for _, f in ipairs(s.frames) do if f.events.UNIT_AURA then listening = true end end
    check("off: no aura events", not listening)

    local card = s.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.campfire
    local shot = card.studio.new(s.Frame())
    card.studio.paint(shot, "up")
    check("preview: Round by default, no bar", s.bars == 0 and shot.icon.shown ~= false)
    s.values.campStyle = "simple"
    card.studio.paint(shot, "low")
    check("preview: the Simple bar once picked", s.bars == 1 and shot.barHost.shown ~= false
        and shot.icon.shown == false and Same(shot.bar.line.to, s.ns.Shared.Style.TIME_OUT_RGB))
    card.studio.paint(shot, "missing")
    check("preview: Refresh Camp", shot.bar.note.text == "Refresh Camp")
end

print(checks .. " campfire look checks passed")
