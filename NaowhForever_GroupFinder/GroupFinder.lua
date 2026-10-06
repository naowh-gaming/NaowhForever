-------------------------------------------------------------------------------
--  GroupFinder.lua -- the Group Finder's core (ns.GroupFinder): its settings, whether it is
--  on, and the small listener list Card, Comms, Listings and the probe tell each other through.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever

local S = ns.UI.ModuleSettings("groupFinder", {
    enabled = false,
    shareScore = true,
    shareKills = true,
    shareQuests = true,
    shareBis = true,
})
ns.GroupFinderSettings = S

local GF = { Settings = S, PREFIX = "NaowhLFG" }
ns.GroupFinder = GF

function GF.On()
    return S.Get("enabled") == true
end

local listeners = {}

function GF.Listen(what, fn)
    local list = listeners[what]
    if not list then
        list = {}
        listeners[what] = list
    end
    list[#list + 1] = fn
end

function GF.Fire(what, a, b, c, d)
    local list = listeners[what]
    if not list then return end
    for i = 1, #list do list[i](a, b, c, d) end
end
