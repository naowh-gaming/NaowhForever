-- NaowhForever_Packs.lua: shareable Reminder Packs, their export, decoding, validation and import.
local ns = _G.NaowhForever
if not ns then return end

local PREFIX = "NSRPACK2:"
local PACK_FORMAT = 1
local LICENSE_MARKER = ":LIC1:"
local MAX_PACK_CHARS = 1000000
local LIMITS = { maxChars = MAX_PACK_CHARS, maxBytes = 4194304, maxDepth = 40, maxValues = 1000000 }
local TEXT_MAX = 64
local MAX_DEPTH = 32
local VALUE_BUDGET = 100000
local MAX_IMPORTED_RULES = 500
local MAX_CONSUMABLES = 500
local MAX_CLASS_MACROS = 100
local MACRO_NAME_MAX, MACRO_BODY_MAX, MACRO_NOTE_MAX = 16, 255, 200
local MAX_ID = 2147483647
local DEFAULT_PROFILE = "Default"
local SECTIONS = {
    { field = "utilityReminders", label = "consumable and class macro groups", count = "keys", value = "table" },
    { field = "presets",         label = "spec priority lists",  count = "nested" },
    { field = "activePreset",    label = "active preset choice", count = "keys", value = "string" },
    { field = "bossLists",       label = "per-boss orders",      count = "keys", value = "table" },
    { field = "callouts",        label = "callout lines",        count = "keys", value = "string" },
    { field = "customReminders", label = "custom reminders",     count = "nested", perEntry = true },
    { field = "abilityBindings", label = "ability on/off",       count = "nested" },
    { field = "audioOff",        label = "audio switches",       count = "keys", value = "boolean" },
    { field = "raidReminders",   label = "raid reminders",       count = "nested", perEntry = true },
    { field = "integrationRules", label = "trash and debuff rules", count = "nested", perEntry = true },
}
local ENTRY_TABLES = { "trigger", "display", "target", "list", "together" }
local TARGET_FLAGS = { "roles", "classes", "specs", "names", "subgroups" }
local SPEC_FIELDS = { "presets", "activePreset", "abilityBindings" }
local CONSUMABLE_CATEGORIES = { food = true, flask = true, scroll = true, battle = true, guardian = true }
local COLOR_FIELDS = { r = "number", g = "number", b = "number", a = "number" }
local TRIGGER_FIELDS = { type = "string", spellID = "number", delay = "number|string",
    stage = "number", leadTime = "number", timeleft = "number", counter = "string|number",
    target = "string", auraEvent = "string", mapID = "number" }
local DISPLAY_FIELDS = { type = "string", text = "string", spellID = "number", dur = "number",
    sound = "string", tts = "boolean", glowTarget = "string", hideAfterCastID = "number" }
local ENTRY_FIELDS = { name = "string", enabled = "boolean", specID = "number", healerReminder = "boolean",
    preset = "string", mode = "string", defensive = "boolean", dur = "number",
    text = "string", sound = "string", abilitySpellID = "number" }
local TARGET_FIELDS = { all = "boolean", kind = "string", value = "string|number" }
local POS_FIELDS = { point = "string", relPoint = "string", x = "number", y = "number" }
local MERGE_WHOLE_SPEC = { presets = true, activePreset = true,
    abilityBindings = true, integrationRules = true }
local MERGE_NO_SPEC = { utilityReminders = true, raidReminders = true, callouts = true, audioOff = true }
local PROFILE_PARTS = { settings = true, macros = true, library = true, smartReminders = true,
    builds = true, bisLists = true, look = true }
local DEFAULT_PACK_NAME = "Reminder Pack"
local IMPORTED_PROFILE = "Imported Profile"
local UNKNOWN_AUTHOR = "unknown"
local SOME_PACK, SOME_CURATOR = "a pack", "its curator"
local COLOR_ERROR, COLOR_BUILT_ON = "|cffff6060", "|cffF0A830"
local TEXT_NO_LIBRARIES = "The serializer libraries are missing from this build."
local TEXT_NOTHING_TO_READ = "Nothing to read."
local TEXT_UNREADABLE = "the string could not be read"
local TEXT_LICENSED = "This profile came from %s, which is licensed to the account that downloaded it. "
    .. "It cannot be exported. Get your own copy from naowh.gg."
local TEXT_IMPORTED = "This profile contains an imported pack (%s by %s), so it cannot be shared onward. "
    .. "Build your own profile to share one."
local TEXT_NOTHING_TO_EXPORT = "There is nothing to export yet."
local TEXT_NOT_SERIALIZED = "The pack could not be serialized."
local TEXT_TOO_LARGE = "That string is too large to be a Reminder Pack."
local TEXT_NO_PREFIX = "Not a Reminder Pack string (missing the %s prefix)."
local TEXT_DAMAGED = "The string is damaged (contents)."
local TEXT_DAMAGED_NAME = "The string is damaged (profile name)."
local TEXT_NEWER = "This pack needs a newer version of the addon."
local TEXT_EMPTY = "The pack is empty."
local TEXT_ONLY_DEFAULT = "This pack carries only a profile named Default, which is never landed -- every "
    .. "account already has its own."
local TEXT_BUILT_ON = COLOR_BUILT_ON .. "Built on|r %s by %s."
local TEXT_WILL_CREATE = "Will create %d new profile%s:"
local TEXT_OWN_UNCHANGED = "Your own existing profiles are not changed."
local TEXT_WITH_SETTINGS = "Includes display, sound and behaviour settings, which will be applied."
local TEXT_BINDS_SPECS = "Each profile is bound to the specs it covers, and spec-matching is switched on: "
    .. "changing spec, on ANY character, auto-loads the matching one."
local TEXT_SWITCH_ALL = COLOR_ERROR .. "Every character on this account will be switched to '%s'|r, including "
    .. "any not yet listed below."
local TEXT_WAS = "%s (was %s)"
local TEXT_KNOWN = "  Known characters: "
local TEXT_NOT_CARRIED = COLOR_ERROR .. "'%s' is not one of the profiles this pack carries -- the account "
    .. "switch would fail.|r"
local TEXT_NOT_APPLIED = "the pack could not be applied"
local TEXT_NOT_IN_PACK = "imported, but %s is not a profile in this pack (%s)"
local TEXT_IMPORT_FAILED = "Naowh Forever import failed: "
local TEXT_SPEC_SWITCH_OFF = "Per-spec profile switching is off while every character shares '%s'; your spec "
    .. "choices are kept if you switch it back on."
local TEXT_NOTHING_THERE = "there is nothing to read"
local TEXT_PROFILE_MISSING = "that profile is not in this string"
local TEXT_NO_PROFILE = "the string does not carry a profile"
local TEXT_CHOOSE_TARGET = "choose the profile to merge into"
local TEXT_TARGET_GONE = "that profile no longer exists"
local TEXT_CHOOSE_SPEC = "choose at least one spec"
local TEXT_CANNOT_OPEN = "that profile could not be opened"

local function ByLower(a, b) return a:lower() < b:lower() end
local function ByName(a, b) return a.name < b.name end

local function CountSection(kind, t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    if kind == "nested" then
        for _, inner in pairs(t) do
            if type(inner) == "table" then
                for _ in pairs(inner) do n = n + 1 end
            end
        end
    else
        for _ in pairs(t) do n = n + 1 end
    end
    return n
end

local function PlainData(value, seen, depth, budget)
    local kind = type(value)
    if kind == "number" then return value == value and math.abs(value) < math.huge end
    if kind ~= "table" then return kind == "string" or kind == "boolean" or kind == "nil" end
    if seen[value] or depth > MAX_DEPTH then return false end
    seen[value] = true
    for k, v in pairs(value) do
        budget[1] = budget[1] - 1
        if budget[1] < 0 or (type(k) ~= "string" and type(k) ~= "number")
            or not PlainData(k, seen, depth + 1, budget)
            or not PlainData(v, seen, depth + 1, budget) then return false end
    end
    seen[value] = nil
    return true
end

local function Fields(t, schema)
    if type(t) ~= "table" then return false end
    for key, kinds in pairs(schema) do
        local v = t[key]
        if v ~= nil and not ("|" .. kinds .. "|"):find("|" .. type(v) .. "|", 1, true) then
            return false
        end
    end
    return true
end

local function FlagMap(t)
    if t == nil then return true end
    if type(t) ~= "table" then return false end
    for _, flag in pairs(t) do if type(flag) ~= "boolean" then return false end end
    return true
end

local function SpellList(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for index, sid in pairs(t) do
        if type(index) ~= "number" or index < 1 or index % 1 ~= 0
            or type(sid) ~= "number" or sid <= 0 or sid % 1 ~= 0 then return false end
        count = count + 1
    end
    for i = 1, count do if t[i] == nil then return false end end
    return true
end

local function ValidTarget(target)
    if not Fields(target, TARGET_FIELDS) then return false end
    for _, key in ipairs(TARGET_FLAGS) do
        if not FlagMap(target[key]) then return false end
    end
    return not (target.kind and target.kind ~= "all" and target.value == nil)
end

local function ValidEntry(entry)
    if not Fields(entry, ENTRY_FIELDS) then return false end
    for j = 1, #ENTRY_TABLES do
        local v = entry[ENTRY_TABLES[j]]
        if v ~= nil and type(v) ~= "table" then return false end
    end
    if entry.list and not SpellList(entry.list) then return false end
    if not FlagMap(entry.together) then return false end
    if entry.trigger and not Fields(entry.trigger, TRIGGER_FIELDS) then return false end
    local display = entry.display
    if display and (not Fields(display, DISPLAY_FIELDS)
        or (display.color and not Fields(display.color, COLOR_FIELDS))) then return false end
    if entry.color and not Fields(entry.color, COLOR_FIELDS) then return false end
    if entry.target then return ValidTarget(entry.target) end
    return true
end

local function PositiveID(id)
    return type(id) == "number" and id >= 1 and id <= MAX_ID and id == math.floor(id)
end

local function ValidConsumables(consumables)
    if type(consumables) ~= "table" then return false end
    local count = 0
    for index, entry in pairs(consumables) do
        count = count + 1
        if not PositiveID(index) or index > #consumables or count > MAX_CONSUMABLES
            or type(entry) ~= "table" or not CONSUMABLE_CATEGORIES[entry.category]
            or not PositiveID(entry.itemID) or type(entry.auras) ~= "table" or #entry.auras == 0 then return false end
        for i, id in pairs(entry.auras) do
            if not PositiveID(i) or i > #entry.auras or not PositiveID(id) then return false end
        end
    end
    return true
end

local function ValidMacro(i, entry, entries)
    return PositiveID(i) and i <= #entries and #entries <= MAX_CLASS_MACROS and type(entry) == "table"
        and type(entry.name) == "string" and #entry.name >= 1 and #entry.name <= MACRO_NAME_MAX
        and type(entry.body) == "string" and #entry.body >= 1 and #entry.body <= MACRO_BODY_MAX
        and (entry.icon == nil or PositiveID(entry.icon))
        and (entry.note == nil or (type(entry.note) == "string" and #entry.note <= MACRO_NOTE_MAX))
end

local function ValidClassMacros(classMacros)
    if type(classMacros) ~= "table" then return false end
    for class, entries in pairs(classMacros) do
        if type(class) ~= "string" or type(entries) ~= "table" then return false end
        for i, entry in pairs(entries) do
            if not ValidMacro(i, entry, entries) then return false end
        end
    end
    return true
end

local function ValidUtilities(data)
    if type(data) ~= "table" then return false end
    if data.consumables ~= nil and not ValidConsumables(data.consumables) then return false end
    if data.classMacros ~= nil and not ValidClassMacros(data.classMacros) then return false end
    return true
end

local function ValidRuleKeys(inner)
    local count = 0
    for uid in pairs(inner) do
        count = count + 1
        if type(uid) ~= "string" or count > MAX_IMPORTED_RULES then return false end
    end
    return true
end

local function ValidRule(entry)
    if ns.Integrations then return ns.Integrations.ValidRule(entry) end
    return ValidEntry(entry) and type(entry.trigger) == "table" and type(entry.display) == "table"
end

local function ValidSectionEntry(sec, entry, data)
    if type(entry) ~= "table" then return false end
    if sec.field == "abilityBindings" and data.bindingsBySpec ~= false then
        for _, binding in pairs(entry) do
            if not ValidEntry(binding) then return false end
        end
        return true
    end
    if sec.field == "integrationRules" then return ValidRule(entry) end
    return ValidEntry(entry)
end

local function ValidInner(sec, inner, data)
    if sec.value then
        if type(inner) ~= sec.value then return false end
        return not (sec.field == "bossLists" and not SpellList(inner))
    end
    if type(inner) ~= "table" then return false end
    if sec.field == "integrationRules" and not ValidRuleKeys(inner) then return false end
    for _, entry in pairs(inner) do
        if not ValidSectionEntry(sec, entry, data) then return false end
    end
    return true
end

local function ValidSection(sec, t, data)
    if t == nil then return true end
    if type(t) ~= "table" then return false end
    for _, inner in pairs(t) do
        if not ValidInner(sec, inner, data) then return false end
    end
    return true
end

local function ValidData(data)
    if not PlainData(data, {}, 0, { VALUE_BUDGET }) then return false end
    if data.utilityReminders ~= nil and not ValidUtilities(data.utilityReminders) then return false end
    for i = 1, #SECTIONS do
        local sec = SECTIONS[i]
        if not ValidSection(sec, data[sec.field], data) then return false end
    end
    if data.modules ~= nil and type(data.modules) ~= "table" then return false end
    if data.settings ~= nil then
        if type(data.settings) ~= "table" then return false end
        if data.settings.pos and not Fields(data.settings.pos, POS_FIELDS) then return false end
    end
    return true
end

local function Codec()
    local LS = LibStub and LibStub("LibSerialize", true)
    local LD = LibStub and LibStub("LibDeflate", true)
    if not (LS and LD) then return nil end
    local Ser = {
        Serialize = function(v) return LS:Serialize(v) end,
        Deserialize = function(s)
            local ok, v = LS:Deserialize(s)
            if not ok then error(v, 0) end
            return v
        end,
    }
    return Ser, LD
end

ns.ValidPackData = ValidData

local function Copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = Copy(val) end
    return out
end

local function ImportedFrom(payload, licensed)
    return {
        name = tostring(payload.name or SOME_PACK),
        author = tostring(payload.author or SOME_CURATOR),
        licensed = licensed,
    }
end

local function ApplySettings(tr, settings)
    for k, v in pairs(settings) do
        if k == "pos" then
            if type(v) == "table" then tr.pos = Copy(v) end
        elseif type(v) == type(ns.SettingDefault(k)) then
            tr[k] = v
        end
    end
end

local function ApplyModuleSettings(name, data)
    if ns.ImportModuleSettings then ns.ImportModuleSettings(ns.ProfileRoot(name), data.modules) end
end

local function ScalarSettings(tr)
    local settings = {}
    local keys = ns.SettingKeys and ns.SettingKeys() or {}
    for i = 1, #keys do
        local v = tr[keys[i]]
        local vt = type(v)
        if vt == "number" or vt == "string" or vt == "boolean" then settings[keys[i]] = v end
    end
    if type(tr.pos) == "table" then settings.pos = Copy(tr.pos) end
    return settings
end

local function DataFromProfile(tr)
    local data, any = {}, false
    for i = 1, #SECTIONS do
        local sec = SECTIONS[i]
        local t = tr[sec.field]
        if type(t) == "table" and next(t) ~= nil then
            data[sec.field] = Copy(t)
            any = true
        end
    end
    data.leadTime = tr.leadTime
    data.voiceNone = tr.voiceNone
    data.bindingsBySpec = tr.bindingsBySpec == true
    local settings = ScalarSettings(tr)
    if next(settings) ~= nil then data.settings = settings end
    return data, any
end

local function ExportBlocked(db, allowImported)
    local pack = db.importedPack
    if type(pack) ~= "table" then return nil end
    if pack.licensed then return TEXT_LICENSED:format(pack.name) end
    if not allowImported then return TEXT_IMPORTED:format(pack.name, pack.author) end
end

local function Given(text, fallback)
    return (text and text ~= "") and text or fallback
end

function ns.ExportPack(packName, author, allowImported)
    local Ser, LD = Codec()
    if not Ser then return nil, TEXT_NO_LIBRARIES end

    local db = ns.DB()
    local blocked = ExportBlocked(db, allowImported)
    if blocked then return nil, blocked end
    local derivedFrom
    if type(db.importedPack) == "table" then
        derivedFrom = { name = tostring(db.importedPack.name),
            author = tostring(db.importedPack.author) }
    end
    local data, any = DataFromProfile(db)
    data.modules = ns.ExportModuleSettings and ns.ExportModuleSettings(ns.SettingsRoot())
    if data.modules then any = true end
    if not any then return nil, TEXT_NOTHING_TO_EXPORT end

    local payload = {
        format  = PACK_FORMAT,
        name    = Given(packName, DEFAULT_PACK_NAME),
        author  = Given(author, nil) or (UnitName and UnitName("player")) or UNKNOWN_AUTHOR,
        made    = date and date("%Y-%m-%d") or "",
        derivedFrom = derivedFrom,
        data    = data,
    }
    local ok, serialized = pcall(Ser.Serialize, payload)
    if not ok then return nil, TEXT_NOT_SERIALIZED end
    local compressed = LD:CompressDeflate(serialized)
    return PREFIX .. LD:EncodeForPrint(compressed)
end

local function SpecNames(specs)
    local names = {}
    for j = 1, #specs do names[j] = specs[j].name end
    return names
end

local function LandedNames(profiles)
    local names = {}
    for name in pairs(profiles) do
        if name ~= DEFAULT_PROFILE then names[#names + 1] = name end
    end
    table.sort(names, ByLower)
    return names
end

local function PackProfiles(payload, multi)
    if not multi then
        return { { name = Given(payload.name, DEFAULT_PACK_NAME), specs = SpecNames(ns.PackSpecs(payload)) } }
    end
    local profiles = {}
    for _, name in ipairs(LandedNames(payload.profiles)) do
        profiles[#profiles + 1] = { name = name, specs = SpecNames(ns.PackSpecs({ data = payload.profiles[name] })) }
    end
    return profiles
end

local function CarriesProfile(profiles, name)
    if not name then return nil end
    for i = 1, #profiles do
        if profiles[i].name == name then return true end
    end
    return false
end

local function AccountLines(lines, account, accountProfileOK, movedChars)
    if not accountProfileOK then
        lines[#lines + 1] = TEXT_NOT_CARRIED:format(tostring(account))
        return
    end
    lines[#lines + 1] = TEXT_SWITCH_ALL:format(account)
    if #movedChars == 0 then return end
    local names = {}
    for i = 1, #movedChars do
        names[i] = TEXT_WAS:format(movedChars[i].char, movedChars[i].profile)
    end
    lines[#lines + 1] = TEXT_KNOWN .. table.concat(names, ", ")
end

local function DescribeLines(payload, profiles, info, opts)
    local lines = {}
    lines[#lines + 1] = (ns.Color("accent", "%s") .. " by %s"):format(
        tostring(payload.name), tostring(payload.author))
    if type(payload.derivedFrom) == "table" then
        lines[#lines + 1] = TEXT_BUILT_ON:format(
            tostring(payload.derivedFrom.name), tostring(payload.derivedFrom.author))
    end
    lines[#lines + 1] = TEXT_WILL_CREATE:format(#profiles, #profiles == 1 and "" or "s")
    for i = 1, #profiles do
        local p = profiles[i]
        local specText = #p.specs > 0 and (" -- " .. table.concat(p.specs, ", ")) or ""
        lines[#lines + 1] = ("  " .. ns.Color("accent", "%s") .. "%s"):format(ns.PlainText(p.name), specText)
    end
    lines[#lines + 1] = TEXT_OWN_UNCHANGED
    if info.willApplySettings then lines[#lines + 1] = TEXT_WITH_SETTINGS end
    if info.willBindSpecs then lines[#lines + 1] = TEXT_BINDS_SPECS end
    if opts.accountProfile then
        AccountLines(lines, opts.accountProfile, info.accountProfileOK, info.movedCharacters)
    end
    return lines
end

function ns.DescribeProfilePack(str, opts)
    opts = type(opts) == "table" and opts or {}
    local payload, err = ns.DecodePack(str)
    if not payload then return nil, nil, err or TEXT_UNREADABLE end

    local multi = type(payload.profiles) == "table"
    local profiles = PackProfiles(payload, multi)
    local accountProfileOK = CarriesProfile(profiles, opts.accountProfile)
    local movedChars = (opts.accountProfile and accountProfileOK) and ns.KnownCharacters() or {}

    local info = {
        packName = payload.name, packAuthor = payload.author,
        profiles = profiles,
        willApplySettings = opts.settings ~= false,
        willBindSpecs = multi and opts.bindSpecs ~= false or false,
        accountProfile = opts.accountProfile,
        accountProfileOK = accountProfileOK,
        movedCharacters = movedChars,
    }
    return table.concat(DescribeLines(payload, profiles, info, opts), "|n"), info
end

local function CurrentSpecEntry()
    local spec = ns.CurrentSpec and ns.CurrentSpec()
    if not spec or spec <= 0 then return nil end
    return tostring(spec), ns.SpecProfileMap()[tostring(spec)]
end

local function LandPack(payload, opts, multi)
    local settings = opts.settings ~= false
    if multi then
        local bind = opts.bindSpecs ~= false
        local ok, landed = ns.ApplyProfiles(payload, nil, settings, bind)
        if ok and bind then ns.AutoSpecProfile(true) end
        return ok, landed
    end
    local name = type(opts.profileName) == "string" and opts.profileName or nil
    return ns.ImportPackAsProfile(payload, nil, settings, name, name ~= nil and name:match("%S") ~= nil)
end

function ns.InstallProfilePack(str, opts)
    opts = type(opts) == "table" and opts or {}
    local payload, err = ns.DecodePack(str)
    if not payload then return false, err or TEXT_UNREADABLE end

    local multi = type(payload.profiles) == "table"
    local specKey, specWas = CurrentSpecEntry()
    local ok, landed = LandPack(payload, opts, multi)
    if not ok then return false, TEXT_NOT_APPLIED end

    if opts.accountProfile then
        local set, why = ns.SetAccountProfile(opts.accountProfile)
        if not set then
            return false, TEXT_NOT_IN_PACK:format(tostring(opts.accountProfile), tostring(why))
        end
        if specKey and not multi then ns.SpecProfileMap()[specKey] = specWas end
    end

    if ns.ApplySpecProfile and ns.CurrentSpec then ns.ApplySpecProfile((ns.CurrentSpec())) end
    return true, landed
end

local API = {}
_G.NaowhForever_API = API

local function ImportString(str, profileName)
    local payload, why = ns.DecodeProfile(str)
    if payload then return true, (ns.ImportProfile(payload, PROFILE_PARTS, profileName, true)) end
    if why == "pack" then return ns.InstallProfilePack(str, { profileName = profileName }) end
    return false, why or TEXT_NOTHING_TO_READ
end

function API:ImportProfile(str, profileName)
    local specKey, specWas = CurrentSpecEntry()
    local ok, landed = ImportString(str, profileName)
    if not ok then
        ns.Print(TEXT_IMPORT_FAILED .. tostring(landed))
        return false, landed
    end
    if type(landed) == "string" then
        local set, autoOff = ns.SetAccountProfile(landed)
        if set and specKey then ns.SpecProfileMap()[specKey] = specWas end
        if set and autoOff then ns.Print(TEXT_SPEC_SWITCH_OFF:format(landed)) end
    end
    return true, landed
end

local function SplitLicense(str)
    local licStart = str:find(LICENSE_MARKER, 1, true)
    if not licStart then return str, nil end
    return str:sub(1, licStart - 1), str:sub(licStart + #LICENSE_MARKER)
end

local function CleanText(payload)
    local Text = ns.Shared.Decode.Text
    payload.name, payload.author = Text(payload.name, TEXT_MAX), Text(payload.author, TEXT_MAX)
    payload.made = Text(payload.made, TEXT_MAX)
    if type(payload.derivedFrom) == "table" then
        payload.derivedFrom = { name = Text(payload.derivedFrom.name, TEXT_MAX),
            author = Text(payload.derivedFrom.author, TEXT_MAX) }
    else
        payload.derivedFrom = nil
    end
end

local function CleanProfileNames(payload)
    local Text = ns.Shared.Decode.Text
    local clean = {}
    for name, data in pairs(payload.profiles) do
        local fixed = Text(name, TEXT_MAX)
        if not fixed or fixed == "" or clean[fixed] then return false end
        clean[fixed] = data
    end
    payload.profiles = clean
    return true
end

local function ValidPayloadData(payload, multi)
    for name, data in pairs(multi and payload.profiles or { payload.data }) do
        if multi and (type(name) ~= "string" or name == "") then return nil, TEXT_DAMAGED_NAME end
        if type(data) ~= "table" or not ValidData(data) then return nil, TEXT_DAMAGED end
    end
    return true
end

local function ProfileParts(payload)
    local parts, names = {}, LandedNames(payload.profiles)
    for i = 1, #names do
        local specs = ns.PackSpecs({ data = payload.profiles[names[i]] })
        local specText
        for j = 1, #specs do
            specText = specText and (specText .. ", " .. specs[j].name) or specs[j].name
        end
        parts[#parts + 1] = (ns.Color("accent", "%s") .. "%s"):format(names[i],
            specText and (" -- " .. specText) or "")
    end
    return parts, payload.profiles[DEFAULT_PROFILE] ~= nil
end

local function SectionParts(data)
    local parts = {}
    for i = 1, #SECTIONS do
        local sec = SECTIONS[i]
        local n = CountSection(sec.count, data[sec.field])
        if n > 0 then parts[#parts + 1] = ("%d %s"):format(n, sec.label) end
    end
    return parts, false
end

local function Describe(payload, parts, multi)
    local derived = ""
    if type(payload.derivedFrom) == "table" then
        derived = "|n" .. TEXT_BUILT_ON:format(
            tostring(payload.derivedFrom.name), tostring(payload.derivedFrom.author))
    end
    return (ns.Color("accent", "%s") .. " by %s%s%s|n%s"):format(
        tostring(payload.name), tostring(payload.author),
        type(payload.made) == "string" and payload.made ~= "" and (" (" .. payload.made .. ")") or "",
        derived,
        table.concat(parts, multi and "|n" or ", "))
end

local function ReadPayload(str)
    if #str > MAX_PACK_CHARS then return nil, TEXT_TOO_LARGE end
    local body, license = SplitLicense(str)
    if body:sub(1, #PREFIX) ~= PREFIX then return nil, TEXT_NO_PREFIX:format(PREFIX) end
    local payload = ns.Shared.Decode.String(body:sub(#PREFIX + 1), LIMITS)
    if type(payload) ~= "table" then return nil, TEXT_DAMAGED end
    if payload.format ~= PACK_FORMAT then return nil, TEXT_NEWER end
    payload.licensed = nil
    if license then
        local licOk, licErr = ns.CheckPackLicense(license)
        if not licOk then return nil, licErr end
        payload.licensed = true
    end
    return payload
end

function ns.DecodePack(str)
    if not Codec() then return nil, TEXT_NO_LIBRARIES end
    if type(str) ~= "string" then return nil, TEXT_NOTHING_TO_READ end
    str = str:gsub("%s+", "")
    if str == "" then return nil, TEXT_NOTHING_TO_READ end
    local payload, why = ReadPayload(str)
    if not payload then return nil, why end
    CleanText(payload)
    local multi = type(payload.profiles) == "table" and next(payload.profiles) ~= nil
    if not multi and type(payload.data) ~= "table" then return nil, TEXT_EMPTY end
    if multi and not CleanProfileNames(payload) then return nil, TEXT_DAMAGED_NAME end
    local valid, damaged = ValidPayloadData(payload, multi)
    if not valid then return nil, damaged end

    local parts, refusedDefault
    if multi then
        parts, refusedDefault = ProfileParts(payload)
    else
        parts, refusedDefault = SectionParts(payload.data)
    end
    if #parts == 0 then return nil, refusedDefault and TEXT_ONLY_DEFAULT or TEXT_EMPTY end
    return payload, Describe(payload, parts, multi)
end

function ns.PackSpecs(payload)
    if type(payload) ~= "table" or type(payload.data) ~= "table" then return {} end
    local d, seen = payload.data, {}
    for _, field in ipairs(SPEC_FIELDS) do
        if type(d[field]) == "table" then
            for k in pairs(d[field]) do seen[tostring(k)] = true end
        end
    end
    if type(d.bossLists) == "table" then
        for k in pairs(d.bossLists) do
            local spec = tostring(k):match("^(%d+):")
            if spec then seen[spec] = true end
        end
    end
    local out = {}
    for key in pairs(seen) do
        out[#out + 1] = { key = key, name = ns.SpecName(key) }
    end
    table.sort(out, ByName)
    return out
end

local function FilterToSpecs(field, incoming, wantSpecs)
    if not wantSpecs then return Copy(incoming) end
    local out = {}
    if field == "bossLists" then
        for k, v in pairs(incoming) do
            local spec = tostring(k):match("^(%d+):")
            if spec and wantSpecs[spec] then out[k] = Copy(v) end
        end
    elseif field == "presets" or field == "activePreset" or field == "abilityBindings" then
        for k, v in pairs(incoming) do
            if wantSpecs[tostring(k)] then out[k] = Copy(v) end
        end
    else
        return Copy(incoming)
    end
    return out
end

local function MergeSections(tr, data)
    for i = 1, #SECTIONS do
        local sec = SECTIONS[i]
        local incoming = data[sec.field]
        if type(incoming) == "table" then
            if type(tr[sec.field]) ~= "table" then tr[sec.field] = {} end
            local dst = tr[sec.field]
            for k, v in pairs(incoming) do
                if sec.perEntry and type(dst[k]) == "table" then
                    for uid, r in pairs(v) do dst[k][uid] = Copy(r) end
                else
                    dst[k] = Copy(v)
                end
            end
        end
    end
end

local function BindSpecs(data, name)
    local specs = ns.PackSpecs({ data = data })
    for si = 1, #specs do
        ns.SetSpecProfile(tonumber(specs[si].key), name)
    end
end

local function LandProfile(payload, name, data, isNewProfile, wantSettings, bindSpecs)
    local tr = ns.EnsureProfile and ns.EnsureProfile(name)
    if not tr then return false end
    MergeSections(tr, data)
    if wantSettings and type(data.settings) == "table" then ApplySettings(tr, data.settings) end
    if wantSettings then ApplyModuleSettings(name, data) end
    tr.importedPack = ImportedFrom(payload, payload.licensed or nil)
    if isNewProfile then tr.bindingsBySpec = data.bindingsBySpec ~= false end
    if bindSpecs then BindSpecs(data, name) end
    return true
end

local function ValidProfiles(profiles)
    for name, data in pairs(profiles) do
        if type(name) ~= "string" or name == "" or type(data) ~= "table" or not ValidData(data) then
            return false
        end
    end
    return true
end

local function ExistingProfiles()
    local existing = {}
    local names = ns.ListProfiles and ns.ListProfiles() or {}
    for i = 1, #names do existing[names[i]] = true end
    return existing
end

function ns.ApplyProfiles(payload, wantProfiles, wantSettings, bindSpecs)
    if type(payload) ~= "table" or type(payload.profiles) ~= "table" then return false end
    if not ValidProfiles(payload.profiles) then return false end
    local existing = ExistingProfiles()
    local landed = 0
    for name, data in pairs(payload.profiles) do
        if name ~= DEFAULT_PROFILE and (not wantProfiles or wantProfiles[name]) and type(data) == "table"
            and LandProfile(payload, name, data, not existing[name], wantSettings, bindSpecs) then
            landed = landed + 1
        end
    end
    if landed == 0 then return false end
    if ns.RefreshRuntime then ns.RefreshRuntime() end
    return true, landed
end

local function MergeSource(payload, sourceName)
    if type(payload.profiles) ~= "table" then return payload.data end
    local data = sourceName and payload.profiles[sourceName]
    if type(data) ~= "table" then return nil, TEXT_PROFILE_MISSING end
    return data
end

local function MergeTarget(payload, sourceName, targetName, wantSpecs)
    if type(payload) ~= "table" then return nil, TEXT_NOTHING_THERE end
    local data, why = MergeSource(payload, sourceName)
    if why then return nil, why end
    if type(data) ~= "table" or not ValidData(data) then return nil, TEXT_NO_PROFILE end
    if type(targetName) ~= "string" or targetName == "" then return nil, TEXT_CHOOSE_TARGET end
    if not (ns.ProfileExists and ns.ProfileExists(targetName)) then return nil, TEXT_TARGET_GONE end
    if wantSpecs and not next(wantSpecs) then return nil, TEXT_CHOOSE_SPEC end
    local tr = ns.EnsureProfile and ns.EnsureProfile(targetName)
    if not tr then return nil, TEXT_CANNOT_OPEN end
    return data, tr
end

local function SpecOwner(field, k)
    if MERGE_WHOLE_SPEC[field] then return tostring(k) end
    if field == "bossLists" then return tostring(k):match("^(%d+):") end
end

local function MergeCustom(dst, k, v, wantSpecs, counts)
    if type(dst[k]) ~= "table" then dst[k] = {} end
    for uid, r in pairs(v) do
        local mine = not wantSpecs
            or (type(r) == "table" and r.specID and wantSpecs[tostring(r.specID)] == true)
        if mine then
            dst[k][uid] = Copy(r)
            counts.entries = counts.entries + 1
        end
    end
end

local function MergeOne(sec, dst, k, v, wantSpecs, counts)
    if MERGE_WHOLE_SPEC[sec.field] then
        dst[k] = Copy(v)
        counts.specs = counts.specs + 1
    elseif sec.field == "customReminders" then
        MergeCustom(dst, k, v, wantSpecs, counts)
    elseif sec.perEntry and type(dst[k]) == "table" then
        for uid, r in pairs(v) do
            dst[k][uid] = Copy(r)
            counts.entries = counts.entries + 1
        end
    else
        dst[k] = Copy(v)
        counts.specs = counts.specs + 1
    end
end

local function MergeSection(tr, sec, incoming, wantSpecs, counts)
    if type(tr[sec.field]) ~= "table" then tr[sec.field] = {} end
    local dst = tr[sec.field]
    for k, v in pairs(incoming) do
        local owner = SpecOwner(sec.field, k)
        if not (wantSpecs and owner and not wantSpecs[owner]) then
            MergeOne(sec, dst, k, v, wantSpecs, counts)
        end
    end
end

function ns.MergeProfileFromPack(payload, sourceName, targetName, opts)
    opts = type(opts) == "table" and opts or {}
    local wantSpecs = opts.specs
    local data, tr = MergeTarget(payload, sourceName, targetName, wantSpecs)
    if not data then return false, tr end

    if payload.licensed then tr.importedPack = ImportedFrom(payload, true) end

    local counts = { specs = 0, entries = 0 }
    for i = 1, #SECTIONS do
        local sec = SECTIONS[i]
        local incoming = data[sec.field]
        if type(incoming) == "table"
            and not (wantSpecs and MERGE_NO_SPEC[sec.field] and not opts.extras) then
            MergeSection(tr, sec, incoming, wantSpecs, counts)
        end
    end
    if opts.settings and type(data.settings) == "table" then ApplySettings(tr, data.settings) end
    if opts.settings then ApplyModuleSettings(targetName, data) end
    if ns.RefreshRuntime then ns.RefreshRuntime() end
    return true, counts.specs, counts.entries
end

local function FreeProfileName(base)
    base = (type(base) == "string" and base ~= "") and base or IMPORTED_PROFILE
    local taken = {}
    local names = ns.ListProfiles and ns.ListProfiles() or {}
    for i = 1, #names do taken[names[i]] = true end
    if not taken[base] then return base end
    local n = 2
    while taken[base .. " " .. n] do n = n + 1 end
    return base .. " " .. n
end

local function WantedName(payload, customName)
    local wanted = Given(customName, payload.name)
    wanted = type(wanted) == "string" and wanted:match("^%s*(.-)%s*$") or ""
    if wanted == "" then wanted = IMPORTED_PROFILE end
    return wanted
end

local function TakeSections(tr, data, wantSpecs)
    for i = 1, #SECTIONS do
        local sec = SECTIONS[i]
        local incoming = data[sec.field]
        if type(incoming) == "table" then
            tr[sec.field] = FilterToSpecs(sec.field, incoming, wantSpecs)
        end
    end
end

function ns.ImportPackAsProfile(payload, wantSpecs, wantSettings, customName, overwrite)
    if type(payload) ~= "table" or type(payload.data) ~= "table" then return false end
    if not ValidData(payload.data) then return false end
    local wanted = WantedName(payload, customName)
    if overwrite and wanted == DEFAULT_PROFILE then overwrite = false end
    local name = overwrite and wanted or FreeProfileName(wanted)
    local tr = ns.EnsureProfile and ns.EnsureProfile(name)
    if not tr then return false end

    if overwrite then
        for i = 1, #SECTIONS do tr[SECTIONS[i].field] = nil end
    end
    local data = payload.data
    TakeSections(tr, data, wantSpecs)
    if wantSettings and type(data.settings) == "table" then ApplySettings(tr, data.settings) end
    if wantSettings then ApplyModuleSettings(name, data) end
    if type(data.leadTime) == "number" then tr.leadTime = data.leadTime end
    if type(data.voiceNone) == "string" and data.voiceNone ~= "" then tr.voiceNone = data.voiceNone end

    tr.importedPack = ImportedFrom(payload, payload.licensed or nil)
    tr.bindingsBySpec = data.bindingsBySpec ~= false

    if ns.SwitchProfile then ns.SwitchProfile(name) end
    if ns.RefreshRuntime then ns.RefreshRuntime() end
    return true, name
end
