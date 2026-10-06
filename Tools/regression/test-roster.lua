-- test-roster.lua -- Shared/Roster.lua: lines on a member's tooltip in the Guild & Communities
-- list. Nothing hooked until a module asks; each row hooked once, new and old; lines in the order
-- modules asked; the tooltip shown again only when a line went in; secret GUIDs and a tooltip
-- that isn't the row's are left alone. Run from the addon root: lua5.1 Tools/regression/test-roster.lua
local checks = 0
local function check(name, ok)
    assert(ok, name)
    checks = checks + 1
end

local SECRET = {}
local state = { onLoaded = {}, shown = 0, calls = {} }
local function Row(guid)
    local row = { memberInfo = guid and { guid = guid, level = 20 } or nil, hooks = 0 }
    function row.HookScript(self, script, fn)
        self.hooks = self.hooks + 1
        self[script] = fn
    end
    return row
end
local scroll = { rows = { Row("Player-1-A"), Row("Player-1-B") } }
function scroll.RegisterCallback(_, event, fn, owner) state.callback, state.event, state.owner = fn, event, owner end
function scroll.ForEachFrame(self, fn) for _, row in ipairs(self.rows) do fn(row) end end

local tooltip = { owner = nil, shownNow = true }
function tooltip.IsForbidden() return false end
function tooltip.IsShown(self) return self.shownNow end
function tooltip.IsOwned(self, frame) return self.owner == frame end
function tooltip.Show() state.shown = state.shown + 1 end

local ns = { Shared = {} }
local env = setmetatable({
    _G = { NaowhForever = ns },
    GameTooltip = tooltip,
    issecretvalue = function(v) return rawequal(v, SECRET) end,
    ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame" } },
    EventUtil = { ContinueOnAddOnLoaded = function(name, fn) state.onLoaded[name] = fn end },
}, { __index = _G })
local chunk = assert(loadfile("Shared/Roster.lua"))
setfenv(chunk, env)
chunk()
local Roster = ns.Shared.Roster

check("nothing hooked at load", state.callback == nil and next(state.onLoaded) == nil)
Roster.AddTooltip(function(_, guid, info, row)
    state.calls[#state.calls + 1] = "badge:" .. guid .. ":" .. info.level
    return false
end)
check("before the window opens, it waits for the list's code", state.onLoaded.Blizzard_Communities ~= nil)
env.CommunitiesFrame = { MemberList = { ScrollBox = scroll } }
state.onLoaded.Blizzard_Communities()
check("the rows already there are hooked", scroll.rows[1].hooks == 1 and scroll.rows[2].hooks == 1)
check("and the list's new rows will be", state.event == "OnInitializedFrame" and state.callback ~= nil)
Roster.AddTooltip(function(_, guid)
    state.calls[#state.calls + 1] = "score:" .. guid
    return guid == "Player-1-A"
end)
check("a second module adds no second hook", scroll.rows[1].hooks == 1)
local new = Row("Player-1-C")
state.callback(state.owner, new)
state.callback(state.owner, new)
state.callback(state.owner, scroll.rows[1])
check("a row is hooked once however often it's reused", new.hooks == 1 and scroll.rows[1].hooks == 1)

local A = scroll.rows[1]
tooltip.owner = A
A.OnEnter(A)
check("lines in the order modules asked", state.calls[1] == "badge:Player-1-A:20" and state.calls[2] == "score:Player-1-A")
check("shown again when a line went in", state.shown == 1)
local B = scroll.rows[2]
tooltip.owner = B
B.OnEnter(B)
check("not shown again when none did", state.shown == 1 and #state.calls == 4)

for k in pairs(state.calls) do state.calls[k] = nil end
tooltip.owner = A
B.OnEnter(B)
check("the tooltip on another row: left alone", #state.calls == 0)
tooltip.owner, tooltip.shownNow = B, false
B.OnEnter(B)
check("no tooltip (an expanded list with nothing cut short): left alone", #state.calls == 0)
tooltip.shownNow = true
local secret = Row(SECRET)
state.callback(state.owner, secret)
tooltip.owner = secret
secret.OnEnter(secret)
local empty = Row(nil)
state.callback(state.owner, empty)
tooltip.owner = empty
empty.OnEnter(empty)
check("a secret GUID or no member: left alone", #state.calls == 0)

print(("test-roster: %d checks passed"):format(checks))
