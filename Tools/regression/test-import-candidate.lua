-- A character's first login and the main it is asked about: Core's SettingsRoot noting a new
-- character (saved in charAsk, so a reload or relog asks again), MarkSeen, MarkAsked and
-- ImportCandidate (the other character played most recently, on any profile), on a stub saved table.
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
    .. Slice("local function CharKey()", "function ns.DB()")
    .. Slice("function ns.MarkSeen()", "function ns.ListProfiles()")

local function Login(sv, name, clock, guid, surname, realm)
    local env = { ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, STARTER = { profile = {}, account = {} } }, UNKNOWNOBJECT = "Unknown",
        UnitName = function() return name end, GetRealmName = function() return realm or "Forever" end,
        UnitFullName = function() return name, surname end,
        UnitGUID = function() return guid end, time = function() return clock or 0 end }
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
    check("and it waits for an answer, saved by character", sv.charAsk["Die Dudu-Forever"] == true
        and sv.charAsk["Die Man-Forever"] == nil)
    ns = Login(sv, "Die Dudu", 400)
    char, profile = ns.ImportCandidate()
    check("a reload or relog with no answer: offered again", char == "Die Man-Forever" and profile == "Raid")
    Login(sv, "Die Man", 450).MarkAsked()
    check("another character's close leaves this one waiting", sv.charAsk["Die Dudu-Forever"] == true)
    ns.MarkAsked()
    check("answered: the wait is cleared", sv.charAsk == nil)
    check("and nothing is offered after, this session", ns.ImportCandidate() == nil)
    ns = Login(sv, "Die Dudu", 500)
    check("logging in again is not new: nothing offered", ns.ImportCandidate() == nil)
    ns.MarkAsked()
    check("a close with nothing waiting changes nothing", sv.charAsk == nil)
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Default" } }
    local ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("the main on the same profile is still the main: asked, with its profile", char == "Die Man-Forever"
        and profile == "Default" and sv.charActive["Die Dudu-Forever"] == "Default")
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, defaultProfile = "Default",
        charActive = { ["Ann-Forever"] = "Default", ["Bob-Forever"] = "Raid" },
        charSeen = { ["Ann-Forever"] = 500, ["Bob-Forever"] = 100 } }
    local ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("the character played most recently, even on this character's profile", char == "Ann-Forever"
        and profile == "Default")
    sv.charSeen["Bob-Forever"] = 900
    check("and it follows who was played last", (ns.ImportCandidate()) == "Bob-Forever")
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, defaultProfile = "Default",
        charActive = { ["Ann-Forever"] = "Raid", ["Bob-Forever"] = "Default" } }
    local ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("this character landing on a profile does not count for it: a tie, by name", char == "Ann-Forever"
        and profile == "Raid")
    sv.charActive["Cid-Forever"] = "Default"
    check("two others on one profile: their profile wins", (ns.ImportCandidate()) == "Bob-Forever")
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
    ns.MarkAsked()
    check("nor any answer", sv.charAsk == nil)
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Default" } }
    Login(sv, "Die Dudu")
    Login(sv, "Die Pri")
    Login(sv, "Die Pri").MarkAsked()
    check("two new characters wait on their own: one answered leaves the other", sv.charAsk["Die Dudu-Forever"] == true
        and sv.charAsk["Die Pri-Forever"] == nil and (Login(sv, "Die Dudu").ImportCandidate()) ~= nil)
end

local MAIN_GUID, PRI_GUID, DUDU_GUID = "Player-4613-006EB819", "Player-4613-006EC000", "Player-4613-006ED000"

do
    local sv = { profiles = { Default = {} }, charActive = {} }
    Login(sv, "Die Man", 100, MAIN_GUID).MarkSeen()
    check("each login saves the character's GUID", sv.charGuid["Die Man-Forever"] == MAIN_GUID)
    Login(sv, "Die Pri", 200).MarkSeen()
    check("a GUID the game does not give yet is not saved", sv.charGuid["Die Pri-Forever"] == nil
        and sv.charSeen["Die Pri-Forever"] == 200)
    Login(sv, "Unknown", 300, PRI_GUID).MarkSeen()
    check("nor one before the game knows the name", sv.charGuid["Unknown-Forever"] == nil)
end

local function Account()
    return { profiles = { Default = {}, Raid = {}, Alts = {} }, defaultProfile = "Default",
        charActive = { ["Die Man-Forever"] = "Raid", ["Die Pri-Forever"] = "Alts" },
        charSeen = { ["Die Man-Forever"] = 100, ["Die Pri-Forever"] = 900 },
        charGuid = { ["Die Man-Forever"] = MAIN_GUID, ["Die Pri-Forever"] = PRI_GUID } }
end

do
    local sv = Account()
    local char, profile = Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()
    check("the first character made wins over the one played most recently", char == "Die Man-Forever"
        and profile == "Raid")
end

do
    local sv = Account()
    sv.charGuid["Die Man-Forever"], sv.charGuid["Die Pri-Forever"] = "Player-4613-100", "Player-4613-FF"
    check("the counter is read as a number, not as text", (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate())
        == "Die Pri-Forever")
end

do
    local sv = Account()
    sv.charActive["Far Away-Forever"], sv.charGuid["Far Away-Forever"] = "Default", "Player-4614-00000001"
    sv.charSeen["Far Away-Forever"] = 2000
    check("another server's characters are left out of the first-made rule",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Man-Forever")
    sv = Account()
    sv.charGuid = { ["Far Away-Forever"] = "Player-4614-00000001" }
    sv.charActive["Far Away-Forever"], sv.charSeen["Far Away-Forever"] = "Default", 50
    check("none known on this server: the one played most recently, as before",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
end

do
    local sv = Account()
    sv.charGuid = nil
    check("no GUIDs known: the one played most recently",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
    sv = Account()
    check("this character's own GUID not known yet: the one played most recently",
        (Login(sv, "Die Dudu", 1000).ImportCandidate()) == "Die Pri-Forever")
end

do
    local sv = Account()
    sv.charGuid["Die Man-Forever"] = "Player-4613-zz"
    sv.charGuid["Die Pri-Forever"] = 42
    sv.charActive["Odd-Forever"], sv.charGuid["Odd-Forever"] = "Default", "Creature-0-4613-0-1-1-0000000001"
    sv.charActive["Odder-Forever"], sv.charGuid["Odder-Forever"] = "Default", "Player-4613-"
    check("malformed GUIDs are left out: the one played most recently",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
    sv.charGuid["Die Man-Forever"] = MAIN_GUID
    check("while a sound one still wins", (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate())
        == "Die Man-Forever")
end

do
    local sv = Account()
    sv.charActive["Unknown-Forever"], sv.charGuid["Unknown-Forever"] = "Default", "Player-4613-00000001"
    sv.charSeen["Unknown-Forever"] = 5000
    check("a provisional Unknown- key is never picked by GUID",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Man-Forever")
    sv.charGuid = nil
    check("nor by when it was played", (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
    sv = { profiles = { Default = {} }, charActive = { ["Unknown-Forever"] = "Default" },
        charGuid = { ["Unknown-Forever"] = "Player-4613-00000001" } }
    check("an Unknown- key alone: nothing offered", Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate() == nil)
end

do
    local sv = Account()
    sv.charGuid["Die Dudu-Forever"] = "Player-4613-00000001"
    check("never this character itself, even with the lowest counter",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Man-Forever")
    sv.charAsk = nil
    check("and only while it waits for an answer", Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate() == nil)
end

local TAPS_GUID, SLAMS_GUID = "Player-4613-00000010", "Player-4613-00000020"

local function Zyros()
    return { profiles = { Default = {}, Caster = {}, Melee = {} }, defaultProfile = "Default",
        charActive = { ["Zyro-Forever"] = "Caster" }, charSeen = { ["Zyro-Forever"] = 100 },
        charGuid = { ["Zyro-Forever"] = TAPS_GUID } }
end

do
    local sv = Zyros()
    local ns = Login(sv, "Zyro", 200, TAPS_GUID, "Taps")
    check("a surname is part of the character's key", sv.charActive["Zyro Taps-Forever"] == "Caster")
    check("its first-name entry is taken over when its GUID matches", sv.charActive["Zyro-Forever"] == nil
        and sv.charGuid["Zyro-Forever"] == nil and sv.charSeen["Zyro-Forever"] == nil)
    check("and it is not asked about a main", ns.ImportCandidate() == nil)
    ns.MarkSeen()
    check("its login is noted under the whole name", sv.charSeen["Zyro Taps-Forever"] == 200
        and sv.charGuid["Zyro Taps-Forever"] == TAPS_GUID)
end

do
    local sv = Zyros()
    sv.charGuid["Zyro-Forever"] = SLAMS_GUID
    Login(sv, "Zyro", 200, TAPS_GUID, "Taps")
    check("another character's first-name entry is copied, not taken", sv.charActive["Zyro Taps-Forever"] == "Caster"
        and sv.charActive["Zyro-Forever"] == "Caster")
    Login(sv, "Zyro", 300, SLAMS_GUID, "Slams")
    check("so the other character keeps its profile too", sv.charActive["Zyro Slams-Forever"] == "Caster"
        and sv.charActive["Zyro-Forever"] == nil)
    sv.charActive["Zyro Slams-Forever"] = "Melee"
    Login(sv, "Zyro", 400, TAPS_GUID, "Taps")
    check("two characters with one first name keep their own profile", sv.charActive["Zyro Taps-Forever"] == "Caster"
        and sv.charActive["Zyro Slams-Forever"] == "Melee")
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, charActive = { ["Die Man-Forever"] = "Raid" },
        charGuid = { ["Die Man-Forever"] = MAIN_GUID } }
    Login(sv, "Die Man", 100, MAIN_GUID)
    check("a character with no surname keeps its key", sv.charActive["Die Man-Forever"] == "Raid"
        and sv.charGuid["Die Man-Forever"] == MAIN_GUID)
end

do
    local sv = Zyros()
    local ns = Login(sv, "Zyro", 200, TAPS_GUID, "Taps")
    local store = { ["Zyro-Forever"] = { seen = true }, ["Other-Forever"] = {} }
    local key = ns.CharKey(store)
    check("a module's first-name entry moves to the whole name", key == "Zyro Taps-Forever"
        and store[key].seen and store["Zyro-Forever"] == nil and store["Other-Forever"])
    store[key] = nil
    ns.CharKey(store)
    check("and a cleared entry stays cleared", store[key] == nil)
    check("without a store it is just the key", ns.CharKey() == "Zyro Taps-Forever")
end

local HIDDEN = ""

do
    local sv = { profiles = { Default = {}, Raid = {} }, charActive = { ["Die Man-Forever"] = "Raid" },
        charGuid = { ["Die Man-Forever"] = MAIN_GUID } }
    local ns = Login(sv, "Die Man", 100, MAIN_GUID, nil, HIDDEN)
    check("with the realm hidden, a character seen before keeps its realm and profile",
        ns.RealmName() == "Forever" and sv.charActive["Die Man-Forever"] == "Raid" and sv.charActive["Die Man-"] == nil)
    Login(sv, "Die Dudu", 200, DUDU_GUID, nil, HIDDEN)
    check("and a new character on that server takes the same realm", sv.charActive["Die Dudu-Forever"] == "Default"
        and sv.charActive["Die Dudu-"] == nil)
end

do
    local sv = { profiles = { Default = {}, Raid = {} },
        charActive = { ["Die Man-Forever"] = "Raid", ["Die Man-"] = "Default", ["Die Dudu-"] = "Raid" },
        charGuid = { ["Die Man-Forever"] = MAIN_GUID, ["Die Man-"] = MAIN_GUID, ["Die Dudu-"] = DUDU_GUID },
        charSeen = { ["Die Man-"] = 50 } }
    Login(sv, "Die Man", 100, MAIN_GUID, nil, HIDDEN)
    check("an entry saved with no realm is dropped when the character has its own",
        sv.charActive["Die Man-Forever"] == "Raid" and sv.charActive["Die Man-"] == nil
        and sv.charGuid["Die Man-"] == nil and sv.charSeen["Die Man-"] == nil)
    Login(sv, "Die Dudu", 200, DUDU_GUID, nil, HIDDEN)
    check("and moved to the realm when it is the character's only one", sv.charActive["Die Dudu-Forever"] == "Raid"
        and sv.charActive["Die Dudu-"] == nil)
end

do
    local sv = { profiles = { Default = {} }, charActive = {} }
    local ns = Login(sv, "Die Man", 100, "Player-77-00000001", nil, HIDDEN)
    check("a server never seen with its realm is keyed by its ID", ns.RealmName() == "77"
        and sv.charActive["Die Man-77"] == "Default")
    check("and with no GUID yet there is no realm", Login({ profiles = {}, charActive = {} }, "Die Man", 100, nil, nil,
        HIDDEN).RealmName() == "")
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Default" },
        charGuid = { ["Die Man-Forever"] = MAIN_GUID } }
    local ns = Login(sv, "Die Man", 100, MAIN_GUID, nil, HIDDEN)
    local store = { ["Die Man-"] = { seen = true } }
    check("a module's entry saved with no realm moves to the realm", ns.CharKey(store) == "Die Man-Forever"
        and store["Die Man-Forever"].seen and store["Die Man-"] == nil)
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, charActive = { ["Die Man-"] = "Raid" },
        charGuid = { ["Die Man-"] = "Player-88-00000001" } }
    Login(sv, "Die Man", 100, "Player-77-00000001", nil, HIDDEN)
    check("another server's character's entry with no realm is not taken", sv.charActive["Die Man-77"] == "Default"
        and sv.charActive["Die Man-"] == "Raid")
end

do
    local sv = { profiles = { Default = {} }, charActive = {},
        charGuid = { ["Die Dudu-4613"] = DUDU_GUID, ["Die Pri-Forever"] = PRI_GUID } }
    for _ = 1, 20 do
        check("a saved realm name wins over a server number", Login(sv, "Die Man", 100, MAIN_GUID, nil, HIDDEN)
            .RealmName() == "Forever")
    end
end

print(("test-import-candidate: %d checks passed"):format(checks))
