-- LayerTracker.lua: Layer Tracker, the layer you are on, read from the NPCs around you.
local ns = _G.NaowhForever

local UnitGUID = UnitGUID
local strsplit = strsplit
local issecretvalue = issecretvalue

local S = ns.QoLSettings
local UI = ns.UI
local Parts = ns.Shared.Parts
local Settings = ns.Shared.Settings

local NPC_KINDS = { Creature = true, Vehicle = true }
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "SHARD_TRANSFER",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
}
local WIDTH_PER_SIZE, ROOM = 7, 8
local DEFAULT_POS = { point = "TOP", relPoint = "TOP", x = -274, y = -77 }
local TEXT_RANGE = { 10, 40, 1 }
local MOVER_LABEL = "Layer Tracker"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Questing & Group", "QoL/Questing & Group:layerTracker"
local TEXT_LAYER = ns.L("Layer %s")
local TEXT_UNKNOWN = "?"

local events, frame
local layer, inside, unlocked

local function On()
    return S.Get("enabled") and S.Get("layerTracker")
end

local function LayerOf(guid)
    if type(guid) ~= "string" or issecretvalue(guid) then return end
    local kind, _, _, _, zone = strsplit("-", guid)
    if not NPC_KINDS[kind] then return end
    zone = tonumber(zone)
    if zone and zone > 0 then return zone end
end

local function Update()
    if inside and not unlocked then
        frame:Hide()
        return
    end
    frame.text:SetText(TEXT_LAYER:format(layer or TEXT_UNKNOWN))
    frame:Show()
end

local function Read(unit, replace)
    if inside or (layer and not replace) then return end
    local seen = LayerOf(UnitGUID(unit))
    if not seen or seen == layer then return end
    layer = seen
    Update()
end

local function Forget()
    layer = nil
    Update()
end

local function OnEvent(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if not (layer or issecretvalue(unit)) then Read(unit) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        Read("target", true)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Read("mouseover", true)
    elseif event == "PLAYER_ENTERING_WORLD" then
        inside = IsInInstance()
        Forget()
        Read("target", true)
    else
        Forget()
    end
end

local function SavePosition(pos)
    S.Set("layerTrackerPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverLayerTracker", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.backdrop = Parts.HudBackdrop(frame)
    frame.text = ns.Font(frame, S.Get("layerTrackerFontSize"), "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    frame:Hide()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

local function Place()
    local pos = S.Get("layerTrackerPos") or DEFAULT_POS
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function Restyle()
    local size = S.Get("layerTrackerFontSize")
    local mode = frame.backdrop:SetMode(S.Get("layerTrackerBackground"))
    Parts.HudFont(frame.text, S.Get("layerTrackerFont"), size, S.Get("layerTrackerOutline"), mode)
    frame:SetSize(size * WIDTH_PER_SIZE, size + ROOM)
end

local function Apply()
    if not On() then
        layer = nil
        if frame then
            events:UnregisterAllEvents()
            frame:Hide()
        end
        return
    end
    if not frame then Build() end
    Restyle()
    Place()
    frame.mover:SetShown(unlocked == true)
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    inside = IsInInstance()
    Read("target", true)
    Update()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^layerTracker") and key ~= "layerTrackerPos") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

Settings.Page(SETTINGS_PAGE, S):Card({
    id = "layerTracker", name = "Layer Tracker", order = 27, switch = "layerTracker",
    help = "Shows which layer you are on, read from the NPCs around you.",
    rows = Settings.Look("layerTracker", { text = true, size = TEXT_RANGE, background = "card" }),
})
