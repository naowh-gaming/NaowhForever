-- GroupInspect.lua: Group Inspect's records of your group (ns.GroupInspect), the inspect walk and the preview.
local ns = _G.NaowhForever
local S = ns.QoLSettings
local Score = ns.NaowhScore
local Queue = Score.InspectQueue
local IP = ns.InspectPanel
local Items = ns.Shared.Items
local Enchants = ns.BiS.Enchants
local GEAR_SLOTS = Items.GEAR_SLOTS

local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo
local GetItemQualityByID = C_Item.GetItemQualityByID

local GI = {}
ns.GroupInspect = GI

local STALE = 300
local LOAD_SETTLE = 0.2
local EARLY = 0.05
local MAIN, OFF = 16, 17
local ROLE_OF = { Tank = "TANK", Healer = "HEALER", Damage = "DAMAGER" }
local EVENTS = { "GROUP_ROSTER_UPDATE", "UNIT_CONNECTION", "PLAYER_ROLES_ASSIGNED", "PLAYER_REGEN_ENABLED",
    "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "TRAIT_CONFIG_UPDATED" }
local ENCHANT_SLOTS = Enchants.SLOTS

local PARTY_UNITS, RAID_UNITS = 4, 40
local TREE_COUNT = 3
local STAT_BASE, STAT_STEP, STAT_SPREAD, STAT_RANGE = 0.9, 7, 11, 50
local TENTHS = 10
local UNENCHANTED_EVERY = 3
local ROUND = 0.5
local GUID_FORMAT = "Player-0-%08X"

local PARTY, RAID = {}, {}
for i = 1, PARTY_UNITS do PARTY[i] = "party" .. i end
for i = 1, RAID_UNITS do RAID[i] = "raid" .. i end

local open, previewOn, previewMode = false, false, "party"
local records, members, count = {}, {}, 0
local free, freeCount = {}, 0
local gen = 0
local ownGUID
local listeners = {}
local dirty, batch = {}, {}
local rosterDirty, flushQueued, rosterQueued, selfQueued, loadQueued, waiting = false, false, false, false, false, false
local staleQueued = false
local walkAt
local events, hooked
local links = {}

local function Readable(value)
    return value ~= nil and not issecretvalue(value)
end

function GI.On()
    return S.Get("enabled") == true and S.Get("groupInspect") == true
end

function GI.IsOpen()
    return open
end

GI.StatsFromGear = GI.StatsFromGear or function() end

local function Flush()
    flushQueued = false
    if not (open or previewOn) then
        rosterDirty = false
        wipe(dirty)
        return
    end
    if rosterDirty then
        rosterDirty = false
        wipe(dirty)
        for i = 1, #listeners do listeners[i](nil) end
        return
    end
    dirty, batch = batch, dirty
    for guid in pairs(batch) do
        for i = 1, #listeners do listeners[i](guid) end
    end
    wipe(batch)
end

function GI.Changed(guid)
    if not (open or previewOn) then return end
    if guid == nil then rosterDirty = true else dirty[guid] = true end
    if flushQueued then return end
    flushQueued = true
    C_Timer.After(0, Flush)
end
local Changed = GI.Changed

function GI.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function NewRecord()
    if freeCount > 0 then
        local rec = free[freeCount]
        free[freeCount] = nil
        freeCount = freeCount - 1
        return rec
    end
    return { gear = {}, _slots = {}, _talents = { spent = {}, ids = {} } }
end

local function Clear(rec)
    rec.guid, rec.unit, rec.name, rec.classFile, rec.level, rec.role = nil, nil, nil, nil, nil, nil
    rec.online, rec.inRange, rec.state, rec.hasNF, rec.nfVersion = nil, nil, nil, nil, nil
    rec.score, rec.scoreShared, rec.ilvl, rec.talents, rec.stats, rec.statsShared = nil, nil, nil, nil, nil, nil
    rec.updated, rec._seen, rec._read, rec._stale, rec._far, rec._loading = nil, nil, nil, nil, nil, nil
    rec._assigned, rec._statsWait = nil, nil
    wipe(rec.gear)
    for _, entry in pairs(rec._slots) do
        entry.id, entry.link, entry.quality, entry.ilvl, entry.enchanted, entry.bis = nil, nil, nil, nil, nil, nil
    end
    local talents = rec._talents
    wipe(talents.spent)
    talents.tree, talents.role, talents.count, talents.total = nil, nil, nil, nil
end

local function Release(rec)
    records[rec.guid] = nil
    Clear(rec)
    freeCount = freeCount + 1
    free[freeCount] = rec
end

local function Fresh(rec, now)
    return rec._read ~= nil and not rec._stale and now - rec._read < STALE
end

local function State(rec)
    if rec.unit == "player" then return "self" end
    if not rec.online then return "offline" end
    if Queue.Pending() == rec.guid then return "inspecting" end
    if Fresh(rec, GetTime()) then return "ready" end
    if rec._far then return "out_of_range" end
    return "queued"
end

local function SetState(rec, state)
    if rec.state == state then return end
    rec.state = state
    Changed(rec.guid)
end

local function TalentRole(rec)
    local talents = rec.talents
    return talents and ROLE_OF[talents.role]
end

local function Basics(rec, unit)
    local guid = rec.guid
    if not rec.name then rec.name = IP.FullName(unit) end
    local _, classFile = UnitClass(unit)
    if Readable(classFile) then rec.classFile = classFile end
    local level = UnitLevel(unit)
    if Readable(level) and level > 0 then rec.level = level end
    local online = UnitIsConnected(unit)
    rec.online = Readable(online) and online == true
    local role = UnitGroupRolesAssigned(unit)
    rec._assigned = Readable(role) and role ~= "NONE"
    rec.role = rec._assigned and role or TalentRole(rec)
    if unit == "player" then
        rec.state = "self"
        if rec.hasNF == nil then rec.hasNF = true end
        return
    end
    local known = Score.Known(guid)
    if known and known.shared then rec.score, rec.scoreShared, rec.hasNF = known.score, true, true end
    if IP.RunsNaowh(guid) then rec.hasNF = true end
    rec.state = State(rec)
end

local function Add(unit)
    local guid = UnitGUID(unit)
    if not Readable(guid) then return end
    local rec = records[guid]
    if not rec then
        rec = NewRecord()
        rec.guid = guid
        records[guid] = rec
    end
    rec.unit, rec._seen = unit, gen
    count = count + 1
    members[count] = rec
    Basics(rec, unit)
end

local function FillItem(entry, slot)
    local link = entry.link
    entry.quality = GetItemQualityByID(entry.id)
    entry.ilvl = link and GetDetailedItemLevelInfo(link) or nil
    entry.enchanted = nil
    if link and ENCHANT_SLOTS[slot] then
        local can, current = Enchants.Enchantable(link)
        if current ~= 0 then entry.enchanted = true elseif can then entry.enchanted = false end
    end
    return link == nil or entry.quality == nil or entry.ilvl == nil
end

local function Average(gear)
    local sum = 0
    for i = 1, #GEAR_SLOTS do
        local entry = gear[GEAR_SLOTS[i][1]]
        if entry and entry.ilvl then sum = sum + entry.ilvl end
    end
    local main = gear[MAIN]
    if main and main.ilvl and not gear[OFF] and Items.IsTwoHand(main.id) then sum = sum + main.ilvl end
    return sum / #GEAR_SLOTS
end

local function ScoreOf(rec)
    if rec.scoreShared then return end
    wipe(links)
    for slot, entry in pairs(rec.gear) do links[slot] = entry.link end
    rec.score = Score.Links(links)
end

local OnItems

local function ReadGear(rec, unit)
    local gear, slots, guid = rec.gear, rec._slots, rec.guid
    local loading = false
    for i = 1, #GEAR_SLOTS do
        local slot = GEAR_SLOTS[i][1]
        local id = GetInventoryItemID(unit, slot)
        if id and id ~= 0 then
            local entry = slots[slot]
            if not entry then
                entry = {}
                slots[slot] = entry
            end
            entry.id, entry.link = id, GetInventoryItemLink(unit, slot)
            gear[slot] = entry
            if FillItem(entry, slot) then loading = true end
            entry.bis = IP.TheirRank(guid, slot, id) and true or nil
        else
            gear[slot] = nil
        end
    end
    rec._loading = loading
    if loading then OnItems() end
end

local function Stats(rec)
    rec._statsWait = rec.statsShared ~= true and GI.StatsFromGear(rec) == false or nil
    if rec._statsWait then OnItems() end
end

local function ReadTalents(rec, unit, read)
    local own = rec._talents
    if rec.talents and rec.talents ~= own then return end
    local _, classFile = UnitClass(unit)
    if read(classFile, own) then rec.talents = own end
    if not rec._assigned then rec.role = TalentRole(rec) end
end

local function InspectTalents(classFile, out)
    return IP.ReadInspectTalents(classFile, out)
end

local function OwnTalents(classFile, out)
    local config = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    return config ~= nil and C_Traits ~= nil and IP.ReadTalentTrees(config, classFile, out)
end

local function FillSelf()
    local rec = ownGUID and records[ownGUID]
    if not rec then return end
    ReadGear(rec, "player")
    rec.score, rec.scoreShared = (Score.Unit("player")), false
    if rec.hasNF == nil then rec.hasNF = true end
    local _, equipped = GetAverageItemLevel()
    if Readable(equipped) then rec.ilvl = equipped end
    ReadTalents(rec, "player", OwnTalents)
    Stats(rec)
    rec.updated, rec.state = GetTime(), "self"
    Changed(rec.guid)
end

local Walk

local function WalkDue()
    if not walkAt or walkAt - GetTime() > EARLY then return end
    walkAt = nil
    Walk()
end

local function WalkSoon(delay)
    if not open then return end
    local at = GetTime() + delay
    if walkAt and walkAt <= at then return end
    walkAt = at
    C_Timer.After(delay, WalkDue)
end

local function StaleDue()
    staleQueued = false
    WalkSoon(0)
end

local function StaleSoon(delay)
    if staleQueued then return end
    staleQueued = true
    C_Timer.After(delay, StaleDue)
end

local function OnReady(guid, unit)
    local rec = records[guid]
    if not rec then return end
    local now = GetTime()
    ReadGear(rec, unit)
    ScoreOf(rec)
    local level = C_PaperDollInfo.GetInspectItemLevel and C_PaperDollInfo.GetInspectItemLevel(unit)
    rec.ilvl = Readable(level) and level > 0 and level or Average(rec.gear)
    ReadTalents(rec, unit, InspectTalents)
    Stats(rec)
    rec._read, rec._stale, rec._far, rec.inRange, rec.updated = now, false, false, true, now
    rec.state = "ready"
    Changed(guid)
    WalkSoon(Queue.Wait())
end

local function Try(rec, now)
    if Fresh(rec, now) then return "known" end
    if Queue.Pending() == rec.guid then return "wait", Queue.WAIT_FOR end
    local unit = rec.unit
    local guid = UnitGUID(unit)
    if not (Readable(guid) and guid == rec.guid) then return "moved" end
    local result = Queue.Request(unit, guid, OnReady)
    if result == "asked" then
        rec.inRange, rec._far = true, false
        SetState(rec, "inspecting")
        return "wait", Queue.WAIT_FOR
    elseif result == "far" then
        rec.inRange, rec._far = false, true
        SetState(rec, "out_of_range")
        return "far"
    end
    SetState(rec, rec._far and "out_of_range" or "queued")
    local wait = Queue.Wait()
    return "wait", wait > 0 and wait or Queue.GAP
end

local RosterSoon

function Walk()
    if not open or previewOn or InCombatLockdown() then return end
    local now = GetTime()
    local far, soonest = false, nil
    for pass = 1, 2 do
        local nf = pass == 2
        for i = 1, count do
            local rec = members[i]
            if rec.unit ~= "player" and rec.online and (rec.hasNF == true) == nf then
                local result, delay = Try(rec, now)
                if result == "wait" then return WalkSoon(delay) end
                if result == "moved" then return RosterSoon() end
                if result == "far" then
                    far = true
                elseif result == "known" then
                    local due = rec._read + STALE - now
                    if not soonest or due < soonest then soonest = due end
                end
            end
        end
    end
    if far then
        WalkSoon(Queue.RETRY)
    elseif soonest then
        StaleSoon(soonest)
    end
end

local function Rebuild()
    rosterQueued = false
    if not open then return end
    gen = gen + 1
    local before = count
    count = 0
    ownGUID = ownGUID or UnitGUID("player")
    Add("player")
    if IsInRaid() then
        for i = 1, math.min(GetNumGroupMembers(), #RAID) do
            local unit = RAID[i]
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then Add(unit) end
        end
    else
        for i = 1, math.min(GetNumSubgroupMembers(), #PARTY) do
            if UnitExists(PARTY[i]) then Add(PARTY[i]) end
        end
    end
    for i = count + 1, before do members[i] = nil end
    for _, rec in pairs(records) do
        if rec._seen ~= gen then Release(rec) end
    end
    Changed(nil)
    WalkSoon(0)
end

function RosterSoon()
    if rosterQueued then return end
    rosterQueued = true
    C_Timer.After(0, Rebuild)
end

local function SelfDue()
    selfQueued = false
    if open then FillSelf() end
end

local function SelfSoon()
    if selfQueued then return end
    selfQueued = true
    C_Timer.After(LOAD_SETTLE, SelfDue)
end

local function Loaded()
    loadQueued = false
    if not open then return end
    local still = false
    for i = 1, count do
        local rec = members[i]
        if rec._loading or rec._statsWait then
            local loading = false
            for slot, entry in pairs(rec.gear) do
                if FillItem(entry, slot) then loading = true end
            end
            rec._loading = loading
            if rec.unit == "player" then rec.score = (Score.Unit("player")) else ScoreOf(rec) end
            Stats(rec)
            if loading or rec._statsWait then still = true end
            Changed(rec.guid)
        end
    end
    if not still and waiting then
        waiting = false
        events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
end

function OnItems()
    if not open or waiting then return end
    waiting = true
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

local function LoadSoon()
    if loadQueued then return end
    loadQueued = true
    C_Timer.After(LOAD_SETTLE, Loaded)
end

local function Worn(unit)
    if not Readable(unit) or UnitIsUnit(unit, "player") then return end
    local guid = UnitGUID(unit)
    local rec = Readable(guid) and records[guid]
    if not rec then return end
    rec._stale = true
    SetState(rec, State(rec))
    WalkSoon(Queue.GAP)
end

local function OnEvent(_, event, arg)
    if event == "UNIT_INVENTORY_CHANGED" then
        Worn(arg)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        LoadSoon()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        SelfSoon()
    elseif event == "PLAYER_REGEN_ENABLED" then
        WalkSoon(0)
    else
        RosterSoon()
    end
end

local function OnRemember(guid, score, _, shared)
    if not open or not shared then return end
    local rec = records[guid]
    if not rec or rec.unit == "player" then return end
    rec.score, rec.scoreShared, rec.hasNF = score, true, true
    Changed(guid)
end

local function Listen(on)
    if on and not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    if not events then return end
    for i = 1, #EVENTS do
        if on then events:RegisterEvent(EVENTS[i]) else events:UnregisterEvent(EVENTS[i]) end
    end
    if not on then
        events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        waiting = false
    end
end

function GI.Open()
    if open or not GI.On() then return end
    open = true
    if not hooked then
        hooked = true
        hooksecurefunc(Score, "Remember", OnRemember)
    end
    Listen(true)
    Queue.Claim(true)
    Rebuild()
    FillSelf()
end

function GI.Close()
    if not open then return end
    open = false
    walkAt = nil
    Listen(false)
    Queue.Claim(false)
end

local function Forget(rec)
    if rec.unit == "player" then return end
    rec._read, rec._stale, rec._far = nil, nil, nil
    rec.state = State(rec)
    Changed(rec.guid)
end

function GI.Refresh(guid)
    local rec = guid and records[guid]
    if not (open and rec) then return end
    if rec.unit == "player" then return SelfSoon() end
    Forget(rec)
    WalkSoon(0)
end

function GI.RefreshAll()
    if not open then return end
    for i = 1, count do Forget(members[i]) end
    SelfSoon()
    WalkSoon(0)
end

local D
local preview = { party = {}, raid = {} }
local previewBy = {}
local reading

local function PreviewRead(slot)
    local entry = reading[slot]
    if not entry then return nil end
    return entry.ilvl, entry.quality, slot == MAIN and Items.IsTwoHand(entry.id)
end

local function PreviewGear(rec, key, nf, index)
    for slot, id, quality, ilvl, bis in D.GEAR[key]:gmatch("(%d+):(%d+):(%d+):(%d+):(%d)") do
        slot = tonumber(slot)
        local enchanted
        if ENCHANT_SLOTS[slot] then enchanted = nf or (slot + index) % UNENCHANTED_EVERY ~= 0 end
        rec.gear[slot] = { id = tonumber(id), link = "item:" .. id, quality = tonumber(quality), ilvl = tonumber(ilvl),
            enchanted = enchanted, bis = nf and bis == "1" or nil }
    end
    reading = rec.gear
    rec.score = Score.Of(PreviewRead)
    rec.ilvl = Average(rec.gear)
end

local function PreviewStats(kind, index)
    local scale = STAT_BASE + (index * STAT_STEP % STAT_SPREAD) / STAT_RANGE
    local stats = {}
    for i, key in ipairs(D.STAT_KEYS) do
        local value = D.PROFILES[kind][i] * scale
        if key == "CRIT" or key == "HIT" then
            stats[key] = math.floor(value * TENTHS + ROUND) / TENTHS
        else
            stats[key] = math.floor(value + ROUND)
        end
    end
    return stats
end

local function PreviewMember(def, index, unit)
    local name, class, key, role, spent, level, nf, kind, state = unpack(def)
    local rec = { guid = GUID_FORMAT:format(index), unit = unit, name = name, classFile = class, level = level,
        role = role, online = state ~= "offline", inRange = state ~= "out_of_range", state = state or "ready",
        hasNF = nf, nfVersion = nf and D.VERSION or nil, gear = {}, updated = 0 }
    if index == 1 then rec.state = "self" end
    local known = rec.state == "ready" or rec.state == "self"
    if known or (nf and rec.online) then
        local lead = 1
        for i = 2, TREE_COUNT do if spent[i] > spent[lead] then lead = i end end
        rec.talents = { spent = { spent[1], spent[2], spent[3] }, tree = D.TREES[class][lead], role = D.TALENT_ROLE[role],
            count = TREE_COUNT, total = spent[1] + spent[2] + spent[3] }
        rec.stats, rec.statsShared = PreviewStats(kind, index), nf
    end
    if known then
        PreviewGear(rec, key, nf, index)
        rec.scoreShared = nf and index ~= 1
    elseif nf and rec.online then
        PreviewGear(rec, key, nf, index)
        wipe(rec.gear)
        rec.ilvl, rec.scoreShared = nil, true
    end
    return rec
end

local function BuildPreview()
    if #preview.raid > 0 then return end
    D = GI.PreviewData
    for i, def in ipairs(D.PREVIEW) do
        local raid = PreviewMember(def, i, i == 1 and "player" or RAID[i])
        preview.raid[i] = raid
        previewBy[raid.guid] = raid
        if i <= D.PARTY_SIZE then
            local party = PreviewMember(def, i, i == 1 and "player" or PARTY[i - 1])
            party.guid = raid.guid
            preview.party[i] = party
        end
    end
end

function GI.Preview(on)
    on = on == true
    if on == previewOn then return end
    if on then BuildPreview() end
    previewOn = on
    Changed(nil)
    if not on then WalkSoon(0) end
end

function GI.PreviewMode(mode)
    if (mode == "party" or mode == "raid") and mode ~= previewMode then
        previewMode = mode
        if previewOn then Changed(nil) end
    end
    return previewMode
end

function GI.Mode()
    if previewOn then return previewMode end
    if IsInRaid() then return "raid" end
    if IsInGroup() then return "party" end
    return "solo"
end

function GI.Members()
    if previewOn then return preview[previewMode] end
    return members
end

function GI.Count()
    return #GI.Members()
end

function GI.Member(guid)
    if previewOn then
        if previewMode == "raid" then return previewBy[guid] end
        for _, rec in ipairs(preview.party) do
            if rec.guid == guid then return rec end
        end
        return nil
    end
    return records[guid]
end

local function OnSettingChanged(key)
    if (key == "enabled" or key == "groupInspect") and not GI.On() then GI.Close() end
end

S.OnChange(OnSettingChanged)
