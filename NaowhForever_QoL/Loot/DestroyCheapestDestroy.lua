-- DestroyCheapestDestroy.lua: the click that picks a bag item up and deletes it.
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetItemCount = C_Item.GetItemCount

local D = ns.DestroyCheapest
local Coins = ns.Shared.Parts.Coins
local TEXT = D.TEXT

local DIALOGS = { "DELETE_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }

local function DialogOpen()
    for i = 1, #DIALOGS do
        if StaticPopup_FindVisible(DIALOGS[i]) then return true end
    end
    return false
end

local function SlotState(p)
    local info = GetContainerItemInfo(p.bag, p.slot)
    if not info or info.itemID ~= p.itemID then return "gone" end
    if info.isLocked then return "locked" end
    return "here"
end

local function StillThere(p)
    local info = GetContainerItemInfo(p.bag, p.slot)
    return info and info.itemID == p.itemID and (info.stackCount or 1) == p.count and not info.isLocked
end

function D.ReturnCursor(p)
    if not D.CursorHolds(p.itemID) then return true end
    if InCombatLockdown() then return false end
    ClearCursor()
    if not D.CursorHolds(p.itemID) then return true end
    if InCombatLockdown() then return false end
    C_Container.PickupContainerItem(p.bag, p.slot)
    return not D.CursorHolds(p.itemID)
end

local function TryLoot(slot)
    if not slot or not D.LootShown() then
        ns.Print(TEXT.ROOM)
        return
    end
    if InCombatLockdown() then
        ns.Print(TEXT.LOOT_COMBAT)
        return
    end
    if not D.SlotOpen(slot) then
        ns.Print(TEXT.LOOT_AGAIN)
        return
    end
    LootSlot(slot)
end

local function Finish(p)
    local slot = p.lootSlot
    D.pending = nil
    D.armed = false
    local money = Coins(p.value)
    if p.vendorEstimated then money = "Vendor est. " .. money end
    if (p.count or 1) > 1 then money = TEXT.FOR_STACK:format(money, p.count) end
    ns.Print(TEXT.DESTROYED:format(p.link or p.name or p.itemID, money))
    if D.Opened() then D.popup:Hide() end
    TryLoot(slot)
end

local function GiveUp()
    D.pending = nil
    D.armed = false
    if D.Opened() then D.Refresh() else D.Listen(false) end
end

function D.Resolve()
    local p = D.pending
    if not p or not p.mode then return end
    if DialogOpen() then return end
    if D.CursorHolds(p.itemID) then
        if p.mode == "cursor" then return end
        if D.ReturnCursor(p) then
            ns.Print(TEXT.RETURNED)
            return GiveUp()
        end
        p.mode = "cursor"
        ns.Print(TEXT.STUCK)
        if D.Opened() then D.Paint() end
        return
    end
    local state = SlotState(p)
    if state == "locked" then return end
    if state == "gone" then
        local left = GetItemCount(p.itemID)
        if type(left) ~= "number" then return end
        if left <= p.owned - p.count then return Finish(p) end
        if not p.sawGone then
            p.sawGone = true
            return
        end
        ns.Print(TEXT.MOVED)
    elseif state == "here" then
        ns.Print(TEXT.BLOCKED)
    end
    GiveUp()
end

function D.ArmedStill(pick, loot)
    if not (D.armed and type(pick) == "table") then return false end
    if pick.bag ~= D.armedBag or pick.slot ~= D.armedSlot or pick.itemID ~= D.armedID then return false end
    if pick.count ~= D.armedCount or pick.link ~= D.armedLink then return false end
    local lootSlot, lootLink
    if type(loot) == "table" then lootSlot, lootLink = loot.slot, loot.link end
    return lootSlot == D.armedLootSlot and lootLink == D.armedLootLink
end

function D.Disarm()
    D.armed = false
    D.armedBag, D.armedSlot, D.armedID, D.armedCount, D.armedLink = nil, nil, nil, nil, nil
    D.armedLootSlot, D.armedLootLink, D.armedForced = nil, nil, nil
end

local function SameArmed(pick, loot, forced)
    return D.ArmedStill(pick, loot) and (forced == true) == (D.armedForced == true)
end

local function Arm(pick, loot, forced)
    D.armed = true
    D.armedBag, D.armedSlot, D.armedID = pick.bag, pick.slot, pick.itemID
    D.armedCount, D.armedLink = pick.count, pick.link
    if type(loot) == "table" then
        D.armedLootSlot, D.armedLootLink = loot.slot, loot.link
    else
        D.armedLootSlot, D.armedLootLink = nil, nil
    end
    D.armedForced = forced == true
    D.Paint()
end

function D.OnDestroy()
    local allow = D.forced
    D.forced = false
    if D.pending or not D.On() then return end
    local pick, loot = D.picks[D.index], D.loots[D.lootIndex]
    if not pick then return end
    if not D.Matches(pick) then
        D.armed = false
        ns.Print(TEXT.MOVED)
        return D.Refresh()
    end
    if not StillThere(pick) then
        ns.Print(TEXT.MOVED)
        return D.Refresh()
    end
    if not allow and not D.WorthIt(pick, loot) then return D.Paint() end
    if GetCursorInfo() then return ns.Print(TEXT.HOLDING) end
    if InCombatLockdown() then return ns.Print(TEXT.COMBAT) end
    if not SameArmed(pick, loot, allow) then return Arm(pick, loot, allow) end
    D.Disarm()
    D.pending = {
        bag = pick.bag, slot = pick.slot, itemID = pick.itemID, link = pick.link, name = pick.name,
        count = pick.count, value = pick.value, vendorEstimated = pick.vendorEstimated,
        owned = GetItemCount(pick.itemID) or 0,
        lootSlot = loot and loot.slot,
    }
    D.Listen(true)
    if InCombatLockdown() then
        D.pending = nil
        return ns.Print(TEXT.COMBAT)
    end
    C_Container.PickupContainerItem(pick.bag, pick.slot)
    local kind, id = GetCursorInfo()
    if kind ~= "item" or id ~= pick.itemID then
        D.pending = nil
        ns.Print(TEXT.MOVED)
        return D.Refresh()
    end
    if InCombatLockdown() then
        if D.ReturnCursor(D.pending) then
            D.pending = nil
            ns.Print(TEXT.BLOCKED)
            return D.Refresh()
        end
        D.pending.mode = "cursor"
        ns.Print(TEXT.STUCK)
        return D.Paint()
    end
    DeleteCursorItem()
    if DialogOpen() then
        D.pending.mode = "dialog"
        return D.Paint()
    end
    if D.CursorHolds(pick.itemID) then
        if D.ReturnCursor(D.pending) then
            D.pending = nil
            ns.Print(TEXT.BLOCKED)
            return D.Refresh()
        end
        D.pending.mode = "cursor"
        ns.Print(TEXT.STUCK)
        return D.Paint()
    end
    D.pending.mode = "wait"
    D.Resolve()
    if D.pending and D.Opened() then D.Paint() end
end

function D.OnAnyway()
    D.forced = true
    D.OnDestroy()
end

function D.ReleaseCursor()
    local p = D.pending
    if not p or not D.CursorHolds(p.itemID) then return end
    D.ReturnCursor(p)
end
