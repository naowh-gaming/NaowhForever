-- PallyPower.lua: the plans of the group's paladins running PallyPower, read from its addon messages.
local ns = _G.NaowhForever

local B = ns.Blessings
local others = B.others

local PREFIX = "PLPWR"
local ASK = "REQ"
local UNKNOWN = "n"
local CLASSES = { "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN" }
local BLESSINGS = { "wisdom", "might", "kings" }
local AURAS = { "devotion", "retribution", "concentration", "shadow", "frost", "fire", "sanctity" }
local MAX_SYMBOLS = 9999
local MAX_COOLDOWN = 7200

local function RefreshPage()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function Plan(who)
    local plan = others[who]
    if plan then return plan.pallyPower and plan or nil end
    plan = { classes = {}, known = {}, players = {}, choices = 0, pallyPower = true }
    others[who] = plan
    return plan
end

local function Known(plan, keys, ranks)
    for i, key in ipairs(keys) do
        local rank = ranks:sub(2 * i - 1, 2 * i - 1)
        plan.known[key] = rank ~= "" and rank ~= UNKNOWN or nil
    end
end

local function OnBlessings(plan, ranks, given)
    Known(plan, BLESSINGS, ranks)
    plan.classes = {}
    for i, class in ipairs(CLASSES) do
        local key = BLESSINGS[tonumber(given:sub(i, i))]
        if key and plan.known[key] then plan.classes[class] = key end
    end
end

local function OnAuras(plan, ranks, given)
    Known(plan, AURAS, ranks)
    local key = AURAS[tonumber(given)]
    plan.aura = key and plan.known[key] and key or nil
end

local function Ends(left)
    left = tonumber(left)
    return left and left >= 0 and left <= MAX_COOLDOWN and GetTime() + left or nil
end

local function OnStatus(plan, symbols, loh, di)
    plan.status = { symbols = math.min(tonumber(symbols), MAX_SYMBOLS), loh = Ends(loh), di = Ends(di) }
end

function B.OnPallyPower(msg, sender)
    local ranks, given = msg:match("^SELF ([%xn]*)@([%dn]*)$")
    local auraRanks, aura = msg:match("^ASELF ([%xn]*)@([%dn]*)$")
    local symbols = msg:match("SYMCOUNT (%d+)")
    if not (ranks or auraRanks or symbols) then return end
    local from = B.Sender(sender)
    if not (from and from.class == "PALADIN") or from.guid == UnitGUID("player") then return end
    local plan = Plan(from.who)
    if not plan then return end
    if ranks then
        OnBlessings(plan, ranks, given)
    elseif auraRanks then
        OnAuras(plan, auraRanks, aura)
    else
        OnStatus(plan, symbols, msg:match("COOLDOWNS:[^:]*:([^:]*):[^:]*:([^:]*)$"))
    end
    RefreshPage()
end

function B.AskPallyPower()
    local channel = B.Channel()
    if not channel or InCombatLockdown() then return end
    local me = UnitGUID("player")
    for _, member in ipairs(B.Roster()) do
        if member.class == "PALADIN" and member.guid ~= me and not others[member.who] then
            C_ChatInfo.SendAddonMessage(PREFIX, ASK, channel)
            return
        end
    end
end

B.PALLYPOWER_PREFIX = PREFIX
