-------------------------------------------------------------------------------
--  NaowhForever_CompletoRareAlert.lua -- Rare Alerts: a warning when a rare is near you, as
--  RareScanner gives, and a skull on it. Any creature the game calls rare or rare elite
--  counts, in the data or not.
--
--  A rare is seen when its nameplate comes up, when you mouse over it or target it, and
--  where the game marks it on the minimap (a vignette, if Forever gives rares one). The
--  alert sits in the Alerts group (move it with Unlock Mode), pulses, plays a sound and
--  flashes the game's taskbar icon; it goes after a while, on a click, or once the rare is
--  killed. Each rare alerts once in a while, not every time its nameplate comes back.
--
--  The skull goes on a rare you can see as a unit (nameplate, mouseover or target, not a
--  minimap mark), once per creature, and only where it has no mark yet and you may mark: on
--  your own, in a party, or as a raid's leader or assistant.
--
--  Off until Rare Alerts is switched on: then the events above, and nothing more.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever
local T = ns.THEME
local S = ns.CompletoSettings
local R = ns.Completo.Rares

local SKULL = 8
local SKULL_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"
local SHOW_FOR = 20       -- seconds the alert stays up
local AGAIN_AFTER = 300   -- seconds before the same rare alerts again
local PULSES = 6

local function On()
    return S.Get("enabled") and S.Get("rareAlert")
end

local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-------------------------------------------------------------------------------
--  The alert
-------------------------------------------------------------------------------
local alert, flash, hideTimer
local shownNpc   -- the rare the alert is about, by npcID; nil for one not in the data

local function HideAlert()
    if not alert then return end
    if hideTimer then hideTimer:Cancel() end
    hideTimer = nil
    flash:Stop()
    alert:Hide()
    shownNpc = nil
end

local function BuildAlert()
    alert = CreateFrame("Frame", "NaowhForeverRareAlert", UIParent)
    alert:SetMovable(true)
    alert:SetClampedToScreen(true)
    alert.title = ns.Font(alert, 22, "OUTLINE", T.accent)
    alert.title:SetPoint("TOP", 0, -4)
    alert.title:SetText("Rare Spotted")
    alert.text = ns.Font(alert, 16, "OUTLINE")
    alert.text:SetPoint("TOP", alert.title, "BOTTOM", 0, -4)
    alert.text:SetJustifyH("CENTER")
    alert.note = ns.Font(alert, 12, "OUTLINE", T.muted)
    alert.note:SetPoint("TOP", alert.text, "BOTTOM", 0, -3)
    alert.note:SetJustifyH("CENTER")
    -- A click puts it away.
    alert:EnableMouse(true)
    alert:SetScript("OnMouseUp", HideAlert)

    flash = alert:CreateAnimationGroup()
    flash:SetLooping("BOUNCE")
    flash:SetScript("OnLoop", function(self)
        self.loops = self.loops + 1
        if self.loops >= PULSES then self:Stop() end
    end)
    local pulse = flash:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.35)
    pulse:SetDuration(0.6)

    alert:Hide()
    ns.AlertStack(alert, 6)
end

local function PlayAlertSound()
    if not S.Get("rareSound") then return end
    local path = ns.UI.SoundPathFor(S.Get("rareSoundKey"))
    if path then
        ns.UI._PlayLSMSound(path)
    else
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
end

-- name: the rare's; level: its level, or nil; npc: its npcID when in the data; marked: a
-- skull went on it; quiet: no sound or flash (Unlock Mode's preview).
local function ShowAlert(name, level, npc, marked, quiet)
    if not alert then BuildAlert() end
    shownNpc = npc
    local line = name
    if level and level > 0 then line = ("%s  (%d)"):format(name, level) end
    if marked then line = SKULL_ICON .. " " .. line end
    alert.text:SetText(line)
    local note = ""
    if npc and R.Known(npc) then
        local record = R.Record(npc)
        if not record then
            note = "Not killed yet"
        elseif record.n > 1 then
            note = ("Killed %d times"):format(record.n)
        else
            note = "Killed before"
        end
    end
    alert.note:SetText(note)
    alert.note:SetShown(note ~= "")
    local h = alert.title:GetStringHeight() + alert.text:GetStringHeight() + 12
    if note ~= "" then h = h + alert.note:GetStringHeight() + 3 end
    alert:SetSize(math.max(alert.title:GetStringWidth(), alert.text:GetStringWidth(),
        alert.note:GetStringWidth()) + 16, h)
    alert:Show()
    flash.loops = 0
    flash:Play()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = nil
    if quiet then return end
    hideTimer = C_Timer.NewTimer(SHOW_FOR, HideAlert)
    PlayAlertSound()
    if FlashClientIcon then FlashClientIcon() end
end

-- The rare the alert is about was killed: nothing left to warn about.
R.OnChange(function(npc)
    if shownNpc and npc == shownNpc and R.Killed(npc) then HideAlert() end
end)

-------------------------------------------------------------------------------
--  Seeing a rare
-------------------------------------------------------------------------------
local alerted = {}   -- npcID or name -> GetTime() of its latest alert
local marked = {}    -- GUID -> true once a skull went on it

local function MayMark()
    if not IsInGroup() then return true end
    if not IsInRaid() then return true end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- A skull on it, once per creature, where it has no mark yet.
local function Mark(unit, guid)
    if not S.Get("rareMark") or marked[guid] or not MayMark() then return false end
    local index = GetRaidTargetIndex(unit)
    if Secret(index) or index then return false end
    marked[guid] = true
    SetRaidTarget(unit, SKULL)
    return true
end

-- Alerts once in AGAIN_AFTER seconds per rare; one you killed only with Killed Rares Too.
local function Alert(key, name, level, npc, skull)
    local now = GetTime()
    if alerted[key] and now - alerted[key] < AGAIN_AFTER then return end
    if npc and R.Known(npc) and R.Killed(npc) and not S.Get("rareAlertKilled") then return end
    alerted[key] = now
    ShowAlert(name, level, npc, skull)
end

local RARE = { rare = true, rareelite = true }

local function Check(unit)
    if not UnitExists(unit) then return end
    local guid, kind = UnitGUID(unit), UnitClassification(unit)
    if Secret(guid) or Secret(kind) or not guid then return end
    local npc = R.NpcOf(guid)
    if not npc or not (RARE[kind] or R.Known(npc)) then return end
    local dead, hostile = UnitIsDead(unit), UnitCanAttack("player", unit)
    if Secret(dead) or Secret(hostile) or dead or not hostile then return end
    local name, level = UnitName(unit), UnitLevel(unit)
    if Secret(name) then return end
    if Secret(level) then level = nil end
    local skull = Mark(unit, guid)
    Alert(npc, name, level, npc, skull)
end

-- A minimap mark: a rare in the data, or one the game draws as a creature to kill.
local function CheckVignette(id)
    local info = C_VignetteInfo.GetVignetteInfo(id)
    if not info or Secret(info.objectGUID) or Secret(info.name) then return end
    local npc = R.NpcOf(info.objectGUID)
    local atlas = type(info.atlasName) == "string" and not Secret(info.atlasName) and info.atlasName or ""
    if not npc or not (R.Known(npc) or atlas:find("Kill")) then return end
    local level
    if R.Known(npc) then level = R.Levels(npc) end
    Alert(npc, info.name or (R.Known(npc) and R.Name(npc)) or "Rare", level, npc, false)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, onMinimap)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Check(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        Check("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Check("mouseover")
    elseif event == "VIGNETTE_MINIMAP_UPDATED" then
        if onMinimap and not Secret(unit) then CheckVignette(unit) end
    end
end)

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        HideAlert()
        return
    end
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    if C_VignetteInfo and C_VignetteInfo.GetVignetteInfo then
        events:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
    end
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "rareAlert" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowRaidReminderAnchorConfig", function()
    if On() then ShowAlert("Mist Howler", 22, nil, true, true) end
end)
hooksecurefunc(ns, "HideRaidReminderAnchorConfig", HideAlert)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local OFF = "Turn on Completo"

local function Enabled() return S.Get("enabled") == true end
local function SoundOn() return Enabled() and S.Get("rareSound") == true end

local function Summary(store)
    local parts = {}
    if store.Get("rareMark") then parts[#parts + 1] = "a skull on it" end
    if store.Get("rareSound") then parts[#parts + 1] = "a sound" end
    if #parts == 0 then return "A warning when a rare is near" end
    return "A warning when a rare is near, " .. table.concat(parts, " and ")
end

Settings.Page("Completo/Rares", S):Card({
    id = "rareAlert", name = "Rare Alerts", order = 20, switch = "rareAlert",
    help = "A warning when a rare is near you: when its nameplate comes up, you mouse over it or target "
        .. "it. It sits with the other alerts; move them with Unlock Mode. Click it to put it away.",
    summary = Summary,
    rows = {
        { key = "rareMark", label = "Mark With a Skull", toggle = true, needs = Enabled, why = OFF,
          help = "Puts a skull on the rare, if it has no mark yet. In a raid only as its leader or an "
              .. "assistant." },
        { key = "rareAlertKilled", label = "Killed Rares Too", toggle = true, needs = Enabled, why = OFF,
          help = "Also warns about rares you have killed before." },
        { key = "rareSound", label = "Play a Sound", toggle = true, needs = Enabled, why = OFF,
          help = "Plays when the warning comes up, and flashes the game's icon on your taskbar." },
        { key = "rareSoundKey", label = "Sound", sound = true, needs = SoundOn, why = "Needs Play a Sound",
          help = "Left at None, the game's raid warning sound." },
    },
})
