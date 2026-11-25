-- Run with Lua 5.1 from the repository root: Whisper Invite. Off, it listens to no whispers; on, a whisper
-- with one of your words invites its sender, unless you cannot invite, they are grouped, or Friends and Guild Only
-- leaves them out. A Battle.net whisper invites the friend's Forever character.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local values = { enabled = true, whisperInvite = false, whisperInviteWords = "inv, invite", whisperInviteFriends = false }
local S = {}
function S.Get(key) return values[key] end
function S.Set(key, value) values[key] = value end

local function Hook(owner, name, after)
    local before = owner[name]
    owner[name] = function(...)
        before(...)
        after(...)
    end
end

local card
local ns = {
    QoLSettings = S,
    Apply = function() end,
    Shared = { Settings = { Page = function() return { Card = function(_, c) card = c end } end } },
}
function ns.OnApply(fn) Hook(ns, "Apply", fn) end

local SECRET = {}
local frame
local invited, bnInvited = {}, {}
local canInvite, party, friends, guild, accounts = true, {}, {}, {}, {}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function()
        local f = { events = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(_, fn) self.onEvent = fn end
        if not frame then frame = f end
        return f
    end,
    hooksecurefunc = Hook,
    issecretvalue = function(v) return v == SECRET end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    Ambiguate = function(name) return (name:gsub("%-.*", "")) end,
    UnitName = function() return "Me" end,
    UnitInParty = function(name) return party[name] end,
    UnitInRaid = function() return nil end,
    UnitFactionGroup = function() return "Horde" end,
    IsInGuild = function() return true end,
    WOW_PROJECT_ID = 11,
    C_GuildInfo = { MemberExistsByName = function(name) return guild[name] end },
    C_FriendList = { IsFriend = function(guid) return friends[guid] end },
    C_PartyInfo = {
        CanInvite = function() return canInvite end,
        CanFormCrossFactionParties = function() return false end,
        InviteUnit = function(name) invited[#invited + 1] = name end,
    },
    C_BattleNet = {
        GetGameAccountInfoByGUID = function() end,
        GetAccountInfoByID = function(id) return accounts[id] end,
        InviteFriend = function(id) bnInvited[#bnInvited + 1] = id end,
    },
}, { __index = _G })
env._G = env
local fn = assert(loadstring(Read("NaowhForever_QoL/Questing/WhisperInvite.lua"), "WhisperInvite"))
setfenv(fn, env)
fn()

local function Whisper(text, sender, guid)
    local before = #invited
    frame.onEvent(frame, "CHAT_MSG_WHISPER", text, sender or "Stranger-Realm", "", "", "", "", 0, 0, "", 0, 1,
        guid or "Player-1")
    return #invited > before
end

local function BNWhisper(text, id)
    local before = #bnInvited
    frame.onEvent(frame, "CHAT_MSG_BN_WHISPER", text, "|Kq1|k", "", "", "", "", 0, 0, "", 0, 1, "", id)
    return #bnInvited > before
end

check("the card turns on with whisperInvite", card.switch == "whisperInvite")
ns.Apply()
check("off, no whispers are listened to", next(frame.events) == nil)
S.Set("whisperInvite", true)
check("on, whispers and Battle.net whispers are listened to",
    frame.events.CHAT_MSG_WHISPER and frame.events.CHAT_MSG_BN_WHISPER)

for _, text in ipairs({ "inv", "INV", "inv pls", "invite?", "  Inv!  ", "can i get an inv" }) do
    check("invited: " .. text, Whisper(text))
end
check("the full name with realm is invited", invited[1] == "Stranger-Realm")
for _, text in ipairs({ "hello", "investing in ore", "invitation", "" }) do
    check("not invited: " .. text, not Whisper(text))
end

S.Set("whisperInviteWords", "Summon me, LFG")
check("a phrase of two words invites", Whisper("summon me please"))
check("the words come apart only at commas", not Whisper("summon"))
check("the old words are gone", not Whisper("inv"))
S.Set("whisperInviteWords", " , ,")
check("an empty list invites no one", not Whisper("inv"))
S.Set("whisperInviteWords", "inv")

check("a secret whisper is left alone", not Whisper(SECRET))
check("a secret sender is left alone", not Whisper("inv", SECRET))
party.Buddy = true
check("someone already in the group is not invited", not Whisper("inv", "Buddy-Realm"))
check("nor yourself", not Whisper("inv", "Me-Realm"))
canInvite = false
check("nor anyone while you cannot invite", not Whisper("inv"))
canInvite = true

S.Set("whisperInviteFriends", true)
check("Friends and Guild Only leaves strangers out", not Whisper("inv"))
friends["Player-2"], guild.Mate = true, true
check("but invites a friend", Whisper("inv", "Pal-Realm", "Player-2"))
check("and a guild member", Whisper("inv", "Mate-Realm"))
S.Set("whisperInviteFriends", false)

local forever = { isOnline = true, wowProjectID = 11, characterName = "Bnet", factionName = "Horde", gameAccountID = 77 }
accounts[5] = { gameAccountInfo = forever }
check("a Battle.net friend on Forever is invited", BNWhisper("inv", 5) and bnInvited[1] == 77)
check("not without a word", not BNWhisper("hi", 5))
forever.factionName = "Alliance"
check("nor on the other faction", not BNWhisper("inv", 5))
forever.factionName, forever.wowProjectID = "Horde", 1
check("nor in another game", not BNWhisper("inv", 5))
forever.wowProjectID = 11
party.Bnet = true
check("nor when their character is grouped", not BNWhisper("inv", 5))
check("an unknown Battle.net sender is left alone", not BNWhisper("inv", 9))

S.Set("whisperInvite", false)
check("turning it off stops listening", next(frame.events) == nil)

print(("whisper invite: %d checks passed"):format(checks))
