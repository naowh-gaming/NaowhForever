-- Builder.lua: the Action Bars window's set builder: a strip of its three steps, your bars as the game shows them with each slot in or out, keybinds and macros, then a name (ns.ActionBars.Builder).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets
local Capture = A.Capture

local WIDTH, HEIGHT, CARD, SIDE_W, GAP = St.WIDTH, St.HEIGHT, St.CARD, St.SIDE_W, St.CARD_GAP
local HEADER, FOOTER, INNER = St.WINDOW_HEADER, St.WINDOW_FOOTER, St.INNER
local ROW_GAP, ROW_FILL, ICON_CROP, OUT_ALPHA = St.ROW_GAP, St.ROW_FILL, St.ICON_CROP, St.OUT_ALPHA
local SWITCH_W, BUTTON_H, LINE_GAP, STACK_GAP = St.SWITCH_W, St.BUTTON_H, St.LINE_GAP, St.STACK_GAP
local BLACK, PICK, SLOTS_PER_BAR = St.BORDER_RGB, St.PICK_RGB, A.C.SLOTS_PER_BAR
local SMALL_SIZE, NOTE_SIZE, NAME_SIZE, TITLE_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.NAME_SIZE, St.TITLE_SIZE
local PET_BAR, PET_CLASSES, FORMS = A.PET_BAR, A.PET_CLASSES, A.FORMS
local DOT = St.PLACE_DOT
local TILE = 36
local STRIP_H, STEP_GAP, STEP_LINE, STEP_NUM_GAP, STEP_PAD = 36, 26, 2, 7, 4
local NAME_BAR, HINT_H = 70, 24
local OFF_BAR_ALPHA, OFF_MACRO_ALPHA = 0.45, 0.45
local BOX_GAP, TAG_GAP = 8, 8
local MACRO_ROW_H, MACRO_GAP, MACRO_INSET, MACRO_ICON_PAD = 44, 4, 8, 14
local CHIP_INSET_X, CHIP_INSET_Y, TEXT_GAP = 8, 7, 6
local OPTION_H, OPTION_GAP, OPTION_INSET = 60, 8, 10
local NAME_H, NAME_MAX, NAME_W, SUMMARY_GAP, SAVE_W = 26, 40, 260, 18, 120
local SAVE_SINK = (BUTTON_H - NAME_H) / 2
local EMPTY_GAP = 8
local STEP_BARS, STEP_KEEP, STEP_NAME = 1, 2, 3
local NONE = {}

local TEXT_TITLE, TEXT_EDIT = ns.L("New Bar Set"), ns.L("Edit ")
local TEXT_SUBTITLE = ns.L("Pick what goes in, then import it on any %s.")
local TEXT_STEPS = { ns.L("Bars"), ns.L("Keybinds & macros"), ns.L("Name") }
local TEXT_PICK_HINT = ns.L("Click a slot to leave it out, or a bar's box for the whole bar.")
local TEXT_SHOW_EMPTY = ns.L("Show empty bars")
local TEXT_MAIN, TEXT_PET_BAR, TEXT_KEYS_ONLY = ns.L("Main"), ns.L("Pet Bar"), ns.L("keys only")
local TEXT_KEYBINDS, TEXT_MACROS, TEXT_SET_NAME = ns.L("Keybinds"), ns.L("Macros"), ns.L("Set name")
local TEXT_SAVE_SET = ns.L("Save Set")
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
local TEXT_KEYS_ON = ns.L("All %d bound keys come along.")
local TEXT_KEYS_OFF = ns.L("Off: an import leaves your keys alone.")
local TEXT_MACROS_ON = ns.L("%d of %d come along. An alt reuses the ones it has.")
local TEXT_MACROS_OFF = ns.L("Only the macros on your kept slots come along.")
local BODY_JOIN = "  "

local Plural = A.Plural

local Builder = {}
A.Builder = Builder

local W, V, draft
local showEmpty = false
local onBars, look, parts, added = {}, {}, {}, {}
local pages, order, petCommands
local petRow = { pet = true }

local function Copy(t)
    local out = {}
    for k, val in pairs(t or {}) do out[k] = val end
    return out
end

local function PaintSteps(v)
    for i, step in ipairs(v.steps) do
        local on = i == draft.step
        local text = on and T.fg or T.muted
        step.label:SetTextColor(text.r, text.g, text.b)
        P.PaintChip(step.number, tostring(i), on and PICK or T.grey)
        local digit = on and T.bg or T.fg
        step.number.text:SetTextColor(digit.r, digit.g, digit.b)
        step.line:SetShown(on)
    end
end

local function Step(n)
    if draft.step == n then return end
    draft.step = n
    if V then PaintSteps(V) end
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
    Step(STEP_BARS)
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

local function BoxEnter(box)
    if box.pet then
        P.Hint(box, box.barOn and TEXT_LEAVE_PET or TEXT_PUT_PET, TEXT_PET_HINT)
    else
        P.Hint(box, box.barOn and TEXT_LEAVE_BAR or TEXT_PUT_BAR, TEXT_BAR_HINT)
    end
end

local function BoxClicked(box)
    Step(STEP_BARS)
    local choices = draft.choices
    if box.pet then
        if not choices.keys then return end
        choices.petOff = not choices.petOff or nil
    else
        for _, slot in ipairs(box.list) do choices.skip[slot] = box.barOn or nil end
    end
    W.Redraw()
end

local function NewRow(parent)
    local row = P.NewBarRow(parent, TILE)
    row.name:SetPoint("LEFT", row.box, "RIGHT", BOX_GAP, 0)
    row.tag = P.Chip(row)
    row.tag:SetPoint("LEFT", row.name, "RIGHT", TAG_GAP, 0)
    row.box.onClick = BoxClicked
    row.box:SetScript("OnEnter", BoxEnter)
    row.box:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function PlaceRow(content, y, label, on)
    local row = ns.UI.Keep(content, "bar", NewRow)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", 0, y)
    row:SetAlpha(on and 1 or OFF_BAR_ALPHA)
    row.name:SetText(label)
    return row
end

local function Counts(list, skip)
    local used, total, out = 0, 0, 0
    for _, slot in ipairs(list) do
        if GetActionInfo(slot) then
            total = total + 1
            if not skip[slot] then used = used + 1 end
        end
        if skip[slot] then out = out + 1 end
    end
    return used, total, out
end

local function DrawBar(content, y, entry, skip, used, out)
    local barOn = out < SLOTS_PER_BAR
    local row = PlaceRow(content, y, entry.label, barOn)
    row.tag:Hide()
    P.PaintBox(row.box, barOn)
    row.box.barOn, row.box.pet, row.box.list = barOn, nil, entry.list
    row.count:SetText(Plural(used, TEXT_ACTION, TEXT_ACTIONS))
    for i, slot in ipairs(entry.list) do
        local tile, kept = row.tiles[i], not skip[slot]
        wipe(look)
        look.texture = GetActionTexture(slot)
        look.key = GetActionInfo(slot) and P.KeyText(entry.commands[i]) or ""
        look.alpha, look.grey = kept and 1 or OUT_ALPHA, not kept
        look.edge = (not kept) and T.muted or nil
        look.tip, look.onClick = SlotTip, SlotClicked
        P.PaintTile(tile, look)
        tile.slot, tile.kept = slot, kept
        tile:Show()
    end
    return y - row:GetHeight() - ROW_GAP
end

local function PetCounts()
    local keys, actions = 0, 0
    for i = 1, PET_BAR.buttons do
        local key1, key2 = GetBindingKey(petCommands[i])
        keys = keys + (key1 and 1 or 0) + (key2 and 1 or 0)
        if PetAction(i) then actions = actions + 1 end
    end
    return keys, actions
end

local function DrawPet(content, y)
    local keys, actions = PetCounts()
    if keys == 0 and actions == 0 and not showEmpty then return y end
    local choices = draft.choices
    local on = choices.keys and not choices.petOff
    local row = PlaceRow(content, y, TEXT_PET_BAR, on)
    P.PaintChip(row.tag, TEXT_KEYS_ONLY, T.grey)
    P.PaintBox(row.box, on, not choices.keys)
    row.box.barOn, row.box.pet, row.box.list = on, true, nil
    row.count:SetText(Plural(keys, TEXT_KEYBIND, TEXT_KEYBINDS_N))
    for i, tile in ipairs(row.tiles) do
        tile:SetShown(i <= PET_BAR.buttons)
        if i <= PET_BAR.buttons then
            local _, texture = PetAction(i)
            wipe(look)
            look.texture, look.key = texture, P.KeyText(petCommands[i])
            look.alpha, look.grey = on and 1 or OUT_ALPHA, not on
            look.tip = PetTip
            P.PaintTile(tile, look)
            tile.slot = i
        end
    end
    return y - row:GetHeight() - ROW_GAP
end

local function DrawBars(v)
    local content, skip = v.content, draft.choices.skip
    ns.UI.BeginReusableRows(content)
    local y, actions = 0, 0
    for _, entry in ipairs(order) do
        if entry.pet then
            y = DrawPet(content, y)
        else
            local used, total, out = Counts(entry.list, skip)
            if total > 0 or showEmpty then
                actions = actions + used
                y = DrawBar(content, y, entry, skip, used, out)
            end
        end
    end
    content:SetHeight(math.max(1, -y))
    return actions
end

local function MacroEnter(row)
    P.Hint(row, row.tipTitle, row.tipLine)
end

local function MacroClicked(row)
    if row.locked or not draft.choices.macros then return end
    Step(STEP_KEEP)
    Flip(draft.choices.macroOff, row.key)
end

local function NewMacroRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(MACRO_ROW_H)
    ns.Solid(row, "BACKGROUND", T.bg, ROW_FILL):SetAllPoints()
    ns.Border(row, BLACK)
    row.box = P.Box(row)
    row.box:SetPoint("LEFT", MACRO_INSET, 0)
    row.box:EnableMouse(false)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(MACRO_ROW_H - MACRO_ICON_PAD, MACRO_ROW_H - MACRO_ICON_PAD)
    row.icon:SetPoint("LEFT", row.box, "RIGHT", MACRO_INSET, 0)
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.scope = P.Chip(row)
    row.scope:SetPoint("TOPRIGHT", -CHIP_INSET_X, -CHIP_INSET_Y)
    row.onBars = P.Chip(row)
    row.onBars:SetPoint("TOPRIGHT", row.scope, "BOTTOMRIGHT", 0, -STACK_GAP)
    row.name = P.Label(row, NAME_SIZE, T.fg)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", MACRO_INSET, 0)
    row.name:SetPoint("RIGHT", row.scope, "LEFT", -TEXT_GAP, 0)
    row.name:SetWordWrap(false)
    row.body = P.Label(row, St.TAG_SIZE, T.muted)
    row.body:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -STACK_GAP)
    row.body:SetPoint("RIGHT", row.scope, "LEFT", -TEXT_GAP, 0)
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
    row.tipTitle = macro.name
    row.tipLine = locked and TEXT_ON_BARS_TIP or TEXT_REUSE_TIP
    row.key, row.locked = key, locked
end

local function DrawMacros(v, slots)
    local choices, content = draft.choices, v.macroContent
    local bars, all = OnBars(slots, choices.skip), Sets.CaptureMacros()
    ns.UI.BeginReusableRows(content)
    local y, kept = 0, 0
    for _, macro in ipairs(all) do
        local key = Sets.MacroKey(macro.name, macro.body)
        local locked = bars[key]
        local on = locked or (choices.macros and not choices.macroOff[key])
        if on then kept = kept + 1 end
        local row = ns.UI.Keep(content, "macro", NewMacroRow)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        PaintMacro(row, macro, key, locked, on, choices)
        y = y - MACRO_ROW_H - MACRO_GAP
    end
    content:SetHeight(math.max(1, -y))
    return kept, #all
end

local function BindingCount()
    local n, petOff = 0, draft.choices.petOff
    for _, command in pairs(Sets.CaptureBindings()) do
        if not (petOff and Capture.PetKey(command)) then n = n + 1 end
    end
    return n
end

local function SaveDraft()
    Step(STEP_NAME)
    local name = strtrim(draft.box:GetText() or "")
    if name == "" then
        ns.Print(TEXT_NO_NAME)
        return
    end
    local function Done()
        if Sets.Save(name, draft.choices) then W.Show("sets") end
    end
    local existing = Sets.Find(name)
    if existing and existing ~= draft.key then
        ns.Confirm(TEXT_REPLACE:format(existing), Done)
    else
        Done()
    end
end

local function KeysOn() return draft.choices.keys end
local function SetKeys(on) draft.choices.keys = on; Step(STEP_KEEP); W.Redraw() end
local function MacrosOn() return draft.choices.macros end
local function SetMacros(on) draft.choices.macros = on; Step(STEP_KEEP); W.Redraw() end
local function EmptyShown() return showEmpty end
local function ShowEmpty(on) showEmpty = on and true or false; Step(STEP_BARS); W.Redraw() end

local function StepClicked(button)
    Step(button.step)
    if button.step == STEP_NAME then draft.box:SetFocus() end
end

local function BuildStrip(v)
    local strip = CreateFrame("Frame", nil, v.frame)
    strip:SetPoint("TOPLEFT", 0, -HEADER)
    strip:SetPoint("TOPRIGHT", 0, -HEADER)
    strip:SetHeight(STRIP_H)
    P.Divider(strip, -STRIP_H)
    v.steps = {}
    local x = CARD + INNER
    for i, text in ipairs(TEXT_STEPS) do
        local step = CreateFrame("Button", nil, strip)
        step.number = P.Chip(step)
        step.number:SetPoint("LEFT", STEP_PAD, 0)
        P.PaintChip(step.number, tostring(i), T.grey)
        step.label = P.Label(step, NOTE_SIZE, T.muted)
        step.label:SetPoint("LEFT", step.number, "RIGHT", STEP_NUM_GAP, 0)
        step.label:SetText(text)
        local w = STEP_PAD * 2 + step.number:GetWidth() + STEP_NUM_GAP + math.ceil(step.label:GetStringWidth())
        step:SetSize(w, STRIP_H)
        step:SetPoint("TOPLEFT", x, 0)
        step.line = ns.Solid(step, "ARTWORK", PICK, 1)
        step.line:SetPoint("BOTTOMLEFT")
        step.line:SetPoint("BOTTOMRIGHT")
        step.line:SetHeight(STEP_LINE)
        step.step = i
        step:SetScript("OnClick", StepClicked)
        v.steps[i] = step
        x = x + w + STEP_GAP
    end
end

local function BuildBars(v, top, bottom)
    local bars = P.Pane(W.frame, CARD, top, SIDE_W + CARD + GAP, bottom)
    bars:SetParent(v.frame)
    v.scroll, v.content = P.List(bars, 0, HINT_H)
    local hint = P.Label(bars, SMALL_SIZE, T.muted)
    hint:SetPoint("BOTTOMLEFT", 0, LINE_GAP)
    hint:SetText(TEXT_PICK_HINT)
    v.emptySwitch = P.Switch(bars, EmptyShown, ShowEmpty)
    v.emptySwitch:SetPoint("BOTTOMRIGHT", 0, LINE_GAP)
    local empty = P.Label(bars, SMALL_SIZE, T.muted)
    empty:SetPoint("RIGHT", v.emptySwitch, "LEFT", -EMPTY_GAP, 0)
    empty:SetText(TEXT_SHOW_EMPTY)
end

local function NewOption(pane, y, title, get, set)
    local card = CreateFrame("Frame", nil, pane)
    card:SetPoint("TOPLEFT", 0, y)
    card:SetPoint("TOPRIGHT", 0, y)
    card:SetHeight(OPTION_H)
    ns.Solid(card, "BACKGROUND", T.bg, ROW_FILL):SetAllPoints()
    ns.Border(card, BLACK)
    local label = P.Label(card, TITLE_SIZE, T.fg)
    label:SetPoint("TOPLEFT", OPTION_INSET, -OPTION_INSET)
    label:SetText(title)
    local line = P.Label(card, SMALL_SIZE, T.muted)
    line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -STACK_GAP)
    line:SetPoint("RIGHT", -(SWITCH_W + OPTION_INSET * 2), 0)
    local switch = P.Switch(card, get, set)
    switch:SetPoint("RIGHT", -OPTION_INSET, 0)
    return line, switch
end

local function BuildKeep(v, rightX, top, bottom)
    local keep = P.Pane(W.frame, rightX, top, CARD, bottom)
    keep:SetParent(v.frame)
    v.keysLine, v.keysSwitch = NewOption(keep, 0, TEXT_KEYBINDS, KeysOn, SetKeys)
    v.macrosLine, v.macrosSwitch = NewOption(keep, -(OPTION_H + OPTION_GAP), TEXT_MACROS, MacrosOn, SetMacros)
    v.macroScroll, v.macroContent = P.List(keep, 2 * (OPTION_H + OPTION_GAP))
end

local function UnFocus(box) box:ClearFocus() end
local function NameFocused() Step(STEP_NAME) end

local function BuildName(v, top, bottom)
    local pane = P.Pane(W.frame, CARD, top, CARD, bottom)
    pane:SetParent(v.frame)
    local label = P.Label(pane, SMALL_SIZE, T.muted)
    label:SetPoint("TOPLEFT")
    label:SetText(TEXT_SET_NAME)
    v.box = ns.NewEditBox(pane)
    v.box:SetSize(NAME_W, NAME_H)
    v.box:SetMaxLetters(NAME_MAX)
    v.box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -LINE_GAP)
    v.box:SetScript("OnEnterPressed", UnFocus)
    v.box:SetScript("OnEscapePressed", UnFocus)
    v.box:HookScript("OnEditFocusGained", NameFocused)
    v.button = ns.AccentBorder(ns.Button(pane, TEXT_SAVE_SET, SAVE_W, BUTTON_H, SaveDraft))
    v.button:SetPoint("BOTTOMRIGHT", 0, -SAVE_SINK)
    v.summary = P.Label(pane, NOTE_SIZE, T.fg)
    v.summary:SetPoint("LEFT", v.box, "RIGHT", SUMMARY_GAP, 0)
    v.summary:SetPoint("RIGHT", v.button, "LEFT", -SUMMARY_GAP, 0)
    v.summary:SetWordWrap(false)
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
    local actions = DrawBars(v)
    local kept, all = DrawMacros(v, slots)
    local choices = draft.choices
    local keys = choices.keys and BindingCount() or 0
    v.keysLine:SetText(choices.keys and TEXT_KEYS_ON:format(keys) or TEXT_KEYS_OFF)
    v.macrosLine:SetText(choices.macros and TEXT_MACROS_ON:format(kept, all) or TEXT_MACROS_OFF)
    v.keysSwitch._refreshValue()
    v.macrosSwitch._refreshValue()
    v.emptySwitch._refreshValue()
    v.summary:SetText(Summary(actions, keys, kept))
    PaintSteps(v)
end

local function NewPage(bar)
    local entry = { bar = bar, label = bar.name, list = P.BarSlots(bar), commands = {} }
    for i = 1, SLOTS_PER_BAR do entry.commands[i] = bar.button .. i end
    return entry
end

local function Pages()
    pages, order, petCommands = {}, {}, {}
    for _, bar in ipairs(Sets.BARS) do pages[bar.page] = NewPage(bar) end
    for i = 1, PET_BAR.buttons do petCommands[i] = PET_BAR.button .. i end
end

local function Add(entry, label)
    if added[entry] then return end
    added[entry] = true
    entry.label = label or entry.bar.name
    order[#order + 1] = entry
end

local function Order()
    wipe(order)
    wipe(added)
    local class = A.Class()
    local main = pages[1]
    Add(main, main.bar.name .. DOT .. TEXT_MAIN)
    for _, form in ipairs(FORMS[class] or NONE) do
        local entry = pages[form.page]
        if entry then Add(entry, main.bar.name .. DOT .. ns.L(form.name)) end
    end
    for _, bar in ipairs(Sets.BARS) do Add(pages[bar.page]) end
    if PET_CLASSES[class] then order[#order + 1] = petRow end
    wipe(added)
end

function Builder.NewDraft(key)
    local set = key and Sets.Get(key)
    local choices = set and set.choices or {}
    draft = {
        key = set and key or nil, name = set and key or "", step = STEP_BARS,
        choices = { skip = Copy(choices.skip), macroOff = Copy(choices.macroOff),
            keys = choices.keys ~= false, macros = choices.macros ~= false, petOff = choices.petOff or nil },
    }
end

function Builder.HasDraft()
    return draft ~= nil
end

function Builder.Build(window)
    W = window
    Pages()
    local v = { cards = {} }
    local top = HEADER + STRIP_H + CARD
    local nameTop = HEIGHT - FOOTER - CARD - NAME_BAR
    local middle = FOOTER + CARD + NAME_BAR + GAP
    local rightX = WIDTH - CARD - SIDE_W
    P.Cards(W.frame, v.cards, CARD, top, SIDE_W + CARD + GAP, middle)
    P.Cards(W.frame, v.cards, rightX, top, CARD, middle)
    P.Cards(W.frame, v.cards, CARD, nameTop, CARD, FOOTER + CARD)
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    BuildStrip(v)
    BuildBars(v, top, middle)
    BuildKeep(v, rightX, top, middle)
    BuildName(v, nameTop, FOOTER + CARD)
    v.title = TEXT_TITLE
    function v.Open()
        Order()
        v.box:SetText(draft.name)
        draft.box = v.box
        v.title = draft.key and (TEXT_EDIT .. draft.key) or TEXT_TITLE
        v.subtitle = TEXT_SUBTITLE:format(UnitClass("player"))
    end
    function v.Draw() Draw(v) end
    v.events = { "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "UPDATE_MACROS", "PET_BAR_UPDATE" }
    V = v
    return v
end
