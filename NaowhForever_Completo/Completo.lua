-- Completo.lua: Completo's settings and its module table (ns.Completo).
local ns = _G.NaowhForever

local F = ns.FEATURES.completo

local S = ns.UI.ModuleSettings("completo", {
    enabled = F.enabled, hideDone = false, windowAlpha = 1, windowScale = 1,
    mapPins = F.mapPins, mapGrey = false, mapChainsOnly = false, mapPinSize = 18,
    rareHideKilled = false, rareAlert = F.rareAlert, rareAlertKilled = false,
    rareSound = true, rareSoundKey = "file:gruntlinghorn", rareAlertPosition = nil, rareAlertScale = 1,
    rareAlertTime = 20, rareAlertFont = "", rareAlertFontSize = 13, rareAlertOutline = "",
    rareAlertBackground = "card", rareAlertGlow = false,
    rarePins = F.rarePins, rarePinsKilled = false, rarePinSize = 18,
})
ns.CompletoSettings = S

local Completo = { Settings = S }
ns.Completo = Completo

function Completo.CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end
