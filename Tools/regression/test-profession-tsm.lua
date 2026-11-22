-- Run with Lua 5.1 from the repository root: TradeSkillMaster's crafting window. TSM's own TSM button sits
-- on Blizzard's window, which is at zero alpha under ours, so ours has its own. While TSM's window is up
-- ours steps aside, and TSM's UI callback brings it back.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local function Slice(source, from, to)
    local first = assert(source:find(from, 1, true), from)
    local last = assert(source:find("\nend\n", source:find(to, first, true), true), to)
    return source:sub(first, last + 4)
end

local source = Read("NaowhForever_Professions/UI/Takeover.lua")
local consts = assert(source:match('\n(local TSM_UI, TSM_TAG = [^\n]+)\n'))
local chunk = consts .. "\nlocal tsmHooked\n"
    .. Slice(source, "local function TsmShown()", "local function Update()")
    .. Slice(source, "local function OnTsmCrafting()", "local function Apply()")
    .. "return Update, Apply"

local calls, registered = {}, {}
local on, tsmShown, shown = true, false, true
local env = {
    On = function() return on end,
    Deactivate = function() calls[#calls + 1] = "off" end,
    Activate = function(mode) calls[#calls + 1] = mode end,
    Queue = function() calls[#calls + 1] = "queue" end,
    BookOpen = function() return false end,
    Links = { Viewing = function() return false end },
    R = { Linked = function() return false end, Own = function() return true end,
        Profession = function() return {} end },
    ProfessionsFrame = { IsShown = function() return shown end },
    EVENTS = {},
    events = { UnregisterAllEvents = function() end, RegisterEvent = function() end },
    OnEvent = function() end,
    C_AddOns = { IsAddOnLoaded = function() return true end },
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local Update, Apply = fn()

Update()
check("without TSM the window opens as before", calls[#calls] == "craft")

env.TSM_API = {
    IsUIVisible = function(name) return name == "CRAFTING" and tsmShown end,
    RegisterUICallback = function(name, tag, func) registered[#registered + 1] = { name, tag, func } end,
}
Update()
check("with TSM's window closed ours still opens", calls[#calls] == "craft")
tsmShown = true
Update()
check("with TSM's crafting window up ours steps aside", calls[#calls] == "off")

on = false
Apply()
check("turned off, nothing is registered with TSM", #registered == 0)
on = true
Apply()
Apply()
check("turned on, the crafting callback is registered once", #registered == 1)
check("for TSM's crafting window", registered[1][1] == "CRAFTING" and registered[1][2] ~= "")
calls = {}
registered[1][3](false)
check("TSM closing its window redraws ours", calls[1] == "queue")
on, calls = false, {}
registered[1][3](true)
check("turned off afterwards, TSM's callback does nothing", #calls == 0)

local button = Read("NaowhForever_Professions/UI/Tsm.lua")
local hide = assert(button:find("W.frame:Hide()", 1, true))
local run = assert(button:find("SlashCmdList.TSM(TSM_COMMAND)", 1, true))
local redraw = assert(button:find("ns.ProfWindowRefresh()", 1, true))
check("the button hides ours before TSM moves Blizzard's window", hide < run)
check("and redraws after, in case TSM did not open", run < redraw)
check("the button shows only with TSM loaded", button:find("TSM_API and SlashCmdList.TSM", 1, true))
check("the button is listed in Professions.xml",
    Read("NaowhForever_Professions/Professions.xml"):find('<Script file="UI\\Tsm.lua"/>', 1, true))

print(checks .. " profession TSM checks passed")
