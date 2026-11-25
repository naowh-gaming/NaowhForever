-- SettingsPage.lua: the Group Finder's settings page (Group Finder/Settings): what your card shares, what it does for you on the game's group finder, and the whispers it sends.
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local S = GF.Settings
local Settings = ns.Shared.Settings

local OFF = ns.L("Turn on the Group Finder")
local TEXT_BASICS = ns.L("Class, level and roles only")
local TEXT_SHARES = ns.L("Shares %d of %d")
local SHARED = { "shareScore", "shareKills", "shareQuests", "shareBis" }

local function On()
    return GF.On()
end

local function Summary(store)
    local count = 0
    for _, key in ipairs(SHARED) do
        if store.Get(key) then count = count + 1 end
    end
    if count == 0 then return TEXT_BASICS end
    return TEXT_SHARES:format(count, #SHARED)
end

local page = Settings.Page(GF.PAGE, S)

page:Card({
    id = "card", name = "Your Card", order = 10,
    help = "What Naowh Forever players see about you when you list or apply.",
    summary = Summary,
    rows = {
        { key = "shareScore", label = "Gear Score", toggle = true, needs = On, why = OFF, hidden = ns.CHINA,
          help = "Shows your Gear Score on your card." },
        { key = "shareKills", label = "Boss Kills", toggle = true, needs = On, why = OFF,
          help = "Shows how often you have killed each boss of the dungeon." },
        { key = "shareQuests", label = "Dungeon Quests", toggle = true, needs = On, why = OFF,
          help = "Shows the dungeon's quests you have or still need." },
        { key = "shareBis", label = "BiS Progress", toggle = true, needs = On, why = OFF, hidden = ns.CHINA,
          help = "Shows how many of your BiS items you already have." },
    },
})

page:Card({
    id = "finder", name = "On the Group Finder", order = 20,
    help = "What the Group Finder does for you beside the game's own window.",
    rows = {
        { key = "panelOpen", label = "Show the Side Panel", toggle = true, needs = On, why = OFF,
          help = "Shows the Naowh Forever panel to the right of the game's group finder." },
        { key = "autoRole", label = "Set My Role When I Join", toggle = true, needs = On, why = OFF,
          help = "Sets your group role to the one the leader invited you as." },
        { key = "applySound", label = "Sound When Someone Applies", toggle = true, needs = On, why = OFF,
          help = "Plays a sound when a player applies to your group." },
        { key = "hideDeclined", label = "Dim Groups That Declined Me", toggle = true, needs = On, why = OFF,
          help = "Dims the groups that declined your application." },
    },
})

page:Card({
    id = "messages", name = "Messages", order = 30,
    help = "The whispers the Group Finder sends for you; %class%, %level%, %spec% and %role% fill in.",
    rows = {
        { key = "askMessage", label = "Ask to Join", text = true, wide = true, needs = On, why = OFF,
          help = "Whispered to a group's leader by Ask to Join; %score% and %dungeon% fill in too." },
        { key = "inviteWhisper", label = "Whisper on Invite", toggle = true, needs = On, why = OFF,
          help = "Whispers a player you invite with the game's Group Invite button." },
        { key = "inviteMessage", label = "Invite Message", text = true, wide = true, needs = On, why = OFF,
          help = "Whispered with an invite; %dungeon% becomes the dungeons you listed." },
    },
})
