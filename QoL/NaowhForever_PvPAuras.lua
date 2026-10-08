-------------------------------------------------------------------------------
--  NaowhForever_PvPAuras.lua -- PvP Auras: your target's big defensives, the defensives cast
--  on them, the crowd control on them and their important buffs, and the crowd control on you,
--  as rows of large icons. Forever closes auras to addons in combat, so Blizzard's
--  AuraContainer picks and draws them: it works in a fight, and shows auras without reacting.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local S = ns.QoLSettings
local UI = ns.UI

local BORDER = 1
local ICON_CROP = 0.08
local ICON_GAP = 3
local ROW_GAP = 4
local TIME_SIZE = 0.34
local COUNT_SIZE = 0.3
local TEXT_INSET = 2
local MIN_TEXT = 8
local BLACK = { r = 0, g = 0, b = 0 }

local SORT_DEFAULT, SORT_BIG_DEFENSIVE = 0, 1

local DISPLAYS = {
    {
        key = "target", unit = "target", setting = "pvpAurasTarget", posKey = "pvpAurasTargetPos",
        name = "PvP Auras: Target",
        rows = {
            { key = "bigDefensive", filter = "HELPFUL|BIG_DEFENSIVE", max = 3, sort = SORT_BIG_DEFENSIVE },
            { key = "externalDefensive", filter = "HELPFUL|EXTERNAL_DEFENSIVE", max = 3 },
            { key = "crowdControl", filter = "HARMFUL|CROWD_CONTROL", max = 3 },
            { key = "important", filter = "HELPFUL|IMPORTANT", max = 6 },
        },
    },
    {
        key = "player", unit = "player", setting = "pvpAurasPlayer", posKey = "pvpAurasPlayerPos",
        name = "PvP Auras: You",
        rows = {
            { key = "crowdControl", filter = "HARMFUL|CROWD_CONTROL", max = 4 },
        },
    },
}

local holders, buttons = {}, {}
local unlocked, pendingResize

local function On()
    return S.Get("enabled") and S.Get("pvpAuras")
end

local function Size()
    return S.Get("pvpAurasSize")
end

local function MaxPerRow(display)
    local most = 0
    for _, row in ipairs(display.rows) do most = math.max(most, row.max) end
    return most
end

local function HolderSize(display)
    local size, wide = Size(), MaxPerRow(display)
    return wide * size + (wide - 1) * ICON_GAP, #display.rows * size + (#display.rows - 1) * ROW_GAP
end

local function TextSize(ratio)
    return math.max(MIN_TEXT, math.floor(Size() * ratio + 0.5))
end

local function StyleButton(button)
    local size = Size()
    button:SetSize(size, size)
    button.timeText:SetFont(ns.UIFontPath(), TextSize(TIME_SIZE), "OUTLINE")
    button.countText:SetFont(ns.UIFontPath(), TextSize(COUNT_SIZE), "OUTLINE")
end

local function InitButton(button)
    local ground = button:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(BLACK.r, BLACK.g, BLACK.b, 1)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", BORDER, -BORDER)
    icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
    icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    local swipe = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    swipe:SetAllPoints(icon)
    swipe:SetDrawEdge(false)
    swipe:SetHideCountdownNumbers(true)
    swipe:SetReverse(true)
    local text = CreateFrame("Frame", nil, button)
    text:SetAllPoints()
    text:SetFrameLevel(swipe:GetFrameLevel() + 1)
    button.timeText = text:CreateFontString(nil, "OVERLAY")
    button.timeText:SetPoint("BOTTOM", 0, TEXT_INSET)
    button.countText = text:CreateFontString(nil, "OVERLAY")
    button.countText:SetPoint("TOPRIGHT", -TEXT_INSET, -TEXT_INSET)
    StyleButton(button)
    button:SetIcon(icon)
    button:SetDurationCooldown(swipe)
    button:SetDurationText(button.timeText)
    button:SetApplicationCount(button.countText)
    buttons[#buttons + 1] = button
end

local ROW_LAYOUT = { elementSpacing = ICON_GAP, lineSpacing = ROW_GAP, groupLineSpacing = ROW_GAP, forceNewLine = true }

local function BuildDisplay(display)
    local holder = CreateFrame("Frame", "NaowhForeverPvPAuras_" .. display.key, UIParent)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    container:SetPoint("TOPLEFT")
    container:SetUnit(display.unit)
    for _, row in ipairs(display.rows) do
        container:AddAuraGroup(row.key, row.filter, {
            maxFrameCount = row.max,
            sortMethod = row.sort or SORT_DEFAULT,
            initializeFrame = InitButton,
            layout = ROW_LAYOUT,
        })
    end
    holder.container = container
    holder.mover = UI.AttachMover(holder, display.name,
        function(pos) S.Set(display.posKey, pos) end, "QoL/Combat", "QoL/Combat:pvpAuras")
    holders[display.key] = holder
    return holder
end

local function Place(holder, display)
    local pos = S.Get(display.posKey)
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function ResizeButtons()
    if InCombatLockdown() then
        pendingResize = true
        return
    end
    pendingResize = false
    for i = 1, #buttons do StyleButton(buttons[i]) end
end

local events = CreateFrame("Frame")
local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        for _, holder in pairs(holders) do
            holder.container:SetEnabled(false)
            holder:Hide()
        end
        return
    end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    for _, display in ipairs(DISPLAYS) do
        local shown = S.Get(display.setting) == true
        local holder = holders[display.key]
        if shown and not holder then holder = BuildDisplay(display) end
        if holder then
            holder:SetSize(HolderSize(display))
            Place(holder, display)
            holder.container:SetEnabled(shown)
            holder:SetShown(shown)
            holder.mover:SetShown(shown and unlocked == true)
        end
    end
    ResizeButtons()
end

events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingResize then ResizeButtons() end
    Apply()
end)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or (key:find("^pvpAuras") and not key:find("Pos$")) then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowRaidReminderAnchorConfig", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideRaidReminderAnchorConfig", function()
    unlocked = false
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared.Settings

local function Summary(store)
    local shown = {}
    if store.Get("pvpAurasTarget") then shown[#shown + 1] = "your target" end
    if store.Get("pvpAurasPlayer") then shown[#shown + 1] = "you" end
    if #shown == 0 then return "Nothing shown" end
    return "On " .. table.concat(shown, " and ")
end

Settings.Page("QoL/Combat", S):Card({
    id = "pvpAuras", name = "PvP Auras", order = 95, switch = "pvpAuras",
    help = "Your target's defensives, crowd control and important buffs, and the crowd control on you, as large icons that keep working in combat.",
    summary = Summary,
    rows = {
        { key = "pvpAurasTarget", label = "Your Target", toggle = true,
          help = "Big defensives, defensives cast on them, crowd control and important buffs, a row each." },
        { key = "pvpAurasPlayer", label = "You", toggle = true,
          help = "The crowd control on you." },
        { key = "pvpAurasSize", label = "Icon Size", slider = { 24, 64, 1 } },
    },
})
