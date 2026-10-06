-------------------------------------------------------------------------------
--  Card.lua -- your Group Finder card and every Group Finder message (ns.GroupFinder.Card):
--  what you share for one dungeon, built only when a message needs it, written and read as
--  one plain, versioned line of at most 255 bytes. Comms.lua sends and receives them.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local GF = ns.GroupFinder
local S = GF.Settings

local byte, find, sub, gsub = string.byte, string.find, string.sub, string.gsub
local concat, floor = table.concat, math.floor

local Card = {
    VERSION = "1",
    MAX_BYTES = 255,
    NOTE_MAX = 60,
    MAX_KILLS = 30,
    KILL_CAP = 99,
    MAX_QUESTS = 8,
    ID_MAX = 9999,
}
GF.Card = Card

local VERSION, MAX_BYTES, NOTE_MAX = Card.VERSION, Card.MAX_BYTES, Card.NOTE_MAX
local MAX_KILLS, KILL_CAP, MAX_QUESTS, ID_MAX = Card.MAX_KILLS, Card.KILL_CAP, Card.MAX_QUESTS, Card.ID_MAX
local VERSION_BYTE = byte(VERSION)
local CLASS_MAX, LEVEL_MAX, SCORE_MAX, BIS_MAX, QUEST_ID_MAX = 20, 100, 99999, 40, 999999
local GUID_MAX, KEY_MAX, SPEC_MAX = 40, 40, 32
local GUID_PATTERN = "^Player%-%d+%-%x+$"
local KEY_PATTERN = "^%u%w*$"
local SPEC_PATTERN = "^[%l%-]+$"
local NOTE_BAD = "[^\32-\123\125\126]"
local ESCAPES = { "|c%x%x%x%x%x%x%x%x", "|H.-|h", "|T.-|t", "|A.-|a", "|K.-|k", "|[rh]" }
local NONE, NONE_BYTE, SPACE = "-", 45, 32

local KINDS = { [81] = "Q", [67] = "C", [65] = "A", [75] = "K", [88] = "X", [68] = "D" }

local TANK, HEALER, DAMAGE = 4, 2, 1
Card.TANK, Card.HEALER, Card.DAMAGE = TANK, HEALER, DAMAGE
local ROLE_CODE = { [0] = NONE, "D", "H", "HD", "T", "TD", "TH", "THD" }
local ROLE_BIT = { [84] = TANK, [72] = HEALER, [68] = DAMAGE }

function Card.New()
    return { kills = {}, have = {}, need = {}, nKills = 0, nHave = 0, nNeed = 0, roles = 0 }
end

function Card.Roles(tank, healer, damage)
    return (tank and TANK or 0) + (healer and HEALER or 0) + (damage and DAMAGE or 0)
end

function Card.RoleCode(bits)
    return ROLE_CODE[bits] or NONE
end

local function Trim(t, n)
    for i = #t, n + 1, -1 do t[i] = nil end
end

local mine = Card.New()
local lastTenths

local function SavedRoles()
    local roles = C_LFGListRoles and C_LFGListRoles.GetRoles and C_LFGListRoles.GetRoles()
    if type(roles) ~= "table" then return 0 end
    return Card.Roles(roles.tank, roles.healer, roles.dps)
end
Card.SavedRoles = SavedRoles

local function Tenths()
    local Score = ns.NaowhScore
    if not (Score and Score.Unit) then return nil end
    local score, complete = Score.Unit("player")
    if complete and type(score) == "number" then
        local tenths = floor(score * 10 + 0.5)
        if tenths >= 0 and tenths <= SCORE_MAX then lastTenths = tenths end
    end
    return lastTenths
end

local function BisOn()
    local B = ns.BiS
    return B ~= nil and B.On ~= nil and B.Lists ~= nil and B.Rankings ~= nil and B.On()
end

local function Spec()
    local spec = ns.BiS.Lists.CurrentSpec()
    local key = spec and spec.key
    if type(key) == "string" and #key <= SPEC_MAX and find(key, SPEC_PATTERN) then return key end
end

local function Bis()
    local have, total = ns.BiS.Rankings.Had(ns.BiS.Lists.List())
    if type(total) ~= "number" or total < 1 or total > BIS_MAX or have > total then return nil end
    return have, total
end

local function Journal()
    local J = ns.Journal
    if J and J.Get and J.Kills and J.Quests then return J end
end

local function FillKills(card, J, dungeon)
    local kills, n = card.kills, 0
    local Kills = J.Kills
    for w = 1, #dungeon.wings do
        local bosses = dungeon.wings[w].bosses
        for b = 1, #bosses do
            local boss = bosses[b]
            if n < MAX_KILLS and not boss.with and Kills.Counted(boss) then
                local count = Kills.Count(boss)
                n = n + 1
                kills[n] = count > KILL_CAP and KILL_CAP or count
            end
        end
    end
    Trim(kills, n)
    card.nKills = n
    return n > 0
end

local function FillQuests(card, J, dungeon)
    local data = dungeon.quests
    local list = data and data.quests
    local Q = J.Quests
    local have, need, nh, nn = card.have, card.need, 0, 0
    for i = 1, list and #list or 0 do
        local quest = list[i]
        if Q.ForMe(quest) then
            local kind = Q.Kind(quest)
            if Q.InLog(kind) then
                if nh < MAX_QUESTS then
                    nh = nh + 1
                    have[nh] = quest[1]
                end
            elseif kind ~= "done" and kind ~= "low" and nn < MAX_QUESTS then
                nn = nn + 1
                need[nn] = quest[1]
            end
        end
    end
    Trim(have, nh)
    Trim(need, nn)
    card.nHave, card.nNeed = nh, nn
    return true
end

function Card.Mine(dungeonKey, roles)
    local card = mine
    card.guid = UnitGUID("player")
    local _, _, classID = UnitClass("player")
    card.class = classID
    card.level = UnitLevel("player")
    card.roles = roles or SavedRoles()
    local bis = BisOn()
    card.spec = bis and Spec() or nil
    card.score = S.Get("shareScore") and Tenths() or nil
    card.bisHave, card.bisTotal = nil, nil
    if bis and S.Get("shareBis") then card.bisHave, card.bisTotal = Bis() end
    local J = Journal()
    local dungeon = dungeonKey and J and J.Get(dungeonKey)
    card.dungeon = dungeon and dungeonKey or nil
    card.hasKills = dungeon and S.Get("shareKills") and FillKills(card, J, dungeon) or false
    card.hasQuests = dungeon and S.Get("shareQuests") and FillQuests(card, J, dungeon) or false
    if not card.hasKills then
        card.nKills = 0
        Trim(card.kills, 0)
    end
    if not card.hasQuests then
        card.nHave, card.nNeed = 0, 0
        Trim(card.have, 0)
        Trim(card.need, 0)
    end
    return card
end

local out = {}

local function Joined(t, n)
    if n == 0 then return "" end
    return concat(t, ",", 1, n)
end

local function Body(card, n, questCap, kills)
    out[n + 1] = card.class
    out[n + 2] = card.level
    out[n + 3] = ROLE_CODE[card.roles] or NONE
    out[n + 4] = card.spec or NONE
    out[n + 5] = card.score or NONE
    out[n + 6] = card.bisTotal and (card.bisHave .. "/" .. card.bisTotal) or NONE
    out[n + 7] = card.dungeon or NONE
    out[n + 8] = (card.dungeon and kills and card.hasKills and card.nKills > 0)
        and Joined(card.kills, card.nKills) or NONE
    if card.dungeon and card.hasQuests then
        local nh = card.nHave < questCap and card.nHave or questCap
        local nn = card.nNeed < questCap and card.nNeed or questCap
        out[n + 9] = Joined(card.have, nh) .. "/" .. Joined(card.need, nn)
    else
        out[n + 9] = NONE
    end
    return n + 9
end

local function WithCard(kind, id, card, note)
    if not card.guid then return nil end
    local cap, kills = MAX_QUESTS, true
    while true do
        out[1], out[2], out[3], out[4] = VERSION, kind, card.guid, id
        local n = Body(card, 4, cap, kills)
        if note then
            n = n + 1
            out[n] = note
        end
        local text = concat(out, " ", 1, n)
        if #text <= MAX_BYTES then return text end
        if cap > 0 then
            cap = cap - 1
        elseif kills then
            kills = false
        else
            return nil
        end
    end
end

function Card.Reply(nonce, card)
    return WithCard("C", nonce, card)
end

function Card.Application(id, card, note)
    return WithCard("A", id, card, note ~= "" and note or nil)
end

function Card.Ask(nonce, dungeonKey)
    local guid = UnitGUID("player")
    if not guid then return nil end
    out[1], out[2], out[3], out[4], out[5] = VERSION, "Q", guid, nonce, dungeonKey or NONE
    return concat(out, " ", 1, 5)
end

function Card.Short(kind, id)
    local guid = UnitGUID("player")
    if not guid then return nil end
    out[1], out[2], out[3], out[4] = VERSION, kind, guid, id
    return concat(out, " ", 1, 4)
end

function Card.CleanNote(text)
    if type(text) ~= "string" then return "" end
    for i = 1, #ESCAPES do text = gsub(text, ESCAPES[i], "") end
    text = gsub(gsub(gsub(text, "%s+", " "), NOTE_BAD, ""), "  +", " ")
    text = gsub(gsub(text, "^ ", ""), " $", "")
    if #text > NOTE_MAX then text = gsub(sub(text, 1, NOTE_MAX), " $", "") end
    return text
end

local function Field(s, pos, len)
    if pos > len then return nil end
    local space = find(s, " ", pos, true)
    if space == pos then return nil end
    if space then return pos, space - 1, space + 1 end
    return pos, len, len + 1
end

local function Int(s, i, j, max)
    if j < i or j - i > 5 then return nil end
    local v = 0
    for k = i, j do
        local b = byte(s, k)
        if b < 48 or b > 57 then return nil end
        v = v * 10 + b - 48
    end
    if v > max then return nil end
    return v
end

local function IsNone(s, i, j)
    return i == j and byte(s, i) == NONE_BYTE
end

local function Text(s, i, j, max, pattern)
    if j - i + 1 > max then return nil end
    local text = sub(s, i, j)
    if not find(text, pattern) then return nil end
    return text
end

local function Roles(s, i, j)
    if IsNone(s, i, j) then return 0 end
    if j - i > 2 then return nil end
    local bits, last = 0, 8
    for k = i, j do
        local bit = ROLE_BIT[byte(s, k)]
        if not bit or bit >= last then return nil end
        bits, last = bits + bit, bit
    end
    return bits
end

local function Slash(s, i, j)
    local slash = find(s, "/", i, true)
    if not slash or slash > j then return nil end
    local again = find(s, "/", slash + 1, true)
    if again and again <= j then return nil end
    return slash
end

local function List(s, i, j, t, max, cap, low)
    if i > j then
        Trim(t, 0)
        return 0
    end
    local n, at = 0, i
    while true do
        local comma = find(s, ",", at, true)
        local e = (comma and comma <= j) and comma - 1 or j
        local v = Int(s, at, e, cap)
        if not v or v < low or n >= max then return nil end
        n = n + 1
        t[n] = v
        if e == j then break end
        at = e + 2
        if at > j then return nil end
    end
    Trim(t, n)
    return n
end

local function ParseBody(s, pos, len, card)
    local i, j
    i, j, pos = Field(s, pos, len)
    card.class = i and Int(s, i, j, CLASS_MAX)
    if not card.class or card.class < 1 then return nil end
    i, j, pos = Field(s, pos, len)
    card.level = i and Int(s, i, j, LEVEL_MAX)
    if not card.level or card.level < 1 then return nil end
    i, j, pos = Field(s, pos, len)
    card.roles = i and Roles(s, i, j)
    if not card.roles then return nil end
    i, j, pos = Field(s, pos, len)
    if not i then return nil end
    if IsNone(s, i, j) then
        card.spec = nil
    else
        card.spec = Text(s, i, j, SPEC_MAX, SPEC_PATTERN)
        if not card.spec then return nil end
    end
    i, j, pos = Field(s, pos, len)
    if not i then return nil end
    if IsNone(s, i, j) then
        card.score = nil
    else
        card.score = Int(s, i, j, SCORE_MAX)
        if not card.score then return nil end
    end
    i, j, pos = Field(s, pos, len)
    if not i then return nil end
    if IsNone(s, i, j) then
        card.bisHave, card.bisTotal = nil, nil
    else
        local slash = Slash(s, i, j)
        local have = slash and Int(s, i, slash - 1, BIS_MAX)
        local total = have and Int(s, slash + 1, j, BIS_MAX)
        if not total or total < 1 or have > total then return nil end
        card.bisHave, card.bisTotal = have, total
    end
    i, j, pos = Field(s, pos, len)
    if not i then return nil end
    if IsNone(s, i, j) then
        card.dungeon = nil
    else
        card.dungeon = Text(s, i, j, KEY_MAX, KEY_PATTERN)
        if not card.dungeon then return nil end
    end
    i, j, pos = Field(s, pos, len)
    if not i then return nil end
    if IsNone(s, i, j) then
        card.hasKills, card.nKills = false, 0
        Trim(card.kills, 0)
    else
        local n = card.dungeon and List(s, i, j, card.kills, MAX_KILLS, KILL_CAP, 0)
        if not n or n < 1 then return nil end
        card.hasKills, card.nKills = true, n
    end
    i, j, pos = Field(s, pos, len)
    if not i then return nil end
    if IsNone(s, i, j) then
        card.hasQuests, card.nHave, card.nNeed = false, 0, 0
        Trim(card.have, 0)
        Trim(card.need, 0)
    else
        local slash = card.dungeon and Slash(s, i, j)
        local nh = slash and List(s, i, slash - 1, card.have, MAX_QUESTS, QUEST_ID_MAX, 1)
        local nn = nh and List(s, slash + 1, j, card.need, MAX_QUESTS, QUEST_ID_MAX, 1)
        if not nn then return nil end
        card.hasQuests, card.nHave, card.nNeed = true, nh, nn
    end
    return pos, j
end

function Card.Decode(text, card)
    if type(text) ~= "string" then return nil end
    local len = #text
    if len > MAX_BYTES then return nil end
    local i, j, pos = Field(text, 1, len)
    if not i or j ~= i or byte(text, i) ~= VERSION_BYTE then return nil end
    i, j, pos = Field(text, pos, len)
    local kind = i and i == j and KINDS[byte(text, i)]
    if not kind then return nil end
    i, j, pos = Field(text, pos, len)
    local guid = i and Text(text, i, j, GUID_MAX, GUID_PATTERN)
    if not guid then return nil end
    i, j, pos = Field(text, pos, len)
    local id = i and Int(text, i, j, ID_MAX)
    if not id or id < 1 then return nil end
    if kind == "Q" then
        i, j = Field(text, pos, len)
        if not i or j ~= len then return nil end
        if IsNone(text, i, j) then return kind, guid, id, nil end
        local key = Text(text, i, j, KEY_MAX, KEY_PATTERN)
        if not key then return nil end
        return kind, guid, id, key
    end
    if kind == "C" or kind == "A" then
        if not card then return nil end
        pos, j = ParseBody(text, pos, len, card)
        if not pos then return nil end
        if j == len then return kind, guid, id, nil end
        if kind == "C" or pos > len or byte(text, pos) == SPACE then return nil end
        local note = sub(text, pos)
        if #note > NOTE_MAX or find(note, NOTE_BAD) or byte(note, #note) == SPACE then return nil end
        return kind, guid, id, note
    end
    if j ~= len then return nil end
    return kind, guid, id
end
