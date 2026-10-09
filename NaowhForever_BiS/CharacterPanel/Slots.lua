-- Slots.lua: the character panel's slots in the BiS List's look, and their marks.
local ns = _G.NaowhForever

local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo

local S = ns.QoLSettings
local CP = ns.CharacterPanel
local C = CP.C
local B = ns.BiS
local Shared = ns.Shared
local Items, Parts, St = Shared.Items, Shared.Parts, Shared.Style

local CROP_IN, CROP_OUT = C.CROP_IN, C.CROP_OUT
local OVER_LIFT = 3
local RING_OUT = -1
local NO_AMMO = 0
local SLOT_BUTTON = "Character%sSlot"
local FOREVER_KIND = "items"
local SLOTS = {
    [0] = "Ammo", [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger0", [12] = "Finger1",
    [13] = "Trinket0", [14] = "Trinket1", [15] = "Back", [16] = "MainHand", [17] = "SecondaryHand",
    [18] = "Ranged", [19] = "Tabard",
}

local overs = {}
local installed = false

local function Fade(button, alpha)
    local normal = button:GetNormalTexture()
    if normal then normal:SetAlpha(alpha) end
    if button.IconBorder then button.IconBorder:SetAlpha(alpha) end
    if button.BorderFrame then button.BorderFrame:SetAlpha(alpha) end
end

local function Crop(button, on)
    local icon = button.icon
    if not icon then return end
    if on then icon:SetTexCoord(CROP_IN, CROP_OUT, CROP_IN, CROP_OUT) else icon:SetTexCoord(0, 1, 0, 1) end
end

local function PaintEdge(over, id)
    local color = id and Items.QualityColor(id) or St.BORDER_RGB
    over.edge:SetColor(color.r, color.g, color.b, 1)
end

local function Paint(over)
    local slot = over.slot
    local id = GetInventoryItemID("player", slot)
    if id == NO_AMMO then id = nil end
    over:Show()
    PaintEdge(over, id)
    local link = id and S.Get("characterPanelLevels") and GetInventoryItemLink("player", slot)
    local marks = id and S.Get("characterPanelMarks")
    Parts.PaintItemMarks(over.marks, link and GetDetailedItemLevelInfo(link), marks and ns.IsBisItem(id) or nil,
        marks and Parts.IsForever(FOREVER_KIND, id))
    if S.Get("characterPanelEnchants") and id then
        B.View.PaintEnchantBadge(over.wand, slot)
    else
        over.wand:Hide()
    end
end

local function PaintAll()
    for _, over in pairs(overs) do Paint(over) end
end

local function MarksOn()
    return CP.On() or (S.Get("enabled") == true and S.Get("characterPanelSlotMarks") == true)
end

local function SlotUpdated(button)
    local over = overs[button]
    if not over or not MarksOn() then return end
    if CP.On() then Crop(button, true) end
    Paint(over)
end

local function SlotOver(button, slot)
    local over = CreateFrame("Frame", nil, button)
    over:SetAllPoints()
    over:SetFrameLevel(button:GetFrameLevel() + OVER_LIFT)
    over.slot = slot
    over.look = CreateFrame("Frame", nil, over)
    over.look:SetAllPoints()
    over.edge = ns.Border(over.look, St.BORDER_RGB)
    local ring = CreateFrame("Frame", nil, over.look)
    ns.PixelInset(ring, RING_OUT, over)
    ns.Border(ring, St.BORDER_RGB)
    over.marks = Parts.ItemMarks(over, button:GetHeight())
    return over
end

local function Over(button, slot)
    local over = SlotOver(button, slot)
    over.wand = B.View.EnchantBadge(over)
    return over
end

local function ListChanged()
    if MarksOn() then PaintAll() end
end

local function Install()
    installed = true
    for slot, name in pairs(SLOTS) do
        local button = _G[SLOT_BUTTON:format(name)]
        if button then overs[button] = Over(button, slot) end
    end
    hooksecurefunc("PaperDollItemSlotButton_Update", SlotUpdated)
    B.OnListChange(ListChanged)
end

local function Apply()
    local styled, marked = CP.On(), MarksOn()
    if marked and not installed then Install() end
    if not installed then return end
    for button, over in pairs(overs) do
        Fade(button, styled and 0 or 1)
        Crop(button, styled)
        over.look:SetShown(styled)
        if marked then Paint(over) else over:Hide() end
    end
end
local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") then Apply() end
end

CP.SLOTS = SLOTS
CP.FadeSlot, CP.CropSlot = Fade, Crop
CP.PaintEdge = PaintEdge
CP.SlotOver = SlotOver
CP.MarksOn = MarksOn
CP.ApplySlots = Apply

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
