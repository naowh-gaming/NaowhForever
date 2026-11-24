-- Run with Lua 5.1 from the repository root: the profession window reopens where it was left.
-- Each of your professions keeps its own selected recipe and scroll; a linked profession starts at the top.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local source = Read("NaowhForever_Professions/UI/Window.lua")
local first = assert(source:find("function Window.SwapPlace(key, fresh)", 1, true))
local last = assert(source:find("\nend\n", first, true))
local chunk = "local Window = {}\n" .. source:sub(first, last + 4) .. "return Window.SwapPlace"

local W = { offset = 0 }
local env = { W = W, places = {}, EMPTY = {} }
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local SwapPlace = fn()

local TAILORING, COOKING = 197, 185

SwapPlace(TAILORING)
check("a profession opened for the first time starts at the top", W.offset == 0 and W.selectedID == nil)
W.selectedID, W.offset = 3914, 40

SwapPlace(TAILORING)
check("reopening the same profession keeps the recipe and scroll", W.selectedID == 3914 and W.offset == 40)

SwapPlace(COOKING)
check("another profession starts at its own place", W.selectedID == nil and W.offset == 0)
W.selectedID, W.selectedUnlearned, W.offset = nil, "unlearned", 12

SwapPlace(TAILORING)
check("going back to the first profession finds its place", W.selectedID == 3914 and W.offset == 40)
check("and does not carry the other's unlearned pick", W.selectedUnlearned == nil)

SwapPlace(false, true)
check("a linked profession opens at the top", W.selectedID == nil and W.offset == 0)
W.selectedID, W.offset = 2000, 8

SwapPlace(false, true)
check("and so does the next link", W.selectedID == nil and W.offset == 0)

SwapPlace(COOKING)
check("back on your own window each profession is still where it was",
    W.selectedUnlearned == "unlearned" and W.offset == 12)

print(checks .. " profession keeps place checks passed")
