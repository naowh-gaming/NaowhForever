-- Toast.lua: a toast (Parts.Toast): a box you can drag, with the logo, a title, a line, a row of icons and buttons, gone by itself after a while.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local PAD = 18
local ICON, ICON_GAP = 30, 6
local LOGO = 26
local LOGO_FILE = "LogoAddon.tga"
local TITLE_GAP, LINE_GAP = 10, 12
local ICONS_GAP, BUTTONS_GAP = 12, 14
local BUTTON_H, BUTTON_GAP = 28, 8
local FONT_TITLE, FONT_LINE = 22, 14
local HOME_DROP = -140

local function Place(toast)
    local pos = toast.store.Get(toast.posKey)
    toast:ClearAllPoints()
    if pos then
        toast:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        toast:SetPoint("TOP", UIParent, "TOP", 0, HOME_DROP)
    end
end

local function DragStart(toast)
    toast.dragging = true
    toast:StartMoving()
end

local function DragStop(toast)
    toast:StopMovingOrSizing()
    toast.dragging = false
    toast.store.Set(toast.posKey, UI.CenterPosition(toast))
    if toast.expired then toast:Hide() end
end

local function AddButton(toast, spec, i)
    local button = ns.Button(toast, spec.text, spec.width, BUTTON_H, function() spec.click(toast) end)
    if spec.accent then ns.AccentBorder(button) end
    toast.buttons[i] = button
end

function Parts.Toast(spec)
    local toast = CreateFrame("Frame", spec.name, UIParent)
    toast.store, toast.posKey, toast.width = spec.store, spec.posKey, spec.width
    toast:SetWidth(spec.width)
    toast:SetFrameStrata("DIALOG")
    toast:SetClampedToScreen(true)
    toast:SetMovable(true)
    toast:EnableMouse(true)
    toast:RegisterForDrag("LeftButton")
    toast:SetScript("OnDragStart", DragStart)
    toast:SetScript("OnDragStop", DragStop)
    ns.Solid(toast, "BACKGROUND", T.bg, St.BACKDROP_ALPHA):SetAllPoints()
    ns.Border(toast, T.accent)
    local logo = toast:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.MEDIA .. LOGO_FILE, nil, nil, "TRILINEAR")
    logo:SetSize(LOGO, LOGO)
    logo:SetPoint("TOPLEFT", PAD, -PAD)
    toast.title = ns.Font(toast, FONT_TITLE, nil)
    toast.title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)
    toast.line = ns.Font(toast, FONT_LINE, nil)
    toast.line:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -LINE_GAP)
    toast.line:SetWidth(spec.width - 2 * PAD)
    toast.line:SetJustifyH("LEFT")
    toast.line:SetWordWrap(true)
    toast.icons = {}
    for i = 1, spec.icons do
        local icon = toast:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(St.ICON_CROP, St.ICON_CROP_HIGH, St.ICON_CROP, St.ICON_CROP_HIGH)
        icon:SetSize(ICON, ICON)
        toast.icons[i] = icon
    end
    toast.buttons = {}
    for i, button in ipairs(spec.buttons) do AddButton(toast, button, i) end
    toast.generation = 0
    Place(toast)
    toast:Hide()
    return toast
end

function Parts.FillToast(toast, title, line, textures)
    toast.title:SetText(title)
    toast.line:SetText(line)
    local y = -(PAD + LOGO + LINE_GAP + math.ceil(toast.line:GetStringHeight()) + ICONS_GAP)
    for i, icon in ipairs(toast.icons) do
        local texture = textures[i]
        icon:SetShown(texture ~= nil)
        if texture then
            icon:SetTexture(texture)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", PAD + (i - 1) * (ICON + ICON_GAP), y)
        end
    end
    y = y - ICON - BUTTONS_GAP
    for i, button in ipairs(toast.buttons) do
        button:ClearAllPoints()
        if i == 1 then
            button:SetPoint("TOPLEFT", PAD, y)
        else
            button:SetPoint("LEFT", toast.buttons[i - 1], "RIGHT", BUTTON_GAP, 0)
        end
    end
    toast:SetHeight(-y + BUTTON_H + PAD)
end

function Parts.ShowToast(toast, seconds)
    toast:Show()
    toast.expired = false
    toast.generation = toast.generation + 1
    local generation = toast.generation
    C_Timer.After(seconds, function()
        if generation ~= toast.generation then return end
        toast.expired = true
        if not toast.dragging then toast:Hide() end
    end)
end
