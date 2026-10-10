local file = assert(io.open("Core/Options/GameMenu.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
local first = assert(source:find("local function Added(menu)", 1, true))
local last = assert(source:find("local function PlaceAfterOptions", first, true))
local added, autoCursor = 0, false
local menu = { buttons = {} }
function menu:AddButton() error("GameMenuFrame:AddButton lists our button in menu.buttons") end
local env = {
 On = function() return true end,
 Label = function() return "Naowh Forever" end,
 Clicked = function() end,
 CanAutoSetGamePadCursorControl = function() return autoCursor end,
 MainMenuFrameMixin = { AddButton = function() added = added + 1 return {} end },
}
local chunk = assert(loadstring("local button\n" .. source:sub(first, last - 1) .. "return Added"))
setfenv(chunk, env)
local Added = chunk()
Added(menu)
assert(added == 1, "button must be added from the pool")
assert(#menu.buttons == 0, "button must stay out of menu.buttons")
autoCursor = true
Added(menu)
assert(added == 1, "button must be left out when the menu's OnHide will set the gamepad cursor")
print("3 game menu gamepad checks passed")
