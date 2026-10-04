-- Run with Lua 5.1 from the repository root: the XP Ticker's text look. The real Core, Shared
-- style and parts and the ticker's own file are loaded against stubs, and the ticker and its
-- settings preview are checked for the house HUD text: the chosen font and size, no outline
-- unless Outlined Text is on, the soft shadow, and colours from the theme.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local Frame
local created = {}
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    HookScript = function(f, script, fn) f.scripts[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 100 end,
    GetHeight = function(f) return rawget(f, "h") or 40 end,
    SetFont = function(f, path, size, flags) f.font, f.size, f.flags = path, size, flags end,
    SetShadowColor = function(f, r, g, b, a) f.shadow = { r, g, b, a } end,
    SetShadowOffset = function(f, x, y) f.offset = { x, y } end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsMouseOver = function() return false end,
    CreateFontString = function(f) return Frame(f) end,
    CreateTexture = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent, name)
    local f = setmetatable({ scripts = {}, events = {}, parent = parent, name = name }, META)
    created[#created + 1] = f
    return f
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local function Boot(account, settings)
    for i = #created, 1, -1 do created[i] = nil end
    local env = {
        CreateFrame = function(_, name, parent) return Frame(parent, name) end,
        NaowhForeverDB = { account = account or {}, profiles = {}, charActive = {} },
        STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF",
        UIParent = Frame(),
        GetTime = function() return 1000 end,
        UnitLevel = function() return 20 end,
        UnitXP = function() return 500 end,
        UnitXPMax = function() return 1000 end,
        UnitName = function() return "Die" end,
        GetRealmName = function() return "Realm" end,
        GetMaxLevelForPlayerExpansion = function() return 60 end,
        IsXPUserDisabled = function() return false end,
        IsResting = function() return false end,
        C_Timer = { After = NOTHING, NewTicker = function() return { Cancel = NOTHING } end },
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
    Load({ "Shared/Shared.lua", "Shared/Style.lua", "Shared/Parts.lua" }, env)

    local defaults = { enabled = true, xpTicker = true, xpTickerLevel = true, xpTickerElapsed = true,
        xpTickerHideResting = false, xpTickerFont = "", xpTickerFontSize = 24, xpTickerOutline = false,
        xpTickerSplits = true, xpTickerHistoryCount = 10 }
    local db = settings or {}
    ns.QoLSettings = {
        Get = function(k) if db[k] == nil then return defaults[k] end return db[k] end,
        Set = function(k, v) db[k] = v end,
    }
    ns.UI = { FontPath = function(name) return name ~= "" and "font:" .. name or "naowh" end,
        AttachMover = function(parent) return Frame(parent) end }
    ns.Button = function(parent) return Frame(parent) end
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
    return { ns = ns, S = ns.QoLSettings, ticker = ticker, card = card }
end

local St
local function Shadowed(fs)
    return fs.offset[1] == St.HUD_SHADOW_X and fs.offset[2] == St.HUD_SHADOW_Y
        and fs.shadow[1] == St.HUD_SHADOW_RGB.r and fs.shadow[4] == St.HUD_SHADOW_ALPHA
end
local function Plain(fs) return fs.flags == "" and Shadowed(fs) end

do
    local s = Boot()
    local ns, t = s.ns, s.ticker
    St = ns.Shared.Style
    check("the ticker is built on login", t and t.shown)
    check("the text has no outline", t.text.flags == "" and t.splits.flags == "")
    check("the text has the soft shadow", Shadowed(t.text) and Shadowed(t.splits))
    check("the shadow is the house one", St.HUD_SHADOW_ALPHA == 0.8 and St.HUD_SHADOW_X == 1
        and St.HUD_SHADOW_Y == -1)
    check("the Addon Font at the set size", t.text.font == "naowh" and t.text.size == 24)
    check("the splits stay smaller", t.splits.font == "naowh" and t.splits.size == 14)

    local text = t.text.text
    check("labels in the theme's muted colour", text:find(ns.Color("muted", "XP/hr:"), 1, true)
        and text:find(ns.Color("muted", "Ding:"), 1, true) and text:find(ns.Color("muted", "Time:"), 1, true))
    check("the rate in the accent", text:find(ns.Color("muted", "XP/hr:") .. " " .. ns.Color("accent"), 1, true))
    check("the other values in the text colour", text:find(ns.Color("muted", "Time:") .. " " .. ns.Color("fg"), 1, true))
    check("no accent on the labels", not text:find(ns.Color("accent", "XP/hr:"), 1, true))
    check("no hand-written grey", not Read("QoL/NaowhForever_XPTicker.lua"):find("|cff", 1, true))

    ns.PauseXPTicker()
    check("paused, in the muted colour", t.text.text:find(ns.Color("muted", "(paused)"), 1, true))

    s.S.Set("xpTickerFont", "Expressway")
    s.S.Set("xpTickerFontSize", 18)
    check("a picked font and size apply", t.text.font == "font:Expressway" and t.text.size == 18)
    check("the splits follow at their smaller size", t.splits.font == "font:Expressway" and t.splits.size == 10)
    check("still no outline", Plain(t.text) and Plain(t.splits))

    s.S.Set("xpTickerOutline", true)
    check("Outlined Text puts the outline back", t.text.flags == "OUTLINE" and t.splits.flags == "OUTLINE")
    check("and takes the shadow off", t.text.offset[1] == 0 and t.text.offset[2] == 0 and t.text.shadow[4] == 0)
    s.S.Set("xpTickerOutline", false)
    check("turning it off brings the shadow back", Plain(t.text) and Plain(t.splits))

    local preview = s.card.studio.new(Frame())
    s.card.studio.paint(preview, "levelling")
    local p = preview.ticker
    check("the preview has the same look", Plain(p.text) and Plain(p.splits) and p.text.size == 18)
    check("the preview's history labels are muted", p.splits.text:find(ns.Color("muted", "Level 22:"), 1, true))

    local row
    for _, r in ipairs(s.card.rows) do
        if r.key == "xpTickerOutline" then row = r end
    end
    check("Outlined Text is a toggle on the card", row and row.toggle and row.label == "Outlined Text")
    check("its help is one short sentence", row.help and #row.help < 100 and not row.help:find("%. %u"))
    check("off by default", Read("QoL/NaowhForever_QoL.lua"):find("xpTickerOutline = false", 1, true))
end

do
    local s = Boot({ themePreset = "slate" })
    local ns, text = s.ns, s.ticker.text.text
    check("a theme preset changes the label colour", ns.Color("muted") ~= "|cff9a9ea6"
        and text:find(ns.Color("muted", "XP/hr:"), 1, true))
    check("and the rate's accent", text:find(ns.Color("muted", "XP/hr:") .. " " .. ns.Color("accent"), 1, true))
end

do
    local s = Boot(nil, { xpTickerOutline = true })
    check("a saved Outlined Text loads outlined", s.ticker.text.flags == "OUTLINE" and s.ticker.text.shadow[4] == 0)
end

print(("PASS xp ticker: %d checks"):format(checks))
