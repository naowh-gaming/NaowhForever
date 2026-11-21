-- Trinkets.lua: the trinket rules (G.Trinkets): each slot's queue, best first, and the trinket-ready alert.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local G = ns.GearSets
local TRINKET_SLOTS = G.C.TRINKET_SLOTS

local PAIR = { [13] = 14, [14] = 13 }
local READY_WITHIN = 30
local RETRY = 1
local GCD = 1.5
local QUEUES = "gearTrinketQueue"
local QUEUE_EVENTS = { "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ALIVE", "PLAYER_UNGHOST" }
local READY_EVENTS = { "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED" }
local TEXT_READY = ns.L("%s is ready.")

local events, queueTimer, readyTimer
local chosen, readyAt, readyItem = {}, {}, {}

local function Secret(...)
    if not issecretvalue then return false end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return true end
    end
    return false
end

local function Queues()
    local account = ns.AccountSettings()
    account[QUEUES] = account[QUEUES] or {}
    local all = account[QUEUES]
    local key = ns.CharKey(all)
    all[key] = all[key] or {}
    return all[key]
end

local function List(slot)
    local queues = Queues()
    queues[slot] = queues[slot] or {}
    return queues[slot]
end

local function Rank(list, id)
    for i, queued in ipairs(list) do
        if queued == id then return i end
    end
end

local function InBags(itemID)
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if C_Container.GetContainerItemID(bag, slot) == itemID then return true end
        end
    end
    return false
end

local function Left(id)
    local start, duration = C_Container.GetItemCooldown(id)
    if Secret(start, duration) then return nil end
    if start == 0 then return 0 end
    return math.max(start + duration - GetTime(), 0)
end

local function BuffLeft(id)
    if C_Secrets.ShouldAurasBeSecret() then return nil end
    local spell = C_Item.GetItemSpell(id)
    local aura = spell and C_UnitAuras.GetAuraDataBySpellName("player", spell, "HELPFUL")
    return aura and aura.expirationTime > 0 and aura.expirationTime - GetTime() or 0
end

local function Best(slot, list, worn)
    local other = GetInventoryItemID("player", PAIR[slot])
    for _, id in ipairs(list) do
        local left = Left(id)
        if not left then return end
        if left <= READY_WITHIN and (id == worn or not chosen[id] and id ~= other and InBags(id)) then return id end
    end
end

local function Soonest(list)
    local soonest
    for _, id in ipairs(list) do
        local left = Left(id)
        if left and left > READY_WITHIN and (not soonest or left - READY_WITHIN < soonest) then
            soonest = left - READY_WITHIN
        end
    end
    return soonest
end

local function RunSlot(slot)
    local list = List(slot)
    if #list == 0 then return end
    local worn = GetInventoryItemID("player", slot)
    if worn and not Rank(list, worn) then return end
    if worn then
        local buff = BuffLeft(worn)
        if not buff then return end
        if buff > 0 then return buff end
    end
    local best = Best(slot, list, worn)
    if best and best ~= worn and not IsInventoryItemLocked(slot) then
        chosen[best] = true
        C_Item.EquipItemByName(best, slot)
    end
    return Soonest(list)
end

local function RunQueue()
    if queueTimer then
        queueTimer:Cancel()
        queueTimer = nil
    end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
    local soonest
    if UnitCastingInfo("player") or UnitChannelInfo("player") or GetCursorInfo() then
        soonest = RETRY
    else
        wipe(chosen)
        for _, slot in ipairs(TRINKET_SLOTS) do
            local due = RunSlot(slot)
            if due and (not soonest or due < soonest) then soonest = due end
        end
    end
    if soonest then queueTimer = C_Timer.NewTimer(soonest, RunQueue) end
end

local function Alert()
    readyTimer = nil
    local now, soonest = GetTime(), nil
    for _, slot in ipairs(TRINKET_SLOTS) do
        local at = readyAt[slot]
        if at and at <= now then
            readyAt[slot] = nil
            if GetInventoryItemID("player", slot) == readyItem[slot] then
                ns.Print(TEXT_READY:format(GetInventoryItemLink("player", slot)))
                ns.UI._PlayLSMSound(ns.UI.SoundPathFor(S.Get("trinketReadySound")))
            end
        elseif at and (not soonest or at - now < soonest) then
            soonest = at - now
        end
    end
    if soonest then readyTimer = C_Timer.NewTimer(soonest, Alert) end
end

local function WatchReady()
    for _, slot in ipairs(TRINKET_SLOTS) do
        local id = GetInventoryItemID("player", slot)
        local start, duration, enable = GetInventoryItemCooldown("player", slot)
        if not Secret(start, duration, enable) then
            if id and enable ~= 0 and duration > GCD and start + duration > GetTime() then
                readyAt[slot], readyItem[slot] = start + duration, id
            elseif readyItem[slot] ~= id or duration == 0 then
                readyAt[slot] = nil
            end
        end
    end
    if readyTimer then readyTimer:Cancel() end
    Alert()
end

local function QueueOn()
    return G.On() and S.Get("trinketQueue")
end

local function ReadyOn()
    return G.On() and S.Get("trinketReady")
end

local function OnEvent(_, event, slot)
    if event == "PLAYER_EQUIPMENT_CHANGED" and not PAIR[slot] then return end
    if ReadyOn() and (event == "BAG_UPDATE_COOLDOWN" or event == "PLAYER_EQUIPMENT_CHANGED") then WatchReady() end
    if QueueOn() and not InCombatLockdown() then RunQueue() end
end

local function Apply()
    local queue, ready = QueueOn(), ReadyOn()
    if events then events:UnregisterAllEvents() end
    if queueTimer and not queue then
        queueTimer:Cancel()
        queueTimer = nil
    end
    if readyTimer and not ready then
        readyTimer:Cancel()
        readyTimer = nil
    end
    if not (queue or ready) then return end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(queue and QUEUE_EVENTS or READY_EVENTS) do events:RegisterEvent(event) end
    if ready then WatchReady() end
    if queue then RunQueue() end
end

local Trinkets = {}
G.Trinkets = Trinkets

Trinkets.InBags = InBags

function Trinkets.Rank(slot, id)
    return Rank(List(slot), id)
end

function Trinkets.Toggle(slot, id)
    local list = List(slot)
    local rank = Rank(list, id)
    if rank then
        table.remove(list, rank)
    else
        list[#list + 1] = id
    end
    if QueueOn() then RunQueue() end
end

local function OnSet(key)
    if key == "gearSets" or key == "trinketQueue" or key == "trinketReady" then Apply() end
end

hooksecurefunc(S, "Set", OnSet)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
