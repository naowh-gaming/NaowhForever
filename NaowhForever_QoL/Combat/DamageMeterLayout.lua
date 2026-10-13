-- DamageMeterLayout.lua: the game's damage meter Bar Height, set in the active Edit Mode layout without opening Edit Mode.
local ns = _G.NaowhForever

local BAR_MIN, BAR_MAX, BAR_DEFAULT = 15, 40, 20
local BAR_RANGE = { BAR_MIN, BAR_MAX, 1 }
local DEBOUNCE, VERIFY = 0.5, 0.5
local BACKUP_KEY = "damageMeterLayoutBackup"
local TEXT_COMBAT = "Not in combat."
local TEXT_NO_EDIT_MODE = "The game's layouts are not available."
local TEXT_EDIT_MODE_OPEN = "Close Edit Mode first."
local TEXT_PRESET = "Your active layout is one of the game's own. Make a copy in Edit Mode first."
local TEXT_NO_SYSTEM = "This layout has no damage meter."
local TEXT_FAILED = "The game would not save the layout (%s)."
local TEXT_RELOAD = "Needs a /reload"
local TEXT_NO_BACKUP = "Nothing to restore yet: it remembers the height from before your first change."

local pending = 0
local backedUp = false
local shown, status, backupStatus

local function Has(object, method)
    return type(object) == "table" and type(object[method]) == "function"
end

local function Refresh()
    if ns.UI and ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function Say(text)
    if status == text then return end
    status = text
    Refresh()
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

local function LayoutHeight()
    local frame = Manager()
    local layout = frame and ActiveLayout(frame.layoutInfo)
    local system = layout and SystemOf(layout)
    if system then return HeightOf(system) end
    return BAR_DEFAULT
end

local function CurrentHeight()
    return shown or LayoutHeight()
end

local function Backup(layout, system)
    if backedUp then return end
    backedUp = true
    local saved = { name = layout.layoutName, height = HeightOf(system) }
    if C_EditMode and C_EditMode.ConvertLayoutInfoToString then
        local ok, text = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
        if ok and type(text) == "string" then saved.text = text end
    end
    ns.AccountSettings()[BACKUP_KEY] = saved
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
    if InCombatLockdown() then Say(TEXT_COMBAT) return end
    local frame = Manager()
    if not (frame and C_EditMode and C_EditMode.SaveLayouts) then Say(TEXT_NO_EDIT_MODE) return end
    if Has(frame, "IsShown") and frame:IsShown() then Say(TEXT_EDIT_MODE_OPEN) return end
    local info = CopyTable(frame.layoutInfo)
    local layout = ActiveLayout(info)
    if not layout then Say(TEXT_NO_EDIT_MODE) return end
    if layout.layoutType == Enum.EditModeLayoutType.Preset then Say(TEXT_PRESET) return end
    local system = SystemOf(layout)
    if not system then Say(TEXT_NO_SYSTEM) return end
    height = Clamp(height)
    if height == HeightOf(system) and EntryOf(system) then return end
    Backup(layout, system)
    Write(system, height)
    local ok, err = pcall(C_EditMode.SaveLayouts, info)
    if not ok then
        Say(TEXT_FAILED:format(tostring(err)))
        return false
    end
    Say(nil)
    return true
end

local function Flush(height)
    if not Change(height) then
        shown = nil
        return
    end
    C_Timer.After(VERIFY, function()
        if LayoutHeight() == height then
            shown = nil
        else
            Say(TEXT_RELOAD)
        end
    end)
end

local function Request(height)
    shown = Clamp(height)
    status = nil
    pending = pending + 1
    local token = pending
    C_Timer.After(DEBOUNCE, function()
        if token == pending then Flush(height) end
    end)
end

local function Restore()
    local saved = ns.AccountSettings()[BACKUP_KEY]
    if type(saved) ~= "table" or type(saved.height) ~= "number" then
        backupStatus = TEXT_NO_BACKUP
        Refresh()
        return
    end
    backupStatus = nil
    status = nil
    shown = Clamp(saved.height)
    Flush(shown)
    Refresh()
end

ns.DamageMeterLayout = {
    rows = {
        { label = "Bar Height", slider = BAR_RANGE, unit = "px", get = CurrentHeight, set = Request,
          note = function() return status end,
          help = "Saved in your active Edit Mode layout, which must be one of your own." },
        { label = "Original Height", buttonText = "Restore", button = Restore,
          note = function() return backupStatus end,
          help = "Puts Bar Height back to what it was before you first changed it here." },
    },
}
