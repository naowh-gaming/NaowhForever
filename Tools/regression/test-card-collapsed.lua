-- Run with Lua 5.1 from the repository root: which settings card opens by itself (Settings.IsOpen).
-- A page's only card does, and so does its first card when it has a live preview, unless the card
-- says collapsed = true (the Crosshair, so the Cursor & Crosshair tab opens folded). A card
-- someone opened or folded stays as they left it.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = { THEME = {}, L = function(text) return text end, Color = function(_, text) return text end,
    Shared = { Style = dofile("Tools/regression/shared_style.lua") }, UI = {} }
local env = setmetatable({ _G = { NaowhForever = ns } }, { __index = _G })
local chunk = assert(loadfile("Shared/Settings/Settings.lua"))
setfenv(chunk, env)
chunk()

local Settings = ns.Shared.Settings
local store = { Get = function() end, Set = function() end }
local studio = { height = 10, states = {}, new = function() end, paint = function() end }
local function Row(key) return { key = key, label = key, toggle = true } end

local preview = Settings.Page("Test/Preview", store):Card({ id = "a", name = "A", order = 1, studio = studio, rows = { Row("a") } })
Settings.Page("Test/Preview", store):Card({ id = "b", name = "B", order = 2, rows = { Row("b") } })
Check(Settings.IsOpen(preview), "a first card with a live preview opens by itself")

local folded = Settings.Page("Test/Folded", store):Card({ id = "a", name = "A", order = 1, studio = studio, collapsed = true,
    rows = { Row("a") } })
Settings.Page("Test/Folded", store):Card({ id = "b", name = "B", order = 2, rows = { Row("b") } })
Check(not Settings.IsOpen(folded), "unless it says collapsed")

Settings.SetOpen(folded, true)
Check(Settings.IsOpen(folded), "and once opened it stays open")
Settings.SetOpen(folded, false)
Check(not Settings.IsOpen(folded), "and folded again")

local only = Settings.Page("Test/Only", store):Card({ id = "a", name = "A", rows = { Row("a") } })
Check(Settings.IsOpen(only), "a page's only card opens")

print(("test-card-collapsed: %d checks passed"):format(checks))
