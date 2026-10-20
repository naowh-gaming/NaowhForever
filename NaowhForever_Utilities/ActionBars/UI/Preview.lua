-- Preview.lua: the Bar Sets tab's import preview: your bars on the scene's strip as an import would leave them, then what comes across (ns.ActionBars.Preview).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets

local VIEW_TOP, GAP, GLASS_PAD = St.VIEW_TOP, St.CARD_GAP, St.GLASS_PAD
local OUT_ALPHA, BUTTON_H, LINE_GAP, CHIP_H = St.OUT_ALPHA, St.BUTTON_H, St.LINE_GAP, St.CHIP_H
local NEW_RGB, LATER_RGB, GREEN_RGB, RED_RGB = St.NEW_RGB, St.LATER_RGB, St.GREEN_RGB, St.RED_RGB
local Import = A.Import
local SMALL_SIZE, NOTE_SIZE, NAME_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.NAME_SIZE
local MAIN_PAGE, LEFT_PAGE, TOP_PAGE, RIGHT_PAGE, MAIN_VIEW = P.MAIN_PAGE, P.LEFT_PAGE, P.TOP_PAGE, P.RIGHT_PAGE, P.MAIN_VIEW
local PET_BAR, PET_CLASSES = A.PET_BAR, A.PET_CLASSES
local DOT = St.PLACE_DOT
local LATER_ALPHA, SAME_ALPHA = 0.45, 0.55
local PANELS = 3
local ACTION_BAR = 46
local LEGEND_TEXT_GAP, LEGEND_GAP = 6, 18
local PANEL_LIST_TOP = 52
local FILL_H, FILL_GAP = 46, 10
local MACROS_SHOWN, NAMES_SHOWN, MACRO_LINE_PAD, KEYS_SHOWN = 6, 6, 4, 6
local KEY_COLUMN = 76
local BUTTON_GAP, CANCEL_W, IMPORT_W = 8, 110, 160
local SAVED_DATE = "%d %b %Y"
local BODY_GREY = 0.8

local TEXT_CAPTION = ns.L("%s change: %s. Nothing changes until you press Import.")
local TEXT_SLOT, TEXT_SLOTS = ns.L("%d slot"), ns.L("%d slots")
local TEXT_ADDED_N, TEXT_SWAPPED_N, TEXT_CLEARED_N = ns.L("%d added"), ns.L("%d swapped"), ns.L("%d cleared")
local TEXT_LATER_N = ns.L("%d later")
local TEXT_SAME = ns.L("Your bars already match this set. Nothing changes until you press Import.")
local TEXT_ADDED, TEXT_SWAPPED, TEXT_CLEARED = ns.L("ADDED"), ns.L("SWAPPED"), ns.L("CLEARED")
local TEXT_CLEARED_TIP = ns.L("The set keeps this slot empty, so the import takes this off.")
local TEXT_SWAPPED_TIP = ns.L("Something else is here now: the import swaps it.")
local TEXT_IMPORT_N = ns.L("Import %d changes")
local TEXT_IMPORT_ONE = ns.L("Import 1 change")
local TEXT_ACTIONS_TITLE = ns.L("Actions")
local TEXT_ACTIONS_OFF = ns.L("Off: your bars stay as they are.")
local TEXT_KEYS_SAME = ns.L("Every key already does what the set binds.")
local TEXT_KEY_CHANGE = "%s  ->  %s"
local TEXT_UNBOUND = ns.L("nothing")
local TEXT_NEW_LEGEND = ns.L("a macro made on this character")
local TEXT_LATER_LEGEND = ns.L("not learned yet")
local TEXT_FILL = ns.L("Fill in as you learn them")
local TEXT_FILL_LINE = ns.L("A trained spell drops into its saved slot.")
local TEXT_FILL_ALWAYS = ns.L("Fills in as you learn them")
local TEXT_FILL_ALWAYS_LINE = ns.L("A website layout always does: each spell drops into its slot when learned.")
local TEXT_CANCEL, TEXT_IMPORT = ns.L("Cancel"), ns.L("Import")
local TEXT_TITLE = "Import"
local TEXT_TITLE_KEY = ns.L("Import ")
local TEXT_SUBTITLE = ns.L("Onto %s, level %d %s. Saved %s%s.")
local TEXT_BY = ns.L(" by ")
local TEXT_MAIN, TEXT_MAIN_BARS, TEXT_PET_BAR = ns.L("Main"), ns.L("Main bars"), ns.L("Pet Bar")
local TEXT_PICKED_BAR = "%s (%d)"
local TEXT_CHIP = "%s %d"
local TEXT_EMPTY_SLOT = ns.L("Empty slot")
local TEXT_NOT_IN_SET = ns.L("Not in the set: stays as it is.")
local TEXT_PET_KEYS = ns.L("Only this button's keys come across.")
local TEXT_LEVEL = ns.L("You learn this at level %d.")
local TEXT_TRAIN = ns.L("Not known yet: train it, or take its talent.")
local TEXT_GONE = ns.L("Cannot come back here, so the slot is left empty.")
local TEXT_NEW_MACRO = ns.L("A macro this character does not have yet: the import makes it.")
local TEXT_ACTION, TEXT_ACTIONS = ns.L("%d of %d action"), ns.L("%d of %d actions")
local TEXT_LATER_LINE = ns.L("%d you have not learned yet: %s.")
local TEXT_GONE_LINE = ns.L("%d cannot come back: %s.")
local TEXT_ALL_BACK = ns.L("Everything goes back where it was.")
local TEXT_MACROS = ns.L("Macros")
local TEXT_MACROS_OFF = ns.L("Off: a macro this character lacks stays missing.")
local TEXT_MACRO, TEXT_MACROS_N = ns.L("%d macro"), ns.L("%d macros")
local TEXT_MACRO_FATES = ns.L("%s: %d new, %d already here")
local TEXT_NO_ROOM_COUNT = ns.L(", %d no room")
local TEXT_NO_MACROS = ns.L("No macros in this set")
local TEXT_MACROS_SAFE = ns.L("Your macros are never changed or copied twice.")
local TEXT_NEW, TEXT_HERE, TEXT_NO_ROOM = ns.L("New"), ns.L("Already here"), ns.L("No room")
local TEXT_MORE = ns.L("and %d more")
local TEXT_MORE_NAMES = ns.L(", and %d more")
local TEXT_NO_KEYS = ns.L("No keybinds in this set")
local TEXT_KEYS_STAY = ns.L("Your keys stay as they are.")
local TEXT_KEYBINDS = ns.L("Keybinds")
local TEXT_KEYS_OFF = ns.L("Off: your keys stay as they are.")
local TEXT_KEYBIND, TEXT_KEYBINDS_N = ns.L("%d keybind"), ns.L("%d keybinds")
local TEXT_KEYS_FREE = ns.L("Keys the set leaves free keep what they do here.")
local BADGE_NEW, BADGE_LEVEL, BADGE_TRAIN, BADGE_GONE = "NEW", "LV", "TRAIN", "GONE"

local Plural = A.Plural

local Preview = {}
A.Preview = Preview

local W, importKey, preview, keyFor, opts
local later, gone, byCommand, slotOf, keyChanges = {}, {}, {}, {}, {}
local counts = { added = 0, swapped = 0, cleared = 0, later = 0 }
local pages, petCommands, forms
local viewPage, formPage = MAIN_VIEW, MAIN_PAGE
local model = { regions = { left = {}, top = {}, bottom = {}, right = {} }, chips = {}, pet = nil }
local single, petLook, chipPool = {}, { keys = {} }, {}
local picker = { values = {}, order = {} }

local function MutedLine(tip, line)
    tip:AddLine(" ")
    tip:AddLine(line, T.muted.r, T.muted.g, T.muted.b, true)
end

local function EntryTip(entry, line)
    return function(tip)
        if entry.kind == "spell" then
            tip:SetSpellByID(entry.id)
        elseif entry.kind == "item" then
            tip:SetItemByID(entry.id)
        else
            tip:SetText(Sets.Describe(entry), 1, 1, 1)
            if entry.kind == "macro" and entry.body then tip:AddLine(entry.body, BODY_GREY, BODY_GREY, BODY_GREY, true) end
        end
        if line then MutedLine(tip, line) end
    end
end

local function PetTip(tip)
    tip:SetText(TEXT_PET_BAR, 1, 1, 1)
    MutedLine(tip, TEXT_PET_KEYS)
end

local function SetKey(command)
    local key = byCommand[command]
    return key and ns.Shared.ActionKeys.Text(key) or ""
end

local function PreviewKeys(set)
    if not (set.bindings and opts.keys) then return P.KeyText end
    wipe(byCommand)
    for key, command in pairs(set.bindings) do
        if not byCommand[command] or #key < #byCommand[command] then byCommand[command] = key end
    end
    return SetKey
end

local function SkipLook(slot, key)
    return { texture = GetActionTexture(slot), key = key, alpha = OUT_ALPHA, grey = true,
        tip = function(tip)
            if GetActionInfo(slot) then tip:SetAction(slot) else tip:SetText(TEXT_EMPTY_SLOT, 1, 1, 1) end
            MutedLine(tip, TEXT_NOT_IN_SET)
        end }
end

local function SameAction(slot, entry)
    local kind, id = GetActionInfo(slot)
    if kind ~= entry.kind then return false end
    if kind == "macro" then return C_ActionBar.GetActionText(slot) == entry.name end
    if kind == "spell" then return id == entry.id or C_Spell.GetSpellName(id) == A.Capture.SpellName(entry) end
    return id == entry.id
end

local function Change(slot, row)
    local state = row.state
    if state == "skip" then return nil end
    local here = GetActionInfo(slot) ~= nil
    if state == "clear" or state == "gone" or state == "later" then return here and "cleared" or nil end
    if not here then return "added" end
    return not SameAction(slot, row.entry) and "swapped" or nil
end

local function ClearedLook(slot, key)
    return { texture = GetActionTexture(slot), key = key, alpha = OUT_ALPHA, grey = true, mark = true, edge = RED_RGB,
        tip = function(tip)
            tip:SetAction(slot)
            MutedLine(tip, TEXT_CLEARED_TIP)
        end }
end

local function LaterLook(entry, row, key)
    local level = row.level or 0
    local mine = UnitLevel("player")
    return { texture = P.EntryTexture(entry), key = key, alpha = LATER_ALPHA, grey = true, edge = LATER_RGB,
        badge = level > mine and (BADGE_LEVEL .. level) or BADGE_TRAIN, badgeColor = LATER_RGB,
        tip = EntryTip(entry, level > mine and TEXT_LEVEL:format(level) or TEXT_TRAIN) }
end

local function PreviewLook(slot, row, key)
    local entry, state = row.entry, row.state
    local change = Change(slot, row)
    if state == "skip" then return SkipLook(slot, key) end
    if state == "clear" then return change and ClearedLook(slot, key) or { key = key } end
    if state == "later" then return LaterLook(entry, row, key) end
    if state == "gone" then
        return { texture = P.EntryTexture(entry), key = key, alpha = OUT_ALPHA, grey = true,
            badge = BADGE_GONE, badgeColor = T.grey, tip = EntryTip(entry, TEXT_GONE) }
    end
    local edge = (state == "new" and T.accent) or (change == "added" and GREEN_RGB) or (change == "swapped" and T.accent)
    return { texture = P.EntryTexture(entry), key = key, edge = edge or nil, alpha = change and 1 or SAME_ALPHA,
        badge = state == "new" and BADGE_NEW or nil, badgeColor = NEW_RGB,
        tip = EntryTip(entry, (state == "new" and TEXT_NEW_MACRO) or (change == "swapped" and TEXT_SWAPPED_TIP) or nil) }
end

local function Count()
    for k in pairs(counts) do counts[k] = 0 end
    for slot, row in pairs(preview.slots) do
        local change = Change(slot, row)
        if row.state == "later" then counts.later = counts.later + 1 end
        if change then counts[change] = counts[change] + 1 end
    end
    return counts.added + counts.swapped + counts.cleared
end

local function Caption(changed)
    if not opts.actions then return TEXT_ACTIONS_OFF end
    if changed == 0 then return TEXT_SAME end
    local parts = {}
    if counts.added > 0 then parts[#parts + 1] = TEXT_ADDED_N:format(counts.added) end
    if counts.swapped > 0 then parts[#parts + 1] = TEXT_SWAPPED_N:format(counts.swapped) end
    if counts.cleared > 0 then parts[#parts + 1] = TEXT_CLEARED_N:format(counts.cleared) end
    if counts.later > 0 then parts[#parts + 1] = TEXT_LATER_N:format(counts.later) end
    return TEXT_CAPTION:format(Plural(changed, TEXT_SLOT, TEXT_SLOTS), table.concat(parts, ", "))
end

local function PaintSlot(tile, region, i)
    local slot = region.entry.list[i]
    P.PaintTile(tile, PreviewLook(slot, preview.slots[slot], keyFor(region.entry.commands[i])))
    tile.slot = slot
end

local function Placed(list)
    local placed = 0
    for _, slot in ipairs(list) do
        local row = preview.slots[slot]
        if row and (row.state == "ok" or row.state == "new") then placed = placed + 1 end
    end
    return placed
end

local function Region(region, entry, label, form)
    region.entry, region.label, region.form, region.out = entry, label or entry.bar.name, form, false
    return region
end

local function DrawChips()
    wipe(model.chips)
    for i, page in ipairs(forms or {}) do
        local entry = pages[page]
        local chip = chipPool[i] or {}
        chipPool[i] = chip
        chip.text = TEXT_CHIP:format(page == MAIN_PAGE and TEXT_MAIN or entry.form, Placed(entry.list))
        chip.picked, chip.page, chip.onClick = page == formPage, page, Preview.PickForm
        model.chips[i] = chip
    end
end

local function DrawPet(set)
    if not PET_CLASSES[A.Class()] then
        model.pet = nil
        return
    end
    model.pet = petLook
    local off = set.choices and set.choices.petOff
    petLook.label, petLook.out = TEXT_PET_BAR, off or false
    petLook.tip = PetTip
    local keys = off and P.KeyText or keyFor
    for i = 1, PET_BAR.buttons do petLook.keys[i] = keys(petCommands[i]) end
end

local function DrawPicker()
    local values, list = picker.values, picker.order
    wipe(values)
    wipe(list)
    values[MAIN_VIEW], list[1] = TEXT_MAIN_BARS, MAIN_VIEW
    for _, bar in ipairs(A.BARS) do
        if P.IsOther(bar.page, forms) then
            values[bar.page] = TEXT_PICKED_BAR:format(bar.name, Placed(pages[bar.page].list))
            list[#list + 1] = bar.page
        end
    end
end

local function DrawScene(v, set)
    keyFor = PreviewKeys(set)
    local regions = model.regions
    if not forms then formPage = MAIN_PAGE end
    local formName = formPage == MAIN_PAGE and TEXT_MAIN or pages[formPage].form
    Region(regions.left, pages[LEFT_PAGE])
    Region(regions.top, pages[TOP_PAGE])
    Region(regions.right, pages[RIGHT_PAGE])
    Region(regions.bottom, pages[formPage], pages[MAIN_PAGE].bar.name .. DOT .. formName, forms ~= nil)
    model.single = viewPage ~= MAIN_VIEW and pages[viewPage] and Region(single, pages[viewPage]) or nil
    DrawChips()
    DrawPet(set)
    DrawPicker()
    model.caption, model.Paint = Caption(Count()), PaintSlot
    P.DrawScene(v.scene, model)
end

local function Names(list, shown)
    local text = table.concat(list, ", ", 1, math.min(#list, shown))
    if #list > shown then text = text .. TEXT_MORE_NAMES:format(#list - shown) end
    return text
end

local function FillLater() return S.Get("fillLater") end
local function SetFillLater(on) S.Set("fillLater", on) end

local function BuildFill(v, panel)
    v.fill = CreateFrame("Frame", nil, panel)
    v.fill:SetHeight(FILL_H)
    ns.Solid(v.fill, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(v.fill, St.BORDER_RGB)
    v.fillName = P.Label(v.fill, NAME_SIZE, T.fg)
    v.fillName:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD + LINE_GAP)
    v.fillName:SetPoint("TOPRIGHT", -(GLASS_PAD * 2 + St.SWITCH_W), -GLASS_PAD + LINE_GAP)
    v.fillLine = P.Label(v.fill, SMALL_SIZE, T.muted)
    v.fillLine:SetPoint("TOPLEFT", v.fillName, "BOTTOMLEFT", 0, -St.STACK_GAP)
    v.fillLine:SetPoint("TOPRIGHT", v.fillName, "BOTTOMRIGHT", 0, -St.STACK_GAP)
    v.fillSwitch = P.Switch(v.fill, FillLater, SetFillLater)
    v.fillSwitch:SetPoint("RIGHT", -GLASS_PAD, 0)
end

local function BuildMacroRows(v, panel)
    v.macroRows = {}
    for i = 1, MACROS_SHOWN do
        local line = CreateFrame("Frame", nil, panel)
        line:SetHeight(CHIP_H + MACRO_LINE_PAD)
        local y = -(PANEL_LIST_TOP + (i - 1) * (CHIP_H + MACRO_LINE_PAD + LINE_GAP))
        line:SetPoint("TOPLEFT", GLASS_PAD, y)
        line:SetPoint("TOPRIGHT", -GLASS_PAD, y)
        line.name = P.Label(line, NOTE_SIZE, T.fg)
        line.name:SetPoint("LEFT")
        line.chip = P.Chip(line)
        line.chip:SetPoint("RIGHT")
        v.macroRows[i] = line
    end
    v.macroMore = P.Label(panel, SMALL_SIZE, T.muted)
    v.macroMore:SetPoint("TOPLEFT", v.macroRows[MACROS_SHOWN], "BOTTOMLEFT", 0, -LINE_GAP)
end

local function BuildKeyRows(v, panel)
    v.keyRows = {}
    for i = 1, KEYS_SHOWN do
        local line = CreateFrame("Frame", nil, panel)
        line:SetHeight(CHIP_H + MACRO_LINE_PAD)
        local y = -(PANEL_LIST_TOP + (i - 1) * (CHIP_H + MACRO_LINE_PAD + LINE_GAP))
        line:SetPoint("TOPLEFT", GLASS_PAD, y)
        line:SetPoint("TOPRIGHT", -GLASS_PAD, y)
        line.key = P.Mono(line, St.MONO_SIZE, St.GOLD_SOFT_RGB)
        line.key:SetPoint("LEFT")
        line.key:SetWidth(KEY_COLUMN)
        line.key:SetJustifyH("LEFT")
        line.text = P.Label(line, NOTE_SIZE, T.fg)
        line.text:SetPoint("LEFT", KEY_COLUMN, 0)
        line.text:SetPoint("RIGHT")
        line.text:SetWordWrap(false)
        v.keyRows[i] = line
    end
    v.keyMore = P.Label(panel, SMALL_SIZE, T.muted)
    v.keyMore:SetPoint("TOPLEFT", v.keyRows[KEYS_SHOWN], "BOTTOMLEFT", 0, -LINE_GAP)
end

local function ImportNow()
    if Sets.Import(importKey, false, opts) then W.Show("sets") end
end

local function Repreview()
    preview = Sets.Preview(importKey, opts)
    W.Redraw()
end

local function Choice(key)
    return function() return opts ~= nil and opts[key] end,
        function(on) opts[key] = on; Repreview() end
end

local function Cancel()
    W.Show("sets")
end

local function Legend(bar)
    local newChip = P.Chip(bar)
    newChip:SetPoint("LEFT", GLASS_PAD, 0)
    P.PaintChip(newChip, BADGE_NEW, NEW_RGB)
    local newText = ns.Font(bar, SMALL_SIZE, nil, T.muted)
    newText:SetPoint("LEFT", newChip, "RIGHT", LEGEND_TEXT_GAP, 0)
    newText:SetText(TEXT_NEW_LEGEND)
    local laterChip = P.Chip(bar)
    laterChip:SetPoint("LEFT", newText, "RIGHT", LEGEND_GAP, 0)
    P.PaintChip(laterChip, BADGE_LEVEL, LATER_RGB)
    local laterText = ns.Font(bar, SMALL_SIZE, nil, T.muted)
    laterText:SetPoint("LEFT", laterChip, "RIGHT", LEGEND_TEXT_GAP, 0)
    laterText:SetText(TEXT_LATER_LEGEND)
    local after = laterText
    for _, look in ipairs({ { TEXT_ADDED, GREEN_RGB }, { TEXT_SWAPPED, T.accent }, { TEXT_CLEARED, RED_RGB } }) do
        local chip = P.Chip(bar)
        chip:SetPoint("LEFT", after, "RIGHT", LEGEND_GAP, 0)
        P.PaintChip(chip, look[1], look[2])
        after = chip
    end
end

local function BuildActionBar(v)
    local bar = P.Glass(CreateFrame("Frame", nil, v.frame))
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(ACTION_BAR)
    Legend(bar)
    v.import = P.Primary(ns.Button(bar, TEXT_IMPORT, IMPORT_W, BUTTON_H, ImportNow))
    v.import:SetPoint("RIGHT", -GLASS_PAD, 0)
    local cancel = ns.Button(bar, TEXT_CANCEL, CANCEL_W, BUTTON_H, Cancel)
    cancel:SetPoint("RIGHT", v.import, "LEFT", -BUTTON_GAP, 0)
end

local function PanelWidths(v, w)
    local width = (w - GAP * (PANELS - 1)) / PANELS
    v.actions:SetWidth(width)
    v.macros:SetWidth(width)
    v.keys:SetWidth(width)
end

local function BuildPanels(v)
    v.actions = P.GlassPanel(v.frame)
    v.actions:SetPoint("TOPLEFT", v.scene, "BOTTOMLEFT", 0, -GAP)
    v.actions:SetPoint("BOTTOMLEFT", 0, ACTION_BAR + GAP)
    v.macros = P.GlassPanel(v.frame)
    v.macros:SetPoint("TOPLEFT", v.actions, "TOPRIGHT", GAP, 0)
    v.macros:SetPoint("BOTTOMLEFT", v.actions, "BOTTOMRIGHT", GAP, 0)
    v.keys = P.GlassPanel(v.frame)
    v.keys:SetPoint("TOPLEFT", v.macros, "TOPRIGHT", GAP, 0)
    v.keys:SetPoint("BOTTOMLEFT", v.macros, "BOTTOMRIGHT", GAP, 0)
    v.switches = { P.PanelSwitch(v.actions, Choice("actions")), P.PanelSwitch(v.macros, Choice("macros")),
        P.PanelSwitch(v.keys, Choice("keys")) }
    BuildFill(v, v.actions)
    BuildMacroRows(v, v.macros)
    BuildKeyRows(v, v.keys)
end

local function Collect()
    wipe(later)
    wipe(gone)
    for _, slot in ipairs(Sets.SlotList()) do
        local row = preview.slots[slot]
        if row.state == "later" then later[#later + 1] = Sets.Describe(row.entry) end
        if row.state == "gone" then gone[#gone + 1] = Sets.Describe(row.entry) end
    end
end

local function DrawActions(v)
    if not opts.actions then
        v.actions.title:SetText(TEXT_ACTIONS_TITLE)
        v.actions.line:SetText(TEXT_ACTIONS_OFF)
        return
    end
    Collect()
    local total = preview.actions
    v.actions.title:SetText((total == 1 and TEXT_ACTION or TEXT_ACTIONS):format(preview.placed, total))
    local lines = {}
    if #later > 0 then lines[#lines + 1] = TEXT_LATER_LINE:format(#later, Names(later, NAMES_SHOWN)) end
    if #gone > 0 then lines[#lines + 1] = TEXT_GONE_LINE:format(#gone, Names(gone, NAMES_SHOWN)) end
    v.actions.line:SetText(#lines > 0 and table.concat(lines, " ") or TEXT_ALL_BACK)
end

local function DrawFill(v, set)
    local always = set.choices and set.choices.website
    v.fillName:SetText(always and TEXT_FILL_ALWAYS or TEXT_FILL)
    v.fillLine:SetText(always and TEXT_FILL_ALWAYS_LINE or TEXT_FILL_LINE)
    v.fillSwitch:SetShown(not always)
    v.fill:SetShown(opts.actions and #later > 0)
    v.fill:ClearAllPoints()
    v.fill:SetPoint("TOPLEFT", v.actions.line, "BOTTOMLEFT", 0, -FILL_GAP)
    v.fill:SetPoint("TOPRIGHT", v.actions.line, "BOTTOMRIGHT", 0, -FILL_GAP)
    v.fillSwitch._refreshValue()
end

local function Fates(fates)
    local new, have, full = 0, 0, 0
    for _, m in ipairs(fates) do
        if m.fate == "new" then new = new + 1 elseif m.fate == "have" then have = have + 1 else full = full + 1 end
    end
    return new, have, full
end

local function DrawMacroTitle(v, fates)
    if not opts.macros then
        v.macros.title:SetText(TEXT_MACROS)
        v.macros.line:SetText(TEXT_MACROS_OFF)
        return
    end
    local new, have, full = Fates(fates)
    local title = TEXT_MACRO_FATES:format(Plural(#fates, TEXT_MACRO, TEXT_MACROS_N), new, have)
    if full > 0 then title = title .. TEXT_NO_ROOM_COUNT:format(full) end
    v.macros.title:SetText(#fates > 0 and title or TEXT_NO_MACROS)
    v.macros.line:SetText(TEXT_MACROS_SAFE)
end

local function PaintFate(line, m)
    line.name:SetText(m.name)
    if m.fate == "new" then
        P.PaintChip(line.chip, TEXT_NEW, NEW_RGB)
    elseif m.fate == "have" then
        P.PaintChip(line.chip, TEXT_HERE, T.grey)
    else
        P.PaintChip(line.chip, TEXT_NO_ROOM, St.RED_RGB)
    end
end

local function DrawMacroRows(v, fates)
    local on = opts.macros
    for i, line in ipairs(v.macroRows) do
        local m = on and fates[i]
        line:SetShown(m and true or false)
        if m then PaintFate(line, m) end
    end
    local more = on and #fates - MACROS_SHOWN or 0
    v.macroMore:SetShown(more > 0)
    if more > 0 then v.macroMore:SetText(TEXT_MORE:format(more)) end
end

local function DrawKeys(v, set)
    if not set.bindings then
        v.keys.title:SetText(TEXT_NO_KEYS)
        v.keys.line:SetText(TEXT_KEYS_STAY)
    elseif not opts.keys then
        v.keys.title:SetText(TEXT_KEYBINDS)
        v.keys.line:SetText(TEXT_KEYS_OFF)
    else
        v.keys.title:SetText(Plural(preview.bound or 0, TEXT_KEYBIND, TEXT_KEYBINDS_N))
        v.keys.line:SetText(#keyChanges > 0 and TEXT_KEYS_FREE or TEXT_KEYS_SAME)
    end
end

local function ActionName(command, entry)
    if entry then return Sets.Describe(entry) end
    local slot = slotOf[command]
    local kind, id = GetActionInfo(slot or 0)
    if kind == "spell" then return C_Spell.GetSpellName(id) end
    if kind == "macro" then return C_ActionBar.GetActionText(slot) end
    if kind == "item" then return C_Item.GetItemNameByID(id) end
    return _G["BINDING_NAME_" .. command] or command
end

local function KeyChanges(set)
    wipe(keyChanges)
    if not (set.bindings and opts.keys) then return end
    for key, command in pairs(set.bindings) do
        local was = GetBindingAction(key)
        if was ~= command then
            keyChanges[#keyChanges + 1] = { key = key, was = was ~= "" and was or nil, now = command }
        end
    end
    table.sort(keyChanges, function(a, b) return a.key < b.key end)
end

local function DrawKeyRows(v, set)
    KeyChanges(set)
    for i, line in ipairs(v.keyRows) do
        local change = keyChanges[i]
        line:SetShown(change ~= nil)
        if change then
            line.key:SetText(ns.Shared.ActionKeys.Text(change.key))
            local was = change.was and ActionName(change.was) or TEXT_UNBOUND
            line.text:SetText(TEXT_KEY_CHANGE:format(was, ActionName(change.now, set.slots[slotOf[change.now] or 0])))
        end
    end
    local more = #keyChanges - KEYS_SHOWN
    v.keyMore:SetShown(more > 0)
    if more > 0 then v.keyMore:SetText(TEXT_MORE:format(more)) end
end

local function ViewPage() return viewPage end
local function SetViewPage(page) viewPage = page; W.Redraw() end

local function Draw(v)
    local set = Sets.Get(importKey)
    if not set then W.Show("sets") return end
    DrawScene(v, set)
    DrawActions(v)
    DrawFill(v, set)
    DrawMacroTitle(v, preview.macros)
    DrawMacroRows(v, preview.macros)
    DrawKeyRows(v, set)
    DrawKeys(v, set)
    for _, switch in ipairs(v.switches) do switch._refreshValue() end
    local changed = counts.added + counts.swapped + counts.cleared
    ns.SetButtonText(v.import, changed == 1 and TEXT_IMPORT_ONE or changed > 1 and TEXT_IMPORT_N:format(changed)
        or TEXT_IMPORT)
end

local function Open(v)
    local set = Sets.Get(importKey)
    v.title = TEXT_TITLE_KEY .. importKey
    v.subtitle = TEXT_SUBTITLE:format(UnitName("player"), UnitLevel("player"),
        UnitClass("player"), date(ns.L(SAVED_DATE), set.saved), set.by and (TEXT_BY .. set.by) or "")
    opts = Import.Options()
    preview = Sets.Preview(importKey, opts)
    pages, petCommands = P.Pages()
    forms = P.FormPages(pages)
    wipe(slotOf)
    for _, bar in ipairs(A.BARS) do
        local entry = pages[bar.page]
        for i, command in ipairs(entry.commands) do slotOf[command] = slotOf[command] or entry.list[i] end
    end
    viewPage, formPage = MAIN_VIEW, MAIN_PAGE
end

function Preview.SetKey(key)
    importKey = key
end

function Preview.PickForm(chip)
    formPage = chip.page
    W.Redraw()
end

function Preview.Build(window)
    W = window
    local v = { cards = {} }
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    v.frame:SetScript("OnSizeChanged", function(_, w) PanelWidths(v, w) end)
    v.scene = P.NewScene(v.frame)
    v.scene:SetPoint("TOPLEFT", 0, -VIEW_TOP)
    v.scene:SetPoint("TOPRIGHT", 0, -VIEW_TOP)
    P.ScenePicker(v.scene, picker.values, picker.order, ViewPage, SetViewPage)
    BuildPanels(v)
    BuildActionBar(v)
    v.title = TEXT_TITLE
    function v.Open() Open(v) end
    function v.Draw() Draw(v) end
    return v
end
