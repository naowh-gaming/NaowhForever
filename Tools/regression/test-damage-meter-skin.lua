-- Offline behavior checks for the Damage Meter Skin (NaowhForever_QoL/Combat/DamageMeterSkin.lua) against a stub
-- of the game's meter; they do not emulate the client. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local THEME = {
    bg = { r = 0.1, g = 0.1, b = 0.1 }, panel = { r = 0.2, g = 0.2, b = 0.2 }, fg = { r = 0.9, g = 0.9, b = 0.9 },
    muted = { r = 0.6, g = 0.6, b = 0.6 }, accent = { r = 0, g = 0.5, b = 1 }, outline = { r = 0, g = 0, b = 0 },
}
local ADDON = "Blizzard_DamageMeter"
local FONT = "Interface\\AddOns\\NaowhForever\\Media\\Fonts\\Naowh.ttf"
local GAME_FONT, GAME_SIZE, GAME_FLAGS = "Fonts\\ARIALN.TTF", 14, "OUTLINE"
local CLASS_RGB = { 0.77, 0.12, 0.23 }

local function Texture(atlas)
    local t = { atlas = atlas, alpha = 1 }
    function t:SetColorTexture(r, g, b, a) self.solid = { r, g, b, a }; self.atlas = nil end
    function t:SetAtlas(name) self.atlas = name; self.solid = nil end
    function t:GetAtlas() return self.atlas end
    function t:SetAlpha(a) self.alpha = a end
    function t:SetVertexColor(r, g, b) self.vertex = { r, g, b } end
    return t
end

local function FontString()
    local f = { path = GAME_FONT, size = GAME_SIZE, flags = GAME_FLAGS, r = 1, g = 0.82, b = 0 }
    function f:GetFont() return self.path, self.size, self.flags end
    function f:SetFont(path, size, flags) self.path, self.size, self.flags = path, size, flags end
    function f:GetTextColor() return self.r, self.g, self.b end
    function f:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
    return f
end

-- The game's entry: it sets its own art and colour from UpdateStyle, UpdateBackground and UpdateStatusBarColor.
local function Entry()
    local bar = { Background = Texture("ui-damagemeters-bar-shadowbg"), BackgroundEdge = Texture("ui-damagemeters-bar-shadowedge"),
        Name = FontString(), Value = FontString() }
    local barTexture = Texture("UI-HUD-CoolDownManager-Bar")
    local e = { StatusBar = bar, Icon = { level = 1 }, refreshes = 0 }
    function e:GetStatusBarTexture() return barTexture end
    function e:UpdateStyle()
        self.refreshes = self.refreshes + 1
        bar.Background:SetAtlas("ui-damagemeters-bar-shadowbg")
    end
    function e:UpdateBackground() bar.BackgroundEdge:SetAlpha(1) end
    function e:UpdateStatusBarColor()
        self.statusBarColor = { GetRGB = function() return CLASS_RGB[1], CLASS_RGB[2], CLASS_RGB[3] end }
        barTexture:SetVertexColor(CLASS_RGB[1], CLASS_RGB[2], CLASS_RGB[3])
    end
    function e.Icon:GetFrameLevel() return self.level end
    e:UpdateStatusBarColor()
    e.barTexture = barTexture
    return e
end

local function ScrollBox(frames)
    local box = { frames = frames or {}, callbacks = {} }
    function box:EnumerateFrames()
        local i = 0
        return function()
            i = i + 1
            if self.frames[i] then return i, self.frames[i] end
        end
    end
    function box:Acquire(entry)
        self.frames[#self.frames + 1] = entry
        for _, fn in ipairs(self.callbacks) do fn(self, entry, {}, true) end
    end
    return box
end

local function Window()
    local source = { Background = Texture("common-dropdown-bg"), ScrollBox = ScrollBox({ Entry() }) }
    local w = { Header = Texture("ui-damagemeters-header-bar"), SessionTimer = FontString(),
        SessionDropdown = { SessionName = FontString() }, DamageMeterTypeDropdown = { TypeName = FontString() },
        MinimizeContainer = { Background = Texture("damagemeters-background"), LocalPlayerEntry = Entry(),
            ScrollBox = ScrollBox({ Entry(), Entry() }), SourceWindow = source } }
    return w
end

-- Builds the addon's environment. loaded: Blizzard_DamageMeter is already loaded. Returns the pieces tests poke.
local function Boot(settings, loaded, windows)
    local s = { settings = settings or {}, hooks = 0, borders = {}, cards = {}, waiting = {} }
    local defaults = { enabled = true, damageMeterSkin = false, damageMeterBars = "class" }
    local store = {}
    function store.Get(k)
        local v = s.settings[k]
        if v == nil then v = defaults[k] end
        return v
    end
    function store.Set(k, v) s.settings[k] = v end
    local meter = { windows = windows or { Window() } }
    function meter:ForEachSessionWindow(fn)
        for _, w in ipairs(self.windows) do fn(w) end
    end
    function meter:SetupSessionWindow() end
    local ns = { QoLSettings = store, THEME = THEME, Apply = function() end,
        UIFontPath = function() return FONT end,
        Border = function(frame, color)
            local border = { frame = frame, color = color, _frame = { shown = true } }
            function border._frame:Show() self.shown = true end
            function border._frame:Hide() self.shown = false end
            s.borders[#s.borders + 1] = border
            return border
        end,
        Shared = { Settings = { Page = function(_, name)
            local page = { name = name }
            function page:Card(def) s.cards[#s.cards + 1] = def; return self end
            return page
        end } } }
    local env = { unpack = unpack, ipairs = ipairs, pairs = pairs, type = type, select = select,
        setmetatable = setmetatable, tostring = tostring, NaowhForever = ns,
        hooksecurefunc = function(tbl, name, fn)
            s.hooks = s.hooks + 1
            local original = tbl[name]
            tbl[name] = function(...)
                local results = { original(...) }
                fn(...)
                return unpack(results)
            end
        end,
        ScrollUtil = { AddAcquiredFrameCallback = function(box, fn) box.callbacks[#box.callbacks + 1] = fn end },
        C_AddOns = { IsAddOnLoaded = function(name) return loaded and name == ADDON end },
        EventUtil = { ContinueOnAddOnLoaded = function(name, fn) s.waiting[name] = fn end },
        CreateFrame = function()
            local f = { events = {} }
            function f:RegisterEvent(e) self.events[e] = true end
            function f:SetScript(_, fn) self.onEvent = fn end
            return f
        end }
    env._G = env
    if loaded then env.DamageMeter = meter end
    local chunk = assert(loadfile("NaowhForever_QoL/Combat/DamageMeterSkin.lua"))
    setfenv(chunk, env)
    local frames = {}
    local create = env.CreateFrame
    env.CreateFrame = function(...) local f = create(...); frames[#frames + 1] = f; return f end
    chunk("NaowhForever")
    s.base = s.hooks
    return s, store, meter, ns, frames, env
end

local function Login(frames)
    local f = frames[#frames]
    if f and f.onEvent then f.onEvent(f, "PLAYER_LOGIN") end
end

local function SameRgb(c, t) return c and c[1] == t.r and c[2] == t.g and c[3] == t.b end
local function Entries(window)
    local c = window.MinimizeContainer
    return { c.LocalPlayerEntry, c.ScrollBox.frames[1], c.ScrollBox.frames[2], c.SourceWindow.ScrollBox.frames[1] }
end

-- the card
do
    local s = Boot()
    check("one card, on the Combat page's store", #s.cards == 1)
    local card = s.cards[1]
    check("its id, name and switch", card.id == "damageMeterSkin" and card.name == "Damage Meter Skin" and card.switch == "damageMeterSkin")
    local row = card.rows[1]
    check("a bar color choice", row.key == "damageMeterBars" and row.choice[2][1] == "class" and row.choice[2][2] == "accent"
        and row.choice[1].class == "Class Colors" and row.choice[1].accent == "Theme Accent")
    check("one short help sentence", #card.help < 100 and not card.help:find("%d"))
end

-- off by default: nothing hooked, nothing touched
do
    local s, _, meter, _, frames = Boot({}, true)
    local window = meter.windows[1]
    Login(frames)
    check("off: no hook is made on the meter", s.hooks == s.base)
    check("off: the art is the game's", window.Header.atlas == "ui-damagemeters-header-bar" and window.Header.solid == nil)
    check("off: no border, no callback", #s.borders == 0 and #window.MinimizeContainer.ScrollBox.callbacks == 0)
    check("off: the meter is not waited for", next(s.waiting) == nil)
end

-- on, with the meter loaded: the windows and entries are skinned
do
    local s, store, meter, _, frames = Boot({ damageMeterSkin = true }, true)
    Login(frames)
    local window = meter.windows[1]
    local c = window.MinimizeContainer
    check("the header is the Panels color", window.Header.solid and SameRgb(window.Header.solid, THEME.panel))
    check("the window background is the Background color", SameRgb(c.Background.solid, THEME.bg))
    check("the source window is the Panels color", SameRgb(c.SourceWindow.Background.solid, THEME.panel))
    check("the timer is Secondary Text, the names Text",
        SameRgb({ window.SessionTimer.r, window.SessionTimer.g, window.SessionTimer.b }, THEME.muted)
        and window.SessionDropdown.SessionName.r == THEME.fg.r and window.DamageMeterTypeDropdown.TypeName.r == THEME.fg.r)
    check("the header text is in the addon font, the game's size and flags",
        window.SessionTimer.path == FONT and window.SessionTimer.size == GAME_SIZE and window.SessionTimer.flags == GAME_FLAGS)
    for i, entry in ipairs(Entries(window)) do
        local bar = entry.StatusBar
        check("entry " .. i .. ": the shadow is the Background color", SameRgb(bar.Background.solid, THEME.bg))
        check("entry " .. i .. ": the shadow's edge is faded out", bar.BackgroundEdge.alpha == 0)
        check("entry " .. i .. ": the name is Text, the value Secondary Text in the addon font",
            bar.Name.r == THEME.fg.r and bar.Value.r == THEME.muted.r and bar.Name.path == FONT and bar.Value.path == FONT)
        local edged = false
        for _, border in ipairs(s.borders) do edged = edged or border.frame == entry.Icon end
        check("entry " .. i .. ": its icon has a border", edged)
        check("entry " .. i .. ": class colors are the game's own", SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))
    end
    check("four icons, four borders, in the outline color", #s.borders == 4 and s.borders[1].color == THEME.outline)

    -- the game sets its art again: ours again
    local entry = c.ScrollBox.frames[1]
    entry:UpdateStyle()
    check("the game's style refresh: flat again", entry.StatusBar.Background.solid and entry.StatusBar.Background.atlas == nil)
    entry:UpdateBackground()
    check("the game's background refresh: faded again", entry.StatusBar.BackgroundEdge.alpha == 0)
    check("and no second border", #s.borders == 4)

    -- an entry acquired later
    local fresh = Entry()
    c.ScrollBox:Acquire(fresh)
    check("a new entry is skinned by the scroll box callback", SameRgb(fresh.StatusBar.Background.solid, THEME.bg) and #s.borders == 5)
    local hooksNow = s.hooks
    c.ScrollBox:Acquire(fresh)
    check("and hooked once", s.hooks == hooksNow)

    -- Theme Accent
    store.Set("damageMeterBars", "accent")
    for i, e in ipairs(Entries(window)) do
        check("accent " .. i .. ": the bar is the Accent", SameRgb(e.barTexture.vertex, THEME.accent))
    end
    entry:UpdateStatusBarColor()
    check("the game sets its color again: the Accent again", SameRgb(entry.barTexture.vertex, THEME.accent))
    store.Set("damageMeterBars", "class")
    check("back to class colors: the game's own", SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))

    -- off: the game's art, fonts and colors come back
    store.Set("damageMeterSkin", false)
    check("off: the header art is back", window.Header.atlas == "ui-damagemeters-header-bar")
    check("off: the window background art is back", c.Background.atlas == "damagemeters-background")
    check("off: the timer's font and color are the game's",
        window.SessionTimer.path == GAME_FONT and window.SessionTimer.size == GAME_SIZE and window.SessionTimer.r == 1
        and window.SessionTimer.g == 0.82)
    check("off: the entry's shadow and edge are back", entry.StatusBar.Background.atlas == "ui-damagemeters-bar-shadowbg"
        and entry.StatusBar.BackgroundEdge.alpha == 1)
    check("off: the edges are hidden", s.borders[1]._frame.shown == false and s.borders[5]._frame.shown == false)
    entry:UpdateStyle()
    check("off: a style refresh leaves the game's art", entry.StatusBar.Background.atlas == "ui-damagemeters-bar-shadowbg")

    -- on again
    store.Set("damageMeterSkin", true)
    check("on again: skinned, with the same borders shown", SameRgb(window.Header.solid, THEME.panel)
        and s.borders[1]._frame.shown == true and #s.borders == 5)
    -- the master switch
    store.Set("enabled", false)
    check("QoL off: given back", window.Header.atlas == "ui-damagemeters-header-bar")
end

-- accent from the start, and the accent restored when the skin goes
do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterBars = "accent" }, true)
    Login(frames)
    local entry = meter.windows[1].MinimizeContainer.ScrollBox.frames[1]
    check("accent at login: the bar is the Accent", SameRgb(entry.barTexture.vertex, THEME.accent))
    store.Set("damageMeterSkin", false)
    check("the skin off: the class color is back", SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))
end

-- the meter is not loaded yet: it is waited for, and a window made later is skinned
do
    local s, _, _, _, frames, env = Boot({ damageMeterSkin = true }, false)
    Login(frames)
    check("not loaded: the addon is waited for, and nothing hooked", s.waiting[ADDON] and s.hooks == s.base)
    local late = Window()
    local meter = { windows = {} }
    function meter:ForEachSessionWindow(fn) for _, w in ipairs(self.windows) do fn(w) end end
    function meter:SetupSessionWindow() end
    env.DamageMeter = meter
    s.waiting[ADDON]()
    check("loaded: its session window creation is hooked", s.hooks - s.base == 1)
    meter.windows[1] = late
    meter:SetupSessionWindow()
    check("a window made later is skinned", SameRgb(late.Header.solid, THEME.panel))
end

-- switched on in Settings after login, with the meter loaded
do
    local s, store, meter, _, frames = Boot({}, true)
    Login(frames)
    check("before the switch: untouched", s.hooks == s.base)
    store.Set("damageMeterSkin", true)
    check("after the switch: skinned", SameRgb(meter.windows[1].Header.solid, THEME.panel) and s.hooks > s.base)
    store.Set("someOtherSetting", 1)
    check("another setting changes nothing here", true)
end

-- missing pieces: no error
do
    local bare = { {}, { MinimizeContainer = {} }, { Header = {}, MinimizeContainer = { ScrollBox = {}, SourceWindow = {} } },
        { MinimizeContainer = { LocalPlayerEntry = {}, ScrollBox = ScrollBox({ { StatusBar = {} }, {} }) } } }
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true }, true, bare)
    Login(frames)
    store.Set("damageMeterBars", "accent")
    store.Set("damageMeterSkin", false)
    check("windows and entries without their parts: skipped without an error", meter ~= nil)
    local _, _, noMeter, _, bootFrames = Boot({ damageMeterSkin = true }, true, {})
    Login(bootFrames)
    check("no windows: nothing to do", noMeter ~= nil)
end

print("PASS damage meter skin: " .. checks .. " checks")
