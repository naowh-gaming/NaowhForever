-- A character's first login and the other character whose settings it is offered: Core's
-- SettingsRoot noting a new character, MarkSeen and ImportCandidate, on a stub saved table.
-- From the repo root: lua5.1 Tools/regression/test-import-candidate.lua
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local f = assert(io.open(arg[1] or "Core/Core.lua", "rb"))
local src = f:read("*a"):gsub("\r\n", "\n"); f:close()

local function Slice(a, b)
    local first = assert(src:find(a, 1, true))
    return src:sub(first, assert(src:find(b, first + #a, true)) - 1)
end

local code = assert(src:match("\n(local MODULE_KEY = .-\n)\nlocal ns = {}\n"), "Core constants")
    .. Slice("local function CharKey()", "local DEFAULTS = {")
    .. Slice("function ns.MarkSeen()", "function ns.ListProfiles()")

local function Login(sv, name, clock)
    local env = { ns = { STARTER = { profile = {}, account = {} } }, UNKNOWNOBJECT = "Unknown",
        UnitName = function() return name end, GetRealmName = function() return "Forever" end,
        time = function() return clock or 0 end }
    function env.CopyTable(t)
        local out = {}
        for k, v in pairs(t) do out[k] = v end
        return out
    end
    env._G = env
    env.NaowhForeverDB = sv
    setmetatable(env, { __index = _G })
    local chunk = assert(loadstring(code))
    setfenv(chunk, env)
    chunk()
    env.ns.SettingsRoot()
    return env.ns
end

do
    local sv = { profiles = { Default = {} }, charActive = {} }
    local ns = Login(sv, "Die Man")
    check("the account's first character is not offered anything", ns.ImportCandidate() == nil)
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, defaultProfile = "Default",
        charActive = { ["Die Man-Forever"] = "Raid", ["Die Pri-Forever"] = "Default" } }
    local ns = Login(sv, "Die Dudu", 300)
    local char, profile = ns.ImportCandidate()
    check("a new character lands on the account's profile", sv.charActive["Die Dudu-Forever"] == "Default")
    check("and is offered the character on another profile", char == "Die Man-Forever" and profile == "Raid")
    ns.MarkSeen()
    check("its login is noted", sv.charSeen["Die Dudu-Forever"] == 300)
    ns = Login(sv, "Die Dudu", 400)
    check("logging in again is not new: nothing offered", ns.ImportCandidate() == nil)
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Default" } }
    local ns = Login(sv, "Die Dudu")
    check("every other character on the same profile: nothing to offer", ns.ImportCandidate() == nil)
end

do
    local sv = { profiles = { Default = {}, Raid = {}, Alts = {} }, defaultProfile = "Default",
        charActive = { ["Ann-Forever"] = "Alts", ["Bob-Forever"] = "Raid", ["Cid-Forever"] = "Raid" },
        charSeen = { ["Ann-Forever"] = 500, ["Bob-Forever"] = 100 } }
    local ns = Login(sv, "Die Dudu")
    check("the character played most recently is offered", (ns.ImportCandidate()) == "Ann-Forever")
    sv.charSeen = nil
    sv.charActive["Die Dudu-Forever"] = nil
    ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("none noted: the profile most characters use", profile == "Raid" and char == "Bob-Forever")
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Gone" } }
    local ns = Login(sv, "Die Dudu")
    check("a profile since deleted is not offered", ns.ImportCandidate() == nil)
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, charActive = { ["Die Man-Forever"] = "Raid" } }
    local ns = Login(sv, "Unknown")
    check("before the game knows the name, nothing is noted or offered", ns.ImportCandidate() == nil
        and sv.charActive["Unknown-Forever"] == nil)
    ns.MarkSeen()
    check("and no login is noted under it", sv.charSeen == nil)
end

print(("test-import-candidate: %d checks passed"):format(checks))
