-- Run with Lua 5.1 from the repository root: Naowh's Forge, the Macros module's window, built
-- on the Shared kit and opened against stubs and a stand-in for the game's macros. Every tab is
-- drawn and its controls used: a macro is created, edited, renamed and deleted in the game's
-- store, the Library starts empty and fills from the pack, and a share string round-trips.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, size, text and shown state; Show runs OnShow.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local frames = {}
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.scripts[script] = fn end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 600 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text)
        f.text = text
        if f.scripts.OnTextChanged then f.scripts.OnTextChanged(f, false) end
    end,
    GetText = function(f) return rawget(f, "text") or "" end,
    Insert = function(f, text) f:SetText(f:GetText() .. text) end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 16 end,
    GetFrameLevel = function() return 1 end,
    Show = function(f)
        local was = rawget(f, "shown")
        f.shown = true
        if was == false and f.scripts.OnShow then f.scripts.OnShow(f) end
    end,
    Hide = function(f)
        local was = rawget(f, "shown")
        f.shown = false
        if was ~= false and f.scripts.OnHide then f.scripts.OnHide(f) end
    end,
    SetShown = function(f, shown) if shown then f:Show() else f:Hide() end end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    SetEnabled = function(f, on) f.enabled = on end,
    SetClipsChildren = function(f, on) f.clips = on end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    local f = setmetatable({ scripts = {}, parent = parent }, META)
    frames[#frames + 1] = f
    return f
end
local function Click(f, ...) assert(f.scripts.OnClick, "clickable")(f, ...) end

-------------------------------------------------------------------------------
--  The game's macros: account 1-120, character 121-138, sorted by name as the game does.
-------------------------------------------------------------------------------
local MAX_ACCOUNT, MAX_CHARACTER = 120, 18
local store = { account = {}, character = {} }
local picked
local function Sort(list) table.sort(list, function(a, b) return a.name < b.name end) end
local function At(index)
    if index <= MAX_ACCOUNT then return store.account[index], store.account, index end
    return store.character[index - MAX_ACCOUNT], store.character, index - MAX_ACCOUNT
end
local macroAPI = {
    GetNumMacros = function() return #store.account, #store.character end,
    -- As the game does, a question mark macro reports the icon #showtooltip shows.
    GetMacroInfo = function(index)
        local m = At(index)
        if m then return m.name, (m.icon == 134400 and m.body:find("^#showtooltip")) and 135846 or m.icon, m.body end
    end,
    GetMacroSpell = function() return nil end,
    CreateMacro = function(name, icon, body, perCharacter)
        local list = perCharacter and store.character or store.account
        list[#list + 1] = { name = name, icon = icon, body = body }
        Sort(list)
    end,
    EditMacro = function(index, name, icon, body)
        local m, list = At(index)
        m.name, m.icon, m.body = name or m.name, icon or m.icon, body or m.body
        Sort(list)
    end,
    DeleteMacro = function(index)
        local _, list, i = At(index)
        table.remove(list, i)
    end,
    PickupMacro = function(index) picked = index end,
}

-------------------------------------------------------------------------------
--  The addon around it
-------------------------------------------------------------------------------
local WHITE = { r = 1, g = 1, b = 1 }
local account, printed, settings, packMacros = {}, {}, {}, {}
local setHooks = {}
local UI = {
    STATUS = { untested = "" },
    CONTENT_PAD = 10,
    Keep = function(parent, key, make)
        local kept = rawget(parent, key)
        if not kept then kept = make(parent); parent[key] = kept end
        return kept
    end,
    RefreshPage = NOTHING,
    CloseOnEscape = NOTHING,
    SlimScroll = function(parent) return Frame(parent) end,
    BuildSliderCore = function(parent)
        local slider = Frame(parent)
        for _, k in ipairs({ "rail", "fill", "thumb", "valueBox", "valueFill" }) do slider[k] = Frame(slider) end
        slider.valueBorder = { _frame = Frame(slider) }
        slider._refreshValue = NOTHING
        return slider
    end,
    BuildToggleControl = function(parent, _, get, set)
        local t = Frame(parent)
        t._get, t._set = get, set
        t._refreshValue = NOTHING
        t.scripts.OnClick = function() set(not get()) end
        return t
    end,
    BuildDropdownControl = function(parent, _, _, _, _, get, set)
        local d = Frame(parent)
        d._get, d._set = get, set
        return d
    end,
    ModuleSettings = function(_, defaults)
        local S = {}
        function S.Get(k) if settings[k] == nil then return defaults[k] end return settings[k] end
        function S.Set(k, v)
            settings[k] = v
            for _, fn in ipairs(setHooks) do fn(k, v) end
        end
        return S
    end,
    Widgets = {
        Note = function() return nil, 20 end, DualRow = function() return nil, 50 end,
        SectionHeader = function() return nil, 30 end, Feature = function() return nil, 30 end,
        Button = function() return nil, 30 end,
    },
}
local ns = {
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    UI = UI,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Border = function(parent) return { SetColor = NOTHING, _frame = Frame(parent) } end,
    AccentBorder = function(b) return b end,
    Button = function(parent, _, _, _, onClick)
        local b = Frame(parent)
        b.label, b._border, b._rest, b._onClick = Frame(b), { SetColor = NOTHING }, WHITE, onClick
        b.scripts.OnClick = function() if b._onClick then b._onClick() end end
        return b
    end,
    NewEditBox = function(parent) return Frame(parent) end,
    NewSearchBox = function(parent)
        local box = Frame(parent)
        box.hint, box.border = Frame(box), { SetColor = NOTHING }
        return box
    end,
    SetButtonText = NOTHING, Tooltip = NOTHING, Hairline = NOTHING, PixelInset = NOTHING,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    AccountSettings = function() return account end,
    Print = function(m) printed[#printed + 1] = m end,
    Confirm = function(text, yes) account.lastConfirm = text; yes() end,
    ShowCopyBox = function(_, text) account.lastCopy = text end,
    StashOptionsWindow = NOTHING, OpenOptionsWindow = NOTHING, Apply = NOTHING,
    DB = function() return { utilityReminders = { classMacros = packMacros } } end,
    HEALTHSTONES = { 5509 }, HEALING_POTIONS = { 13446 },
}
local lastPrompt
local vault = {}
ns.PromptText = function(_, _, _, accept) lastPrompt = accept end
local env = setmetatable({
    NaowhForever = ns,
    UIParent = {},
    GameTooltip = Frame(),
    GameTooltip_Hide = NOTHING,
    CreateFrame = function(_, _, parent) return Frame(parent) end,
    CreateColor = function() return { SetRGBA = NOTHING } end,
    hooksecurefunc = function(t, name, fn)
        if type(t) == "table" and name == "Set" then setHooks[#setHooks + 1] = fn end
    end,
    InCombatLockdown = function() return false end,
    IsMouseButtonDown = function() return false end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    UnitClass = function() return "Mage", "MAGE", 8 end,
    UnitName = function() return "Glyalith" end,
    IsInRaid = function() return false end,
    IsInGroup = function() return false end,
    LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, k) return k end }),
    RAID_CLASS_COLORS = setmetatable({}, { __index = function()
        return { WrapTextInColorCode = function(_, text) return text end }
    end }),
    Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = MAX_ACCOUNT, MAX_CHARACTER_MACROS = MAX_CHARACTER } },
    GetLooseMacroIcons = function(t) t[#t + 1] = 136243 end,
    GetLooseMacroItemIcons = NOTHING,
    GetMacroIcons = function(t) t[#t + 1] = 134400; t[#t + 1] = 135846 end,
    GetMacroItemIcons = NOTHING,
    GetMacroIndexByName = function() return 0 end,
    GetMacroBody = function() return nil end,
    GetInventoryItemID = function() return 19949 end,
    NUM_BAG_SLOTS = 0,
    C_Container = { GetContainerNumSlots = function() return 0 end },
    C_Item = { GetItemCount = function(id) return id == 5509 and 1 or 0 end, GetItemIconByID = function() return 133939 end,
        GetItemNameByID = function(id) return "Item " .. id end, GetItemSpell = NOTHING, GetItemInfo = NOTHING },
    C_Spell = { GetSpellName = function(id) return "Spell " .. id end, GetSpellTexture = function() return 135846 end },
    LibStub = function()
        return {
            Serialize = function(_, v) vault[1] = v; return "S" end,
            Deserialize = function() return true, vault[1] end,
            CompressDeflate = function(_, v) return v end, DecompressDeflate = function(_, v) return v end,
            EncodeForPrint = function(_, v) return v end, DecodeForPrint = function(_, v) return v end,
        }
    end,
}, { __index = _G })
for k, v in pairs(macroAPI) do env[k] = v end
env._G = env

Load({
    "Shared/Shared.lua", "Shared/Data/Forever.lua", "Shared/Style.lua", "Shared/Items.lua", "Shared/Places.lua",
    "Shared/Parts.lua", "Shared/Window.lua", "Shared/View.lua", "Shared/Kinds.lua",
    "Macros/NaowhForever_MacroText.lua", "Macros/NaowhForever_Macros.lua", "Macros/NaowhForever_MacroWindow.lua",
}, env)

local function Window()
    for _, f in ipairs(frames) do
        if rawget(f, "positionKey") == "macroWindow" then return f end
    end
end
local function Shown(test)
    local out = {}
    for _, f in ipairs(frames) do
        if rawget(f, "shown") ~= false and test(f) then out[#out + 1] = f end
    end
    return out
end

-------------------------------------------------------------------------------
--  My Macros
-------------------------------------------------------------------------------
store.account[1] = { name = "Hearth", icon = 134400, body = "#showtooltip\n/use Hearthstone" }
store.character[1] = { name = "Sheep", icon = 134400, body = "#showtooltip Polymorph\n/cast [@focus,harm][] Polymorph" }

ns.OpenMacroWindow()
local window = Window()
check("Naowh's Forge is built by the kit", window and window.backdrop and window.switch)
check("its title is Naowh's Forge", window.title:GetText() == "Naowh's Forge")
check("the subtitle counts the slots", window.subtitle:GetText():find("Account 1/120", 1, true)
    and window.subtitle:GetText():find("Character 1/18", 1, true))
check("a new macro waits in the editor", window.name:GetText() == "New Macro")

local rows = Shown(function(f) return rawget(f, "macro") ~= nil end)
check("both macros are listed", #rows == 2)
local sheepRow
for _, r in ipairs(rows) do if r.macro.name == "Sheep" then sheepRow = r end end
Click(sheepRow)
check("clicking one opens it", window.name:GetText() == "Sheep" and window.code:GetText():find("Polymorph"))
sheepRow.scripts.OnDragStart(sheepRow)
check("dragging a row picks the macro up", picked == MAX_ACCOUNT + 1)

-- Edit and rename: the game re-sorts, the editor follows it.
window.name:SetText("Asheep")
window.code:SetText("#showtooltip Polymorph\n/stopcasting\n/cast [@focus,harm][] Polymorph")
-- The editor's buttons, in the order they are made: Save, Shorten, Export, Revert, Delete.
local editorButtons = {}
for _, f in ipairs(frames) do
    if rawget(f, "_onClick") and f.parent == window.editor then editorButtons[#editorButtons + 1] = f end
end
check("the editor has Save, Shorten, Export, Revert and Delete", #editorButtons == 5)
Click(editorButtons[1])
check("saving edits the game's macro", store.character[1].name == "Asheep"
    and store.character[1].body:find("/stopcasting", 1, true))
check("and says so", printed[#printed]:find("Saved Asheep", 1, true))

-- Shorten, Export.
window.code:SetText("/cast [ target=focus ] Polymorph ; Frostbolt")
Click(editorButtons[2])
check("Shorten rewrites it", window.code:GetText() == "/cast [@focus] Polymorph;Frostbolt")
Click(editorButtons[3])
check("Export gives a share string", (account.lastCopy or ""):find("^!NFM1!"))

-- New macro on the account, then delete it.
local newButton
for _, f in ipairs(frames) do if rawget(f, "tip") == "New Macro" then newButton = f end end
Click(newButton)
check("New starts an empty macro", window.name:GetText() == "New Macro")
Click(window.editor.scopeAccount)
window.name:SetText("Mount")
window.code:SetText("#showtooltip\n/use Swift Brown Steed")
Click(editorButtons[1])
check("Create makes an account macro", #store.account == 2 and store.account[2].name == "Mount")
Click(editorButtons[5])
check("Delete removes it from the game", #store.account == 1)

-- Problems show on the right line.
window.code:SetText("#showtooltip\n/castsequnce Scorch, Fire Blast")
check("an unknown command is caught", window.editor.issueLines[1]:GetText():find("^L2", 1) ~= nil)

-- The inspector's panes.
for _, key in ipairs({ "conditions", "commands", "icons", "explain" }) do window.inspector.Show(key) end

-------------------------------------------------------------------------------
--  Smart Macros and Library
-------------------------------------------------------------------------------
window.switch.onPick("smart")
local cards = Shown(function(f) return rawget(f, "key") ~= nil and rawget(f, "uses") ~= nil end)
check("one card per Smart Macro", #cards == 8)
local health
for _, c in ipairs(cards) do if c.key == "health" then health = c end end
check("the health card says what it will use", health.uses[1].text.text == "Item 5509")
Click(health.toggle)
check("its switch turns the macro on", settings.health == true)

window.switch.onPick("lib")
check("the Library starts empty, with Import", window.lib.empty:IsShown() and window.lib.importEmpty:IsShown())
packMacros.MAGE = { { name = "Naowh Sheep", body = "#showtooltip Polymorph\n/cast Polymorph", note = "Naowh's" } }
window.switch.onPick("mine")
window.switch.onPick("lib")
local libCards = Shown(function(f) return rawget(f, "open") ~= nil and rawget(f, "add") ~= nil end)
check("the pack's macros fill it", #libCards == 1 and not window.lib.empty:IsShown())
Click(libCards[1].add)
check("Add makes a character macro", store.character[2] and store.character[2].name == "Naowh Sheep")

-------------------------------------------------------------------------------
--  Import
-------------------------------------------------------------------------------
Click(window.lib.importEmpty)
lastPrompt(account.lastCopy)
check("a share string imports as character macros", #store.character == 3)
lastPrompt("not a string")
check("anything else is turned away", printed[#printed]:find("not a Naowh Forever macro string", 1, true))

-------------------------------------------------------------------------------
--  The game moves macros: the editor follows the one it has open
-------------------------------------------------------------------------------
local function OpenNamed(name)
    window.switch.onPick("mine")
    for _, r in ipairs(Shown(function(f) return rawget(f, "macro") ~= nil end)) do
        if r.macro.name == name then return Click(r) end
    end
    error("no row for " .. name)
end

store.account = { { name = "Zed", icon = 136243, body = "/cast Zed" } }
OpenNamed("Zed")
macroAPI.CreateMacro("Abc", 134400, "/cast Abc", false)   -- a Smart Macro made meanwhile sorts before it
window.code:SetText("/cast Zed 2")
Click(editorButtons[1])
check("Save follows the open macro to its new slot", store.account[1].body == "/cast Abc"
    and store.account[2].name == "Zed" and store.account[2].body == "/cast Zed 2")
macroAPI.CreateMacro("Aaa", 134400, "/cast Aaa", false)
Click(editorButtons[5])
check("Delete removes the open macro, not whatever moved into its slot", #store.account == 2
    and store.account[1].name == "Aaa" and store.account[2].name == "Abc")

OpenNamed("Abc")
macroAPI.DeleteMacro(2)   -- removed outside the Forge
window.code:SetText("/cast Abc 2")
Click(editorButtons[1])
check("a macro gone from under it is not saved over another", #store.account == 1 and store.account[1].name == "Aaa"
    and printed[#printed]:find("changed or removed outside", 1, true))
Click(editorButtons[1])
check("Save then makes it again as a new macro", #store.account == 2 and store.account[2].body == "/cast Abc 2")

-- Saving text leaves a question mark icon alone, so it keeps following #showtooltip.
store.character = { { name = "Show", icon = 134400, body = "#showtooltip Polymorph\n/cast Polymorph" } }
OpenNamed("Show")
window.code:SetText("#showtooltip Polymorph\n/stopcasting\n/cast Polymorph")
Click(editorButtons[1])
check("the icon stays the question mark", store.character[1].icon == 134400
    and store.character[1].body:find("/stopcasting", 1, true))

-- Import: any number, as many as fit; a script in any case is called out.
local twenty = {}
for i = 1, 20 do twenty[i] = { name = "M" .. i, body = "/cast Spell " .. i } end
vault[1] = { v = 1, macros = twenty }
Click(window.lib.importEmpty)
lastPrompt("!NFM1!S")
check("all 20 are read, as many added as fit", #store.character == 18
    and printed[#printed]:find("Added 17 of 20", 1, true))
store.character = {}
for _, body in ipairs({ "/RUN print(1)", "/dump GetTime()" }) do
    vault[1] = { v = 1, macros = { { name = "X", body = body } } }
    Click(window.lib.importEmpty)
    lastPrompt("!NFM1!S")
    check("a script is called out: " .. body, account.lastConfirm:find("runs a script", 1, true))
end

check("line numbers stay inside the editor box", window.editor.gutter.clips == true)

print(("test-macro-window: %d checks passed"):format(checks))
