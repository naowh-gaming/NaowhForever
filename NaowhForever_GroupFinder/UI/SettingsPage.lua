-------------------------------------------------------------------------------
--  UI/SettingsPage.lua -- the Group Finder's settings page (Group Finder/Settings): what your
--  card shares with the Naowh Forever players you ask or apply to.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local GF = ns.GroupFinder
local S = GF.Settings

S.OnChange(function(key)
    if key == "enabled" then ns.UI:RefreshPage(true) end
end)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local OFF = "Turn on the Group Finder"
local SHARED = { "shareScore", "shareKills", "shareQuests", "shareBis" }

local function On()
    return GF.On()
end

local function Summary(store)
    local count = 0
    for _, key in ipairs(SHARED) do
        if store.Get(key) then count = count + 1 end
    end
    if count == 0 then return "Class, level and roles only" end
    return ("Shares %d of %d"):format(count, #SHARED)
end

local page = Settings.Page("Group Finder/Settings", S)

page:Card({
    id = "card", name = "Your Card", order = 10,
    help = "What Naowh Forever players see about you when you ask or apply to their group.",
    summary = Summary,
    rows = {
        { key = "shareScore", label = "Naowh Score", toggle = true, needs = On, why = OFF,
          help = "Shows your Naowh Score on your card." },
        { key = "shareKills", label = "Boss Kills", toggle = true, needs = On, why = OFF,
          help = "Shows how often you have killed each boss of the dungeon." },
        { key = "shareQuests", label = "Dungeon Quests", toggle = true, needs = On, why = OFF,
          help = "Shows the dungeon's quests you have or still need." },
        { key = "shareBis", label = "BiS Progress", toggle = true, needs = On, why = OFF,
          help = "Shows how many of your BiS items you already have." },
    },
})
