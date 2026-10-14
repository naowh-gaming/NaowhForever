-- Run with Lua 5.1 from the repository root: the Total Craft Timer ends when the client refuses a
-- craft (no reagents) or a batch stops early, instead of counting the whole batch down. A refused
-- craft sends no spellcast events, so only the watch ticker can notice. Loads CraftTimer.lua
-- against stubs and drives the clock and the ticker by hand.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local RECIPE = 3946
local boot, bar, timer
local now, casting, craftHook, tick = 100, nil, nil, nil

local function Noop() end
local frameMethods = {
    GetAlpha = function() return 1 end,
    GetFrameLevel = function() return 1 end,
    GetScale = function() return 1 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetScript = function(f, name, fn) f[name] = fn end,
    RegisterEvent = function(f, event)
        if event == "PLAYER_LOGIN" then boot = f end
        if event == "UPDATE_TRADESKILL_CAST_STOPPED" then timer = f end
    end,
}
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }
local function Frame(_, name)
    local f = setmetatable({}, frameMeta)
    if name == "NaowhForeverCraftTimer" then bar = f end
    return f
end
frameMethods.CreateTexture = function() return Frame() end

local color = { r = 1, g = 1, b = 1 }
local settings = { enabled = true, craftTimer = true, craftTimerFontSize = 14, craftTimerBgAlpha = 0.9 }
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    THEME = { bg = color, accent = color, accentSoft = color },
    Shared = { Parts = { HudFont = Noop } },
    UI = { TexturePath = function() return "" end },
    Solid = function() return Frame() end, Border = Noop, Font = function() return Frame() end, Apply = Noop,
    Professions = {
        Settings = { Get = function(k) return settings[k] end, Set = Noop },
        Style = { BORDER_RGB = color },
        Widgets = { Crop = function(t) return t end },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    UIParent = Frame(),
    CreateFrame = Frame,
    GetTime = function() return now end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UnitCastingInfo = function()
        if casting then return "Solid Dynamite", nil, nil, now * 1000, (now + 5) * 1000, nil, nil, nil, casting end
    end,
    C_Spell = { GetSpellInfo = function() return { name = "Solid Dynamite", castTime = 5000 } end },
    C_TradeSkillUI = { GetRecipeInfo = function() return { name = "Solid Dynamite", icon = 1 } end },
    C_Timer = { NewTicker = function(_, fn) tick = fn; return { Cancel = Noop } end },
    hooksecurefunc = function(_, name, fn)
        if name == "CraftRecipe" then craftHook = fn end
    end,
}, { __index = _G })
env._G = env

Load({ "NaowhForever_Professions/UI/CraftTimer.lua" }, env)
boot.OnEvent(boot, "PLAYER_LOGIN")
check("logging in hooks CraftRecipe", craftHook ~= nil)

local function Advance(seconds)
    for _ = 1, seconds do
        now = now + 1
        tick()
    end
end

craftHook(RECIPE, 20)
check("a batch of 20 shows the bar", bar.shown)
Advance(1)
check("one second without a cast keeps it", bar.shown)
Advance(2)
check("a refused craft ends the bar within a few seconds", not bar.shown)

craftHook(RECIPE, 3)
casting = RECIPE
timer.OnEvent(timer, "UNIT_SPELLCAST_START", "player", nil, RECIPE)
Advance(4)
check("a long cast keeps the bar", bar.shown)
casting = nil
timer.OnEvent(timer, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, RECIPE)
Advance(1)
check("the short gap between crafts keeps it", bar.shown)
casting = RECIPE
timer.OnEvent(timer, "UNIT_SPELLCAST_START", "player", nil, RECIPE)
Advance(5)
casting = nil
timer.OnEvent(timer, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, RECIPE)
check("still counting with one craft left", bar.shown)
Advance(3)
check("out of reagents before the last craft, it ends", not bar.shown)

print(("test-craft-timer-refused: %d checks passed"):format(checks))
