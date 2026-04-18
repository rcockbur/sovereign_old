-- core/simulation.lua
-- Tick orchestrator. Called once per simulation tick from playing.lua.

local time      = require("core.time")
local units     = require("simulation.units")
local resources = require("simulation.resources")

local simulation = {}

function simulation.onTick()
    time.advance()
    units.tickAll()
    units.update()
    if DEBUG_VALIDATE_RESOURCE_COUNTS then
        resources.validateCounts()
    end
end

return simulation
