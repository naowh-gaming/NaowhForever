-- RarePanel.lua: the focused rare's panel beside its star on the world map: what it is, its drops, two buttons.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local C = Completo.C
local Parts = ns.Shared.Parts
local Style = Completo.Style
local R = Completo.Rares

local PANEL_W, PAD, HEADER = Style.PANEL_W, Style.PANEL_PAD, Style.PANEL_HEADER
local DROP_H, DROP_ICON, TICK = 20, 16, 14
local BUTTON_H, BUTTON_GAP = 24, 4
local ROW_INSET = 2
local NAME_GAP = 6
local LINE_GAP = 3
local DROPS_GAP = 6
local BESIDE = 8
local HOVER_ALPHA = 0.06
local LINE_SIZE = 12
local TEXT_WAYPOINT = "Set a Waypoint"
local TEXT_OPEN = "Open in Completo"
local TEXT_RARE = "Rare"
local TEXT_ELITE = "Rare elite"
local TEXT_KIND_LEVEL = "%s, level %s"
local TEXT_NOT_KILLED = "Not killed yet"
local TEXT_PATROLS = "Patrols: the small stars are its way"
local TEXT_SPAWNS = "Spawns at %d more spots, shown smaller"
local TEXT_DROPS = "Drops"
local TEXT_MORE = "And %d more"
local TEXT_NO_DROPS = "No special drops"
local TEXT_DROPPED = "This rare dropped it for you."
local TEXT_WOWHEAD = "Right-click: Wowhead link"

local panel
local lineN, lineY

local Panel = {}
Completo.RarePanel = Panel

local function QualityColor(quality)
    return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or T.fg
end

local function DropEnter(row)
    local have = Style.HAVE_RGB
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.item[C.LOOT_ID])
    if R.NewInForever(row.item) then GameTooltip:AddLine(Parts.ForeverLine()) end
    if row.tick:IsShown() then GameTooltip:AddLine(TEXT_DROPPED, have.r, have.g, have.b) end
    GameTooltip:AddLine(TEXT_WOWHEAD, Style.Hint())
    GameTooltip:Show()
end

local function DropLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function DropClick(row, button)
    if button == "RightButton" then Parts.CopyWowhead("item", row.item[C.LOOT_ID], row.item[C.LOOT_NAME]) end
end

local function NewDropRow()
    local have = Style.HAVE_RGB
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_W - PAD * 2, DROP_H)
    row:RegisterForClicks("RightButtonUp")
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, HOVER_ALPHA)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.icon = Parts.ItemIcon(row, DROP_ICON)
    row.icon:SetPoint("LEFT", ROW_INSET, 0)
    row.chance = ns.Font(row, Style.SMALL_SIZE, nil, T.muted)
    row.chance:SetPoint("RIGHT", -ROW_INSET, 0)
    row.chance:SetJustifyH("RIGHT")
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetTexture(Style.TICK, nil, nil, "TRILINEAR")
    row.tick:SetSize(TICK, TICK)
    row.tick:SetVertexColor(have.r, have.g, have.b)
    row.tick:SetPoint("RIGHT", row.chance, "LEFT", -NAME_GAP, 0)
    row.name = ns.Font(row, LINE_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
    row.name:SetPoint("RIGHT", row.tick, "LEFT", -NAME_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", DropEnter)
    row:SetScript("OnLeave", DropLeave)
    row:SetScript("OnClick", DropClick)
    return row
end

local function LetGo()
    if Panel.onLetGo then Panel.onLetGo() end
end

local function PanelWaypoint()
    local pin = panel.pin
    if pin then ns.PlaceWaypoint(R.Name(pin.npc), R.Map(pin.npc), pin.spotX, pin.spotY) end
end

local function OpenInCompleto()
    local npc = panel.npc
    LetGo()
    ns.OpenCompletoWindow("rares", npc)
end

local function BuildPanel()
    panel = Parts.Panel("")
    panel:SetParent(WorldMapFrame)
    panel:SetFrameStrata("DIALOG")
    panel.close._onClick = LetGo
    panel.lines = {}
    panel.rows = {}
    local width = (PANEL_W - PAD * 2 - BUTTON_GAP) / 2
    panel.waypoint = ns.Button(panel, TEXT_WAYPOINT, width, BUTTON_H, PanelWaypoint)
    panel.waypoint:SetPoint("BOTTOMLEFT", PAD, PAD)
    panel.open = ns.Button(panel, TEXT_OPEN, width, BUTTON_H, OpenInCompleto)
    panel.open:SetPoint("LEFT", panel.waypoint, "RIGHT", BUTTON_GAP, 0)
    panel:Hide()
end

local function LineAt(i)
    local fs = panel.lines[i]
    if fs then return fs end
    fs = ns.Font(panel, LINE_SIZE, nil, T.fg)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(PANEL_W - PAD * 2)
    panel.lines[i] = fs
    return fs
end

local function Add(text, color)
    lineN = lineN + 1
    local fs = LineAt(lineN)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", PAD, -lineY)
    fs:SetText(text)
    fs:SetTextColor(color.r, color.g, color.b)
    fs:Show()
    lineY = lineY + math.ceil(fs:GetStringHeight()) + LINE_GAP
end

local function SetDropRow(i, npc, item)
    local row = panel.rows[i] or NewDropRow()
    panel.rows[i] = row
    row.item = item
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", PAD, -lineY)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(item[C.LOOT_ID]) or C.FALLBACK_ICON)
    local name = item[C.LOOT_NAME]
    if R.NewInForever(item) then name = name .. Parts.ForeverInline(C.FOREVER_SIGN_SIZE) end
    row.name:SetText(name)
    local c = QualityColor(item[C.LOOT_QUALITY])
    row.name:SetTextColor(c.r, c.g, c.b)
    row.tick:SetShown(R.Dropped(npc, item[C.LOOT_ID]))
    row.chance:SetText(R.ChanceText(item[C.LOOT_CHANCE]))
    row:Show()
    lineY = lineY + DROP_H
end

local function AddAbout(npc)
    Add(TEXT_KIND_LEVEL:format(R.Elite(npc) and TEXT_ELITE or TEXT_RARE, R.LevelText(npc)), Style.GOLD_RGB)
    local record = R.Record(npc)
    Add(record and R.KilledText(record) or TEXT_NOT_KILLED, record and Style.HAVE_RGB or T.fg)
    if R.Trail(npc) then Add(TEXT_PATROLS, T.muted) end
    local others = R.SpotCount(npc) - 1
    if others > 0 then Add(TEXT_SPAWNS:format(others), T.muted) end
end

local function AddDrops(npc)
    local loot = R.Loot(npc)
    lineY = lineY + DROPS_GAP
    if not loot then return Add(TEXT_NO_DROPS, T.muted) end
    Add(TEXT_DROPS, Style.GOLD_RGB)
    for i, item in ipairs(loot) do SetDropRow(i, npc, item) end
    if loot.more then Add(TEXT_MORE:format(loot.more), T.muted) end
end

local function Clear()
    for _, fs in ipairs(panel.lines) do fs:Hide() end
    for _, row in ipairs(panel.rows) do row:Hide() end
    lineN, lineY = 0, HEADER
end

function Panel.Place(pin)
    panel:ClearAllPoints()
    local right = (pin:GetRight() or 0) * pin:GetEffectiveScale()
    local room = UIParent:GetRight() * UIParent:GetEffectiveScale() - right
    if room >= (PANEL_W + BESIDE) * panel:GetEffectiveScale() then
        panel:SetPoint("TOPLEFT", pin, "TOPRIGHT", BESIDE, 0)
    else
        panel:SetPoint("TOPRIGHT", pin, "TOPLEFT", -BESIDE, 0)
    end
end

function Panel.Show(pin)
    if not panel then BuildPanel() end
    local npc = pin.npc
    if panel:IsShown() and panel.npc == npc and panel.pin == pin then return end
    panel.npc, panel.pin = npc, pin
    panel.title:SetText(R.Name(npc))
    Clear()
    AddAbout(npc)
    AddDrops(npc)
    panel:SetHeight(lineY + PAD + BUTTON_H + PAD)
    Panel.Place(pin)
    panel:Show()
end

function Panel.Hide()
    if not panel then return end
    panel:Hide()
    panel.npc, panel.pin = nil, nil
end

function Panel.Reside()
    if panel and panel:IsShown() and panel.pin then Panel.Place(panel.pin) end
end
