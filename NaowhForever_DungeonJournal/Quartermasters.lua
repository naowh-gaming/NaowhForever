-- Quartermasters.lua: where each faction's quartermaster and the PvP rank's vendor stand, and what the rank vendors sell at each rank, learned at the vendor.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Rep = J.Reputation
local PERCENT = J.C.PERCENT

local SPOTS_KEY = "journalQuartermasters"
local RANK_ITEMS_KEY = "journalRankItems"
local MAP_FRACTION = 1
local SIDE_JOIN = "-"
local FIRST_RANK = 1

local EMPTY = {}
local unranked = {}
local found = {}
local rankLists = {}
local requirementRanks
local sellers
local rankIndexed = false
local listener

local function Spots(create)
    local account = ns.AccountSettings()
    local spots = account[SPOTS_KEY]
    if type(spots) == "table" then return spots end
    if not create then return nil end
    spots = {}
    account[SPOTS_KEY] = spots
    return spots
end

local function Learned(spot)
    if type(spot) ~= "table" or not (spot.map and spot.x and spot.y) then return nil end
    if spot.x <= MAP_FRACTION and spot.y <= MAP_FRACTION then spot.x, spot.y = spot.x * PERCENT, spot.y * PERCENT end
    return spot
end

local function RankKey()
    return J.RANK.key .. SIDE_JOIN .. (UnitFactionGroup("player") or "")
end

local function IndexRewards()
    sellers = {}
    for _, tab in ipairs(J.TABS) do
        for _, faction in ipairs(J.Factions(tab)) do
            for _, tier in ipairs(faction.tiers) do
                for _, id in ipairs(tier.items) do
                    local seller = sellers[id]
                    sellers[id] = (seller == nil or seller == faction) and faction
                end
            end
        end
    end
end

local function IndexRank(info)
    rankIndexed = true
    for rank = 1, info.maxLevel or 0 do
        for _, reward in ipairs(Rep.RankRewards(rank) or EMPTY) do
            if reward.itemID then sellers[reward.itemID] = J.RANK end
        end
    end
end

local function Sellers()
    if not sellers then IndexRewards() end
    local info = not rankIndexed and Rep.Rank()
    if info then IndexRank(info) end
    return sellers
end

local function SoldHere()
    local index = Sellers()
    for i = 1, GetMerchantNumItems() do
        local faction = index[GetMerchantItemID(i) or 0]
        if faction then return faction end
    end
end

local function RequirementRanks()
    if requirementRanks then return requirementRanks end
    local texts = J.RANK_REQUIREMENTS
    requirementRanks = {}
    for rank, text in ipairs(texts[GetLocale()] or texts.enUS) do requirementRanks[text] = rank end
    return requirementRanks
end

local function RequiredRank(index)
    local data = C_TooltipInfo.GetMerchantItem(index)
    local lines = data and data.lines
    if not lines then return nil end
    local ranks = RequirementRanks()
    for i = 1, #lines do
        local text = lines[i].leftText
        if text and not issecretvalue(text) and ranks[text] then return ranks[text] end
    end
    return nil
end

local function SideItems()
    local side = UnitFactionGroup("player")
    if not side then return nil end
    local account = ns.AccountSettings()
    local all = account[RANK_ITEMS_KEY]
    if type(all) ~= "table" then
        all = {}
        account[RANK_ITEMS_KEY] = all
    end
    all[side] = all[side] or {}
    return all[side]
end

local function LearnRankItems()
    wipe(unranked)
    wipe(found)
    for i = 1, GetMerchantNumItems() do
        local id = GetMerchantItemID(i)
        if id then
            local rank = RequiredRank(i)
            if rank then
                found[id] = rank
            elseif C_Item.IsItemDataCachedByID(id) then
                unranked[#unranked + 1] = id
            end
        end
    end
    if not next(found) then return false end
    local items = SideItems()
    if not items then return false end
    local info = Rep.Rank()
    if info and info.renownLevel == FIRST_RANK then
        for i = 1, #unranked do
            local id = unranked[i]
            found[id] = items[id] or FIRST_RANK
        end
    end
    for id, rank in pairs(found) do items[id] = rank end
    wipe(rankLists)
    return true
end

local function MerchantShown()
    local faction = SoldHere()
    if LearnRankItems() then faction = faction or J.RANK end
    if not faction then return end
    local map = C_Map.GetBestMapForUnit("player")
    local position = map and C_Map.GetPlayerMapPosition(map, "player")
    if not position then return end
    local x, y = position:GetXY()
    local name = UnitName("npc")
    if name and issecretvalue(name) then name = nil end
    Spots(true)[faction.rank and RankKey() or faction.key] = { name = name, map = map, x = x * PERCENT, y = y * PERCENT }
end

function Rep.Quartermaster(faction)
    local spots = Spots()
    return spots and Learned(spots[faction.key]) or faction.quartermaster
end

function Rep.RankVendor()
    local spots = Spots()
    return spots and Learned(spots[RankKey()]) or nil
end

function Rep.RankItems(rank)
    local list = rankLists[rank]
    if list then return list end
    list = {}
    local all = ns.AccountSettings()[RANK_ITEMS_KEY]
    local items = type(all) == "table" and all[UnitFactionGroup("player") or ""]
    if type(items) == "table" then
        for id, itemRank in pairs(items) do
            if itemRank == rank then list[#list + 1] = id end
        end
        table.sort(list)
    end
    rankLists[rank] = list
    return list
end

local function Sync()
    local on = S.Get("enabled")
    if not (on or listener) then return end
    if not listener then
        listener = CreateFrame("Frame")
        listener:SetScript("OnEvent", MerchantShown)
    end
    if on then listener:RegisterEvent("MERCHANT_SHOW") else listener:UnregisterAllEvents() end
end

local function OnSettingChanged(key)
    if key == "enabled" then Sync() end
end

S.OnChange(OnSettingChanged)
ns.OnApply(Sync)
