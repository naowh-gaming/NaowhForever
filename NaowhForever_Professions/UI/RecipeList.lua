-- RecipeList.lua: the window's recipe list on the left: headers, your recipes, the unlearned ones, the scrollbar.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local W = P.State
local R = P.Recipes
local V = P.Vendors
local Prices = P.Prices
local Favorites = P.Favorites
local Auctions = P.Auctions
local Shopping = P.Shopping
local Entries = P.Entries
local Orders = P.Orders
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets
local SetColor = Widgets.SetColor
local entries = Entries.list

local ROW_H = Style.ROW_H
local ROUND = P.C.ROUND
local SCROLL_W = 6
local SCROLL_INSET = 2
local SCROLL_STEP = 2
local THUMB_H, THUMB_MIN = 40, 20
local THUMB_ALPHA = 0.8
local ROW_INSET = 2
local ROW_RIGHT_ROOM = SCROLL_W + 6
local ICON_SHRINK = Style.ROW_ICON_SHRINK
local TEXT_GAP = 6
local STAR_GAP = 4
local STAR_SIZE = 12
local CART_SIZE = 12
local HEAD_X, SUB_HEAD_X = 4, 14
local COUNT_X, COUNT_GAP, ICON_X = 4, 6, 24
local TEXT_HEAD = "%s (%d)"
local TEXT_OPEN, TEXT_CLOSED = "-  ", "+  "
local TEXT_RECIPE = ns.L("Recipe ")
local TEXT_SEPARATOR = " | "
local TEXT_REQUIRED = ns.L("Required skill: %d  (%s)")

local win
local rows = {}
local listedText = {}
local inList, onSale

local List = {}
P.List = List

local function VisibleRows()
    return math.max(1, math.floor((win.list:GetHeight()) / ROW_H))
end

local function ListProfit(recipeID, output, made)
    local profit = not W.linked and S.Get("craftProfitList") and Prices.RecipeProfit(recipeID, output, made)
    if not profit then return "", T.fg end
    return Text.Money(profit, true), profit >= 0 and Style.PROFIT_RGB or Style.RED_RGB
end

local function FormatCraftCount(info)
    local have = R.Craftable(info)
    local plain = have > 0 and tostring(have) or ""
    if not S.Get("vendorMaterials") then return plain end
    local withVendor = V.CraftableWithVendor(info)
    if not withVendor or withVendor <= have then return plain end
    local orange = Text.Hex(Style.VENDOR_RGB) .. withVendor .. "|r"
    if have == 0 then return orange end
    return plain .. TEXT_SEPARATOR .. orange
end

local function AlignRows(visible)
    local width = 0
    for i = 1, visible do
        local row, e = rows[i], entries[i + W.offset]
        if row and e and not e.cat then width = math.max(width, row.count:GetStringWidth()) end
    end
    local iconX = math.max(ICON_X, width > 0 and COUNT_X + width + COUNT_GAP or 0)
    for i = 1, visible do
        local row, e = rows[i], entries[i + W.offset]
        if row and e and not e.cat then
            row.count:ClearAllPoints()
            row.count:SetPoint("RIGHT", row, "LEFT", iconX - COUNT_GAP, 0)
            row.icon:SetPoint("LEFT", iconX, 0)
        end
    end
end

local function Scroll(_, delta)
    W.offset = math.min(math.max(0, #entries - VisibleRows()), math.max(0, W.offset - delta * SCROLL_STEP))
    List.Render()
end

local function OnScrollValue(self, value)
    if self.syncing then return end
    W.offset = math.floor(value + ROUND)
    List.Render()
end

local function RedrawAll()
    Entries.Build()
    List.Render()
    P.Detail.Render()
end

local function SelectRecipe(info)
    W.selectedID, W.selectedUnlearned = info.recipeID, nil
    List.Render()
    P.Detail.Render()
end

local function OnRowClick(self, button)
    local e = self.entry
    if button == "RightButton" then
        if (e.recipe or e.unlearned) and not W.linked then
            Favorites.Toggle(e.recipe or e.unlearned)
            RedrawAll()
        end
        return
    end
    if e.cat then
        Entries.Toggle(e.cat)
        Entries.Build()
        List.Render()
    elseif e.unlearned then
        W.selectedUnlearned = e.unlearned
        List.Render()
        P.Detail.Render()
    elseif IsModifiedClick("CHATLINK") then
        local id = e.recipe.recipeID
        P.AH.ShiftClick((R.OutputItem(id)), C_TradeSkillUI.GetRecipeLink(id))
    else
        SelectRecipe(e.recipe)
    end
end

local function OnRowEnter(self)
    local r = self.entry.unlearned
    if r then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(r.spell)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_REQUIRED:format(ns.RecipeFinder.Skill(r), ns.RecipeFinder.Tag(r)), 1, 1, 1)
        GameTooltip:Show()
        return
    end
    if not self.entry.recipe then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(GameTooltip.SetRecipeResultItem, GameTooltip, self.entry.recipe.recipeID) then
        GameTooltip:SetSpellByID(self.entry.recipe.recipeID)
    end
    GameTooltip:Show()
end

local function NewRow(i)
    local row = CreateFrame("Button", nil, win.list)
    row:SetSize(Style.LEFT_W - ROW_RIGHT_ROOM, ROW_H)
    row:SetPoint("TOPLEFT", ROW_INSET, -ROW_INSET - (i - 1) * ROW_H)
    row.head = ns.Solid(row, "BACKGROUND", T.line, Style.PANEL_ALPHA)
    row.head:SetAllPoints()
    row.sel = ns.Solid(row, "BACKGROUND", T.accent, Style.SELECTED_ALPHA)
    row.sel:SetAllPoints()
    row.hl = ns.Solid(row, "HIGHLIGHT", T.fg, Style.HIGHLIGHT_ALPHA)
    row.hl:SetAllPoints()
    row.icon = Widgets.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(ROW_H - ICON_SHRINK, ROW_H - ICON_SHRINK)
    row.profit = ns.Font(row, Style.FONT, nil)
    row.profit:SetPoint("RIGHT", -TEXT_GAP, 0)
    row.profit:SetJustifyH("RIGHT")
    row.count = ns.Font(row, Style.FONT, nil)
    row.count:SetJustifyH("RIGHT")
    row.text = ns.Font(row, Style.FONT, nil)
    row.text:SetPoint("RIGHT", row.profit, "LEFT", -TEXT_GAP, 0)
    row.fav = row:CreateTexture(nil, "OVERLAY")
    row.fav:SetSize(STAR_SIZE, STAR_SIZE)
    row.fav:SetPoint("RIGHT", row.profit, "LEFT", -STAR_GAP, 0)
    Widgets.Star(row.fav, true)
    row.fav:Hide()
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnMouseWheel", Scroll)
    return row
end

local function ListedText(n)
    local text = listedText[n]
    if not text then
        text = Style.AUCTION_ICON .. n
        listedText[n] = text
    end
    return text
end

local function NewMarks(row)
    row.cart = row:CreateTexture(nil, "OVERLAY")
    row.cart:SetSize(CART_SIZE, CART_SIZE)
    row.cart:SetTexture(Style.BAG)
    row.listed = ns.Font(row, Style.FONT_SMALL, nil, T.muted)
end

local function Mark(part, shown, anchor)
    if not part then return anchor end
    part:SetShown(shown)
    if not shown then return anchor end
    part:SetPoint("RIGHT", anchor, "LEFT", -STAR_GAP, 0)
    return part
end

local function TextBeforeMarks(row, fav, cart, listed)
    local anchor = Mark(row.fav, fav, row.profit)
    if (cart or listed > 0) and not row.cart then NewMarks(row) end
    anchor = Mark(row.cart, cart, anchor)
    if cart then row.cart:SetVertexColor(T.accent.r, T.accent.g, T.accent.b) end
    anchor = Mark(row.listed, listed > 0, anchor)
    if listed > 0 then row.listed:SetText(ListedText(listed)) end
    row.text:SetPoint("RIGHT", anchor, "LEFT", anchor == row.profit and -TEXT_GAP or -STAR_GAP, 0)
end

local function FillHeader(row, cat)
    local label = cat.count and TEXT_HEAD:format(cat.name, cat.count) or cat.name
    row.text:SetText((Entries.IsCollapsed(cat) and TEXT_CLOSED or TEXT_OPEN) .. label)
    SetColor(row.text, Style.GOLD_RGB)
    row.text:SetPoint("LEFT", cat.sub and SUB_HEAD_X or HEAD_X, 0)
    row.count:SetText("")
    row.profit:SetText("")
    row.icon:Hide()
    TextBeforeMarks(row, false, false, 0)
    row.head:Show()
    row.sel:Hide()
end

local function FillUnlearned(row, r)
    local c = ns.RecipeFinder.Color(r)
    row.icon:SetTexture((r.item and C_Item.GetItemIconByID(r.item)) or C_Spell.GetSpellTexture(r.spell))
    row.icon:Show()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", TEXT_GAP, 0)
    row.text:SetText(C_Spell.GetSpellName(r.spell) or (TEXT_RECIPE .. r.spell))
    SetColor(row.text, c)
    row.count:SetText(ns.RecipeFinder.Skill(r))
    SetColor(row.count, c)
    local read, made = R.OutputItem(r.spell)
    local profit, color = ListProfit(r.spell, r.item or read, made)
    row.profit:SetText(profit)
    SetColor(row.profit, color)
    TextBeforeMarks(row, Favorites.Is(r), false, 0)
    row.head:Hide()
    row.sel:SetShown(r == W.selectedUnlearned)
end

local function FillRecipe(row, info)
    SetColor(row.count, T.fg)
    row.icon:SetTexture(info.icon)
    row.icon:Show()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", TEXT_GAP, 0)
    row.text:SetText(info.name)
    SetColor(row.text, Style.DIFFICULTY_RGB[info.relativeDifficulty] or T.fg)
    row.count:SetText(W.linked and Orders.Count(info.recipeID) or FormatCraftCount(info))
    local output = R.OutputItem(info.recipeID)
    local own = not W.linked
    TextBeforeMarks(row, own and Favorites.Is(info), own and inList ~= nil and inList[info.recipeID] ~= nil,
        own and onSale and output and onSale[output] or 0)
    local profit, color = ListProfit(info.recipeID, output)
    row.profit:SetText(profit)
    SetColor(row.profit, color)
    row.head:Hide()
    row.sel:SetShown(not W.selectedUnlearned and info.recipeID == W.selectedID)
end

local function FillRow(i, e)
    local row = rows[i]
    if not row then
        row = NewRow(i)
        rows[i] = row
    end
    row.entry = e
    row.icon:ClearAllPoints()
    if e.cat then
        FillHeader(row, e.cat)
    elseif e.unlearned then
        FillUnlearned(row, e.unlearned)
    else
        FillRecipe(row, e.recipe)
    end
    row:Show()
end

local function SyncScrollbar(visible)
    local bar, maxOffset = win.scroll, math.max(0, #entries - visible)
    if not bar then return end
    bar:SetShown(maxOffset > 0)
    if maxOffset <= 0 then return end
    bar.thumb:SetHeight(math.max(THUMB_MIN, bar:GetHeight() * visible / #entries))
    bar.syncing = true
    bar:SetMinMaxValues(0, maxOffset)
    bar:SetValue(W.offset)
    bar.syncing = nil
end

function List.Render()
    local visible = VisibleRows()
    inList, onSale = Shopping.MarkedCrafts(), Auctions.Counts()
    W.offset = math.min(W.offset, math.max(0, #entries - visible))
    for i = 1, visible do
        local e = entries[i + W.offset]
        if e then
            FillRow(i, e)
        elseif rows[i] then
            rows[i]:Hide()
        end
    end
    for i = visible + 1, #rows do rows[i]:Hide() end
    AlignRows(visible)
    SyncScrollbar(visible)
end

function List.Build(frame, below)
    win = frame
    local list = CreateFrame("Frame", nil, win)
    list:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -TEXT_GAP)
    list:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", Style.PAD, Style.PAD)
    list:SetWidth(Style.LEFT_W)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", Scroll)
    ns.Solid(list, "BACKGROUND", T.panel, Style.PANEL_ALPHA):SetAllPoints()
    win.list = list

    local bar = CreateFrame("Slider", nil, list)
    bar:SetPoint("TOPRIGHT", -SCROLL_INSET, -SCROLL_INSET)
    bar:SetPoint("BOTTOMRIGHT", -SCROLL_INSET, SCROLL_INSET)
    bar:SetWidth(SCROLL_W)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    ns.Solid(bar, "BACKGROUND", T.line, Style.PANEL_ALPHA):SetAllPoints()
    bar.thumb = bar:CreateTexture(nil, "ARTWORK")
    bar.thumb:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, THUMB_ALPHA)
    bar.thumb:SetSize(SCROLL_W, THUMB_H)
    bar:SetThumbTexture(bar.thumb)
    bar:SetScript("OnValueChanged", OnScrollValue)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", Scroll)
    win.scroll = bar
end

List.RedrawAll = RedrawAll
