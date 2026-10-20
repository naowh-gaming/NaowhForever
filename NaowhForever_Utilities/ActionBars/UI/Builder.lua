-- Builder.lua: the Bar Sets tab's set builder: your bars on the scene's strip with each bar and slot in or out, keybinds and macros, then a name (ns.ActionBars.Builder).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets
local Capture = A.Capture

local VIEW_TOP, GAP, GLASS_PAD = St.VIEW_TOP, St.CARD_GAP, St.GLASS_PAD
local OUT_ALPHA, ICON_CROP = St.OUT_ALPHA, St.ICON_CROP
local BUTTON_H, LINE_GAP = St.BUTTON_H, St.LINE_GAP
local SLOTS_PER_BAR = A.C.SLOTS_PER_BAR
local SMALL_SIZE, NOTE_SIZE = St.SMALL_SIZE, St.NOTE_SIZE
local PET_BAR, PET_CLASSES = A.PET_BAR, A.PET_CLASSES
local DOT = St.PLACE_DOT
local MAIN_PAGE, LEFT_PAGE, TOP_PAGE, RIGHT_PAGE, MAIN_VIEW = P.MAIN_PAGE, P.LEFT_PAGE, P.TOP_PAGE, P.RIGHT_PAGE, P.MAIN_VIEW
local SUMMARY_BAR, PANEL_H, IDENT_H, LEFT_W = 56, 72, 50, 300
local ICON_BUTTON, PICKER_TILE, PICKER_GAP, PICKER_COLUMNS, PICKER_MAX, PICKER_LEVEL = 44, 28, 3, 10, 40, 20
local MAX_TAGS, TAG_MAX, TAG_PAD, TAG_H, TAGS_X, ADD_TAG_W = 3, 16, 8, 20, 18, 60
local OFF_MACRO_ALPHA = 0.45
local MACRO_ROW_H, MACRO_GAP, MACRO_INSET, MACRO_ICON = 30, 4, 8, 22
local NAME_COLUMN, TEXT_GAP, TAG_GAP = 140, 8, 4
local NAME_H, NAME_MAX, NAME_W, SUMMARY_GAP, SAVE_W = 26, 40, 260, 18, 120

local TEXT_TITLE, TEXT_EDIT = ns.L("New Bar Set"), ns.L("Edit ")
local TEXT_SUBTITLE = ns.L("Pick what goes in, then import it on any %s.")
local TEXT_PICK_HINT = ns.L("Click a bar's name to leave it out, or a button to skip just that slot.")
local TEXT_MAIN, TEXT_MAIN_BARS, TEXT_PET_BAR = ns.L("Main"), ns.L("Main bars"), ns.L("Pet Bar")
local TEXT_PICKED_BAR = "%s (%d)"
local TEXT_CHIP = "%s %d"
local TEXT_KEYBINDS, TEXT_MACROS, TEXT_SET_NAME = ns.L("Keybinds"), ns.L("Macros"), ns.L("Set name")
local TEXT_SAVE_SET = ns.L("Save Set")
local TEXT_ICON = ns.L("Set icon")
local TEXT_ICON_TIP = ns.L("Pick one from your bars. Auto shows the set's first spell.")
local TEXT_AUTO = ns.L("Auto")
local TEXT_TAGS, TEXT_ADD_TAG = ns.L("Tags"), ns.L("+ Tag")
local TEXT_NEW_TAG = ns.L("A tag for this set, such as Dungeon or PvP")
local TEXT_TAG_TIP = ns.L("Click to take this tag off.")
local TEXT_ACTION, TEXT_ACTIONS = ns.L("%d action"), ns.L("%d actions")
local TEXT_KEYBIND, TEXT_KEYBINDS_N = ns.L("%d keybind"), ns.L("%d keybinds")
local TEXT_MACRO, TEXT_MACROS_N = ns.L("%d macro"), ns.L("%d macros")
local TEXT_LEAVE_BAR, TEXT_PUT_BAR = ns.L("Leave this bar out"), ns.L("Put this bar back in")
local TEXT_BAR_HINT = ns.L("A bar left out is not touched by an import.")
local TEXT_LEAVE_PET, TEXT_PUT_PET = ns.L("Leave the pet bar's keys out"), ns.L("Put the pet bar's keys back in")
local TEXT_PET_HINT = ns.L("Only the pet bar's keys go in a set, never your pet's actions.")
local TEXT_PET_TIP = ns.L("Only this button's keys go in the set.")
local TEXT_EMPTY_SLOT = ns.L("Empty slot")
local TEXT_KEPT = ns.L("In the set. Click to leave it out.")
local TEXT_KEPT_EMPTY = ns.L("In the set as empty: an import clears it. Click to leave it out.")
local TEXT_LEFT_OUT = ns.L("Left out: an import leaves this slot as it is. Click to put it back in.")
local TEXT_CHARACTER, TEXT_ACCOUNT, TEXT_ON_BARS = ns.L("Character"), ns.L("Account"), ns.L("On bars")
local TEXT_ON_BARS_TIP = ns.L("On a slot in the set, so it always comes along.")
local TEXT_REUSE_TIP = ns.L("An alt that already has this macro, by name and text or text alone, uses its own.")
local TEXT_NO_NAME = ns.L("Give the set a name first.")
local TEXT_REPLACE = ns.L("Replace %s with these bars?")
local TEXT_KEYS_ON = ns.L("All %d come along: %d on your bars, %d for other commands.")
local TEXT_KEYS_OFF = ns.L("Off: an import leaves your keys alone.")
local TEXT_MACROS_ON = ns.L("%d of %d come along. An alt reuses the ones it has.")
local TEXT_MACROS_OFF = ns.L("Only the macros on your kept slots come along.")
local BODY_JOIN = "  "
local BAR_COMMAND = "^(.-)%d+$"

local Plural = A.Plural

local Builder = {}
A.Builder = Builder

local W, draft
local viewPage, formPage = MAIN_VIEW, MAIN_PAGE
local onBars, look, parts, barButtons = {}, {}, {}, {}
local pages, order, petCommands, forms
local model = { regions = { left = {}, top = {}, bottom = {}, right = {} }, single = nil, chips = {},
    pet = nil }
local single, chipPool = {}, {}
local picker = { values = {}, order = {} }

for _, bar in ipairs(A.BARS) do barButtons[bar.button] = true end
barButtons[PET_BAR.button] = true

local function Copy(t)
    local out = {}
    for k, val in pairs(t or {}) do out[k] = val end
    return out
end

local function Flip(t, key)
    t[key] = not t[key] or nil
    W.Redraw()
end

local function SlotTip(tip, tile)
    local slot = tile.slot
    if GetActionInfo(slot) then tip:SetAction(slot) else tip:SetText(TEXT_EMPTY_SLOT, 1, 1, 1) end
    tip:AddLine(" ")
    local line = tile.kept and (GetActionInfo(slot) and TEXT_KEPT or TEXT_KEPT_EMPTY) or TEXT_LEFT_OUT
    tip:AddLine(line, T.muted.r, T.muted.g, T.muted.b, true)
end

local function SlotClicked(tile)
    Flip(draft.choices.skip, tile.slot)
end

local function PetAction(i)
    if not GetPetActionInfo then return nil end
    local name, texture, isToken = GetPetActionInfo(i)
    if isToken and texture then texture = _G[texture] end
    return name, texture
end

local function PetTip(tip, tile)
    if PetAction(tile.slot) then tip:SetPetAction(tile.slot) else tip:SetText(TEXT_EMPTY_SLOT, 1, 1, 1) end
    tip:AddLine(" ")
    tip:AddLine(TEXT_PET_TIP, T.muted.r, T.muted.g, T.muted.b, true)
end

local function BarHint(label)
    P.Hint(label, label.out and TEXT_PUT_BAR or TEXT_LEAVE_BAR, TEXT_BAR_HINT)
end

local function PetHint(label)
    P.Hint(label, label.out and TEXT_PUT_PET or TEXT_LEAVE_PET, TEXT_PET_HINT)
end

local function BarClicked(label)
    local skip = draft.choices.skip
    for _, slot in ipairs(label.entry.list) do skip[slot] = (not label.out) or nil end
    W.Redraw()
end

local function PetClicked()
    local choices = draft.choices
    if not choices.keys then return end
    choices.petOff = not choices.petOff or nil
    W.Redraw()
end

local function Counts(list, skip)
    local used, out = 0, 0
    for _, slot in ipairs(list) do
        if GetActionInfo(slot) and not skip[slot] then used = used + 1 end
        if skip[slot] then out = out + 1 end
    end
    return used, out
end

local function PaintSlot(tile, region, i)
    local entry, skip = region.entry, draft.choices.skip
    local slot = entry.list[i]
    local kept = not skip[slot]
    local dim = not kept and not region.out
    wipe(look)
    look.texture = GetActionTexture(slot)
    look.key = GetActionInfo(slot) and P.KeyText(entry.commands[i]) or ""
    look.alpha, look.grey, look.mark = dim and OUT_ALPHA or 1, not kept, dim
    look.edge = dim and T.muted or nil
    look.tip, look.onClick = SlotTip, SlotClicked
    P.PaintTile(tile, look)
    tile.slot, tile.kept = slot, kept
end

local function Region(region, entry, label)
    local _, out = Counts(entry.list, draft.choices.skip)
    region.entry, region.label = entry, label or entry.bar.name
    region.out = out == SLOTS_PER_BAR
    region.onClick, region.hint = BarClicked, BarHint
    return region
end

local function DrawChips()
    wipe(model.chips)
    if not forms then return end
    local skip = draft.choices.skip
    for i, page in ipairs(forms) do
        local entry = pages[page]
        local used, out = Counts(entry.list, skip)
        local chip = chipPool[i] or {}
        chipPool[i] = chip
        chip.text = TEXT_CHIP:format(page == MAIN_PAGE and TEXT_MAIN or entry.form, used)
        chip.picked, chip.out, chip.page = page == formPage, out == SLOTS_PER_BAR, page
        chip.onClick = Builder.PickForm
        model.chips[i] = chip
    end
end

local function DrawPet()
    if not PET_CLASSES[A.Class()] then
        model.pet = nil
        return
    end
    local pet = model.petLook or { keys = {} }
    model.petLook, model.pet = pet, pet
    local choices = draft.choices
    pet.label, pet.out = TEXT_PET_BAR, not (choices.keys and not choices.petOff)
    pet.tip, pet.onClick, pet.hint = PetTip, PetClicked, PetHint
    for i = 1, PET_BAR.buttons do pet.keys[i] = P.KeyText(petCommands[i]) end
end

local function DrawPicker()
    local values, list, skip = picker.values, picker.order, draft.choices.skip
    wipe(values)
    wipe(list)
    values[MAIN_VIEW], list[1] = TEXT_MAIN_BARS, MAIN_VIEW
    for _, entry in ipairs(order) do
        if entry.other then
            local used = Counts(entry.list, skip)
            values[entry.bar.page] = TEXT_PICKED_BAR:format(entry.bar.name, used)
            list[#list + 1] = entry.bar.page
        end
    end
end

local function DrawScene(v)
    local regions = model.regions
    if not forms then formPage = MAIN_PAGE end
    local bottom = pages[formPage]
    local formName = formPage == MAIN_PAGE and TEXT_MAIN or bottom.form
    Region(regions.left, pages[LEFT_PAGE])
    Region(regions.top, pages[TOP_PAGE])
    Region(regions.right, pages[RIGHT_PAGE])
    Region(regions.bottom, bottom, pages[MAIN_PAGE].bar.name .. DOT .. formName)
    model.single = viewPage ~= MAIN_VIEW and pages[viewPage] and Region(single, pages[viewPage]) or nil
    DrawChips()
    DrawPet()
    DrawPicker()
    model.caption = TEXT_PICK_HINT
    model.Paint = PaintSlot
    P.DrawScene(v.scene, model)
end

local function ActionCount()
    local actions, skip = 0, draft.choices.skip
    for _, entry in ipairs(order) do actions = actions + Counts(entry.list, skip) end
    return actions
end

local function MacroEnter(row)
    P.Hint(row, row.tipTitle, row.tipLine)
end

local function MacroClicked(row)
    if row.locked or not draft.choices.macros then return end
    Flip(draft.choices.macroOff, row.key)
end

local function NewMacroRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(MACRO_ROW_H)
    ns.Solid(row, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(row, St.BORDER_RGB)
    row.box = P.Box(row)
    row.box:SetPoint("LEFT", MACRO_INSET, 0)
    row.box:EnableMouse(false)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(MACRO_ICON, MACRO_ICON)
    row.icon:SetPoint("LEFT", row.box, "RIGHT", MACRO_INSET, 0)
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.scope = P.Chip(row)
    row.scope:SetPoint("RIGHT", -MACRO_INSET, 0)
    row.onBars = P.Chip(row)
    row.onBars:SetPoint("RIGHT", row.scope, "LEFT", -TAG_GAP, 0)
    row.name = P.Label(row, NOTE_SIZE, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", MACRO_INSET, 0)
    row.name:SetWidth(NAME_COLUMN)
    row.name:SetWordWrap(false)
    row.body = P.Mono(row, St.MONO_SIZE, T.muted)
    row.body:SetJustifyH("LEFT")
    row.body:SetPoint("LEFT", row.name, "RIGHT", TEXT_GAP, 0)
    row.body:SetPoint("RIGHT", row.onBars, "LEFT", -TEXT_GAP, 0)
    row.body:SetWordWrap(false)
    row.onClick = MacroClicked
    row:SetScript("OnClick", P.Clicked)
    row:SetScript("OnEnter", MacroEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function OnBars(slots, skip)
    wipe(onBars)
    for slot, entry in pairs(slots) do
        if entry.kind == "macro" and not skip[slot] then onBars[Sets.MacroKey(entry.name, entry.body)] = true end
    end
    return onBars
end

local function PaintMacro(row, macro, key, locked, on, choices)
    row:SetAlpha((choices.macros or locked) and 1 or OFF_MACRO_ALPHA)
    P.PaintBox(row.box, on, locked)
    row.icon:SetTexture(macro.icon)
    row.name:SetText(macro.name)
    row.body:SetText((((macro.body or ""):gsub("[\r\n]+", BODY_JOIN))))
    P.PaintChip(row.scope, macro.perCharacter and TEXT_CHARACTER or TEXT_ACCOUNT,
        macro.perCharacter and St.CHARACTER_RGB or St.ACCOUNT_RGB)
    if locked then P.PaintChip(row.onBars, TEXT_ON_BARS, T.grey) else row.onBars:Hide() end
    row.body:SetPoint("RIGHT", locked and row.onBars or row.scope, "LEFT", -TEXT_GAP, 0)
    row.tipTitle = macro.name
    row.tipLine = locked and TEXT_ON_BARS_TIP or TEXT_REUSE_TIP
    row.key, row.locked = key, locked
end

local function DrawMacros(v, slots)
    local choices, content = draft.choices, v.macroContent
    local bars, all = OnBars(slots, choices.skip), Sets.CaptureMacros()
    ns.UI.BeginReusableRows(content)
    local kept = 0
    local width = (content:GetWidth() - MACRO_GAP) / 2
    for i, macro in ipairs(all) do
        local key = Sets.MacroKey(macro.name, macro.body)
        local locked = bars[key]
        local on = locked or (choices.macros and not choices.macroOff[key])
        if on then kept = kept + 1 end
        local row = ns.UI.Keep(content, "macro", NewMacroRow)
        local column = (i - 1) % 2
        row:SetPoint("TOPLEFT", column * (width + MACRO_GAP), -math.floor((i - 1) / 2) * (MACRO_ROW_H + MACRO_GAP))
        row:SetWidth(width)
        PaintMacro(row, macro, key, locked, on, choices)
    end
    content:SetHeight(math.max(1, math.ceil(#all / 2) * (MACRO_ROW_H + MACRO_GAP)))
    return kept, #all
end

local function BindingCount()
    local n, onBar, petOff = 0, 0, draft.choices.petOff
    for _, command in pairs(Sets.CaptureBindings()) do
        if not (petOff and Capture.PetKey(command)) then
            n = n + 1
            if barButtons[command:match(BAR_COMMAND) or command] then onBar = onBar + 1 end
        end
    end
    return n, onBar
end

local function SaveDraft()
    local name = strtrim(draft.box:GetText() or "")
    if name == "" then
        ns.Print(TEXT_NO_NAME)
        return
    end
    local function Done()
        local style = { icon = draft.icon, tags = #draft.tags > 0 and draft.tags or nil }
        if Sets.Save(name, draft.choices, style) then W.Show("sets") end
    end
    local existing = Sets.Find(name)
    if existing and existing ~= draft.key then
        ns.Confirm(TEXT_REPLACE:format(existing), Done)
    else
        Done()
    end
end

local function KeysOn() return draft.choices.keys end
local function SetKeys(on) draft.choices.keys = on; W.Redraw() end
local function MacrosOn() return draft.choices.macros end
local function SetMacros(on) draft.choices.macros = on; W.Redraw() end
local function ViewPage() return viewPage end
local function SetViewPage(page) viewPage = page; W.Redraw() end

local function BuildScene(v, top)
    v.scene = P.NewScene(v.frame)
    v.scene:SetPoint("TOPLEFT", 0, -top)
    v.scene:SetPoint("TOPRIGHT", 0, -top)
    P.ScenePicker(v.scene, picker.values, picker.order, ViewPage, SetViewPage)
end

local function BuildKeep(v, bottom)
    v.keys = P.GlassPanel(v.frame, TEXT_KEYBINDS)
    v.keys:SetPoint("TOPLEFT", v.scene, "BOTTOMLEFT", 0, -GAP)
    v.keys:SetSize(LEFT_W, PANEL_H)
    v.keysSwitch = P.PanelSwitch(v.keys, KeysOn, SetKeys)
    v.macros = P.GlassPanel(v.frame, TEXT_MACROS)
    v.macros:SetPoint("TOPLEFT", v.keys, "BOTTOMLEFT", 0, -GAP)
    v.macros:SetSize(LEFT_W, PANEL_H)
    v.macrosSwitch = P.PanelSwitch(v.macros, MacrosOn, SetMacros)
    local list = P.Glass(CreateFrame("Frame", nil, v.frame))
    list:SetPoint("TOPLEFT", v.keys, "TOPRIGHT", GAP, 0)
    list:SetPoint("BOTTOMRIGHT", 0, bottom)
    local inner = CreateFrame("Frame", nil, list)
    P.Place(inner, GLASS_PAD, GLASS_PAD, GLASS_PAD, GLASS_PAD)
    v.macroScroll, v.macroContent = P.List(inner, 0)
end

local function UnFocus(box) box:ClearFocus() end

local function AutoIcon()
    for _, page in ipairs(P.STRIP_PAGES) do
        for i = 1, SLOTS_PER_BAR do
            local texture = GetActionTexture((page - 1) * SLOTS_PER_BAR + i)
            if texture then return texture end
        end
    end
    return A.C.QUESTION
end

local function PickIcon(tile)
    draft.icon = tile.texture
    tile:GetParent():Hide()
    W.Redraw()
end

local function IconTip(tile)
    if tile.texture then return end
    P.Hint(tile, TEXT_AUTO, TEXT_ICON_TIP)
end

local function NewPickerTile(grid, i)
    local tile = CreateFrame("Button", nil, grid)
    tile:SetSize(PICKER_TILE, PICKER_TILE)
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetAllPoints()
    tile.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.Border(tile, St.BORDER_RGB)
    local column, row = (i - 1) % PICKER_COLUMNS, math.floor((i - 1) / PICKER_COLUMNS)
    tile:SetPoint("TOPLEFT", GLASS_PAD + column * (PICKER_TILE + PICKER_GAP), -(GLASS_PAD + row * (PICKER_TILE + PICKER_GAP)))
    tile:SetScript("OnClick", PickIcon)
    tile:SetScript("OnEnter", IconTip)
    tile:SetScript("OnLeave", GameTooltip_Hide)
    return tile
end

local function FillPicker(grid)
    local seen, textures = {}, { false }
    for _, slot in ipairs(Sets.SlotList()) do
        local texture = GetActionTexture(slot)
        if texture and not seen[texture] and #textures < PICKER_MAX then
            seen[texture] = true
            textures[#textures + 1] = texture
        end
    end
    for i, texture in ipairs(textures) do
        local tile = grid.tiles[i] or NewPickerTile(grid, i)
        grid.tiles[i] = tile
        tile.texture = texture or nil
        tile.icon:SetTexture(texture or A.C.QUESTION)
        tile:Show()
    end
    for i = #textures + 1, #grid.tiles do grid.tiles[i]:Hide() end
    local rows = math.ceil(#textures / PICKER_COLUMNS)
    grid:SetSize(GLASS_PAD * 2 + PICKER_COLUMNS * (PICKER_TILE + PICKER_GAP) - PICKER_GAP,
        GLASS_PAD * 2 + rows * (PICKER_TILE + PICKER_GAP) - PICKER_GAP)
end

local function TogglePicker(v)
    local grid = v.iconGrid
    if grid:IsShown() then grid:Hide() return end
    FillPicker(grid)
    grid:Show()
end

local function RemoveTag(chip)
    table.remove(draft.tags, chip.index)
    W.Redraw()
end

local function AddTag()
    ns.PromptText(TEXT_NEW_TAG, "", TAG_MAX, function(text)
        local tag = strtrim(text or "")
        if tag == "" or #draft.tags >= MAX_TAGS then return end
        for _, have in ipairs(draft.tags) do if have:lower() == tag:lower() then return end end
        draft.tags[#draft.tags + 1] = tag
        W.Redraw()
    end)
end

local function TagEnter(chip)
    P.Hint(chip, chip.text:GetText(), TEXT_TAG_TIP)
end

local function NewTagChip(parent)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(TAG_H)
    ns.Solid(chip, "BACKGROUND", St.ACCOUNT_RGB, 1):SetAllPoints()
    ns.Border(chip, St.BORDER_RGB)
    chip.text = P.Mono(chip, St.MONO_SIZE, T.fg)
    chip.text:SetPoint("CENTER")
    chip:SetScript("OnClick", RemoveTag)
    chip:SetScript("OnEnter", TagEnter)
    chip:SetScript("OnLeave", GameTooltip_Hide)
    return chip
end

local function IconEnter(icon)
    P.Hint(icon, TEXT_ICON, TEXT_ICON_TIP)
end

local function BuildIdentity(v)
    v.icon = CreateFrame("Button", nil, v.frame)
    v.icon:SetSize(ICON_BUTTON, ICON_BUTTON)
    v.icon:SetPoint("TOPLEFT", 0, -VIEW_TOP)
    v.icon.texture = v.icon:CreateTexture(nil, "ARTWORK")
    v.icon.texture:SetAllPoints()
    v.icon.texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.Border(v.icon, St.GOLD_RGB)
    v.icon:SetScript("OnClick", function() TogglePicker(v) end)
    v.icon:SetScript("OnEnter", IconEnter)
    v.icon:SetScript("OnLeave", GameTooltip_Hide)
    v.iconGrid = CreateFrame("Frame", nil, v.frame)
    v.iconGrid:SetPoint("TOPLEFT", v.icon, "BOTTOMLEFT", 0, -LINE_GAP)
    v.iconGrid:SetFrameLevel(v.frame:GetFrameLevel() + PICKER_LEVEL)
    v.iconGrid:EnableMouse(true)
    ns.Solid(v.iconGrid, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(v.iconGrid, St.BORDER_RGB)
    v.iconGrid.tiles = {}
    v.iconGrid:Hide()
    local label = P.Label(v.frame, SMALL_SIZE, T.muted)
    label:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", SUMMARY_GAP, 0)
    label:SetText(TEXT_SET_NAME)
    v.box = ns.NewEditBox(v.frame)
    v.box:SetSize(NAME_W, NAME_H)
    v.box:SetMaxLetters(NAME_MAX)
    v.box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -LINE_GAP)
    v.box:SetScript("OnEnterPressed", UnFocus)
    v.box:SetScript("OnEscapePressed", UnFocus)
    v.tagsAt = P.Label(v.frame, SMALL_SIZE, T.muted)
    v.tagsAt:SetPoint("LEFT", label, "LEFT", NAME_W + TAGS_X, 0)
    v.tagsAt:SetText(TEXT_TAGS)
    v.tagChips = {}
    v.addTag = ns.Button(v.frame, TEXT_ADD_TAG, ADD_TAG_W, TAG_H, AddTag)
end

local function BuildSummary(v)
    local bar = P.Glass(CreateFrame("Frame", nil, v.frame))
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(SUMMARY_BAR)
    v.button = P.Primary(ns.Button(bar, TEXT_SAVE_SET, SAVE_W, BUTTON_H, SaveDraft))
    v.button:SetPoint("RIGHT", -GLASS_PAD, 0)
    v.summary = P.Label(bar, St.NAME_SIZE, T.fg)
    v.summary:SetPoint("LEFT", GLASS_PAD, 0)
    v.summary:SetPoint("RIGHT", v.button, "LEFT", -SUMMARY_GAP, 0)
    v.summary:SetWordWrap(false)
end

local function PaintIdentity(v)
    v.icon.texture:SetTexture(draft.icon or AutoIcon())
    local after
    for i, tag in ipairs(draft.tags) do
        local chip = v.tagChips[i] or NewTagChip(v.frame)
        v.tagChips[i] = chip
        chip.index = i
        chip.text:SetText(ns.Upper(tag))
        chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + TAG_PAD * 2)
        chip:ClearAllPoints()
        if after then
            chip:SetPoint("LEFT", after, "RIGHT", TAG_GAP, 0)
        else
            chip:SetPoint("TOPLEFT", v.tagsAt, "BOTTOMLEFT", 0, -LINE_GAP)
        end
        chip:Show()
        after = chip
    end
    for i = #draft.tags + 1, #v.tagChips do v.tagChips[i]:Hide() end
    v.addTag:ClearAllPoints()
    if after then
        v.addTag:SetPoint("LEFT", after, "RIGHT", TAG_GAP, 0)
    else
        v.addTag:SetPoint("TOPLEFT", v.tagsAt, "BOTTOMLEFT", 0, -LINE_GAP)
    end
    v.addTag:SetShown(#draft.tags < MAX_TAGS)
end

local function Summary(actions, keys, kept)
    wipe(parts)
    parts[1] = Plural(actions, TEXT_ACTION, TEXT_ACTIONS)
    if draft.choices.keys then parts[#parts + 1] = Plural(keys, TEXT_KEYBIND, TEXT_KEYBINDS_N) end
    parts[#parts + 1] = Plural(kept, TEXT_MACRO, TEXT_MACROS_N)
    return table.concat(parts, DOT)
end

local function Draw(v)
    local slots = Sets.Capture()
    DrawScene(v)
    local kept, all = DrawMacros(v, slots)
    local choices = draft.choices
    local keys, onBar = 0, 0
    if choices.keys then keys, onBar = BindingCount() end
    v.keys.line:SetText(choices.keys and TEXT_KEYS_ON:format(keys, onBar, keys - onBar) or TEXT_KEYS_OFF)
    v.macros.line:SetText(choices.macros and TEXT_MACROS_ON:format(kept, all) or TEXT_MACROS_OFF)
    v.keysSwitch._refreshValue()
    v.macrosSwitch._refreshValue()
    v.summary:SetText(Summary(ActionCount(), keys, kept))
    PaintIdentity(v)
end

local function Order()
    pages, petCommands = P.Pages()
    forms = P.FormPages(pages)
    order = {}
    for _, bar in ipairs(Sets.BARS) do
        local entry = pages[bar.page]
        entry.other = P.IsOther(bar.page, forms)
        order[#order + 1] = entry
    end
end

function Builder.PickForm(chip)
    formPage = chip.page
    W.Redraw()
end

function Builder.NewDraft(key)
    local set = key and Sets.Get(key)
    local choices = set and set.choices or {}
    local tags = {}
    for i, tag in ipairs(set and set.tags or {}) do tags[i] = tag end
    draft = {
        key = set and key or nil, name = set and key or "", icon = set and set.icon, tags = tags,
        choices = { skip = Copy(choices.skip), macroOff = Copy(choices.macroOff),
            keys = choices.keys ~= false, macros = choices.macros ~= false, petOff = choices.petOff or nil },
    }
end

function Builder.HasDraft()
    return draft ~= nil
end

function Builder.Build(window)
    W = window
    local v = { cards = {} }
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    BuildIdentity(v)
    BuildScene(v, VIEW_TOP + IDENT_H + GAP)
    BuildKeep(v, SUMMARY_BAR + GAP)
    BuildSummary(v)
    v.title = TEXT_TITLE
    function v.Open()
        Order()
        viewPage, formPage = MAIN_VIEW, MAIN_PAGE
        v.box:SetText(draft.name)
        draft.box = v.box
        v.iconGrid:Hide()
        v.title = draft.key and (TEXT_EDIT .. draft.key) or TEXT_TITLE
        v.subtitle = TEXT_SUBTITLE:format(UnitClass("player"))
    end
    function v.Draw() Draw(v) end
    v.events = { "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "UPDATE_MACROS", "PET_BAR_UPDATE" }
    return v
end
