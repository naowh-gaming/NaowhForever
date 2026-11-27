-- View.lua: a page of the BiS List on the shared engine: your list or a slot's picker (B.View).
local ns = _G.NaowhForever

local B = ns.BiS
local L, R = B.Lists, B.Rankings
local Shared = ns.Shared
local Items = Shared.Items
local St = B.Style

local OFF_HAND = B.C.OFF_HAND
local SECTION_SPACE = St.SECTION_SPACE
local JOURNAL = "NaowhForever_DungeonJournal"
local TEXT_TURN_ON_JOURNAL = ns.L("Turn On Dungeon Journal")
local TEXT_RUN_NEXT = ns.L("Run next")
local TEXT_RUN_NEXT_OFF = ns.L("Turn on the Dungeon Journal for each dungeon's levels and quests here.")
local TEXT_ROUTE = ns.L("Route")
local TEXT_NEXT_STOP, TEXT_AFTER_THAT = ns.L("Next stop"), ns.L("After that")
local TEXT_ROUTE_EMPTY = ns.L("Nothing left to get: every pick you can go and get is yours.")
local TEXT_OFF_HAND_IDLE = ns.L("Unused while your main hand's BiS is a two-hander.")
local TEXT_YOUR_PICKS = ns.L("Your picks")
local TEXT_NO_PICKS = ns.L("Nothing picked yet. Click an item below: the first is your BiS.")
local TEXT_RANKED = ns.L("Ranked")
local TEXT_RANKED_FOR = ns.L("Ranked for ")
local TEXT_NOTHING_RANKED = ns.L("Nothing ranked for this slot.")
local TEXT_LATER = ns.L("For later levels")
local TEXT_DROPS = ns.L("Dungeon drops")
local TEXT_DROPS_NEAR = ns.L("Dungeon drops near your level")
local TEXT_DROPS_OFF = ns.L("Turn on the Dungeon Journal to see what drops in dungeons for this slot.")
local TEXT_NEAR_LINK, TEXT_ALL_LINK = ns.L("Near My Level"), "Show All"
local TEXT_NO_DROPS = ns.L("No dungeon drops for this slot that you can use.")
local TEXT_NO_DROPS_NEAR = ns.L("No dungeon drops for this slot within 10 levels of yours.")
local TEXT_CRAFTS = ns.L("Crafted gear")
local TEXT_CRAFTS_NEAR = ns.L("Crafted gear near your level")
local TEXT_NO_CRAFTS = ns.L("No crafted gear for this slot that you can use.")
local TEXT_NO_CRAFTS_NEAR = ns.L("No crafted gear for this slot within 10 levels of yours.")
local TEXT_CLASS = ns.L("Class quest rewards")
local TEXT_CLASS_NEAR = ns.L("Class quest rewards near your level")
local TEXT_NO_CLASS = ns.L("No class quest rewards for this slot that you can use.")
local TEXT_NO_CLASS_NEAR = ns.L("No class quest rewards for this slot within 10 levels of yours.")
local TEXT_WORLD = ns.L("World drops")
local TEXT_WORLD_NEAR = ns.L("World drops near your level")
local TEXT_NO_WORLD = ns.L("No world drops for this slot that you can use.")
local TEXT_NO_WORLD_NEAR = ns.L("No world drops for this slot within 10 levels of yours.")
local TEXT_QUESTS = ns.L("Quests for your BiS")
local TEXT_QUESTS_OFF = ns.L("Turn on the Dungeon Journal to see the quests that reward your picks, "
    .. "with their chains and waypoints.")
local EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP" }
local GROUPS = {
    { title = ns.L("Armor"), slots = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8 } },
    { title = ns.L("Jewelry"), slots = { 11, 12, 13, 14 } },
    { title = ns.L("Weapons"), slots = { 16, 17, 18 } },
}
local NOTHING_LEFT = {
    get = "Every BiS on your list is yours.",
    wear = "Nothing to put on: you wear every BiS you have.",
    enchant = "Everything you wear has the best enchant for your level.",
}

local function KeepAll() return true end
local function KeepToGet(_, bis) return bis ~= nil and not Items.Owned(bis) end
local function KeepToWear(slot, bis) return bis ~= nil and Items.Owned(bis) and not Items.Wearing(slot, bis) end
local function KeepToEnchant(slot) return B.Enchants.ToDo(slot) end

local FILTERS = { all = KeepAll, get = KeepToGet, wear = KeepToWear, enchant = KeepToEnchant }

local function Memo(format)
    local made = {}
    return function(a, b)
        local byA = made[a]
        if not byA then
            byA = {}
            made[a] = byA
        end
        local text = byA[b]
        if not text then
            text = format:format(a, b)
            byA[b] = text
        end
        return text
    end
end

local Yours = Memo(ns.L("%d of %d yours"))

local function ToggleDrops(view)
    view.allDrops = not view.allDrops
    view:Redraw()
end

local function ToggleCrafts(view)
    view.allCrafts = not view.allCrafts
    view:Redraw()
end

local function ToggleClassQuests(view)
    view.allClassQuests = not view.allClassQuests
    view:Redraw()
end

local function ToggleWorld(view)
    view.allWorld = not view.allWorld
    view:Redraw()
end

local function Most(gains)
    local most = 0
    for _, gain in pairs(gains) do
        if gain > most then most = gain end
    end
    return most
end

local ViewMixin = {}

function ViewMixin:Begin()
    self:Clear()
    self.playerLevel = UnitLevel("player")
    self.striped = false
end

function ViewMixin:Count()
    local counts, slots = self.counts, self.list.slots
    for key in pairs(FILTERS) do counts[key] = 0 end
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local slot = gear[1]
        for key, keep in pairs(FILTERS) do
            if keep(slot, slots[slot]) then counts[key] = counts[key] + 1 end
        end
    end
end

function ViewMixin:DrawSlot(slot)
    local picks = B.Picks(self.list, slot, self.picks)
    local open = self.open[slot] == true and #picks > 1
    self.rowTops[slot] = self.cursor
    self.rows[slot] = self:Add("slotRow", slot, picks[1], #picks, open)
    if open then
        for rank = 2, #picks do self:Add("backup", slot, picks[rank], rank, #picks) end
    end
    if slot == OFF_HAND and picks[1] and B.OffHandIdle(self.list) then self:Note(TEXT_OFF_HAND_IDLE) end
end

function ViewMixin:DrawGroup(group, keep)
    local slots, shown, have, picked = self.list.slots, 0, 0, 0
    for _, slot in ipairs(group.slots) do
        local bis = slots[slot]
        if keep(slot, bis) then shown = shown + 1 end
        if bis then
            picked = picked + 1
            if Items.Owned(bis) then have = have + 1 end
        end
    end
    if shown == 0 then return 0 end
    self:Section(group.title, picked > 0 and Yours(have, picked) or nil)
    local n = 0
    for _, slot in ipairs(group.slots) do
        if keep(slot, slots[slot]) then
            n = n + 1
            self.striped = n % 2 == 1
            self:DrawSlot(slot)
        end
    end
    self.striped = false
    self:Space(SECTION_SPACE)
    return shown
end

function ViewMixin:DrawRunNext()
    local places = (self.filter == "all" or self.filter == "get") and R.RunNext(self.list, self.gains)
    if not (places and places[1]) then return end
    self.mostPlaceGain = places[1].gain
    if ns.Journal then
        self:Section(TEXT_RUN_NEXT)
    else
        self:NeedsModule(TEXT_RUN_NEXT, TEXT_RUN_NEXT_OFF, JOURNAL, TEXT_TURN_ON_JOURNAL)
    end
    for i = 1, #places do self:Add("place", places[i]) end
    self:Space(SECTION_SPACE)
end

function ViewMixin:DrawList()
    self.page = "list"
    self:Begin()
    wipe(self.rows)
    self.list = L.List()
    self:Count()
    self.gains = B.Upgrades.Read(self.list)
    self.mostGain = Most(self.gains)
    if self.summary then B.View.PaintSummary(self.summary, self.list, self.filter, self.counts) end
    self:DrawRunNext()
    local keep, shown = FILTERS[self.filter], 0
    for _, group in ipairs(GROUPS) do shown = shown + self:DrawGroup(group, keep) end
    if shown == 0 then self:Note(NOTHING_LEFT[self.filter]) end
    self:Fit(EVENTS)
    self:Light(self.lit)
    if self.onDrawn then self.onDrawn() end
end

function ViewMixin:DrawRoute()
    self.page = "route"
    self:Begin()
    wipe(self.rows)
    self.list = L.List()
    self.route = R.Route(self.list)
    local steps = #self.route
    if not ns.Journal then self:NeedsModule(TEXT_ROUTE, TEXT_RUN_NEXT_OFF, JOURNAL, TEXT_TURN_ON_JOURNAL) end
    if steps == 0 then self:Note(TEXT_ROUTE_EMPTY) end
    for i = 1, steps do
        if i == 1 then
            self:Section(TEXT_NEXT_STOP)
        elseif i == 2 then
            self:Space(SECTION_SPACE)
            self:Section(TEXT_AFTER_THAT, steps - 1)
        end
        self:Add("place", self.route[i], i, steps)
    end
    self:Fit(EVENTS)
    if self.onDrawn then self.onDrawn() end
end

function ViewMixin:SetFilter(key)
    self.filter = key
    self:Redraw()
end

function ViewMixin:Toggle(slot)
    self.open[slot] = not self.open[slot] or nil
    self:Redraw()
end

function ViewMixin:Light(slot)
    self.lit = slot
    for rowSlot, row in pairs(self.rows) do row.lit:SetShown(rowSlot == slot) end
end

function ViewMixin:ScrollTo(slot)
    local row, top = self.rows[slot], self.rowTops[slot]
    if not row then return end
    local scroll = self:GetParent()
    local y, height = scroll:GetVerticalScroll(), scroll:GetHeight()
    local bottom = top + row:GetHeight()
    if top >= y and bottom <= y + height then return end
    local target = bottom > y + height and bottom - height or top
    scroll:SetVerticalScroll(math.max(0, math.min(target, scroll:GetVerticalScrollRange())))
end

function ViewMixin:DrawItems(slot, ids, mode, count, numbered, ranks)
    local picked = self.picked
    for i = 1, #ids do
        self.striped = i % 2 == 1
        self:Add("pick", slot, ids[i], picked[ids[i]], mode, count, numbered and (ranks and ranks[i] or i))
    end
    self.striped = false
end

function ViewMixin:DrawOwnPicks(slot)
    local picks = B.Picks(L.List(), slot, self.picks)
    local picked = wipe(self.picked)
    for rank = 1, #picks do picked[picks[rank]] = rank end
    self:Section(TEXT_YOUR_PICKS, #picks)
    self:DrawItems(slot, picks, "own", #picks)
    if #picks == 0 then self:Note(TEXT_NO_PICKS) end
    self:Space(SECTION_SPACE)
end

function ViewMixin:DrawRanked(slot)
    local spec = L.CurrentSpec()
    local ranked = R.Candidates(slot, spec)
    local top = self.playerLevel + B.Settings.Get("bisAutoAhead")
    local now, nowRanks, later, laterRanks = wipe(self.rankedNow), wipe(self.nowRanks), wipe(self.rankedLater),
        wipe(self.laterRanks)
    for i, id in ipairs(ranked) do
        local required = R.ReqLevel(id)
        if required and required > top then
            later[#later + 1], laterRanks[#laterRanks + 1] = id, i
        else
            now[#now + 1], nowRanks[#nowRanks + 1] = id, i
        end
    end
    self:Section(spec and TEXT_RANKED_FOR .. spec.name or TEXT_RANKED, #now)
    self:DrawItems(slot, now, "add", nil, true, nowRanks)
    if #ranked == 0 then self:Note(TEXT_NOTHING_RANKED) end
    if #later > 0 then
        self:Space(SECTION_SPACE)
        self:Section(TEXT_LATER, #later)
        self:DrawItems(slot, later, "add", nil, true, laterRanks)
    end
    self:Space(SECTION_SPACE)
    return ranked
end

function ViewMixin:DrawDrops(slot, ranked)
    local all = self.allDrops
    local drops = R.DungeonDrops(slot, ranked, not all)
    self:SectionLink(all and TEXT_DROPS or TEXT_DROPS_NEAR, all and TEXT_NEAR_LINK or TEXT_ALL_LINK, ToggleDrops, self)
    self:DrawItems(slot, drops, "add")
    if #drops == 0 then self:Note(all and TEXT_NO_DROPS or TEXT_NO_DROPS_NEAR) end
end

function ViewMixin:DrawCrafts(slot, ranked)
    local all = self.allCrafts
    local crafts = R.Crafts(slot, ranked, not all)
    self:SectionLink(all and TEXT_CRAFTS or TEXT_CRAFTS_NEAR, all and TEXT_NEAR_LINK or TEXT_ALL_LINK, ToggleCrafts, self)
    self:DrawItems(slot, crafts, "add")
    if #crafts == 0 then self:Note(all and TEXT_NO_CRAFTS or TEXT_NO_CRAFTS_NEAR) end
end

function ViewMixin:DrawClassQuests(slot, ranked)
    local all = self.allClassQuests
    local rewards = R.ClassQuests(slot, ranked, not all)
    self:SectionLink(all and TEXT_CLASS or TEXT_CLASS_NEAR, all and TEXT_NEAR_LINK or TEXT_ALL_LINK,
        ToggleClassQuests, self)
    self:DrawItems(slot, rewards, "add")
    if #rewards == 0 then self:Note(all and TEXT_NO_CLASS or TEXT_NO_CLASS_NEAR) end
end

function ViewMixin:DrawWorldDrops(slot, ranked)
    local all = self.allWorld
    local drops = R.WorldDrops(slot, ranked, not all)
    self:SectionLink(all and TEXT_WORLD or TEXT_WORLD_NEAR, all and TEXT_NEAR_LINK or TEXT_ALL_LINK, ToggleWorld, self)
    self:DrawItems(slot, drops, "add")
    if #drops == 0 then self:Note(all and TEXT_NO_WORLD or TEXT_NO_WORLD_NEAR) end
end

function ViewMixin:DrawPicker(slot)
    self.page, self.slot = "picker", slot
    self:Begin()
    self:DrawOwnPicks(slot)
    local ranked = self:DrawRanked(slot)
    if ns.Journal then
        self:DrawDrops(slot, ranked)
    else
        self:NeedsModule(TEXT_DROPS, TEXT_DROPS_OFF, JOURNAL, TEXT_TURN_ON_JOURNAL)
    end
    self:Space(SECTION_SPACE)
    self:DrawCrafts(slot, ranked)
    self:Space(SECTION_SPACE)
    self:DrawClassQuests(slot, ranked)
    self:Space(SECTION_SPACE)
    self:DrawWorldDrops(slot, ranked)
    self:Fit(EVENTS)
end

function ViewMixin:DrawQuestsOff()
    self.page = "questsOff"
    self:Begin()
    self:NeedsModule(TEXT_QUESTS, TEXT_QUESTS_OFF, JOURNAL, TEXT_TURN_ON_JOURNAL)
    self:Fit(EVENTS)
end

function ViewMixin:Redraw()
    if not self:IsVisible() then return end
    if self.page == "picker" then
        self:DrawPicker(self.slot)
    elseif self.page == "questsOff" then
        self:DrawQuestsOff()
    elseif self.page == "route" then
        self:DrawRoute()
    else
        self:DrawList()
    end
end

local View = { Kinds = Shared.View.NewKinds() }
B.View = View
View.Memo = Memo

function View.New(parent)
    local view = Shared.View.New(parent, View.Kinds, ViewMixin)
    view.picks, view.picked, view.counts, view.open = {}, {}, {}, {}
    view.rankedNow, view.nowRanks, view.rankedLater, view.laterRanks = {}, {}, {}, {}
    view.rows, view.rowTops, view.filter = {}, {}, "all"
    view.inset = St.STATUS_W
    B.OnListChange(view.redrawFn)
    ns.StatWeights.OnChange(view.redrawFn)
    B.Settings.OnChange(function(key)
        if key == "bisAutoAhead" or key == "bisPvP" then view:Redraw() end
    end)
    return view
end
