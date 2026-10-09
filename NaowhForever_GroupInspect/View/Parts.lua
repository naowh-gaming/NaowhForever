-- Parts.lua: the pieces Group Inspect's cards, rows and preview share: icons, pills, badges, gear.
local ns = _G.NaowhForever

local GetItemIconByID = C_Item.GetItemIconByID

local T = ns.THEME
local S = ns.QoLSettings
local GI = ns.GroupInspect
local UI = GI.UI
local St = UI.Style
local Parts, Items = ns.Shared.Parts, ns.Shared.Items

local BORDER_RGB, WARN_RGB = St.BORDER_RGB, St.WARN_RGB
local TITLE_RGB = { r = 1, g = 1, b = 1 }
local VERSION_MAX = 24
local BIS_RANK = 1
local RUNS_NF, VERSION = "Runs Naowh Forever", "Version %s"
local OLDER = "Older than yours (%s): ask them to update."
local NO_ENCHANT, EMPTY, NOT_READ = "No enchant", "Empty", "Not inspected yet"
local THEIR_BIS = "Their BiS"
local NF = "NF"
local BARE = { color = WARN_RGB, tip = NO_ENCHANT }

local parts = {}
local emptyArt = {}
local theirBis

function UI.FitName(fs, text, maxW, size, minSize)
    local path = ns.UIFontPath()
    fs:SetWidth(maxW)
    if fs.fitSize ~= size then
        fs.fitSize = size
        fs:SetFont(path, size, "")
    end
    fs:SetText(text)
    local width = fs:GetUnboundedStringWidth()
    while width > maxW and size > minSize do
        size = size - 1
        fs.fitSize = size
        fs:SetFont(path, size, "")
        width = fs:GetUnboundedStringWidth()
    end
    return math.min(width, maxW)
end

function UI.ClassIcon(parent, size)
    local icon = Parts.ItemIcon(parent, size)
    icon.texture:SetTexture(St.CLASS_ICONS)
    return icon
end

function UI.PaintClass(icon, classFile)
    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    icon.texture:SetShown(coords ~= nil)
    if not coords then return end
    local crop = St.CLASS_CROP
    icon.texture:SetTexCoord(coords[1] + crop, coords[2] - crop, coords[3] + crop, coords[4] - crop)
end

function UI.RoleIcon(parent, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:Hide()
    return icon
end

function UI.PaintRole(icon, role)
    local atlas = role and St.ROLE_ATLAS[role]
    icon:SetShown(atlas ~= nil)
    if atlas then icon:SetAtlas(atlas) end
    return atlas ~= nil
end

function UI.Kicker(parent, text)
    local kicker = ns.Font(parent, St.KICKER_SIZE, nil, T.accentSoft)
    kicker:SetText(text)
    return kicker
end

local function Older(theirs, mine)
    if type(theirs) ~= "string" or type(mine) ~= "string" then return false end
    wipe(parts)
    for n in mine:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    local i = 0
    for n in theirs:gmatch("%d+") do
        i = i + 1
        local a, b = tonumber(n), parts[i]
        if b == nil then return false end
        if a ~= b then return a < b end
    end
    return i < #parts
end

UI.Older = Older

function UI.PaintNFPill(pill, rec)
    local old = rec and rec.hasNF == true and Older(rec.nfVersion, ns.CODE_BUILD)
    Parts.ColorPill(pill, old and St.WARN_RGB or T.accent)
end

local function PillEnter(pill)
    if GameTooltip:IsForbidden() or not Parts.Tip(pill, "ANCHOR_TOP") then return end
    local guid = pill.holder.guid
    local rec = guid and GI.Member(guid)
    GameTooltip:SetText(RUNS_NF, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    local version = rec and ns.PlainText(rec.nfVersion, VERSION_MAX)
    if version and version ~= "" then
        GameTooltip:AddLine(VERSION:format(version), T.muted.r, T.muted.g, T.muted.b)
        if Older(rec.nfVersion, ns.CODE_BUILD) then
            local w = St.WARN_RGB
            GameTooltip:AddLine(OLDER:format(ns.PlainText(ns.CODE_BUILD, VERSION_MAX)), w.r, w.g, w.b, true)
        end
    end
    GameTooltip:Show()
end

function UI.NFPill(parent, holder)
    local pill = Parts.Pill(parent, St.PILL_SIZE, T.accent)
    pill.color = T.accent
    Parts.SetPill(pill, NF)
    pill.holder = holder
    pill:EnableMouse(true)
    pill:SetScript("OnEnter", PillEnter)
    pill:SetScript("OnLeave", GameTooltip_Hide)
    pill:Hide()
    return pill
end

local function BadgesOn()
    if ns.FEATURE_BADGES == 1 then return S.Get("badgeChat") == true end
    return S.Default("badgeChat") == true
end

function UI.BadgeOf(guid)
    if not (guid and ns.BadgeOf and BadgesOn()) then return nil end
    return ns.BadgeOf(guid)
end

local function BadgeEnter(badge)
    if GameTooltip:IsForbidden() then return end
    local tier = UI.BadgeOf(badge.holder.guid)
    if not (tier and Parts.Tip(badge, "ANCHOR_TOP")) then return end
    GameTooltip:SetText(tier.tooltipLine or tier.title or "", TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    if tier.about then GameTooltip:AddLine(tier.about, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

function UI.Badge(parent, holder)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(St.BADGE, St.BADGE)
    badge.icon = Parts.Smooth(badge:CreateTexture(nil, "ARTWORK"))
    badge.icon:SetAllPoints()
    badge.holder = holder
    badge:EnableMouse(true)
    badge:SetScript("OnEnter", BadgeEnter)
    badge:SetScript("OnLeave", GameTooltip_Hide)
    badge:Hide()
    return badge
end

function UI.PaintBadge(badge, guid)
    local tier = UI.BadgeOf(guid)
    local texture = tier and tier.chat
    badge:SetShown(texture ~= nil)
    if texture then badge.icon:SetTexture(texture) end
    return texture ~= nil
end

local function NameEnter(hit)
    if GameTooltip:IsForbidden() then return end
    local guid = hit.holder.guid
    local rec = guid and GI.Member(guid)
    if not (rec and Parts.Tip(hit, "ANCHOR_TOP")) then return end
    local color = UI.ClassColor(rec.classFile)
    GameTooltip:SetText(rec.name or UI.WAITING, color.r, color.g, color.b)
    GameTooltip:AddLine(UI.LevelText(rec.level, rec.classFile), T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

function UI.NameHit(parent, holder)
    local hit = CreateFrame("Frame", nil, parent)
    hit.holder = holder
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", NameEnter)
    hit:SetScript("OnLeave", GameTooltip_Hide)
    return hit
end

local function TheirBis()
    theirBis = theirBis or Parts.RankMark(BIS_RANK) .. " " .. St.BIS_CODE .. THEIR_BIS .. "|r"
    return theirBis
end

local function GearEnter(icon)
    if GameTooltip:IsForbidden() then return end
    local guid = icon.holder.guid
    local rec = guid and GI.Member(guid)
    local entry = rec and rec.gear and rec.gear[icon.slot]
    if not Parts.Tip(icon, "ANCHOR_RIGHT") then return end
    if entry and entry.link then
        GameTooltip:SetHyperlink(entry.link)
        if entry.bis then GameTooltip:AddLine(TheirBis()) end
        if entry.enchanted == false then GameTooltip:AddLine(NO_ENCHANT, WARN_RGB.r, WARN_RGB.g, WARN_RGB.b) end
    else
        GameTooltip:SetText(Items.SLOT_NAME[icon.slot] or "", TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
        GameTooltip:AddLine(rec and rec.gear and EMPTY or NOT_READ, T.muted.r, T.muted.g, T.muted.b)
    end
    GameTooltip:Show()
end

function UI.GearIcon(parent, size, slot, holder, marks)
    local icon = Parts.ItemIcon(parent, size)
    icon.slot, icon.holder = slot, holder
    if marks then icon.marks = Parts.ItemMarks(icon, size) end
    icon.bare = ns.BiS.View.EnchantBadge(icon, BARE)
    icon.bare:EnableMouse(false)
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", GearEnter)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    return icon
end

local function EmptyArt(slot)
    local art = emptyArt[slot]
    if art == nil then
        local info = C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfoForInvSlot
        art = info and select(2, info(slot)) or false
        emptyArt[slot] = art
    end
    return art or nil
end

function UI.PaintGear(icon, entry)
    local texture = icon.texture
    local id = entry and entry.id
    if id then
        texture:SetTexture(GetItemIconByID(id))
        texture:SetAlpha(1)
        local quality = entry.quality and ITEM_QUALITY_COLORS[entry.quality]
        local edge = quality or BORDER_RGB
        icon.edge:SetColor(edge.r, edge.g, edge.b, 1)
        icon.bare:SetShown(entry.enchanted == false)
    else
        texture:SetTexture(EmptyArt(icon.slot))
        texture:SetAlpha(St.EMPTY_ALPHA)
        icon.edge:SetColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
        icon.bare:Hide()
    end
    if icon.marks then
        Parts.PaintItemMarks(icon.marks, id and entry.ilvl, id and entry.bis and BIS_RANK or nil,
            id ~= nil and Parts.IsForever("items", id))
    end
end
