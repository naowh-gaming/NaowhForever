-- Offline behavior checks for the Damage Meter Layout (NaowhForever_QoL/Combat/DamageMeterLayout.lua) against a stub of
-- the game's Edit Mode manager and C_EditMode; they do not emulate the client. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

local function Info(active)
    return { activeLayout = active or 3, layouts = {
        { layoutName = "Modern", layoutType = 0, systems = {} },
        { layoutName = "Classic", layoutType = 0, systems = {} },
        { layoutName = "Mine", layoutType = 1, systems = {
            { system = 1, settings = { { setting = 0, value = 9 } } },
            { system = 23, settings = { { setting = 10, value = 5 }, { setting = 11, value = 3 } } } } },
    } }
end

local function Boot(opts)
    opts = opts or {}
    local s = { printed = {}, saves = {}, timers = {}, converts = 0, copies = {}, account = {} }
    local ns = { QoLSettings = {}, Print = function(text) s.printed[#s.printed + 1] = text end,
        AccountSettings = function() return s.account end,
        ShowCopyBox = function(title, text) s.copies[#s.copies + 1] = { title = title, text = text } end,
        Shared = { Settings = { Page = function()
            return { Card = function(_, def) s.card = def end }
        end } } }
    s.manager = { layoutInfo = opts.info or Info(), IsShown = function() return s.editOpen == true end }
    local env = { ipairs = ipairs, pairs = pairs, type = type, pcall = pcall, tostring = tostring,
        NaowhForever = ns, CopyTable = Copy,
        Enum = { EditModeSystem = { DamageMeter = 23 }, EditModeDamageMeterSetting = { BarHeight = 10 },
            EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 } },
        InCombatLockdown = function() return s.combat == true end,
        C_Timer = { After = function(_, fn) s.timers[#s.timers + 1] = fn end },
        C_EditMode = { SaveLayouts = function(info)
                if s.saveError then error(s.saveError) end
                s.saves[#s.saves + 1] = info
            end,
            ConvertLayoutInfoToString = function(layout)
                s.converts = s.converts + 1
                return "export:" .. layout.layoutName
            end } }
    env._G = env
    if not opts.noManager then env.EditModeManagerFrame = s.manager end
    local chunk = assert(loadfile("NaowhForever_QoL/Combat/DamageMeterLayout.lua"))
    setfenv(chunk, env)
    chunk("NaowhForever")
    function s.Flush()
        local list = s.timers
        s.timers = {}
        for _, fn in ipairs(list) do fn() end
    end
    s.slider = s.card.rows[1]
    s.copy = s.card.rows[2]
    return s
end

-- the card
do
    local s = Boot()
    check("one card, with a slider of the game's range and a backup button", s.card.id == "damageMeterLayout"
        and s.slider.slider[1] == 15 and s.slider.slider[2] == 40 and s.slider.label == "Bar Height"
        and type(s.copy.button) == "function")
    check("help is short", #s.card.help < 100 and #s.slider.help < 100 and #s.copy.help < 100)
    check("the slider shows the layout's value: stored 5 is 20", s.slider.get() == 20)
end

-- a change is written into a copy, once, after a pause
do
    local s = Boot()
    local original = Copy(s.manager.layoutInfo)
    s.slider.set(24); s.slider.set(26); s.slider.set(30)
    check("nothing is written while the slider moves", #s.saves == 0)
    s.Flush()
    check("one save, with the last value", #s.saves == 1)
    local saved = s.saves[1]
    local system = saved.layouts[3].systems[2]
    check("the value is stored from the minimum: 30 is 15", system.settings[1].setting == 10 and system.settings[1].value == 15)
    check("the other settings and systems are as they were", system.settings[2].value == 3
        and saved.layouts[3].systems[1].settings[1].value == 9 and saved.activeLayout == 3 and #saved.layouts == 3)
    check("the game's own table is not touched", s.manager.layoutInfo.layouts[3].systems[2].settings[1].value == 5
        and saved ~= s.manager.layoutInfo)
    check("a backup of the layout, as it was", s.account.damageMeterLayoutBackup.text == "export:Mine"
        and s.account.damageMeterLayoutBackup.name == "Mine" and s.converts == 1)
    check("and a line that says so", #s.printed == 1 and s.printed[1]:find("30", 1, true) ~= nil)
    s.manager.layoutInfo.layouts[3].systems[2].settings[1].value = 15
    s.slider.set(35); s.Flush()
    check("a second change is a second save, with no second backup", #s.saves == 2 and s.converts == 1)
    check("the layout the game gave is unchanged after it all", Copy(original).layouts[1].layoutName == "Modern")
end

-- the same height is not saved again, and the range is held
do
    local s = Boot()
    s.slider.set(20); s.Flush()
    check("the height it already has: nothing to save", #s.saves == 0)
    s.slider.set(100); s.Flush()
    check("too tall is the tallest: 40 is 25", s.saves[1].layouts[3].systems[2].settings[1].value == 25)
    s.slider.set(1); s.Flush()
    check("too short is the shortest: 15 is 0", s.saves[2].layouts[3].systems[2].settings[1].value == 0)
end

-- a layout that never set it gets the entry
do
    local info = Info()
    info.layouts[3].systems[2].settings = { { setting = 11, value = 3 } }
    local s = Boot({ info = info })
    check("no entry yet: the game's default height is shown", s.slider.get() == 20)
    s.slider.set(28); s.Flush()
    local settings = s.saves[1].layouts[3].systems[2].settings
    check("and it is added, the others kept", #settings == 2 and settings[2].setting == 10 and settings[2].value == 13
        and settings[1].value == 3)
end

-- what it will not do
do
    local s = Boot()
    s.combat = true
    s.slider.set(30); s.Flush()
    check("in combat: not saved, said", #s.saves == 0 and #s.printed == 1)
    s.combat = false
    s.editOpen = true
    s.slider.set(30); s.Flush()
    check("with Edit Mode open: not saved, said", #s.saves == 0 and #s.printed == 2)
    s.editOpen = false
    s.manager.layoutInfo.activeLayout = 1
    s.slider.set(30); s.Flush()
    check("on one of the game's own layouts: not saved, said", #s.saves == 0 and #s.printed == 3
        and s.printed[3]:find("copy", 1, true) ~= nil and s.converts == 0)
    s.manager.layoutInfo.activeLayout = 2
    check("and the slider still reads without an error", s.slider.get() == 20)
    s.manager.layoutInfo.activeLayout = 9
    s.slider.set(30); s.Flush()
    check("an active layout that is not there: not saved, said", #s.saves == 0 and #s.printed == 4)
    s.manager.layoutInfo.activeLayout = 3
    s.manager.layoutInfo.layouts[3].systems[2] = nil
    s.slider.set(30); s.Flush()
    check("a layout without a damage meter: not saved, said", #s.saves == 0 and #s.printed == 5)
end

do
    local s = Boot({ noManager = true })
    check("no manager: the slider reads the default", s.slider.get() == 20)
    s.slider.set(30); s.Flush()
    check("and says so, saving nothing", #s.saves == 0 and #s.printed == 1)
end

-- the game refuses
do
    local s = Boot()
    s.saveError = "protected"
    s.slider.set(30); s.Flush()
    check("a refused save is said, with the reason", #s.printed == 1 and s.printed[1]:find("protected", 1, true) ~= nil)
end

-- the backup button
do
    local s = Boot()
    s.copy.button()
    check("no backup yet: said", #s.copies == 0 and #s.printed == 1)
    s.slider.set(30); s.Flush()
    s.copy.button()
    check("after a change: the copy box has the layout string", #s.copies == 1 and s.copies[1].text == "export:Mine"
        and s.copies[1].title:find("Mine", 1, true) ~= nil)
end

print("PASS damage meter layout: " .. checks .. " checks")
