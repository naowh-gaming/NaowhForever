-- Search.lua: the search box at the top of the options window's sidebar.
local ns = _G.NaowhForever
local UI = ns.UI

local TEXT_SEARCH_HINT = "Search settings"

local function Words(text)
    return " " .. text:lower():gsub("[^%w]+", " ") .. " "
end

local function Typed(query)
    local typed = {}
    for word in Words(query):gmatch("%S+") do typed[#typed + 1] = word end
    return typed
end

local function Place(page, cardName)
    local parts = {}
    local mod = page.module
    if mod and #mod.tabs > 1 then parts[#parts + 1] = ns.L(page.name) end
    if cardName then parts[#parts + 1] = cardName end
    return ns.L(mod and mod.name or page.title or page.name), table.concat(parts, " / ")
end

local function Collect()
    local list = {}
    local Settings = ns.Shared and ns.Shared.Settings
    for _, page in ipairs(UI.SearchPages()) do
        local tag, trail = Place(page)
        local pageWords = Words(tag .. " " .. trail)
        list[#list + 1] = { page = page.key, tag = tag, trail = trail, words = pageWords }
        if Settings then
            Settings.Index(page.key, function(card, label, help, cardName, group)
                local t, where = Place(page, cardName)
                list[#list + 1] = { page = page.key, card = card, label = label, tag = t, trail = where,
                    isCard = cardName == nil,
                    words = Words(table.concat({ label, help or "", group or "", cardName or "" }, " ")) }
            end)
        end
    end
    return list
end

local function Matches(list, typed)
    local out = {}
    if #typed == 0 then return out end
    for _, target in ipairs(list) do
        local all = true
        for _, word in ipairs(typed) do
            if not target.words:find(" " .. word, 1, true) then all = false break end
        end
        if all then out[#out + 1] = target end
    end
    return out
end

local function Find(list, query)
    return Matches(list, Typed(query))
end

local function AddMatch(f, t)
    local key = t.page
    if not f.count[key] then
        f.count[key] = 0
        f.order[#f.order + 1] = key
    end
    if not t.card then
        f.all[key] = true
        return
    end
    f.count[key] = f.count[key] + 1
    f.first[key] = f.first[key] or t.card
    if t.isCard then
        f.cards[t.card] = true
    elseif f.cards[t.card] ~= true then
        local labels = f.cards[t.card] or {}
        labels[t.label] = true
        f.cards[t.card] = labels
    end
end

local function Build(list, query)
    local typed = Typed(query)
    if #typed == 0 then return nil end
    local f = { typed = typed, count = {}, all = {}, cards = {}, order = {}, first = {} }
    for _, t in ipairs(Matches(list, typed)) do AddMatch(f, t) end
    return f
end

local function StartsWord(lower, s)
    return s == 1 or not lower:sub(s - 1, s - 1):find("%w")
end

local function LitLetters(filter, lower)
    local lit
    for _, word in ipairs(filter.typed) do
        local from = 1
        while true do
            local s, e = lower:find(word, from, true)
            if not s then break end
            if StartsWord(lower, s) then
                lit = lit or {}
                for i = s, e do lit[i] = true end
            end
            from = s + 1
        end
    end
    return lit
end

local function Paint(text, lit)
    local out, i = {}, 1
    while i <= #text do
        local on, j = lit[i] == true, i
        while j < #text and (lit[j + 1] == true) == on do j = j + 1 end
        local piece = text:sub(i, j)
        out[#out + 1] = on and ns.Color("accent", piece) or piece
        i = j + 1
    end
    return table.concat(out)
end

local function Mark(filter, text)
    if not (filter and text) then return text end
    local lit = LitLetters(filter, text:lower())
    if not lit then return text end
    return Paint(text, lit)
end

UI.Search = { Collect = Collect, Find = Find, Build = Build, Mark = Mark }

local box, list, onFilter

local function OnText(text)
    if text:find("%S") then
        list = list or Collect()
        UI.filter = Build(list, text)
    else
        list, UI.filter = nil, nil
    end
    onFilter()
end

function UI.FocusSearch()
    box:SetFocus()
    box:HighlightText()
end

function UI.SearchTyped()
    return box:GetText() ~= ""
end

function UI.ClearSearch()
    if box:GetText() ~= "" then box:SetText("") end
    box:ClearFocus()
end

function UI.AttachSearchBox(parent, onChange, columns)
    onFilter = onChange
    box = ns.Shared.Parts.SearchBox(parent, TEXT_SEARCH_HINT, OnText, columns)
    UI:RegisterOnHide(UI.ClearSearch)
    return box
end
