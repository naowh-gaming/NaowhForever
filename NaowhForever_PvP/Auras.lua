-- Auras.lua: PvP Auras, your target's and your focus's short buffs, crowd control and debuffs.
local ns = _G.NaowhForever

local P = ns.PvP
local S = P.Settings
local UI = ns.UI
local SPELLS = ns.PvPSpells
local St = P.Style
local Icon = P.Icon

local ICON_GAP, ROW_GAP, HEADER_PAD = St.ICON_GAP, St.ROW_GAP, St.HEADER_PAD
local ABSORB_TEXT, ABSORB_SIZE, ABSORB_PAD, ABSORB_RGB = St.ABSORB_TEXT, St.ABSORB_SIZE, St.ABSORB_PAD, St.ABSORB_RGB
local NAME_SIZE, NAME_RGB, CLASS_ICONS, OUTLINE = St.NAME_SIZE, St.NAME_RGB, St.CLASS_ICONS, St.OUTLINE
local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local SORT_DEFAULT = 0
local NAME_GAP = ICON_GAP * 2
local ABSORB_WIDTH = 2
local MAGIC = { Magic = true }
local ROWS = { "buffs", "cc", "debuffs" }
local MAX_KEY = { buffs = "buffMax", cc = "ccMax", debuffs = "debuffMax" }
local FILTER = { buffs = "HELPFUL", cc = "HARMFUL", debuffs = "HARMFUL" }
local PAGE, CARD = "PvP/Auras", "PvP/Auras:auras"

local DISPLAYS = {
    { key = "target", unit = "target", frame = "NaowhForeverPvPAuras", name = "PvP Auras", posKey = "pos",
      changed = "PLAYER_TARGET_CHANGED", rows = { buffs = "buffs", cc = "cc", debuffs = "debuffs" } },
    { key = "focus", unit = "focus", frame = "NaowhForeverPvPAurasFocus", name = "PvP Auras: Focus",
      posKey = "focusPos", changed = "PLAYER_FOCUS_CHANGED", switch = "focus", nameKey = "focusName",
      rows = { buffs = "focusBuffs", cc = "focusCC", debuffs = "focusDebuffs" } },
}

local ROW_LAYOUT = { elementSpacing = ICON_GAP, lineSpacing = ROW_GAP, groupLineSpacing = ROW_GAP, forceNewLine = true }

local buttons = {}
local unlocked, pendingResize, built
local buffFilters = {}
local absorbUnits = {}
local pickParts = {}
local lists = {
    cc = { ids = {}, filters = {}, version = 0 },
    debuffs = { ids = {}, filters = {}, version = 0 },
}
local events = CreateFrame("Frame")

local function Readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function On()
    return S.Get("enabled") == true and S.Get("auras") == true
end

local function DisplayOn(d)
    return d.switch == nil or S.Get(d.switch) == true
end

local function RowOn(d, row)
    return S.Get(d.rows[row]) == true
end

local function InitButton(button)
    button.aura = true
    Icon.New(button)
    button:SetIcon(button.icon)
    button:SetDurationCooldown(button.swipe)
    button:SetApplicationCount(button.countText)
    buttons[#buttons + 1] = button
end

local function BuffFilters()
    buffFilters.maxDuration = S.Get("buffLength")
    buffFilters.includeDispelTypes = S.Get("buffMagicOnly") and MAGIC or nil
    return buffFilters
end

local function Pick(entries, prefix, ids)
    wipe(pickParts)
    wipe(ids)
    for _, entry in ipairs(entries) do
        local on = S.Get(prefix .. entry.key) == true
        pickParts[#pickParts + 1] = on and "1" or "0"
        if on then
            for id in pairs(entry.ids) do ids[id] = true end
        end
    end
    return table.concat(pickParts)
end

local function AddTyped(text, ids)
    for id in tostring(text or ""):gmatch("%d+") do ids[tonumber(id)] = true end
end

local function RefreshCrowdControl()
    local cc = lists.cc
    local signature = Pick(SPELLS.crowdControl, P.CC_PREFIX, cc.ids) .. (S.Get("ccOther") and "1" or "0")
    if S.Get("ccOther") then
        for id in pairs(SPELLS.otherCrowdControl) do cc.ids[id] = true end
    end
    if signature == cc.signature then return end
    cc.signature, cc.version = signature, cc.version + 1
    cc.filters.includeSpellIDs = cc.ids
end

local function RefreshDebuffs()
    local debuffs = lists.debuffs
    local extra = S.Get("debuffExtra") or ""
    local signature = Pick(SPELLS.debuffs, P.DEBUFF_PREFIX, debuffs.ids) .. "|" .. extra
    AddTyped(extra, debuffs.ids)
    if signature == debuffs.signature then return end
    debuffs.signature, debuffs.version = signature, debuffs.version + 1
    debuffs.filters.includeSpellIDs = debuffs.ids
end

local function NewAbsorb(holder)
    local absorb = CreateFrame("StatusBar", nil, holder)
    absorb:SetStatusBarTexture(WHITE8X8)
    absorb:SetStatusBarColor(0, 0, 0, 0)
    absorb:SetMinMaxValues(0, 1)
    absorb:SetValue(0)
    absorb.clip = CreateFrame("Frame", nil, absorb)
    absorb.clip:SetClipsChildren(true)
    absorb.clip:SetPoint("TOPLEFT", absorb:GetStatusBarTexture(), "TOPLEFT")
    absorb.clip:SetPoint("BOTTOMRIGHT", absorb:GetStatusBarTexture(), "BOTTOMRIGHT")
    absorb.text = absorb.clip:CreateFontString(nil, "OVERLAY")
    absorb.text:SetPoint("RIGHT", absorb, "RIGHT")
    absorb.text:SetJustifyH("RIGHT")
    return absorb
end

local function NewHeader(holder)
    local header = CreateFrame("Frame", nil, holder)
    header.class = header:CreateTexture(nil, "ARTWORK")
    header.class:SetTexture(CLASS_ICONS)
    header.class:SetPoint("LEFT")
    header.name = header:CreateFontString(nil, "OVERLAY")
    header.name:SetPoint("LEFT", header.class, "RIGHT", NAME_GAP, 0)
    header.name:SetJustifyH("LEFT")
    header.name:SetWordWrap(false)
    return header
end

local function Build(d)
    local holder = CreateFrame("Frame", d.frame, UIParent)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    container:SetPoint("TOPLEFT")
    container:SetUnit(d.unit)
    local filters = { buffs = BuffFilters(), cc = lists.cc.filters, debuffs = lists.debuffs.filters }
    for _, row in ipairs(ROWS) do
        container:AddAuraGroup(row, FILTER[row], {
            maxFrameCount = S.Get(MAX_KEY[row]), sortMethod = SORT_DEFAULT, initializeFrame = InitButton,
            layout = ROW_LAYOUT, candidateFilters = filters[row],
        })
    end
    d.applied = { cc = lists.cc.version, debuffs = lists.debuffs.version }
    holder.mover = UI.AttachMover(holder, d.name, function(pos) S.Set(d.posKey, pos) end, PAGE, CARD)
    local absorb = NewAbsorb(holder)
    if d.nameKey then d.header = NewHeader(holder) end
    d.holder, d.container, d.absorb = holder, container, absorb
    built = true
end

local function UpdateAbsorb(d)
    local absorb = d.absorb
    if not absorb or not absorb:IsShown() then return end
    if not UnitExists(d.unit) then
        absorb:SetValue(0)
        return
    end
    local amount = UnitGetTotalAbsorbs(d.unit)
    absorb:SetValue(amount)
    absorb.text:SetFormattedText(ABSORB_TEXT, amount)
end

local function UpdateHeader(d)
    local header = d.header
    if not header then return end
    local shown = S.Get(d.nameKey) == true and UnitExists(d.unit)
    header:SetShown(shown)
    if not shown then return end
    header.name:SetText(UnitName(d.unit))
    local _, classFile = UnitClass(d.unit)
    local readable = Readable(classFile)
    local color = readable and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] or NAME_RGB
    local coords = readable and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    header.name:SetTextColor(color.r, color.g, color.b)
    header.class:SetShown(coords ~= nil)
    if coords then Icon.SetClass(header.class, coords) end
end

local function Place(d)
    local pos = S.Get(d.posKey)
    d.holder:ClearAllPoints()
    d.holder:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function LayoutHeader(d)
    local nameSize = Icon.TextSize(NAME_SIZE)
    d.header.name:SetFont(ns.UIFontPath(), nameSize, OUTLINE)
    d.header.class:SetSize(nameSize + HEADER_PAD, nameSize + HEADER_PAD)
    d.header:SetSize(d.holder:GetWidth(), nameSize + HEADER_PAD)
    d.header:ClearAllPoints()
    d.header:SetPoint("BOTTOMLEFT", d.holder, "TOPLEFT", 0, ROW_GAP)
end

local function Layout(d)
    local size, rows, wide = Icon.Size(), 0, 1
    for _, row in ipairs(ROWS) do
        if RowOn(d, row) then rows, wide = rows + 1, math.max(wide, S.Get(MAX_KEY[row])) end
    end
    rows = math.max(rows, 1)
    d.holder:SetSize(wide * size + (wide - 1) * ICON_GAP, rows * size + (rows - 1) * ROW_GAP)
    local absorbSize = Icon.TextSize(ABSORB_SIZE)
    d.absorb.text:SetFont(ns.UIFontPath(), absorbSize, OUTLINE)
    d.absorb.text:SetTextColor(ABSORB_RGB.r, ABSORB_RGB.g, ABSORB_RGB.b)
    d.absorb:SetSize(size * ABSORB_WIDTH, absorbSize + ABSORB_PAD)
    d.absorb:ClearAllPoints()
    d.absorb:SetPoint("RIGHT", d.holder, "TOPLEFT", -NAME_GAP, -size / 2)
    if d.header then LayoutHeader(d) end
end

local function Rows(d)
    for _, row in ipairs(ROWS) do
        d.container:SetAuraGroupEnabled(row, RowOn(d, row))
        d.container:SetAuraGroupMaxFrameCount(row, S.Get(MAX_KEY[row]))
    end
    d.container:SetAuraGroupCandidateFilters("buffs", BuffFilters())
    for list, data in pairs(lists) do
        if d.applied[list] ~= data.version then
            d.applied[list] = data.version
            d.container:SetAuraGroupCandidateFilters(list, data.filters)
        end
    end
end

local function ResizeButtons()
    if InCombatLockdown() then
        pendingResize = true
        return
    end
    pendingResize = false
    for i = 1, #buttons do Icon.Style(buttons[i]) end
end

local function Hide(d)
    if not d.holder then return end
    d.container:SetEnabled(false)
    d.holder:Hide()
    d.holder.mover:Hide()
end

local function FocusIsTarget()
    if not (UnitExists("focus") and UnitExists("target")) then return false end
    local same = UnitIsUnit("focus", "target")
    return Readable(same) and same == true
end

local function UpdateFocusFade()
    for _, d in ipairs(DISPLAYS) do
        if d.nameKey and d.holder then
            d.holder:SetAlpha((FocusIsTarget() and not unlocked) and 0 or 1)
        end
    end
end

local function ShowDisplay(d)
    events:RegisterEvent(d.changed)
    if not d.holder then Build(d) end
    Rows(d)
    Layout(d)
    Place(d)
    d.container:SetEnabled(true)
    d.holder:Show()
    d.absorb:SetShown(S.Get("absorb") == true)
    if S.Get("absorb") then absorbUnits[#absorbUnits + 1] = d.unit end
    UpdateAbsorb(d)
    UpdateHeader(d)
    d.holder.mover:SetShown(unlocked == true)
end

local function Apply()
    if not On() and not built then
        events:UnregisterAllEvents()
        return
    end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterAllEvents()
    if not On() then
        for _, d in ipairs(DISPLAYS) do Hide(d) end
        return
    end
    RefreshCrowdControl()
    RefreshDebuffs()
    wipe(absorbUnits)
    for _, d in ipairs(DISPLAYS) do
        if DisplayOn(d) then ShowDisplay(d) else Hide(d) end
    end
    UpdateFocusFade()
    if absorbUnits[1] then events:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", absorbUnits[1], absorbUnits[2]) end
    ResizeButtons()
end

local function OnAbsorbChanged(unit)
    for _, d in ipairs(DISPLAYS) do
        if d.unit == unit then UpdateAbsorb(d) end
    end
end

local function OnUnitChanged(event)
    for _, d in ipairs(DISPLAYS) do
        if event == d.changed and d.container then
            d.container:UpdateAllAuras()
            UpdateAbsorb(d)
            UpdateHeader(d)
            UpdateFocusFade()
            return true
        end
    end
end

local function OnEvent(self, event, unit)
    if event == "UNIT_ABSORB_AMOUNT_CHANGED" then return OnAbsorbChanged(unit) end
    if OnUnitChanged(event) then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingResize then ResizeButtons() end
    Apply()
end

local function OnSettingChanged(key)
    if key ~= "pos" and key ~= "focusPos" then Apply() end
end

local function OnUnlock()
    unlocked = S.Get("enabled") == true
    Apply()
end

local function OnLock()
    unlocked = false
    Apply()
end

P.Displays = DISPLAYS
P.ROWS = ROWS
P.MAX_KEY = MAX_KEY
P.RowOn = RowOn

events:SetScript("OnEvent", OnEvent)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowRaidReminderAnchorConfig", OnUnlock)
hooksecurefunc(ns, "HideRaidReminderAnchorConfig", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
