-- FirstLogin.lua: opens the onboarding on an account's first login, and asks a new character whether it shares its main's settings.
local ns = _G.NaowhForever

local SHOW_DELAY = 5
local FIRST_COPY = 2

local ASK = "Welcome, %s! Use the same settings as %s, or set this character up on its own?"
local ASK_SAME, ASK_OWN = "Same as %s", "Set Up %s"
local SAME_DONE = "%s now uses the same settings as %s."
local COPY_NAME = "%s %d"

local timer, armed
local login = CreateFrame("Frame")

local function Stop()
    login:UnregisterAllEvents()
    if timer then timer:Cancel() end
    timer = nil
end

local function Wanted()
    return not ns.AccountSettings().onboardingSeen or ns.ImportCandidate() ~= nil
end

local function UseMain(me, main, profile)
    if profile == ns.ActiveProfileName() then return end
    if ns.SwitchProfile(profile) then ns.Print(SAME_DONE:format(me, main)) end
end

local function FreeName(me)
    local name, n = me, FIRST_COPY
    while ns.ProfileExists(name) do
        name, n = COPY_NAME:format(me, n), n + 1
    end
    return name
end

local function SetUpOwn(me)
    local name = FreeName(me)
    if not ns.CopyProfile(ns.ActiveProfileName(), name) then return end
    if ns.SwitchProfile(name) then ns.ShowSetup(true) end
end

local function AskMain()
    local char, profile = ns.ImportCandidate()
    if not char then return end
    local me, main = UnitName("player"), char:match("^[^-]+")
    ns.Confirm(ASK:format(me, main), function() UseMain(me, main, profile) end, nil,
        ASK_SAME:format(main), ASK_OWN:format(me), function() SetUpOwn(me) end)
end

local function Due()
    timer = nil
    if not Wanted() then return Stop() end
    if InCombatLockdown() then
        login:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Stop()
    if ns.AccountSettings().onboardingSeen then return AskMain() end
    ns.ShowSetup()
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
