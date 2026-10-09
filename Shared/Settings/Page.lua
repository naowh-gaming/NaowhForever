-- Page.lua: draws a declared settings page on the row engine, one card per feature, for the options window (Settings.Render).
local ns = _G.NaowhForever
local Shared = ns.Shared
local Settings, View = Shared.Settings, Shared.View
local SS = Settings.Style

local BORDER_RGB, CARD_GAP = SS.BORDER_RGB, SS.CARD_GAP
local TWO_COLUMNS_W = 620
local DRAG_WAIT = 0.05
local NO_EVENTS = {}
local TEXT_NO_MATCH = "Nothing on this page matches the search."

local Draw = {}
local watched = {}
local findLabel, findCard

local function Hidden(row)
    local hidden = row.hidden
    if type(hidden) == "function" then hidden = hidden() end
    return hidden
end

local function IsGroup(row)
    return row ~= nil and row.kind == "group"
end

local function KeepRows(rows, card, only)
    for _, row in ipairs(Settings.Rows(card)) do
        local group = row.kind == "group"
        local keep = not Hidden(row) and (not only or group or only[row.label])
        if keep and only and group and IsGroup(rows[#rows]) then
            rows[#rows] = row
        elseif keep then
            rows[#rows + 1] = row
        end
    end
    if only and IsGroup(rows[#rows]) then rows[#rows] = nil end
    return rows
end

local function AddPair(view, row, second, w)
    local half = math.floor(w / 2)
    local top = view.cursor
    local pair = second and second.kind ~= "group" and not second.wide
    view.width = half
    view:Add("setting", row, true)
    if not pair then return 1 end
    view.cursor = top
    view.left, view.width = half, w - half
    view:Add("setting", second, false)
    return 2
end

local function OnlyOf(card, found)
    local only = found ~= true and found or nil
    for _, row in ipairs(only and Settings.Rows(card) or NO_EVENTS) do
        if only[row.label] and Hidden(row) then return nil end
    end
    return only
end

local function OpenCardFrame(view)
    view.left, view.width = 0, view:GetWidth()
    local frame = view:Acquire("card")
    frame:SetFrameLevel(view:GetFrameLevel())
    frame.edge:SetColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
    frame.note:Hide()
    return frame
end

local function FlushSettings(view)
    if ns.UI.sliderDrag then
        C_Timer.After(DRAG_WAIT, view.settingsRedrawFn)
        return
    end
    view.settingsQueued = false
    if view:IsVisible() then
        view:Redraw()
        if view.onResize then view.onResize(view:GetHeight()) end
    end
end

local function Watch(store, view)
    local views = watched[store]
    if not views then
        views = {}
        watched[store] = views
        store.OnChange(function()
            for v in pairs(views) do
                if v:IsVisible() then v:QueueSettingsRedraw() end
            end
        end)
    end
    views[view] = true
end

local function WatchPage(view, page)
    for _, item in ipairs(page and page.items or NO_EVENTS) do
        if item.store then Watch(item.store, view) end
        for _, row in ipairs(item.rows or NO_EVENTS) do
            if row.store and row.store ~= item.store then Watch(row.store, view) end
        end
    end
end

local function NewView(parent)
    local view = View.New(parent, Settings.kinds, Draw)
    view.settingsRedrawFn = function() FlushSettings(view) end
    view.shownRows = {}
    return view
end

local function IsSetting(row)
    return row.setting.label == findLabel and (not findCard or row.setting.card.uid == findCard)
end

local function IsHead(head)
    return (findLabel == nil or head.card.name == findLabel) and (not findCard or head.card.uid == findCard)
end

function Draw:Settings(card, only)
    local w = self:GetWidth()
    local columns = w >= TWO_COLUMNS_W and 2 or 1
    local rows = KeepRows(wipe(self.shownRows), card, only)
    local i = 1
    while i <= #rows do
        local row = rows[i]
        self.left, self.width = 0, w
        if row.kind == "group" then
            self:Add("group", row.group)
            i = i + 1
        elseif row.wide or columns == 1 then
            self:Add("setting", row, false)
            i = i + 1
        else
            i = i + AddPair(self, row, rows[i + 1], w)
            self.left, self.width = 0, w
        end
    end
end

function Draw:CardBody(card, found)
    if card.info then
        for _, line in ipairs(card.rows) do
            if line.group then self:Add("group", line.group) else self:Add("infoLine", line) end
        end
        return
    end
    local only = OnlyOf(card, found)
    if card.studio and self.kinds.studio and not only then self:Add("studio", card) end
    self:Settings(card, only)
    local changed = Settings.ChangedCount(card)
    if changed > 0 and not only then self:Add("cardFoot", card, changed) end
end

function Draw:Card(card, found)
    local top = self.cursor
    local frame = OpenCardFrame(self)
    local isOpen = (found ~= nil or Settings.IsOpen(card)) and Settings.Openable(card)
    self:Add("cardHead", card, isOpen, found ~= nil)
    if isOpen then self:CardBody(card, found) end
    frame:SetHeight(self.cursor - top)
    self:Space(CARD_GAP)
end

function Draw:Redraw()
    self:Clear()
    local page = Settings.pages[self.pageKey]
    local f = self.filter
    if f and f.all[self.pageKey] then f = nil end
    if page then
        local drawn = false
        for _, item in ipairs(page.items) do
            if not f then
                if item.window then
                    self:Add("window", item)
                    self:Space(CARD_GAP)
                else
                    self:Card(item)
                end
            elseif not item.window and f.cards[item.uid] then
                self:Card(item, f.cards[item.uid])
                drawn = true
            end
        end
        if f and not drawn then self:Note(TEXT_NO_MATCH) end
    end
    self:Fit(NO_EVENTS)
end

function Draw:QueueSettingsRedraw()
    if self.settingsQueued then return end
    self.settingsQueued = true
    C_Timer.After(0, self.settingsRedrawFn)
end

function Settings.Render(parent, pageKey, onResize, filter)
    local view = parent.settingsView
    if not view then
        view = NewView(parent)
        parent.settingsView = view
    end
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI.CONTENT_PAD, -ns.UI.CONTENT_PAD / 2)
    view:SetWidth(math.max(1, parent:GetWidth() - ns.UI.CONTENT_PAD * 2))
    view.pageKey, view.onResize, view.filter = pageKey, onResize, filter
    WatchPage(view, Settings.pages[pageKey])
    view:Show()
    view:Redraw()
    return view:GetHeight() + ns.UI.CONTENT_PAD
end

function Settings.FindRow(parent, label, cardUid)
    local view = parent.settingsView
    if not view then return nil end
    findLabel, findCard = label, cardUid
    local row = (label and view:Find("setting", IsSetting)) or view:Find("cardHead", IsHead)
    findLabel, findCard = nil, nil
    if not row then return nil end
    return row, row.top + ns.UI.CONTENT_PAD / 2
end

function Settings.Reveal(cardUid)
    local card = cardUid and Settings.CardOf(cardUid)
    if card then Settings.SetOpen(card, true) end
end
