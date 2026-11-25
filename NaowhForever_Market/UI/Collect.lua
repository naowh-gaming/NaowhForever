-- Collect.lua: the Collect button beside the inbox, which takes the gold and items from all your mail or only from sold, bought or expired auctions.
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Ledger = Market.Ledger

local BUTTON_W, BUTTON_H = 64, 22
local BUTTON_X, BUTTON_Y = 4, -30
local TAKE_DELAY = 0.15
local KINDS = { "all", "sold", "bought", "expired" }
local MATCHES = { sold = { sold = true }, bought = { bought = true }, expired = { expired = true, cancelled = true } }
local TEXT_COLLECT = ns.L("Collect")
local TEXT_STOP = ns.L("Stop")
local TEXT_TIP = ns.L("Collect Mail")
local TEXT_HELP = ns.L("Takes all your mail, or only your sold, bought or expired auctions.")
local TEXT_FULL = ns.L("Your bags are full, so some items stayed in the mail.")
local TEXT_ROW = "%s (%d)"
local LABELS = { all = ns.L("All Mail"), sold = ns.L("Sold Auctions"), bought = ns.L("Bought Auctions"),
    expired = ns.L("Expired and Cancelled") }

local button, ticker, events
local collecting, wait, full
local failed = {}

local function On()
    return Market.On() and S.Get("mailCollect")
end

local function Wanted(index, kind)
    local _, _, _, _, money, cod, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(index)
    if isGM or cod and cod > 0 then return end
    if not (money and money > 0 or itemCount and itemCount > 0) then return end
    if kind ~= "all" and not MATCHES[kind][Ledger.MailKind(index) or ""] then return end
    return money
end

local function Count(kind)
    local n = 0
    for index = 1, GetInboxNumItems() do
        if Wanted(index, kind) then n = n + 1 end
    end
    return n
end

local function TakeFrom(index, money)
    if money and money > 0 then
        TakeInboxMoney(index)
        return true
    end
    for attachment = 1, ATTACHMENTS_MAX_RECEIVE do
        local _, itemID = GetInboxItem(index, attachment)
        if itemID and not failed[itemID] then
            if C_Container.CalculateTotalNumberOfFreeBagSlots() == 0 then
                full = true
                return
            end
            TakeInboxItem(index, attachment)
            return true
        end
    end
end

local function TakeNext()
    for index = 1, GetInboxNumItems() do
        local money = Wanted(index, collecting)
        if money and TakeFrom(index, money) then return true end
    end
end

local function Stop()
    if not collecting then return end
    collecting = nil
    ticker:Hide()
    events:UnregisterEvent("MAIL_FAILED")
    button.label:SetText(TEXT_COLLECT)
    if full then ns.Print(TEXT_FULL) end
end

local function OnUpdate(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = TAKE_DELAY
    if C_Mail.IsCommandPending() then return end
    if not TakeNext() then Stop() end
end

local function Start(kind)
    collecting, wait, full = kind, 0, nil
    wipe(failed)
    events:RegisterEvent("MAIL_FAILED")
    button.label:SetText(TEXT_STOP)
    ticker:Show()
end

local function OpenMenu()
    ns.ContextMenu(button, function(_, root)
        root:CreateTitle(TEXT_TIP)
        for _, kind in ipairs(KINDS) do
            root:CreateButton(TEXT_ROW:format(LABELS[kind], Count(kind)), function() Start(kind) end)
        end
    end)
end

local function OnClick()
    if collecting then return Stop() end
    OpenMenu()
end

local function OnEvent(_, event, itemID)
    if event == "MAIL_FAILED" then
        if not itemID then return Stop() end
        failed[itemID] = true
    elseif event == "MAIL_SHOW" then
        if button or not InboxFrame then return end
        button = ns.Button(InboxFrame, TEXT_COLLECT, BUTTON_W, BUTTON_H, OnClick)
        button:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", BUTTON_X, BUTTON_Y)
        button:SetScript("OnHide", Stop)
        ns.Tooltip(button, TEXT_TIP, TEXT_HELP)
    elseif event == "MAIL_CLOSED" then
        Stop()
    end
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
            ticker = CreateFrame("Frame")
            ticker:Hide()
            ticker:SetScript("OnUpdate", OnUpdate)
        end
        events:RegisterEvent("MAIL_SHOW")
        events:RegisterEvent("MAIL_CLOSED")
        if MailFrame and MailFrame:IsShown() then OnEvent(nil, "MAIL_SHOW") end
    elseif events then
        Stop()
        events:UnregisterAllEvents()
    end
    if button then button:SetShown(On()) end
end

S.OnChange(function(key)
    if key == "enabled" or key == "mailCollect" then Apply() end
end)
ns.OnApply(Apply)
