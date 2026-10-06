-------------------------------------------------------------------------------
--  Listings.lua -- Forever's own group listings, read for the Group Finder
--  (ns.GroupFinder.Listings): after the player's own search, each listing's leader, its
--  dungeon as a Journal key, its first members and its age, in pooled entries. Read only when
--  asked and never in chat lockdown; it never searches, lists or invites by itself.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local GF = ns.GroupFinder
local S = GF.Settings

local lower, gsub, sub, min = string.lower, string.gsub, string.sub, math.min

local MEMBERS_READ = 5
local MAX_ENTRIES = 100
local NAME_MIN = 4
local EVENTS = { "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED" }

local Listings = { entries = {}, n = 0, state = "none", searched = false, MEMBERS_READ = MEMBERS_READ }
GF.Listings = Listings

local entries = Listings.entries
local stale = true
local frame, on = nil, false
local activityKey = {}
local byName, byMap, names

local function Secret(v)
    return v ~= nil and issecretvalue(v)
end

local function Locked()
    return C_ChatInfo.InChatMessagingLockdown ~= nil and C_ChatInfo.InChatMessagingLockdown()
end

local function Plain(name)
    return (gsub(gsub(lower(name), "^the ", ""), "[^%w]", ""))
end

local function Index()
    if byName then return true end
    local J = ns.Journal
    if not (J and J.Dungeons) then return false end
    byName, byMap, names = {}, {}, {}
    for _, dungeon in ipairs(J.Dungeons()) do
        local plain = Plain(dungeon.name)
        byName[plain] = dungeon.key
        names[#names + 1] = plain
        local map = dungeon.quests and dungeon.quests.map
        if map then byMap[map] = byMap[map] == nil and dungeon.key or false end
    end
    return true
end

local function Match(fullName, mapID)
    local plain = Plain(fullName)
    if byName[plain] then return byName[plain] end
    if #plain >= NAME_MIN then
        local best
        for i = 1, #names do
            local name = names[i]
            if sub(plain, 1, #name) == name and (not best or #name > #best) then best = name end
        end
        if best then return byName[best] end
        local only, count = nil, 0
        for i = 1, #names do
            if sub(names[i], 1, #plain) == plain then only, count = names[i], count + 1 end
        end
        if count == 1 then return byName[only] end
    end
    return mapID and byMap[mapID] or false
end
function Listings.Match(fullName, mapID)
    if not Index() then return nil end
    return Match(fullName, mapID) or nil
end

function Listings.DungeonOf(activityID)
    local key = activityKey[activityID]
    if key ~= nil then return key or nil end
    if not (C_LFGList.GetActivityInfoTable and Index()) then return nil end
    local info = C_LFGList.GetActivityInfoTable(activityID)
    local name = type(info) == "table" and info.fullName
    if type(name) ~= "string" or Secret(name) or Secret(info.mapID) then return nil end
    key = Match(name, info.mapID)
    activityKey[activityID] = key
    return key or nil
end

local function Fill(entry, id)
    local info = C_LFGList.GetSearchResultInfo(id)
    if type(info) ~= "table" then return false end
    local leader, count, age, delisted, activities = info.leaderName, info.numMembers, info.age, info.isDelisted,
        info.activityIDs
    if Secret(leader) or Secret(count) or Secret(age) or Secret(delisted) or Secret(activities) then return false end
    if type(count) ~= "number" or type(activities) ~= "table" then return false end
    local activity = activities[1]
    if Secret(activity) then return false end
    entry.id, entry.leader, entry.numMembers = id, type(leader) == "string" and leader or nil, count
    entry.age, entry.delisted, entry.party = type(age) == "number" and age or 0, delisted == true, info.partyGUID
    entry.activity, entry.nActivities = activity, #activities
    entry.dungeon = activity and Listings.DungeonOf(activity) or nil
    local members, n = entry.members, 0
    for m = 1, min(count, MEMBERS_READ) do
        local player = C_LFGList.GetSearchResultPlayerInfo(id, m)
        if type(player) == "table" and not (Secret(player.name) or Secret(player.level)
            or Secret(player.classFilename) or Secret(player.assignedRole) or Secret(player.isLeader)) then
            n = n + 1
            local member = members[n]
            if not member then
                member = {}
                members[n] = member
            end
            member.name, member.level, member.class = player.name, player.level, player.classFilename
            member.role, member.leader = player.assignedRole, player.isLeader == true
        end
    end
    entry.nMembers = n
    return true
end

function Listings.Read(force)
    if not (C_LFGList and C_LFGList.GetSearchResults and C_LFGList.GetSearchResultInfo) then
        Listings.state, Listings.n = "missing", 0
        return 0
    end
    if Locked() then
        Listings.state, Listings.n, stale = "locked", 0, true
        return 0
    end
    if not (stale or force) then return Listings.n end
    local _, results = C_LFGList.GetSearchResults()
    local n = 0
    for i = 1, type(results) == "table" and min(#results, MAX_ENTRIES) or 0 do
        local entry = entries[n + 1]
        if not entry then
            entry = { members = {} }
            entries[n + 1] = entry
        end
        if Fill(entry, results[i]) then n = n + 1 end
    end
    Listings.n, Listings.state, stale = n, "ready", false
    return n
end

local function OnEvent(_, event, id)
    if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
        stale, Listings.searched = true, true
        GF.Fire("listings")
        return
    end
    if stale or Secret(id) then return end
    for i = 1, Listings.n do
        local entry = entries[i]
        if entry.id == id then
            if Locked() or not Fill(entry, id) then stale = true end
            GF.Fire("listing", entry)
            return
        end
    end
end

local function Sync()
    local want = GF.On()
    if want == on then return end
    on = want
    if want then
        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
    else
        frame:UnregisterAllEvents()
        Listings.n, Listings.state, Listings.searched, stale = 0, "none", false, true
    end
end

S.OnChange(function(key)
    if key == "enabled" then Sync() end
end)
hooksecurefunc(ns, "Apply", Sync)
