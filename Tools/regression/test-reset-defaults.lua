-- Regression: QoL > System > Defaults resets the profile in use to the starter (ns.STARTER):
-- every module's settings and positions, keeping Smart Reminders and what this player answered
-- about EllesmereUI's windows, telling the character and inspect panels so they swap back, and
-- offering the reload. Run from the repo root: lua5.1 Tools/regression/test-reset-defaults.lua
local passed = 0
local function check(name, ok)
    if not ok then error("FAIL " .. name, 2) end
    passed = passed + 1
end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

local root = {
    qol = { characterPanel = true, fastLoot = false, characterPanelAsked = true, characterPanelTookOver = true,
        lootFeedPos = { point = "TOP", x = 1, y = 2 } },
    topBar = { use24h = false, extra = 5 },
    tankReminder = { leadTime = 9 },
    oldModule = { x = 1 },
}
local STARTER = { profile = {
    qol = { characterPanel = false, lootFeedPos = { point = "CENTER", x = 0, y = -124 } },
    topBar = { use24h = true },
    auraBuffs = { iconSize = 48 },
} }
local QOL_DEFAULTS = { characterPanel = true, inspectPanel = true }
local sets = {}
local S = {}
function S.Get(k)
    local v = root.qol and root.qol[k]
    if v == nil then return QOL_DEFAULTS[k] end
    return v
end
function S.Set(k, v)
    root.qol[k] = v
    sets[#sets + 1] = k .. "=" .. tostring(v)
end
local card, asked, reload
local ns = {
    QoLSettings = S, STARTER = STARTER,
    PROFILE_OWN = { qol = { "characterPanelAsked", "characterPanelTookOver", "inspectPanelAsked", "inspectPanelTookOver" } },
    SettingsRoot = function() return root end,
    Confirm = function(text, yes) asked = text; yes() end,
    ConfirmReload = function(text) reload = text end,
    Shared = { Settings = { Page = function(key)
        return { Card = function(_, c) c.page = key; card = c end }
    end } },
}
local env = setmetatable({ _G = { NaowhForever = ns }, CopyTable = Copy }, { __index = _G })
local chunk = assert(loadfile("QoL/NaowhForever_Defaults.lua"))
setfenv(chunk, env)
chunk()

check("the card sits on QoL > System with one Reset button", card and card.page == "QoL/System"
    and card.rows[1].buttonText == "Reset" and card.rows[1].always == true)
card.rows[1].button()
check("it asks first", asked and asked:find("Cannot be undone", 1, true))
check("every module back to the starter", root.qol.fastLoot == nil and root.topBar.use24h == true
    and root.topBar.extra == nil and root.auraBuffs.iconSize == 48 and root.oldModule == nil)
check("positions too", root.qol.lootFeedPos.point == "CENTER" and root.qol.lootFeedPos.y == -124)
check("Smart Reminders kept", root.tankReminder.leadTime == 9)
check("what you answered about EllesmereUI's windows kept", root.qol.characterPanelAsked == true
    and root.qol.characterPanelTookOver == true)
check("the character panel told it changed, the inspect panel not", #sets == 1 and sets[1] == "characterPanel=false")
check("a reload offered", reload and reload:find("Reload", 1, true))
root.qol.lootFeedPos.y = 5
check("a copy: the starter itself untouched", STARTER.profile.qol.lootFeedPos.y == -124)

print(("test-reset-defaults: %d checks passed"):format(passed))
