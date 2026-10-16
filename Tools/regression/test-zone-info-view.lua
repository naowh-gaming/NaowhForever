-- Zone Info drawing through the existing shared UI harness and real settings widgets.
local function Read(path)
    local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local harness = Read("Tools/regression/test-forever-skin.lua")
local head = assert(harness:match("^(.-)%-%- Naowh: nothing"))
head = head:gsub("C_AddOns = {", "C_Item = { GetItemInfo = function() end, GetItemIconByID = function() end }, C_AddOns = {", 1)
local Load, New = assert(loadstring(head .. "\nreturn Load, New"))()
local ns = Load({}, {}, {}, { "Core/Features.lua", "Core/Settings.lua", "Shared/Data/SameMaps.lua", "Shared/Game/Places.lua", "Shared/View/Kinds.lua", "Shared/Settings/Studio.lua",
    "NaowhForever_QoL/Interface/ZoneLevelsData.lua", "NaowhForever_QoL/Interface/FishingLevelsData.lua",
    "NaowhForever_QoL/Interface/ZoneInfo/Model.lua", "NaowhForever_QoL/Interface/ZoneInfo/View.lua",
    "NaowhForever_QoL/Interface/ZoneInfo/SettingsPage.lua" })
local settingsRoot = {}
ns.SettingsRoot = function() return settingsRoot end
local Z, S = ns.ZoneInfo, ns.QoLSettings
local env = getfenv(Z.MapInfo)
local canvas = New("Frame"); canvas:SetSize(700, 500)
local map = New("Frame")
local right, left = 1000, 10
function map:GetRight() return right end
function map:GetLeft() return left end
function env.UIParent:GetRight() return 1600 end
function map:GetCanvasContainer() return canvas end
function map:GetCanvas() return canvas end
canvas:SetFrameLevel(500)
env.WorldMapFrame = map
local info = { mapID = 1436, name = "Westfall", mapType = 3, parentMapID = 1415 }
env.C_Map = { GetMapInfo = function(id) return id == 1436 and info or nil end }
env.Enum = { UIMapType = { Zone = 3 } }
Z.level, Z.fishing, Z.current, Z.professionsKnown = 16, 75, 1436, true
local checks = 0
local function Check(ok, text) assert(ok, text); checks = checks + 1 end
function Z.Pin(id, detached) S.Set("zoneInfoPinned", id); Z.ShowDetails(detached) end
S.Set("zoneInfo", true)
S.Set("zoneInfoFishing", true)
S.Set("zoneInfoPinned", 1436)
Z.Hover(1436)
Z.Hover(nil)
Z.ShowDetails(false)
Z.PaintDetails()
Z.ShowDetails(true)
Z.HideMap()
Z.HideAll()
Check(true, "hover and pinned panels build and switch parents through shared parts")
local dungeon = { name = "The Deadmines", entrance = { map = 1436, x = 43.2, y = 72.4 } }
ns.Journal = { Settings = { Get = function() return true end },
    Dungeons = function() return { dungeon } end, LevelRange = function() return "17-26" end }
local opened, marked
ns.OpenJournalWindow = function(value) opened = value end
ns.PlaceWaypoint = function(title, id, x, y) marked = { title, id, x, y } end
S.Set("zoneInfoDungeons", true)
canvas:SetSize(230, 260)
right = 1372
Z.ShowDetails(false)
local pinned
for _, frame in ipairs(env.UIParent.children) do if frame.tabs and frame.view and frame.meta then pinned = frame end end
Check(pinned and pinned.w == 220 and pinned.h == 236, "pinned card fits available side space and map height")
Check(pinned.points[1][1] == "TOPLEFT" and pinned.points[1][2] == map and pinned.points[1][3] == "TOPRIGHT",
    "details dock outside the entire map and quest log")
right, left = 1590, 500
Z.ShowDetails(false)
Check(pinned.points[1][1] == "TOPRIGHT" and pinned.points[1][3] == "TOPLEFT", "no right-side room uses the outside left edge")
right, left = 1372, 10
Z.ShowDetails(false)
Check(pinned.strata == "DIALOG" and pinned.level > canvas:GetFrameLevel(), "panel is above the map canvas after reparenting")
local solid
for _, child in ipairs(pinned.children) do
    if child.kind == "Texture" and child.color and child.color[1] == ns.THEME.bg.r and child.color[4] == 1 then solid = child end
end
Check(solid ~= nil and pinned.backdrop == nil, "map details use an opaque theme fill rather than a window gradient")
Z.Hover(1436)
local summary
for _, frame in ipairs(env.UIParent.children) do if frame.pin then summary = frame end end
Check(summary and summary.points[1][2] == map and summary.points[1][3] == "TOPRIGHT", "compact summary also docks outside the map")
Check(pinned.points[1][5] < -summary.h, "pinned details stack below the summary without overlap")
Z.Hover(nil)
Check(pinned.points[1][5] == 0, "details reclaim the top when the compact summary hides")
local entryRow = pinned.view.pools.zoneEntry[1]
Check(entryRow.mark.points[1][3] < entryRow.journal.points[1][3], "narrow cards stack actions instead of overlapping")
entryRow.journal.scripts.OnClick(entryRow.journal)
entryRow.mark.scripts.OnClick(entryRow.mark)
Check(opened == dungeon and marked[2] == 1436 and marked[3] == 43.2, "real row buttons open the chosen dungeon and mark its entrance")
local hud = Z.NewHUD(canvas, true)
Z.PaintHUD(hud, 1436, true)
Check(hud.title.text == "Westfall" and hud.detail.text == "Fishing 75 / 75 reliable", "HUD paints map name and readiness")
local parent = New("Frame"); parent:SetWidth(900)
ns.Shared.Settings.Render(parent, "QoL/Map & Pins", function() end)
local page = ns.Shared.Settings.pages["QoL/Map & Pins"]
local card = page.items[1]
ns.Shared.Settings.SetOpen(card, true)
parent.settingsView:Redraw()
Check(parent.settingsView.pools.setting.used == 10, "real options page renders every setting")
local found
for i = 1, parent.settingsView.pools.setting.used do
    local row = parent.settingsView.pools.setting[i]
    if row.setting.label == "Recommended Details" then found = row end
end
Check(found ~= nil and found.controls.button ~= nil, "recommended action uses the real button widget")
found.controls.button.scripts.OnClick()
Check(S.Get("zoneInfoDungeons") and S.Get("zoneInfoFishing") and S.Get("zoneInfoTravel") and S.Get("zoneInfo"),
    "recommended button configures details through the store")
Check(not S.Get("zoneInfoCurrent") and not S.Get("zoneInfoGathering"), "recommended setup leaves optional HUD and gathering off")
print("test-zone-info-view: " .. checks .. " checks passed")
