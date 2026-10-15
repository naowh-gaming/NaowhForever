-- TransportTimes.lua: session observations and expiring estimates for each transport dock.
local ns = _G.NaowhForever

local MIN_PERIOD, MAX_PERIOD = 30, 900
local VALID_CYCLES = 2
local ARRIVAL, DEPARTURE = "arrival", "departure"

local observations
local Times = {}
ns.TransportTimes = Times

function Times.Clear(key)
    if not key then observations = nil
    elseif observations then observations[key] = nil end
end

function Times.Record(key, kind, now)
    if not key or (kind ~= ARRIVAL and kind ~= DEPARTURE) then return false end
    local row = observations and observations[key]
    if row and (now < row.last or now - row.arrival > MAX_PERIOD) then
        observations[key] = nil
        row = nil
    end
    if not row then
        if kind ~= ARRIVAL then return false end
        observations = observations or {}
        observations[key] = { arrival = now, last = now, kind = kind }
        return true
    end
    if row.kind == kind or now <= row.last then return false end
    if kind == DEPARTURE then
        local dwell = now - row.arrival
        if dwell >= (row.period or MAX_PERIOD) then return false end
        row.dwell = dwell
    else
        local period = now - row.arrival
        if period < MIN_PERIOD then return false end
        row.period, row.arrival = period, now
    end
    row.last, row.kind = now, kind
    return true
end

function Times.Next(key, now)
    local row = observations and observations[key]
    if not row then return nil, "new" end
    if now < row.last or now - row.last > MAX_PERIOD then
        return nil, "stale", row.kind
    end
    if not row.period or not row.dwell then
        return nil, row.kind == ARRIVAL and DEPARTURE or ARRIVAL, row.kind
    end
    if now >= row.arrival + row.period * VALID_CYCLES then return nil, "stale", row.kind end
    local phase = (now - row.arrival) % row.period
    if phase < row.dwell then return row.dwell - phase, DEPARTURE, row.kind end
    return row.period - phase, ARRIVAL, row.kind
end
