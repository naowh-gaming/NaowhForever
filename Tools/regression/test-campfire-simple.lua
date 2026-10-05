-- Run with Lua 5.1 from the repository root: the campfire reminder's two looks, loaded from the
-- real Shared files, AuraBuffs and Campfire against stubs. Round stays the default and the
-- Simple bar is built only once picked; its bonuses come from the camp features' own auras, as
-- one tidy group with their amounts; the fire sits in a notch of the bar's top edge; the time
-- line runs down on a full track; the down state is a compact pill; resting shows the bonuses
-- to come; the card's preview can be edited with the mouse; and a refresh makes no garbage.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Measure = dofile("Tools/regression/measure.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local CAMP, NEARBY, TENT, KIT, CHAIR, SITTING = 1229741, 1283391, 1229451, 1230124, 1229519, 1229739
local CANDLE = 1229513

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local function Fixture(settings)
    local state = { now = 1000, auras = {}, frames = {}, named = {}, timers = {}, bars = 0, tips = {},
        tooltipReads = 0, secret = false, combat = false, cursorX = 0, cursorY = 0, shift = false, menus = 0 }
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
        SetPoint = function(f, a, _, _, d, e) f.pt[a], f.pty[a] = d or 0, e or 0 end,
        ClearAllPoints = function() end,
        SetShadowColor = function(f, _, _, _, a) f.shadow = a end,
        GetCenter = function(f) return rawget(f, "cx"), rawget(f, "cy") end,
        GetLeft = function(f) return rawget(f, "left") end,
        SetText = function(f, text) f.text = text end,
        GetText = function(f) return rawget(f, "text") or "" end,
        SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
        GetStringWidth = function(f) return #(rawget(f, "text") or "") * 6 end,
        SetFont = function(f, _, size) f.size = size end,
        SetAlpha = function(f, a) f.alpha = a end,
        SetDesaturated = function(f, on) f.desaturated = on end,
        SetVertexColor = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
        SetColorTexture = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
        SetGradient = function(f, _, from, to) f.from, f.to = from, to end,
        SetTexture = function(f, texture) f.texture = texture end,
        Show = function(f) f.shown = true end,
        Hide = function(f) f.shown = false end,
        SetShown = function(f, shown) f.shown = shown and true or false end,
        IsShown = function(f) return rawget(f, "shown") ~= false end,
        IsVisible = function(f) return rawget(f, "shown") ~= false end,
        IsMouseOver = function(f) return rawget(f, "over") == true end,
        EnableMouse = function(f, on) f.mouse = on end,
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
        CreateTexture = function(f) return Frame(f) end,
        CreateMaskTexture = function(f) return Frame(f) end,
        CreateFontString = function(f) return Frame(f) end,
    }
    setmetatable(METHODS, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return NOTHING end
    end })
    local META = { __index = METHODS }
    function Frame(parent, name)
        local f = setmetatable({ scripts = {}, events = {}, parent = parent, pt = {}, pty = {} }, META)
        state.frames[#state.frames + 1] = f
        if name then state.named[name] = f end
        return f
    end

    local COLOR_META = { __index = { SetRGBA = function(c, r, g, b, a) c.r, c.g, c.b, c.a = r, g, b, a end } }
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
    local values, defaults = settings or {}, {}
    local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end,
        Raw = function(k) return values[k] end, Default = function(k) return defaults[k] end }
    local ns = {
        THEME = T,
        Color = function(_, text) return tostring(text) end,
        Font = function(parent, _, flags, color)
            local fs = Frame(parent)
            fs.flags = flags
            local c = color or T.fg
            fs.r, fs.g, fs.b = c.r, c.g, c.b
            return fs
        end,
        Solid = function(parent, _, color) local t = Frame(parent); t.color = color; return t end,
        ThemeTint = function(_, literal) return literal end,
        Hairline = function(region) return region end,
        PixelInset = function(region) return region end,
        OnePixel = function() return 1 end,
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
            ModuleSettings = function(_, given)
                for key, value in pairs(given) do
                    defaults[key] = value
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
        GetCursorPosition = function() return state.cursorX, state.cursorY end,
        IsShiftKeyDown = function() return state.shift end,
        InCombatLockdown = function() return state.combat end,
        IsInInstance = function() return false end,
        issecretvalue = function(v) return state.secret and type(v) == "number" and v == 2 end,
        C_Secrets = { ShouldAurasBeSecret = function() return false end },
        C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return state.auras[id] end },
        C_Spell = { GetSpellTexture = function(id) return id end },
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
        C_Item = {},
        Enum = {
            StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
            StatusBarInterpolation = { Immediate = 0 },
            NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 },
        },
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        MenuUtil = { CreateContextMenu = function(owner, generator)
            state.menus = state.menus + 1
            state.menu = { owner = owner, generator = generator }
        end },
        GameTooltip = tooltip,
        GameTooltip_Hide = NOTHING,
        UIParent = Frame(),
    }, { __index = _G })
    env._G = env
    local files = TocFiles("^Shared/.*%.lua$")
    files[#files + 1] = "AuraBuffs/NaowhForever_AuraBuffs.lua"
    files[#files + 1] = "AuraBuffs/NaowhForever_Campfire.lua"
    Load(files, env)
    state.ns, state.S, state.T, state.values, state.Frame = ns, ns.AuraBuffSettings, T, values, Frame
    state.St = ns.Shared.Style
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
    function state.menuEntries()
        local entries = {}
        local function Root()
            local root = {}
            local function Add(kind)
                return function(_, text) entries[#entries + 1] = kind .. ":" .. text; return Root() end
            end
            root.CreateTitle, root.CreateRadio, root.CreateCheckbox = Add("title"), Add("radio"), Add("check")
            root.CreateButton, root.CreateDivider = Add("button"), function() end
            return root
        end
        state.menu.generator(state.menu.owner, Root())
        return table.concat(entries, "\n")
    end
    return state
end

local function Same(c, want) return c.r == want.r and c.g == want.g and c.b == want.b end
local function Aura(points) return { points = points } end

do
    local s = Fixture()
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = Aura({ 5 }), Aura({ 56 }), Aura({ 2 })
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
    check("Simple: one group, title case, amounts inline, Rested with no number",
        s.labels(bar) == "Rested +56 Sta +2% Crit" and Same(bar.labels.labels[1], s.T.fg))
    local labels, seps = bar.labels.labels, bar.labels.seps
    check("Simple: packed left to right after the fire, a muted dot between",
        labels[1].pt.LEFT == 0 and labels[2].pt.LEFT > labels[1].pt.LEFT and labels[3].pt.LEFT > labels[2].pt.LEFT
        and seps[2].text == s.St.PLACE_DOT and Same(seps[2], s.T.muted) and bar.labels.pt.LEFT == bar.labelX)

    local size = bar.campSize
    check("the fire is seated on the bar's top-left corner, its centre on the top edge",
        size == 24 and bar.campX == bar.radius and bar.camp.pt.CENTER == bar.campX and bar.camp.pty.CENTER == 0
        and bar.cap.shown ~= false)
    local gap = bar.topRight.pt.TOPLEFT - bar.notchFrom
    check("the top border has a gap under the fire, as wide as its outline, from the left edge", gap == size + 2 * 4
        and bar.notchFrom == 0 and bar.topLeft.shown == false and bar.topRight.shown ~= false)
    check("the house backdrop and black edge, no custom alpha", bar.backdrop and rawget(bar, "bg") == nil
        and bar.topRight.color == s.St.BORDER_RGB and s.St.BACKDROP_ALPHA
        and not Read("AuraBuffs/NaowhForever_Campfire.lua"):find("BAR%.ALPHA")
        and not Read("AuraBuffs/NaowhForever_Campfire.lua"):find("SHEEN"))
    check("a thin time-colored ring inside the black edge", bar.timeRing.shown ~= false
        and Same(bar.outerRing, s.St.BORDER_RGB))
    local track
    for _, f in ipairs(s.frames) do if f.parent == bar.line and f.color == s.T.line then track = f end end
    check("the time line runs on a full-width track in the line color", track ~= nil)

    local line = bar.line
    local early = line:GetValue()
    check("the time line runs on its own, counting down what is left",
        line.direction == 1 and math.abs(early - 2400 / 3600) < 1e-6)
    check("the time text is bound to the same timer", line.binding.fontString == bar.time
        and line.binding.enabled == true and bar.time.shown ~= false)
    check("plenty of time: a green line, the time in the text color, no glow",
        Same(line.to, s.St.TIME_OK_RGB) and Same(bar.time, s.T.fg) and bar.halo.shown == false)
    s.advance(700)
    check("the line has shrunk", line:GetValue() < early)
    check("running low: the line and the time in yellow, a soft glow", Same(line.to, s.St.TIME_LOW_RGB)
        and Same(bar.time, s.St.TIME_LOW_RGB) and bar.halo.shown == true)
    s.tips = {}
    bar.scripts.OnEnter(bar)
    local text = s.tipText()
    check("tooltip: each bonus with its amount", text:find("+56 Stamina | First Aid Kit", 1, true)
        and text:find("+2% Critical Strike | Camp Chair", 1, true)
        and text:find("Rested experience | Camp Tent", 1, true))
    check("tooltip: the time left and when to refresh", text:find("Time left | 29 min", 1, true)
        and text:find("Refresh in 24 min", 1, true))
    s.advance(1500)
    check("out: red", Same(line.to, s.St.TIME_OUT_RGB) and Same(bar.time, s.St.TIME_OUT_RGB))
    s.secret = true
    s.fire("UNIT_AURA")
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("a secret amount is never shown or compared", s.labels(bar) == "Rested +56 Sta Crit"
        and s.tipText():find("Critical Strike | Camp Chair", 1, true) and not s.tipText():find("+2%", 1, true))
    s.secret = false
    s.fire("UNIT_AURA")

    s.S.Set("campSimpleHeight", 30)
    gap = bar.topRight.pt.TOPLEFT - bar.notchFrom
    check("the notch follows the fire's size", bar.campSize == 28 and gap == 28 + 2 * 4)
    s.S.Set("campSimpleHeight", 26)

    s.S.Set("campHiddenBonuses", { [CHAIR] = true })
    check("a hidden bonus never draws in game", s.labels(bar) == "Rested +56 Sta")
    s.S.Set("campHiddenBonuses", {})
    s.S.Set("campBonusIcons", true)
    local icons = bar.labels.icons
    check("bonus icons: the feature's own spell icon before each bonus", icons[1].shown ~= false
        and icons[1].texture.texture == TENT and icons[3].texture.texture == CHAIR)
    s.S.Set("campBonusIcons", false)
    check("bonus icons off by default and hidden", icons[1].shown == false)

    s.auras[CANDLE] = Aura({ 25 })
    s.fire("UNIT_AURA")
    check("the default width fits four bonuses", s.labels(bar) == "Rested +56 Sta +25 Int +2% Crit" and bar.more == 0
        and icon.w == 340)
    s.S.Set("campSimpleWidth", 200)
    check("too narrow: the rest as +N more", bar.more > 0 and s.labels(bar):find("+" .. bar.more .. " more$")
        and icon.w == 200)
    s.S.Set("campSimpleWidth", 340)
    s.auras[CANDLE] = nil
    s.fire("UNIT_AURA")

    local editing = 0
    for _, f in ipairs(s.frames) do if f.scripts.OnMouseWheel then editing = editing + 1 end end
    check("nothing on the live HUD takes the wheel or clicks", editing == 0)

    do
        local frame, onEvent = s.listener("UNIT_AURA")
        Measure(check)("a Simple refresh", 1, function() onEvent(frame, "UNIT_AURA") end)
    end

    local fullW = icon.w
    s.auras[CAMP], s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = nil, nil, nil, nil
    s.fire("UNIT_AURA")
    check("down: a compact pill around the fire and the words", bar.pill and icon.w < fullW
        and icon.w == math.ceil(8 + 3 * 2 + bar.pillIcon + 6 + #"Refresh Camp" * 6 + 8))
    check("down: the fire inline at the pill's left, grey in a muted frame, no notch", bar.camp.pt.LEFT == 8 + 3
        and bar.camp.tex.desaturated == true and Same(bar.timeRing, s.T.muted) and bar.cap.shown == false
        and bar.topRight.shown == false and bar.topLeft.shown ~= false)
    check("Simple: no big Camp Nearby alert", s.named.NaowhForeverCampNearby == nil)
    check("down: it reads Refresh Camp, no time line", bar.note.text == "Refresh Camp"
        and bar.line.shown == false and bar.time.shown == false)
    local refreshW = icon.w
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    check("down with a campfire in range: one pattern, the same left edge",
        bar.note.text == "Camp Nearby" .. s.St.PLACE_DOT .. "sit to refresh" and bar.camp.pt.LEFT == 8 + 3
        and icon.w > refreshW and (s.named.NaowhForeverCampNearby == nil or not s.named.NaowhForeverCampNearby.shown))
    s.auras[NEARBY] = nil
    s.fire("UNIT_AURA")

    s.S.Set("campPos", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -40 })
    icon.cx, icon.cy, icon.left = 300, 500, 250
    s.S.Set("campStyle", "round")
    local pos = s.S.Get("campPos")
    check("switching to Round keeps it centred where it was", pos.point == "CENTER" and pos.x == 300 and pos.y == 500)
    check("Round again: the bar hidden, the round art back", bar.shown == false and icon.tex.shown == true
        and icon.label.text == "Refresh Camp")
    check("Round: Refresh Camp in the house text style, a shadow and no outline",
        icon.label.flags == nil and icon.label.shadow == s.St.HUD_SHADOW_ALPHA)
    s.ns.ShowRaidReminderAnchorConfig()
    local alert = s.named.NaowhForeverCampNearby
    check("Camp Nearby in the house text style, in the theme's text color", alert and alert.text.flags == nil
        and alert.text.shadow == s.St.HUD_SHADOW_ALPHA and Same(alert.text, s.T.fg))
    s.ns.HideRaidReminderAnchorConfig()
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    check("Round: the big Camp Nearby alert shows as before", alert.shown == true)
    s.S.Set("campStyle", "simple")
    check("Simple: the big alert hides, the bar's pill covers it", alert.shown == false and bar.pill
        and bar.note.text == "Camp Nearby" .. s.St.PLACE_DOT .. "sit to refresh")
    pos = s.S.Get("campPos")
    check("switching to Simple keeps its left edge where it was", pos.point == "LEFT" and pos.x == 250)
end

do
    local s = Fixture()
    s.S.Set("campStyle", "simple")
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.fire("PLAYER_LOGIN")
    local bar = s.bar()
    check("no feature auras readable: the tooltip's tags, in title case", s.labels(bar) == "Rested"
        and s.tooltipReads > 0)

    s.auras[CAMP] = nil
    s.auras[SITTING] = { duration = 60, expirationTime = s.now + 35 }
    s.auras[TENT], s.auras[CHAIR] = Aura({ 5 }), Aura({ 2 })
    s.fire("UNIT_AURA")
    check("resting: the bonuses to come, from the features' auras", s.labels(bar) == "Rested +2% Crit"
        and bar.note.shown == false)
    check("resting: styled as upcoming, the line in the accent", Same(bar.labels.labels[1], s.T.accentSoft)
        and Same(bar.line.to, s.T.accent))
    check("resting: the countdown reads in 35s", bar.line.binding.formatter.points[1].format == "in %ds")
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("resting tooltip: what you'll get and when", s.tipText():find("You'll get:", 1, true)
        and s.tipText():find("+2% Critical Strike | Camp Chair", 1, true)
        and s.tipText():find("Camp Benefits in 35 sec", 1, true))
    local restingW, restingX = s.named.NaowhForeverCampfire.w, bar.labels.labels[2].pt.LEFT
    s.auras[SITTING] = nil
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 3600, auraInstanceID = 1 }
    s.fire("UNIT_AURA")
    check("landing: the same labels in the normal style, no jump", s.labels(bar) == "Rested +2% Crit"
        and Same(bar.labels.labels[1], s.T.fg) and s.named.NaowhForeverCampfire.w == restingW
        and bar.labels.labels[2].pt.LEFT == restingX)
    check("landing: the countdown drops its prefix", bar.line.binding.formatter.points[1].format == "%ds")

    s.auras[CAMP], s.auras[TENT], s.auras[CHAIR] = nil, nil, nil
    s.auras[SITTING] = { duration = 60, expirationTime = s.now + 35 }
    s.fire("UNIT_AURA")
    check("resting, nothing readable: Resting with the last bonuses greyed", bar.note.text == "Resting"
        and bar.note.shown ~= false and s.labels(bar) == "Rested +2% Crit"
        and Same(bar.labels.labels[1], s.T.muted) and bar.lead > 0)
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
    local f = shot.bar
    check("preview: the Simple bar once picked", s.bars == 1 and shot.barHost.shown ~= false
        and shot.icon.shown == false and Same(f.line.to, s.St.TIME_OUT_RGB))
    check("preview: grouped sample bonuses, four of them", s.labels(f) == "Rested +2% Crit +56 Sta +25 Int"
        and f.more == 0)
    check("preview: not editable while the reminder is off", shot.widthZone.shown == false
        and shot.hint.text:find("Turn on", 1, true))
    s.values.campfire = true
    card.studio.paint(shot, "up")
    check("preview: editable, with its hint", shot.widthZone.shown ~= false
        and shot.hint.text:find("Drag the right edge", 1, true))

    local edge = shot.widthZone
    s.cursorX = 100
    edge.scripts.OnMouseDown(edge, "LeftButton")
    s.cursorX = 130
    edge.scripts.OnUpdate(edge)
    check("drag: the bar grows live", shot.barHost.w == 400)
    edge.scripts.OnMouseUp(edge, "LeftButton")
    check("drag: the right edge sets the width", s.S.Get("campSimpleWidth") == 400)

    local body = shot.zones[1]
    body.scripts.OnMouseWheel(body, 1)
    check("wheel: text size", s.S.Get("campSimpleTextSize") == 13)
    s.shift = true
    body.scripts.OnMouseWheel(body, 1)
    s.shift = false
    check("shift-wheel: bar height", s.S.Get("campSimpleHeight") == 27)

    local crit = shot.bonusZones[2]
    crit.over = true
    crit.scripts.OnMouseUp(crit, "LeftButton")
    card.studio.paint(shot, "up")
    check("click a bonus: hidden, and dimmed in the preview", s.S.Get("campHiddenBonuses")[CHAIR] == true
        and f.labels.labels[2].alpha < 1 and f.labels.labels[1].alpha == 1)
    crit.scripts.OnMouseUp(crit, "LeftButton")
    check("click it again: shown", s.S.Get("campHiddenBonuses")[CHAIR] == nil)

    shot.timeZone.over = true
    shot.timeZone.scripts.OnMouseUp(shot.timeZone, "LeftButton")
    check("click the time: Show Camp Timer off", s.S.Get("campTimer") == false)

    body.over = true
    body.scripts.OnMouseUp(body, "RightButton")
    local entries = s.menuEntries()
    check("right-click: the house menu with the bar's choices", s.menus == 1
        and entries:find("radio:Round", 1, true) and entries:find("radio:Simple", 1, true)
        and entries:find("check:Bonus Icons", 1, true) and entries:find("check:Show Timer", 1, true)
        and entries:find("button:Bonuses", 1, true) and entries:find("button:Reset Bar", 1, true))

    local left = shot.barHost.pt.LEFT
    card.studio.paint(shot, "sitting")
    local sittingLeft = shot.barHost.pt.LEFT
    check("preview Resting: upcoming bonuses", Same(f.labels.labels[1], s.T.accentSoft) and f.note.shown == false)
    card.studio.paint(shot, "nearby")
    check("preview Camp Nearby: the pill, one pattern", f.pill
        and f.note.text == "Camp Nearby" .. s.St.PLACE_DOT .. "sit to refresh"
        and shot.widthZone.shown == false)
    card.studio.paint(shot, "missing")
    check("preview Refresh: the pill", f.pill and f.note.text == "Refresh Camp")
    check("preview: every state starts at the same left edge", sittingLeft == left
        and shot.barHost.pt.LEFT == left and f.camp.pt.LEFT == 8 + 3)
end

print(checks .. " campfire look checks passed")
