-- Run with Lua 5.1 from the repository root: New Herbs and Ores (UI/NodeToast.lua) and the shared toast
-- (Shared/UI/Toast.lua) under it and under Training's Level-Up Toast. A Mining skill-up that reaches new veins
-- names them, with one icon per ore, and the toast goes by itself after 20 seconds unless dragged; logging in,
-- learning a profession, the same skill again or a bonus coming and going shows nothing. The Level-Up Toast
-- keeps its frame name, buttons, saved place and timer on the shared part.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local timers = {}
local frames = {}
local boot, skillEvents, levelEvents

local regionMethods = {
    SetText = function(r, text) r.text = text end,
    GetStringHeight = function() return 14 end,
    SetTexture = function(r, texture) r.texture = texture end,
    SetShown = function(r, on) r.shown = on and true or false end,
    Show = function(r) r.shown = true end,
    Hide = function(r) r.shown = false end,
    SetHeight = function(r, h) r.height = h end,
    SetWidth = function(r, w) r.width = w end,
    SetPoint = function(r, point, rel, relPoint, x, y) r.point = { point, rel, relPoint, x, y } end,
    SetScript = function(r, name, fn) r[name] = fn end,
    RegisterEvent = function(r, event)
        r.events = r.events or {}
        r.events[event] = true
        if event == "PLAYER_LOGIN" then boot = boot or {}; boot[#boot + 1] = r end
        if event == "SKILL_LINES_CHANGED" then skillEvents = r end
        if event == "PLAYER_LEVEL_UP" then levelEvents = r end
    end,
    UnregisterAllEvents = function(r) r.events = {} end,
}
local regionMeta = { __index = function(_, k)
    if regionMethods[k] then return regionMethods[k] end
    if k:find("^%u") then return Noop end
end }
local function Region() return setmetatable({}, regionMeta) end
regionMethods.CreateTexture = function() return Region() end

local function CreateFrame(_, name)
    local f = Region()
    if name then frames[name] = f end
    return f
end

local store = {}
local function Store(values)
    local S = { values = values }
    function S.Get(k) return S.values[k] end
    function S.Set(k, v) S.values[k] = v end
    function S.OnChange(fn) S.changed = fn end
    return S
end

local skills = { ore = 50, herb = 0 }
local S = Store({ enabled = true, nodeToast = true })
local trainingS = Store({ enabled = true, levelUpToast = true, toastPos = { point = "CENTER", relPoint = "CENTER", x = 5, y = 6 } })
local setHook
local buttons = {}
local accented = {}
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    THEME = { bg = {}, accent = {} },
    MEDIA = "Interface\\AddOns\\NaowhForever\\Core\\Media\\",
    Apply = Noop,
    UI = { CenterPosition = function() return { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 } end },
    Solid = function() return Region() end,
    Border = Noop,
    Font = function() return Region() end,
    Button = function(_, text, _, _, click)
        local b = Region()
        b.label, b.click = text, click
        buttons[#buttons + 1] = b
        return b
    end,
    AccentBorder = function(b) accented[b] = true return b end,
    Shared = { Parts = {}, Style = { BACKDROP_ALPHA = 0.97, ICON_CROP = 0.08, ICON_CROP_HIGH = 0.92 } },
    Professions = { Settings = S },
    Training = {
        Settings = trainingS, C = { ENTRY_SPELL = 2 },
        On = function() return true end,
        Plan = function() return { now = { { 1, 133 }, { 1, 168 } } } end,
        Total = function() return 300 end,
        Price = function() return 150 end,
        Coins = function(c) return c .. "c" end,
        WaypointToTrainer = function() store.waypoint = true end,
    },
}

local env = setmetatable({
    NaowhForever = ns,
    UIParent = Region(),
    CreateFrame = CreateFrame,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    GetMoney = function() return 1000 end,
    C_Timer = { After = function(seconds, fn) timers[#timers + 1] = { seconds = seconds, fn = fn } end },
    C_Item = { GetItemIconByID = function(id) return "item:" .. id end },
    C_Spell = { GetSpellTexture = function(id) return "spell:" .. id end },
    GetProfessions = function() return skills.ore > 0 and 1 or nil, skills.herb > 0 and 2 or nil end,
    GetProfessionInfo = function(index)
        if index == 1 then return "Mining", nil, skills.ore, 300, nil, nil, 186, skills.oreBonus or 0 end
        return "Herbalism", nil, skills.herb, 300, nil, nil, 182, 0
    end,
    hooksecurefunc = function(target, name, fn)
        if target == S and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env
ns.OpenTrainingWindow = function() store.planner = true end

Load({
    "Shared/UI/Toast.lua",
    "NaowhForever_Professions/Data/GatherNodes.lua",
    "NaowhForever_Professions/NodeScan.lua",
    "NaowhForever_Professions/UI/NodeToast.lua",
    "NaowhForever_Training/UI/Toast.lua",
}, env)

for _, f in ipairs(boot) do f.OnEvent(f, "PLAYER_LOGIN") end
check("logging in shows no toast", frames.NaowhForeverNodeToast == nil)
check("it listens for skill changes", skillEvents and skillEvents.events.SKILL_LINES_CHANGED)

local function SkillUp()
    skillEvents.OnEvent(skillEvents, "SKILL_LINES_CHANGED")
    return frames.NaowhForeverNodeToast
end

skills.ore = 75
local toast = SkillUp()
check("Mining 50 to 75 shows the toast", toast and toast.shown)
check("titled with the new skill", toast.title.text == "Mining 75")
check("naming the veins it reached, lowest first", toast.line.text
    == "You can now mine Incendicite Mineral Vein, Tin Vein, Lesser Bloodstone Deposit, Ooze Covered Silver Vein and Silver Vein.")
local shownIcons = {}
for _, icon in ipairs(toast.icons) do if icon.shown then shownIcons[#shownIcons + 1] = icon.texture end end
check("one icon per ore, not per vein", #shownIcons == 4)
check("Tin Ore's among them", (function()
    for _, t in ipairs(shownIcons) do if t == "item:2771" then return true end end
end)())
check("with a Dismiss button", buttons[1].label == "Dismiss")
check("it goes by itself after 20 seconds", timers[#timers].seconds == 20)
timers[#timers].fn()
check("and is gone then", toast.shown == false)

toast.shown = false
SkillUp()
check("the same skill again shows nothing", toast.shown == false)
skills.ore = 76
SkillUp()
check("a skill-up that reaches no new vein shows nothing", toast.shown == false)

skills.oreBonus = 50
SkillUp()
check("a Mining bonus reaching Iron Deposit counts", toast.shown and toast.line.text:find("Iron Deposit", 1, true))
toast.shown = false
skills.oreBonus = 0
SkillUp()
skills.oreBonus = 50
SkillUp()
check("but taking it off and on again shows it only once", toast.shown == false)

skills.herb = 1
SkillUp()
check("learning Herbalism shows nothing", toast.shown == false)
skills.herb = 50
SkillUp()
check("Herbalism 1 to 50 names its herbs", toast.shown and toast.title.text == "Herbalism 50"
    and toast.line.text == "You can now gather Earthroot and Mageroyal.")

toast.dragging = true
timers[#timers].fn()
check("a toast being dragged stays until it is let go", toast.shown == true)
toast.OnDragStop(toast)
check("then it goes", toast.shown == false)
check("and its place is kept", S.values.nodeToastPos and S.values.nodeToastPos.x == 1)

local out = {}
ns.Professions.NodeScan.Unlocked("ore", 0, 1, out)
check("Mining 1 unlocks the copper and amber veins", #out == 4 and out[1] == "Chunk of Amber")

S.values.nodeToast = false
setHook("nodeToast")
check("turning it off stops listening", next(skillEvents.events) == nil)

levelEvents.OnEvent(levelEvents, "PLAYER_LEVEL_UP", 12)
timers[#timers].fn()
local level = frames.NaowhForeverTrainingToast
check("the Level-Up Toast keeps its frame name", level and level.shown)
check("and its text", level.title.text == "Level 12" and level.line.text:find("2 spells to train", 1, true))
check("and its three buttons, Open Planner outlined", #level.buttons == 3 and accented[level.buttons[1]]
    and level.buttons[2].label == "Waypoint" and level.buttons[3].label == "Dismiss")
check("and its saved place", level.point[1] == "CENTER" and level.point[4] == 5 and level.point[5] == 6)
level.buttons[1].click()
check("Open Planner still opens the planner and hides the toast", store.planner and level.shown == false)
level.buttons[2].click()
check("Waypoint still sets the waypoint", store.waypoint)
check("and it still goes after 20 seconds", timers[#timers].seconds == 20)

print(("test-node-toast: %d checks passed"):format(checks))
