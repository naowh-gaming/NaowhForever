-- Marks.lua: Upgrade Marks, the upgrade arrow and percent on quest rewards, merchants, loot, rolls and the auction house.
local ns = _G.NaowhForever

local GetTime = GetTime
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local SW = ns.StatWeights
local S = SW.Settings
local Shared = ns.Shared
local Parts, Items, St = Shared.Parts, Shared.Items, Shared.Style

local AUCTION_ADDON = "Blizzard_AuctionHouseUI"
local ITEM, CHOICE = "item", "choice"
local SELL_PRICE = 11
local COIN_ATLAS = "coin-gold-20x20"
local GAIN_TEXT = "+%d%%"
local ROUND = 0.5
local MIN_CHOICES = 2
local ROW_TEXT_SIZE, ROW_TEXT_GAP, ROW_UP = 10, 2, 8

local sets = {}
local weights, power, weighedAt
local installed, auctionHooked = false, false
local events

local function On()
    return S.Get("upgradeMarks") == true
end

local function Weights()
    local now = GetTime()
    if now ~= weighedAt then
        weighedAt = now
        local key = SW.ActiveSpec()
        weights = key and SW.For(key)
        power = weights and SW.Power(weights)
    end
    return weights, power
end

local function Gain(item)
    local id = GetItemInfoInstant(item)
    if not (id and Items.SlotsFor(id)) then return nil end
    return SW.BestGain(id, type(item) == "string" and item or nil, Weights())
end

local function FitRow(set, anchor)
    set.row = true
    set.level:ClearAllPoints()
    set.level:SetPoint("RIGHT", anchor, "LEFT", -ROW_TEXT_GAP, 0)
    set.level:SetFont(ns.UIFontPath(), ROW_TEXT_SIZE, "OUTLINE")
    set.up:SetSize(ROW_UP, ROW_UP)
end

local function NewSet(owner, anchor, row)
    local set = Parts.ItemMarks(owner, anchor:GetHeight())
    set:ClearAllPoints()
    set:SetAllPoints(anchor)
    set.level:SetTextColor(St.UPGRADE_RGB.r, St.UPGRADE_RGB.g, St.UPGRADE_RGB.b)
    set.coin = Parts.ItemBadge(set, "TOPLEFT", COIN_ATLAS)
    if row then FitRow(set, anchor) end
    sets[owner] = set
    return set
end

local function Paint(owner, anchor, item, coin, row)
    local gain = item and On() and Gain(item) or nil
    local set = sets[owner]
    if not (gain or coin) then
        if set then set:Hide() end
        return
    end
    set = set or NewSet(owner, anchor, row)
    Parts.PaintItemMarks(set, nil, nil, false, gain ~= nil)
    set.level:SetText(gain and GAIN_TEXT:format(math.floor(gain + ROUND)) or "")
    set.shade:SetShown(gain ~= nil and not set.row)
    set.coin:SetShown(coin == true)
    set:Show()
end

local function QuestLink(button)
    if QuestInfoFrame.questLog then return GetQuestLogItemLink(button.type, button:GetID()) end
    return GetQuestItemLink(button.type, button:GetID())
end

local function SellPrice(link)
    return link and select(SELL_PRICE, GetItemInfo(link)) or 0
end

local function BestSale(frame)
    local best, most, choices = nil, 0, 0
    for _, button in ipairs(frame.RewardButtons) do
        if button:IsShown() and button.objectType == ITEM and button.type == CHOICE then
            choices = choices + 1
            local price = SellPrice(QuestLink(button))
            if price > most then best, most = button, price end
        end
    end
    return choices >= MIN_CHOICES and best or nil
end

local function PaintQuest(frame)
    if not (frame and frame.RewardButtons) then return end
    local sale = On() and BestSale(frame)
    for _, button in ipairs(frame.RewardButtons) do
        local link = button:IsShown() and button.objectType == ITEM and QuestLink(button)
        Paint(button, button.Icon, link or nil, button == sale)
    end
end

local function OnShowRewards()
    if On() then PaintQuest(QuestInfoFrame.rewardsFrame) end
end

local function OnItemQuality(button)
    if not On() then return end
    local parent = button:GetParent()
    if not parent then return end
    if parent == QuestInfoFrame.rewardsFrame then return PaintQuest(parent) end
    if not parent.GetSlotIndex then return end
    local slot = parent:GetSlotIndex()
    local item = slot and GetLootSlotType(slot) == Enum.LootSlotType.Item and GetLootSlotLink(slot)
    Paint(button, button, item or nil)
end

local function OnMerchantItem(container, link)
    local button = container.ItemButton
    if button and (On() or sets[button]) then Paint(button, button, link) end
end

local function OnRoll(frame)
    local icon = frame.IconFrame
    if not (icon and (On() or sets[icon])) then return end
    Paint(icon, icon, frame.rollID and GetLootRollItemLink(frame.rollID) or nil)
end

local function OnAuctionCell(cell, itemKey)
    if not (cell.Icon and (On() or sets[cell])) then return end
    Paint(cell, cell.Icon, itemKey and itemKey.itemID or nil, nil, true)
end

local function HookAuction()
    if auctionHooked or not AuctionHouseTableCellItemDisplayMixin then return end
    auctionHooked = true
    hooksecurefunc(AuctionHouseTableCellItemDisplayMixin, "UpdateDisplay", OnAuctionCell)
    if events then events:UnregisterAllEvents() end
end

local function OnEvent(_, _, name)
    if name == AUCTION_ADDON then HookAuction() end
end

local function Install()
    installed = true
    hooksecurefunc("QuestInfo_ShowRewards", OnShowRewards)
    hooksecurefunc("SetItemButtonQuality", OnItemQuality)
    hooksecurefunc("MerchantFrameItem_UpdateQuality", OnMerchantItem)
    if not ns.GamepadStandDown() then hooksecurefunc("GroupLootFrame_SetupItemDisplay", OnRoll) end
    if C_AddOns.IsAddOnLoaded(AUCTION_ADDON) then return HookAuction() end
    events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", OnEvent)
end

local function Apply()
    if On() then
        if not installed then Install() end
        return
    end
    for _, set in pairs(sets) do set:Hide() end
end

local function OnSetting(key)
    if key == "upgradeMarks" then Apply() end
end

S.OnChange(OnSetting)
ns.OnApply(Apply)
