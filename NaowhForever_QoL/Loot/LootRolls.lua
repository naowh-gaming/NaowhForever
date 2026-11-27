-- LootRolls.lua: Loot Rolls, a small window of the group's rolls: who picked Need, Greed or Pass, their roll and the winner.
local ns = _G.NaowhForever

local GetSortedInfoForDrop = C_LootHistory.GetSortedInfoForDrop

local T = ns.THEME
local S = ns.QoLSettings
local UI = ns.UI
local Parts = ns.Shared.Parts
local St = ns.Shared.Style
local STATE = Enum.EncounterLootDropRollState

local MAX_DROPS = 8
local KEEP_SETTLED = 60
local KEEP_OPEN = 300
local MAX_HEIGHT = 360
local WIDTH = St.TRACKER_W
local NEXT_FRAME = 0
local ROLL_ICON = 14
local PLACE = { "BOTTOM", "BOTTOM", 260, 220 }
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Loot & Items", "QoL/Loot & Items:lootRolls"
local EVENTS = { "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_CLEAR_HISTORY" }
local ATLAS = {
    [STATE.NeedMainSpec] = "lootroll-icon-need", [STATE.NeedOffSpec] = "lootroll-icon-need",
    [STATE.Transmog] = "lootroll-icon-transmog", [STATE.Greed] = "lootroll-icon-greed",
    [STATE.Pass] = "lootroll-icon-pass",
}
local TEXT_TITLE = ns.L("LOOT ROLLS")
local TEXT_NAME = "Loot Rolls"
local TEXT_WON = ns.L("Won by %s")
local TEXT_WON_ROLL = ns.L("Won by %s with %s")
local TEXT_ALL_PASSED = ns.L("Everyone passed")
local TEXT_LEADING = ns.L("%s leads with %s")
local TEXT_TIED = ns.L("Tied at %s")
local TEXT_WAITING = ns.L("waiting on %d")
local TEXT_WAITING_ONLY = ns.L("Waiting on %d")
local TEXT_JOIN = "%s, %s"
local TEXT_OFF_SPEC = ns.L("%s (off spec)")
local TEXT_CHOOSING = ns.L("%s is choosing")
local TEXT_ROLL = "%s %s  %s"
local TEXT_HINT = ns.L("Click for everyone's roll, Shift-click to link it.")
local TEXT_HINT_LINK = ns.L("Shift-click to link it.")

local panel, events, unlocked
local drops = {}
local entries, pool = {}, {}
local icons = {}

local function On()
    return S.Get("enabled") and S.Get("lootRolls")
end

local function Settled(info)
    return info.winner ~= nil or info.allPassed == true
end

local function Name(roll)
    local name = roll and roll.playerName
    if not name or issecretvalue(name) then return nil end
    return name
end

local function Icon(state)
    local atlas = ATLAS[state]
    if not atlas then return "" end
    local icon = icons[atlas]
    if not icon then
        icon = CreateAtlasMarkup(atlas, ROLL_ICON, ROLL_ICON)
        icons[atlas] = icon
    end
    return icon
end

local function Waiting(rolls)
    local n = 0
    for i = 1, #rolls do
        if Name(rolls[i]) and rolls[i].state == STATE.NoRoll then n = n + 1 end
    end
    return n
end

local function Won(winner)
    local name = Name(winner)
    if not name then return nil end
    if winner.roll then return TEXT_WON_ROLL:format(name, winner.roll) end
    return TEXT_WON:format(name)
end

local function Leading(info)
    local leader = info.currentLeader
    if not (leader and leader.roll) then return nil end
    if info.isTied then return TEXT_TIED:format(leader.roll) end
    local name = Name(leader)
    return name and TEXT_LEADING:format(name, leader.roll)
end

local function Status(info)
    if info.allPassed then return TEXT_ALL_PASSED end
    if info.winner then return Won(info.winner) end
    local leading, waiting = Leading(info), Waiting(info.rollInfos)
    if waiting == 0 then return leading end
    if not leading then return TEXT_WAITING_ONLY:format(waiting) end
    return TEXT_JOIN:format(leading, TEXT_WAITING:format(waiting))
end

local function RollText(roll, name)
    if roll.state == STATE.NoRoll then return TEXT_CHOOSING:format(name) end
    if roll.state == STATE.NeedOffSpec then name = TEXT_OFF_SPEC:format(name) end
    return TEXT_ROLL:format(Icon(roll.state), roll.roll or "", name)
end

local function DropTip(row)
    GameTooltip:SetHyperlink(row.entry.drop.info.itemHyperlink)
    local hint = S.Get("lootRollsExpanded") and TEXT_HINT_LINK or TEXT_HINT
    GameTooltip:AddLine(hint, T.muted.r, T.muted.g, T.muted.b, true)
end

local Render

local function DropClick(row)
    local drop = row.entry.drop
    if IsModifiedClick() then
        HandleModifiedItemClick(drop.info.itemHyperlink)
        return
    end
    if S.Get("lootRollsExpanded") then return end
    drop.open = not drop.open
    Render()
end

local function Entry(n)
    local entry = pool[n] or {}
    pool[n] = entry
    entries[n] = entry
    return entry
end

local function AddDrop(n, drop)
    local entry = Entry(n)
    local info = drop.info
    entry.drop, entry.text, entry.sub = drop, info.itemHyperlink, Status(info)
    entry.color, entry.done = nil, Settled(info)
    entry.tip, entry.click = DropTip, DropClick
    return n
end

local function AddRolls(n, drop)
    local rolls = drop.info.rollInfos
    for i = 1, #rolls do
        local roll = rolls[i]
        local name = Name(roll)
        if name then
            n = n + 1
            local entry = Entry(n)
            local class = roll.playerClass
            entry.drop, entry.text, entry.sub = nil, RollText(roll, name), nil
            entry.color = roll.state == STATE.NoRoll and T.muted
                or (class and not issecretvalue(class) and RAID_CLASS_COLORS[class]) or nil
            entry.done, entry.tip, entry.click = roll.isWinner == true, nil, nil
        end
    end
    return n
end

local function Redraw()
    if panel:IsShown() then Render() end
end

function Render()
    local all, n = S.Get("lootRollsExpanded"), 0
    for i = #drops, 1, -1 do
        local drop = drops[i]
        if not drop.closed then
            n = AddDrop(n + 1, drop)
            if all or drop.open then n = AddRolls(n, drop) end
        end
    end
    for i = n + 1, #entries do entries[i] = nil end
    if panel:Fit(panel:SetRows(entries)) then
        panel:SetTrackerWidth(WIDTH)
        C_Timer.After(NEXT_FRAME, Redraw)
    end
end

local function Shown()
    for i = 1, #drops do
        if not drops[i].closed then return true end
    end
    return false
end

local function Prune()
    local now = GetTime()
    for i = #drops, 1, -1 do
        local drop = drops[i]
        if (drop.settled and now - drop.settled >= KEEP_SETTLED) or now - drop.seen >= KEEP_OPEN then
            table.remove(drops, i)
        end
    end
    local i = 1
    while #drops > MAX_DROPS and i <= #drops do
        if drops[i].settled then table.remove(drops, i) else i = i + 1 end
    end
end

local function LoadPosition()
    local pos = S.Get("lootRollsPos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("lootRollsPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(frame, onMoved)
    return UI.AttachMover(frame, TEXT_NAME, onMoved, SETTINGS_PAGE, SETTINGS_CARD)
end

local function Close()
    for i = 1, #drops do drops[i].closed = true end
    panel:Hide()
end

local function Build()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        onClose = Close,
        load = LoadPosition, save = SavePosition, place = PLACE,
        mover = Mover,
        maxHeight = function() return MAX_HEIGHT end,
    })
    panel:SetScale(S.Get("lootRollsScale"))
    panel:Place()
    panel:Paint()
    panel:Hide()
end

local function Refresh()
    if not On() or (not Shown() and not unlocked) then
        if panel then panel:Hide() end
        return
    end
    if not panel then Build() end
    Render()
    panel.mover:SetShown(unlocked == true)
    panel:Show()
end

local function Expire()
    Prune()
    Refresh()
end

local function Find(encounterID, key)
    for i = 1, #drops do
        local drop = drops[i]
        if drop.encounterID == encounterID and drop.key == key then return drop end
    end
end

local function OnDrop(encounterID, key)
    if issecretvalue(encounterID) or issecretvalue(key) then return end
    local info = GetSortedInfoForDrop(encounterID, key)
    local link = info and info.itemHyperlink
    if type(link) ~= "string" or issecretvalue(link) then return end
    local drop = Find(encounterID, key)
    if not drop then
        drop = { encounterID = encounterID, key = key, seen = GetTime() }
        drops[#drops + 1] = drop
        C_Timer.After(KEEP_OPEN, Expire)
    end
    drop.info = info
    if Settled(info) and not drop.settled then
        drop.settled = GetTime()
        C_Timer.After(KEEP_SETTLED, Expire)
    end
    Prune()
    Refresh()
end

local function OnEvent(_, event, encounterID, key)
    if event == "LOOT_HISTORY_CLEAR_HISTORY" then
        wipe(drops)
        return Refresh()
    end
    OnDrop(encounterID, key)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        wipe(drops)
        return Refresh()
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if panel then
        panel:SetScale(S.Get("lootRollsScale"))
        panel:Place()
    end
    Refresh()
end

local function OnSettingChanged(key, value)
    if key == "lootRollsScale" and panel then panel:SetScale(value) end
    if key == "lootRollsExpanded" then Refresh() end
    if key == "enabled" or key == "lootRolls" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
ns.OnApply(Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Refresh()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Refresh()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "lootRolls", name = "Loot Rolls", order = 6, switch = "lootRolls",
    help = "A small window of the group's rolls: who picked Need, Greed or Pass, their roll and the winner.",
    rows = {
        { key = "lootRollsExpanded", label = "Show Everyone's Rolls", toggle = true,
          help = "Lists each player's choice under every item, without a click." },
        { key = "lootRollsScale", label = "Scale", slider = St.SCALE_RANGE, unit = "%", scale = St.PERCENT_SCALE,
          help = "How big the window is." },
    },
})
