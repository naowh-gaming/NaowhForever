-- DamageMeterSkin.lua: Damage Meter Skin, the game's damage meter in the theme's colors.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Settings = ns.Shared.Settings

local ADDON = "Blizzard_DamageMeter"
local BARS = { { class = "Class Colors", accent = "Theme Accent" }, { "class", "accent" } }
local ENTRY_REFRESH = { "UpdateStyle", "UpdateBackground", "UpdateStatusBarColor" }
local SETTING_KEYS = { enabled = true, damageMeterSkin = true, damageMeterBars = true }

local meter
local looks = setmetatable({}, { __mode = "k" })     -- texture or font string -> what the game had on it
local hooked = setmetatable({}, { __mode = "k" })    -- entry or scroll box -> it is ours to restyle
local edges = setmetatable({}, { __mode = "k" })     -- icon frame -> its border
local entries = setmetatable({}, { __mode = "k" })   -- every entry skinned, to give back

local function On()
    return S.Get("enabled") and S.Get("damageMeterSkin")
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

local function Flat(texture, c)
    if not Has(texture, "SetColorTexture") then return end
    local atlas = Has(texture, "GetAtlas") and texture:GetAtlas() or nil
    if atlas or looks[texture] == nil then looks[texture] = atlas or false end
    texture:SetColorTexture(c.r, c.g, c.b, 1)
end

local function Text(fontString, c)
    if not Has(fontString, "SetTextColor") then return end
    if not looks[fontString] then
        local path, size, flags = fontString:GetFont()
        local r, g, b = fontString:GetTextColor()
        looks[fontString] = { path, size, flags, r, g, b }
    end
    local _, size, flags = unpack(looks[fontString])
    if size then fontString:SetFont(ns.UIFontPath(), size, flags) end
    fontString:SetTextColor(c.r, c.g, c.b)
end

local function Edge(frame)
    if not Has(frame, "GetFrameLevel") then return end
    edges[frame] = edges[frame] or ns.Border(frame, T.outline)
    edges[frame]._frame:Show()
end

local function Tint(entry)
    if not Has(entry, "GetStatusBarTexture") then return end
    local texture = entry:GetStatusBarTexture()
    if not Has(texture, "SetVertexColor") then return end
    if On() and S.Get("damageMeterBars") == "accent" then
        texture:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
    elseif entry.statusBarColor then
        texture:SetVertexColor(entry.statusBarColor:GetRGB())
    end
end

local function Restyle(entry)
    if not On() then return end
    local bar = entry.StatusBar
    if type(bar) ~= "table" then return end
    Flat(bar.Background, T.bg)
    if Has(bar.BackgroundEdge, "SetAlpha") then bar.BackgroundEdge:SetAlpha(0) end
    Text(bar.Name, T.fg)
    Text(bar.Value, T.muted)
    Edge(entry.Icon)
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
    Flat(window.Header, T.panel)
    Text(window.SessionTimer, T.muted)
    Text(Dig(window, "SessionDropdown", "SessionName"), T.fg)
    Text(Dig(window, "DamageMeterTypeDropdown", "TypeName"), T.fg)
    local container = window.MinimizeContainer
    if type(container) ~= "table" then return end
    Flat(container.Background, T.bg)
    Skin(container.LocalPlayerEntry)
    Entries(container.ScrollBox)
    local source = container.SourceWindow
    if type(source) == "table" then
        Flat(source.Background, T.panel)
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
        end
    end
    for _, border in pairs(edges) do border._frame:Hide() end
    for entry in pairs(entries) do
        local bar = entry.StatusBar
        if type(bar) == "table" and Has(bar.BackgroundEdge, "SetAlpha") then bar.BackgroundEdge:SetAlpha(1) end
        Tint(entry)
    end
end

local function Apply()
    if not meter then return end
    if not On() then
        GiveBack()
    elseif Has(meter, "ForEachSessionWindow") then
        meter:ForEachSessionWindow(SkinWindow)
        for entry in pairs(entries) do Tint(entry) end
    end
end

local function Hook()
    meter = _G.DamageMeter
    if Has(meter, "SetupSessionWindow") then hooksecurefunc(meter, "SetupSessionWindow", Apply) end
    Apply()
end

local function Start()
    if meter or not On() then return end
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

Settings.Page("QoL/Combat", S):Card({
    id = "damageMeterSkin", name = "Damage Meter Skin", order = 110, switch = "damageMeterSkin",
    help = "The game's damage meter in your theme's colors.",
    rows = {
        { key = "damageMeterBars", label = "Bar Color", choice = BARS },
    },
})
