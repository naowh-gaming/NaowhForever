-- Chrome.lua: the character panel's frame in the BiS List's look (CP.Restyler, CP.Chrome).
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local CP = ns.CharacterPanel
local C = CP.C
local St = ns.Shared.Style
local Parts = ns.Shared.Parts

local HEADER = 20
local LOGO = 14
local LOGO_IN = 6
local MODEL_INSET = 4
local CLOSE = 10
local TITLE_SIZE, LEVEL_SIZE, STAT_SIZE, CATEGORY_SIZE = C.TEXT_SIZE, 14, C.TEXT_SIZE, C.SECTION_SIZE
local BACKDROP_ALPHA = St.BACKDROP_ALPHA
local MODEL_ALPHA = 0.35
local HOVER_ALPHA = 0.5
local CATEGORY_X, CATEGORY_Y = 8, 8
local RULE_X, RULE_Y = 8, 4
local GAME_TITLE_Y = 1
local TOGGLE_EDGE, TOGGLE_W, LINK_GAP = 6, 28, 12
local BADGE_MID_FALLBACK = 32
local COVER_LIFT = 20
local LEVEL_STRIP_Y = 2
local SIDE_TABS, SIDEBAR_TABS = 6, 3
local FILTER = "TRILINEAR"
local TEXTURE = "Texture"
local SIDE_TAB, SIDEBAR_TAB = "CharacterFrameModeTab", "PaperDollSidebarTab"
local TEXT_BIS_LIST = " BiS List"
local TAB_RGB = { r = 0.16, g = 0.16, b = 0.17 }
local MODEL_ART = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight",
    "BackgroundOverlay" }

local uppers = {}
local styled = setmetatable({}, { __mode = "k" })
local chrome, installed, levelMoved
local game

local function Textures(frame, each, ...)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == TEXTURE then each(region, ...) end
    end
end

local function Upper(text)
    local upper = uppers[text]
    if not upper then
        upper = text:upper()
        uppers[text], uppers[upper] = upper, upper
    end
    return upper
end

local function CategoryRule(frame)
    local line = styled[frame]
    if type(line) == "table" then return line end
    line = ns.Solid(frame, "ARTWORK", T.line, 1)
    line:SetPoint("BOTTOMLEFT", RULE_X, RULE_Y)
    line:SetPoint("BOTTOMRIGHT", -RULE_X, RULE_Y)
    ns.Hairline(line, "h")
    styled[frame] = line
    return line
end

local function StyleCategory(frame)
    local title = frame.Title
    game.Restyle(title, CATEGORY_SIZE, T.accentSoft)
    local text = title:GetText()
    if text then title:SetText(Upper(text)) end
    title:ClearAllPoints()
    title:SetPoint("BOTTOMLEFT", CATEGORY_X, CATEGORY_Y)
    CategoryRule(frame):Show()
end

local function StyleStat(_, frame)
    if not CP.On() then return end
    if frame.Background then frame.Background:SetAlpha(0) end
    if frame.Title then return StyleCategory(frame) end
    game.Restyle(frame.Label, STAT_SIZE, T.muted)
    game.Restyle(frame.Value, STAT_SIZE, T.fg)
    styled[frame] = styled[frame] or true
end

local function StyleFrame(frame)
    StyleStat(nil, frame)
end

local function UnstyleStats()
    for frame, line in pairs(styled) do
        if frame.Background then frame.Background:SetAlpha(1) end
        if type(line) == "table" then
            line:Hide()
            frame.Title:ClearAllPoints()
            frame.Title:SetPoint("CENTER", 0, GAME_TITLE_Y)
        end
    end
end

local function CloseCross(close)
    local cross = close:CreateTexture(nil, "OVERLAY")
    cross:SetTexture(St.CROSS, nil, nil, FILTER)
    cross:SetSize(CLOSE, CLOSE)
    cross:SetPoint("CENTER")
    cross:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    close:HookScript("OnEnter", function() cross:SetVertexColor(T.fg.r, T.fg.g, T.fg.b) end)
    close:HookScript("OnLeave", function() cross:SetVertexColor(T.muted.r, T.muted.g, T.muted.b) end)
    return cross
end

local function OpenBis()
    ns.OpenBisWindow()
end

local function Cover(frame, controls)
    local cover = CreateFrame("Frame", nil, PaperDollFrame or frame)
    cover:SetAllPoints(controls)
    cover:SetFrameLevel(CharacterModelScene:GetFrameLevel() + COVER_LIFT)
    cover:EnableMouse(true)
    local bis = Parts.Link(cover, OpenBis, true)
    Parts.SetLink(bis, Parts.Inline(St.STAR, St.BIS_RGB, Parts.CARD_DROP) .. TEXT_BIS_LIST)
    bis:SetPoint("RIGHT", frame.LeftPaneHost, "TOPRIGHT", -(TOGGLE_EDGE + TOGGLE_W + LINK_GAP),
        -(CP.BADGE_MID or BADGE_MID_FALLBACK))
    return cover
end

local function Build()
    local frame = CharacterFrame
    chrome = CP.Chrome(frame)
    CP.ModelPanel(chrome, frame.LeftPaneHost)
    CP.Split(chrome, frame.RightPaneHost)
    local controls = CharacterModelScene and CharacterModelScene.ControlFrame
    if controls then chrome.cover = Cover(frame, controls) end
end

local function FadeAmmo()
    local ammo = _G.CharacterAmmoSlot
    if not ammo then return end
    for _, region in ipairs({ ammo:GetRegions() }) do
        if region ~= ammo.icon and region:GetObjectType() == TEXTURE then game.Fade(region) end
    end
end

local function FadeGame()
    local frame = CharacterFrame
    game.Fade(frame.NineSlice)
    game.Fade(frame.PortraitContainer)
    game.FadeRegions(frame.LeftPaneHost)
    local right = frame.RightPaneHost
    game.FadeRegions(right)
    if right then
        for _, child in ipairs({ right:GetChildren() }) do game.Fade(child) end
    end
    local model = CharacterModelScene
    if model then
        for _, key in ipairs(MODEL_ART) do game.Fade(model[key]) end
    end
    game.Fade(CharacterLevelTextBackground)
    game.FadeTree(PaperDollFrame and PaperDollFrame.TopBackgroundStripHost)
    game.FadeRegions(CharacterStatsPaneScrollBox)
    FadeAmmo()
    game.FadeClose(frame.CloseButton)
end

local function TintSidebarTab(tab)
    for _, region in ipairs({ tab:GetRegions() }) do
        if region ~= tab.Icon and region:GetObjectType() == TEXTURE then game.Tint(region, TAB_RGB) end
    end
    game.Tint(tab:GetCheckedTexture(), T.accent)
    game.Tint(tab:GetHighlightTexture(), T.accent, HOVER_ALPHA)
end

local function TintGame()
    for i = 1, SIDE_TABS do game.TintSideTab(_G[SIDE_TAB .. i]) end
    for i = 1, SIDEBAR_TABS do
        local tab = _G[SIDEBAR_TAB .. i]
        if tab then TintSidebarTab(tab) end
    end
    local toggle = CharacterFrame.RightPaneToggleButton
    if toggle then
        game.Tint(toggle:GetNormalTexture(), T.muted)
        game.Tint(toggle:GetPushedTexture(), T.accent)
    end
    game.TintTree(CharacterStatsPaneScrollBox and CharacterStatsPaneScrollBox.ScrollBar, T.muted)
    game.FadeTree(CharacterModelScene and CharacterModelScene.ControlFrame)
end

local function PlaceLevel(onRow)
    local info, strip = PaperDollLevelInfo, PaperDollFrame and PaperDollFrame.TopBackgroundStripHost
    if not (info and strip) or (not onRow and not levelMoved) then return end
    info:ClearAllPoints()
    if onRow then
        info:SetPoint("CENTER", CharacterFrame.LeftPaneHost, "TOP", 0, -CP.BADGE_MID)
    else
        info:SetPoint("CENTER", strip, "CENTER", 0, -LEVEL_STRIP_Y)
    end
    levelMoved = onRow
end

local function Install()
    installed = true
    Build()
    local list = CharacterStatsPaneScrollBox and CharacterStatsPaneScrollBox.ScrollBox
    if list and ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
        ScrollUtil.AddInitializedFrameCallback(list, StyleStat, chrome, true)
    end
end

local function ShowChrome(on)
    chrome:SetShown(on)
    if chrome.cross then chrome.cross:SetShown(on) end
    if chrome.cover then chrome.cover:SetShown(on) end
end

local function Dress()
    FadeGame()
    TintGame()
    game.Restyle(CharacterFrameTitleText, TITLE_SIZE, T.fg)
    game.Restyle(CharacterLevelText, LEVEL_SIZE, T.fg)
    PlaceLevel(true)
    ShowChrome(true)
    local list = CharacterStatsPaneScrollBox and CharacterStatsPaneScrollBox.ScrollBox
    if list and list.ForEachFrame then list:ForEachFrame(StyleFrame) end
end

local function Apply()
    local on = CP.On()
    if on and not installed and CharacterFrame then Install() end
    if not installed then return end
    if on then return Dress() end
    game.Restore()
    PlaceLevel(false)
    UnstyleStats()
    ShowChrome(false)
end

local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") then Apply() end
end

CP.HEADER, CP.TITLE_SIZE, CP.LEVEL_SIZE, CP.MODEL_ALPHA = HEADER, TITLE_SIZE, LEVEL_SIZE, MODEL_ALPHA
CP.TAB_RGB = TAB_RGB

function CP.Restyler()
    local r = {}
    local faded, tinted, fonts = {}, {}, {}

    function r.Fade(region)
        if type(region) == "table" and region.SetAlpha then
            region:SetAlpha(0)
            faded[region] = true
        end
    end

    function r.FadeRegions(frame)
        if not frame then return end
        for _, region in ipairs({ frame:GetRegions() }) do r.Fade(region) end
    end

    function r.FadeTree(frame)
        if not frame then return end
        Textures(frame, r.Fade)
        for _, child in ipairs({ frame:GetChildren() }) do r.FadeTree(child) end
    end

    function r.Tint(region, color, alpha)
        if not (type(region) == "table" and region.SetDesaturated) then return end
        region:SetDesaturated(true)
        region:SetVertexColor(color.r, color.g, color.b, alpha or 1)
        tinted[region] = true
    end

    function r.TintTree(frame, color)
        if not frame then return end
        Textures(frame, r.Tint, color)
        for _, child in ipairs({ frame:GetChildren() }) do r.TintTree(child, color) end
    end

    function r.Restyle(fontString, size, color)
        if not fontString then return end
        if not fonts[fontString] then fonts[fontString] = fontString:GetFontObject() or GameFontNormal end
        fontString:SetFont(ns.UIFontPath(), size, "")
        fontString:SetTextColor(color.r, color.g, color.b, 1)
    end

    function r.TintSideTab(tab)
        if not tab then return end
        r.Tint(tab.Background, TAB_RGB)
        r.Tint(tab.SelectedTexture, T.accent)
        r.Tint(tab.HighlightTexture, T.accent, HOVER_ALPHA)
        r.Fade(tab.TabGlow)
    end

    function r.FadeClose(close)
        if not close then return end
        r.Fade(close:GetNormalTexture())
        r.Fade(close:GetPushedTexture())
        r.Fade(close:GetHighlightTexture())
        r.Fade(close:GetDisabledTexture())
    end

    function r.Restore()
        for region in pairs(faded) do region:SetAlpha(1) end
        wipe(faded)
        for region in pairs(tinted) do
            region:SetDesaturated(false)
            region:SetVertexColor(1, 1, 1, 1)
        end
        wipe(tinted)
        for fontString, object in pairs(fonts) do fontString:SetFontObject(object) end
        wipe(fonts)
    end

    return r
end

function CP.Chrome(frame)
    local back = CreateFrame("Frame", nil, frame)
    back:SetAllPoints()
    back:SetFrameLevel(frame:GetFrameLevel())
    back.backdrop = Parts.Backdrop(back)
    back.backdrop:Paint(BACKDROP_ALPHA)
    ns.Border(back, St.BORDER_RGB)
    local rule = ns.Solid(back, "ARTWORK", St.BORDER_RGB, 1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)
    ns.Hairline(rule, "h")
    local logo = back:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(St.LOGO_SMALL, nil, nil, FILTER)
    logo:SetSize(LOGO, LOGO)
    logo:SetPoint("LEFT", back, "TOPLEFT", LOGO_IN, -HEADER / 2)
    local close = frame.CloseButton
    if close then back.cross = CloseCross(close) end
    return back
end

function CP.ModelPanel(back, box)
    local panel = ns.Solid(back, "BACKGROUND", T.panel, MODEL_ALPHA)
    panel:SetPoint("TOPLEFT", box, "TOPLEFT", MODEL_INSET, -MODEL_INSET)
    panel:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -MODEL_INSET, MODEL_INSET)
    return panel
end

function CP.Split(back, pane)
    local split = ns.Solid(back, "ARTWORK", St.BORDER_RGB, 1)
    split:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    split:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    ns.Hairline(split, "v")
    return split
end

game = CP.Restyler()
CP.ApplyChrome = Apply

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
