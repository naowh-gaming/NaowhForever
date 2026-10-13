-- Auctions.lua: how many of each item you have up for sale on the auction house, kept per character (P.Auctions).
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local C = P.C

local ACTIVE_STATUS = 0
local ACTIVE = Enum.AuctionStatus and Enum.AuctionStatus.Active or ACTIVE_STATUS
local OWNED_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local AUCTION_KEYS = { enabled = true, auctionCounts = true }
local EVENTS = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED",
    "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_CANCELED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }
local TEXT_UNKNOWN = "?"

local events
local who
local open, wanted = false, false

local Auctions = {}
P.Auctions = Auctions

local function On()
    return P.On() and S.Get("auctionCounts")
end

local function Who()
    if not who then who = (UnitName("player") or TEXT_UNKNOWN) .. "-" .. (GetRealmName() or TEXT_UNKNOWN) end
    return who
end

local function Mine()
    local account = ns.AccountSettings()
    if type(account.profAuctions) ~= "table" then account.profAuctions = {} end
    account.profAuctions[Who()] = account.profAuctions[Who()] or {}
    return account.profAuctions[Who()]
end

local function Ask()
    if not (open and wanted) then return end
    local ready = C_AuctionHouse.IsThrottledMessageSystemReady
    if ready and not ready() then return end
    wanted = false
    C_AuctionHouse.QueryOwnedAuctions(OWNED_SORT)
end

local function Want()
    if wanted then return end
    wanted = true
    C_Timer.After(C.QUEUE_DELAY, Ask)
end

local function Read()
    local counts = Mine()
    wipe(counts)
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() or 0 do
        local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
        local item = info and info.status == ACTIVE and info.itemKey and info.itemKey.itemID
        if item then counts[item] = (counts[item] or 0) + (info.quantity or 1) end
    end
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

local function OnEvent(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        open = true
        Want()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        open, wanted = false, false
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        Read()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        Ask()
    else
        Want()
    end
end

function Auctions.On()
    return On() and true or false
end

function Auctions.Counts()
    if not On() then return end
    local all = ns.AccountSettings().profAuctions
    return all and all[Who()]
end

function Auctions.Count(item)
    local counts = item and Auctions.Counts()
    return counts and counts[item] or 0
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        open, wanted = false, false
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    open = P.AH ~= nil and P.AH.Open() and true or false
    if open then Want() end
end

local function OnSettingChanged(key)
    if AUCTION_KEYS[key] then Apply() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
Apply()
