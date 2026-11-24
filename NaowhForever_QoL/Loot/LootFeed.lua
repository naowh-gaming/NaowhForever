-- LootFeed.lua: the QoL loot feed, gold per hour, and quick loot with the loot window out of sight.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Parts = ns.Shared.Parts

local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local XP_ICON = "Interface\\Icons\\INV_Misc_Book_11"
local QUEST_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local REP_ICON = "Interface\\Icons\\INV_BannerPVP_02"
local XP_COLOR, REP_COLOR = "|cffb48ef9", "|cff4fc3f7"
local STYLES = {
    dark  = { bg = { 0.05, 0.05, 0.06, 0.8 }, edge = { 0, 0, 0, 1 } },
    light = { bg = { 0.32, 0.23, 0.14, 0.7 }, edge = { 0.12, 0.08, 0.04, 1 } },
}

local DARK_BG = { r = 0.05, g = 0.05, b = 0.06 }
local LIGHT_BG = { r = 0.32, g = 0.23, b = 0.14 }
local LIGHT_EDGE = { r = 0.12, g = 0.08, b = 0.04 }
local GLOW = { r = 1, g = 0.8, b = 0.3 }
local GPH_RGB = { r = 1, g = 0.82, b = 0 }
local ICON_CROP_LOW, ICON_CROP_HIGH = ns.QoLConstants.ICON_CROP, ns.QoLConstants.ICON_CROP_HIGH
local ICON_INSET = 1
local GLOW_ALPHA, GLOW_W = 0.7, 12
local BAGS_SIZE, COIN_SIZE, VALUE_SIZE, NAME_SIZE, GPH_SIZE = 11, 12, 12, 13, 13
local BAGS_INSET = 2
local NAME_GAP, NAME_VALUE_GAP = 10, 8
local MIN_BAGS_SIZE, BAGS_SHRINK = 8, 2
local COPPER_PER_SILVER, COPPER_PER_GOLD = 100, 10000
local SEPARATE_FROM = 1000
local HOUR = ns.QoLConstants.SECONDS_PER_HOUR
local MIN_HOURS = 1 / 60
local APPEAR_TIME, FADE_TIME = 0.15, 0.4
local LOOT_STEP, LOOT_GRACE = 0.05, 1
local SHRUNK = 0.001
local DEFAULT_X, DEFAULT_Y = -469, -141
local TSM_SOURCE = "dbminbuyout"
local EVENTS = { "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_XP_GAIN",
    "CHAT_MSG_COMBAT_FACTION_CHANGE", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED" }

local TEXT_COINS = ns.L("Coins")
local TEXT_PER_HOUR = ns.L("%dg %ds %dc/Hr")
local TEXT_ITEM = "|c%s%s|r |cff20ff20x%d|r"
local TEXT_QUEST = ns.L("Quest Complete")
local TEXT_QUEST_XP = ns.L(" XP|r")
local TEXT_REP = ns.L(" Rep|r")
local TEXT_MOVER = "Loot Feed"

local feed, gph, unlocked
local rows, pool = {}, {}
local coinRow
local sessionStart, sessionValue = nil, 0
local lootHidden, lootScale, lootHooked
local lootGen = 0
local events = CreateFrame("Frame")
local lootWatch = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("lootFeed")
end

local PATTERNS = {}
for _, fmt in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF,
                       LOOT_ITEM_PUSHED_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF }) do
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    PATTERNS[#PATTERNS + 1] = "^" .. p .. "$"
end

local GOLD = GOLD_AMOUNT:gsub("%%d", "(%%d+)")
local SILVER = SILVER_AMOUNT:gsub("%%d", "(%%d+)")
local COPPER = COPPER_AMOUNT:gsub("%%d", "(%%d+)")

local REP_PATTERN = "^" .. FACTION_STANDING_INCREASED:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    :gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
local UNNAMED_XP = COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED and "^" .. COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED
    :gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%d", "(%%d+)")

local COIN_TEXTURES = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
local SAMPLE_PANTS, SAMPLE_COINS = 94, 31250
local SAMPLE_PANTS_BAGS = 1
local PANTS_ICON = "Interface\\Icons\\INV_Pants_04"
local SAMPLE_PANTS_NAME = ns.L("|cff1eff00Journeyman's Pants|r |cff20ff20x1|r")
local VALUE_INSET, COIN_GAP, PAIR_GAP = 8, 2, 5
local GPH_GAP = 10

local Look = {}

local function CountSize()
    return S.Get("lootFeedCountSize") or math.max(MIN_BAGS_SIZE, S.Get("lootFeedFontSize") - BAGS_SHRINK)
end

function Look.NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.border = ns.Border(row)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", ICON_INSET, 0)
    row.icon:SetTexCoord(ICON_CROP_LOW, ICON_CROP_HIGH, ICON_CROP_LOW, ICON_CROP_HIGH)

    row.glow = row:CreateTexture(nil, "ARTWORK")
    row.glow:SetColorTexture(1, 1, 1, 1)
    local glow = ns.ThemeTint("accent", GLOW)
    row.glow:SetGradient("HORIZONTAL", CreateColor(glow.r, glow.g, glow.b, GLOW_ALPHA), CreateColor(glow.r, glow.g, glow.b, 0))
    row.glow:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 0, 0)
    row.glow:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 0, 0)
    row.glow:SetWidth(GLOW_W)

    row.qualityBorder = ns.Border(row)
    row.qualityBorder._frame:SetAllPoints(row.icon)

    row.bags = ns.Font(row, BAGS_SIZE, "OUTLINE")
    row.bags:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMLEFT", BAGS_INSET, BAGS_INSET)

    row.coins = {}
    for i = 1, #COIN_TEXTURES do
        local pair = { icon = row:CreateTexture(nil, "ARTWORK"), amount = ns.Font(row, COIN_SIZE, "OUTLINE") }
        pair.icon:SetTexture(COIN_TEXTURES[i])
        pair.amount:SetPoint("RIGHT", pair.icon, "LEFT", -COIN_GAP, 0)
        row.coins[i] = pair
    end
    row.value = ns.Font(row, VALUE_SIZE, "OUTLINE")
    row.value:SetPoint("RIGHT", -VALUE_INSET, 0)
    row.name = ns.Font(row, NAME_SIZE, "OUTLINE")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -NAME_VALUE_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

function Look.Size(row, w, h)
    row:SetSize(w, h)
    row.icon:SetSize(h - 2 * ICON_INSET, h - 2 * ICON_INSET)
end

function Look.QualityBorder(row)
    local edge = row.qualityBorder
    local color = row.quality and S.Get("lootFeedQualityBorder") and ColorManager.GetColorDataForBagItemQuality(row.quality)
    if color then
        edge:SetColor(color.r, color.g, color.b)
        edge._frame:Show()
    else
        edge._frame:Hide()
    end
end

function Look.StyleRow(row)
    local style = S.Get("lootFeedStyle")
    local bare = style == "none"
    row.bg:SetShown(not bare)
    row.border._frame:SetShown(not bare)
    local st = STYLES[style] or STYLES.dark
    if st == STYLES.dark then
        local c = ns.ThemeTint("bg", DARK_BG)
        row.bg:SetColorTexture(c.r, c.g, c.b, st.bg[4])
        row.border:SetColor(unpack(st.edge))
    else
        local c, e = ns.ThemeTint("panel", LIGHT_BG), ns.ThemeTint("line", LIGHT_EDGE)
        row.bg:SetColorTexture(c.r, c.g, c.b, st.bg[4])
        row.border:SetColor(e.r, e.g, e.b, st.edge[4])
    end
    row.glow:SetShown(S.Get("lootFeedGlow"))
    Look.QualityBorder(row)
    local size, font, outline = S.Get("lootFeedFontSize"), S.Get("lootFeedFont"), S.Get("lootFeedOutline")
    local shadow = bare and "none" or "card"
    Look.Size(row, S.Get("lootFeedWidth"), S.Get("lootFeedHeight"))
    Parts.HudFont(row.name, font, size, outline, shadow)
    Parts.HudFont(row.value, font, size - 1, outline, shadow)
    for _, pair in ipairs(row.coins) do
        Parts.HudFont(pair.amount, font, size - 1, outline, shadow)
        pair.icon:SetSize(size - 1, size - 1)
    end
    Parts.HudFont(row.bags, font, CountSize(), outline, shadow)
end

local function CoinPair(pair, amount, anchor)
    if amount <= 0 then
        pair.icon:Hide()
        pair.amount:Hide()
        return anchor
    end
    pair.icon:ClearAllPoints()
    if anchor then
        pair.icon:SetPoint("RIGHT", anchor, "LEFT", -PAIR_GAP, 0)
    else
        pair.icon:SetPoint("RIGHT", pair.icon:GetParent(), "RIGHT", -VALUE_INSET, 0)
    end
    pair.amount:SetText(amount >= SEPARATE_FROM and BreakUpLargeNumbers(amount) or amount)
    pair.icon:Show()
    pair.amount:Show()
    return pair.amount
end

function Look.Coins(row, copper)
    copper = copper or 0
    local left = CoinPair(row.coins[3], copper % COPPER_PER_SILVER, nil)
    left = CoinPair(row.coins[2], math.floor(copper / COPPER_PER_SILVER) % COPPER_PER_SILVER, left)
    left = CoinPair(row.coins[1], math.floor(copper / COPPER_PER_GOLD), left)
    row.value:ClearAllPoints()
    if left then
        row.value:SetPoint("RIGHT", left, "LEFT", -PAIR_GAP, 0)
    else
        row.value:SetPoint("RIGHT", row, "RIGHT", -VALUE_INSET, 0)
    end
end

function Look.Fill(row, icon, name, value, bags, copper, quality)
    row.icon:SetTexture(icon)
    row.quality = quality
    row.name:SetText(name)
    row.value:SetText(value or "")
    row.bags:SetText(bags or "")
    Look.Coins(row, copper)
end

function Look.Gap(holder)
    local spacing = S.Get("lootFeedSpacing")
    if spacing < 0 then return spacing * ns.OnePixel(holder) end
    return spacing
end

function Look.Stack(list, holder, height)
    local step = (height or S.Get("lootFeedHeight")) + Look.Gap(holder)
    local down = S.Get("lootFeedGrowth") == "down"
    local point = down and "TOP" or "BOTTOM"
    if down then step = -step end
    for i, row in ipairs(list) do
        row:ClearAllPoints()
        row:SetPoint(point, holder, point, 0, (i - 1) * step)
    end
end

function Look.GPHFont(text)
    Parts.HudFont(text, S.Get("lootFeedFont"), S.Get("lootFeedFontSize"), S.Get("lootFeedOutline"), "none")
end

function Look.GPH(text, newest, per)
    text:SetText(TEXT_PER_HOUR:format(math.floor(per / COPPER_PER_GOLD), math.floor(per / COPPER_PER_SILVER) % COPPER_PER_SILVER,
        per % COPPER_PER_SILVER))
    text:ClearAllPoints()
    text:SetPoint("LEFT", newest, "RIGHT", GPH_GAP, 0)
end

ns.LootFeed = {
    Look = Look, On = On, CountSize = CountSize,
    COIN_ICON = COIN_ICON, PANTS_ICON = PANTS_ICON, TEXT_COINS = TEXT_COINS,
    SAMPLE_COINS = SAMPLE_COINS, SAMPLE_PANTS = SAMPLE_PANTS, SAMPLE_PANTS_BAGS = SAMPLE_PANTS_BAGS,
    SAMPLE_PANTS_NAME = SAMPLE_PANTS_NAME,
    GPH_SIZE = GPH_SIZE, GPH_RGB = GPH_RGB, GPH_GAP = GPH_GAP,
    VALUE_INSET = VALUE_INSET, COIN_GAP = COIN_GAP, PAIR_GAP = PAIR_GAP,
}

local function PerHour()
    local hours = (GetTime() - sessionStart) / HOUR
    return math.floor(sessionValue / math.max(hours, MIN_HOURS))
end

local function AddSessionValue(copper)
    if not sessionStart then sessionStart = GetTime() end
    sessionValue = sessionValue + copper
end

function ns.ResetLootFeedSession()
    sessionStart, sessionValue = nil, 0
    if gph then gph:Hide() end
end

local function UnitPrice(link, vendor)
    if S.Get("lootFeedPrice") == "ahscan" then
        local price = ns.AuctionPrice((C_Item.GetItemInfoInstant(link)), link)
        if price then return price end
    end
    if S.Get("lootFeedPrice") == "tsm" and TSM_API and TSM_API.GetCustomPriceValue then
        local ok, value = pcall(TSM_API.GetCustomPriceValue, TSM_SOURCE, TSM_API.ToItemString(link))
        if ok and value then return value end
    end
    return vendor or 0
end

local function Layout()
    Look.Stack(rows, feed)
    local newest = rows[1]
    if gph and newest and S.Get("lootFeedGPH") and sessionStart then
        Look.GPH(gph, newest, PerHour())
        gph:Show()
    elseif gph then
        gph:Hide()
    end
end

local function Release(row)
    row.anim:Stop()
    row:Hide()
    row.link = nil
    if row == coinRow then coinRow = nil end
    for i = #rows, 1, -1 do
        if rows[i] == row then table.remove(rows, i) end
    end
    pool[#pool + 1] = row
    Layout()
end

local function OnRowEnter(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
end

local function OnRowLeave()
    GameTooltip:Hide()
end

local function NewRow()
    local row = Look.NewRow(feed)

    row.anim = row:CreateAnimationGroup()
    row.appear = row.anim:CreateAnimation("Alpha")
    row.appear:SetToAlpha(1)
    row.appear:SetDuration(APPEAR_TIME)
    row.fade = row.anim:CreateAnimation("Alpha")
    row.fade:SetFromAlpha(1)
    row.fade:SetToAlpha(0)
    row.fade:SetDuration(FADE_TIME)
    row.fade:SetOrder(2)
    row.anim:SetScript("OnFinished", function() Release(row) end)

    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)
    return row
end

local function Push(icon, name, value, bags, link, copper, quality)
    local row = table.remove(pool) or NewRow()
    Look.Fill(row, icon, name, value, bags, copper, quality)
    Look.StyleRow(row)
    row.link = link
    row:EnableMouse(link ~= nil)
    row:SetAlpha(1)
    row:Show()
    table.insert(rows, 1, row)
    while #rows > S.Get("lootFeedCount") do Release(rows[#rows]) end
    row.appear:SetFromAlpha(0)
    row.fade:SetStartDelay(S.Get("lootFeedFade"))
    row.anim:Restart()
    Layout()
    return row
end

local function Owned(link)
    local count = C_Item.GetItemCount(link)
    if S.Get("lootFeedBank") then count = count + ns.BankCount(C_Item.GetItemInfoInstant(link)) end
    return count
end

local function OnItem(link, count)
    local item = Item:CreateFromItemLink(link)
    if item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
        local _, _, quality, _, _, _, _, _, _, texture, sellPrice = C_Item.GetItemInfo(link)
        if not quality or quality < S.Get("lootFeedQuality") then return end
        local worth = UnitPrice(link, sellPrice) * count
        AddSessionValue(worth)
        local bags = Owned(link)
        bags = bags > 0 and bags or nil
        local _, _, _, hex = C_Item.GetItemQualityColor(quality)
        local function Named(total)
            local name = TEXT_ITEM:format(hex, item:GetItemName(), total)
            local pick = ns.IsBisItem and ns.IsBisItem(item:GetItemID())
            if pick then name = name .. "  " .. ns.Color("accent", "BiS" .. (pick > 1 and " #" .. pick or "")) end
            return name
        end
        for _, row in ipairs(rows) do
            if row.link == link then
                row.count, row.worth = row.count + count, row.worth + worth
                Look.Fill(row, texture, Named(row.count), nil, bags,
                    S.Get("lootFeedValue") and row.worth or nil, quality)
                row.appear:SetFromAlpha(1)
                row.fade:SetStartDelay(S.Get("lootFeedFade"))
                row.anim:Restart()
                Layout()
                return
            end
        end
        local row = Push(texture, Named(count), nil, bags, link,
            S.Get("lootFeedValue") and worth or nil, quality)
        row.count, row.worth = count, worth
    end)
end

local function RefreshBags()
    for _, row in ipairs(rows) do
        if row.link then
            local bags = Owned(row.link)
            row.bags:SetText(bags > 0 and bags or "")
        end
    end
end

local function OnMoney(copper)
    AddSessionValue(copper)
    if not S.Get("lootFeedMoney") then return end
    if coinRow then
        coinRow.copper = coinRow.copper + copper
        Look.Coins(coinRow, coinRow.copper)
        coinRow.appear:SetFromAlpha(1)
        coinRow.fade:SetStartDelay(S.Get("lootFeedFade"))
        coinRow.anim:Restart()
        Layout()
        return
    end
    coinRow = Push(COIN_ICON, TEXT_COINS, nil, nil, nil, copper)
    coinRow.copper = copper
end

local function MoneyMessage(text)
    local copper = (tonumber(text:match(GOLD)) or 0) * COPPER_PER_GOLD
        + (tonumber(text:match(SILVER)) or 0) * COPPER_PER_SILVER
        + (tonumber(text:match(COPPER)) or 0)
    if copper > 0 then OnMoney(copper) end
end

local function KillXP(text)
    if UNNAMED_XP and S.Get("lootFeedQuest") and text:match(UNNAMED_XP) then return end
    local gained = tonumber(text:match("(%d+)"))
    if gained and gained > 0 then
        Push(XP_ICON, XP_COLOR .. "Experience|r", XP_COLOR .. "+" .. BreakUpLargeNumbers(gained) .. "|r")
    end
end

local function QuestTurnedIn(questID, xp, money)
    if money > 0 then AddSessionValue(money) end
    if xp <= 0 and money <= 0 then return end
    local xpText = xp > 0 and (XP_COLOR .. "+" .. BreakUpLargeNumbers(xp) .. TEXT_QUEST_XP) or nil
    local title = C_QuestLog.GetTitleForQuestID(questID) or TEXT_QUEST
    Push(QUEST_ICON, "|cffffd100" .. title .. "|r", xpText, nil, nil, money)
end

local function Reputation(text)
    local faction, amount = text:match(REP_PATTERN)
    if faction then
        Push(REP_ICON, REP_COLOR .. faction .. "|r", REP_COLOR .. "+" .. amount .. TEXT_REP)
    end
end

local function LootMessage(text)
    for _, pattern in ipairs(PATTERNS) do
        local link, count = text:match(pattern)
        if link then
            OnItem(link, tonumber(count) or 1)
            return
        end
    end
end

local function OnEvent(_, event, text, ...)
    if event == "BAG_UPDATE_DELAYED" then
        RefreshBags()
        return
    end
    if event == "QUEST_TURNED_IN" then
        if S.Get("lootFeedQuest") then QuestTurnedIn(text, ...) end
        return
    end
    if issecretvalue and issecretvalue(text) then return end
    if event == "CHAT_MSG_LOOT" then
        LootMessage(text)
    elseif event == "CHAT_MSG_MONEY" then
        MoneyMessage(text)
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        if S.Get("lootFeedXP") then KillXP(text) end
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if S.Get("lootFeedRep") then Reputation(text) end
    end
end

local function HideWindowOn()
    return S.Get("hideLootWindow") and not ns.GamepadStandDown()
end

local function StackRoom(itemID)
    local stack = itemID and C_Item.GetItemMaxStackSizeByID(itemID)
    if not stack then return 0 end
    local room = 0
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then room = room + stack - info.stackCount end
        end
    end
    return room
end

local function AllTakeable()
    local threshold = IsInGroup() and GetLootThreshold()
    local items = 0
    for i = 1, GetNumLootItems() do
        local _, _, quantity, currencyID, quality, locked, _, _, _, isCoin = GetLootSlotInfo(i)
        if locked then return false end
        if not (isCoin or currencyID) then
            if threshold and quality and quality >= threshold then return false end
            local link = GetLootSlotLink(i)
            if not (link and quantity and quantity <=StackRoom(C_Item.GetItemInfoInstant(link))) then items = items + 1 end
        end
    end
    local free = 0
    for bag = 0, NUM_BAG_SLOTS do free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
    return items <= free
end

local function ShrinkLootWindow()
    if not lootScale then
        lootScale = LootFrame:GetScale()
        LootFrame:SetScale(SHRUNK)
    end
end

local function RestoreLootWindow()
    if lootScale then
        LootFrame:SetScale(lootScale)
        lootScale = nil
    end
end

local function ShowLootWindow()
    lootHidden = false
    RestoreLootWindow()
end

local function OnLootReady()
    if IsShiftKeyDown() then return end
    lootWatch:RegisterEvent("UI_ERROR_MESSAGE")
    lootHidden = HideWindowOn() and AllTakeable()
    lootGen = lootGen + 1
    local gen = lootGen
    local count = GetNumLootItems()
    for i = 1, count do
        C_Timer.After(LOOT_STEP * i, function()
            if gen == lootGen then LootSlot(i) end
        end)
    end
    C_Timer.After(LOOT_STEP * count + LOOT_GRACE, function()
        if gen == lootGen then ShowLootWindow() end
    end)
end

local function OnLootWindowOpen()
    if lootHidden then ShrinkLootWindow() else RestoreLootWindow() end
end

lootWatch:SetScript("OnEvent", function(_, event, _, arg2)
    if event == "LOOT_READY" then
        OnLootReady()
    elseif event == "LOOT_CLOSED" then
        lootGen = lootGen + 1
        lootHidden = false
        lootWatch:UnregisterEvent("UI_ERROR_MESSAGE")
    elseif event == "UI_ERROR_MESSAGE" and arg2 == ERR_INV_FULL then
        ShowLootWindow()
    end
end)

local function ApplyLootWindow()
    if not HideWindowOn() then ShowLootWindow() end
    if S.Get("enabled") and (HideWindowOn() or S.Get("fastLoot")) then
        if not lootHooked and not ns.GamepadStandDown() then
            lootHooked = true
            hooksecurefunc(LootFrame, "Open", OnLootWindowOpen)
            LootFrame.HideAnim:HookScript("OnFinished", RestoreLootWindow)
        end
        lootWatch:RegisterEvent("LOOT_READY")
        lootWatch:RegisterEvent("LOOT_CLOSED")
    else
        lootWatch:UnregisterAllEvents()
        lootGen = lootGen + 1
        ShowLootWindow()
    end
end

local function PlaceFeed()
    local pos = S.Get("lootFeedPos")
    feed:ClearAllPoints()
    if pos then
        feed:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        feed:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
    end
end

local function CreateFeed()
    feed = CreateFrame("Frame", "NaowhForeverLootFeed", UIParent)
    feed:SetMovable(true)
    feed:SetClampedToScreen(true)
    gph = ns.Font(feed, GPH_SIZE, "OUTLINE", GPH_RGB)
    gph:Hide()
    feed.mover = ns.UI.AttachMover(feed, TEXT_MOVER, function(pos) S.Set("lootFeedPos", pos) end, "QoL/Loot & Items", "QoL/Loot & Items:lootFeed")
    PlaceFeed()
end

local function Apply()
    ApplyLootWindow()
    if not On() then
        events:UnregisterAllEvents()
        if feed then
            for i = #rows, 1, -1 do Release(rows[i]) end
            feed.mover:Hide()
        end
        return
    end
    if not feed then CreateFeed() end
    feed:SetSize(S.Get("lootFeedWidth"), S.Get("lootFeedHeight"))
    Look.GPHFont(gph)
    PlaceFeed()
    for _, e in ipairs(EVENTS) do events:RegisterEvent(e) end
    for _, row in ipairs(rows) do Look.StyleRow(row) end
    feed.mover:SetShown(unlocked == true)
    Layout()
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "hideLootWindow" or key == "fastLoot"
        or (key:find("^lootFeed") and key ~= "lootFeedPos") then
        Apply()
    end
end)
ns.OnApply(Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = true
    if On() then
        Apply()
        Push(COIN_ICON, TEXT_COINS, nil, nil, nil, SAMPLE_COINS)
        Push(PANTS_ICON, SAMPLE_PANTS_NAME, nil, SAMPLE_PANTS_BAGS, nil, SAMPLE_PANTS, Enum.ItemQuality.Uncommon)
    end
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if feed then feed.mover:Hide() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
