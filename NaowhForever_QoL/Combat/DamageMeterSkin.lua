-- DamageMeterSkin.lua: Damage Meter Skin, the game's damage meter in the theme's colors, texture and font.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Settings = ns.Shared.Settings
local Parts = ns.Shared.Parts

local ADDON = "Blizzard_DamageMeter"
local PRIMARY_WINDOW = "DamageMeterSessionWindow1"
local TEXT_NO_WINDOW = "Damage Meter Window: the game's meter has no window to place."
local TEXT_NO_PLACE = "Damage Meter Window: the game's meter has no place on screen yet. Show it, then switch this off and on."
local BAR_CLASS, BAR_ACCENT, BAR_CUSTOM = "class", "accent", "custom"
local BARS = { { class = "Class Colors", accent = "Theme Accent", custom = "Custom Color" },
    { BAR_CLASS, BAR_ACCENT, BAR_CUSTOM } }
local OUTLINE_GAME, OUTLINE_SHADOW = "game", ""
local TEXT_GAME_DEFAULT, TEXT_NEEDS_CUSTOM = "Game Default", "Set Bar Color to Custom Color"
local ENTRY_REFRESH = { "UpdateStyle", "UpdateBackground", "UpdateStatusBarColor" }
local SETTING_KEYS = { enabled = true, damageMeterSkin = true, damageMeterBars = true, damageMeterBarColor = true,
    damageMeterTexture = true, damageMeterFont = true, damageMeterOutline = true, damageMeterIconEdge = true,
    damageMeterHeaderColor = true, damageMeterWindowColor = true, damageMeterNameColor = true,
    damageMeterValueColor = true, damageMeterTitleColor = true, damageMeterFree = true }

local OUTLINES = { { [OUTLINE_GAME] = TEXT_GAME_DEFAULT }, { OUTLINE_GAME } }
for key, name in pairs(Parts.HUD_OUTLINES[1]) do OUTLINES[1][key] = name end
for _, key in ipairs(Parts.HUD_OUTLINES[2]) do OUTLINES[2][#OUTLINES[2] + 1] = key end

local meter
local generation = 0
local looks = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local edges = setmetatable({}, { __mode = "k" })
local entries = setmetatable({}, { __mode = "k" })
local arts = setmetatable({}, { __mode = "k" })
local swapped = setmetatable({}, { __mode = "k" })
local faced = setmetatable({}, { __mode = "k" })

local function On()
    return S.Get("enabled") and S.Get("damageMeterSkin")
end

local function Free()
    return S.Get("enabled") and S.Get("damageMeterFree")
end

local function Has(object, method)
    return type(object) == "table" and type(object[method]) == "function"
end

local function Dig(t, ...)
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[select(i, ...)]
    end
    return t
end

local function Pick(key, token)
    local c = S.Get(key)
    if type(c) == "table" then return c end
    return T[token]
end

local function BarColor()
    local choice = S.Get("damageMeterBars")
    if choice == BAR_ACCENT then return T.accent end
    if choice == BAR_CUSTOM then return Pick("damageMeterBarColor", "accent") end
end

local function FontPath()
    local name = S.Get("damageMeterFont")
    if name == "" then return ns.UIFontPath() end
    return ns.UI.FontPath(name)
end

local function Flat(texture, c)
    if not Has(texture, "SetColorTexture") then return end
    local atlas = Has(texture, "GetAtlas") and texture:GetAtlas() or nil
    if atlas or looks[texture] == nil then looks[texture] = atlas or false end
    texture:SetColorTexture(c.r, c.g, c.b, 1)
end

local function Remember(fontString)
    local path, size, flags = fontString:GetFont()
    local r, g, b = fontString:GetTextColor()
    local was = { path, size, flags, r, g, b }
    if Has(fontString, "GetShadowOffset") and Has(fontString, "GetShadowColor") then
        was.shadowX, was.shadowY = fontString:GetShadowOffset()
        was.shadowR, was.shadowG, was.shadowB, was.shadowA = fontString:GetShadowColor()
    end
    looks[fontString] = was
    return was
end

local function Shadow(fontString, was)
    if not (was.shadowX and Has(fontString, "SetShadowOffset") and Has(fontString, "SetShadowColor")) then return end
    fontString:SetShadowOffset(was.shadowX, was.shadowY)
    fontString:SetShadowColor(was.shadowR, was.shadowG, was.shadowB, was.shadowA)
end

local function Face(fontString, was)
    local outline = S.Get("damageMeterOutline")
    if outline == OUTLINE_GAME then
        fontString:SetFont(FontPath(), was[2], was[3])
        Shadow(fontString, was)
        return
    end
    fontString:SetFont(FontPath(), was[2], Parts.HudFlags(outline))
    if outline == OUTLINE_SHADOW then Parts.HudText(fontString) else Parts.HudText(fontString, false) end
end

local function Text(fontString, c)
    if not Has(fontString, "SetTextColor") then return end
    local was = looks[fontString] or Remember(fontString)
    if was[2] and faced[fontString] ~= generation then
        faced[fontString] = generation
        Face(fontString, was)
    end
    fontString:SetTextColor(c.r, c.g, c.b)
end

local function Edge(frame)
    if not Has(frame, "GetFrameLevel") then return end
    if S.Get("damageMeterIconEdge") == false then
        if edges[frame] then edges[frame]._frame:Hide() end
        return
    end
    edges[frame] = edges[frame] or ns.Border(frame, T.outline)
    edges[frame]._frame:Show()
end

local function Tint(entry)
    if not Has(entry, "GetStatusBarTexture") then return end
    local texture = entry:GetStatusBarTexture()
    if not Has(texture, "SetVertexColor") then return end
    local color = On() and BarColor()
    if color then
        texture:SetVertexColor(color.r, color.g, color.b)
    elseif entry.statusBarColor then
        texture:SetVertexColor(entry.statusBarColor:GetRGB())
    end
end

local function BarTexture(entry)
    local bar = entry.StatusBar
    if not (Has(bar, "SetStatusBarTexture") and Has(entry, "GetStatusBarTexture")) then return end
    local art = entry:GetStatusBarTexture()
    local file = ns.UI.TexturePath(S.Get("damageMeterTexture"), nil)
    if file then
        if arts[entry] == nil then arts[entry] = Has(art, "GetAtlas") and art:GetAtlas() or false end
        if swapped[entry] ~= file then
            swapped[entry] = file
            bar:SetStatusBarTexture(file)
        end
    elseif swapped[entry] then
        swapped[entry] = nil
        if arts[entry] and Has(art, "SetAtlas") then art:SetAtlas(arts[entry]) end
    end
end

local function Restyle(entry)
    if not On() then return end
    local bar = entry.StatusBar
    if type(bar) ~= "table" then return end
    Flat(bar.Background, Pick("damageMeterWindowColor", "bg"))
    if Has(bar.BackgroundEdge, "SetAlpha") then bar.BackgroundEdge:SetAlpha(0) end
    Text(bar.Name, Pick("damageMeterNameColor", "fg"))
    Text(bar.Value, Pick("damageMeterValueColor", "muted"))
    Edge(entry.Icon)
    BarTexture(entry)
    Tint(entry)
end

local function Skin(entry)
    if type(entry) ~= "table" then return end
    entries[entry] = true
    if not hooked[entry] then
        hooked[entry] = true
        for _, method in ipairs(ENTRY_REFRESH) do
            if Has(entry, method) then hooksecurefunc(entry, method, Restyle) end
        end
    end
    Restyle(entry)
end

local function Entries(scrollBox)
    if not Has(scrollBox, "EnumerateFrames") then return end
    if not hooked[scrollBox] and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
        hooked[scrollBox] = true
        ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, frame) Skin(frame) end)
    end
    for _, frame in scrollBox:EnumerateFrames() do Skin(frame) end
end

local function SkinWindow(window)
    local titles, values = Pick("damageMeterTitleColor", "fg"), Pick("damageMeterValueColor", "muted")
    local header, background = Pick("damageMeterHeaderColor", "panel"), Pick("damageMeterWindowColor", "bg")
    Flat(window.Header, header)
    Text(window.SessionTimer, values)
    Text(Dig(window, "SessionDropdown", "SessionName"), titles)
    Text(Dig(window, "DamageMeterTypeDropdown", "TypeName"), titles)
    local container = window.MinimizeContainer
    if type(container) ~= "table" then return end
    Flat(container.Background, background)
    Skin(container.LocalPlayerEntry)
    Entries(container.ScrollBox)
    local source = container.SourceWindow
    if type(source) == "table" then
        Flat(source.Background, header)
        Entries(source.ScrollBox)
    end
end

local function GiveBack()
    for region, was in pairs(looks) do
        if type(was) == "string" and Has(region, "SetAtlas") then
            region:SetAtlas(was)
        elseif type(was) == "table" and was[1] then
            region:SetFont(was[1], was[2], was[3])
            region:SetTextColor(was[4], was[5], was[6])
            Shadow(region, was)
        end
    end
    for _, border in pairs(edges) do border._frame:Hide() end
    for entry in pairs(entries) do
        local bar = entry.StatusBar
        if type(bar) == "table" and Has(bar.BackgroundEdge, "SetAlpha") then bar.BackgroundEdge:SetAlpha(1) end
        if swapped[entry] then
            swapped[entry] = nil
            local art = Has(entry, "GetStatusBarTexture") and entry:GetStatusBarTexture() or nil
            if arts[entry] and Has(art, "SetAtlas") then art:SetAtlas(arts[entry]) end
        end
        Tint(entry)
    end
end

local placed = false
local noted = false

local function Note(text)
    if noted then return end
    noted = true
    ns.Print(text)
end

local function Primary()
    local window = Has(meter, "GetPrimarySessionWindow") and meter:GetPrimarySessionWindow() or nil
    if type(window) ~= "table" then window = _G[PRIMARY_WINDOW] end
    return window
end

local function Locked(window)
    return Has(window, "IsLocked") and window:IsLocked() == true
end

local function Save(window)
    local left, top = window:GetLeft(), window:GetTop()
    if not (left and top) then return end
    S.Set("damageMeterPos", { left = left, top = top, width = window:GetWidth(), height = window:GetHeight() })
end

local function Handles(window)
    if hooked[window] or not Has(window, "HookScript") then return end
    hooked[window] = true
    window:HookScript("OnDragStart", function(self)
        if Free() and not Locked(self) then self:StartMoving() end
    end)
    window:HookScript("OnDragStop", function(self)
        if not Free() then return end
        self:StopMovingOrSizing()
        Save(self)
    end)
    local grip = Dig(window, "MinimizeContainer", "ResizeButton")
    if not Has(grip, "HookScript") then return end
    grip:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and Free() and not Locked(window) then window:StartSizing("BOTTOMRIGHT") end
    end)
    grip:HookScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not Free() then return end
        window:StopMovingOrSizing()
        Save(window)
    end)
    grip:HookScript("OnEnter", function(self)
        if Free() and not Locked(window) then self:SetAlpha(1) end
    end)
    grip:HookScript("OnLeave", function(self)
        if Free() then self:SetAlpha(0) end
    end)
end

local function Reattach(window)
    placed = false
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT")
    window:SetPoint("BOTTOMRIGHT")
    if Has(window, "SetMovable") then window:SetMovable(false) end
    if Has(window, "SetResizable") then window:SetResizable(false) end
end

local function Place()
    local window = Primary()
    if not (Has(window, "SetPoint") and Has(window, "ClearAllPoints") and Has(window, "SetSize")) then
        if Free() then Note(TEXT_NO_WINDOW) end
        return
    end
    if not Free() then
        if placed then Reattach(window) end
        return
    end
    local pos = S.Get("damageMeterPos")
    if type(pos) ~= "table" then
        Save(window)
        pos = S.Get("damageMeterPos")
        if type(pos) ~= "table" then
            Note(TEXT_NO_PLACE)
            return
        end
    end
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.left, pos.top)
    window:SetSize(pos.width, pos.height)
    if Has(window, "SetMovable") then window:SetMovable(true) end
    if Has(window, "SetResizable") then window:SetResizable(true) end
    placed = true
    Handles(window)
end

local function ResetPosition()
    local window = Primary()
    if placed and Has(window, "ClearAllPoints") then Reattach(window) end
    S.Set("damageMeterPos", false)
    Place()
end

local function Apply()
    if not meter then return end
    generation = generation + 1
    if not On() then
        GiveBack()
    elseif Has(meter, "ForEachSessionWindow") then
        meter:ForEachSessionWindow(SkinWindow)
        for entry in pairs(entries) do
            BarTexture(entry)
            Tint(entry)
        end
    end
    Place()
end

local function Hook()
    meter = _G.DamageMeter
    if Has(meter, "SetupSessionWindow") then hooksecurefunc(meter, "SetupSessionWindow", Apply) end
    Apply()
end

local function Start()
    if meter or not (On() or Free()) then return end
    if C_AddOns.IsAddOnLoaded(ADDON) then
        Hook()
    else
        EventUtil.ContinueOnAddOnLoaded(ADDON, Hook)
    end
end

hooksecurefunc(S, "Set", function(key)
    if not SETTING_KEYS[key] then return end
    Start()
    Apply()
end)
hooksecurefunc(ns, "Apply", function()
    Start()
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Start)

local function CustomBars()
    return S.Get("damageMeterBars") == BAR_CUSTOM
end

local function ColorRow(key, label, token, help)
    return { key = key, label = label, colour = true, help = help,
        get = function()
            local c = Pick(key, token)
            return c.r, c.g, c.b, 1
        end,
        set = function(r, g, b) S.Set(key, { r = r, g = g, b = b }) end }
end

Settings.Page("QoL/Combat", S):Card({
    id = "damageMeterSkin", name = "Damage Meter Skin", order = 110, switch = "damageMeterSkin",
    help = "The game's damage meter in your theme's colors.",
    rows = {
        { key = "damageMeterBars", label = "Bar Color", choice = BARS },
        { key = "damageMeterBarColor", label = "Custom Bar Color", colour = true, needs = CustomBars,
          why = TEXT_NEEDS_CUSTOM,
          get = function()
              local c = Pick("damageMeterBarColor", "accent")
              return c.r, c.g, c.b, 1
          end,
          set = function(r, g, b) S.Set("damageMeterBarColor", { r = r, g = g, b = b }) end,
          help = "The bars' color when Bar Color is Custom Color." },
        { key = "damageMeterTexture", label = "Bar Texture", texture = TEXT_GAME_DEFAULT },
        { key = "damageMeterIconEdge", label = "Icon Border", toggle = true,
          help = "A thin border round each bar's icon." },
        Settings.Group("Text"),
        { key = "damageMeterFont", label = "Font", font = true },
        { key = "damageMeterOutline", label = "Outline", choice = OUTLINES,
          help = "The game's own, none, the soft shadow, a thin outline or a thick one." },
        ColorRow("damageMeterNameColor", "Name Color", "fg", "The names on the bars."),
        ColorRow("damageMeterValueColor", "Amount Color", "muted", "The amounts, and the fight time."),
        ColorRow("damageMeterTitleColor", "Title Color", "fg", "The list and session names in the title bar."),
        Settings.Group("Window"),
        ColorRow("damageMeterHeaderColor", "Title Bar Color", "panel", "The title bar and the spell panel."),
        ColorRow("damageMeterWindowColor", "Window Color", "bg", "The window and the shadow behind each bar."),
    },
})

Settings.Page("QoL/Combat", S):Card({
    id = "damageMeterWindow", name = "Damage Meter Window", order = 111, switch = "damageMeterFree",
    help = "Move and resize the game's damage meter here, without Edit Mode.",
    rows = {
        { label = "Window Position", buttonText = "Reset", button = ResetPosition,
          help = "Puts the window back where Edit Mode has it." },
    },
})
