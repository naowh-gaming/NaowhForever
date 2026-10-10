-- Disenchant.lua: the bag items Disenchant can take, the ones you keep, and which one is next (P.Disenchant).
local ns = _G.NaowhForever

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemQualityByID = C_Item.GetItemQualityByID

local P = ns.Professions

local SPELL = 13262
local ENCHANTING = 333
local WEAPON, ARMOR = 2, 4
local UNCOMMON, EPIC = 2, 4
local NEVER = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local KEEP_KEY = "profDisenchantKeep"

local records, failed = {}, {}
local count = 0

local D = { SPELL = SPELL, ENCHANTING = ENCHANTING }
P.Disenchant = D

local function KeepList()
    local account = ns.AccountSettings()
    account[KEEP_KEY] = account[KEEP_KEY] or {}
    return account[KEEP_KEY]
end

local function Takes(itemID, quality)
    quality = quality or GetItemQualityByID(itemID)
    if not quality or quality < UNCOMMON or quality > EPIC then return false end
    local _, _, _, equip, _, class = GetItemInfoInstant(itemID)
    if class ~= WEAPON and class ~= ARMOR then return false end
    return not NEVER[equip or ""]
end

local function Note(bag, slot, info)
    count = count + 1
    local r = records[count] or {}
    records[count] = r
    r.bag, r.slot, r.itemID = bag, slot, info.itemID
    r.link, r.icon = info.hyperlink, info.iconFileID
    r.quality = info.quality or GetItemQualityByID(info.itemID)
    r.locked = info.isLocked == true
end

function D.Known()
    return C_SpellBook.IsSpellKnown(SPELL) == true
end

function D.Collect()
    count = 0
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local info = GetContainerItemInfo(bag, slot)
            if info and info.itemID and Takes(info.itemID, info.quality) then Note(bag, slot, info) end
        end
    end
    return records, count
end

function D.Kept(itemID)
    return KeepList()[itemID] == true
end

function D.ToggleKeep(itemID)
    local list = KeepList()
    list[itemID] = not list[itemID] or nil
end

function D.Failed(itemID)
    return failed[itemID] == true
end

function D.MarkFailed(itemID)
    failed[itemID] = true
end

function D.Ready(r)
    return not (D.Kept(r.itemID) or failed[r.itemID])
end

function D.Next()
    for i = 1, count do
        if D.Ready(records[i]) then return records[i] end
    end
end

function D.Counts()
    local ready, kept = 0, 0
    for i = 1, count do
        local r = records[i]
        if D.Kept(r.itemID) then
            kept = kept + 1
        elseif not failed[r.itemID] then
            ready = ready + 1
        end
    end
    return ready, kept
end
