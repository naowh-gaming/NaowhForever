-- Returns ns.QoLConstants as QoL/Constants.lua makes it, for a test whose stub ns loads QoL files
-- one by one rather than through QoL.xml. Not a test itself (run-all.sh runs only test*.lua).
-- Run from the repo root:
--
--   ns.QoLConstants = dofile("Tools/regression/qol_constants.lua")
local ns = {}
local chunk = assert(loadfile("QoL/Constants.lua"))
setfenv(chunk, { _G = { NaowhForever = ns } })
chunk()
return ns.QoLConstants
