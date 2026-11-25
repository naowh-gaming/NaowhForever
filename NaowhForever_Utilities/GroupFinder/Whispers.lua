-- Whispers.lua: whispering players from the Group Finder: Ask to Join to a group's leader, a line with an invite, and the whispers you receive kept as a list (ns.GroupFinder.Whispers).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms, Filter, Listings = GF.Card, GF.Comms, GF.Filter, GF.Listings
local S = GF.Settings

local gsub, lower = string.gsub, string.lower
local remove = table.remove

local WHISPER = "WHISPER"
local EVENT = "CHAT_MSG_WHISPER"
local LINE_MAX = 255
local LOG_MAX = 100
local ASKED_MAX = 100
local GUID_ARG = 12
local SCORE_FORMAT = "%.1f"
local TEXT_LOCKED = ns.L("Group Finder: whispers cannot be sent right now. Try again after the encounter.")
local TEXT_TOO_LONG = ns.L("Group Finder: that whisper is longer than 255 letters, so it was not sent.")
local TEXT_OR = ns.L(" or ")
local ROLE_WORD = { [Card.TANK] = ns.L("tank"), [Card.HEALER] = ns.L("healer"), [Card.DAMAGE] = ns.L("dps") }
local ROLE_ORDER = { Card.TANK, Card.HEALER, Card.DAMAGE }

local Whispers = { log = {}, unread = 0, LOG_MAX = LOG_MAX,
    PLACEHOLDERS = { "%class%", "%level%", "%spec%", "%role%", "%score%", "%dungeon%" } }
GF.Whispers = Whispers

local log = Whispers.log
local asked, nAsked = {}, 0
local values, words = {}, {}
local frame, on = nil, false

local function Roles()
    wipe(words)
    local roles = Filter.MyRoles()
    for _, role in ipairs(ROLE_ORDER) do
        if Card.Has(roles, role) then words[#words + 1] = ROLE_WORD[role] end
    end
    return table.concat(words, TEXT_OR)
end

local function Spec()
    local BiS = ns.BiS
    local spec = BiS and BiS.On() and BiS.Lists.CurrentSpec()
    return spec and lower(BiS.Lists.SpecShort(spec)) or ""
end

local function Score()
    local score = not ns.CHINA and ns.NaowhScore.Unit("player")
    return score and SCORE_FORMAT:format(score) or ""
end

local function Fill(text, dungeon)
    local className = UnitClass("player")
    values["%class%"] = className and lower(className) or ""
    values["%level%"] = tostring(UnitLevel("player"))
    values["%spec%"] = Spec()
    values["%role%"] = Roles()
    values["%score%"] = Score()
    values["%dungeon%"] = dungeon or ""
    text = gsub(text, "%%%a+%%", function(word) return values[lower(word)] end)
    return (gsub(gsub(text, "%s+", " "), "^ ", ""))
end
Whispers.Fill = Fill

local function Send(target, text)
    if text == "" then return false end
    if C_ChatInfo.InChatMessagingLockdown() then
        ns.Print(TEXT_LOCKED)
        return false
    end
    if #text > LINE_MAX then
        ns.Print(TEXT_TOO_LONG)
        return false
    end
    C_ChatInfo.SendChatMessage(text, WHISPER, nil, target)
    return true
end

local function DungeonOf(entry)
    local activity = entry and entry.activity and Listings.Activity(entry.activity)
    return activity and activity.name
end

function Whispers.Ask(entry)
    if not (entry and entry.leader) then return false end
    if not Send(entry.leader, Fill(S.Get("askMessage"), DungeonOf(entry))) then return false end
    local key = Comms.Key(entry.leader)
    if not asked[key] then
        if nAsked >= ASKED_MAX then
            wipe(asked)
            nAsked = 0
        end
        nAsked = nAsked + 1
    end
    asked[key] = GetTime()
    GF.Fire("asked", entry)
    return true
end

function Whispers.AskedAt(name)
    return asked[Comms.Key(name)]
end

local function ListedDungeons()
    local active = C_LFGList.GetActiveEntryInfo()
    if not active then return nil end
    wipe(words)
    for _, id in ipairs(active.activityIDs) do
        local activity = Listings.Activity(id)
        if activity then words[#words + 1] = activity.name end
    end
    if #words == 0 then return nil end
    return table.concat(words, TEXT_OR)
end

function Whispers.Invited(name)
    if not S.Get("inviteWhisper") then return false end
    if IsInGroup() and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then return false end
    local dungeon = ListedDungeons()
    if not dungeon then return false end
    return Send(name, Fill(S.Get("inviteMessage"), dungeon))
end

function Whispers.Remove(record)
    for i = 1, #log do
        if log[i] == record then
            remove(log, i)
            GF.Fire("whispers")
            return
        end
    end
end

function Whispers.Clear()
    wipe(log)
    Whispers.unread = 0
    GF.Fire("whispers")
end

function Whispers.Seen()
    Whispers.unread = 0
end

local function OnWhisper(_, _, text, sender, ...)
    if issecretvalue(text) or issecretvalue(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    local guid = select(GUID_ARG - 2, ...)
    local class
    if type(guid) == "string" and not issecretvalue(guid) and guid ~= "" then
        local _, classFile = GetPlayerInfoByGUID(guid)
        class = classFile
    end
    if #log >= LOG_MAX then remove(log) end
    table.insert(log, 1, { name = sender, text = text, at = time(), class = class })
    Whispers.unread = Whispers.unread + 1
    GF.Fire("whispers")
end

local function Sync()
    local want = GF.On()
    if want == on then return end
    on = want
    if want then
        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", OnWhisper)
        end
        frame:RegisterEvent(EVENT)
    else
        frame:UnregisterAllEvents()
        wipe(log)
        Whispers.unread = 0
    end
end

S.OnChange(function(key)
    if key == "enabled" then Sync() end
end)
ns.OnApply(Sync)
