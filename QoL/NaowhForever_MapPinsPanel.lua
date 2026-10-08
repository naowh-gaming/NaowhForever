-------------------------------------------------------------------------------
--  NaowhForever_MapPinsPanel.lua -- the Map Pins button on the world map, beside the quest
--  log toggle in the bottom right. It opens a panel with the town map's switches: which kinds
--  of pin show, Shops & Trainers Only in Capitals and the minimap pins. The options window
--  keeps only the card's switch and Pin Size; the rest is chosen with the map open.
--
--  The keys stay in the QoL table, so saved settings carry over. Free while the map pins are
--  off: the button and the panel are made the first time they are on.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local UI = ns.UI
local T = ns.THEME
local S = ns.QoLSettings

-- The panel's rows in order. `half` rows pair up two to a line.
local ROWS = {
    { header = "OPTIONS" },
    { key = "townCapitalsOnly", text = "Shops & Trainers Only in Capitals",
      tip = "Keeps vendors, trainers and the bank off questing maps. Flight masters, innkeepers, "
          .. "stable masters, spirit healers and mailboxes show everywhere." },
    { key = "townMinimap", text = "Mailboxes & Spirit Healers on Minimap",
      tip = "Pins the mailboxes and spirit healers near you on the minimap." },
    { header = "SHOW" },
    { key = "townFlight", text = "Flight Masters", half = true },
    { key = "townInn", text = "Innkeepers", half = true },
    { key = "townMail", text = "Mailboxes", half = true, tip = "Every mailbox, in towns and out in the world." },
    { key = "townSpiritHealers", text = "Spirit Healers", half = true,
      tip = "Every graveyard's spirit healer, in towns and out in the world." },
    { key = "townZoneLinks", text = "Zone Exits", half = true, tip = "Click an exit to open the adjoining zone map." },
    { key = "townTravel", text = "Boats & Zeppelins", half = true,
      tip = "Every dock and zeppelin tower; click one to open where it goes." },
    { key = "townClass", text = "Class Trainers", half = true, tip = "Your class's trainers only." },
    { key = "townProfession", text = "Profession Trainers", half = true },
    { key = "townBank", text = "Bank & Auction House", half = true },
    { key = "townRepair", text = "Repairs", half = true },
    { key = "townSupplies", text = "Reagents, Ammo & Food", half = true },
    { key = "townStable", text = "Stable Masters", half = true },
    { key = "townVendors", text = "Other Vendors", half = true, tip = "Trade goods and every other merchant." },
}

local function On()
    return S.Get("enabled") and S.Get("townMap")
end

-------------------------------------------------------------------------------
--  The panel
-------------------------------------------------------------------------------
local PAD, ROW_H, HEADER_H, COL_W = 10, 22, 22, 170
local PANEL_W = PAD * 2 + COL_W * 2

local button, panel
local controls = {}

local function RefreshRows()
    for _, control in ipairs(controls) do control._refreshValue() end
end

local function MakeRow(parent, row, x, y, w)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(w, ROW_H)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:EnableMouse(true)
    local control = UI.BuildToggleControl(frame, nil,
        function() return S.Get(row.key) end,
        function(v)
            S.Set(row.key, v)
            if UI.RefreshPage then UI:RefreshPage(true) end
        end, 28, 14)
    control:SetPoint("LEFT", 0, 0)
    local label = ns.Font(frame, 12, nil)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetPoint("LEFT", control, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    label:SetText(row.text)
    if row.tip then ns.Tooltip(frame, row.text, row.tip) end
    controls[#controls + 1] = control
end

local function BuildPanel()
    panel = CreateFrame("Frame", nil, button)
    panel:SetFrameStrata("DIALOG")
    panel:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 4)
    panel:EnableMouse(true)
    panel:Hide()
    ns.Solid(panel, "BACKGROUND", T.bg, 0.95):SetAllPoints()
    ns.Border(panel, T.line)

    local title = ns.Font(panel, 14, nil)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Map Pins")
    local close = ns.Button(panel, "X", 18, 18, function() panel:Hide() end)
    close:SetPoint("TOPRIGHT", -5, -5)

    local y, col = -PAD - 22, 0
    for _, row in ipairs(ROWS) do
        if row.header then
            if col == 1 then y, col = y - ROW_H, 0 end
            local h = ns.Font(panel, 11, nil, T.accent)
            h:SetPoint("TOPLEFT", PAD, y - 6)
            h:SetText(row.header)
            y = y - HEADER_H
        elseif row.half then
            MakeRow(panel, row, PAD + col * COL_W, y, COL_W - 4)
            if col == 1 then y = y - ROW_H end
            col = 1 - col
        else
            if col == 1 then y, col = y - ROW_H, 0 end
            MakeRow(panel, row, PAD, y, COL_W * 2 - 4)
            y = y - ROW_H
        end
    end
    if col == 1 then y = y - ROW_H end
    panel:SetSize(PANEL_W, -y + PAD)
    panel:SetScript("OnShow", RefreshRows)
end

-------------------------------------------------------------------------------
--  The map button
-------------------------------------------------------------------------------
-- Beside the quest log toggle in the map's bottom right, at its size, so the two read as a
-- pair. A map without that toggle gets the same corner.
local function Place()
    local toggle = WorldMapFrame.SidePanelToggle
    button:ClearAllPoints()
    if toggle then
        local w, h = toggle:GetSize()
        button:SetSize(w > 0 and w or 32, h > 0 and h or 32)
        button:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMLEFT", -2, 0)
    else
        button:SetSize(32, 32)
        button:SetPoint("BOTTOMRIGHT", WorldMapFrame:GetCanvasContainer(), "BOTTOMRIGHT", -2, 2)
    end
end

local function BuildButton()
    button = CreateFrame("Button", nil, WorldMapFrame:GetCanvasContainer())
    button:SetFrameStrata("DIALOG")
    ns.Solid(button, "BACKGROUND", T.bg, 0.9):SetAllPoints()
    local border = ns.Border(button, { r = 0, g = 0, b = 0 })
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\NaowhForever\\Media\\LogoSmall.tga")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    button:SetScript("OnClick", function()
        if not panel then BuildPanel() end
        panel:SetShown(not panel:IsShown())
    end)
    button:SetScript("OnEnter", function()
        border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
    end)
    button:SetScript("OnLeave", function()
        border:SetColor(0, 0, 0, 1)
    end)
    ns.Tooltip(button, "Map Pins", "Click to choose which pins show on the map.")
    Place()
end

local function Apply()
    if On() then
        if not button then BuildButton() end
        button:Show()
        if panel and panel:IsShown() then RefreshRows() end
    elseif button then
        button:Hide()
    end
end

-- A reset or a change in the options window shows on an open panel straight away.
hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key:find("^town") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)
