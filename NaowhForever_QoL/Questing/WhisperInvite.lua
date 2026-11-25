-- WhisperInvite.lua: Whisper Invite, inviting players who whisper you one of your words.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local EVENTS = { "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }
local BN_WHISPER = "CHAT_MSG_BN_WHISPER"
local GUID_ARG, BN_SENDER_ARG = 12, 13
local LIST_SEP = "[^,]+"
local NOT_WORD = "[%p%s]+"
local EMPTY = "  "

local events = CreateFrame("Frame")
local words = {}

local function On()
    return S.Get("enabled") and S.Get("whisperInvite")
end

local function Spaced(text)
    return " " .. strtrim((text:lower():gsub(NOT_WORD, " "))) .. " "
end

local function Asked(text)
    text = Spaced(text)
    for _, word in ipairs(words) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

local function InGroup(name)
    return UnitInParty(name) or UnitInRaid(name)
end

local function Known(name, guid)
    if type(guid) == "string" and guid ~= "" and not issecretvalue(guid)
        and (C_FriendList.IsFriend(guid) or C_BattleNet.GetGameAccountInfoByGUID(guid)) then
        return true
    end
    return IsInGuild() and C_GuildInfo.MemberExistsByName(name)
end

local function InviteFriend(id)
    if type(id) ~= "number" or issecretvalue(id) then return end
    local account = C_BattleNet.GetAccountInfoByID(id)
    local game = account and account.gameAccountInfo
    if not (game and game.isOnline and game.wowProjectID == WOW_PROJECT_ID and game.characterName) then return end
    if not C_PartyInfo.CanFormCrossFactionParties() and game.factionName ~= UnitFactionGroup("player") then return end
    if InGroup(game.characterName) then return end
    C_BattleNet.InviteFriend(game.gameAccountID)
end

local function OnWhisper(_, event, text, sender, ...)
    if issecretvalue(text) or issecretvalue(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    if not (Asked(text) and C_PartyInfo.CanInvite()) then return end
    if event == BN_WHISPER then return InviteFriend(select(BN_SENDER_ARG - 2, ...)) end
    local name = Ambiguate(sender, "none")
    if name == UnitName("player") or InGroup(name) then return end
    if S.Get("whisperInviteFriends") and not Known(name, select(GUID_ARG - 2, ...)) then return end
    C_PartyInfo.InviteUnit(sender)
end

local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        return
    end
    wipe(words)
    for item in S.Get("whisperInviteWords"):gmatch(LIST_SEP) do
        item = Spaced(item)
        if item ~= EMPTY then words[#words + 1] = item end
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

events:SetScript("OnEvent", OnWhisper)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "whisperInvite" or key == "whisperInviteWords" then Apply() end
end)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "whisperInvite", name = "Whisper Invite", order = 27, switch = "whisperInvite",
    help = "Invites players who whisper you one of your words.",
    rows = {
        { key = "whisperInviteWords", label = "Invite Words", text = true, wide = true,
          help = "Words or phrases that get an invite, separated by commas. Capitals and punctuation do not matter." },
        { key = "whisperInviteFriends", label = "Friends and Guild Only", toggle = true,
          help = "Only friends, Battle.net friends and guild members get an invite." },
    },
})
