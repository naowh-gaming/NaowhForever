-- Run with Lua 5.1 from the repository root: RetireOldFolders cut out of Core/Core.lua and run on stubs.
-- An old module folder that moved into QoL is switched off at login; when it loaded this session too,
-- a reload is offered at once, so its code (the Top Bar's bar, with its secure buttons) never runs twice.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local f = assert(io.open("Core/Core.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()

local retired = assert(loadstring("return " .. assert(source:match("\nlocal RETIRED_ADDONS = (%b{})\n"), "RETIRED_ADDONS")))()
local text = assert(source:match('\nlocal TEXT_RETIRED = "([^"]+)"\n'), "TEXT_RETIRED")
local body = assert(source:match("\n(local function RetireOldFolders%(%)\n.-\nend)\n"), "RetireOldFolders")

local listed = {}
for _, addon in ipairs(retired) do listed[addon] = true end
check("the old Top Bar folder is retired", listed.NaowhForever_TopBar)
check("as are the old Glimmer folders", listed.NaowhForever_Glimmer and listed.NaowhForever_GlimmerData)
check("and the Top Bar ships no addon of its own", io.open("NaowhForever_TopBar/NaowhForever_TopBar.toc") == nil)

local function Run(exists, loaded)
    local w = { disabled = {}, printed = {}, reloads = {} }
    local ns = {
        L = function(s) return s end,
        Print = function(s) w.printed[#w.printed + 1] = s end,
        ConfirmReload = function(s) w.reloads[#w.reloads + 1] = s end,
    }
    local C_AddOns = {
        DoesAddOnExist = function(addon) return exists[addon] == true end,
        IsAddOnLoaded = function(addon) return loaded[addon] == true end,
        DisableAddOn = function(addon, who) w.disabled[addon] = who == nil end,
    }
    local chunk = assert(loadstring("local ns, C_AddOns, RETIRED_ADDONS, TEXT_RETIRED = ...\n" .. body
        .. "\nRetireOldFolders()"))
    chunk(ns, C_AddOns, retired, text)
    return w
end

local w = Run({}, {})
check("no old folder: nothing is switched off or said", next(w.disabled) == nil and #w.printed == 0 and #w.reloads == 0)

w = Run({ NaowhForever_TopBar = true }, {})
check("an old folder that did not load is switched off", w.disabled.NaowhForever_TopBar)
check("with a line in chat and no reload", #w.printed == 1 and w.printed[1] == text:format("NaowhForever_TopBar")
    and #w.reloads == 0)

w = Run({ NaowhForever_TopBar = true }, { NaowhForever_TopBar = true })
check("an old folder that loaded is switched off too", w.disabled.NaowhForever_TopBar)
check("and a reload is offered instead of the chat line", #w.reloads == 1
    and w.reloads[1] == text:format("NaowhForever_TopBar") and #w.printed == 0)

print(("test-retired-folders: %d checks passed"):format(checks))
