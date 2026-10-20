-- SetsPage.lua: the Bar Sets tab's home: Save Current Bars, Import Website Code and Export to Website as cards, an Undo after an import, the bar check, then your class's saved sets as cards with a small strip of their bars, and the backups taken before each import (ns.BuildActionBarsPage).
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local A = ns.ActionBars
local St = A.Style
local P = A.Parts
local Check = A.Check

local SLOTS_PER_BAR, GLASS_PAD = A.C.SLOTS_PER_BAR, St.GLASS_PAD
local CARD_H, CARD_GAP, CARD_BUTTON_W, BUTTON_H = 96, 10, 120, 26
local ACTIONS = 3
local SET_H, SET_COLUMNS, ROW_BUTTON_W, BUTTON_GAP = 154, 2, 84, 8
local ICON, ICON_GAP, STRIP_TOP, LINE_GAP, TAG_GAP = 36, 10, 58, 3, 4
local HEAD_GAP, HEAD_H, SECTION_GAP = 22, 22, 18
local BANNER_H, CHECK_H, CHECK_ICON, CHECK_ICONS, CHECK_BUTTON_W = 44, 96, 28, 10, 110
local NAMES_SHOWN = 3
local BACKUP_H, BACKUP_GAP, BACKUP_BUTTON_W, BACKUP_BUTTON_H = 34, 4, 96, 22
local FILTER_H, FILTER_PAD, FILTER_GAP = 20, 10, 6
local BANNER_ALPHA = 0.16
local DOT = St.PLACE_DOT
local NO_FORMS = {}
local NEW_NAME_MAX = 40
local SAVED_DATE = "%d %b %Y"
local BACKUP_DATE = "%d %b %H:%M"
local TEXT_ACTION, TEXT_ACTIONS = ns.L("%d action"), ns.L("%d actions")
local TEXT_MACRO, TEXT_MACROS = ns.L("%d macro"), ns.L("%d macros")
local TEXT_KEYBIND, TEXT_KEYBINDS = ns.L("%d keybind"), ns.L("%d keybinds")

local TEXT_SAVE = ns.L("Save Current Bars")
local TEXT_SAVE_LINE = ns.L("Bars, macros and keybinds, for every %s.")
local TEXT_SAVE_BUTTON = ns.L("Save")
local TEXT_WEBSITE = ns.L("Import Website Code")
local TEXT_WEBSITE_LINE = ns.L("Bring a layout from naowh.gg into a new set.")
local TEXT_WEBSITE_BUTTON = ns.L("Paste code")
local TEXT_EXPORT = ns.L("Export to Website")
local TEXT_EXPORT_LINE = ns.L("Your bars now, as a code for naowh.gg.")
local TEXT_EXPORT_BUTTON = ns.L("Get code")
local TEXT_PLUS_FORM = ns.L("+ %s")
local TEXT_PLUS_FORMS = ns.L("+ %d forms")
local TEXT_PLUS_BARS = ns.L("+ %d more bars")
local TEXT_PLUS_BAR = ns.L("+ 1 more bar")
local TEXT_PLUS_PET = ns.L("+ pet keys")
local TEXT_HEADER = ns.L("Saved Sets")
local TEXT_EMPTY = ns.L("Nothing saved yet. Save your bars, macros and keybinds as they are now, then "
    .. "import them on a fresh character, for another spec or a dungeon set-up.")
local TEXT_NO_MATCH = ns.L("No saved set has this tag.")
local TEXT_SAVED = ns.L("Saved ")
local TEXT_BY = ns.L(" by ")
local TEXT_IMPORT, TEXT_MORE = ns.L("Import"), ns.L("More")
local TEXT_EDIT, TEXT_RENAME, TEXT_DELETE = ns.L("Edit and Save Again"), ns.L("Rename"), ns.L("Delete")
local TEXT_NEW_NAME = ns.L("New name for ")
local TEXT_ON_BARS = ns.L("ON YOUR BARS")
local TEXT_ALL = ns.L("All")
local TEXT_IMPORTED = ns.L("%s is on your bars. Your bars from before it are kept as a backup.")
local TEXT_UNDO = ns.L("Undo Import")
local TEXT_RANKS_HEAD = ns.L("BAR CHECK")
local TEXT_RANKS, TEXT_RANKS_ONE = ns.L("%d spells below your best rank"), ns.L("1 spell below your best rank")
local TEXT_UPGRADE, TEXT_KEEP = ns.L("Upgrade All"), ns.L("Leave as Is")
local TEXT_KEEP_TIP = ns.L("Keeps these ranks, for downranking, and stops asking about them.")
local TEXT_RANK_NAME = "%s %s"
local TEXT_MORE_NAMES = ns.L(", and %d more")
local TEXT_SPELLS_HEAD = ns.L("NEW SPELLS")
local TEXT_SPELLS, TEXT_SPELLS_ONE = ns.L("%d spells you know are on no bar"), ns.L("1 spell you know is on no bar")
local TEXT_SPELLS_LINE = ns.L("Drag one onto your bars.")
local TEXT_HIDE = ns.L("Hide These")
local TEXT_HIDE_TIP = ns.L("Stops listing these spells. A spell you learn later is listed again.")
local TEXT_BACKUPS = ns.L("Backups")
local TEXT_RESTORE, TEXT_SAVE_AS = ns.L("Put Back"), ns.L("Save as Set")
local TEXT_RESTORE_ASK = ns.L("Put back your bars, keybinds and macros from %s?")
local TEXT_BACKUP_NAME = ns.L("Name for the set made from this backup")
local CONTENTS_JOIN = ", "

local function OpenBuilder() ns.OpenActionBarsBuilder() end
local function ExportNow() A.Sharing.ShowExport() end

local ACTION_CARDS = {
    { title = TEXT_SAVE, line = TEXT_SAVE_LINE, button = TEXT_SAVE_BUTTON, primary = true, onClick = OpenBuilder },
    { title = TEXT_WEBSITE, line = TEXT_WEBSITE_LINE, button = TEXT_WEBSITE_BUTTON,
        onClick = function() A.Sharing.Prompt() end },
    { title = TEXT_EXPORT, line = TEXT_EXPORT_LINE, button = TEXT_EXPORT_BUTTON, onClick = ExportNow },
}
local extras, formPages = {}, {}
local tagFilter

local function OnBars(key)
    local last = A.Last()
    return last ~= nil and last.class == A.Class() and last.name == key
end

local function HasPage(set, page)
    local first = (page - 1) * SLOTS_PER_BAR
    for i = 1, SLOTS_PER_BAR do
        if set.slots[first + i] then return true end
    end
    return false
end

local function HasPetKeys(set)
    for _, command in pairs(set.bindings or NO_FORMS) do
        if A.Capture.PetKey(command) then return true end
    end
    return false
end

function A.SetExtras(set)
    wipe(extras)
    local forms, count, named = A.FORMS[A.Class()] or NO_FORMS, 0, nil
    wipe(formPages)
    for _, form in ipairs(forms) do
        formPages[#formPages + 1] = form.page
        if HasPage(set, form.page) then count, named = count + 1, form.name end
    end
    if count == 1 then extras[#extras + 1] = TEXT_PLUS_FORM:format(ns.L(named)) end
    if count > 1 then extras[#extras + 1] = TEXT_PLUS_FORMS:format(count) end
    local others = 0
    for _, bar in ipairs(A.BARS) do
        if P.IsOther(bar.page, formPages) and HasPage(set, bar.page) then others = others + 1 end
    end
    if others == 1 then extras[#extras + 1] = TEXT_PLUS_BAR end
    if others > 1 then extras[#extras + 1] = TEXT_PLUS_BARS:format(others) end
    if A.PET_CLASSES[A.Class()] and HasPetKeys(set) then extras[#extras + 1] = TEXT_PLUS_PET end
    return table.concat(extras, DOT)
end

function A.SetMenu(key)
    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateButton(TEXT_EDIT, function() ns.OpenActionBarsBuilder(key) end)
        root:CreateButton(TEXT_EXPORT, function() A.Sharing.ShowExport(key) end)
        root:CreateButton(TEXT_RENAME, function()
            ns.PromptText(TEXT_NEW_NAME .. key, key, NEW_NAME_MAX, function(new) A.Rename(key, new) end)
        end)
        root:CreateButton(TEXT_DELETE, function() A.ConfirmDelete(key) end)
    end)
end

function A.SetContents(set)
    local actions, keys = 0, 0
    for _ in pairs(set.slots) do actions = actions + 1 end
    local parts = { A.Plural(actions, TEXT_ACTION, TEXT_ACTIONS) }
    if set.macros then parts[#parts + 1] = A.Plural(#set.macros, TEXT_MACRO, TEXT_MACROS) end
    if set.bindings then
        for _ in pairs(set.bindings) do keys = keys + 1 end
        parts[#parts + 1] = A.Plural(keys, TEXT_KEYBIND, TEXT_KEYBINDS)
    end
    return table.concat(parts, CONTENTS_JOIN)
end

function A.SetIcon(set)
    if set.icon then return set.icon end
    for _, page in ipairs(P.STRIP_PAGES) do
        local first = (page - 1) * SLOTS_PER_BAR
        for i = 1, SLOTS_PER_BAR do
            local texture = P.EntryTexture(set.slots[first + i])
            if texture then return texture end
        end
    end
    return A.C.QUESTION
end

local function NewAction(parent)
    local card = P.GlassPanel(parent)
    card:SetHeight(CARD_H)
    card.button = ns.Button(card, "", CARD_BUTTON_W, BUTTON_H)
    card.button:SetPoint("BOTTOMLEFT", GLASS_PAD, GLASS_PAD)
    return card
end

local function PaintAction(card, action)
    card.title:SetText(action.title)
    card.line:SetText(action.line:format(UnitClass("player")))
    ns.SetButtonText(card.button, action.button)
    card.button._onClick = action.onClick
    if action.primary then P.Primary(card.button) end
end

local function NewBanner(parent)
    local banner = CreateFrame("Frame", nil, parent)
    banner:SetHeight(BANNER_H)
    ns.Solid(banner, "BACKGROUND", St.GREEN_RGB, BANNER_ALPHA):SetAllPoints()
    ns.Border(banner, St.GREEN_RGB)
    banner.text = P.Label(banner, St.NOTE_SIZE, T.fg)
    banner.text:SetPoint("LEFT", GLASS_PAD, 0)
    banner.undo = ns.Button(banner, TEXT_UNDO, CARD_BUTTON_W, BUTTON_H, function() A.Undo() end)
    banner.undo:SetPoint("RIGHT", -GLASS_PAD, 0)
    return banner
end

local function Tip(owner)
    P.Hint(owner, owner.tipTitle, owner.tipLine)
end

local function SpellEnter(icon)
    if not ns.Shared.Parts.Tip(icon, "ANCHOR_TOP") then return end
    GameTooltip:SetSpellByID(icon.spell)
    GameTooltip:Show()
end

local function PickUpSpell(icon)
    if InCombatLockdown() then return end
    C_Spell.PickupSpell(icon.spell)
end

local function NewSpellIcon(card)
    local icon = CreateFrame("Button", nil, card)
    icon:SetSize(CHECK_ICON, CHECK_ICON)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(St.ICON_CROP, 1 - St.ICON_CROP, St.ICON_CROP, 1 - St.ICON_CROP)
    ns.Border(icon, St.BORDER_RGB)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", PickUpSpell)
    icon:SetScript("OnClick", PickUpSpell)
    icon:SetScript("OnEnter", SpellEnter)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    return icon
end

local function NewCheck(parent)
    local card = P.Glass(CreateFrame("Frame", nil, parent))
    card:SetHeight(CHECK_H)
    card.head = P.Mono(card, St.MONO_SIZE, St.GOLD_RGB)
    card.head:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    card.title = P.Label(card, St.NAME_SIZE, T.fg)
    card.title:SetPoint("TOPLEFT", card.head, "BOTTOMLEFT", 0, -LINE_GAP * 2)
    card.line = P.Label(card, St.SMALL_SIZE, T.muted)
    card.line:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -LINE_GAP)
    card.line:SetPoint("RIGHT", -(GLASS_PAD * 2 + CHECK_BUTTON_W), 0)
    card.line:SetWordWrap(false)
    card.first = ns.Button(card, "", CHECK_BUTTON_W, BUTTON_H)
    card.first:SetPoint("TOPRIGHT", -GLASS_PAD, -GLASS_PAD)
    card.first:SetScript("OnEnter", Tip)
    card.first:SetScript("OnLeave", GameTooltip_Hide)
    card.second = ns.Button(card, "", CHECK_BUTTON_W, BUTTON_H)
    card.second:SetPoint("TOPRIGHT", card.first, "BOTTOMRIGHT", 0, -BUTTON_GAP)
    card.second:SetScript("OnEnter", Tip)
    card.second:SetScript("OnLeave", GameTooltip_Hide)
    card.icons = {}
    for i = 1, CHECK_ICONS do
        local icon = NewSpellIcon(card)
        icon:SetPoint("BOTTOMLEFT", GLASS_PAD + (i - 1) * (CHECK_ICON + TAG_GAP), GLASS_PAD)
        card.icons[i] = icon
    end
    return card
end

local function RankNames(list)
    local names = {}
    for i = 1, math.min(#list, NAMES_SHOWN) do
        local id = list[i].id
        names[i] = TEXT_RANK_NAME:format(C_Spell.GetSpellName(id) or "", C_Spell.GetSpellSubtext(id) or "")
    end
    local text = table.concat(names, CONTENTS_JOIN)
    if #list > NAMES_SHOWN then text = text .. TEXT_MORE_NAMES:format(#list - NAMES_SHOWN) end
    return text
end

local function PaintCheck(card, look)
    card.head:SetText(look.head)
    card.title:SetText(look.title)
    card.line:SetText(look.line)
    ns.SetButtonText(card.first, look.first)
    card.first._onClick = look.onFirst
    card.first.tipTitle, card.first.tipLine = look.first, look.firstTip
    card.second:SetShown(look.second ~= nil)
    ns.SetButtonText(card.second, look.second or "")
    card.second._onClick = look.onSecond
    card.second.tipTitle, card.second.tipLine = look.second, look.tip
    for i, icon in ipairs(card.icons) do
        local row = look.spells and look.spells[i]
        icon:SetShown(row ~= nil)
        if row then
            icon.spell = row.id
            icon.texture:SetTexture(C_Spell.GetSpellTexture(row.id))
        end
    end
end

local function CheckLooks()
    local looks = {}
    local upgrades = Check.Upgrades()
    if #upgrades > 0 then
        looks[#looks + 1] = { head = TEXT_RANKS_HEAD, line = RankNames(upgrades),
            title = #upgrades == 1 and TEXT_RANKS_ONE or TEXT_RANKS:format(#upgrades),
            first = TEXT_UPGRADE, onFirst = function() Check.Upgrade(upgrades) end,
            second = TEXT_KEEP, onSecond = function() Check.Keep(upgrades) end, tip = TEXT_KEEP_TIP }
    end
    local missing = Check.Missing()
    if missing and #missing > 0 then
        looks[#looks + 1] = { head = TEXT_SPELLS_HEAD, line = TEXT_SPELLS_LINE, spells = missing,
            title = #missing == 1 and TEXT_SPELLS_ONE or TEXT_SPELLS:format(#missing),
            first = TEXT_HIDE, onFirst = function() Check.Hide(missing) end, firstTip = TEXT_HIDE_TIP }
    end
    return looks
end

local function NewFilter(parent)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(FILTER_H)
    ns.Solid(chip, "BACKGROUND", St.BORDER_RGB, St.CHIP_FILL_ALPHA):SetAllPoints()
    chip.edge = ns.Border(chip, St.GOLD_RGB, St.CHIP_EDGE_ALPHA)
    chip.text = P.Mono(chip, St.MONO_SIZE, St.GOLD_RGB)
    chip.text:SetPoint("CENTER")
    chip:SetScript("OnClick", P.Clicked)
    return chip
end

local function PaintFilter(chip, text, tag)
    local picked = tagFilter == tag
    chip.text:SetText(ns.Upper(text))
    local c = picked and St.GOLD_SOFT_RGB or St.GOLD_RGB
    chip.text:SetTextColor(c.r, c.g, c.b)
    chip.edge:SetColor(c.r, c.g, c.b, picked and 1 or St.CHIP_EDGE_ALPHA)
    chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + FILTER_PAD * 2)
    chip.onClick = function()
        tagFilter = tag
        A.Refresh()
    end
end

local function NewSetCard(parent)
    local row = P.Glass(CreateFrame("Frame", nil, parent))
    row:SetHeight(SET_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    row.icon:SetTexCoord(St.ICON_CROP, 1 - St.ICON_CROP, St.ICON_CROP, 1 - St.ICON_CROP)
    row.on = P.Chip(row)
    row.on:SetPoint("TOPRIGHT", -GLASS_PAD, -GLASS_PAD)
    row.name = P.Label(row, St.NAME_SIZE, T.fg)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", ICON_GAP, -LINE_GAP)
    row.name:SetPoint("RIGHT", row.on, "LEFT", -ICON_GAP, 0)
    row.name:SetWordWrap(false)
    row.saved = P.Label(row, St.SMALL_SIZE, T.muted)
    row.saved:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -LINE_GAP)
    row.tags = {}
    row.strip = P.NewMiniStrip(row)
    row.strip:SetPoint("TOPLEFT", GLASS_PAD, -STRIP_TOP)
    row.extras = P.Label(row, St.SMALL_SIZE, T.muted)
    row.extras:SetPoint("TOPLEFT", row.strip, "BOTTOMLEFT", 0, -LINE_GAP)
    row.more = ns.Button(row, TEXT_MORE, ROW_BUTTON_W, BUTTON_H, function() A.SetMenu(row.key) end)
    row.more:SetPoint("BOTTOMRIGHT", -GLASS_PAD, GLASS_PAD)
    row.import = P.Primary(ns.Button(row, TEXT_IMPORT, ROW_BUTTON_W, BUTTON_H,
        function() ns.OpenActionBarsImport(row.key) end))
    row.import:SetPoint("RIGHT", row.more, "LEFT", -BUTTON_GAP, 0)
    row.has = P.Label(row, St.SMALL_SIZE, T.fg)
    row.has:SetPoint("BOTTOMLEFT", GLASS_PAD, GLASS_PAD + (BUTTON_H - St.SMALL_SIZE) / 2)
    return row
end

local function PaintTags(row, set)
    for i, tag in ipairs(set.tags or NO_FORMS) do
        local chip = row.tags[i] or P.Chip(row)
        row.tags[i] = chip
        P.PaintChip(chip, ns.Upper(tag), St.ACCOUNT_RGB)
        chip:ClearAllPoints()
        chip:SetPoint("TOPRIGHT", -GLASS_PAD, -(STRIP_TOP + (i - 1) * (St.CHIP_H + TAG_GAP)))
    end
    for i = #(set.tags or NO_FORMS) + 1, #row.tags do row.tags[i]:Hide() end
end

local function PaintSetRow(row, key, set)
    row.key = key
    row.icon:SetTexture(A.SetIcon(set))
    row.name:SetText(key)
    row.saved:SetText(TEXT_SAVED .. date(ns.L(SAVED_DATE), set.saved) .. (set.by and (TEXT_BY .. set.by) or ""))
    row.has:SetText(A.SetContents(set))
    if OnBars(key) then P.PaintChip(row.on, TEXT_ON_BARS, T.accent) else row.on:Hide() end
    PaintTags(row, set)
    P.PaintMiniStrip(row.strip, set.slots)
    row.extras:SetText(A.SetExtras(set))
end

local function Heading(parent, y, key, text)
    local head = UI.Keep(parent, key, function(p) return P.Mono(p, St.MONO_SIZE, St.GOLD_RGB) end)
    head:SetPoint("TOPLEFT", 0, y)
    head:SetText(ns.Upper(text))
    return head
end

local function HasTag(set, tag)
    for _, t in ipairs(set.tags or NO_FORMS) do if t == tag then return true end end
    return false
end

local function Tags(sets)
    local seen, list = {}, {}
    for _, set in pairs(sets) do
        for _, tag in ipairs(set.tags or NO_FORMS) do
            if not seen[tag] then
                seen[tag] = true
                list[#list + 1] = tag
            end
        end
    end
    table.sort(list)
    return list
end

local function Filters(parent, head, sets)
    local tags = Tags(sets)
    if tagFilter and not HasTag({ tags = tags }, tagFilter) then tagFilter = nil end
    if #tags == 0 then return end
    local after = head
    for i = 0, #tags do
        local chip = UI.Keep(parent, "barsFilter", NewFilter)
        PaintFilter(chip, i == 0 and TEXT_ALL or tags[i], i > 0 and tags[i] or nil)
        chip:SetPoint("LEFT", after, "RIGHT", i == 0 and SECTION_GAP or FILTER_GAP, 0)
        after = chip
    end
end

local function DrawActions(parent, y, width)
    local cardW = (width - CARD_GAP * (ACTIONS - 1)) / ACTIONS
    for i, action in ipairs(ACTION_CARDS) do
        local card = UI.Keep(parent, "barsAction", NewAction)
        card:SetPoint("TOPLEFT", (i - 1) * (cardW + CARD_GAP), y)
        card:SetWidth(cardW)
        PaintAction(card, action)
    end
    return y - CARD_H - CARD_GAP
end

local function DrawBanner(parent, y)
    if not (A.lastImport and A.Sets()[A.lastImport.key]) then return y end
    local banner = UI.Keep(parent, "barsBanner", NewBanner)
    banner:SetPoint("TOPLEFT", 0, y)
    banner:SetPoint("TOPRIGHT", 0, y)
    banner.text:SetText(TEXT_IMPORTED:format(A.lastImport.key))
    return y - BANNER_H - CARD_GAP
end

local function DrawChecks(parent, y, width)
    local looks = CheckLooks()
    if #looks == 0 then return y end
    local cardW = (width - CARD_GAP) / 2
    for i, look in ipairs(looks) do
        local card = UI.Keep(parent, "barsCheck", NewCheck)
        card:SetPoint("TOPLEFT", (i - 1) * (cardW + CARD_GAP), y)
        card:SetWidth(cardW)
        PaintCheck(card, look)
    end
    return y - CHECK_H - CARD_GAP
end

local function DrawSets(parent, y, width)
    local head = Heading(parent, y - HEAD_GAP + CARD_GAP, "barsHeading", TEXT_HEADER)
    local sets = A.Sets()
    Filters(parent, head, sets)
    y = y - HEAD_GAP + CARD_GAP - HEAD_H
    local names = A.SortedNames()
    if #names == 0 then
        local _, h = UI.Widgets:Note(parent, TEXT_EMPTY, y)
        return y - h
    end
    local cardW = (width - CARD_GAP * (SET_COLUMNS - 1)) / SET_COLUMNS
    local shown = 0
    for _, key in ipairs(names) do
        if not tagFilter or HasTag(sets[key], tagFilter) then
            local row = UI.Keep(parent, "barsRow", NewSetCard)
            local column = shown % SET_COLUMNS
            row:SetPoint("TOPLEFT", column * (cardW + CARD_GAP), y - math.floor(shown / SET_COLUMNS) * (SET_H + CARD_GAP))
            row:SetWidth(cardW)
            PaintSetRow(row, key, sets[key])
            shown = shown + 1
        end
    end
    if shown == 0 then
        local _, h = UI.Widgets:Note(parent, TEXT_NO_MATCH, y)
        return y - h
    end
    return y - math.ceil(shown / SET_COLUMNS) * (SET_H + CARD_GAP)
end

local function NewBackupRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(BACKUP_H)
    ns.Solid(row, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(row, St.BORDER_RGB)
    row.when = P.Mono(row, St.MONO_SIZE, St.INK_RGB)
    row.when:SetPoint("LEFT", GLASS_PAD, 0)
    row.why = P.Label(row, St.NOTE_SIZE, T.fg)
    row.why:SetPoint("LEFT", row.when, "RIGHT", GLASS_PAD, 0)
    row.save = ns.Button(row, TEXT_SAVE_AS, BACKUP_BUTTON_W, BACKUP_BUTTON_H)
    row.save:SetPoint("RIGHT", -GLASS_PAD / 2, 0)
    row.restore = ns.Button(row, TEXT_RESTORE, BACKUP_BUTTON_W, BACKUP_BUTTON_H)
    row.restore:SetPoint("RIGHT", row.save, "LEFT", -BUTTON_GAP, 0)
    return row
end

local function DrawBackups(parent, y)
    local list = A.Backups.List()
    if #list == 0 then return y end
    y = y - SECTION_GAP
    Heading(parent, y, "barsBackupsHeading", TEXT_BACKUPS)
    y = y - HEAD_H
    for i, backup in ipairs(list) do
        local row = UI.Keep(parent, "barsBackup", NewBackupRow)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        local when = date(ns.L(BACKUP_DATE), backup.saved)
        row.when:SetText(when)
        row.why:SetText(backup.why or "")
        row.restore._onClick = function()
            ns.Confirm(TEXT_RESTORE_ASK:format(when), function() A.RestoreBackup(i) end)
        end
        row.save._onClick = function()
            ns.PromptText(TEXT_BACKUP_NAME, backup.why or "", NEW_NAME_MAX, function(name) A.SaveBackup(i, name) end)
        end
        y = y - BACKUP_H - BACKUP_GAP
    end
    return y
end

function ns.ActionBarsSearchTerms(add)
    for _, action in ipairs(ACTION_CARDS) do add(action.title, action.line:format(UnitClass("player"))) end
    add(TEXT_UNDO)
    add(TEXT_BACKUPS)
    add(TEXT_UPGRADE, TEXT_RANKS_HEAD)
end

function ns.BuildActionBarsPage(parent, y)
    local width = parent:GetWidth()
    y = DrawActions(parent, y, width)
    y = DrawBanner(parent, y)
    y = DrawChecks(parent, y, width)
    y = DrawSets(parent, y, width)
    return DrawBackups(parent, y)
end
