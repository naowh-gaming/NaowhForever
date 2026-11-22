-- Tsm.lua: the TSM title bar button, shown when TradeSkillMaster is loaded, that switches to TSM's own crafting window.
local ns = _G.NaowhForever

local P = ns.Professions
local W = P.State
local R = P.Recipes
local TitleButtons = P.TitleButtons

local OPEN_W, OPEN_H, OPEN_ORDER = 50, 22, 8
local TEXT_OPEN = "TSM"
local TSM_COMMAND = "crafting"

local opener

local function OpenTsm()
    if InCombatLockdown() then return end
    W.frame:Hide()
    SlashCmdList.TSM(TSM_COMMAND)
    ns.ProfWindowRefresh()
end

local function PlaceOpener()
    local win = W.frame
    if not (win and TSM_API and SlashCmdList.TSM) then return end
    if not opener then
        opener = ns.Button(win, TEXT_OPEN, OPEN_W, OPEN_H, OpenTsm)
        ns.Tooltip(opener, TEXT_OPEN, ns.L("Switch to TradeSkillMaster's crafting window."))
        opener:Hide()
        TitleButtons.Add(opener, OPEN_ORDER)
    end
    opener:SetShown(R.Own() and R.Profession() ~= nil)
end

local function HideOpener()
    if opener then opener:Hide() end
end

hooksecurefunc(P.Window, "Render", PlaceOpener)
hooksecurefunc(P.Book, "Render", HideOpener)
