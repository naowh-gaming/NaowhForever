-- Run with Lua 5.1 from the repository root: the Group Finder's window and Browse rows, loaded from the files
-- Shared.xml and GroupFinder.xml load, against stubs and a stubbed ns.GroupFinder whose listings, cards and
-- search are shaped as the module's contract says. Checks that it builds and listens to nothing until opened;
-- opening turns it on; the note before a search, while searching, after a failure and in chat lockdown; the
-- rows, your own listing first then newest first, with the dungeon, its levels, the leader in their class color,
-- the role slots of a group, a solo player's roles and a raid's count; the leader's card (score, kills, quests)
-- and the wait for it; a delisted listing faded; a card's arrival redrawing on pooled rows; Search; turning it
-- off closing the window; and the settings page's window card.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local Frame
local made = 0
local function Run(f, script)
    local fn = f.scripts[script]
    if fn then fn(f) end
    fn = f.hooks[script]
    if fn then fn(f) end
end
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.hooks[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    GetParent = function(f) return rawget(f, "parent") end,
    IsForbidden = function() return false end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 600 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    SetTexture = function(f, texture) f.texture = texture end,
    SetAtlas = function(f, atlas) f.atlas = atlas end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    SetScale = function(f, scale) f.scale = scale end,
    SetColorTexture = function(f, r, g, b) f.red, f.green, f.blue = r, g, b end,
    Show = function(f)
        local was = rawget(f, "shown") ~= false
        f.shown = true
        if not was then Run(f, "OnShow") end
    end,
    Hide = function(f)
        local was = rawget(f, "shown") ~= false
        f.shown = false
        if was then Run(f, "OnHide") end
    end,
    SetShown = function(f, shown)
        if shown then f:Show() else f:Hide() end
    end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    GetEffectiveScale = function() return 1 end,
    GetFrameLevel = function() return 1 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    made = made + 1
    return setmetatable({ scripts = {}, hooks = {}, events = {}, parent = parent }, META)
end

local WHITE = { r = 1, g = 1, b = 1 }
local MAGE = { r = 0.25, g = 0.78, b = 0.92 }
local timers, printed = {}, {}
local function Flush()
    local n = #timers
    for i = 1, n do timers[i]() end
    for i = n, 1, -1 do table.remove(timers, i) end
end

local values, listeners = { enabled = false }, {}
local S = {
    Get = function(key) return values[key] end,
    Set = function(key, value)
        values[key] = value
        for i = 1, #listeners do listeners[i](key, value) end
    end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
    Default = function() return false end,
}

-------------------------------------------------------------------------------
--  The module's rules, as their contract shapes them
-------------------------------------------------------------------------------
local TANK, HEALER, DAMAGE = 4, 2, 1
local ACTIVITY = {
    [1] = { name = "The Deadmines", short = "DM", min = 17, max = 26, size = 5 },
    [2] = { name = "Shadowfang Keep", short = "SFK", min = 22, max = 30, size = 5 },
    [3] = { name = "Molten Core", short = "MC", min = 0, max = 0, size = 40 },
}
local function Member(name, class, level, roles, leader)
    return { name = name, class = class, level = level, roles = roles, leader = leader }
end
local ENTRIES = {
    { id = 11, leader = "Korvath", activity = 2, dungeon = "ShadowfangKeep", numMembers = 3, age = 600, delisted = false,
        mine = false, tanks = 1, healers = 0, damage = 2, nMembers = 3,
        members = { Member("Korvath", "WARRIOR", 25, TANK, true), Member("Magi", "MAGE", 24, DAMAGE),
            Member("Kilt", "MAGE", 24, DAMAGE) } },
    { id = 12, leader = "Nessa", activity = 1, dungeon = "Deadmines", numMembers = 1, age = 30, delisted = false,
        mine = false, tanks = 0, healers = 0, damage = 0, nMembers = 1,
        members = { Member("Nessa", "PRIEST", 19, HEALER + DAMAGE, true) } },
    { id = 13, leader = "Die Man", activity = 1, dungeon = "Deadmines", numMembers = 2, age = 900, delisted = false,
        mine = true, tanks = 0, healers = 1, damage = 1, nMembers = 2,
        members = { Member("Die Man", "MAGE", 20, DAMAGE, true), Member("Pal", "PALADIN", 20, HEALER) } },
    { id = 14, leader = "Raider", activity = 3, numMembers = 12, age = 120, delisted = true, mine = false,
        tanks = 2, healers = 3, damage = 7, nMembers = 5,
        members = { Member("Raider", "MAGE", 60, DAMAGE, true) } },
}
local cards = {
    Korvath = { score = 239, level = 25, dungeon = "ShadowfangKeep", hasKills = true, nKills = 3, kills = { 2, 0, 1 },
        hasQuests = true, nHave = 2 },
}
local mine = { score = 189, level = 20, dungeon = "Deadmines", hasKills = true, nKills = 2, kills = { 0, 0 },
    hasQuests = false, nHave = 0 }
local waitingFor = { Nessa = true }

local GF = { Settings = S, PAGE = "Group Finder/Settings", fns = {}, asks = 0, runs = 0 }
function GF.On() return S.Get("enabled") == true end
function GF.Listen(what, fn)
    GF.fns[what] = GF.fns[what] or {}
    table.insert(GF.fns[what], fn)
end
function GF.Fire(what, a)
    for _, fn in ipairs(GF.fns[what] or {}) do fn(a) end
end
GF.Card = { TANK = TANK, HEALER = HEALER, DAMAGE = DAMAGE, Mine = function() return mine end }
GF.Comms = { IsMe = function(name) return name == "Die Man" end }
GF.Listings = { entries = {}, n = 0, state = "none", searched = false }
function GF.Listings.Read()
    local L = GF.Listings
    if L.state == "locked" then return 0 end
    if L.searched and L.state ~= "failed" then
        for i, entry in ipairs(ENTRIES) do L.entries[i] = entry end
        L.n, L.state = #ENTRIES, "ready"
    end
    return L.n
end
function GF.Listings.Activity(id) return ACTIVITY[id] end
GF.Browse = {
    Ask = function() GF.asks = GF.asks + 1 end,
    CardOf = function(leader) return cards[leader], waitingFor[leader] == true end,
}
GF.Search = { state = "idle", Run = function()
    GF.runs = GF.runs + 1
    GF.Search.state = "searching"
    return true
end }

local tooltip = Frame()
tooltip.SetOwner, tooltip.SetText, tooltip.AddLine = NOTHING, NOTHING, NOTHING
local ns
ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    MEDIA = dofile("Tools/regression/core_media.lua"),
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    GroupFinder = GF,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Hairline = function(region) return region end,
    PixelInset = function(region) return region end,
    AllowOffscreen = NOTHING,
    Border = function(parent)
        local edge = Frame(parent)
        edge.SetColor = NOTHING
        edge._frame = edge
        return edge
    end,
    Button = function(parent, text, _, _, onClick)
        local button = Frame(parent)
        button.label, button.onClick = text, onClick
        return button
    end,
    AccentBorder = function(frame) return frame end,
    SetButtonText = NOTHING,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    AccountSettings = function() return {} end,
    Print = function(text) printed[#printed + 1] = text end,
    Apply = NOTHING,
    UI = {
        SlimScroll = function(parent) return Frame(parent) end,
        CloseOnEscape = NOTHING,
        CONTENT_PAD = 20,
    },
    NaowhScore = { Colored = function(score, level) return ("score %.1f at %d"):format(score, level) end },
}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent) return Frame(parent) end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    hooksecurefunc = function(t, name, fn)
        local original = t[name]
        t[name] = function(...) original(...); fn(...) end
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function() return false end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Item = {
        GetItemIconByID = function(id) return 130000 + id end,
        GetItemQualityByID = function() return 4 end,
        GetItemNameByID = function(id) return "Item " .. id end,
        GetItemInfoInstant = NOTHING,
        GetItemCount = function() return 0 end,
        IsItemDataCachedByID = function() return true end,
    },
    ITEM_QUALITY_COLORS = { [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } },
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    MenuUtil = { CreateContextMenu = NOTHING },
    IsMouseButtonDown = function() return false end,
    C_CurrencyInfo = { GetCoinTextureString = function(copper) return tostring(copper) end },
    C_PaperDollInfo = { GetInventorySlotInfoForInvSlot = function(slot) return slot, "empty:" .. slot, false end },
    RAID_CLASS_COLORS = { MAGE = MAGE },
    CLASS_ICON_TCOORDS = setmetatable({}, { __index = function(t, class)
        t[class] = { 0, 0.25, 0, 0.25 }
        return t[class]
    end }),
    GameTooltip = tooltip,
    GameTooltip_Hide = NOTHING,
    InCombatLockdown = function() return false end,
    CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, SetRGBA = NOTHING } end,
    UIParent = Frame(),
}, { __index = _G })
env._G = env

-------------------------------------------------------------------------------
--  Loading: nothing made, nothing listened to
-------------------------------------------------------------------------------
Load(TocFiles("^Shared/.*%.lua$"), env)
local shared = made
for _, path in ipairs(TocFiles("^NaowhForever_Utilities/GroupFinder/.*%.lua$")) do
    if path:find("/View/") or path:find("/UI/") then Load({ path }, env) end
end
local UI = GF.UI
local function Listened()
    local n = 0
    for _, list in pairs(GF.fns) do n = n + #list end
    return n
end
check("nothing made at load, nothing listened to, no timer", made == shared and Listened() == 0 and #timers == 0)
check("the window's opener and toggle are there", type(ns.OpenGroupFinder) == "function"
    and type(ns.ToggleGroupFinder) == "function" and UI.Window() == nil)

local page = ns.Shared.Settings.pages["Group Finder/Settings"]
local banner = page and page.items[1]
check("its settings page opens with Open Group Finder, then Your Card", banner and banner.window
    and banner.text == "Open Group Finder" and page.items[2] == page.cards.card)

-------------------------------------------------------------------------------
--  Opening: turns it on, then the note before a search
-------------------------------------------------------------------------------
ns.OpenGroupFinder()
local window = UI.Window()
local view = window.view
check("opening turns it on and says so", values.enabled == true and printed[1]:find("turned on", 1, true))
check("the window is shown, titled, with its Search button", window:IsShown() and window.title.text == "Looking For Group"
    and window.search ~= nil)
check("it listens once opened", Listened() > 0)

local function Note()
    local note = view:Find("note", function() return true end)
    return note and note.text and note.text.text
end

local function Listing(id)
    return view:Find("listing", function(row) return row.id == id end)
end

check("before a search: a note to search, no rows, no count", Note() and Note():find("Search", 1, true)
    and Listing(11) == nil and window.subtitle.text == "")
check("the leaders were asked on the draw", GF.asks == 1)

window.search.scripts.OnClick(window.search)
Flush()
check("Search runs a search", GF.runs == 1)
check("and says it is searching", Note() == "Searching...")

GF.Listings.searched = true
GF.Search.state = "done"
GF.Fire("listings", false)
Flush()
check("results: four rows and the count", Listing(11) and Listing(12) and Listing(13) and Listing(14)
    and window.subtitle.text == "4 groups" and Note() == nil)
check("your own listing first, then newest first", Listing(13).index == 1 and Listing(12).index == 2
    and Listing(14).index == 3 and Listing(11).index == 4)

local group = Listing(11)
check("a listing's dungeon and its levels", group.title.text == "Shadowfang Keep" and group.range.text == "22-30")
check("its leader and level", group.leader.text == "Korvath" and group.level.text == "25")
local mage = Listing(13)
check("the leader in their class color, on the band too", mage.leader.r == MAGE.r and mage.band.red == MAGE.r)
check("a group's spots: its roles, then empty", group.slots[1].atlas == UI.Style.ROLE_ATLAS.TANK
    and group.slots[2].atlas == UI.Style.ROLE_ATLAS.DAMAGER and group.slots[3].atlas == UI.Style.ROLE_ATLAS.DAMAGER
    and group.slots[4].atlas == UI.Style.EMPTY_SLOT and group.slots[5].atlas == UI.Style.EMPTY_SLOT
    and group.slots[5]:IsShown())
local solo = Listing(12)
check("a solo player's roles, and no empty spots", solo.slots[1].atlas == UI.Style.ROLE_ATLAS.HEALER
    and solo.slots[2].atlas == UI.Style.ROLE_ATLAS.DAMAGER and not solo.slots[3]:IsShown())
local raid = Listing(14)
check("a raid's size as a count", raid.size:IsShown() and raid.size.text == "12/40" and not raid.slots[1]:IsShown()
    and raid.range.text == "")
check("a delisted listing is faded", raid.alpha == UI.Style.DELISTED_ALPHA and group.alpha == 1)
check("the leader's card: score, kills and quests", group.score.text == "score 23.9 at 25"
    and group.kills.text == "3 boss kills" and group.quests.text == "2 quests")
check("a leader waited on shows it", solo.score.text == "..." and solo.kills.text == "")
check("no card and none coming: nothing", raid.score.text == "")
check("your own card on your own listing", mage.score.text == "score 18.9 at 20" and mage.kills.text == "First time"
    and mage.quests.text == "")
check("how long ago each was listed", solo.age.text == "just now" and group.age.text == "10m ago")

local before = made
cards.Nessa = { score = 211, level = 19, dungeon = "Deadmines", hasKills = false, nKills = 0, kills = {},
    hasQuests = true, nHave = 0 }
waitingFor.Nessa = nil
GF.Fire("card")
Flush()
check("a card arriving redraws its row", Listing(12).score.text == "score 21.1 at 19")
check("on the same rows: nothing made", made == before)
cards.Nessa.dungeon = "ShadowfangKeep"
view:Redraw()
check("a card for another dungeon shows only the score", Listing(12).kills.text == "" and Listing(12).quests.text == ""
    and Listing(12).score.text == "score 21.1 at 19")

GF.Search.state = "failed"
GF.Fire("search", "failed")
Flush()
check("a failed search says so, and shows no rows", Note():find("failed", 1, true) and Listing(11) == nil)
GF.Search.state = "unavailable"
view:Redraw()
check("nothing to search at your level says so", Note():find("nothing to search", 1, true))
GF.Search.state = "done"
GF.Listings.state = "locked"
view:Redraw()
check("chat lockdown says listings cannot be read", Note():find("encounter", 1, true) and Listing(11) == nil)
GF.Listings.state = "ready"
view:Redraw()

S.Set("enabled", false)
check("turning it off closes the window", not window:IsShown())
ns.ToggleGroupFinder()
check("the toggle opens it again, turning it on", window:IsShown() and values.enabled == true)
ns.ToggleGroupFinder()
check("and closes it", not window:IsShown())

print(("test-group-finder-ui: %d checks passed"):format(checks))
