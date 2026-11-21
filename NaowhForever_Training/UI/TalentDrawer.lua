-- TalentDrawer.lua: the side panel beside a talent window (build picker, next talents, glow switch) and its button.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Next = Training.Next

local PAD = 4
local ROW_H, BIG_H, PICK_H = 28, 48, 40
local GROUP_SIZE, NOTE_SIZE, NAME_SIZE, SMALL_SIZE = 11, 12, 13, 11
local GROUP_DROP, NOTE_PAD, LABEL_GAP = 7, 7, 8
local BIG_ICON, SMALL_ICON, ICON_GAP, ICON_CROP = 30, 16, 10, 0.08
local BIG_TEXT_DROP = 1
local RULE_ALPHA = 0.6
local CONTROL_LEVEL = 2
local UNDER_SEARCH, SEARCH_LEVEL = 64, 2
local BUTTON_SIZE, BUTTON_LOGO_INSET, BUTTON_ALPHA = 32, 4, 0.9
local NO_SEARCH_X, NO_SEARCH_Y, NO_SEARCH_LEVEL = -30, -4, 20
local MAX_FRAME_LEVEL = 9000
local GLOW_KEY = "nextTalentGlow"
local TEXT_BUILD = ns.Upper(ns.L("Build"))
local TEXT_NEXT = ns.Upper(ns.L("Next Talent"))
local TEXT_THEN = ns.Upper(ns.L("Then"))
local TEXT_PROGRESS = ns.Upper(ns.L("Progress"))
local TEXT_OPTIONS = ns.Upper(ns.L("Options"))
local TEXT_PICK = ns.L("Build to Light")
local TEXT_PICK_TIP = ns.L("Lights this build's next talent without following it, so no points are spent for you.")
local TEXT_FOLLOWED = ns.L("%s (followed)")
local TEXT_NO_PICK = ns.L("No build picked")
local TEXT_GLOW = ns.L("Glow on the Next Talent")
local TEXT_GLOW_TIP = ns.L("A glow around the next talent's button that pulses while you have a point to spend.")
local TEXT_SHOW_HIDE = ns.L("Show or hide this panel.")

local shown = {}
local summaryPieces = {}

local function LevelAbove(frame, steps)
    return math.min(frame:GetFrameLevel() + steps, MAX_FRAME_LEVEL)
end

local function NewBody(scroll)
    return CreateFrame("Frame", nil, scroll)
end

local function FullOpacity()
    return 1
end

local function GlowOn()
    return S.Get(GLOW_KEY)
end

local function SetGlow(on)
    S.Set(GLOW_KEY, on)
end

local function SpellTip(strip)
    if not strip.spellID then return end
    GameTooltip:SetOwner(strip, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(strip.spellID)
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function NewStrip(view, height)
    local strip = CreateFrame("Frame", nil, view.body)
    strip:SetHeight(height)
    strip.height = height
    strip:Hide()
    local rule = ns.Solid(strip, "ARTWORK", T.line, RULE_ALPHA)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    ns.Hairline(rule, "h")
    view.strips[#view.strips + 1] = strip
    return strip
end

local function NewGroup(view, title)
    local strip = NewStrip(view, ROW_H)
    local text = ns.Font(strip, GROUP_SIZE, nil, T.accentSoft)
    text:SetPoint("BOTTOMLEFT", PAD, GROUP_DROP)
    text:SetText(title)
    return strip
end

local function NewNote(view)
    local strip = NewStrip(view, ROW_H)
    strip.text = ns.Font(strip, NOTE_SIZE, nil, T.fg)
    strip.text:SetWidth(view.body:GetWidth() - PAD * 2)
    strip.text:SetJustifyH("LEFT")
    strip.text:SetWordWrap(true)
    strip.text:SetPoint("TOPLEFT", PAD, -NOTE_PAD)
    return strip
end

local function SetNote(strip, text)
    strip.text:SetText(text)
    local textHeight = math.ceil(strip.text:GetStringHeight())
    strip.height = math.max(ROW_H, textHeight + NOTE_PAD * 2)
end

local function NewTalentRow(view, big)
    local rowHeight = ROW_H
    local iconSize = SMALL_ICON
    if big then
        rowHeight = BIG_H
        iconSize = BIG_ICON
    end
    local strip = NewStrip(view, rowHeight)
    strip:EnableMouse(true)
    strip:SetScript("OnEnter", SpellTip)
    strip:SetScript("OnLeave", HideTip)
    strip.icon = strip:CreateTexture(nil, "ARTWORK")
    strip.icon:SetSize(iconSize, iconSize)
    strip.icon:SetPoint("LEFT", PAD, 0)
    strip.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    strip.name = ns.Font(strip, NAME_SIZE, nil, T.fg)
    strip.name:SetJustifyH("LEFT")
    strip.name:SetWordWrap(false)
    if big then
        local textTop = (BIG_H - BIG_ICON) / 2 + BIG_TEXT_DROP
        local textLeft = PAD + BIG_ICON + ICON_GAP
        strip.name:SetPoint("TOPLEFT", textLeft, -textTop)
        strip.name:SetPoint("TOPRIGHT", -PAD, -textTop)
        strip.sub = ns.Font(strip, SMALL_SIZE, nil, T.muted)
        strip.sub:SetJustifyH("LEFT")
        strip.sub:SetWordWrap(false)
        strip.sub:SetPoint("BOTTOMLEFT", textLeft, textTop)
        strip.sub:SetPoint("BOTTOMRIGHT", -PAD, textTop)
    else
        strip.when = ns.Font(strip, SMALL_SIZE, nil, T.muted)
        strip.when:SetJustifyH("RIGHT")
        strip.when:SetPoint("RIGHT", -PAD, 0)
        strip.name:SetPoint("LEFT", strip.icon, "RIGHT", LABEL_GAP, 0)
        strip.name:SetPoint("RIGHT", strip.when, "LEFT", -LABEL_GAP, 0)
    end
    return strip
end

local function FillTalentRow(strip, row)
    strip.spellID = row.spellID
    strip.icon:SetTexture(row.icon)
    strip.name:SetText(row.name)
    if strip.sub then
        strip.sub:SetText(row.sub)
    else
        strip.when:SetText(row.when)
    end
end

local function NewPicker(view)
    local strip = NewStrip(view, PICK_H)
    view.values = {}
    view.order = {}
    local function Picked()
        return view.pickKey
    end
    local level = LevelAbove(strip, CONTROL_LEVEL)
    local dropdown = UI.BuildDropdownControl(strip, nil, level, view.values, view.order, Picked, Next.SetPick)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("LEFT", PAD, 0)
    dropdown:SetPoint("RIGHT", -PAD, 0)
    ns.Tooltip(dropdown, TEXT_PICK, TEXT_PICK_TIP)
    strip.dropdown = dropdown
    return strip
end

local function RefreshPicker(view, model)
    local values = view.values
    local order = view.order
    wipe(values)
    wipe(order)
    for _, build in ipairs(model.builds) do
        local key = Training.BuildKey(model.classID, build)
        values[key] = Next.BuildLabel(build)
        order[#order + 1] = key
    end
    if model.followed then
        values[Next.FOLLOWED] = TEXT_FOLLOWED:format(Next.BuildLabel(model.followed))
    else
        values[Next.FOLLOWED] = TEXT_NO_PICK
    end
    order[#order + 1] = Next.FOLLOWED
    view.pickKey = model.pickKey
    view.parts.picker.dropdown._refreshLabel()
end

local function NewGlowRow(view)
    local strip = NewStrip(view, ROW_H)
    strip:EnableMouse(true)
    local toggle = UI.BuildToggleControl(strip, LevelAbove(strip, CONTROL_LEVEL), GlowOn, SetGlow)
    toggle:SetPoint("RIGHT", -PAD, 0)
    local label = ns.Font(strip, NAME_SIZE, nil, T.fg)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetPoint("LEFT", PAD, 0)
    label:SetPoint("RIGHT", toggle, "LEFT", -LABEL_GAP, 0)
    label:SetText(TEXT_GLOW)
    ns.Tooltip(strip, TEXT_GLOW, TEXT_GLOW_TIP)
    strip.toggle = toggle
    return strip
end

local function BuildPanel(view)
    local panel = Parts.SidePanel({}, NewBody, FullOpacity)
    panel:Hide()
    panel.title:SetText(view.title)
    panel.close._onClick = function()
        S.Set(view.openKey, false)
    end
    view.panel = panel
    view.body = panel.view
    view.strips = {}
    local parts = {}
    view.parts = parts
    parts.buildGroup = NewGroup(view, TEXT_BUILD)
    parts.picker = NewPicker(view)
    parts.nextGroup = NewGroup(view, TEXT_NEXT)
    parts.notice = NewNote(view)
    parts.big = NewTalentRow(view, true)
    parts.thenGroup = NewGroup(view, TEXT_THEN)
    parts.small = {}
    for place = 1, Next.UPCOMING - 1 do
        parts.small[place] = NewTalentRow(view, false)
    end
    parts.progressGroup = NewGroup(view, TEXT_PROGRESS)
    parts.progress = NewNote(view)
    parts.extra = NewNote(view)
    parts.follow = NewNote(view)
    parts.optionsGroup = NewGroup(view, TEXT_OPTIONS)
    parts.glowRow = NewGlowRow(view)
end

local function Add(strip)
    shown[#shown + 1] = strip
end

local function AddNote(strip, text)
    if not text then return end
    SetNote(strip, text)
    Add(strip)
end

local function Stack(view)
    for _, strip in ipairs(view.strips) do
        strip:Hide()
    end
    local offset = 0
    for _, strip in ipairs(shown) do
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", view.body, "TOPLEFT", 0, -offset)
        strip:SetPoint("TOPRIGHT", view.body, "TOPRIGHT", 0, -offset)
        strip:SetHeight(strip.height)
        strip:Show()
        offset = offset + strip.height
    end
    view.body:SetHeight(math.max(offset, 1))
end

local function AddTalents(parts, model)
    Add(parts.nextGroup)
    if model.notice then
        AddNote(parts.notice, model.notice)
    elseif model.count > 0 then
        FillTalentRow(parts.big, model.rows[1])
        Add(parts.big)
    end
    local rest = model.count - 1
    if rest < 1 then return end
    Add(parts.thenGroup)
    for place = 1, rest do
        local strip = parts.small[place]
        FillTalentRow(strip, model.rows[place + 1])
        Add(strip)
    end
end

local function PaintBorder(button, lit)
    local color = Style.BORDER_RGB
    if lit then color = T.accent end
    button.border:SetColor(color.r, color.g, color.b, 1)
end

local function ButtonClicked(button)
    local key = button.view.openKey
    S.Set(key, not S.Get(key))
end

local function ButtonEnter(button)
    PaintBorder(button, true)
end

local function ButtonLeave(button)
    PaintBorder(button, S.Get(button.view.openKey))
end

local function NewButton(view, parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    local background = ns.Solid(button, "BACKGROUND", T.bg, BUTTON_ALPHA)
    background:SetAllPoints()
    button.border = ns.Border(button, Style.BORDER_RGB)
    local logo = button:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO_SMALL)
    logo:SetPoint("TOPLEFT", BUTTON_LOGO_INSET, -BUTTON_LOGO_INSET)
    logo:SetPoint("BOTTOMRIGHT", -BUTTON_LOGO_INSET, BUTTON_LOGO_INSET)
    button.view = view
    button:SetScript("OnClick", ButtonClicked)
    button:SetScript("OnEnter", ButtonEnter)
    button:SetScript("OnLeave", ButtonLeave)
    ns.Tooltip(button, view.title, TEXT_SHOW_HIDE)
    view.button = button
end

local function AddPiece(piece)
    if piece == nil then
        summaryPieces[#summaryPieces + 1] = ""
    else
        summaryPieces[#summaryPieces + 1] = tostring(piece)
    end
end

function Next.DrawerSummary(model)
    wipe(summaryPieces)
    AddPiece(model.pickKey)
    if model.builds then
        AddPiece(#model.builds)
    else
        AddPiece(nil)
    end
    AddPiece(model.notice)
    AddPiece(model.progress)
    AddPiece(model.extra)
    AddPiece(model.follow)
    AddPiece(GlowOn())
    for place = 1, model.count do
        local row = model.rows[place]
        AddPiece(row.icon)
        AddPiece(row.name)
        AddPiece(row.sub)
        AddPiece(row.when)
    end
    return table.concat(summaryPieces, ";")
end

function Next.PaintDrawer(view, model)
    if not view.panel then BuildPanel(view) end
    local parts = view.parts
    wipe(shown)
    RefreshPicker(view, model)
    Add(parts.buildGroup)
    Add(parts.picker)
    AddTalents(parts, model)
    if model.progress or model.extra or model.follow then
        Add(parts.progressGroup)
        AddNote(parts.progress, model.progress)
        AddNote(parts.extra, model.extra)
        AddNote(parts.follow, model.follow)
    end
    Add(parts.optionsGroup)
    parts.glowRow.toggle._refreshValue()
    Add(parts.glowRow)
    Stack(view)
end

function Next.ShowDrawer(view, window)
    if view.panel:IsShown() then return end
    Parts.ShowBeside(view.panel, window.outer)
end

function Next.HideDrawer(view, alsoButton)
    if view.panel then view.panel:Hide() end
    if alsoButton and view.button then view.button:Hide() end
end

function Next.PaintButton(view)
    local button = view.button
    if not button then return end
    local lit = S.Get(view.openKey) or button:IsMouseOver()
    PaintBorder(button, lit)
end

function Next.Dock(view, window)
    if not view.button then NewButton(view, window.content) end
    local button = view.button
    button:SetParent(window.content)
    button:ClearAllPoints()
    local search = window.search
    if search then
        button:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -UNDER_SEARCH)
        button:SetFrameLevel(LevelAbove(search, SEARCH_LEVEL))
    else
        button:SetPoint("TOPRIGHT", window.outer, "TOPRIGHT", NO_SEARCH_X, NO_SEARCH_Y)
        button:SetFrameLevel(LevelAbove(window.outer, NO_SEARCH_LEVEL))
    end
    Next.PaintButton(view)
    button:Show()
end
