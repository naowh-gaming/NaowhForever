-- Row.lua: a listing's row on the shared row engine: the dungeon, its leader, its spots and the leader's card (ns.GroupFinder.UI.Kinds).
local ns = _G.NaowhForever
local T = ns.THEME

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local Parts, View = ns.Shared.Parts, ns.Shared.View
local Card, Comms, Listings, Browse = GF.Card, GF.Comms, GF.Listings, GF.Browse

local St = UI.Style
local ROW_H, PAD, BAND_W = St.ROW_H, St.ROW_PAD, St.BAND_W
local LINE_1, LINE_2, LINE_3 = St.LINE_1, St.LINE_2, St.LINE_3
local ROLE_ICON, ROLE_GAP, SLOTS_SHOWN = St.ROLE_ICON, St.ROLE_GAP, St.SLOTS_SHOWN
local TEXT_GAP, DETAIL_GAP = St.TEXT_GAP, St.DETAIL_GAP
local DETAIL_X = PAD + SLOTS_SHOWN * (ROLE_ICON + ROLE_GAP) + DETAIL_GAP
local SCORE_TENTHS = 10
local SECONDS_PER_MINUTE, SECONDS_PER_HOUR = 60, 3600
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_COUNT = { TANK = "tanks", HEALER = "healers", DAMAGER = "damage" }
local ROLE_BIT = { TANK = Card.TANK, HEALER = Card.HEALER, DAMAGER = Card.DAMAGE }
local WAITING = UI.WAITING

local TEXT_RANGE = "%d-%d"
local TEXT_SIZE = "%d/%d"
local TEXT_KILLS = ns.L("%d boss kills")
local TEXT_FIRST = ns.L("First time")
local TEXT_QUESTS = ns.L("%d quests")
local TEXT_JUST_NOW = ns.L("just now")
local TEXT_MINUTES = ns.L("%dm ago")
local TEXT_HOURS = ns.L("%dh ago")

local function RowEnter(row) row.hover:Show() end
local function RowLeave(row) row.hover:Hide() end

local function NewRow(view)
    local row = CreateFrame("Frame", nil, view)
    Parts.RowBands(row, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row.band = ns.Solid(row, "ARTWORK", T.fg, 1)
    row.band:SetPoint("TOPLEFT")
    row.band:SetPoint("BOTTOMLEFT")
    row.band:SetWidth(BAND_W)
    row.title = ns.Font(row, St.TITLE_SIZE, nil, T.fg)
    row.title:SetPoint("TOPLEFT", PAD, -LINE_1)
    row.range = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.range:SetPoint("LEFT", row.title, "RIGHT", TEXT_GAP, 0)
    row.class = Parts.ItemIcon(row, St.CLASS_ICON)
    row.class.texture:SetTexture(St.CLASS_ICONS)
    row.class:SetPoint("TOPLEFT", PAD, -LINE_2)
    row.leader = ns.Font(row, St.LINE_SIZE, nil, T.fg)
    row.leader:SetPoint("LEFT", row.class, "RIGHT", TEXT_GAP, 0)
    row.level = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.level:SetPoint("LEFT", row.leader, "RIGHT", TEXT_GAP, 0)
    row.slots = {}
    for i = 1, SLOTS_SHOWN do
        local slot = row:CreateTexture(nil, "ARTWORK")
        slot:SetSize(ROLE_ICON, ROLE_ICON)
        slot:SetPoint("TOPLEFT", PAD + (i - 1) * (ROLE_ICON + ROLE_GAP), -LINE_3)
        row.slots[i] = slot
    end
    row.size = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.size:SetPoint("TOPLEFT", PAD, -LINE_3)
    row.kills = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.kills:SetPoint("TOPLEFT", DETAIL_X, -LINE_3)
    row.quests = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.quests:SetPoint("LEFT", row.kills, "RIGHT", DETAIL_GAP, 0)
    row.score = ns.Font(row, St.SCORE_SIZE, nil, T.fg)
    row.score:SetPoint("TOPRIGHT", -PAD, -LINE_1)
    row.age = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.age:SetPoint("TOPRIGHT", -PAD, -LINE_3)
    return row
end

local function Leader(entry)
    local members = entry.members
    for i = 1, entry.nMembers do
        if members[i].leader then return members[i] end
    end
    return members[1]
end

local function PaintClass(icon, class)
    local coords = class and CLASS_ICON_TCOORDS[class]
    icon.texture:SetShown(coords ~= nil)
    if coords then Parts.ClassCrop(icon.texture, coords) end
end

local function Slot(row, i, atlas)
    local slot = row.slots[i]
    slot:SetAtlas(atlas, false)
    slot:Show()
end

local function PaintSlots(row, entry, activity, leader)
    local size = activity and activity.size or SLOTS_SHOWN
    local slots, n = row.slots, 0
    row.size:SetShown(size > SLOTS_SHOWN)
    if size > SLOTS_SHOWN then
        row.size:SetText(TEXT_SIZE:format(entry.numMembers, size))
    elseif entry.numMembers == 1 and leader then
        for r = 1, #ROLE_ORDER do
            local role = ROLE_ORDER[r]
            local roleBit = ROLE_BIT[role]
            if leader.roles % (roleBit * 2) >= roleBit then
                n = n + 1
                Slot(row, n, St.ROLE_ATLAS[role])
            end
        end
    else
        for r = 1, #ROLE_ORDER do
            local role = ROLE_ORDER[r]
            for _ = 1, entry[ROLE_COUNT[role]] do
                if n < size then
                    n = n + 1
                    Slot(row, n, St.ROLE_ATLAS[role])
                end
            end
        end
        for _ = n + 1, size do
            n = n + 1
            Slot(row, n, St.EMPTY_SLOT)
        end
    end
    for i = n + 1, SLOTS_SHOWN do slots[i]:Hide() end
end

local function Kills(card)
    local total = 0
    for i = 1, card.nKills do total = total + card.kills[i] end
    return total
end

local function PaintCard(row, entry)
    local leader = entry.leader
    local card, waiting
    if leader and Comms.IsMe(leader) then
        card = Card.Mine(entry.dungeon)
    elseif leader then
        card, waiting = Browse.CardOf(leader)
    end
    if card and card.score then
        row.score:SetText(ns.NaowhScore.Colored(card.score / SCORE_TENTHS, card.level))
    else
        row.score:SetText(waiting and WAITING or "")
    end
    local here = card and card.dungeon ~= nil and card.dungeon == entry.dungeon
    if here and card.hasKills then
        local total = Kills(card)
        row.kills:SetText(total > 0 and TEXT_KILLS:format(total) or TEXT_FIRST)
    else
        row.kills:SetText("")
    end
    row.quests:SetText(here and card.hasQuests and card.nHave > 0 and TEXT_QUESTS:format(card.nHave) or "")
end

local function Age(seconds)
    if seconds < SECONDS_PER_MINUTE then return TEXT_JUST_NOW end
    if seconds < SECONDS_PER_HOUR then return TEXT_MINUTES:format(math.floor(seconds / SECONDS_PER_MINUTE)) end
    return TEXT_HOURS:format(math.floor(seconds / SECONDS_PER_HOUR))
end

local function SetRow(row, entry, index)
    row.id, row.index = entry.id, index
    row.stripe:SetShown(index % 2 == 0)
    local activity = entry.activity and Listings.Activity(entry.activity)
    row.title:SetText(activity and activity.name or WAITING)
    row.range:SetText(activity and activity.max > 0 and TEXT_RANGE:format(activity.min, activity.max) or "")
    local leader = Leader(entry)
    local class = leader and leader.class
    local color = class and RAID_CLASS_COLORS[class] or T.fg
    row.band:SetColorTexture(color.r, color.g, color.b, 1)
    PaintClass(row.class, class)
    row.leader:SetText(entry.leader or WAITING)
    row.leader:SetTextColor(color.r, color.g, color.b)
    row.level:SetText(leader and leader.level and tostring(leader.level) or "")
    PaintSlots(row, entry, activity, leader)
    PaintCard(row, entry)
    row.age:SetText(Age(entry.age))
    row:SetAlpha(entry.delisted and St.DELISTED_ALPHA or 1)
    return ROW_H
end

local kinds = View.NewKinds()
kinds.listing = { New = NewRow, Set = SetRow }
UI.Kinds = kinds
