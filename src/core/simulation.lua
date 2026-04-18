-- core/simulation.lua
-- Tick orchestrator. Called once per simulation tick from playing.lua.

local time  = require("core.time")
local units = require("simulation.units")

local simulation = {}

function simulation.onTick()
    time.advance()
    units.tickAll()
    units.update()
end

return simulation
