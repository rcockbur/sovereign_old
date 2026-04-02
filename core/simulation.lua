-- core/simulation.lua
-- The onTick orchestrator. Calls module update functions in order.
-- Owns no data.


local world   = require("core.world")
local units   = require("simulation.unit")
local hauling = require("simulation.hauling")
local events  = require("events.events")

local simulation = {}

function simulation:onTick(time)
    time:updateClock()

    units:update(time)

    world:updateBuildings(time)
    world:updateResources(time)
    world:updatePlants(time)

    if time.tick % HASH_INTERVAL == 0 then
        hauling:update(time)
    end

    units:sweepDead(time)

    -- Calendar-driven ticks
    if time.tick % TICKS_PER_DAY == WAKE_HOUR * TICKS_PER_HOUR
       and time.game_day == CHURCH_DAY then
        events:onSundayService(units.all, time)
    end

    -- if time.tick % TICKS_PER_SEASON == 0 then
    --     units:processSeasonalAging(time)
    -- end
end

return simulation
