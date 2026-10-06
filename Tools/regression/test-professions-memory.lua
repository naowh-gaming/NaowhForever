-- Loads the Professions module's window, recipe finder, favourites and shopping list against
-- stubbed game APIs, opens the window beside the auction house, and drives what runs while it
-- is open: item data loading (the auction house's own lists load hundreds), an item that never
-- loads, bag updates, scrolling and redraws. It checks that unrelated item loads and failed
-- loads do not redraw anything, what each path costs in time and garbage, and that repeating
-- them does not grow retained memory. Run from the repo root (a folder argument loads the
-- module from there instead, to measure an older copy):
--   lua Tools/regression/test-professions-memory.lua
local DIR = arg and arg[1] or "NaowhForever_Professions"
local Load = dofile("Tools/regression/load_files.lua")

local checks, failures = 0, {}
local function check(label, value)
    checks = checks + 1
    if not value then failures[#failures + 1] = label end
end

local function Noop() end
local EMPTY = {}

-- A runaway loop fails the test instead of hanging it.
local DEADLINE = os.clock() + 60
debug.sethook(function()
    if os.clock() > DEADLINE then error("test-professions-memory: still running after 60 s") end
end, "", 1000000)

-------------------------------------------------------------------------------
--  Time, timers and events
-------------------------------------------------------------------------------
local FRAME = 1 / 60
local now = 1000
-- Timers in parallel arrays, so scheduling one makes no garbage once the arrays have grown.
local timerFn, timerAt, timerCount = {}, {}, 0
-- Item loads answered on the next frame: itemID and whether it loaded.
local loadID, loadOK, loadCount = {}, {}, 0
local registry = {}     -- event -> { frame -> true }
local calls = setmetatable({}, { __index = function() return 0 end })
local function Count(name) calls[name] = calls[name] + 1 end

local function Fire(event, ...)
    local set = registry[event]
    if not set then return end
    for frame in pairs(set) do
        local fn = frame.scripts and frame.scripts.OnEvent
        if fn then fn(frame, event, ...) end
    end
end

local function RunTimers()
    local n, kept = timerCount, 0
    for i = 1, n do
        if timerAt[i] <= now then
            timerFn[i]()
        else
            kept = kept + 1
            timerFn[kept], timerAt[kept] = timerFn[i], timerAt[i]
        end
    end
    -- Timers scheduled while these ran sit after n; move them down behind the kept ones.
    for i = n + 1, timerCount do
        kept = kept + 1
        timerFn[kept], timerAt[kept] = timerFn[i], timerAt[i]
    end
    for i = kept + 1, timerCount do timerFn[i], timerAt[i] = nil, nil end
    timerCount = kept
end

-- One frame: the item loads asked for last frame answer, then the timers due run. Loads asked
-- for while those answer wait for the next frame.
local answerID, answerOK = {}, {}
local function Step()
    now = now + FRAME
    local n = loadCount
    for i = 1, n do answerID[i], answerOK[i] = loadID[i], loadOK[i] end
    loadCount = 0
    for i = 1, n do Fire("ITEM_DATA_LOAD_RESULT", answerID[i], answerOK[i]) end
    RunTimers()
end

local function Advance(seconds)
    local stop = now + seconds
    while now < stop do Step() end
end

-------------------------------------------------------------------------------
--  Frames
-------------------------------------------------------------------------------
local Widget
local methods = {}
-- A setter or other action a stub lacks does nothing; any other field never set is nil, as on
-- a real frame (BookPage, SearchBar).
local NOOP_PREFIXES = { "Set", "Clear", "Enable", "Register", "Start", "Stop", "Add", "Disable" }
local widgetMeta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) ~= "string" then return end
    for _, p in ipairs(NOOP_PREFIXES) do
        if k:sub(1, #p) == p then
            methods[k] = Noop
            return Noop
        end
    end
end }

local function RunHooks(self, name)
    local hooks = self.hooks and self.hooks[name]
    if hooks then for i = 1, #hooks do hooks[i](self) end end
end

function methods.Show(self)
    if self.shown then return end
    self.shown = true
    local fn = self.scripts and self.scripts.OnShow
    if fn then fn(self) end
    RunHooks(self, "OnShow")
end
function methods.Hide(self)
    if not self.shown then return end
    self.shown = false
    local fn = self.scripts and self.scripts.OnHide
    if fn then fn(self) end
    RunHooks(self, "OnHide")
end
function methods.SetShown(self, on) if on then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.IsVisible(self) return self.shown end
function methods.SetText(self, v) self.text = v end
function methods.GetText(self) return self.text end
function methods.GetStringWidth() return 20 end
function methods.GetStringHeight() return 12 end
function methods.GetWidth(self) return self.w or 400 end
function methods.GetHeight(self) return self.h or 500 end
function methods.SetSize(self, w, h) self.w, self.h = w, h end
function methods.SetWidth(self, w) self.w = w end
function methods.SetHeight(self, h) self.h = h end
function methods.GetFrameLevel() return 1 end
function methods.GetFrameStrata() return "MEDIUM" end
function methods.GetNumPoints() return 0 end
function methods.GetAlpha() return 1 end
function methods.HasFocus() return false end
function methods.GetChecked(self) return self.checked end
function methods.SetChecked(self, v) self.checked = v end
function methods.GetParent(self) return self.parent end
function methods.GetPoint() return nil end
function methods.SetScript(self, name, fn)
    self.scripts = self.scripts or {}
    self.scripts[name] = fn
end
function methods.GetScript(self, name) return self.scripts and self.scripts[name] end
function methods.HookScript(self, name, fn)
    self.hooks = self.hooks or {}
    self.hooks[name] = self.hooks[name] or {}
    local hooks = self.hooks[name]
    hooks[#hooks + 1] = fn
end
function methods.CreateTexture(self) return Widget(self) end
function methods.CreateFontString(self) return Widget(self) end
function methods.GetStatusBarTexture(self) return Widget(self) end
function methods.RegisterEvent(self, event)
    registry[event] = registry[event] or {}
    registry[event][self] = true
end
methods.RegisterUnitEvent = methods.RegisterEvent
-- Only a key that is there is cleared: in Lua 5.1 setting an absent key to nil adds it, which
-- could rehash a set that Fire is walking.
function methods.UnregisterEvent(self, event)
    local set = registry[event]
    if set and set[self] then set[self] = nil end
end
function methods.UnregisterAllEvents(self)
    for _, set in pairs(registry) do
        if set[self] then set[self] = nil end
    end
end

local made = 0
function Widget(parent)
    made = made + 1
    local w = setmetatable({ shown = true, parent = parent }, widgetMeta)
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = w
    end
    return w
end

local env
local function CreateFrame(_, name, parent)
    local w = Widget(parent)
    if name then env[name] = w end
    return w
end

local function hooksecurefunc(a, b, c)
    local tbl, name, fn = a, b, c
    if type(a) == "string" then tbl, name, fn = env, a, b end
    local orig = tbl[name]
    tbl[name] = function(...)
        local r1, r2, r3 = orig(...)
        fn(...)
        return r1, r2, r3
    end
end

-------------------------------------------------------------------------------
--  Game data: Tailoring, the first recipes learned, the rest of RecipeData not yet
-------------------------------------------------------------------------------
local PROF = 197
local LEARNED_N = 60
local REAGENTS = {}            -- reagent itemIDs
for i = 1, 30 do REAGENTS[i] = 50000 + i end
local BROKEN = 49999           -- an item that never loads once `broken` is set (gone from the client)
local broken = false
local UNRELATED = 777777       -- an item the auction house loads for its own lists

local names, loaded = {}, {}
local function ItemNameOf(id)
    local n = names[id]
    if not n then n = "Item " .. id; names[id] = n end
    return n
end

local recipeIDs, recipeInfo, schematic, categoryInfo = {}, {}, {}, {}
local spellNames = {}

local api = {}
-- Called once the real data file has loaded.
function api.Build(data)
    local recipes = data[PROF].recipes
    for i = 1, LEARNED_N do
        local r = recipes[i]
        recipeIDs[i] = r.spell
        local cat = 100 + (i % 6)
        categoryInfo[cat] = categoryInfo[cat] or { name = "Category " .. cat, uiOrder = cat }
        recipeInfo[r.spell] = { recipeID = r.spell, name = "Recipe " .. i, icon = 1000 + i,
            categoryID = cat, learned = true, relativeDifficulty = i % 4, numAvailable = 0 }
        local slots = {}
        for k = 1, 3 do
            local item = REAGENTS[((i + k * 7) % #REAGENTS) + 1]
            slots[k] = { reagents = { { itemID = item } }, quantityRequired = k, required = true }
        end
        schematic[r.spell] = { reagentSlotSchematics = slots, outputItemID = r.item or (60000 + i),
            quantityMin = 1 }
    end
    -- The recipe chosen when the window opens (the first of the first category) takes the
    -- item that never loads.
    schematic[recipes[6].spell].reagentSlotSchematics[2].reagents[1].itemID = BROKEN
    for _, r in ipairs(recipes) do
        loaded[r.spell] = true
        if r.item then loaded[r.item] = true end
        if r.recipe then loaded[r.recipe] = true end
    end
    for _, id in ipairs(REAGENTS) do loaded[id] = true end
    for i = 1, LEARNED_N do loaded[schematic[recipes[i].spell].outputItemID] = true end
    return recipes
end

-- One answer per item per frame however often it is asked for, as the client keeps one load.
local function RequestLoad(id)
    Count("RequestLoadItemDataByID")
    if loaded[id] then return end
    for i = 1, loadCount do if loadID[i] == id then return end end
    loadCount = loadCount + 1
    local ok = not (broken and id == BROKEN)
    loadID[loadCount], loadOK[loadCount] = id, ok
    if ok then loaded[id] = true end
end

local bagItems = {}            -- slot key -> info, made once
local function BagInfo(bag, slot)
    Count("GetContainerItemInfo")
    if bag > 0 then return nil end
    local key = bag * 100 + slot
    local info = bagItems[key]
    if not info then
        info = { itemID = REAGENTS[slot], stackCount = slot }
        bagItems[key] = info
    end
    return info
end

local ah = Widget()
ah.SearchBar = { SetSearchText = Noop, StartSearch = Noop }
local professionsFrame = Widget()
local childInfo = { professionID = PROF, professionName = "Tailoring", skillLevel = 150, maxSkillLevel = 225 }
local itemKeys = {}

local settings = { enabled = true, recipeFinder = true, vendorMaterials = true, craftProfit = true,
    craftProfitList = true, ahSearch = true, bagReagents = true, bankReagents = true,
    buyMaterials = true, shoppingList = true, searchFavoritesAH = true }
local defaults = {}
local db = {}
local account = {}
local ns
ns = {
    THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
        fg = { r = 0.94, g = 0.95, b = 0.95 }, bg = { r = 0.05, g = 0.06, b = 0.07 },
        panel = { r = 0.1, g = 0.1, b = 0.1 }, line = { r = 0.18, g = 0.19, b = 0.21 },
        accentSoft = { r = 0.3, g = 0.71, b = 0.96 } },
    UI = {
        ModuleSettings = function(_, defs)
            for k, v in pairs(defs) do defaults[k] = v end
            local S = {}
            function S.DB() return db end
            function S.Get(k)
                local v = settings[k]
                if v == nil then v = db[k] end
                if v == nil then return defaults[k] end
                return v
            end
            function S.Set(k, v) settings[k] = v end
            return S
        end,
    },
    ThemeTint = function() return nil end,
    Solid = function(parent) return Widget(parent) end,
    Border = function(parent) return Widget(parent) end,
    Font = function(parent) return Widget(parent) end,
    Button = function(parent, text, _, _, onClick)
        local b = Widget(parent)
        b.label = Widget(b)
        b.label.text = text
        b:SetScript("OnClick", onClick)
        return b
    end,
    NewEditBox = function(parent) return Widget(parent) end,
    Tooltip = Noop,
    SetButtonText = function(b, text) b.label.text = text end,
    AccentBorder = function(f) return f end,
    AccountSettings = function() return account end,
    Print = Noop,
    Apply = Noop,
    AllowOffscreen = Noop,
    Color = function(_, text) return text end,
    AuctionPrice = function(id) return 1000 + (id % 97) * 37 end,
    AuctionScanTime = function() return 5000 end,
    AuctionScanSummary = function() return "Last scan" end,
}

env = {
    NaowhForever = ns,
    CreateFrame = CreateFrame,
    CreateColor = function() return EMPTY end,
    hooksecurefunc = hooksecurefunc,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    GetTime = function() return now end,
    time = function() return now end,
    C_Timer = {
        After = function(d, fn)
            timerCount = timerCount + 1
            timerFn[timerCount], timerAt[timerCount] = fn, now + d
        end,
        NewTicker = function() return { Cancel = Noop } end,
    },
    UIParent = Widget(),
    ProfessionsFrame = professionsFrame,
    AuctionHouseFrame = ah,
    GameTooltip = setmetatable({}, widgetMeta),
    GameTooltip_Hide = Noop,
    HideUIPanel = Noop,
    InCombatLockdown = function() return false end,
    IsShiftKeyDown = function() return false end,
    IsControlKeyDown = function() return false end,
    IsModifiedClick = function() return false end,
    IsInGroup = function() return false end,
    GetMoney = function() return 10000000 end,
    UnitGUID = function() return "Player-1-SELF" end,
    UnitName = function() return "Tester" end,
    UnitLevel = function() return 40 end,
    GetRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Alliance" end,
    GetProfessions = function() return 1 end,
    GetProfessionInfo = function() return "Tailoring", 1, 150, 225, 0, 0, PROF, 0 end,
    SecondsToTime = function() return "1 min" end,
    GetMerchantNumItems = function() return 0 end,
    bit = { band = function() return 0 end },
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4,
    SetItemRef = Noop,
    Enum = { BagIndex = { ReagentBag = 5 }, ItemClass = { Tradegoods = 7 },
        AuctionHouseSortOrder = { Price = 0 } },
    C_AddOns = { IsAddOnLoaded = function() return true end },
    C_SpellBook = { IsSpellKnown = function() return false end },
    C_Spell = {
        GetSpellName = function(id)
            local n = spellNames[id]
            if not n then n = "Spell " .. id; spellNames[id] = n end
            return n
        end,
        GetSpellTexture = function(id) return id end,
        GetSpellInfo = function() return nil end,
    },
    C_Map = { GetBestMapForUnit = function() return nil end, GetMapInfo = function() return nil end,
        GetAreaInfo = function() return "Area" end },
    C_QuestLog = { GetTitleForQuestID = function() return nil end },
    C_Item = {
        GetItemNameByID = function(id) if loaded[id] then return ItemNameOf(id) end end,
        RequestLoadItemDataByID = RequestLoad,
        GetItemCount = function(id, bank) return (id % 5) + (bank and 3 or 0) end,
        GetItemIconByID = function(id) return id end,
        GetItemInfo = function(id)
            if not loaded[id] then return nil end
            return ItemNameOf(id), nil, 1, 1, 0, "", "", 20, "", id, 1, 7, 0, 2, 0, 0, false
        end,
        GetItemInfoInstant = function(id) return id end,
        GetItemMaxStackSizeByID = function() return 20 end,
        GetItemFamily = function() return 0 end,
    },
    C_Container = {
        GetContainerNumSlots = function() return 16 end,
        GetContainerNumFreeSlots = function() return 2, 0 end,
        GetContainerItemInfo = BagInfo,
    },
    C_AuctionHouse = {
        MakeItemKey = function(id)
            local k = itemKeys[id]
            if not k then k = { itemID = id }; itemKeys[id] = k end
            return k
        end,
        SendSearchQuery = Noop,
        IsThrottledMessageSystemReady = function() return true end,
    },
    C_TradeSkillUI = {
        GetChildProfessionInfo = function() return childInfo end,
        GetBaseProfessionInfo = function() return childInfo end,
        GetAllRecipeIDs = function() Count("render"); return recipeIDs end,
        GetRecipeInfo = function(id) Count("GetRecipeInfo"); return recipeInfo[id] end,
        GetCategoryInfo = function(id) return categoryInfo[id] end,
        GetRecipeSchematic = function(id) Count("GetRecipeSchematic"); return schematic[id] or EMPTY end,
        GetRecipeOutputItemData = function() return nil end,
        IsTradeSkillLinked = function() return false end,
        IsTradeSkillGuild = function() return false end,
        IsNPCCrafting = function() return false end,
        GetRecipeDescription = function() return "A recipe." end,
        GetRecipeRequirements = function() return EMPTY end,
        GetRecipeCooldown = function() return 0 end,
        IsRecipeTracked = function() return false end,
        SetRecipeTracked = Noop,
        GetRecipeLink = function() return "[link]" end,
        CraftRecipe = Noop,
    },
}
env._G = env
-- A global no stub covers reads as nil, as an absent API would in game.
setmetatable(env, { __index = _G })

-------------------------------------------------------------------------------
--  Load the module and open its window beside the auction house
-------------------------------------------------------------------------------
local files = { "NaowhForever_Professions.lua", "NaowhForever_RecipeData.lua",
    "NaowhForever_RecipeFinder.lua", "NaowhForever_CraftTimer.lua",
    "NaowhForever_FavoriteRecipes.lua", "NaowhForever_ShoppingList.lua" }
local paths = {}
for i, f in ipairs(files) do paths[i] = DIR .. "/" .. f end
Load({ paths[1], paths[2] }, env)
local recipes = api.Build(ns.RecipeData)
Load({ paths[3], paths[4], paths[5], paths[6] }, env)

-- Count the auction house panels' draws: the shopping list places itself on every draw.
local place = ns.ShoppingListPlace
ns.ShoppingListPlace = function() Count("shopping") return place() end

-- Two favourite patterns to look up at the auction house, one of them an item that never
-- loads; and a shopping list with that item on it too.
local favorites, favCount = {}, 0
for i = LEARNED_N + 1, #recipes do
    local r = recipes[i]
    if r.recipe and favCount < 2 then
        favorites[r.spell] = true
        favCount = favCount + 1
        if favCount == 2 then loaded[r.recipe] = nil; r.recipe = BROKEN end
    end
end
db.craftFavorites = favorites
account.profShopping = { ["Tester-Realm"] = {
    [recipes[1].spell] = { name = "Recipe 1", icon = 1, count = 2,
        need = { [BROKEN] = 1, [REAGENTS[3]] = 2, [REAGENTS[4]] = 3, [REAGENTS[9]] = 1 } },
} }

Fire("PLAYER_LOGIN")
Fire("AUCTION_HOUSE_SHOW")
Advance(0.5)
local win = env.NaowhForeverProfessions
assert(win and win:IsShown(), "the window opens")
check("the window lists recipes", calls.render > 0)

-- A pass of every hot path, also the warm-up before measuring.
local list = win.list
local function Scroll()
    list.scripts.OnMouseWheel(list, -1)
    list.scripts.OnMouseWheel(list, 1)
end
local function Redraw() ns.ProfWindowRefresh(); Step() end
local function BagUpdate() Fire("BAG_UPDATE_DELAYED"); Step() end
local function UnrelatedLoad() Fire("ITEM_DATA_LOAD_RESULT", UNRELATED, true); Step() end
for _ = 1, 5 do Redraw(); Scroll(); BagUpdate(); UnrelatedLoad() end
Advance(1)

-------------------------------------------------------------------------------
--  1. Item loads that are not the window's own redraw nothing
-------------------------------------------------------------------------------
local function Snapshot() return calls.render, calls.shopping, calls.RequestLoadItemDataByID end

local r0, s0 = Snapshot()
for _ = 1, 100 do UnrelatedLoad() end
local r1, s1 = Snapshot()
print(("  100 unrelated item loads at the AH: %d window redraws, %d shopping list redraws"):format(
    r1 - r0, s1 - s0))
check("an item loaded for the auction house's own lists does not redraw the window", r1 - r0 == 0)
check("nor the shopping list", s1 - s0 == 0)

-------------------------------------------------------------------------------
--  2. An item that never loads does not keep the window redrawing
-------------------------------------------------------------------------------
local function Break(on)
    broken = on
    loaded[BROKEN] = nil
    Redraw()
    Advance(0.1)
end
Break(true)
local r2, s2, q2 = Snapshot()
Advance(2)
local r3, s3, q3 = Snapshot()
print(("  2 s idle with an item that never loads: %d window redraws, %d shopping list redraws, "
    .. "%d load requests"):format(r3 - r2, s3 - s2, q3 - q2))
check("an item that fails to load does not redraw the window over and over", r3 - r2 <= 1)
check("nor the shopping list", s3 - s2 <= 1)

Break(false)

-------------------------------------------------------------------------------
--  2b. A name the window or the list is waiting for still shows once it loads
-------------------------------------------------------------------------------
local REAGENT = REAGENTS[14]    -- the chosen recipe's first reagent
loaded[REAGENT] = nil
Redraw()
local r5 = calls.render
Advance(0.1)
check("a reagent's name loading redraws the window once", calls.render == r5 + 1)

local LISTED = REAGENTS[3]      -- on the shopping list
loaded[LISTED] = nil
ns.ShoppingListRender(nil)
local s5 = calls.shopping
Advance(0.1)
check("a listed material's name loading redraws the shopping list once", calls.shopping == s5 + 1)

-------------------------------------------------------------------------------
--  3. What each path costs
-------------------------------------------------------------------------------
local RUNS = 200
local function Cost(fn)
    for _ = 1, 3 do fn() end
    collectgarbage("collect")
    collectgarbage("stop")
    local before, start = collectgarbage("count"), os.clock()
    for _ = 1, RUNS do fn() end
    local ms = (os.clock() - start) * 1000 / RUNS
    local kb = (collectgarbage("count") - before) / RUNS
    collectgarbage("restart")
    return ms, kb
end

local function Report(label, fn, maxMs, maxKb)
    local info0, schem0 = calls.GetRecipeInfo, calls.GetRecipeSchematic
    local ms, kb = Cost(fn)
    local runs = RUNS + 3
    print(("  %s: %.3f ms, %.2f KB a call; %.0f GetRecipeInfo, %.0f GetRecipeSchematic a call")
        :format(label, ms, kb, (calls.GetRecipeInfo - info0) / runs, (calls.GetRecipeSchematic - schem0) / runs))
    check(label .. " takes under " .. maxMs .. " ms", ms < maxMs)
    check(label .. " makes under " .. maxKb .. " KB of garbage", kb < maxKb)
end

Report("full redraw", Redraw, 4, 0.05)
Report("bag update", BagUpdate, 4, 0.05)
Report("scroll a step down and up", Scroll, 1, 0.05)
Report("unrelated item load at the AH", UnrelatedLoad, 0.1, 0.01)
-- The auction house opening: the window redraws, the shopping list and Favorite Patterns show.
Report("auction house shown", function()
    Fire("AUCTION_HOUSE_SHOW")
    now = now + 0.31
    RunTimers()
end, 5, 0.5)
-- As the recipe pane draws it: the column first, then the chosen recipe's Add to List row.
Report("shopping list column with the recipe pane", function()
    ns.ShoppingListRender(nil)
    ns.ShoppingListRender(ns.ProfWindowAPI.SelectedInfo(), win.detail.reagents[1])
end, 0.5, 0.05)

-------------------------------------------------------------------------------
--  4. Repeating it all grows no retained memory
-------------------------------------------------------------------------------
local function Round()
    for _ = 1, 50 do Redraw(); Scroll(); BagUpdate(); UnrelatedLoad() end
    Advance(1)
end
Break(true)
Round()
collectgarbage("collect"); collectgarbage("collect")
local base = collectgarbage("count")
for _ = 1, 6 do Round() end
collectgarbage("collect"); collectgarbage("collect")
local grown = collectgarbage("count") - base
print(("  retained after 300 more redraws, scrolls, bag updates and item loads: %+.2f KB"):format(grown))
check("repeated redraws and item loads grow no retained memory", grown < 2)

-------------------------------------------------------------------------------
--  5. Closed, it stays quiet
-------------------------------------------------------------------------------
professionsFrame:Hide()
win:Hide()
Step()
local r4 = calls.render
for _ = 1, 50 do UnrelatedLoad(); BagUpdate() end
check("with the window closed, item loads and bag updates draw nothing", calls.render == r4)

if #failures > 0 then
    for _, label in ipairs(failures) do print("  FAIL " .. label) end
    error(("test-professions-memory: %d of %d checks failed"):format(#failures, checks))
end
print(("test-professions-memory: %d checks passed"):format(checks))
