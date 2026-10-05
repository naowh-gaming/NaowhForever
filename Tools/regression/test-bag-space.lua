-- Loads NaowhForever_BagSpace.lua, after the Shared files it draws with, against stubbed bag,
-- item and frame APIs and checks what the row offers, what the clicks do, stacking, the card's
-- look (header, shared marks and coins, no outline, colors by state), its settings preview,
-- and what a scan costs.
-- Run from the repo root: lua Tools/regression/test-bag-space.lua
local f = assert(io.open(arg[1] or "QoL/NaowhForever_BagSpace.lua", "rb"))
local source = f:read("*a"); f:close()
local SHARED = { "Shared/Shared.lua", "Shared/Style.lua", "Shared/Parts.lua" }

-- itemID -> name, quality, required level, max stack, vendor price, class
local ITEMS = {
    [1] = { "Small Egg", 1, 0, 20, 4, 7 },
    [2] = { "Coyote Meat", 1, 0, 20, 3, 7 },
    [3] = { "Light Feather", 1, 0, 20, 41, 7 },
    [4] = { "Chipped Boar Tusk", 0, 0, 5, 38, 15 },
    [5] = { "Flash Powder", 1, 0, 20, 1, 5 },          -- reagent: protected
    [6] = { "Quest Letter", 1, 0, 1, 1, 12 },          -- quest: protected
    [7] = { "Hearthstone", 1, 0, 1, 0, 15 },           -- no vendor price: never offered
    [8] = { "Blue Ring", 3, 0, 1, 900, 4 },            -- rare: above the quality limit
    [9] = { "Tough Jerky", 1, 5, 20, 1, 0 },           -- food ten or more levels below: old
    [10] = { "Linen Cloth", 1, 0, 20, 13, 7 },
    [11] = { "Green Belt", 2, 0, 1, 50, 4 },
}

local WHITE = { r = 1, g = 1, b = 1, hex = "|cffffffff" }
local HEX = { accent = "0091ed", muted = "9a9ea6", fg = "f0f1f3", accentSoft = "4db5f5" }
-- The game's coin string, stubbed: what Parts.Coins caches, so prices can be traced to it.
local function CoinString(copper) return "<" .. copper .. ">" end

local function Fixture(opts)
    local settings = opts.settings or {}
    local defaults = {
        enabled = true, bagSpace = true, bagSpaceCount = 4, bagSpaceSize = 36,
        bagSpaceGrow = "RIGHT", bagSpaceMaxQuality = 2, bagSpaceJunkFirst = false,
        bagSpaceAuction = true, bagSpaceProtect = true, bagSpaceFreeBelow = 0,
        bagSpaceHideCombat = true, bagSpaceOnFull = true, bagSpaceShowFree = true,
        bagSpaceStack = true, bagSpaceOldFirst = false, bagSpacePrices = true,
        bagSpaceTipVendor = true, bagSpaceTipAuction = true, bagSpaceTipDelete = true, bagSpaceTipIgnore = true,
    }
    local db, printed, buttons = {}, {}, {}
    local made = 0                         -- frames made, all told
    local bags = opts.bags                 -- bags[bag][slot] = { id, count } or nil
    local cursor, ctrl, now = nil, false, 1000
    local registered = {}
    local infoCache = {}                   -- one table per slot, as reused as the real API allows

    local S = {}
    function S.Get(k) if settings[k] ~= nil then return settings[k] end return defaults[k] end
    function S.Set(k, v) settings[k] = v end
    function S.DB() return db end

    -- Methods are made once and shared, so the stubs add no garbage to the cost measured below.
    local function Noop() end
    -- Any method a stub lacks does nothing; a field never set is nil, as on a real frame.
    local noopMeta = { __index = function(_, k) if type(k) == "string" and k:find("^%u") then return Noop end end }
    local function Stub() return setmetatable({}, noopMeta) end
    local Widget
    local methods = setmetatable({
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, v) self.shown = v and true or false end,
        IsShown = function(self) return self.shown end,
        SetText = function(self, v) self.text = v end,
        SetTextColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end,
        SetShadowOffset = function(self, x, y) self.shadowX, self.shadowY = x, y end,
        SetSize = function(self, w, h) self.w, self.h = w, h end,
        SetWidth = function(self, w) self.w = w end,
        SetHeight = function(self, h) self.h = h end,
        GetWidth = function(self) return self.w or 0 end,
        GetHeight = function(self) return self.h or 0 end,
        SetPoint = function(self, point, _, _, x, y) self.point, self.x, self.y = point, x, y end,
        SetScale = function(self, s) self.scale = s end,
        GetFrameLevel = function() return 1 end,
        GetStringWidth = function() return 20 end,
        SetTexture = function(self, v) self.texture = v end,
        SetScript = function(self, name, fn) self[name] = fn end,
        CreateTexture = function() return Widget("region") end,
        CreateFontString = function() return Widget("region") end,
        RegisterEvent = function(self, e) registered[e] = registered[e] or {}; registered[e][self] = true end,
        UnregisterEvent = function(self, e) if registered[e] then registered[e][self] = nil end end,
        UnregisterAllEvents = function(self) for _, set in pairs(registered) do set[self] = nil end end,
    }, noopMeta)
    local widgetMeta = { __index = methods }
    function Widget(kind)
        made = made + 1
        return setmetatable({ kind = kind, shown = true }, widgetMeta)
    end
    local border = { SetColor = Noop }
    local cards = {}

    local ns = {
        Color = function(token, text) return "|cff" .. HEX[token] .. (text and (text .. "|r") or "") end,
        THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
            fg = { r = 0.94, g = 0.95, b = 0.95 }, bg = { r = 0.05, g = 0.06, b = 0.07 },
            line = { r = 0.18, g = 0.19, b = 0.21 }, accentSoft = { r = 0.3, g = 0.71, b = 0.96 } },
        QoLSettings = S,
        Print = function(msg) printed[#printed + 1] = msg end,
        Apply = function() end,
        ShowRaidReminderAnchorConfig = function() end,
        HideRaidReminderAnchorConfig = function() end,
        IsBisItem = function(id) return opts.bis and opts.bis[id] end,
        AuctionPrice = function(id) return opts.ah and opts.ah[id] end,
        ScrapMarker = opts.scrap,
        Font = function(_, size, flags, color)
            local w = Widget("font")
            w.size, w.flags, w.color = size, flags, color
            return w
        end,
        Solid = function() return Widget("texture") end,
        PixelInset = function(region) return region end,
        Border = function() return border end,
        -- ns.Button, keeping its label and click so the Stack button can be read and pressed.
        Button = function(_, text, _, _, onClick)
            local w = Widget("button")
            w.label, w._onClick = Widget("font"), onClick
            w.label.text = text
            return w
        end,
        SetButtonText = function(button, text) button.label.text = text end,
        AccentBorder = function(frame) return frame end,
        Confirm = function(_, onYes) onYes() end,
        UI = { AttachMover = function() return Widget("mover") end },
    }

    local function Item(bag, slot) return bags[bag] and bags[bag][slot] end
    local function Info(bag, slot)
        local it = Item(bag, slot)
        if not it then return nil end
        local key = bag * 100 + slot
        local t = infoCache[key] or {}
        infoCache[key] = t
        local def = ITEMS[it.id]
        t.itemID, t.stackCount, t.quality, t.iconFileID = it.id, it.count, def[2], it.id
        t.hyperlink, t.isLocked = "[" .. def[1] .. "]", false
        return t
    end
    local function Place(bag, slot)
        local it = Item(bag, slot)
        if not it then
            bags[bag][slot] = cursor
            cursor = nil
        elseif it.id == cursor.id then
            local room = ITEMS[it.id][4] - it.count
            local moved = math.min(room, cursor.count)
            it.count = it.count + moved
            cursor.count = cursor.count - moved
            if cursor.count == 0 then cursor = nil end
        else
            bags[bag][slot], cursor = cursor, it
        end
    end

    local env = {
        BACKPACK_CONTAINER = 0, NUM_BAG_SLOTS = #bags,
        ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return WHITE end }),
        ERR_INV_FULL = "Inventory is full.", ERR_BAG_FULL = "That bag is full.",
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        time = function() return now end,
        GetTime = function() return now end,
        UnitLevel = function() return opts.level or 20 end,
        UnitAffectingCombat = function() return false end,
        InCombatLockdown = function() return false end,
        IsControlKeyDown = function() return ctrl end,
        IsModifiedClick = function() return false end,
        GameTooltip = Stub(),
        GameTooltip_Hide = function() end,
        C_Timer = { After = function(_, fn) fn() end },
        C_Container = {
            GetContainerNumSlots = function(bag) return bags[bag] and bags[bag].size or 0 end,
            GetContainerNumFreeSlots = function(bag)
                local n = 0
                for slot = 1, bags[bag].size do if not bags[bag][slot] then n = n + 1 end end
                return n, 0
            end,
            GetContainerItemInfo = Info,
            PickupContainerItem = function(bag, slot)
                if cursor then return Place(bag, slot) end
                cursor, bags[bag][slot] = bags[bag][slot], nil
            end,
            SplitContainerItem = function(bag, slot, amount)
                local it = bags[bag][slot]
                it.count = it.count - amount
                cursor = { id = it.id, count = amount }
            end,
            UseContainerItem = function(bag, slot) bags[bag][slot] = nil end,
        },
        C_Item = {
            GetItemInfo = function(id)
                local d = ITEMS[id]
                return d[1], nil, d[2], nil, d[3], nil, nil, d[4], nil, nil, d[5]
            end,
            GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, ITEMS[id][6] end,
        },
        C_QuestLog = {
            GetNumQuestLogEntries = function() return opts.quests and #opts.quests or 0 end,
            GetInfo = function(i) return { questID = i, title = opts.quests[i].title, isHeader = false } end,
            GetQuestObjectives = function(id) return opts.quests[id].objectives end,
        },
        C_CurrencyInfo = { GetCoinTextureString = CoinString },
        CreateColor = function() return WHITE end,
        GetCursorInfo = function() if cursor then return "item", cursor.id end end,
        ClearCursor = function() cursor = nil end,
        DeleteCursorItem = function() cursor = nil end,
        CreateFrame = function(kind, name)
            local w = Widget(kind)
            if kind == "Button" then buttons[#buttons + 1] = w end
            if name == "NaowhForeverBagSpace" then buttons.row = w end
            return w
        end,
        hooksecurefunc = function(tbl, key, fn)
            local orig = tbl[key]
            tbl[key] = function(...) orig(...); fn(...) end
        end,
    }
    env._G = { NaowhForever = ns }
    setmetatable(env, { __index = _G })
    for _, path in ipairs(SHARED) do
        local shared = assert(loadfile(path))
        setfenv(shared, env)
        shared()
    end
    local Parts = ns.Shared.Parts
    -- Every corner tag the shared part makes, so the row's OLD and "!" can be traced to it.
    local tags, ItemTag = {}, Parts.ItemTag
    function Parts.ItemTag(...)
        local tag = ItemTag(...)
        tags[tag] = true
        return tag
    end
    if opts.studio then
        ns.Shared.Settings = {
            Group = function(name) return { group = name } end,
            Page = function() return { Card = function(_, card) cards[card.id] = card end } end,
        }
    end
    local chunk = assert(loadstring(source)); setfenv(chunk, env)
    chunk()

    local t = { ns = ns, printed = printed, env = env, buttons = buttons, Parts = Parts, tags = tags,
        Style = ns.Shared.Style, cards = cards, settings = settings }
    function t.Made() return made end
    function t.Fire(event, ...)
        for frame in pairs(registered[event] or {}) do frame.OnEvent(frame, event, ...) end
    end
    -- What the row shows, left to right: "Stack" for the header's Stack button, then item names.
    function t.Row()
        local out = {}
        if not (buttons.row and buttons.row.shown) then return "" end
        if buttons.row.stack.shown then out[1] = "Stack" end
        for _, b in ipairs(buttons) do
            if b.shown and b.pick then
                out[#out + 1] = b.pick.stack and "Stack" or ITEMS[b.pick.itemID][1]
            end
        end
        return table.concat(out, ", ")
    end
    function t.FreeText()
        return buttons.row and buttons.row.free and buttons.row.free.text.text
    end
    -- Scrap Marker's "+N" beside the count, nil while hidden.
    function t.ScrapText()
        local scrap = buttons.row.free.scrap
        return scrap.shown and scrap.text or nil
    end
    function t.ClickStack()
        buttons.row.stack._onClick()
    end
    function t.Button(i)
        local n = 0
        for _, b in ipairs(buttons) do
            if b.shown and b.pick then
                n = n + 1
                if n == i then return b end
            end
        end
    end
    function t.Click(i, mouse, withCtrl)
        ctrl = withCtrl or false
        local b = t.Button(i)
        b.OnClick(b, mouse or "LeftButton")
        ctrl = false
    end
    function t.Count(id)
        local n = 0
        for bag = 0, #bags do
            for slot = 1, bags[bag].size do
                local it = bags[bag][slot]
                if it and it.id == id then n = n + it.count end
            end
        end
        return n
    end
    function t.Slots(id)
        local n = 0
        for bag = 0, #bags do
            for slot = 1, bags[bag].size do
                if bags[bag][slot] and bags[bag][slot].id == id then n = n + 1 end
            end
        end
        return n
    end
    t.db, t.Set = db, S.Set
    -- The world loads: the module builds and scans.
    for frame in pairs(registered.PLAYER_LOGIN or {}) do frame.OnEvent(frame, "PLAYER_LOGIN") end
    return t
end

local failures = 0
local function Check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(label, tostring(got), tostring(want)))
    end
end

local function Bag(size, items)
    local bag = { size = size }
    for slot, it in pairs(items) do bag[slot] = { id = it[1], count = it[2] } end
    return bag
end

-- Cheapest stack first; protected, priceless and too-good items never offered.
do
    local t = Fixture({ bags = { [0] = Bag(16, {
        { 3, 2 }, { 1, 3 }, { 2, 11 }, { 4, 2 }, { 5, 10 }, { 6, 1 }, { 7, 1 }, { 8, 1 },
    }) } })
    Check("cheapest stack first", t.Row(), "Small Egg, Coyote Meat, Chipped Boar Tusk, Light Feather")
    Check("counter reads free out of total", t.FreeText(), "8/16")
end

-- Scrap Marker's scrap goes first, even above the quality limit, and the counter shows the
-- slots it frees at the next vendor; with Scrap Marker off, nothing changes.
do
    local scrap = { on = true, ids = { [3] = true, [8] = true } }
    scrap.On = function() return scrap.on end
    scrap.IsScrap = function(id) return scrap.on and scrap.ids[id] == true end
    local t = Fixture({ scrap = scrap, bags = { [0] = Bag(16, { { 3, 2 }, { 1, 3 }, { 4, 2 }, { 8, 1 } }) } })
    Check("scrap first", t.Row(), "Light Feather, Blue Ring, Small Egg, Chipped Boar Tusk")
    Check("header: free out of total", t.FreeText(), "12/16")
    Check("header: slots scrap frees", t.ScrapText(), "+2")
    scrap.on = false
    t.ns.BagSpaceRescan()
    Check("Scrap Marker off: the usual order", t.Row(), "Small Egg, Chipped Boar Tusk, Light Feather")
    Check("Scrap Marker off: the usual counter", t.FreeText(), "12/16")
    Check("Scrap Marker off: no +N", t.ScrapText(), nil)
end

-- Grey Items First puts the tusk ahead of everything.
do
    local t = Fixture({ settings = { bagSpaceJunkFirst = true },
        bags = { [0] = Bag(16, { { 3, 2 }, { 1, 3 }, { 4, 2 } }) } })
    Check("grey first", t.Row(), "Chipped Boar Tusk, Small Egg, Light Feather")
end

-- An auction price above the vendor price values the stack at the auction price.
do
    local t = Fixture({ ah = { [1] = 500 }, bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) } })
    Check("auction value counts", t.Row(), "Coyote Meat, Small Egg")
end

-- BiS items are protected; outlevelled food is marked old and can go first.
do
    local t = Fixture({ bis = { [2] = true }, settings = { bagSpaceOldFirst = true },
        bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 }, { 9, 20 } }) } })
    Check("BiS protected, old food first", t.Row(), "Tough Jerky, Small Egg")
    Check("old flag", t.Button(1).pick.old, true)
end

-- Ctrl-click deletes; middle-click ignores with the time it happened.
do
    local t = Fixture({ bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) } })
    t.Click(1, "LeftButton", true)
    t.Fire("BAG_UPDATE_DELAYED")
    Check("ctrl-click deleted the eggs", t.Count(1), 0)
    Check("deleted message", t.printed[#t.printed]:find("^deleted") ~= nil, true)
    t.Click(1, "MiddleButton")
    Check("middle-click ignores with a time", type(t.db.bagSpaceIgnore[2]), "number")
    Check("ignored item leaves the row", t.Row(), "")
end

-- An unfinished quest objective flags its item, puts it last and asks for a second Ctrl-click;
-- a finished objective, or a count-first objective text, is read the same way.
do
    local t = Fixture({
        quests = {
            { title = "Westfall Stew", objectives = {
                { type = "item", text = "Small Egg: 1/3", finished = false, numFulfilled = 1, numRequired = 3 },
                { type = "item", text = "Coyote Meat: 5/5", finished = true, numFulfilled = 5, numRequired = 5 },
            } },
            { title = "Linen Trouble", objectives = {
                { type = "item", text = "2/6 Linen Cloth", finished = false, numFulfilled = 2, numRequired = 6 },
            } },
        },
        bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 }, { 10, 1 } }) },
    })
    Check("quest items go last", t.Row(), "Coyote Meat, Small Egg, Linen Cloth")
    Check("badge on a quest item", t.Button(2).quest.shown, true)
    Check("no badge on a finished objective", t.Button(1).quest.shown, false)
    t.Click(2, "LeftButton", true)
    Check("first ctrl-click only warns", t.Count(1), 3)
    Check("warning names the quest", t.printed[#t.printed]:find("Westfall Stew %(1/3%)") ~= nil, true)
    t.Click(2, "LeftButton", true)
    t.Fire("BAG_UPDATE_DELAYED")
    Check("second ctrl-click deletes", t.Count(1), 0)
end

-- Uncommon and better only go on the cursor, so the game's own delete confirmation applies.
do
    local t = Fixture({ bags = { [0] = Bag(16, { { 11, 1 } }) } })
    t.Click(1, "LeftButton", true)
    Check("uncommon is picked up, not deleted", select(2, t.env.GetCursorInfo()), 11)
    Check("ground hint", t.printed[#t.printed]:find("is on your cursor") ~= nil, true)
end

-- Unlock Mode shows your own items where you have them, and the sample question mark only in
-- the slots left over, with your real free-slot count.
do
    local bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) }
    local t = Fixture({ bags = bags })
    local free = t.FreeText()
    t.ns.ShowRaidReminderAnchorConfig()
    local icons = {}
    for _, b in ipairs(t.buttons) do
        if b.shown and b.icon then icons[#icons + 1] = b.icon.texture end
    end
    Check("unlock: four slots shown", #icons, 4)
    Check("unlock: your items first", type(icons[1]) == "number" and type(icons[2]) == "number", true)
    Check("unlock: a sample only where you have no item",
        icons[3] == "Interface\\Icons\\INV_Misc_QuestionMark" and icons[4] == icons[3], true)
    Check("unlock: your real free slots", t.FreeText(), free)
end

-- The key binding redraws the row from the scan it acts on, so icons match their items.
do
    local bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 }, { 3, 2 } }) }
    local t = Fixture({ bags = bags })
    bags[0][1] = nil   -- the eggs are gone, with no bag event yet
    t.env.NaowhForever_BagSpacePickUp()
    Check("binding picks up the cheapest", select(2, t.env.GetCursorInfo()), 2)
    for i = 1, 2 do
        local b = t.Button(i)
        Check("icon " .. i .. " matches its item", b.icon.texture, b.pick.itemID)
    end
end

-- Stacking starts from a fresh scan: a stack moved by hand since the row was drawn is found
-- where it is now, and the item put in its old slot stays put.
do
    local bags = { [0] = Bag(16, { { 1, 3 }, { 1, 5 }, { 2, 11 } }) }
    local t = Fixture({ bags = bags })
    bags[0][4], bags[0][1] = bags[0][1], { id = 10, count = 3 }
    t.ClickStack()
    for _ = 1, 5 do t.Fire("BAG_UPDATE_DELAYED") end
    Check("linen left alone", bags[0][1] and bags[0][1].id, 10)
    Check("moved eggs merged", t.Slots(1), 1)
    Check("no moved eggs lost", t.Count(1), 8)
end

-- Two part-filled egg stacks: a Stack button that merges them into one slot.
do
    local t = Fixture({ bags = { [0] = Bag(16, { { 1, 3 }, { 1, 5 }, { 2, 11 } }) } })
    Check("stack button first", t.Row():match("^[^,]+"), "Stack")
    Check("stack button says what it frees", t.buttons.row.stack.label.text, "Stack +1")
    t.ClickStack()
    for _ = 1, 5 do t.Fire("BAG_UPDATE_DELAYED") end
    Check("eggs merged into one slot", t.Slots(1), 1)
    Check("no eggs lost", t.Count(1), 8)
    Check("stack message", t.printed[#t.printed], "stacked your bags: 1 slot freed.")
end

-- A threshold hides the row until an "Inventory is full" error brings it up.
do
    local t = Fixture({ settings = { bagSpaceFreeBelow = 3 },
        bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) } })
    Check("hidden with room to spare", t.Row(), "")
    t.Fire("UI_ERROR_MESSAGE", 0, "Inventory is full.")
    Check("shown after inventory full", t.Row(), "Small Egg, Coyote Meat")
end

-- The card's look: OLD and the quest "!" are the shared corner tags in their Style colors, the
-- stack count is the shared marks' number, prices are the shared compact coins, the text has
-- the house shadow and no outline, and the free count is colored by how full the bags are.
do
    local t = Fixture({
        settings = { bagSpaceOldFirst = true },
        quests = { { title = "Linen Trouble", objectives = {
            { type = "item", text = "2/6 Linen Cloth", finished = false, numFulfilled = 2, numRequired = 6 },
        } } },
        bags = { [0] = Bag(16, { { 9, 20 }, { 1, 3 }, { 10, 1 } }) },
    })
    local St, Parts, T = t.Style, t.Parts, t.ns.THEME
    Check("look: the order", t.Row(), "Tough Jerky, Small Egg, Linen Cloth")
    local old, egg, quest = t.Button(1), t.Button(2), t.Button(3)
    Check("look: OLD is a shared tag", t.tags[old.old] and old.old.shown, true)
    Check("look: OLD's word", old.old.text.text, "OLD")
    Check("look: OLD in the warning color", old.old.text.color, St.WARN_RGB)
    Check("look: no OLD on fresh food", egg.old.shown, false)
    Check("look: the quest mark is a shared tag", t.tags[quest.quest] and quest.quest.shown, true)
    Check("look: the quest mark's sign", quest.quest.text.text, "!")
    Check("look: the quest mark in quest gold", quest.quest.text.color, St.CARRIED_RGB)
    Check("look: stack count in the shared marks", old.marks.level.text, 20)
    Check("look: no count on a single item", quest.marks.level.text, "")
    Check("look: price from the shared coins", old.price.text, Parts.Coins(20, true))
    Check("look: the coins are the game's", old.price.text, CoinString(20))
    Check("look: compact coins keep the two largest", Parts.Coins(12345, true), CoinString(12300))
    Check("look: prices muted", old.price.color, T.muted)
    Check("look: no own money formatter", source:find("Money(", 1, true), nil)
    local free = t.buttons.row.free
    for _, text in ipairs({ old.price, free.text, free.word, free.scrap }) do
        Check("look: no outline", text.flags, nil)
        Check("look: the house shadow", text.shadowX == St.HUD_SHADOW_X and text.shadowY == St.HUD_SHADOW_Y, true)
    end
    Check("look: room to spare in the text color", free.text.r, T.fg.r)
    -- Three cells 44 wide (a 36 icon, widened for its price), 6 apart, inside the card's padding.
    Check("look: the card wraps the row", t.buttons.row.card.w, 3 * 44 + 2 * 6 + 2 * 6)
    t.Set("bagSpacePrices", false)
    Check("look: Show Prices off", old.price.shown, false)
    t.Set("bagSpaceGrow", "DOWN")
    Check("look: down, one under another", egg.x == 0 and egg.y < 0, true)
end

-- Few slots free: the count turns orange; none: red.
do
    local function Filled(n)
        local items = {}
        for slot = 1, n do items[slot] = { 1, 1 } end
        return Fixture({ bags = { [0] = Bag(16, items) } })
    end
    local low, full = Filled(15), Filled(16)
    Check("low: one free", low.FreeText(), "1/16")
    Check("low: orange", low.buttons.row.free.text.r, low.Style.WARN_RGB.r)
    Check("full: none free", full.FreeText(), "0/16")
    Check("full: red", full.buttons.row.free.text.r, full.Style.RED_RGB.r)
end

-- The settings card's preview: nothing built until the card opens (and nothing at all while Bag
-- Space is off), then the same card from the addon's samples, following Items Shown, Highest
-- Quality Offered, Icon Size, Direction, the sort settings, Offer to Stack and Show Free Slots,
-- with Low and Full states, a hover that acts on nothing, and no garbage per paint.
do
    local t = Fixture({ studio = true, settings = { bagSpace = false }, bags = { [0] = Bag(16, { { 1, 3 } }) } })
    local studio = t.cards.bagSpace and t.cards.bagSpace.studio
    Check("studio: declared on the card", studio ~= nil, true)
    Check("studio: no card while Bag Space is off", t.buttons.row, nil)
    local before = t.Made()
    local stage = t.env.CreateFrame("Frame")
    local preview = studio.new(stage)
    Check("studio: built when the card opens", t.Made() > before + 1, true)
    preview.w, preview.h = 500, studio.height
    local view = preview.view
    local function Names()
        local out = {}
        for _, b in ipairs(view.cells) do
            if b.shown then out[#out + 1] = b.pick.name end
        end
        return table.concat(out, ", ")
    end
    studio.paint(preview, "bags")
    Check("studio: cheapest first, the quest item last", Names(),
        "Worn Leather Pants, Ruined Pelt, Tough Jerky, Linen Cloth")
    Check("studio: the free count", view.free.text.text, "28/52")
    Check("studio: Scrap Marker's +N", view.free.scrap.text, "+2")
    Check("studio: the Stack button", view.stack.shown, true)
    Check("studio: OLD on the jerky", view.cells[3].old.shown, true)
    Check("studio: the quest mark on the linen", view.cells[4].quest.shown, true)
    Check("studio: prices from the shared coins", view.cells[1].price.text, t.Parts.Coins(150, true))
    local made = t.Made()
    studio.paint(preview, "bags")
    Check("studio: a repaint makes no frames", t.Made(), made)
    t.Set("bagSpaceCount", 2)
    studio.paint(preview, "bags")
    Check("studio: Items Shown", Names(), "Worn Leather Pants, Ruined Pelt")
    t.Set("bagSpaceCount", 8)
    t.Set("bagSpaceMaxQuality", 0)
    studio.paint(preview, "bags")
    Check("studio: Highest Quality Offered", Names(), "Ruined Pelt")
    t.Set("bagSpaceMaxQuality", 3)
    t.Set("bagSpaceJunkFirst", true)
    studio.paint(preview, "bags")
    Check("studio: Grey Items First", Names(), "Ruined Pelt, Worn Leather Pants, Tough Jerky, Jade Ring, Linen Cloth")
    t.Set("bagSpaceJunkFirst", false)
    t.Set("bagSpaceOldFirst", true)
    studio.paint(preview, "bags")
    Check("studio: Outlevelled First", Names():match("^[^,]+"), "Tough Jerky")
    t.Set("bagSpaceSize", 48)
    t.Set("bagSpaceGrow", "UP")
    studio.paint(preview, "bags")
    Check("studio: Icon Size", view.cells[1].w, 48)
    Check("studio: Direction", view.cells[2].x == 0 and view.cells[2].y > 0, true)
    Check("studio: shrunk to fit the stage", view.scale < 1, true)
    t.Set("bagSpaceStack", false)
    studio.paint(preview, "bags")
    Check("studio: Offer to Stack off", view.stack.shown, false)
    studio.paint(preview, "low")
    Check("studio: Low", view.free.text.text, "4/52")
    Check("studio: Low in orange", view.free.text.r, t.Style.WARN_RGB.r)
    studio.paint(preview, "full")
    Check("studio: Full", view.free.text.text, "0/52")
    Check("studio: Full in red", view.free.text.r, t.Style.RED_RGB.r)
    Check("studio: Low and Full need the free count", studio.states[2].needs == "bagSpaceShowFree"
        and studio.states[3].needs == "bagSpaceShowFree", true)
    t.Set("bagSpaceShowFree", false)
    studio.paint(preview, "bags")
    Check("studio: Show Free Slots off", view.free.shown, false)
    view.cells[1].OnEnter(view.cells[1])
    Check("studio: a sample only shows a tooltip", rawget(view.cells[1], "OnClick"), nil)
    for _ = 1, 20 do studio.paint(preview, "bags") end
    collectgarbage("collect")
    collectgarbage("stop")
    local kb = collectgarbage("count")
    for _ = 1, 500 do studio.paint(preview, "full") end
    local grown = collectgarbage("count") - kb
    collectgarbage("restart")
    Check("studio: no garbage per paint", grown / 500 < 0.05, true)
end

-- Cost: a full set of bags, scanned the way loot triggers it.
do
    local bags = { [0] = Bag(16, {}) }
    for b = 1, 4 do bags[b] = Bag(20, {}) end
    local n = 0
    for b = 0, 4 do
        for slot = 1, bags[b].size do
            n = n + 1
            local id = n % 10 + 1
            bags[b][slot] = { id = id, count = math.max(1, (n * 7) % ITEMS[id][4]) }
        end
    end
    local t = Fixture({ bags = bags })
    local SCANS = 2000
    for _ = 1, 50 do t.Fire("BAG_UPDATE_DELAYED") end   -- warm the pools
    collectgarbage("collect")
    collectgarbage("stop")
    local before, start = collectgarbage("count"), os.clock()
    for _ = 1, SCANS do t.Fire("BAG_UPDATE_DELAYED") end
    local elapsed, grown = os.clock() - start, collectgarbage("count") - before
    collectgarbage("restart")
    print(("bag space: %d slots, %.3f ms and %.2f KB per scan and redraw")
        :format(96, elapsed * 1000 / SCANS, grown / SCANS))
    Check("under 1 ms per scan", elapsed * 1000 / SCANS < 1, true)
    -- Pooled: once warm, a scan leaves nothing for the garbage collector.
    Check("no garbage per scan", grown / SCANS < 0.05, true)
end

-- Shift-click links through ChatFrameUtil: ChatEdit_InsertLink is a deprecated shim Forever
-- does not load, so a call to it does nothing there.
local deprecated = false
for line in source:gmatch("[^\n]+") do
    if not line:match("^%s*%-%-") and line:find("ChatEdit_", 1, true) then deprecated = true end
end
Check("no deprecated ChatEdit_ calls", deprecated, false)
Check("Shift-click links through ChatFrameUtil",
    source:find("ChatFrameUtil.InsertLink(p.link)", 1, true) ~= nil, true)

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("test-bag-space: all passed")
