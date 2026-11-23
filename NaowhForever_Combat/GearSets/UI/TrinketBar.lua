-- TrinketBar.lua: the Trinket Bar, your trinket slots (and your weapons or all your gear, if picked), and its picker of what fits a slot from your bags.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local G = ns.GearSets
local C, St, Look = G.C, G.Style, G.Look
local TRINKET_SLOTS, BAR_SLOTS = C.TRINKET_SLOTS, C.BAR_SLOTS
local Trinkets = G.Trinkets

local PICKER_COLS, PICKER_CELL, PICKER_STEP, PICKER_PAD = 6, 36, 40, 6
local PICKER_ROOM, PICKER_EDGE, PICKER_GAP = 34, 8, 5
local PICKER_SIDES = {
    above = { "BOTTOMLEFT", "TOPLEFT", 0, PICKER_GAP },
    below = { "TOPLEFT", "BOTTOMLEFT", 0, -PICKER_GAP },
    left = { "TOPRIGHT", "TOPLEFT", -PICKER_GAP, 0 },
    right = { "TOPLEFT", "TOPRIGHT", PICKER_GAP, 0 },
}
local CLOSE_W, CLOSE_H, CLOSE_Y = 80, 22, 5
local RANK_SIZE, RANK_INSET = 12, 2
local HOME_Y = -160
local GCD = 1.5
local BLACK, EMPTY_ICON = St.BLACK, St.EMPTY_ICON
local TRINKET_INDEX = { [TRINKET_SLOTS[1]] = 1, [TRINKET_SLOTS[2]] = 2 }
local CARD = C.PAGE .. ":trinketBar"
local WATCHED = { "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_EQUIPMENT_CHANGED" }

local TEXT_NONE = ns.L("No spare trinkets in your bags.")
local TEXT_NONE_SLOT = ns.L("Nothing in your bags fits that slot.")
local TEXT_CLOSE = ns.L("Close")
local TEXT_EMPTY = ns.L("%s - Empty")
local TEXT_QUEUE_HINT = ns.L("Shift-click to add it to this slot's queue, or take it out.")
local TEXT_PICKED = ns.L("%s goes on when combat ends.")
local TEXT_UNPICKED = ns.L("Nothing will be swapped in when combat ends.")
local TEXT_MOVER = "Trinkets"

local trinkets, picker, moving
local items, seen, bySlot, shown = {}, {}, {}, {}
local watcher = CreateFrame("Frame")

local function ClosePicker()
    if picker then picker:Hide() end
end

local function Queueable(slot)
    return S.Get("trinketQueue") == true and TRINKET_INDEX[slot] ~= nil
end

local function Fitting(inventorySlot)
    wipe(items)
    wipe(seen)
    local worn = Queueable(inventorySlot) and GetInventoryItemID("player", inventorySlot)
    if worn then
        seen[worn] = true
        items[1] = worn
    end
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not seen[id] and Items.Fits(id, inventorySlot) then
                seen[id] = true
                items[#items + 1] = id
            end
        end
    end
    return items
end

local function Sweep(cooldown, start, duration, enable)
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(enable)) then return end
    if enable and enable ~= 0 and duration > GCD then
        cooldown:SetCooldown(start, duration)
        cooldown:Show()
    else
        cooldown:Hide()
    end
end

local function ShowPickCooldowns()
    local on = S.Get("trinketCooldown")
    for _, button in ipairs(picker.buttons) do
        if on and button:IsShown() then
            Sweep(button.cooldown, C_Container.GetItemCooldown(button.itemID))
        else
            button.cooldown:Hide()
        end
    end
end

local function ShowRank(button)
    local rank = Queueable(button.inventorySlot) and Trinkets.Rank(button.inventorySlot, button.itemID)
    button.rank:SetText(rank or "")
end

local function ShowPicks()
    for slot, button in pairs(shown) do
        local id = Trinkets.Picked(slot)
        button.next.icon:SetTexture(id and C_Item.GetItemIconByID(id))
        button.next:SetShown(id ~= nil)
    end
end

local function OnPickClick(self)
    local slot, id = self.inventorySlot, self.itemID
    if Queueable(slot) and IsShiftKeyDown() then
        Trinkets.Toggle(slot, id)
        for _, button in ipairs(picker.buttons) do ShowRank(button) end
        return
    end
    ClosePicker()
    if InCombatLockdown() then
        if Trinkets.Picked(slot) == id or GetInventoryItemID("player", slot) == id then
            Trinkets.Pick(slot, nil)
            ns.Print(TEXT_UNPICKED)
        else
            Trinkets.Pick(slot, id)
            ns.Print(TEXT_PICKED:format(select(2, C_Item.GetItemInfo(id))))
        end
        return ShowPicks()
    end
    if Trinkets.Picked(slot) then
        Trinkets.Pick(slot, nil)
        ShowPicks()
    end
    if Trinkets.InBags(id) then C_Item.EquipItemByName(id, slot) end
end

local function OnPickEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    if Queueable(self.inventorySlot) then
        GameTooltip:AddLine(TEXT_QUEUE_HINT, St.HINT_RGB.r, St.HINT_RGB.g, St.HINT_RGB.b, true)
    end
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function NewPicker()
    picker = CreateFrame("Frame", nil, UIParent)
    picker:SetFrameStrata("DIALOG")
    picker:SetClampedToScreen(true)
    ns.Solid(picker, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(picker)
    picker.buttons = {}
    picker.close = ns.Button(picker, TEXT_CLOSE, CLOSE_W, CLOSE_H, ClosePicker)
    picker.close:SetPoint("BOTTOM", 0, CLOSE_Y)
end

local function PickButton(i)
    local button = picker.buttons[i]
    if button then return button end
    button = CreateFrame("Button", nil, picker)
    button:SetSize(PICKER_CELL, PICKER_CELL)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    ns.Border(button, BLACK)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetDrawEdge(false)
    local over = CreateFrame("Frame", nil, button)
    over:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    over:SetAllPoints()
    button.rank = ns.Font(over, RANK_SIZE, "OUTLINE", T.fg)
    button.rank:SetPoint("TOPLEFT", RANK_INSET, -RANK_INSET)
    button:SetScript("OnClick", OnPickClick)
    Parts.Press(button)
    button:SetScript("OnEnter", OnPickEnter)
    button:SetScript("OnLeave", HideTooltip)
    picker.buttons[i] = button
    return button
end

local function Choose(anchor, inventorySlot)
    ClosePicker()
    if not picker then NewPicker() end
    local spare = Fitting(inventorySlot)
    if #spare == 0 then return ns.Print(TRINKET_INDEX[inventorySlot] and TEXT_NONE or TEXT_NONE_SLOT) end
    local countdown = S.Get("trinketCountdown")
    for i, id in ipairs(spare) do
        local button = PickButton(i)
        button.itemID, button.inventorySlot = id, inventorySlot
        button.icon:SetTexture(C_Item.GetItemIconByID(id))
        ShowRank(button)
        button.cooldown:SetHideCountdownNumbers(not countdown)
        button.cooldown:Hide()
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", PICKER_PAD + ((i - 1) % PICKER_COLS) * PICKER_STEP,
            -PICKER_PAD - math.floor((i - 1) / PICKER_COLS) * PICKER_STEP)
        button:Show()
    end
    for i = #spare + 1, #picker.buttons do picker.buttons[i]:Hide() end
    picker:SetSize(math.min(#spare, PICKER_COLS) * PICKER_STEP + PICKER_EDGE,
        math.ceil(#spare / PICKER_COLS) * PICKER_STEP + PICKER_ROOM)
    local side = PICKER_SIDES[S.Get("trinketPickerSide")] or PICKER_SIDES.above
    picker:ClearAllPoints()
    picker:SetPoint(side[1], anchor, side[2], side[3], side[4])
    picker:Show()
    ShowPickCooldowns()
end

local function OnSlotEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GetInventoryItemID("player", self.inventorySlot) then
        GameTooltip:SetInventoryItem("player", self.inventorySlot)
    else
        GameTooltip:SetText(TEXT_EMPTY:format(Items.SlotName(self.inventorySlot)))
    end
    GameTooltip:Show()
end

local function OnSlotPostClick(self, mouse, down)
    if mouse == "RightButton" and not down then Choose(self, self.inventorySlot) end
end

local function NewSlot(slot)
    local i = TRINKET_INDEX[slot]
    local button
    if i then
        button = CreateFrame("Button", "NaowhForeverTrinket" .. i, trinkets, "SecureActionButtonTemplate")
    else
        button = CreateFrame("Button", "NaowhForeverGearSlot" .. slot, trinkets, "SecureActionButtonTemplate")
    end
    button:RegisterForClicks("AnyUp", "AnyDown")
    Parts.Press(button)
    button:SetAttribute("item1", tostring(slot))
    button.icon = Look.Dress(button)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetDrawEdge(false)
    button.next = CreateFrame("Frame", nil, button)
    button.next:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    button.next:SetPoint("TOPLEFT", button, "CENTER")
    button.next:SetPoint("BOTTOMRIGHT")
    button.next.icon = button.next:CreateTexture(nil, "ARTWORK")
    button.next.icon:SetAllPoints()
    ns.Border(button.next, BLACK)
    button.next:Hide()
    button.inventorySlot = slot
    button:SetScript("PostClick", OnSlotPostClick)
    button:SetScript("OnEnter", OnSlotEnter)
    button:SetScript("OnLeave", HideTooltip)
    bySlot[slot] = button
    return button
end

local function SavePosition(pos)
    S.Set("trinketPos", pos)
end

local function BuildTrinkets()
    trinkets = CreateFrame("Frame", "NaowhForeverTrinkets", UIParent)
    trinkets:SetMovable(true)
    trinkets:SetClampedToScreen(true)
    trinkets.buttons = {}
    trinkets.mover = ns.UI.AttachMover(trinkets, TEXT_MOVER, SavePosition, C.PAGE, CARD)
end

local function PickSlots()
    wipe(trinkets.buttons)
    wipe(shown)
    for _, slot in ipairs(BAR_SLOTS[S.Get("trinketSlots")] or TRINKET_SLOTS) do
        local button = bySlot[slot] or NewSlot(slot)
        trinkets.buttons[#trinkets.buttons + 1] = button
        shown[slot] = button
        button:Show()
    end
    for slot, button in pairs(bySlot) do
        if not shown[slot] then button:Hide() end
    end
end

local function Place()
    trinkets:ClearAllPoints()
    local pos = S.Get("trinketPos")
    if pos then
        trinkets:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        trinkets:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
end

local function ShowCooldowns()
    local on = S.Get("trinketCooldown")
    for _, button in ipairs(trinkets.buttons) do
        if on then
            Sweep(button.cooldown, GetInventoryItemCooldown("player", button.inventorySlot))
        else
            button.cooldown:Hide()
        end
    end
end

local function ApplyTrinkets()
    if InCombatLockdown() then
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    ClosePicker()
    local on = G.On() and S.Get("trinketBar")
    for _, event in ipairs(WATCHED) do
        if on then watcher:RegisterEvent(event) else watcher:UnregisterEvent(event) end
    end
    if on and S.Get("trinketCooldown") then
        watcher:RegisterEvent("BAG_UPDATE_COOLDOWN")
    else
        watcher:UnregisterEvent("BAG_UPDATE_COOLDOWN")
    end
    if not on then
        if trinkets then trinkets:Hide() end
        return
    end
    if not trinkets then BuildTrinkets() end
    PickSlots()
    Place()
    Look.Trinkets(trinkets, trinkets.buttons, S.Get("trinketSize"), S.Get("trinketSpacing"), S.Get("trinketGrow"),
        S.Get("trinketSquare"))
    for _, button in ipairs(trinkets.buttons) do
        button:SetAttribute("type1", GetInventoryItemID("player", button.inventorySlot) and "item" or nil)
        button.cooldown:SetHideCountdownNumbers(not S.Get("trinketCountdown"))
    end
    ShowCooldowns()
    ShowPicks()
    trinkets.mover:SetShown(moving == true)
    trinkets:Show()
end

local function OnEvent(_, event, slot)
    if event == "PLAYER_REGEN_DISABLED" then
        ClosePicker()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        ShowCooldowns()
        if picker and picker:IsShown() then ShowPickCooldowns() end
    elseif event ~= "PLAYER_EQUIPMENT_CHANGED" then
        ApplyTrinkets()
    elseif shown[slot] then
        if InCombatLockdown() then shown[slot].icon:SetTexture(GetInventoryItemTexture("player", slot) or EMPTY_ICON) end
        ApplyTrinkets()
    end
end

local function OnSet(key)
    if key == "gearSets" or key:find("^trinket") and key ~= "trinketPos" then ApplyTrinkets() end
end

local function OnUnlock()
    moving = true
    ApplyTrinkets()
end

local function OnLock()
    moving = false
    ApplyTrinkets()
end

watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(Trinkets, "Clear", ShowPicks)
ns.OnApply(ApplyTrinkets)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)
