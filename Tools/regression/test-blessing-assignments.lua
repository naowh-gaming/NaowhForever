-- Run with Lua 5.1 from the repository root: the Blessings window's grid draws a paladin's row you
-- may not change (a PallyPower paladin's, or anyone's while you do not lead) with icons that do
-- nothing on click, instead of erroring. The game's SetScript takes a function or nil, never false;
-- the stub below enforces that. Frames are stubs: this does not emulate the game's renderer.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local methods = {}
local frameMeta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^[A-Z]") then return methods.Nothing end
end }
local function New()
    return setmetatable({ scripts = {} }, frameMeta)
end
function methods.Nothing() end
function methods:SetScript(k, v)
    assert(v == nil or type(v) == "function", "Usage: self:SetScript(scriptTypeName [, script])")
    self.scripts[k] = v
end
function methods:CreateTexture() return New() end

rawset(_G, "CreateFrame", function() return New() end)
rawset(_G, "UIParent", New())
rawset(_G, "Ambiguate", function(name) return (name:gsub("%-.*", "")) end)
rawset(_G, "UnitGUID", function() return "Player-1" end)
rawset(_G, "GetTime", function() return 0 end)
rawset(_G, "RAID_CLASS_COLORS", { PALADIN = {} })

local cells = {}
local lead = false
local B = {
    Look = { ICON_CROP = 0.07, ICON_BORDER = {}, CLASS_ICON_PATH = "class-" },
    AURA_COLUMN = "AURA",
    CLASSES = { "WARRIOR", "MAGE" },
    AURAS = {}, BLESSINGS = {},
}
function B.CanAssign() return lead end
function B.IsPaladin() return false end
function B.Others()
    return {
        ["Holdout-Realm"] = { pallyPower = true, classes = { WARRIOR = "kings" }, known = {}, players = {} },
        ["Helper-Realm"] = { classes = { MAGE = "wisdom" }, known = {}, players = {} },
    }
end
function B.Roster() return {} end
function B.SpellIcon(key) return key end
function B.SpellName(key) return key end
function B.ClassName(class) return class end

local W = {}
function W.Note() return nil, 10 end
function W.SectionHeader() return nil, 10 end
function W.DualRow() return nil, 10 end

local ns = {
    Blessings = B,
    THEME = { muted = {} },
    L = function(text) return text end,
    Border = function() end,
    PixelInset = function() end,
    Tooltip = function(btn, title) btn.title = title end,
    UI = {
        CONTENT_PAD = 10,
        Widgets = W,
        Keep = function(_, key, make)
            local frame = make()
            if key == "cell" then cells[#cells + 1] = frame end
            return frame
        end,
        KeepFont = function() return New() end,
    },
}
rawset(_G, "NaowhForever", ns)
dofile("NaowhForever_Combat/Blessings/UI/Assignments.lua")

local function Build()
    for i = #cells, 1, -1 do cells[i] = nil end
    ns.BuildBlessingAssignmentsPage(New(), 0)
end

local function Clickable()
    local n = 0
    for _, cell in ipairs(cells) do
        if cell.scripts.OnClick then n = n + 1 end
    end
    return n
end

local columns = #B.CLASSES + 1
local headers = columns

check("the grid draws with a PallyPower paladin and you not leading", pcall(Build))
check("a header cell and every cell of both rows are drawn", #cells == headers + 2 * columns)
check("no cell is clickable when you may change no row", Clickable() == 0)

lead = true
check("the grid draws while you lead", pcall(Build))
check("leading, only the Naowh Forever paladin's row is clickable, never PallyPower's",
    Clickable() == columns)

print(("test-blessing-assignments: %d checks passed"):format(checks))
