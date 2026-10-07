-------------------------------------------------------------------------------
--  NaowhForever_Defaults.lua -- QoL > System > Defaults: one button that puts the profile in use
--  back to the setup a new install starts from (ns.STARTER), then offers the reload. Smart
--  Reminders, what you answered about EllesmereUI's windows and the account's data stay.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local S = ns.QoLSettings

local ASK = "Reset every setting and position to Naowh's defaults? Smart Reminders and your BiS lists stay. "
    .. "Cannot be undone."
local DONE = "Every setting is back to Naowh's defaults. Reload now to finish?"
local RIVALS = { "characterPanel", "inspectPanel" }

function ns.ResetToStarter()
    local root = ns.SettingsRoot()
    local qol = type(root.qol) == "table" and root.qol or {}
    local own, was = {}, {}
    for _, key in ipairs(ns.PROFILE_OWN.qol) do own[key] = qol[key] end
    for _, key in ipairs(RIVALS) do was[key] = S.Get(key) end
    for key in pairs(root) do
        if key ~= "tankReminder" then root[key] = nil end
    end
    for key, values in pairs(ns.STARTER.profile) do root[key] = CopyTable(values) end
    if type(root.qol) ~= "table" then root.qol = {} end
    for key, value in pairs(own) do root.qol[key] = value end
    for _, key in ipairs(RIVALS) do
        if S.Get(key) ~= was[key] then S.Set(key, S.Get(key)) end
    end
end

local function Reset()
    ns.Confirm(ASK, function()
        ns.ResetToStarter()
        ns.ConfirmReload(DONE)
    end, nil, "Reset")
end

ns.Shared.Settings.Page("QoL/System", S):Card({
    id = "defaults", name = "Defaults", order = 90,
    help = "Puts every setting and position back to the setup a new install starts with.",
    summary = function() return "Naowh's setup" end,
    rows = {
        { label = "Reset All Settings", buttonText = "Reset", button = Reset, always = true,
          help = "Smart Reminders, BiS lists, notes and the Macro Library are kept." },
    },
})
