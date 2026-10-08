-------------------------------------------------------------------------------
--  NaowhForever_MapPinsPanel.lua -- the Map Pins button in the world map's top right corner.
--  It opens a panel with the town map's switches: which kinds of pin show, Shops & Trainers
--  Only in Capitals and the minimap pins. The options window keeps only the card's switch and
--  Pin Size; the rest is chosen with the map open.
--
--  The keys stay in the QoL table, so saved settings carry over. Free while the map pins are
--  off: the button and the panel are made the first time they are on.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local UI = ns.UI
local T = ns.THEME
local S = ns.QoLSettings

-- The panel's rows in order.
local ROWS = {
    { header = "OPTIONS" },
    { key = "townCapitalsOnly", text = "Shops & Trainers Only in Capitals",
      tip = "Keeps vendors, trainers and the bank off questing maps. Flight masters, innkeepers, "
          .. "stable masters, spirit healers and mailboxes show everywhere." },
    { key = "townMinimap", text = "Mailboxes & Spirit Healers on Minimap",
      tip = "Pins the mailboxes and spirit healers near you on the minimap." },
    { header = "SHOW" },
    { key = "townFlight", text = "Flight Masters" },
    { key = "townInn", text = "Innkeepers" },
    { key = "townMail", text = "Mailboxes", tip = "Every mailbox, in towns and out in the world." },
    { key = "townSpiritHealers", text = "Spirit Healers",
      tip = "Every graveyard's spirit healer, in towns and out in the world." },
    { key = "townZoneLinks", text = "Zone Exits", tip = "Click an exit to open the adjoining zone map." },
    { key = "townTravel", text = "Boats & Zeppelins",
      tip = "Every dock and zeppelin tower; click one to open where it goes." },
    { key = "townClass", text = "Class Trainers", tip = "Your class's trainers only." },
    { key = "townProfession", text = "Profession Trainers" },
    { key = "townBank", text = "Bank & Auction House" },
    { key = "townRepair", text = "Repairs" },
    { key = "townSupplies", text = "Reagents, Ammo & Food" },
    { key = "townStable", text = "Stable Masters" },
    { key = "townVendors", text = "Other Vendors", tip = "Trade goods and every other merchant." },
}

local function On()
    return S.Get("enabled") and S.Get("townMap")
end

-------------------------------------------------------------------------------
--  The panel: a drawer against the map window's left side, the map's height (the Dungeon
--  Journal takes the right side). Where that side has no room, the right; on the maximized
--  map, which fills the screen, inside its top left corner.
-------------------------------------------------------------------------------
local PAD, ROW_H, HEADER_H, GAP = 12, 24, 26, 4
local PANEL_W = 270

local button, panel
local controls = {}

local function RefreshRows()
    for _, control in ipairs(controls) do control._refreshValue() end
end

local function MakeRow(parent, row, y)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(ROW_H)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    frame:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
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
    label:SetPoint("LEFT", control, "RIGHT", 8, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    label:SetText(row.text)
    if row.tip then ns.Tooltip(frame, row.text, row.tip) end
    controls[#controls + 1] = control
end

local function PlacePanel()
    if not panel then return end
    local map = WorldMapFrame
    panel:ClearAllPoints()
    if map.IsMaximized and map:IsMaximized() then
        local canvas = map:GetCanvasContainer()
        panel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 8, -8)
        panel:SetHeight(panel.contentH)
    else
        if (map:GetLeft() or 0) >= PANEL_W + GAP then
            panel:SetPoint("TOPRIGHT", map, "TOPLEFT", -GAP, 0)
        else
            panel:SetPoint("TOPLEFT", map, "TOPRIGHT", GAP, 0)
        end
        -- The map's height, or the rows' where the map is shorter.
        panel:SetHeight(math.max(panel.contentH, map:GetHeight()))
    end
end

local function BuildPanel()
    -- The map's child, so it opens, closes and scales with the map.
    panel = CreateFrame("Frame", nil, WorldMapFrame)
    panel:SetWidth(PANEL_W)
    panel:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)
    panel:EnableMouse(true)
    panel:Hide()
    ns.Solid(panel, "BACKGROUND", T.bg, 0.95):SetAllPoints()
    ns.Border(panel, T.line)

    local title = ns.Font(panel, 14, nil)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Map Pins")
    local close = ns.Button(panel, "X", 18, 18, function() panel:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -6)

    local y = -PAD - 24
    for _, row in ipairs(ROWS) do
        if row.header then
            local h = ns.Font(panel, 11, nil, T.accent)
            h:SetPoint("TOPLEFT", PAD, y - 8)
            h:SetText(row.header)
            y = y - HEADER_H
        else
            MakeRow(panel, row, y)
            y = y - ROW_H
        end
    end
    panel.contentH = -y + PAD
    panel:SetScript("OnShow", RefreshRows)
    -- The map's size buttons move it between windowed and the whole screen.
    if WorldMapFrame.Maximize then hooksecurefunc(WorldMapFrame, "Maximize", PlacePanel) end
    if WorldMapFrame.Minimize then hooksecurefunc(WorldMapFrame, "Minimize", PlacePanel) end
end

-------------------------------------------------------------------------------
--  The map button
-------------------------------------------------------------------------------
-- In the map's top right corner, left of the buttons the map keeps there (tracking options and
-- the like) and at their size, so they read as one row. Those are found by where they sit, not
-- by name, so a map with more, fewer or none of them still gets a free spot.
local function Place()
    local canvas = WorldMapFrame:GetCanvasContainer()
    local edge, edgeX
    for _, frame in ipairs(WorldMapFrame.overlayFrames or {}) do
        if frame:IsShown() and frame:GetNumPoints() > 0 then
            local point, relative, _, x = frame:GetPoint(1)
            if point == "TOPRIGHT" and relative == canvas and (not edgeX or x < edgeX) then
                edge, edgeX = frame, x
            end
        end
    end
    button:ClearAllPoints()
    if edge then
        local w, h = edge:GetSize()
        button:SetSize(w > 0 and w or 32, h > 0 and h or 32)
        button:SetPoint("TOPRIGHT", edge, "TOPLEFT", -2, 0)
    else
        button:SetSize(32, 32)
        button:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -4, -2)
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
        PlacePanel()
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
    WorldMapFrame:HookScript("OnShow", function()
        Place()
        PlacePanel()
    end)
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
