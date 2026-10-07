-- Run with Lua 5.1 from the repository root: the Waypoint Pin against stubs of the game's
-- navigation. Off by default and idle while off; on, it follows the navigation frame with the
-- name ns.PlaceWaypoint gave the spot, moves to the screen's edge or the behind-you cue while
-- the spot is off screen, shows the arrival and clears a waypoint you set, and fades the game's
-- own marker only while it is on. These do not emulate rendering or the 3D projection.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local W, H = 1920, 1080
local NOOP = function() end
local made = {}
local Frame = {}
local FrameMeta = { __index = function(_, k)
    if Frame[k] then return Frame[k] end
    if type(k) == "string" and k:match("^%u") then return NOOP end
end }

local function NewFrame(kind, parent)
    local f = setmetatable({ kind = kind, parent = parent, scripts = {}, events = {}, shown = true, alpha = 1 }, FrameMeta)
    made[#made + 1] = f
    return f
end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:IsShown() return self.shown end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:SetScale(v) self.scale = v end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:SetRotation(r) self.rotation = r end
function Frame:CreateTexture() return NewFrame("Texture", self) end
function Frame:CreateFontString() return NewFrame("FontString", self) end

local UIParent = NewFrame("Frame")
function UIParent:GetWidth() return W end
function UIParent:GetHeight() return H end
function UIParent:GetCenter() return W / 2, H / 2 end

local settings = {}
local defaults = { enabled = true, waypoints = false, waypointShape = "hex", waypointScale = 1, waypointCard = true,
    waypointTime = true, waypointBeam = true, waypointFadeNear = 40, waypointEdge = true, waypointNav = true,
    waypointClear = true, waypointSound = "none", waypointHideGame = true }
local S = {}
function S.Get(k) if settings[k] ~= nil then return settings[k] end return defaults[k] end
function S.Set(k, v) settings[k] = v end

local nav = { frame = nil, valid = true, clamped = false, distance = 312, x = 1100, y = 700 }
local navFrame = NewFrame("NavFrame")
function navFrame:GetCenter() return nav.x, nav.y end
local userWaypoint, cleared, superCleared = nil, 0, 0
local timers, played, printed = {}, {}, {}
local speed = 0
local tracking = 1   -- Enum.SuperTrackingType.UserWaypoint

local gameMarker = {}
for _, key in ipairs({ "Icon", "Arrow", "DistanceText", "IconBorder" }) do gameMarker[key] = NewFrame("Texture") end

local function Theme() return { r = 0, g = 0.57, b = 0.93 } end
local ns = {
    QoLSettings = S,
    THEME = { accent = Theme(), accentSoft = Theme(), fg = Theme(), muted = Theme(), bg = Theme() },
    Font = function(parent) return parent:CreateFontString() end,
    Solid = function(parent) return parent:CreateTexture() end,
    Print = function(msg) printed[#printed + 1] = msg end,
    Apply = NOOP, ShowRaidReminderAnchorConfig = NOOP, HideRaidReminderAnchorConfig = NOOP,
    UI = {
        AttachMover = function(frame) return NewFrame("Mover", frame) end,
        _PlayLSMSound = function(path) if path then played[#played + 1] = path end end,
        SoundPathFor = function(key) if key ~= "none" then return "sound:" .. key end end,
    },
    Shared = {
        Style = { ROUND = "round" },
        Parts = {
            HudBackdrop = NOOP,
            HudText = function(fs) return fs end,
            IconButton = function(parent, onClick)
                local b = NewFrame("Button", parent)
                b.click = onClick
                return b
            end,
        },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    UIParent = UIParent,
    CreateFrame = function(kind, _, parent) return NewFrame(kind, parent) end,
    C_Navigation = {
        GetFrame = function() return nav.frame end,
        HasValidScreenPosition = function() return nav.valid end,
        WasClampedToScreen = function() return nav.clamped end,
        GetDistance = function() return nav.distance end,
    },
    C_SuperTrack = {
        GetHighestPrioritySuperTrackingType = function() return tracking end,
        GetSuperTrackedQuestID = function() return 7 end,
        ClearAllSuperTracked = function() superCleared = superCleared + 1 end,
    },
    C_Map = {
        GetUserWaypoint = function() return userWaypoint end,
        ClearUserWaypoint = function() userWaypoint = nil; cleared = cleared + 1 end,
        GetMapInfo = function() return { name = "Thunder Bluff" } end,
    },
    C_QuestLog = { GetTitleForQuestID = function() return "The Barrens Oases" end },
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end },
    Enum = { SuperTrackingType = { Quest = 0, UserWaypoint = 1, Corpse = 2 } },
    SuperTrackedFrame = gameMarker,
    GetUnitSpeed = function() return speed end,
    GetTime = function() return 0 end,
    BreakUpLargeNumbers = function(n)
        local s = tostring(n)
        while true do
            local k
            s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
            if k == 0 then return s end
        end
    end,
    hooksecurefunc = function(tbl, name, fn)
        local orig = tbl[name]
        tbl[name] = function(...)
            orig(...)
            fn(...)
        end
    end,
}, { __index = _G })
env._G = env
local f = assert(io.open("QoL/NaowhForever_Waypoints.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local chunk = assert(loadstring(source, "QoL/NaowhForever_Waypoints.lua"))
setfenv(chunk, env)
chunk()

local function Find(pred)
    for _, fr in ipairs(made) do
        if pred(fr) then return fr end
    end
end
local boot = Find(function(fr) return fr.events.PLAYER_LOGIN end)
boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
local events = Find(function(fr) return fr.scripts.OnEvent and fr ~= boot end)

-- Off by default: nothing listens and nothing is built.
Check(next(events.events) == nil, "off by default, no events")
Check(not Find(function(fr) return fr.card end), "and no pin built")
Check(gameMarker.Icon.alpha == 1, "and the game's marker untouched")

-- On with no waypoint: it listens, shows nothing, and fades the game's marker.
S.Set("waypoints", true)
Check(events.events.NAVIGATION_FRAME_CREATED and events.events.NAVIGATION_DESTINATION_REACHED, "on, it listens")
local pin = Find(function(fr) return fr.card end)
local navBar = Find(function(fr) return fr.mover end)
local driver = Find(function(fr) return fr.kind == "Frame" and fr.parent == nil and fr ~= UIParent and fr ~= boot
    and fr ~= events end)
Check(pin and not pin:IsShown() and not navBar:IsShown(), "with no waypoint nothing shows")
Check(gameMarker.Icon.alpha == 0 and gameMarker.DistanceText.alpha == 0, "the game's marker is faded")

-- A spot from ns.PlaceWaypoint: followed on the navigation frame, named as it was placed.
ns.placedWaypoint = { title = "Mage Trainer", map = 88, x = 46.2, y = 49.8 }
userWaypoint = { uiMapID = 88, position = { x = 0.462, y = 0.498 } }
nav.frame = navFrame
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
Check(pin:IsShown() and pin.point[2] == navFrame, "the pin sits on the navigation frame")
Check(pin.card.name.text == "Mage Trainer" and pin.card.dist.text == "312 yd", "named as placed, with its distance")
Check(pin.card.time.text == "about 0:45", "standing still, the walking time is at running pace")
speed = 14
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:22", "moving, at your own speed")
Check(navBar:IsShown() and navBar.name.text == "Mage Trainer" and navBar.sub.text == "Thunder Bluff",
    "the navigator names it and its zone")
Check(navBar.dist.text == "312 yd" and pin.scale < 1 and pin.scale > 0.65, "and shrinks the pin with distance")
nav.distance = 20
driver.scripts.OnUpdate(driver, 0)
Check(pin.alpha < 1 and pin.alpha >= 0.25, "it fades up close")
nav.distance = 1240
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.dist.text == "1,240 yd", "long distances read with a comma")

-- Off screen to the right: at the edge, the arrow pointing right, the card toward the middle.
nav.clamped, nav.x, nav.y = true, 2400, 540
driver.scripts.OnUpdate(driver, 0)
Check(pin.point[2] == UIParent and pin.point[4] == W / 2 - 70 and pin.point[5] == 0, "clamped right, it sits at the edge")
Check(pin.arrow.shown and pin.arrow.rotation == 0 and not pin.beam.shown, "with the arrow out and no line down")
Check(pin.card.point[1] == "RIGHT" and pin.card.point[3] == "LEFT", "the card on the screen's side of it")
S.Set("waypointScale", 1.5)
driver.scripts.OnUpdate(driver, 0)
Check(math.abs(pin.point[4] * pin.scale - (W / 2 - 70)) < 0.01, "a bigger pin still sits on the edge")
S.Set("waypointScale", nil)
-- Behind the camera (straight down): the behind-you cue instead.
nav.x, nav.y = 960, -900
driver.scripts.OnUpdate(driver, 0)
local cue = Find(function(fr) return fr.text and fr.arrow and not fr.card and not fr.mover end)
Check(not pin:IsShown() and cue:IsShown() and cue.text.text == "Behind you", "behind you, the cue shows instead")
S.Set("waypointEdge", false)
driver.scripts.OnUpdate(driver, 0)
Check(not cue:IsShown(), "and not with Edge Arrow off")
S.Set("waypointEdge", nil)
nav.clamped, nav.x, nav.y = false, 1100, 700
driver.scripts.OnUpdate(driver, 0)
Check(pin:IsShown() and pin.point[2] == navFrame, "back on screen, back on the navigation frame")

-- Arrival: shown, then a waypoint you set is cleared; a newer arrival keeps the older timer
-- from acting.
S.Set("waypointSound", "naowh")
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", true)
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.dist.text == "Arrived" and pin.check.shown and navBar.dist.text == "Arrived", "it shows the arrival")
Check(played[#played] == "sound:naowh", "with the arrival sound")
local first = timers[#timers]
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", true)
first.fn()
Check(cleared == 0, "an older arrival's timer does nothing")
timers[#timers].fn()
Check(cleared == 1 and userWaypoint == nil, "the waypoint you set is cleared")
events.scripts.OnEvent(events, "NAVIGATION_FRAME_DESTROYED")
Check(not pin:IsShown() and not navBar:IsShown() and driver.scripts.OnUpdate == nil, "gone with the frame, and idle")

-- A quest: named from the quest log; Clear on Arrival leaves it to the game.
tracking = 0
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
Check(pin.card.name.text == "The Barrens Oases", "a quest is named from the quest log")
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
timers[#timers].fn()
Check(cleared == 1, "a quest is not cleared")

-- The navigator's clear button clears the waypoint and the game's tracking.
navBar.clear.click()
Check(cleared == 2 and superCleared == 1, "the navigator clears the waypoint")

-- Off again: idle, and the game's marker back.
S.Set("waypoints", false)
Check(next(events.events) == nil and not pin:IsShown() and driver.scripts.OnUpdate == nil, "off, it stops listening")
Check(gameMarker.Icon.alpha == 1 and gameMarker.IconBorder.alpha == 1, "and the game's marker is back")
Check(#printed == 0, "nothing printed")

print(("test-waypoints: %d checks passed"):format(checks))
