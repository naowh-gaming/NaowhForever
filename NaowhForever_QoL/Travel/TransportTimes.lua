-- TransportTimes.lua: single-sighting server-clock phases for each transport dock.
local ns = _G.NaowhForever

local ARRIVAL, DEPARTURE = "arrival", "departure"

local observations
local Times = {}
ns.TransportTimes = Times

function Times.Clear(key)
    if not key then observations = nil
    elseif observations then observations[key] = nil end
end

function Times.Record(key, kind, now)
    local timing = ns.TransportData[key]
    if not timing or (kind ~= ARRIVAL and kind ~= DEPARTURE) then return false end
    observations = observations or {}
    local row = observations[key]
    if row and now == row.last then return false end
    observations[key] = { arrival = kind == ARRIVAL and now or now - timing.dwell, last = now }
    return true
end

function Times.Next(key, now)
    local row = observations and observations[key]
    if not row then return nil, "new" end
    if now < row.last then return nil, "stale" end
    local timing = ns.TransportData[key]
    local phase = (now - row.arrival) % timing.period
    if phase < timing.dwell then return timing.dwell - phase, DEPARTURE end
    return timing.period - phase, ARRIVAL
end
