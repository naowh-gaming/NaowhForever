-- Welcome.lua: the welcome window, shown once per account.
local ns = _G.NaowhForever
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local WIDTH = 520
local INSET = St.CONTENT_INSET
local EDGE = St.WINDOW_PAD
local HEADER = St.WINDOW_HEADER
local BODY_SIZE = 13
local LINE_GAP = 10
local BUTTON_H = 26
local BUTTON_GAP = 8
local DISCORD_W, SETTINGS_W, CLOSE_W = 120, 120, 90
local PRESET_W, PRESET_GAP, PICK_GAP, PRESET_SPACE = 130, 6, 14, 14
local OR_GAP, OR_PAD = 12, 6
local ROUND = 0.5
local BLACK = { r = 0, g = 0, b = 0 }
local PICTURE_SHARE = 0.25
local PICTURES = "Interface\\AddOns\\NaowhForever\\Media\\Welcome\\"
local PICTURE_EXT = ".png"
local OPAQUE = 1
local SHOW_DELAY = 5
local POSITION_KEY = "welcomeWindow"

local TITLE = "Welcome to Naowh Forever"
local SUBTITLE = "Good to have you here."
local DISCORD_TITLE = "Naowh's Discord"
local PICK = "How do you want to start?"
local OR = "or"
local TAILOR = "Tailor my setup"
local TAILOR_ABOUT = "Answer a few quick questions and we pick what to turn on."
local IMPORT = "Welcome, %s! We found settings from %s. Use them on this character too?"
local IMPORT_YES, IMPORT_NO = "Use Them", "Not Now"
local IMPORT_DONE = "%s now uses the same settings as %s."
local TEXT_JOIN_DISCORD, TEXT_OPEN_SETTINGS, TEXT_CLOSE = "Join Discord", "Open Settings", "Close"

local window, timer, armed
local login = CreateFrame("Frame")

local function Lines()
    return {
        "Quality of life, guides and tools for WoW Forever, all in one place.",
        "Type " .. ns.Color("accent", "/nf") .. " to open the settings and turn on what you want.",
        "We keep improving the addon and would love your feedback. Come say hi on our Discord.",
    }
end

local function Seen()
    local account = ns.AccountSettings()
    account.welcomeSeen, account.freshInstall = true, nil
end

local function Hidden(self)
    if not self:IsShown() then Seen() end
end

local function JoinDiscord()
    Seen()
    ns.ShowCopyLine(DISCORD_TITLE, ns.NAOWH_DISCORD, St.LOGO)
end

local function OpenSettings()
    window:Hide()
    ns.OpenOptionsWindow()
end

local function Close()
    window:Hide()
end

local function Pick(key)
    local account = ns.AccountSettings()
    local fresh = not account.welcomeSeen and account.freshInstall == true
    window:Hide()
    if fresh and key == ns.PRESETS.newInstall then return end
    ns.UsePreset(key, not fresh)
end

local function Tailor()
    window:Hide()
    ns.ShowSetup(true)
end

local function Fit(content)
    window:SetHeight(math.ceil(content:GetHeight()) + INSET + BUTTON_H + EDGE)
end

local function Presets()
    local P = ns.PRESETS
    if not (P and P.order and #P.order > 1 and ns.UsePreset) then return nil end
    return P
end

local function AddLines(height)
    local above
    window.lines = {}
    for i, text in ipairs(Lines()) do
        local line = ns.Font(window, BODY_SIZE, nil, T.fg)
        line:SetWidth(WIDTH - INSET * 2)
        line:SetJustifyH("LEFT")
        line:SetText(text)
        if above then
            line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -LINE_GAP)
            height = height + LINE_GAP
        else
            line:SetPoint("TOPLEFT", INSET, -(HEADER + INSET))
        end
        height = height + math.ceil(line:GetStringHeight())
        window.lines[i] = line
        above = line
    end
    return height, above
end

local function AddAbout(button, text)
    local about = ns.Font(window, BODY_SIZE, nil, T.muted)
    about:SetPoint("LEFT", button, "RIGHT", BUTTON_GAP, 0)
    about:SetPoint("RIGHT", window, "RIGHT", -INSET, 0)
    about:SetJustifyH("LEFT")
    about:SetText(text)
    return about
end

local function AddPreset(P, key, above, gap, width, tall)
    local holder = CreateFrame("Frame", nil, window)
    holder:SetSize(width, tall)
    holder:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
    local picture = holder:CreateTexture(nil, "ARTWORK")
    picture:SetAllPoints()
    picture:SetTexture(PICTURES .. key .. PICTURE_EXT)
    ns.Border(holder, BLACK)
    local button = ns.Button(window, P[key].name, PRESET_W, BUTTON_H, function() Pick(key) end)
    ns.Tooltip(button, P[key].name, function() return ns.PresetChanges and ns.PresetChanges(key) end)
    button:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -PRESET_GAP)
    AddAbout(button, P[key].about)
    return button
end

local function AddTailor(above)
    local rule = ns.Solid(window, "ARTWORK", T.line, 1)
    rule:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -OR_GAP)
    rule:SetPoint("RIGHT", window, "RIGHT", -INSET, 0)
    ns.Hairline(rule, "h")
    local word = ns.Font(window, BODY_SIZE, nil, T.muted)
    word:SetPoint("CENTER", rule, "CENTER")
    word:SetText(OR)
    local behind = ns.Solid(window, "OVERLAY", T.bg, 1)
    behind:SetPoint("TOPLEFT", word, "TOPLEFT", -OR_PAD, 0)
    behind:SetPoint("BOTTOMRIGHT", word, "BOTTOMRIGHT", OR_PAD, 0)
    behind:SetDrawLayer("ARTWORK", 1)
    local button = ns.AccentBorder(ns.Button(window, TAILOR, PRESET_W, BUTTON_H, Tailor))
    button:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -OR_GAP * 2)
    AddAbout(button, TAILOR_ABOUT)
    window.tailor = button
    return button
end

local function AddPresets(P, height, above)
    local head = ns.Font(window, BODY_SIZE, nil, T.accent)
    head:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -PICK_GAP)
    head:SetText(PICK)
    height = height + PICK_GAP + math.ceil(head:GetStringHeight())
    above = head
    window.presets = {}
    local width = WIDTH - INSET * 2
    local tall = math.floor(width * PICTURE_SHARE + ROUND)
    for i, key in ipairs(P.order) do
        local gap = i == 1 and LINE_GAP or PRESET_SPACE
        above = AddPreset(P, key, above, gap, width, tall)
        height = height + gap + tall + PRESET_GAP + BUTTON_H
        window.presets[i] = above
    end
    if ns.ShowSetup then
        above = AddTailor(above)
        height = height + OR_GAP * 2 + BUTTON_H
    end
    return height, above
end

local function AddFooter(above)
    window.content = CreateFrame("Frame", nil, window)
    window.content:SetPoint("TOPLEFT")
    window.content:SetPoint("BOTTOMRIGHT", above, "BOTTOMRIGHT")
    window.content:SetScript("OnSizeChanged", Fit)
    window.discord = ns.AccentBorder(ns.Button(window, TEXT_JOIN_DISCORD, DISCORD_W, BUTTON_H, JoinDiscord))
    window.discord:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    window.settings = ns.Button(window, TEXT_OPEN_SETTINGS, SETTINGS_W, BUTTON_H, OpenSettings)
    window.settings:SetPoint("LEFT", window.discord, "RIGHT", BUTTON_GAP, 0)
    window.close = ns.Button(window, TEXT_CLOSE, CLOSE_W, BUTTON_H, Close)
    window.close:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
end

local function Build()
    window = Parts.Window(WIDTH, HEADER, POSITION_KEY)
    window.backdrop:Paint(OPAQUE)
    Parts.TitleBar(window, TITLE, SUBTITLE)
    window:HookScript("OnHide", Hidden)
    local height, above = AddLines(HEADER + INSET)
    local P = Presets()
    if P then height, above = AddPresets(P, height, above) end
    AddFooter(above)
    window:SetHeight(height + INSET + BUTTON_H + EDGE)
end

local function Show()
    if not window then Build() end
    window:Show()
end

local function Stop()
    login:UnregisterAllEvents()
    if timer then timer:Cancel() end
    timer = nil
end

function ns.ShowWelcome()
    Stop()
    ns.OpenFromOptions(Show)
end

local function Wanted()
    return not ns.AccountSettings().welcomeSeen or ns.ImportCandidate() ~= nil
end

local function OfferImport()
    local char, profile = ns.ImportCandidate()
    if not char then return end
    local me, them = UnitName("player"), char:match("^[^-]+")
    ns.Confirm(IMPORT:format(me, them), function()
        if ns.SwitchProfile(profile) then ns.Print(IMPORT_DONE:format(me, them)) end
    end, nil, IMPORT_YES, IMPORT_NO)
end

local function Due()
    timer = nil
    if not Wanted() then return Stop() end
    if InCombatLockdown() then
        login:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if ns.AccountSettings().welcomeSeen then
        Stop()
        return OfferImport()
    end
    ns.ShowWelcome()
end

local function OnEnteringWorld(self, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then ns.MarkSeen() end
    if not (armed or isInitialLogin or isReloadingUi) or not Wanted() then
        return Stop()
    end
    armed = true
    if timer then timer:Cancel() end
    timer = C_Timer.NewTimer(SHOW_DELAY, Due)
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
end

local function OnLeavingWorld(self)
    if timer then timer:Cancel() end
    timer = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

local function OnLoginEvent(self, event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_ENTERING_WORLD" then
        OnEnteringWorld(self, isInitialLogin, isReloadingUi)
    elseif event == "PLAYER_LEAVING_WORLD" then
        OnLeavingWorld(self)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Due()
    end
end

login:SetScript("OnEvent", OnLoginEvent)
login:RegisterEvent("PLAYER_ENTERING_WORLD")

local Settings = ns.Shared.Settings
Settings.Page("QoL/System", ns.QoLSettings):Card({
    id = "welcome", name = "Welcome", order = 40,
    help = "The window from your first login, with how to get started and our Discord.",
    rows = {
        { label = "Welcome Window", buttonText = "Show", button = ns.ShowWelcome,
          help = "Opens the welcome window again." },
    },
})
