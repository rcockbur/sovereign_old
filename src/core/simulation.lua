-- core/simulation.lua
-- Tick orchestrator. Called once per simulation tick from playing.lua.

local time      = require("core.time")
local units     = require("simulation.units")
local buildings = require("simulation.buildings")
local resources = require("simulation.resources")

local simulation = {}

function simulation.onTick()
    time.advance()
    units.tickAll()
    units.update()
    buildings.sweepDeleted()
    if DEBUG_VALIDATE_RESOURCE_COUNTS then
        resources.validateCounts()
    end
end

return simulation
