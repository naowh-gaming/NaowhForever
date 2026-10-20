-- Run with Lua 5.1 from the repository root: the Action Bars window's three views (saved
-- sets, the set builder and the import preview) built and drawn from the real files against
-- stubs. Checks that each draws, that the builder's clicks become the saved set's choices,
-- that the builder lists the bars each class uses (forms, the pet bar's keys) and hides empty
-- ones, and that the preview's Import imports.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, size, text and shown state; every other method is one
--  shared do-nothing function.
-------------------------------------------------------------------------------
local NOTHING = function() end
local WHITE = { r = 1, g = 1, b = 1 }
local Frame
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.hooks[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterEvent = function(f, event) f.events[event] = nil end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetParent = function(f, parent) f.parent = parent end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 300 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    SetPoint = function(f, point, x, y) if point == "TOPLEFT" and type(x) == "number" then f.y = y end end,
    GetText = function(f) return rawget(f, "text") or "" end,
    SetTexture = function(f, texture) f.texture = texture end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true; if f.scripts.OnShow then f.scripts.OnShow(f) end end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    SetDesaturated = function(f, on) f.desaturated = on end,
    GetFrameLevel = function() return 1 end,
    GetEffectiveScale = function() return 1 end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    return setmetatable({ scripts = {}, hooks = {}, events = {}, parent = parent }, META)
end

local function Click(frame)
    local fn = frame.scripts.OnClick
    if fn then fn(frame) elseif rawget(frame, "onClick") then frame.onClick() end
end

-------------------------------------------------------------------------------
--  The game: a priest who knows Smite, with bars, macros and keys
-------------------------------------------------------------------------------
local state = { account = {}, printed = {}, timers = {}, bars = {}, macros = {}, binds = {}, frames = {} }
local SPELLS = { [585] = "Smite", [2054] = "Heal" }
local known = { [585] = true }

local function Values(defaults)
    local db, heard = {}, {}
    return {
        Get = function(k) if db[k] == nil then return defaults[k] end return db[k] end,
        Set = function(k, v)
            db[k] = v
            for i = 1, #heard do heard[i](k, v) end
        end,
        OnChange = function(fn) heard[#heard + 1] = fn end,
        Toggle = NOTHING,
    }
end

local rowParents = setmetatable({}, { __mode = "k" })
local ns
ns = {
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    UI = {
        ModuleSettings = function(_, defaults) return Values(defaults) end,
        SlimScroll = function(parent) return Frame(parent) end,
        CloseOnEscape = NOTHING, RefreshPage = NOTHING, CONTENT_PAD = 20,
        -- Kept frames per parent and key, hidden at the start of each draw, as the real kit.
        BeginReusableRows = function(parent)
            local kept = rowParents[parent] or {}
            rowParents[parent] = kept
            kept.uses = {}
            for key, list in pairs(kept) do
                if key ~= "uses" then for _, el in ipairs(list) do el:Hide() end end
            end
        end,
        Keep = function(parent, key, create)
            local kept = rowParents[parent]
            if not kept then return create(parent) end
            local i = (kept.uses[key] or 0) + 1
            kept.uses[key] = i
            kept[key] = kept[key] or {}
            local el = kept[key][i] or create(parent)
            kept[key][i] = el
            el:Show()
            return el
        end,
        KeepFont = function(parent) return Frame(parent) end,
        KeepButton = function(parent, key, text, _, _, onClick)
            local button = Frame(parent)
            button.label, button.onClick, button.key = text, onClick, key
            state.rowButtons[text] = button
            return button
        end,
        BuildToggleControl = function(parent, _, get, set)
            local toggle = Frame(parent)
            state.toggles[#state.toggles + 1] = toggle
            -- The real switch reads its value when it is made.
            toggle._get, toggle._set, toggle._refreshValue = get, set, function() get() end
            toggle._refreshValue()
            toggle.scripts.OnClick = function() set(not get()) end
            return toggle
        end,
        BuildSliderCore = function(parent, _, _, _, _, _, _, _, _, _, _, get, set)
            local slider = Frame(parent)
            slider.rail, slider.fill, slider.thumb = Frame(slider), Frame(slider), Frame(slider)
            slider.valueBox, slider.valueFill = Frame(parent), Frame(parent)
            slider.valueBorder = { _frame = Frame(parent) }
            slider._get, slider._set, slider._refreshValue = get, set, NOTHING
            return slider, slider.valueBox
        end,
        Widgets = {
            SectionHeader = function() return nil, 20 end,
            Note = function() return nil, 20 end,
        },
    },
    AccountSettings = function() return state.account end,
    Print = function(text) state.printed[#state.printed + 1] = text end,
    Color = function(_, text) return text end,
    L = function(text) return text end,
    Font = function(parent)
        local fs = Frame(parent)
        state.fonts[#state.fonts + 1] = fs
        return fs
    end,
    Solid = function(parent) return Frame(parent) end,
    Hairline = function(region) return region end,
    AllowOffscreen = function() end,
    Border = function(parent)
        local edge = Frame(parent)
        edge.SetColor = function(self, r) self.red = r end
        edge._frame = edge
        return edge
    end,
    Button = function(parent, text, _, _, onClick)
        local button = Frame(parent)
        button.label, button.onClick = text, onClick
        state.buttons[text] = button
        return button
    end,
    AccentBorder = function(frame) return frame end,
    SetButtonText = function(button, text) button.label = text end,
    NewEditBox = function(parent)
        state.editBox = Frame(parent)
        return state.editBox
    end,
    UIScale = function() return 1 end,
    UIFontPath = function() return "font" end,
    Apply = NOTHING,
    Confirm = function(text, yes) state.confirmed = text; yes() end,
    PromptText = NOTHING,
}
state.buttons, state.rowButtons, state.toggles, state.fonts = {}, {}, {}, {}
state.class, state.className = "PRIEST", "Priest"

local function ActionInfo(slot)
    local a = state.bars[slot]
    if a then return a.kind, a.id end
end

local env = setmetatable({
    _G = { NaowhForever = ns },
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } },
    Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } },
    C_GamepadUI = {
        GetFirstGamepadActionStorageSlotIndex = function() return 181 end,
        IsValidGamepadActionStorageSlotIndex = function() return false end,
    },
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
        GetSpellBookItemInfo = function() return { name = "Smite", subName = "Rank 1", actionID = 585,
            itemType = 1, isPassive = false } end,
    },
    C_Spell = {
        GetSpellName = function(id) return SPELLS[id] end,
        GetSpellTexture = function() return 135924 end,
        GetSpellLevelLearned = function() return 30 end,
        GetSpellSubtext = function() return "Rank 1" end,
        PickupSpell = function(id) if known[id] then state.cursor = { kind = "spell", id = id } end end,
    },
    C_Item = { GetItemIconByID = function() return 134400 end, GetItemNameByID = function() return "Item" end,
        PickupItem = function(id) state.cursor = { kind = "item", id = id } end },
    C_ActionBar = { GetActionText = function(slot) return state.bars[slot] and state.bars[slot].name end },
    C_EquipmentSet = { GetEquipmentSetID = NOTHING, PickupEquipmentSet = NOTHING },
    C_KeyBindings = { GetBindingContextForAction = function() return 1 end },
    C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    MenuUtil = { CreateContextMenu = function(_, build)
        state.menu = {}
        build(nil, { CreateButton = function(_, text, fn) state.menu[text] = fn end })
    end },
    GameTooltip = Frame(), GameTooltip_Hide = NOTHING,
    GetActionInfo = ActionInfo,
    GetActionTexture = function(slot) return state.bars[slot] and 135924 end,
    GetCursorInfo = function() return state.cursor and state.cursor.kind end,
    ClearCursor = function() state.cursor = nil end,
    PlaceAction = function(slot) state.bars[slot], state.cursor = state.cursor, state.bars[slot] end,
    PickupAction = function(slot) state.cursor, state.bars[slot] = state.bars[slot], nil end,
    GetNumMacros = function() return #state.macros, 0 end,
    GetMacroInfo = function(i) local m = state.macros[i]; if m then return m.name, m.icon, m.body end end,
    GetMacroIndexByName = function(name)
        for i, m in ipairs(state.macros) do if m.name == name then return i end end
        return 0
    end,
    CreateMacro = function(name, icon, body)
        state.macros[#state.macros + 1] = { name = name, icon = icon, body = body }
        return #state.macros
    end,
    PickupMacro = function(i) state.cursor = { kind = "macro", id = 0, name = state.macros[i].name } end,
    GetNumBindings = function() return #state.binds end,
    GetBinding = function(i) local b = state.binds[i]; return b[1], "", b[2] end,
    GetBindingKey = function(command)
        for _, b in ipairs(state.binds) do if b[1] == command then return b[2] end end
    end,
    GetBindingText = function(key) return key end,
    SetBinding = function() return true end,
    SaveBindings = NOTHING, GetCurrentBindingSet = function() return 1 end,
    InCombatLockdown = function() return false end,
    UnitClass = function() return state.className, state.class end,
    GetPetActionInfo = function(i)
        local pet = state.pet and state.pet[i]
        if pet then return pet[1], pet[2], pet[3] end
    end,
    UnitName = function() return "Alt" end,
    UnitLevel = function() return 20 end,
    GetRealmName = function() return "Realm" end,
    CreateFrame = function(_, _, parent)
        local frame = Frame(parent)
        state.frames[#state.frames + 1] = frame
        return frame
    end,
    CreateColor = function() return Frame() end,
    UIParent = Frame(),
    hooksecurefunc = function(t, key, fn)
        local original = t[key]
        t[key] = function(...) original(...); fn(...) end
    end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    time = os.time, date = os.date,
    print = function(text) state.printed[#state.printed + 1] = text end,
}, { __index = _G })
env._G.NaowhForever = ns

Load({ "Shared/Shared.lua", "Shared/Style.lua", "Shared/Game/ActionKeys.lua", "Shared/UI/Parts.lua", "Shared/UI/Marks.lua", "Shared/UI/Text.lua", "Shared/UI/Hud.lua", "Shared/UI/Timer.lua", "Shared/UI/Share.lua", "Shared/UI/Panels.lua", "Shared/UI/Window.lua", "Shared/UI/Tabs.lua", "Shared/UI/SettingsCard.lua",
    }, env)
local MODULE = { "Core/Features.lua" }
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_Utilities/ActionBars/.*%.lua$")) do
    if not path:find("SettingsPage%.lua$") then MODULE[#MODULE + 1] = path end
end
Load(MODULE, env)

local function RunTimers()
    local timers = state.timers
    state.timers = {}
    for _, fn in ipairs(timers) do fn() end
end

local function Visible(frame)
    while frame do
        if not frame:IsShown() then return false end
        frame = frame:GetParent()
    end
    return true
end

-- Every tile on screen: tiles are the frames with a key font and a badge.
local function Tiles()
    local tiles = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "key") and rawget(frame, "badge") and Visible(frame) then tiles[#tiles + 1] = frame end
    end
    return tiles
end

-------------------------------------------------------------------------------
--  The checks
-------------------------------------------------------------------------------
state.bars = { [1] = { kind = "spell", id = 585 }, [2] = { kind = "spell", id = 2054 },
    [3] = { kind = "macro", id = 0, name = "Pull" } }
state.macros = { { name = "Pull", icon = 1, body = "/say pull" }, { name = "Dance", icon = 2, body = "/dance" } }
state.binds = { { "ACTIONBUTTON1", "1" }, { "ACTIONBUTTON2", "2" } }
known[2054] = true

ns.OpenActionBarsWindow()
check("the saved sets view draws its Save Current Bars button", state.rowButtons["Save Current Bars"])

state.rowButtons["Save Current Bars"].onClick()
local tiles = Tiles()
check("the builder draws a bar of twelve tiles", #tiles == 12)
check("a slot with an action shows its key", tiles[1].key.text == "1")
Click(tiles[2])
check("a click leaves a slot out, and it greys", Tiles()[2].icon.desaturated == true)

local editBox = state.editBox
check("the builder has a name box", editBox and editBox.scripts.OnEnterPressed)
editBox:SetText("Raid")
state.buttons["Save Set"].onClick()
local set = state.account.barSets.PRIEST.Raid
check("Save Set saves under the typed name", set)
check("with the slot left out", set.slots[1] and not set.slots[2] and set.choices.skip[2])
check("and every macro, keys too", #set.macros == 2 and set.bindings and set.bindings["1"] == "ACTIONBUTTON1")

-- The same set on an alt that knows only Smite, has no macros and other things on its bars.
known[2054] = nil
state.macros = {}
state.bars = { [2] = { kind = "item", id = 6948 }, [7] = { kind = "spell", id = 585 } }
ns.OpenActionBarsImport("Raid")
tiles = Tiles()
check("the preview draws the bar", #tiles == 12)
check("a macro the import makes is marked NEW", tiles[3].badge.text.text == "NEW")
check("a slot left out shows the alt's own action", tiles[2].icon.texture == 135924 and tiles[2].icon.desaturated)
check("nothing changed yet", state.bars[2].kind == "item" and #state.macros == 0)
state.buttons.Import.onClick()
check("Import imports", state.bars[1].id == 585 and state.bars[3].kind == "macro" and #state.macros == 2)
check("and leaves the left-out slot alone", state.bars[2].kind == "item")
check("and clears a slot the set keeps empty", state.bars[7] == nil)
RunTimers()
check("and goes back to the saved sets, the new set listed", state.rowButtons.Import)

-- More > Edit and Save Again opens the builder on the set, its picks in place.
ns.OpenActionBarsBuilder("Raid")
check("editing a set keeps its name", editBox.text == "Raid")
check("and its left-out slot", Tiles()[2].icon.desaturated == true)

-- The builder's bars for each class: the rows on screen, top to bottom, with their names.
local DOT = ns.Shared.Style.PLACE_DOT
local function Rows()
    local rows = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "tiles") and rawget(frame, "box") and Visible(frame) then rows[#rows + 1] = frame end
    end
    table.sort(rows, function(a, b) return (a.y or 0) > (b.y or 0) end)
    return rows
end
local function Names()
    local names = {}
    for i, row in ipairs(Rows()) do names[i] = row.name.text end
    return table.concat(names, ", ")
end
local function Summary()
    for _, fs in ipairs(state.fonts) do
        local text = rawget(fs, "text")
        if type(text) == "string" and text:find(" macro", 1, true) and text:find(DOT, 1, true) and Visible(fs) then
            return text
        end
    end
end
local function Row(name)
    for _, row in ipairs(Rows()) do if row.name.text == name then return row end end
end
local function Steps()
    local on = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "step") and Visible(frame) then on[frame.step] = frame.line.shown ~= false end
    end
    return on
end
local function BackLink()
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "underline") and Visible(frame) then return frame end
    end
end
local SHOW_EMPTY, KEYS = state.toggles[1], state.toggles[2]
local MAIN, STEALTH = "Action Bar 1" .. DOT .. "Main", "Action Bar 1" .. DOT .. "Stealth"

state.class, state.className = "ROGUE", "Rogue"
state.bars = { [1] = { kind = "spell", id = 585 }, [2] = { kind = "spell", id = 2054 },
    [73] = { kind = "spell", id = 585 }, [61] = { kind = "spell", id = 2054 } }
state.macros = { { name = "Pull", icon = 1, body = "/say pull" }, { name = "Dance", icon = 2, body = "/dance" } }
state.binds = { { "ACTIONBUTTON1", "1" }, { "ACTIONBUTTON2", "2" } }
ns.OpenActionBarsBuilder()
check("a rogue sees the main bar, its Stealth page and Action Bar 2, empty bars hidden",
    Names() == MAIN .. ", " .. STEALTH .. ", Action Bar 2")
check("each bar counts its actions", Row(STEALTH).count.text == "1 action" and Row(MAIN).count.text == "2 actions")
check("the summary counts actions, keybinds and macros", Summary() == "4 actions" .. DOT .. "2 keybinds" .. DOT .. "2 macros")
Click(SHOW_EMPTY)
check("Show empty bars lists every bar", #Rows() == 15)
Click(SHOW_EMPTY)
check("and off hides them again", #Rows() == 3)
Click(Row(STEALTH).tiles[1])
check("a click on one button leaves just that slot out", Row(STEALTH).tiles[1].icon.desaturated == true
    and Row(STEALTH).tiles[2].icon.desaturated == false and Summary():find("^3 actions"))
Click(Row("Action Bar 2").box)
check("a bar's box leaves the whole bar out, and dims it", Row("Action Bar 2").alpha < 1 and Summary():find("^2 actions"))
editBox:SetText("Rogue")
state.buttons["Save Set"].onClick()
set = state.account.barSets.ROGUE.Rogue
check("the saved set leaves those slots out", set.slots[1] and set.slots[73] == nil and set.choices.skip[73]
    and set.slots[61] == nil and set.choices.skip[72])

state.class, state.className = "DRUID", "Druid"
state.bars = { [1] = { kind = "spell", id = 585 }, [73] = { kind = "spell", id = 585 },
    [85] = { kind = "spell", id = 585 }, [97] = { kind = "spell", id = 585 }, [109] = { kind = "spell", id = 585 } }
ns.OpenActionBarsBuilder()
check("a druid sees its forms after the main bar", Names() == MAIN .. ", Action Bar 1" .. DOT .. "Cat, Action Bar 1" .. DOT
    .. "Prowl, Action Bar 1" .. DOT .. "Bear, Action Bar 1" .. DOT .. "Moonkin")
check("a form page shows the main bar's keys", Row("Action Bar 1" .. DOT .. "Bear").tiles[1].key.text == "1")

state.class, state.className = "HUNTER", "Hunter"
state.bars = { [1] = { kind = "spell", id = 585 } }
state.binds = { { "ACTIONBUTTON1", "1" }, { "BONUSACTIONBUTTON1", "CTRL-1" }, { "BONUSACTIONBUTTON2", "CTRL-2" } }
state.pet = { { "Attack", "PET_ATTACK_TEXTURE", true } }
ns.OpenActionBarsBuilder()
local petBar = Row("Pet Bar")
check("a hunter sees the pet bar last, keys only", Names() == MAIN .. ", Pet Bar" and petBar.tag.text.text == "keys only")
check("with its ten buttons and their keys", petBar.tiles[10]:IsShown() and not petBar.tiles[11]:IsShown()
    and petBar.tiles[1].key.text == "CTRL-1" and petBar.count.text == "2 keybinds")
check("its keys count in the summary", Summary() == "1 action" .. DOT .. "3 keybinds" .. DOT .. "2 macros")
Click(petBar.tiles[1])
check("a pet button is not a slot to leave out", not petBar.tiles[1].icon.desaturated)
Click(petBar.box)
check("its box leaves the pet bar's keys out", Row("Pet Bar").alpha < 1 and Summary():find(DOT .. "1 keybind" .. DOT, 1, true))
editBox:SetText("Hunter")
state.buttons["Save Set"].onClick()
set = state.account.barSets.HUNTER.Hunter
check("so the set keeps the bar keys only", set.bindings["1"] == "ACTIONBUTTON1" and set.bindings["CTRL-1"] == nil
    and set.choices.petOff == true)
ns.OpenActionBarsBuilder("Hunter")
Click(Row("Pet Bar").box)
Click(KEYS)
check("keybinds off dims the pet bar and drops keys from the summary", Row("Pet Bar").alpha < 1
    and Summary() == "1 action" .. DOT .. "2 macros")
check("the step strip marks Keybinds & macros", Steps()[2] and not Steps()[1] and not Steps()[3])
Click(Row("Pet Bar").box)
check("and its box cannot be ticked then", Row("Pet Bar").alpha < 1)

state.class, state.className = "MAGE", "Mage"
state.bars = {}
state.binds = {}
ns.OpenActionBarsBuilder()
check("a character with nothing on its bars sees no rows until Show empty bars", #Rows() == 0)
check("the step strip starts on Bars", Steps()[1] and not Steps()[2])
local back = BackLink()
check("the builder links back to the saved sets", back and back.text.text == "Saved Sets")
Click(back)
check("which it opens", state.rowButtons["Save Current Bars"] and not BackLink())
local settings = Frame()
ns.Shared.Parts.OpenWithBack(ns.OpenActionBarsWindow, settings, function() state.settings = true end, "Back to Settings")
back = BackLink()
check("opened from Settings, the link goes back there", back and back.text.text == "Settings")
Click(back)
check("closing the window", not Visible(back))

print(checks .. " action bar window checks passed")
