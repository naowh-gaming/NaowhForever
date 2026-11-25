-- Run with Lua 5.1 from the repository root: the Dungeon Journal's data and rules. Loads the
-- files its DungeonJournal.xml lists, in that order, against stubs (and checks the TOC loads
-- that XML), then checks the generated data holds together, the loot rules, which dungeon
-- you are in, the small helpers, what counting costs, that nothing is made or hooked while
-- the Journal is off, the dungeon map's list of bosses and its boss page, and the Reputation
-- and PvP tabs. Its quests have their own test
-- (test-journal-quests.lua).
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-- The journal's files, in load order, from its XML; the TOC loads that XML.
local tocLoads = false
for line in io.lines("NaowhForever_DungeonJournal/NaowhForever_DungeonJournal.toc") do
    if line:gsub("\r$", "") == "DungeonJournal.xml" then tocLoads = true end
end
check("the TOC loads the journal", tocLoads)
local TocFiles = dofile("Tools/regression/toc_files.lua")
local journalFiles = TocFiles("^NaowhForever_DungeonJournal/.*%.lua$")
check("the journal lists its files", #journalFiles > 40)
-- What the modules share loads first: the Journal is drawn with it.
local files = TocFiles("^Shared/.*%.lua$")
check("the shared parts load", #files >= 7)
-- The copy cards are stubbed, so their Shared file is left out.
for i = #files, 1, -1 do
    if files[i] == "Shared/UI/CopyCard.lua" then table.remove(files, i) end
end
for _, path in ipairs(journalFiles) do files[#files + 1] = path end

local RING_SLOTS = { 1, 2 }
local function BORDER_SET_COLOR(_, r, g, b)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number",
        "SetColor takes r, g, b numbers, as SetColorTexture does")
end
local WHITE = { r = 1, g = 1, b = 1 }
-- A class's colour, as the game's ColorMixin: it can wrap a name in its colour code.
local CLASS_COLOR = { r = 1, g = 1, b = 1, WrapTextInColorCode = function(_, text) return "|cffffffff" .. text .. "|r" end }

-- The game's strsplit: the parts of s between each sep, as separate values; with limit, at
-- most that many, the last holding the rest.
local function strsplit(sep, s, limit)
    local parts, n, at = {}, 0, 1
    local plain = sep:gsub("%p", "%%%0")
    while true do
        local first, last = s:find(plain, at)
        if not first or (limit and n == limit - 1) then break end
        n = n + 1
        parts[n] = s:sub(at, first - 1)
        at = last + 1
    end
    n = n + 1
    parts[n] = s:sub(at)
    return unpack(parts, 1, n)
end

-- A frame whose every method does nothing, except: HookScript, which is counted; its
-- scripts and events, which it keeps (frame.scripts, frame.events) for a test to fire; its
-- parent, size and text, which it remembers; and the measures a layout reads, which answer
-- plausible numbers. Enough to build and draw the window offline, not to look at it.
local MEASURES = { GetStringWidth = 40, GetStringHeight = 12, GetFrameLevel = 1, GetEffectiveScale = 1,
    GetScale = 1, GetLeft = 0, GetRight = 300, GetTop = 0, GetBottom = 0, GetVerticalScroll = 0,
    GetVerticalScrollRange = 0, GetValue = 0 }
-- Each measure as a method, made once.
local MEASURE_METHODS = {}
for name, value in pairs(MEASURES) do MEASURE_METHODS[name] = function() return value end end
local Frame
-- One function for every method a frame does nothing with: made once, so a stub frame makes
-- no garbage and timings measure the addon alone.
local NOTHING = function() end
local METHODS = {
    SetScript = function(frame, script, fn) frame.scripts[script] = fn end,
    RegisterEvent = function(frame, event) frame.events[event] = true end,
    UnregisterAllEvents = function(frame) for event in pairs(frame.events) do frame.events[event] = nil end end,
    UnregisterEvent = function(frame, event) frame.events[event] = nil end,
    GetParent = function(frame) return rawget(frame, "parent") end,
    SetWidth = function(frame, w) frame.w = w end,
    SetHeight = function(frame, h) frame.h = h end,
    SetSize = function(frame, w, h) frame.w, frame.h = w, h end,
    GetWidth = function(frame) return rawget(frame, "w") or 300 end,
    GetHeight = function(frame) return rawget(frame, "h") or 24 end,
    SetText = function(frame, text) frame.text = text end,
    GetText = function(frame) return rawget(frame, "text") or "" end,
    IsShown = function(frame) return rawget(frame, "shown") ~= false end,
    SetTexture = function(frame, texture) frame.texture = texture end,
    SetTexCoord = function(frame, left, right, top, bottom)
        frame.texCoord = frame.texCoord or {}
        local coords = frame.texCoord
        coords[1], coords[2], coords[3], coords[4] = left, right, top, bottom
    end,
    SetPoint = function(frame, _, a, b, c)
        frame.pointX = type(a) == "number" and a or type(b) == "number" and b or c
        frame.pointY = type(a) == "number" and b or c
    end,
    IsVisible = function(frame)
        repeat
            if rawget(frame, "shown") == false then return false end
            frame = rawget(frame, "parent")
        until type(frame) ~= "table"
        return true
    end,
    Show = function(frame) frame.shown = true end,
    Hide = function(frame) frame.shown = false end,
    SetShown = function(frame, shown) frame.shown = shown and true or false end,
    CreateTexture = function(frame) return Frame(rawget(frame, "state"), frame) end,
    CreateMaskTexture = function(frame) return Frame(rawget(frame, "state"), frame) end,
    CreateFontString = function(frame) return Frame(rawget(frame, "state"), frame) end,
    -- The world map: maximised when a test says so.
    IsMaximized = function(frame)
        local state = rawget(frame, "state")
        return state ~= nil and state.mapMaximised == true
    end,
    -- Animations: groups and their steps, which play nothing here.
    CreateAnimationGroup = function(frame) return Frame(rawget(frame, "state"), frame) end,
    CreateAnimation = function(frame) return Frame(rawget(frame, "state"), frame) end,
    IsMouseOver = function(frame)
        local state = rawget(frame, "state")
        return state ~= nil and state.mouseOver == true
    end,
    -- Kept, so a test can tell what has the keyboard.
    SetFocus = function(frame)
        local state = rawget(frame, "state")
        if state then state.focus = frame end
    end,
    HasFocus = function(frame)
        local state = rawget(frame, "state")
        return state ~= nil and state.focus == frame
    end,
    -- Kept, so a test can tell which of the game's icons were shown.
    SetAtlas = function(frame, atlas)
        local state = rawget(frame, "state")
        if state then state.atlases[atlas] = true end
    end,
}
Frame = function(state, parent)
    return setmetatable({ scripts = {}, events = {}, state = state, parent = parent }, { __index = function(_, key)
        if key == "HookScript" then
            return function(frame, script, fn)
                state.hooks[#state.hooks + 1] = script
                if frame == state.worldMap then state.hooked[script] = fn end
            end
        end
        if METHODS[key] then return METHODS[key] end
        local measure = MEASURE_METHODS[key]
        if measure then return measure end
        -- Any other method does nothing; a field the code keeps on the frame (lower case) is
        -- nil until set, as on a real frame.
        if key:find("^%u") then return NOTHING end
    end })
end

-- The tooltips the stub answers with, made once.
local KNOWN_TOOLTIP = { lines = { { leftText = "Recipe" }, { leftText = "Already known" } } }
local EMPTY_TOOLTIP = { lines = {} }
local NO_PROFESSIONS = {}
-- Where you stand, as C_Map.GetPlayerMapPosition answers.
local STANDING_AT = { GetXY = function() return 0.42, 0.61 end }

-- language: none for English, else { code, L, instances, areas }: its catalog and the game's names.
local function fixture(settings, noBis, language)
    local state = {
        level = 20, instance = nil, combat = false, bisList = true,
        hooks = {}, frames = 0, printed = {}, waypoints = {}, mapOpened = nil, requested = {},
        refreshes = 0, made = {}, hooked = {}, logged = {}, watched = {}, objectives = {}, account = {}, guid = "Player-4613-006EB819", now = 1000, clock = 50,
        bis = {}, worn = {}, owned = {}, names = {}, sources = {}, looks = {},
        log = {}, repQuests = {}, readyQuests = {},
        sent = {}, timers = {}, pushed = {}, fonts = {}, atlases = {}, dressable = {}, hasLook = {}, buttons = {},
        cvars = { questLogOpen = "1" },
        bindings = {},
        said = {},
        standings = {}, rankRewards = {},
        currency = { name = "Honor", quantity = 1234, iconFileID = 1455894 },
    }
    state.tooltip = Frame(state)   -- the game's, kept so a test can read what it says
    -- The game's quest tracker: shown and its alpha, for a test to read.
    state.gameTracker = {
        shown = true, alpha = 1,
        IsShown = function(self) return self.shown end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false; state.gameHides = (state.gameHides or 0) + 1 end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        GetAlpha = function(self) return self.alpha end,
    }
    local values = {
        enabled = false, mapPanel = true, usableOnly = true, showChance = true,
        showAlliance = true, showHorde = true, showKills = true, shareRequests = true,
        showAppearance = false, showTips = true, missingBisOnly = false, myRecipes = true, showCosmetic = true,
        repQuestsOpen = true, bossTipOpen = true, bossQuestsOpen = true, bossAbilitiesOpen = true,
        showKeys = true, questHelp = false,
    }
    for k, v in pairs(settings or {}) do values[k] = v end
    -- The kit's module settings: Set tells every listener, as UI.ModuleSettings does.
    local listeners = {}
    local S = {}
    function S.Get(key) return values[key] end
    -- What the player set, and nothing for a key left at its default.
    function S.Raw(key) return values[key] end
    function S.Set(key, value)
        values[key] = value
        for i = 1, #listeners do listeners[i](key, value) end
    end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end

    local ns = { LOCALE = language and language.code or "enUS",
        L = language and language.L or dofile("Tools/regression/locale_stub.lua").L,
        Upper = string.upper, Lower = string.lower,
        MEDIA = dofile("Tools/regression/core_media.lua"),
        THEME = setmetatable({}, { __index = function() return WHITE end }),
        UI = { ModuleSettings = function(_, defaults) state.defaults = defaults; return S end,
            SlimScroll = function(parent)
                local scroll = Frame(state, parent)
                scroll.bar = Frame(state, parent)
                return scroll
            end,
            BuildSliderCore = function(parent)
                local track = Frame(state, parent)
                track.rail, track.fill, track.thumb = Frame(state, track), Frame(state, track), Frame(state, track)
                track.valueBox, track.valueFill = Frame(state, parent), Frame(state, parent)
                track.valueBorder = { _frame = Frame(state, parent) }
                track._refreshValue = function() end
                return track
            end,
            CloseOnEscape = function() end,
            -- The settings page, opened on a card: kept for a test to read.
            GoToSetting = function(_, _, feature) state.wentTo = feature end,
            -- The quest tracker's dungeon dropdown, kept for a test to pick from.
            BuildDropdownControl = function(parent, _, _, choices, order, get, set)
                local dropdown = Frame(state, parent)
                dropdown.values, dropdown.order, dropdown.get, dropdown.set = choices, order, get, set
                dropdown._refreshLabel = function() end
                state.dropdown = dropdown
                return dropdown
            end,
            STATUS = { untested = "" },
            RefreshPage = function() state.refreshes = state.refreshes + 1 end },
        QoLSettings = { Get = function(key) return key == "bis" and state.bisList end },
        Color = function(_, text) return text and ("|cffffffff" .. text .. "|r") or "|cffffffff" end,
        Apply = function() end,
        AccountSettings = function() return state.account end,
        UIScale = function() return 1 end,
        UIFontPath = function() return "font" end,
        -- Kept, so a test can read what was written.
        Font = function(parent)
            local font = Frame(state, parent)
            state.fonts[#state.fonts + 1] = font
            return font
        end,
        Solid = function(parent) return Frame(state, parent) end,
        -- As ns.Hairline and ns.PixelInset: whole-pixel sizing has no effect on these stubs.
        Hairline = function(region) return region end,
        PixelInset = function(region) return region end,
        -- As ns.Border: its frame, and a way to colour it.
        -- Its SetColor takes numbers, as the game's SetColorTexture does: a colour table errors.
        Border = function(parent) return { _frame = Frame(state, parent), SetColor = BORDER_SET_COLOR } end,
        AllowOffscreen = function() end,
        -- Its words and what a click does, kept for a test to press it.
        Button = function(parent, text, _, _, onClick)
            local button = Frame(state, parent)
            button.label, button.onClick = text, onClick
            state.buttons[#state.buttons + 1] = button
            return button
        end,
        BlackBorder = function(frame) return frame end,
        AccentBorder = function(frame) return frame end,
        BisListIsEmpty = function() return false end,
        OpenOptionsWindow = function(page) state.optionsOpened = page end,
        OpenBisWindow = function() state.bisOpened = true end,
        SetButtonText = function() end,
        Tooltip = function() end,
        ThemeTint = function() return WHITE end,
        NewSearchBox = function(parent, _, onSearch)
            local box = Frame(state, parent)
            state.searchBox, state.onSearch = box, onSearch
            box.border = Frame(state, box)   -- as ns.NewEditBox gives an edit box
            box.hint = Frame(state, box)     -- and ns.NewSearchBox its hint
            return box
        end,
        Print = function(text) state.printed[#state.printed + 1] = text end,
        GamepadStandDown = function() return false end,
        GamepadOwnsPanels = function() return false end,
        -- The copy box: kept, so a test can read what it was given to copy.
        ShowCopyBox = function(title, text) state.copied = { title = title, text = text } end,
        ShowCopyLine = function(title, text) state.copied = { title = title, text = text } end,
        -- The copy card: what the Forever database's page would be, its link selected.
        ShowCopyCard = function(kind, _, id, title, mode)
            state.copied = { title = title, text = mode == "url" and "https://www.wowhead.com/forever/" .. kind .. "=" .. id }
        end,
        PlaceWaypoint = function(title, map, x, y, note)
            state.waypoints[#state.waypoints + 1] = { title = title, map = map, x = x, y = y, note = note }
            return true
        end,
        ToggleWaypoint = function(title, map, x, y, note)
            state.waypoints[#state.waypoints + 1] = { title = title, map = map, x = x, y = y, note = note, toggled = true }
            return true
        end,
        IsBisItem = not noBis and function(id) return state.bis[id] end or nil,
        TurnOnModule = function(addon) state.turnedOn = addon end,
        -- Every item goes in slot 1 or 2, like a ring.
        BisSlotsFor = function(id) return not (state.recipes and state.recipes[id]) and RING_SLOTS or nil end,
        -- Cloth only, so a mage can use cloth and anything without an armor type.
        ClassCanUse = function(class, facts)
            return class == "MAGE" and (facts[1] == 4 and (facts[2] == 0 or facts[2] == 1))
        end,
    }
    function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end
    local env = {
        _G = { NaowhForever = ns, ObjectiveTrackerFrame = state.gameTracker },
        strsplit = strsplit,
        strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function() return false end,
        -- You are a mage; a group member is what the test made them.
        UnitClass = function(unit)
            local member = state.party and state.party[tonumber(unit:match("^party(%d)$") or 0)]
            if member and member.class then return member.class, member.class end
            return "Mage", "MAGE"
        end,
        UnitGroupRolesAssigned = function(unit)
            if unit == "player" then return state.role or "NONE" end
            local member = state.party and state.party[tonumber(unit:match("^party(%d)$") or 0)]
            return member and member.role or "NONE"
        end,
        UnitIsUnit = function(a, b) return a == b end,
        GetNumGroupMembers = function() return state.party and #state.party + 1 or 0 end,
        C_ClassColor = { GetClassColor = function() return CLASS_COLOR end },
        UnitLevel = function() return state.level end,
        GetMaxLevelForPlayerExpansion = function() return state.maxLevel or 60 end,
        GetBuildInfo = function() return "1.60.1", "70205" end,
        UnitFactionGroup = function() return "Alliance" end,
        UnitRace = function() return "Human", "Human", 1 end,
        IsInInstance = function() return state.instance ~= nil, state.instance and (state.instance.kind or "party") end,
        LOOT_ITEM_SELF = "You receive loot: %s.",
        GetInstanceInfo = function()
            local i = state.instance or {}
            return i.name, nil, nil, nil, nil, nil, nil, i.id
        end,
        -- Only a language other than English asks; English has none to answer with.
        GetRealZoneText = function(id) return language.instances[id] or ("Mapa " .. id) end,
        C_CreatureInfo = { GetCreatureTypeInfo = function(id)
            return { name = id == 7 and (language and "Humanoide" or "Humanoid") or "Type " .. id }
        end },
        InCombatLockdown = function() return state.combat end,
        GetCursorPosition = function() return 0, 0 end,
        GetQuestLink = function(id)
            if state.noLink then return nil end
            return "|Hquest:" .. id .. "|h[Quest " .. id .. "]|h"
        end,
        -- The chat box: open while state.chatOpen.
        ChatFrameUtil = {
            InsertLink = function(link) state.inserted = link; return state.chatOpen == true end,
            GetActiveWindow = function() return state.chatOpen and {} or nil end,
        },
        GameTooltip_SetTitle = function(tooltip, text) tooltip.title = text end,
        SHARE_QUEST = "Share Quest",
        -- Key bindings, kept for a test to read: key -> action.
        GetBindingKey = function(action)
            for key, bound in pairs(state.bindings) do
                if bound == action then return key end
            end
        end,
        GetBindingAction = function(key) return state.bindings[key] or "" end,
        SetBinding = function(key, action) state.bindings[key] = action end,
        SaveBindings = function() state.bindingsSaved = true end,
        GetCurrentBindingSet = function() return 1 end,
        GetSubZoneText = function() return state.subzone or "" end,
        -- The game's settings, kept for a test to read.
        GetCVar = function(name) return state.cvars[name] end,
        SetCVar = function(name, value) state.cvars[name] = tostring(value) end,
        IsControlKeyDown = function() return state.ctrl == true end,
        LOCALIZED_CLASS_NAMES_MALE = { WARLOCK = "Warlock", PALADIN = "Paladin", MAGE = "Mage" },
        hooksecurefunc = function(t, key, fn)
            local orig = t[key]
            t[key] = function(...) orig(...); fn(...) end
        end,
        CreateFrame = function(_, _, parent)
            state.frames = state.frames + 1
            local frame = Frame(state, parent)
            state.made[#state.made + 1] = frame
            return frame
        end,
        Mixin = function(target, ...)
            for i = 1, select("#", ...) do
                for k, v in pairs((select(i, ...))) do target[k] = v end
            end
            return target
        end,
        CreateColor = function() return Frame(state) end,
        CreateAtlasMarkup = function(atlas) return "|A:" .. atlas .. "|a" end,
        UIParent = Frame(state),
        GameTooltip = state.tooltip,
        GameTooltip_Hide = function() end,
        GameTooltip_SuppressAutomaticCompareItem = function(tip) tip.suppressAutomaticCompareItem = true end,
        -- A home group, not an instance one (the dungeon finder's).
        IsInGroup = function(category) return state.party ~= nil and category ~= 2 end,
        IsInRaid = function() return false end,
        LE_PARTY_CATEGORY_INSTANCE = 2,
        GetNumSubgroupMembers = function() return state.party and #state.party or 0 end,
        UnitName = function(unit)
            if unit == "player" then return "Die Man" end
            if unit == "npc" then return state.vendor end
            local member = state.party and state.party[tonumber(unit:match("^party(%d)$") or 0)]
            return member and member.name
        end,
        QuestLogPushQuest = function(index) state.pushed[#state.pushed + 1] = index end,
        Enum = { SendAddonMessageResult = { Success = 0 }, PvPRanks = { Rank_1 = 5 }, UIMapType = { Zone = 3 },
            TooltipDataType = { Item = 0 },
            InventoryType = { IndexHeadType = 1, IndexNeckType = 2, IndexShoulderType = 3, IndexChestType = 5,
                IndexWaistType = 6, IndexLegsType = 7, IndexFeetType = 8, IndexWristType = 9, IndexHandType = 10,
                IndexFingerType = 11, IndexTrinketType = 12, IndexWeaponType = 13, IndexShieldType = 14,
                IndexRangedType = 15, IndexCloakType = 16, Index2HweaponType = 17, IndexRobeType = 20,
                IndexWeaponmainhandType = 21, IndexWeaponoffhandType = 22, IndexHoldableType = 23,
                IndexThrownType = 25, IndexRangedrightType = 26, IndexRelicType = 28 } },
        -- Item tooltip post-calls, kept for a test to call.
        TooltipDataProcessor = { AddTooltipPostCall = function(_, fn)
            state.itemTips = state.itemTips or {}
            state.itemTips[#state.itemTips + 1] = fn
        end },
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        C_ChatInfo = {
            InChatMessagingLockdown = function() return state.locked end,
            -- Chat lines sent, kept for a test to read.
            SendChatMessage = function(text, channel) state.said[#state.said + 1] = { text = text, channel = channel } end,
            RegisterAddonMessagePrefix = function(prefix) state.prefix = prefix end,
            SendAddonMessage = function(prefix, text, channel)
                state.sent[#state.sent + 1] = { prefix = prefix, text = text, channel = channel }
                return 0
            end,
        },
        GetQuestLogQuestText = function() return "Bring me the head of Edwin VanCleef.", "0/1 Head" end,
        GetNumQuestLogChoices = function() return 1 end,
        GetQuestLogChoiceInfo = function() return "Chausses of Westfall", 134400, 1, 3, true, 6087 end,
        GetNumQuestLogRewards = function() return 0 end,
        GetQuestLogRewardInfo = function() end,
        GetQuestLogRewardXP = function() return 9750 end,
        GetQuestLogRewardMoney = function() return 0 end,
        BreakUpLargeNumbers = function(n) return tostring(n) end,
        QuestUtils_IsQuestWatched = function(id) return state.watched[id] == true end,
        IsMouseButtonDown = function() return false end,
        -- The level asked about kept, for a test to read.
        GetQuestDifficultyColor = function(level) state.difficultyAsked = level; return { r = 1, g = 1, b = 1 } end,
        QuestDifficultyColors = { trivial = {} },
        UnitFullName = function(unit)
            if unit == "player" then return "Die Man" end
            local member = state.party and state.party[tonumber(unit:match("^party(%d)$") or 0)]
            return member and member.name
        end,
        GetNormalizedRealmName = function() return "Realm" end,
        UnitGUID = function(unit)
            if unit == "player" then return state.guid end
            local member = state.party and state.party[tonumber(unit:match("^party(%d)$") or 0)]
            return member and member.guid
        end,
        time = function() return state.now end,
        date = os.date,   -- the game's date is the same function
        GetTime = function() return state.clock end,
        WorldMapFrame = Frame(state),
        EventUtil = { ContinueOnAddOnLoaded = function() end },
        -- A boss's abilities: every spell loaded, with a name and a line saying what it does.
        IsModifiedClick = function(kind) return kind == "CHATLINK" and state.shift == true end,
        C_Spell = { GetSpellName = function(id) return "Spell " .. id end,
            GetSpellLink = function(id) return "|Hspell:" .. id .. "|h[Spell " .. id .. "]|h" end,
            GetSpellTexture = function() return 136243 end,
            GetSpellDescription = function(id) return state.spellText and state.spellText[id] or "Hits the tank." end,
            IsSpellDataCached = function() return true end },
        -- The world map's pin kit, for the entrance pins: a provider's map is the world map.
        CreateFromMixins = function(...)
            local t = {}
            for i = 1, select("#", ...) do
                for k, v in pairs((select(i, ...))) do t[k] = v end
            end
            return t
        end,
        MapCanvasPinMixin = {},
        MapCanvasDataProviderMixin = { GetMap = function() return state.worldMap end },
        CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end,
        C_Map = { OpenWorldMap = function(map) state.mapOpened = map end,
            -- A spot on a zone's map, and where it falls on another map: state.onMap scales
            -- the zone's spot onto the map shown (none for a map it is not on).
            GetWorldPosFromMapPos = function(map, pos) return 0, { x = pos.x, y = pos.y, map = map } end,
            GetMapPosFromWorldPos = function(_, world, map)
                local scale = state.onMap and state.onMap[map]
                if not scale then return nil end
                return 0, { GetXY = function() return world.x * scale, world.y * scale end }
            end,
            GetMapInfo = function(map)
                return state.mapInfo and state.mapInfo[map] or map == 52 and { name = "Westfall" } or nil
            end,
            GetBestMapForUnit = function() return state.standingOn end,
            GetAreaInfo = function(area) return language.areas[area] or ("Zona " .. area) end,
            GetPlayerMapPosition = function() return state.standingOn and STANDING_AT end },
        GetMerchantNumItems = function() return #(state.merchant or NO_PROFESSIONS) end,
        GetMerchantItemID = function(i) return state.merchant[i] end,
        C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
        C_Item = {
            IsEquippedItem = function(id) return state.worn[1] == id or state.worn[2] == id end,
            GetItemCount = function(id) return state.owned[id] or 0 end,
            IsDressableItemByID = function(id) return state.dressable[id] == true end,
            GetItemNameByID = function(id) return state.names[id] end,
            GetItemInfo = function(id) return state.names[id], nil, state.names[id] and 3 end,
            -- What the test says an item is: its type's words and the slot it goes in; or a
            -- recipe (no slot, the game's class 9 and its profession's subclass); else gear.
            GetDetailedItemLevelInfo = function(link) return state.itemLevels and state.itemLevels[link] end,
            GetItemInfoInstant = function(id)
                local slot = state.slots and state.slots[id]
                if slot then return id, nil, "Game's words", slot end
                local recipe = state.recipes and state.recipes[id]
                if recipe then return id, "Recipe", recipe.words, "", 134400, 9, recipe.sub end
                -- A cosmetic item: armor, the game's subclass 5.
                if state.cosmetic and state.cosmetic[id] then return id, nil, nil, "INVTYPE_SHOULDER", 134400, 4, 5 end
                -- A crafted item: { the game's class, its slot }.
                local made = state.crafted and state.crafted[id]
                if made then return id, nil, nil, made[2], 134400, made[1] end
                return id, nil, nil, "INVTYPE_CHEST"
            end,
            GetItemIconByID = function() return 134400 end,
            GetItemQualityColor = function() return 1, 1, 1, "ffffffff" end,
            GetItemQualityByID = function() return nil end,
            RequestLoadItemDataByID = function(id) state.requested[#state.requested + 1] = id end,
            IsItemDataCachedByID = function() return true end,
        },
        C_QuestLog = {
            IsOnQuest = function(id) return state.onQuest ~= nil and state.onQuest[id] == true end,
            IsComplete = function() return false end,
            IsQuestFlaggedCompleted = function() return state.allDone == true end,
            GetTitleForQuestID = function() return nil end,
            GetQuestDifficultyLevel = function() return 0 end,
            IsUnitOnQuest = function(unit, id)
                local member = state.party and state.party[tonumber(unit:match("^party(%d)$") or 0)]
                return member ~= nil and member.quests[id] == true
            end,
            -- One quest in the log, for the quest panel.
            GetLogIndexForQuestID = function(id) return state.logged[id] end,
            GetSelectedQuest = function() return state.selected end,
            SetSelectedQuest = function(id) state.selected = id end,
            GetQuestObjectives = function() return state.objectives end,
            IsPushableQuest = function(id) return state.unpushable ~= id end,
            CanAbandonQuest = function() return true end,
            AddQuestWatch = function(id) state.watched[id] = true end,
            RemoveQuestWatch = function(id) state.watched[id] = nil end,
            SetAbandonQuest = function() state.abandonSet = state.selected end,
            AbandonQuest = function() state.abandoned = state.abandonSet end,
            RequestLoadQuestByID = function() end,
            -- The log as the test set it: quest IDs, which faction each raises, which are ready.
            GetNumQuestLogEntries = function() return #state.log end,
            GetQuestIDForLogIndex = function(i) return state.log[i] end,
            DoesQuestAwardReputationWithFaction = function(id, faction) return state.repQuests[id] == faction end,
            ReadyForTurnIn = function(id) return state.readyQuests[id] == true end,
        },
        C_TransmogCollection = {
            GetItemInfo = function(id) return nil, state.sources[id] end,
            GetAppearanceInfoBySource = function(source) return state.looks[source] end,
            PlayerHasTransmogByItemInfo = function(id) return state.hasLook[id] == true end,
        },
        GetInventoryItemID = function(_, slot) return state.worn[slot] end,
        -- A worn item's link is its ID here, and its item level what the test set for it.
        GetInventoryItemLink = function(_, slot) return state.worn[slot] end,
        -- Your standing with each faction, and your PvP rank: what the test set, as the game's
        -- own tables (made by the test, so the stubs make no garbage).
        C_Reputation = { GetFactionDataByID = function(id) return state.standings[id] end },
        C_MajorFactions = {
            GetMajorFactionProgressionInfo = function() return state.rank end,
            GetRenownRewardsForLevel = function(_, rank) return state.rankRewards[rank] end,
        },
        -- Forever has the money string here only; the global GetCoinTextureString is not loaded.
        C_CurrencyInfo = { GetCurrencyInfo = function() return state.currency end,
            GetCoinTextureString = function(n) return tostring(n) end },
        C_SeasonInfo = { GetTimeUntilCurrentPVPSeasonEnd = function() return 3 * 86400 + 60 end },
        GetCurrentArenaSeason = function() return 1 end,
        GetMoney = function() return state.money or 0 end,
        -- Your professions: state.professions lists their skill lines (Tailoring 197...).
        GetProfessions = function()
            local p = state.professions or NO_PROFESSIONS
            return p[1] and 1, p[2] and 2
        end,
        GetProfessionInfo = function(index)
            return "Profession", 134400, 300, 300, 0, 0, (state.professions or NO_PROFESSIONS)[index]
        end,
        -- An item's tooltip: "Already known" for the recipes in state.known.
        C_TooltipInfo = { GetItemByID = function(id)
            return state.known and state.known[id] and KNOWN_TOOLTIP or EMPTY_TOOLTIP
        end, GetMerchantItem = function(i)
            return state.merchantTips and state.merchantTips[i] or EMPTY_TOOLTIP
        end },
        GetLocale = function() return "enUS" end,
        ITEM_SPELL_KNOWN = "Already known",
        SOUNDKIT = { MAP_PING = 3175 },
        UnitSex = function() return 2 end,
        GetText = function(token) return token end,
        PVP_RANK_0_NAME = "Unranked",
        PVP_RANK_REWARDS_VENDOR_ALLIANCE = "Rank rewards are sold in Stormwind.",
    }
    setmetatable(env, { __index = _G })
    state.G = env._G
    state.worldMap = env.WorldMapFrame
    state.env = env
    local senders = assert(loadfile("Core/Senders.lua"))
    setfenv(senders, env)
    senders()
    -- The feature switches the Journal's settings read their defaults from.
    local features = assert(loadfile("Core/Features.lua"))
    setfenv(features, env)
    features()
    local classCanUse, slotsFor = ns.ClassCanUse, ns.BisSlotsFor
    for _, path in ipairs(files) do
        if path:find("^NaowhForever_DungeonJournal/") and ns.Shared.Items.ClassCanUse ~= classCanUse then
            ns.Shared.Items.ClassCanUse, ns.Shared.Items.SlotsFor = classCanUse, slotsFor
        end
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    -- A context menu: its entries kept (text and what a click does) for a test to click.
    function ns.ContextMenu(_, build)
        local entries = {}
        local root = {
            CreateTitle = function(_, text) entries.title = text end,
            CreateDivider = function() end,
            CreateButton = function(_, text, onClick)
                local item = { text = text, click = onClick, enabled = true,
                    SetEnabled = function(self, on) self.enabled = on end,
                    SetTooltip = function(self, tip) self.tooltip = tip end,
                    SetTitleAndTextTooltip = function() end }
                entries[#entries + 1] = item
                return item
            end,
        }
        build(nil, root)
        state.menu = entries
    end
    return ns, state, S
end

-------------------------------------------------------------------------------
--  The data
-------------------------------------------------------------------------------
do
    local ns, state = fixture()
    local J = ns.Journal
    local questNames = {}
    for _, entry in ipairs(J.QuestData) do questNames[entry.name] = true end

    local keys, npcs, bosses, items, entrances = {}, {}, 0, 0, 0
    for _, dungeon in ipairs(J.Dungeons()) do
        check("dungeon key is unique: " .. dungeon.key, not keys[dungeon.key])
        keys[dungeon.key] = true
        check("dungeon is named as the quest data names it: " .. dungeon.name, questNames[dungeon.name])
        check("dungeon joined with its quest entry: " .. dungeon.name, dungeon.quests ~= nil)
        check("dungeon knows the zone of its entrance: " .. dungeon.name, type(dungeon.zone) == "string")
        check("and whose ground it is: " .. dungeon.name, dungeon.territory == "Alliance"
            or dungeon.territory == "Horde" or dungeon.territory == "Contested")
        local entrance = dungeon.entrance
        if entrance then
            entrances = entrances + 1
            check("entrance is on a map: " .. dungeon.name, type(entrance.map) == "number" and entrance.map > 0)
            check("entrance is a spot on it: " .. dungeon.name, entrance.x > 0 and entrance.x < 100
                and entrance.y > 0 and entrance.y < 100)
        end
        local here = {}
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                bosses = bosses + 1
                check("boss has a name in " .. dungeon.name, type(boss.name) == "string" and boss.name ~= "")
                if boss.npc then
                    check("boss listed once: " .. boss.name, not here[boss.npc])
                    here[boss.npc], npcs[boss.npc] = boss, true
                end
                if boss.chance then
                    check("a chance for every item: " .. boss.name, #boss.chance == #boss.loot)
                    for _, c in ipairs(boss.chance) do
                        check("chance is a percent, 0 when unknown: " .. boss.name, c >= 0 and c <= 100)
                    end
                end
                local listed = {}
                for _, id in ipairs(boss.loot or {}) do
                    items = items + 1
                    check("item " .. id .. " listed once on " .. boss.name .. " (" .. dungeon.name .. ")", not listed[id])
                    listed[id] = true
                    local facts = J.Items[id] or J.NotYet[id]
                    check("item " .. id .. " has its facts", facts ~= nil)
                    check("item " .. id .. " is uncommon or better", facts[J.FACT.QUALITY] >= 2)
                    check("item " .. id .. " is in Forever or not yet, not both", not (J.Items[id] and J.NotYet[id]))
                    if J.NotYet[id] then
                        check("item " .. id .. " not in Forever yet has its icon and name",
                            facts[J.FACT.ICON] > 0 and type(facts[J.FACT.NAME]) == "string" and facts[J.FACT.NAME] ~= "")
                    end
                end
                -- A tip is shared in chat whole: "Naowh's tip for <boss>: <tip>" in one message.
                local tip = J.Tip(boss)
                if tip then
                    check("tip for " .. boss.name .. " is one plain line", tip ~= "" and not tip:find("[\r\n|]"))
                    check("tip for " .. boss.name .. " fits one chat message",
                        #("Naowh's tip for %s: %s"):format(boss.name, tip) <= 255)
                end
            end
        end
    end
    check("every quest dungeon has a journal entry", #J.Dungeons() == #J.QuestData)
    local new, raids = 0, {}
    for _, dungeon in ipairs(J.Dungeons()) do
        if dungeon.raid then
            raids[dungeon.key] = dungeon.raid
        elseif dungeon.new then
            new = new + 1
        end
    end
    check("the nine dungeons new in Forever are marked new", new == 9)
    -- WoW Forever's mark: what Forever's tables have and Classic Era's do not, so not a quest
    -- Forever reworked on its classic ID (Friend of the Library, 78150).
    local Parts = ns.Shared.Parts
    check("a boss of a dungeon new in Forever is Forever's", J.IsForeverBoss(J.Get("AlcazPrison").wings[1].bosses[1]))
    check("a classic boss is not", not J.IsForeverBoss(J.Get("RagefireChasm").wings[1].bosses[1]))
    check("a quest new in Forever is, a changed or classic one not", Parts.IsForever("quests", 95195)
        and not Parts.IsForever("quests", 78150) and not Parts.IsForever("quests", 1012))
    check("an item new in Forever is, a classic one not", Parts.IsForever("items", 273023)
        and not Parts.IsForever("items", 5813))
    check("nothing is without an ID", not Parts.IsForever("npcs", nil))
    check("the mark in text is made once per size", Parts.ForeverInline(12) == Parts.ForeverInline(12)
        and Parts.ForeverLine():find("Forever|r", 1, true))
    -- The raids announced for Forever, and only those: the classic ones wait in the data.
    check("the three announced raids, with their sizes", raids.OnyxiasLair == 40 and raids.BarrowDeeps == 10
        and raids.HyjalSummit == 20)
    check("no raid that is not announced", raids.MoltenCore == nil and raids.Naxxramas == nil)
    check("a raid's page says what is not known yet", J.Get("HyjalSummit").note ~= nil)
    check("a raid for one level shows it once", J.LevelRange(J.Get("OnyxiasLair")) == "60")
    check("a dungeon shows its range", J.LevelRange(J.Get("RagefireChasm")) == "13-18")
    check("Onyxia's kills are counted", J.Get("OnyxiasLair").wings[1].bosses[1].encounters[1] == 1084)
    -- A quest that starts from a drop inside its dungeon has its waypoint at the entrance.
    local glowing
    for _, entry in ipairs(J.Quests.List(J.Get("WailingCaverns").quests, {}, {})) do
        if entry.quest[1] == 6981 then glowing = entry end
    end
    check("The Glowing Shard is listed", glowing ~= nil)
    local tome, QUEST = J.Quests.ByID(94984), J.C.QUEST
    check("a quest with a giver per faction shows only the player's own", tome
        and tome[QUEST.WHERE] == "Riverglades - Ashe Amberhall (66.7, 81)" and tome[QUEST.MAP] == 2548
        and tome[QUEST.X] == 66.7 and tome[QUEST.Y] == 81.0)
    check("and has a waypoint: the dungeon's entrance", glowing.canWaypoint)
    check("hundreds of bosses", bosses > 150)
    check("the entrances with a source that matches Forever's map", entrances == 35)
    local boss, dungeon = J.Boss(639)
    check("the boss loot window finds a boss by its NPC ID", boss and boss.name == "Edwin VanCleef"
        and dungeon.key == "Deadmines")
    check("and nothing for an NPC that is no boss", J.Boss(1) == nil)
    check("hundreds of loot entries", items > 300)
    local tips = 0
    for npc in pairs(J.Tips) do
        check("tip " .. npc .. " belongs to a listed boss", npcs[npc])
        tips = tips + 1
    end
    check("nearly every boss has a tip", tips > 150)
    check("a boss with no NPC ID has no tip", J.Tip({ name = "Nobody" }) == nil)
    local withAbilities = 0
    for _ in pairs(J.Abilities) do withAbilities = withAbilities + 1 end
    check("hundreds of bosses have abilities", withAbilities > 150)

    -- The Filters menu and the settings page are both built from J.OPTION_GROUPS.
    local labels, offered = {}, {}
    for _, group in ipairs(J.OPTION_GROUPS) do
        check("an option group has a title", type(group.title) == "string" and #group.options > 0)
        for _, option in ipairs(group.options) do
            check("option " .. option.key .. " is a setting", state.defaults[option.key] ~= nil)
            check("option " .. option.key .. " is offered once", not offered[option.key])
            check("option label " .. option.label .. " is unique", not labels[option.label])
            check("option " .. option.key .. " says what it does", type(option.tooltip) == "string"
                and option.tooltip ~= "")
            offered[option.key], labels[option.label] = true, true
        end
    end
    print(("  %d dungeons, %d bosses, %d loot entries, %d tips"):format(#J.Dungeons(), bosses, items, tips))
end

-------------------------------------------------------------------------------
--  Where you are, and the way in
-------------------------------------------------------------------------------
do
    local ns, state = fixture()
    local J = ns.Journal
    check("outside an instance, none", J.Current() == nil)
    state.instance = { id = 36, name = "The Deadmines" }
    check("the instance ID finds the dungeon", J.Current()[1].key == "Deadmines")
    check("and the page opens on it", J.Suggested().key == "Deadmines")
    state.instance = { id = 229, name = "Blackrock Spire" }
    check("Blackrock Spire is both halves", #J.Current() == 2)
    check("at its door, Lower first", J.Current()[1].key == "LowerBlackrockSpire")
    state.subzone = "Hordemar City"
    check("Hordemar City is on the way to both: still Lower", J.Current()[1].key == "LowerBlackrockSpire")
    state.subzone = "Hall of Binding"
    check("in the Hall of Binding, Upper first", J.Current()[1].key == "UpperBlackrockSpire"
        and #J.Current() == 2)
    state.subzone = ""
    check("a room with no subzone keeps the half you were last in", J.Current()[1].key == "UpperBlackrockSpire")
    state.subzone = "Skitterweb Tunnels"
    check("in the Skitterweb Tunnels, Lower", J.Current()[1].key == "LowerBlackrockSpire")
    state.instance, state.subzone = nil, nil
    check("outside, no dungeon", J.Current() == nil)
    -- Scarlet Monastery: four wings, one instance, the one you are in told by its map or subzone.
    state.instance = { id = 189, name = "Scarlet Monastery" }
    check("Scarlet Monastery is four wings", #J.Current() == 4
        and J.Get("ScarletMonasteryLibrary").name == "Scarlet Monastery - Library")
    check("the old single dungeon is gone", J.Get("ScarletMonastery") == nil)
    state.subzone = "Athenaeum"
    check("in the Athenaeum, the Library first", J.Current()[1].key == "ScarletMonasteryLibrary"
        and #J.Current() == 4)
    state.subzone = "Crusader's Chapel"
    check("in the Crusader's Chapel, the Cathedral", J.Current()[1].key == "ScarletMonasteryCathedral")
    state.subzone = "Somewhere Forever names otherwise"
    check("a subzone not known keeps the wing you were last in",
        J.Current()[1].key == "ScarletMonasteryCathedral")
    state.instance = nil
    J.Current()
    state.instance = { id = 189, name = "Scarlet Monastery" }
    check("and after leaving, a subzone not known: the first wing",
        J.Current()[1].key == "ScarletMonasteryGraveyard")
    state.subzone, state.standingOn = "", 305
    check("in a room with no subzone, the wing by its map: the Cathedral",
        J.Current()[1].key == "ScarletMonasteryCathedral")
    state.subzone, state.standingOn = "Athenaeum", 304
    check("the map wins over the subzone", J.Current()[1].key == "ScarletMonasteryArmory")
    state.subzone, state.standingOn = nil, nil
    check("each wing's quests: the Library's books", #J.Get("ScarletMonasteryLibrary").quests.quests == 5
        and #J.Get("ScarletMonasteryArmory").quests.quests == 0)
    check("each wing has its own map", J.Maps.ScarletMonasteryCathedral.floors == 1
        and J.Maps.ScarletMonasteryGraveyard.pins[3983] ~= nil)
    local function Pinned(key, npc)
        local map = J.Maps[key]
        local pin = map.pins[npc]
        return pin ~= nil and pin[1] == (map.floor or 1)
    end
    check("each wing's bosses stand on its own floor", Pinned("ScarletMonasteryLibrary", 3974)
        and Pinned("ScarletMonasteryLibrary", 6487) and Pinned("ScarletMonasteryArmory", 3975)
        and Pinned("ScarletMonasteryCathedral", 4542) and Pinned("ScarletMonasteryCathedral", 3976)
        and Pinned("ScarletMonasteryCathedral", 3977))
    state.instance = { id = 99999, name = "Shaper's Terrace" }
    check("a new dungeon is found by its name", J.Current()[1].key == "ShapersTerrace")
    state.instance = { id = 99998, name = "Onyxia's Lair", kind = "raid" }
    check("so is a raid", J.Current()[1].key == "OnyxiasLair")
    state.instance = { id = 99997, name = "Warsong Gulch", kind = "pvp" }
    check("a battleground is no dungeon", J.Current() == nil)
    state.instance = nil
    state.level = 40
    local levels = J.Levels(J.Suggested())
    check("outside, the page opens on one in range", levels[1] <= 40 and levels[2] >= 40)

    check("an entrance that is not known shows nothing", J.ShowEntrance({ name = "Nowhere" }) == false)

    check("and places no waypoint", #state.waypoints == 0)
    local deadmines = J.Get("Deadmines")
    check("a known entrance shows", J.ShowEntrance(deadmines))
    local placed = state.waypoints[1]
    check("with a waypoint on it", placed.map == deadmines.entrance.map and placed.x == deadmines.entrance.x
        and placed.note == " (entrance)")
    check("and the world map open on its zone", state.mapOpened == deadmines.entrance.map)
    state.mapOpened, state.combat = nil, true
    J.ShowEntrance(deadmines)
    check("in combat the waypoint still goes on", #state.waypoints == 2)
    check("but the map stays shut", state.mapOpened == nil)
end

-------------------------------------------------------------------------------
--  Names in the player's language
-------------------------------------------------------------------------------
do
    local env = { NaowhForever = { LOCALE = "esES" } }
    local chunk = assert(loadfile("NaowhForever_Locales/esES.lua"))
    setfenv(chunk, env)
    chunk()
    local catalog = env.NaowhForeverTranslation
    local spanish = {
        code = "esES",
        L = function(text, ...)
            local shown = catalog[text] or text
            if select("#", ...) > 0 then return shown:format(...) end
            return shown
        end,
        instances = { [36] = "Minas de la Muerte", [189] = "Monasterio Escarlata", [229] = "Cumbre de Roca Negra" },
        areas = { [40] = "Paramos de Poniente" },
    }
    local ns, state = fixture(nil, nil, spanish)
    local J = ns.Journal
    local deadmines = J.Get("Deadmines")
    check("a Spanish client names a dungeon as the game does", deadmines.name == "Minas de la Muerte"
        and deadmines.english == "The Deadmines")
    check("and its zone", deadmines.zone == "Paramos de Poniente")
    check("its quests still join by the English name", deadmines.quests ~= nil and deadmines.quests.name == "The Deadmines")
    check("a Scarlet Monastery wing keeps its wing, from the catalog",
        J.Get("ScarletMonasteryLibrary").name == "Monasterio Escarlata - Biblioteca"
        and J.Get("ScarletMonasteryArmory").name == catalog["Scarlet Monastery - Armory"])
    check("and so do the Blackrock Spires", J.Get("UpperBlackrockSpire").name == "Cumbre de Roca Negra Superior")
    check("a raid the game has no instance for yet keeps its English name", J.Get("HyjalSummit").name == "Hyjal Summit")
    for _, dungeon in ipairs(J.Dungeons()) do
        check("every other dungeon takes the game's name: " .. dungeon.english,
            not dungeon.instance or dungeon.name ~= dungeon.english)
    end
    state.instance = { id = 36, name = "Minas de la Muerte" }
    check("its instance still finds it", J.Current()[1].key == "Deadmines")

    local names = J.Names
    local greenskin = J.Boss(647)
    check("a boss takes its Spanish name by its NPC", names.npcs[647] and greenskin.name == names.npcs[647]
        and greenskin.name ~= "Captain Greenskin" and greenskin.english == "Captain Greenskin")
    local tribute
    for _, wing in ipairs(J.Get("DireMaul").wings) do
        for _, boss in ipairs(wing.bosses) do
            if boss.chest == 179564 then tribute = boss end
        end
    end
    check("a chest by its object", tribute.name == "Tributo a Gordok" and tribute.english == "Gordok Tribute")
    local argent
    for _, faction in ipairs(J.Factions("reputation")) do
        if faction.key == "ArgentDawn" then argent = faction end
    end
    check("a faction by its ID", argent.name == names.factions[529] and argent.name ~= "Argent Dawn")
    check("and its zone by the game's name for it", argent.zone == names.places["Eastern Plaguelands"])
    check("a place the data names in English", J.PlaceName("Duskwood") == names.places.Duskwood
        and J.PlaceName("The Deadmines") == "Minas de la Muerte" and J.PlaceName("Nowhere") == "Nowhere")
    state.instance = { id = 189, name = "Monasterio Escarlata" }
    state.subzone = "El Athenaeum"
    check("Scarlet Monastery's wing by its Spanish subzone", J.Current()[1].key == "ScarletMonasteryLibrary")
    state.instance, state.subzone = nil, nil
    local vanCleef = J.Boss(639)
    state.account.journalLoot = { [state.guid] = { { id = vanCleef.loot[1], link = "|Hitem:" .. vanCleef.loot[1] .. "|h",
        at = 1, dungeon = "Deadmines", boss = "Edwin VanCleef" } } }
    check("loot saved under the English name is still the boss's", #J.Looted.AllFrom(vanCleef, {}) == 1)
    J.View.OpenBossLoot(J.Boss(644), J.Get("Deadmines"))
    local about
    for _, made in ipairs(state.made) do
        local row = rawget(made, "about")
        if row and (rawget(row, "text") or ""):find(names.titles[644], 1, true) then about = rawget(row, "text") end
    end
    check("a boss's title in Spanish, and its kind the game's", about and about:find("Humanoide", 1, true) ~= nil)

    ns = fixture()
    deadmines = ns.Journal.Get("Deadmines")
    check("English keeps the data's names", deadmines.name == "The Deadmines" and deadmines.zone == "Westfall"
        and ns.Journal.Get("Stockade").name == "The Stockade" and ns.Journal.Boss(647).name == "Captain Greenskin"
        and ns.Journal.Names == nil and ns.Journal.PlaceName("Duskwood") == "Duskwood")

    local core = assert(io.open("Core/Core.lua", "rb")):read("*a")
    local xml = assert(io.open("NaowhForever_DungeonJournal/DungeonJournal.xml", "rb")):read("*a")
    for code in core:match("local LANGUAGES = (%b{})"):gmatch('"(%a+)"') do
        if code ~= "enUS" then
            check("the Journal loads its names in " .. code, xml:find("Data\\Names\\" .. code .. ".lua", 1, true) ~= nil)
        end
    end
end

-------------------------------------------------------------------------------
--  The small helpers
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture()
    local J = ns.Journal
    check("a creature's GUID gives its NPC ID", J.NpcID("Creature-0-4613-36-1234-639-0000ABCDEF") == 639)
    check("so does a vehicle's", J.NpcID("Vehicle-0-4613-36-1234-1234-0000ABCDEF") == 1234)
    check("a player's gives none", J.NpcID("Player-4613-006EB819") == nil)
    check("a pet's gives none", J.NpcID("Pet-0-4613-36-1234-165189-0100ABCDEF") == nil)

    J.TurnOn()
    check("opening the Journal turns it on", S.Get("enabled") == true)
    check("and its settings page follows", state.refreshes == 1)
    check("and says so once", #state.printed == 1)
    J.TurnOn()
    check("not again while it is on", #state.printed == 1)
    S.Set("enabled", false)
    S.Set("enabled", true)
    check("turned on, it binds no key: players set their own", next(state.bindings) == nil and not state.bindingsSaved)

    -- The faction switch: a dungeon inside one side's city is listed while that side is on;
    -- any other one always.
    local horde, alliance, contested = J.Get("RagefireChasm"), J.Get("Stockade"), nil
    local gnomeregan = J.Get("Gnomeregan")
    for _, dungeon in ipairs(J.Dungeons()) do
        if dungeon.territory == "Contested" then contested = contested or dungeon end
    end
    check("Ragefire Chasm is on Horde ground", horde.territory == "Horde")
    check("The Stockade on Alliance ground", alliance.territory == "Alliance")
    check("both sides listed by default", J.FactionShown(horde) and J.FactionShown(alliance))
    S.Set("showHorde", false)
    check("Horde off hides Horde ground", not J.FactionShown(horde) and J.FactionShown(alliance))
    check("a raid is listed whichever side is off", J.FactionShown(J.Get("OnyxiasLair")))
    check("some dungeons are on contested ground", contested ~= nil)
    S.Set("showAlliance", false)
    check("which is listed with either side off", J.FactionShown(contested))
    check("Gnomeregan is on Alliance ground, outside a city", gnomeregan.territory == "Alliance")
    check("so it is listed with Alliance off", J.FactionShown(gnomeregan) and not J.FactionShown(alliance))
    S.Set("showAlliance", true)
    S.Set("showHorde", true)

    local Columns, St = J.View.Columns, J.Style
    for _, width in ipairs({ 100, 340, 560, 700, 1000, 3000 }) do
        local columns, w = Columns(width)
        check("at least one card across at " .. width, columns >= 1 and columns <= St.MAX_COLUMNS)
        check("the cards fit across at " .. width, columns * w + St.CARD_GAP * (columns - 1) <= width)
        check("a second card only where both are wide enough at " .. width, columns == 1 or w >= St.CARD_MIN_W)
    end
    check("a narrow view is one card as wide as it", select(2, Columns(300)) == 300)
    check("a wide one stops at the most across", Columns(5000) == St.MAX_COLUMNS)

    local Plain = J.View.Parts.Plain
    check("a where line loses its colors and has dots for dashes",
        Plain("|cffffd100Ratchet|r - Crane Operator") == "Ratchet" .. St.PLACE_DOT .. "Crane Operator")
    check("a line with neither is unchanged", Plain("Plain place") == "Plain place")
end

-------------------------------------------------------------------------------
--  The loot rules
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture()
    local J, Loot = ns.Journal, ns.Journal.Loot
    local filters = Loot.ReadFilters({})
    local cloth, leather
    for id, facts in pairs(J.Items) do
        if facts[1] == 4 and facts[2] == 1 then cloth = cloth or id end
        if facts[1] == 4 and facts[2] == 2 then leather = leather or id end
    end
    check("a mage can use cloth", Loot.Usable(cloth))
    check("but not leather", not Loot.Usable(leather))
    check("an item the journal does not know is usable", Loot.Usable(1))
    check("My Class Only hides leather", not Loot.Shown(leather, filters))
    S.Set("usableOnly", false)
    check("the filters are what was read, not the setting now", not Loot.Shown(leather, filters))
    Loot.ReadFilters(filters)
    check("and read again they show it", Loot.Shown(leather, filters))

    local boss = { loot = { 101, 102, 103 } }
    state.bis = { [101] = 1, [102] = 2 }
    check("a boss counts its BiS, pick 1 only", Loot.BossBis(boss) == 1)
    check("a boss with no loot counts none", Loot.BossBis({}) == 0)

    -- On your list: higher on it than what you wear in a slot it fits. Missing BiS Only goes
    -- by that; the Upgrade mark only over a piece of your list, the star saying the rest.
    state.bis = { [201] = 2, [202] = 3, [203] = 1 }
    state.worn = { 202, 203 }
    check("a #2 beats the #3 you wear in one of its slots", Loot.BisUpgrade(201) and Loot.Upgrade(201))
    state.worn = { 203, 203 }
    check("not your BiS in both slots", not Loot.BisUpgrade(201) and not Loot.Upgrade(201))
    state.worn = { 203 }
    check("an empty slot takes anything on the list", Loot.BisUpgrade(201))
    check("with its star saying so, no Upgrade mark too", not Loot.Upgrade(201))
    state.worn = { 999, 203 }
    check("something off the list is beaten by any pick", Loot.BisUpgrade(202))
    check("its star says that too", not Loot.Upgrade(202))
    state.worn = { 201, 202 }
    check("never what you have on", not Loot.BisUpgrade(201) and not Loot.Upgrade(201))
    check("never an item off the list, for your BiS", not Loot.BisUpgrade(999))

    -- Off your list: gear your class can use with a higher item level than yours there.
    local items, levels, yourLevel = ns.Journal.Items, {}, state.level
    items[998] = { 4, 0, 60, 55, 3 }
    state.itemLevels, state.level = levels, 55
    state.worn, levels[999] = { 999, 999 }, 50
    check("a higher item level than what you wear is an upgrade", Loot.Upgrade(998))
    levels[999] = 62
    check("a lower one is not", not Loot.Upgrade(998))
    state.worn = { 999 }
    check("an empty slot takes it", Loot.Upgrade(998))
    state.level = 54
    check("not one you cannot wear yet at your level", not Loot.Upgrade(998))
    state.level = 55
    state.worn, levels[203] = { 203, 203 }, 40
    check("never over a piece of your list", not Loot.Upgrade(998))
    state.worn = {}
    check("not one the Journal has no item level for", not Loot.Upgrade(997))
    -- Upgrades Only lists just those.
    state.worn, levels[999] = { 999, 999 }, 50
    S.Set("upgradesOnly", true)
    Loot.ReadFilters(filters)
    check("Upgrades Only lists an upgrade", Loot.Shown(998, filters))
    levels[999] = 70
    check("and hides the rest", not Loot.Shown(998, filters) and not Loot.Shown(203, filters))
    S.Set("upgradesOnly", false)
    Loot.ReadFilters(filters)
    check("off, it hides nothing", Loot.Shown(998, filters))
    items[998], state.itemLevels, state.level = nil, nil, yourLevel

    -- Missing BiS: an upgrade you do not have in your bags or bank.
    state.worn = { 202, 203 }
    check("an upgrade you do not have is missing", Loot.Missing(201))
    state.owned[201] = 1
    check("one in your bags or bank is not", not Loot.Missing(201))
    state.owned[201] = nil
    S.Set("missingBisOnly", true)
    Loot.ReadFilters(filters)
    check("Missing BiS Only lists a missing one", Loot.Shown(201, filters))
    check("and hides the rest", not Loot.Shown(999, filters))
    state.bisList = false
    Loot.ReadFilters(filters)
    check("with the BiS List off it filters nothing", Loot.Shown(999, filters) and not filters.missingBis)
    state.bisList = true
    S.Set("missingBisOnly", false)
    Loot.ReadFilters(filters)
    state.bis = { [101] = 1, [102] = 2 }

    local rare = { rare = true, loot = { 101 } }
    local dungeon = { wings = { { bosses = { boss, rare } } } }
    check("the dungeon counts its rares, always listed", Loot.DungeonBis(dungeon, filters) == 2)
    check("none of them had", select(2, Loot.DungeonBis(dungeon, filters)) == 0)
    state.owned[101] = 1
    check("and each one you have counted: in your bags", select(2, Loot.DungeonBis(dungeon, filters)) == 2)
    state.owned[101] = nil

    -- Looks: nil for an item with none (a ring), else whether you have it.
    state.sources = { [101] = 11, [102] = 12, [103] = 13 }
    state.looks = { [11] = { appearanceIsCollected = true }, [12] = { sourceIsCollected = false },
        [13] = { appearanceIsCollected = false, sourceIsCollected = false } }
    check("a look you have", Loot.Appearance(101) == true)
    check("a look you do not", Loot.Appearance(102) == false)
    check("no look to collect", Loot.Appearance(104) == nil)
    -- One the game has no appearance for, though you can wear it: whether you have it.
    state.dressable[105], state.dressable[106], state.hasLook[106] = true, true, true
    check("a wearable item with no appearance you do not have is a new look", Loot.Appearance(105) == false)
    check("and one you have is not", Loot.Appearance(106) == true)
    check("the dungeon counts the looks you do not have", Loot.DungeonNewLooks(dungeon, filters) == 2)
    check("and the items with a look at all", select(2, Loot.DungeonNewLooks(dungeon, filters)) >= 2)

    -- Names: asked for while the client has yet to load them, kept in lower case once it has.
    check("an unloaded name is nil", Loot.LowerName(101) == nil)
    check("and its load is asked for", state.requested[1] == 101)
    state.names[101] = "Cowl of the Magus"
    check("a loaded one is in lower case", Loot.LowerName(101) == "cowl of the magus")
    state.names[101] = nil
    check("and kept", Loot.LowerName(101) == "cowl of the magus")
    ns.Shared.Items.Refuse(4242)
    local asked = #state.requested
    check("a name the server would not send: nil", Loot.LowerName(4242) == nil)
    check("and not asked for again", #state.requested == asked)
end

-------------------------------------------------------------------------------
--  The dungeon page's header: previous and next dungeon, and Find Group
-------------------------------------------------------------------------------
do
    local ns, state = fixture({ enabled = true })
    ns.Apply()
    local J = ns.Journal
    local deadmines = J.Get("Deadmines")
    local function Header(dungeon)
        for _, frame in ipairs(state.made) do
            if rawget(frame, "previous") and rawget(frame, "dungeon") == dungeon and rawget(frame, "shown") ~= false then
                return frame
            end
        end
    end
    ns.OpenJournalWindow(deadmines)
    local header = Header(deadmines)
    local after, before = J.DungeonList.Next(deadmines, 1), J.DungeonList.Next(deadmines, -1)
    check("the header has a next and a previous dungeon", header and rawget(header.next, "shown") ~= false
        and rawget(header.previous, "shown") ~= false)
    check("each names where it goes", header.next.target == after and header.next.tip:find(after.name, 1, true)
        and header.previous.target == before and header.previous.tip:find(before.name, 1, true))
    header.next.scripts.OnClick(header.next)
    check("next goes as Down does", Header(after) ~= nil)
    Header(after).previous.scripts.OnClick(Header(after).previous)
    check("previous comes back as Up does", Header(deadmines) ~= nil)
    check("without the Group Finder, no Find Group", rawget(header.find, "shown") == false)
    local on, pick = true, nil
    ns.GroupFinder = {
        On = function() return on end,
        Search = { Activities = function(list)
            list[1], list[2] = 11, 12
            return 2
        end },
        Listings = { DungeonOf = function(id) return id == 12 and "Deadmines" or "Stockade" end },
    }
    ns.OpenGroupFinder = function(activity) pick = activity end
    ns.OpenJournalWindow(deadmines)
    header = Header(deadmines)
    check("with it on, Find Group beside the entrance", rawget(header.find, "shown") ~= false
        and rawget(header.find.text, "text") == "Find Group")
    header.find.scripts.OnClick(header.find)
    check("which opens it searching this dungeon's activity", pick == 12)
    ns.OpenJournalWindow(J.Get("WailingCaverns"))
    check("a dungeon it has no activity for has none", rawget(Header(J.Get("WailingCaverns")).find, "shown") == false)
    on = false
    ns.OpenJournalWindow(deadmines)
    check("and none while the Group Finder is off", rawget(Header(deadmines).find, "shown") == false)
    ns.GroupFinder, ns.OpenGroupFinder = nil, nil
end

-------------------------------------------------------------------------------
--  Cost: counting over every dungeon, as the list and the page header do
-------------------------------------------------------------------------------
local function Measure(label, budget, fn)
    -- Shared CI runners run these about 1.5x slower than a desktop, and vary.
    if os.getenv("CI") then budget = budget * 2 end
    fn()   -- warm up
    local runs = 200
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    local start = os.clock()
    for _ = 1, runs do fn() end
    local ms = (os.clock() - start) * 1000 / runs
    local kb = (collectgarbage("count") - before) / runs
    collectgarbage("restart")
    print(("  %s: %.3f ms, %.3f KB"):format(label, ms, kb))
    check(label .. " takes under " .. budget .. " ms", ms < budget)
    check(label .. " makes no garbage", kb < 0.01)
end

do
    local ns, state = fixture()
    local J, Loot, Quests = ns.Journal, ns.Journal.Loot, ns.Journal.Quests
    for id in pairs(J.Items) do
        if id % 7 == 0 then state.bis[id] = 1 end
    end
    local dungeons = J.Dungeons()
    local filters = Loot.ReadFilters({})
    Measure("BiS count over every dungeon", 1, function()
        for _, d in ipairs(dungeons) do Loot.DungeonBis(d, filters) end
    end)
    Measure("quest signature over every dungeon", 1, function()
        for _, d in ipairs(dungeons) do Quests.Signature(d.quests) end
    end)
end

-------------------------------------------------------------------------------
--  The tracker's opacity, from the one setting it was before; the windows have none
-------------------------------------------------------------------------------
do
    local ns, _, S = fixture({ windowAlpha = 0.5 })
    ns.Apply()
    check("the tracker keeps the opacity set before it had its own", S.Get("trackerAlpha") == 0.5)
    ns, _, S = fixture({ windowAlpha = 0.5, trackerAlpha = 0.9 })
    ns.Apply()
    check("the tracker's own opacity, once set, is kept", S.Get("trackerAlpha") == 0.9)
    ns, _, S = fixture({})
    ns.Apply()
    check("none set: the tracker at its default", S.Raw("trackerAlpha") == nil)
    local sources = {}
    for _, path in ipairs({ "UI/Window.lua", "UI/MapWindow.lua", "UI/MapPanel.lua", "UI/Popup.lua",
        "View/Parts.lua", "UI/SettingsPage.lua" }) do
        local f = assert(io.open("NaowhForever_DungeonJournal/" .. path, "rb"))
        sources[#sources + 1] = f:read("*a")
        f:close()
    end
    local all = table.concat(sources, "\n")
    check("the Journal's windows have no opacity: always solid", all:find("windowAlpha", 1, true) == nil
        and all:find("mapAlpha", 1, true) == nil and all:find("Parts.Opacity", 1, true) == nil
        and all:find("Window Opacity", 1, true) == nil)
end

-------------------------------------------------------------------------------
--  Off means off
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = false })
    check("loading makes no frame", state.frames == 0)
    ns.Apply()
    check("off, the map is not hooked", #state.hooks == 0)
    S.Set("mapPanel", true)
    check("turning the panel on with the module off hooks nothing", #state.hooks == 0)
    S.Set("enabled", true)
    check("turning the module on hooks the map", #state.hooks == 3)
    check("and makes four frames, the kill count's, the loot's, the share asks' and the quartermasters', "
        .. "until the map shows in a dungeon, and the one that folds the quest log there", state.frames == 5)
    -- Each by what it listens to.
    local counter, looted, asks, vendors
    for _, frame in ipairs(state.made) do
        if frame.events.ENCOUNTER_END then counter = frame
        elseif frame.events.PLAYER_ENTERING_WORLD then looted = frame
        elseif frame.events.GROUP_ROSTER_UPDATE then asks = frame
        elseif frame.events.MERCHANT_SHOW then vendors = frame end
    end
    check("which learn where a quartermaster stands when you open a vendor", vendors ~= nil)
    check("which listens for your group, and for share asks only in one", asks.events.GROUP_ROSTER_UPDATE
        and not asks.events.CHAT_MSG_ADDON)
    check("which listen for boss fights", counter.events.ENCOUNTER_START and counter.events.ENCOUNTER_END)
    check("and for loading screens, not loot, outside a dungeon", looted.events.PLAYER_ENTERING_WORLD
        and not looted.events.CHAT_MSG_LOOT)
    -- A loading screen into a dungeon the Journal has: the game's quest log beside the map
    -- folds, and comes back as it was on leaving.
    local function LoadingScreen()
        for _, frame in ipairs(state.made) do
            if frame.events.PLAYER_ENTERING_WORLD then frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD") end
        end
    end
    state.instance = { id = 36, name = "The Deadmines" }
    LoadingScreen()
    check("in a dungeon, the quest log beside the map folds", state.cvars.questLogOpen == "0")
    check("what it was is kept", state.account.journalQuestLogWas == "1")
    state.instance = nil
    LoadingScreen()
    check("and comes back on leaving", state.cvars.questLogOpen == "1" and state.account.journalQuestLogWas == nil)
    S.Set("enabled", false)
    check("off again, they stop listening", next(counter.events) == nil and next(looted.events) == nil
        and next(asks.events) == nil and next(vendors.events) == nil)
    S.Set("enabled", true)
    ns.Apply()
    check("and hooks the map only once", #state.hooks == 3)
    check("and makes its frames only once", state.frames == 5)
end

-------------------------------------------------------------------------------
--  Beside the map in a dungeon: the page drawn once, and again only when something changed
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true, favourites = true })
    local J, map = ns.Journal, state.worldMap
    local draws, draw = 0, J.View.Mixin.Draw
    J.View.Mixin.Draw = function(...)
        draws = draws + 1
        return draw(...)
    end
    ns.Apply()
    state.instance = { id = 36, name = "The Deadmines" }
    local wanted = J.Boss(639).loot[1]
    J.Favourites.Toggle(wanted)
    local function Open()
        map.shown = true
        state.hooked.OnShow(map)
    end
    local function Close()
        map.shown = false
        state.hooked.OnHide(map)
    end
    Open()
    check("the map opened in a dungeon draws its page", draws == 1)
    local view
    for _, frame in ipairs(state.made) do
        if rawget(frame, "keepHidden") then view = frame end
    end
    check("on a view that keeps it while the map is shut", view ~= nil)
    local function Event(event, arg)
        view.scripts.OnEvent(view, event, arg)
    end
    Close()
    Open()
    check("opened again with nothing changed, it is not drawn again", draws == 1)
    Close()
    Event("QUEST_LOG_UPDATE")
    Event("BAG_UPDATE_DELAYED")
    Open()
    check("quest log and bag updates that change nothing on it leave it", draws == 1)
    Close()
    state.owned[wanted] = 1
    Event("BAG_UPDATE_DELAYED")
    Open()
    check("a favourite looted while it was shut draws it again", draws == 2)
    Close()
    Event("PLAYER_EQUIPMENT_CHANGED")
    check("gear changed while shut: it stops listening until it is drawn", next(view.events) == nil)
    Open()
    check("and draws on the next open", draws == 3)
    Close()
    S.Set("showChance", false)
    Open()
    check("a setting changed while shut draws it again", draws == 4)
    Close()
    J.Favourites.Toggle(wanted)
    Open()
    check("so does a favourite added or removed", draws == 5)
    Close()
    state.instance = nil
    for _, frame in ipairs(state.made) do
        if frame.events.PLAYER_ENTERING_WORLD and frame ~= view then
            frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
        end
    end
    check("after a loading screen it listens for nothing", next(view.events) == nil)
    state.instance = { id = 36, name = "The Deadmines" }
    Open()
    check("and the next open draws it", draws == 6)
    Close()
    local function RunTimers()
        local timers = state.timers
        state.timers = {}
        for _, fn in ipairs(timers) do fn() end
    end
    local function LoadingScreen()
        for _, frame in ipairs(state.made) do
            if frame.events.PLAYER_ENTERING_WORLD and frame ~= view then
                frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
            end
        end
        RunTimers()
    end
    LoadingScreen()
    local warmed = draws
    check("a loading screen into a dungeon draws its page with the map shut", warmed > 6 and view:IsVisible() == false)
    Open()
    check("so the first open after it draws nothing", draws == warmed)
    Close()
    view.waitingFor[4242] = true
    Event("GET_ITEM_INFO_RECEIVED", 4242, true)
    RunTimers()
    check("an item's name arriving while shut draws it again, still shut", draws > warmed)
    warmed = draws
    Open()
    check("and the open after that draws nothing", draws == warmed)
    Close()
    state.owned[J.Boss(639).loot[2]] = 1
    Event("BAG_UPDATE_DELAYED")
    Open()
    check("any drop on the page looted while shut draws it again, for its In Bag tag", draws == warmed + 1)
    Close()
    S.Set("enabled", false)
    check("off, the kept page listens for nothing", next(view.events) == nil)
end

-------------------------------------------------------------------------------
--  Beside the map outside a dungeon: the factions earned where you are
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J, here = ns.Journal, {}
    check("Factions Beside the Map is off until switched on", not S.Get("mapFactions"))
    state.mapInfo = {
        [1451] = { mapID = 1451, mapType = 3, parentMapID = 1414 },   -- Silithus
        [9001] = { mapID = 9001, mapType = 4, parentMapID = 1451 },   -- a cave in it
        [1450] = { mapID = 1450, mapType = 3, parentMapID = 1414 },   -- Moonglade
        [1417] = { mapID = 1417, mapType = 3, parentMapID = 1415 },   -- Arathi Highlands
        [1446] = { mapID = 1446, mapType = 3, parentMapID = 1414 },   -- Tanaris
        [1413] = { mapID = 1413, mapType = 3, parentMapID = 1414 },   -- The Barrens
        [1455] = { mapID = 1455, mapType = 3, parentMapID = 1415 },   -- Ironforge
        [1454] = { mapID = 1454, mapType = 3, parentMapID = 1414 },   -- Orgrimmar
    }
    local function Keys()
        J.FactionsHere(here)
        local keys = {}
        for i, faction in ipairs(here) do keys[i] = faction.key end
        return table.concat(keys, " ")
    end
    state.standingOn = 1451
    check("in Silithus: the Cenarion Circle", Keys() == "CenarionCircle")
    state.standingOn = 9001
    check("in a cave there: the same, its zone's", Keys() == "CenarionCircle")
    state.standingOn = 1450
    check("in Moonglade, where it is also earned: the same", Keys() == "CenarionCircle")
    state.standingOn = 1446
    check("in Tanaris: Gadgetzan, not Brood of Nozdormu (not in Forever yet)", Keys() == "Gadgetzan")
    state.standingOn = 1417
    check("in Arathi Highlands: your side's battleground faction only", Keys() == "LeagueOfArathor")
    state.standingOn = 1413
    check("in The Barrens: Ratchet, Durotar Supply and Logistics, and your side's Darkspear Islands faction",
        Keys() == "Ratchet DurotarSupplyAndLogistics TheramoreExpeditionaryForce")
    state.standingOn = 1455
    check("in Ironforge: its city and the Gnomeregan Exiles", Keys() == "Ironforge GnomereganExiles")
    state.standingOn = 1454
    check("in Orgrimmar, for the Alliance: none", Keys() == "")
    local Rep, cities = J.Reputation, {}
    for _, faction in ipairs(J.Factions("reputation")) do cities[faction.key] = faction end
    check("your side's cities are listed", Rep.Shown(cities.Stormwind))
    check("the other side's are not", not Rep.Shown(cities.Orgrimmar))
    check("a city's hand-ins: Additional Runecloth", cities.Stormwind.turnins[1].name == "Additional Runecloth")
    check("its Runecloth farmed first in Silithus, not in the city",
        cities.Stormwind.turnins[1].from[1][1] == "Silithus" and cities.Orgrimmar.turnins[1].from[1][1] == "Silithus")
    state.instance = { id = 529, name = "Arathi Basin", kind = "pvp" }
    check("in Arathi Basin: the League of Arathor", Keys() == "LeagueOfArathor")
    state.instance = { id = 36, name = "The Deadmines" }
    check("in a dungeon: none, its own page shows", Keys() == "")
    state.instance, state.standingOn = nil, nil
    check("nowhere the game says: none", Keys() == "")
end

-------------------------------------------------------------------------------
--  The window: it builds, draws a dungeon and a search, and its switches work
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    ns.Apply()
    state.instance = { id = 36, name = "The Deadmines" }
    ns.OpenJournalWindow()
    check("the window opens", state.frames > 10)
    local entrance = false
    for _, frame in ipairs(state.made) do
        local text = rawget(frame, "text")
        if type(text) == "table" and rawget(text, "text") == "Entrance" and rawget(frame, "shown") ~= false then entrance = true end
    end
    check("the entrance is a labelled link beside the title", entrance)
    -- A boss with nothing recorded says so in the middle of its card, not in its header.
    ns.OpenJournalWindow(ns.Journal.Get("Dalaran"))   -- the Shade of the Archmage
    local inBody = false
    for _, frame in ipairs(state.made) do
        local note = rawget(frame, "note")
        if note and rawget(note, "shown") ~= false and rawget(note, "text") == "No boss loot known yet" then
            inBody = true
        end
    end
    check("an empty boss's card says so in its body", inBody)
    local DJ = ns.Journal
    local Parts = DJ.View.Parts
    check("none known: unknown", Parts.BossEmptyText(0, {}) == "No boss loot known yet")
    check("loot, all filtered: for your class", Parts.BossEmptyText(0, { loot = { 1 } }) == "Nothing for your class")
    check("loot shown: nothing to say", Parts.BossEmptyText(2, { loot = { 1, 2 } }) == "")
    local function PageSays(text)
        for _, frame in ipairs(state.made) do
            local line = rawget(frame, "text")
            if type(line) == "table" and rawget(frame, "shown") ~= false and rawget(line, "text") == text then
                return true
            end
        end
        return false
    end
    local function Row(itemID)
        local found
        for _, frame in ipairs(state.made) do
            if rawget(frame, "itemID") == itemID and rawget(frame, "shown") ~= false then found = frame end
        end
        return found
    end
    local function findBoss(key, name)
        for _, wing in ipairs(DJ.Get(key).wings) do
            for _, b in ipairs(wing.bosses) do
                if b.name == name then return b end
            end
        end
    end
    local function Has(list, id)
        for _, v in ipairs(list or {}) do if v == id then return true end end
        return false
    end
    ns.OpenJournalWindow(DJ.Get("Deadmines"))
    check("an open dungeon: no line saying it is not open", not PageSays(DJ.CLOSED_NOTE))
    local trashTitle, trashItem
    for _, frame in ipairs(state.made) do
        local line = rawget(frame, "text")
        if type(line) == "table" and rawget(frame, "shown") ~= false and type(rawget(line, "text")) == "string"
            and rawget(line, "text"):upper():find("^TRASH") then trashTitle = true end
    end
    for _, wing in ipairs(DJ.Get("Deadmines").wings) do
        for _, b in ipairs(wing.bosses) do
            if b.trash then
                for _, id in ipairs(b.loot) do
                    if not trashItem and Row(id) then trashItem = id end
                end
            end
        end
    end
    check("the trash in its own section, after the bosses", trashTitle and trashItem ~= nil)
    local notYet
    for _, wing in ipairs(DJ.Get("RazorfenDowns").wings) do
        for _, b in ipairs(wing.bosses) do
            for _, id in ipairs(b.loot or {}) do
                local facts = DJ.NotYet[id]
                if not notYet and facts and facts[1] == 4 and facts[2] <= 1 then notYet = id end
            end
        end
    end
    check("Razorfen Downs lists loot not in Forever yet", notYet ~= nil)
    local notYetName = DJ.NotYet[notYet][DJ.FACT.NAME]
    state.requested = {}
    state.bis[notYet] = 1
    local tipLines, setByID = {}, 0
    rawset(state.tooltip, "AddLine", function(_, text) tipLines[#tipLines + 1] = text end)
    rawset(state.tooltip, "SetItemByID", function() setByID = setByID + 1 end)
    ns.OpenJournalWindow(DJ.Get("RazorfenDowns"))
    check("a dungeon not open says so at the top of its page", DJ.Get("RazorfenDowns").closed and PageSays(DJ.CLOSED_NOTE))
    check("its bosses list their whole loot", Has(findBoss("RazorfenDowns", "Tuten'kash").loot, 10776))
    local row = Row(notYet)
    check("an item not in Forever yet has its row", row ~= nil)
    check("named from the Journal's data", rawget(row.name, "text"):find(notYetName, 1, true) ~= nil)
    check("tagged, muted, on its second line", rawget(row.metaTail, "text"):find(DJ.NOT_YET, 1, true) ~= nil)
    check("its icon from the Journal's data", DJ.NotYet[notYet][DJ.FACT.ICON] > 0)
    check("never asked of the server", not Has(state.requested, notYet))
    local notYetView = row:GetParent()
    check("nor waited on", notYetView.waitingFor[notYet] == nil)
    check("not your BiS while not in Forever", DJ.Loot.Rank(notYet) == nil and not DJ.Loot.BisUpgrade(notYet))
    check("not an upgrade, no look to collect", not DJ.Loot.Upgrade(notYet) and DJ.Loot.Appearance(notYet) == nil)
    check("found by a search for its name", notYetView:Listed(notYet, notYetName:lower()))
    row.scripts.OnEnter(row)
    check("the game's item comparison waits for Shift", rawget(state.tooltip, "suppressAutomaticCompareItem") == true)
    check("its tooltip is the Journal's own", setByID == 0 and rawget(state.tooltip, "text") == notYetName)
    check("which says it is not in Forever yet", Has(tipLines, DJ.NOT_YET))
    check("and offers the menu, not a link it cannot give", Has(tipLines, "Right-click: menu"))
    state.bis[notYet] = nil
    local herod = findBoss("ScarletMonasteryArmory", "Herod")
    check("Herod: Ravager, which Forever sends", Has(herod.loot, 7717) and DJ.Items[7717] ~= nil)
    check("and his Classic loot, in Forever since build 1.60.1.70338", Has(herod.loot, 7718)
        and not DJ.IsNotYet(7718) and DJ.Items[7718] ~= nil)
    check("each with its chance", herod.chance and #herod.chance == #herod.loot)
    do
        local blueprints = { Shadetooth = 273106, ["Relic Guardian"] = 273097 }
        for _, name in ipairs({ "Saltspine", "Shadetooth", "Relic Guardian" }) do
            local b = findBoss("ExcavationSite", name)
            local known = b.loot and #b.loot >= 3 and b.chance and #b.chance == #b.loot
            for i, c in ipairs(known and b.chance or {}) do known = known and (c > 0 or b.loot[i] == blueprints[name]) end
            check("Excavation Site: " .. name .. "'s loot, each with its chance but a blueprint", known)
        end
        for name, id in pairs(blueprints) do
            check(name .. "'s blueprint", Has(findBoss("ExcavationSite", name).loot, id))
        end
    end
    for _, key in ipairs({ "ScarletMonasteryGraveyard", "ScarletMonasteryLibrary", "ScarletMonasteryArmory",
        "ScarletMonasteryCathedral", "ExcavationSite", "HallOfThanes", "RuinsOfLordaeron", "Deadmines", "Dalaran",
        "ShapersTerrace" }) do
        check("open on Forever: " .. key, not DJ.Get(key).closed)
    end
    for _, key in ipairs({ "RazorfenDowns", "Uldaman" }) do
        check("not open on Forever yet: " .. key, DJ.Get(key).closed)
    end
    -- An item the server will not send: no redraw for it, never waited on again.
    ns.OpenJournalWindow(ns.Journal.Get("Deadmines"))
    local view, refusedID
    for _, frame in ipairs(state.made) do
        local waiting = rawget(frame, "waitingFor")
        if waiting and frame:IsVisible() and next(waiting) then view, refusedID = frame, next(waiting) end
    end
    check("the Deadmines waits on its names", view ~= nil)
    local queued = #state.timers
    view:OnEvent("GET_ITEM_INFO_RECEIVED", refusedID, false)
    check("refused: no redraw", #state.timers == queued and view.waitingFor[refusedID] == nil)
    view:Redraw()
    check("drawn again: not waited on", view.waitingFor[refusedID] == nil and next(view.waitingFor) ~= nil)
    -- The trash: under its own section title, in two columns, with no header of its own.
    ns.OpenJournalWindow(ns.Journal.Get("ShadowfangKeep"))
    local trashHeader, items = nil, {}
    for _, frame in ipairs(state.made) do
        local boss = rawget(frame, "boss")
        if boss and boss.trash and rawget(frame, "shown") ~= false then
            if rawget(frame, "badge") then
                trashHeader = frame
            elseif rawget(frame, "itemID") then
                items[#items + 1] = frame
            end
        end
    end
    check("Shadowfang Keep lists its trash, with no header of its own", #items > 1 and trashHeader == nil)
    -- Right-click: an item's and a boss's Wowhead Forever link, in the copy box.
    local function MenuEntry(text)
        for _, e in ipairs(state.menu or {}) do
            if e.text == text then return e end
        end
    end
    local itemRow, bossRow
    for _, frame in ipairs(state.made) do
        if rawget(frame, "itemID") and frame.scripts.OnClick and not itemRow then itemRow = frame end
        if rawget(frame, "boss") and frame.scripts.OnMouseUp and rawget(frame, "boss").npc and not bossRow then
            bossRow = frame
        end
    end
    itemRow.scripts.OnClick(itemRow, "RightButton")
    local link = MenuEntry("Wowhead Link")
    check("an item's menu has its Wowhead link", link ~= nil)
    link.click()
    check("which shows its Wowhead Forever page to copy",
        state.copied and state.copied.text == "https://www.wowhead.com/forever/item=" .. itemRow.itemID)
    bossRow.scripts.OnMouseUp(bossRow, "RightButton")
    MenuEntry("Wowhead Link").click()
    check("a boss's right-click gives its NPC's page",
        state.copied.text == "https://www.wowhead.com/forever/npc=" .. bossRow.boss.npc)
    state.menu, state.copied = nil, nil
    ns.OpenJournalWindow(ns.Journal.Get("Deadmines"))
    -- The Filters menu: the addon's own, a row per switch; a click flips one, a click
    -- elsewhere closes it.
    local funnel, menu
    for _, frame in ipairs(state.made) do
        local parent = rawget(frame, "parent")
        if rawget(frame, "count") and frame.scripts.OnClick and parent and rawget(parent, "factions") then
            funnel = frame
        end
    end
    funnel.scripts.OnClick(funnel)
    for _, frame in ipairs(state.made) do
        if rawget(frame, "parts") then menu = frame end
    end
    check("the funnel opens the Filters menu", menu ~= nil and menu:IsShown())
    local rows, upgradesRow = 0, nil
    for _, part in ipairs(menu.parts) do
        if rawget(part, "option") then
            rows = rows + 1
            if part.option.key == "upgradesOnly" then upgradesRow = part end
        end
    end
    check("a row for each switch", rows == #ns.Journal.OPTION_GROUPS[1].options)
    local hover = {}
    state.tooltip.AddLine = function(_, text) hover[#hover + 1] = text end
    upgradesRow.scripts.OnEnter(upgradesRow)
    check("each saying what it does on hover, not under its name", hover[1] == upgradesRow.option.tooltip
        and rawget(upgradesRow, "text") == nil)
    upgradesRow.scripts.OnLeave(upgradesRow)
    state.tooltip.AddLine = nil
    menu.scripts.OnShow(menu)
    check("listening for clicks while open", menu.events.GLOBAL_MOUSE_DOWN == true)
    upgradesRow.scripts.OnClick(upgradesRow)
    check("a click on a row flips its switch", S.Get("upgradesOnly") == true)
    check("and ticks its box", upgradesRow.tick:IsShown())
    upgradesRow.scripts.OnClick(upgradesRow)
    state.mouseOver = false
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN")
    check("a click elsewhere closes it", not menu:IsShown())
    menu.scripts.OnHide(menu)
    check("and it stops listening", next(menu.events) == nil)
    state.mouseOver = nil
    -- An item's drop chance on hover reads as its marks do: a bag, the words in its bar's
    -- colour, then how often, muted.
    local item, lines = nil, {}
    for _, frame in ipairs(state.made) do
        if rawget(frame, "itemID") and rawget(frame, "chance") and frame.scripts.OnEnter then item = frame end
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    state.tooltip.AddLine = function(_, text) lines[#lines + 1] = text end
    item.scripts.OnEnter(item)
    local chanceLine
    for _, text in ipairs(lines) do
        if type(text) == "string" and text:find("% drop chance", 1, true) then chanceLine = text end
    end
    check("the drop chance line has its bag", chanceLine and chanceLine:find("bag", 1, true) ~= nil)
    check("and says how often", chanceLine and (chanceLine:find("1 in ", 1, true) or chanceLine:find("every kill", 1, true)))
    state.tooltip.AddLine = nil
    -- Quests handed in of how many; every one handed in, the count is a check.
    local Progress, deadminesQuests = ns.Journal.Quests.Progress, ns.Journal.Get("Deadmines").quests
    local done, total = Progress(deadminesQuests)
    check("none of The Deadmines' quests handed in yet, of several", done == 0 and total > 1)
    state.allDone = true
    done = Progress(deadminesQuests)
    check("all of them once every one is handed in", done == total)
    check("none for you, none to count", select(2, Progress({ quests = {} })) == 0 and select(2, Progress(nil)) == 0)
    -- Shadowfang Keep has none for an Alliance mage: says whose they are.
    local why = ns.Journal.Quests.NoneWhy(ns.Journal.Get("ShadowfangKeep").quests)
    check("a dungeon with none for you says whose they are", why == "None for you here. The rest: 3 Horde, 1 Warlock, 2 Paladin.")
    check("a dungeon with no quests says nothing", ns.Journal.Quests.NoneWhy(nil) == nil)
    -- A switch changing draws the page again, now with every quest handed in.
    ns.Journal.Settings.Set("showCosmetic", false)
    local checked = false
    for _, font in ipairs(state.fonts) do
        local text = rawget(font, "text")
        if type(text) == "string" and text:find("|t", 1, true) and text:find("Quests", 1, true) then checked = true end
    end
    check("and the header shows a check for Quests", checked)
    state.allDone = nil
    ns.Journal.Settings.Set("showCosmetic", true)

    -- Weapons in short: a one-handed sword, and one that only goes in the main hand.
    local sword, mainHand
    for _, w in ipairs(ns.Journal.Get("Deadmines").wings) do
        for _, b in ipairs(w.bosses) do
            for _, id in ipairs(b.loot or {}) do
                local facts = ns.Journal.Items[id]
                if facts and facts[1] == 2 and facts[2] == 7 then
                    if not sword then sword = id elseif not mainHand then mainHand = id end
                end
            end
        end
    end
    state.slots = { [sword] = "INVTYPE_WEAPON", [mainHand] = "INVTYPE_WEAPONMAINHAND" }
    ns.Journal.Settings.Set("usableOnly", false)
    local said = {}
    for _, font in ipairs(state.fonts) do
        local text = rawget(font, "text")
        if type(text) == "string" then said[text] = true end
    end
    check("a one-handed sword says 1h Sword", said["1h Sword"])
    check("one only for the main hand says MH Sword", said["MH Sword"])
    state.slots = nil
    -- The faction switch's halves, clicked as a player would.
    local half = {}
    for _, frame in ipairs(state.made) do
        local side = rawget(frame, "side")
        if side then half[side.faction] = frame end
    end
    check("the faction switch has both halves", half.Alliance and half.Horde)
    half.Horde.scripts.OnClick(half.Horde)
    check("a click hides Horde ground", S.Get("showHorde") == false)
    half.Alliance.scripts.OnClick(half.Alliance)
    check("switching off the other side turns the first back on", S.Get("showAlliance") == false
        and S.Get("showHorde") == true)
    half.Alliance.scripts.OnClick(half.Alliance)
    check("and both can be on", S.Get("showAlliance") and S.Get("showHorde"))
    S.Set("usableOnly", false)
    S.Set("listHidden", true)
    S.Set("listHidden", false)
    S.Set("trackerAlpha", 0.7)
    check("and takes its settings without an error", true)
    -- The list: the BiS here you still miss, and nothing once you have them all.
    local List, deadmines = ns.Journal.DungeonList, ns.Journal.Get("Deadmines")
    local function BisText()
        for _, font in ipairs(state.fonts) do
            local text = rawget(font, "text")
            local parent = rawget(font, "parent")
            if type(text) == "string" and text:find("|t", 1, true) and parent and rawget(parent, "bis") == font
                and rawget(parent, "dungeon") == deadmines and text:find("^|T") then
                return text
            end
        end
    end
    local first = deadmines.wings[1].bosses[1].loot[1]
    state.bis[first] = 1
    List.Paint(deadmines)
    check("the list says how many of your BiS here you still miss", BisText() and BisText():find("1$"))
    state.owned[first] = 1
    List.Paint(deadmines)
    check("and nothing once you have them all", BisText() == nil)
    Measure("the dungeon list's repaint", 2, function() List.Paint(deadmines) end)
    state.bis[first], state.owned[first] = nil, nil
    -- The list's groups: Low level first, closed until you open it; your level's right under it.
    do
        local function GroupHeader(label)
            for _, font in ipairs(state.fonts) do
                local parent = rawget(font, "parent")
                if rawget(font, "text") == label and parent and rawget(parent, "arrow") then return parent end
            end
        end
        check("Low level starts closed", state.defaults.closedGroup3 == true)
        local levelBefore = state.level
        state.level = 30
        S.Set("closedGroup3", true)
        List.Layout()
        local behind, yours = GroupHeader("LOW LEVEL"), GroupHeader("FOR YOUR LEVEL")
        check("Low level sits above your level's dungeons", behind and yours and behind.pointY > yours.pointY)
        check("closed, it shows how many it holds", (tonumber(rawget(behind.count, "text")) or 0) > 0)
        local deadminesRow
        for _, font in ipairs(state.fonts) do
            local parent = rawget(font, "parent")
            if parent and rawget(parent, "dungeon") == deadmines and rawget(parent, "stripe") then deadminesRow = parent end
        end
        check("its dungeons are hidden while it is closed", deadminesRow and deadminesRow.shown == false)
        S.Set("closedGroup3", false)
        List.Layout()
        check("opened, they show", deadminesRow.shown == true and behind.count.text == "")
        S.Set("closedGroup3", true)
        state.level = levelBefore
        List.Layout()
    end
    -- Each row: your quests there as done/total, a check once all are handed in, nothing without any.
    do
        local J = ns.Journal
        local function RowOf(dungeon)
            for _, font in ipairs(state.fonts) do
                local parent = rawget(font, "parent")
                if parent and rawget(parent, "quests") == font and rawget(parent, "dungeon") == dungeon then
                    return parent
                end
            end
        end
        local deadminesRow = RowOf(deadmines)
        local questsDone, questsTotal = J.Quests.Progress(deadmines.quests)
        List.Paint(deadmines)
        check("a row counts your quests there", questsTotal > 0
            and rawget(deadminesRow.quests, "text"):find(("%d/%d$"):format(questsDone, questsTotal)) ~= nil)
        local none
        for _, dungeon in ipairs(J.Dungeons()) do
            local _, count = J.Quests.Progress(dungeon.quests)
            if count == 0 then none = none or dungeon end
        end
        check("and shows nothing where none are for you", none and rawget(RowOf(none).quests, "text") == "")
        state.allDone = true
        List.Paint(deadmines)
        check("all handed in: a check instead", rawget(deadminesRow.quests, "text") == J.Style.DONE_MARK)
        check("Show Done Quests starts off", state.defaults.showDoneQuests == false)
        check("off, handed-in quests are not listed", #J.Quests.List(deadmines.quests, {}, {}) == 0)
        local doneList = J.Quests.List(deadmines.quests, {}, {}, true)
        local allDone = #doneList > 0
        for _, entry in ipairs(doneList) do allDone = allDone and entry.kind == "done" end
        check("on, they are listed as handed in", allDone)
        check("Hide Completed Dungeons starts off, in the filters", state.defaults.hideCompleted == false
            and J.OPTION_GROUPS[1].options[6].key == "hideCompleted")
        check("off, a dungeon all done stays listed", deadminesRow.shown ~= false)
        local before = List.Next(deadmines, -1)
        S.Set("hideCompleted", true)
        List.Layout()
        check("on, it leaves the list", deadminesRow.shown == false)
        check("and Up and Down skip it", List.Next(before, 1) ~= deadmines)
        Measure("the dungeon list's repaint, hiding the dungeons done", 2, function() List.Paint(deadmines) end)
        state.allDone = false
        List.Paint(deadmines)
        check("a quest no longer done brings it back on the next repaint", deadminesRow.shown == true)
        S.Set("hideCompleted", false)
        List.Layout()
        local env = getfenv(J.Quests.List)
        local color = env.GetQuestDifficultyColor
        env.GetQuestDifficultyColor = function() return env.QuestDifficultyColors.trivial end
        check("Show Low-Level Quests starts off, after Show Done Quests", state.defaults.showLowQuests == false
            and J.OPTION_GROUPS[1].options[8].key == "showLowQuests")
        local greyList = J.Quests.List(deadmines.quests, {}, {})
        local onlyTurnIns = true
        for _, entry in ipairs(greyList) do
            onlyTurnIns = onlyTurnIns and not (J.Quests.ToPickUp(entry.kind) and not entry.quest.turnin)
        end
        check("off, grey quests to pick up are not listed", onlyTurnIns)
        check("on, they are", #J.Quests.List(deadmines.quests, {}, {}, false, true) > #greyList)
        local note = J.Quests.NoneWhy(deadmines.quests)
        check("and with none listed, it says they have gone grey", note and note:find("gone grey", 1, true) ~= nil)
        env.GetQuestDifficultyColor = color
    end


    -- The quest tracker: the dungeon's quests alone, each on one line, under its title and a
    -- dropdown of every dungeon with quests.
    ns.OpenQuestTracker(deadmines)
    local tracker
    for _, made in ipairs(state.made) do
        local title = rawget(made, "title")
        if title and rawget(made, "share") and rawget(title, "text") == "DUNGEON QUEST TRACKER" then tracker = made end
    end
    local picker = tracker and rawget(tracker, "picker")
    check("the quest tracker opens, under its title", tracker ~= nil and tracker:IsShown())
    check("on the shared tracker window, its quests under the dropdown", tracker.SetRows ~= nil and tracker:Top() == 64)
    check("on the dungeon, in its dropdown", picker and picker.get() == deadmines.key)
    check("its Share button shares them all", rawget(tracker, "share").label == "Share All")
    local cog = rawget(tracker, "settings")
    cog.scripts.OnClick(cog)
    check("its cog opens the Quest Tracker settings", state.optionsOpened == "Dungeon Journal/Quest Tracker"
        and state.wentTo == "Dungeon Journal/Quest Tracker:quests")
    check("which lists every dungeon with quests", picker and picker.values[deadmines.key] ~= nil
        and #picker.order > 10)
    check("with its level range", picker.values[deadmines.key]:find("17-26", 1, true) ~= nil)
    check("the whole list at once: its menu as tall as the screen", type(picker._menuHeight) == "function")
    -- Its range in the quest log's colours for you: its lowest level while above you, yours
    -- inside it, its highest once outgrown.
    local level = state.level
    state.level = 12
    ns.Journal.ColoredLevelRange(deadmines)
    check("above you: colored as its lowest level", state.difficultyAsked == 17)
    state.level = 20
    ns.Journal.ColoredLevelRange(deadmines)
    check("for you: colored as your level", state.difficultyAsked == 20)
    state.level = 40
    ns.Journal.ColoredLevelRange(deadmines)
    check("outgrown: colored as its highest", state.difficultyAsked == 26)
    state.level = level
    local ragefireKey = ns.Journal.Get("RagefireChasm").key
    picker.set(ragefireKey)
    check("picking another shows it", picker.get() == ragefireKey and tracker:IsShown())
    picker.set(deadmines.key)
    ns.OpenQuestTracker(deadmines)
    check("and closes on a second click", not tracker:IsShown())

    -- Open Tracker in Dungeons: a loading screen into a dungeon with quests for you opens the
    -- tracker on it; closed there, it stays closed until you leave the dungeon.
    local function EnterWorld()
        for _, frame in ipairs(state.made) do
            if frame.events.PLAYER_ENTERING_WORLD then frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD") end
        end
    end
    check("the tracker is found", tracker ~= nil)
    check("off, entering a dungeon leaves it closed", (function()
        state.instance = { id = 36, name = "The Deadmines" }
        EnterWorld()
        return not tracker:IsShown()
    end)())
    check("fading the game's quest tracker is off by default", state.defaults.hideGameTracker == false)
    S.Set("trackerAuto", true)
    S.Set("hideGameTracker", true)
    state.instance = nil
    EnterWorld()
    state.instance = { id = 36, name = "The Deadmines" }
    EnterWorld()
    check("on, entering a dungeon with quests for you opens it", tracker:IsShown())
    -- Hide the Game's Quest Tracker: faded while this one is up in the dungeon, never hidden.
    local game = state.gameTracker
    check("the game's quest tracker is faded", game.shown and game.alpha == 0)
    game:SetAlpha(1)
    game:Show()
    check("and stays faded when the game shows it again", game.shown and game.alpha == 0)
    game:SetAlpha(1)
    check("and when the game only sets its alpha back (the managed frames' fade in)", game.shown and game.alpha == 0)
    state.combat = true
    game:SetAlpha(1)
    game:Show()
    check("in combat too", game.shown and game.alpha == 0)
    state.combat = false
    tracker:Hide()
    tracker.scripts.OnHide(tracker)
    check("closing this one brings the game's back", game.shown and game.alpha == 1)
    game:SetAlpha(0.5)
    check("and its own alpha changes are left alone then", game.alpha == 0.5)
    game:SetAlpha(1)
    EnterWorld()
    check("closed in there, it stays closed", not tracker:IsShown())
    state.instance = nil
    EnterWorld()
    state.instance = { id = 36, name = "The Deadmines" }
    EnterWorld()
    check("until you leave and come back", tracker:IsShown())
    -- Skip at Max Level: off by default; on, a max-level character enters with it closed.
    check("Skip at Max Level is off by default", state.defaults.trackerSkipMaxLevel == false)
    tracker:Hide()
    tracker.scripts.OnHide(tracker)
    state.instance = nil
    EnterWorld()
    S.Set("trackerSkipMaxLevel", true)
    state.maxLevel = state.level
    state.instance = { id = 36, name = "The Deadmines" }
    EnterWorld()
    check("on, at max level, entering a dungeon leaves it closed", not tracker:IsShown())
    S.Set("trackerSkipMaxLevel", false)
    check("switched off in there, it opens straight away", tracker:IsShown())
    tracker:Hide()
    tracker.scripts.OnHide(tracker)
    S.Set("trackerSkipMaxLevel", true)
    state.instance = nil
    EnterWorld()
    state.maxLevel = nil
    state.instance = { id = 36, name = "The Deadmines" }
    EnterWorld()
    check("below max level it still opens", tracker:IsShown())
    S.Set("trackerSkipMaxLevel", false)
    -- A /reload inside: the settings are applied during that loading screen's own event, so
    -- applying them has to look where you are.
    tracker:Hide()
    state.instance = nil
    tracker.scripts.OnHide(tracker)
    state.instance = { id = 36, name = "The Deadmines" }
    S.Set("trackerAuto", true)   -- the settings applied, as a reload does
    check("a reload inside a dungeon opens it", tracker:IsShown())
    check("and fades the game's quest tracker", game.alpha == 0)
    state.instance = nil
    tracker.scripts.OnEvent(tracker, "PLAYER_ENTERING_WORLD")
    check("leaving the dungeon with it open brings the game's back", game.alpha == 1)
    S.Set("hideGameTracker", false)
    state.instance = { id = 36, name = "The Deadmines" }
    tracker.scripts.OnEvent(tracker, "PLAYER_ENTERING_WORLD")
    check("switched off, the game's is left alone", game.alpha == 1)
    S.Set("hideGameTracker", true)
    check("switched on again, it is faded", game.alpha == 0)
    tracker:Hide()
    tracker.scripts.OnHide(tracker)
    check("closed again, the game's is back", game.alpha == 1)
    -- The game's own was down (no quests to watch): it stays down after.
    game.shown = false
    ns.OpenQuestTracker(deadmines)
    check("opened again over a game tracker that was down", tracker:IsShown() and not game.shown)
    tracker:Hide()
    tracker.scripts.OnHide(tracker)
    check("one that was not up before stays down", not game.shown)
    game.shown = true
    check("the game's quest tracker is never hidden or shown by it", state.gameHides == nil)
    S.Set("trackerAuto", false)
    state.instance = nil
    EnterWorld()
    -- Show Outside Dungeons: out in the world it opens on the dungeon your quests are for.
    check("outside, off, it stays closed", not tracker:IsShown())
    S.Set("trackerOutside", true)
    check("on, out in the world it opens", tracker:IsShown())
    tracker:Hide()
    tracker.scripts.OnHide(tracker)
    EnterWorld()
    check("closed out there, it stays closed", not tracker:IsShown())
    state.instance = { id = 36, name = "The Deadmines" }
    EnterWorld()
    state.instance = nil
    EnterWorld()
    check("until you have been in a dungeon", tracker:IsShown())
    tracker:Hide()
    tracker.scripts.OnHide(tracker)
    S.Set("trackerOutside", false)

    -- The dungeon map: Map on the Bosses title opens it, the bosses stand where they were
    -- placed, and placing's Copy gives the dungeon's line for Data/Maps.lua.
    local J = ns.Journal
    local ragefire = J.Get("RagefireChasm")
    ns.OpenJournalWindow(ragefire)
    local mapTitle
    for _, made in ipairs(state.made) do
        local titleLink = rawget(made, "link")
        if rawget(made, "linkArg") == ragefire and titleLink and rawget(titleLink.text, "text") == "Map" then
            mapTitle = made
        end
    end
    check("the Bosses title has Map", mapTitle ~= nil)
    -- A dungeon with no map yet: Map, muted, saying so on hover; a click does nothing.
    do
        local alcazMap = J.Maps.AlcazPrison
        J.Maps.AlcazPrison = nil
        ns.OpenJournalWindow(J.Get("AlcazPrison"))
        local soon
        for _, made in ipairs(state.made) do
            local titleLink = rawget(made, "link")
            if titleLink and rawget(titleLink, "tip") == "Coming soon" and rawget(titleLink, "shown") ~= false then soon = titleLink end
        end
        check("a dungeon with no map has Map, coming soon", soon ~= nil and soon.disabled == true)
        soon.scripts.OnClick(soon)
        check("which does nothing", true)
        J.Maps.AlcazPrison = alcazMap
    end
    ns.OpenJournalWindow(ragefire)
    -- Placed on this account over the data: Oggleflint moved, Bazzalan taken off the data.
    local bazzalan = J.Maps.RagefireChasm.pins[11519]
    J.Maps.RagefireChasm.pins[11519] = nil
    state.account.journalMapPins = { RagefireChasm = { [11517] = { 1, 0.5, 0.4 }, entrance = { 1, 0.5, 0.9 } } }
    mapTitle.onLink(mapTitle.linkArg)
    local onMap = {}
    for _, made in ipairs(state.made) do
        local boss = rawget(made, "boss")
        if rawget(made, "glow") and boss and rawget(made, "shown") ~= false then onMap[boss.name] = true end
    end
    check("a placed boss is on the map", onMap["Oggleflint"])
    state.spellText = { [J.Abilities[11519][1]] = "Hits the tank.\nThen the healer." }
    local St = J.Style
    local portraits = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
    _G.SetPortraitTextureFromCreatureDisplayID = function() end
    J.DrawDungeonMap()
    local function Rows()
        local list = {}
        for _, made in ipairs(state.made) do
            if rawget(made, "bisText") and rawget(made, "mark") and rawget(made, "shown") ~= false then
                list[#list + 1] = made
            end
        end
        return list
    end
    local function RowFor(name)
        for _, entry in ipairs(Rows()) do
            if entry.boss.name == name then return entry end
        end
    end
    local function PinFor(name)
        for _, made in ipairs(state.made) do
            local boss = rawget(made, "boss")
            if rawget(made, "glow") and boss and boss.name == name and rawget(made, "shown") ~= false then return made end
        end
    end
    local function KillOrder(dungeon)
        local list = {}
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.npc or boss.chest then list[#list + 1] = boss end
            end
        end
        return list
    end
    local order = KillOrder(ragefire)
    local shownRows = Rows()
    local listView = shownRows[1]:GetParent()
    local listScroll = listView:GetParent()
    local mapWindow = listScroll:GetParent()
    local MAP_SHOWN_W, MAP_SHOWN_H = 1002 * 0.7, 668 * 0.7
    local function WingRows()
        local list = {}
        for _, made in ipairs(state.made) do
            if rawget(made, "parent") == listView and rawget(made, "shown") ~= false and rawget(made, "text")
                and not rawget(made, "arrow") and not rawget(made, "mark") then
                list[#list + 1] = made
            end
        end
        return list
    end
    check("the list beside the map, on its right, as tall as it", listScroll.pointX > MAP_SHOWN_W
        and rawget(listScroll, "h") == MAP_SHOWN_H)
    local title
    for _, made in ipairs(state.made) do
        if rawget(made, "arrow") and rawget(made, "parent") == listView and rawget(made, "shown") ~= false then
            title = made
        end
    end
    check("under a BOSSES title with their count", title and tostring(rawget(title.text, "text")):find("^BOSSES") ~= nil)
    check("a row for every boss, placed or not", #shownRows == #order)
    local inOrder, numbered = true, 0
    for i, entry in ipairs(shownRows) do
        if entry.boss ~= order[i] or rawget(entry.name, "text") ~= entry.boss.name or entry.h ~= 28 then inOrder = false end
        if J.Numbered(entry.boss) then
            numbered = numbered + 1
            if rawget(entry.mark.badge.text, "text") ~= numbered then inOrder = false end
        end
    end
    check("in kill order, each with its number on its mark's badge and its name", inOrder)
    local markX, nameX, aligned = shownRows[1].mark.pointX, shownRows[1].name.pointX, true
    for _, entry in ipairs(shownRows) do
        if entry.mark.pointX ~= markX or entry.name.pointX ~= nameX then aligned = false end
    end
    check("every portrait at the same x, every name at the same x after it", aligned
        and nameX > markX * 0.52 + 46 * 0.52)
    check("one wing: no wing names", #WingRows() == 0)
    local pickRow = RowFor("Bazzalan")
    pickRow.scripts.OnClick(pickRow)
    check("a row picks its boss, on an accent fill", rawget(pickRow.fill, "shown") == true)
    check("its mark ringed as a picked pin is", rawget(pickRow.mark.gold, "shown") == true
        and rawget(pickRow.mark.halo, "shown") == false)
    local jergosh = RowFor("Jergosh the Invoker")
    jergosh.scripts.OnClick(jergosh)
    check("and its pin with it", rawget(jergosh.mark.gold, "shown") == true
        and rawget(PinFor("Jergosh the Invoker").gold, "shown") == true)
    pickRow.scripts.OnClick(pickRow)
    check("and no other", rawget(RowFor("Oggleflint").fill, "shown") == false)
    local oggle = RowFor("Oggleflint")
    oggle.scripts.OnEnter(oggle)
    check("hovering a row lights its pin", rawget(PinFor("Oggleflint").glow, "shown") == true)
    check("and the row", rawget(oggle.hover, "shown") == true)
    oggle.scripts.OnLeave(oggle)
    check("leaving puts both out", rawget(PinFor("Oggleflint").glow, "shown") == false
        and rawget(oggle.hover, "shown") == false)
    local oggPin = PinFor("Oggleflint")
    oggPin.scripts.OnEnter(oggPin)
    check("hovering a pin lights its row", rawget(oggle.hover, "shown") == true)
    oggPin.scripts.OnLeave(oggPin)
    check("and leaving it puts it out", rawget(oggle.hover, "shown") == false)
    local current, thisRun = J.Current, J.Kills.ThisRun
    J.Current = function() return { ragefire } end
    J.Kills.ThisRun = function(boss) return boss.name == "Oggleflint" end
    J.DrawDungeonMap()
    check("a boss killed this run is dimmed, with a tick", oggle.killed == true
        and rawget(oggle.mark.badge.tick, "shown") == true and rawget(oggle.mark.badge.text, "shown") == false)
    check("its pin too", rawget(PinFor("Oggleflint").badge.tick, "shown") == true)
    check("the others are not", RowFor("Jergosh the Invoker").killed == false
        and rawget(RowFor("Jergosh the Invoker").mark.badge.tick, "shown") == false)
    local runTitle
    for _, font in ipairs(state.fonts) do
        local text = rawget(font, "text")
        if type(text) == "string" and text:find(ragefire.name:upper(), 1, true)
            and text:find(("1 of %d down"):format(numbered), 1, true) then runTitle = font end
    end
    check("the title counts the run", runTitle ~= nil)
    J.Current, J.Kills.ThisRun = current, thisRun
    J.DrawDungeonMap()
    check("out of the run, nothing is dimmed", oggle.killed == false)

    local spells = J.Abilities[11519]
    local function PageRow(pv, test)
        for _, made in ipairs(state.made) do
            if rawget(made, "shown") ~= false and rawget(made, "parent") == pv and test(made) then return made end
        end
    end
    local function TitleRow(name, bossPage)
        for _, made in ipairs(state.made) do
            local bossTitle = rawget(made, "title")
            if rawget(made, "about") and bossTitle and rawget(bossTitle, "text") == name and rawget(made, "shown") ~= false
                and made:GetParent().bossPage == bossPage then
                return made
            end
        end
    end
    local function Section(pv, name)
        return PageRow(pv, function(made)
            local text = rawget(made, "text")
            return rawget(made, "arrow") and text and tostring(rawget(text, "text")):find("^" .. name) ~= nil
        end)
    end
    local bossTitle = TitleRow("Bazzalan", true)
    check("the page has its name on top", bossTitle ~= nil)
    local pageView = bossTitle:GetParent()
    check("the page under the map and the list, the window's whole width",
        pageView:GetWidth() >= MAP_SHOWN_W + 10 + 210 - 16 and mapWindow:GetWidth() > MAP_SHOWN_W + 210)
    check("all the height under the map", math.abs(pageView.fitHeight - (mapWindow:GetHeight() - 30 - MAP_SHOWN_H - 6 - 10)) < 0.01)
    check("and its level beside it, where Wowhead has it", not J.BossInfo[11519]
        or tostring(rawget(bossTitle.about, "text")):find("Level") ~= nil)
    local lootTitle, abilitiesTitle = Section(pageView, "LOOT"), Section(pageView, "ABILITIES")
    check("its loot and abilities, side by side", lootTitle and abilitiesTitle and lootTitle.top == abilitiesTitle.top
        and lootTitle.w == abilitiesTitle.w and lootTitle.w < pageView:GetWidth() / 2)
    check("nothing to open or close", lootTitle.onToggle == nil and abilitiesTitle.onToggle == nil)
    local pageItem = PageRow(pageView, function(made)
        local boss = rawget(made, "boss")
        return rawget(made, "chanceText") and boss and boss.name == "Bazzalan"
    end)
    check("its items in the left column, compact", pageItem ~= nil and pageItem.w == lootTitle.w
        and pageItem.h == St.DENSE_H)
    local ability = PageRow(pageView, function(made) return rawget(made, "spell") == spells[1] end)
    check("its abilities in the right one", ability ~= nil and ability.w == abilitiesTitle.w)
    check("with room below, what each does on two lines", pageView.abilityLines == 2
        and ability.h == St.DENSE_TALL_H and rawget(ability.desc, "text") == "Hits the tank. Then the healer.")
    local roomy = mapWindow:GetHeight()
    mapWindow:SetHeight(roomy - 200)
    pickRow.scripts.OnClick(pickRow)
    check("without, on one line, cut short, as tall as an item", pageView.abilityLines == 1
        and ability.h == St.DENSE_H and rawget(ability.desc, "text") == "Hits the tank. Then the healer.")
    mapWindow:SetHeight(roomy)
    pickRow.scripts.OnClick(pickRow)
    check("and two again once there is room", pageView.abilityLines == 2 and ability.h == St.DENSE_TALL_H)
    local spellShown
    local spellLines = {}
    rawset(state.tooltip, "SetSpellByID", function(_, id) spellShown = id end)
    ---@diagnostic disable-next-line: duplicate-set-field
    state.tooltip.AddLine = function(_, text) spellLines[#spellLines + 1] = text end
    ability.scripts.OnEnter(ability)
    check("the whole of it in the spell's tooltip", spellShown == spells[1] and Has(spellLines, "Shift-click: link"))
    ability.scripts.OnLeave(ability)
    state.tooltip.AddLine, state.tooltip.SetSpellByID = nil, nil
    state.inserted = nil
    ability.scripts.OnClick(ability)
    check("a plain click on an ability links nothing", state.inserted == nil)
    state.shift = true
    ability.scripts.OnClick(ability)
    state.shift = nil
    check("Shift-click puts its spell link in chat", state.inserted == "|Hspell:" .. spells[1] .. "|h[Spell " .. spells[1] .. "]|h")
    local tipRow = PageRow(pageView, function(made)
        return rawget(made, "mark") and rawget(made, "share") and rawget(made.text, "text") == J.Tips[11519]
    end)
    check("Naowh's tip, written out under its name", tipRow ~= nil and tipRow.top > bossTitle.top
        and tipRow.top < lootTitle.top)
    check("across the page, in a card", tipRow.w == pageView:GetWidth() - St.CARD_PAD * 2)
    check("with its share button", rawget(tipRow.share, "shown") ~= false)
    check("a boss with a tip: the columns under it", lootTitle.top > tipRow.top + tipRow.h)

    J.View.OpenBossLoot(pickRow.boss, ragefire)
    local stackedHeader = TitleRow("Bazzalan", false)
    check("the stacked page has its name on top", stackedHeader ~= nil)
    check("its kind is the game's name for it", rawget(stackedHeader.about, "text"):find("Humanoid", 1, true) ~= nil)
    local stacked = stackedHeader:GetParent()
    local stackedAbility = PageRow(stacked, function(made) return rawget(made, "spell") == spells[1] end)
    check("its abilities written out whole", stackedAbility ~= nil
        and rawget(stackedAbility.desc, "text") == "Hits the tank.\nThen the healer."
        and stackedAbility.h ~= St.DENSE_H)
    check("and Naowh's tip", PageRow(stacked, function(made)
        return rawget(made, "mark") and rawget(made.text, "text") == J.Tips[11519]
    end) ~= nil)
    local stackedAbilities = Section(stacked, "ABILITIES")
    stackedAbilities.onToggle()
    check("a section closes by its title", rawget(stackedAbility, "shown") == false)
    stackedAbilities.onToggle()
    check("and opens again", rawget(stackedAbility, "shown") ~= false)
    local function LootShown(name)
        return PageRow(stacked, function(made)
            local boss = rawget(made, "boss")
            return rawget(made, "chanceText") and boss and boss.name == name
        end) ~= nil
    end
    check("its loot shows", LootShown("Bazzalan"))
    Section(stacked, "LOOT").onToggle()
    check("its loot closes by its title", not LootShown("Bazzalan"))
    J.View.OpenBossLoot(oggle.boss, ragefire)
    check("and opens again on the next boss", LootShown("Oggleflint"))
    J.View.CloseBossLoot()

    local excavation = J.Get("ExcavationSite")
    -- Saltspine's tip taken away for a while, for a boss with none.
    local saltTip = J.Tips[260322]
    J.Tips[260322] = nil
    J.OpenDungeonMap(excavation)
    local horror, guardian = RowFor("Highland Horror"), RowFor("Relic Guardian")
    check("Highland Horror is a quest boss", horror.boss.quest == true and not J.Numbered(horror.boss))
    check("tagged QUEST after its name", rawget(horror.tag, "text") == "QUEST" and rawget(horror.tag, "shown") ~= false)
    check("and Q, muted, where a number goes", rawget(horror.mark.badge.text, "text") == "Q"
        and rawget(horror.mark.badge, "shown") ~= false)
    check("as on its pin", rawget(PinFor("Highland Horror").badge.text, "text") == "Q")
    check("Relic Guardian is the third", rawget(guardian.mark.badge.text, "text") == 3)
    check("and so is its pin", rawget(PinFor("Relic Guardian").badge.text, "text") == 3)
    check("the first not killed is picked", rawget(RowFor("Saltspine").fill, "shown") == true)
    local saltTitle = TitleRow("Saltspine", true)
    check("Saltspine has no tip", J.Tips[260322] == nil and PageRow(pageView, function(made)
        return rawget(made, "mark") and rawget(made, "share")
    end) == nil)
    check("and no gap for one: its columns right under its name",
        Section(pageView, "LOOT").top == saltTitle.top + saltTitle.h + 6)
    J.Tips[260322] = saltTip
    horror.scripts.OnClick(horror)
    local quests = PageRow(pageView, function(made) return rawget(made, "chips") and rawget(made, "label") end)
    local horrorAbilities = Section(pageView, "ABILITIES")
    check("its quest shows", quests ~= nil
        and tostring(rawget(quests.chips[1].name, "text")):find("Horrors in the Highland", 1, true) ~= nil)
    check("over its abilities, as it has no loot", quests.top < horrorAbilities.top and Section(pageView, "LOOT") == nil)
    check("which take the whole width", horrorAbilities.w == pageView:GetWidth())
    ns.OpenJournalWindow(excavation)
    local function Card(name)
        for _, made in ipairs(state.made) do
            local boss = rawget(made, "boss")
            if rawget(made, "badge") and rawget(made, "rare") and boss and boss.name == name
                and rawget(made, "shown") ~= false then
                return made
            end
        end
    end
    check("on the Journal's page, Relic Guardian is the third", rawget(Card("Relic Guardian").number, "text") == 3)
    do
        local relic = Card("Relic Guardian")
        check("no portrait on a boss card while Boss Portraits is off", rawget(relic.face, "shown") == false)
        local before = rawget(relic.name, "pointX")
        local faces = {}
        _G.SetPortraitTextureFromCreatureDisplayID = function(texture, model) faces[texture] = model end
        ns.Journal.Settings.Set("bossPortraits", true)
        relic = Card("Relic Guardian")
        check("with it on, the boss's face from its model, its name moved past it",
            faces[relic.face] == 144224 and rawget(relic.face, "shown") == true
            and rawget(relic.name, "pointX") > before)
        ns.Journal.Settings.Set("bossPortraits", false)
        _G.SetPortraitTextureFromCreatureDisplayID = function() end
    end
    do
        local function KeysRow()
            for _, made in ipairs(state.made) do
                local label = rawget(made, "label")
                if rawget(made, "links") and label and rawget(label, "text") == "Keys" and rawget(made, "shown") ~= false then
                    return made
                end
            end
        end
        ns.OpenJournalWindow(J.Get("Scholomance"))
        check("Keys and Attunements is on by default", KeysRow() ~= nil)
        ns.Journal.Settings.Set("showKeys", false)
        check("no keys row while it is off", KeysRow() == nil)
        state.names[13704] = "Skeleton Key"
        ns.Journal.Settings.Set("showKeys", true)
        local keys = KeysRow()
        check("with it on, Scholomance lists the Skeleton Key", keys ~= nil and rawget(keys.links[1].text, "text") == "Skeleton Key")
        check("unmarked while you do not carry it", rawget(keys.links[1].mark, "text") == "")
        state.owned[13704] = 1
        local pending = #state.timers
        for _, frame in ipairs(state.made) do
            local events = rawget(frame, "events")
            if events and events.BAG_UPDATE_DELAYED then frame.scripts.OnEvent(frame, "BAG_UPDATE_DELAYED") end
        end
        for i = pending + 1, #state.timers do state.timers[i]() end
        check("marked once a bag change shows you do", rawget(KeysRow().links[1].mark, "text") ~= "")
        state.owned[13704], state.names[13704] = nil, nil
        ns.OpenJournalWindow(excavation)
    end
    do
        local function Header(dungeon)
            for _, made in ipairs(state.made) do
                if rawget(made, "stats") and rawget(made, "zone") and rawget(made, "dungeon") == dungeon
                    and rawget(made, "shown") ~= false then
                    return made
                end
            end
        end
        check("Dungeon Art is on by default", state.defaults.dungeonArt == true)
        check("switched off, it draws nothing behind the header", rawget(Header(excavation), "art") == nil)
        ns.Journal.Settings.Set("dungeonArt", true)
        local art = rawget(Header(excavation), "art")
        local coords = art and rawget(art, "texCoord")
        check("with it on, the Excavation Site's loading screen behind its header",
            art ~= nil and rawget(art, "texture") == J.DungeonArt.ExcavationSite and rawget(art, "shown") == true)
        check("cropped to a band across the whole picture", coords ~= nil and coords[1] == 0 and coords[2] == 1
            and coords[3] > 0 and coords[4] < 1 and coords[3] < coords[4])
        ns.OpenJournalWindow(J.Get("Scholomance"))
        local other = Header(J.Get("Scholomance"))
        check("a dungeon with no art of its own shows none", J.DungeonArt.Scholomance == nil
            and (rawget(other, "art") == nil or rawget(rawget(other, "art"), "shown") == false))
        ns.OpenJournalWindow(excavation)
        ns.Journal.Settings.Set("dungeonArt", false)
        check("and turned off, it goes", rawget(rawget(Header(excavation), "art"), "shown") == false)
        for key, file in pairs(J.DungeonArt) do
            check(key .. "'s art is a dungeon's and a file ID", J.Get(key) ~= nil and type(file) == "number")
        end
    end
    do
        local colors = {}
        METHODS.SetTextColor = function(frame, r, g, b) colors[frame] = r + g + b end
        ns.OpenJournalWindow(J.Get("Deadmines"))
        local miner = Card("Miner Johnson")
        local rare = J.Style.RARE_RGB
        local silver = rare.r + rare.g + rare.b
        check("a rare's RARE tag is drawn in the rare colour", rawget(miner.rare, "text") == "RARE"
            and colors[miner.rare] == silver)
        check("no ring on its face while Boss Portraits is off", rawget(miner.ring, "shown") == false)
        ns.Journal.Settings.Set("bossPortraits", true)
        miner = Card("Miner Johnson")
        local cookie = Card("Cookie")
        check("with it on, a rare's face is ringed, another boss's not",
            rawget(miner.ring, "shown") == true and rawget(cookie.ring, "shown") == false)
        ns.Journal.Settings.Set("bossPortraits", false)
        METHODS.SetTextColor = nil
        ns.OpenJournalWindow(excavation)
    end
    do
        local function LinksRow(label)
            for _, made in ipairs(state.made) do
                local text = rawget(made, "label")
                if rawget(made, "links") and text and rawget(text, "text") == label and rawget(made, "shown") ~= false then
                    return made
                end
            end
        end
        state.names[9240] = "Mallet of Zul'Farrak"
        ns.OpenJournalWindow(J.Get("ZulFarrak"))
        check("no summon row while Quest Help is off", LinksRow("Summon") == nil)
        ns.Journal.Settings.Set("questHelp", true)
        local summon = LinksRow("Summon")
        check("with it on, Gahz'rilla's card names the Mallet of Zul'Farrak",
            summon ~= nil and rawget(summon.links[1].text, "text") == "Mallet of Zul'Farrak")
        check("unmarked while you do not carry it", rawget(summon.links[1].mark, "text") == "")
        state.names[9240] = nil

        ns.OpenJournalWindow(J.Get("OnyxiasLair"))
        local keys = LinksRow("Keys")
        state.menu = nil
        keys.links[1].scripts.OnClick(keys.links[1])
        local steps = 0
        for _, entry in ipairs(state.menu or {}) do
            if entry.text:find("^%d+%.") then steps = steps + 1 end
        end
        check("clicking the Drakefire Amulet opens its attunement chain, a step a line", steps > 0)
        ns.Journal.Settings.Set("questHelp", false)
        state.menu = nil
        keys.links[1].scripts.OnClick(keys.links[1])
        check("with Quest Help off, a click only links the key", state.menu == nil)

        ns.Journal.Settings.Set("questHelp", true)
        state.logged[1200] = 5
        state.objectives = { { text = "0/1 Head of Kelris", finished = false } }
        ns.Journal.View.QuestPanel.Show(1200, state.made[#state.made])
        local head
        for _, made in ipairs(state.made) do
            local meta = rawget(made, "meta")
            if meta and rawget(made, "itemID") == 5881 and rawget(made, "shown") ~= false then head = made end
        end
        check("the quest panel lists the Head of Kelris with where it drops and your count",
            head ~= nil and rawget(head.meta, "text") == "Drops from Twilight Lord Kelris"
            and rawget(head.value, "text") == "0/1", head and tostring(rawget(head.meta, "text")))
        ns.Journal.View.QuestPanel.Show(1200, state.made[#state.made])
        state.logged[1200], state.objectives = nil, nil
        ns.Journal.Settings.Set("questHelp", false)
        ns.OpenJournalWindow(excavation)
    end
    for npc, list in pairs(J.Summons) do
        local boss = J.Boss(npc)
        check(npc .. " is a Journal boss something summons", boss ~= nil)
        for _, k in ipairs(list) do
            check(npc .. "'s summon comes from a listed quest, a boss or a named drop", (k.quest and J.Quests.ByID(k.quest))
                or (k.boss and J.Boss(k.boss)) or (k.drop and k.zone) and true)
            check(npc .. "'s summon says it calls the boss", k.opens == "summon")
        end
    end
    for key, list in pairs(J.Keys) do
        check(key .. " has keys and is a dungeon", J.Get(key) ~= nil and #list > 0)
        for _, k in ipairs(list) do
            local givers = type(k.quest) == "table" and { k.quest.A, k.quest.H } or { k.quest }
            for _, id in ipairs(givers) do check(key .. "'s key quest " .. id .. " is listed", J.Quests.ByID(id) ~= nil) end
            check(key .. "'s key comes from a quest or a boss here", #givers > 0 or (k.boss and J.Boss(k.boss)) ~= nil)
            check(key .. "'s key opens what the view knows", k.opens == nil or k.opens == "doors" or k.opens == "shortcut")
        end
    end
    do
        local hall = J.Get("HallOfThanes")
        local function Shown(test)
            for _, made in ipairs(state.made) do
                if rawget(made, "shown") ~= false and test(made) then return made end
            end
        end
        local function LinkSaying(text)
            return Shown(function(made)
                local label = rawget(made, "text")
                return type(label) == "table" and rawget(label, "text") == text and rawget(made, "underline") ~= nil
            end)
        end
        local realCurrent, realThisRun = J.Current, J.Kills.ThisRun
        J.Current = function() return { hall } end
        J.Kills.ThisRun = function(boss) return boss.name == "Faldrim Anvilmar" or boss.name == "Magmatus" end
        ns.OpenJournalWindow(hall)
        local faldrim, plunder = Card("Faldrim Anvilmar"), Card("Plunder")
        check("inside, a boss killed this run shows a check for its number",
            rawget(faldrim, "run") == "killed" and rawget(faldrim.number, "text") ~= 1)
        check("and the first one left is the next boss", rawget(plunder, "run") == "next"
            and rawget(Card("Durgen Dirgehammer"), "run") == nil)
        J.Current, J.Kills.ThisRun = realCurrent, realThisRun
        ns.OpenJournalWindow(hall)
        check("outside, no run state", rawget(Card("Plunder"), "run") == nil
            and rawget(Card("Faldrim Anvilmar").number, "text") == 1)
        check("a boss card lists the quests that need it", Shown(function(made)
            local chips = rawget(made, "chips")
            return chips ~= nil and chips[1] ~= nil and rawget(chips[1], "shown") ~= false
        end) ~= nil)
        local toDo = false
        for _, font in ipairs(state.fonts) do
            local text = rawget(font, "text")
            if type(text) == "string" and text:find("^%d+ to do$") then toDo = true end
        end
        check("the header counts the quests left to do", toDo)
        check("no Share All out of a group", LinkSaying("Share All") == nil)
        state.party = { { name = "Ally", quests = {} } }
        ns.OpenJournalWindow(hall)
        check("Share All on the quests' header in a group", LinkSaying("Share All") ~= nil)
        state.party = nil
        local opened
        local open = ns.Journal.View.OpenBossLoot
        local plunderRow = Card("Plunder")
        plunderRow:GetParent().openBoss = function(boss, dungeon) opened = { boss = boss, dungeon = dungeon } end
        plunderRow.scripts.OnMouseUp(plunderRow, "LeftButton")
        check("clicking a boss opens its page", opened ~= nil and opened.boss.name == "Plunder" and opened.dungeon == hall)
        plunderRow.canPin = true
        state.menu = nil
        plunderRow.scripts.OnMouseUp(plunderRow, "RightButton")
        local onlyBest
        for _, entry in ipairs(state.menu or {}) do
            if entry.text == "Show Only BiS and Upgrades" then onlyBest = entry end
        end
        check("its right-click menu still shows only its BiS and upgrades", onlyBest ~= nil)
        onlyBest.click()
        check("and that pins it", plunderRow:GetParent().pinned == plunderRow.boss)
        state.searchBox:SetText("plunder")
        state.onSearch()
        state.timers[#state.timers]()
        opened = nil
        local found = Card("Plunder")
        found:GetParent().openBoss = function(boss, dungeon) opened = { boss = boss, dungeon = dungeon } end
        found.scripts.OnMouseUp(found, "LeftButton")
        check("a boss found by a search opens with its own dungeon", found:GetParent().dungeon == nil
            and opened ~= nil and opened.dungeon == hall)
        check("and shows no run state there", rawget(found, "run") == nil)
        found:GetParent().openBoss = open
        state.searchBox:SetText("")
        state.onSearch()
        state.timers[#state.timers]()
        plunderRow:GetParent().openBoss = open
        ns.OpenJournalWindow(excavation)
    end
    check("and Highland Horror tagged QUEST, with no number", rawget(Card("Highland Horror").rare, "text") == "QUEST"
        and rawget(Card("Highland Horror").badge, "shown") == false)
    check("its level on its card", tostring(rawget(Card("Highland Horror").stats, "text")):find("Level", 1, true)
        and tostring(rawget(Card("Highland Horror").stats, "text")):find("28", 1, true))
    check("a boss with no known level shows none", J.BossInfo[260322] and J.BossInfo[260322][1] == nil
        and rawget(Card("Saltspine").stats, "text") == "")
    check("?? only for the game's skull level", J.View.Parts.BossLevel(J.BossInfo[10184]) == "??"
        and J.View.Parts.BossLevel({ 24, 26, 1 }) == "24-26" and J.View.Parts.BossLevel({ nil, nil, 1 }) == nil)
    J.OpenDungeonMap(J.Get("Deadmines"))
    local vancleef = RowFor("Edwin VanCleef")
    vancleef.scripts.OnClick(vancleef)
    quests = PageRow(pageView, function(made) return rawget(made, "chips") and rawget(made, "label") end)
    check("a quest boss with loot: the quest under the columns", quests ~= nil
        and quests.top > Section(pageView, "LOOT").top)
    local wailing = J.Get("WailingCaverns")
    J.OpenDungeonMap(wailing)
    local wc = Rows()
    check("Wailing Caverns: its nine bosses", #wc == 9)
    rawset(wc[1].name, "GetStringWidth", function() return 300 end)
    J.DrawDungeonMap()
    check("a long name cut to fit", wc[1].name.w < wc[1].w - nameX)
    rawset(wc[1].name, "GetStringWidth", nil)
    local dragon = RowFor("Deviate Faerie Dragon")
    check("a rare: its tag after its name, R on its badge", rawget(dragon.tag, "shown") ~= false
        and rawget(dragon.tag, "text") == "RARE" and rawget(dragon.mark.badge.text, "text") == "R")
    check("the numbered ones have no tag", rawget(RowFor("Kresh").tag, "shown") == false)
    check("its mark and name where a numbered one's are", dragon.mark.pointX == RowFor("Kresh").mark.pointX
        and dragon.name.pointX == RowFor("Kresh").name.pointX)
    local brd = J.Get("BlackrockDepths")
    J.OpenDungeonMap(brd)
    local brdRows = Rows()
    check("Blackrock Depths: a row for each of its bosses", #brdRows == #KillOrder(brd))
    local headers = {}
    for _, made in ipairs(WingRows()) do headers[rawget(made.text, "text")] = made end
    local wingsRight = true
    for w, wing in ipairs(brd.wings) do
        local header, nextWing = headers[wing.name:upper()], brd.wings[w + 1]
        local after = nextWing and headers[nextWing.name:upper()]
        if not header then wingsRight = false end
        for _, entry in ipairs(brdRows) do
            local mine = false
            for _, boss in ipairs(wing.bosses) do mine = mine or boss == entry.boss end
            if mine and header and (entry.top < header.top or after and entry.top > after.top) then wingsRight = false end
        end
    end
    check("each wing's name over its own bosses", wingsRight)
    local firstOfRing
    for _, entry in ipairs(brdRows) do
        if not firstOfRing and entry.boss == brd.wings[2].bosses[1] then firstOfRing = entry end
    end
    check("numbers start again under each wing", rawget(firstOfRing.mark.badge.text, "text") == 1)
    local safe
    for _, entry in ipairs(brdRows) do
        if entry.boss.chest then safe = entry end
    end
    check("a chest's mark is a chest's icon", safe and rawget(safe.mark.face, "texture") == St.CHEST_ICON
        and rawget(safe.mark.face, "shown") ~= false and rawget(safe.mark.big, "shown") == false)
    check("tagged CHEST", rawget(safe.tag, "text") == "CHEST")
    check("as is its pin's", not PinFor(safe.boss.name)
        or rawget(PinFor(safe.boss.name).face, "texture") == St.CHEST_ICON)
    rawset(listScroll, "SetVerticalScroll", function(self, offset) self.offset = offset end)
    rawset(listScroll, "GetVerticalScroll", function(self) return rawget(self, "offset") or 0 end)
    check("longer than the map, the list scrolls", listView:GetHeight() > rawget(listScroll, "h"))
    safe.scripts.OnClick(safe)
    local offset = listScroll:GetVerticalScroll()
    check("the picked row scrolled into view", offset > 0 and safe.top >= offset
        and safe.top + 28 <= offset + rawget(listScroll, "h"))
    rawset(listScroll, "SetVerticalScroll", nil)
    rawset(listScroll, "GetVerticalScroll", nil)
    J.OpenDungeonMap(ragefire)
    check("back to one wing: no wing names", #WingRows() == 0)

    local function Door()
        for _, made in ipairs(state.made) do
            if rawget(made, "key") == "entrance" and made.view.editable then return made end
        end
    end
    local door = Door()
    rawset(door.text, "GetStringWidth", function() return 75 end)
    -- The rare just right of the entrance, wherever the data has it.
    local faerie = J.Maps.WailingCaverns.pins[5912]
    local gate = J.Maps.WailingCaverns.entrance
    J.Maps.WailingCaverns.pins[5912] = { gate[1], gate[2] + 0.115, gate[3] + 0.01 }
    J.OpenDungeonMap(wailing)
    check("Wailing Caverns: the entrance's label clear of the rare on its right", door.side == "LEFT"
        and rawget(door.text, "shown") ~= false)
    J.Maps.WailingCaverns.pins[5912] = faerie
    local placedPins = state.account.journalMapPins
    state.account.journalMapPins = { RagefireChasm = { entrance = { 1, 0.5, 0.5 },
        [11517] = { 1, 0.1, 0.1 }, [11520] = { 1, 0.9, 0.1 }, [11518] = { 1, 0.1, 0.9 }, [11519] = { 1, 0.9, 0.9 } } }
    J.OpenDungeonMap(ragefire)
    check("with room, the label is on the right", door.side == "RIGHT")
    state.account.journalMapPins.RagefireChasm[11519] = { 1, 0.56, 0.5 }
    J.DrawDungeonMap()
    check("a pin there: on the left", door.side == "LEFT")
    state.account.journalMapPins.RagefireChasm.entrance = { 1, 0.045, 0.5 }
    state.account.journalMapPins.RagefireChasm[11519] = { 1, 0.1, 0.47 }
    J.DrawDungeonMap()
    check("the map's edge on the left and a pin on the right: below", door.side == "BELOW")
    state.account.journalMapPins.RagefireChasm = { entrance = { 1, 0.5, 0.5 },
        [11517] = { 1, 0.44, 0.5 }, [11520] = { 1, 0.56, 0.5 }, [11518] = { 1, 0.5, 0.46 }, [11519] = { 1, 0.5, 0.54 } }
    J.DrawDungeonMap()
    check("boxed in: no label", door.side == nil and rawget(door.text, "shown") == false)
    check("but the entrance still shows", rawget(door, "shown") ~= false)
    state.account.journalMapPins.RagefireChasm[11517] = { 2, 0.44, 0.5 }
    J.DrawDungeonMap()
    check("a placing on a floor the map no longer has: the data's spot", PinFor("Oggleflint") ~= nil
        and PinFor("Oggleflint").atX == J.Maps.RagefireChasm.pins[11517][2] * J.C.MAP_W)
    state.account.journalMapPins = placedPins
    rawset(door.text, "GetStringWidth", nil)
    _G.SetPortraitTextureFromCreatureDisplayID = portraits
    J.OpenDungeonMap(J.Get("Deadmines"))
    J.OpenDungeonMap(ragefire)
    local fold = mapWindow.fold:GetParent()
    local atMouse, openLoot = 0, J.View.OpenBossLoot
    J.View.OpenBossLoot = function() atMouse = atMouse + 1 end
    fold.scripts.OnClick(fold)
    check("folded: the page away, the list stays beside the map", state.account.journalMapFolded == true
        and rawget(pageView:GetParent(), "shown") == false and rawget(listScroll, "shown") ~= false)
    oggPin = PinFor("Oggleflint")
    oggPin.scripts.OnClick(oggPin, "LeftButton")
    check("a pin opens its loot at the mouse", atMouse == 1)
    RowFor("Oggleflint").scripts.OnClick(RowFor("Oggleflint"))
    check("and so does a row", atMouse == 2)
    J.View.OpenBossLoot = openLoot
    fold.scripts.OnClick(fold)
    check("unfolded: the page again", state.account.journalMapFolded == nil
        and rawget(pageView:GetParent(), "shown") == true and rawget(pageView, "shown") ~= false)
    pickRow = RowFor("Bazzalan")
    pickRow.scripts.OnClick(pickRow)
    -- A drag on a pin while not placing keeps nothing: only placing saves where a pin stands.
    state.account.journalMapPins = nil
    for _, made in ipairs(state.made) do
        if rawget(made, "glow") and made.scripts.OnDragStop and rawget(made, "shown") ~= false then
            made.scripts.OnDragStop(made)
        end
    end
    check("a drag outside placing saves nothing", state.account.journalMapPins == nil)
    state.account.journalMapPins = { RagefireChasm = { [11517] = { 1, 0.5, 0.4 }, entrance = { 1, 0.5, 0.9 } } }
    -- This run: from a loading screen into the dungeon; a login outside ends it.
    local Kills = J.Kills
    state.instance = { id = 36, name = "The Deadmines" }
    Kills.NoteRun(J.Current(), false)
    local run = state.account
    for _, all in pairs(state.account) do
        if type(all) == "table" and all[state.guid] and all[state.guid].at then run = all[state.guid] end
    end
    check("a loading screen into a dungeon starts a run", run ~= state.account and run.at ~= nil)
    state.instance = nil
    Kills.NoteRun(nil, false)
    check("leaving keeps it, for a run back", run.at ~= nil and run.left ~= nil)
    Kills.NoteRun(nil, true)
    check("a login outside ends it", run.at == nil)
    Measure("the dungeon map and its list of bosses drawn", 2, function() J.DrawDungeonMap() end)
    Measure("a boss picked again on the map, its page drawn", 2, function() pickRow.scripts.OnClick(pickRow) end)
    -- The Naowh mark in its title: back to the Journal, on the dungeon's page.
    local openJournal = ns.OpenJournalWindow
    local openedOn
    ns.OpenJournalWindow = function(dungeon) openedOn = dungeon end
    for _, made in ipairs(state.made) do
        local icon = rawget(made, "icon")
        if icon and made.scripts.OnClick and made.scripts.OnEnter and rawget(icon, "alpha") == nil
            and made.scripts.OnDragStart == nil and not rawget(made, "boss") then
            made.scripts.OnClick(made)
        end
    end
    ns.OpenJournalWindow = openJournal
    check("its title opens the Journal on the dungeon's page", openedOn == ragefire)
    check("one the data places too", onMap["Jergosh the Invoker"])
    check("one not placed yet is not", not onMap["Bazzalan"])
    ns.DungeonMapCommand("mappins")
    local copy
    for _, button in ipairs(state.buttons) do
        if button.label == "Copy" then copy = button end
    end
    copy.onClick()
    local text = state.copied and state.copied.text or ""
    check("Copy gives where each boss stands", text:find("[11517] = { 1, 0.5, 0.4 },   -- Oggleflint", 1, true) ~= nil)
    check("and the entrance", text:find("entrance = { 1, 0.5, 0.9 },", 1, true) ~= nil)
    do
        local ragefireCopy = assert(loadstring("return {\n" .. text .. "\n}"))().RagefireChasm
        check("and its local image without cropping", ragefireCopy.image == J.Maps.RagefireChasm.image
            and ragefireCopy.imageBottom == 1)
    end
    ns.DungeonMapCommand("mappins")
    J.OpenDungeonMap(ragefire)
    check("a second Map closes it", true)
    -- A dungeon with two floors of the addon's own pictures: one images line keeps both.
    local ubrs = J.Get("UpperBlackrockSpire")
    J.OpenDungeonMap(ubrs)
    ns.DungeonMapCommand("mappins")
    for _, button in ipairs(state.buttons) do
        if button.label == "Copy" then copy = button end
    end
    state.copied = nil
    copy.onClick()
    text = state.copied and state.copied.text or ""
    local _, imageLines = text:gsub("images = ", "")
    check("Copy gives one images line", imageLines == 1)
    local pasted = assert(loadstring("return {\n" .. text .. "\n}"))().UpperBlackrockSpire
    check("which keeps every floor's picture", pasted.images[8] == J.Maps.UpperBlackrockSpire.images[8]
        and pasted.images[9] == J.Maps.UpperBlackrockSpire.images[9])
    check("and the floors in the order you walk them", text:find("order = { 9, 8, 7 },", 1, true) ~= nil)
    ns.DungeonMapCommand("mappins")
    J.OpenDungeonMap(ubrs)

    -- Quest Pins: the quest givers, hand-ins and quest objects inside a dungeon. The data has who
    -- and which quests, never a spot: a pin shows once placed with /nf mappins, and only with the
    -- option on. Its own function: this block is at Lua 5.1's limit of locals.
    do (function()
        local Map = J.DungeonMap
        local entries, maps = 0, 0
        for key, map in pairs(J.Maps) do
            local dungeon = J.Get(key)
            local bossKeys, seen = {}, {}
            Map.EachBoss(dungeon, function(_, _, bossKey) bossKeys[bossKey] = true end)
            if map.quests then maps = maps + 1 end
            for _, data in ipairs(map.quests or {}) do
                entries = entries + 1
                local id = data.npc or data.object
                local pinKey = Map.QuestKey(data)
                check("a quest pin is an NPC or an object, not both: " .. key,
                    (data.npc == nil) ~= (data.object == nil) and type(id) == "number" and id > 0 and id % 1 == 0)
                check("and has a name: " .. key, type(data.name) == "string" and data.name ~= "")
                check("and is listed once on its map: " .. data.name, not seen[pinKey])
                seen[pinKey] = true
                check("and is not one of its bosses: " .. data.name, not bossKeys[pinKey])
                local spot = map.pins[pinKey]
                check("and its spot, once placed, is on one of the map's floors: " .. data.name, spot == nil
                    or (spot[1] >= 1 and spot[1] <= map.floors and spot[2] >= 0 and spot[2] <= 1
                        and spot[3] >= 0 and spot[3] <= 1))
                local roles = 0
                for _, role in ipairs({ "start", "finish", "use" }) do
                    for _, quest in ipairs(data[role] or {}) do
                        roles = roles + 1
                        local ok = type(quest) == "number"
                        if type(quest) == "table" then
                            ok = next(quest) ~= nil
                            for side, questID in pairs(quest) do
                                ok = ok and (side == "A" or side == "H") and type(questID) == "number"
                            end
                        end
                        check("a quest is an ID, or one ID per side: " .. data.name, ok)
                    end
                end
                check("it starts, takes or is used for a quest: " .. data.name, roles > 0)
            end
        end
        check("the quest givers and objects of every classic dungeon with one inside", entries == 56 and maps == 17)

        local function QuestPins()
            local list = {}
            for _, made in ipairs(state.made) do
                if rawget(made, "quest") and rawget(made, "glow") and rawget(made, "shown") ~= false then
                    list[#list + 1] = made
                end
            end
            return list
        end
        local function Watcher()
            for _, made in ipairs(state.made) do
                local events = made.events
                if events.QUEST_LOG_UPDATE and events.PLAYER_LEVEL_UP and not events.PLAYER_EQUIPMENT_CHANGED then
                    return made
                end
            end
        end
        local function QuestEvent()
            local watcher = Watcher()
            local pending = #state.timers
            watcher.scripts.OnEvent(watcher, "QUEST_LOG_UPDATE")
            watcher.scripts.OnEvent(watcher, "QUEST_LOG_UPDATE")
            check("quest events are drawn once, on the next frame", #state.timers == pending + 1)
            state.timers[#state.timers]()
        end
        check("Quest Pins is on by default", ns.FEATURES.journal.mapQuestPins == true)
        local placedBefore = state.account.journalMapPins
        state.account.journalMapPins = {}
        local depths = J.Get("BlackrockDepths")
        local depthsPins, shippedSpots = J.Maps.BlackrockDepths.pins, {}
        for _, data in ipairs(J.Maps.BlackrockDepths.quests) do
            local pinKey = Map.QuestKey(data)
            shippedSpots[pinKey], depthsPins[pinKey] = depthsPins[pinKey], nil
        end
        J.OpenDungeonMap(depths)
        local floor = Map.windowView.floor
        state.account.journalMapPins.BlackrockDepths = { [9021] = { floor, 0.5, 0.5 } }
        J.DrawDungeonMap()
        check("off: no quest pin, even a placed one", #QuestPins() == 0)
        check("and nothing listens for quests", Watcher() == nil)
        S.Set("mapQuestPins", true)
        local pins = QuestPins()
        check("on: the placed one shows", #pins == 1 and pins[1].quest.name == "Kharan Mighthammer")
        check("those not placed yet are not drawn", #pins == 1)
        local kharan = pins[1]
        check("at its spot", kharan.pointX == 0.5 * J.C.MAP_W)
        check("its quests for your side only, Kharan's Tale once though he gives and takes it",
            #kharan.quests == 3)
        check("a quest waiting on its chain: a grey !", kharan.quests[1].kind == "prereq"
            and rawget(kharan.face, "texture") == St.BANG)
        check("quest events are listened for while it shows", Watcher() ~= nil)
        state.onQuest = { [4341] = true }
        QuestEvent()
        check("one in your log he takes: a ?", kharan.quests[1].kind == "active"
            and kharan.quests[1].loggedID == 4341 and rawget(kharan.face, "texture") == St.QUESTION)
        kharan.scripts.OnClick(kharan, "RightButton")
        check("right-click: the quest's menu, as on its row", state.menu and state.menu.title == kharan.quests[1].name)
        state.inserted, state.shift = nil, true
        kharan.scripts.OnClick(kharan, "LeftButton")
        check("Shift-click: the quest's link into the chat box", state.inserted == "|Hquest:4341|h[Quest 4341]|h")
        state.shift = nil
        state.onQuest, state.allDone = nil, true
        QuestEvent()
        check("all done: greyed, nothing for you", kharan.quests[1].kind == "none")
        local redraw, redraws = J.RedrawDungeonMaps, 0
        J.RedrawDungeonMaps = function(...) redraws = redraws + 1; return redraw(...) end
        QuestEvent()
        check("a quest event that changes no quest there redraws nothing", redraws == 0)
        J.RedrawDungeonMaps = redraw
        state.allDone = nil
        state.menu = nil
        ns.DungeonMapCommand("mappins")
        check("placing: every quest pin offered, the rest along the top", #QuestPins() == #J.Maps.BlackrockDepths.quests)
        for _, button in ipairs(state.buttons) do
            if button.label == "Copy" then copy = button end
        end
        state.copied = nil
        copy.onClick()
        text = state.copied and state.copied.text or ""
        local brdCopy = assert(loadstring("return {\n" .. text .. "\n}"))().BlackrockDepths
        check("Copy gives the placed quest pin's spot", text:find("[9021] = { " .. floor
            .. ", 0.5, 0.5 },   -- Kharan Mighthammer", 1, true) ~= nil and brdCopy.pins[9021][2] == 0.5)
        local same = #brdCopy.quests == #J.Maps.BlackrockDepths.quests
        for i, data in ipairs(J.Maps.BlackrockDepths.quests) do
            local copied = brdCopy.quests[i]
            same = same and copied.npc == data.npc and copied.object == data.object and copied.name == data.name
            for _, role in ipairs({ "start", "finish", "use" }) do
                for n, quest in ipairs(data[role] or {}) do
                    local back = copied[role] and copied[role][n]
                    same = same and (type(quest) == "number" and back == quest
                        or type(quest) == "table" and type(back) == "table" and back.A == quest.A and back.H == quest.H)
                end
            end
        end
        check("and its quest givers and objects as the data has them", same)
        ns.DungeonMapCommand("mappins")
        -- Rares are boss pins: one with no spot yet waits along the top while placing.
        local kraul = J.Get("RazorfenKraul")
        J.OpenDungeonMap(kraul)
        ns.DungeonMapCommand("mappins")
        local offered, rares = {}, 0
        for _, made in ipairs(state.made) do
            local boss = rawget(made, "boss")
            if rawget(made, "glow") and boss and rawget(made, "shown") ~= false then offered[boss] = true end
        end
        for _, wing in ipairs(kraul.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.rare then
                    rares = rares + 1
                    check("placing offers the rare " .. boss.name, offered[boss])
                end
            end
        end
        check("Razorfen Kraul's three unplaced rares", rares == 3)
        ns.DungeonMapCommand("mappins")
        J.OpenDungeonMap(depths)
        S.Set("mapQuestPins", false)
        check("off again: the quest pins go", #QuestPins() == 0)
        check("and nothing listens for quests", next(Watcher() and Watcher().events or {}) == nil)
        J.OpenDungeonMap(depths)
        state.account.journalMapPins = placedBefore
        for pinKey, spot in pairs(shippedSpots) do depthsPins[pinKey] = spot end
    end)() end

    local NOT_PLACED = {
        Dalaran = { [246931] = "Mana Wraith" },
        LowerBlackrockSpire = { [10584] = "Urok Doomhowl" },
        Scholomance = { [10432] = "Vectus", [10433] = "Marduk Blackpool", [10508] = "Ras Frostwhisper",
            [16118] = "Kormok" },
        Stratholme = { [11032] = "Malor the Zealous", [11058] = "Ezra Grimm" },
        ShapersTerrace = { [261993] = "King Op" },
        UpperBlackrockSpire = { [16042] = "Lord Valthalak" },
    }
    local function MapFloorsAndGaps(key, map, dungeon)
        local function Offered(n)
            if map.floor then return n == map.floor end
            if map.order then
                for _, m in ipairs(map.order) do
                    if m == n then return true end
                end
                return false
            end
            return n >= 1 and n <= map.floors
        end
        for id, spot in pairs(map.pins) do
            check("on a floor its switch offers: " .. key .. " " .. id, Offered(spot[1]))
        end
        check("its entrance on a floor its switch offers: " .. key, map.entrance == nil or Offered(map.entrance[1]))
        local function Shipped(path)
            local file = io.open(path:gsub("^Interface\\AddOns\\", ""):gsub("^NaowhForever\\", ""):gsub("\\", "/") .. ".blp", "rb")
            if file then file:close() end
            return file ~= nil
        end
        if map.image then
            check("its picture is shipped: " .. key, Shipped(map.image))
            for n = 2, map.floors do
                check("its floor's picture is shipped: " .. key .. " " .. n,
                    Shipped(map.images and map.images[n] or map.image .. n))
            end
        end
        for n, path in pairs(map.images or {}) do
            check("its floor's picture is shipped: " .. key .. " " .. n, Shipped(path))
            check("and offered: " .. key .. " " .. n, Offered(n))
        end
        if next(map.pins) == nil then return end
        local waiting = NOT_PLACED[key] or {}
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.npc and boss.encounters and #boss.encounters > 0 then
                    check("a boss with an encounter is pinned or listed as not placed yet: " .. key .. " "
                        .. boss.name, (map.pins[boss.npc] ~= nil) ~= (waiting[boss.npc] ~= nil))
                end
            end
        end
    end

    local function FloorsAndFollowing()
        local function FloorsOf(shownView)
            local list = {}
            for i, n in ipairs(shownView.floors) do list[i] = n end
            return table.concat(list, ",")
        end
        local function ShownView(name)
            local pin = PinFor(name)
            return pin and pin.view
        end
        local savedPins = state.account.journalMapPins
        state.account.journalMapPins = nil
        J.OpenDungeonMap(ubrs)
        local ubrsView = ShownView("Pyroguard Emberseer")
        check("Upper Blackrock Spire: its three floors, walked from Dragonspire Hall", ubrsView ~= nil
            and FloorsOf(ubrsView) == "9,8,7")
        check("on its first boss's floor, the addon's picture of it", ubrsView.floor == 8
            and rawget(ubrsView.picture, "shown") == true
            and ubrsView.picture.texture == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\UpperBlackrockSpire8"
            and rawget(ubrsView.tiles[1], "shown") == false)
        check("switching from an imported image restores the original crop", ubrsView.picture.texCoord[4] == 683 / 1024)
        check("named for the switch", rawget(ubrsView.floorName, "text") == "Hall of Binding and the Rookery")
        ubrsView:Step(1)
        check("the art's seventh floor next, numbered as walked", ubrsView.floor == 7
            and rawget(ubrsView.floorName, "text") == "Floor 3" and rawget(ubrsView.picture, "shown") == true
            and rawget(ubrsView.tiles[1], "shown") == false
            and ubrsView.picture.texture == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\BlackrockSpire7")
        check("with Rend's pin on it", PinFor("Warchief Rend Blackhand") ~= nil and PinFor("Pyroguard Emberseer") == nil)
        ubrsView:Step(1)
        check("then round to Dragonspire Hall, where you come in", ubrsView.floor == 9
            and rawget(ubrsView.floorName, "text") == "Dragonspire Hall"
            and ubrsView.picture.texture == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\UpperBlackrockSpire9")
        local rend = RowFor("Warchief Rend Blackhand")
        rend.scripts.OnClick(rend)
        check("a mapRow of a boss on another floor goes to its floor", ubrsView.floor == 7
            and rawget(PinFor("Warchief Rend Blackhand").gold, "shown") == true)
        J.OpenDungeonMap(J.Get("LowerBlackrockSpire"))
        check("Lower Blackrock Spire: only the art's first six floors",
            FloorsOf(ShownView("War Master Voone") or ShownView("Highlord Omokk")) == "1,2,3,4,5,6")
        J.OpenDungeonMap(J.Get("ShadowfangKeep"))
        local sfkView = ShownView("Rethilgore")
        check("an imported map shows the complete image", sfkView.picture.texCoord[4] == 1
            and rawget(sfkView.tiles[1], "shown") == false)
        check("Shadowfang Keep: the imported floors in order", FloorsOf(sfkView) == "1,2,4,5,7")
        sfkView:Step(2)
        check("the courtyard's first floor third", sfkView.floor == 4
            and rawget(sfkView.floorName, "text") == "Courtyard's 1st Floor")
        local odo = RowFor("Odo the Blindwatcher")
        odo.scripts.OnEnter(odo)
        check("hovering a mapRow lights its pin on the floor shown", rawget(PinFor("Odo the Blindwatcher").glow, "shown") == true)
        odo.scripts.OnLeave(odo)
        sfkView:Step(1)
        check("Fenrus' Room after it", sfkView.floor == 5 and rawget(sfkView.floorName, "text") == "Fenrus' Room"
            and PinFor("Odo the Blindwatcher") == nil and PinFor("Fenrus the Devourer") ~= nil)
        J.OpenDungeonMap(J.Get("BlackfathomDeeps"))
        local bfdView = ShownView("Ghamoo-ra")
        while bfdView.floor ~= 2 do bfdView:Step(1) end
        local lorgus, faded = 0, 0
        for _, made in ipairs(state.made) do
            local boss = rawget(made, "boss")
            if rawget(made, "glow") and made.view == bfdView and boss and boss.name == "Lorgus Jett"
                and rawget(made, "shown") ~= false then
                lorgus = lorgus + 1
                if rawget(made, "also") then faded = faded + 1 end
            end
        end
        check("Lorgus Jett: his pin and the two other spots he can spawn at", lorgus == 3 and faded == 2)
        for _, key in ipairs({ "RazorfenDowns", "Uldaman", "Maraudon", "SunkenTemple", "BlackrockDepths", "DireMaul",
            "LowerBlackrockSpire", "UpperBlackrockSpire", "Scholomance", "Stratholme", "Dalaran", "ShadowfangKeep",
            "Deadmines" }) do
            local dungeon = J.Get(key)
            J.OpenDungeonMap(dungeon)
            local shownView
            for _, mapRow in ipairs(Rows()) do
                shownView = shownView or (PinFor(mapRow.boss.name) and PinFor(mapRow.boss.name).view)
            end
            local lit, linked, seen = true, true, 0
            for _ = 1, shownView and #shownView.floors or 0 do
                if J.Maps[key].image then
                    local map = J.Maps[key]
                    local image = map.images and map.images[shownView.floor]
                        or map.image .. (shownView.floor > 1 and shownView.floor or "")
                    check(key .. ": its floor uses the shipped picture: " .. shownView.floor,
                        shownView.picture.texture == image and rawget(shownView.picture, "shown") == true
                            and rawget(shownView.tiles[1], "shown") == false
                            and rawget(shownView.tiles[12], "shown") == false)
                end
                for _, mapRow in ipairs(Rows()) do
                    local pin = PinFor(mapRow.boss.name)
                    if pin then
                        seen = seen + 1
                        mapRow.scripts.OnEnter(mapRow)
                        lit = lit and rawget(pin.glow, "shown") == true
                        mapRow.scripts.OnLeave(mapRow)
                        pin.scripts.OnEnter(pin)
                        lit = lit and rawget(mapRow.hover, "shown") == true
                        pin.scripts.OnLeave(pin)
                    end
                    local spot = J.Maps[key].pins[mapRow.key]
                    if spot and spot[1] ~= shownView.floor then
                        local at = shownView.floor
                        mapRow.scripts.OnClick(mapRow)
                        local there = PinFor(mapRow.boss.name)
                        linked = linked and shownView.floor == spot[1] and there ~= nil and rawget(there.gold, "shown") == true
                        shownView.floor = at
                        shownView:Draw()
                    end
                end
                shownView:Step(1)
            end
            local questPins, pinned = {}, 0
            for _, data in ipairs(J.Maps[key].quests or {}) do questPins[data.npc or -data.object] = true end
            for pinKey in pairs(J.Maps[key].pins) do
                if not questPins[pinKey] then pinned = pinned + 1 end
            end
            check(key .. ": its rows and pins light each other on every floor", shownView ~= nil and lit and seen == pinned)
            check(key .. ": a mapRow goes to its pin's floor", linked)
            J.OpenDungeonMap(dungeon)
        end

        local dalaran = J.Get("Dalaran")
        J.OpenDungeonMap(dalaran)
        local dalRows = Rows()
        check("City of Dalaran: a mapRow for each of its nine bosses", #dalRows == 9 and #KillOrder(dalaran) == 9
            and dalRows[1].boss.name == "Atrexis the Grave Knight")
        local inKillOrder = true
        for i, name in ipairs({ "Atrexis the Grave Knight", "Arcane Anomaly", "Fel Ancient", "Unstable Sentinel",
            "Shade of the Archmage" }) do
            if dalRows[i].boss.name ~= name or rawget(dalRows[i].mark.badge.text, "text") ~= i then inKillOrder = false end
        end
        check("numbered in kill order", inKillOrder)
        check("Lyn the Ignored a rare", rawget(RowFor("Lyn the Ignored").tag, "text") == "RARE")
        check("the Mana Wraith optional", rawget(RowFor("Mana Wraith").tag, "text") == "OPTIONAL")
        local dalView = ShownView("Atrexis the Grave Knight")
        check("opens in the sewers, its first imported picture", dalView ~= nil and dalView.floor == 1
            and FloorsOf(dalView) == "1,2"
            and dalView.picture.texture == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\CityOfDalaran_1"
            and rawget(dalView.floorName, "text") == "Sewers")
        check("Atrexis alone there", PinFor("Arcane Anomaly") == nil)
        local shade = RowFor("Shade of the Archmage")
        shade.scripts.OnClick(shade)
        check("a mapRow on the city's floor goes up to it", dalView.floor == 2
            and dalView.picture.texture == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\CityOfDalaran_2"
            and rawget(dalView.floorName, "text") == "Streets")
        check("its pin ringed there, Atrexis's gone", rawget(PinFor("Shade of the Archmage").gold, "shown") == true
            and PinFor("Atrexis the Grave Knight") == nil)
        local anomaly = PinFor("Arcane Anomaly")
        anomaly.scripts.OnEnter(anomaly)
        check("its pins light their rows", rawget(RowFor("Arcane Anomaly").hover, "shown") == true)
        anomaly.scripts.OnLeave(anomaly)

        dalView:Step(-1)
        ns.DungeonMapCommand("mappins")
        check("placing: Arcane Anomaly waits along the top, from the city", PinFor("Arcane Anomaly") ~= nil
            and PinFor("Arcane Anomaly").atX == nil and PinFor("Arcane Anomaly").elsewhere == "Streets")
        check("Atrexis stays where it is", PinFor("Atrexis the Grave Knight").atX ~= nil
            and PinFor("Atrexis the Grave Knight").elsewhere == nil)
        check("and the Mana Wraith, on no floor yet, waits too", PinFor("Mana Wraith").atX == nil
            and PinFor("Mana Wraith").elsewhere == nil)
        local tray, apart = {}, true
        for i = 1, dalView.used do
            if not dalView.pins[i].atX then tray[#tray + 1] = dalView.pins[i] end
        end
        for i = 2, #tray do
            if tray[i].pointX == tray[i - 1].pointX then apart = false end
        end
        check("each in its own place along the top", #tray == 7 and apart)
        local atrexis = PinFor("Atrexis the Grave Knight")
        atrexis.scripts.OnClick(atrexis, "RightButton")
        check("a right-click takes a pin off its floor", state.account.journalMapPins.Dalaran[247126] == false
            and PinFor("Atrexis the Grave Knight").atX == nil)
        state.copied = nil
        copy.onClick()
        text = state.copied and state.copied.text or ""
        check("Copy leaves it out", text:find("[247126]", 1, true) == nil and text:find("[245999]", 1, true) ~= nil)
        check("and keeps the floors' names",
            text:find('names = { [1] = "Sewers", [2] = "Streets" },', 1, true) ~= nil)
        ns.DungeonMapCommand("mappins")
        check("taken off, it is on no floor, whatever the data says", PinFor("Atrexis the Grave Knight") == nil)
        state.account.journalMapPins = nil
        J.DrawDungeonMap()
        check("until the placings are cleared", PinFor("Atrexis the Grave Knight") ~= nil)
        J.OpenDungeonMap(dalaran)

        local blackmaw = J.Get("BlackmawHold")
        J.OpenDungeonMap(blackmaw)
        local blackmawView = J.DungeonMap.windowView
        check("Blackmaw Hold: no pins yet, so all its pictures are offered", blackmawView.dungeon == blackmaw
            and FloorsOf(blackmawView) == "1,2,3,4,5,6"
            and blackmawView.picture.texture == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\BlackmawHold_1"
            and rawget(blackmawView.floorName, "text") == "Blackmaw Grove")
        blackmawView:Step(1)
        check("Festering Grotto next", blackmawView.picture.texture
            == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\BlackmawHold_2"
            and rawget(blackmawView.floorName, "text") == "Festering Grotto")

        J.OpenDungeonMap(J.Get("AlcazPrison"))
        local alcazView = J.DungeonMap.windowView
        local stairs = alcazView.stairs[1]
        check("Alcaz Prison: the stairs down show on the Main Unit", alcazView.floor == 1
            and rawget(stairs, "shown") ~= false and stairs.stairs.to == 2)
        stairs.scripts.OnClick(stairs)
        check("and a click goes down to the Maximum Security Unit", alcazView.floor == 2
            and rawget(alcazView.floorName, "text") == "Maximum Security Unit" and rawget(stairs, "shown") == false)

        local drowned = J.Get("DrownedCity")
        J.OpenDungeonMap(drowned)
        local drownedView = J.DungeonMap.windowView
        check("The Drowned City: its bosses are all in the main city", drownedView.dungeon == drowned
            and FloorsOf(drownedView) == "1" and PinFor("Zul'Alai") ~= nil
            and drownedView.picture.texture == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\DrownedCity_1")

        local function MapLink(dungeon)
            for _, made in ipairs(state.made) do
                local titleLink = rawget(made, "link")
                if rawget(made, "linkArg") == dungeon and titleLink and rawget(titleLink.text, "text") == "Map"
                    and rawget(made, "shown") ~= false then
                    return made
                end
            end
        end
        local folded = state.account.journalMapFolded
        state.account.journalMapFolded = nil
        ns.OpenJournalWindow(ragefire)
        local mapLink = MapLink(ragefire)
        mapLink.onLink(mapLink.linkArg, mapLink.link)
        check("Map opens Ragefire Chasm's map beside the Journal", rawget(mapWindow, "shown") ~= false
            and PinFor("Oggleflint") ~= nil)
        ns.OpenJournalWindow(wailing)
        check("the Journal on Wailing Caverns: the map follows", rawget(mapWindow, "shown") ~= false
            and PinFor("Mutanus the Devourer") ~= nil and PinFor("Oggleflint") == nil and #Rows() == 9)
        check("with its first boss picked", rawget(RowFor(wailing.wings[1].bosses[1].name).fill, "shown") == true)
        ns.OpenJournalWindow(dalaran)
        check("and to City of Dalaran", PinFor("Atrexis the Grave Knight") ~= nil and #Rows() == 9)
        do
            local alcazMap = J.Maps.AlcazPrison
            J.Maps.AlcazPrison = nil
            ns.OpenJournalWindow(J.Get("AlcazPrison"))
            check("a dungeon with no map closes it", rawget(mapWindow, "shown") == false)
            J.Maps.AlcazPrison = alcazMap
        end
        ns.OpenJournalWindow(wailing)
        check("closed, it stays closed", rawget(mapWindow, "shown") == false)
        J.OpenDungeonMap(J.Get("Stockade"))
        do
            local stockadeView = ShownView("Bazil Thredd")
            check("Stockade uses its shipped local picture", stockadeView.picture.texture
                == "Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\Stockade"
                and rawget(stockadeView.picture, "shown") == true and stockadeView.picture.texCoord[4] == 1)
            for i, tile in ipairs(stockadeView.tiles) do
                check("Stockade hides the client tile: " .. i, rawget(tile, "shown") == false)
            end
            J.DungeonMap.Copy(J.Get("Stockade"))
            local pastedStockade = assert(loadstring("return {\n" .. state.copied.text .. "\n}"))().Stockade
            check("Stockade Copy preserves the local picture and crop",
                pastedStockade.image == J.Maps.Stockade.image and pastedStockade.imageBottom == 1)
        end
        ns.OpenJournalWindow(ragefire)
        check("a map opened from nothing stays on its dungeon", PinFor("Bazil Thredd") ~= nil and PinFor("Oggleflint") == nil)
        J.OpenDungeonMap(J.Get("Stockade"))
        state.account.journalMapPins, state.account.journalMapFolded = savedPins, folded
    end
    FloorsAndFollowing()
    -- The world map opening (M) puts the Journal's window away; closing it brings it back.
    ns.OpenJournalWindow(ragefire)
    local journalWindow
    for _, made in ipairs(state.made) do
        if made.scripts.OnKeyDown then journalWindow = made end
    end
    J.WindowAwayForMap(true)
    check("M puts the Journal away", rawget(journalWindow, "shown") == false)
    J.WindowAwayForMap(false)
    check("and M again brings it back", rawget(journalWindow, "shown") == true)
    J.WindowAwayForMap(false)
    check("a map closed with no Journal put away leaves it as it is", rawget(journalWindow, "shown") == true)
    -- On the world map, inside the Stockade: its map over the map's picture; a right-click
    -- goes up to Stormwind, and not in combat.
    local stockade = J.Get("Stockade")
    J.ShowMapOnWorldMap(stockade)
    local overlay
    for _, made in ipairs(state.made) do
        if made.scripts.OnMouseWheel then overlay = made end
    end
    check("the dungeon's map shows on the world map", overlay ~= nil and rawget(overlay, "shown") ~= false)
    local onWorld = {}
    for _, made in ipairs(state.made) do
        local boss = rawget(made, "boss")
        if rawget(made, "glow") and boss and rawget(made, "shown") ~= false then onWorld[boss.name] = true end
    end
    check("with its bosses", onWorld["Bazil Thredd"] and onWorld["Dextren Ward"])
    do
        local stockadeView = PinFor("Bazil Thredd").view
        check("Stockade also uses the local picture over the world map",
            stockadeView.picture.texture == J.Maps.Stockade.image and rawget(stockadeView.picture, "shown") == true
            and rawget(stockadeView.tiles[1], "shown") == false and rawget(stockadeView.tiles[12], "shown") == false)
    end
    Measure("the dungeon's map shown on the world map", 2, function() J.ShowMapOnWorldMap(stockade) end)
    -- A boss's loot from its pin closes with the map.
    local opened, closed = 0, 0
    local open, close = J.View.OpenBossLoot, J.View.CloseBossLoot
    ---@diagnostic disable-next-line: duplicate-set-field
    J.View.OpenBossLoot = function() opened = opened + 1 end
    J.View.CloseBossLoot = function() closed = closed + 1 end
    local bazil
    for _, made in ipairs(state.made) do
        local boss = rawget(made, "boss")
        if boss and boss.name == "Bazil Thredd" and made.scripts.OnClick and rawget(made, "shown") ~= false then
            bazil = made
        end
    end
    -- The small map has the Journal beside it: the pin is only ringed in gold.
    bazil.scripts.OnClick(bazil, "LeftButton")
    check("the small map opens no loot at the mouse", opened == 0)
    check("but rings the boss", rawget(bazil.gold, "shown") == true)
    bazil.scripts.OnClick(bazil, "LeftButton")
    check("clicked again, it is no longer picked", rawget(bazil.gold, "shown") == false)
    state.mapMaximised = true
    bazil.scripts.OnClick(bazil, "LeftButton")
    overlay:Hide()
    if overlay.scripts.OnHide then overlay.scripts.OnHide(overlay) end
    check("a boss's pin opens its loot", opened == 1)
    check("which closes with the map", closed == 1)
    check("and takes the ring with it", rawget(bazil.gold, "shown") == false)
    state.mapMaximised = nil
    J.View.OpenBossLoot, J.View.CloseBossLoot = open, close
    J.ShowMapOnWorldMap(stockade)
    state.mapOpened = nil
    overlay.scripts.OnMouseUp(overlay, "RightButton")
    check("a right-click goes up to its zone", state.mapOpened == stockade.entrance.map
        and rawget(overlay, "shown") == false)
    J.ShowMapOnWorldMap(stockade)
    state.mapOpened, state.combat = nil, true
    overlay.scripts.OnMouseUp(overlay, "RightButton")
    check("in combat it only steps aside", state.mapOpened == nil and rawget(overlay, "shown") == false)
    state.combat = false
    local bfd = J.Get("BlackfathomDeeps")
    J.ShowMapOnWorldMap(bfd)
    local floorText, up
    for _, font in ipairs(state.fonts) do
        if rawget(font, "text") == "Pool of Ask'ar" and rawget(font, "shown") ~= false then floorText = font end
    end
    for _, button in ipairs(state.buttons) do
        if button.label == ">" and floorText and button:GetParent() == floorText:GetParent() then up = button end
    end
    check("Blackfathom Deeps opens on its first floor, with a switch", floorText ~= nil and up ~= nil)
    up.onClick()
    check("the switch goes to its second floor", floorText.text == "Moonshrine Sanctum")
    J.ShowMapOnWorldMap(bfd)
    check("and drawn again for a boss's page, it stays there", floorText.text == "Moonshrine Sanctum")
    J.ShowMapOnWorldMap(stockade)
    J.ShowMapOnWorldMap(bfd)
    check("another dungeon in between: it starts on its first floor again", floorText.text == "Pool of Ask'ar")
    J.ShowMapOnWorldMap(nil)
    state.account.journalMapPins, state.copied = nil, nil
    J.Maps.RagefireChasm.pins[11519] = bazzalan
    for key, map in pairs(J.Maps) do
        local dungeon = J.Get(key)
        check("a map is for a dungeon the Journal has: " .. key, dungeon ~= nil)
        check("its art and floors: " .. key, (type(map.art) == "string" or type(map.image) == "string")
            and map.floors >= 1)
        -- The addon's own picture is in NaowhForever_DungeonJournal/Media/Maps, for a dungeon the game has no art for.
        if map.image then
            check("its picture is the addon's: " .. key, map.image:find("^Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\") ~= nil
                and map.art == nil)
        end
        -- A floor the art lacks, as the addon's own picture.
        for n, path in pairs(map.images or {}) do
            check("its floor's picture is the addon's: " .. key .. " " .. n,
                n >= 1 and n <= map.floors and path:find("^Interface\\AddOns\\NaowhForever_DungeonJournal\\Media\\Maps\\") ~= nil)
        end
        -- Every pin is one of its bosses, on one of its floors, on the map.
        local bosses = {}
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.npc then bosses[boss.npc] = true end
                if boss.chest then bosses[-boss.chest] = true end
            end
        end
        for _, data in ipairs(map.quests or {}) do bosses[data.npc or -data.object] = true end
        for id, spot in pairs(map.pins) do
            check("a pin is a boss or quest pin of " .. key .. ": " .. id, bosses[id] == true)
            check("on its map: " .. key .. " " .. id, spot[1] >= 1 and spot[1] <= map.floors
                and spot[2] >= 0 and spot[2] <= 1 and spot[3] >= 0 and spot[3] <= 1)
        end
        MapFloorsAndGaps(key, map, dungeon)
    end

    -- Ctrl+F, with the mouse on the window: the search box.
    local frame = state.made[1]
    for _, made in ipairs(state.made) do
        if made.scripts.OnKeyDown then frame = made end
    end
    state.mouseOver, state.ctrl = true, true
    frame.scripts.OnKeyDown(frame, "F")
    check("Ctrl+F goes to the search box", state.focus ~= nil)
    state.mouseOver, state.ctrl, state.focus = nil, nil, nil

    state.instance = nil
    ns.ToggleJournalWindow()
    ns.ToggleJournalWindow()
    check("and closes and opens again", true)

    -- A quest in the log, opened from its row: drawn, with your selection put back.
    local Panel = ns.Journal.View.QuestPanel
    state.logged[166], state.selected = 4, 99
    state.objectives = { { text = "0/1 Head of VanCleef", finished = false } }
    Panel.Show(166, state.made[#state.made])
    check("a quest in the log opens its panel", true)
    check("and your quest log selection is put back", state.selected == 99)

    -- A quest's row, in the log or not: its hover card lists the rewards to choose from, each with its icon.
    local questRow
    for _, made in ipairs(state.made) do
        local entry = rawget(made, "entry")
        if entry and entry.quest and entry.quest[1] == 96403 and rawget(made, "shown") ~= false then questRow = made end
    end
    check("Important Heirlooms has its row", questRow ~= nil)
    check("its title leads with the quest's level, in its difficulty color", questRow.entry.level ~= nil
        and tostring(rawget(questRow.title, "text")):find("^|cffffffff%[" .. questRow.entry.level .. "%] |r") ~= nil)
    local rewardLines = {}
    rawset(state.tooltip, "AddLine", function(_, line) rewardLines[#rewardLines + 1] = line end)
    questRow.name.scripts.OnEnter(questRow.name)
    local icons = 0
    for _, line in ipairs(rewardLines) do
        if line:find("^|T%d+:0|t ") then icons = icons + 1 end
    end
    check("its hover card offers its two rewards to choose from", Has(rewardLines, "Choose one of these:")
        and icons == 2)
    rawset(state.tooltip, "AddLine", nil)
    check("a chain's row has its last step's rewards (The Glowing Shard)",
        Panel.HasRewards({ quest = ns.Journal.Quests.ByID(6981) }))
    state.logged[166] = nil
end

local function FactionOf(J, key)
    for _, tab in ipairs({ "reputation", "pvp" }) do
        for _, faction in ipairs(J.Factions(tab)) do
            if faction.key == key then return faction end
        end
    end
end

-------------------------------------------------------------------------------
--  The factions' data: each faction's rewards by standing, Neutral to Exalted, every reward
--  known to the item facts, and each faction linked with the dungeons it is earned in
-------------------------------------------------------------------------------
do
    local ns = fixture()
    local J = ns.Journal
    local seen = {}
    for _, tab in ipairs({ "reputation", "pvp" }) do
        local list = J.Factions(tab)
        check(tab .. " has factions", #list > 0)
        for _, faction in ipairs(list) do
            check(faction.key .. " is listed once", not seen[faction.key])
            seen[faction.key] = true
            check(faction.key .. " has a name and an ID", type(faction.name) == "string" and faction.id > 0)
            check(faction.key .. "'s rewards are a list, empty while a build has none", type(faction.tiers) == "table")
            local last = 0
            for _, tier in ipairs(faction.tiers) do
                check(faction.key .. "'s standings run Neutral to Exalted, lowest first",
                    tier.standing >= 4 and tier.standing <= 8 and tier.standing > last)
                last = tier.standing
                check(faction.key .. "'s tier knows its faction", tier.faction == faction)
                for _, id in ipairs(tier.items) do
                    check(faction.key .. "'s reward " .. id .. " is in the item facts", J.Items[id] ~= nil)
                    local price = faction.prices and faction.prices[id]
                    check(faction.key .. "'s price for " .. id .. " is whole copper", price == nil
                        or (price > 0 and price % 1 == 0))
                end
            end
            check(faction.key .. " has a side on the PvP tab, or is a city", (faction.side ~= nil) == (tab == "pvp"
                or faction.group == "Cities"))
        end
    end
    local dawn, strat = FactionOf(J, "ArgentDawn"), J.Get("Stratholme")
    local linked = false
    for _, f in ipairs(strat.factions or {}) do linked = linked or f == dawn end
    check("Stratholme links to the Argent Dawn", linked)
    check("and the Argent Dawn back to it", dawn.linked[1] == strat)
end

-------------------------------------------------------------------------------
--  The reputation rules: your standing, prices in short, BiS among the rewards, and the
--  faction switch on the battleground factions
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture()
    local J, Rep = ns.Journal, ns.Journal.Reputation
    local dawn = FactionOf(J, "ArgentDawn")
    check("a faction not met has no standing", Rep.Standing(dawn) == nil)
    state.standings[529] = { reaction = 6, currentStanding = 12000, currentReactionThreshold = 9000,
        nextReactionThreshold = 21000 }
    local reaction, value, max = Rep.Standing(dawn)
    check("Honored, 3000 into 12000", reaction == 6 and value == 3000 and max == 12000)
    state.standings[529] = { reaction = 8, currentStanding = 42999, currentReactionThreshold = 42000,
        nextReactionThreshold = 42000 }
    reaction, value, max = Rep.Standing(dawn)
    check("Exalted is a full bar, with no division by zero", reaction == 8 and value == 1 and max == 1)
    check("a standing's label is the game's", Rep.Label(7) == "FACTION_STANDING_LABEL7")
    check("each standing has a color", Rep.Color(1) and Rep.Color(8) and Rep.Color(99))

    -- A price as people read it: its coin's icon as its letter.
    local function Plain(text)
        return (text:gsub("|TInterface\\MoneyFrame\\UI%-GoldIcon[^|]*|t", "g")
            :gsub("|TInterface\\MoneyFrame\\UI%-SilverIcon[^|]*|t", "s"))
    end
    check("63s 15c reads 63s", Plain(Rep.PriceText(6315)) == "63s")
    check("12g 53s reads 13g: from 10g, whole gold", Plain(Rep.PriceText(125321)) == "13g")
    check("4g 50s reads 4.5g", Plain(Rep.PriceText(45000)) == "4.5g")
    local text = Rep.PriceText(20004)
    check("2g reads 2g, not 2.0g", Plain(text) == "2g")
    check("a few copper still reads 1s", Plain((Rep.PriceText(3))) == "1s")

    local first = dawn.tiers[#dawn.tiers].items[1]
    state.bis[first] = 1
    local bis, have = Rep.Bis(dawn)
    check("its rewards hold your BiS", bis == 1 and have == 0)
    state.owned[first] = 1
    bis, have = Rep.Bis(dawn)
    check("and you have it", bis == 1 and have == 1)

    local defilers, league = FactionOf(J, "Defilers"), FactionOf(J, "LeagueOfArathor")
    check("both sides' battleground factions show", Rep.Shown(defilers) and Rep.Shown(league))
    S.Set("showHorde", false)
    check("the switch hides the Horde's", not Rep.Shown(defilers) and Rep.Shown(league))
    check("and never the rank, or a faction for both", Rep.Shown(J.RANK) and Rep.Shown(dawn))

    state.rank = { renownLevel = 3, maxLevel = 14 }
    check("rank 3 is the game's rank title for your side", Rep.RankTitle(3) == "PVP_RANK_7_1")
    check("no rank is the game's word for it", Rep.RankTitle(0) == "Unranked")
    check("three days and a minute read 3 days", Rep.Duration(3 * 86400 + 60) == "3 days")
    check("an hour reads 1 hour", Rep.Duration(3700) == "1 hour")

    local reputation, pvp = J.Factions("reputation"), J.Factions("pvp")
    Measure("BiS among every faction's rewards", 1, function()
        for _, faction in ipairs(reputation) do Rep.Bis(faction) end
        for _, faction in ipairs(pvp) do Rep.Bis(faction) end
    end)
end

-------------------------------------------------------------------------------
--  The Reputation and PvP tabs: a faction's page, its prices and links, the rank's page,
--  search across them, and Up and Down through the faction list
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J = ns.Journal
    ns.Apply()
    ns.OpenJournalWindow(J.Get("Stratholme"))
    -- Shown: it and every frame it is in (a pooled row hidden keeps its text).
    local function Shown(frame)
        while frame do
            if rawget(frame, "shown") == false then return false end
            frame = rawget(frame, "parent")
        end
        return true
    end
    local function Said(want)
        for _, font in ipairs(state.fonts) do
            local text = rawget(font, "text")
            if type(text) == "string" and Shown(font) and text:find(want, 1, true) then return true end
        end
        return false
    end
    local function Click(label)
        for _, font in ipairs(state.fonts) do
            if rawget(font, "text") == label and Shown(font) then
                local button = rawget(font, "parent")
                if button.scripts.OnClick then
                    button.scripts.OnClick(button)
                    return true
                end
            end
        end
    end
    check("a dungeon's page links the faction earned there", Said("Argent Dawn"))
    check("the switch over the list has its three parts", Said("Dungeons & Raids") and Said("Reputation")
        and Said("PvP"))

    state.standings[529] = { reaction = 6, currentStanding = 12000, currentReactionThreshold = 9000,
        nextReactionThreshold = 21000 }
    check("a click on the link opens the faction", Click("Argent Dawn"))
    check("on the Reputation tab", state.account.journalTab == "reputation")
    check("its page says your standing", Said("FACTION_STANDING_LABEL6"))
    check("and how far to the next one", Said("9000 to go"))
    check("and links back to its dungeons", Said("Stratholme"))
    check("its rewards are under a title", Said("REWARDS"))

    -- Prices where the drop chance goes.
    local priced = false
    for _, font in ipairs(state.fonts) do
        local text = rawget(font, "text")
        if type(text) == "string" and Shown(font) and text:find("^%d[%d.]*|TInterface\\MoneyFrame\\UI%-%a+Icon")
        then
            priced = true
        end
    end
    check("its rewards show their prices", priced)
    -- Hovering a priced reward, and its price: the tooltips write the price in coins (Forever has
    -- the money string under C_CurrencyInfo only).
    local hovered = 0
    for _, made in ipairs(state.made) do
        if rawget(made, "priced") and rawget(made, "price") and made.scripts.OnEnter then
            made.scripts.OnEnter(made)
            made.chanceZone.scripts.OnEnter(made.chanceZone)
            hovered = hovered + 1
        end
    end
    check("hovering a priced reward and its price shows its tooltips", hovered > 0)

    -- Up and Down step through the faction list.
    local frame
    for _, made in ipairs(state.made) do
        if made.scripts.OnKeyDown then frame = made end
    end
    state.mouseOver = true
    frame.scripts.OnKeyDown(frame, "DOWN")
    check("Down goes to the next faction", state.account.journalTab == "reputation" and not Said("9000 to go"))
    frame.scripts.OnKeyDown(frame, "UP")
    check("and Up back", Said("9000 to go"))
    state.mouseOver = nil

    -- The PvP tab opens on your rank.
    state.rank = { renownLevel = 3, maxLevel = 5, renownReputationEarned = 400, renownLevelThreshold = 1000,
        currentWeekProgressiveMaxLevel = 4, previousWeekProgressiveMaxLevel = 3, weekNumber = 2 }
    state.rankRewards[4] = { { renownRewardID = 1, uiOrder = 1, isAccountUnlock = false, itemID = 6087 } }
    state.rankRewards[5] = { { renownRewardID = 2, uiOrder = 1, isAccountUnlock = false, titleMaskID = 9,
        name = "Knight", icon = 1, isCollected = false },
        { renownRewardID = 3, uiOrder = 2, isAccountUnlock = false, name = "Rank 5 Rewards", icon = 1,
          description = "Unlocks the Knight's Tabard at the rank vendor.\nSecond line." } }
    state.account.journalRankItems = { Alliance = { [7001] = 5 } }
    check("the PvP tab opens", Click("PvP"))
    check("on your rank's title", Said("PVP_RANK_7_1"))
    check("with the season and when it ends", Said("Season") and Said("3 days"))
    check("how far to the next rank", Said("400") and Said("600 to go"))
    check("this week's cap", Said("This week you can reach rank 4 of 5"))
    check("a card for each rank that gives something", Said("RANK REWARDS") and Said("Rank 5"))
    check("a reward that is not an item says what it is", Said("Title"))
    check("and what the game says it gives, its first line", Said("Unlocks the Knight's Tabard at the rank vendor.")
        and not Said("Second line"))
    local unlock, unlockLines = nil, {}
    for _, made in ipairs(state.made) do
        local reward = rawget(made, "reward")
        if reward and reward.renownRewardID == 3 then unlock = made end
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    state.tooltip.AddLine = function(_, text) unlockLines[#unlockLines + 1] = text end
    unlock.scripts.OnEnter(unlock)
    local soldIn
    for _, text in ipairs(unlockLines) do
        if text == "Rank vendor in Stormwind" then soldIn = true end
    end
    check("an unlock's tooltip says which rank vendor sells it", soldIn)
    state.tooltip.AddLine = nil
    local listed
    for _, made in ipairs(state.made) do
        if rawget(made, "itemID") == 7001 then listed = true end
    end
    check("what the rank vendor sells at a rank is listed on its card", listed)
    check("the list says you have no rank yet, in the game's word",
        Said(ns.Journal.Reputation.RankTitle(0)) or Said("Rank 3"))
    check("the header says where the rewards are sold, as a quartermaster's", Said("Rank vendor in ")
        and not Said("Rank rewards are sold in Stormwind"))
    check("your honor", Said("1234"))

    -- Back to the dungeons: the page last shown there.
    check("the first tab goes back", Click("Dungeons & Raids"))
    check("to the dungeon last shown", state.account.journalTab == "dungeons" and Said("Argent Dawn"))

    -- A search finds a faction by its name, with its rewards and a link to it.
    state.searchBox:SetText("argent dawn")
    state.onSearch()
    state.timers[#state.timers]()
    check("a search finds a faction by its name", Said("ARGENT DAWN") and Said("Open"))
    state.searchBox:SetText("")
    state.onSearch()
    state.timers[#state.timers]()
    S.Set("listHidden", true)
    S.Set("listHidden", false)
    check("and takes its settings on every tab", true)
end

-------------------------------------------------------------------------------
--  A faction's page: recipes for your professions only, known ones marked, grouped under
--  gear; the standing track; the unlocked counts and the raids not in Forever in the list;
--  the switch gone on Reputation; a quartermaster learned at the vendor, and its pin
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J = ns.Journal
    local Loot, Rep = J.Loot, J.Reputation
    local druids = FactionOf(J, "NightclawDruids")
    -- Its Friendly rewards: two tailoring recipes (one known), a blacksmithing one, and gear.
    local friendly = druids.tiers[1].items
    local tailor, known, smith, gear = friendly[1], friendly[2], friendly[3], friendly[4]
    state.recipes = { [tailor] = { words = "Tailoring", sub = 2 }, [known] = { words = "Tailoring", sub = 2 },
        [smith] = { words = "Blacksmithing", sub = 4 } }
    for i = 5, #friendly do state.recipes[friendly[i]] = { words = "Leatherworking", sub = 1 } end
    state.professions = { 197 }        -- Tailoring
    state.known = { [known] = true }

    local filters = Loot.ReadFilters({})
    check("a recipe for your profession is listed", Loot.Shown(tailor, filters))
    check("one for another is not, with My Professions Only", not Loot.Shown(smith, filters))
    check("gear is, whatever your professions", Loot.Shown(gear, filters))
    S.Set("myRecipes", false)
    check("every recipe is, with it off", Loot.Shown(smith, Loot.ReadFilters(filters)))
    S.Set("myRecipes", true)
    check("a recipe has no look to collect", Loot.Appearance(tailor) == nil)
    state.cosmetic = { [gear] = true }
    check("a cosmetic item is listed", Loot.Shown(gear, Loot.ReadFilters(filters)))
    check("and never BiS: no stats", not Loot.BisGear(gear))
    S.Set("showCosmetic", false)
    check("Show Cosmetic Items off hides it", not Loot.Shown(gear, Loot.ReadFilters(filters)))
    S.Set("showCosmetic", true)
    Loot.ReadFilters(filters)
    state.cosmetic = nil
    check("nor a place on a BiS list", not Loot.BisGear(tailor) and Loot.BisGear(gear))

    -- Learnt at the vendor: where you stand when you open one who sells its rewards.
    -- Before: where the data says (Wowhead Forever's), until the vendor is opened.
    check("before, the data's quartermaster", Rep.Quartermaster(druids) == druids.quartermaster
        and druids.quartermaster.name == "Vayn Moongaze")
    ns.Apply()
    local vendors
    for _, frame in ipairs(state.made) do
        if frame.events.MERCHANT_SHOW then vendors = frame end
    end
    state.merchant, state.standingOn, state.vendor = { 999999, gear }, 2422, "Nightclaw Quartermaster"
    vendors.scripts.OnEvent(vendors, "MERCHANT_SHOW")
    local spot = Rep.Quartermaster(druids)
    check("a vendor who sells its rewards is where its quartermaster stands, in percent", spot and spot.map == 2422
        and math.abs(spot.x - 42) < 1e-9 and math.abs(spot.y - 61) < 1e-9 and spot.name == "Nightclaw Quartermaster")
    check("kept account-wide", state.account.journalQuartermasters.NightclawDruids == spot)
    state.merchant = { 999999 }
    vendors.scripts.OnEvent(vendors, "MERCHANT_SHOW")
    check("another vendor changes nothing", Rep.Quartermaster(druids) == spot)
    -- A spot learned before, kept as the map's 0 to 1: put in percent once, when read.
    state.account.journalQuartermasters.NightclawDruids = { map = 2422, x = 0.5, y = 0.25 }
    local old = Rep.Quartermaster(druids)
    check("a spot learned before is read in percent", old.x == 50 and old.y == 25)
    check("and kept that way", Rep.Quartermaster(druids).x == 50)
    state.account.journalQuartermasters.NightclawDruids = spot
    -- The rank's vendor, learnt the same way: the one who sells a reward of the rank's.
    check("no rank vendor spot before you open it", Rep.RankVendor() == nil)
    state.rank = { renownLevel = 1, maxLevel = 2 }
    state.rankRewards[2] = { { renownRewardID = 1, uiOrder = 1, itemID = 6087 } }
    state.merchant, state.vendor = { 6087 }, "Champion's Hall vendor"
    vendors.scripts.OnEvent(vendors, "MERCHANT_SHOW")
    local hall = Rep.RankVendor()
    check("a vendor who sells a rank reward is where the rank's rewards are sold",
        hall and hall.name == "Champion's Hall vendor")
    check("kept for your side", state.account.journalQuartermasters["PvPRank-Alliance"] == hall)
    -- What the rank vendors sell: the rank each item needs is the red line on its tooltip.
    local function Tip(...)
        local lines = {}
        for i = 1, select("#", ...) do lines[i] = { leftText = select(i, ...) } end
        return { lines = lines }
    end
    state.account.journalQuartermasters["PvPRank-Alliance"] = nil
    state.merchant, state.vendor = { 7001, 7002, 7003 }, "Brave Stonehide"
    state.merchantTips = { Tip("Requires Level 55", "Requires Corporal/Grunt (Rank 2)"),
        Tip("Requires Knight / Stone Guard (Rank 6)"), Tip("Scout's Tabard") }
    vendors.scripts.OnEvent(vendors, "MERCHANT_SHOW")
    local RankItems = Rep.RankItems
    check("an item's rank is read from its vendor's tooltip", RankItems(2)[1] == 7001 and RankItems(6)[1] == 7002)
    check("one with no rank line is rank 1 while you are rank 1", RankItems(1)[1] == 7003)
    check("kept for your side", state.account.journalRankItems.Alliance[7001] == 2)
    check("a vendor who sells by rank is the rank vendor", Rep.RankVendor().name == "Brave Stonehide")
    state.merchant = { 7001, 7002 }
    state.merchantTips = { Tip("Requires Corporal/Grunt (Rank 2)"), Tip("Knight's Colors") }
    vendors.scripts.OnEvent(vendors, "MERCHANT_SHOW")
    check("at rank 1, an item already learnt at its rank keeps it", state.account.journalRankItems.Alliance[7002] == 6)
    state.rank.renownLevel = 2
    state.merchant, state.merchantTips = { 7004 }, nil
    vendors.scripts.OnEvent(vendors, "MERCHANT_SHOW")
    check("past rank 1, an item with no rank line is not placed", state.account.journalRankItems.Alliance[7004] == nil)
    state.merchant = { 7005, 7006 }
    state.merchantTips = { Tip("Requires Level 55"), Tip("Requires Corporal/Grunt (Rank 2)") }
    vendors.scripts.OnEvent(vendors, "MERCHANT_SHOW")
    check("and one you reached keeps the rank it was learnt at", state.account.journalRankItems.Alliance[7005] == nil
        and RankItems(2)[2] == 7006)
    state.merchant, state.merchantTips, state.rank = nil, nil, nil

    ns.OpenJournalWindow(druids)
    local function Shown(frame)
        while frame do
            if rawget(frame, "shown") == false then return false end
            frame = rawget(frame, "parent")
        end
        return true
    end
    local function Said(want)
        for _, font in ipairs(state.fonts) do
            local text = rawget(font, "text")
            if type(text) == "string" and Shown(font) and text:find(want, 1, true) then return font end
        end
    end
    check("the window's title says the data's build", Said("build " .. J.DATA_BUILD))
    check("its standing track names each standing", Said("FACTION_STANDING_LABEL8"))
    check("and how many rewards each unlocks", Said(" 1"))
    -- A segment's words fit it: the count without its word where the whole is too wide, then
    -- the standing alone; never wider than the segment.
    local friendlyLabel = Said("FACTION_STANDING_LABEL5")
    local trackRow, segs = rawget(friendlyLabel, "parent"), 0
    for _, seg in ipairs(trackRow.segments) do
        if seg.track:IsShown() then segs = segs + 1 end
    end
    check("Friendly's says its rewards where they fit", friendlyLabel.text:find(" rewards", 1, true)
        and friendlyLabel.w < trackRow:GetWidth() / segs)
    friendlyLabel.GetStringWidth = function(font) return font.text:find("reward", 1, true) and 1000 or 10 end
    ns.OpenJournalWindow(druids)
    check("too narrow: the count alone", friendlyLabel.text:find("%d|r$") and not friendlyLabel.text:find("reward"))
    ---@diagnostic disable-next-line: duplicate-set-field
    friendlyLabel.GetStringWidth = function(font) return font.text:find("|c", 1, true) and 1000 or 10 end
    ns.OpenJournalWindow(druids)
    check("narrower: the standing alone", friendlyLabel.text == "FACTION_STANDING_LABEL5")
    friendlyLabel.GetStringWidth = nil
    ns.OpenJournalWindow(druids)
    -- The BiS stat: a click opens your BiS list, as its tip says, while the BiS List is on.
    local bisStat, hints = nil, {}
    for _, frame in ipairs(state.made) do
        if rawget(frame, "noneTip") == "None of your BiS is among its rewards" then bisStat = frame end
    end
    state.tooltip.AddLine = function(_, text) hints[#hints + 1] = text end
    bisStat.scripts.OnEnter(bisStat)
    check("the BiS stat's tip says a click shows your list", hints[#hints] == "Click to see your BiS.")
    bisStat.scripts.OnMouseUp(bisStat, "LeftButton")
    check("and a click opens it", state.bisOpened)
    state.bisList, state.bisOpened, hints[1] = false, nil, nil
    bisStat.scripts.OnEnter(bisStat)
    bisStat.scripts.OnMouseUp(bisStat, "LeftButton")
    check("not with the BiS List off", #hints == 0 and not state.bisOpened)
    state.bisList, state.tooltip.AddLine = true, nil
    -- Its Friendly card: its gear, then its recipes folded to a count, opened by a click.
    -- Every card titles its kinds, even one with gear alone, so cards side by side line up.
    local gearTitles = 0
    for _, font in ipairs(state.fonts) do
        local text = rawget(font, "text")
        if type(text) == "string" and Shown(font) and text:find("^GEAR") then gearTitles = gearTitles + 1 end
    end
    check("each card with gear titles it", gearTitles > 1)
    local recipes = Said("RECIPES")
    check("recipes beside gear are under their own title, folded", recipes ~= nil and Said("GEAR") ~= nil)
    check("so the known one is not drawn yet", not Said("Known"))
    local group = rawget(recipes, "parent")
    group.scripts.OnClick(group)
    check("a click opens them, and a recipe you know says Known", Said("Known") ~= nil)
    group.scripts.OnClick(group)
    check("and folds them again", not Said("Known"))
    local pin
    for _, frame in ipairs(state.made) do
        if rawget(frame, "tip") == "Show the quartermaster on your map" then pin = frame end
    end
    check("the pin shows once the quartermaster's spot is known", pin and rawget(pin, "shown") ~= false)
    pin.scripts.OnClick(pin, "LeftButton")
    local placed = state.waypoints[#state.waypoints]
    check("a click on it places a waypoint there, in percent", placed and placed.map == 2422
        and math.abs(placed.x - 42) < 1e-9
        and placed.title == "Nightclaw Quartermaster" and state.mapOpened == 2422)

    -- The list: the unlocked counts, and the raids not in Forever closed under their title.
    local zandalar = FactionOf(J, "ZandalarTribe")
    check("Zandalar Tribe is not in Forever yet", zandalar.unreleased == true)
    check("listed apart, closed", Said("NOT IN FOREVER YET") ~= nil and not Said("Zandalar Tribe"))
    S.Set("openUnreleased", true)
    check("opened, it shows them", Said("Zandalar Tribe") ~= nil)
    S.Set("openUnreleased", false)
    state.standings[2758] = { reaction = 6, currentStanding = 9500, currentReactionThreshold = 9000,
        nextReactionThreshold = 21000 }
    J.FactionList.Paint(druids)
    local unlocked, total = Rep.Unlocked(druids, 6, Loot.ReadFilters(filters))
    check("Honored unlocks the Friendly and Honored rewards for you", unlocked > 0 and unlocked < total)
    check("the row says how many", Said(unlocked .. "/" .. total) ~= nil)

    -- Reputation's factions are no side's: the switch has nothing to do there.
    local switch
    for _, frame in ipairs(state.made) do
        if rawget(frame, "side") then switch = rawget(frame, "parent") end
    end
    check("the faction switch hides on Reputation", rawget(switch, "shown") == false)

    -- How much reputation to go: exact to the next standing, about past it.
    local toGo, exact = Rep.ToGo(7, 6, 3000, 12000)
    check("to Revered from Honored 3,000/12,000: 9,000, exactly", toGo == 9000 and exact)
    toGo, exact = Rep.ToGo(8, 6, 3000, 12000)
    check("to Exalted: 9,000 and Revered's 21,000, about", toGo == 30000 and not exact)
    check("reached: none", Rep.ToGo(5, 6, 3000, 12000) == 0)
    check("not met: not known", Rep.ToGo(5, nil, 0, 1) == nil)
    check("said as people read it", Rep.ToGoText(30000, false) == "about 30000 to go")

    -- The page at Honored: what the unlocked rewards would cost; no reward picked out for you.
    state.money = 100
    ns.OpenJournalWindow(druids)
    check("no reward is picked out as the best for you", not Said("Best for you") and not Said("Next: "))
    check("what the unlocked rewards you have not got would cost", Said("Unlocked and not yours yet") ~= nil)
    check("in red when it is more than your gold", Said("|cfff87171you have") ~= nil)
    state.money = 10000000
    ns.OpenJournalWindow(druids)
    check("not when you have enough", Said("you have") and not Said("|cfff87171you have"))

    -- How to raise it: the quests in your log that give its reputation, then its hand-ins.
    check("with neither, no Quests section", not Said("QUESTS"))
    -- Each in the dungeon quests' rows: found by its title.
    local function QuestRow(title)
        for _, frame in ipairs(state.made) do
            local entry = rawget(frame, "entry")
            if entry and rawget(frame, "quest") and Shown(frame) and entry.name:find(title, 1, true) then
                return frame
            end
        end
    end
    state.log[1], state.log[2] = 70001, 70002
    state.logged[70001], state.logged[70002] = 1, 2
    state.onQuest = { [70001] = true, [70002] = true }
    state.repQuests[70001], state.repQuests[70002] = druids.id, 9999
    state.readyQuests[70001] = true
    druids.turnins = { { name = "Feathers", quests = { { 70003, "B", "Zephras Isle - Fenwick (40, 50)", 2521, 40, 50 } },
        rep = 25, level = 30, takes = { 12840, 20 }, from = { { "Zephras Isle", 9, "Thicket Owl", "Gale Harpy" } } } }
    druids.questData = { quests = { { 70003, "Feathers", 30, "B", true, "Zephras Isle - Fenwick (40, 50)", 2521, 40,
        50, turnin = druids.turnins[1] } } }
    state.owned[12840] = 45
    ns.OpenJournalWindow(druids)
    check("its quests are under a title", Said("QUESTS"))
    local logged = QuestRow("Quest 70001")
    check("a quest in your log that raises it, in a quest row", logged and logged.entry.inLog)
    check("a quest on its own shows no chain icon", not logged.chain:IsShown())
    -- Its ! or ? says what it means on hover: in your log, its state's words.
    local said
    state.tooltip.SetText = function(_, text) said = text end
    logged.markHit.scripts.OnEnter(logged.markHit)
    state.tooltip.SetText = nil
    check("its mark says what it means on hover", type(said) == "string" and said:find("In log") ~= nil)
    -- Link in chat: in a group it goes to party chat, into the chat box instead while you have
    -- it open, and out of a group only there: never to Say.
    local function LinkItem()
        logged.scripts.OnMouseUp(logged, "RightButton")
        for _, item in ipairs(state.menu) do
            if item.text:find("^Link in ") then return item end
        end
    end
    local sayCount = #state.said
    local link = LinkItem()
    check("out of a group with the chat box shut, Link in Chat is greyed out",
        link and link.text == "Link in Chat" and link.enabled == false)
    local tip = {}
    if link.tooltip then link.tooltip(tip) end
    check("and says why", tip.title == "Join a group, or open your chat box first.")
    -- Forever links only quests in your quest log: one with no link says so.
    state.noLink = true
    link, tip = LinkItem(), {}
    if link.tooltip then link.tooltip(tip) end
    check("a quest with no link is greyed out and says why", link.enabled == false
        and tip.title == "Only quests in your quest log can be linked.")
    state.inserted, state.shift = nil, true
    logged.scripts.OnMouseUp(logged, "LeftButton")
    check("and Shift-click links nothing", state.inserted == nil)
    state.noLink, state.shift = nil, nil
    link.click()
    check("it never sends to Say", #state.said == sayCount)
    state.chatOpen = true
    link = LinkItem()
    check("with the chat box open it can be linked", link.enabled == true and link.tooltip == nil)
    link.click()
    check("into the chat box, nothing sent", #state.said == sayCount)
    -- Shift-click links it into the open chat box, and opens nothing else.
    state.inserted, state.shift = nil, true
    logged.scripts.OnMouseUp(logged, "LeftButton")
    check("Shift-click links the quest into the chat box", state.inserted == "|Hquest:70001|h[Quest 70001]|h")
    state.shift = nil
    state.chatOpen = nil
    check("solo, a quest row shows no group count", not logged.party:IsShown())
    state.party = { { name = "Ally", quests = {} } }
    logged:GetParent():Redraw()
    logged = QuestRow("Quest 70001")
    check("in a group, it does", logged.party:IsShown())
    link = LinkItem()
    check("in a group, in party chat", link.text == "Link in Party")
    link.click()
    check("straight to party", state.said[#state.said].channel == "PARTY")
    state.chatOpen = true
    local count = #state.said
    link.click()
    check("into the chat box instead while it is open", #state.said == count)
    state.party, state.chatOpen = nil, nil
    check("not one that raises another faction", not QuestRow("Quest 70002"))
    local feathers = QuestRow("Feathers")
    check("a hand-in, in a quest row, with what one gives", feathers and feathers.entry.name:find("+25 rep", 1, true))
    check("where it is handed in, and who takes it", Said("Fenwick (40, 50)"))
    check("with a waypoint to them", feathers.entry.canWaypoint)
    state.mapOpened = nil
    feathers.waypoint.scripts.OnClick(feathers.waypoint, "LeftButton")
    local pinned = state.waypoints[#state.waypoints]
    check("its pin places the waypoint there", pinned and pinned.map == 2521 and pinned.x == 40 and pinned.y == 50)
    check("and opens the map to it", state.mapOpened == 2521)
    check("enough in your bags: the ? to hand it in", feathers.entry.held == 2 and feathers.entry.kind == "ready")
    check("its bag says how many times", feathers.chain.tip:find("2 times", 1, true) ~= nil)
    check("a hand-in's bag shows, chain or not", feathers.chain:IsShown())
    state.owned[12840] = 5
    ns.OpenJournalWindow(druids)
    feathers = QuestRow("Feathers")
    check("short of one: the ! to go and get them", feathers.entry.held == 0 and feathers.entry.kind == "pickup")
    S.Set("repQuestsOpen", false)
    check("the title closes them", Said("QUESTS") and not QuestRow("Feathers"))
    S.Set("repQuestsOpen", true)
    check("and opens them again", QuestRow("Feathers") ~= nil)
    local log = {}
    local _, before = Rep.LogQuests(druids, log)
    state.readyQuests[70001] = nil
    local _, after = Rep.LogQuests(druids, log)
    check("a quest no longer ready changes the page's quests", before ~= after)
    check("an objective ticking up does not", select(2, Rep.LogQuests(druids, log)) == after)
    state.log[3], state.repQuests[70003] = 70003, druids.id
    Rep.LogQuests(druids, log)
    check("a hand-in in your log is not listed twice", #log == 1 and log[1] == 70001)
    druids.turnins, druids.questData, state.owned[12840] = nil, nil, nil
    state.log, state.logged[70001], state.logged[70002], state.onQuest = {}, nil, nil, nil
    -- The data's own: Timbermaw's feathers and beads, each item one the game knows.
    ns.OpenJournalWindow(FactionOf(J, "TimbermawHold"))
    check("Timbermaw lists its hand-ins", QuestRow("Feathers for Grazle") and QuestRow("Beads for Salfa")
        and Said("+50 rep"))
    check("each saying who takes it and where", Said("Grazle (51, 85)"))
    local handIns = 0
    for _, faction in ipairs(J.Factions("reputation")) do
        for _, turnin in ipairs(faction.turnins or {}) do
            handIns = handIns + 1
            check(faction.key .. ": " .. turnin.name .. " reads", #turnin.quests > 0 and turnin.rep > 0
                and #turnin.takes > 0 and #turnin.takes % 2 == 0)
            for _, quest in ipairs(turnin.quests) do
                check(faction.key .. ": " .. turnin.name .. "'s quest " .. quest[1] .. " says where it is handed in",
                    type(quest[1]) == "number" and (quest[2] == "A" or quest[2] == "H" or quest[2] == "B")
                    and type(quest[3]) == "string" and quest[3] ~= "")
            end
        end
    end
    check("the data has its hand-ins", handIns >= 20)

    -- A dungeon's page: each faction earned there with your standing.
    state.standings[529] = { reaction = 6, currentStanding = 12000, currentReactionThreshold = 9000,
        nextReactionThreshold = 21000 }
    ns.OpenJournalWindow(J.Get("Stratholme"))
    check("a dungeon's faction link says your standing", Said("FACTION_STANDING_LABEL6") ~= nil
        and Said("3000 / 12000") ~= nil)
    local dungeonBis
    for _, frame in ipairs(state.made) do
        if rawget(frame, "noneTip") == "None of your BiS drops here" then dungeonBis = frame end
    end
    dungeonBis.scripts.OnMouseUp(dungeonBis, "LeftButton")
    check("a dungeon's BiS stat opens your BiS list too", state.bisOpened)
    Measure("the faction list's repaint", 2, function() J.FactionList.Paint(druids) end)
end

-------------------------------------------------------------------------------
--  Kill counts
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J, Kills = ns.Journal, ns.Journal.Kills
    ns.Apply()
    local OnEvent = state.made[1].scripts.OnEvent
    local boss = J.Boss(639)   -- Edwin VanCleef
    check("a boss the game names when it dies is counted", Kills.Counted(boss))
    check("no kills before the first", Kills.Count(boss) == 0 and Kills.Record(boss) == nil)
    check("and nothing saved for it", state.account.journalKills == nil)

    local id = boss.encounters[1]
    OnEvent(nil, "ENCOUNTER_START", id, "Edwin VanCleef", 1, 5)
    state.clock, state.now = 50 + 92.4, 2000
    OnEvent(nil, "ENCOUNTER_END", id, "Edwin VanCleef", 1, 5, 1)
    local record = Kills.Record(boss)
    check("a kill is counted", Kills.Count(boss) == 1)
    check("with when it was", record.first == 2000 and record.at[1] == 2000)
    check("and how long it took, in whole seconds", record.took[1] == 92)
    check("saved account-wide under this character", state.account.journalKills[state.guid][id] == record)

    OnEvent(nil, "ENCOUNTER_START", id, "Edwin VanCleef", 1, 5)
    OnEvent(nil, "ENCOUNTER_END", id, "Edwin VanCleef", 1, 5, 0)
    check("a wipe is not a kill", Kills.Count(boss) == 1)
    OnEvent(nil, "ENCOUNTER_END", 99999, "Nobody", 1, 5, 1)
    check("an encounter the Journal does not list counts for nothing", next(state.account.journalKills[state.guid], next(state.account.journalKills[state.guid])) == nil)
    OnEvent(nil, "ENCOUNTER_END", id, "Edwin VanCleef", 1, 5, 1)
    check("a kill with no pull seen (after a reload) counts, its length not known",
        Kills.Count(boss) == 2 and Kills.Record(boss).took[2] == false)

    check("the record is the fastest kill", Kills.Best(record) == 92 and select(2, Kills.Best(record)) == 2000)
    state.now = 2500
    Kills.Add(boss, 30.4)
    check("a faster kill is the new record", Kills.Best(Kills.Record(boss)) == 30 and Kills.Record(boss).bestAt == 2500)
    check("and is said in chat", state.printed[#state.printed] == "New record on Edwin VanCleef: 0:30, was 1:32.")
    for i = 1, 12 do
        state.now = 3000 + i
        Kills.Add(boss, 60)
    end
    check("the record is kept past the latest kills", Kills.Best(Kills.Record(boss)) == 30)
    record = Kills.Record(boss)
    check("the count goes on", record.n == 15)
    check("but only the latest ones keep their date", #record.at == Kills.KEEP and #record.took == Kills.KEEP)
    check("oldest first", record.at[Kills.KEEP] == 3012 and record.at[1] == 3003)
    check("the first kill's date stays", record.first == 2000)

    state.guid = "Player-4613-00ABCDEF"
    check("another character has its own count", Kills.Count(boss) == 0)
    state.guid = "Player-4613-006EB819"

    -- Every boss's encounter IDs are its own: one kill never counts for two bosses.
    local owner, counted = {}, 0
    for _, dungeon in ipairs(J.Dungeons()) do
        for _, wing in ipairs(dungeon.wings) do
            for _, b in ipairs(wing.bosses) do
                -- One killed on the way into another's fight shares that fight's encounters.
                if b.encounters and not b.with then
                    counted = counted + 1
                    for _, e in ipairs(b.encounters) do
                        check("encounter " .. e .. " names one boss", owner[e] == nil)
                        owner[e] = b
                    end
                end
            end
        end
    end
    check("most bosses can be counted", counted > 150)
    print(("  %d bosses with a kill count"):format(counted))

    S.Set("enabled", false)
    check("off, no fight is listened for", next(state.made[1].events) == nil)
    check("and the saved kills stay", Kills.Count(boss) == 15)

    -- The latest kills of any boss, newest first.
    local first = J.Get("Deadmines").wings[1].bosses[1]
    state.now = 5000
    Kills.Add(first, nil)
    local latest = Kills.Latest(5, {})
    check("the latest kills, newest first", #latest == 5 and latest[1].boss == first and latest[1].at == 5000
        and latest[2].boss == boss and latest[2].at == 3012 and latest[5].at == 3009)
    check("with their dungeon and length", latest[1].dungeon.key == "Deadmines" and latest[1].took == false
        and latest[2].took == 60)
    check("and no more than asked for", #Kills.Latest(2, latest) == 2)
    Kills.Forget()
    check("forgotten, every count starts again", Kills.Count(boss) == 0 and #Kills.Latest(5, latest) == 0)
    state.guid = "Player-4613-00ABCDEF"
    check("none for a character with no kills", #Kills.Latest(5, latest) == 0)
end

-------------------------------------------------------------------------------
--  Loot looted in the Journal's dungeons
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J, Looted = ns.Journal, ns.Journal.Looted
    ns.Apply()
    local frame = state.made[2]
    local OnEvent = frame.scripts.OnEvent
    check("loot is listened for only inside a dungeon", frame.events.PLAYER_ENTERING_WORLD
        and not frame.events.CHAT_MSG_LOOT)
    state.instance = { id = 36, name = "The Deadmines" }
    OnEvent(frame, "PLAYER_ENTERING_WORLD")
    check("inside one, it is", frame.events.CHAT_MSG_LOOT)

    local vanCleef = J.Boss(639)
    local drop = vanCleef.loot[1]
    local link = "|cnIQ3:|Hitem:" .. drop .. "::::::::20:::::|h[Cruel Barb]|h|r"
    OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
    local function List() return state.account.journalLoot and state.account.journalLoot[state.guid] end
    local list = List()
    check("your loot is kept", list and #list == 1 and list[1].id == drop and list[1].link == link)
    check("with where, from whom and when", list[1].dungeon == "Deadmines" and list[1].boss == "Edwin VanCleef"
        and list[1].at == state.now)
    check("saved account-wide under this character", state.account.journalLoot[state.guid] == list)
    OnEvent(frame, "CHAT_MSG_LOOT", "Die Dudu receives loot: " .. link .. ".")
    check("a group member's is not", #list == 1)
    OnEvent(frame, "CHAT_MSG_LOOT", "You receive item: " .. link .. ".")
    check("nor an item handed to you", #list == 1)
    OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: |cnIQ1:|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r.")
    check("nor trash below Uncommon", #list == 1)
    local green = "|cnIQ2:|Hitem:99901::::::::20:::::|h[Some Green]|h|r"
    OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: " .. green .. "x2.")
    check("but a green from trash is, from no boss", #list == 2 and list[2].id == 99901 and list[2].boss == nil)
    check("the boss's history lists what you looted from it", Looted.AllFrom(vanCleef, {})[1] == list[1])
    check("and another boss's lists none", #Looted.AllFrom(J.Boss(644), {}) == 0)
    local latest = Looted.Latest(5, {})
    check("the latest loot, newest first", #latest == 2 and latest[1] == list[2] and latest[2] == list[1])
    OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:99902::::::::20:::::|h[Unknown]|h|r.")
    check("an item whose quality is not known is not", #list == 2)
    for _ = 1, 25 do Looted.Add(J.Current(), green, 99901) end
    check("only the latest are kept", #list == Looted.KEEP and list[1].id == 99901)

    state.instance = nil
    OnEvent(frame, "PLAYER_ENTERING_WORLD")
    check("outside, it stops listening", not frame.events.CHAT_MSG_LOOT)
    OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
    check("and keeps nothing", list[Looted.KEEP].id == 99901)
    list[1].dungeon = "NoSuchDungeon"
    list[2].link = nil
    check("a mangled entry, or one of a dungeon no longer listed, is passed over",
        #Looted.Latest(Looted.KEEP, latest) == Looted.KEEP - 2)
    Looted.Forget()
    check("forgotten, the list is empty", #Looted.Latest(5, latest) == 0 and #Looted.AllFrom(vanCleef, {}) == 0)
    state.guid = "Player-4613-00ABCDEF"
    check("another character has its own list", List() == nil)
    S.Set("enabled", false)
    check("off, no loot is listened for", next(frame.events) == nil)
end

-------------------------------------------------------------------------------
--  What the latest kills and loot cost, for a player who has killed every boss ten times
--  and has a full loot list; and what the handlers cost for messages that are not theirs.
-------------------------------------------------------------------------------
do
    local ns, state = fixture({ enabled = true })
    local J, Kills, Looted = ns.Journal, ns.Journal.Kills, ns.Journal.Looted
    ns.Apply()
    local bosses, kills = {}, 0
    for _, d in ipairs(J.Dungeons()) do
        for _, w in ipairs(d.wings) do
            for _, b in ipairs(w.bosses) do
                bosses[#bosses + 1] = b
                if b.encounters then
                    for i = 1, Kills.KEEP do
                        state.now = i * 1000 + #bosses
                        Kills.Add(b, 60)
                        kills = kills + 1
                    end
                end
            end
        end
    end
    state.instance = { id = 36, name = "The Deadmines" }
    local vanCleef = J.Boss(639)
    local link = "|cnIQ3:|Hitem:" .. vanCleef.loot[1] .. "::::::::20:::::|h[Cruel Barb]|h|r"
    for _ = 1, Looted.KEEP do Looted.Add(J.Current(), link, vanCleef.loot[1]) end
    local out = {}
    Measure(("the latest 5 of %d kills"):format(kills), 0.5, function() Kills.Latest(5, out) end)
    check("five of them, the newest kill first", #out == 5 and out[1].at == state.now)
    for i = 1, 4 do check("then each older than the one before", out[i].at >= out[i + 1].at) end
    Measure("the latest 5 items looted", 0.1, function() Looted.Latest(5, out) end)
    Measure("what you looted from each boss of a dungeon", 0.1, function()
        for _, w in ipairs(J.Get("Deadmines").wings) do
            for _, b in ipairs(w.bosses) do Looted.AllFrom(b, out) end
        end
    end)
    local looted, asks = state.made[2], state.made[3]
    looted.scripts.OnEvent(looted, "PLAYER_ENTERING_WORLD")
    local others = "Emmy receives loot: " .. link .. "."
    Measure("a group member's loot line", 0.01, function()
        looted.scripts.OnEvent(looted, "CHAT_MSG_LOOT", others)
    end)
    Measure("another addon's message", 0.01, function()
        asks.scripts.OnEvent(asks, "CHAT_MSG_ADDON", "BigWigs", "V^1^2", "RAID", "Emmy-Realm")
    end)
end

-------------------------------------------------------------------------------
--  Who was with you: the team kept with a kill or an item, and read back in role order
-------------------------------------------------------------------------------
do
    local ns, state = fixture({ enabled = true })
    local Team = ns.Journal.Team
    check("solo, the team is you", Team.Now() == "Die Man,MAGE,N,m")
    state.role = "DAMAGER"
    state.party = {
        { name = "Trudy", guid = "Player-1-T", class = "WARRIOR", role = "TANK", quests = {} },
        { name = "Ding", guid = "Player-1-D", class = "ROGUE", role = "DAMAGER", quests = {} },
        { name = "Emmy", guid = "Player-1-E", class = "PRIEST", role = "HEALER", quests = {} },
        { name = "Ace", guid = "Player-1-A", class = "HUNTER", role = "DAMAGER", quests = {} },
    }
    local text = Team.Now()
    check("a group is kept as one line", text == "Die Man,MAGE,D,m;Trudy,WARRIOR,T,;Ding,ROGUE,D,;Emmy,PRIEST,H,;Ace,HUNTER,D,")
    local out = Team.Read(text, {})
    local order = {}
    for i, member in ipairs(out) do order[i] = member.name end
    check("read back: the tank, the healer, you, then the damage", table.concat(order, ",") == "Trudy,Emmy,Die Man,Ace,Ding")
    check("you are marked", out[3].me and not out[1].me)
    check("with each member's class and role", out[1].class == "WARRIOR" and out[1].role == "T")
    local first = out[1]
    Team.Read(text, out)
    check("a second read reuses the members", out[1] == first and #out == 5)
    check("nothing kept reads as no one", #Team.Read(nil, out) == 0 and #Team.Read(false, out) == 0)
    check("a mangled line reads what it can", #Team.Read("Trudy,WARRIOR,T,;garbage;,,;Emmy,PRIEST,X,", out) == 1)
    state.party[2].name = "Bad,Name;"
    check("a name cannot break the line", Team.Now():find("BadName,ROGUE", 1, true) ~= nil)
end

-------------------------------------------------------------------------------
--  The team kept with each kill; and a boss the game does not run as an encounter, which
--  cannot be counted (in a dungeon the game keeps which creature died secret)
-------------------------------------------------------------------------------
do
    local ns, state = fixture({ enabled = true })
    local J, Kills = ns.Journal, ns.Journal.Kills
    ns.Apply()
    local frame = state.made[1]
    local OnEvent = frame.scripts.OnEvent
    -- A boss the game runs no fight for (Baron Aquanis, Grizzle and others).
    local unnamed
    for _, d in ipairs(J.Dungeons()) do
        for _, w in ipairs(d.wings) do
            for _, b in ipairs(w.bosses) do
                if not b.encounters and b.npc then unnamed = unnamed or b end
            end
        end
    end
    check("a boss with no encounter is not counted", not Kills.Counted(unnamed) and Kills.Count(unnamed) == 0)
    check("and no death is listened for", not frame.events.UNIT_DIED and not frame.events.PARTY_KILL)

    -- Sneed's Shredder: Sneed climbs out of it, so it counts with his fight.
    local shredder, sneed = J.Boss(642), J.Boss(643)
    check("the Shredder counts with Sneed", Kills.Counted(shredder) and shredder.with == "Sneed")
    OnEvent(frame, "ENCOUNTER_END", sneed.encounters[1], "Sneed", 1, 5, 1)
    check("Sneed's fight is his kill", Kills.Count(sneed) == 1)
    check("and the Shredder's", Kills.Count(shredder) == 1 and Kills.Record(shredder) == Kills.Record(sneed))
    check("listed once among the latest, as Sneed", Kills.Latest(5, {})[1].boss == sneed)

    local vanCleef = J.Boss(639)
    OnEvent(frame, "ENCOUNTER_END", vanCleef.encounters[1], "Edwin VanCleef", 1, 5, 1)
    check("a kill keeps its team: you", Kills.Record(vanCleef).team[1] == "Die Man,MAGE,N,m")

    -- A kill kept before teams were: its list is filled in so the kills line up.
    state.account.journalKills[state.guid][vanCleef.encounters[1]] = { n = 2, first = 1, at = { 1, 2 }, took = { 60, 61 } }
    OnEvent(frame, "ENCOUNTER_END", vanCleef.encounters[1], "Edwin VanCleef", 1, 5, 1)
    local record = Kills.Record(vanCleef)
    check("an older record takes teams from its next kill", record.team[1] == false and record.team[2] == false
        and type(record.team[3]) == "string" and #record.at == 3)
end

-------------------------------------------------------------------------------
--  The rolls kept with an item, from the game's loot history; and the boss's side panel
-------------------------------------------------------------------------------
do
    local ns, state = fixture({ enabled = true })
    local J, Looted = ns.Journal, ns.Journal.Looted
    local vanCleef = J.Boss(639)
    local drop = vanCleef.loot[1]
    local link = "|cnIQ3:|Hitem:" .. drop .. "::::::::20:::::|h[Cruel Barb]|h|r"
    local history = {
        lootListKey = 1, itemHyperlink = link, startTime = 100,
        winner = { isSelf = true },
        rollInfos = {
            { playerName = "Die Man", state = 0, roll = 87, isWinner = true, isSelf = true, playerClass = "MAGE" },
            { playerName = "Emmy-Realm", state = 3, roll = 40, playerClass = "DRUID" },
            { playerName = "Trudy", state = 5 },
        },
    }
    local drops = {}
    -- The game's loot history, as the test fills it.
    local env = getfenv(J.TurnOn)
    env.C_LootHistory = {
        GetAllEncounterInfos = function() return { { encounterID = 2747 } } end,
        GetSortedDropsForEncounter = function() return drops end,
        GetSortedInfoForDrop = function() return history end,
    }
    ns.Apply()
    state.instance = { id = 36, name = "The Deadmines" }
    local frame = state.made[2]
    frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
    check("the loot history is listened for inside a dungeon", frame.events.LOOT_HISTORY_UPDATE_DROP)

    -- The roll came after the item: kept with it when it does.
    frame.scripts.OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
    local list = state.account.journalLoot[state.guid]
    check("an item looted before its roll is in has no rolls yet", list[1].rolls == nil)
    check("but its team", list[1].team == "Die Man,MAGE,N,m")
    frame.scripts.OnEvent(frame, "LOOT_HISTORY_UPDATE_DROP", 2747, 1)
    check("the roll's result is kept with it when it comes",
        list[1].rolls == "Die Man,0,87,w,MAGE;Emmy,3,40,,DRUID;Trudy,5,,,")
    local rolls = ns.Journal.Team.ReadRolls(list[1].rolls, {})
    check("read back: who rolled what, and who won", #rolls == 3 and rolls[1].winner and rolls[1].roll == 87
        and rolls[2].name == "Emmy" and rolls[2].state == 3 and rolls[2].class == "DRUID"
        and rolls[3].roll == nil and not rolls[3].winner and rolls[3].class == nil)

    -- The roll was in before the item: kept with it at once.
    drops[1] = history
    frame.scripts.OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
    check("an item whose roll is in already keeps it at once", list[2].rolls == list[1].rolls)
    history.winner.isSelf = false
    state.now = state.now + 1
    frame.scripts.OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
    check("someone else's win is not yours", list[3].rolls == nil)
    check("every item from the boss, newest first", #Looted.AllFrom(vanCleef, {}) == 3)

    -- Every drop of a kill, kept with it as each roll ends, whoever won it.
    local kills = state.made[1]
    kills.scripts.OnEvent(kills, "ENCOUNTER_END", 2747, "Edwin VanCleef", 1, 5, 1)
    local record = J.Kills.Record(vanCleef)
    check("a kill keeps no drops before the rolls end", record.drops[#record.at] == false)
    local saw = "|cnIQ2:|Hitem:5191::::::::20:::::|h[Cruel Barb]|h|r"
    drops[1] = { itemHyperlink = saw, startTime = state.clock * 1000 + 2000, rollInfos = {
            { playerName = "Ding", state = 3, roll = 96, isWinner = true, playerClass = "SHAMAN" },
            { playerName = "Die Man", state = 3, roll = 74, isSelf = true, playerClass = "MAGE" } },
        winner = { playerName = "Ding" } }
    drops[2] = { itemHyperlink = link, startTime = state.clock * 1000 - 3600000, winner = {},
        rollInfos = {} }   -- an hour before: another run's
    drops[3] = { itemHyperlink = link, startTime = state.clock * 1000 + 3000, rollInfos = {} }   -- still rolling
    kills.scripts.OnEvent(kills, "LOOT_HISTORY_UPDATE_DROP", 2747, 1)
    check("each drop with a winner is kept with the kill nearest it: only this run's, only ended rolls",
        record.drops[#record.at] == saw .. "\tDing,3,96,w,SHAMAN;Die Man,3,74,,MAGE")
    local seen = {}
    J.Kills.EachDrop(record.drops[#record.at], function(l, r) seen[#seen + 1] = l .. "|" .. r end)
    check("and read back, item by item", #seen == 1 and seen[1] == saw .. "|Ding,3,96,w,SHAMAN;Die Man,3,74,,MAGE")
    -- A kill missed (from before drops were kept, or a reload mid-roll) is filled in from the
    -- history when the boss's history is opened.
    record.drops[#record.at] = false
    J.Kills.Gather(vanCleef)
    check("a kill that missed its drops gets them from the history", record.drops[#record.at]
        == saw .. "	Ding,3,96,w,SHAMAN;Die Man,3,74,,MAGE")
    drops[1], drops[2], drops[3] = nil, nil, nil

    -- The side panel, drawn on both: what it says.
    local function Says(text)
        for _, font in ipairs(state.fonts) do
            local said = rawget(font, "text")
            if rawget(font, "shown") ~= false and type(said) == "string" and said:find(text, 1, true) then
                return true
            end
        end
        return false
    end
    local Panel = J.View.BossPanel
    local from = state.made[#state.made]
    Panel.Show(vanCleef, from)
    check("the boss's history opens in the side panel", Says("EDWIN VANCLEEF") and Says("KILLS"))
    check("loot with no kill before it stands on its own", Says("looted"))
    check("each item with everyone's roll, as the game's own icons", Says("Die Man") and Says("Emmy")
        and Says("Trudy") and state.atlases["lootroll-icon-need"] and state.atlases["lootroll-icon-greed"]
        and state.atlases["lootroll-icon-pass"])
    check("and what was picked up without one", Says("Picked up without a roll"))
    Panel.Show(vanCleef, from)

    -- A kill, then its loot: the loot goes under the kill.
    state.now = state.now + 60
    J.Kills.Add(vanCleef, 60, "Die Man,MAGE,D,m;Trudy,WARRIOR,T,")
    state.now = state.now + 30
    history.winner.isSelf = true
    frame.scripts.OnEvent(frame, "CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
    Panel.Show(vanCleef, from)
    check("a kill shows when, how long, and who was with you", Says("GROUP  2") and Says("took 1:00")
        and Says("Trudy") and Says("(you)"))
    check("and everything that dropped, with who won it", Says("Ding"))
    check("the fastest kill says it is the record", Says("Record|r  took 1:00"))
    Panel.Show(vanCleef, from)
    local unnamed
    for _, w in ipairs(J.Get("BlackfathomDeeps").wings) do
        for _, b in ipairs(w.bosses) do
            if not b.encounters then unnamed = unnamed or b end
        end
    end
    Panel.Show(unnamed, from)
    check("a boss the game does not report says why", Says("no boss fight to the game"))
end

-------------------------------------------------------------------------------
--  Asking a group member to share a quest: two players, each with the addon, passing the
--  messages one sends to the other.
-------------------------------------------------------------------------------
do
    local ME, EMMY, TRUDY = "Player-4613-006EB819", "Player-4613-00E33333", "Player-4613-00F44444"
    local QUEST = 6981   -- The Glowing Shard
    local asker, mine = fixture({ enabled = true })
    local emmy, hers = fixture({ enabled = true })
    asker.Apply()
    emmy.Apply()
    mine.guid, hers.guid = ME, EMMY
    mine.party = { { name = "Emmy", guid = EMMY, quests = { [QUEST] = true } } }
    hers.party = { { name = "Die Man", guid = ME, quests = {} } }
    hers.logged[QUEST] = 7
    local askerFrame, emmyFrame = mine.made[3], hers.made[3]
    check("out of a group, asks are not listened for", not askerFrame.events.CHAT_MSG_ADDON)
    askerFrame.scripts.OnEvent(askerFrame, "GROUP_ROSTER_UPDATE")
    emmyFrame.scripts.OnEvent(emmyFrame, "GROUP_ROSTER_UPDATE")
    check("in one, they are", askerFrame.events.CHAT_MSG_ADDON and emmyFrame.events.CHAT_MSG_ADDON)
    check("the share asks' prefix is registered", mine.prefix == "NaowhJournal")

    -- Delivers every message one side has sent to the other (and back to itself, as the game
    -- does on a group channel).
    local function Deliver(from, fromFrame, sender, to, toFrame)
        local sent = from.sent
        from.sent = {}
        for _, message in ipairs(sent) do
            for _, frame in ipairs({ toFrame, fromFrame }) do
                frame.scripts.OnEvent(frame, "CHAT_MSG_ADDON", message.prefix, message.text, message.channel, sender)
            end
        end
        return #sent
    end
    local function Printed(state) return state.printed[#state.printed] or "" end

    local entry
    for _, e in ipairs(asker.Journal.Quests.List(asker.Journal.Get("WailingCaverns").quests, {}, {})) do
        if e.quest[1] == QUEST then entry = e end
    end
    check("the asker does not have the quest, Emmy does", entry and not entry.inLog and entry.party == 1)
    asker.Journal.Sharing.Ask(entry)
    check("the ask goes to the group", #mine.sent == 1 and mine.sent[1].channel == "PARTY")
    check("and says so", Printed(mine):find("Asking Emmy to share", 1, true))
    Deliver(mine, askerFrame, "Die Man-Realm", hers, emmyFrame)
    check("Emmy shares it", #hers.pushed == 1 and hers.pushed[1] == 7)
    check("and is told who asked", Printed(hers):find("Die Man asked you to share", 1, true)
        and Printed(hers):find("shared it with your group", 1, true))
    check("and answers", Deliver(hers, emmyFrame, "Emmy-Realm", mine, askerFrame) == 1)
    check("the asker is told it was shared", Printed(mine):find("Emmy shared", 1, true))
    check("only once: the sender's own copy is not for it", #hers.pushed == 1)
    mine.timers[1]()
    check("the answered ask's timer does nothing", Printed(mine):find("Emmy shared", 1, true))

    -- Asked again at once, Emmy waits; her answer ends the ask.
    asker.Journal.Sharing.Ask(entry)
    Deliver(mine, askerFrame, "Die Man-Realm", hers, emmyFrame)
    check("a second ask in a moment is not shared", #hers.pushed == 1)
    Deliver(hers, emmyFrame, "Emmy-Realm", mine, askerFrame)
    check("and the asker is told to wait", Printed(mine):find("a moment ago", 1, true))

    -- A quest the game will not share.
    hers.clock = hers.clock + 30
    hers.unpushable = QUEST
    asker.Journal.Sharing.Ask(entry)
    Deliver(mine, askerFrame, "Die Man-Realm", hers, emmyFrame)
    Deliver(hers, emmyFrame, "Emmy-Realm", mine, askerFrame)
    check("one the game will not share is not", #hers.pushed == 1)
    check("and both are told why", Printed(hers):find("does not let it be shared", 1, true)
        and mine.printed[#mine.printed - 1]:find("does not let it be shared", 1, true))
    check("and that no one else can", Printed(mine):find("No one else in your group", 1, true))
    hers.unpushable = nil

    -- Two members on it: the first does not answer (no addon), the next is asked.
    mine.party = { { name = "Trudy", guid = TRUDY, quests = { [QUEST] = true } },
        { name = "Emmy", guid = EMMY, quests = { [QUEST] = true } } }
    mine.timers = {}
    asker.Journal.Sharing.Ask(entry)
    check("the first member on it is asked", mine.sent[1].text:find(TRUDY, 1, true))
    Deliver(mine, askerFrame, "Die Man-Realm", hers, emmyFrame)
    check("an ask for someone else is not answered", #hers.sent == 0 and #hers.pushed == 1)
    asker.Journal.Sharing.Ask(entry)
    check("a second click waits for the first ask", Printed(mine):find("Still waiting on Trudy", 1, true)
        and #mine.sent == 0)
    mine.timers[1]()
    check("no answer, and the asker is told", mine.printed[#mine.printed - 1]:find("Trudy did not answer", 1, true))
    check("and the next member is asked", Printed(mine):find("Asking Emmy", 1, true))
    Deliver(mine, askerFrame, "Die Man-Realm", hers, emmyFrame)
    Deliver(hers, emmyFrame, "Emmy-Realm", mine, askerFrame)
    check("who shares it", #hers.pushed == 2 and Printed(mine):find("Emmy shared", 1, true))
    mine.timers[1]()
    check("and the first timer, run late, does nothing", Printed(mine):find("Emmy shared", 1, true))

    -- A flood of asks: a few are answered, the rest dropped; what is not a quest ID is skipped.
    hers.clock = hers.clock + 60
    local printedBefore, sentBefore = #hers.printed, #hers.sent
    for _ = 1, 20 do
        emmyFrame.scripts.OnEvent(emmyFrame, "CHAT_MSG_ADDON", "NaowhJournal",
            "1 A " .. EMMY .. " " .. ME .. " 99999999999999999999,1e5,|cff", "PARTY", "Die Man-Realm")
    end
    check("twenty asks in a moment: four answered, the rest dropped, and said in chat once",
        #hers.sent - sentBefore == 4 and #hers.printed - printedBefore == 1 and #hers.pushed == 2)
    hers.clock = hers.clock + 11
    emmyFrame.scripts.OnEvent(emmyFrame, "CHAT_MSG_ADDON", "NaowhJournal", "1 A " .. EMMY .. " " .. ME .. " 1",
        "PARTY", "Die Man-Realm")
    check("answered again after the window, still not said again inside 30 seconds",
        #hers.sent - sentBefore == 5 and #hers.printed - printedBefore == 1)
    hers.clock = hers.clock + 20
    emmyFrame.scripts.OnEvent(emmyFrame, "CHAT_MSG_ADDON", "NaowhJournal", "1 A " .. EMMY .. " " .. ME .. " 1",
        "PARTY", "Die Man-Realm")
    check("and said again once 30 seconds have passed", #hers.printed - printedBefore == 2)
    sentBefore = #hers.sent - 4
    emmyFrame.scripts.OnEvent(emmyFrame, "CHAT_MSG_ADDON", "NaowhJournal",
        "1 A " .. EMMY .. " Player-1-" .. string.rep("A", 200) .. " 6981", "PARTY", "Die Man-Realm")
    check("an asker that is not a GUID is not answered", #hers.sent - sentBefore == 4)
    hers.sent = {}

    -- In an encounter the game passes no addon messages.
    mine.locked = true
    asker.Journal.Sharing.Ask(entry)
    check("locked, nothing is sent", #mine.sent == 0 and Printed(mine):find("in an encounter", 1, true))
    mine.locked = false

    -- Quest Share Requests off: nothing is asked or answered.
    emmy.Journal.Settings.Set("shareRequests", false)
    check("with Quest Share Requests off, asks are not listened for", next(emmyFrame.events) == nil)
    asker.Journal.Settings.Set("shareRequests", false)
    asker.Journal.Sharing.Ask(entry)
    check("and nothing is asked", #mine.sent == 0)
    emmy.Journal.Settings.Set("shareRequests", true)
    check("on again, they are", emmyFrame.events.GROUP_ROSTER_UPDATE ~= nil)

    -- Off, nothing is answered.
    emmy.Journal.Settings.Set("enabled", false)
    check("off, asks are not listened for", next(emmyFrame.events) == nil)
end

do
    local ME, EMMY = "Player-4613-006EB819", "Player-4613-00E33333"
    local emmy, hers = fixture({ enabled = true })
    emmy.Apply()
    hers.guid = EMMY
    hers.party = { { name = "Die Man", guid = ME, quests = {} } }
    local emmyFrame = hers.made[3]
    emmyFrame.scripts.OnEvent(emmyFrame, "GROUP_ROSTER_UPDATE")
    local lookups = 0
    setmetatable(hers.logged, { __index = function() lookups = lookups + 1 end })
    local function Ask(text, sender)
        emmyFrame.scripts.OnEvent(emmyFrame, "CHAT_MSG_ADDON", "NaowhJournal", text, "PARTY", sender or "Die Man-Realm")
    end
    Ask("1 A " .. EMMY .. " |TInterface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\BadgeNaowhChat.tga:0|t 6981")
    Ask("1 A " .. EMMY .. " Player-%s%d 6981")
    check("an ask from something that is not a player's GUID is not answered", #hers.sent == 0 and lookups == 0)
    local ids = {}
    for i = 1, 120 do ids[i] = tostring(100 + i) end
    Ask("1 A " .. EMMY .. " " .. ME .. " " .. table.concat(ids, ","))
    check("only the first few IDs of a long ask are looked up", lookups == 8 and #hers.sent == 1)
    lookups = 0
    hers.sent = {}
    Ask("1 A " .. EMMY .. " " .. ME .. " " .. ("9"):rep(200) .. ",6981")
    check("an ID too long to be a quest is skipped", lookups == 1 and #hers.sent == 1)
    hers.sent = {}
    hers.clock = hers.clock + 30
    hers.party[1].name = "Bad%s%dName"
    Ask("1 A " .. EMMY .. " " .. ME .. " 6981", "Bad%s%dName-Realm")
    check("a sender's name with format codes prints as written",
        (hers.printed[#hers.printed] or ""):find("Bad%s%dName asked you", 1, true) ~= nil)
end

-------------------------------------------------------------------------------
--  The BiS List's Quests page: the quests that reward a pick you do not have yet, by zone,
--  as the Journal's quests, so its rules and rows work on them as on a dungeon's.
-------------------------------------------------------------------------------
do
    local ns, state = fixture()
    local J = ns.Journal
    check("the BiS quests load with the Journal", J.BiSQuestData ~= nil and #J.BiSQuestData.quests > 0)
    local zoned = 0
    for _, quest in ipairs(J.BiSQuestData.quests) do
        check("a BiS quest rewards something: " .. quest[1], J.BiSQuestRewards[quest[1]] ~= nil)
        check("and is a quest record: " .. quest[1], type(quest[2]) == "string" and type(quest[3]) == "number"
            and (quest[4] == "A" or quest[4] == "H" or quest[4] == "B") and type(quest[6]) == "string")
        if J.BiSQuestZones[quest[1]] then zoned = zoned + 1 end
    end
    check("most say where they start", zoned * 2 > #J.BiSQuestData.quests)

    -- A Journal quest among them, then three of its own: an Alliance one with a choice, a
    -- Horde one and a warrior's.
    local journal
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            if not journal and quest[4] ~= "H" and not quest.class then journal = quest end
        end
    end
    J.BiSQuestData = { quests = {
        { journal[1], "Its copy", journal[3], journal[4], true, "Somewhere" },
        { 990001, "Low One", 10, "A", true, "Elwynn Forest - Marshal (40, 60)", 1429, 40, 60 },
        { 990002, "Horde One", 12, "H", true, "Durotar - Grunt (50, 50)", 1411, 50, 50 },
        { 990003, "Warrior One", 14, "A", false, "Elwynn Forest - Trainer (41, 61)", 1429, 41, 61, class = "WARRIOR" },
        { 990004, "Dwarf One", 11, "A", true, "Dun Morogh - Elder (30, 40)", 1426, 30, 40, races = 4 },
    } }
    J.BiSQuestRewards = { [journal[1]] = { 880001 }, [990001] = { 880002, 880009 }, [990002] = { 880003 },
        [990003] = { 880004 }, [990004] = { 880005 } }
    J.BiSQuestChoices = { [990001] = true }
    J.BiSQuestZones = { [990001] = "Elwynn Forest", [990002] = "Durotar", [990003] = "Elwynn Forest" }

    -- Your list, as the BiS List keeps it; then the page's files, as BiS.xml loads them.
    local list = { slots = { [1] = 880001, [2] = 880002, [3] = 880003, [5] = 880004, [6] = 880005 } }
    local env = getfenv(J.Quests.List)
    ns.BiS = { View = {}, Lists = { List = function() return list end },
        Rankings = { PlaceName = function(name) return J.PlaceName(name) end },
        Picks = function(l, slot, out)
            env.wipe(out)
            out[1] = l.slots[slot]
            return out
        end }
    for _, path in ipairs({ "NaowhForever_BiS/BiS/Quests.lua", "NaowhForever_BiS/BiS/View/QuestsPage.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local Q = ns.BiS.Quests
    local zones = Q.Zones(list)
    local byName = {}
    for _, zone in ipairs(zones) do byName[zone.name] = zone end
    check("the zones the quests start in", byName["Elwynn Forest"] and byName.Durotar and #zones == 3)
    check("lowest first", zones[1].level <= zones[2].level and zones[2].level <= zones[3].level)
    local own
    for _, zone in ipairs(zones) do
        if zone.data.quests[1] == journal then own = zone end
    end
    check("a quest the Journal lists is its record there", own ~= nil)
    check("under its quest giver's zone or its dungeon, not Elsewhere", own and own.name ~= "Elsewhere")
    check("a reward not on your list is not wanted", not Q.Wanted(880009) and Q.Wanted(880002))
    for _, zone in ipairs(zones) do
        for _, quest in ipairs(zone.data.quests) do
            check("a human is not shown a dwarf's quest", quest[1] ~= 990004)
        end
    end
    state.owned[880002] = 1
    for _, zone in ipairs(Q.Zones(list)) do
        for _, quest in ipairs(zone.data.quests) do
            check("a quest whose pick you have is gone", quest[1] ~= 990001)
        end
    end
    state.owned[880002] = nil

    -- The page: each quest for you as the Journal's row, your picks under it.
    local view = ns.BiS.View.QuestsPage(env.CreateFrame("Frame"))
    view:SetWidth(700)
    view:Show()
    view:Redraw()
    local rows, items = {}, {}
    for _, frame in ipairs(state.made) do
        local entry = rawget(frame, "entry")
        if entry and rawget(frame, "quest") and frame:IsShown() then rows[entry.quest[1]] = true end
        if rawget(frame, "itemID") and frame:IsShown() then items[frame.itemID] = true end
    end
    check("an Alliance mage sees the Alliance quest", rows[990001])
    check("not the Horde one, nor the warrior's", not rows[990002] and not rows[990003])
    check("under it the pick it gives, not what is off your list", items[880002] and not items[880009])
    check("and says it is a choice", view.pools.note.used >= 1
        and view.pools.note[1].text.text:find("choice", 1, true) ~= nil)
    check("Quests counts them for its tab", Q.Count(list) >= 1)
end

-------------------------------------------------------------------------------
--  Never open the chat box: ChatFrameUtil.OpenChat from addon code writes fields on the
--  game's edit box, and the next message the player sends is then blocked as ours.
-------------------------------------------------------------------------------
do
    local opens = {}
    for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("%.lua$")) do
        local number = 0
        for line in io.lines(path) do
            number = number + 1
            local code = line:gsub("%-%-.*$", "")
            if code:find("ChatFrameUtil.OpenChat", 1, true) then opens[#opens + 1] = path .. ":" .. number end
        end
    end
    check("no addon code opens the chat box (" .. table.concat(opens, ", ") .. ")", #opens == 0)
end

do
    local ns, state = fixture({ enabled = true })
    ns.Apply()
    local J = ns.Journal
    local function Listening()
        for _, frame in ipairs(state.made) do
            if frame.events.ITEM_DATA_LOAD_RESULT then return frame end
        end
    end
    check("the probe listens to nothing until it is run", Listening() == nil)
    state.G.NaowhForeverDB = {}
    local named = next(J.Items)
    state.names[named] = "Loaded"
    state.requested, state.timers = {}, {}
    ns.JournalItemProbe()
    local probe = Listening()
    check("run, it listens for the answers", probe ~= nil)
    local silent = state.requested[#state.requested]
    local seen, rounds = {}, 0
    while not state.G.NaowhForeverDB.journalProbe and rounds < 200 do
        rounds = rounds + 1
        local asked = state.requested
        state.requested = {}
        if #asked == 0 then
            local fire = table.remove(state.timers)
            check("a batch with no answer is timed out", fire ~= nil)
            fire()
        end
        for _, id in ipairs(asked) do
            seen[id] = true
            if id ~= silent then probe.scripts.OnEvent(probe, "ITEM_DATA_LOAD_RESULT", id, not J.NotYet[id]) end
        end
    end
    local saved = state.G.NaowhForeverDB.journalProbe
    check("the answers are kept, with the build", saved ~= nil and saved.build == 70205)
    local loads, refused = {}, {}
    for _, id in ipairs(saved.loads) do loads[id] = true end
    for _, id in ipairs(saved.refused) do refused[id] = true end
    check("an item with a name already loads, unasked", loads[named] and not seen[named])
    check("one the server would not send is refused", refused[next(J.NotYet)] == true)
    check("one with no answer in time counts by its name", refused[silent] == true)
    local all, kept = 0, 0
    for _ in pairs(J.Items) do all = all + 1 end
    for id in pairs(J.NotYet) do if not J.Items[id] then all = all + 1 end end
    for _ in pairs(loads) do kept = kept + 1 end
    for _ in pairs(refused) do kept = kept + 1 end
    check("every item the Journal lists is answered", kept == all)
    check("done, it listens to nothing", next(probe.events) == nil)
end

-------------------------------------------------------------------------------
--  The entrances on the world map
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J, map = ns.Journal, state.worldMap
    local pins, providers, shownMap = {}, {}, 1420   -- Tirisfal Glades
    map.AddDataProvider = function(_, provider) providers[#providers + 1] = provider end
    map.GetMapID = function() return shownMap end
    map.AcquirePin = function(_, template, group) pins[#pins + 1] = group; state.pinTemplate = template end
    map.RemoveAllPinsByTemplate = function() for i = #pins, 1, -1 do pins[i] = nil end end
    check("Entrances on the World Map is off until switched on", not S.Get("mapEntrances"))
    ns.Apply()   -- the rest of the Journal makes its frames
    local frames = state.frames
    ns.Apply()
    check("off, nothing is made or added to the map", state.frames == frames and #providers == 0)
    S.Set("mapEntrances", true)
    check("on, its pins are added to the map once", #providers == 1)
    check("in the template the XML names", state.pinTemplate == "NaowhForeverEntrancePinTemplate")
    check("the Scarlet Monastery's four wings share one pin", #pins == 1 and #pins[1].dungeons == 4)
    check("on its spot", math.abs(pins[1].x - 0.839) < 1e-9 and math.abs(pins[1].y - 0.316) < 1e-9)
    S.Set("showHorde", false)
    check("outside a city, Horde off leaves its pin", #pins == 1)
    S.Set("showHorde", true)
    -- A continent: every entrance it holds, those on one spot together.
    shownMap, state.onMap = 1415, { [1415] = 0.5 }
    providers[1]:RefreshAllData()
    local spots = {}
    for _, dungeon in ipairs(J.Dungeons()) do
        if dungeon.entrance and J.FactionShown(dungeon) then
            for _, e in ipairs(dungeon.doors or { dungeon.entrance }) do spots[e.map .. ":" .. e.x .. ":" .. e.y] = true end
        end
    end
    local want = 0
    for _ in pairs(spots) do want = want + 1 end
    check("a map that holds them shows every entrance and door, one pin per spot", #pins == want and want > 20)
    -- Off the map's edge: not on it.
    state.onMap = { [1415] = 3 }
    shownMap = 1415
    providers[1]:RefreshAllData()
    local inside = true
    for _, group in ipairs(pins) do
        if group.x > 1 or group.y > 1 then inside = false end
    end
    check("a spot off the map's edge gets no pin", inside)
    -- The pin itself: the dungeon's door, a raid's own, and a waypoint on a click.
    shownMap, state.onMap = 1445, nil   -- Dustwallow Marsh: Onyxia's Lair
    providers[1]:RefreshAllData()
    local onyxia, alcaz
    for _, group in ipairs(pins) do
        local key = group.dungeons[1].key
        if key == "OnyxiasLair" then onyxia = group elseif key == "AlcazPrison" then alcaz = group end
    end
    check("Onyxia's Lair on its zone", #pins == 2 and onyxia ~= nil and onyxia.dungeons[1].raid ~= nil)
    check("and Alcaz Prison beside it", alcaz ~= nil)
    shownMap = 1449   -- Un'Goro Crater: Shaper's Terrace's stairs on its northern rim
    providers[1]:RefreshAllData()
    check("Shaper's Terrace on Un'Goro's map", #pins == 1 and pins[1].dungeons[1].key == "ShapersTerrace")
    shownMap = 1445
    providers[1]:RefreshAllData()
    for _, group in ipairs(pins) do
        if group.dungeons[1].key == "OnyxiasLair" then onyxia = group end
    end
    for i, group in ipairs(pins) do
        if group == onyxia then table.remove(pins, i); table.insert(pins, 1, onyxia) end
    end
    local Pin = state.env.NaowhForeverEntrancePinMixin
    local pin = state.worldMap:CreateTexture()
    pin.Icon = state.worldMap:CreateTexture()
    for k, v in pairs(Pin) do pin[k] = v end
    pin.SetPosition = function(self, x, y) self.at = { x, y } end
    pin.GetMap = function() return map end
    pin:OnAcquired(pins[1])
    check("a raid's pin shows the raid door", state.atlases.raid == true)
    -- Its size: by the kind of map shown, the same full screen, one size on screen at any zoom.
    state.mapInfo = { [1445] = { mapType = 3 }, [1414] = { mapType = 2 }, [947] = { mapType = 1 } }
    local function SizeOn(mapID)
        shownMap = mapID
        pin:OnAcquired(pins[1])
        return pin.w
    end
    check("on a zone's map at 100%", SizeOn(1445) == 18 and pin.h == 18)
    check("on a continent's at 75%", SizeOn(1414) == 13.5)
    check("on the world's at 60%", math.abs(SizeOn(947) - 10.8) < 1e-9)
    state.mapMaximised = true
    check("full screen, the same", math.abs(SizeOn(947) - 10.8) < 1e-9)
    state.mapMaximised = false
    check("scaled by the shared map pin scale", Pin.ApplyCurrentScale == ns.Shared.ScalePin)
    shownMap = 1445
    local shown = { pin }
    map.EnumeratePinsByTemplate = function() local i = 0; return function() i = i + 1; return shown[i] end end
    local count = #pins
    S.Set("mapEntranceScale", 0.5)
    check("Icon Size resizes the pins shown without drawing them again", pin.w == 9 and #pins == count)
    state.mapInfo = nil
    pin:OnMouseEnter()
    pin:OnClick("LeftButton")
    local waypoint = state.waypoints[#state.waypoints]
    check("a click puts a waypoint on the entrance", waypoint.map == 1445 and waypoint.x == 52.9
        and waypoint.note == " (entrance)" and waypoint.title == "Onyxia's Lair")
    -- A dungeon with several doors: one pin each, named, its waypoint on that door.
    shownMap = 1444   -- Feralas: Dire Maul
    providers[1]:RefreshAllData()
    local doors = {}
    for _, group in ipairs(pins) do
        if group.dungeons[1].key == "DireMaul" then doors[group.door] = group end
    end
    check("Dire Maul has a pin for each door, none for its courtyard", doors.East and doors["East Back Door"]
        and doors.West and doors.North and #pins == 4)
    pin:OnAcquired(doors.West)
    pin:OnMouseEnter()
    pin:OnClick("LeftButton")
    waypoint = state.waypoints[#state.waypoints]
    check("a door's waypoint is on that door, named for it", waypoint.map == 1444 and waypoint.x == 60.3
        and waypoint.y == 30.7 and waypoint.title == "Dire Maul: West")
    S.Set("mapEntrances", false)
    check("off again, its pins go", #pins == 0)
end

do
    local ns, state = fixture({ enabled = true })
    local J = ns.Journal
    ns.Apply()
    for id in pairs(J.Items) do state.names[id] = "Item " .. id end
    local filters, hidden = J.Loot.ReadFilters({}), nil
    for id in pairs(J.Items) do
        if not J.Loot.Shown(id, filters) then hidden = id end
    end
    state.names[hidden] = "Zq Hidden"
    ns.OpenJournalWindow(J.Get("Stratholme"))
    state.searchBox:SetText("zq")
    state.onSearch()
    for i = #state.timers, 1, -1 do table.remove(state.timers, i)() end
    local view
    for _, frame in ipairs(state.made) do
        if rawget(frame, "waitingFor") and frame:IsVisible() and frame.query == "zq" then view = frame end
    end
    check("a search draws on the window's page", view ~= nil)
    check("a name that matches is still left out when the filters hide it", not view:Listed(hidden, "zq"))
    check("a name that does not match is left out", not view:Listed(next(J.Items), "zq"))
    Measure("a search over every dungeon and faction redrawn", 2, function() view:Redraw() end)
end

do
    local ns, state = fixture({ enabled = true, missingBisOnly = true }, true)
    local J = ns.Journal
    ns.Apply()
    check("without the BiS List loaded the Journal loads, its class rules the core's",
        J.Loot.Usable ~= nil and not J.Loot.BisOn() and J.Loot.Rank(next(J.Items)) == nil)
    check("and Missing BiS Only lists nothing away", not J.Loot.ReadFilters({}).missingBis)
    ns.OpenJournalWindow(J.Get("Shadowfang Keep"))
    local link
    for _, frame in ipairs(state.made) do
        if rawget(frame, "linkArg") == "NaowhForever_BiS" and rawget(frame, "onLink") then link = frame end
    end
    check("a dungeon's page offers to turn the BiS List on", link ~= nil)
    link.onLink(link.linkArg)
    check("and its link does", state.turnedOn == "NaowhForever_BiS")
    state.turnedOn = nil
    local itemRow
    for _, frame in ipairs(state.made) do
        if rawget(frame, "itemID") and frame.scripts.OnClick and J.Loot.BisGear(frame.itemID) and not itemRow then
            itemRow = frame
        end
    end
    itemRow.scripts.OnClick(itemRow, "RightButton")
    local turnOn
    for _, e in ipairs(state.menu or {}) do
        if e.text == "Turn on BiS List" then turnOn = e end
        check("no BiS List entries without it", e.text ~= "Add to BiS List" and e.text ~= "Remove from BiS List")
    end
    turnOn.click()
    check("an item's menu turns the BiS List on", state.turnedOn == "NaowhForever_BiS")
end

-------------------------------------------------------------------------------
--  Where It Drops: an item's bosses on its tooltip anywhere
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true, itemSources = false })
    ns.Apply()
    check("Where It Drops is on by default", state.defaults.itemSources == true)
    check("off, no tooltip is hooked", state.itemTips == nil)
    S.Set("itemSources", true)
    check("on, the item tooltip is hooked", state.itemTips and #state.itemTips == 1)
    S.Set("itemSources", false)
    S.Set("itemSources", true)
    ns.Apply()
    check("and only once", #state.itemTips == 1)
    local lines, owner = {}, nil
    local tooltip = {
        AddLine = function(_, text) lines[#lines + 1] = text end,
        GetOwner = function() return owner end,
    }
    local post = state.itemTips[1]
    post(tooltip, { id = 5202 })
    check("an item names its boss, dungeon and chance", lines[1] == "Drops from Edwin VanCleef, The Deadmines (24%)")
    lines = {}
    post(tooltip, { id = 1945 })
    check("trash says so", lines[1] == "Drops from Trash, The Deadmines (6%)")
    lines = {}
    post(tooltip, { id = 6948 })
    check("an item no boss drops adds nothing", #lines == 0)
    owner = { journalItem = true }
    post(tooltip, { id = 5202 })
    check("the Journal's own item rows add nothing", #lines == 0)
    owner = nil
    S.Set("itemSources", false)
    post(tooltip, { id = 5202 })
    check("switched off, nothing", #lines == 0)
end

-------------------------------------------------------------------------------
--  Favourites: the menu adds and removes one, its row is starred and ticked once you have
--  it, the title bar's list shows where each drops, and entering a dungeon names the ones
--  there you do not have yet; off, none of it
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J = ns.Journal
    local Favourites = J.Favourites
    ns.Apply()
    local frames = state.frames
    local vanCleef = J.Boss(639)
    local wanted = vanCleef.loot[1]
    state.names[wanted] = "Cruel Barb"
    local function Row()
        local found
        for _, frame in ipairs(state.made) do
            if rawget(frame, "itemID") == wanted and frame.scripts.OnClick and rawget(frame, "shown") ~= false then
                found = frame
            end
        end
        return found
    end
    local function MenuHas(text)
        for _, e in ipairs(state.menu or {}) do
            if e.text == text then return e end
        end
    end
    local function Starred(row)
        return tostring(rawget(row.name, "text")):find(J.Style.FAVOURITE, 1, true) ~= nil
    end
    local function Ticked(row)
        return tostring(rawget(row.name, "text")):find(J.Style.CHECK, 1, true) ~= nil
    end
    local function BarIcon()
        for _, frame in ipairs(state.made) do
            local icon = rawget(frame, "icon")
            if type(icon) == "table" and rawget(icon, "texture") == J.Style.FAVOURITE and frame.scripts.OnClick then
                return frame
            end
        end
    end
    check("off, loading makes nothing for it", state.frames == frames)
    ns.OpenJournalWindow(J.Get("Deadmines"))
    local row = Row()
    row.scripts.OnClick(row, "RightButton")
    check("off, an item's menu has no Favourites entry",
        not MenuHas("Add to Favourites") and not MenuHas("Remove from Favourites"))
    check("no star on its row", not Starred(row))
    check("and no list on the title bar", BarIcon() == nil)

    local made = #state.made
    S.Set("favourites", true)
    local listener
    for i = made + 1, #state.made do
        if state.made[i].events.PLAYER_ENTERING_WORLD then
            check("on, one frame listens for loading screens", listener == nil)
            listener = state.made[i]
        end
    end
    check("on, a frame listens for loading screens", listener ~= nil)
    local button = BarIcon()
    check("the title bar has its list", button ~= nil and rawget(button, "shown") ~= false)
    row = Row()
    row.scripts.OnClick(row, "RightButton")
    MenuHas("Add to Favourites").click()
    local mine = state.account.journalFavourites[state.guid]
    check("Add to Favourites keeps it for this character", mine[wanted] == true and Favourites.Is(wanted))
    row = Row()
    check("its row is starred", Starred(row) and not Ticked(row))
    row.scripts.OnClick(row, "RightButton")
    check("and its menu takes it off again", MenuHas("Remove from Favourites") ~= nil)
    state.owned[wanted] = 1
    ns.RedrawJournalWindow()
    row = Row()
    check("in your bags, its row is ticked too", Starred(row) and Ticked(row))
    state.owned[wanted] = nil

    local list = Favourites.List({})
    check("the list has it with its boss, dungeon and chance", #list == 1 and list[1].id == wanted
        and list[1].page == J.Get("Deadmines") and list[1].from == vanCleef and list[1].chance == vanCleef.chance[1])
    button.scripts.OnClick(button)
    local listed
    for _, frame in ipairs(state.made) do
        if rawget(frame, "itemID") == wanted and rawget(frame, "remove") and rawget(frame, "shown") ~= false then
            listed = frame
        end
    end
    check("its panel shows a row for it, with its boss and dungeon", listed
        and rawget(listed.from, "text") == vanCleef.name and rawget(listed.where, "text") == "The Deadmines"
        and rawget(listed.tick, "shown") == false)
    listed.scripts.OnClick(listed)
    check("a click opens its dungeon", rawget(Row(), "shown") ~= false)

    state.instance = { id = 36, name = "The Deadmines" }
    local printed = #state.printed
    listener.scripts.OnEvent(listener, "PLAYER_ENTERING_WORLD", false, false)
    check("entering its dungeon names it once", #state.printed == printed + 1
        and state.printed[#state.printed]:find("Cruel Barb", 1, true))
    listener.scripts.OnEvent(listener, "PLAYER_ENTERING_WORLD", false, false)
    check("not again in the same dungeon", #state.printed == printed + 1)
    state.instance = nil
    listener.scripts.OnEvent(listener, "PLAYER_ENTERING_WORLD", false, false)
    state.instance = { id = 36, name = "The Deadmines" }
    state.owned[wanted] = 1
    listener.scripts.OnEvent(listener, "PLAYER_ENTERING_WORLD", false, false)
    check("once you have it, it is not named", #state.printed == printed + 1)
    state.owned[wanted] = nil
    state.instance = { id = 33, name = "Shadowfang Keep" }
    listener.scripts.OnEvent(listener, "PLAYER_ENTERING_WORLD", false, false)
    check("and a dungeon with none says nothing", #state.printed == printed + 1)

    listed.remove.scripts.OnClick(listed.remove)
    check("the panel's cross takes it off", mine[wanted] == nil and #Favourites.List({}) == 0)

    mine[wanted] = true
    S.Set("favourites", false)
    check("off again, it stops listening", next(listener.events) == nil)
    check("its list leaves the title bar", rawget(button, "shown") == false)
    row = Row()
    check("its row loses its star", not Starred(row) and not Favourites.Is(wanted))
    row.scripts.OnClick(row, "RightButton")
    check("and its menu has no Favourites entry", not MenuHas("Remove from Favourites"))
    check("what was kept stays for when it is on", mine[wanted] == true)
end

-------------------------------------------------------------------------------
--  The Loot Finder: on by default; its slot, armor, stat, resistance and level picks; the
--  filters and the faction switch; the order; a click opens the boss; what a search costs
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true, usableOnly = false })
    local J = ns.Journal
    local Finder, Loot = J.Finder, J.Loot
    check("the Loot Finder starts on", state.defaults.lootFinder == true)
    for _, slot in ipairs({ "HEAD", "NECK", "CHEST", "WEAPON" }) do state.G["INVTYPE_" .. slot] = slot end
    for id, stats in pairs(J.ItemStats) do
        check("item " .. id .. " in the finder's data is a Journal item with a slot", J.Facts(id) ~= nil and stats[1] > 0)
    end
    local function Pick(title, label)
        for _, group in ipairs(Finder.GROUPS) do
            for _, pick in ipairs(group.picks) do
                if group.title == title and Finder.Label(pick) == label then return pick end
            end
        end
    end
    local filters = {}
    local function Shown(_, id) return Loot.Shown(id, filters) end
    local out = {}
    local function Find(...)
        Finder.Clear()
        for i = 1, select("#", ...) do Finder.Toggle((select(i, ...))) end
        Loot.ReadFilters(filters)
        return Finder.Collect(out, Shown, nil, state.level), out
    end
    local function Has(id, stat)
        local stats = J.ItemStats[id]
        for i = 2, #stats do
            if stats[i] == stat then return true end
        end
        return false
    end
    local function Every(n, list, test)
        for i = 1, n do
            if not test(list[i]) then return false end
        end
        return true
    end
    local head, neck = Pick("Slot", "HEAD"), Pick("Slot", "NECK")
    local leather, plate = Pick("Armor", "Leather"), Pick("Armor", "Plate")
    local stamina, intellect = Pick("Stats", "Stamina"), Pick("Stats", "Intellect")
    local fire = Pick("Resistances", "Fire")
    local band, mine = Pick("Level", "21-30"), Pick("Level", "Up to Your Level")
    check("nothing picked, nothing to find", not Finder.Any())

    local heads, found = Find(head)
    check("a slot finds loot", heads > 0)
    check("only for that slot", Every(heads, found, function(r) return J.ItemStats[r.item][1] == 1 end))
    local necks = Find(neck)
    check("two slots find either", Find(head, neck) == heads + necks)
    local n
    n, found = Find(leather)
    check("an armor type finds its armor, and what has none (rings, cloaks)", n > 0 and Every(n, found, function(r)
        local facts = J.Facts(r.item)
        return facts[1] == 4 and (facts[2] == 2 or facts[2] == 0)
    end))
    local someLeather = false
    for i = 1, n do
        if J.Facts(found[i].item)[2] == 2 then someLeather = true end
    end
    check("leather among it", someLeather)
    n, found = Find(stamina)
    check("a stat finds the loot that has it", n > 0 and Every(n, found, function(r) return Has(r.item, 7) end))
    local both
    both, found = Find(stamina, intellect)
    check("two stats find the loot with both", both > 0 and both < n
        and Every(both, found, function(r) return Has(r.item, 7) and Has(r.item, 5) end))
    n, found = Find(fire)
    check("a resistance finds the loot that has it", n > 0 and Every(n, found, function(r) return Has(r.item, 51) end))
    n, found = Find(band)
    check("a level band finds what needs a level in it", n > 0 and Every(n, found, function(r)
        local required = J.Facts(r.item)[4]
        return required >= 21 and required <= 30
    end))
    n, found = Find(mine)
    check("up to your level finds what you can wear now", n > 0
        and Every(n, found, function(r) return J.Facts(r.item)[4] <= state.level end))
    local combined
    combined, found = Find(head, stamina, band)
    check("picks of different kinds all hold", combined > 0 and combined < heads and Every(combined, found, function(r)
        return J.ItemStats[r.item][1] == 1 and Has(r.item, 7) and J.Facts(r.item)[4] >= 21
    end))

    -- Sorted by required level, then the likelier drop first, one with no chance known last.
    n, found = Find(stamina)
    local sorted = true
    for i = 2, n do
        local a, b = found[i - 1], found[i]
        if a.required > b.required or (a.required == b.required and a.chance < b.chance) then sorted = false end
    end
    check("found loot is sorted by required level, then chance", sorted)
    check("each with its boss and dungeon", found[1].boss ~= nil and found[1].dungeon ~= nil)

    -- Sorted by upgrade: a BiS-list upgrade (no %) first, then the biggest gain, then the rest as before.
    local once, picks = {}, {}
    for i = 1, n do once[found[i].item] = (once[found[i].item] or 0) + 1 end
    for i = n, 1, -1 do
        if once[found[i].item] == 1 and #picks < 3 then picks[#picks + 1] = found[i].item end
    end
    local gains = { [picks[1]] = true, [picks[2]] = 5, [picks[3]] = 12 }
    Finder.SortByUpgrade(found, n, function(_, id) return gains[id] or false end)
    check("by upgrade, the BiS-list one first, then the biggest gain", found[1].item == picks[1]
        and found[2].item == picks[3] and found[3].item == picks[2])
    sorted = true
    for i = 5, n do
        local a, b = found[i - 1], found[i]
        if a.required > b.required or (a.required == b.required and a.chance < b.chance) then sorted = false end
    end
    check("and what is no upgrade keeps the usual order", sorted)

    -- The Journal's own filters: a mage (cloth only here) with My Class Only finds no plate.
    local function PlateFound()
        local plates = 0
        n, found = Find(plate)
        for i = 1, n do
            if J.Facts(found[i].item)[2] == 4 then plates = plates + 1 end
        end
        return plates
    end
    check("plate is found with My Class Only off", PlateFound() > 0)
    S.Set("usableOnly", true)
    check("and none with it on", PlateFound() == 0)
    S.Set("usableOnly", false)

    -- The faction switch: the dungeons in Horde cities hidden, none of their loot is found.
    local function InHordeCity(dungeon)
        return dungeon.territory == "Horde" and ns.TownCapitals[dungeon.entrance.map]
    end
    local horde = 0
    n, found = Find(stamina)
    for i = 1, n do
        if InHordeCity(found[i].dungeon) then horde = horde + 1 end
    end
    check("the Horde's city dungeons have some", horde > 0)
    S.Set("showHorde", false)
    local without
    without, found = Find(stamina)
    check("hidden by the switch, their loot is not found", without == n - horde
        and Every(without, found, function(r) return not InHordeCity(r.dungeon) end))
    S.Set("showHorde", true)
    Finder.Clear()

    -- The window: no bag while it is off; on, the bag opens the finder on the page.
    ns.Apply()
    ns.OpenJournalWindow(J.Get("Deadmines"))
    local function Bag()
        for _, frame in ipairs(state.made) do
            if rawget(frame, "tip") == "Loot Finder" then return frame end
        end
    end
    check("off, the window has no Loot Finder", Bag() == nil)
    S.Set("lootFinder", true)
    local bag = Bag()
    check("on, its bag is on the title bar", bag ~= nil and bag:IsShown())
    bag.scripts.OnClick(bag)
    local view
    for _, frame in ipairs(state.made) do
        if rawget(frame, "finding") and frame:IsVisible() then view = frame end
    end
    check("the bag opens the finder on the window's page", view ~= nil)
    local chip
    for _, frame in ipairs(state.made) do
        if rawget(frame, "pick") == stamina and frame:IsShown() then chip = frame end
    end
    check("with a chip for each pick", chip ~= nil and not Finder.Picked(stamina))
    chip.scripts.OnClick(chip)
    check("a chip picks", Finder.Picked(stamina))
    local row
    for _, frame in ipairs(state.made) do
        if rawget(frame, "where") and frame:IsShown() and not row then row = frame end
    end
    check("what it finds is listed, with its boss and dungeon", row ~= nil
        and row.where == row.boss.name .. J.Style.PLACE_DOT .. row.dungeon.name)
    for id in pairs(J.Items) do state.names[id] = "Item " .. id end
    Measure("the broadest Loot Finder search (one stat) redrawn", 3, function() view:Redraw() end)
    Finder.Toggle(head)
    Measure("a Loot Finder search for a slot and a stat redrawn", 2, function() view:Redraw() end)
    Finder.Toggle(head)
    view.finderAside = true
    view:Redraw()
    local sort
    for _, frame in ipairs(state.made) do
        if rawget(frame, "arrow") and rawget(frame, "view") == view and frame:IsShown() then sort = frame end
    end
    check("the For you column sorts by upgrade", sort ~= nil and not Finder.byUpgrade)
    sort.scripts.OnClick(sort)
    check("a click sorts it, the arrow showing", Finder.byUpgrade and sort.arrow:IsShown())
    Measure("the broadest Loot Finder search redrawn, sorted by upgrade", 4, function() view:Redraw() end)
    sort.scripts.OnClick(sort)
    check("a second click puts it back", not Finder.byUpgrade and not sort.arrow:IsShown())
    view.finderAside = false
    view:Redraw()
    local boss, dungeon = row.boss, row.dungeon
    row.scripts.OnClick(row, "LeftButton")
    check("a click opens its dungeon's page", view.dungeon == dungeon and not view.finding)
    check("on its boss", view.pinned == boss)
    bag.scripts.OnClick(bag)
    check("the bag opens the finder again, its picks kept", view.finding and Finder.Picked(stamina))
    S.Set("lootFinder", false)
    check("turned off, the bag goes and the page comes back", not bag:IsShown() and not view.finding)
    Finder.Clear()
end

-------------------------------------------------------------------------------
--  Crafting: off by default; nothing to browse without the Professions module; your own
--  profession picked first; the profession, what and skill picks; on the window, items with
--  their slot, skill and source, and enchants as spells
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J = ns.Journal
    local Crafting = J.Crafting
    check("Crafting starts off", state.defaults.crafting == false)
    check("without the Professions module there is nothing to browse", not Crafting.Available())
    ns.RecipeData = {
        [197] = { skillSpell = 3908, recipes = {
            { spell = 10, item = 9001, skill = 120, source = "vendor" },
            { spell = 11, item = 9002, skill = 1, source = "trainer" },
            { spell = 12, item = 9003, skill = 250, source = "drop" },
        } },
        [333] = { skillSpell = 7411, recipes = {
            { spell = 20, skill = 90, source = "trainer" },
            { spell = 21, item = 9004, skill = 10, source = "teacher" },
        } },
        [356] = { skillSpell = 7620, recipes = {} },
    }
    state.crafted = { [9001] = { 4, "INVTYPE_CHEST" }, [9002] = { 4, "INVTYPE_HEAD" }, [9003] = { 0, "" },
        [9004] = { 7, "" } }
    state.professions = { 333 }
    state.G.INVTYPE_CHEST = "Chest"
    check("with it, there is", Crafting.Available())
    local groups = Crafting.Groups()
    local professions, what, skill = groups[1].picks, groups[2].picks, groups[3].picks
    check("a pick for each profession with recipes", #professions == 2)
    check("your own profession is picked first", Crafting.Profession().line == 333)
    local out = {}
    local n = Crafting.Collect(out)
    check("its recipes, lowest skill first", n == 2 and out[1].spell == 21 and out[2].spell == 20)
    check("a recipe with no item is an enchant", out[2].what == "enchant" and out[1].what == "other")
    local tailoring = professions[1].line == 197 and professions[1] or professions[2]
    Crafting.Toggle(tailoring)
    check("another profession picked lists only its recipes", Crafting.Profession() == tailoring
        and Crafting.Collect(out) == 3)
    Crafting.Toggle(tailoring)
    check("and stays picked when clicked again", Crafting.Profession() == tailoring)
    Crafting.Toggle(what[1])
    n = Crafting.Collect(out)
    check("Gear lists what goes in a slot", n == 2 and out[1].item == 9002 and out[2].item == 9001)
    Crafting.Toggle(what[2])
    check("Gear and Consumables list either", Crafting.Collect(out) == 3)
    Crafting.Toggle(what[1])
    Crafting.Toggle(what[2])
    Crafting.Toggle(skill[2])
    n = Crafting.Collect(out)
    check("a skill band lists what needs a skill in it", n == 1 and out[1].item == 9001)
    check("the top band has no end", Crafting.Label(skill[#skill]) == "225+")
    Crafting.Toggle(skill[2])

    ns.Apply()
    ns.OpenJournalWindow(J.Get("Deadmines"))
    local function Hammer()
        for _, frame in ipairs(state.made) do
            if rawget(frame, "tip") == "Crafting" then return frame end
        end
    end
    check("off, the window has no hammer", Hammer() == nil)
    S.Set("crafting", true)
    local hammer = Hammer()
    check("on, its hammer is on the title bar", hammer ~= nil and hammer:IsShown())
    hammer.scripts.OnClick(hammer)
    local view
    for _, frame in ipairs(state.made) do
        if rawget(frame, "crafting") and frame:IsVisible() then view = frame end
    end
    check("the hammer opens Crafting on the window's page", view ~= nil)
    local function Shown(key, value)
        for _, frame in ipairs(state.made) do
            if rawget(frame, key) == value and frame:IsShown() then return frame end
        end
    end
    local chest = Shown("itemID", 9001)
    check("an item is listed with its slot, skill and source", chest ~= nil
        and chest.where == "Chest" .. J.Style.PLACE_DOT .. "Skill 120" .. J.Style.PLACE_DOT .. "Vendor")
    local enchanting = professions[1] == tailoring and professions[2] or professions[1]
    local chip = Shown("pick", enchanting)
    check("with a chip for each profession", chip ~= nil)
    chip.scripts.OnClick(chip)
    check("a chip picks the profession", Crafting.Profession() == enchanting)
    check("an enchant is listed as its spell", Shown("spell", 20) ~= nil)
    hammer.scripts.OnClick(hammer)
    check("the hammer again puts the page back", not view.crafting)
    local portraits = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
    _G.RequestRaidInfo, _G.GetNumSavedInstances = function() end, function() return 0 end
    _G.SetPortraitTextureFromCreatureDisplayID = function() end
    S.Set("newLayout", true)
    local tab
    for _, button in ipairs(hammer:GetParent().tabBar.buttons) do
        if button.key == "crafting" and button:IsShown() then tab = button end
    end
    check("in New Layout it is a tab, not a hammer", tab ~= nil and not hammer:IsShown())
    tab.scripts.OnClick(tab)
    check("the tab opens Crafting", view.crafting)
    S.Set("newLayout", false)
    _G.SetPortraitTextureFromCreatureDisplayID = portraits
    _G.RequestRaidInfo, _G.GetNumSavedInstances = nil, nil
    hammer.scripts.OnClick(hammer)
    S.Set("crafting", false)
    check("turned off, the hammer goes and the page comes back", not hammer:IsShown() and not view.crafting)
end

-------------------------------------------------------------------------------
--  New Layout: on by default; nothing of it is built while it is off; on, it shows its pages
-------------------------------------------------------------------------------
do
    local ns, state, S = fixture({ enabled = true })
    local J = ns.Journal
    ns.Apply()
    local function Made(field)
        for _, frame in ipairs(state.made) do
            if rawget(frame, field) ~= nil then return frame end
        end
    end
    ns.OpenJournalWindow(J.Get("Deadmines"))
    ns.OpenJournalWindow(J.RANK)
    ns.OpenJournalWindow(J.Factions("reputation")[1])
    check("on by default for players, off in this fixture", ns.FEATURES.journal.newLayout == true and not S.Get("newLayout"))
    check("off, no dungeon pane is built", not J.DungeonPane.Built())
    check("nor a dungeon card", Made("shade") == nil)
    check("nor a faction card", Made("counts") == nil)
    local portraits = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
    _G.RequestRaidInfo, _G.GetNumSavedInstances = function() end, function() return 0 end
    _G.SetPortraitTextureFromCreatureDisplayID = function() end
    ns.OpenJournalWindow(J.Get("Deadmines"))
    S.Set("newLayout", true)
    check("on, a dungeon opens in the pane", J.DungeonPane.Built() and J.DungeonPane.shown)
    local St, window, loot = J.Style, Made("positionKey"), Made("lootDense")
    local lootW = loot.w
    check("at Map Size 100% the window keeps its size", window.w == St.WINDOW_W and window.h == St.WINDOW_H)
    state.env.UIParent:SetSize(2133, 1200)
    S.Set("mapSize", 1.5)
    check("a bigger map grows the window by its extra width and height",
        window.w == St.WINDOW_W + 220 and window.h == St.WINDOW_H + 147)
    check("so the loot beside it keeps its width", loot.w == lootW)
    state.env.UIParent:SetSize(1365, 768)
    S.Set("mapSize", 2)
    check("on a screen with no room to spare the map stays at its own size",
        window.w == St.WINDOW_W and window.h == St.WINDOW_H)
    state.env.UIParent:SetSize(2133, St.WINDOW_H + 32 + 100)
    S.Set("mapSize", 1.9)
    check("with a little room it grows only as far as the screen allows",
        window.h > St.WINDOW_H and window.h <= St.WINDOW_H + 101 and window.w < St.WINDOW_W + 396)
    check("and the loot still keeps its width", loot.w == lootW)
    local Finder = J.Finder
    S.Set("lootFinder", true)
    Finder.Toggle(Finder.GROUPS[1].picks[1])
    local bag, clear
    for _, frame in ipairs(state.made) do
        if rawget(frame, "tip") == "Loot Finder" then bag = frame end
    end
    bag.scripts.OnClick(bag)
    for _, frame in ipairs(state.made) do
        if rawget(frame, "clear") and rawget(frame, "found") and frame:IsVisible() then clear = frame.clear end
    end
    clear.onClick()
    check("the Loot Finder's Clear drops every pick and stays on the finder",
        not Finder.Any() and Made("finding").finding)
    bag.scripts.OnClick(bag)
    S.Set("lootFinder", false)
    S.Set("newLayout", false)
    check("turned off again, the pane goes", not J.DungeonPane.shown)
    check("and the old lists ignore Map Size", window.w == St.WINDOW_W and window.h == St.WINDOW_H)
    S.Set("mapSize", 2)
    check("even when it changes while they show", window.w == St.WINDOW_W and window.h == St.WINDOW_H)
    S.Set("mapSize", 1)
    _G.SetPortraitTextureFromCreatureDisplayID = portraits
    _G.RequestRaidInfo, _G.GetNumSavedInstances = nil, nil
end

print(("test-dungeon-journal: %d checks passed"):format(checks))
