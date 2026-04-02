-- simulation/hauling.lua
-- Scans buildings with hauling rules and posts deficit-based hauling jobs.
-- Runs on a hash-interval cadence from simulation:onTick.
-- Push: building output exceeds threshold → post job to move to stockpile.
-- Pull: building input is below threshold → post job to fetch from stockpile.
-- Stub: scan structure is real; posting logic waits for inventory (Phase 6).


local world    = require("core.world")
local jobqueue = require("simulation.jobqueue")
local log      = require("core.log")

local hauling = {}

--- Count total units of a resource across all inventory slots.
local function inventoryCount(inventory, resource)
    local total = 0
    for i = 1, #inventory.slots do
        local slot = inventory.slots[i]
        if slot.resource == resource then
            total = total + slot.amount
        end
    end
    return total
end

--- Post a hauling job if the output inventory of a building exceeds the push threshold.
function hauling:checkPush(building, rule, time)
    if building.output == nil then return end
    local count = inventoryCount(building.output, rule.resource)
    if count >= rule.threshold then
        -- Phase 6: find nearest stockpile with capacity and post haul job
        log:debug("HAUL", "building %d has %d %s (push threshold %d) — job pending stockpile lookup",
            building.id, count, rule.resource, rule.threshold)
    end
end

--- Post a hauling job if the input inventory of a building is below the pull threshold.
function hauling:checkPull(building, rule, time)
    if building.input == nil then return end
    local count = inventoryCount(building.input, rule.resource)
    if count < rule.threshold then
        -- Phase 6: find nearest stockpile with stock and post haul job
        log:debug("HAUL", "building %d has %d %s (pull threshold %d) — job pending stockpile lookup",
            building.id, count, rule.resource, rule.threshold)
    end
end

--- Scan all buildings with hauling rules. Called periodically from simulation:onTick.
function hauling:update(time)
    for i = 1, #world.buildings do
        local building = world.buildings[i]
        if building.hauling_rules ~= nil then
            for _, rule in ipairs(building.hauling_rules) do
                if rule.direction == "push" then
                    self:checkPush(building, rule, time)
                elseif rule.direction == "pull" then
                    self:checkPull(building, rule, time)
                end
            end
        end
    end
end

return hauling
