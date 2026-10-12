-- DamageMeterLayout.lua: the game's damage meter Bar Height, set in the active Edit Mode layout without opening Edit Mode.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Settings = ns.Shared.Settings

local BAR_MIN, BAR_MAX, BAR_DEFAULT = 15, 40, 20
local BAR_RANGE = { BAR_MIN, BAR_MAX, 1 }
local DEBOUNCE = 0.5
local BACKUP_KEY = "damageMeterLayoutBackup"
local TEXT_COMBAT = "Damage Meter Layout: not in combat."
local TEXT_NO_EDIT_MODE = "Damage Meter Layout: the game's layouts are not available."
local TEXT_EDIT_MODE_OPEN = "Damage Meter Layout: close Edit Mode first."
local TEXT_PRESET = "Damage Meter Layout: your active layout is one of the game's own. Make a copy in Edit Mode first."
local TEXT_NO_SYSTEM = "Damage Meter Layout: this layout has no damage meter."
local TEXT_FAILED = "Damage Meter Layout: the game would not save the layout (%s)."
local TEXT_SAVED = "Damage Meter Layout: Bar Height %d saved. If the bars have not changed, /reload."
local TEXT_NO_BACKUP = "Damage Meter Layout: no backup yet; one is made before the first change."
local TEXT_BACKUP_TITLE = "Edit Mode layout backup: %s"

local pending = 0
local backedUp = false

local function Has(object, method)
    return type(object) == "table" and type(object[method]) == "function"
end

local function Manager()
    local frame = _G.EditModeManagerFrame
    if type(frame) == "table" and type(frame.layoutInfo) == "table" then return frame end
end

local function ActiveLayout(info)
    local layouts = info.layouts
    local layout = type(layouts) == "table" and layouts[info.activeLayout] or nil
    if type(layout) == "table" then return layout end
end

local function SystemOf(layout)
    if type(layout.systems) ~= "table" then return nil end
    for _, system in ipairs(layout.systems) do
        if system.system == Enum.EditModeSystem.DamageMeter then return system end
    end
end

local function EntryOf(system)
    if type(system.settings) ~= "table" then return nil end
    for _, entry in ipairs(system.settings) do
        if entry.setting == Enum.EditModeDamageMeterSetting.BarHeight then return entry end
    end
end

local function Clamp(height)
    if height < BAR_MIN then return BAR_MIN end
    if height > BAR_MAX then return BAR_MAX end
    return height
end

local function HeightOf(system)
    local entry = EntryOf(system)
    if entry and type(entry.value) == "number" then return Clamp(entry.value + BAR_MIN) end
    return BAR_DEFAULT
end

local function CurrentHeight()
    local frame = Manager()
    local layout = frame and ActiveLayout(frame.layoutInfo)
    local system = layout and SystemOf(layout)
    if system then return HeightOf(system) end
    return BAR_DEFAULT
end

local function Backup(layout)
    if backedUp or not (C_EditMode and C_EditMode.ConvertLayoutInfoToString) then return end
    backedUp = true
    local ok, text = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
    if ok and type(text) == "string" then
        ns.AccountSettings()[BACKUP_KEY] = { name = layout.layoutName, text = text }
    end
end

local function Write(system, height)
    local entry = EntryOf(system)
    if entry then
        entry.value = height - BAR_MIN
        return
    end
    system.settings = system.settings or {}
    system.settings[#system.settings + 1] = { setting = Enum.EditModeDamageMeterSetting.BarHeight,
        value = height - BAR_MIN }
end

local function Change(height)
    if InCombatLockdown() then ns.Print(TEXT_COMBAT) return end
    local frame = Manager()
    if not (frame and C_EditMode and C_EditMode.SaveLayouts) then ns.Print(TEXT_NO_EDIT_MODE) return end
    if Has(frame, "IsShown") and frame:IsShown() then ns.Print(TEXT_EDIT_MODE_OPEN) return end
    local info = CopyTable(frame.layoutInfo)
    local layout = ActiveLayout(info)
    if not layout then ns.Print(TEXT_NO_EDIT_MODE) return end
    if layout.layoutType == Enum.EditModeLayoutType.Preset then ns.Print(TEXT_PRESET) return end
    local system = SystemOf(layout)
    if not system then ns.Print(TEXT_NO_SYSTEM) return end
    height = Clamp(height)
    if height == HeightOf(system) and EntryOf(system) then return end
    Backup(layout)
    Write(system, height)
    local ok, err = pcall(C_EditMode.SaveLayouts, info)
    if ok then
        ns.Print(TEXT_SAVED:format(height))
    else
        ns.Print(TEXT_FAILED:format(tostring(err)))
    end
end

local function Request(height)
    pending = pending + 1
    local token = pending
    C_Timer.After(DEBOUNCE, function()
        if token == pending then Change(height) end
    end)
end

local function ShowBackup()
    local saved = ns.AccountSettings()[BACKUP_KEY]
    if type(saved) ~= "table" then
        ns.Print(TEXT_NO_BACKUP)
        return
    end
    ns.ShowCopyBox(TEXT_BACKUP_TITLE:format(tostring(saved.name)), saved.text)
end

Settings.Page("QoL/Combat", S):Card({
    id = "damageMeterLayout", name = "Damage Meter Layout", order = 112,
    help = "The game's damage meter Bar Height, set here instead of in Edit Mode.",
    rows = {
        { label = "Bar Height", slider = BAR_RANGE, unit = "px", get = CurrentHeight, set = Request,
          help = "Saved in your active Edit Mode layout, which must be one of your own." },
        { label = "Layout Backup", buttonText = "Copy", button = ShowBackup,
          help = "Your layout as it was before the first change, to import in Edit Mode." },
    },
})
