-- GlobalCopy.lua: Global Copy, /copy for the text under the cursor, tooltip IDs and the copy cards.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME

local CARD_W = 500
local ACCENT_H = 2
local PAD = 18
local ICON_SIZE, ICON_Y = 40, -20
local ICON_CROP = ns.QoLConstants.ICON_CROP
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local TEXT_X = 70
local KICKER_SIZE, KICKER_Y = 10, -20
local NAME_SIZE, NAME_Y, NAME_RIGHT = 16, -38, -44
local CLOSE_SIZE, CLOSE_INSET = 24, 10
local BOX_W, BOX_H, BOX_INSET = 464, 36, 10
local HINT_SIZE, HINT_BELOW = 12, 49
local ID_CARD_H, ID_BOX_Y = 230, -112
local NOTE_SIZE, NOTE_Y = 10, -187
local LINE_CARD_H, LINE_BOX_Y = 150, -76
local BUTTONS_Y, BUTTON_H, BUTTON_GAP = -76, 26, 8
local ID_BUTTON_W, LINK_BUTTON_W, CLASSIC_BUTTON_W = 170, 140, 90
local VALUE_RGB = { r = 0.85, g = 0.89, b = 0.93 }
local PREVIEW_SPELL = 133
local WOWHEAD = "https://www.wowhead.com/"
local WOWHEAD_FOREVER, WOWHEAD_CLASSIC = "forever/", "classic/"
local LINE_BREAK = "\n"
local TEXT_NOTHING = "No copyable text found."
local TEXT_GLOBAL_COPY = "Global Copy"
local TEXT_IN_COMBAT = "Copy cards are available outside combat."
local TEXT_HINT = "Text selected. Press Ctrl+C to copy."
local TEXT_NOTE = "Open the link in your browser. No page on Forever's Wowhead yet? Try Classic."
local TEXT_ID_KICKER = "NAOWH  /  TOOLTIP COPY"
local TEXT_LINE_KICKER = "NAOWH  /  COPY"
local TEXT_LINK, TEXT_CLASSIC = "Wowhead Link", "Classic"
local TEXT_COPY_HINT = ": copy ID or Wowhead link"
local TEXT_HIDDEN = "Hidden"
local TEXT_PREVIEW_TITLE = "Fireball - Preview"
local SUMMARY_IDS = "%d of %d IDs"
local SUMMARY_COPIES = "%d of %d IDs, %s copies"

local keyboard
local Apply
local decorated = setmetatable({}, { __mode = "k" })
local hints = {}

local function On()
    return S.Get("enabled") and S.Get("globalCopy")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function CanAccess(v)
    return not canaccessvalue or canaccessvalue(v)
end

local function CanAccessAll(...)
    return not canaccessallvalues or canaccessallvalues(...)
end

local function Reapply()
    Apply()
end

local function ShowCopyBox(title, text)
    if not text or text == "" then
        ns.Print(TEXT_NOTHING)
        return
    end
    ns.ShowCopyBox(title, text, Reapply)
end

local function RegionText(region)
    if not region.GetText then return nil end
    local ok, shown = pcall(region.IsVisible, region)
    if not (ok and CanAccess(shown) and shown) then return nil end
    local textOk, text = pcall(region.GetText, region)
    if textOk and CanAccess(text) and text and text ~= "" then return text end
end

local function Collect(target, lines)
    for _, region in ipairs({ target:GetRegions() }) do
        local text = RegionText(region)
        if text then lines[#lines + 1] = text end
    end
    for _, child in ipairs({ target:GetChildren() }) do Collect(child, lines) end
end

local function FrameText(frame)
    if not (frame and frame.GetRegions) then return nil end
    local lines = {}
    if not pcall(Collect, frame, lines) then return nil end
    return lines[1] and table.concat(lines, LINE_BREAK) or nil
end

local function UnderCursor(frame)
    local shown, over, name = frame:IsVisible(), frame:IsMouseOver(), frame:GetName()
    if not CanAccessAll(shown, over, name) then return false end
    return shown and over and name ~= "WorldFrame"
end

local function MouseText()
    local lines = {}
    for _, frame in ipairs(GetMouseFoci()) do
        if frame ~= WorldFrame then lines[#lines + 1] = FrameText(frame) end
    end
    if lines[1] then return table.concat(lines, LINE_BREAK) end
    local frame = EnumerateFrames()
    while frame do
        local ok, use = pcall(UnderCursor, frame)
        if ok and use then lines[#lines + 1] = FrameText(frame) end
        frame = EnumerateFrames(frame)
    end
    return lines[1] and table.concat(lines, LINE_BREAK) or nil
end

local function CopySlash(msg)
    if not On() or InCombatLockdown() then return end
    msg = strtrim(msg or "")
    local named = msg ~= "" and _G[msg]
    local text
    if type(named) == "table" then
        text = FrameText(named)
    else
        text = MouseText()
    end
    ShowCopyBox(msg ~= "" and msg or TEXT_GLOBAL_COPY, text)
end

SLASH_NAOWHFOREVERCOPY1 = "/copy"
SLASH_NAOWHFOREVERCOPY2 = "/ncopy"
SlashCmdList["NAOWHFOREVERCOPY"] = CopySlash

local function Accessible(value)
    return not Secret(value) and CanAccess(value)
end

local TYPES = {
    [Enum.TooltipDataType.Spell] = { kind = "spell", label = "Spell ID", setting = "tooltipSpellID" },
    [Enum.TooltipDataType.Item] = { kind = "item", label = "Item ID", setting = "tooltipItemID" },
    [Enum.TooltipDataType.Unit] = { kind = "npc", label = "NPC ID", setting = "tooltipNPCID" },
}

local function DisplayOn()
    return S.Get("enabled") and S.Get("tooltipDisplay")
end

local function NpcID(data)
    local guid = data.guid
    if not Accessible(guid) then return nil, true end
    if type(guid) ~= "string" then return nil, false, true end
    local kind, _, _, _, _, entry = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil, false, true end
    return tonumber(entry), false
end

local function Resolve(data)
    if not Accessible(data) or (issecrettable and issecrettable(data)) then return end
    if type(data) ~= "table" then return end
    local dataType = data.type
    if not Accessible(dataType) then return end
    local info = TYPES[dataType]
    if not info then return end
    local id
    if info.kind == "npc" then
        local hidden, stop
        id, hidden, stop = NpcID(data)
        if stop then return end
        if hidden then return info, nil, true end
    else
        id = data.id
    end
    if not Accessible(id) then return info, nil, true end
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return end
    return info, id, false
end

local function URL(info, id, classic)
    return WOWHEAD .. (classic and WOWHEAD_CLASSIC or WOWHEAD_FOREVER) .. info.kind .. "=" .. tostring(id)
end

local function NewAccent(p)
    return ns.Solid(p, "OVERLAY", T.accent, 1)
end

local function NewIcon(p)
    return p:CreateTexture(nil, "ARTWORK")
end

local function NewBox(p)
    local edit = CreateFrame("EditBox", nil, p)
    edit:SetAutoFocus(false); edit:SetMultiLine(false)
    edit:SetTextInsets(BOX_INSET, BOX_INSET, 0, 0); edit:SetFontObject("GameFontHighlight")
    ns.Solid(edit, "BACKGROUND", T.bg, 1):SetAllPoints(); ns.Border(edit)
    return edit
end

local function CardHead(panel, texture, kickerText, title)
    local UI = ns.UI
    local accent = UI.Keep(panel, "accent", NewAccent)
    accent:SetPoint("TOPLEFT"); accent:SetPoint("TOPRIGHT"); accent:SetHeight(ACCENT_H)
    local icon = UI.Keep(panel, "icon", NewIcon)
    icon:SetSize(ICON_SIZE, ICON_SIZE); icon:SetPoint("TOPLEFT", PAD, ICON_Y)
    icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    icon:SetTexture(texture or DEFAULT_ICON)
    local kicker = UI.KeepFont(panel, "kicker", KICKER_SIZE, "OUTLINE", T.accent)
    kicker:SetPoint("TOPLEFT", TEXT_X, KICKER_Y); kicker:SetText(kickerText)
    local name = UI.KeepFont(panel, "name", NAME_SIZE, "OUTLINE")
    name:SetPoint("TOPLEFT", TEXT_X, NAME_Y); name:SetPoint("RIGHT", NAME_RIGHT, 0)
    name:SetJustifyH("LEFT"); name:SetWordWrap(false); name:SetText(title)
end

local function Card(key, height, texture, kickerText, title, boxY)
    local UI = ns.UI
    local dimmer, panel = ns.MakeModal(CARD_W, height, key)
    CardHead(panel, texture, kickerText, title)
    UI.KeepButton(panel, "close", "X", CLOSE_SIZE, CLOSE_SIZE, function() dimmer:Hide() end)
        :SetPoint("TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)
    local box = UI.Keep(panel, "value", NewBox)
    box:SetPoint("TOPLEFT", PAD, boxY); box:SetSize(BOX_W, BOX_H)
    box:SetScript("OnEscapePressed", function() box:ClearFocus(); dimmer:Hide() end)
    local hint = UI.KeepFont(panel, "hint", HINT_SIZE, nil, T.muted)
    hint:SetPoint("TOPLEFT", PAD, boxY - HINT_BELOW); hint:SetText(TEXT_HINT)
    return dimmer, panel, box
end

local function CardTexture(info, id)
    local texture
    if info.kind == "spell" then texture = C_Spell.GetSpellTexture(id)
    elseif info.kind == "item" then texture = C_Item.GetItemIconByID(id) end
    if not Accessible(texture) then texture = nil end
    return texture
end

local function ShowIDCard(info, id, title, mode)
    if InCombatLockdown() then return end
    local UI = ns.UI
    local dimmer, panel, box = Card("tooltipCopy", ID_CARD_H, CardTexture(info, id), TEXT_ID_KICKER,
        title or info.label, ID_BOX_Y)
    local note = UI.KeepFont(panel, "note", NOTE_SIZE, nil, T.muted)
    note:SetPoint("TOPLEFT", PAD, NOTE_Y); note:SetWidth(BOX_W); note:SetJustifyH("LEFT")
    note:SetText(TEXT_NOTE)
    local buttons
    local function Select(pick)
        box:SetText(pick == "id" and tostring(id) or URL(info, id, pick == "classic"))
        for key, button in pairs(buttons) do
            local color = key == pick and T.accent or T.muted
            button.label:SetTextColor(color.r, color.g, color.b)
        end
        box:SetFocus(); box:HighlightText()
    end
    buttons = {
        id = UI.KeepButton(panel, "id", info.label .. ": " .. id, ID_BUTTON_W, BUTTON_H, function() Select("id") end),
        url = UI.KeepButton(panel, "link", TEXT_LINK, LINK_BUTTON_W, BUTTON_H, function() Select("url") end),
        classic = UI.KeepButton(panel, "classic", TEXT_CLASSIC, CLASSIC_BUTTON_W, BUTTON_H,
            function() Select("classic") end),
    }
    buttons.id:SetPoint("TOPLEFT", PAD, BUTTONS_Y)
    buttons.url:SetPoint("LEFT", buttons.id, "RIGHT", BUTTON_GAP, 0)
    buttons.classic:SetPoint("LEFT", buttons.url, "RIGHT", BUTTON_GAP, 0)
    dimmer.onClose = function() box:ClearFocus(); Apply() end
    dimmer:Show(); Select(mode or S.Get("tooltipCopyFormat"))
end

function ns.ShowCopyCard(kind, label, id, title, mode)
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT); return end
    ShowIDCard({ kind = kind, label = label }, id, title, mode)
end

function ns.ShowCopyLine(title, text, texture)
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT); return end
    local dimmer, _, box = Card("copyLine", LINE_CARD_H, texture, TEXT_LINE_KICKER, title, LINE_BOX_Y)
    box:SetText(text)
    dimmer.onClose = function() box:ClearFocus() end
    dimmer:Show()
    box:SetFocus(); box:HighlightText()
end

function ns.PreviewTooltipCopyCard()
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT); return end
    ShowIDCard(TYPES[Enum.TooltipDataType.Spell], PREVIEW_SPELL, TEXT_PREVIEW_TITLE)
end

local function Capitalise(first, rest)
    return first:upper() .. rest
end

local function Combo(modifier, key)
    return ((modifier .. "-" .. key):lower():gsub("(%a)(%a*)", Capitalise))
end

local function CopyHint(modifier, key)
    local combo = modifier .. "-" .. key
    local hint = hints[combo]
    if not hint then
        hint = Combo(modifier, key) .. TEXT_COPY_HINT
        hints[combo] = hint
    end
    return hint
end

local function Decorates(tooltip)
    return tooltip == GameTooltip or tooltip == ItemRefTooltip or tooltip == ShoppingTooltip1
        or tooltip == ShoppingTooltip2
end

local function AlreadyDecorated(tooltip, info)
    local at = decorated[tooltip]
    if not (at and at <= tooltip:NumLines()) then return false end
    local left = _G[tooltip:GetName() .. "TextLeft" .. at]
    local text = left and left:GetText()
    return text and not Secret(text) and text == info.label
end

local function Decorate(tooltip, data)
    if not DisplayOn() or tooltip:IsForbidden() then return end
    if not Decorates(tooltip) then return end
    local info, id, hidden = Resolve(data)
    if not info or not S.Get(info.setting) then return end
    if hidden and S.Get("tooltipRestricted") ~= "hidden" then return end
    if AlreadyDecorated(tooltip, info) then return end
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(info.label, hidden and TEXT_HIDDEN or tostring(id), T.accent.r, T.accent.g, T.accent.b,
        VALUE_RGB.r, VALUE_RGB.g, VALUE_RGB.b)
    decorated[tooltip] = tooltip:NumLines()
    if not hidden and S.Get("tooltipCopy") and S.Get("tooltipCopyHint")
        and (tooltip == GameTooltip or tooltip == ItemRefTooltip) then
        tooltip:AddLine(CopyHint(S.Get("tooltipModifier"), S.Get("tooltipKey")), T.muted.r, T.muted.g, T.muted.b)
    end
end

local function Matches(modifier)
    local ctrl = modifier:find("CTRL", 1, true) ~= nil
    local shift = modifier:find("SHIFT", 1, true) ~= nil
    local alt = modifier:find("ALT", 1, true) ~= nil
    return (not not IsControlKeyDown()) == ctrl and (not not IsShiftKeyDown()) == shift
        and (not not IsAltKeyDown()) == alt
end

local function ShownTooltip()
    local tooltip, titleLine = GameTooltip, GameTooltipTextLeft1
    if tooltip:IsForbidden() or not tooltip:IsShown() then
        tooltip, titleLine = ItemRefTooltip, ItemRefTooltipTextLeft1
    end
    if not tooltip or tooltip:IsForbidden() or not tooltip:IsShown() then return nil end
    return tooltip, titleLine
end

local function OnKeyDown(self, key)
    if InCombatLockdown() then return end
    self:SetPropagateKeyboardInput(true)
    if GetCurrentKeyBoardFocus() then return end
    local modern = DisplayOn() and S.Get("tooltipCopy") and key == S.Get("tooltipKey") and Matches(S.Get("tooltipModifier"))
    local legacy = On() and S.Get("copyTooltipIds") and key == S.Get("copyKey") and Matches(S.Get("copyModifier"))
    if not modern and not legacy then return end
    local tooltip, titleLine = ShownTooltip()
    if not tooltip then return end
    local info, id = Resolve(tooltip:GetPrimaryTooltipData())
    if not info or not id or (modern and not S.Get(info.setting)) then return end
    local title = titleLine and titleLine:GetText()
    if not Accessible(title) or type(title) ~= "string" then title = info.label end
    self:SetPropagateKeyboardInput(false)
    if modern then ShowIDCard(info, id, title) else ShowCopyBox(title, tostring(id)) end
    self:EnableKeyboard(false)
end

local function OnKeyUp(self)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
end

function Apply()
    if InCombatLockdown() then return end
    local enabled = (DisplayOn() and S.Get("tooltipCopy")) or (On() and S.Get("copyTooltipIds"))
    if not keyboard and enabled then
        keyboard = CreateFrame("Frame")
        keyboard:SetScript("OnKeyDown", OnKeyDown)
        keyboard:SetScript("OnKeyUp", OnKeyUp)
    end
    if keyboard then keyboard:SetPropagateKeyboardInput(true); keyboard:EnableKeyboard(enabled) end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "globalCopy" or key:find("^copy") or key:find("^tooltip") then Apply() end
end

local function SyncShortcut()
    if S.Get("copyShortcutSynced") then return end
    local db = S.DB()
    db.copyTooltipIds = S.Get("tooltipCopy")
    db.copyModifier = S.Get("tooltipModifier")
    db.copyKey = S.Get("tooltipKey")
    db.copyShortcutSynced = true
end

for dataType in pairs(TYPES) do TooltipDataProcessor.AddTooltipPostCall(dataType, Decorate) end
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
local boot = CreateFrame("Frame")
boot:SetScript("OnEvent", Apply)
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
hooksecurefunc(ns, "Apply", SyncShortcut)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local MODIFIERS = { { CTRL = "Ctrl", SHIFT = "Shift", ALT = "Alt", ["CTRL-SHIFT"] = "Ctrl + Shift",
    ["CTRL-ALT"] = "Ctrl + Alt", ["ALT-SHIFT"] = "Alt + Shift" },
    { "CTRL-SHIFT", "CTRL-ALT", "ALT-SHIFT", "CTRL", "SHIFT", "ALT" } }
local KEY_VALUES, KEY_ORDER = {}, {}
for i = string.byte("A"), string.byte("Z") do
    local letter = string.char(i)
    KEY_VALUES[letter] = letter
    KEY_ORDER[#KEY_ORDER + 1] = letter
end
local KEYS = { KEY_VALUES, KEY_ORDER }
local RESTRICTED = { { hide = "Hide Line", hidden = "Show Hidden" }, { "hide", "hidden" } }
local COPY_FORMAT = { { id = "ID", url = "Wowhead Link" }, { "id", "url" } }
local ID_KEYS = { "tooltipSpellID", "tooltipItemID", "tooltipNPCID" }
local PAIRED = { tooltipCopy = "copyTooltipIds", tooltipModifier = "copyModifier", tooltipKey = "copyKey" }

local Shortcut = {
    Get = function(key) return S.Get(key) end,
    Raw = function(key) return S.Raw(key) end,
    Default = function(key) return S.Default(key) end,
    Set = function(key, value)
        S.Set(key, value)
        S.Set(PAIRED[key], value)
    end,
    OnChange = function() end,
}

local function CopyReachable()
    return S.Get("tooltipDisplay") or S.Get("globalCopy")
end

local function ShortcutOn()
    return S.Get("tooltipCopy") and CopyReachable()
end

local function TooltipSummary(store)
    local shown = 0
    for i = 1, #ID_KEYS do
        if store.Get(ID_KEYS[i]) then shown = shown + 1 end
    end
    if not store.Get("tooltipCopy") then return SUMMARY_IDS:format(shown, #ID_KEYS) end
    return SUMMARY_COPIES:format(shown, #ID_KEYS, Combo(store.Get("tooltipModifier"), store.Get("tooltipKey")))
end

Settings.Page("QoL/Interface", S):Card({
    id = "tooltips", name = "Tooltips", order = 50, switch = "tooltipDisplay",
    help = "Spell, item and NPC IDs at the bottom of tooltips, where the game lets them be read. "
        .. "Hover a spell, item or NPC and press your shortcut to open a copy card with its ID and "
        .. "Wowhead link. Copy cards open outside combat; typing never triggers the shortcut.",
    summary = TooltipSummary,
    rows = {
        Group("IDs"),
        { key = "tooltipSpellID", label = "Show Spell ID", toggle = true },
        { key = "tooltipItemID", label = "Show Item ID", toggle = true },
        { key = "tooltipNPCID", label = "Show NPC ID", toggle = true,
          help = "Creature and vehicle IDs only; never player GUIDs." },
        { key = "tooltipRestricted", label = "Restricted IDs", choice = RESTRICTED,
          help = "An ID the game keeps hidden: Hide Line leaves it off the tooltip, Show Hidden "
              .. "shows the line with Hidden in place of the number." },
        Group("Copy"),
        { key = "tooltipCopy", label = "Copy Shortcut", toggle = true, store = Shortcut, always = true,
          needs = CopyReachable, why = "Needs Tooltips or Copy Command",
          help = "Hover a spell, item or NPC and press the shortcut to copy its ID. With Tooltips "
              .. "on it opens the copy card; with only Copy Command on, a box with the ID." },
        { key = "tooltipCopyHint", label = "Show Shortcut Hint", toggle = true, needs = "tooltipCopy",
          help = "A line under the ID saying which keys copy it (Ctrl-Shift-C: copy ID or Wowhead "
              .. "link). Off, the shortcut still works; the line is just not shown." },
        { key = "tooltipModifier", label = "Modifier", choice = MODIFIERS, store = Shortcut, always = true,
          needs = ShortcutOn, why = "Needs Copy Shortcut" },
        { key = "tooltipKey", label = "Key", choice = KEYS, store = Shortcut, always = true,
          needs = ShortcutOn, why = "Needs Copy Shortcut" },
        { key = "tooltipCopyFormat", label = "Initially Select", choice = COPY_FORMAT, needs = "tooltipCopy",
          help = "What the copy card has selected when it opens." },
        { label = "Preview Copy Card", button = ns.PreviewTooltipCopyCard, buttonText = "Preview",
          always = true, help = "Opens the copy card on a sample spell. Select the ID or link, then Ctrl+C." },
        { key = "globalCopy", label = "Copy Command", toggle = true, always = true,
          help = "/copy puts the text of whatever is under your cursor in a box you can copy from. "
              .. "/copy followed by a frame name copies that frame's text instead." },
    },
})
