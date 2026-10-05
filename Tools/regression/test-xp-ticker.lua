-- Run with Lua 5.1 from the repository root: the XP Ticker's card. The real Core, Shared style,
-- parts and window parts and the ticker's own file are loaded against stubs, and the ticker and
-- its settings preview are checked: the card (theme background, black border), the header's
-- kicker, rate and Paused tag, the two-column rows, the icon buttons in the header shown on
-- hover, Background off giving outlined text alone, the font settings, the preview's states and
-- edits, theme colors, the saved place, and no garbage or text work on an unchanged update.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local Frame
local created = {}
local textsSet = 0
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    HookScript = function(f, script, fn) f.hooks[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    GetWidth = function(f) return rawget(f, "w") or 100 end,
    GetHeight = function(f) return rawget(f, "h") or 40 end,
    SetPoint = function(f, p1, p2, p3, p4, p5) f.p1, f.p2, f.p3, f.p4, f.p5 = p1, p2, p3, p4, p5 end,
    SetFont = function(f, path, size, flags) f.font, f.size, f.flags = path, size, flags end,
    SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
    SetColorTexture = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
    SetTexture = function(f, tex) f.tex = tex end,
    SetShadowColor = function(f, r, g, b, a) f.shadow = { r, g, b, a } end,
    SetShadowOffset = function(f, x, y) f.offset = { x, y } end,
    SetText = function(f, text) f.text = text; textsSet = textsSet + 1 end,
    GetText = function(f) return rawget(f, "text") or "" end,
    GetStringWidth = function(f) return #(rawget(f, "text") or "") * (rawget(f, "size") or 12) * 0.5 end,
    GetStringHeight = function(f) return rawget(f, "size") or 12 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return f.shown ~= false end,
    EnableMouse = function(f, on) f.mouse = on end,
    EnableMouseWheel = function(f, on) f.wheel = on end,
    IsMouseOver = function(f) return f.over == true end,
    GetFrameLevel = function() return 1 end,
    GetEffectiveScale = function() return 1 end,
    GetParent = function(f) return f.parent end,
    GetObjectType = function(f) return f.kind or "Frame" end,
    CreateFontString = function(f) return Frame(f, nil, "FontString") end,
    CreateTexture = function(f) return Frame(f, nil, "Texture") end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent, name, kind)
    local f = setmetatable({ scripts = {}, hooks = {}, events = {}, parent = parent, name = name, kind = kind }, META)
    created[#created + 1] = f
    return f
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local now = 1000
local tick
local menu

local function Boot(account, settings)
    for i = #created, 1, -1 do created[i] = nil end
    now, tick, menu = 1000, nil, nil
    local env = {
        CreateFrame = function(_, name, parent) return Frame(parent, name) end,
        NaowhForeverDB = { account = account or {}, profiles = {}, charActive = {} },
        STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF",
        UIParent = Frame(),
        PixelUtil = { GetPixelToUIUnitFactor = function() return 1 end },
        GetTime = function() return now end,
        UnitLevel = function() return 20 end,
        UnitXP = function() return 500 end,
        UnitXPMax = function() return 1000 end,
        UnitName = function() return "Die" end,
        GetRealmName = function() return "Realm" end,
        GetMaxLevelForPlayerExpansion = function() return 60 end,
        IsXPUserDisabled = function() return false end,
        IsResting = function() return false end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_Timer = { After = NOTHING, NewTicker = function(_, fn) tick = fn; return { Cancel = NOTHING } end },
        MenuUtil = { CreateContextMenu = function(owner, gen) menu = { owner = owner, gen = gen } end },
        hooksecurefunc = function(t, k, fn)
            local old = t[k]
            t[k] = function(...) local r = old(...); fn(...); return r end
        end,
    }
    env._G = env
    setmetatable(env, { __index = _G })
    local core = assert(loadstring(Read("Core/NaowhForever_Core.lua"), "Core"))
    setfenv(core, env)
    core("NaowhForever")
    local ns = env.NaowhForever
    ns.ApplyThemeColors()
    Load({ "Shared/Shared.lua", "Shared/Style.lua", "Shared/Parts.lua", "Shared/Window.lua" }, env)

    local defaults = { enabled = true, xpTicker = true, xpTickerLevel = true, xpTickerElapsed = true,
        xpTickerHideResting = false, xpTickerFont = "", xpTickerFontSize = 24, xpTickerOutline = false,
        xpTickerSplits = true, xpTickerHistoryCount = 10, xpTickerBackground = true }
    local db = settings or {}
    ns.QoLSettings = {
        Get = function(k) if db[k] == nil then return defaults[k] end return db[k] end,
        Set = function(k, v) db[k] = v end,
    }
    ns.UI = { FontPath = function(name) return name ~= "" and "font:" .. name or "naowh" end,
        AttachMover = function(parent) return Frame(parent) end }
    ns.Apply, ns.ResetXPBarSession = NOTHING, NOTHING
    ns.ShowRaidReminderAnchorConfig, ns.HideRaidReminderAnchorConfig = NOTHING, NOTHING
    local card
    ns.Shared.Settings = { Group = function(name) return { group = name } end,
        Page = function() return { Card = function(_, c) card = c end } end }
    local first = #created + 1
    Load({ "QoL/NaowhForever_XPTicker.lua" }, env)

    for i = first, #created do
        local f = created[i]
        if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
    end
    local ticker
    for _, f in ipairs(created) do
        if f.name == "NaowhForeverXPTicker" then ticker = f end
    end
    return { ns = ns, S = ns.QoLSettings, ticker = ticker, card = card, T = ns.THEME }
end

local St
local function Shadowed(fs)
    return fs.offset[1] == St.HUD_SHADOW_X and fs.offset[2] == St.HUD_SHADOW_Y
        and fs.shadow[1] == St.HUD_SHADOW_RGB.r and fs.shadow[4] == St.HUD_SHADOW_ALPHA
end
local function Plain(fs) return fs.flags == "" and Shadowed(fs) end
local function Outlined(fs) return fs.flags == "OUTLINE" and fs.offset[1] == 0 and fs.shadow[4] == 0 end
local function Is(fs, c) return fs.r == c.r and fs.g == c.g and fs.b == c.b end
local function All(t, test)
    for _, fs in ipairs(t.texts) do
        if not test(fs) then return false end
    end
    return true
end

do
    local s = Boot()
    local ns, t, T = s.ns, s.ticker, s.T
    St = ns.Shared.Style
    check("the ticker is built on login", t and t.shown)
    check("the card is the theme's background", t.bg.shown and Is(t.bg, T.bg))
    check("at the card alpha the Flight Timer uses", t.bg.a == St.HUD_CARD_ALPHA and St.HUD_CARD_ALPHA == 0.85
        and Read("QoL/NaowhForever_Flight.lua"):find("CARD_ALPHA = 380, 10, 6, St.HUD_CARD_ALPHA", 1, true))
    check("with the black border", t.border._frame.shown ~= false)

    check("the kicker reads XP / HOUR", t.kicker.text == "XP / HOUR")
    check("the kicker in the accent, small", Is(t.kicker, T.accentSoft) and t.kicker.size == 10)
    check("the kicker at the card's top left", t.kicker.p1 == "TOPLEFT" and t.kicker.p2 == 8 and t.kicker.p3 == -8)
    check("the rate big, in the text color", Is(t.rate, T.fg) and t.rate.size == 24 and t.rate.text == "0")
    check("the rate under the kicker", t.rate.p1 == "TOPLEFT" and t.rate.p2 == t.kicker and t.rate.p3 == "BOTTOMLEFT")
    check("no Paused tag while running", t.tag.shown == false and t.tag.text == "PAUSED" and Is(t.tag, T.muted))

    check("Ding and Time rows", t.ding.label.text == "Ding" and t.time.label.text == "Time"
        and t.ding.on and t.time.on)
    check("labels muted on the left", Is(t.ding.label, T.muted) and t.ding.label.p1 == "TOPLEFT"
        and t.ding.label.p4 == 8)
    check("values in the text color on the right", Is(t.ding.value, T.fg) and t.ding.value.p1 == "TOPRIGHT"
        and t.ding.value.p4 == -8)
    check("a label and its value share a line", t.ding.label.p5 == t.ding.value.p5
        and t.time.label.p5 == t.time.value.p5)
    check("Time under Ding", t.time.label.p5 < t.ding.label.p5)
    check("no ding yet", t.ding.value.text == "--")
    check("the session time", t.time.value.text == "0:00")
    check("rows smaller than the rate", t.ding.label.size == 14 and t.ding.value.size == 14)
    check("no history rows without completed levels", not t.history[1].on)

    check("the text has no outline, the soft shadow", All(t, Plain))
    check("no hand-written color codes", not Read("QoL/NaowhForever_XPTicker.lua"):find("|cff", 1, true))

    local c = t.controls
    check("the buttons sit in the card's header", c.parent == t and c.p1 == "TOPRIGHT" and c.p2 < 0 and c.p3 < 0)
    check("two icon buttons: pause and reset", t.toggle.parent == c and t.reset.parent == c
        and t.toggle.icon.tex == St.PAUSE and t.reset.icon.tex == St.RESET)
    check("with tooltips", t.toggle.tip == "Pause" and t.toggle.hint and t.reset.tip == "Reset" and t.reset.hint)
    check("house icons", St.PLAY:find("Media\\play$") and St.PAUSE:find("Media\\pause$")
        and St.RESET:find("Media\\reset$"))
    for _, file in ipairs({ "play", "pause", "reset" }) do
        local f = io.open("Media/" .. file .. ".tga", "rb")
        check(file .. " icon exists", f)
        f:close()
    end
    check("hidden until hovered", c.shown == false)
    check("no button outside the card", t.w >= c.w - c.p2 + 8 and t.h >= c.h - c.p3)
    t.scripts.OnEnter(t)
    check("shown on hover", c.shown)
    t.over = true
    t.scripts.OnLeave(t)
    check("still shown moving onto a button", c.shown)
    t.over = false
    t.toggle.hooks.OnLeave(t.toggle)
    check("hidden once the mouse leaves the card", c.shown == false)

    t.toggle.scripts.OnClick(t.toggle)
    check("the pause button pauses", t.tag.shown and t.toggle.icon.tex == St.PLAY and t.toggle.tip == "Start")
    t.toggle.scripts.OnClick(t.toggle)
    check("and starts again", t.tag.shown == false and t.toggle.icon.tex == St.PAUSE)
    ns.XPTickerCommand("pause")
    check("/naowh xp pause still works", t.tag.shown)
    ns.XPTickerCommand("start")
    check("/naowh xp start still works", t.tag.shown == false)
    now = now + 125
    tick()
    check("the clock runs", t.time.value.text == "2:05")
    t.reset.scripts.OnClick(t.reset)
    check("the reset button starts the session again", t.time.value.text == "0:00")
    now = now + 30
    tick()
    ns.XPTickerCommand("reset")
    check("/naowh xp reset still works", t.time.value.text == "0:00")

    s.S.Set("xpTickerFont", "Expressway")
    s.S.Set("xpTickerFontSize", 12)
    check("a picked font and size apply", t.rate.font == "font:Expressway" and t.rate.size == 12)
    check("the kicker and rows follow", t.kicker.font == "font:Expressway" and t.kicker.size == 9
        and t.ding.value.size == 10 and t.ding.label.font == "font:Expressway")
    local small = t.w
    s.S.Set("xpTickerFontSize", 32)
    check("the card is sized from the font size", t.w > small and t.rate.size == 32 and t.ding.value.size == 19)
    check("still no outline", All(t, Plain))

    s.S.Set("xpTickerOutline", true)
    check("Outlined Text outlines the card's text", All(t, Outlined) and t.bg.shown)
    s.S.Set("xpTickerOutline", false)
    check("turning it off brings the shadow back", All(t, Plain))

    s.S.Set("xpTickerBackground", false)
    check("Background off: no card", t.bg.shown == false and t.border._frame.shown == false)
    check("and the text outlined", All(t, Outlined))
    s.S.Set("xpTickerBackground", true)
    check("Background on: the card is back", t.bg.shown and t.border._frame.shown and All(t, Plain))

    local timeAt = t.time.label.p5
    s.S.Set("xpTickerLevel", false)
    check("Show Ding Time off hides its row", not t.ding.on and t.ding.label.shown == false)
    check("Time moves up", t.time.on and t.time.label.p5 > timeAt)
    s.S.Set("xpTickerLevel", true)

    local rows, labels = {}, {}
    for _, r in ipairs(s.card.rows) do
        if r.key then rows[r.key] = r end
        if r.label then labels[r.label] = r end
    end
    local bg, outline = rows.xpTickerBackground, rows.xpTickerOutline
    check("Background is a toggle on the card", bg and bg.toggle and bg.label == "Background")
    check("Outlined Text is kept", outline and outline.toggle and outline.label == "Outlined Text")
    for _, r in ipairs({ bg, outline }) do
        check(r.label .. ": one short sentence", r.help and #r.help < 100 and not r.help:find("%. %u"))
    end
    local qol = Read("QoL/NaowhForever_QoL.lua")
    check("Background on by default", qol:find("xpTickerBackground = true", 1, true))
    check("Outlined Text off by default", qol:find("xpTickerOutline = false", 1, true))
    check("the Color spelling in player text", not Read("QoL/NaowhForever_XPTicker.lua"):find("[Cc]olour"))
    check("Reset XP per Hour is still on the card", labels["Reset XP per Hour"])
end

do
    local splits = { ["Die-Realm"] = { current = { level = 20, base = 0 },
        levels = { [19] = { total = 2391 }, [18] = { total = 2248 }, [17] = {} } } }
    local s = Boot({ levelSplits = splits })
    local t = s.ticker
    check("completed levels as rows, newest first", t.history[1].on and t.history[1].label.text == "Level 19"
        and t.history[2].label.text == "Level 18" and not t.history[3].on)
    check("their times on the right", t.history[1].value.text == "39:51" and t.history[1].value.p1 == "TOPRIGHT")
    check("history a little smaller", t.history[1].label.size == 12 and t.history[1].label.size < t.time.label.size)
    check("under the session rows", t.history[1].label.p5 < t.time.label.p5)
    s.S.Set("xpTickerHistoryCount", 1)
    check("Levels Shown caps them", t.history[1].on and not t.history[2].on)

    local before = textsSet
    tick()
    tick()
    check("an unchanged update sets no text", textsSet == before)
    now = now + 1
    tick()
    check("a new second sets one text, the clock", textsSet == before + 1)
    for _ = 1, 50 do tick() end
    collectgarbage("collect")
    collectgarbage("stop")
    local mem = collectgarbage("count")
    for _ = 1, 2000 do tick() end
    local grown = collectgarbage("count") - mem
    collectgarbage("restart")
    check(("no garbage per update (%.3f KB over 2000)"):format(grown), grown < 0.05)
end

do
    local s = Boot()
    local studio, T = s.card.studio, s.T
    local keys = {}
    for _, state in ipairs(studio.states) do keys[#keys + 1] = state.key end
    check("preview states: Levelling, Paused, Resting", table.concat(keys, ",") == "levelling,paused,resting")
    local preview = studio.new(Frame())
    local p = preview.ticker
    studio.paint(preview, "levelling")
    check("the preview draws the card", p.bg.shown and Is(p.bg, T.bg) and p.bg.a == St.HUD_CARD_ALPHA)
    check("levelling: the rate and rows", p.rate.text == "48.2k" and p.ding.value.text == "23 mins"
        and p.time.value.text == "1:12:40" and p.tag.shown == false)
    check("levelling: sample history", p.history[1].label.text == "Level 22" and p.history[5].on)
    check("the preview's buttons do nothing", p.toggle.mouse == false and p.reset.mouse == false)
    studio.paint(preview, "paused")
    check("paused: the tag and the play icon", p.tag.shown and p.toggle.icon.tex == St.PLAY)
    studio.paint(preview, "resting")
    check("resting: shown while Hide While Resting is off", p.shown ~= false and preview.note.text == "")
    s.S.Set("xpTickerHideResting", true)
    studio.paint(preview, "resting")
    check("resting: hidden with a note when it is on", p.shown == false and preview.note.text ~= "")
    s.S.Set("xpTickerHideResting", false)
    studio.paint(preview, "levelling")
    check("the preview has the hint", preview.hint.text:find("Wheel", 1, true))

    p.scripts.OnMouseWheel(p, 1)
    check("the wheel makes the text bigger", s.S.Get("xpTickerFontSize") == 25)
    p.scripts.OnMouseWheel(p, -1)
    check("and smaller", s.S.Get("xpTickerFontSize") == 24)
    local dingHit
    for _, hit in ipairs(preview.hits) do
        if hit.row == p.ding then dingHit = hit end
    end
    check("a row can be clicked", dingHit and dingHit.shown and dingHit.key == "xpTickerLevel")
    dingHit.over = true
    dingHit.scripts.OnMouseUp(dingHit, "LeftButton")
    check("clicking Ding hides it", s.S.Get("xpTickerLevel") == false)
    studio.paint(preview, "levelling")
    check("and the preview drops it", not p.ding.on and dingHit.shown == false)
    p.scripts.OnMouseUp(p, "RightButton")
    check("right-click opens a menu", menu and menu.owner == p)
    local items = {}
    local root = {
        CreateTitle = NOTHING, CreateDivider = NOTHING,
        CreateCheckbox = function(_, label, _, set, data) items[label] = { set = set, data = data } end,
        CreateButton = function(_, label, fn) items[label] = { fn = fn } end,
    }
    menu.gen(p, root)
    check("the menu has Background, Outlined Text and Reset", items.Background and items["Outlined Text"]
        and items["Reset XP per Hour"] and items["Show Ding Time"])
    items["Show Ding Time"].set(items["Show Ding Time"].data)
    check("and turns rows back on", s.S.Get("xpTickerLevel") == true)
    items.Background.set(items.Background.data)
    studio.paint(preview, "levelling")
    check("Background off in the preview too", p.bg.shown == false and All(p, Outlined))

    s.S.Set("xpTicker", false)
    studio.paint(preview, "levelling")
    check("no edits while it is off", not preview.editable and not preview.hint.text:find("Wheel", 1, true))
    p.scripts.OnMouseWheel(p, 1)
    check("the wheel does nothing then", s.S.Get("xpTickerFontSize") == 24)
end

do
    local s = Boot({ themePreset = "slate" })
    local ns, t, T = s.ns, s.ticker, s.T
    check("a theme preset changes the colors", ns.Color("muted") ~= "|cff9a9ea6")
    check("the card follows the theme", Is(t.bg, T.bg) and Is(t.kicker, T.accentSoft) and Is(t.rate, T.fg)
        and Is(t.ding.label, T.muted) and Is(t.ding.value, T.fg))
end

do
    local s = Boot(nil, { xpTickerOutline = true })
    check("a saved Outlined Text loads outlined", All(s.ticker, Outlined))
end

do
    local pos = { point = "TOPLEFT", relPoint = "CENTER", x = -500, y = 120 }
    local s = Boot(nil, { xpTickerPos = pos })
    local t = s.ticker
    check("the card sits at the saved place", t.p1 == "TOPLEFT" and t.p3 == "CENTER" and t.p4 == -500 and t.p5 == 120)
end

print(("PASS xp ticker: %d checks"):format(checks))
