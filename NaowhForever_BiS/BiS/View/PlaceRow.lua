-- PlaceRow.lua: a place to run next: where your BiS is, its levels and quests, and a click to go there.
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local R = B.Rankings
local Shared = ns.Shared
local Items, Parts, Places = Shared.Items, Shared.Parts, Shared.Places
local Tip = Parts.Tip
local Cells = B.View.Cells
local St = B.Style

local INSET, ACTION, PLACE_H, NAME_GAP = St.STATUS_W, St.ACTION, St.PLACE_H, St.NAME_GAP
local PLACE_DOT, RED_CODE, TITLE_RGB, ACTION_GAP = St.PLACE_DOT, St.RED_CODE, St.TIP_TITLE_RGB, St.ACTION_GAP
local CARD_DROP = Parts.CARD_DROP
local PLACE_LINK_W, PLACE_COUNT_W, PLACE_GAP = 72, 34, 10
local PIN_Y, LINK_Y, LINK_H = 4, 2, 16
local COLUMN_GAP = 10
local DETAIL_Y = 3
local UP, DOWN = -1, 1
local STAR_MARK = Parts.RankMark(1, CARD_DROP)
local TEXT_UNKNOWN = ns.L("World drop")
local TEXT_BACK = ns.L("Back to BiS List")
local TEXT_YOUR_BIS = ns.L("your BiS")
local TEXT_SELLS, TEXT_DROPS = ns.L(" sells"), ns.L(" drops")
local TEXT_WHERE = "%s %.1f, %.1f"
local TEXT_AROUND, TEXT_AT = ns.L("around"), ns.L("at")
local TEXT_HAS_IT = ns.L("%s it %s.")
local TEXT_IN = ns.L("in ")
local TEXT_OPEN_HINT = ns.L("Click to open it in the Dungeon Journal.")
local TEXT_WAYPOINT_HINT = ns.L("Click to put a waypoint on %s.")
local TEXT_MAP_HINT = ns.L("Click to show %s on your map.")
local TEXT_QUEST, TEXT_QUESTS = ns.L("quest"), ns.L("quests")
local TEXT_OPEN, TEXT_WAYPOINT, TEXT_MAP = ns.L("Open"), ns.L("Waypoint"), ns.L("Map")
local VIA_LINKS = { quest = ns.L("Quest"), recipe = ns.L("Recipe"), faction = ns.L("Open") }
local VIA_WORDS = { quest = "Rewards ", recipe = "Crafts ", faction = "Sells " }
local TEXT_EARLIER, TEXT_LATER = ns.L("Go here earlier"), ns.L("Go here later")

local QuestsText = B.View.Memo("%d %s")
local dungeonsByName
local counts, details = {}, {}

local function JournalDungeon(name)
    local J = ns.Journal
    if not (J and ns.OpenJournalWindow) then return nil end
    if not dungeonsByName then
        dungeonsByName = {}
        for _, dungeon in ipairs(J.Dungeons()) do dungeonsByName[dungeon.english] = dungeon end
    end
    return dungeonsByName[name]
end

local function Waypoint(row)
    local spot = row.spot
    local name = C_Item.GetItemNameByID(row.spotItem)
    ns.PlaceWaypoint(spot.name, spot.map, spot.x, spot.y, name and " (" .. name .. ")",
        C_Item.GetItemIconByID(row.spotItem))
end

local function Go(row)
    if row.place.via then return B.Sources.Go(row.place.via) end
    if row.dungeon then
        B.StepAside("journal")
        ns.OpenJournalWindow(row.dungeon, B.BackFromJournal, TEXT_BACK)
        return
    end
    if row.spot then Waypoint(row) end
    if Places.ShowMap(row.map) then B.StepAside("map") end
end

local function GoLink(link)
    Go(link:GetParent())
end

local function Count(bis)
    local text = counts[bis]
    if not text then
        text = STAR_MARK .. " " .. bis
        counts[bis] = text
    end
    return text
end

local function Drop(id)
    local _, who = R.Place(ns.BiSSource(id) or TEXT_UNKNOWN)
    return who and ns.L(who), C_Item.GetItemNameByID(id), R.Spot(id)
end

local function Has(who, spot)
    return who .. (spot and spot.sells and TEXT_SELLS or TEXT_DROPS)
end

local function Where(spot)
    return TEXT_WHERE:format(spot.roams and TEXT_AROUND or TEXT_AT, spot.x, spot.y)
end

local function FirstSpot(place)
    for _, id in ipairs(place.ids) do
        local spot = R.Spot(id)
        if spot then return id, spot end
    end
end

local function SlotName(slot)
    return Items.SlotName(slot)
end

local function Part(place, dungeon, slot, boss, name, spot, who, seen)
    if place.kind then return (name or TEXT_YOUR_BIS) .. " (" .. SlotName(slot) .. ")" end
    if dungeon then
        if boss and not seen[boss] then
            seen[boss] = true
            who[#who + 1] = boss
        end
        if seen[slot] then return nil end
        seen[slot] = true
        return SlotName(slot)
    end
    return (boss and Has(boss, spot) .. " " or "") .. (name or TEXT_YOUR_BIS)
        .. " (" .. SlotName(slot) .. ")" .. (spot and " " .. Where(spot) or "")
end

local function Joined(place, parts, who, dungeon)
    if place.kind then return VIA_WORDS[place.kind] .. table.concat(parts, ", ") end
    if dungeon then return table.concat(parts, ", ") .. (who[1] and PLACE_DOT .. table.concat(who, ", ") or "") end
    return table.concat(parts, "; ")
end

local function Detail(place, dungeon)
    local byKey = details[place.name]
    if not byKey then
        byKey = {}
        details[place.name] = byKey
    end
    local text = byKey[place.key]
    if text then return text, true end
    local parts, who, seen, loaded = {}, {}, {}, true
    for i, slot in ipairs(place.slots) do
        local boss, name, spot = Drop(place.ids[i])
        loaded = loaded and name ~= nil
        parts[#parts + 1] = Part(place, dungeon, slot, boss, name, spot, who, seen)
    end
    text = Joined(place, parts, who, dungeon)
    if loaded then byKey[place.key] = text end
    return text, loaded
end

local function Levels(dungeon, playerLevel)
    local range = ns.Journal.LevelRange(dungeon)
    if not range then return "" end
    local levels = ns.Journal.Levels(dungeon)
    if playerLevel < levels[1] then return RED_CODE .. range .. "|r" end
    if playerLevel > levels[2] then return ns.Color("muted", range) end
    return range
end

local function Hint(row)
    local via = row.place.via
    if via then return B.Sources.Hint(via) end
    if row.dungeon then return TEXT_OPEN_HINT end
    if row.spot then return TEXT_WAYPOINT_HINT:format(row.spot.name) end
    return row.map and TEXT_MAP_HINT:format(R.PlaceName(row.place.name))
end

local function AddItem(row, slot, id, rank)
    local muted = T.muted
    GameTooltip:AddDoubleLine(Parts.RankMark(rank) .. " " .. Items.QualityHex(id) .. Items.Name(id) .. "|r",
        SlotName(slot), TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b, muted.r, muted.g, muted.b)
    local who, _, spot = Drop(id)
    if who and not (row.dungeon or row.place.via) then
        GameTooltip:AddLine(TEXT_HAS_IT:format(Has(who, spot), spot and Where(spot) or TEXT_IN .. R.PlaceName(row.place.name)),
            muted.r, muted.g, muted.b)
    end
end

local function Enter(row)
    row.hover:Show()
    if not Tip(row, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(R.PlaceName(row.place.name), TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    if row.dungeon and row.dungeon.new then GameTooltip:AddLine(Parts.ForeverLine()) end
    local place = row.place
    for i, slot in ipairs(place.slots) do AddItem(row, slot, place.ids[i], place.ranks[i]) end
    local hint = Hint(row)
    if hint then GameTooltip:AddLine(hint, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b) end
    GameTooltip:Show()
end

local function Leave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function Move(button, step)
    local row = button:GetParent()
    ns.MoveBisRouteStep(row:GetParent().route, row.index, step)
end

local function MoveUp(button) Move(button, UP) end
local function MoveDown(button) Move(button, DOWN) end

local function QuestCount(dungeon)
    if not (dungeon and dungeon.quests) then return 0 end
    local toPickUp, inLog = ns.Journal.Quests.Count(dungeon.quests)
    return toPickUp + inLog
end

local function Pin(row)
    row.pin = row:CreateTexture(nil, "ARTWORK")
    row.pin:SetTexture(St.PIN)
    row.pin:SetSize(ACTION, ACTION)
    row.pin:SetPoint("TOPLEFT", INSET, -PIN_Y)
    row.pin:SetVertexColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
end

local function Columns(row)
    row.open = Parts.Link(row, GoLink, true)
    row.open:SetPoint("TOPRIGHT", -INSET, -LINK_Y)
    local linkSlot = CreateFrame("Frame", nil, row)
    linkSlot:SetSize(PLACE_LINK_W, LINK_H)
    linkSlot:SetPoint("TOPRIGHT", -INSET, -LINK_Y)
    Cells.Gain(row, linkSlot, PLACE_GAP)
    row.count = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.count:SetPoint("RIGHT", row.gain, "LEFT", -PLACE_GAP, 0)
    row.count:SetWidth(PLACE_COUNT_W)
    row.count:SetJustifyH("LEFT")
    row.down = Parts.IconButton(row, MoveDown, St.UP, 0, TEXT_LATER)
    row.down.icon:SetTexCoord(0, 1, 1, 0)
    row.down:SetPoint("RIGHT", row.count, "LEFT", -PLACE_GAP, 0)
    row.up = Parts.IconButton(row, MoveUp, St.UP, 0, TEXT_EARLIER)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -ACTION_GAP, 0)
end

local function New(view)
    local row = CreateFrame("Button", nil, view)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    Pin(row)
    row.name = ns.Font(row, St.NAME_SIZE, nil, T.fg)
    row.name:SetPoint("TOPLEFT", row.pin, "TOPRIGHT", NAME_GAP, 0)
    row.levels = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.levels:SetPoint("LEFT", row.name, "RIGHT", COLUMN_GAP, 0)
    row.quests = ns.Font(row, St.TEXT_SIZE, nil, T.muted)
    row.quests:SetPoint("LEFT", row.levels, "RIGHT", COLUMN_GAP, 0)
    Columns(row)
    row.detail = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -DETAIL_Y)
    row.detail:SetPoint("RIGHT", -INSET, 0)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)
    row:SetScript("OnClick", Go)
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    return row
end

local function LinkText(place, dungeon, spot)
    return VIA_LINKS[place.kind] or dungeon and TEXT_OPEN or spot and TEXT_WAYPOINT or TEXT_MAP
end

local function Set(row, place, index, steps)
    local view = row:GetParent()
    row.place, row.index = place, index
    row.count:SetText(place.bis > 0 and Count(place.bis) or "")
    row.up:SetShown(index ~= nil and index > 1)
    row.down:SetShown(index ~= nil and index < steps)
    Cells.PaintGain(row.gain, place.gain > 0 and place.gain or nil, view.mostPlaceGain)
    local dungeon = not place.via and JournalDungeon(place.name) or nil
    row.dungeon = dungeon
    local name = R.PlaceName(place.name)
    row.name:SetText(dungeon and dungeon.new and name .. Parts.ForeverInline(St.SMALL_SIZE, CARD_DROP) or name)
    row.spotItem, row.spot = nil, nil
    local outdoors = not (dungeon or place.via)
    if outdoors then row.spotItem, row.spot = FirstSpot(place) end
    row.map = outdoors and (row.spot and row.spot.map or Places.Zone(place.name)) or nil
    local detail, loaded = Detail(place, dungeon)
    row.detail:SetText(detail)
    if not loaded then
        for _, id in ipairs(place.ids) do
            if not C_Item.GetItemNameByID(id) then view.waitingFor[id] = true end
        end
    end
    row.levels:SetText(dungeon and Levels(dungeon, view.playerLevel) or "")
    local quests = QuestCount(dungeon)
    row.quests:SetText(quests > 0 and QuestsText(quests, quests == 1 and TEXT_QUEST or TEXT_QUESTS) or "")
    row.open:SetShown(dungeon ~= nil or row.map ~= nil or place.via ~= nil)
    Parts.SetLink(row.open, LinkText(place, dungeon, row.spot))
    return PLACE_H, not loaded
end

B.View.Kinds.place = { New = New, Set = Set }
