-- Filter.lua: which listings Browse shows bright: a group's open spots, what it has, its leader, a player's class and level, playstyle, declined groups, a typed filter and the search text, kept between sessions and as named filters (ns.GroupFinder.Filter).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms, Listings = GF.Card, GF.Comms, GF.Listings
local S = GF.Settings

local sub, find, lower, floor = string.sub, string.find, string.lower, math.floor

local EXPECTED = { [Card.TANK] = 1, [Card.HEALER] = 1, [Card.DAMAGE] = 3 }
local NEED_KEY = GF.Group.NEED_KEY
local ROLES = { Card.TANK, Card.HEALER, Card.DAMAGE }
local SECONDS_PER_MINUTE = 60
local TENTHS = 10
local EXPR_MAX = 200
local LUST_CLASS, RES_CLASS = "SHAMAN", "DRUID"
local HAS, LACKS = 1, 2
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local HAS_KEYS = { "myClass", "bloodlust", "battleRes", "friend" }
local WORDS = { "tank", "healer", "dps", "members", "tankOpen", "healerOpen", "dpsOpen", "score", "min", "age",
    "level", "friends", "myClass", "hasBL", "hasBR", "warrior", "paladin", "hunter", "rogue", "priest", "shaman",
    "mage", "warlock", "druid" }
local OPERATORS = { "and", "or", "not", ">", "<", ">=", "<=", "==", "!=", "+", "-", "(", ")" }
local TEXT_UNKNOWN = ns.L("unknown word: %s")
local TEXT_MISSING = ns.L("missing )")
local TEXT_END = ns.L("ends too soon")
local TEXT_UNEXPECTED = ns.L("unexpected %s")
local TEXT_UNREADABLE = ns.L("cannot read %s")
local PRESETS_MAX = 20
local PRESET_NAME_MAX = 20

local Filter = {
    roles = {}, partyFit = false, has = {}, classes = {}, minScore = 0, styles = {}, expr = "", q = "",
    soloClasses = {}, levelMin = 0, levelMax = 0,
    HAS = HAS, LACKS = LACKS, HAS_KEYS = HAS_KEYS, CLASSES = CLASSES, WORDS = WORDS, OPERATORS = OPERATORS,
    EXPR_MAX = EXPR_MAX, PRESETS_MAX = PRESETS_MAX, PRESET_NAME_MAX = PRESET_NAME_MAX,
}
GF.Filter = Filter

local env = {}
local wordSet = {}
for _, word in ipairs(WORDS) do wordSet[lower(word)] = true end
local compiled, compiledFrom, compileError = nil, nil, nil
local guild, guildRead = {}, false
local tokens, nTokens, at = {}, 0, 1

function Filter.MyRoles()
    local roles = S.Get("applyRoles")
    if roles == 0 then roles = Card.SavedRoles() end
    return roles
end

function Filter.Open(entry, role)
    local card = entry.leader and Comms.CardOf(entry.leader)
    local group = card and card.group
    if group then return group[NEED_KEY[role]] end
    local open = EXPECTED[role] - entry[NEED_KEY[role]]
    return open > 0 and open or 0
end

local function ReadGuild()
    if guildRead then return end
    guildRead = true
    wipe(guild)
    if not IsInGuild() then return end
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if type(name) == "string" and not issecretvalue(name) then guild[Comms.Key(name)] = true end
    end
end

local function Known(name)
    if C_FriendList.GetFriendInfo(Ambiguate(name, "none")) then return true end
    ReadGuild()
    return guild[Comms.Key(name)] == true
end

function Filter.Friends(entry)
    local n = 0
    for m = 1, entry.nMembers do
        local member = entry.members[m]
        if member.name and not Comms.IsMe(member.name) and Known(member.name) then n = n + 1 end
    end
    return n
end

function Filter.HasClass(entry, class)
    for m = 1, entry.nMembers do
        if entry.members[m].class == class then return true end
    end
    return false
end

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

local function HasKey(entry, key)
    if key == "myClass" then return Filter.HasClass(entry, PlayerClass()) end
    if key == "bloodlust" then return Filter.HasClass(entry, LUST_CLASS) end
    if key == "battleRes" then return Filter.HasClass(entry, RES_CLASS) end
    if key == "friend" then return Filter.Friends(entry) > 0 end
    return Filter.HasClass(entry, key)
end

function Filter.Score(entry)
    local card = entry.leader and Comms.CardOf(entry.leader)
    return card and card.score
end

local function Fill(entry)
    wipe(env)
    env.tank, env.healer, env.dps, env.members = entry.tanks, entry.healers, entry.damage, entry.numMembers
    env.tankopen, env.healeropen = Filter.Open(entry, Card.TANK), Filter.Open(entry, Card.HEALER)
    env.dpsopen = Filter.Open(entry, Card.DAMAGE)
    local card = entry.leader and Comms.CardOf(entry.leader)
    env.score = card and card.score and card.score / TENTHS or 0
    env.min = card and card.group and card.group.min / TENTHS or 0
    env.age = floor(entry.age / SECONDS_PER_MINUTE)
    env.friends = Filter.Friends(entry)
    for m = 1, entry.nMembers do
        local member = entry.members[m]
        if member.leader then env.level = member.level end
        local word = member.class and lower(member.class)
        if word then env[word] = (env[word] or 0) + 1 end
    end
    env.level = env.level or 0
    env.myclass = env[lower(PlayerClass())] or 0
    env.hasbl = (env[lower(LUST_CLASS)] or 0) > 0 and 1 or 0
    env.hasbr = (env[lower(RES_CLASS)] or 0) > 0 and 1 or 0
end

local function Lex(text)
    nTokens = 0
    wipe(tokens)
    local i, len = 1, #text
    while i <= len do
        local c = sub(text, i, i)
        if find(c, "%s") then
            i = i + 1
        else
            local token
            local s, e = find(text, "^%d+%.?%d*", i)
            if s then
                token = { n = tonumber(sub(text, s, e)) }
            else
                s, e = find(text, "^%a+", i)
                if s then
                    local word = lower(sub(text, s, e))
                    if word == "and" or word == "or" or word == "not" then
                        token = { o = word }
                    elseif word == "true" or word == "false" then
                        token = { n = word == "true" and 1 or 0 }
                    elseif wordSet[word] then
                        token = { v = word }
                    else
                        return TEXT_UNKNOWN:format(sub(text, s, e))
                    end
                else
                    s, e = find(text, "^[<>=!~]=", i)
                    if not s then s, e = find(text, "^[%(%)%+%-%*/<>=!]", i) end
                    if not s then s, e = find(text, "^&&", i) end
                    if not s then s, e = find(text, "^||", i) end
                    if not s then return TEXT_UNREADABLE:format(c) end
                    local op = sub(text, s, e)
                    if op == "&&" then op = "and" elseif op == "||" then op = "or" elseif op == "!" then op = "not"
                    elseif op == "=" then op = "==" elseif op == "~=" then op = "!=" end
                    token = { o = op }
                end
            end
            nTokens = nTokens + 1
            tokens[nTokens] = token
            i = e + 1
        end
    end
end

local Or

local function Peek()
    return tokens[at]
end

local function Primary()
    local token = tokens[at]
    if not token then error(TEXT_END, 0) end
    at = at + 1
    if token.n then
        local n = token.n
        return function() return n end
    end
    if token.v then
        local word = token.v
        return function() return env[word] or 0 end
    end
    if token.o == "(" then
        local inner = Or()
        local close = tokens[at]
        if not (close and close.o == ")") then error(TEXT_MISSING, 0) end
        at = at + 1
        return inner
    end
    if token.o == "-" then
        local operand = Primary()
        return function() return -operand() end
    end
    error(TEXT_UNEXPECTED:format(token.o), 0)
end

local function Binary(next, ops)
    return function()
        local left = next()
        while true do
            local token = Peek()
            local op = token and token.o and ops[token.o]
            if not op then return left end
            at = at + 1
            local a, b = left, next()
            left = function() return op(a(), b()) end
        end
    end
end

local function B(v) return v and 1 or 0 end

local Mul = Binary(Primary, {
    ["*"] = function(a, b) return a * b end,
    ["/"] = function(a, b) return b ~= 0 and a / b or 0 end,
})
local Add = Binary(Mul, {
    ["+"] = function(a, b) return a + b end,
    ["-"] = function(a, b) return a - b end,
})
local Compare = Binary(Add, {
    ["<"] = function(a, b) return B(a < b) end,
    [">"] = function(a, b) return B(a > b) end,
    ["<="] = function(a, b) return B(a <= b) end,
    [">="] = function(a, b) return B(a >= b) end,
    ["=="] = function(a, b) return B(a == b) end,
    ["!="] = function(a, b) return B(a ~= b) end,
})
local function Not()
    local token = Peek()
    if token and token.o == "not" then
        at = at + 1
        local operand = Not()
        return function() return operand() == 0 and 1 or 0 end
    end
    return Compare()
end

local And = Binary(Not, { ["and"] = function(a, b) return B(a ~= 0 and b ~= 0) end })
Or = Binary(And, { ["or"] = function(a, b) return B(a ~= 0 or b ~= 0) end })

local function Compile(text)
    local lexError = Lex(text)
    if lexError then return nil, lexError end
    at = 1
    local ok, result = pcall(Or)
    if not ok then return nil, result end
    if at <= nTokens then
        local token = tokens[at]
        return nil, TEXT_UNEXPECTED:format(token.o or token.v or tostring(token.n))
    end
    return result
end

function Filter.Expression()
    local text = Filter.expr
    if text == compiledFrom then return compiled, compileError end
    compiledFrom = text
    if find(text, "^%s*$") then
        compiled, compileError = nil, nil
    else
        compiled, compileError = Compile(text)
    end
    return compiled, compileError
end

local function Declined(entry)
    local record = entry.leader and Comms.SentTo(entry.leader)
    return record ~= nil and record.declined
end

local function HasText(text, needle)
    return type(text) == "string" and find(lower(text), needle, 1, true) ~= nil
end

local function Matches(entry, needle)
    local activity = entry.activity and Listings.Activity(entry.activity)
    local card = entry.leader and Comms.CardOf(entry.leader)
    local group = card and card.group
    return HasText(activity and activity.name, needle) or HasText(activity and activity.short, needle)
        or HasText(entry.leader, needle)
        or HasText(group and group.note, needle)
end

local function PartyRoom(entry)
    local size = IsInGroup() and GetNumGroupMembers() or 1
    local open = 0
    for _, role in ipairs(ROLES) do open = open + Filter.Open(entry, role) end
    if open < size then return false end
    if size > 1 then return true end
    local roles = Filter.MyRoles()
    for _, role in ipairs(ROLES) do
        if Card.Has(roles, role) and Filter.Open(entry, role) > 0 then return true end
    end
    return false
end

local function AnyRole()
    for _, role in ipairs(ROLES) do
        if Filter.roles[role] then return true end
    end
    return false
end

local function RoleOpen(entry)
    for _, role in ipairs(ROLES) do
        if Filter.roles[role] and Filter.Open(entry, role) > 0 then return true end
    end
    return false
end

local function AnyStyle()
    return next(Filter.styles) ~= nil
end

local function SoloPass(entry)
    local player = entry.nMembers > 0 and entry.members[1] or nil
    if next(Filter.soloClasses) and not (player and Filter.soloClasses[player.class]) then return false end
    if (Filter.levelMin > 0 or Filter.levelMax > 0) and not player then return false end
    local level = player and player.level or 0
    if Filter.levelMin > 0 and level < Filter.levelMin then return false end
    if Filter.levelMax > 0 and level > Filter.levelMax then return false end
    if AnyStyle() and not Filter.styles[entry.style or 0] then return false end
    if Filter.q ~= "" and not Matches(entry, lower(Filter.q)) then return false end
    return true
end

function Filter.Solo(entry)
    return entry.numMembers == 1
end

function Filter.Pass(entry)
    if Filter.Solo(entry) then return SoloPass(entry) end
    if AnyRole() and not RoleOpen(entry) then return false end
    if Filter.partyFit and not PartyRoom(entry) then return false end
    for key, want in pairs(Filter.has) do
        local has = HasKey(entry, key)
        if (want == HAS and not has) or (want == LACKS and has) then return false end
    end
    if Filter.minScore > 0 then
        local score = Filter.Score(entry)
        if not score or score < Filter.minScore then return false end
    end
    if AnyStyle() and not Filter.styles[entry.style or 0] then return false end
    if S.Get("hideDeclined") and Declined(entry) then return false end
    local fn = Filter.Expression()
    if fn then
        Fill(entry)
        if fn() == 0 then return false end
    end
    if Filter.q ~= "" and not Matches(entry, lower(Filter.q)) then return false end
    return true
end

function Filter.Count()
    local n = 0
    for _, role in ipairs(ROLES) do
        if Filter.roles[role] then n = n + 1 end
    end
    if Filter.partyFit then n = n + 1 end
    for _ in pairs(Filter.has) do n = n + 1 end
    if Filter.minScore > 0 then n = n + 1 end
    for _ in pairs(Filter.styles) do n = n + 1 end
    if S.Get("hideDeclined") then n = n + 1 end
    if Filter.Expression() then n = n + 1 end
    if Filter.q ~= "" then n = n + 1 end
    for _ in pairs(Filter.soloClasses) do n = n + 1 end
    if Filter.levelMin > 0 or Filter.levelMax > 0 then n = n + 1 end
    return n
end

local function Keys(set)
    local list = {}
    for key, on in pairs(set) do
        if on then list[#list + 1] = key end
    end
    return list
end

local function Snapshot()
    local has = {}
    for key, want in pairs(Filter.has) do has[key] = want end
    local classes = {}
    for i, class in ipairs(Filter.classes) do classes[i] = class end
    return { roles = Keys(Filter.roles), partyFit = Filter.partyFit, has = has, classes = classes,
        minScore = Filter.minScore, styles = Keys(Filter.styles), expr = Filter.expr,
        soloClasses = Keys(Filter.soloClasses), levelMin = Filter.levelMin, levelMax = Filter.levelMax }
end

local function FillSet(set, list)
    wipe(set)
    for _, key in ipairs(type(list) == "table" and list or {}) do set[key] = true end
end

local function Load(saved)
    if type(saved) ~= "table" then return end
    FillSet(Filter.roles, saved.roles)
    FillSet(Filter.styles, saved.styles)
    FillSet(Filter.soloClasses, saved.soloClasses)
    wipe(Filter.has)
    for key, want in pairs(type(saved.has) == "table" and saved.has or {}) do
        if want == HAS or want == LACKS then Filter.has[key] = want end
    end
    wipe(Filter.classes)
    for _, class in ipairs(type(saved.classes) == "table" and saved.classes or {}) do
        Filter.classes[#Filter.classes + 1] = class
    end
    Filter.partyFit = saved.partyFit == true
    Filter.minScore = not ns.CHINA and tonumber(saved.minScore) or 0
    Filter.expr = type(saved.expr) == "string" and saved.expr or ""
    Filter.levelMin, Filter.levelMax = tonumber(saved.levelMin) or 0, tonumber(saved.levelMax) or 0
end

function Filter.Changed()
    S.Set("filters", Snapshot())
    GF.Fire("filter")
end

local function Presets(create)
    local presets = S.Get("presets")
    if type(presets) ~= "table" then
        if not create then return nil end
        presets = {}
        S.Set("presets", presets)
    end
    return presets
end

function Filter.PresetNames(out)
    wipe(out)
    for name in pairs(Presets() or out) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Filter.SavePreset(name)
    name = strtrim(name or "")
    if name == "" then return false, "empty" end
    local presets = Presets(true)
    local count = 0
    for _ in pairs(presets) do count = count + 1 end
    if not presets[name] and count >= PRESETS_MAX then return false, "full" end
    presets[name] = Snapshot()
    GF.Fire("filter")
    return true
end

function Filter.LoadPreset(name)
    local presets = Presets()
    if not (presets and presets[name]) then return false end
    Load(presets[name])
    Filter.Changed()
    return true
end

function Filter.DeletePreset(name)
    local presets = Presets()
    if not (presets and presets[name]) then return end
    presets[name] = nil
    GF.Fire("filter")
end

function Filter.Cycle(key)
    local want = (Filter.has[key] or 0) + 1
    Filter.has[key] = want <= LACKS and want or nil
    Filter.Changed()
end

function Filter.AddClass(class)
    local known = false
    for _, listed in ipairs(Filter.classes) do
        if listed == class then known = true end
    end
    if not known then Filter.classes[#Filter.classes + 1] = class end
    Filter.has[class] = HAS
    Filter.Changed()
end

function Filter.Reset()
    wipe(Filter.roles)
    wipe(Filter.has)
    wipe(Filter.classes)
    wipe(Filter.styles)
    wipe(Filter.soloClasses)
    Filter.partyFit, Filter.minScore, Filter.expr, Filter.q = false, 0, "", ""
    Filter.levelMin, Filter.levelMax = 0, 0
    if S.Get("hideDeclined") then S.Set("hideDeclined", false) end
    Filter.Changed()
end

GF.Listen("listings", function()
    guildRead = false
end)

ns.OnApply(function()
    Load(S.Get("filters"))
end)
