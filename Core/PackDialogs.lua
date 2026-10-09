-- PackDialogs.lua: the Reminder Pack dialogs: share, diagnostic trace, merge and import.
local ns = _G.NaowhForever
if not ns then return end

local PAD = 14
local TITLE_SIZE = 14
local LABEL_SIZE = 12
local BOX_RIGHT = 34
local RAISE = 10
local TOGGLE_GAP = 8
local SPEC_TOGGLE_W, SPEC_TOGGLE_H = 28, 14
local BUTTON_H = 26
local CLOSE_W, ACTION_W, ACTION_SHIFT = 110, 130, 70
local NAME_H = 22
local OPTION_H = 22
local SELECT_W, DESELECT_W, SELECT_GAP = 84, 96, 6
local UNKNOWN_ORDER, UNKNOWN_ROLE = 99, 9
local EXPORT_LAYOUT = { w = 560, minH = 392, nameW = 300, nameY = 44, hintGap = 10, boxY = 78, boxH = 180,
    statusGap = 14, closeGap = 10, bottom = 16 }
local DIAG_LAYOUT = { w = 620, h = 420, hintGap = 6, boxY = 56, boxH = 300 }
local MERGE_LAYOUT = { w = 620, h = 560, boxY = 40, boxH = 110, previewY = 158, rowsY = 192, pickerW = 280,
    pickerH = 44, pickerDropY = 20, pickerStep = 50, targetStep = 54, headW = 560, headH = 16, headStep = 20,
    selectH = 20, selectRise = 2, cols = 3, colW = 188, rowH = 22, gridGap = 8, optionW = 460, optionStep = 24,
    bottom = 78, dim = 0.4 }
local IMPORT_LAYOUT = { w = 700, h = 470, boxY = 40, boxH = 150, previewY = 200, headGap = 12, cols = 3,
    colW = 220, rowH = 28, specRowH = 22, specInset = 6, specLabelGap = 6, settingsW = 320, bindW = 380,
    accountW = 420, settingsGap = 10, optionGap = 6, nameBoxW = 260, nameGap = 16, nameLabelGap = 8,
    overwriteGap = 12, selectNameGap = 12, bottom = 74, dim = 0.35 }
local DEFAULT_PROFILE = "Default"
local IMPORTED_PROFILE = "Imported Profile"
local ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
local ROLE_SORT = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local COLOR_ERROR = "|cffff6060"
local TEXT_SPEC_ROLE = "%s (%s)"
local TEXT_SELECT_ALL, TEXT_DESELECT_ALL = "Select All", "Deselect All"
local TEXT_CLOSE, TEXT_CANCEL = "Close", "Cancel"
local TEXT_SHARE_TITLE = "Share your Profile"
local TEXT_DEFAULT_PACK = "My Reminder Pack"
local TEXT_PACK_NAME_HINT = "pack name, shown on import"
local TEXT_EXPORTED = "%d characters%s. Click the text, then Ctrl+A Ctrl+C."
local TEXT_COVERING = " covering "
local TEXT_DIAG_TITLE = "Diagnostic Trace"
local TEXT_DIAG_HINT = "Click the text, then Ctrl+A Ctrl+C, and paste it to whoever asked."
local TEXT_MERGE_TITLE = "Merge a Profile Into Yours"
local TEXT_PASTE_THEIRS = "Paste their profile string above."
local TEXT_TAKE_PROFILE = "Take which of their profiles"
local TEXT_MERGE_INTO = "Merge it into"
local TEXT_TAKE_SPECS, TEXT_NO_SPECS = "Take which specs", "Their string names no specs"
local TEXT_TAKE_SETTINGS = "Also take their display, sound and behaviour settings"
local TEXT_TAKE_EXTRAS = "Also take their raid reminders and callout lines"
local TEXT_EXTRAS_TITLE = "Raid reminders and callout lines"
local TEXT_EXTRAS_HELP = "Neither records a spec, so a spec handover leaves them alone. Tick this only "
    .. "when you want theirs in place of yours."
local TEXT_READY = "Ready to merge."
local TEXT_UNREADABLE = "That string could not be read."
local TEXT_MERGE = "Merge"
local TEXT_IMPORT_TITLE = "Import Profile"
local TEXT_PASTE_PACK = "Paste a pack string above."
local TEXT_WHICH_PROFILES, TEXT_WHICH_ITEMS = "Bring in which profiles:", "Bring in which of these:"
local TEXT_THEIR_SETTINGS = "Their display, sound and behaviour settings"
local TEXT_BIND = "Use each on the character whose spec it covers"
local TEXT_ALL_CHARACTERS = "Use it on all %d characters on this account, and new ones"
local TEXT_EVERY_CHARACTER = "Use it on every character on this account, and new ones"
local TEXT_SAVE_AS = "Save as:"
local TEXT_REPLACE = "Replace the existing profile '%s' instead of making a copy"
local TEXT_IMPORT = "Import"
local TEXT_PICK_PROFILE = COLOR_ERROR .. "Pick at least one profile to bring in.|r"
local TEXT_PICK_ONE = COLOR_ERROR .. "Pick at least one to bring in.|r"
local TEXT_NOT_APPLIED = COLOR_ERROR .. "The pack could not be applied.|r"
local TEXT_PROFILES_IMPORTED = "%d profile%s imported.%s"
local TEXT_EACH_SPEC = " Each character will load the one for its spec."
local TEXT_PICK_ACTIVE = " Pick one under Active Profile."
local TEXT_IMPORTED_ALL = "imported as the profile '%s'. %s on this account use%s it now, and any you log into "
    .. "later will too. Switching a single character afterwards moves only that one.%s"
local TEXT_ONE_CHARACTER, TEXT_N_CHARACTERS = "The one character", "All %d characters"
local TEXT_AUTO_OFF = " Per-spec profile switching is off while they share one profile; your spec choices "
    .. "are kept if you switch it back on."
local TEXT_REPLACED = "replaced the profile '%s' with this pack, and switched to it."
local TEXT_IMPORTED_AS = "imported as the profile '%s', and switched to it. Your own profile is untouched -- "
    .. "switch back to it any time."

local classLookup
local packExport, packImport, diagExport, profileMerge

local function ByLower(a, b) return a:lower() < b:lower() end
local function ClearFocus(self) self:ClearFocus() end
local function SetFocus(self) self:SetFocus() end
local function HighlightText(self) self:HighlightText() end

local function ErrorText(text)
    return COLOR_ERROR .. tostring(text) .. "|r"
end

local function RefreshOptions()
    local UI = ns.UI
    if UI and UI.RefreshPage then UI:RefreshPage(true) end
end

local function Title(panel, text)
    local title = ns.Font(panel, TITLE_SIZE, "OUTLINE")
    title:SetPoint("TOP", panel, "TOP", 0, -PAD)
    title:SetText(text)
    return title
end

local function LandedNames(profiles)
    local names = {}
    for name in pairs(profiles) do
        if name ~= DEFAULT_PROFILE then names[#names + 1] = name end
    end
    table.sort(names, ByLower)
    return names
end

local function SpecInfo(specKey)
    local id = tonumber(specKey)
    if not (id and GetSpecializationInfoByID) then return nil, nil, nil end
    local ok, _, name, _, _, role, _, className = pcall(GetSpecializationInfoByID, id)
    if not ok then return nil, nil, nil end
    return name, className, role
end

local function ClassInfo(className)
    if not classLookup then
        classLookup = {}
        if GetNumClasses and GetClassInfo then
            for i = 1, GetNumClasses() do
                local displayName, token = GetClassInfo(i)
                if displayName and token then
                    classLookup[displayName] = { token = token, order = i }
                end
            end
        end
    end
    return className and classLookup[className]
end

local function BySpec(a, b)
    local ca, cb = ClassInfo(a.className), ClassInfo(b.className)
    local oa, ob = ca and ca.order or UNKNOWN_ORDER, cb and cb.order or UNKNOWN_ORDER
    if oa ~= ob then return oa < ob end
    local ra, rb = ROLE_SORT[a.role] or UNKNOWN_ROLE, ROLE_SORT[b.role] or UNKNOWN_ROLE
    if ra ~= rb then return ra < rb end
    return a.name < b.name
end

local function SortSpecs(specs)
    for i = 1, #specs do
        specs[i].specName, specs[i].className, specs[i].role = SpecInfo(specs[i].key)
    end
    table.sort(specs, BySpec)
    return specs
end

local function PaintSpecLabel(label, spec)
    if spec.specName and spec.role then
        label:SetText(TEXT_SPEC_ROLE:format(spec.specName, ROLE_LABEL[spec.role] or spec.role))
    else
        label:SetText(spec.name)
    end
    local classColors = RAID_CLASS_COLORS or CUSTOM_CLASS_COLORS
    local ci = spec.className and ClassInfo(spec.className)
    local color = (ci and classColors and classColors[ci.token]) or ns.THEME.fg
    label:SetTextColor(color.r, color.g, color.b, 1)
end

function ns.MakeMultilineBox(panel, topOffset, height)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, topOffset)
    scroll:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -BOX_RIGHT, topOffset)
    scroll:SetHeight(height)
    ns.Solid(scroll, "BACKGROUND", ns.THEME.bg, 1):SetAllPoints()
    ns.Border(scroll)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetWidth(1)
    box:SetHeight(height)
    box:SetScript("OnEscapePressed", ClearFocus)
    scroll:SetScrollChild(box)
    scroll:SetScript("OnSizeChanged", function(_, w) box:SetWidth(w) end)

    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
    return box
end

local function MakeToggleRow(parent, w, h, frameLevel, get, set, toggleW, toggleH)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(w, h)
    if frameLevel then row:SetFrameLevel(frameLevel) end
    row.toggle = ns.UI.BuildToggleControl(row, row:GetFrameLevel() + 1, get, set,
        toggleW, toggleH)
    row.toggle:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label = ns.Font(row, LABEL_SIZE, nil)
    row.label:SetPoint("LEFT", row.toggle, "RIGHT", TOGGLE_GAP, 0)
    return row
end

local function NameBox(panel, width)
    local nameBox = CreateFrame("EditBox", nil, panel)
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject("GameFontHighlight")
    nameBox:SetSize(width, NAME_H)
    return nameBox
end

local function StyleNameBox(nameBox)
    nameBox:SetTextColor(ns.THEME.accent.r, ns.THEME.accent.g, ns.THEME.accent.b, 1)
    ns.Solid(nameBox, "BACKGROUND", ns.THEME.line, 1):SetAllPoints()
end

local function ExportedSpecs()
    local db = ns.DB()
    local specs = ns.PackSpecs({ data = { presets = db.presets, activePreset = db.activePreset,
        bossLists = db.bossLists, abilityBindings = db.abilityBindings } })
    local names
    for i = 1, #specs do
        names = names and (names .. ", " .. specs[i].name) or specs[i].name
    end
    return names
end

local function Regenerate(exp)
    local str, err = ns.ExportPack(exp.nameBox:GetText(), UnitName and UnitName("player"))
    if str then
        exp.box:SetText(str)
        local names = ExportedSpecs()
        exp.status:SetText(TEXT_EXPORTED:format(#str, names and (TEXT_COVERING .. names) or ""))
    else
        exp.box:SetText("")
        exp.status:SetText(ErrorText(err))
    end
    if exp.closeBtn then
        local needed = EXPORT_LAYOUT.boxY + EXPORT_LAYOUT.boxH + EXPORT_LAYOUT.statusGap + exp.status:GetHeight() + EXPORT_LAYOUT.closeGap
            + exp.closeBtn:GetHeight() + EXPORT_LAYOUT.bottom
        exp.panel:SetHeight(math.max(EXPORT_LAYOUT.minH, needed))
    end
end

local function ExportNameBox(panel)
    local nameBox = NameBox(panel, EXPORT_LAYOUT.nameW)
    nameBox:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -EXPORT_LAYOUT.nameY)
    nameBox:SetText(TEXT_DEFAULT_PACK)
    StyleNameBox(nameBox)
    nameBox:SetScript("OnEscapePressed", ClearFocus)
    nameBox:EnableMouse(true)
    nameBox:SetScript("OnMouseDown", SetFocus)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", nameBox, "RIGHT", EXPORT_LAYOUT.hintGap, 0)
    hint:SetText(TEXT_PACK_NAME_HINT)
    return nameBox
end

local function BuildPackExport()
    local dimmer, panel = ns.MakeModal(EXPORT_LAYOUT.w, EXPORT_LAYOUT.minH, "packExport")
    Title(panel, TEXT_SHARE_TITLE)
    local exp = { dimmer = dimmer, panel = panel }
    exp.nameBox = ExportNameBox(panel)
    exp.box = ns.MakeMultilineBox(panel, -EXPORT_LAYOUT.boxY, EXPORT_LAYOUT.boxH)
    exp.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    exp.status:SetWordWrap(true)
    exp.status:SetJustifyH("CENTER")
    exp.status:SetPoint("TOP", exp.box:GetParent(), "BOTTOM", 0, -EXPORT_LAYOUT.statusGap)
    exp.status:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    exp.status:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)

    exp.box:SetScript("OnEditFocusGained", HighlightText)
    exp.box:SetScript("OnTextChanged", function(_, user) if user then Regenerate(exp) end end)
    exp.nameBox:SetScript("OnEnterPressed", ClearFocus)
    exp.nameBox:SetScript("OnEditFocusLost", function() Regenerate(exp) end)

    exp.closeBtn = ns.Button(panel, TEXT_CLOSE, CLOSE_W, BUTTON_H, function() dimmer:Hide() end)
    exp.closeBtn:SetPoint("TOP", exp.status, "BOTTOM", 0, -EXPORT_LAYOUT.closeGap)
    exp.Regenerate = function() Regenerate(exp) end
    return exp
end

function ns.ShowPackExport()
    if packExport then
        packExport.Regenerate()
        packExport.dimmer:Show()
        return
    end
    packExport = BuildPackExport()
    packExport.Regenerate()
    packExport.dimmer:Show()
end

local function BuildDiagExport()
    local dimmer, panel = ns.MakeModal(DIAG_LAYOUT.w, DIAG_LAYOUT.h, "diagExport")
    local title = Title(panel, TEXT_DIAG_TITLE)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -DIAG_LAYOUT.hintGap)
    hint:SetText(TEXT_DIAG_HINT)

    local box = ns.MakeMultilineBox(panel, -DIAG_LAYOUT.boxY, DIAG_LAYOUT.boxH)
    box:SetScript("OnEditFocusGained", HighlightText)
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(diagExport.text or "") end
    end)

    ns.Button(panel, TEXT_CLOSE, CLOSE_W, BUTTON_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", 0, PAD)
    return { dimmer = dimmer, box = box }
end

function ns.ShowDiagExport(text)
    if not diagExport then diagExport = BuildDiagExport() end
    diagExport.text = text or ""
    diagExport.box:SetText(diagExport.text)
    diagExport.dimmer:Show()
    diagExport.box:SetFocus()
end

local function MergeSetAll(m, on)
    for i = 1, #m.specRows do
        if m.specRows[i]:IsShown() then
            m.specWanted[m.rowKeys[i]] = on or nil
            m.specRows[i].toggle._refreshValue()
        end
    end
end

local function MergeClearRows(m)
    ns.UI.BeginReusableRows(m.rowsHost)
    for i = 1, #m.specRows do m.specRows[i]:Hide() end
    if m.selectAllBtn then m.selectAllBtn:Hide(); m.deselectAllBtn:Hide() end
end

local function MergeSourceData(m)
    if not m.decoded then return nil end
    if type(m.decoded.profiles) == "table" then
        return m.sourceName and m.decoded.profiles[m.sourceName]
    end
    return m.decoded.data
end

local function MergeSourceNames(m)
    if m.decoded and type(m.decoded.profiles) == "table" then return LandedNames(m.decoded.profiles) end
    return {}
end

local function ValuesOf(list)
    local values = {}
    for _, n in ipairs(list) do values[n] = n end
    return values
end

local function NewPicker(host, values, order, get, set)
    local r = CreateFrame("Frame", nil, host)
    r.lbl = ns.Font(r, LABEL_SIZE, nil, ns.THEME.muted)
    r.lbl:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.dd = ns.UI.BuildDropdownControl(r, MERGE_LAYOUT.pickerW, nil, values, order, get, set)
    r.dd:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -MERGE_LAYOUT.pickerDropY)
    return r
end

local function Picker(m, y, label, values, order, get, set)
    local row = ns.UI.Keep(m.rowsHost, "picker", function(host) return NewPicker(host, values, order, get, set) end)
    row:SetPoint("TOPLEFT", m.panel, "TOPLEFT", PAD, y)
    row:SetSize(MERGE_LAYOUT.pickerW, MERGE_LAYOUT.pickerH)
    row:SetFrameLevel(m.panel:GetFrameLevel() + RAISE)
    row.lbl:SetText(label)
    local dd = row.dd
    dd._values, dd._order, dd._get, dd._set = values, order, get, set
    dd:SetFrameLevel(row:GetFrameLevel() + 2)
    dd._refreshLabel()
    return row
end

local MergeRebuild

local function ResetSpecs(m)
    m.specWanted, m.specSeeded = {}, false
end

local function MergeSourcePicker(m, y)
    local sources = MergeSourceNames(m)
    if #sources == 0 then
        m.sourceName = nil
        return y
    end
    if not m.sourceName or not m.decoded.profiles[m.sourceName] then
        m.sourceName = sources[1]
        ResetSpecs(m)
    end
    Picker(m, y, TEXT_TAKE_PROFILE, ValuesOf(sources), sources,
        function() return m.sourceName end,
        function(v) m.sourceName = v; ResetSpecs(m); MergeRebuild(m) end)
    return y - MERGE_LAYOUT.pickerStep
end

local function MergeTargetPicker(m, y)
    local mine = ns.ListProfiles()
    if not m.targetName or not ns.ProfileExists(m.targetName) then
        m.targetName = ns.ActiveProfileName()
    end
    Picker(m, y, TEXT_MERGE_INTO, ValuesOf(mine), mine,
        function() return m.targetName end,
        function(v) m.targetName = v end)
    return y - MERGE_LAYOUT.targetStep
end

local function NewMergeHead(host)
    local f = CreateFrame("Frame", nil, host)
    f.text = ns.Font(f, LABEL_SIZE, nil, ns.THEME.muted)
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    return f
end

local function MergeSpecHead(m, y, specs)
    local head = ns.UI.Keep(m.rowsHost, "head", NewMergeHead)
    head:SetPoint("TOPLEFT", m.panel, "TOPLEFT", PAD, y)
    head:SetSize(MERGE_LAYOUT.headW, MERGE_LAYOUT.headH)
    head.text:SetText(#specs > 0 and TEXT_TAKE_SPECS or TEXT_NO_SPECS)
    if not m.selectAllBtn then
        m.selectAllBtn = ns.Button(m.panel, TEXT_SELECT_ALL, SELECT_W, MERGE_LAYOUT.selectH,
            function() MergeSetAll(m, true) end)
        m.deselectAllBtn = ns.Button(m.panel, TEXT_DESELECT_ALL, DESELECT_W, MERGE_LAYOUT.selectH,
            function() MergeSetAll(m, false) end)
        m.selectAllBtn:SetPoint("TOPRIGHT", m.deselectAllBtn, "TOPLEFT", -SELECT_GAP, 0)
    end
    m.deselectAllBtn:ClearAllPoints()
    m.deselectAllBtn:SetPoint("TOPRIGHT", m.panel, "TOPRIGHT", -PAD, y + MERGE_LAYOUT.selectRise)
    m.selectAllBtn:SetShown(#specs > 0)
    m.deselectAllBtn:SetShown(#specs > 0)
    return y - MERGE_LAYOUT.headStep
end

local function MergeSpecRow(m, i)
    return MakeToggleRow(m.panel, MERGE_LAYOUT.colW, MERGE_LAYOUT.rowH, m.panel:GetFrameLevel() + RAISE,
        function() return m.specWanted[m.rowKeys[i]] end,
        function(v) m.specWanted[m.rowKeys[i]] = v or nil end, SPEC_TOGGLE_W, SPEC_TOGGLE_H)
end

local function MergeSpecGrid(m, y, specs)
    for i, s in ipairs(specs) do
        local col, line = (i - 1) % MERGE_LAYOUT.cols, math.floor((i - 1) / MERGE_LAYOUT.cols)
        m.rowKeys[i] = s.key
        local row = m.specRows[i] or MergeSpecRow(m, i)
        m.specRows[i] = row
        row.toggle._refreshValue()
        PaintSpecLabel(row.label, s)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", m.panel, "TOPLEFT", PAD + col * MERGE_LAYOUT.colW, y - line * MERGE_LAYOUT.rowH)
        row:Show()
    end
    return y - math.max(1, math.ceil(#specs / MERGE_LAYOUT.cols)) * MERGE_LAYOUT.rowH - MERGE_LAYOUT.gridGap
end

local function MergeOption(m, key, field, text, tipTitle, tip)
    local row = ns.UI.Keep(m.rowsHost, key, function(host)
        local r = MakeToggleRow(host, MERGE_LAYOUT.optionW, OPTION_H, nil,
            function() return m[field] end,
            function(v) m[field] = v end)
        r.label:SetText(text)
        if tip then ns.Tooltip(r, tipTitle, tip) end
        return r
    end)
    row:SetFrameLevel(m.panel:GetFrameLevel() + RAISE)
    row.toggle._refreshValue()
    return row
end

MergeRebuild = function(m)
    MergeClearRows(m)
    if not m.decoded then
        m.panel:SetHeight(MERGE_LAYOUT.h)
        ResetSpecs(m)
        return
    end
    local y = MergeSourcePicker(m, -MERGE_LAYOUT.rowsY)
    y = MergeTargetPicker(m, y)
    local data = MergeSourceData(m)
    local specs = data and SortSpecs(ns.PackSpecs({ data = data })) or {}
    if not m.specSeeded then
        for _, s in ipairs(specs) do m.specWanted[s.key] = true end
        m.specSeeded = true
    end
    y = MergeSpecHead(m, y, specs)
    y = MergeSpecGrid(m, y, specs)
    MergeOption(m, "settings", "wantSettings", TEXT_TAKE_SETTINGS):SetPoint("TOPLEFT", m.panel, "TOPLEFT", PAD, y)
    y = y - MERGE_LAYOUT.optionStep
    MergeOption(m, "extras", "wantExtras", TEXT_TAKE_EXTRAS, TEXT_EXTRAS_TITLE, TEXT_EXTRAS_HELP)
        :SetPoint("TOPLEFT", m.panel, "TOPLEFT", PAD, y)
    m.panel:SetHeight(math.max(MERGE_LAYOUT.h, -y + MERGE_LAYOUT.bottom))
end

local function MergeRevalidate(m)
    m.decoded = nil
    local text = m.box:GetText()
    if text and text:gsub("%s+", "") ~= "" then
        local payload, describe = ns.DecodePack(text)
        if payload then
            m.decoded = payload
            m.preview:SetText(describe or TEXT_READY)
        else
            m.preview:SetText(ErrorText(describe or TEXT_UNREADABLE))
        end
    else
        m.preview:SetText(TEXT_PASTE_THEIRS)
    end
    MergeRebuild(m)
    if m.mergeBtn then m.mergeBtn:SetAlpha(m.decoded and 1 or MERGE_LAYOUT.dim) end
end

local function MergeNow(m)
    if not m.decoded then return end
    local ok, a, b = ns.MergeProfileFromPack(m.decoded, m.sourceName, m.targetName,
        { settings = m.wantSettings, extras = m.wantExtras, specs = m.specWanted })
    if not ok then
        m.preview:SetText(ErrorText(a))
        return
    end
    ns.Print(("merged into " .. ns.Color("accent", "%s") .. ": %d spec sections and %d reminders. Specs you "
        .. "did not tick are exactly as they were."):format(
        tostring(m.targetName), a or 0, b or 0))
    m.dimmer:Hide()
    if ns.UI and ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function BuildProfileMerge()
    local dimmer, panel = ns.MakeModal(MERGE_LAYOUT.w, MERGE_LAYOUT.h, "profileMerge")
    Title(panel, TEXT_MERGE_TITLE)
    local m = { dimmer = dimmer, panel = panel, wantSettings = false, wantExtras = false,
        specWanted = {}, specSeeded = false, specRows = {}, rowKeys = {} }
    m.box = ns.MakeMultilineBox(panel, -MERGE_LAYOUT.boxY, MERGE_LAYOUT.boxH)
    m.preview = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m.preview:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -MERGE_LAYOUT.previewY)
    m.preview:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -MERGE_LAYOUT.previewY)
    m.preview:SetJustifyH("LEFT")
    m.preview:SetText(TEXT_PASTE_THEIRS)
    m.rowsHost = CreateFrame("Frame", nil, panel)
    m.rowsHost:SetAllPoints()
    m.box:SetScript("OnTextChanged", function() MergeRevalidate(m) end)

    m.mergeBtn = ns.Button(panel, TEXT_MERGE, ACTION_W, BUTTON_H, function() MergeNow(m) end)
    m.mergeBtn:SetPoint("BOTTOM", panel, "BOTTOM", -ACTION_SHIFT, PAD)
    ns.Button(panel, TEXT_CANCEL, CLOSE_W, BUTTON_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", ACTION_SHIFT, PAD)
    m.Revalidate = function() MergeRevalidate(m) end
    return m
end

function ns.ShowProfileMergeDialog()
    if profileMerge then
        profileMerge.box:SetText("")
        profileMerge.Revalidate()
        profileMerge.dimmer:Show()
        profileMerge.box:SetFocus()
        return
    end
    profileMerge = BuildProfileMerge()
    profileMerge.Revalidate()
    profileMerge.dimmer:Show()
    profileMerge.box:SetFocus()
end

local function ShownOr(frame, fallback)
    return (frame and frame:IsShown()) and frame or fallback
end

local function ImportSetAll(imp, on)
    for i = 1, #imp.specRows do
        local row = imp.specRows[i]
        if row:IsShown() and row.specKey then
            imp.specWanted[row.specKey] = on or nil
            if row.Repaint then row.Repaint() end
        end
    end
end

local function ClearOverwrite(imp)
    imp.overwriteWanted = false
    local btn = imp.overwriteBtn
    if not btn then return end
    if btn.toggle and btn.toggle._refreshValue then btn.toggle._refreshValue() end
    btn:Hide()
end

local function ResetImportRows(imp)
    ClearOverwrite(imp)
    for i = 1, #imp.specRows do imp.specRows[i]:Hide() end
    if imp.settingsBtn then imp.settingsBtn:Hide() end
    if imp.bindBtn then imp.bindBtn:Hide() end
    if imp.selectAllBtn then imp.selectAllBtn:Hide() end
    if imp.deselectAllBtn then imp.deselectAllBtn:Hide() end
    wipe(imp.specWanted)
end

local function ImportChoices(payload, multi)
    if multi then
        local specs = {}
        local names = LandedNames(payload.profiles)
        for i = 1, #names do specs[i] = { key = names[i], name = names[i] } end
        return specs
    end
    if payload then return SortSpecs(ns.PackSpecs(payload)) end
    return {}
end

local function HideImportOptions(imp)
    imp.specHead:Hide()
    if imp.nameBox then imp.nameBox:SetText(""); imp.nameLabel:Hide(); imp.nameBox:Hide() end
    if imp.accountBtn then imp.accountBtn:Hide() end
    if imp.bindBtn then imp.bindBtn:Hide() end
    if imp.settingsBtn then imp.settingsBtn:Hide() end
end

local function ImportSpecRow(imp)
    local btn = CreateFrame("Frame", nil, imp.panel)
    btn:SetSize(IMPORT_LAYOUT.colW, IMPORT_LAYOUT.specRowH)
    btn:SetFrameLevel(imp.panel:GetFrameLevel() + RAISE)
    btn.label = ns.Font(btn, LABEL_SIZE, nil)
    local tgl, _, repaint = ns.UI.BuildToggleControl(btn, btn:GetFrameLevel() + 1,
        function() return imp.specWanted[btn.specKey] end,
        function(v) imp.specWanted[btn.specKey] = v or nil end, SPEC_TOGGLE_W, SPEC_TOGGLE_H)
    btn.toggle, btn.Repaint = tgl, repaint
    tgl:SetPoint("LEFT", btn, "LEFT", 0, 0)
    btn.label:SetPoint("LEFT", tgl, "RIGHT", IMPORT_LAYOUT.specLabelGap, 0)
    return btn
end

local function PlaceSpecGrid(imp, specs)
    for i = 1, #specs do
        local spec = specs[i]
        imp.specWanted[spec.key] = true
        local btn = imp.specRows[i] or ImportSpecRow(imp)
        imp.specRows[i] = btn
        local col = (i - 1) % IMPORT_LAYOUT.cols
        local row = math.floor((i - 1) / IMPORT_LAYOUT.cols)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", imp.specHead, "BOTTOMLEFT", IMPORT_LAYOUT.specInset + col * IMPORT_LAYOUT.colW, -IMPORT_LAYOUT.specInset - row * IMPORT_LAYOUT.rowH)
        btn.specKey = spec.key
        btn.Repaint()
        PaintSpecLabel(btn.label, spec)
        btn:Show()
    end
    if not imp.gridAnchor then
        imp.gridAnchor = CreateFrame("Frame", nil, imp.panel)
        imp.gridAnchor:SetSize(1, 1)
    end
    imp.gridAnchor:ClearAllPoints()
    imp.gridAnchor:SetPoint("TOPLEFT", imp.specHead, "BOTTOMLEFT",
        IMPORT_LAYOUT.specInset, -IMPORT_LAYOUT.specInset - math.ceil(#specs / IMPORT_LAYOUT.cols) * IMPORT_LAYOUT.rowH)
end

local function ImportOption(imp, width, field)
    return MakeToggleRow(imp.panel, width, OPTION_H, imp.panel:GetFrameLevel() + RAISE,
        function() return imp[field] end,
        function(v) imp[field] = v end)
end

local function PlaceSettingsRow(imp, payload)
    if not (type(payload.data) == "table" and type(payload.data.settings) == "table") then
        if imp.settingsBtn then imp.settingsBtn:Hide() end
        return
    end
    if not imp.settingsBtn then
        imp.settingsBtn = ImportOption(imp, IMPORT_LAYOUT.settingsW, "settingsWanted")
        imp.settingsBtn.label:SetText(TEXT_THEIR_SETTINGS)
    end
    imp.settingsBtn:ClearAllPoints()
    imp.settingsBtn:SetPoint("TOPLEFT", imp.gridAnchor, "BOTTOMLEFT", 0, -IMPORT_LAYOUT.settingsGap)
    imp.settingsBtn:Show()
end

local function PlaceBindRow(imp, multi)
    if not multi then
        if imp.bindBtn then imp.bindBtn:Hide() end
        return
    end
    if not imp.bindBtn then
        imp.bindBtn = ImportOption(imp, IMPORT_LAYOUT.bindW, "bindWanted")
        imp.bindBtn.label:SetText(TEXT_BIND)
    end
    imp.bindBtn:ClearAllPoints()
    imp.bindBtn:SetPoint("TOPLEFT", ShownOr(imp.settingsBtn, imp.gridAnchor), "BOTTOMLEFT", 0, -IMPORT_LAYOUT.optionGap)
    imp.bindBtn:Show()
end

local function PlaceAccountRow(imp, multi)
    if multi then
        if imp.accountBtn then imp.accountBtn:Hide() end
        return
    end
    if not imp.accountBtn then imp.accountBtn = ImportOption(imp, IMPORT_LAYOUT.accountW, "accountWanted") end
    local known = ns.KnownCharacters and #ns.KnownCharacters() or 0
    imp.accountBtn.label:SetText(known > 1 and TEXT_ALL_CHARACTERS:format(known) or TEXT_EVERY_CHARACTER)
    imp.accountBtn:ClearAllPoints()
    imp.accountBtn:SetPoint("TOPLEFT", ShownOr(imp.settingsBtn, imp.gridAnchor), "BOTTOMLEFT", 0, -IMPORT_LAYOUT.optionGap)
    imp.accountBtn:Show()
end

local function ImportNameBox(imp)
    local panel = imp.panel
    imp.nameLabel = ns.Font(panel, LABEL_SIZE, nil)
    imp.nameLabel:SetText(TEXT_SAVE_AS)
    local nameBox = NameBox(panel, IMPORT_LAYOUT.nameBoxW)
    StyleNameBox(nameBox)
    nameBox:SetFrameLevel(panel:GetFrameLevel() + RAISE)
    nameBox:SetScript("OnEscapePressed", ClearFocus)
    nameBox:EnableMouse(true)
    nameBox:SetScript("OnMouseDown", SetFocus)
    imp.nameBox = nameBox
end

local function RefreshOverwrite(imp)
    local typed = imp.nameBox:GetText()
    if ns.ProfileExists and ns.ProfileExists(typed) then
        imp.overwriteBtn.label:SetText(TEXT_REPLACE:format(typed))
        imp.overwriteBtn:Show()
    else
        ClearOverwrite(imp)
    end
end

local function PlaceNameRow(imp, payload, multi)
    if multi then
        if imp.nameBox then
            imp.nameLabel:Hide()
            imp.nameBox:Hide()
            ClearOverwrite(imp)
        end
        return
    end
    if not imp.nameBox then ImportNameBox(imp) end
    local anchorTo = ShownOr(imp.accountBtn) or ShownOr(imp.bindBtn) or ShownOr(imp.settingsBtn) or imp.gridAnchor
    imp.nameLabel:ClearAllPoints()
    imp.nameLabel:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -IMPORT_LAYOUT.nameGap)
    imp.nameBox:ClearAllPoints()
    imp.nameBox:SetPoint("LEFT", imp.nameLabel, "RIGHT", IMPORT_LAYOUT.nameLabelGap, 0)
    imp.nameBox:SetText((payload.name and payload.name ~= "") and payload.name or IMPORTED_PROFILE)
    imp.nameLabel:Show()
    imp.nameBox:Show()
    if not imp.overwriteBtn then imp.overwriteBtn = ImportOption(imp, IMPORT_LAYOUT.accountW, "overwriteWanted") end
    imp.overwriteBtn:ClearAllPoints()
    imp.overwriteBtn:SetPoint("TOPLEFT", imp.nameLabel, "BOTTOMLEFT", 0, -IMPORT_LAYOUT.overwriteGap)
    imp.nameBox:SetScript("OnTextChanged", function() RefreshOverwrite(imp) end)
    RefreshOverwrite(imp)
end

local function PlaceSelectButtons(imp)
    if not imp.selectAllBtn then
        imp.selectAllBtn = ns.Button(imp.panel, TEXT_SELECT_ALL, SELECT_W, OPTION_H, function() ImportSetAll(imp, true) end)
        imp.deselectAllBtn = ns.Button(imp.panel, TEXT_DESELECT_ALL, DESELECT_W, OPTION_H,
            function() ImportSetAll(imp, false) end)
    end
    imp.selectAllBtn:ClearAllPoints()
    if imp.nameBox and imp.nameBox:IsShown() then
        imp.selectAllBtn:SetPoint("LEFT", imp.nameBox, "RIGHT", IMPORT_LAYOUT.selectNameGap, 0)
    else
        local anchorTo = ShownOr(imp.bindBtn) or ShownOr(imp.settingsBtn) or imp.gridAnchor
        imp.selectAllBtn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -IMPORT_LAYOUT.nameGap)
    end
    imp.deselectAllBtn:ClearAllPoints()
    imp.deselectAllBtn:SetPoint("LEFT", imp.selectAllBtn, "RIGHT", SELECT_GAP, 0)
    imp.selectAllBtn:Show()
    imp.deselectAllBtn:Show()
end

local function FitImport(imp, specs)
    local last = ShownOr(imp.overwriteBtn)
        or (imp.nameBox and imp.nameBox:IsShown() and imp.nameLabel)
        or ShownOr(imp.bindBtn) or ShownOr(imp.settingsBtn)
        or imp.specRows[#specs]
    if not last then return end
    local used = imp.panel:GetTop() - last:GetBottom()
    imp.panel:SetHeight(math.max(IMPORT_LAYOUT.h, used + IMPORT_LAYOUT.bottom))
end

local function BuildSpecRows(imp, payload)
    ResetImportRows(imp)
    local multi = payload and type(payload.profiles) == "table"
    local specs = ImportChoices(payload, multi)
    if #specs == 0 then return HideImportOptions(imp) end
    imp.specHead:SetText(multi and TEXT_WHICH_PROFILES or TEXT_WHICH_ITEMS)
    imp.specHead:Show()
    PlaceSpecGrid(imp, specs)
    PlaceSettingsRow(imp, payload)
    PlaceBindRow(imp, multi)
    PlaceAccountRow(imp, multi)
    PlaceNameRow(imp, payload, multi)
    PlaceSelectButtons(imp)
    FitImport(imp, specs)
end

local function ImportRevalidate(imp)
    local payload, descOrErr = ns.DecodePack(imp.box:GetText())
    imp.decoded = payload
    if payload then
        imp.preview:SetText(descOrErr)
    else
        imp.preview:SetText(ErrorText(descOrErr))
    end
    BuildSpecRows(imp, payload)
    local b = imp.applyBtn
    if not b then return end
    if payload ~= nil then
        b:Enable()
        b:SetAlpha(1)
    else
        b:Disable()
        b:SetAlpha(IMPORT_LAYOUT.dim)
    end
end

local function FinishProfiles(imp)
    local wantP, anyP = {}, false
    for name in pairs(imp.decoded.profiles) do
        if imp.specWanted[name] then wantP[name] = true; anyP = true end
    end
    if not anyP then
        imp.preview:SetText(TEXT_PICK_PROFILE)
        return
    end
    local ok, landed = ns.ApplyProfiles(imp.decoded, wantP, imp.settingsWanted, imp.bindWanted)
    if not ok then
        imp.preview:SetText(TEXT_NOT_APPLIED)
        return
    end
    if imp.bindWanted then ns.AutoSpecProfile(true) end
    ns.Print(TEXT_PROFILES_IMPORTED:format(landed, landed == 1 and "" or "s",
        imp.bindWanted and TEXT_EACH_SPEC or TEXT_PICK_ACTIVE))
    if imp.bindWanted and ns.ApplySpecProfile and ns.CurrentSpec then
        ns.ApplySpecProfile((ns.CurrentSpec()))
    end
    imp.dimmer:Hide()
    RefreshOptions()
end

local function WantedSpecs(imp)
    local all, any = true, false
    local specs = ns.PackSpecs(imp.decoded)
    for i = 1, #specs do
        if imp.specWanted[specs[i].key] then any = true else all = false end
    end
    if #specs > 0 and not any then return nil, false end
    if #specs > 0 and not all then return imp.specWanted, true end
    return nil, true
end

local function ImportedMessage(imp, newName, accountSet, autoOff)
    if accountSet then
        local known = ns.KnownCharacters and #ns.KnownCharacters() or 0
        return TEXT_IMPORTED_ALL:format(tostring(newName),
            known == 1 and TEXT_ONE_CHARACTER or TEXT_N_CHARACTERS:format(known),
            known == 1 and "s" or "",
            autoOff and TEXT_AUTO_OFF or "")
    end
    if imp.overwriteWanted then return TEXT_REPLACED:format(tostring(newName)) end
    return TEXT_IMPORTED_AS:format(tostring(newName))
end

local function FinishSingle(imp)
    local want, any = WantedSpecs(imp)
    if not any then
        imp.preview:SetText(TEXT_PICK_ONE)
        return
    end
    local ok, newName = ns.ImportPackAsProfile(imp.decoded, want, imp.settingsWanted,
        imp.nameBox and imp.nameBox:GetText(), imp.overwriteWanted)
    if not ok then
        imp.preview:SetText(TEXT_NOT_APPLIED)
        return
    end
    local accountSet, autoOff = false, false
    if imp.accountWanted and ns.SetAccountProfile then
        accountSet, autoOff = ns.SetAccountProfile(newName)
    end
    ns.Print(ImportedMessage(imp, newName, accountSet, autoOff))
    imp.dimmer:Hide()
    RefreshOptions()
end

local function Finish(imp)
    if not imp.decoded then return end
    if type(imp.decoded.profiles) == "table" then return FinishProfiles(imp) end
    FinishSingle(imp)
end

local function BuildPackImport()
    local dimmer, panel = ns.MakeModal(IMPORT_LAYOUT.w, IMPORT_LAYOUT.h, "packImport")
    Title(panel, TEXT_IMPORT_TITLE)
    local imp = { dimmer = dimmer, panel = panel, specRows = {}, specWanted = {},
        settingsWanted = true, bindWanted = true, accountWanted = true, overwriteWanted = false }
    imp.box = ns.MakeMultilineBox(panel, -IMPORT_LAYOUT.boxY, IMPORT_LAYOUT.boxH)
    imp.preview = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    imp.preview:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -IMPORT_LAYOUT.previewY)
    imp.preview:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -IMPORT_LAYOUT.previewY)
    imp.preview:SetJustifyH("LEFT")
    imp.preview:SetText(TEXT_PASTE_PACK)
    imp.specHead = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    imp.specHead:SetPoint("TOPLEFT", imp.preview, "BOTTOMLEFT", 0, -IMPORT_LAYOUT.headGap)
    imp.specHead:SetJustifyH("LEFT")
    imp.specHead:Hide()
    imp.box:SetScript("OnTextChanged", function(_, user) if user then ImportRevalidate(imp) end end)

    imp.applyBtn = ns.Button(panel, TEXT_IMPORT, ACTION_W, BUTTON_H, function() Finish(imp) end)
    imp.applyBtn:SetPoint("BOTTOM", panel, "BOTTOM", -ACTION_SHIFT, PAD)
    ns.Button(panel, TEXT_CANCEL, CLOSE_W, BUTTON_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", ACTION_SHIFT, PAD)
    imp.Revalidate = function() ImportRevalidate(imp) end
    return imp
end

function ns.ShowPackImport(text)
    if packImport then
        packImport.box:SetText(text or "")
        packImport.Revalidate()
        packImport.dimmer:Show()
        packImport.box:SetFocus()
        return
    end
    packImport = BuildPackImport()
    if text then packImport.box:SetText(text) end
    packImport.Revalidate()
    packImport.dimmer:Show()
    packImport.box:SetFocus()
end
