-- Loads the four Destroy Cheapest files against stubbed bag, item, loot and cursor APIs and checks
-- what may be destroyed: the protections, which All Items does not lift; Keep Items Worth More
-- Than, in the scan and at the second click; the two-click confirmation, which is cancelled when
-- the stack, the link, the loot shown or the button changes; and the second click's re-read of
-- the slot, which deletes nothing when the item or a setting changed.
-- Run from the repo root: lua Tools/regression/test-destroy-cheapest.lua
local FILES = {
    "NaowhForever_QoL/Loot/DestroyCheapest.lua",
    "NaowhForever_QoL/Loot/DestroyCheapestScan.lua",
    "NaowhForever_QoL/Loot/DestroyCheapestDestroy.lua",
    "NaowhForever_QoL/Loot/DestroyCheapestPopup.lua",
}

local CLASS = { CONSUMABLE = 0, WEAPON = 2, ARMOR = 4, TRADE = 7, QUEST = 12, KEY = 13 }
local FISHING_POLE, HEARTHSTONE, MINING_PICK = 6256, 6948, 2901
local BIND_ON_ACQUIRE, BIND_QUEST = 1, 4
local SLOTS = 16

local checks = 0
local function check(ok, what)
    checks = checks + 1
    if not ok then error("test-destroy-cheapest: " .. what, 2) end
end

-- itemID -> name, quality, vendor price, class, subclass, bind type, item set
local ITEMS = {
    [10] = { "Linen Cloth", 1, 10, CLASS.TRADE, 0 },
    [11] = { "Wool Cloth", 1, 30, CLASS.TRADE, 0 },
    [12] = { "Silk Cloth", 1, 500, CLASS.TRADE, 0 },
    [20] = { "Blue Ring", 3, 900, CLASS.ARMOR, 0 },
    [21] = { "Rough Stone", 1, 0, CLASS.TRADE, 0 },
    [30] = { "Quest Letter", 1, 5, CLASS.QUEST, 0 },
    [31] = { "Quest Bound Pouch", 1, 5, CLASS.TRADE, 0, BIND_QUEST },
    [32] = { "Bound Chest", 0, 5, CLASS.ARMOR, 1, BIND_ON_ACQUIRE },
    [33] = { "Set Helm", 2, 40, CLASS.ARMOR, 1, 0, 77 },
    [34] = { "Key", 1, 0, CLASS.KEY, 0 },
    [35] = { "BiS Ring", 2, 50, CLASS.ARMOR, 0 },
    [36] = { "Library Book", 1, 5, CLASS.TRADE, 0 },
    [37] = { "Gear Set Belt", 2, 50, CLASS.ARMOR, 0 },
    [38] = { "Quest Slot Rock", 1, 5, CLASS.TRADE, 0 },
    [40] = { "Worn Sword", 1, 100, CLASS.WEAPON, 1 },
    [FISHING_POLE] = { "Fishing Pole", 1, 5, CLASS.WEAPON, 20 },
    [HEARTHSTONE] = { "Hearthstone", 1, 0, CLASS.TRADE, 0 },
    [MINING_PICK] = { "Mining Pick", 1, 2, CLASS.WEAPON, 14 },
    [50] = { "Runecloth", 1, 2000, CLASS.TRADE, 0 },
}

local function Fixture()
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local t = { env = env, settings = {}, deleted = 0, picked = 0, printed = {}, auction = {},
        linkVendor = {}, missingLinks = {} }
    local defaults = {
        enabled = true, destroyCheapest = true,
        destroyCheapestPoor = true, destroyCheapestCommon = true, destroyCheapestUncommon = true,
        destroyCheapestRare = true, destroyCheapestEpic = false, destroyCheapestLegendary = false,
        destroyCheapestArtifact = false, destroyCheapestHeirloom = false,
        destroyCheapestSide = "top", destroyCheapestMovable = false, destroyCheapestTransfers = false,
        destroyCheapestMarket = false, destroyCheapestMarketRank = false, destroyCheapestAnyway = false,
        destroyCheapestMarketStale = false, destroyCheapestMarketDays = 7,
        destroyCheapestConsumable = true, destroyCheapestAll = false, bagCleanupMaxValue = 0,
        destroyCheapestRankQty = "batch", destroyCheapestZeroVendor = false,
        destroyCheapestBoundGear = false, destroyCheapestDurability = false,
    }
    local db = {}
    local S = {}
    function S.Get(k)
        if t.settings[k] ~= nil then return t.settings[k] end
        return defaults[k]
    end
    function S.DB() return db end
    function S.Set(k, v) t.settings[k] = v end
    t.S, t.db = S, db

    -- bags[bag] = { n = slots, [slot] = { id, count, link, bound } }; family[bag] = bag family.
    t.bags, t.family, t.loot, t.quests, t.sets, t.bis, t.books = {}, {}, {}, {}, {}, {}, {}
    t.durability = {}
    local cursor

    local noop = function() end
    local methods = {
        IsShown = function(self) return self._shown == true end,
        Show = function(self)
            self._shown = true
            if self._scripts.hOnShow then self._scripts.hOnShow(self) end
        end,
        Hide = function(self)
            local was = self._shown
            self._shown = false
            if was and self._scripts.hOnHide then self._scripts.hOnHide(self) end
        end,
        SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
        SetScript = function(self, ev, fn) self._scripts[ev] = fn end,
        GetScript = function(self, ev) return self._scripts[ev] end,
        HookScript = function(self, ev, fn)
            local old = self._scripts["h" .. ev]
            self._scripts["h" .. ev] = function(...) if old then old(...) end fn(...) end
        end,
        RegisterEvent = function(self, ev) self._events[ev] = true end,
        UnregisterAllEvents = function(self) for k in pairs(self._events) do self._events[k] = nil end end,
        GetFrameLevel = function() return 1 end,
        GetHeight = function() return 1 end,
        GetWidth = function() return 1 end,
        GetText = function() return "" end,
        IsMouseOver = function() return false end,
        GetParent = function(self) return self._parent end,
    }
    local widget
    local mt = { __index = function(w, k)
        local m = methods[k]
        if m then return m end
        if k:match("^[A-Z]") then return noop end
        local child = widget()
        rawset(w, k, child)
        return child
    end }
    widget = function() return setmetatable({ _scripts = {}, _events = {} }, mt) end
    t.widget = widget

    env.LootFrame = widget()
    env.UIParent = widget()
    env.GameTooltip = widget()
    env.CreateFrame = function() return widget() end
    env.wipe = function(tbl) for k in pairs(tbl) do tbl[k] = nil end return tbl end
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.time = function() return 0 end
    env.GetServerTime = function() return 1000 end
    env.InCombatLockdown = function() return false end
    env.StaticPopup_FindVisible = function() return nil end
    env.ClearCursor = function() cursor = nil end
    env.GetCursorInfo = function()
        if cursor then return "item", cursor.id end
    end
    env.DeleteCursorItem = function()
        if not cursor then return end
        t.bags[cursor.bag][cursor.slot] = nil
        cursor = nil
        t.deleted = t.deleted + 1
    end
    env.LootSlot = noop
    env.hooksecurefunc = function(tbl, name, fn)
        local orig = tbl[name]
        tbl[name] = function(...)
            local a, b, c = orig(...)
            fn(...)
            return a, b, c
        end
    end
    env.BACKPACK_CONTAINER, env.NUM_BAG_SLOTS, env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0, 4, 4
    env.ERR_INV_FULL, env.ERR_BAG_FULL = "ERR_INV_FULL", "ERR_BAG_FULL"
    env.LOOT_SLOT_ITEM = 1
    env.ITEM_QUALITY_COLORS = {}
    for q = 0, 7 do env.ITEM_QUALITY_COLORS[q] = { r = 1, g = 1, b = 1 } end
    env.Enum = { ItemWeaponSubclass = { Fishingpole = 20 }, ItemBind = { OnAcquire = BIND_ON_ACQUIRE, Quest = BIND_QUEST } }

    local function Slot(bag, slot)
        local b = t.bags[bag]
        local s = b and b[slot]
        if not s then return nil end
        return { itemID = s.id, stackCount = s.count, hyperlink = s.link or ("item:" .. s.id),
            quality = ITEMS[s.id][2], iconFileID = s.id, isBound = s.bound, isLocked = s.locked }
    end
    env.C_Container = {
        GetContainerItemInfo = Slot,
        GetContainerNumSlots = function(bag) return t.bags[bag] and t.bags[bag].n or 0 end,
        GetContainerNumFreeSlots = function(bag) return 0, t.family[bag] or 0 end,
        GetContainerItemQuestInfo = function(bag, slot)
            local s = t.bags[bag] and t.bags[bag][slot]
            return { isQuestItem = s and t.quests[s.id] or false }
        end,
        GetContainerItemEquipmentSetInfo = function() return false end,
        GetContainerItemDurability = function(bag, slot)
            local value = t.durability[bag .. ":" .. slot]
            if value then return value[1], value[2] end
        end,
        PickupContainerItem = function(bag, slot)
            if cursor then
                cursor = nil
                return
            end
            local s = t.bags[bag] and t.bags[bag][slot]
            t.picked = t.picked + 1
            if s then cursor = { bag = bag, slot = slot, id = s.id } end
        end,
    }
    local function Info(query)
        if t.missingLinks[query] then return nil end
        local id = query
        if type(query) == "string" then id = tonumber(query:match("item:(%d+)")) end
        local row = ITEMS[id]
        if not row then return nil end
        local vendor = t.linkVendor[query]
        if vendor == nil then vendor = row[3] end
        return row[1], "item:" .. id, row[2], 1, 1, "x", "y", 1, "", id, vendor, row[4], row[5],
            row[6] or 0, 0, row[7]
    end
    env.C_Item = {
        GetItemInfo = Info,
        GetItemInfoInstant = function(query)
            local id = query
            if type(query) == "string" then id = tonumber(query:match("item:(%d+)")) end
            local row = ITEMS[id]
            if not row then return id end
            return id, "t", "s", "e", id, row[4], row[5]
        end,
        GetItemCount = function(id)
            local n = 0
            for _, b in pairs(t.bags) do
                for slot = 1, b.n do
                    local s = b[slot]
                    if s and s.id == id then n = n + (s.count or 1) end
                end
            end
            return n
        end,
        RequestLoadItemDataByID = noop,
    }
    env.C_EquipmentSet = {
        GetEquipmentSetIDs = function() return { 1 } end,
        GetItemIDs = function() return t.sets end,
    }
    env.GetNumLootItems = function() return #t.loot end
    env.LootSlotHasItem = function(i) return t.loot[i] ~= nil end
    env.GetLootSlotType = function(i) return t.loot[i] and 1 or 0 end
    env.GetLootSlotLink = function(i) return t.loot[i] and ("item:" .. t.loot[i].id) end
    env.GetLootSlotInfo = function(i)
        local l = t.loot[i]
        if not l then return nil end
        return l.id, ITEMS[l.id][1], l.count or 1, nil, ITEMS[l.id][2], false, false, nil, false, false
    end

    local ns = {}
    env.NaowhForever = ns
    ns.L = function(s) return s end
    ns.Print = function(s) t.printed[#t.printed + 1] = s end
    ns.QoLSettings = S
    ns.QoLConstants = { PLAIN_BAG = 0, SELL_PRICE = 11, SECONDS_PER_DAY = 86400 }
    ns.THEME = { bg = { r = 0, g = 0, b = 0 }, fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 } }
    ns.IsLibraryBook = function(id) return t.books[id] == true end
    ns.IsBisItem = function(id) return t.bis[id] == true end
    ns.AuctionPrice = function(id)
        local quote = t.auction[id]
        if quote then return quote[1], quote[2] end
    end
    ns.AuctionAge = function() return "" end
    ns.GamepadStandDown = function() return false end
    ns.OnApply = noop
    ns.Font = widget
    ns.Button = function(_, _, _, _, onClick)
        local b = widget()
        b.click = onClick
        return b
    end
    ns.Solid = widget
    ns.Border = noop
    ns.PrimaryButton = noop
    ns.SetButtonText = function(button, text) button.text = text end
    ns.UI = { CenterPosition = function() return nil end }
    ns.Shared = {
        Parts = {
            Coins = function(c) return tostring(c) .. "c" end,
            Panel = function() local p = widget(); p.backdrop = widget(); return p end,
            ItemIcon = function() local i = widget(); i.texture = widget(); i.edge = widget(); return i end,
        },
        Style = { PANEL_W = 380, ACTION = 16, BORDER_RGB = { r = 0, g = 0, b = 0 },
            HAVE_RGB = { r = 0, g = 1, b = 0 }, RED_RGB = { r = 1, g = 0, b = 0 },
            CLOSE_IN = 4, CLOSE_SIZE = 16,
            ICON_CROP = 0.07, ICON_CROP_HIGH = 0.93 },
        Items = { OnLoaded = function(_, fn) fn() end },
    }

    for _, path in ipairs(FILES) do
        local f = assert(io.open(path, "rb"))
        local src = f:read("*a")
        f:close()
        local chunk = assert(loadstring(src, "@" .. path))
        setfenv(chunk, env)
        chunk()
    end
    t.D = ns.DestroyCheapest

    function t.Fill(slots)
        for k in pairs(t.bags) do t.bags[k] = nil end
        t.bags[0] = { n = SLOTS }
        for i = 1, SLOTS do
            local s = slots[i]
            if s then t.bags[0][i] = { id = s[1], count = s[2] or 1, link = s[3], bound = s[4] } end
        end
    end
    function t.Offered(id)
        for i = 1, #t.D.picks do
            if t.D.picks[i].itemID == id then return t.D.picks[i] end
        end
    end
    function t.Event(ev, a, b) t.D.watch:GetScript("OnEvent")(t.D.watch, ev, a, b) end
    function t.Open(lootIDs)
        for k in pairs(t.loot) do t.loot[k] = nil end
        for i, id in ipairs(lootIDs or { 50 }) do t.loot[i] = { id = id, count = 1 } end
        env.LootFrame:Show()
        t.Event("UI_ERROR_MESSAGE", 0, env.ERR_INV_FULL)
        return t.D.Opened() == true
    end
    function t.Close()
        if t.D.popup and t.D.popup:IsShown() then t.D.popup:Hide() end
        env.LootFrame:Hide()
        t.Event("LOOT_CLOSED")
        t.D.pending, t.D.armed = nil, false
    end
    function t.Bag()
        t.Event("BAG_UPDATE_DELAYED")
    end
    return t
end

-- Every protection holds with the quality switches as they are and with All Items on.
do
    local t = Fixture()
    t.quests[38], t.sets[1], t.bis[35], t.books[36] = true, 37, true, true
    t.Fill({
        { 10, 5 }, { 30 }, { 31 }, { 32, 1, nil, true }, { 33 }, { 34 }, { 35 }, { 36 }, { 37 }, { 38 },
        { FISHING_POLE }, { HEARTHSTONE }, { MINING_PICK }, { 20 }, { 21, 3 },
    })
    local protected = {
        [30] = "a quest-class item", [31] = "a quest-bound item", [32] = "bound armor",
        [33] = "an item-set piece", [34] = "a key", [35] = "a BiS item", [36] = "a library book",
        [37] = "an equipment-set item", [38] = "an item the slot marks as a quest item",
        [FISHING_POLE] = "the fishing pole", [HEARTHSTONE] = "the hearthstone", [MINING_PICK] = "a mining pick",
    }
    t.D.Scan()
    for id, what in pairs(protected) do check(t.Offered(id) == nil, what .. " is not offered") end
    check(t.Offered(10) ~= nil, "linen cloth is offered")
    check(t.Offered(21) == nil, "a zero-vendor item is not offered with All Items off")
    t.settings.destroyCheapestAll = true
    t.D.Scan()
    for id, what in pairs(protected) do check(t.Offered(id) == nil, what .. " stays protected under All Items") end
    check(t.Offered(21) ~= nil, "All Items offers a zero-vendor item")
    t.settings.destroyCheapestRare = false
    t.D.Scan()
    check(t.Offered(20) ~= nil, "All Items offers a quality that is switched off")
    t.db.destroyCheapestIgnore = { [10] = 0 }
    t.D.Scan()
    check(t.Offered(10) == nil, "an ignored item stays out under All Items")
end

-- Keep Items Worth More Than: the stack's value, skipped by All Items.
do
    local t = Fixture()
    t.Fill({ { 10, 20 }, { 11, 1 } })
    t.settings.bagCleanupMaxValue = 100
    t.D.Scan()
    check(t.Offered(10) == nil, "a stack of 20 at 10c is over a 100c limit")
    check(t.Offered(11) ~= nil, "one wool cloth at 30c is under the limit")
    t.settings.destroyCheapestAll = true
    t.D.Scan()
    check(t.Offered(10) ~= nil, "All Items skips the value limit")
end

-- Two clicks on the same button delete; a single click never does.
do
    local t = Fixture()
    t.Fill({ { 10, 5 } })
    check(t.Open(), "the popup opens on a full-bags loot")
    t.D.OnDestroy()
    check(t.D.armed and t.deleted == 0 and t.picked == 0, "the first click only arms")
    t.D.OnDestroy()
    check(t.deleted == 1, "the second click deletes")
end

-- The stack grows between the clicks: the next click arms again.
do
    local t = Fixture()
    t.Fill({ { 10, 5 } })
    t.Open()
    t.D.OnDestroy()
    t.bags[0][1].count = 8
    t.Bag()
    t.D.OnDestroy()
    check(t.deleted == 0, "a grown stack is not deleted on one click")
    check(t.D.armed and t.D.armedCount == 8, "the grown stack is armed again")
    t.D.OnDestroy()
    check(t.deleted == 1, "the second click after the re-arm deletes")
end

-- The second click re-reads the slot: a change between the clicks deletes nothing.
do
    local cases = {
        { "the link changed", function(t) t.bags[0][1].link = "item:10:5" end },
        { "the stack changed", function(t) t.bags[0][1].count = 4 end },
        { "the item was ignored", function(t) t.db.destroyCheapestIgnore = { [10] = 0 } end },
        { "its quality was switched off", function(t) t.settings.destroyCheapestCommon = false end },
        { "the value limit went below it", function(t) t.settings.bagCleanupMaxValue = 20 end },
        { "the slot became a quest item", function(t) t.quests[10] = true end },
        { "its bag is no longer a plain bag", function(t) t.family[0] = 8 end },
        { "the slot is locked", function(t) t.bags[0][1].locked = true end },
    }
    for _, case in ipairs(cases) do
        local t = Fixture()
        t.Fill({ { 10, 5 } })
        t.Open()
        t.D.OnDestroy()
        check(t.D.armed, "armed before: " .. case[1])
        case[2](t)
        t.D.OnDestroy()
        check(t.deleted == 0 and t.picked == 0, "nothing is picked up or deleted when " .. case[1])
        check(not t.D.armed, "the arm is dropped when " .. case[1])
    end
end

-- Paging the loot card, or the other button, cancels the arm.
do
    local t = Fixture()
    t.settings.destroyCheapestAnyway = true
    t.Fill({ { 10, 5 } })
    t.Open({ 50, 12 })
    check(#t.D.loots == 2, "two incoming items are read")
    t.D.OnDestroy()
    check(t.D.armed, "armed against the first incoming item")
    t.D.lootIndex = 2
    t.D.Paint()
    check(not t.D.armed, "showing another incoming item cancels the arm")
    t.D.lootIndex = 1
    t.D.Paint()
    t.D.OnDestroy()
    t.D.OnAnyway()
    check(t.deleted == 0, "Destroy Anyway does not complete an arm made with Destroy")
    check(t.D.armed and t.D.armedForced, "Destroy Anyway arms on its own")
    t.D.OnDestroy()
    check(t.deleted == 0, "Destroy does not complete an arm made with Destroy Anyway")
    t.D.OnDestroy()
    check(t.deleted == 1, "two clicks on Destroy delete")
end

-- The incoming row is replaced and re-read between the clicks.
do
    local t = Fixture()
    t.Fill({ { 10, 5 } })
    t.Open({ 50 })
    t.D.OnDestroy()
    t.loot[1] = { id = 12, count = 1 }
    t.Event("LOOT_SLOT_CLEARED")
    t.D.OnDestroy()
    check(t.deleted == 0, "a changed incoming item needs a new first click")
    t.D.OnDestroy()
    check(t.deleted == 1, "the next two clicks delete")
end

-- Paging the Destroy card cancels the arm, as before.
do
    local t = Fixture()
    t.Fill({ { 10, 5 }, { 11, 1 } })
    t.Open()
    t.D.OnDestroy()
    t.D.index = 2
    t.D.Paint()
    check(not t.D.armed, "another item to destroy cancels the arm")
    t.Close()
end

-- A variant is valued from its own link and never from the base item id.
do
    local t = Fixture()
    t.linkVendor["item:10:5"] = 3
    t.Fill({ { 10, 1, "item:10:5" } })
    t.D.Scan()
    check(t.Offered(10).vendorUnit == 3, "a variant keeps the vendor price from its own item link")
    t.missingLinks["item:10:6"] = true
    t.Fill({ { 10, 1, "item:10:6" } })
    t.D.Scan()
    check(t.Offered(10) == nil, "an unloaded variant is not priced from its base item id")
end

-- The optional filters expose only their named exception and stay off by default.
do
    local t = Fixture()
    t.Fill({ { 21, 3 }, { 32, 1, nil, true }, { 30 } })
    t.D.Scan()
    check(t.Offered(21) == nil, "zero-vendor trade goods stay protected by default")
    check(t.Offered(32) == nil, "bound gear stays protected by default")
    t.settings.destroyCheapestZeroVendor = true
    t.settings.destroyCheapestBoundGear = true
    t.D.Scan()
    check(t.Offered(21) ~= nil, "Include Zero-Vendor-Value Items offers a zero-vendor trade good")
    check(t.Offered(32) ~= nil, "Include Bound Armor and Weapons offers bound gear")
    check(t.Offered(30) == nil, "the new filters do not lift quest-item protection")
end

-- Turning an exception off after the first click keeps the item in the bag.
do
    local cases = {
        { "the zero-vendor exception", 21, "destroyCheapestZeroVendor" },
        { "the bound-gear exception", 32, "destroyCheapestBoundGear", true },
    }
    for _, case in ipairs(cases) do
        local t = Fixture()
        t.settings[case[3]] = true
        t.Fill({ { case[2], 1, nil, case[4] } })
        t.Open()
        t.D.OnDestroy()
        t.settings[case[3]] = false
        t.D.OnDestroy()
        check(t.deleted == 0 and t.picked == 0, "turning off " .. case[1] .. " cancels the delete")
    end
end

-- Worn vendor estimates use the live slot's durability and are marked as estimates.
do
    local t = Fixture()
    t.settings.destroyCheapestDurability = true
    t.durability["0:1"] = { 40, 100 }
    t.Fill({ { 40 } })
    t.D.Scan()
    local pick = t.Offered(40)
    check(pick and pick.vendorUnit == 40 and pick.value == 40,
        "Estimate Worn Vendor Price lowers the offer by remaining durability")
    check(pick.vendorEstimated == true and t.D.PriceCells(pick).vendorLabel == t.D.TEXT.VENDOR_EST_TAG,
        "a worn vendor price is labelled as an estimate")
    t.Open()
    t.D.OnDestroy()
    t.durability["0:1"] = { 20, 100 }
    t.D.OnDestroy()
    check(t.deleted == 0 and t.picked == 0, "a changed worn-value estimate cancels the delete")
end

-- Rank Quantity changes ordering, while Keep Items Worth More Than still uses the stack value.
do
    local t = Fixture()
    t.Fill({ { 10, 20 }, { 11, 1 } })
    t.D.Scan()
    check(t.D.picks[1].itemID == 11, "Batch ranks a 30c item below a 200c stack")
    t.settings.destroyCheapestRankQty = "unit"
    t.D.Scan()
    check(t.D.picks[1].itemID == 10, "Individual ranks a 10c unit below a 30c unit")
    t.settings.bagCleanupMaxValue = 100
    t.D.Scan()
    check(t.Offered(10) == nil, "the value cap still compares the 200c stack under Individual ranking")
end

-- A zero-vendor offer with an auction estimate never takes the main destroy path.
do
    local t = Fixture()
    t.settings.destroyCheapestMarket = true
    t.auction[21] = { 100, 1000 }
    t.settings.destroyCheapestZeroVendor = true
    t.Fill({ { 21 } })
    t.Open({ 10 })
    check(t.D.WorthIt(t.D.picks[1], t.D.loots[1]) == false,
        "an auction-valued zero-vendor item requires Destroy Anyway")
end

-- The cards keep unit and stack prices separate, and the comparison uses each side's count.
do
    local t = Fixture()
    t.settings.destroyCheapestMarket = true
    t.auction[10], t.auction[50] = { 40, 1000 }, { 2500, 1000 }
    t.Fill({ { 10, 5 } })
    t.Open({ 50 })
    local pick, loot = t.D.picks[1], t.D.loots[1]
    local pickCells = t.D.PriceCells(pick)
    check(pickCells.vendorEach == "10c" and pickCells.vendorStack == "50c",
        "the Destroy card shows vendor prices for one item and the stack")
    check(pickCells.ahEach == "40c" and pickCells.ahStack == "200c",
        "the Destroy card shows auction prices for one item and the stack")
    local lootCells = t.D.PriceCells(loot)
    check(lootCells.vendorEach == "2000c" and lootCells.vendorStack == nil,
        "the Incoming card shows one price for a single item")
    local gaps = t.D.CompareGaps(pick, loot)
    check(gaps.columns == t.D.STACK_COLUMNS and gaps.stackLabel == t.D.TEXT.COL_TOTAL,
        "the comparison adds a total column when only the Destroy side is a stack")
    check(gaps.vendorEach == 1990 and gaps.vendorStack == 1950,
        "the vendor comparison reports the individual and total profit")
    check(gaps.ahEach == 2460 and gaps.ahStack == 2300,
        "the auction comparison reports the individual and total profit")
    check(t.D.SignedCoin(-25) == "-25c" and t.D.GapTone(-25) == "bad",
        "a deficit has a signed price and the deficit tone")
end

-- An old market scan stays visible but muted when it is excluded from comparisons.
do
    local t = Fixture()
    t.settings.destroyCheapestMarket = true
    t.settings.destroyCheapestMarketStale = true
    t.auction[10] = { 40, -700000 }
    t.Fill({ { 10 } })
    t.D.Scan()
    local cells = t.D.PriceCells(t.D.picks[1])
    check(cells.ahEach == "40c" and cells.ahTone == "muted",
        "a stale auction estimate is still shown muted")
end

print(("test-destroy-cheapest: %d checks passed"):format(checks))
