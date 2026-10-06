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

-- The parts, in the order the import and the Profiles page list them. help: what Import does
-- with one; share: what the page's export says it is.
local PARTS = {
    { key = "settings", label = "Settings", help = "Every module's settings and positions",
      share = "Every module's settings and where its frames sit." },
    { key = "macros", label = "Macros", help = "Your class macros and the Macros settings",
      share = "Your class macros and the Macros settings." },
    { key = "library", label = "Macro Library", help = "Added next to your Library, never over it",
      share = "The macros you saved to the Forge's Library." },
    { key = "smartReminders", label = "Smart Reminders", help = "Reminders, priorities and callouts",
      share = "Reminders, priorities and callouts." },
    { key = "builds", label = "Talent Builds", help = "Added next to your saved builds",
      share = "The talent builds you saved in the Training Planner." },
    { key = "bisLists", label = "BiS Lists", help = "Added next to your own lists, never over them",
      share = "Your BiS lists, for every class." },
    { key = "look", label = "Look", help = "Theme colours, font and window scale, for every profile",
      share = "Theme colours, font and window scale." },
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

-- Forever's Lua raises on 1 / 0, which LibSerialize does to every 0 it writes (to spot -0), so
-- a 0 travels as ZERO and is put back on import.
local ZERO = "\0"

local function Swap(v, from, to)
    if v == from then return to end
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[Swap(k, from, to)] = Swap(val, from, to) end
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
    return PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(Swap(payload, 0, ZERO)))), note
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
    payload.parts = Plain(Swap(payload.parts, ZERO, 0), 1, budget)
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
    -- The Library and builds are checked by the Macros and Training Planner code, so they wait
    -- for those modules to be on.
    if wanted.library and ns.MacroText and type(parts.library) == "table" then added.library = AddLibrary(parts.library) end
    if wanted.builds and ns.Training and type(parts.builds) == "table" then added.builds = AddBuilds(parts.builds) end
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
local EXPORT_W, EXPORT_H, BOX_H = 560, 360, 180
local IMPORT_W, IMPORT_H, PASTE_H = 600, 520, 110
local PAD, ROW_H, BUTTON_W, BUTTON_H = 14, 24, 120, 26
local TOGGLE_W, TOGGLE_H = 32, 16

-- Strings another import takes in: what the dialog says, and the button that hands them over.
-- `needs` is the ns function the hand-off calls, missing while its `module` is switched off.
local HANDOFFS = {
    { prefix = PACK_PREFIX, button = "Open Pack Import",
      what = "This is a Smart Reminders pack. The pack import takes it in, with its specs and licence.",
      go = function(text) ns.ShowPackImport(text) end },
    { prefix = "!NFM1!", button = "Add Macros", module = "Macros", needs = "ImportMacroString",
      what = "These are Forge macros. They are added as character macros on this character.",
      go = function(text) ns.ImportMacroString(text) end },
    { prefix = "!NFB1!", button = "Add Build", module = "Training Planner", needs = "Training",
      what = "This is a talent build. It is added to your builds in the Training Planner.",
      go = function(text) ns.Training.ImportBuild(text, function() end) end },
    { prefix = "!NBIS1!", button = "Add BiS List", module = "BiS List", needs = "ImportBisList",
      what = "This is a BiS list. It is added next to your own lists.",
      go = function(text) ns.ImportBisList(text) end },
}

local export

-- The string for the parts ticked in wanted (nil for all), ready to copy.
function ns.ShowProfileExport(wanted)
    if not export then
        local dimmer, panel = ns.MakeModal(EXPORT_W, EXPORT_H, "profileExport")
        local title = ns.Font(panel, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -PAD)
        title:SetText("Export Profile")
        local what = UI.KeepFont(panel, "what", 11, nil, ns.THEME.muted)
        what:SetPoint("TOPLEFT", PAD, -40)
        what:SetPoint("RIGHT", -PAD, 0)
        what:SetJustifyH("LEFT")
        local box = ns.MakeMultilineBox(panel, -62, BOX_H)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        -- The text is the export: typing in it is undone.
        box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(export.text or "") end end)
        local status = UI.KeepFont(panel, "status", 11, nil, ns.THEME.fg)
        status:SetPoint("TOPLEFT", PAD, -(62 + BOX_H + 12))
        status:SetPoint("RIGHT", -PAD, 0)
        status:SetJustifyH("LEFT")
        local close = ns.Button(panel, "Close", BUTTON_W, BUTTON_H, function() dimmer:Hide() end)
        close:SetPoint("BOTTOM", 0, PAD)
        export = { dimmer = dimmer, box = box, what = what, status = status }
    end
    local labels = {}
    for _, part in ipairs(PARTS) do
        if not wanted or wanted[part.key] then labels[#labels + 1] = part.label end
    end
    export.what:SetText(("Profile: %s. %s."):format(ns.ActiveProfileName() or "?", table.concat(labels, ", ")))
    local text, note = ns.ExportProfile(wanted)
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
        if import.handoff.needs and not ns[import.handoff.needs] then
            import.preview:SetText(("Turn on %s under Settings > Modules to add this."):format(import.handoff.module))
            import.go:Hide()
            return
        end
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
        local row = import.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, import.panel)
            row:SetHeight(ROW_H)
            row.toggle = UI.BuildToggleControl(row, nil, function() return import.wanted[row.key] end,
                function(on) import.wanted[row.key] = on == true end, TOGGLE_W, TOGGLE_H)
            row.toggle:SetPoint("LEFT", 0, 0)
            row.label = UI.KeepFont(row, "label", 12, nil, ns.THEME.fg)
            row.label:SetPoint("LEFT", row.toggle, "RIGHT", 10, 0)
            row.help = UI.KeepFont(row, "help", 11, nil, ns.THEME.muted)
            row.help:SetPoint("LEFT", row.label, "RIGHT", 10, 0)
            import.rows[i] = row
        end
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

-- text: what was pasted on the Profiles page, to carry on with here.
function ns.ShowProfileImport(text)
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
    import.box:SetText(text or "")
    wipe(import.wanted)
    PaintImport()
    import.dimmer:Show()
    import.box:SetFocus()
end

-------------------------------------------------------------------------------
--  The Profiles page: your profiles as a list, the parts to share as chips, and a paste box
-------------------------------------------------------------------------------
local PROFILE_H, MARK_W, MARK_INSET, TEXT_X = 40, 2, 6, 12   -- a profile's row; the accent bar on the one in use
local LINK_GAP = 14           -- between a row's links
local SHOWN_CHARS = 3         -- characters named under a profile before "+N"
local CHIP_H, CHIP_GAP, CHIP_PAD, CHIP_TICK, CHIP_SPACE = 26, 6, 10, 10, 6
local SEND_H, SEND_W = 44, 150
local FIELD_H, FIELD_BAR = 44, 22   -- the paste box, and room right of it for its scroll bar
local HINT_X, HINT_Y = 6, -6
local SECTION_GAP = 14

-- Picks on the share, by part key: false when left out, so every part starts in.
local wanted = {}

local function Ticked(key)
    return wanted[key] ~= false
end

local function Done(ok, err)
    if not ok and err then ns.Print(err) end
    UI:RefreshPage(true)
end

local function NewProfile()
    ns.PromptText("New Profile", "", 40, function(text)
        local name = strtrim(text)
        local function Make(overwrite)
            local ok, err = ns.CreateProfile(name, overwrite)
            if ok then ns.SwitchProfile(name) end
            Done(ok, err)
        end
        if not ns.ProfileExists(name) then return Make(false) end
        ns.Confirm(("Replace %s with a profile at default settings? Cannot be undone."):format(name),
            function() Make(true) end, nil, "Replace")
    end)
end

local function CopyNamed(from)
    ns.PromptText("Copy " .. from, "", 40, function(text)
        local name = strtrim(text)
        local function Make(overwrite)
            local ok, err = ns.CopyProfile(from, name, overwrite)
            if ok then ns.SwitchProfile(name) end
            Done(ok, err)
        end
        if not ns.ProfileExists(name) then return Make(false) end
        ns.Confirm(("Overwrite %s with a copy of %s? Cannot be undone."):format(name, from),
            function() Make(true) end, nil, "Overwrite")
    end)
end

-- Only the profile in use: ResetProfileNamed clears just Smart Reminders on any other.
local function ResetActive(name)
    ns.Confirm(("Reset %s to default settings? Cannot be undone."):format(name),
        function() Done(ns.ResetProfileNamed(name)) end, nil, "Reset")
end

local function DeleteNamed(name)
    ns.Confirm(("Delete %s? Characters using it move to the account's default profile."):format(name),
        function() Done(ns.DeleteProfile(name)) end, nil, "Delete")
end

-- A profile row's links, right to left as listed last to first.
local ROW_LINKS = {
    { key = "use", text = "Use", action = function(name) Done(ns.SwitchProfile(name)) end },
    { key = "copy", text = "Copy", action = CopyNamed },
    { key = "reset", text = "Reset", action = ResetActive },
    { key = "delete", text = "Delete", action = DeleteNamed },
}

-- Who else is on each profile, by name without the realm.
local function Characters()
    local me = UnitName("player") .. "-" .. GetRealmName()
    local by = {}
    for _, known in ipairs(ns.KnownCharacters()) do
        if known.char ~= me then
            local list = by[known.profile] or {}
            by[known.profile] = list
            list[#list + 1] = known.char:match("^[^-]+")
        end
    end
    return by
end

local function WhoUses(names, active)
    local shown = {}
    for i = 1, math.min(#names, SHOWN_CHARS) do shown[i] = names[i] end
    local list = table.concat(shown, ", ")
    if #names > SHOWN_CHARS then list = ("%s +%d"):format(list, #names - SHOWN_CHARS) end
    if active then
        return list == "" and "In use on this character" or "In use here, and on " .. list
    end
    return list == "" and "Not in use" or "On " .. list
end

local function RowEnter(row)
    row.hover:Show()
end

local function RowLeave(row)
    if not row:IsMouseOver() then row.hover:Hide() end
end

local function RowLinkClicked(link)
    if link.disabled then return end
    link.action(link:GetParent().profile)
end

local function RowLinkLeft(link)
    RowLeave(link:GetParent())
end

local function NewProfileRow(view)
    local T = ns.THEME
    local Parts = ns.Shared.Parts
    local row = CreateFrame("Frame", nil, view)
    Parts.RowBands(row, 0)
    row.mark = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.mark:SetPoint("TOPLEFT", 0, -MARK_INSET)
    row.mark:SetPoint("BOTTOMLEFT", 0, MARK_INSET)
    row.mark:SetWidth(MARK_W)
    row.title = ns.Font(row, 13, nil, T.fg)
    row.title:SetPoint("BOTTOMLEFT", row, "LEFT", TEXT_X, 1)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.line = ns.Font(row, 11, nil, T.muted)
    row.line:SetPoint("TOPLEFT", row, "LEFT", TEXT_X, -3)
    row.line:SetJustifyH("LEFT")
    row.line:SetWordWrap(false)
    row.links = {}
    for i, def in ipairs(ROW_LINKS) do
        local link = Parts.Link(row, RowLinkClicked)
        Parts.SetLink(link, def.text)
        link.key, link.action = def.key, def.action
        link:HookScript("OnLeave", RowLinkLeft)
        row.links[i] = link
    end
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function SetProfileRow(row, name, active, line, alone, striped)
    local T = ns.THEME
    row.profile = name
    row.mark:SetShown(active)
    row.stripe:SetShown(striped)
    row.hover:Hide()
    local c = active and T.accent or T.fg
    row.title:SetTextColor(c.r, c.g, c.b, 1)
    row.title:SetText(name)
    row.line:SetText(line)
    local x = 0
    for i = #row.links, 1, -1 do
        local link = row.links[i]
        local show = not (link.key == "use" and active) and not (link.key == "reset" and not active)
        link:SetShown(show)
        if show then
            local off = link.key == "delete" and alone
            link.disabled, link.tip = off, off and "The last profile cannot be deleted." or nil
            ns.Shared.Parts.LinkColor(link, off and T.muted or T.accentSoft)
            link:ClearAllPoints()
            link:SetPoint("RIGHT", -x, 0)
            x = x + link:GetWidth() + LINK_GAP
        end
    end
    row.title:SetPoint("RIGHT", -x, 0)
    row.line:SetPoint("RIGHT", -x, 0)
    return PROFILE_H
end

local function PickAll(view)
    local all = true
    for _, part in ipairs(PARTS) do
        if view.status[part.key] == "ready" and not Ticked(part.key) then all = false end
    end
    for _, part in ipairs(PARTS) do wanted[part.key] = not all end
    view:Redraw()
end

local function ChipClicked(chip)
    if not chip.ready then return end
    wanted[chip.key] = not Ticked(chip.key)
    chip:GetParent():GetParent():Redraw()
end

local function ChipEnter(chip)
    local T = ns.THEME
    if chip.ready then chip.edge:SetColor(T.accent.r, T.accent.g, T.accent.b, 1) end
    if not ns.Shared.Parts.Tip(chip, "ANCHOR_TOP") then return end
    GameTooltip:SetText(chip.label:GetText(), 1, 1, 1)
    GameTooltip:AddLine(chip.tip, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function ChipLeave(chip)
    local c = chip.rest
    chip.edge:SetColor(c.r, c.g, c.b, 1)
    GameTooltip:Hide()
end

local function Chip(row, i)
    local chip = row.chips[i]
    if chip then return chip end
    local T = ns.THEME
    chip = CreateFrame("Button", nil, row)
    chip:SetHeight(CHIP_H)
    ns.Solid(chip, "BACKGROUND", T.panel, 1):SetAllPoints()
    chip.edge = ns.Border(chip, ns.Shared.Style.BORDER_RGB)
    chip.tick = chip:CreateTexture(nil, "ARTWORK")
    chip.tick:SetSize(CHIP_TICK, CHIP_TICK)
    chip.tick:SetPoint("LEFT", CHIP_PAD, 0)
    chip.tick:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, 1)
    ns.Shared.Parts.Smooth(chip.tick, ns.Shared.Style.TICK)
    chip.label = ns.Font(chip, 12, nil, T.fg)
    chip.label:SetPoint("LEFT", chip.tick, "RIGHT", CHIP_SPACE, 0)
    chip.detail = ns.Font(chip, 11, nil, T.muted)
    chip.detail:SetPoint("LEFT", chip.label, "RIGHT", CHIP_SPACE, 0)
    chip:SetScript("OnClick", ChipClicked)
    chip:SetScript("OnEnter", ChipEnter)
    chip:SetScript("OnLeave", ChipLeave)
    row.chips[i] = chip
    return chip
end

local function NewChips(view)
    local row = CreateFrame("Frame", nil, view)
    row.chips = {}
    return row
end

-- A chip per part: ticked and edged in the accent while it goes in, muted while left out,
-- greyed with why when the profile has none of it.
local function SetChips(row, status, details)
    local T, St = ns.THEME, ns.Shared.Style
    local width = row:GetWidth()
    local x, y = 0, 0
    for i, part in ipairs(PARTS) do
        local chip = Chip(row, i)
        local state = status[part.key]
        local on = state == "ready" and Ticked(part.key)
        chip.key, chip.ready = part.key, state == "ready"
        chip.rest = on and T.accent or St.BORDER_RGB
        chip.edge:SetColor(chip.rest.r, chip.rest.g, chip.rest.b, 1)
        chip.tick:SetShown(on)
        local c = on and T.fg or T.muted
        chip.label:SetTextColor(c.r, c.g, c.b, 1)
        chip.label:SetText(part.label)
        local detail = state == "pack" and "from a pack" or state == "empty" and "none" or details[part.key]
        c = state == "pack" and St.WARN_RGB or T.muted
        chip.detail:SetTextColor(c.r, c.g, c.b, 1)
        chip.detail:SetText(detail or "")
        chip.tip = state == "pack" and "Came with a pack, so it stays with the pack's author." or part.share
        local w = CHIP_PAD + CHIP_TICK + CHIP_SPACE + math.ceil(chip.label:GetStringWidth()) + CHIP_PAD
        if detail then w = w + CHIP_SPACE + math.ceil(chip.detail:GetStringWidth()) end
        if x > 0 and x + w > width then
            x, y = 0, y + CHIP_H + CHIP_GAP
        end
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", x, -y)
        chip:Show()
        x = x + w + CHIP_GAP
    end
    return y + CHIP_H + CHIP_GAP
end

local function NewSend(view)
    local row = CreateFrame("Frame", nil, view)
    row.count = ns.Font(row, 12, nil, ns.THEME.muted)
    row.count:SetPoint("LEFT")
    row.send = ns.AccentBorder(ns.Button(row, "Get Share String", SEND_W, CHIP_H, function()
        local ticks = {}
        for _, part in ipairs(PARTS) do ticks[part.key] = Ticked(part.key) or nil end
        ns.ShowProfileExport(ticks)
    end))
    row.send:SetPoint("RIGHT")
    return row
end

local function SetSend(row, count, ready)
    row.count:SetText(count > 0 and ("%d of %d parts of %s go in the string."):format(count, ready,
        ns.ActiveProfileName() or "?") or "Pick a part to share.")
    return SEND_H
end

-- Anything pasted or typed here carries on in the import, which previews it first.
local function Pasted(box, user)
    local text = box:GetText()
    box.hint:SetShown(text == "")
    if not user or not text:find("%S") then return end
    box:SetText("")
    box:ClearFocus()
    ns.ShowProfileImport(text)
end

local function NewPaste(view)
    local row = CreateFrame("Frame", nil, view)
    local box = ns.MakeMultilineBox(row, 0, FIELD_H)
    local field = box:GetParent()
    field:ClearAllPoints()
    field:SetPoint("TOPLEFT")
    field:SetPoint("TOPRIGHT", -FIELD_BAR, 0)
    box.hint = ns.Font(field, 12, nil, ns.THEME.muted)
    box.hint:SetPoint("TOPLEFT", HINT_X, HINT_Y)
    box.hint:SetText("Paste a profile, macro, talent build or BiS list string here.")
    box:SetScript("OnTextChanged", Pasted)
    return row
end

local function SetPaste()
    return FIELD_H + CHIP_GAP
end

local kinds
local Draw = {}

function Draw:Redraw()
    self:Clear()
    local order, by = ns.ListProfiles(), Characters()
    local active = ns.ActiveProfileName()
    self:Add("section", "Your Profiles", #order, nil, nil, "New Profile", NewProfile)
    for i, name in ipairs(order) do
        self:Add("profile", name, name == active, WhoUses(by[name] or {}, name == active), #order == 1, i % 2 == 0)
    end
    self:Space(SECTION_GAP)

    local count, ready = 0, 0
    for _, part in ipairs(PARTS) do
        if self.status[part.key] == "ready" then
            ready = ready + 1
            if Ticked(part.key) then count = count + 1 end
        end
    end
    self:Add("section", "Share", nil, nil, nil, count < ready and "Pick All" or "Pick None", PickAll, self)
    self:Space(ns.Shared.Style.SECTION_SPACE)
    self:Add("chips", self.status, self.details)
    self:Add("send", count, ready)
    self:Space(SECTION_GAP)

    self:Add("section", "Import")
    self:Space(ns.Shared.Style.SECTION_SPACE)
    self:Add("paste")
    self:Fit({})
end

local function Kinds()
    if kinds then return kinds end
    kinds = ns.Shared.View.NewKinds()
    kinds.profile = { New = NewProfileRow, Set = SetProfileRow }
    kinds.chips = { New = NewChips, Set = SetChips }
    kinds.send = { New = NewSend, Set = SetSend }
    kinds.paste = { New = NewPaste, Set = SetPaste }
    return kinds
end

function ns.BuildProfileSettings(parent, y)
    local view = parent.profilesView
    if not view then
        view = ns.Shared.View.New(parent, Kinds(), Draw)
        parent.profilesView = view
    end
    local all = Collect()
    local sr = ns.SettingsRoot().tankReminder
    local packed = type(sr) == "table" and type(sr.importedPack) == "table"
    view.status, view.details = {}, {}
    for _, part in ipairs(PARTS) do
        view.status[part.key] = all[part.key] and "ready"
            or packed and part.key == "smartReminders" and "pack" or "empty"
    end
    for _, part in ipairs(ns.ProfileStringParts({ parts = all })) do view.details[part.key] = part.detail end
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.CONTENT_PAD, y - UI.CONTENT_PAD / 2)
    view:SetWidth(math.max(1, parent:GetWidth() - UI.CONTENT_PAD * 2))
    view:Show()
    view:Redraw()
    return y - view:GetHeight() - UI.CONTENT_PAD
end
