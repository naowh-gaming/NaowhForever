-------------------------------------------------------------------------------
--  NaowhForever_ActionBars.lua -- the Action Bars module: every action bar slot, macro and
--  keybind saved under a name and imported later, out of combat. Sets belong to a class and
--  are shared by every character of that class on the account.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local UI = ns.UI
local S = UI.ModuleSettings("actionBars", {
    enabled = true, highestRank = false, importMacros = true, importBindings = true, saveOnLogout = false,
    windowAlpha = 1,
})
ns.ActionBarSettings = S

local KEYBOARD_SLOTS = 180
local PLAYER_BANK = Enum.SpellBookSpellBank.Player
local MACRO_ICON = 134400

local function Account(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    return account[key]
end

local function Class()
    local _, class = UnitClass("player")
    return class
end

local function Sets()
    local all = Account("barSets")
    all[Class()] = all[Class()] or {}
    return all[Class()]
end

local function CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- The set this character saved or imported last, which Save on Logout writes back to. The
-- class is kept with it, since set names only mean something within a class.
local function SetLast(name)
    Account("barSetLast")[CharKey()] = { class = Class(), name = name }
end

-- Set names match without case, so slash commands find them however they are typed.
local function Find(name)
    local sets = Sets()
    if sets[name] then return name end
    local lower = name:lower()
    for key in pairs(sets) do
        if key:lower() == lower then return key end
    end
end

local function SortedNames()
    local names = {}
    for name in pairs(Sets()) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

local function Slots()
    local list = {}
    for slot = 1, KEYBOARD_SLOTS do list[#list + 1] = slot end
    local slot = math.max(C_GamepadUI.GetFirstGamepadActionStorageSlotIndex(), KEYBOARD_SLOTS + 1)
    while C_GamepadUI.IsValidGamepadActionStorageSlotIndex(slot) do
        list[#list + 1] = slot
        slot = slot + 1
    end
    return list
end

-- name -> spellID of the highest rank of each active spell in the spellbook.
local function HighestRanks()
    local best, rank = {}, {}
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.isGuild then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(i, PLAYER_BANK)
                if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isPassive then
                    local r = tonumber(item.subName and item.subName:match("%d+")) or 0
                    if not rank[item.name] or r > rank[item.name] then
                        best[item.name], rank[item.name] = item.actionID, r
                    end
                end
            end
        end
    end
    return best
end

local function MacroIndices()
    local account, character = GetNumMacros()
    local list = {}
    for i = 1, account do list[#list + 1] = i end
    local first = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    for i = first + 1, first + character do list[#list + 1] = i end
    return list
end

local function Body(body)
    return strtrim(((body or ""):gsub("\r", "")))
end

local function MacroKey(name, body)
    return name .. "\n" .. Body(body)
end

-- Macros already on this character, by name and text and by text alone, so a set's macro is
-- found again even under another name and never made twice.
local function MacroIndex()
    local index = { text = {}, body = {} }
    for _, i in ipairs(MacroIndices()) do
        local name, _, body = GetMacroInfo(i)
        if name then
            local key, text = MacroKey(name, body), Body(body)
            index.text[key] = index.text[key] or i
            if text ~= "" then index.body[text] = index.body[text] or i end
        end
    end
    return index
end

local function Lookup(index, macro)
    local text = Body(macro.body)
    return index.text[MacroKey(macro.name, macro.body)] or (text ~= "" and index.body[text]) or nil
end

-------------------------------------------------------------------------------
--  Saving
-------------------------------------------------------------------------------
-- A macro slot's id is the spell or item it shows, not the macro, so the macro is found by
-- the name the slot carries.
local function Capture()
    local slots = {}
    for _, slot in ipairs(Slots()) do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" then
            slots[slot] = { kind = "spell", id = id, name = C_Spell.GetSpellName(id) }
        elseif kind == "macro" then
            local name = C_ActionBar.GetActionText(slot)
            local index = name and GetMacroIndexByName(name) or 0
            if index > 0 then
                local _, icon, body = GetMacroInfo(index)
                slots[slot] = { kind = "macro", name = name, icon = icon, body = body,
                    perCharacter = index > Constants.MacroConsts.MAX_ACCOUNT_MACROS }
            end
        elseif kind then
            slots[slot] = { kind = kind, id = id }
        end
    end
    return slots
end

local function CaptureMacros()
    local macros = {}
    local first = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    for _, i in ipairs(MacroIndices()) do
        local name, icon, body = GetMacroInfo(i)
        if name then
            macros[#macros + 1] = { name = name, icon = icon, body = body, perCharacter = i > first }
        end
    end
    return macros
end

local function CaptureBindings()
    local bindings = {}
    for i = 1, GetNumBindings() do
        local command, _, key1, key2 = GetBinding(i)
        if key1 then bindings[key1] = command end
        if key2 then bindings[key2] = command end
    end
    return bindings
end

local function Snapshot()
    return { saved = time(), by = UnitName("player"), slots = Capture(), macros = CaptureMacros(),
        bindings = CaptureBindings() }
end

local function Ready(what)
    if not S.Get("enabled") then ns.Print("Action Bars is switched off.") return false end
    if InCombatLockdown() then ns.Print(("Bar sets can be %s out of combat."):format(what)) return false end
    return true
end

local function Save(name)
    if not Ready("saved") then return end
    local key = Find(name) or name
    Sets()[key] = Snapshot()
    SetLast(key)
    ns.Print(("Saved your bars, macros and keybinds as %s."):format(key))
    if UI.RefreshPage then UI:RefreshPage(true) end
end

-------------------------------------------------------------------------------
--  Importing
-------------------------------------------------------------------------------
local function Describe(entry)
    if entry.kind == "spell" then return entry.name or ("spell " .. entry.id) end
    if entry.kind == "macro" then return "macro " .. entry.name end
    if entry.kind == "item" then return C_Item.GetItemNameByID(entry.id) or ("item " .. entry.id) end
    return ("%s %s"):format(entry.kind, tostring(entry.id))
end

local RESTORABLE = { spell = true, macro = true, item = true, equipmentset = true }

-- plan holds the macros a test import would make, since a test does not make them.
local function MacroRoom(perCharacter, plan)
    local account, character = GetNumMacros()
    account, character = account + plan.account, character + plan.character
    local max = Constants.MacroConsts
    if perCharacter then return character < max.MAX_CHARACTER_MACROS end
    return account < max.MAX_ACCOUNT_MACROS
end

-- Sets saved before macros were kept whole carry only the macros on the bars, in their slots.
local function SetMacros(set)
    if set.macros then return set.macros end
    local list, seen = {}, {}
    for _, entry in pairs(set.slots) do
        if entry.kind == "macro" and not seen[MacroKey(entry.name, entry.body)] then
            seen[MacroKey(entry.name, entry.body)] = true
            list[#list + 1] = entry
        end
    end
    return list
end

-- A macro this character lacks is made in the scope it was saved in. One it already has is
-- used as it is. In a test, the macros it would make go in the index as true.
local function ImportMacros(set, test)
    local index, plan, made, full = MacroIndex(), { account = 0, character = 0 }, 0, {}
    for _, macro in ipairs(SetMacros(set)) do
        if not Lookup(index, macro) then
            if MacroRoom(macro.perCharacter, plan) then
                if test then
                    local kind = macro.perCharacter and "character" or "account"
                    plan[kind] = plan[kind] + 1
                else
                    -- GetMacroInfo gives a #showtooltip macro the icon it was showing; made
                    -- with that icon, it would stop following its spell.
                    local icon = Body(macro.body):find("^#showtooltip") and MACRO_ICON or macro.icon
                    CreateMacro(macro.name, icon or MACRO_ICON, macro.body or "", macro.perCharacter)
                end
                index.text[MacroKey(macro.name, macro.body)] = true
                made = made + 1
            else
                full[#full + 1] = macro.name
            end
        end
    end
    -- Macros are kept sorted by name, so making one moves the others.
    if made > 0 and not test then index = MacroIndex() end
    return index, made, full
end

local function ImportBindings(set, test)
    local count = 0
    for key, command in pairs(set.bindings) do
        if test or SetBinding(key, command, C_KeyBindings.GetBindingContextForAction(command)) then
            count = count + 1
        end
    end
    if not test then SaveBindings(GetCurrentBindingSet()) end
    return count
end

-- A spell falls back to the highest rank known when the saved rank is not, so a set made at
-- a higher level still imports.
local function PickUp(entry, best, index, test)
    ClearCursor()
    if entry.kind == "spell" then
        local top = entry.name and best[entry.name]
        if top and S.Get("highestRank") then C_Spell.PickupSpell(top) end
        if not GetCursorInfo() then C_Spell.PickupSpell(entry.id) end
        if not GetCursorInfo() and top then C_Spell.PickupSpell(top) end
    elseif entry.kind == "macro" then
        local found = Lookup(index, entry)
        if test then return found ~= nil end
        if found then PickupMacro(found) end
    elseif entry.kind == "item" then
        C_Item.PickupItem(entry.id)
    elseif entry.kind == "equipmentset" then
        local setID = type(entry.id) == "number" and entry.id or C_EquipmentSet.GetEquipmentSetID(entry.id)
        if setID then C_EquipmentSet.PickupEquipmentSet(setID) end
    end
    return GetCursorInfo() ~= nil
end

local function Plural(n, word)
    return ("%d %s%s"):format(n, word, n == 1 and "" or "s")
end

-- Every slot ends as it was saved: a slot the set leaves empty is cleared, and so is one
-- whose action cannot come back. A slot saved holding something no set can import (a
-- mount, a pet, a flyout) is left as it is. Keys the set leaves free keep what they do here.
local function Import(name, test)
    if not Ready("imported") then return end
    local key = Find(name)
    if not key then ns.Print(("No bar set called %s for your class."):format(name)) return end
    local set = Sets()[key]
    local index, made, full
    if S.Get("importMacros") then
        index, made, full = ImportMacros(set, test)
    else
        index, made, full = MacroIndex(), 0, {}
    end
    local best, failed, actions = HighestRanks(), {}, 0
    for _, slot in ipairs(Slots()) do
        local entry = set.slots[slot]
        if not entry or RESTORABLE[entry.kind] then
            if entry then actions = actions + 1 end
            if entry and PickUp(entry, best, index, test) then
                if not test then PlaceAction(slot) end
            else
                if entry then failed[#failed + 1] = ("Slot %d: %s"):format(slot, Describe(entry)) end
                if not test and GetActionInfo(slot) then PickupAction(slot) end
            end
            ClearCursor()
        end
    end
    local bound = set.bindings and S.Get("importBindings") and ImportBindings(set, test)
    if not test then SetLast(key) end

    local parts = { ("%d of %d actions"):format(actions - #failed, actions) }
    if made > 0 then parts[#parts + 1] = Plural(made, "new macro") end
    if bound then parts[#parts + 1] = Plural(bound, "keybind") end
    ns.Print(("%s %s: %s."):format(test and "Test import of" or "Imported", key, table.concat(parts, ", ")))
    if #full > 0 then
        print(("   No room for %s: %s"):format(Plural(#full, "macro"), table.concat(full, ", ")))
    end
    if #failed > 0 then
        print(test and "   These slots would be left empty:" or "   These slots were left empty:")
        for _, line in ipairs(failed) do print("      " .. line) end
    end
end

local function Delete(key)
    Sets()[key] = nil
    ns.Print(("Deleted the bar set %s."):format(key))
    if UI.RefreshPage then UI:RefreshPage(true) end
end

local function Rename(key, new)
    if new == key then return end
    if Find(new) and Find(new) ~= key then ns.Print(("There is already a bar set called %s."):format(new)) return end
    local sets = Sets()
    local set = sets[key]
    sets[key] = nil
    sets[new] = set
    for _, last in pairs(Account("barSetLast")) do
        if last.class == Class() and last.name == key then last.name = new end
    end
    if UI.RefreshPage then UI:RefreshPage(true) end
end

local function PromptSave()
    ns.PromptText("Name for your current bars", "", 40, function(name)
        local key = Find(name)
        if key then
            ns.Confirm(("Replace %s with the bars you have now?"):format(key), function() Save(key) end)
        else
            Save(name)
        end
    end)
end

-------------------------------------------------------------------------------
--  Options and slash command
-------------------------------------------------------------------------------
local function ConfirmImport(key)
    ns.Confirm(("Import %s? Your action bars and keybinds are replaced."):format(key), function() Import(key) end)
end

local function SetMenu(key)
    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateButton("Test Import", function() Import(key, true) end)
        root:CreateButton("Save Current Bars Here", function()
            ns.Confirm(("Replace %s with the bars you have now?"):format(key), function() Save(key) end)
        end)
        root:CreateButton("Rename", function()
            ns.PromptText("New name for " .. key, key, 40, function(new) Rename(key, new) end)
        end)
        root:CreateButton("Delete", function()
            ns.Confirm(("Delete the bar set %s?"):format(key), function() Delete(key) end)
        end)
    end)
end

local SAVE_W, BUTTON_H, ROW_BUTTON_W, ROW_PAD, ROW_GAP = 170, 26, 80, 8, 8
local STRIPE_ALPHA = 0.025

local function Contents(set)
    local actions, keys = 0, 0
    for _ in pairs(set.slots) do actions = actions + 1 end
    local parts = { Plural(actions, "action") }
    if set.macros then parts[#parts + 1] = Plural(#set.macros, "macro") end
    if set.bindings then
        for _ in pairs(set.bindings) do keys = keys + 1 end
        parts[#parts + 1] = Plural(keys, "keybind")
    end
    return table.concat(parts, ", ")
end

local function SetRow(parent, y, key, set, stripe)
    local T, x = ns.THEME, UI.CONTENT_PAD
    local band = UI.Keep(parent, "barsStripe", function(p) return ns.Solid(p, "BACKGROUND", ns.THEME.fg, STRIPE_ALPHA) end)
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", parent, "TOPLEFT", x - ROW_PAD, y)
    band:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(x - ROW_PAD), y)
    band:SetShown(stripe)
    local name = UI.KeepFont(parent, "barsName", 13, nil, T.fg)
    name:ClearAllPoints()
    name:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - ROW_PAD)
    name:SetText(key)
    local saved = UI.KeepFont(parent, "barsSaved", 11, nil, T.muted)
    saved:ClearAllPoints()
    saved:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    saved:SetText("Saved " .. date("%d %b %Y", set.saved) .. (set.by and (" by " .. set.by) or ""))
    local has = UI.KeepFont(parent, "barsHas", 11, nil, T.muted)
    has:ClearAllPoints()
    has:SetPoint("TOPLEFT", saved, "BOTTOMLEFT", 0, -3)
    has:SetText(Contents(set))
    local h = ROW_PAD * 2 + math.ceil(name:GetStringHeight()) + 3 + math.ceil(saved:GetStringHeight())
        + 3 + math.ceil(has:GetStringHeight())
    local more = UI.KeepButton(parent, "barsMore", "More", ROW_BUTTON_W, BUTTON_H, function() SetMenu(key) end)
    more:ClearAllPoints()
    more:SetPoint("RIGHT", parent, "TOPRIGHT", -x, y - h / 2)
    local import = UI.KeepButton(parent, "barsImport", "Import", ROW_BUTTON_W, BUTTON_H, function() ConfirmImport(key) end)
    import:ClearAllPoints()
    import:SetPoint("RIGHT", more, "LEFT", -ROW_GAP, 0)
    band:SetHeight(h)
    return h
end

function ns.BuildActionBarsPage(parent, y)
    local W = UI.Widgets
    local T, x = ns.THEME, UI.CONTENT_PAD
    local _, h
    local save = UI.KeepButton(parent, "barsSave", "Save Current Bars", SAVE_W, BUTTON_H, PromptSave)
    ns.AccentBorder(save)
    save:ClearAllPoints()
    save:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - ROW_PAD)
    local hint = UI.KeepFont(parent, "barsHint", 11, nil, T.muted)
    hint:ClearAllPoints()
    hint:SetPoint("LEFT", save, "RIGHT", 12, 0)
    hint:SetText(("Bars, macros and keybinds, for every %s."):format(UnitClass("player")))
    y = y - BUTTON_H - ROW_PAD * 3

    local names = SortedNames()
    _, h = W:SectionHeader(parent, "SAVED SETS", y); y = y - h
    if #names == 0 then
        _, h = W:Note(parent, "Nothing saved yet. Save your bars, macros and keybinds as they are now, then "
            .. "import them on a fresh character, for another spec or a dungeon set-up.", y)
        return y - h
    end
    for i, key in ipairs(names) do
        y = y - SetRow(parent, y, key, Sets()[key], i % 2 == 0)
    end
    return y
end

-- /nf bars save|import|test|delete <name>, /nf bars list; on its own it opens the window.
-- restore still works for import.
function ns.ActionBarsCommand(text)
    local cmd, name = strtrim(text or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "list" then
        local names = SortedNames()
        ns.Print(#names > 0 and ("Bar sets: " .. table.concat(names, ", ")) or "No bar sets saved for your class.")
    elseif name == "" or not (cmd == "save" or cmd == "import" or cmd == "restore" or cmd == "test"
        or cmd == "delete") then
        ns.OpenActionBarsWindow()
    elseif cmd == "save" then
        Save(name)
    elseif cmd == "import" or cmd == "restore" then
        Import(name)
    elseif cmd == "test" then
        Import(name, true)
    else
        local key = Find(name)
        if key then Delete(key) else ns.Print(("No bar set called %s for your class."):format(name)) end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function()
    if not (S.Get("enabled") and S.Get("saveOnLogout")) then return end
    local last = Account("barSetLast")[CharKey()]
    local key = last and last.name
    if key and Sets()[key] then Sets()[key] = Snapshot() end
end)

local function On() return S.Get("enabled") == true end

local function Headline()
    local n = 0
    for _ in pairs(Sets()) do n = n + 1 end
    local class = UnitClass("player")
    if n == 0 then return ("No bar sets saved for your %s yet"):format(class) end
    return ("%d bar set%s saved for your %s"):format(n, n == 1 and "" or "s", class)
end

local function Detail()
    if not On() then return "Turn on Action Bars to save and import your bars." end
    local last = Account("barSetLast")[CharKey()]
    if last and last.class == Class() and Sets()[last.name] then
        return ("This character last used %s. Import any set from the window, out of combat."):format(last.name)
    end
    return "Save your bars from the window, or with /nf bars save and a name."
end

ns.ActionBarSets = { Headline = Headline, Detail = Detail }

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local BARS_OFF = "Turn on Action Bars"

local function ImportingSummary(store)
    local parts = { store.Get("highestRank") and "Highest ranks" or "Saved ranks" }
    if store.Get("importMacros") then parts[#parts + 1] = "macros" end
    if store.Get("importBindings") then parts[#parts + 1] = "keybinds" end
    if store.Get("saveOnLogout") then parts[#parts + 1] = "saves on logout" end
    return table.concat(parts, ", ")
end

local page = Settings.Page("Action Bars/Settings", S)

page:Window({
    text = "Open Action Bars",
    open = function() ns.OpenActionBarsWindow() end,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "importing", name = "Importing", order = 10,
    help = "What a saved set brings back when you import it. Sets are saved and imported from the Action "
        .. "Bars window, out of combat.",
    summary = ImportingSummary,
    rows = {
        { key = "highestRank", label = "Highest Rank", toggle = true, needs = On, why = BARS_OFF,
          help = "Imports the highest rank you know of each spell instead of the rank that was saved. Off, a "
              .. "rank you no longer have still falls back to your highest." },
        { key = "importMacros", label = "Import Macros", toggle = true, needs = On, why = BARS_OFF,
          help = "Makes the set's macros that this character does not have. A macro you already have, by name "
              .. "and text or by text alone, is used as it is: never copied twice or changed." },
        { key = "importBindings", label = "Import Keybinds", toggle = true, needs = On, why = BARS_OFF,
          help = "Binds every key the set has bound. Keys the set leaves free keep what they do here." },
        { key = "saveOnLogout", label = "Save on Logout", toggle = true, needs = On, why = BARS_OFF,
          help = "When you log out, the set this character saved or imported last is saved again with your "
              .. "bars, macros and keybinds as they are." },
    },
})

page:Card({
    id = "window", name = "Window", order = 20,
    help = "Action Bars' own window, with your class's saved sets.",
    rows = {
        { key = "windowAlpha", label = "Window Opacity", slider = { ns.Shared.Style.OPACITY_MIN, 100, 5 },
          unit = "%", scale = 0.01, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
