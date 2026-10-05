-------------------------------------------------------------------------------
--  NaowhForever_ProfileShare.lua -- the Profiles page's Export and Import. Export makes the
--  parts ticked of the profile in use one string: every module's settings and positions, the
--  macros, the macro Library, Smart Reminders, talent builds, the BiS lists and the account's
--  look. Import shows what a string holds, takes the parts left ticked into a new profile and
--  switches to it; no existing profile changes. Any other Naowh Forever string pasted there
--  goes to its own import: a Smart Reminders pack, Forge macros, a talent build, a BiS list.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local UI = ns.UI

local PREFIX = "NFPROFILE1:"
local PACK_PREFIX = "NSRPACK2:"
local FORMAT = 1
local MAX_DEPTH = 12
local MAX_VALUES = 200000   -- values a string may hold; more is refused as too big

-- The account's look: every profile shares it, so it travels as its own part.
local LOOK = { "themePreset", "themeColors", "uiFont", "windowScale" }

-- The parts, in the order the import lists them.
local PARTS = {
    { key = "settings", label = "Settings", help = "Every module's settings and positions" },
    { key = "macros", label = "Macros", help = "Your class macros and the Macros settings" },
    { key = "library", label = "Macro Library", help = "Added next to your Library, never over it" },
    { key = "smartReminders", label = "Smart Reminders", help = "Reminders, priorities and callouts" },
    { key = "builds", label = "Talent Builds", help = "Added next to your saved builds" },
    { key = "bisLists", label = "BiS Lists", help = "Added next to your own lists, never over them" },
    { key = "look", label = "Look", help = "Theme colours, font and window scale, for every profile" },
}

-------------------------------------------------------------------------------
--  The string
-------------------------------------------------------------------------------
local function Codec()
    local LS = LibStub and LibStub("LibSerialize", true)
    local LD = LibStub and LibStub("LibDeflate", true)
    if LS and LD then return LS, LD end
end

-- Plain data only (strings, numbers, booleans, tables keyed by strings or numbers), so
-- nothing live or unsaveable is shared or taken in. budget.over once there is too much.
local function Plain(v, depth, budget)
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return v end
    if t ~= "table" or depth > MAX_DEPTH or budget.over then return nil end
    local out = {}
    for k, val in pairs(v) do
        budget.n = budget.n + 1
        if budget.n > MAX_VALUES then
            budget.over = true
            return nil
        end
        local kt = type(k)
        if kt == "string" or kt == "number" then out[k] = Plain(val, depth + 1, budget) end
    end
    return out
end

-- A module's values as its settings keep them: a value with a default only as that type.
local function Checked(values, defaults)
    local out = {}
    for k, v in pairs(values) do
        local d = defaults[k]
        if d == nil or type(v) == type(d) then out[k] = v end
    end
    return out
end

-- Every part the profile in use can share, what had to stay behind, and whether it is too big.
local function Collect()
    local root, account = ns.SettingsRoot(), ns.AccountSettings()
    local budget = { n = 0 }
    local parts, note = {}, nil

    local settings = {}
    for key, values in pairs(root) do
        if key ~= "tankReminder" and key ~= "macros" and type(values) == "table" and ns.ModuleDefaults(key) then
            settings[key] = Plain(values, 1, budget)
        end
    end
    if next(settings) then parts.settings = settings end

    -- A profile made from someone's pack keeps their work: the pack export refuses it too.
    local sr = root.tankReminder
    local packed = type(sr) == "table" and type(sr.importedPack) == "table"
    if packed then
        note = ("Smart Reminders and class macros came from %s, so they are left out."):format(
            tostring(sr.importedPack.name))
    end

    local macros = {}
    if type(root.macros) == "table" then macros.module = Plain(root.macros, 1, budget) end
    local utility = type(sr) == "table" and sr.utilityReminders
    if not packed and type(utility) == "table" and type(utility.classMacros) == "table" then
        macros.classMacros = Plain(utility.classMacros, 1, budget)
    end
    if next(macros) then parts.macros = macros end

    -- Class macros live in Smart Reminders' data; they travel as Macros only, so leaving
    -- Macros unticked on import leaves them out.
    if type(sr) == "table" and not packed then
        local copy = Plain(sr, 1, budget)
        if copy and type(copy.utilityReminders) == "table" then copy.utilityReminders.classMacros = nil end
        parts.smartReminders = copy
    end

    if type(account.bisLists) == "table" then
        local lists = {}
        for class, store in pairs(account.bisLists) do
            if type(store) == "table" and type(store.lists) == "table" and #store.lists > 0 then
                lists[class] = Plain(store.lists, 1, budget)
            end
        end
        if next(lists) then parts.bisLists = lists end
    end

    -- A Library copy of a pack macro stays with the pack's curator, as the pack's macros do.
    if type(account.libraryMacros) == "table" then
        local library, copies = {}, false
        for class, list in pairs(account.libraryMacros) do
            local own = {}
            for _, m in ipairs(list) do
                if m.pack then copies = true else own[#own + 1] = Plain(m, 1, budget) end
            end
            if #own > 0 then library[class] = own end
        end
        if next(library) then parts.library = library end
        if copies then
            note = (note and note .. "\n" or "") .. "Library macros copied from a pack are left out."
        end
    end

    if type(account.trainingBuilds) == "table" then
        local builds = {}
        for classID, list in pairs(account.trainingBuilds) do
            local out = {}
            for i, b in ipairs(list) do
                out[i] = { name = b.name, spec = b.spec, points = Plain(b.points, 1, budget) }
            end
            if #out > 0 then builds[classID] = out end
        end
        if next(builds) then parts.builds = builds end
    end

    local look = {}
    for _, key in ipairs(LOOK) do
        if account[key] ~= nil then look[key] = Plain(account[key], 1, budget) end
    end
    if next(look) then parts.look = look end

    return parts, note, budget.over
end

--- The parts ticked in wanted ({ [partKey] = true }, nil for all) of the profile in use as a
--- string. Returns it and, when a part had to stay behind, why.
---@return string? text
---@return string? note an error when text is nil, else what was left out
function ns.ExportProfile(wanted)
    local LS, LD = Codec()
    if not LS then return nil, "The serializer libraries are missing from this build." end
    local all, note, over = Collect()
    if over then return nil, "This profile is too big to share." end
    local parts = {}
    for key, data in pairs(all) do
        if not wanted or wanted[key] then parts[key] = data end
    end
    if not next(parts) then
        return nil, next(all) and "Tick a part to share." or "There is nothing to export yet."
    end
    local payload = {
        format = FORMAT, name = ns.ActiveProfileName(), author = UnitName("player"),
        made = date("%Y-%m-%d"), build = ns.CODE_BUILD, parts = parts,
    }
    return PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(payload))), note
end

--- A string back into what it holds. "pack" for a Smart Reminders pack string.
---@return table? payload
---@return string? err
function ns.DecodeProfile(text)
    text = (text or ""):gsub("%s", "")
    if text == "" then return nil end
    if text:sub(1, #PACK_PREFIX) == PACK_PREFIX then return nil, "pack" end
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, "This is not a Naowh Forever profile string." end
    local LS, LD = Codec()
    if not LS then return nil, "The serializer libraries are missing from this build." end
    local compressed = LD:DecodeForPrint(text:sub(#PREFIX + 1))
    local raw = compressed and LD:DecompressDeflate(compressed)
    if not raw then return nil, "The string is damaged: copy it again in full." end
    local ok, payload = LS:Deserialize(raw)
    if not ok or type(payload) ~= "table" or type(payload.parts) ~= "table" then
        return nil, "The string is damaged: copy it again in full."
    end
    if payload.format ~= FORMAT then return nil, "This string is from a newer Naowh Forever: update first." end
    local budget = { n = 0 }
    payload.parts = Plain(payload.parts, 1, budget)
    if budget.over then return nil, "This string is too big." end
    return payload
end

local function Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- What a decoded string holds, part by part: { key, label, help, detail }.
function ns.ProfileStringParts(payload)
    local out, parts = {}, payload.parts
    for _, part in ipairs(PARTS) do
        local data = parts[part.key]
        if type(data) == "table" and next(data) then
            local detail
            if part.key == "settings" then
                detail = ("%d modules"):format(Count(data))
            elseif part.key == "macros" then
                local n = 0
                for _, list in pairs(type(data.classMacros) == "table" and data.classMacros or {}) do
                    if type(list) == "table" then n = n + Count(list) end
                end
                detail = ("%d class macros"):format(n)
            elseif part.key == "bisLists" or part.key == "library" or part.key == "builds" then
                local n = 0
                for _, list in pairs(data) do
                    if type(list) == "table" then n = n + #list end
                end
                detail = ("%d %s"):format(n, part.key == "bisLists" and "lists"
                    or part.key == "library" and "macros" or "builds")
            end
            out[#out + 1] = { key = part.key, label = part.label, help = part.help, detail = detail }
        end
    end
    return out
end

-------------------------------------------------------------------------------
--  Taking a string in
-------------------------------------------------------------------------------
local function FreeProfileName(base)
    base = type(base) == "string" and base:match("^%s*(.-)%s*$") or ""
    if base == "" then base = "Imported Profile" end
    if not ns.ProfileExists(base) then return base end
    local n = 2
    while ns.ProfileExists(base .. " " .. n) do n = n + 1 end
    return base .. " " .. n
end

local function SameList(a, b)
    if a.name ~= b.name or type(a.slots) ~= type(b.slots) then return false end
    if type(a.slots) ~= "table" then return true end
    for slot, id in pairs(a.slots) do if b.slots[slot] ~= id then return false end end
    for slot in pairs(b.slots) do if a.slots[slot] == nil then return false end end
    return true
end

-- Each list joins its class's lists under a free name; one already there as it is, is skipped.
local function AddBisLists(incoming)
    local account = ns.AccountSettings()
    account.bisLists = type(account.bisLists) == "table" and account.bisLists or {}
    local added = 0
    for class, lists in pairs(incoming) do
        if type(class) == "string" and type(lists) == "table" then
            local store = account.bisLists[class]
            if type(store) ~= "table" or type(store.lists) ~= "table" then
                store = { lists = {}, nextID = 1 }
                account.bisLists[class] = store
            end
            store.nextID = tonumber(store.nextID) or #store.lists + 1
            for _, list in ipairs(lists) do
                local have = false
                for _, mine in ipairs(store.lists) do
                    if type(list) == "table" and SameList(mine, list) then have = true end
                end
                if type(list) == "table" and type(list.name) == "string" and not have then
                    local name, n = list.name, 1
                    local function Taken(try)
                        for _, mine in ipairs(store.lists) do
                            if type(mine.name) == "string" and mine.name:lower() == try:lower() then return true end
                        end
                    end
                    while Taken(name) do
                        n = n + 1
                        name = ("%s %d"):format(list.name, n)
                    end
                    list.name, list.id = name, store.nextID
                    store.nextID = store.nextID + 1
                    store.lists[#store.lists + 1] = list
                    added = added + 1
                end
            end
        end
    end
    return added
end

-- Each macro joins its class's Library when it fits a macro; a name already there keeps yours.
local function AddLibrary(incoming)
    local account = ns.AccountSettings()
    account.libraryMacros = type(account.libraryMacros) == "table" and account.libraryMacros or {}
    local added = 0
    for class, list in pairs(incoming) do
        if type(class) == "string" and type(list) == "table" then
            local mine = account.libraryMacros[class] or {}
            for _, m in ipairs(list) do
                local name = type(m) == "table" and type(m.name) == "string" and m.name:gsub("[|\r\n]", "")
                local body = name and m.body
                local taken = false
                for _, e in ipairs(mine) do taken = taken or e.name == name end
                if name and #name >= 1 and #name <= 16 and type(body) == "string" and #body >= 1
                    and #body <= ns.MacroText.LIMIT and not taken then
                    local icon = (type(m.icon) == "number" or type(m.icon) == "string") and m.icon or nil
                    mine[#mine + 1] = { name = name, body = body, icon = icon }
                    account.libraryMacros[class] = mine
                    added = added + 1
                end
            end
        end
    end
    return added
end

local function SameBuild(a, b)
    if a.name ~= b.name or #a.points ~= #b.points then return false end
    for i, node in ipairs(a.points) do if b.points[i] ~= node then return false end end
    return true
end

-- Each build joins its class's saved builds when its points can be taken in that order; one
-- already there as it is, is skipped.
local function AddBuilds(incoming)
    local Training = ns.Training
    local account = ns.AccountSettings()
    account.trainingBuilds = type(account.trainingBuilds) == "table" and account.trainingBuilds or {}
    local added = 0
    for classID, list in pairs(incoming) do
        local tree = ns.TrainingBuilds[classID]
        if tree and type(list) == "table" then
            local saved = account.trainingBuilds[classID] or {}
            for _, b in ipairs(list) do
                local points = {}
                for i, node in ipairs(type(b) == "table" and type(b.points) == "table" and b.points or {}) do
                    points[i] = node
                end
                if #points > 0 and not Training.CheckBuild(tree, points) then
                    local build = { name = Training.BuildName(b.name, "Imported Build"),
                        spec = Training.BuildName(b.spec, "Imported"), points = points, saved = true }
                    local have = false
                    for _, mine in ipairs(saved) do have = have or SameBuild(mine, build) end
                    if not have then
                        saved[#saved + 1] = build
                        account.trainingBuilds[classID] = saved
                        added = added + 1
                    end
                end
            end
        end
    end
    if added > 0 then Training.Changed() end
    return added
end

--- The parts of a decoded string ticked in wanted ({ [partKey] = true }), as a new profile
--- named name (made free if taken), then switched to. The look, Library, builds and BiS lists
--- are account-wide.
---@return string name the profile made
---@return table added how many { bisLists, library, builds } joined the account's
function ns.ImportProfile(payload, wanted, name)
    local parts = payload.parts
    name = FreeProfileName(name or payload.name)
    local root = ns.ProfileRoot(name)

    if wanted.settings and type(parts.settings) == "table" then
        for key, values in pairs(parts.settings) do
            local defaults = ns.ModuleDefaults(key)
            if defaults and key ~= "macros" and key ~= "tankReminder" and type(values) == "table" then
                root[key] = Checked(values, defaults)
            end
        end
    end
    if wanted.smartReminders and type(parts.smartReminders) == "table" then
        root.tankReminder = parts.smartReminders
        root.tankReminder.importedPack = nil
    end
    if wanted.macros and type(parts.macros) == "table" then
        local macros = parts.macros
        if type(macros.module) == "table" then root.macros = Checked(macros.module, ns.ModuleDefaults("macros") or {}) end
        if type(macros.classMacros) == "table" then
            local sr = root.tankReminder
            if type(sr.utilityReminders) ~= "table" then sr.utilityReminders = {} end
            sr.utilityReminders.classMacros = macros.classMacros
        end
    end
    local added = { bisLists = 0, library = 0, builds = 0 }
    if wanted.bisLists and type(parts.bisLists) == "table" then added.bisLists = AddBisLists(parts.bisLists) end
    if wanted.library and type(parts.library) == "table" then added.library = AddLibrary(parts.library) end
    if wanted.builds and type(parts.builds) == "table" then added.builds = AddBuilds(parts.builds) end
    if wanted.look and type(parts.look) == "table" then
        local account = ns.AccountSettings()
        for _, key in ipairs(LOOK) do
            if parts.look[key] ~= nil then account[key] = parts.look[key] end
        end
    end

    ns.SwitchProfile(name)
    if ns.RefreshRuntime then ns.RefreshRuntime() end
    return name, added
end

-------------------------------------------------------------------------------
--  The two dialogs, in the house modal
-------------------------------------------------------------------------------
local EXPORT_W, EXPORT_H, BOX_H = 560, 460, 180
local IMPORT_W, IMPORT_H, PASTE_H = 600, 520, 110
local PAD, ROW_H, BUTTON_W, BUTTON_H = 14, 24, 120, 26
local TOGGLE_W, TOGGLE_H = 32, 16
local TICKS_TOP = 62               -- export: the part ticks start under the profile's name
local TICK_LINES = 4               -- export: two columns, room for every part

-- Strings another import takes in: what the dialog says, and the button that hands them over.
local HANDOFFS = {
    { prefix = PACK_PREFIX, button = "Open Pack Import",
      what = "This is a Smart Reminders pack. The pack import takes it in, with its specs and licence.",
      go = function(text) ns.ShowPackImport(text) end },
    { prefix = "!NFM1!", button = "Add Macros",
      what = "These are Forge macros. They are added as character macros on this character.",
      go = function(text) ns.ImportMacroString(text) end },
    { prefix = "!NFB1!", button = "Add Build",
      what = "This is a talent build. It is added to your builds in the Training Planner.",
      go = function(text) ns.Training.ImportBuild(text, function() end) end },
    { prefix = "!NBIS1!", button = "Add BiS List",
      what = "This is a BiS list. It is added next to your own lists.",
      go = function(text) ns.ImportBisList(text) end },
}

-- A dialog's i-th part row with its tick; dialog.onTick runs after a tick changes.
local function PartRow(dialog, i)
    local row = dialog.rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, dialog.panel)
    row:SetHeight(ROW_H)
    row.toggle = UI.BuildToggleControl(row, nil, function() return dialog.wanted[row.key] end,
        function(on)
            dialog.wanted[row.key] = on == true
            if dialog.onTick then dialog.onTick() end
        end, TOGGLE_W, TOGGLE_H)
    row.toggle:SetPoint("LEFT", 0, 0)
    row.label = UI.KeepFont(row, "label", 12, nil, ns.THEME.fg)
    row.label:SetPoint("LEFT", row.toggle, "RIGHT", 10, 0)
    row.help = UI.KeepFont(row, "help", 11, nil, ns.THEME.muted)
    row.help:SetPoint("LEFT", row.label, "RIGHT", 10, 0)
    dialog.rows[i] = row
    return row
end

local export

local function PaintExport()
    local text, note = ns.ExportProfile(export.wanted)
    if text then
        export.text = ns.WrapForDisplay(text, export.box:GetParent():GetWidth())
        export.box:SetText(export.text)
        export.status:SetText(("%d characters. Click the text, then Ctrl+A and Ctrl+C.%s"):format(#text,
            note and ("\n" .. note) or ""))
    else
        export.text = ""
        export.box:SetText("")
        export.status:SetText(note or "")
    end
end

function ns.ShowProfileExport()
    if not export then
        local dimmer, panel = ns.MakeModal(EXPORT_W, EXPORT_H, "profileExport")
        local title = ns.Font(panel, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -PAD)
        title:SetText("Export Profile")
        local what = UI.KeepFont(panel, "what", 11, nil, ns.THEME.muted)
        what:SetPoint("TOPLEFT", PAD, -40)
        what:SetPoint("RIGHT", -PAD, 0)
        what:SetJustifyH("LEFT")
        local boxTop = TICKS_TOP + TICK_LINES * ROW_H + 8
        local box = ns.MakeMultilineBox(panel, -boxTop, BOX_H)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        -- The text is the export: typing in it is undone.
        box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(export.text or "") end end)
        local status = UI.KeepFont(panel, "status", 11, nil, ns.THEME.fg)
        status:SetPoint("TOPLEFT", PAD, -(boxTop + BOX_H + 12))
        status:SetPoint("RIGHT", -PAD, 0)
        status:SetJustifyH("LEFT")
        local close = ns.Button(panel, "Close", BUTTON_W, BUTTON_H, function() dimmer:Hide() end)
        close:SetPoint("BOTTOM", 0, PAD)
        export = { dimmer = dimmer, panel = panel, box = box, what = what, status = status, rows = {},
            wanted = {}, onTick = PaintExport }
    end
    export.what:SetText(("Profile: %s. Untick what you don't want to share."):format(ns.ActiveProfileName() or "?"))
    wipe(export.wanted)
    for _, row in ipairs(export.rows) do row:Hide() end
    local colW = (EXPORT_W - 2 * PAD) / 2
    for i, part in ipairs(ns.ProfileStringParts({ parts = (Collect()) })) do
        local row = PartRow(export, i)
        row.key = part.key
        export.wanted[part.key] = true
        row.label:SetText(part.label)
        row.help:SetText(part.detail or "")
        row.toggle._refreshValue()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD + ((i - 1) % 2) * colW, -(TICKS_TOP + math.floor((i - 1) / 2) * ROW_H))
        row:SetWidth(colW)
        row:Show()
    end
    PaintExport()
    export.dimmer:Show()
end

local import

local function PaintImport()
    local text = import.box:GetText()
    local flat = text:gsub("%s", "")
    import.handoff = nil
    for _, handoff in ipairs(HANDOFFS) do
        if flat:sub(1, #handoff.prefix) == handoff.prefix then import.handoff = handoff end
    end
    for _, row in ipairs(import.rows) do row:Hide() end
    if import.handoff then
        import.payload = nil
        import.nameRow:Hide()
        import.preview:SetText(import.handoff.what)
        ns.SetButtonText(import.go, import.handoff.button)
        import.go:Show()
        return
    end
    local payload, err = ns.DecodeProfile(text)
    import.payload = payload
    import.nameRow:SetShown(payload ~= nil)
    ns.SetButtonText(import.go, "Import")
    import.go:SetShown(payload ~= nil)
    if not payload then
        import.preview:SetText(err or "Paste a profile, macro, talent build or BiS list string above.")
        return
    end
    import.preview:SetText(("%s, shared by %s on %s. Untick what you don't want."):format(
        tostring(payload.name or "A profile"), tostring(payload.author or "someone"), tostring(payload.made or "?")))
    local y = -(40 + PASTE_H + 44)
    for i, part in ipairs(ns.ProfileStringParts(payload)) do
        local row = PartRow(import, i)
        row.key = part.key
        if import.wanted[part.key] == nil then import.wanted[part.key] = true end
        row.label:SetText(part.label)
        row.help:SetText(part.detail and (part.help .. " (" .. part.detail .. ")") or part.help)
        row.toggle._refreshValue()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, y)
        row:SetPoint("RIGHT", -PAD, 0)
        row:Show()
        y = y - ROW_H
    end
    import.nameRow:ClearAllPoints()
    import.nameRow:SetPoint("TOPLEFT", PAD, y - 10)
    import.nameRow:SetPoint("RIGHT", -PAD, 0)
    import.nameBox:SetText(FreeProfileName(payload.name))
end

local function Go()
    if import.handoff then
        local text = import.box:GetText()
        import.dimmer:Hide()
        import.handoff.go(text)
        return
    end
    local payload = import.payload
    if not payload then return end
    local name, added = ns.ImportProfile(payload, import.wanted, import.nameBox:GetText())
    import.dimmer:Hide()
    if UI.RefreshPage then UI:RefreshPage(true) end
    local joined = {}
    if added.library > 0 then joined[#joined + 1] = added.library .. " Library macros" end
    if added.builds > 0 then joined[#joined + 1] = added.builds .. " talent builds" end
    if added.bisLists > 0 then joined[#joined + 1] = added.bisLists .. " BiS lists" end
    local extra = #joined > 0 and (" Added %s."):format(table.concat(joined, ", ")) or ""
    ns.ConfirmReload(("Imported as %s and switched to it.%s Reload so every module picks it up?"):format(name, extra))
end

function ns.ShowProfileImport()
    if not import then
        local dimmer, panel = ns.MakeModal(IMPORT_W, IMPORT_H, "profileImport")
        local title = ns.Font(panel, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -PAD)
        title:SetText("Import")
        local box = ns.MakeMultilineBox(panel, -40, PASTE_H)
        local preview = UI.KeepFont(panel, "preview", 12, nil, ns.THEME.fg)
        preview:SetPoint("TOPLEFT", PAD, -(40 + PASTE_H + 14))
        preview:SetPoint("RIGHT", -PAD, 0)
        preview:SetJustifyH("LEFT")
        local nameRow = CreateFrame("Frame", nil, panel)
        nameRow:SetHeight(ROW_H)
        local nameLabel = UI.KeepFont(nameRow, "label", 12, nil, ns.THEME.fg)
        nameLabel:SetPoint("LEFT", 0, 0)
        nameLabel:SetText("New profile's name")
        local nameBox = ns.NewEditBox(nameRow)
        nameBox:SetSize(220, 22)
        nameBox:SetMaxLetters(40)
        nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
        nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local go = ns.AccentBorder(ns.Button(panel, "Import", BUTTON_W, BUTTON_H, Go))
        go:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -4, PAD)
        local cancel = ns.Button(panel, "Cancel", BUTTON_W, BUTTON_H, function() dimmer:Hide() end)
        cancel:SetPoint("BOTTOMLEFT", panel, "BOTTOM", 4, PAD)
        import = { dimmer = dimmer, panel = panel, box = box, preview = preview, nameRow = nameRow,
            nameBox = nameBox, go = go, rows = {}, wanted = {} }
        box:SetScript("OnTextChanged", function(_, user) if user then PaintImport() end end)
    end
    import.box:SetText("")
    wipe(import.wanted)
    PaintImport()
    import.dimmer:Show()
    import.box:SetFocus()
end
