-- Every setting search can reach, run against every module's real settings: its own name finds it first
-- among the names typed, on the page Categories.lua places it, with no two results that read the same; with
-- every module turned off, the generated index finds each one on the same page. Run with Lua 5.1 from the
-- repository root, with Libs/.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local Stub
local stubMeta = {}
stubMeta.__index = function(t, k)
    local v = Stub()
    rawset(t, k, v)
    return v
end
stubMeta.__call = function() return Stub() end
stubMeta.__tostring = function() return "" end
stubMeta.__concat = function(a, b)
    return (type(a) == "string" and a or "") .. (type(b) == "string" and b or "")
end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
    stubMeta[op] = function() return 0 end
end
stubMeta.__lt = function() return false end
stubMeta.__le = function() return false end
function Stub() return setmetatable({}, stubMeta) end

local off = {}
local env = setmetatable({}, { __index = function(t, k)
    local v = _G[k]
    if v ~= nil then return v end
    if k:find("^NaowhForever") then return nil end
    v = Stub()
    rawset(t, k, v)
    return v
end })
env._G = env
env.GetLocale = function() return "enUS" end
env.GetNumShapeshiftForms = function() return 0 end
env.C_AddOns = { IsAddOnLoaded = function(name) return not off[name] end,
    DoesAddOnExist = function(name) return io.open(name .. "/" .. name .. ".toc") ~= nil end,
    GetAddOnMetadata = function() return "" end, GetAddOnEnableState = function() return 2 end,
    LoadAddOn = function() return true end }
env.C_Item = { GetItemNameByID = function() return nil end }
env.MAX_PARTY_MEMBERS, env.MAX_RAID_MEMBERS = 4, 40
env.MerchantFrame = { IsShown = function() return false end }
env.ClassTrainerFrame = { IsShown = function() return false end }
env.C_ClassColor = { GetClassColor = function()
    return { WrapTextInColorCode = function(_, text) return text end }
end }
env.LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, class)
    return class:sub(1, 1) .. class:sub(2):lower()
end })
env.UnitClass = function() return "Paladin", "PALADIN" end

for _, path in ipairs(TocFiles("%.lua$")) do
    local skip = path:find("^Libs/") or path:find("SearchIndex%.lua$") or (path:find("Locales/") and path ~= "Core/Locales/enUS.lua")
    if not skip then
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk(path:match("^(NaowhForever_[^/]+)/") or "NaowhForever", rawget(env, "NaowhForever"))
    end
end

local ns = rawget(env, "NaowhForever")
local UI, O, Settings = ns.UI, ns.Options, ns.Shared.Settings
local Find = UI.Search.Find

local failures, checks = {}, 0
local function Check(ok, why)
    checks = checks + 1
    if not ok and #failures < 20 then failures[#failures + 1] = why end
end

local function Shown(t)
    return table.concat({ ns.L(t.label or t.tag), t.tag, t.trail or "" }, " | ")
end

local function NoTwins(matches, query)
    local seen = {}
    for _, m in ipairs(matches) do
        local shown = Shown(m)
        Check(not seen[shown], "'" .. query .. "' lists '" .. shown .. "' twice")
        seen[shown] = true
    end
end

-- What a player types: every word the results show, whole and by its first three letters. Each result
-- shows a typed word lit, in its name or the line under it, or holds it among its card's search words;
-- a result found only by its help is listed only when nothing shows the words. Each result's page counts it.
local Mark, Trail, Build = UI.Search.Mark, UI.Search.Trail, UI.Search.Build
local LIT = "<lit>"
local function Flat(text)
    return " " .. text:lower():gsub("[^%w\128-\255]+", " ") .. " "
end

local function Keyword(text, word)
    if text:find(" " .. word, 1, true) then return true end
    for _, plural in ipairs({ "^(.-)s$", "^(.-[sxz])es$", "^(.-[cs]h)es$" }) do
        local stem = word:match(plural)
        if stem and #stem >= 3 and text:find(" " .. stem, 1, true) then return true end
    end
    return false
end

local function Typing(list, where)
    local color = ns.Color
    ns.Color = function(_, text) return LIT .. text end
    local queries = {}
    for _, t in ipairs(list) do
        for w in Flat(ns.L(t.label or t.tag) .. " " .. Trail(t, nil)):gmatch("%S+") do
            if #w >= 2 then
                queries[w] = true
                if #w > 3 then queries[w:sub(1, 3)] = true end
            end
        end
    end
    local typed = 0
    for q in pairs(queries) do
        typed = typed + 1
        local filter, matches, unlit, lit = Build(list, q), Find(list, q), {}, false
        for _, m in ipairs(matches) do
            local shown = Mark(filter, ns.L(m.label or m.tag)) .. Trail(m, filter)
            if shown:find(LIT, 1, true) then
                lit = true
            elseif not Keyword(m.seen or "", q) then
                unlit[#unlit + 1] = m
            end
            Check(filter.count[m.page] or filter.all[m.page],
                "'" .. q .. "' lists " .. Shown(m) .. " but its page does not count it" .. where)
        end
        for _, m in ipairs(lit and unlit or {}) do
            Check(false, "'" .. q .. "' lists " .. Shown(m) .. " with no typed word in sight" .. where)
        end
        NoTwins(matches, q)
    end
    ns.Color = color
    Check(typed > 1000, "every word the results show is typed, " .. typed .. where)
end

-- Every module on: each card and setting by its own name.
local list = UI.Search.Collect()
local entries = 0
for _, page in ipairs(UI.SearchPages()) do
    Settings.Index(page.key, function(card, label)
        if type(label) ~= "string" then return end
        entries = entries + 1
        local matches = Find(list, label)
        local at
        for i, m in ipairs(matches) do
            if m.card == card and m.label == label and m.page == page.key then at = i break end
        end
        Check(at ~= nil, "'" .. label .. "' is not found on " .. page.key)
        Check(not at or matches[at].named == 2, "'" .. label .. "' is not ranked as its own name")
        Check(O.IsModuleCard(card) or O.NavPage(card) == page.key,
            card .. " is shown on " .. page.key .. " but a jump lands on " .. tostring((O.NavPage(card))))
        NoTwins(matches, label)
    end)
end
Check(entries > 1500, "every module's settings are searched, " .. entries .. " found")

for _, cat in ipairs(O.CATEGORIES) do
    for _, page in ipairs(cat.pages) do
        local found = false
        for _, m in ipairs(Find(list, cat.name .. " " .. page.name)) do found = found or m.page == page.key end
        Check(found, page.key .. " is not found by its name")
    end
end
for _, mod in ipairs(O.MODULES) do
    local matches = Find(list, O.DisplayName(mod))
    Check(#matches > 0, O.DisplayName(mod) .. " is not found by its name")
    local card, switch = false, false
    for _, m in ipairs(matches) do
        card = card or (m.card ~= nil and ns.L(m.label or "") == O.DisplayName(mod))
        switch = switch or (m.page == "Settings" and m.trail == "MODULES" and ns.L(m.label or "") == O.DisplayName(mod))
    end
    Check(not (card and switch), O.DisplayName(mod) .. " lists its card and its Settings > Modules switch")
end

-- A word only a setting's help holds lists it only when nothing shows the word: "real" is not "realm".
for _, m in ipairs(Find(list, "real")) do
    Check(not (m.label or ""):find("Alt") and not (m.label or ""):find("Scan"), "'real' lists " .. tostring(m.label))
end

-- A plural finds what is named in the singular.
Check(#Find(list, "minimap buttons") > 0 and #Find(list, "reminders") > 0, "a plural finds the singular")
Typing(list, "")

-- A card one module declares on another's page: the module lists it, and with that module off the page
-- shows the module's own card in its place and search finds the card's settings there.
local built, declaredBy = dofile("Tools/build/search_index.lua")
local index = assert(loadstring(built, "SearchIndex.lua"))
setfenv(index, env)
index()

local function ModuleOf(path)
    local best, bestLen
    for _, mod in ipairs(O.MODULES) do
        if mod.addon then
            local folder = mod.host and (mod.host .. "/" .. mod.addon:gsub("^NaowhForever_", "") .. "/") or (mod.addon .. "/")
            if path:sub(1, #folder) == folder and (not bestLen or #folder > bestLen) then best, bestLen = mod, #folder end
        end
    end
    return best
end

local listed = {}
for _, mod in ipairs(O.MODULES) do
    for _, uid in ipairs(mod.cards or {}) do listed[uid] = mod end
end
local lentCount = 0
for uid, path in pairs(declaredBy) do
    local pageKey = uid:match("^(.-):[^:]+$")
    local owner, by = pageKey and O.PAGES[pageKey] and O.PAGES[pageKey].module, ModuleOf(path)
    if owner and by and owner ~= by then
        lentCount = lentCount + 1
        Check(listed[uid] == by, uid .. " is declared by " .. by.name .. " on " .. owner.name
            .. "'s page: list it in that module's cards in Core/Options/Modules.lua")
    end
end
Check(lentCount >= 3, "cards declared on another module's page are found, " .. lentCount)

local function Holds(items, uid)
    for _, item in ipairs(items or {}) do
        if item.uid == uid then return true end
    end
    return false
end

for uid, mod in pairs(listed) do
    local pageKey, id = uid:match("^(.-):([^:]+)$")
    local page = O.NavPage(uid)
    Check(page ~= nil, uid .. " is placed on no page")
    off[mod.host or mod.addon] = true
    local composed
    local Compose = Settings.Compose
    Settings.Compose = function(key, items) if key == page then composed = items end return Compose(key, items) end
    O.Compose(O.PAGES[page])
    Settings.Compose = Compose
    Check(Holds(composed, O.ModuleCardUid(mod)) and not Holds(composed, uid),
        uid .. ": with " .. mod.name .. " off, " .. tostring(page) .. " shows its module card instead")
    Check(#mod.tabs > 0 or O.NavPage(mod.name) == page, mod.name .. ": its name opens " .. tostring(page))
    list = UI.Search.Collect()
    local labels = 0
    for _, e in ipairs(ns.SEARCH_INDEX[pageKey] or {}) do
        if e[1] == id then
            labels = labels + 1
            local label, found = e[2] or e[4], false
            for _, m in ipairs(Find(list, label)) do
                found = found or (m.page == page and m.card == O.ModuleCardUid(mod) and m.label == label)
            end
            Check(found, "'" .. label .. "' of " .. uid .. ", " .. mod.name .. " off, is not found on " .. tostring(page))
        end
    end
    Check(labels > 0, uid .. " has settings in the index")
    off[mod.host or mod.addon] = nil
end

-- Every module off: the generated index, one result per setting, on the page it is placed on.
for _, mod in ipairs(O.MODULES) do
    if mod.addon then off[mod.host or mod.addon] = true end
end
list = UI.Search.Collect()
local offEntries = 0
for _, mod in ipairs(O.MODULES) do
    for _, tab in ipairs(mod.tabs) do
        for _, e in ipairs(ns.SEARCH_INDEX[tab.key] or {}) do
            offEntries = offEntries + 1
            local label, page = e[2] or e[4], O.NavPage(tab.key .. ":" .. e[1])
            Check(page ~= nil, tab.key .. ":" .. e[1] .. " is placed on no page")
            local matches, found = Find(list, label), false
            for _, m in ipairs(matches) do
                found = found or (m.page == page and m.card == O.ModuleCardUid(mod) and m.label == label)
            end
            Check(found, "'" .. label .. "' of " .. mod.name .. ", turned off, is not found on " .. tostring(page))
            NoTwins(matches, label)
        end
    end
end
Check(offEntries > 1000, "every turned-off module's settings are searched, " .. offEntries .. " found")
Typing(list, ", every module off")

assert(#failures == 0, table.concat(failures, "\n"))
print(("PASS search audit: %d checks, %d settings on, %d off"):format(checks, entries, offEntries))
