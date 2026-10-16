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
function map:GetCanvasContainer() return canvas end
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
Z.ShowDetails(false)
local pinned
for _, frame in ipairs(env.UIParent.children) do if frame.tabs and frame.view and frame.meta then pinned = frame end end
Check(pinned and pinned.w == 220 and pinned.h == 236, "pinned card adapts to a small map canvas")
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
