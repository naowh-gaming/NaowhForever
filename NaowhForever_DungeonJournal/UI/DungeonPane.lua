-- DungeonPane.lua: the new look's dungeon page: its header, the map, quests or keys on the left, and on the right the boss portraits over every boss's loot or the picked boss (J.DungeonPane).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Map = J.DungeonMap
local Parts = J.View.Parts
local C = J.C
local St = J.Style
local TAB_H, TEXT_SIZE, SCROLLBAR = St.TAB_H, St.TEXT_SIZE, St.SCROLLBAR
local LIST_BAR, LIST_BAR_GAP = St.LIST_BAR, St.LIST_BAR_GAP

local LEFT_W = 440
local PANE_GAP, ROW_GAP, HEAD_GAP = 16, 8, 10
local MAP_SHARE = 2 / 3
local MAP_MIN_W = 240
local BACK_H, BACK_SIZE = 22, 12
local TEXT_ALL_BOSSES = ns.L("< All bosses")
local FACE_MAX, FACE_GAP, FACE_RING = 44, 10, 2
local FACE_MIN_BOX, FACE_ROW_GAP = 30, 6
local FACE_LEVEL_GAP, FACE_LEVEL_H = 2, 12
local STRIP_H = FACE_MAX + FACE_RING * 2 + FACE_LEVEL_GAP + FACE_LEVEL_H + ROW_GAP
local stripH = STRIP_H
local PlaceMain
local FLOOR_TOP = TAB_H + ROW_GAP
local FLOOR_ROW = TAB_H + ROW_GAP
local CIRCLE = ns.MEDIA .. "circle_mask.tga"
local CIRCLE_WRAP = "CLAMPTOBLACKADDITIVE"
local SKULL_LEVEL = "??"
local KILLED_ALPHA = 0.55
local TEXT_LEVEL = ns.L("Level ")
local NAMED_FLOORS, NUMBER_W, FLOOR_NAME_GAP = 3, 48, 10
local SIDE_TOP = TAB_H + ROW_GAP
local MAP, QUESTS, KEYS = "map", "quests", "keys"
local TAB_MAP = { key = MAP, label = "Map and Boss" }
local TAB_QUESTS = { key = QUESTS, label = "Quests" }
local TAB_KEYS = { key = KEYS, label = "Keys" }

local SOON_SIZE, SOON_GAP, SOON_ART = 18, 6, 0.25
local BUTTON_ART = { left = 10 / 256, right = 164 / 256, top = 10 / 128, bottom = 86 / 128 }

local TEXT_NO_MAP = ns.L("No map of this dungeon yet.")
local TEXT_COMING_SOON = ns.L("Coming soon")

local frame, left, tabs, headView, mapView, infoScroll, infoView, sideScroll, sideView, noMap
local floorTabs, floorName, strip, backButton
local faces = {}
local ShowBoss
local floorItems, floorPool = {}, {}
local mainView, mainScroll
local dungeon, picked
local mode = MAP
local width, headHeight = 0, 0
local leftW, wantW = LEFT_W, LEFT_W
local stripW = 0
local mapW = LEFT_W
local floorRow = false
local tabItems = {}

local function MapHeight(w)
    return math.floor(C.MAP_H * w / C.MAP_W)
end

local function Round(owner, texture)
    local mask = owner:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture(CIRCLE, CIRCLE_WRAP, CIRCLE_WRAP)
    texture:AddMaskTexture(mask)
    return texture
end

local function FaceLevel(boss)
    local info = boss.npc and J.BossInfo[boss.npc]
    local text = info and Parts.BossLevel(info)
    if not text then return nil end
    local high = info[2]
    if text == SKULL_LEVEL or not high or high < 0 then return text, St.SKULL_LEVEL_RGB end
    return text, GetQuestDifficultyColor(high)
end

local function PaintFace(face)
    local lit = face.boss == picked
    local color = lit and T.accent or face:IsMouseOver() and T.accentSoft or St.BORDER_RGB
    face.ring:SetColorTexture(color.r, color.g, color.b, 1)
end

local function PaintStrip()
    for _, face in ipairs(faces) do
        if face:IsShown() then PaintFace(face) end
    end
end

local function FaceEnter(face)
    PaintFace(face)
    GameTooltip:SetOwner(face, "ANCHOR_BOTTOM")
    GameTooltip:SetText(face.boss.name, 1, 1, 1)
    if face.levelText then
        local c = face.levelColor
        GameTooltip:AddLine(TEXT_LEVEL .. face.levelText, c.r, c.g, c.b)
    end
    GameTooltip:Show()
end

local function FaceLeave(face)
    PaintFace(face)
    GameTooltip:Hide()
end

local function FaceClicked(face)
    ShowBoss(face.boss ~= picked and face.boss or nil, true)
end

local function NewFace()
    local face = CreateFrame("Button", nil, strip)
    face.ring = Round(face, face:CreateTexture(nil, "BORDER"))
    face.ring:SetAllPoints()
    face.disc = Round(face, face:CreateTexture(nil, "ARTWORK", nil, -1))
    face.disc:SetColorTexture(T.panel.r, T.panel.g, T.panel.b, 1)
    face.disc:SetPoint("TOPLEFT", FACE_RING, -FACE_RING)
    face.disc:SetPoint("BOTTOMRIGHT", -FACE_RING, FACE_RING)
    face.art = Round(face, face:CreateTexture(nil, "ARTWORK"))
    face.art:SetAllPoints(face.disc)
    face.number = ns.Font(face, St.SMALL_SIZE, nil, T.muted)
    face.number:SetPoint("CENTER")
    face.level = ns.Font(face, St.TINY_SIZE, nil, T.fg)
    face.level:SetPoint("TOP", face, "BOTTOM", 0, -FACE_LEVEL_GAP)
    face:SetScript("OnEnter", FaceEnter)
    face:SetScript("OnLeave", FaceLeave)
    face:SetScript("OnClick", FaceClicked)
    return face
end

local function StripBosses(shown, list)
    for _, wing in ipairs(shown.wings) do
        for _, boss in ipairs(wing.bosses) do
            if not (boss.trash or boss.chest) then list[#list + 1] = boss end
        end
    end
    return list
end

local stripBosses = {}

local function DrawStrip()
    if not (strip and dungeon) then return end
    wipe(stripBosses)
    local bosses = StripBosses(dungeon, stripBosses)
    local n = #bosses
    local perRow = math.max(1, math.floor((stripW + FACE_GAP) / (FACE_MIN_BOX + FACE_GAP)))
    local rows = math.max(1, math.ceil(n / perRow))
    local cols = math.max(1, math.ceil(n / rows))
    local box = math.max(FACE_MIN_BOX, math.min(FACE_MAX + FACE_RING * 2,
        math.floor((stripW + FACE_GAP) / cols) - FACE_GAP))
    local rowH = box + FACE_LEVEL_GAP + FACE_LEVEL_H + FACE_ROW_GAP
    local inside = mapView and mapView.inside
    for i, boss in ipairs(bosses) do
        local face = faces[i] or NewFace()
        faces[i] = face
        face.boss = boss
        face:SetSize(box, box)
        face:ClearAllPoints()
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        face:SetPoint("TOPLEFT", col * (box + FACE_GAP), -row * rowH)
        local hasArt = boss.model ~= nil
        if hasArt then SetPortraitTextureFromCreatureDisplayID(face.art, boss.model) end
        face.art:SetShown(hasArt)
        face.number:SetText(hasArt and "" or tostring(i))
        local killed = inside and J.Kills.ThisRun(boss) or false
        face.art:SetDesaturated(killed == true)
        face:SetAlpha(killed and KILLED_ALPHA or 1)
        face.levelText, face.levelColor = FaceLevel(boss)
        face.level:SetText(face.levelText or "")
        if face.levelColor then
            face.level:SetTextColor(face.levelColor.r, face.levelColor.g, face.levelColor.b)
        end
        face:Show()
    end
    for i = n + 1, #faces do faces[i]:Hide() end
    PaintStrip()
    local height = rows * rowH - FACE_ROW_GAP + ROW_GAP
    strip:SetHeight(height - ROW_GAP)
    if height ~= stripH then
        stripH = height
        if PlaceMain and mainScroll then PlaceMain() end
    end
end

local function PlaceMap(drawing)
    local top = FLOOR_TOP + (floorRow and FLOOR_ROW or 0)
    mapW = leftW
    local roomH = frame:GetHeight() - headHeight - HEAD_GAP
    if roomH and roomH > 0 then
        local fitW = math.floor((roomH - top) * C.MAP_W / C.MAP_H)
        mapW = math.max(MAP_MIN_W, math.min(leftW, fitW))
    end
    local scale = mapW / C.MAP_W
    local rescaled = scale ~= mapView.scale
    mapView.scale = scale
    mapView.canvas:SetScale(scale)
    mapView.canvas:ClearAllPoints()
    mapView.canvas:SetPoint("TOPLEFT", math.floor((leftW - mapW) / 2) / scale, -top / scale)
    noMap:SetSize(leftW, MapHeight(mapW))
    if rescaled and not drawing and mode == MAP and dungeon and J.Maps[dungeon.key] then mapView:Draw() end
end

local function SizeLeft()
    leftW = wantW
    local sideW = leftW - LIST_BAR - LIST_BAR_GAP
    left:SetWidth(leftW)
    tabs:SetWidth(leftW)
    Parts.SetTabs(tabs, tabItems)
    PlaceMap()
    sideScroll:SetWidth(sideW)
    sideView:SetWidth(sideW)
end

local function IsBoss(row, boss)
    return row.boss == boss
end

function PlaceMain(height)
    headHeight = height or headHeight
    local top = headHeight + HEAD_GAP
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", 0, -top)
    left:SetPoint("BOTTOMLEFT")
    local right = leftW + PANE_GAP
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", right, -top)
    mainScroll:ClearAllPoints()
    mainScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", right, -(top + stripH))
    backButton:ClearAllPoints()
    backButton:SetPoint("TOPLEFT", frame, "TOPLEFT", right, -(top + stripH))
    infoScroll:ClearAllPoints()
    infoScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", right, -(top + stripH + BACK_H))
    infoScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", right, 0)
    mainScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR, 0)
    if mapView then PlaceMap() end
end

local function ShowSide()
    local one = picked ~= nil and frame:IsShown()
    mainScroll:SetShown(not one)
    if one then mainScroll.bar:Hide() end
    backButton:SetShown(one)
    infoScroll:SetShown(one)
end

function ShowBoss(boss, scrollTo)
    local was = picked
    picked = boss
    mainView.marked = boss
    mainView:ApplyPin()
    PaintStrip()
    ShowSide()
    if boss then
        infoScroll:SetVerticalScroll(0)
        infoView:DrawBossInfo(boss, dungeon)
    elseif scrollTo and was then
        local row = mainView:Find("boss", IsBoss, was)
        if row then mainView:ScrollToRow(mainScroll, row) end
    end
    if mode ~= MAP or not J.Maps[dungeon.key] then return end
    if not boss then
        mapView:Pick(nil)
        return
    end
    do
        local key = Map.KeyOf(boss)
        local spot = Map.Spot(dungeon, key)
        if type(spot) == "table" and mapView.floor ~= spot[1] and mapView:FloorAt(spot[1]) then
            mapView.floor = spot[1]
            mapView:Draw()
        end
        mapView:Pick(key)
    end
end

local function PinPicked(boss)
    ShowBoss(boss ~= picked and boss or nil, true)
end

local function HideStepper()
    mapView.down:Hide()
    mapView.up:Hide()
    mapView.floorName:Hide()
end

local function FloorPicked(floor)
    mapView.floor = floor
    mapView:Draw()
end

local function MapDrawn()
    HideStepper()
    local floors, map = mapView.floors, J.Maps[dungeon.key]
    local named = #floors <= NAMED_FLOORS
    wipe(floorItems)
    for i, floor in ipairs(floors) do
        local item = floorPool[i] or {}
        floorPool[i] = item
        item.key, item.label = floor, named and Map.FloorName(map, floor) or tostring(i)
        floorItems[i] = item
    end
    floorTabs:SetShown(#floors > 1)
    if floorRow ~= (#floors > 1) then
        floorRow = #floors > 1
        PlaceMap(true)
    end
    floorTabs:SetWidth(named and leftW or math.min(leftW, #floors * NUMBER_W))
    Parts.SetTabs(floorTabs, floorItems)
    Parts.PaintTabs(floorTabs, mapView.floor)
    floorName:SetShown(#floors > 1 and not named)
    floorName:SetText(Map.FloorName(map, mapView.floor))
end

local function ShowMap(shown)
    local has = shown and J.Maps[dungeon.key] ~= nil
    mapView.canvas:SetShown(has)
    noMap:SetShown(shown and not has)
    local painting = J.Paintings[dungeon.key]
    noMap.art:SetShown(painting ~= nil)
    if painting then noMap.art:SetTexture(painting[1]) end
    if has then
        mapView:Draw()
    else
        HideStepper()
        floorTabs:Hide()
        floorName:Hide()
        if floorRow then
            floorRow = false
            PlaceMap()
        end
    end
end

local function ShowMode()
    Parts.PaintTabs(tabs, mode)
    ShowMap(mode == MAP)
    sideScroll:SetShown(mode ~= MAP)
    ShowBoss(picked)
    if mode == MAP then
        return
    elseif mode == QUESTS then
        sideView.part = "DrawAside"
        sideView:DrawAside(dungeon)
    else
        sideView.part = "DrawKeysPage"
        sideView:DrawKeysPage(dungeon)
    end
end

local function TabPicked(key)
    mode = key
    ShowMode()
end

local function BuildMap()
    mapView = Map.NewView(left, left, false)
    mapView.onPick = PinPicked
    mapView.onDraw = MapDrawn
    mapView.down:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -FLOOR_TOP)
    strip = CreateFrame("Frame", nil, frame)
    strip:SetSize(LEFT_W, STRIP_H - ROW_GAP)
    floorTabs = Parts.Tabs(left, LEFT_W, floorItems, FloorPicked)
    floorTabs.equal = true
    floorTabs:SetPoint("TOPLEFT", 0, -FLOOR_TOP)
    floorName = ns.Font(left, TEXT_SIZE, nil, T.fg)
    floorName:SetPoint("LEFT", floorTabs, "RIGHT", FLOOR_NAME_GAP, 0)
    noMap = CreateFrame("Frame", nil, left)
    noMap:SetPoint("TOPLEFT", 0, -FLOOR_TOP)
    ns.Solid(noMap, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(noMap, St.BORDER_RGB)
    noMap.art = noMap:CreateTexture(nil, "BORDER")
    noMap.art:SetAllPoints()
    noMap.art:SetTexCoord(BUTTON_ART.left, BUTTON_ART.right, BUTTON_ART.top, BUTTON_ART.bottom)
    noMap.art:SetAlpha(SOON_ART)
    local title = ns.Font(noMap, SOON_SIZE, nil, T.fg)
    title:SetPoint("BOTTOM", noMap, "CENTER", 0, SOON_GAP / 2)
    title:SetText(TEXT_COMING_SOON)
    local note = ns.Font(noMap, TEXT_SIZE, nil, T.muted)
    note:SetPoint("TOP", noMap, "CENTER", 0, -SOON_GAP / 2)
    note:SetText(TEXT_NO_MAP)
end

local function BuildViews()
    infoScroll = ns.UI.SlimScroll(frame, LIST_BAR, LIST_BAR_GAP)
    infoScroll:Hide()
    infoView = J.View.New(infoScroll)
    infoView.part = "RedrawInfo"
    infoView.withLoot = true
    backButton = CreateFrame("Button", nil, frame)
    backButton:SetHeight(BACK_H)
    backButton.text = ns.Font(backButton, BACK_SIZE, nil, T.accent)
    backButton.text:SetPoint("LEFT")
    backButton.text:SetText(TEXT_ALL_BOSSES)
    backButton:SetWidth(math.ceil(backButton.text:GetStringWidth()) + St.BACK_TEXT_PAD)
    backButton:SetScript("OnEnter", function(b) b.text:SetTextColor(T.fg.r, T.fg.g, T.fg.b) end)
    backButton:SetScript("OnLeave", function(b) b.text:SetTextColor(T.accent.r, T.accent.g, T.accent.b) end)
    backButton:SetScript("OnClick", function() ShowBoss(nil, true) end)
    backButton:Hide()
    infoScroll:SetScrollChild(infoView)
    sideScroll = ns.UI.SlimScroll(left, LIST_BAR, LIST_BAR_GAP)
    sideScroll:SetPoint("TOPLEFT", 0, -SIDE_TOP)
    sideScroll:SetPoint("BOTTOMLEFT")
    sideView = J.View.New(sideScroll)
    sideView.questInline = true
    sideScroll:SetScrollChild(sideView)
end

local Pane = {}
J.DungeonPane = Pane

function Pane.Built()
    return frame ~= nil
end

function Pane.Build(window, view, scroll, navigate, step)
    mainView, mainScroll = view, scroll
    scroll:HookScript("OnShow", function(self)
        if frame and frame:IsShown() and picked then self:Hide() end
    end)
    scroll.bar:HookScript("OnShow", function(bar)
        if not scroll:IsShown() then bar:Hide() end
    end)
    frame = CreateFrame("Frame", nil, window)
    headView = J.View.New(frame)
    headView.part = "DrawHead"
    headView.newLook = true
    headView.navigate, headView.step = navigate, step
    headView.onResize = PlaceMain
    headView:SetPoint("TOPLEFT")
    left = CreateFrame("Frame", nil, frame)
    left:SetScript("OnSizeChanged", function() if mapView then PlaceMap() end end)
    tabs = Parts.Tabs(left, LEFT_W, tabItems, TabPicked)
    tabs.equal = true
    tabs:SetPoint("TOPLEFT")
    BuildMap()
    BuildViews()
    SizeLeft()
end

function Pane.Grown(roomW, roomH, baseW)
    local paneW = math.min(math.floor(baseW * (S.Get("mapSize") or 1)), baseW + math.max(0, roomW))
    return paneW - baseW, 0
end

function Pane.Place(x, top, right, bottom)
    width = frame:GetParent():GetWidth() - x - right
    wantW = math.floor(width * MAP_SHARE)
    if leftW ~= wantW then SizeLeft() end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", x, -top)
    frame:SetPoint("BOTTOMRIGHT", -right, bottom)
    headView:SetWidth(width)
    mainView:SetWidth(width - leftW - PANE_GAP - SCROLLBAR)
    stripW = width - leftW - PANE_GAP - SCROLLBAR
    infoScroll:SetWidth(stripW + SCROLLBAR - LIST_BAR - LIST_BAR_GAP)
    infoView:SetWidth(stripW + SCROLLBAR - LIST_BAR - LIST_BAR_GAP)
    strip:SetWidth(stripW)
    DrawStrip()
    PlaceMain()
end

function Pane.SetShown(shown)
    frame:SetShown(shown)
    if shown then
        ShowSide()
    elseif not mainScroll:IsShown() then
        mainScroll:Show()
    end
end

function Pane.Show(shown)
    local same = shown == dungeon
    dungeon = shown
    headView:DrawHead(shown)
    wipe(tabItems)
    tabItems[1], tabItems[2] = TAB_MAP, TAB_QUESTS
    if J.Keys[shown.key] then tabItems[3] = TAB_KEYS end
    Parts.SetTabs(tabs, tabItems)
    if mode == KEYS and not tabItems[3] then mode = MAP end
    if not same then
        picked = nil
        sideView.openQuest = nil
        if J.Maps[shown.key] then mapView:Open(shown) end
    end
    DrawStrip()
    ShowMode()
end

function Pane.Pick(boss)
    ShowBoss(boss, true)
end

function Pane.Redraw()
    if not (frame and frame:IsShown() and dungeon) then return end
    headView:Redraw()
    DrawStrip()
    if picked then infoView:Redraw() end
    if mode == MAP then
        if J.Maps[dungeon.key] then mapView:Draw() end
    else
        sideView:Redraw()
    end
end
