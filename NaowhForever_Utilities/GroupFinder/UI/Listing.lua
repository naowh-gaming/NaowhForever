-- Listing.lua: the panel beside the game's Listing screen: what Naowh Forever players are told about your group, the players who applied with Invite and Decline, and your party (ns.GroupFinder.UI.Listing).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms, Group = GF.Card, GF.Comms, GF.Group
local UI = GF.UI
local St = UI.Style
local T = ns.THEME
local Style = ns.Shared.Style

local SLOTS = 5
local SHOWN_MAX = 12
local SCORE_STEP, SCORE_MAX = 5, 300
local PARTY_UNITS = 4
local TEXT_LOOKING = "Looking for"
local TEXT_MIN = "Minimum Gear Score"
local TEXT_NOTE = "Note"
local TEXT_NOTE_HINT = "What should applicants know?"
local TEXT_ONLY_NF = ns.L("Only Naowh Forever players see these. The game's own comment box cannot be filled by an addon.")
local TEXT_APPLICANTS = "Applicants"
local TEXT_BEST = ns.L("best Gear Score first")
local TEXT_NOT_LISTED = ns.L("List your group with the game's button on the left. Naowh Forever players who apply show here.")
local TEXT_NOT_LEADER = ns.L("Only your group's leader sees who applied.")
local TEXT_NONE = ns.L("No one has applied yet.")
local TEXT_PARTY = ns.L("Your party %d/%d")
local TEXT_INVITE = "Invite"
local TEXT_DECLINE = "Decline"
local TEXT_INVITED = ns.L("Invited as %s, waiting")
local TEXT_INVITE_AS = ns.L("Invite as")
local TEXT_FULL = ns.L("No %s spot open. Raise Looking For above, or pick another role.")
local TEXT_UNDER = ns.L("Under your minimum of %.1f")
local TEXT_SUB = ns.L("%s %s %d")
local TEXT_KILLS = ns.L("%d boss kills here")
local TEXT_FIRST = ns.L("first time here")
local TEXT_BIS = ns.L("BiS %d/%d")
local TEXT_QUESTS = ns.L("%d quests needed")
local TEXT_DOT = ns.Shared.Style.PLACE_DOT
local TEXT_ANY = ns.L("Any")
local TEXT_SCORE = "%.1f"
local TEXT_COUNT = ns.L("%d/%d")
local TEXT_MORE = ns.L("%d more")
local NEED_MAX = 4
local TEXT_NO_ROLE = ns.L("They applied without a role, so they cannot be invited from here.")
local TEXT_LEVEL = ns.L("%s %d")
local ROLE_OF = { TANK = Card.TANK, HEALER = Card.HEALER, DAMAGER = Card.DAMAGE }

local Listing = {}
UI.Listing = Listing

local view
local order, subParts = {}, {}

local function ByScore(a, b)
    return (a.card.score or -1) > (b.card.score or -1)
end

local function Sub(card)
    wipe(subParts)
    local spec = card.spec and card.spec:match("^([^%-]+)") or ""
    spec = (spec:gsub("^%l", string.upper))
    local class = GetClassInfo(card.class) or ""
    subParts[1] = TEXT_SUB:format(spec, class, card.level)
    if card.hasKills then
        local total = 0
        for i = 1, card.nKills do total = total + card.kills[i] end
        subParts[#subParts + 1] = total > 0 and TEXT_KILLS:format(total) or TEXT_FIRST
    end
    if card.bisTotal then subParts[#subParts + 1] = TEXT_BIS:format(card.bisHave, card.bisTotal) end
    if card.hasQuests and card.nNeed > 0 then subParts[#subParts + 1] = TEXT_QUESTS:format(card.nNeed) end
    return table.concat(subParts, TEXT_DOT)
end

local function NewApplicant()
    local box = CreateFrame("Frame", nil, view)
    ns.Solid(box, "BACKGROUND", T.fg, Style.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(box, Style.BORDER_RGB)
    box.band = ns.Solid(box, "ARTWORK", T.fg, 1)
    box.band:SetPoint("TOPLEFT")
    box.band:SetPoint("BOTTOMLEFT")
    box.band:SetWidth(St.APPLICANT_BAND)
    box.class = box:CreateTexture(nil, "ARTWORK")
    box.class:SetTexture(Style.CLASS_ICONS)
    box.class:SetSize(St.CLASS_ICON, St.CLASS_ICON)
    box.class:SetPoint("TOPLEFT", St.CARD_PAD, -St.CARD_PAD)
    box.name = ns.Font(box, St.LINE_SIZE)
    box.name:SetPoint("LEFT", box.class, "RIGHT", St.GAP, 0)
    box.score = ns.Font(box, St.SCORE_SIZE)
    box.score:SetPoint("RIGHT", box, "TOPRIGHT", -St.CARD_PAD, -St.CARD_PAD - St.CLASS_ICON / 2)
    box.sub = UI.Wrapped(box, St.SUB_SIZE, T.muted)
    box.sub:SetPoint("TOPLEFT", box.class, "BOTTOMLEFT", 0, -St.ROW_LINE_GAP)
    box.sub:SetPoint("RIGHT", -St.CARD_PAD, 0)
    box.roles = {}
    for i, role in ipairs(UI.ROLES) do
        local button = UI.RoleButton(box, role, function()
            box.record.as = role
            Listing.Refresh()
        end)
        ns.Tooltip(button, TEXT_INVITE_AS, UI.ROLE_LABEL[role])
        box.roles[i] = button
    end
    box.invite = ns.PrimaryButton(ns.Button(box, TEXT_INVITE, St.APPLICANT_BUTTON_W, St.ROLE_BUTTON, function()
        Group.Invite(box.record)
    end))
    box.decline = ns.Button(box, TEXT_DECLINE, St.APPLICANT_BUTTON_W, St.ROLE_BUTTON, function()
        Group.Decline(box.record)
    end)
    box.decline:SetPoint("TOPRIGHT", box, "TOPRIGHT", -St.CARD_PAD, 0)
    box.invite:SetPoint("RIGHT", box.decline, "LEFT", -St.GAP / 2, 0)
    box.note = UI.Wrapped(box, St.SUB_SIZE)
    box.state = UI.Wrapped(box, St.SUB_SIZE)
    return box
end

local function PaintApplicant(box, record)
    box.record = record
    local card = record.card
    local _, classFile = GetClassInfo(card.class)
    local color = UI.ClassColor(classFile)
    box.band:SetColorTexture(color.r, color.g, color.b, 1)
    local coords = classFile and CLASS_ICON_TCOORDS[classFile]
    box.class:SetShown(coords ~= nil)
    if coords then ns.Shared.Parts.ClassCrop(box.class, coords) end
    box.name:SetText(Ambiguate(record.name, "none"))
    box.name:SetTextColor(color.r, color.g, color.b)
    box.score:SetText(card.score and UI.Score(card.score, card.level) or "")
    local sub = Sub(card)
    if Group.min > 0 and (card.score or 0) < Group.min then
        sub = sub .. TEXT_DOT .. Style.RED_CODE .. TEXT_UNDER:format(Group.min / UI.TENTHS) .. "|r"
    end
    box.sub:SetText(sub)
    local y = St.CARD_PAD + St.CLASS_ICON + St.ROW_LINE_GAP + math.ceil(box.sub:GetStringHeight()) + St.GAP
    local fits, role = Group.Fits(record)
    local x = St.CARD_PAD
    for _, button in ipairs(box.roles) do
        local offered = Card.Has(card.roles, button.role)
        button:SetShown(offered)
        if offered then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", box, "TOPLEFT", x, -y)
            x = x + St.ROLE_BUTTON + St.GAP / 2
            UI.PaintRole(button, button.role == role)
            button:SetEnabled(not record.invited)
        end
    end
    box.decline:ClearAllPoints()
    box.decline:SetPoint("TOPRIGHT", box, "TOPRIGHT", -St.CARD_PAD, -y)
    box.invite:SetShown(not record.invited)
    box.decline:SetShown(not record.invited)
    box.invite:SetEnabled(fits)
    box.invite:SetAlpha(fits and 1 or St.DIM_ALPHA)
    box.state:ClearAllPoints()
    if record.invited then
        box.state:SetPoint("LEFT", box, "TOPLEFT", x + St.GAP, -y - St.ROLE_BUTTON / 2)
        box.state:SetPoint("RIGHT", -St.CARD_PAD, 0)
        box.state:SetText(TEXT_INVITED:format(UI.ROLE_WORD[record.as] or ""))
        box.state:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        box.state:Show()
    end
    y = y + St.ROLE_BUTTON + St.GAP
    if record.note and record.note ~= "" then
        box.note:SetText(record.note)
        box.note:ClearAllPoints()
        box.note:SetPoint("TOPLEFT", St.CARD_PAD, -y)
        box.note:SetPoint("RIGHT", -St.CARD_PAD, 0)
        box.note:Show()
        y = y + math.ceil(box.note:GetStringHeight()) + St.GAP
    else
        box.note:Hide()
    end
    if not fits and not record.invited then
        box.state:SetPoint("TOPLEFT", St.CARD_PAD, -y)
        box.state:SetPoint("RIGHT", -St.CARD_PAD, 0)
        box.state:SetText(role and TEXT_FULL:format(UI.ROLE_WORD[role]) or TEXT_NO_ROLE)
        box.state:SetTextColor(Style.RED_RGB.r, Style.RED_RGB.g, Style.RED_RGB.b)
        box.state:Show()
        y = y + math.ceil(box.state:GetStringHeight()) + St.GAP
    elseif not record.invited then
        box.state:Hide()
    end
    return y + St.CARD_PAD - St.GAP
end

local function NeedStepper(role)
    local key = Group.NEED_KEY[role]
    local stepper = UI.Stepper(view, UI.ROLE_LABEL[role], function() return Group[key] end, function(v)
        Group[key] = v
        Group.Changed()
    end, 1, 0, NEED_MAX)
    stepper.icon = stepper:CreateTexture(nil, "ARTWORK")
    stepper.icon:SetAtlas(St.ROLE_MICRO[role])
    stepper.icon:SetSize(St.SQUARE_ICON, St.SQUARE_ICON)
    stepper.icon:SetPoint("LEFT")
    stepper.label:ClearAllPoints()
    stepper.label:SetPoint("LEFT", stepper.icon, "RIGHT", St.GAP, 0)
    return stepper
end

local function Build(parent)
    view = CreateFrame("Frame", nil, parent)
    view.stack = UI.Stack(view)
    view.lookingKicker = UI.Kicker(view, TEXT_LOOKING)
    view.needs = {}
    for i, role in ipairs(UI.ROLES) do view.needs[i] = NeedStepper(role) end
    view.min = UI.Stepper(view, TEXT_MIN, function() return Group.min end, function(v)
        Group.min = v
        Group.Changed()
    end, SCORE_STEP, 0, SCORE_MAX)
    view.min.Refresh = function()
        view.min.value:SetText(Group.min > 0 and TEXT_SCORE:format(Group.min / UI.TENTHS) or TEXT_ANY)
    end
    view.noteHead = CreateFrame("Frame", nil, view)
    UI.Kicker(view.noteHead, TEXT_NOTE):SetPoint("LEFT")
    view.counter = ns.Font(view.noteHead, St.SUB_SIZE, nil, T.muted)
    view.counter:SetPoint("RIGHT")
    view.note = UI.EditLine(view, TEXT_NOTE_HINT, Card.NOTE_MAX, function(text)
        if view.filling then return end
        Group.note = Card.CleanNote(text)
        view.counter:SetText(TEXT_COUNT:format(#text, Card.NOTE_MAX))
    end)
    view.only = UI.Wrapped(view, St.SUB_SIZE, T.muted)
    view.only:SetText(TEXT_ONLY_NF)
    view.appHead = CreateFrame("Frame", nil, view)
    UI.Kicker(view.appHead, TEXT_APPLICANTS):SetPoint("LEFT")
    view.best = ns.Font(view.appHead, St.SUB_SIZE, nil, T.muted)
    view.best:SetPoint("RIGHT")
    view.best:SetText(TEXT_BEST)
    view.empty = UI.Wrapped(view, St.LINE_SIZE, T.muted)
    view.more = ns.Font(view, St.SUB_SIZE, nil, T.muted)
    view.more:SetJustifyH("LEFT")
    view.boxes = {}
    view.partyKicker = UI.Kicker(view)
    view.lines = {}
    for i = 1, SLOTS do view.lines[i] = UI.MemberLine(view) end
    return view
end

local function Party(stack)
    local n = 0
    for i = 1, SLOTS do view.lines[i]:Hide() end
    local function Add(unit)
        local name = GetUnitName(unit, true)
        if type(name) ~= "string" or issecretvalue(name) then return end
        local _, class = UnitClass(unit)
        local assigned = UnitGroupRolesAssigned(unit)
        if issecretvalue(assigned) then assigned = "NONE" end
        local role = ROLE_OF[assigned] or Card.DAMAGE
        local leads = UnitIsGroupLeader(unit)
        n = n + 1
        local className = class and LOCALIZED_CLASS_NAMES_MALE[class]
        UI.PaintMember(view.lines[n], role, Ambiguate(name, "none"), class,
            className and TEXT_LEVEL:format(className, UnitLevel(unit)) or "", not issecretvalue(leads) and leads)
        stack:Put(view.lines[n], St.MEMBER_H, 0)
    end
    Add("player")
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        for i = 1, PARTY_UNITS do
            if UnitExists("party" .. i) then Add("party" .. i) end
        end
    end
end

local function HideAll()
    for _, region in ipairs({ view.empty, view.more }) do region:Hide() end
    for _, box in ipairs(view.boxes) do box:Hide() end
end

function Listing.Refresh()
    if not (view and view:IsShown()) then return end
    HideAll()
    local stack = view.stack
    stack:Reset()
    stack:Put(view.lookingKicker, St.KICKER_SIZE + 2, St.GAP)
    for _, stepper in ipairs(view.needs) do
        stepper.Refresh()
        stack:Put(stepper, St.SMALL_BUTTON_H, St.GAP / 2)
    end
    stack:Space(St.GAP)
    if not ns.CHINA then
        view.min.Refresh()
        stack:Put(view.min, St.SMALL_BUTTON_H, St.PANEL_GAP)
    end
    view.counter:SetText(TEXT_COUNT:format(#Group.note, Card.NOTE_MAX))
    stack:Put(view.noteHead, St.KICKER_SIZE + 2, St.GAP)
    if view.note:GetText() ~= Group.note and not view.note:HasFocus() then
        view.filling = true
        view.note:SetText(Group.note)
        view.filling = false
    end
    stack:Put(view.note, St.EDIT_H, St.GAP)
    stack:Text(view.only, St.PANEL_GAP)
    stack:Put(view.appHead, St.KICKER_SIZE + 2, St.GAP)
    if not Group.Listed() then
        view.empty:SetText(TEXT_NOT_LISTED)
        stack:Text(view.empty, St.PANEL_GAP)
    elseif not Group.CanEdit() then
        view.empty:SetText(TEXT_NOT_LEADER)
        stack:Text(view.empty, St.PANEL_GAP)
    else
        wipe(order)
        for _, record in ipairs(Comms.applicants) do order[#order + 1] = record end
        table.sort(order, ByScore)
        if #order == 0 then
            view.empty:SetText(TEXT_NONE)
            stack:Text(view.empty, St.PANEL_GAP)
        end
        for i = 1, math.min(#order, SHOWN_MAX) do
            local box = view.boxes[i] or NewApplicant()
            view.boxes[i] = box
            local height = PaintApplicant(box, order[i])
            stack:Put(box, height, St.APPLICANT_GAP)
        end
        if #order > SHOWN_MAX then
            view.more:SetText(TEXT_MORE:format(#order - SHOWN_MAX))
            stack:Text(view.more, St.PANEL_GAP)
        end
    end
    local members = IsInGroup(LE_PARTY_CATEGORY_HOME) and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) or 1
    view.partyKicker:SetText(TEXT_PARTY:format(members, SLOTS))
    stack:Put(view.partyKicker, St.KICKER_SIZE + 2, St.GAP)
    Party(stack)
    return stack:Finish()
end

function Listing.Build(parent)
    return Build(parent)
end
