-------------------------------------------------------------------------------
--  Probe.lua -- /nf groupfinder: "probe" prints what the client offers the Group Finder (its
--  LFG functions, your last search's listings, chat lockdown, the chat filter), and "ping
--  <name>" asks a player for their card by addon whisper and prints the answer, so two testers
--  can check that the whispers reach across realms.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local GF = ns.GroupFinder
local Comms, Listings = GF.Comms, GF.Listings

local format, lower, match, concat, floor = string.format, string.lower, string.match, table.concat, math.floor

local FINDER = "Blizzard_GroupFinder_VanillaStyle"
local LISTED_SHOWN = 5
local FUNCTIONS = { "GetSearchResults", "GetSearchResultInfo", "GetSearchResultLeaderInfo",
    "GetSearchResultPlayerInfo", "GetActivityInfoTable", "GetActiveEntryInfo", "HasActiveEntryInfo",
    "GetPremadeGroupFinderStyle", "Search", "CreateListing", "UpdateListing" }
local ROLE_WORDS = { [0] = "none", "damage", "healer", "healer, damage", "tank", "tank, damage", "tank, healer",
    "tank, healer, damage" }

local asked = {}

local function YesNo(value)
    return value and "yes" or "no"
end

local function Locked()
    return C_ChatInfo.InChatMessagingLockdown ~= nil and C_ChatInfo.InChatMessagingLockdown()
end

local function Functions()
    local lfg = C_LFGList
    if not lfg then return "missing" end
    local missing = {}
    for _, name in ipairs(FUNCTIONS) do
        if type(lfg[name]) ~= "function" then missing[#missing + 1] = name end
    end
    return format("%d of %d listed functions; missing: %s", #FUNCTIONS - #missing, #FUNCTIONS,
        #missing > 0 and concat(missing, ", ") or "none")
end

local function Activity(id)
    local info = id and C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(id)
    if type(info) ~= "table" or issecretvalue(info.fullName) then return "?", "?" end
    return tostring(info.fullName), tostring(info.mapID)
end

local function ListingLines()
    if not (C_LFGList and C_LFGList.GetSearchResults) then return end
    if Locked() then return ns.Print("  Listings: not read during chat lockdown (an encounter).") end
    local total, results = C_LFGList.GetSearchResults()
    ns.Print(format("  Listings from your last search: %d (%d returned). Search in the game's Group Finder first.",
        type(total) == "number" and total or 0, type(results) == "table" and #results or 0))
    local n = Listings.Read(true)
    for i = 1, math.min(n, LISTED_SHOWN) do
        local entry = Listings.entries[i]
        local name, map = Activity(entry.activity)
        ns.Print(format("  %d. %s: activity %s \"%s\" map %s -> %s, %d member(s), listed %dm ago%s", i,
            entry.leader or "?", tostring(entry.activity), name, map, entry.dungeon or "no Journal match",
            entry.numMembers, floor(entry.age / 60), entry.delisted and ", delisted" or ""))
    end
end

local function Probe()
    ns.Print("Group Finder probe:")
    ns.Print("  C_LFGList: " .. Functions())
    ns.Print("  C_LFGListRoles.GetRoles: " .. YesNo(C_LFGListRoles and C_LFGListRoles.GetRoles))
    ns.Print("  " .. FINDER .. " loaded: " .. YesNo(C_AddOns.IsAddOnLoaded(FINDER)))
    ns.Print("  Chat lockdown now: " .. YesNo(Locked()))
    ns.Print("  Chat filter (ChatFrameUtil.AddMessageEventFilter): "
        .. YesNo(ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter))
    ns.Print("  \"No player named\" line known: " .. YesNo(type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string"))
    ns.Print("  Group Finder on: " .. YesNo(GF.On()) .. ", listening on " .. GF.PREFIX .. ": " .. YesNo(Comms.On()))
    ListingLines()
end

local function Describe(card)
    local class = GetClassInfo and card.class and GetClassInfo(card.class) or tostring(card.class)
    local parts = { format("%s %s", tostring(class), tostring(card.level)), "roles " .. ROLE_WORDS[card.roles] }
    if card.spec then parts[#parts + 1] = "spec " .. card.spec end
    parts[#parts + 1] = card.score and format("score %.1f", card.score / 10) or "score not shared"
    parts[#parts + 1] = card.bisTotal and format("BiS %d/%d", card.bisHave, card.bisTotal) or "BiS not shared"
    if card.dungeon then
        parts[#parts + 1] = card.dungeon
        if card.hasKills then parts[#parts + 1] = "kills " .. concat(card.kills, ",", 1, card.nKills) end
        if card.hasQuests then parts[#parts + 1] = format("quests %d in log, %d needed", card.nHave, card.nNeed) end
    end
    return concat(parts, "; ")
end

GF.Listen("card", function(sender, card, ping, seconds)
    if not asked[ping.id] then return end
    asked[ping.id] = nil
    ns.Print(format("Group Finder: %s answered in %d ms: %s.", sender, floor(seconds * 1000 + 0.5), Describe(card)))
end)

GF.Listen("noreply", function(ping)
    if not asked[ping.id] then return end
    asked[ping.id] = nil
    ns.Print(format("Group Finder: no answer from %s in %d seconds. They need Naowh Forever with Group Finder on.",
        ping.name, Comms.PING_WAIT))
end)

GF.Listen("offline", function(ping)
    if not asked[ping.id] then return end
    asked[ping.id] = nil
    ns.Print(format("Group Finder: %s is not online, or the name is spelled differently.", ping.name))
end)

local function Ping(name)
    name = strtrim(name or "")
    if name == "" then return ns.Print("Group Finder: /nf groupfinder ping <name>") end
    if not GF.On() then return ns.Print("Group Finder is off: turn it on in its settings page first.") end
    if lower(name) == lower(UnitName("player") or "") then
        return ns.Print("Group Finder: that is you. Ping a second player.")
    end
    local J = ns.Journal
    local suggested = J and J.Suggested and J.Suggested()
    local nonce, why = Comms.Ping(name, suggested and suggested.key)
    if not nonce then return ns.Print("Group Finder: could not ask " .. name .. " (" .. tostring(why) .. ").") end
    asked[nonce] = true
    ns.Print(format("Group Finder: asked %s for their card%s.", name,
        suggested and " for " .. suggested.name or ""))
end

function ns.GroupFinderCommand(rest)
    local command, arg = match(rest or "", "^(%S*)%s*(.-)$")
    command = lower(command or "")
    if command == "probe" then
        Probe()
    elseif command == "ping" then
        Ping(arg)
    else
        ns.Print("Group Finder: /nf groupfinder probe, or /nf groupfinder ping <name>.")
    end
end

GF.Describe = Describe
