-------------------------------------------------------------------------------
--  NaowhForever_Search.lua -- the find strip: every setting matching what is typed, stepped
--  through one at a time on its own page.
--  The first keystroke runs the page builders in scan mode (UI.searchScan): each row says
--  what it is called and builds nothing. `noscan` pages in Window.lua are found by module
--  and tab name only. Rows that only exist under some settings are found only while they exist.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local failed = {}           -- pages whose builder errored in the last scan (for /dump)

-- A parent that answers every call with 0. A builder that does more than call the row
-- widgets fails on it before it can build anything, and that page stays out of the index.
local STUB = setmetatable({}, { __index = function() return function() return 0 end end })

local function Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A section header without its colour codes and the status tag the page appended.
local function Plain(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return Trim(text)
end

local function Crumb(page)
    if page.module then return ns.L(page.module.name) .. " > " .. ns.L(page.name) end
    return ns.L(page.title or page.name)
end

-- feature is the W:Feature the setting sits under, which the jump opens; its name joins
-- the breadcrumb.
local function Entry(page, crumb, label, section, tooltip, feature, featureName)
    if featureName and featureName ~= label then crumb = crumb .. " > " .. Plain(featureName) end
    return { key = page.key, crumb = crumb, crumbLower = crumb:lower(),
        label = label, labelLower = label and label:lower(),
        sectionLower = section and section ~= "" and section:lower() or nil,
        tipLower = tooltip and tooltip:lower() or nil, feature = feature }
end

local function BuildIndex()
    local index = {}
    for i = #failed, 1, -1 do failed[i] = nil end
    local Settings = ns.Shared and ns.Shared.Settings
    for _, page in ipairs(UI.SearchPages()) do
        local crumb = Crumb(page)
        index[#index + 1] = Entry(page, crumb)
        local declared = Settings and Settings.Index(page.key, function(cardUid, label, help, cardName, group)
            index[#index + 1] = Entry(page, crumb, label, group, help, cardUid, cardName)
        end)
        if not declared and not (page.noscan or page.soon) and ns[page.build] then
            local scan = { section = "", items = {}, page = page.key }
            UI.searchScan = scan
            local ok = pcall(ns[page.build], STUB, -6, page.arg)
            UI.searchScan = nil
            -- What a page said before it failed still counts.
            for _, item in ipairs(scan.items) do
                index[#index + 1] = Entry(page, crumb, item.label, Plain(item.section), item.tooltip,
                    item.feature, item.featureName)
            end
            if not ok then failed[#failed + 1] = page.key end
        end
    end
    return index
end

-- Every word has to appear: in the setting's name (3), its section, tab or module (2), or
-- its tooltip (1). A page by name ranks just under a setting that scores the same.
local function Score(entry, words)
    local score = 0
    for _, word in ipairs(words) do
        if entry.labelLower and entry.labelLower:find(word, 1, true) then
            score = score + 3
        elseif entry.crumbLower:find(word, 1, true)
            or (entry.sectionLower and entry.sectionLower:find(word, 1, true)) then
            score = score + 2
        elseif entry.tipLower and entry.tipLower:find(word, 1, true) then
            score = score + 1
        else
            return nil
        end
    end
    return entry.label and score or score - 0.5
end

local function Match(index, query, limit)
    local words = {}
    for word in query:lower():gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return {} end
    local found = {}
    for i, entry in ipairs(index) do
        local score = Score(entry, words)
        if score then found[#found + 1] = { entry = entry, score = score, order = i } end
    end
    table.sort(found, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.order < b.order
    end)
    local out = {}
    for i = 1, math.min(#found, limit or #found) do out[i] = found[i].entry end
    return out
end

UI.Search = { Build = BuildIndex, Match = Match, Plain = Plain, failed = failed }

-------------------------------------------------------------------------------
--  The strip: docked under the page, above the footer. The input, a "3 of 12" counter and
--  Previous / Next on its first line; under them a chip per match, the current one lit.
-------------------------------------------------------------------------------
local STRIP_H, STRIP_PAD = 72, 10
local TOP_EDGE = 2          -- the accent line along the strip's top
local TAG_SIZE = 11         -- the FIND tag before the input
local INPUT_W, INPUT_H = 280, 26
local STEP_W, CLOSE_W, BUTTON_GAP = 72, 26, 6
local CHIP_H, CHIP_PAD, CHIP_GAP, CHIP_MAX_W = 22, 10, 6, 320
local CHIP_TEXT = 11
local CHIP_LIT = 0.16       -- the current chip's fill, in the accent

local strip, input, counter, measure
local chips = {}
local matches, widths = {}, {}
local current, first = 0, 1
local active                -- the index is built on the first keystroke after the strip opens

local function ChipText(entry)
    if not entry.label then return entry.crumb end
    return ns.Color("muted", entry.crumb .. " > ") .. entry.label
end

local function ChipWidth(i)
    if not widths[i] then
        measure:SetText(ChipText(matches[i]))
        widths[i] = math.min(measure:GetStringWidth() + CHIP_PAD * 2, CHIP_MAX_W)
    end
    return widths[i]
end

local function PaintChip(chip, hover)
    local lit = chip.index == current
    local edge = (lit or hover) and T.accent or T.line
    local fill = lit and T.accent or T.bg
    chip.edge:SetColor(edge.r, edge.g, edge.b, 1)
    chip.fill:SetColorTexture(fill.r, fill.g, fill.b, lit and CHIP_LIT or 1)
end

local Go

local function NewChip()
    local chip = CreateFrame("Button", nil, strip)
    chip:SetHeight(CHIP_H)
    chip.fill = ns.Solid(chip, "BACKGROUND", T.bg, 1)
    chip.fill:SetAllPoints()
    chip.edge = ns.Border(chip, T.line)
    chip.text = ns.Font(chip, CHIP_TEXT, nil)
    chip.text:SetPoint("LEFT", CHIP_PAD, 0)
    chip.text:SetPoint("RIGHT", -CHIP_PAD, 0)
    chip.text:SetJustifyH("LEFT")
    chip.text:SetWordWrap(false)
    chip:SetScript("OnClick", function(self) Go(self.index) end)
    chip:SetScript("OnEnter", function(self) PaintChip(self, true) end)
    chip:SetScript("OnLeave", function(self) PaintChip(self, false) end)
    return chip
end

-- The chips from `first` on, as many as fit; `first` moves only as far as it must to keep
-- the current chip in view.
local function DrawChips()
    local room = strip:GetWidth() - STRIP_PAD * 2
    if current > 0 then
        if current < first then first = current end
        local span = -CHIP_GAP
        for i = first, current do span = span + ChipWidth(i) + CHIP_GAP end
        while first < current and span > room do
            span = span - ChipWidth(first) - CHIP_GAP
            first = first + 1
        end
    end
    local x, shown = STRIP_PAD, 0
    for i = first, #matches do
        local w = ChipWidth(i)
        if x + w > STRIP_PAD + room and shown > 0 then break end
        shown = shown + 1
        local chip = chips[shown] or NewChip()
        chips[shown] = chip
        chip.index = i
        chip.text:SetText(ChipText(matches[i]))
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, STRIP_PAD)
        PaintChip(chip, false)
        chip:Show()
        x = x + w + CHIP_GAP
    end
    for i = shown + 1, #chips do chips[i]:Hide() end
    if current > 0 then
        counter:SetText(current .. " " .. ns.L("of") .. " " .. #matches)
    else
        counter:SetText(input:GetText() ~= "" and ns.L("No match") or "")
    end
end

-- The match is held open and marked only while the strip is up; GoToSetting scrolls to it.
function Go(i)
    current = i
    local entry = matches[i]
    local open = entry.feature and { [entry.feature] = true }
    if open then UI.MarkFeatureParents(open) end
    UI.searchOpen = open
    UI.searchFocus = { label = entry.label, feature = entry.feature }
    UI.GoToSetting(entry.key, entry.label, entry.feature)
    DrawChips()
end

local function Step(by)
    if #matches > 0 then Go((current - 1 + by) % #matches + 1) end
end

-- Every page a match was marked on is drawn again without it.
local function Unmark()
    if not (UI.searchFocus or UI.searchOpen) then return end
    UI.searchFocus, UI.searchOpen = nil, nil
    UI:RefreshPage(true)
end

local function OnText(text)
    text = Trim(text)
    matches, widths, current, first = {}, {}, 0, 1
    if text ~= "" then
        -- Built once per opening of the strip, so it matches the settings as they are now.
        if not active then
            active = true
            UI.searchIndex = BuildIndex()
        end
        matches = Match(UI.searchIndex, text)
    end
    if matches[1] then
        Go(1)
    else
        Unmark()
        DrawChips()
    end
end

-- The card holding the last match stays open, so the setting is still there to change.
function UI.CloseFind()
    local entry = matches[current]
    if entry then UI.RevealFeature(entry.key, entry.feature) end
    strip:Hide()
    input:ClearFocus()
    input:SetText("")
    active = false
end

function UI.OpenFind()
    strip:Show()
    input:SetFocus()
    input:HighlightText()
end

local function StepButton(text, by)
    return ns.Button(strip, text, STEP_W, INPUT_H, function() Step(by) end)
end

function UI.AttachFind(window, onLayout)
    strip = CreateFrame("Frame", nil, window)
    strip:SetHeight(STRIP_H)
    strip:SetFrameLevel(window:GetFrameLevel() + 20)
    strip:EnableMouse(true)
    strip:Hide()
    ns.Solid(strip, "BACKGROUND", T.panel, 1):SetAllPoints()
    local edge = ns.Solid(strip, "ARTWORK", T.accent, 1)
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("TOPRIGHT")
    edge:SetHeight(TOP_EDGE)
    input = ns.NewEditBox(strip)
    input:SetSize(INPUT_W, INPUT_H)
    input:SetScript("OnTextChanged", function(self) OnText(self:GetText()) end)
    input:SetScript("OnEnterPressed", function() Step(IsShiftKeyDown() and -1 or 1) end)
    input:SetScript("OnEscapePressed", UI.CloseFind)
    local tag = ns.Font(strip, TAG_SIZE, nil, T.accent)
    tag:SetPoint("TOPLEFT", STRIP_PAD, -STRIP_PAD)
    tag:SetHeight(INPUT_H)
    tag:SetText(ns.L("FIND"))
    input:SetPoint("LEFT", tag, "RIGHT", STRIP_PAD, 0)
    counter = ns.Font(strip, 12, nil, T.muted)
    counter:SetPoint("LEFT", input, "RIGHT", STRIP_PAD, 0)
    measure = ns.Font(strip, CHIP_TEXT, nil)
    measure:Hide()
    local close = ns.Button(strip, "X", CLOSE_W, INPUT_H, UI.CloseFind)
    close:SetPoint("TOPRIGHT", -STRIP_PAD, -STRIP_PAD)
    local nextButton = StepButton("Next", 1)
    nextButton:SetPoint("RIGHT", close, "LEFT", -BUTTON_GAP * 2, 0)
    StepButton("Previous", -1):SetPoint("RIGHT", nextButton, "LEFT", -BUTTON_GAP, 0)
    strip:SetScript("OnShow", onLayout)
    strip:SetScript("OnHide", function()
        Unmark()
        onLayout()
    end)
    strip:SetScript("OnSizeChanged", function() if strip:IsShown() then DrawChips() end end)
    UI:RegisterOnHide(UI.CloseFind)
    return strip
end
