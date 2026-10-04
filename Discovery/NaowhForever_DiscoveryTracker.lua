-------------------------------------------------------------------------------
--  NaowhForever_DiscoveryTracker.lua -- the library book tracker: in a zone with books you
--  still need, a small window lists them with a waypoint for each. It pops up on entering
--  such a zone; Always Show keeps it up in every zone. In the Dungeon Quest Tracker's look:
--  the Journal's window style (its gradient faded by the window's Opacity, a card behind the
--  list, its titles' blue), the progress bar and the zone dropdown under the title, rows like
--  its quest rows (a waypoint pin in front, a tick in its place once a book is handed in) and
--  a cog for its settings in the bottom right.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local S = ns.DiscoverySettings
local L = ns.Library
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

-- The light blue of the hint lines: the shade each one always was (r, g, b), or the theme's
-- lighter Accent once the theme has changed the Accent. Returns r, g, b, so where it is not
-- the last argument its values are put in locals first.
local function SoftBlue(r, g, b)
    local c = ns.ThemeTint("accentSoft", nil)
    if c then return c.r, c.g, c.b end
    return r, g, b
end
local BAR_BG = { r = 0x14 / 255, g = 0x16 / 255, b = 0x19 / 255 }
local READY = { r = 0x19 / 255, g = 1, b = 0x19 / 255 }

-- The window: as the Dungeon Quest Tracker's (UI/QuestTracker.lua), its parts on the same
-- measures.
local PANEL_W = 320
local PANEL_PAD, PANEL_HEADER = St.PANEL_PAD, St.PANEL_HEADER
local BODY_W = PANEL_W - PANEL_PAD * 2
local BAR_H, BAR_GAP = 24, 6               -- the progress bar, as tall as the dropdown under it
local FOOTER = St.ACTION + 6               -- the cog under the list, and the room above it
local SETTINGS_PAGE = "Discovery/Library Books"
-- A row, as a quest row (View/QuestRows.lua): the pin in a column of its own (a tick there
-- once the book is handed in), then the name with where it is under it.
local ROW_LEFT, WAYPOINT_SLOT, TICK = 6, 20, 16
local TITLE_LEFT = ROW_LEFT + WAYPOINT_SLOT + 6
local ROW_TOP, ROW_LINE_GAP, ROW_BOTTOM = 6, 3, 8

local panel, zoneEvents, shownEvents
local dismissedZone   -- the zone the X closed it in, until you leave
local pickedZone      -- the zone the dropdown is listing, while it shows

local function On()
    return S.Get("enabled") and S.Get("tracker")
end

local function BarTooltip(bar)
    local done, total = L.Progress()
    GameTooltip:SetOwner(bar, "ANCHOR_LEFT")
    GameTooltip:SetText("Library Books")
    GameTooltip:AddLine(("%d of %d books handed in"):format(done, total), 1, 1, 1)
    for _, goal in ipairs(ns.LibraryGoals) do
        local state, r, g, b
        local now = L.GoalState(goal, done)
        if now == "claimed" then
            state, r, g, b = "Claimed", 0.61, 0.64, 0.69
        elseif now == "ready" then
            state, r, g, b = "Ready to hand in", READY.r, READY.g, READY.b
        elseif now == "level" then
            state, r, g, b = ("At level %d"):format(goal.level), 1, 0.82, 0
        else
            state, r, g, b = ("%d to go"):format(goal.books - done), 1, 1, 1
        end
        GameTooltip:AddLine(" ")
        local sr, sg, sb = SoftBlue(0.3, 0.71, 0.96)
        GameTooltip:AddDoubleLine(("%s (%d)"):format(goal.name, goal.books), state, sr, sg, sb, r, g, b)
        local names = {}
        for _, reward in ipairs(goal.rewards) do
            names[#names + 1] = C_Item.GetItemNameByID(reward[1]) or reward[2]
        end
        GameTooltip:AddLine(table.concat(names, " or "), 0.61, 0.64, 0.69, true)
    end
    local librarian = ns.LibraryTurnIns.librarian[L.Side()]
    GameTooltip:AddLine(" ")
    local hr, hg, hb = SoftBlue(0.3, 0.7, 0.95)
    GameTooltip:AddLine("Hand in to " .. librarian.name .. ", " .. librarian.place, hr, hg, hb, true)
    local bags, bank = 0, 0
    for _, book in ipairs(ns.LibraryBooks) do
        local stored = L.ForMe(book) and L.Stored(book)
        if stored == "bags" then bags = bags + 1 elseif stored == "bank" then bank = bank + 1 end
    end
    if bags > 0 then GameTooltip:AddLine(bags .. " waiting in your bags", 1, 0.82, 0) end
    if bank > 0 then GameTooltip:AddLine(bank .. " waiting in your bank", 1, 0.82, 0) end
    GameTooltip:Show()
end

-------------------------------------------------------------------------------
--  The window
-------------------------------------------------------------------------------
-- Its look's opacity: its own (trackerAlpha).
local function Paint()
    panel.backdrop:Paint(S.Get("trackerAlpha") or 1)
end

-- Dragged by its body or its title, as the Dungeon Quest Tracker is: kept where you leave it,
-- the same place Unlock Mode's mover keeps (trackerPos).
local function DragStop()
    panel:StopMovingOrSizing()
    local point, _, relPoint, x, y = panel:GetPoint(1)
    S.Set("trackerPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function DragStart()
    panel:StartMoving()
end

local function BuildPanel()
    panel = Parts.Panel("LIBRARY BOOKS", true)
    panel.backdrop:Card(4, PANEL_HEADER, 4, 4)
    panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    panel:SetWidth(PANEL_W)
    panel:SetScale(S.Get("trackerScale"))
    panel:SetMovable(true)
    panel:SetFrameStrata("MEDIUM")
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", DragStart)
    panel:SetScript("OnDragStop", DragStop)
    -- The X closes it until you change zone, and switches Always Show off, so switching that
    -- back on is how to bring it back.
    panel.close:SetScript("OnClick", function()
        dismissedZone = L.PlayerZone()
        panel:Hide()
        if S.Get("trackerAlways") then
            S.Set("trackerAlways", false)
            ns.UI:RefreshPage(true)
        end
    end)
    local titleBtn = CreateFrame("Button", nil, panel)
    titleBtn:SetPoint("TOPLEFT", panel.title, "TOPLEFT", -4, 4)
    titleBtn:SetPoint("BOTTOMRIGHT", panel.title, "BOTTOMRIGHT", 0, -4)
    titleBtn:SetScript("OnClick", function() ns.OpenDiscoveryWindow("books") end)
    titleBtn:RegisterForDrag("LeftButton")
    titleBtn:SetScript("OnDragStart", DragStart)
    titleBtn:SetScript("OnDragStop", DragStop)
    titleBtn:SetScript("OnEnter", function(self)
        panel.title:SetTextColor(T.accent.r, T.accent.g, T.accent.b)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Library Books")
        GameTooltip:AddLine("Click to open the Books page.", SoftBlue(0.3, 0.7, 0.95))
        GameTooltip:Show()
    end)
    titleBtn:SetScript("OnLeave", function()
        panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
        GameTooltip:Hide()
    end)

    local bar = CreateFrame("StatusBar", nil, panel)
    bar:SetSize(BODY_W, BAR_H)
    bar:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEADER - 4)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    ns.Solid(bar, "BACKGROUND", ns.ThemeTint("panel", BAR_BG), 1):SetAllPoints()
    ns.Border(bar, St.BORDER_RGB)
    bar.text = ns.Font(bar, 12, "OUTLINE")
    bar.text:SetPoint("CENTER", 0, 0)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", BarTooltip)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    panel.bar = bar

    -- With Always Show, in a zone with no books left: pick another zone to list. Its zones
    -- are handed to it on every redraw.
    panel.picker = ns.UI.BuildDropdownControl(panel, BODY_W, panel:GetFrameLevel() + 3, {}, {},
        function() return pickedZone end,
        function(id) S.Set("trackerZone", id) end)
    panel.picker:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -BAR_GAP)
    panel.picker:Hide()

    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetWidth(BODY_W)
    panel.rows = {}

    -- Bottom right, under the list: the tracker's settings.
    panel.settings = Parts.IconButton(panel, function()
        ns.OpenOptionsWindow(SETTINGS_PAGE)
        ns.UI.GoToSetting(SETTINGS_PAGE, nil, SETTINGS_PAGE .. ":tracker")
    end, ns.UI.COGS_ICON, 0, "Library Books settings")
    panel.settings:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    panel.settings.hint = "Opens the Library Books tracker's settings."

    panel.mover = ns.UI.AttachMover(panel, "Library Books", function(pos) S.Set("trackerPos", pos) end,
        "Discovery/Library Books")
    local pos = S.Get("trackerPos")
    if pos then
        panel:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        panel:SetPoint("RIGHT", UIParent, "RIGHT", -260, -120)
    end
    Paint()
    panel:Hide()
end

local function RowEnter(row)
    row.hover:Show()
    local entry = row.entry
    if not (entry and entry.tip) then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    entry.tip()
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function PinClick(pin)
    local entry = pin:GetParent().entry
    if entry and entry.waypoint then entry.waypoint() end
end

local function Row(i)
    local row = panel.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, panel.body)
    row:SetWidth(BODY_W)
    -- Every other row on a faint band, lit on hover, a line under each, as a quest row.
    row.stripe = ns.Solid(row, "BACKGROUND", T.fg, St.STRIPE)
    row.stripe:SetAllPoints()
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, 0.04)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.divider = ns.Solid(row, "BORDER", T.line, 0.6)
    row.divider:SetPoint("BOTTOMLEFT", ROW_LEFT, 0)
    row.divider:SetPoint("BOTTOMRIGHT")
    ns.Hairline(row.divider, "h")
    -- Centred in its column, so the pin sits over the tick a book handed in shows there
    -- (measured in game, 2026-10-04: 4 to the right put the pin 4px right of the tick, 2 put it
    -- 2px right).
    row.pin = Parts.IconButton(row, PinClick, St.PIN, 0, "Waypoint")
    row.pin.hint = "Click to mark it on your map."
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetTexture(St.CHECK)
    row.tick:SetSize(TICK, TICK)
    row.text = ns.Font(row, 13, nil, T.fg)
    row.text:SetPoint("TOPLEFT", TITLE_LEFT, -ROW_TOP)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.sub = ns.Font(row, 11, nil, T.muted)
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -ROW_LINE_GAP)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    panel.rows[i] = row
    return row
end

-- entries: { text, sub?, done?, waypoint?, tip? }. Every row keeps the pin's column, so the
-- names line up whether or not a row has one.
local function Layout(entries)
    local y = 0
    local width = BODY_W - TITLE_LEFT - PANEL_PAD
    for i, entry in ipairs(entries) do
        local row = Row(i)
        row.entry = entry
        row.stripe:SetShown(i % 2 == 0)
        row.hover:Hide()
        row.text:SetWidth(width)
        row.text:SetText(entry.text)
        local h = ROW_TOP + math.ceil(row.text:GetStringHeight()) + ROW_BOTTOM
        row.sub:SetWidth(width)
        row.sub:SetText(entry.sub or "")
        row.sub:SetShown(entry.sub ~= nil)
        if entry.sub then h = h + ROW_LINE_GAP + math.ceil(row.sub:GetStringHeight()) end
        -- The pin, or the tick of a book handed in, on the name's line.
        local line = -(ROW_TOP + math.ceil(row.text:GetStringHeight()) / 2)
        row.pin:ClearAllPoints()
        row.pin:SetPoint("CENTER", row, "TOPLEFT", ROW_LEFT + WAYPOINT_SLOT / 2, line)
        row.pin:SetShown(entry.waypoint ~= nil)
        row.tick:ClearAllPoints()
        row.tick:SetPoint("CENTER", row, "TOPLEFT", ROW_LEFT + WAYPOINT_SLOT / 2, line)
        row.tick:SetShown(entry.done == true)
        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, -y)
        row.divider:SetShown(entries[i + 1] ~= nil)
        row:Show()
        y = y + h
    end
    for i = #entries + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.body:SetHeight(math.max(y, 1))
    return y
end

-------------------------------------------------------------------------------
--  What it lists
-------------------------------------------------------------------------------
-- Books looted and not handed in, counted per person who takes them and where they are
-- kept: out["librarian/bags"] and so on.
local function CarriedByTurnIn()
    local out = {}
    for _, book in ipairs(ns.LibraryBooks) do
        local stored = L.ForMe(book) and L.Stored(book)
        if stored then
            local key = (book.turnIn or "librarian") .. "/" .. stored
            out[key] = (out[key] or 0) + 1
        end
    end
    return out
end

local function RenderBar()
    local bar = panel.bar
    local done, total = L.Progress()
    local goal = L.NextGoal()
    local accent = T.accent
    if goal then
        local ready = L.GoalState(goal, done) == "ready"
        bar:SetMinMaxValues(0, goal.books)
        bar:SetValue(math.min(done, goal.books))
        local c = ready and READY or accent
        bar:SetStatusBarColor(c.r, c.g, c.b, 0.85)
        bar.text:SetText(ready and (goal.name .. " ready to hand in")
            or ("%d / %d  %s"):format(done, goal.books, goal.name))
    else
        bar:SetMinMaxValues(0, math.max(total, 1))
        bar:SetValue(done)
        bar:SetStatusBarColor(READY.r, READY.g, READY.b, 0.85)
        bar.text:SetText(("%d / %d books handed in"):format(done, total))
    end
end

-- Every zone with a book still to find, in the data's order (by set), with how many:
-- { uiMapID, count } pairs. keep, the zone picked in the dropdown, stays in the list at 0
-- once its last book is looted, so the pick does not jump to another zone under you.
local function ZonesLeft(keep)
    local out, seen = {}, {}
    for _, book in ipairs(ns.LibraryBooks) do
        for _, spot in ipairs(book.spots) do
            local id = spot[1]
            if not seen[id] then
                seen[id] = true
                local n = #L.OnMap(id)
                if n > 0 or id == keep then out[#out + 1] = { id, n } end
            end
        end
    end
    return out
end

-- Points the dropdown at the zones left and returns the one to list: the saved pick, which
-- ZonesLeft keeps even once it runs out, else the first.
local function Pick(left)
    local saved, values, order = S.Get("trackerZone"), {}, {}
    pickedZone = nil
    for _, z in ipairs(left) do
        values[z[1]] = L.ZoneName(z[1]) .. "  " .. ns.Color("muted", "(" .. z[2] .. ")")
        order[#order + 1] = z[1]
        if z[1] == saved then pickedZone = saved end
    end
    pickedZone = pickedZone or left[1][1]
    panel.picker._values, panel.picker._order = values, order
    panel.picker._refreshLabel()
    return pickedZone
end

-- zone is where you stand; left, when given, is the zones for the dropdown, and the list is
-- the picked zone's instead of yours.
local function Render(zone, left)
    local listZone = left and Pick(left) or zone
    panel.picker:SetShown(left ~= nil)
    panel.body:ClearAllPoints()
    panel.body:SetPoint("TOPLEFT", left and panel.picker or panel.bar, "BOTTOMLEFT", 0, -BAR_GAP)
    local entries = {}
    local carried = CarriedByTurnIn()
    for _, kind in ipairs({ "librarian", "trainer" }) do
        for _, place in ipairs({ "bags", "bank" }) do
            local n = carried[kind .. "/" .. place]
            if n then
                local npc = ns.LibraryTurnIns[kind][L.Side()]
                local books = n == 1 and "1 book" or (n .. " books")
                entries[#entries + 1] = {
                    text = "|cffffd100" .. books .. " in your " .. place .. "|r",   -- gold: ready to hand in
                    sub = "Hand in to " .. npc.name .. ", " .. npc.place,
                    waypoint = function() L.WaypointNpc(npc) end,
                }
            end
        end
    end
    local toFind = L.OnMap(listZone)
    if #toFind == 0 then
        entries[#entries + 1] = { text = ns.Color("muted", "No more books in this area.") }
    end
    for _, item in ipairs(toFind) do
        local book, spot = item[1], item[2]
        local sub = L.Where(spot)
        if book.turnIn == "trainer" then sub = sub .. ", mage trainer" end
        entries[#entries + 1] = {
            text = book.name, sub = sub,
            waypoint = function() L.WaypointBook(book, spot) end,
            tip = function()
                GameTooltip:SetText(book.name)
                local c = GetQuestDifficultyColor(book.tier)
                GameTooltip:AddLine(("Level %d"):format(book.tier), c.r, c.g, c.b)
                if spot[5] then GameTooltip:AddLine(spot[5], 1, 1, 1, true) end
                local npc = L.TurnIn(book)
                local hr, hg, hb = SoftBlue(0.3, 0.7, 0.95)
                GameTooltip:AddLine("Hand in to " .. npc.name .. ", " .. npc.place, hr, hg, hb, true)
            end,
        }
    end
    for _, item in ipairs(L.DoneOnMap(listZone)) do
        entries[#entries + 1] = {
            text = ns.Color("muted", item[1].name), done = true,
        }
    end
    panel.title:SetText("LIBRARY BOOKS  " .. ns.Color("muted", L.ZoneName(zone)))
    RenderBar()
    local listH = Layout(entries)
    -- The header, the bar and the dropdown each with the gap under them, the list, then the
    -- cog's footer.
    local pickerH = left and (panel.picker:GetHeight() + BAR_GAP) or 0
    panel:SetHeight(PANEL_HEADER + 4 + BAR_H + BAR_GAP + pickerH + listH + FOOTER + PANEL_PAD)
end

-------------------------------------------------------------------------------
--  When it shows
-------------------------------------------------------------------------------
local shownZone   -- the zone it popped up in; it stays up there until you leave or close it
local lastZone    -- the zone of the last redraw, so entering a zone selects it once

local function Hide()
    shownZone = nil
    if shownEvents then shownEvents:UnregisterAllEvents() end
    if panel then panel:Hide() end
end

-- Without Always Show it pops up on entering a zone with books to find and stays for as
-- long as you are in that zone, even once they are looted. With it, it shows in every zone
-- with the dropdown, until the X or the toggle switches it off. Entering a zone with books
-- selects it; a zone picked from the dropdown after that sticks until you enter another.
local function Refresh()
    if not On() then return Hide() end
    local zone = L.PlayerZone()
    if zone ~= dismissedZone then dismissedZone = nil end
    local here = zone and #L.OnMap(zone) > 0
    local always = S.Get("trackerAlways")
    local entered = zone ~= lastZone
    lastZone = zone
    if always and here and entered and S.Get("trackerZone") ~= zone then
        S.Set("trackerZone", zone)   -- redraws through the Set hook
        return
    end
    local left = zone and always and ZonesLeft(S.Get("trackerZone")) or nil
    if left and #left == 0 then left = nil end
    local stay = panel and panel:IsShown() and shownZone == zone
    local show = zone and not dismissedZone and (always or here or stay)
    if not show then return Hide() end
    if not panel then BuildPanel() end
    Render(zone, left)
    panel:Show()
    shownZone = zone
    -- Looting a book fills your bags; handing one in completes its quest.
    shownEvents:RegisterEvent("BAG_UPDATE_DELAYED")
    shownEvents:RegisterEvent("QUEST_TURNED_IN")
end

-- Loot and turn-ins can fire several events at once; gather them into one redraw.
local redrawQueued
local function QueueRefresh()
    if redrawQueued then return end
    redrawQueued = true
    C_Timer.After(0.2, function()
        redrawQueued = false
        Refresh()
    end)
end

local function Apply()
    if On() then
        if not zoneEvents then
            zoneEvents = CreateFrame("Frame")
            zoneEvents:SetScript("OnEvent", QueueRefresh)
            shownEvents = CreateFrame("Frame")
            shownEvents:SetScript("OnEvent", QueueRefresh)
        end
        zoneEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
        zoneEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    elseif zoneEvents then
        zoneEvents:UnregisterAllEvents()
    end
    Refresh()
end

local OWN_KEYS = { enabled = true, tracker = true, trackerAlways = true, trackerZone = true }

hooksecurefunc(S, "Set", function(key, value)
    if key == "trackerScale" and panel then panel:SetScale(value) end
    if key == "trackerAlpha" and panel then Paint() end
    if not OWN_KEYS[key] then return end
    -- Switching Always Show back on brings the tracker back here, whatever the X closed.
    -- Switching it off closes it, unless the zone you are in has books to find.
    if key == "trackerAlways" then
        -- Switching it on selects the zone you are in, as entering it would.
        if value then dismissedZone, lastZone = nil, nil else shownZone = nil end
    end
    Apply()
end)
hooksecurefunc(ns, "Apply", Apply)

-- Unlock Mode shows it wherever you are, on your zone or the first zone with books for you.
hooksecurefunc(ns, "ShowRaidReminderAnchorConfig", function()
    if not On() then return end
    if not panel then BuildPanel() end
    local zone = L.PlayerZone()
    if not zone or #L.OnMap(zone) == 0 then
        zone = L.Side() == "H" and 1413 or 1436
    end
    Render(zone)
    panel.mover:Show()
    panel:Show()
end)
hooksecurefunc(ns, "HideRaidReminderAnchorConfig", function()
    if panel then
        panel.mover:Hide()
        Refresh()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)
