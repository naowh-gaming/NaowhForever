-- FavouritesPanel.lua: Favourites on the window's title bar: this character's favourite items, where each drops, and whether you have it (J.FavouritesPanel).
local ns = _G.NaowhForever

local GetItemIconByID = C_Item.GetItemIconByID
local GetItemQualityByID = C_Item.GetItemQualityByID
local GetItemQualityColor = C_Item.GetItemQualityColor

local T = ns.THEME
local J = ns.Journal
local Loot = J.Loot
local Favourites = J.Favourites
local Rep = J.Reputation
local Parts = J.View.Parts
local St = J.Style
local BORDER_RGB, HOVER, FAVOURITE, CHECK, CROSS = St.BORDER_RGB, St.ITEM_HOVER, St.FAVOURITE, St.CHECK, St.CROSS
local HAVE_RGB, TEXT_SIZE, HEADING_SIZE = St.HAVE_RGB, St.TEXT_SIZE, St.HEADING_SIZE

local ROW_H = 26
local HEAD = 30
local FOOT = 8
local INSET = 20
local ICON = 16
local ICON_GAP = 8
local MAX_SHOWN = 10
local FROM_W, WHERE_W, CHANCE_W = 150, 150, 40
local TICK, REMOVE = 14, 16
local COLUMN_GAP = 12
local TITLE_TOP = 10
local PANEL_W, PANEL_PAD, PANEL_DROP = 760, 8, 6
local SCROLL_ROOM = 10
local COMMON = 1

local TEXT_FAVOURITES = ns.L("Favourites")
local TEXT_TIP = ns.L("The items you are after, where each drops and whether you have it.")
local TEXT_EMPTY = ns.L("No favourites yet. Right-click an item in the Journal to add one.")
local TEXT_OPEN_HINT = ns.L("Click to show where it comes from.")
local TEXT_REMOVE = "Remove from Favourites"
local TEXT_ITEM = ns.L("Item ")
local TEXT_UNDER_ONE = "<1%"
local TEXT_PERCENT = "%d%%"
local TEXT_NONE = "-"

local entries = {}
local panel, button, show
local Fill

local function RowEnter(row)
    local muted = T.muted
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip_SuppressAutomaticCompareItem(GameTooltip)
    local notYet = J.NotYet[row.itemID]
    if notYet then
        GameTooltip:SetText(Loot.Name(row.itemID), 1, 1, 1)
    else
        GameTooltip:SetItemByID(row.itemID)
    end
    if row.page then
        GameTooltip:AddLine(row.page.name, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
        GameTooltip:AddLine(TEXT_OPEN_HINT, muted.r, muted.g, muted.b)
    end
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function RowClick(row)
    if not row.page then return end
    panel:Hide()
    show(row.page, row.itemID)
end

local function RemoveClicked(remove)
    Favourites.Toggle(remove:GetParent().itemID)
    GameTooltip:Hide()
    Fill()
    ns.RedrawJournalWindow()
end

local function Column(row, width, justify)
    local font = ns.Font(row, TEXT_SIZE, nil, T.muted)
    font:SetWidth(width)
    font:SetJustifyH(justify)
    font:SetWordWrap(false)
    return font
end

local function NewRow(list, index)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT")
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.icon = CreateFrame("Frame", nil, row)
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", INSET / 2, 0)
    row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.texture:SetAllPoints()
    ns.Border(row.icon, BORDER_RGB)
    row.remove = Parts.IconButton(row, RemoveClicked, CROSS, 0, TEXT_REMOVE)
    row.remove:SetSize(REMOVE, REMOVE)
    row.remove.icon:SetSize(REMOVE, REMOVE)
    row.remove:SetPoint("RIGHT", -INSET / 2, 0)
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetTexture(CHECK)
    row.tick:SetSize(TICK, TICK)
    row.tick:SetPoint("RIGHT", row.remove, "LEFT", -COLUMN_GAP, 0)
    row.tick:SetVertexColor(HAVE_RGB.r, HAVE_RGB.g, HAVE_RGB.b)
    row.chance = Column(row, CHANCE_W, "RIGHT")
    row.chance:SetPoint("RIGHT", row.tick, "LEFT", -COLUMN_GAP, 0)
    row.where = Column(row, WHERE_W, "LEFT")
    row.where:SetPoint("RIGHT", row.chance, "LEFT", -COLUMN_GAP, 0)
    row.from = Column(row, FROM_W, "LEFT")
    row.from:SetPoint("RIGHT", row.where, "LEFT", -COLUMN_GAP, 0)
    row.name = ns.Font(row, HEADING_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.from, "LEFT", -COLUMN_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    return row
end

local function FromText(from)
    if not from then return "" end
    if from.standing then return Rep.Label(from.standing) end
    return from.name
end

local function ChanceText(chance)
    if not (chance and chance > 0) then return TEXT_NONE end
    if chance < 1 then return TEXT_UNDER_ONE end
    return TEXT_PERCENT:format(chance)
end

local function Quality(id)
    local facts = J.Facts(id)
    return GetItemQualityByID(id) or facts and facts[J.FACT.QUALITY] or COMMON
end

local function ShowEntry(row, entry)
    local id = entry.id
    row.itemID, row.page = id, entry.page
    local notYet = J.NotYet[id]
    row.icon.texture:SetTexture(notYet and notYet[J.FACT.ICON] or GetItemIconByID(id))
    row.name:SetText(Loot.Name(id) or TEXT_ITEM .. id)
    local r, g, b = GetItemQualityColor(Quality(id))
    row.name:SetTextColor(r, g, b)
    row.from:SetText(FromText(entry.from))
    row.where:SetText(entry.page and entry.page.name or "")
    row.chance:SetText(ChanceText(entry.chance))
    row.tick:SetShown(Loot.Have(id))
    row:Show()
end

function Fill()
    local list = Favourites.List(entries)
    local rows = panel.rows
    for i = 1, #list do
        rows[i] = rows[i] or NewRow(panel.list, i)
        ShowEntry(rows[i], list[i])
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    panel.empty:SetShown(#list == 0)
    panel.list:SetHeight(math.max(#list, 1) * ROW_H)
    local shown = math.min(math.max(#list, 1), MAX_SHOWN)
    panel:SetHeight(HEAD + shown * ROW_H + FOOT + PANEL_PAD * 2)
end

local function MouseDown()
    if not (panel:IsMouseOver() or button:IsMouseOver()) then panel:Hide() end
end

local function PanelShown(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
end

local function PanelHidden(self)
    self:UnregisterAllEvents()
    self:Hide()
end

local function Build()
    panel = CreateFrame("Frame", nil, button)
    panel:SetWidth(PANEL_W)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -PANEL_DROP)
    ns.Solid(panel, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(panel, BORDER_RGB)
    panel.title = ns.Font(panel, TEXT_SIZE, nil, T.muted)
    panel.title:SetPoint("TOPLEFT", PANEL_PAD + INSET, -(PANEL_PAD + TITLE_TOP))
    panel.title:SetText(TEXT_FAVOURITES)
    local scroll = ns.UI.SlimScroll(panel)
    scroll:SetPoint("TOPLEFT", PANEL_PAD + INSET / 2, -(PANEL_PAD + HEAD))
    scroll:SetPoint("BOTTOMRIGHT", -(PANEL_PAD + SCROLL_ROOM), PANEL_PAD + FOOT)
    panel.list = CreateFrame("Frame", nil, scroll)
    panel.list:SetWidth(PANEL_W - PANEL_PAD * 2 - INSET / 2 - SCROLL_ROOM)
    scroll:SetScrollChild(panel.list)
    panel.rows = {}
    panel.empty = ns.Font(panel.list, TEXT_SIZE, nil, T.muted)
    panel.empty:SetPoint("TOPLEFT", INSET / 2, 0)
    panel.empty:SetPoint("RIGHT")
    panel.empty:SetHeight(ROW_H)
    panel.empty:SetJustifyH("LEFT")
    panel.empty:SetText(TEXT_EMPTY)
    panel:SetScript("OnShow", PanelShown)
    panel:SetScript("OnHide", PanelHidden)
    panel:SetScript("OnEvent", MouseDown)
    panel:Hide()
end

local function Clicked()
    if not panel then Build() end
    if panel:IsShown() then
        panel:Hide()
        return
    end
    GameTooltip:Hide()
    panel:Show()
    Fill()
end

local function Enter(self)
    Parts.LightBarIcon(self, true)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(TEXT_FAVOURITES, 1, 1, 1)
    GameTooltip:AddLine(TEXT_TIP, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local FavouritesPanel = {}
J.FavouritesPanel = FavouritesPanel

function FavouritesPanel.Button(window, onPick)
    show = onPick
    button = Parts.BarIcon(window, FAVOURITE, true)
    button:SetScript("OnClick", Clicked)
    button:SetScript("OnEnter", Enter)
    return button
end
