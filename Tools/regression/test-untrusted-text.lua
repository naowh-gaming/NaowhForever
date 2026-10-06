-- Run with Lua 5.1 from the repository root: text from other players and shared strings is shown
-- as plain text. ns.PlainText (Core) on crafted names, and a crafted Reminder Pack's preview
-- (Core/NaowhForever_Packs.lua, through the real LibSerialize and LibDeflate).
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")

local PlainText = dofile("Tools/regression/plain_text.lua")()

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local BADGE = "|TInterface\\AddOns\\NaowhForever\\Media\\Badges\\BadgeNaowhChat.tga:0:0:0:-1|t"

local function Live(text)
    return (text:gsub("||", "")):find("|", 1, true) ~= nil or text:find("%c") ~= nil
end

Case("escapes in a name are shown, never drawn", function()
    for _, raw in ipairs({ BADGE .. " Naowh", "|cffe6cc80Naowh Forever:|r hi", "|Hitem:19019|h[Thunderfury]|h",
        "|Kq1|k", "|A:raidicon:16:16|a", "a|nb", "line\nbreak", "tab\there", "end|", "|", "x\0y" }) do
        local out = PlainText(raw)
        assert(not Live(out), out)
    end
    assert(PlainText(BADGE):find("||T", 1, true) == 1, "the texture code reads as text")
end)

Case("plain names, format codes and escaped pipes are left as they are", function()
    for _, raw in ipairs({ "Die Man", "Naowh's Pack (2026)", "%s%d%n%%", "a||b", "" }) do
        assert(PlainText(raw) == raw, raw)
    end
    assert(PlainText(PlainText(BADGE)) == PlainText(BADGE), "cleaning twice changes nothing more")
    assert(("Imported %s."):format(PlainText("%s%d")) == "Imported %s%d.", "a name with %s is an argument")
end)

Case("anything but a string is nil, and a cap cuts", function()
    assert(PlainText(nil) == nil and PlainText(42) == nil and PlainText({}) == nil)
    assert(#PlainText(("x"):rep(500), 100) == 100)
end)

Case("4000 letters of colour codes clean quickly", function()
    local long = ("|cffff0000x|r"):rep(400)
    assert(#long >= 4000)
    local started = os.clock()
    local out
    for _ = 1, 200 do out = PlainText(long) end
    assert(not Live(out) and os.clock() - started < 1, "slow: " .. (os.clock() - started))
end)

local function Packs()
    local ns = { PlainText = PlainText,
        Color = function(_, text) return "|cff0091ed" .. (text and (text .. "|r") or "") end }
    local env = setmetatable({ _G = { NaowhForever = ns }, LibStub = LibStub }, { __index = _G })
    local f = assert(io.open("Core/NaowhForever_Packs.lua", "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
    local chunk = assert(loadstring(source, "Packs")); setfenv(chunk, env); chunk()
    return ns
end

local function PackString(payload)
    local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")
    return "NSRPACK2:" .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(payload)))
end

local function Stray(desc)
    local rest = desc:gsub("||", ""):gsub("|cff0091ed", ""):gsub("|cffF0A830", ""):gsub("|r", ""):gsub("|n", " ")
    return rest:find("|", 1, true) ~= nil or rest:find("%c") ~= nil
end

Case("a crafted pack's name, author, date and maker show as plain text", function()
    local ns = Packs()
    local payload, desc = ns.DecodePack(PackString({ format = 1,
        name = BADGE .. " |cffe6cc80Official Naowh Pack|r",
        author = "Naowh " .. BADGE .. "\nVerified by the Naowh Forever team",
        made = "%s%d%n", derivedFrom = { name = "|Hitem:1|h[x]|h", author = ("|cffff0000x|r"):rep(400) },
        data = { callouts = { a = "Taunt" } } }))
    assert(payload, desc)
    assert(not Stray(desc), desc)
    assert(desc:find("||TInterface", 1, true) and desc:find("(%s%d%n)", 1, true), desc)
    assert(not payload.author:find("\n", 1, true) and #payload.derivedFrom.author <= 200)
end)

Case("a crafted pack's profile names show as plain text in its preview", function()
    local ns = Packs()
    local fake = "|cffff0000Naowh|r " .. BADGE
    local payload, desc = ns.DecodePack(PackString({ format = 1, name = "Pack", author = "Me",
        profiles = { [fake] = { callouts = { a = "Taunt" } } } }))
    assert(payload, desc)
    assert(not Stray(desc), desc)
    local text = ns.DescribeProfilePack(PackString({ format = 1, name = "Pack", author = "Me",
        profiles = { [fake] = { callouts = { a = "Taunt" } } } }))
    assert(text and not Stray(text), text)
    assert(payload.profiles[fake], "the profile itself keeps its key")
end)

Case("a plain pack reads as before", function()
    local ns = Packs()
    local payload, desc = ns.DecodePack(PackString({ format = 1, name = "Naowh", author = "Naowh",
        made = "2026-10-06", data = { callouts = { a = "Taunt" } } }))
    assert(payload.name == "Naowh" and payload.author == "Naowh" and payload.made == "2026-10-06")
    assert(desc == "|cff0091edNaowh|r by Naowh (2026-10-06)|n1 callout lines", desc)
end)

print(count .. " untrusted text regressions passed")
