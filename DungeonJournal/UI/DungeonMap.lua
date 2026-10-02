-------------------------------------------------------------------------------
--  UI/DungeonMap.lua -- a dungeon's map: the game's own map art of the dungeon (Data/Maps.lua),
--  its bosses as round portraits where they stand, each with its place in the kill order,
--  and the entrance. Hover a boss for its name, click it for its loot; a dungeon on several
--  floors has a switch under the map. It shows in two places, each a view of its own:
--
--  - A small window, from Map on a dungeon page's Bosses title: in front of the window that
--    holds the page, beside it where the screen has room (else over its top right). It
--    closes with that window unless pinned (the pin in its title, kept for the account).
--  - The world map: press M inside a dungeon and its map fills the map's picture, while the
--    Journal sits beside the map (UI/MapPanel.lua says when: it already watches the map).
--    Right-click goes up to the zone the dungeon is in, as the world map goes up a level;
--    Map on the panel beside it brings it back.
--
--  Where the bosses stand is placed by hand. /nf mappins turns placing on in the window:
--  every boss gets a pin to drag (those not placed yet wait along the top), the entrance too,
--  and Copy gives the dungeon's line for Data/Maps.lua. What you place is kept for the
--  account until then, and shown over the data. /nf mapcheck prints which map art and floors
--  the client has. The switch only offers the floors something stands on, once anything is
--  placed: the art has floors with nothing of the dungeon on them (Shadowfang Keep's fifth).
--  Placing, or before anything is placed, it offers them all.
--
--  Nothing is made until a map is first shown, and it listens to nothing.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local T = ns.THEME
local J = ns.Journal
local S = J.Settings

local St = J.Style
local PANEL_PAD, PANEL_HEADER = St.PANEL_PAD, St.PANEL_HEADER

local ART = "Interface\\WorldMap\\%s\\%s%d_%d"   -- folder, folder, floor, tile (1 to 12)
local TILE = 256
local MAP_W, MAP_H = 1002, 668   -- the part of the four by three tiles the map shows
local WINDOW_SCALE = 0.7         -- the map in the window: about 700 by 470
local PIN = 46                   -- a boss's portrait, in the map's own size
local BADGE = 20                 -- its number
local ENTRANCE = 28
local TRAY_STEP = PIN + 10       -- placing: the pins not placed yet, along the top
local FLOOR_H = 22               -- the floor switch under the map
local FLOOR_STEP_W = 22
local COPY_W = 52
local PIN_BUTTON = 20            -- the window's pin, beside its close button
local PIN_ICON = 14
local MASK = "Interface\\AddOns\\NaowhForever\\Media\\circle_mask.tga"

local placing = false            -- /nf mappins, in the window
local lootFrom                   -- the view whose pin opened the boss's loot, to close it with

-------------------------------------------------------------------------------
--  Where a pin stands: what was placed on this account while placing, else the data
-------------------------------------------------------------------------------
local function Placed(dungeon)
    local all = ns.AccountSettings().journalMapPins
    return type(all) == "table" and all[dungeon.key] or nil
end

local function Spot(dungeon, key)
    local placed = Placed(dungeon)
    local spot = placed and placed[key]
    if type(spot) == "table" then return spot end
    local map = J.Maps[dungeon.key]
    if key == "entrance" then return map.entrance end
    return map.pins[key]
end

local function Keep(dungeon, key, spot)
    local account = ns.AccountSettings()
    account.journalMapPins = account.journalMapPins or {}
    account.journalMapPins[dungeon.key] = account.journalMapPins[dungeon.key] or {}
    account.journalMapPins[dungeon.key][key] = spot
end

-- A boss's key on the map: its NPC ID, or minus a chest's object ID; nil for the trash.
local function KeyOf(boss)
    return boss.npc or (boss.chest and -boss.chest) or nil
end

-- Each boss of the dungeon, numbered in kill order as its page numbers them (a rare, an
-- optional boss and a chest have none); fn(boss, number, key).
local function EachBoss(dungeon, fn)
    for _, wing in ipairs(dungeon.wings) do
        local number = 0
        for _, boss in ipairs(wing.bosses) do
            local key = KeyOf(boss)
            local ordered = not (boss.rare or boss.optional or boss.chest or boss.trash)
            if ordered then number = number + 1 end
            if key then fn(boss, ordered and number or nil, key) end
        end
    end
end

-------------------------------------------------------------------------------
--  A view: the map art, its pins and the floor switch, drawn into a frame
-------------------------------------------------------------------------------
local View = {}
View.__index = View

local function PinEnter(pin)
    local boss = pin.boss
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(boss.name, 1, 1, 1)
    local kind = boss.rare and "Rare" or boss.optional and "Optional" or boss.chest and "Chest" or nil
    if kind then GameTooltip:AddLine(kind, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:AddLine(pin.view:Placing() and "Drag to place it." or "Click for its loot.",
        T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function PinClicked(pin, button)
    -- A right-click goes to the view (on the world map: up to the zone).
    if button == "RightButton" then
        if pin.view.onRightClick then pin.view.onRightClick() end
        return
    end
    if pin.view:Placing() then return end
    lootFrom = pin.view
    J.View.OpenBossLoot(pin.boss, pin.view.dungeon)
end

-- A map closes (the world map, M again; the window): the loot one of its pins opened goes too.
local function ViewHidden(view)
    if lootFrom == view then
        lootFrom = nil
        J.View.CloseBossLoot()
    end
end

-- A drag ends: where the pin's middle is on the map, 0 to 1 across and down, kept.
local function DragStop(frame)
    frame:StopMovingOrSizing()
    local view = frame.view
    local x, y = frame:GetCenter()
    local left, top = view.canvas:GetLeft(), view.canvas:GetTop()
    if x and left then
        x = math.min(1, math.max(0, (x - left) / MAP_W))
        y = math.min(1, math.max(0, (top - y) / MAP_H))
        Keep(view.dungeon, frame.key, { view.floor, math.floor(x * 1000 + 0.5) / 1000,
            math.floor(y * 1000 + 0.5) / 1000 })
    end
    view:Draw()
end

local function DragStart(frame)
    if frame.view:Placing() then frame:StartMoving() end
end

local function Draggable(frame)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", DragStart)
    frame:SetScript("OnDragStop", DragStop)
end

-- Round: a texture cut to a circle.
local function Round(frame, texture)
    local mask = frame:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    texture:AddMaskTexture(mask)
end

-- The portrait in a 1px black ring, as the house's edges are (its width set for the view's
-- scale when drawn); its number on a small dark disc at its foot. A boss without a portrait
-- (or a chest) shows its number, larger.
function View:NewPin()
    local pin = CreateFrame("Button", nil, self.canvas)
    pin.view = self
    pin:SetSize(PIN, PIN)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetPoint("CENTER")
    pin.ring:SetColorTexture(0, 0, 0, 1)
    Round(pin, pin.ring)
    pin.plate = pin:CreateTexture(nil, "BORDER")
    pin.plate:SetAllPoints()
    pin.plate:SetColorTexture(T.bg.r, T.bg.g, T.bg.b, 1)
    Round(pin, pin.plate)
    pin.face = pin:CreateTexture(nil, "ARTWORK")
    pin.face:SetAllPoints()
    Round(pin, pin.face)
    pin.big = ns.Font(pin, 18, nil, T.fg)
    pin.big:SetPoint("CENTER")
    pin.badge = CreateFrame("Frame", nil, pin)
    pin.badge:SetSize(BADGE, BADGE)
    pin.badge:SetPoint("CENTER", pin, "BOTTOMRIGHT", -6, 6)
    pin.badge.disc = pin.badge:CreateTexture(nil, "ARTWORK")
    pin.badge.disc:SetAllPoints()
    pin.badge.disc:SetColorTexture(0, 0, 0, 0.9)
    Round(pin.badge, pin.badge.disc)
    pin.badge.text = ns.Font(pin.badge, 11, nil, T.fg)
    pin.badge.text:SetPoint("CENTER")
    pin:SetScript("OnEnter", PinEnter)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin:SetScript("OnClick", PinClicked)
    Draggable(pin)
    return pin
end

-- The boss's portrait from its creature display, where the client can draw one.
local function SetFace(pin, boss, number, ring)
    pin.ring:SetSize(PIN + ring * 2, PIN + ring * 2)
    local face = boss.model and SetPortraitTextureFromCreatureDisplayID
    if face then SetPortraitTextureFromCreatureDisplayID(pin.face, boss.model) end
    pin.face:SetShown(face ~= nil)
    pin.big:SetShown(not face)
    pin.big:SetText(boss.chest and "?" or number or "")
    pin.badge:SetShown(face ~= nil and number ~= nil)
    pin.badge.text:SetText(number or "")
end

-- The view's switch: back, the floor's name, on; its caller places self.down.
local function NewView(parent, holder, editable)
    local view = setmetatable({ pins = {}, used = 0, tray = 0, floors = {}, editable = editable }, View)
    -- The map in its own size; what lies past its 1002 by 668 is cut off.
    local canvas = CreateFrame("Frame", nil, parent)
    canvas:SetSize(MAP_W, MAP_H)
    canvas:SetClipsChildren(true)
    view.canvas, view.tiles = canvas, {}
    for i = 1, 12 do
        local tile = canvas:CreateTexture(nil, "BACKGROUND")
        tile:SetSize(TILE, TILE)
        tile:SetPoint("TOPLEFT", (i - 1) % 4 * TILE, -math.floor((i - 1) / 4) * TILE)
        view.tiles[i] = tile
    end
    local door = CreateFrame("Button", nil, canvas)
    door:SetSize(ENTRANCE, ENTRANCE)
    door.icon = door:CreateTexture(nil, "ARTWORK")
    door.icon:SetAllPoints()
    door.icon:SetAtlas("dungeon")
    door.text = ns.Font(door, 16, "OUTLINE", T.fg)
    door.text:SetPoint("LEFT", door, "RIGHT", 4, 0)
    door.text:SetText("Entrance")
    door.key, door.view = "entrance", view
    Draggable(door)
    view.door = door
    view.down = ns.Button(holder, "<", FLOOR_STEP_W, FLOOR_H - 2, function() view:Step(-1) end)
    view.floorName = ns.Font(holder, 12, nil, T.fg)
    view.floorName:SetPoint("LEFT", view.down, "RIGHT", 8, 0)
    view.up = ns.Button(holder, ">", FLOOR_STEP_W, FLOOR_H - 2, function() view:Step(1) end)
    view.up:SetPoint("LEFT", view.floorName, "RIGHT", 8, 0)
    return view
end

function View:Placing()
    return placing and self.editable
end

-- Where n is in the switch's floors, or nil.
function View:FloorAt(n)
    for i = 1, #self.floors do
        if self.floors[i] == n then return i end
    end
end

function View:Offer(spot)
    if type(spot) == "table" and not self:FloorAt(spot[1]) then self.floors[#self.floors + 1] = spot[1] end
end

-- The floors the switch offers: those something stands on, else (placing, or nothing placed
-- yet) every floor of the art.
function View:FillFloors()
    local dungeon, floors = self.dungeon, self.floors
    wipe(floors)
    if not self:Placing() then
        self:Offer(Spot(dungeon, "entrance"))
        EachBoss(dungeon, function(_, _, key) self:Offer(Spot(dungeon, key)) end)
        table.sort(floors)
    end
    if #floors == 0 then
        for n = 1, J.Maps[dungeon.key].floors do floors[n] = n end
    end
    if not self:FloorAt(self.floor) then self.floor = floors[1] end
end

-- Shows the dungeon, on the floor its first placed boss is on, else its first.
function View:Open(dungeon)
    self.dungeon, self.floor = dungeon, nil
    EachBoss(dungeon, function(_, _, key)
        local spot = Spot(dungeon, key)
        if not self.floor and type(spot) == "table" then self.floor = spot[1] end
    end)
    self:FillFloors()
end

function View:At(frame, x, y)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", self.canvas, "TOPLEFT", x * MAP_W, -y * MAP_H)
end

function View:DrawPin(boss, number, key)
    local spot = Spot(self.dungeon, key)
    local here = type(spot) == "table" and spot[1] == self.floor
    if not here and not (self:Placing() and spot == nil) then return end
    self.used = self.used + 1
    local pin = self.pins[self.used] or self:NewPin()
    self.pins[self.used] = pin
    pin.boss, pin.key = boss, key
    SetFace(pin, boss, number, 1 / self.scale)
    if here then
        self:At(pin, spot[2], spot[3])
        pin:SetAlpha(1)
    else
        -- Not placed yet: along the top, to drag from.
        self.tray = self.tray + 1
        pin:ClearAllPoints()
        pin:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", (self.tray - 1) * TRAY_STEP + 8, -8)
        pin:SetAlpha(0.7)
    end
    pin:Show()
end

local function FloorName(map, n)
    return map.names and map.names[n] or ("Floor %d"):format(n)
end

local function DrawPinOf(view)
    return function(boss, number, key) view:DrawPin(boss, number, key) end
end

function View:Draw()
    local dungeon = self.dungeon
    if not dungeon then return end
    local map = J.Maps[dungeon.key]
    for i = 1, 12 do self.tiles[i]:SetTexture(ART:format(map.art, map.art, self.floor, i)) end
    for i = 1, self.used do self.pins[i]:Hide() end
    self.used, self.tray = 0, 0
    self.drawPin = self.drawPin or DrawPinOf(self)
    EachBoss(dungeon, self.drawPin)
    local door = Spot(dungeon, "entrance")
    local here = type(door) == "table" and door[1] == self.floor
    self.door:SetShown(here or self:Placing())
    if here then
        self:At(self.door, door[2], door[3])
    elseif self:Placing() then
        self.door:ClearAllPoints()
        self.door:SetPoint("TOPRIGHT", self.canvas, "TOPRIGHT", -8, -8)
    end
    local several = #self.floors > 1
    self.floorName:SetShown(several)
    self.down:SetShown(several)
    self.up:SetShown(several)
    self.floorName:SetText(FloorName(map, self.floor))
    if self.onDraw then self.onDraw() end
end

function View:Step(by)
    local at = self:FloorAt(self.floor) or 1
    self.floor = self.floors[(at - 1 + by) % #self.floors + 1]
    self:Draw()
end

-------------------------------------------------------------------------------
--  Placing: the dungeon's line for Data/Maps.lua
-------------------------------------------------------------------------------
-- 0.5, not 0.500.
local function Number(v)
    local text = ("%.3f"):format(v):gsub("0+$", "")
    return (text:gsub("%.$", ""))
end

local function SpotText(spot)
    return ("{ %d, %s, %s }"):format(spot[1], Number(spot[2]), Number(spot[3]))
end

local function Copy(dungeon)
    local map = J.Maps[dungeon.key]
    local lines = { ("    %s = { art = %q, floors = %d,"):format(dungeon.key, map.art, map.floors) }
    if map.names then
        local names = {}
        for i, name in ipairs(map.names) do names[i] = ("%q"):format(name) end
        lines[#lines + 1] = "        names = { " .. table.concat(names, ", ") .. " },"
    end
    local door = Spot(dungeon, "entrance")
    if door then lines[#lines + 1] = "        entrance = " .. SpotText(door) .. "," end
    lines[#lines + 1] = "        pins = {"
    EachBoss(dungeon, function(boss, _, key)
        local spot = Spot(dungeon, key)
        if spot then
            lines[#lines + 1] = ("            [%d] = %s,   -- %s"):format(key, SpotText(spot), boss.name)
        end
    end)
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "    },"
    ns.ShowCopyBox(dungeon.name .. ": Data/Maps.lua", table.concat(lines, "\n"))
end

-------------------------------------------------------------------------------
--  The window
-------------------------------------------------------------------------------
local BESIDE_GAP = 4
local OVER_INSET = 40      -- over the window, clear of its title bar
local window, windowView
local owners = {}          -- the windows it closes with, hooked once each

local function Pinned()
    return ns.AccountSettings().journalMapPinned == true
end

-- The top of the frame Map was clicked in: the Journal window, or the map panel.
local function Owner(frame)
    while frame:GetParent() and frame:GetParent() ~= UIParent do frame = frame:GetParent() end
    return frame
end

-- Its window closes: the map goes with it, unless pinned; pinned, it stays where it is.
local function OwnerHidden()
    if not window:IsShown() then return end
    if not Pinned() then
        window:Hide()
        return
    end
    local x, y = window:GetCenter()
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- In front of the window it was opened from, on its layer: beside it on the right where the
-- screen has room, else on the left, else over its top right. Opened with nothing to
-- follow (a test, a command), in the middle.
local function Place(from)
    window:ClearAllPoints()
    local owner = from and Owner(from)
    if not owner then
        window:SetFrameStrata("HIGH")
        window:SetScale(ns.UIScale())
        window:SetPoint("CENTER")
        return
    end
    if not owners[owner] then
        owners[owner] = true
        owner:HookScript("OnHide", OwnerHidden)
    end
    window:SetFrameStrata(owner:GetFrameStrata())
    window:SetScale(owner:GetScale())
    local scale = owner:GetEffectiveScale()
    local need = (window:GetWidth() + BESIDE_GAP) * scale
    local right = UIParent:GetRight() * UIParent:GetEffectiveScale() - (owner:GetRight() or 0) * scale
    local left = (owner:GetLeft() or 0) * scale
    if right >= need then
        window:SetPoint("TOPLEFT", owner, "TOPRIGHT", BESIDE_GAP, 0)
    elseif left >= need then
        window:SetPoint("TOPRIGHT", owner, "TOPLEFT", -BESIDE_GAP, 0)
    else
        window:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -OVER_INSET / 2, -OVER_INSET)
    end
end

local function Paint()
    window.backdrop:Paint(S.Get("windowAlpha") or 1)
end

-- The pin: the accent while pinned, muted while not, white under the mouse.
local function PaintPin(button)
    local color = button:IsMouseOver() and T.fg or Pinned() and T.accent or T.muted
    button.icon:SetVertexColor(color.r, color.g, color.b)
end

local function PinButtonEnter(button)
    PaintPin(button)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(Pinned() and "Pinned" or "Pin the map", 1, 1, 1)
    GameTooltip:AddLine(Pinned() and "It stays open when the Journal closes. Click to unpin."
        or "Keeps it open when the Journal closes.", T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function PinButtonLeave(button)
    PaintPin(button)
    GameTooltip:Hide()
end

local function PinButtonClicked(button)
    ns.AccountSettings().journalMapPinned = not Pinned() or nil
    PinButtonEnter(button)
end

local function WindowDrawn()
    window.title:SetText(windowView.dungeon.name:upper()
        .. (placing and ns.Color("muted", "   PLACING PINS") or ""))
    window.copy:SetShown(placing)
end

local function Build()
    window = J.View.Parts.Panel("", true)
    window:SetSize(MAP_W * WINDOW_SCALE + PANEL_PAD * 2, PANEL_HEADER + MAP_H * WINDOW_SCALE + FLOOR_H + PANEL_PAD * 2)
    window.backdrop:Card(4, PANEL_HEADER, 4, 4)
    window.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    window.title:SetPoint("RIGHT", -34 - PIN_BUTTON - 4, 0)
    window:SetToplevel(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    windowView = NewView(window, window, true)
    window:HookScript("OnHide", function() ViewHidden(windowView) end)
    windowView.scale = WINDOW_SCALE
    windowView.onDraw = WindowDrawn
    local canvas = windowView.canvas
    canvas:SetScale(WINDOW_SCALE)
    canvas:SetPoint("TOPLEFT", PANEL_PAD / WINDOW_SCALE, -PANEL_HEADER / WINDOW_SCALE)
    windowView.down:SetPoint("BOTTOMLEFT", PANEL_PAD, PANEL_PAD)
    window.copy = ns.Button(window, "Copy", COPY_W, FLOOR_H - 2, function() Copy(windowView.dungeon) end)
    window.copy:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    local pin = CreateFrame("Button", nil, window)
    pin:SetSize(PIN_BUTTON, PIN_BUTTON)
    pin:SetPoint("RIGHT", window.close, "LEFT", -4, 0)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetTexture(St.PIN, nil, nil, "TRILINEAR")
    pin.icon:SetSize(PIN_ICON, PIN_ICON)
    pin.icon:SetPoint("CENTER")
    pin:SetScript("OnEnter", PinButtonEnter)
    pin:SetScript("OnLeave", PinButtonLeave)
    pin:SetScript("OnClick", PinButtonClicked)
    PaintPin(pin)
    window.pin = pin
end

-------------------------------------------------------------------------------
--  On the world map
-------------------------------------------------------------------------------
local OVERLAY_LEVEL = 50   -- over the map's picture, under its own buttons' strata
local HINT_PAD = 10
local overlay, overlayView

-- Right-click: up to the zone the dungeon is in, as the world map goes up a level. In combat
-- the map is not moved (the game keeps it from addons then): the world shows instead.
local function UpToZone()
    overlay:Hide()
    local entrance = overlayView.dungeon.entrance
    if entrance and not InCombatLockdown() then C_Map.OpenWorldMap(entrance.map) end
end

local function OverlayClicked(_, button)
    if button == "RightButton" then UpToZone() end
end

-- As big as the map's picture lets it be, in the middle; black round it.
local function Fit()
    local w, h = overlay:GetWidth(), overlay:GetHeight()
    local scale = math.max(0.1, math.min(w / MAP_W, (h - FLOOR_H - HINT_PAD) / MAP_H))
    overlayView.scale = scale
    overlayView.canvas:SetScale(scale)
    overlayView.canvas:ClearAllPoints()
    overlayView.canvas:SetPoint("TOP", overlay, "TOP", 0, 0)
end

local function BuildOverlay()
    local map = WorldMapFrame
    -- The map's picture, where the client has it as the mainline map does; else the map.
    local picture = type(map.ScrollContainer) == "table" and map.ScrollContainer or map
    overlay = CreateFrame("Frame", nil, map)
    overlay:SetAllPoints(picture)
    overlay:SetFrameLevel(picture:GetFrameLevel() + OVERLAY_LEVEL)
    overlay:EnableMouse(true)
    overlay:EnableMouseWheel(true)   -- the picture under it does not zoom
    overlay:SetScript("OnMouseUp", OverlayClicked)
    overlay:SetScript("OnMouseWheel", function() end)
    ns.Solid(overlay, "BACKGROUND", { r = 0, g = 0, b = 0 }, 1):SetAllPoints()
    overlayView = NewView(overlay, overlay, false)
    overlay:SetScript("OnHide", function() ViewHidden(overlayView) end)
    overlayView.onRightClick = UpToZone
    overlayView.down:SetPoint("BOTTOMLEFT", HINT_PAD, HINT_PAD / 2)
    overlay.hint = ns.Font(overlay, 12, nil, T.muted)
    overlay.hint:SetPoint("BOTTOMRIGHT", -HINT_PAD, HINT_PAD / 2 + 4)
end

-- The map panel's say: the dungeon to show on the world map (it is open, inside one), or
-- nil to hide it.
---@param dungeon? JournalDungeon
function J.ShowMapOnWorldMap(dungeon)
    if not (dungeon and J.Maps[dungeon.key]) then
        if overlay then overlay:Hide() end
        return
    end
    if not overlay then BuildOverlay() end
    overlayView:Open(dungeon)
    overlay.hint:SetText(dungeon.entrance and dungeon.zone and ("Right-click: " .. dungeon.zone) or "")
    overlay:Show()
    Fit()
    overlayView:Draw()
end

-- The world map changed size (maximised, or small again).
function J.FitMapOnWorldMap()
    if overlay and overlay:IsShown() then
        Fit()
        overlayView:Draw()
    end
end

-------------------------------------------------------------------------------
--  Opening
-------------------------------------------------------------------------------
-- Opens the map of the dungeon: from the panel beside the world map, on the world map; else
-- in the window, beside the window holding from. On the dungeon the window shows already,
-- it closes.
---@param dungeon JournalDungeon
---@param from? Frame what Map was clicked on
function J.OpenDungeonMap(dungeon, from)
    if not J.Maps[dungeon.key] then return end
    local owner = from and Owner(from)
    if owner and owner.onWorldMap then return J.ShowMapOnWorldMap(dungeon) end
    if not window then Build() end
    if window:IsShown() and windowView.dungeon == dungeon then
        window:Hide()
        return
    end
    windowView:Open(dungeon)
    Paint()
    Place(from)
    window:Show()
    window:Raise()
    windowView:Draw()
end

-- What the window shows, drawn again (a test, a setting).
function J.DrawDungeonMap()
    if window and window:IsShown() then windowView:Draw() end
end

-------------------------------------------------------------------------------
--  /nf mappins and /nf mapcheck
-------------------------------------------------------------------------------
local probe

-- Which floors of each map's art the client has: a file the client holds has an ID, one it
-- does not has none (SetTexture's own answer is true either way, measured 2 Oct 2026).
local function MapCheck()
    probe = probe or CreateFrame("Frame"):CreateTexture()
    local seen = {}
    for key, map in pairs(J.Maps) do
        if not seen[map.art] then
            seen[map.art] = true
            local found = {}
            for n = 1, 10 do
                probe:SetTexture(ART:format(map.art, map.art, n, 1))
                local id = probe:GetTextureFileID()
                if type(id) == "number" and id > 0 then found[#found + 1] = n end
            end
            ns.Print(("%s (%s): %s, data says %d"):format(map.art, key,
                #found > 0 and "floors " .. table.concat(found, ",") or "no art", map.floors))
        end
    end
    probe:SetTexture(nil)
    ns.Print(("Portraits: %s. Your position in here: %s."):format(
        SetPortraitTextureFromCreatureDisplayID and "yes" or "no",
        UnitPosition("player") and "yes" or "no"))
end

function ns.DungeonMapCommand(cmd)
    if cmd == "mapcheck" then return MapCheck() end
    placing = not placing
    ns.Print(placing and "Placing map pins: drag them, then Copy. /nf mappins again to stop."
        or "Placing map pins: off.")
    if window and window:IsShown() then
        windowView:FillFloors()
        windowView:Draw()
    end
end

-- The Journal switched off: the maps go with it. Its Opacity: the window follows.
S.OnChange(function(key)
    if key == "enabled" and not S.Get("enabled") then
        if window then window:Hide() end
        if overlay then overlay:Hide() end
    elseif key == "windowAlpha" and window then
        Paint()
    end
end)
