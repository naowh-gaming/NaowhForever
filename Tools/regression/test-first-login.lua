-- Run with Lua 5.1 from the repository root: the onboarding on an account's first login
-- (Core/Onboarding/FirstLogin.lua) on stub frames. Checks that it makes one frame at load; opens
-- the onboarding a few seconds after the first login, or after a reload while it is still unseen,
-- never during a loading screen, and waits for combat to end; once seen it never opens by itself
-- again; a new character with another's settings around is asked once; /nf welcome and /nf setup
-- open the onboarding.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local FIRST_LOGIN = "Core/Onboarding/FirstLogin.lua"

local Frame = {}
Frame.__index = Frame
local function NewFrame(made)
    local f = setmetatable({ scripts = {}, events = {} }, Frame)
    made[#made + 1] = f
    return f
end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:UnregisterAllEvents() self.events = {} end

local function Setup(account)
    local s = { account = account or {}, made = {}, timers = {}, combat = false, onboarding = 0 }
    local ns = {
        AccountSettings = function() return s.account end,
        ShowSetup = function() s.onboarding = s.onboarding + 1 end,
        MarkSeen = function() s.marked = (s.marked or 0) + 1 end,
        ImportCandidate = function() return s.candidate, s.candidate and "Raid" end,
        SwitchProfile = function(name) s.switched = name; return true end,
        Confirm = function(text, onYes, _, yes, no) s.confirm = { text = text, yes = onYes, yesText = yes, noText = no } end,
        Print = function(text) s.printed = text end,
    }
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function() return NewFrame(s.made) end,
        InCombatLockdown = function() return s.combat end,
        UnitName = function() return "Die Dudu" end,
        C_Timer = { NewTimer = function(delay, fn)
            local t = { delay = delay, fn = fn }
            t.Cancel = function(self) self.cancelled = true end
            s.timers[#s.timers + 1] = t
            return t
        end },
    }, { __index = _G })
    env._G = env
    local chunk = assert(loadfile(FIRST_LOGIN))
    setfenv(chunk, env)
    chunk()
    s.ns = ns
    s.login = s.made[1]
    return s
end

local function Event(s, event, ...)
    s.login.scripts.OnEvent(s.login, event, ...)
end

local function RunTimer(s)
    for i = #s.timers, 1, -1 do
        local t = s.timers[i]
        if not t.cancelled and not t.ran then
            t.ran = true
            t.fn()
            return t
        end
    end
end

-------------------------------------------------------------------------------
--  Nothing at load
-------------------------------------------------------------------------------
do
    local s = Setup()
    check("one frame at load, for the login check", #s.made == 1)
    check("it listens for the first world entry only", s.login.events.PLAYER_ENTERING_WORLD
        and not s.login.events.PLAYER_REGEN_ENABLED and not s.login.events.PLAYER_LEAVING_WORLD)
    check("the onboarding is not opened at load", s.onboarding == 0)
end

-------------------------------------------------------------------------------
--  The first login: a few seconds in, then once
-------------------------------------------------------------------------------
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("the first login waits a few seconds", #s.timers == 1 and s.timers[1].delay > 0 and s.onboarding == 0)
    RunTimer(s)
    check("then the onboarding opens", s.onboarding == 1)
    check("and it stops listening", next(s.login.events) == nil)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", false, true)
    RunTimer(s)
    check("a reload before it was seen (another addon's setup reloading over it): it opens again", s.onboarding == 1)
end
do
    local s = Setup({ welcomeSeen = true })
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("seen: the next login starts no timer and stops listening", #s.timers == 0
        and next(s.login.events) == nil and s.onboarding == 0)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", false, false)
    check("a world entry that is neither login nor reload does not start it", #s.timers == 0)
end

-------------------------------------------------------------------------------
--  Combat and loading screens
-------------------------------------------------------------------------------
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    s.combat = true
    RunTimer(s)
    check("in combat when due: nothing yet, waits for combat to end", s.onboarding == 0
        and s.login.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    Event(s, "PLAYER_REGEN_ENABLED")
    check("combat over: it opens", s.onboarding == 1 and next(s.login.events) == nil)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    local first = s.timers[1]
    Event(s, "PLAYER_LEAVING_WORLD")
    check("a loading screen before it is due puts it off", first.cancelled == true and s.onboarding == 0)
    Event(s, "PLAYER_ENTERING_WORLD", false, false)
    check("the world entry after it starts the wait again", #s.timers == 2 and not s.timers[2].cancelled)
    RunTimer(s)
    check("and it opens after", s.onboarding == 1)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    s.combat = true
    RunTimer(s)
    Event(s, "PLAYER_LEAVING_WORLD")
    check("waiting on combat, a loading screen stops the wait", not s.login.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    Event(s, "PLAYER_ENTERING_WORLD", false, false)
    RunTimer(s)
    check("and the next world entry opens it", s.onboarding == 1)
end

-------------------------------------------------------------------------------
--  A character's first login, the onboarding seen: another character's settings offered
-------------------------------------------------------------------------------
do
    local s = Setup({ welcomeSeen = true })
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("each login notes when the character was last played", s.marked == 1)
    check("no other character's settings to offer: nothing waits", #s.timers == 0 and s.confirm == nil)
end
do
    local s = Setup({ welcomeSeen = true })
    s.candidate = "Die Man-Forever"
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("a new character with another's settings around: a few seconds in", #s.timers == 1 and s.confirm == nil)
    s.combat = true
    RunTimer(s)
    check("not in combat", s.confirm == nil and s.login.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    Event(s, "PLAYER_REGEN_ENABLED")
    check("it says whose settings it found and asks", s.confirm and s.onboarding == 0
        and s.confirm.text == "Welcome, Die Dudu! We found settings from Die Man. Use them on this character too?"
        and s.confirm.yesText == "Use Them" and s.confirm.noText == "Not Now")
    check("asked once, then it stops listening", next(s.login.events) == nil)
    s.confirm.yes()
    check("yes: this character uses that profile, and it says so", s.switched == "Raid"
        and s.printed == "Die Dudu now uses the same settings as Die Man.")
end
do
    local s = Setup()
    s.candidate = "Die Man-Forever"
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    RunTimer(s)
    check("the onboarding not seen yet: it opens, not the offer", s.onboarding == 1 and s.confirm == nil)
end

-------------------------------------------------------------------------------
--  /nf welcome and /nf setup
-------------------------------------------------------------------------------
do
    local s = Setup({ welcomeSeen = true })
    local source = Read("Core/Commands.lua")
    local body = assert(source:match('SlashCmdList%["NAOWHFOREVER"%] = function%(msg%)\n(.-)\nend\n'),
        "the /nf handler")
    local env = setmetatable({ ns = s.ns, strtrim = function(t) return (t:gsub("^%s+", ""):gsub("%s+$", "")) end },
        { __index = _G })
    local handler = assert(loadstring("return function(msg)\n" .. body .. "\nend"))
    setfenv(handler, env)
    handler = handler()
    s.ns.ToggleOptionsWindow = function() s.toggled = true end
    handler("setup")
    check("/nf setup opens the onboarding, seen or not", s.onboarding == 1 and not s.toggled)
    handler(" Welcome ")
    check("/nf welcome too, as it did before the onboarding", s.onboarding == 2 and not s.toggled)
end

-------------------------------------------------------------------------------
--  Its words: no ask
-------------------------------------------------------------------------------
do
    local source = Read(FIRST_LOGIN):lower()
    for _, word in ipairs({ "support", "patreon", "badge", "donat" }) do
        check("no " .. word .. " anywhere in the file", not source:find(word, 1, true))
    end
end

print(("test-first-login: %d checks passed"):format(checks))
