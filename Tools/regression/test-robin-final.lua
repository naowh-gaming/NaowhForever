-- Run with Lua 5.1 from the repository root. Hardware actions are recorded, not executed.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local TocFiles = dofile('Tools/regression/toc_files.lua')
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local function fixture(kind)
    local state = { combat = false, secret = false, now = 1000, bags = { 101, 202, 101, 303 },
        settings = { gearSets = true, gearBarVisible = false, trinketBar = true, trinketPickerSide = 'above',
            trinketSize = 36, trinketSpacing = 4, gearBarSize = 32, gearBarSpacing = 4, gearBarShow = 'always',
            gearMounted = '', gearResting = '', gearDrinking = '', gearDungeon = '', gearRaid = '', gearBattleground = '',
            gearForms = {} },
        frames = {}, named = {}, timers = {}, equips = {} }
    local function frame(name, parent, template)
        local f = { scripts = {}, events = {}, shown = true, parent = parent, attributes = {},
            secure = template == 'SecureActionButtonTemplate' or name == 'NaowhForeverTrinkets' }
        local noop = function() end
        setmetatable(f, { __index = function(_, key) if key ~= 'sitSpot' and key ~= 'hot' then return noop end end })
        function f:SetScript(key, fn) self.scripts[key] = fn end
        function f:HookScript(key, fn)
            local old = self.scripts[key]
            self.scripts[key] = function(...) if old then old(...) end; fn(...) end
        end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterUnitEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
        function f:SetShown(v) if v then self:Show() else self:Hide() end end
        function f:IsShown() return self.shown end
        function f:IsProtected()
            if self.secure then return true end
            for _, other in ipairs(state.frames) do
                if other.parent == self and other.secure then return true end
            end
            return false
        end
        function f:SetSize(w, h)
            assert(not (self.secure and state.combat), 'layout changed in combat')
            self.width, self.height = w, h
        end
        function f:SetPoint(...) self.point = { ... } end
        function f:GetFrameLevel() return 1 end
        function f:SetTexture(v) self.texture = v end
        function f:SetTexCoord(l) self.crop = l end
        function f:SetColorTexture(...) self.color = { ... } end
        function f:SetVertexColor(...) self.color = { ... } end
        function f:SetText(v) self.text = v end
        function f:SetFont(...) self.font = { ... } end
        function f:SetDrawSwipe(v) self.swipe = v end
        function f:SetCooldown(start, duration) self.cooldown = { start, duration } end
        function f:SetHideCountdownNumbers(v) self.hideNumbers = v end
        function f:SetAttribute(key, value)
            assert(not state.combat, 'secure attribute changed in combat')
            self.attributes[key] = value
        end
        function f:CreateTexture() return frame(nil, self) end
        function f:CreateMaskTexture() return frame(nil, self) end
        state.frames[#state.frames + 1] = f
        if name then state.named[name] = f end
        return f
    end
    local S = { Get = function(k) return state.settings[k] end,
        Set = function(k, v) state.settings[k] = v end, OnChange = function() end }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), QoLSettings = S, Apply = function() end, Print = function() end,
        ShowUnlockMode = function() end, HideUnlockMode = function() end,
        THEME = { bg = {}, accent = { r = 0, g = 1, b = 1 }, accentSoft = {} },
        UIFontPath = function() return 'font' end,
        Border = function() return frame() end, Solid = function() return frame() end,
        PixelInset = function(region) return region end,
        ThemeTint = function(_, literal) return literal end,
        Shared = { Style = { TIME_OK_RGB = {}, TIME_LOW_RGB = {}, TIME_OUT_RGB = {}, ICON_CROP = 0.08 }, Items = { SLEEPING_BAG = 211527,
            Fits = function(id, slot)
                if slot >= 16 then return id == 404 end
                return id ~= 303 and id ~= 404 and (slot == 13 or slot == 14)
            end },
            Parts = { Smooth = function(t) return t end, HudText = function(t) return t end,
                Pill = function() return frame() end, SetPill = function() return 0 end, ColorPill = function() end,
                Press = function(button) button.pressed = true end,
                HudFont = function(fs, font, size, outline) fs:SetFont(font, size, outline) end } },
        Font = function() return frame() end, Tooltip = function() end,
        Button = function(parent, text, w, h, callback)
            local f = frame(nil, parent); f.scripts.OnClick = callback; return f
        end,
        UI = { STATUS = {}, AttachMover = function() return frame() end,
            ModuleSettings = function(_, defaults)
                for key, value in pairs(defaults) do
                    if state.settings[key] == nil then state.settings[key] = value end
                end
                return S
            end },
    }
    function ns.OnApply(fn) local was = ns.Apply ns.Apply = function(...) was(...) fn(...) end end
    local env = { _G = { NaowhForever = ns }, UIParent = {}, BACKPACK_CONTAINER = 0, NUM_BAG_SLOTS = 0,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        CreateFrame = function(_, name, parent, template) return frame(name, parent, template) end,
        InCombatLockdown = function() return state.combat end,
        UnitIsDeadOrGhost = function() return false end,
        UnitIsFeignDeath = function() return false end, INVSLOT_FIRST_EQUIPPED = 1, INVSLOT_LAST_EQUIPPED = 19,
        UnitCastingInfo = function() end, UnitChannelInfo = function() end, GetCursorInfo = function() end,
        GetTime = function() return state.now end,
        IsInInstance = function() return false end,
        IsMounted = function() return false end, IsResting = function() return false end,
        GetInventoryItemTexture = function(_, slot) return slot + 1000 end,
        GetInventoryItemID = function(_, slot) return slot + 2000 end,
        GetInventoryItemCooldown = function(_, slot)
            local cd = state.cooldowns and state.cooldowns[slot]
            if cd then return cd[1], cd[2], 1 end
            return 0, 0, 1
        end,
        C_Secrets = { ShouldAurasBeSecret = function() return state.secret end },
        LibStub = function() return { PixelGlow_Start = function() end, PixelGlow_Stop = function() end } end,
        C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
            assert(not state.combat and not state.secret, 'restricted aura read')
            return state.auras and state.auras[id]
        end },
        C_TooltipInfo = { GetUnitBuffByAuraInstanceID = function() return { lines = {
            { leftText = 'Camp Benefits' }, { leftText = 'Tent: Rested XP\nMana Well: 10 MP5' },
            { leftText = 'Spell ID: 1229741' }, { leftText = '20 |4minute:minutes;' },
        } } end },
        C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
        C_EquipmentSet = {
            GetEquipmentSetIDs = function() return state.setIDs or {} end,
            GetEquipmentSetInfo = function(id) return 'Set' .. id, 500 + id, id, false, 1, 1, 0, 0 end,
            GetItemIDs = function(id) return { [16] = 4000 + id } end,
            GetIgnoredSlots = function() return {} end,
        },
        C_Container = {
            GetContainerNumSlots = function() return #state.bags end,
            GetContainerItemID = function(_, slot) return state.bags[slot] end,
            GetItemCooldown = function(id)
                local cd = state.itemCooldowns and state.itemCooldowns[id]
                if cd then return cd[1], cd[2], 1 end
                return 0, 0, 1
            end,
        },
        C_Item = {
            GetItemInfoInstant = function(id) return id, nil, nil, id == 303 and 'INVTYPE_HEAD' or 'INVTYPE_TRINKET' end,
            GetItemIconByID = function(id) return id end,
            GetItemInfo = function(id) return 'Weapon' .. id, '[Weapon' .. id .. ']' end,
            GetItemCount = function() return 0 end,
            EquipItemByName = function(id, slot)
                assert(not state.combat); state.equips[#state.equips + 1] = { id, slot }
            end,
        },
        hooksecurefunc = function(t, key, callback)
            local orig = t[key]; t[key] = function(...) orig(...); callback(...) end
        end,
    }
    setmetatable(env, { __index = _G })
    function state.load(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
    end
    state.load('Shared/UI/ItemBar.lua')
    function state.loadModule(dir)
        for _, path in ipairs(TocFiles("^" .. dir .. "/.*%.lua$")) do state.load(path) end
    end
    function state.fire(event)
        local copy = {}; for i, f in ipairs(state.frames) do copy[i] = f end
        for _, f in ipairs(copy) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end end
    end
    state.ns, state.S = ns, S
    return state
end

do
    local s = fixture('gear')
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    check('hidden set bar stays hidden', not s.named.NaowhForeverGearBar.shown)
    local swaps = false
    for _, f in ipairs(s.frames) do if f.events.PLAYER_MOUNT_DISPLAY_CHANGED then swaps = true end end
    check('hidden set bar keeps automatic swaps', swaps)
    local bar = s.named.NaowhForeverTrinkets
    check('two trinket slots', #bar.buttons == 2)
    check('secure use top slot', bar.buttons[1].attributes.item1 == '13')
    check('secure use bottom slot', bar.buttons[2].attributes.item1 == '14')
    bar.buttons[2].scripts.PostClick(bar.buttons[2], 'RightButton', false)
    local picker
    for _, f in ipairs(s.frames) do if type(rawget(f, 'buttons')) == 'table' and rawget(f, 'close') then picker = f end end
    check('deduplicates trinkets and excludes armor', #picker.buttons == 2)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('uses selected destination slot', s.equips[1][1] == 101 and s.equips[1][2] == 14)
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    s.bags = {}
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('stale bag selection is refused', #s.equips == 1)
    s.bags = { 101 }; bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    s.fire('PLAYER_REGEN_DISABLED'); s.combat = true
    check('combat closes picker', not picker.shown)
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    check('and a right-click opens it again in combat', picker.shown)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('a pick in combat waits, its icon on the slot', #s.equips == 1 and not picker.shown
        and bar.buttons[1].next.shown and bar.buttons[1].next.icon.texture == 101)
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('picking it again calls it off', not bar.buttons[1].next.shown)
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    s.S.Set('trinketSize', 50); s.ns.Apply()
    check('combat blocks equips and layout', #s.equips == 1 and bar.buttons[1].width == 36)
    s.combat = false; s.fire('PLAYER_REGEN_ENABLED')
    check('deferred settings apply', bar.buttons[1].width == 50)
    check('the pick goes on as combat ends', #s.equips == 2 and s.equips[2][1] == 101 and s.equips[2][2] == 13)
    check('and its mark clears', not bar.buttons[1].next.shown)
end

do
    local s = fixture('gear')
    s.settings.trinketSlots = 'weapons'
    s.bags = { 101, 404 }
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    local bar = s.named.NaowhForeverTrinkets
    check('Trinkets and Weapons: five slots', #bar.buttons == 5)
    check('the trinkets keep their names for their keys', bar.buttons[1] == s.named.NaowhForeverTrinket1
        and bar.buttons[2] == s.named.NaowhForeverTrinket2)
    local main = s.named.NaowhForeverGearSlot16
    check('a weapon slot is a secure use of its slot', bar.buttons[3] == main and main.attributes.item1 == '16')
    check('the bar is as wide as its slots', bar.width == 5 * 36 + 4 * 4)
    main.scripts.PostClick(main, 'RightButton', false)
    local picker
    for _, f in ipairs(s.frames) do if type(rawget(f, 'buttons')) == 'table' and rawget(f, 'close') then picker = f end end
    check('a weapon slot opens its picker, with only what fits it', picker and picker.shown
        and picker.buttons[1].itemID == 404 and #picker.buttons == 1)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('and swaps the weapon', s.equips[1][1] == 404 and s.equips[1][2] == 16)
    s.fire('PLAYER_REGEN_DISABLED'); s.combat = true
    main.scripts.PostClick(main, 'RightButton', false)
    check('in combat a weapon slot opens its picker too', picker.shown)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('and its pick waits for the fight to end', #s.equips == 1 and main.next.shown)
    local watcher
    for _, f in ipairs(s.frames) do if f.events.PLAYER_EQUIPMENT_CHANGED and f.events.PLAYER_REGEN_DISABLED then watcher = f end end
    main.icon.texture = nil
    watcher.scripts.OnEvent(watcher, 'PLAYER_EQUIPMENT_CHANGED', 16)
    check('a weapon swapped in combat shows on its slot at once', main.icon.texture == 1016)
    s.combat = false; s.fire('PLAYER_REGEN_ENABLED')
    s.S.Set('trinketSlots', 'trinkets')
    check('back to Trinkets: two slots, the weapons hidden', #bar.buttons == 2 and not main.shown)
end

do
    local s = fixture('gear')
    s.settings.gearBarVisible, s.settings.trinketBar = true, false
    s.setIDs = { 1, 2 }
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    for _, t in ipairs(s.timers) do t() end
    local bar = s.named.NaowhForeverGearBar
    local function Buttons(secure)
        local found = {}
        for _, f in ipairs(s.frames) do
            if f.parent == bar and f.secure == secure and f.shown and rawget(f, 'set') then found[#found + 1] = f end
        end
        return found
    end
    check('Swap Weapons in Combat off: plain buttons, the bar is not protected', #Buttons(false) == 2
        and not bar:IsProtected())
    s.S.Set('gearCombatWeapons', true)
    local secure = Buttons(true)
    check('on: secure buttons instead', #secure == 2 and #Buttons(false) == 0)
    check('a plain click runs its weapons through /equipslot in combat', secure[1].attributes.type1 == 'macro'
        and secure[1].attributes.macrotext1 == '/equipslot [combat]16 Weapon4001')
    s.fire('PLAYER_REGEN_DISABLED'); s.combat = true
    s.S.Set('gearBarSize', 40)
    for _, t in ipairs(s.timers) do t() end
    check('in combat a change waits, nothing protected is touched', secure[1].width == 32)
    s.combat = false; s.fire('PLAYER_REGEN_ENABLED')
    for _, t in ipairs(s.timers) do t() end
    check('and goes through once the fight ends', secure[1].width == 40)
end

do
    local s = fixture('gear')
    s.settings.trinketBar = false
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    local function Listening(e)
        for _, f in ipairs(s.frames) do if f.events[e] then return f end end
    end
    check('trinket bar off: no combat events of its own', not Listening('PLAYER_REGEN_DISABLED'))
    s.S.Set('trinketBar', true)
    local watcher = Listening('PLAYER_REGEN_DISABLED')
    check('trinket bar on: it listens', watcher and watcher.events.PLAYER_EQUIPMENT_CHANGED)
    local bar = s.named.NaowhForeverTrinkets
    bar.buttons[1].width = nil
    watcher.scripts.OnEvent(watcher, 'PLAYER_EQUIPMENT_CHANGED', 5)
    check('another slot changing leaves the trinkets alone', rawget(bar.buttons[1], 'width') == nil)
    watcher.scripts.OnEvent(watcher, 'PLAYER_EQUIPMENT_CHANGED', 13)
    check('a trinket slot changing redraws them', bar.buttons[1].width == 36)
    s.S.Set('trinketBar', false)
    check('switched off again: it stops listening', not watcher.events.PLAYER_REGEN_DISABLED
        and not watcher.events.PLAYER_EQUIPMENT_CHANGED and not watcher.events.PLAYER_REGEN_ENABLED)
end

do
    local s = fixture('gear')
    s.settings.trinketCooldown, s.settings.trinketCountdown = true, true
    s.cooldowns = { [13] = { 900, 120 } }
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    local bar = s.named.NaowhForeverTrinkets
    local top, bottom = bar.buttons[1].cooldown, bar.buttons[2].cooldown
    check('a trinket on cooldown sweeps', top.shown and top.cooldown[1] == 900 and top.cooldown[2] == 120)
    check('a ready trinket shows no sweep', not bottom.shown)
    check('cooldown numbers on', top.hideNumbers == false)
    s.itemCooldowns = { [101] = { 950, 60 } }
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    local picker
    for _, f in ipairs(s.frames) do if type(rawget(f, 'buttons')) == 'table' and rawget(f, 'close') then picker = f end end
    local cooling, ready = picker.buttons[1].cooldown, picker.buttons[2].cooldown
    check('a trinket in the picker on cooldown sweeps', cooling.shown and cooling.cooldown[2] == 60
        and cooling.hideNumbers == false)
    check('a ready one in the picker shows no sweep', not ready.shown)
    check('the picker opens above the slot', picker.point[1] == 'BOTTOMLEFT' and picker.point[3] == 'TOPLEFT')
    s.itemCooldowns[202] = { 990, 30 }
    s.fire('BAG_UPDATE_COOLDOWN')
    check('the open picker follows a new cooldown', ready.shown and ready.cooldown[2] == 30)
    s.S.Set('trinketPickerSide', 'left')
    check('changing the side closes the picker', not picker.shown)
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    check('it opens on the left', picker.point[1] == 'TOPRIGHT' and picker.point[2] == bar.buttons[1]
        and picker.point[3] == 'TOPLEFT' and picker.point[4] < 0)
    s.S.Set('trinketPickerSide', 'below')
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    check('or below', picker.point[1] == 'TOPLEFT' and picker.point[3] == 'BOTTOMLEFT' and picker.point[5] < 0)
    picker:Hide()
    s.fire('PLAYER_REGEN_DISABLED'); s.combat = true
    s.cooldowns[14] = { 1000, 30 }
    s.fire('BAG_UPDATE_COOLDOWN')
    check('a trinket used in combat starts its sweep', bottom.shown and bottom.cooldown[2] == 30)
    s.cooldowns[14] = { 1010, 1.5 }; bottom:Hide()
    s.fire('BAG_UPDATE_COOLDOWN')
    check('the global cooldown alone draws no sweep', not bottom.shown)
    s.combat = false; s.fire('PLAYER_REGEN_ENABLED')
    s.S.Set('trinketCountdown', false)
    check('cooldown numbers off', top.hideNumbers == true and top.shown)
    s.S.Set('trinketCooldown', false)
    local listening = false
    for _, f in ipairs(s.frames) do if f.events.BAG_UPDATE_COOLDOWN then listening = true end end
    check('cooldowns off: no sweeps and no cooldown events', not top.shown and not bottom.shown and not listening)
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    check('cooldowns off: none in the picker either', not picker.buttons[1].cooldown.shown)
    local icon = bar.buttons[1].icon
    check('trinket icons keep their rounded edges by default', icon.crop == 0)
    s.S.Set('trinketSquare', true)
    check('square icons trims the edges', icon.crop > 0)
    s.S.Set('trinketSquare', false)
    check('square icons off restores the edges', icon.crop == 0)
end

do
    local s = fixture('gear')
    s.settings.gearBarVisible, s.settings.gearBarShow, s.settings.trinketBar = true, 'nocombat', false
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    local bar = s.named.NaowhForeverGearBar
    check('Show Out of Combat: shown out of combat', bar.shown)
    s.fire('PLAYER_REGEN_DISABLED'); s.combat = true
    check('and hidden as a fight starts', not bar.shown)
    s.combat = false; s.fire('PLAYER_REGEN_ENABLED')
    check('and back after it', bar.shown)
    check('4px between buttons by default', bar.width == 36)
    s.S.Set('gearBarSpacing', 10)
    check('Spacing widens the gaps', bar.width == 42)
    s.S.Set('gearBarShow', 'combat')
    check('Show In Combat: hidden out of combat', not bar.shown)
    s.fire('PLAYER_REGEN_DISABLED')
    check('shown in one', bar.shown)
    s.fire('PLAYER_REGEN_ENABLED')
    s.S.Set('gearBarShow', 'always')
    local listens = false
    for _, f in ipairs(s.frames) do if f.events.PLAYER_REGEN_DISABLED then listens = true end end
    check('Show Always: shown, with no combat event of its own', bar.shown and not listens)
end

do
    local s = fixture('camp')
    s.load('Core/Features.lua'); s.load('NaowhForever_Combat/AuraBuffs/AuraBuffs.lua')
    s.load('NaowhForever_Combat/AuraBuffs/Constants.lua')
    s.S.Set('campShowUnder', false)
    for _, file in ipairs({ 'Data/Campfire.lua', 'CampReader.lua', 'View/Style.lua', 'View/Glow.lua', 'View/CampIcon.lua',
        'View/CampBar.lua', 'View/CampAlert.lua', 'UI/CampBag.lua', 'UI/Campfire.lua', 'UI/CampfireCards.lua' }) do
        s.load('NaowhForever_Combat/AuraBuffs/' .. file)
    end
    s.fire('PLAYER_LOGIN')
    local icon = s.named.NaowhForeverCampfire
    check('no icon swipe', icon.timer.swipe == false)
    check('missing shown by default', icon.shown)
    s.S.Set('campShowMissing', false)
    check('missing can be hidden', not icon.shown)
    s.auras = { [1229739] = { duration = 60, expirationTime = 1060 } }
    s.fire('UNIT_AURA')
    check('sitting label is Resting', icon.label.text == 'Resting' and icon.shown)
    s.auras = { [1229741] = { duration = 3600, expirationTime = 2200, auraInstanceID = 1 } }
    s.fire('UNIT_AURA')
    check('effects instead of objects', icon.buffs.text == '+Rested\n+MP5')
    s.S.Set('campBuffSide', 'right'); s.S.Set('campBuffTextSize', 20)
    check('buff text position and size', icon.buffs.point[1] == 'LEFT' and icon.buffs.font[2] == 20)
    s.S.Set('campShowUnder', true); s.S.Set('campShowUnderMinutes', 1)
    check('one-minute threshold hides healthy camp', not icon.shown)
    s.combat = true; s.fire('UNIT_AURA'); s.combat = false
    s.secret = true; s.fire('UNIT_AURA')
    check('restricted aura access skipped', true)
end
do
    local active = {}
    local m = fixture('profile')
    m.ns.DB = function() return active end
    m.load('Core/Features.lua')
    m.load('NaowhForever_Utilities/Macros/Macros.lua')
    m.S.Set("classMacros", { PALADIN = { { name = "Test", body = "/say test" } } })
    check('class macros use profile-backed data', active.utilityReminders.classMacros.PALADIN[1].name == "Test")
    active = {}
    check('class macros follow active profile', next(m.S.Get("classMacros")) == nil)
end
print(checks .. ' final-video regressions passed')
