local f = assert(io.open(arg[1] or "NaowhForever_QoL/Interface/HideClutter.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()

local function Compile(env)
    if setfenv then
        local chunk = assert(loadstring(source)); setfenv(chunk, env)
        return chunk
    end
    return assert(load(source, "=UIClutter", "t", env))
end

-- Loads the file against a fresh session: settings, the account store and CVars persist
-- across sessions the way SavedVariables and the client do; frames and hooks do not.
local function Session(settings, account, cvars)
    local log = { cvarWrites = 0, errors = {}, frames = {} }
    local boot
    local function Frame()
        local frame = { events = {} }
        log.frames[#log.frames + 1] = frame
        function frame:RegisterEvent(e) self.events[e] = true; if self == log.uiErrors then log.errors[#log.errors + 1] = "+" .. e end end
        function frame:UnregisterAllEvents() self.events = {} end
        function frame:UnregisterEvent(e) self.events[e] = nil; if self == log.uiErrors then log.errors[#log.errors + 1] = "-" .. e end end
        function frame:SetScript(_, fn) self.onEvent = fn end
        return frame
    end
    log.uiErrors = Frame()
    local S = { Get = function(k) return settings[k] end }
    function S.Set(k, v) settings[k] = v end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = S, AccountSettings = function() return account end }
    function ns.Apply() end
    local env = {
        _G = { NaowhForever = ns },
        pairs = pairs, ipairs = ipairs,
        CreateFrame = function() local fr = Frame(); boot = fr; return fr end,
        hooksecurefunc = function(t, name, post)
            if type(t) ~= "table" then return end
            local orig = t[name]
            t[name] = function(...) orig(...); post(...) end
        end,
        UIErrorsFrame = log.uiErrors,
        ActionStatus = Frame(),
        MovieFrame = {},
        C_CVar = {
            GetCVar = function(name) return cvars[name] end,
            SetCVar = function(name, value) cvars[name] = value; log.cvarWrites = log.cvarWrites + 1 end,
        },
    }
    Compile(env)()
    boot.onEvent(boot, "PLAYER_LOGIN")
    return S, log
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("a player who never turned it on keeps their tutorial settings untouched", function()
    local cvars = { showTutorials = "0", hideHelptips = "0" }
    local _, log = Session({ enabled = true, hideTutorials = false }, {}, cvars)
    assert(log.cvarWrites == 0 and cvars.showTutorials == "0")
end)
Case("turning it on hides, turning it off puts back what the player had", function()
    local cvars = { showTutorials = "1", hideHelptips = "0" }
    local account = {}
    local S = Session({ enabled = true, hideTutorials = false }, account, cvars)
    S.Set("hideTutorials", true)
    assert(cvars.showTutorials == "0" and cvars.hideHelptips == "1")
    S.Set("hideTutorials", false)
    assert(cvars.showTutorials == "1" and cvars.hideHelptips == "0" and account.tutorialCVars == nil)
end)
Case("the values from before survive a reload while it stays on", function()
    local cvars = { showTutorials = "1", hideHelptips = "0" }
    local settings, account = { enabled = true, hideTutorials = false }, {}
    Session(settings, account, cvars).Set("hideTutorials", true)
    local S = Session(settings, account, cvars)
    assert(account.tutorialCVars.showTutorials == "1")
    S.Set("hideTutorials", false)
    assert(cvars.showTutorials == "1" and cvars.hideHelptips == "0")
end)
Case("switching the QoL module off restores the tutorials too", function()
    local cvars = { showTutorials = "1", hideHelptips = "0" }
    local S = Session({ enabled = true, hideTutorials = true }, {}, cvars)
    assert(cvars.showTutorials == "0")
    S.Set("enabled", false)
    assert(cvars.showTutorials == "1")
end)
Case("error text is only touched on a change, and comes back when turned off", function()
    local S, log = Session({ enabled = true, hideErrors = false }, {}, {})
    assert(#log.errors == 0)
    S.Set("hideErrors", true)
    S.Set("hideTutorials", false)
    S.Set("hideErrors", false)
    assert(table.concat(log.errors, " ") == "-UI_ERROR_MESSAGE +UI_ERROR_MESSAGE")
end)
Case("the cursor settings live on the Cursor & Crosshair tab, not in UI Clutter or Combat", function()
    local function Read(path)
        local file = assert(io.open(path, "rb"))
        local s = file:read("*a"):gsub("\r\n", "\n"); file:close()
        return s
    end
    assert(not source:find("cursorClip", 1, true))
    local clip = Read("NaowhForever_QoL/Cursor/CursorClip.lua")
    assert(clip:find('Page("QoL/Cursor & Crosshair", S):Card({', 1, true) and clip:find('key = "cursorClip"', 1, true))
    local cooldown = Read("NaowhForever_QoL/Combat/CursorCooldown.lua")
    assert(cooldown:find('Page("QoL/Cursor & Crosshair", S):Card({\n    id = "cursorCooldown"', 1, true))
end)
Case("auto push stays untouched by default", function()
    local cvars = { AutoPushSpellToActionBar = "1" }
    local _, log = Session({ enabled = true }, {}, cvars)
    assert(log.cvarWrites == 0 and cvars.AutoPushSpellToActionBar == "1")
end)
Case("auto push is blocked and the original value survives a reload", function()
    local cvars, account = { AutoPushSpellToActionBar = "1" }, {}
    local settings = { enabled = true, stopAutoPushSpells = false }
    local S = Session(settings, account, cvars)
    S.Set("stopAutoPushSpells", true)
    assert(cvars.AutoPushSpellToActionBar == "0" and account.autoPushSpellCVar == "1")
    S = Session(settings, account, cvars)
    S.Set("stopAutoPushSpells", false)
    assert(cvars.AutoPushSpellToActionBar == "1" and account.autoPushSpellCVar == nil)
end)
Case("auto push restores an already disabled value and on module disable", function()
    for _, original in ipairs({ "0", "1" }) do
        local cvars, account = { AutoPushSpellToActionBar = original }, {}
        local S = Session({ enabled = true, stopAutoPushSpells = true }, account, cvars)
        S.Set("enabled", false)
        assert(cvars.AutoPushSpellToActionBar == original and account.autoPushSpellCVar == nil)
    end
end)
Case("Blizzard cannot re-enable auto push while the switch is on", function()
    local cvars = { AutoPushSpellToActionBar = "1" }
    local S, log = Session({ enabled = true, stopAutoPushSpells = true }, {}, cvars)
    local watcher = log.frames[#log.frames]
    assert(watcher.events.CVAR_UPDATE)
    cvars.AutoPushSpellToActionBar = "1"
    watcher.onEvent(watcher, "CVAR_UPDATE", "AutoPushSpellToActionBar")
    assert(cvars.AutoPushSpellToActionBar == "0")
    S.Set("stopAutoPushSpells", false)
    assert(not watcher.events.CVAR_UPDATE and cvars.AutoPushSpellToActionBar == "1")
end)
Case("missing auto push CVar is never written", function()
    local S, log = Session({ enabled = true, stopAutoPushSpells = true }, {}, {})
    S.Set("stopAutoPushSpells", false)
    assert(log.cvarWrites == 0)
end)
print(count .. " UI clutter regressions passed")
