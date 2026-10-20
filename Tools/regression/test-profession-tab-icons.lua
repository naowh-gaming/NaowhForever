-- Run with Lua 5.1 from the repository root: the profession window's docked Blizzard parts stay readable:
-- the Unlearn button shows a red cross even where its atlas is missing, and the tabs keep Blizzard's look.
local f = assert(io.open(arg[1] or "NaowhForever_Professions/UI/Takeover.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

local ATLAS, FALLBACK = "Profession-button-red-crossmark", "Interface/RAIDFRAME/ReadyCheck-NotReady"
local function Env(atlasKnown)
    local env = {
        UNLEARN_ATLAS = ATLAS, UNLEARN_FALLBACK = FALLBACK, UNLEARN_SIZE = 20,
        C_Texture = { GetAtlasInfo = function(name) return atlasKnown and name == ATLAS and {} or nil end },
    }
    setmetatable(env, { __index = _G })
    local code = Slice("local function ShowUnlearn(", "\nlocal function DockTabs(") .. "\nreturn ShowUnlearn"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    return chunk()
end
local function Icon()
    return { SetTexture = function(self, t) self.texture = t end,
        SetSize = function(self, w, h) self.w, self.h = w, h end,
        SetAlpha = function(self, a) self.alpha = a end }
end
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("an Unlearn button without its atlas gets the red cross texture", function()
    local Show = Env(false)
    local button = { Icon = Icon() }
    Show(button)
    assert(button.Icon.texture == FALLBACK and button.Icon.w == 20 and button.Icon.h == 20 and button.Icon.alpha == 1)
end)
Case("with its atlas it keeps it, at a size and strength that can be seen", function()
    local Show = Env(true)
    local button = { Icon = Icon() }
    Show(button)
    assert(button.Icon.texture == nil and button.Icon.w == 20 and button.Icon.alpha == 1)
end)
Case("a button with no icon is left alone", function()
    local Show = Env(true)
    Show({})
end)
Case("the docked tabs get no outline of ours", function()
    assert(not Slice("local function DockTabs(", "\nlocal function Place("):find("Border", 1, true))
    assert(not source:find("OutlineTab", 1, true))
end)
Case("docking restyles the Unlearn button", function()
    assert(Slice("local function DockCards(", "\nlocal function DockBook(")
        :find("ShowUnlearn(blizz.UnlearnButton)", 1, true))
end)
print(count .. " profession tab icon regressions passed")
