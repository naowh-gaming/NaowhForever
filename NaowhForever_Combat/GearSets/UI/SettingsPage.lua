-- SettingsPage.lua: the Gear & Trinkets settings page, declared as cards, with the bars' previews.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local G = ns.GearSets
local C, Look = G.C, G.Look

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local PREVIEW_NOTE_GAP = 10
local ADD_TEXT_SIZE, NOTE_SIZE = 14, 12
local BAR_STAGE_H, TRINKET_STAGE_H = 100, 110
local BAR_SIZE_RANGE, TRINKET_SIZE_RANGE, SPACING_RANGE = { 20, 48, 1 }, { 20, 70, 1 }, { 0, 30, 1 }
local ORDER_GEAR_BAR, ORDER_EQUIPPING, ORDER_SWAPS, ORDER_TRINKETS = 10, 15, 20, 30
local SHOW = { { always = "Always", combat = "In Combat", nocombat = "Out of Combat" },
    { "always", "combat", "nocombat" } }
local GROW = ns.Shared.ItemBar.GrowChoice()
local PREVIEW_STATE = { { key = "bar", label = "Bar" } }

local GEAR_OFF = ns.L("Turn on Gear & Trinkets")
local COOLDOWNS_OFF = ns.L("Needs Show Cooldowns")
local TEXT_NO_SETS = ns.L("No gear sets yet: + saves what you wear as one.")
local TEXT_NONE = ns.L("None")
local TEXT_NO_SETS_HEAD = ns.L("No gear sets yet")
local TEXT_DETAIL = ns.L("The same sets as the character sheet's: equip, save, rename or delete them in the Gear Sets window.")

local function GearOn() return S.Get("gearSets") == true end
local function CooldownsOn() return GearOn() and S.Get("trinketCooldown") == true end

local function PreviewButton(parent)
    local btn = CreateFrame("Frame", nil, parent)
    btn.icon, btn.border = Look.Dress(btn)
    return btn
end

local function NewBarPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.row = CreateFrame("Frame", nil, preview)
    preview.row:SetPoint("CENTER")
    preview.buttons = {}
    local add = CreateFrame("Frame", nil, preview.row)
    ns.Solid(add, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(add, G.Style.BLACK)
    add.text = ns.Font(add, ADD_TEXT_SIZE, nil, T.fg)
    add.text:SetPoint("CENTER")
    add.text:SetText("+")
    preview.add = add
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("TOP", preview.row, "BOTTOM", 0, -PREVIEW_NOTE_GAP)
    preview.note:SetText(TEXT_NO_SETS)
    return preview
end

local function PaintBarPreview(preview)
    local size, gap, grow = S.Get("gearBarSize"), S.Get("gearBarSpacing"), S.Get("gearBarGrow")
    local sets = G.Sets()
    for i, set in ipairs(sets) do
        local btn = preview.buttons[i] or PreviewButton(preview.row)
        preview.buttons[i] = btn
        Look.SetButton(btn, set, i, size, gap, grow)
    end
    for i = #sets + 1, #preview.buttons do preview.buttons[i]:Hide() end
    Look.Fit(preview.row, preview.add, #sets, size, gap, grow)
    preview.note:SetShown(#sets == 0)
end

local function NewTrinketPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.row = CreateFrame("Frame", nil, preview)
    preview.row:SetPoint("CENTER")
    preview.slots = {}
    for i = 1, #C.TRINKET_SLOTS do preview.slots[i] = PreviewButton(preview.row) end
    return preview
end

local function PaintTrinketPreview(preview)
    Look.Trinkets(preview.row, preview.slots, S.Get("trinketSize"), S.Get("trinketSpacing"), S.Get("trinketGrow"),
        S.Get("trinketSquare"))
end

local function SetChoices()
    local values, order = { [""] = TEXT_NONE }, { "" }
    for _, set in ipairs(G.Sets()) do
        values[set.name] = set.name
        order[#order + 1] = set.name
    end
    return values, order
end

local TEXT_GEAR_SET, TEXT_GEAR_SETS = ns.L("%d gear set"), ns.L("%d gear sets")

local function SetsText(n)
    return (n == 1 and TEXT_GEAR_SET or TEXT_GEAR_SETS):format(n)
end

local function Headline()
    local sets = G.Sets()
    if #sets == 0 then return TEXT_NO_SETS_HEAD end
    for _, set in ipairs(sets) do
        if set.equipped then return SetsText(#sets) .. ns.L(", wearing ") .. ns.Color("accentSoft", set.name) end
    end
    return SetsText(#sets)
end

local function Detail()
    return TEXT_DETAIL
end

local TEXT_SWAP, TEXT_SWAPS = ns.L("%d swap"), ns.L("%d swaps")
local TEXT_WEAR_IN = ns.L("Wear in %s")

local function SwapSummary(store)
    local n = 0
    for _, key in ipairs(G.SWAP_KEYS) do
        if key ~= "fishingGearSet" and store.Get(key) ~= "" then n = n + 1 end
    end
    for _ in pairs(store.Get("gearForms")) do n = n + 1 end
    if n == 0 then return TEXT_NONE end
    return (n == 1 and TEXT_SWAP or TEXT_SWAPS):format(n)
end

local function SwapRow(key, label, help)
    return { key = key, label = label, choice = SetChoices, needs = GearOn, why = GEAR_OFF, help = help }
end

local SWAP_ROWS = {
    SwapRow("gearMounted", "Wear While Mounted",
        "Put on while you ride, and the set you had on goes back when you dismount."),
    SwapRow("gearDrinking", "Wear While Drinking", "Put on while you drink, and taken off when you stand up."),
    SwapRow("gearDungeon", "Wear in Dungeons", "Put on in a dungeon, and taken off when you leave it."),
    SwapRow("gearRaid", "Wear in Raids", "Put on in a raid, and taken off when you leave it."),
    SwapRow("gearBattleground", "Wear in Battlegrounds", "Put on in a battleground, and taken off when you leave it."),
    SwapRow("gearResting", "Wear While Resting", "Put on in cities and inns, and taken off again when you leave."),
}
local FORMS_GROUP = Settings.Group("Forms and Stances")
local formRows = {}

local function SetForm(spellID, name)
    local forms = CopyTable(S.Get("gearForms"))
    forms[spellID] = name ~= "" and name or nil
    S.Set("gearForms", forms)
end

local function FormRow(spellID)
    local row = formRows[spellID]
    if row then return row end
    row = { key = "gearForms", field = spellID, label = TEXT_WEAR_IN:format(C_Spell.GetSpellName(spellID)),
        choice = SetChoices, needs = GearOn, why = GEAR_OFF,
        help = "Put on in this form or stance, and taken off when you leave it.",
        get = function() return S.Get("gearForms")[spellID] or "" end,
        set = function(name) SetForm(spellID, name) end }
    formRows[spellID] = row
    return row
end

local function SwapRows()
    local rows = { SWAP_ROWS }
    for i = 1, GetNumShapeshiftForms() do
        local spellID = G.FormSpell(i)
        if spellID then
            if #rows == 1 then rows[2] = FORMS_GROUP end
            rows[#rows + 1] = FormRow(spellID)
        end
    end
    return rows
end

local function SizeSummary(key)
    return function(store) return store.Get(key) .. " px" end
end

local function OpenWindow()
    ns.OpenGearSetsWindow()
end

if G.OLD_COPY then return end

local page = Settings.Page(C.PAGE, S)

page:Window({
    text = "Open Gear Sets",
    open = OpenWindow,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "gearBar", name = "Gear Set Bar", order = ORDER_GEAR_BAR, switch = "gearBarVisible",
    help = "A button per set: click to equip, Shift-click to save what you wear into it, Ctrl-click to rename "
        .. "it, right-click to change its icon, and + to save a new one. The set you wear is outlined. Move it "
        .. "in the HUD Editor.",
    summary = SizeSummary("gearBarSize"),
    studio = { height = BAR_STAGE_H, states = PREVIEW_STATE, new = NewBarPreview, paint = PaintBarPreview },
    rows = {
        Settings.Group("Size"),
        { key = "gearBarSize", label = "Button Size", slider = BAR_SIZE_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "How big each set's button is." },
        { key = "gearBarSpacing", label = "Spacing", slider = SPACING_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "The gap between two buttons." },
        { key = "gearBarGrow", label = "Growth Direction", choice = GROW, needs = GearOn, why = GEAR_OFF,
          help = "Which way the bar grows from its first button." },
        Settings.Group("Visibility"),
        { key = "gearBarShow", label = "Show", choice = SHOW, needs = GearOn, why = GEAR_OFF,
          help = "Always, only in combat, or only out of combat." },
    },
})

page:Card({
    id = "equipping", name = "Equipping", order = ORDER_EQUIPPING,
    help = "How a set goes on when you pick one.",
    rows = {
        { key = "gearCombatWeapons", label = "Swap Weapons in Combat", toggle = true, needs = GearOn, why = GEAR_OFF,
          help = "A set's weapons go on at once in combat, and the rest when the fight ends." },
        { key = "gearClickOff", label = "Click Again to Take Off", toggle = true, needs = GearOn, why = GEAR_OFF,
          help = "Clicking the set you wear puts back what you had on before it." },
    },
})

page:Card({
    id = "autoSwap", name = "Automatic Swaps", order = ORDER_SWAPS,
    help = "A set that goes on by itself, and what you had on goes back afterwards.",
    summary = SwapSummary,
    rowsFn = SwapRows,
})

page:Card({
    id = "trinketBar", name = "Trinket Bar", order = ORDER_TRINKETS, switch = "trinketBar",
    help = "Your two trinket slots, movable: left-click to use one, right-click to equip a trinket from your "
        .. "bags outside combat. Move it in the HUD Editor.",
    summary = SizeSummary("trinketSize"),
    studio = { height = TRINKET_STAGE_H, states = PREVIEW_STATE, new = NewTrinketPreview, paint = PaintTrinketPreview },
    rows = {
        { key = "trinketSize", label = "Icon Size", slider = TRINKET_SIZE_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "How big each trinket is." },
        { key = "trinketSpacing", label = "Spacing", slider = SPACING_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "The gap between the two." },
        { key = "trinketGrow", label = "Growth Direction", choice = GROW, needs = GearOn, why = GEAR_OFF,
          help = "Which way the second trinket sits from the first." },
        { key = "trinketCooldown", label = "Show Cooldowns", toggle = true, needs = GearOn, why = GEAR_OFF,
          help = "The trinket's cooldown sweeps over its icon." },
        { key = "trinketCountdown", label = "Cooldown Numbers", toggle = true, needs = CooldownsOn, why = COOLDOWNS_OFF,
          help = "Counts down the time left on the icon." },
        { key = "trinketSquare", label = "Square Icons", toggle = true, needs = GearOn, why = GEAR_OFF,
          help = "Trims the rounded edges off the trinket icons, like the Gear Set Bar's." },
    },
})
