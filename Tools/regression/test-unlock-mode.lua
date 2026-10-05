-- Run with Lua 5.1 from the repository root: Unlock Mode's placement controls, cut out of
-- Core/NaowhForever_Widgets.lua and run against frame stubs. No position box is drawn, and
-- selecting, nudging, dragging and combat still work and save.
local f = assert(io.open("Core/NaowhForever_Widgets.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local body = assert(source:match("\n(local placement = .-)\n%-%- Font dropdown data"), "placement section")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local made = { frames = {}, textures = 0, fonts = 0 }
local Frame = {}
Frame.__index = Frame
local function NewFrame(parent)
    local fr = setmetatable({ parent = parent, scripts = {}, hooks = {}, shown = true, points = {}, events = {} }, Frame)
    made.frames[#made.frames + 1] = fr
    return fr
end
local function Region()
    return setmetatable({}, { __index = function() return function() end end })
end
function Frame:CreateTexture() made.textures = made.textures + 1; self.drawn = true; return Region() end
function Frame:CreateFontString() made.fonts = made.fonts + 1; self.drawn = true; return Region() end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:HookScript(name, fn) self.hooks[name] = fn end
function Frame:Show() self.shown = true end
function Frame:Hide()
    local was = self.shown
    self.shown = false
    if was and self.hooks.OnHide then self.hooks.OnHide(self) end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(point, rel, relPoint, x, y)
    self.points[#self.points + 1] = { point, rel, relPoint, x or 0, y or 0 }
end
function Frame:SetAllPoints() self.points = { { "TOPLEFT", self.parent, "TOPLEFT", 0, 0 } } end
function Frame:GetPoint(i)
    local p = self.points[i]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:GetWidth() return self.w or 0 end
function Frame:GetHeight() return self.h or 0 end
-- Bounds from the first point, taken against UIParent (every frame here is placed on it).
local FRACTION = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 },
    CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local SCREEN_W, SCREEN_H = 1920, 1080
local function Bounds(self)
    local p = self.points[1]
    if not p or not FRACTION[p[1]] or not FRACTION[p[3]] then return 100, 200, 150, 220 end
    local w, h = self.w or 0, self.h or 0
    local ax = SCREEN_W * FRACTION[p[3]][1] + p[4]
    local ay = SCREEN_H * FRACTION[p[3]][2] + p[5]
    local left, bottom = ax - w * FRACTION[p[1]][1], ay - h * FRACTION[p[1]][2]
    return left, bottom, left + w, bottom + h
end
function Frame:GetLeft() return (Bounds(self)) end
function Frame:GetBottom() return select(2, Bounds(self)) end
function Frame:GetRight() return select(3, Bounds(self)) end
function Frame:GetTop() return select(4, Bounds(self)) end
function Frame:GetCenter()
    local l, b, r, t = Bounds(self)
    return (l + r) / 2, (b + t) / 2
end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetFrameLevel() return 1 end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:EnableKeyboard(v) self.keyboard = v end
function Frame:EnableMouse(v) self.mouse = v end
function Frame:SetPropagateKeyboardInput(v) self.propagate = v end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:IsProtected() return false end
for _, name in ipairs({ "SetFrameStrata", "SetFrameLevel", "RegisterForDrag" }) do
    Frame[name] = function() end
end

-- The right-click menu's radios and buttons by label, and the anchors and links picked.
local anchorDB, radios, buttons, printed = {}, {}, {}, {}
local function MenuEntry()
    return { CreateRadio = function(_, text, isSelected, set) radios[text] = { selected = isSelected, set = set } end }
end
local menuRoot = { CreateTitle = function() end,
    CreateButton = function(_, text, fn) buttons[text] = fn; return MenuEntry() end }
local UIParent = NewFrame()
UIParent.w, UIParent.h = SCREEN_W, SCREEN_H
local combat, shift = false, false
local env = setmetatable({
    UI = {}, T = { accent = {}, accentSoft = {} }, BLACK = {},
    ns = {
        UnlockModeSettings = { DB = function() return anchorDB end },
        Solid = function(parent) return parent:CreateTexture() end,
        Border = function(frame) return NewFrame(frame) end,
        Font = function(parent) return parent:CreateFontString() end,
        HideRaidReminderAnchorConfig = function() end,
        OpenOptionsWindow = function() end,
        Print = function(msg) printed[#printed + 1] = msg end,
    },
    UIParent = UIParent,
    CreateFrame = function(_, _, parent) return NewFrame(parent) end,
    InCombatLockdown = function() return combat end,
    IsShiftKeyDown = function() return shift end,
    GetCurrentKeyBoardFocus = function() return nil end,
    MenuUtil = { CreateContextMenu = function(_, build) build(nil, menuRoot) end },
}, { __index = _G })
local chunk = assert(loadstring(body))
setfenv(chunk, env)
chunk()
local UI = env.UI

Check(not source:find("placement.hud", 1, true), "the position box is gone from Widgets.lua")

local display = NewFrame(UIParent)
display:SetSize(100, 40)
display:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 1118, 117)
local saved = {}
local mover = UI.AttachMover(display, "Campfire", function(pos) saved[#saved + 1] = pos end, "QoL/General")
mover:Show()
local meter = NewFrame(UIParent)
meter:SetSize(200, 20)
meter:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
local meterSaved = {}
local meterMover = UI.AttachMover(meter, "Threat Meter", function(pos) meterSaved[#meterSaved + 1] = pos end)

local before = { frames = #made.frames, textures = made.textures, fonts = made.fonts }
UI.BeginMoverMode()
Check(made.fonts == before.fonts, "Unlock Mode draws no text of its own")
local keys
for i = before.frames + 1, #made.frames do
    if made.frames[i].scripts.OnKeyDown then keys = made.frames[i] end
end
Check(keys ~= nil, "a frame takes the arrow keys")
Check(not keys.drawn and not keys.mouse, "the key frame draws nothing and takes no clicks")
Check(keys.events.PLAYER_REGEN_DISABLED and keys.events.PLAYER_REGEN_ENABLED, "combat is still watched")

UI.SelectMover(mover)
Check(made.fonts == before.fonts, "selecting a display draws no text")
local outline
for i = before.frames + 1, #made.frames do
    local fr = made.frames[i]
    if fr ~= keys and fr.w and fr.w > 1 and fr.h and fr.h > 1 and fr.shown then outline = fr end
end
Check(outline ~= nil, "the outline still shows around the selected display")

keys.scripts.OnKeyDown(keys, "RIGHT")
local last = saved[#saved]
-- Low on the screen and between its thirds across: held to the bottom's middle, at its distance.
Check(last and last.point == "BOTTOM" and last.relPoint == "BOTTOM" and last.x == 209 and last.y == 97,
    "an arrow nudges by 1 and saves, held to the nearest part of the screen")
Check(keys.propagate == false, "a used arrow key is not passed on")
shift = true
keys.scripts.OnKeyDown(keys, "UP")
shift = false
last = saved[#saved]
Check(last.point == "BOTTOM" and last.x == 209 and last.y == 107, "Shift + arrow nudges by 10 and saves")

local count = #saved
mover.scripts.OnDragStart()
Check(display.moving, "dragging moves the display")
display:ClearAllPoints()
display:SetPoint("CENTER", UIParent, "CENTER", -40, 25)
mover.scripts.OnDragStop()
last = saved[#saved]
Check(#saved == count + 1 and last.point == "CENTER" and last.x == -40 and last.y == 25,
    "a drag saves where it was dropped; in the middle it stays held to the centre")

-- Anchor to Screen: a pick holds it where it is, nudges keep the pick, Automatic lets it go.
mover.scripts.OnMouseDown(mover, "RightButton")
Check(radios.Automatic and radios.Automatic.selected() and radios["Top Right"], "the menu offers the anchors")
radios["Top Right"].set()
last = saved[#saved]
Check(last.point == "TOPRIGHT" and last.relPoint == "TOPRIGHT" and last.x == -950 and last.y == -495,
    "Top Right holds it to that corner where it is")
Check(anchorDB.anchors.Campfire == "TOPRIGHT" and radios["Top Right"].selected(), "the pick is kept")
keys.scripts.OnKeyDown(keys, "RIGHT")
last = saved[#saved]
Check(last.point == "TOPRIGHT" and last.x == -949, "a nudge keeps the picked anchor")
radios.Automatic.set()
last = saved[#saved]
Check(last.point == "CENTER" and last.x == -39 and last.y == 25 and anchorDB.anchors.Campfire == nil,
    "Automatic goes back to the nearest")
Check(UI.AnchorAllMovers() == 1, "Anchor All holds every element shown")

-- Anchor to Element: Campfire above the Threat Meter follows it, keeps its gap, and lets go.
meterMover:Show()
mover.scripts.OnMouseDown(mover, "RightButton")
Check(buttons["Anchor to Element..."] and not buttons["Detach from Threat Meter"], "the menu offers Anchor to Element")
buttons["Anchor to Element..."]()
meterMover.scripts.OnMouseDown(meterMover, "LeftButton")
Check(buttons["Above it"] and buttons["Left of it"], "clicking the target offers the sides")
count = #saved
buttons["Above it"]()
local link = anchorDB.links.Campfire
Check(link and link.to == "Threat Meter" and link.side == "TOP" and link.x == -39 and link.y == 195,
    "the link keeps the gap from where it is")
Check(#saved == count, "linking does not move it")

UI.SelectMover(meterMover)
keys.scripts.OnKeyDown(keys, "RIGHT")
last = saved[#saved]
Check(meterSaved[#meterSaved].x == 1 and last.point == "CENTER" and last.x == -38 and last.y == 25,
    "a nudged target takes its linked element along, saved as its screen spot")
meter:SetSize(200, 60)
meter.hooks.OnSizeChanged(meter)
last = saved[#saved]
Check(last.x == -38 and last.y == 65, "a target that grows (upward, held to the bottom) pushes its linked element out")

meterMover.scripts.OnMouseDown(meterMover, "RightButton")
buttons["Anchor to Element..."]()
mover.scripts.OnMouseDown(mover, "LeftButton")
buttons["Below it"]()
Check(anchorDB.links["Threat Meter"] == nil and printed[#printed]:find("already follows"), "a loop is refused")

buttons["Above it"] = nil
mover.scripts.OnMouseDown(mover, "RightButton")
buttons["Anchor to Element..."]()
keys.scripts.OnKeyDown(keys, "ESCAPE")
meterMover.scripts.OnMouseDown(meterMover, "LeftButton")
Check(buttons["Above it"] == nil, "Esc cancels picking")

mover.scripts.OnMouseDown(mover, "RightButton")
buttons["Detach from Threat Meter"]()
Check(anchorDB.links.Campfire == nil, "Detach lets it go")
count = #saved
UI.SelectMover(meterMover)
keys.scripts.OnKeyDown(keys, "LEFT")
Check(#saved == count, "a detached element stays put")

combat = true
keys.scripts.OnEvent(keys, "PLAYER_REGEN_DISABLED")
Check(not keys:IsShown(), "the key frame stops in combat")
count = #saved
keys.scripts.OnKeyDown(keys, "LEFT")
Check(#saved == count, "no nudge in combat")
combat = false
keys.scripts.OnEvent(keys, "PLAYER_REGEN_ENABLED")
Check(keys:IsShown(), "Unlock Mode carries on after combat")
UI.SelectMover(mover)
count = #saved
keys.scripts.OnKeyDown(keys, "LEFT")
Check(#saved == count + 1, "nudges work again after combat")

UI.EndMoverMode()
Check(not keys:IsShown() and keys.keyboard == false, "leaving Unlock Mode stops the keys")
Check(made.fonts == before.fonts, "nothing in Unlock Mode drew text")

print(("test-unlock-mode: %d checks passed"):format(checks))
