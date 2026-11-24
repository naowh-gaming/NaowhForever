-- Find.lua: the Find window (/nf find): town services, mailboxes, spirit healers and, with Discovery on, its quests and rares, nearest first, each a click from a waypoint.
local ns = _G.NaowhForever

local Shared = ns.Shared
local Parts, St, View = Shared.Parts, Shared.Style, Shared.View
local T = ns.THEME
local CATEGORIES = ns.TownCategories

local PAGE = "QoL/Interface"
local DISCOVERY = "NaowhForever_Discovery"
local WIDTH, HEIGHT = 460, 560
local HEADER, PAD, FOOTER, SCROLLBAR = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.SCROLLBAR
local SEARCH_H, INSET = St.SEARCH_H, St.CONTENT_INSET
local ICON, ROW_H, GAP, HOVER = St.ICON, St.ITEM_H, St.GAP, St.HOVER
local TEXT_SIZE, SMALL_SIZE = St.TEXT_SIZE, St.SMALL_SIZE
local CARD_INSET = 6
local SEARCH_DROP = 4
local SCROLL_GAP = 4
local VIEW_SPARE = 8
local SECTION_SPACE = 8
local TEXT_GAP = 8
local NAME_TOP = 1
local VALUE_W = 64
local LIMIT = 50
local PERCENT = 100
local STABLE_CLASS = "HUNTER"
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local ICONS = { quest = "Interface\\Icons\\INV_Misc_Note_02", rare = "Interface\\Icons\\Ability_Hunter_SniperShot" }
local NEAREST = { "flight", "inn", "mail", "bank", "auction", "repair", "class", "stable", "spirit" }
local EVENTS = { "ZONE_CHANGED_NEW_AREA", "PLAYER_STOPPED_MOVING" }
local NO_MAP = {}
local SHOWN = {}
for _, kind in ipairs(NEAREST) do SHOWN[kind] = true end

local TEXT_TITLE = ns.L("Find")
local TEXT_SUBTITLE = ns.L("Town services, quests and rares, nearest first. Click one for a waypoint.")
local TEXT_SEARCH = ns.L("Search a name, a service, a quest or a rare")
local TEXT_HINT = ns.L("Type a name or a service: banker, mailbox, flight master, innkeeper, trainer.")
local TEXT_NEAREST = ns.L("Nearest")
local TEXT_PLACES = ns.L("Town Services")
local TEXT_QUESTS, TEXT_RARES = ns.L("Quests"), ns.L("Rares")
local TEXT_NPCS = ns.L("Creatures & Objects")
local TEXT_QUESTS_RARES = ns.L("Quests & Rares")
local TEXT_NO_MATCH = ns.L("Nothing matches your search.")
local TEXT_FIRST_OF = ns.L("The first %d of %d; type more to narrow it down.")
local TEXT_YARDS = ns.L("%d yd")
local TEXT_DISCOVERY_OFF = ns.L("Turn on Discovery to find quests, quest givers and rares too.")
local TEXT_TURN_ON = ns.L("Turn On Discovery")
local TEXT_DETAIL = "%s, %s"

local window, view, search
local filter = ""
local faction, class
local hereCont, hereX, hereY
local withDiscovery
local maps, zones, lowered = {}, {}, {}
local pool, used = {}, 0
local places, quests, rares, creatures = {}, {}, {}, {}
local lists = { place = places, quest = quests, rare = rares, npc = creatures }

local function Fit(map)
    local fit = maps[map]
    if fit then return fit end
    local ok, cont, o = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(0, 0))
    local _, _, u = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(1, 0))
    local _, _, v = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(0, 1))
    if ok and o and u and v then
        local ox, oy = o:GetXY()
        local ux, uy = u:GetXY()
        local vx, vy = v:GetXY()
        fit = { cont = cont, ox = ox, oy = oy, ux = ux - ox, uy = uy - oy, vx = vx - ox, vy = vy - oy }
    else
        fit = NO_MAP
    end
    maps[map] = fit
    return fit
end

local function Distance(map, x, y)
    local fit = Fit(map)
    if not hereCont or fit.cont ~= hereCont then return math.huge end
    x, y = x / PERCENT, y / PERCENT
    local dx = fit.ox + x * fit.ux + y * fit.vx - hereX
    local dy = fit.oy + x * fit.uy + y * fit.vy - hereY
    return math.sqrt(dx * dx + dy * dy)
end

local function ZoneName(map)
    local name = zones[map]
    if not name then
        local info = C_Map.GetMapInfo(map)
        name = info and info.name or ""
        zones[map] = name
    end
    return name
end

local function Add(kind, name, detail, map, x, y, icon)
    used = used + 1
    local hit = pool[used] or {}
    pool[used] = hit
    hit.name, hit.map, hit.x, hit.y = name, map, x, y
    hit.icon = icon or ICONS[kind]
    hit.detail = detail and detail ~= "" and TEXT_DETAIL:format(detail, ZoneName(map)) or ZoneName(map)
    hit.dist = Distance(map, x, y)
    local list = lists[kind]
    list[#list + 1] = hit
end

local function Label(kind) return CATEGORIES[kind][3] end

local function Icon(npc)
    if npc[3] == "class" then return CLASS_ICON .. npc[6]:lower():gsub("^%l", string.upper) end
    return CATEGORIES[npc[3]][2]
end

local function ForMe(npc)
    local kind = npc[3]
    return npc[7]:find(faction, 1, true) and (kind ~= "class" or npc[6] == class)
        and (kind ~= "stable" or class == STABLE_CLASS)
end

local function Lowered(npc)
    local text = lowered[npc]
    if not text then
        text = (npc[4] .. "\n" .. npc[5] .. "\n" .. Label(npc[3])):lower()
        lowered[npc] = text
    end
    return text
end

local function AddNPC(npc, map)
    Add("place", npc[4], npc[5] ~= "" and npc[5] or Label(npc[3]), map, npc[1], npc[2], Icon(npc))
end

local function EachTown(fn)
    for _, source in ipairs({ ns.TownNPCs, ns.TownMailboxes, ns.TownSpiritHealers }) do
        for map, npcs in pairs(source) do
            for _, npc in ipairs(npcs) do
                if ForMe(npc) then fn(npc, map) end
            end
        end
    end
end

local function ByDistance(a, b)
    if a.dist ~= b.dist then return a.dist < b.dist end
    return a.name < b.name
end

local nearest = {}

local function KeepNearest(npc, map)
    if not SHOWN[npc[3]] then return end
    local best = nearest[npc[3]]
    local dist = Distance(map, npc[1], npc[2])
    if dist < math.huge and (not best or dist < best.dist) then
        best = best or {}
        best.npc, best.map, best.dist = npc, map, dist
        nearest[npc[3]] = best
    end
end

local function Matching(npc, map)
    if Lowered(npc):find(filter, 1, true) then AddNPC(npc, map) end
end

local function Gather()
    used = 0
    wipe(places)
    wipe(quests)
    wipe(rares)
    wipe(creatures)
    faction = UnitFactionGroup("player") == "Horde" and "H" or "A"
    class = select(2, UnitClass("player"))
    local wx, wy, _, cont = UnitPosition("player")
    hereCont, hereX, hereY = wx and cont, wx, wy
    if filter == "" then
        wipe(nearest)
        EachTown(KeepNearest)
        for _, kind in ipairs(NEAREST) do
            local best = nearest[kind]
            if best then AddNPC(best.npc, best.map) end
        end
        return
    end
    EachTown(Matching)
    withDiscovery = ns.FindQuestsAndRares ~= nil and ns.FindQuestsAndRares(filter, Add)
    table.sort(places, ByDistance)
    table.sort(quests, ByDistance)
    table.sort(rares, ByDistance)
    table.sort(creatures, ByDistance)
end

local function RowClicked(row)
    local hit = row.hit
    ns.PlaceWaypoint(hit.name, hit.map, hit.x, hit.y)
end

local function RowEnter(row) row.hover:Show() end
local function RowLeave(row) row.hover:Hide() end

local function RowLine(row, size, color, icon, point, iconPoint, y)
    local line = ns.Font(row, size, nil, color)
    line:SetPoint(point, icon, iconPoint, TEXT_GAP, y)
    line:SetPoint("RIGHT", row.value, "LEFT", -GAP, 0)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(false)
    return line
end

local function NewRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    local icon = Parts.ItemIcon(row, ICON)
    icon:SetPoint("LEFT", 0, 0)
    row.icon = icon.texture
    row.value = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.value:SetWidth(VALUE_W)
    row.value:SetPoint("RIGHT", -GAP, 0)
    row.value:SetJustifyH("RIGHT")
    row.name = RowLine(row, TEXT_SIZE, T.fg, icon, "TOPLEFT", "TOPRIGHT", -NAME_TOP)
    row.meta = RowLine(row, SMALL_SIZE, T.muted, icon, "BOTTOMLEFT", "BOTTOMRIGHT", NAME_TOP)
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function SetRow(row, hit)
    row.hit = hit
    row.hover:Hide()
    row.icon:SetTexture(hit.icon)
    row.name:SetText(hit.name)
    row.meta:SetText(hit.detail)
    row.value:SetText(hit.dist < math.huge and TEXT_YARDS:format(hit.dist) or "")
    return ROW_H
end

local kinds = View.NewKinds()
kinds.place = { New = NewRow, Set = SetRow }

local Draw = {}

function Draw:DrawList(title, list)
    if #list == 0 then return end
    self:Section(title, #list)
    for i = 1, math.min(#list, LIMIT) do self:Add("place", list[i]) end
    if #list > LIMIT then self:Note(TEXT_FIRST_OF:format(LIMIT, #list)) end
    self:Space(SECTION_SPACE)
end

function Draw:Redraw()
    self:Clear()
    Gather()
    if filter == "" then
        self:Note(TEXT_HINT)
        self:DrawList(TEXT_NEAREST, places)
    else
        self:DrawList(TEXT_PLACES, places)
        self:DrawList(TEXT_QUESTS, quests)
        self:DrawList(TEXT_RARES, rares)
        self:DrawList(TEXT_NPCS, creatures)
        if #places + #quests + #rares + #creatures == 0 then self:Note(TEXT_NO_MATCH) end
        if not withDiscovery then
            self:NeedsModule(TEXT_QUESTS_RARES, TEXT_DISCOVERY_OFF, DISCOVERY, TEXT_TURN_ON)
        end
    end
    self:Fit(EVENTS)
end

local function OnSearch(text)
    filter = strtrim(text or ""):lower()
    if view then view:Redraw() end
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "findWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE)
    Parts.FooterBrand(window, PAGE)
    local top = HEADER + PAD + SEARCH_DROP
    search = Parts.SearchBox(window, TEXT_SEARCH, OnSearch)
    search:SetPoint("TOPLEFT", INSET, -top)
    search:SetPoint("TOPRIGHT", -INSET, -top)
    search:SetHeight(SEARCH_H)
    local scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -(top + SEARCH_H + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD)
    view = View.New(scroll, kinds, Draw)
    view:SetWidth(WIDTH - INSET - SCROLLBAR - PAD - VIEW_SPARE)
    scroll:SetScrollChild(view)
end

function ns.OpenFind(text)
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
    if text and text ~= "" and text ~= search:GetText() then search:SetText(text) else view:Redraw() end
end

function ns.ToggleFind()
    if window and window:IsShown() then window:Hide() else ns.OpenFind() end
end

ns.RegisterMinimapFeature({
    id = "Find", name = "Find", icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
    open = ns.ToggleFind, tooltip = "Click to open or close Find.",
})

local function OpenFromCard()
    ns.OpenFind()
end

Shared.Settings.Page(PAGE, ns.QoLSettings):Window({
    order = 43,
    text = "Open Find",
    open = OpenFromCard,
    headline = "Find",
    detail = "Search town services, mailboxes, spirit healers, quests and rares, nearest first, and click one for a waypoint.",
})
