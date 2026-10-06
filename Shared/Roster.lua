-------------------------------------------------------------------------------
--  Roster.lua -- Naowh Forever's part of a member's tooltip in the Guild & Communities list
--  (ns.Shared.Roster), for Badges (the badge plate) and Naowh Score (the score line). Nothing
--  is hooked until a module first asks: then each list row gets a HookScript after the game's
--  own tooltip, and every Roster.AddTooltip(fn) runs in the order modules asked, as
--  fn(tooltip, guid, info, row), returning true when it added a line.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever

local Roster = {}
ns.Shared.Roster = Roster

local adders = {}
local hookedRows = setmetatable({}, { __mode = "k" })

local function OnEnter(row)
    local tooltip = GameTooltip
    if tooltip:IsForbidden() or not tooltip:IsShown() or not tooltip:IsOwned(row) then return end
    local info = row.memberInfo
    local guid = info and info.guid
    if type(guid) ~= "string" or (issecretvalue and issecretvalue(guid)) then return end
    local added = false
    for i = 1, #adders do
        if adders[i](tooltip, guid, info, row) then added = true end
    end
    if added then tooltip:Show() end
end

local function HookRow(row)
    if hookedRows[row] then return end
    hookedRows[row] = true
    row:HookScript("OnEnter", OnEnter)
end

local function RowInitialized(_, row)
    HookRow(row)
end

local function HookList()
    local frame = CommunitiesFrame
    local scroll = frame and frame.MemberList and frame.MemberList.ScrollBox
    if not scroll then return end
    scroll:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, RowInitialized, hookedRows)
    scroll:ForEachFrame(HookRow)
end

function Roster.AddTooltip(fn)
    adders[#adders + 1] = fn
    if #adders > 1 then return end
    if CommunitiesFrame then
        HookList()
    else
        EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", HookList)
    end
end
