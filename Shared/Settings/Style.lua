-- Style.lua: the look of a settings page that its controls, rows and page share (ns.Shared.Settings.Style).
local Shared = _G.NaowhForever.Shared

Shared.Settings.Style = setmetatable({
    PAD = 14,
    CONTROL_GAP = 8,
    CONTROL_LEVEL = 2,
    RULE_ALPHA = 0.6,
}, { __index = Shared.Style })
