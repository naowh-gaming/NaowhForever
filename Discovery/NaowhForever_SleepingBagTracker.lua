-------------------------------------------------------------------------------
--  NaowhForever_SleepingBagTracker.lua -- the Cozy Sleeping Bag tracker: the chain's steps in
--  a small window, as the Library Books tracker looks: how far along you are, then each step
--  with a waypoint pin (a tick once done), the step to do now in full white with how to get
--  there under it. Off by default; on, it shows from level 14 until you have the bag. The X
--  closes it until you log in again. Drag it or move it in Unlock Mode.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local S = ns.DiscoverySettings
local Bag = ns.SleepingBagChain
local L = ns.Library
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local BAR_BG = { r = 0x14 / 255, g = 0x16 / 255, b = 0x19 / 255 }
local PANEL_W = 320
local PANEL_PAD, PANEL_HEADER = St.PANEL_PAD, St.PANEL_HEADER
local BODY_W = PANEL_W - PANEL_PAD * 2
local BAR_H, BAR_GAP = 24, 6
local FOOTER = St.ACTION + 6
local SETTINGS_PAGE = "Discovery/Sleeping Bags"
local ROW_LEFT, WAYPOINT_SLOT, TICK = 6, 20, 16
local TITLE_LEFT = ROW_LEFT + WAYPOINT_SLOT + 6
local ROW_TOP, ROW_LINE_GAP, ROW_BOTTOM = 6, 3, 8

local panel, events
local closed   -- the X closed it, until you log in again

local function On()
    return S.Get("enabled") and S.Get("bagTracker")
end

-------------------------------------------------------------------------------
--  The window
-------------------------------------------------------------------------------
local function Paint()
    panel.backdrop:Paint(S.Get("bagTrackerAlpha") or 1)
end

local function DragStop()
    panel:StopMovingOrSizing()
    local point, _, relPoint, x, y = panel:GetPoint(1)
    S.Set("bagTrackerPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function DragStart()
    panel:StartMoving()
end

local function PinClick(pin)
    local step = pin:GetParent().step
    if step then Bag.Waypoint(step) end
end

local function RowEnter(row)
    row.hover:Show()
    local step = row.step
    if not step then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:SetText(step.object, 1, 1, 1)
    GameTooltip:AddLine(Bag.Where(step), T.muted.r, T.muted.g, T.muted.b, true)
    if step.tip then GameTooltip:AddLine(step.tip, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function BuildPanel()
    panel = Parts.Panel("COZY SLEEPING BAG", true)
    panel.backdrop:Card(4, PANEL_HEADER, 4, 4)
    panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    panel:SetWidth(PANEL_W)
    panel:SetScale(S.Get("bagTrackerScale"))
    panel:SetMovable(true)
    panel:SetFrameStrata("MEDIUM")
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", DragStart)
    panel:SetScript("OnDragStop", DragStop)
    panel.close:SetScript("OnClick", function()
        closed = true
        panel:Hide()
    end)
    local titleBtn = CreateFrame("Button", nil, panel)
    titleBtn:SetPoint("TOPLEFT", panel.title, "TOPLEFT", -4, 4)
    titleBtn:SetPoint("BOTTOMRIGHT", panel.title, "BOTTOMRIGHT", 0, -4)
    titleBtn:SetScript("OnClick", function() ns.OpenDiscoveryWindow("bag") end)
    titleBtn:RegisterForDrag("LeftButton")
    titleBtn:SetScript("OnDragStart", DragStart)
    titleBtn:SetScript("OnDragStop", DragStop)
    titleBtn:SetScript("OnEnter", function(self)
        panel.title:SetTextColor(T.accent.r, T.accent.g, T.accent.b)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Cozy Sleeping Bag")
        GameTooltip:AddLine("Click to see every step in the Discovery window.", T.accentSoft.r, T.accentSoft.g,
            T.accentSoft.b)
        GameTooltip:Show()
    end)
    titleBtn:SetScript("OnLeave", function()
        panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
        GameTooltip:Hide()
    end)

    local bar = CreateFrame("StatusBar", nil, panel)
    bar:SetSize(BODY_W, BAR_H)
    bar:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEADER - 4)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    ns.Solid(bar, "BACKGROUND", ns.ThemeTint("panel", BAR_BG), 1):SetAllPoints()
    ns.Border(bar, St.BORDER_RGB)
    bar.text = ns.Font(bar, 12, "OUTLINE")
    bar.text:SetPoint("CENTER", 0, 0)
    panel.bar = bar

    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetWidth(BODY_W)
    panel.body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -BAR_GAP)
    panel.rows = {}

    panel.settings = Parts.IconButton(panel, function()
        ns.OpenOptionsWindow(SETTINGS_PAGE)
        ns.UI.GoToSetting(SETTINGS_PAGE, nil, SETTINGS_PAGE .. ":bagtracker")
    end, ns.UI.COGS_ICON, 0, "Sleeping Bag settings")
    panel.settings:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    panel.settings.hint = "Opens the Sleeping Bag tracker's settings."

    panel.mover = ns.UI.AttachMover(panel, "Sleeping Bag", function(pos) S.Set("bagTrackerPos", pos) end,
        "Discovery/Sleeping Bags")
    local pos = S.Get("bagTrackerPos")
    if pos then
        panel:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        panel:SetPoint("RIGHT", UIParent, "RIGHT", -260, 120)
    end
    Paint()
    panel:Hide()
end

local function Row(i)
    local row = panel.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, panel.body)
    row:SetWidth(BODY_W)
    row.stripe = ns.Solid(row, "BACKGROUND", T.fg, St.STRIPE)
    row.stripe:SetAllPoints()
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, 0.04)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.divider = ns.Solid(row, "BORDER", T.line, 0.6)
    row.divider:SetPoint("BOTTOMLEFT", ROW_LEFT, 0)
    row.divider:SetPoint("BOTTOMRIGHT")
    ns.Hairline(row.divider, "h")
    row.pin = Parts.IconButton(row, PinClick, St.PIN, 0, "Waypoint")
    row.pin.hint = "Click to mark it on your map."
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetTexture(St.CHECK)
    row.tick:SetSize(TICK, TICK)
    row.text = ns.Font(row, 13, nil, T.fg)
    row.text:SetPoint("TOPLEFT", TITLE_LEFT, -ROW_TOP)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.sub = ns.Font(row, 11, nil, T.muted)
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -ROW_LINE_GAP)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    panel.rows[i] = row
    return row
end

-- Every step: done ones ticked and muted, the one to do now in white with how to get there,
-- the ones after it muted with a pin.
local function Render()
    local steps = Bag.Steps()
    local _, at = Bag.Current()
    local n = #steps
    local done = (at or n + 1) - 1
    local bar = panel.bar
    bar:SetMinMaxValues(0, n)
    bar:SetValue(done)
    bar:SetStatusBarColor(T.accent.r, T.accent.g, T.accent.b, 0.85)
    bar.text:SetText(("%d / %d  steps"):format(done, n))
    local y = 0
    local width = BODY_W - TITLE_LEFT - PANEL_PAD
    for i, step in ipairs(steps) do
        local row = Row(i)
        row.step = step
        local isDone, isNow = i <= done, i == at
        row.stripe:SetShown(i % 2 == 0)
        row.hover:Hide()
        row.text:SetWidth(width)
        local name = ("%d. %s"):format(i, step.object)
        row.text:SetText(isNow and name or ns.Color("muted", name))
        local sub = ("%s, %s"):format(L.ZoneName(step.map), step.place)
        if isNow and step.tip then sub = sub .. "\n" .. step.tip end
        row.sub:SetWidth(width)
        row.sub:SetText(sub)
        row.sub:SetShown(not isDone)
        local h = ROW_TOP + math.ceil(row.text:GetStringHeight()) + ROW_BOTTOM
        if not isDone then h = h + ROW_LINE_GAP + math.ceil(row.sub:GetStringHeight()) end
        local line = -(ROW_TOP + math.ceil(row.text:GetStringHeight()) / 2)
        row.pin:ClearAllPoints()
        row.pin:SetPoint("CENTER", row, "TOPLEFT", ROW_LEFT + WAYPOINT_SLOT / 2, line)
        row.pin:SetShown(not isDone)
        row.tick:ClearAllPoints()
        row.tick:SetPoint("CENTER", row, "TOPLEFT", ROW_LEFT + WAYPOINT_SLOT / 2, line)
        row.tick:SetShown(isDone)
        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, -y)
        row.divider:SetShown(i < n)
        row:Show()
        y = y + h
    end
    for i = n + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.body:SetHeight(math.max(y, 1))
    panel:SetHeight(PANEL_HEADER + 4 + BAR_H + BAR_GAP + y + FOOTER + PANEL_PAD)
end

-------------------------------------------------------------------------------
--  When it shows
-------------------------------------------------------------------------------
local function Refresh()
    local show = On() and not closed and Bag.Level() and Bag.Current() ~= nil
    if not show then
        if panel then panel:Hide() end
        return
    end
    if not panel then BuildPanel() end
    Render()
    panel:Show()
end

-- A quest taken or handed in moves the chain on; a level can bring it within reach.
local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }

local function OnEvent()
    -- The quest log has the change a moment later.
    C_Timer.After(0.2, Refresh)
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    elseif events then
        events:UnregisterAllEvents()
    end
    Refresh()
end

hooksecurefunc(S, "Set", function(key, value)
    if key == "bagTrackerScale" and panel then panel:SetScale(value) end
    if key == "bagTrackerAlpha" and panel then Paint() end
    if key == "enabled" or key == "bagTracker" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

-- Unlock Mode shows it wherever you are, to place it.
hooksecurefunc(ns, "ShowRaidReminderAnchorConfig", function()
    if not On() then return end
    if not panel then BuildPanel() end
    Render()
    panel.mover:Show()
    panel:Show()
end)
hooksecurefunc(ns, "HideRaidReminderAnchorConfig", function()
    if panel then
        panel.mover:Hide()
        Refresh()
    end
end)
