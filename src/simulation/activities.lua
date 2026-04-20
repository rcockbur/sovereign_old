-- simulation/activities.lua
-- Activity lifecycle: posting, claiming, removal, scoring, and handlers.
-- ActivityHandlers lives here — activity system owns the full lifecycle.

local world     = require("core.world")
local registry  = require("core.registry")
local log       = require("core.log")
local resources = require("simulation.resources")

local activities = {}

-- Handler dispatch table. Each entry: { nextAction = function(unit, activity) end }
-- Units call activities.handlers[activity.type].nextAction(unit, activity).
local ActivityHandlers = {}
activities.handlers = ActivityHandlers

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

function activities.postActivity(fields)
    local activity = registry.createEntity(world.activities, {
        type           = fields.type,
        purpose        = fields.purpose or "work",
        worker_id      = nil,
        posted_tick    = world.time.tick,
        x              = fields.x or 0,
        y              = fields.y or 0,
        workplace_id   = fields.workplace_id,
        progress       = 0,
        resource_type    = fields.resource_type,
        source_id        = fields.source_id,
        destination_id   = fields.destination_id,
        reserved_amount  = fields.reserved_amount,
    })
    if fields.workplace_id ~= nil then
        local building = registry[fields.workplace_id]
        building.posted_activity_ids[#building.posted_activity_ids + 1] = activity.id
    end
    log:debug("ACTIVITY", "Posted activity %d (type=%s) at (%d,%d)",
        activity.id, activity.type, activity.x, activity.y)
    return activity
end

function activities.removeActivity(activity_id)
    local activity = registry[activity_id]
    if activity == nil then
        return
    end
    -- Clear worker claim
    if activity.worker_id ~= nil then
        local worker = registry[activity.worker_id]
        if worker ~= nil then
            worker.activity_id = nil
        end
    end
    -- Remove from building's posted_activity_ids
    if activity.workplace_id ~= nil then
        local building = registry[activity.workplace_id]
        if building ~= nil then
            local ids = building.posted_activity_ids
            for i = 1, #ids do
                if ids[i] == activity_id then
                    ids[i] = ids[#ids]
                    ids[#ids] = nil
                    break
                end
            end
        end
    end
    -- Swap-and-pop from world.activities
    registry[activity_id] = nil
    for i = 1, #world.activities do
        if world.activities[i].id == activity_id then
            world.activities[i] = world.activities[#world.activities]
            world.activities[#world.activities] = nil
            break
        end
    end
end

function activities.claimActivity(unit, activity)
    activity.worker_id = unit.id
    unit.activity_id   = activity.id
end

function activities.releaseActivity(unit)
    if unit.activity_id == nil then
        return
    end
    local activity = registry[unit.activity_id]
    if activity ~= nil then
        activity.worker_id = nil
    end
    unit.activity_id = nil
end

-- ─── Scoring and polling ──────────────────────────────────────────────────────

local function getActivityPosition(activity)
    -- Hauling: distance to pickup source
    if activity.source_id ~= nil then
        local source = registry[activity.source_id]
        return source.x, source.y
    end
    -- Building-based: distance to building
    if activity.workplace_id ~= nil then
        local building = registry[activity.workplace_id]
        return building.x, building.y
    end
    -- Designation / debug: use tile coordinates directly
    return activity.x, activity.y
end

local function scoreActivity(unit, activity)
    local activity_x, activity_y = getActivityPosition(activity)
    local dist = math.abs(unit.x - activity_x) + math.abs(unit.y - activity_y)
    return ActivityConfig.age_weight * (world.time.tick - activity.posted_tick) - dist
end

local function canClaim(unit, activity)
    if activity.worker_id ~= nil then
        return false
    end
    if activity.type == "haul" then
        if activity.source_id ~= nil
                and resources.findNearestStorage(unit, activity.resource_type, 1) == nil then
            return false
        end
        return unit.class == "serf"
    end
    local type_cfg = ActivityTypeConfig[activity.type]
    if type_cfg == nil then
        return false
    end
    if unit.class == "serf" then
        return type_cfg.is_specialty == false
    elseif unit.class == "freeman" then
        return type_cfg.is_specialty == true
            and type_cfg.class == "freeman"
            and activity.type == unit.specialty
    elseif unit.class == "clergy" then
        return type_cfg.is_specialty == true
            and type_cfg.class == "clergy"
            and activity.type == unit.specialty
    end
    return false  -- gentry do not work
end

function activities.pollBest(unit)
    local best_score    = nil
    local best_activity = nil
    for i = 1, #world.activities do
        local activity = world.activities[i]
        if canClaim(unit, activity) then
            local score = scoreActivity(unit, activity)
            if best_score == nil or score > best_score then
                best_score    = score
                best_activity = activity
            end
        end
    end
    return best_activity
end

-- ─── Designation helpers ──────────────────────────────────────────────────────

function activities.cancelDesignation(tile_idx)
    local tile = world.tiles[tile_idx]
    if tile.designation == nil then
        return
    end
    local act_id = tile.designation_activity_id
    tile.designation             = nil
    tile.designation_activity_id = nil
    if act_id ~= nil then
        local activity = registry[act_id]
        if activity ~= nil and activity.worker_id ~= nil then
            local worker = registry[activity.worker_id]
            if worker ~= nil then
                worker.claimed_tile = nil
            end
        end
        tile.claimed_by = nil
        activities.removeActivity(act_id)
    end
end

-- ─── Ground pile haul ────────────────────────────────────────────────────────

-- Posts a public haul activity for a ground pile + resource type if one doesn't exist.
function activities.postGroundPileHaulIfNeeded(gp, rtype)
    for i = 1, #world.activities do
        local activity = world.activities[i]
        if activity.type == "haul" and activity.source_id == gp.id and activity.resource_type == rtype then
            return
        end
    end
    activities.postActivity({
        type          = "haul",
        x             = gp.x,
        y             = gp.y,
        source_id     = gp.id,
        resource_type = rtype,
    })
end

-- ─── Handlers ─────────────────────────────────────────────────────────────────

-- units module is required lazily to avoid a circular require at load time.
-- By the time any handler's nextAction runs, units.lua is fully initialized.
local units_ref

local function getUnits()
    if units_ref == nil then
        units_ref = require("simulation.units")
    end
    return units_ref
end

-- Debug handler for M14 test activities (type = "fisher").
-- Removed once real fisher/extraction handler arrives in M22.
-- Cycle: travel to activity tile → work for DEBUG_WORK_TICKS → idle.
local DEBUG_WORK_TICKS = 5 * TICKS_PER_MINUTE

ActivityHandlers["fisher"] = {
    nextAction = function(unit, activity)
        local action_type = unit.current_action.type
        if action_type == "idle" then
            local dest_idx = tileIndex(activity.x, activity.y)
            if getUnits().startMove(unit, dest_idx) then
                unit.current_action = { type = "travel" }
            else
                activities.removeActivity(activity.id)
                unit.current_action = { type = "idle" }
            end
        elseif action_type == "travel" then
            unit.current_action = { type = "work", progress = 0, work_ticks = DEBUG_WORK_TICKS }
        elseif action_type == "work" then
            log:info("ACTIVITY", "Unit %d (%s) finished work at (%d,%d)",
                unit.id, unit.name, activity.x, activity.y)
            activities.removeActivity(activity.id)
            unit.current_action = { type = "idle" }
        end
    end
}

local function findNearestDesignation(unit, act_type)
    local best_dist = nil
    local best_act  = nil
    for i = 1, #world.activities do
        local activity = world.activities[i]
        if activity.type == act_type and activity.worker_id == nil then
            local dist = math.abs(unit.x - activity.x) + math.abs(unit.y - activity.y)
            if best_dist == nil or dist < best_dist then
                best_dist = dist
                best_act  = activity
            end
        end
    end
    return best_act
end

ActivityHandlers["woodcutter"] = {
    nextAction = function(unit, activity)
        local phase = activity.phase

        if phase == nil then
            -- Claim the resource tile and path adjacent to it
            local tile_idx = tileIndex(activity.x, activity.y)
            local tile     = world.tiles[tile_idx]
            tile.claimed_by   = unit.id
            unit.claimed_tile = tile_idx
            if getUnits().startMoveAdjacentToRect(unit, activity.x, activity.y, 1, 1) then
                activity.phase      = "travel_tree"
                unit.current_action = { type = "travel" }
            else
                tile.claimed_by   = nil
                unit.claimed_tile = nil
                activities.releaseActivity(unit)
                unit.current_action = { type = "idle" }
            end

        elseif phase == "travel_tree" then
            -- Arrived adjacent to tree: validate plant still exists
            local tile = world.tiles[tileIndex(activity.x, activity.y)]
            if tile.plant_type == nil then
                if unit.claimed_tile ~= nil then
                    world.tiles[unit.claimed_tile].claimed_by = nil
                    unit.claimed_tile = nil
                end
                if tile.designation_activity_id == activity.id then
                    tile.designation             = nil
                    tile.designation_activity_id = nil
                end
                activities.removeActivity(activity.id)
                unit.current_action = { type = "idle" }
                return
            end
            activity.phase = "work"
            unit.current_action = {
                type       = "work",
                progress   = 0,
                work_ticks = PlantConfig[tile.plant_type].harvest_ticks,
            }

        elseif phase == "work" then
            -- Chop complete: remove tree, grant wood, clear tile
            local tile_idx  = tileIndex(activity.x, activity.y)
            local tile      = world.tiles[tile_idx]
            local plant_cfg = PlantConfig["tree"]

            tile.plant_type  = nil
            tile.plant_growth = 0
            tile.claimed_by   = nil
            unit.claimed_tile = nil
            tile.designation             = nil
            tile.designation_activity_id = nil

            resources.carryResource(unit, "wood", plant_cfg.harvest_yield)
            log:info("ACTIVITY", "Unit %d (%s) chopped tree at (%d,%d), carrying %d wood",
                unit.id, unit.name, activity.x, activity.y,
                resources.countWeight(unit.carrying) / ResourceConfig["wood"].weight)

            -- Chain: can carry another yield AND an unclaimed designation exists?
            if unit:carryableAmount("wood") >= plant_cfg.harvest_yield then
                local next_act = findNearestDesignation(unit, "woodcutter")
                if next_act ~= nil then
                    activities.removeActivity(activity.id)
                    activities.claimActivity(unit, next_act)
                    activities.handlers["woodcutter"].nextAction(unit, next_act)
                    return
                end
            end

            -- Self-deposit: keep activity alive to drive the deposit travel
            local carry_amount = registry[unit.carrying[1]].amount
            local storage = resources.findNearestStorage(unit, "wood", 1)
            if storage ~= nil then
                local reserve_amount = math.min(carry_amount, resources.getAvailableCapacity(storage.storage, "wood"))
                resources.reserve(storage.storage, "wood", reserve_amount, "in")
                activity.phase           = "travel_deposit"
                activity.storage_id      = storage.id
                activity.reserved_amount = reserve_amount
                if getUnits().startMoveAdjacentToRect(
                    unit, storage.x, storage.y, storage.width, storage.height) then
                    unit.current_action = { type = "travel" }
                else
                    resources.releaseReservation(storage.storage, "wood", reserve_amount, "in")
                    activities.removeActivity(activity.id)
                    unit.current_action = { type = "idle" }
                end
            else
                -- No storage: ground drop
                if #unit.carrying > 0 then
                    local rtype = registry[unit.carrying[1]].type
                    local gp = resources.groundDrop(unit)
                    if gp ~= nil then
                        activities.postGroundPileHaulIfNeeded(gp, rtype)
                    end
                end
                activities.removeActivity(activity.id)
                unit.current_action = { type = "idle" }
            end

        elseif phase == "travel_deposit" then
            -- Arrived at stockpile: deposit all wood
            local storage = registry[activity.storage_id]
            if storage == nil then
                -- Stockpile gone: ground drop
                if #unit.carrying > 0 then
                    local rtype = registry[unit.carrying[1]].type
                    local gp = resources.groundDrop(unit)
                    if gp ~= nil then
                        activities.postGroundPileHaulIfNeeded(gp, rtype)
                    end
                end
            elseif #unit.carrying > 0 then
                local stack = registry[unit.carrying[1]]
                if stack ~= nil then
                    local ids = resources.withdrawFromCarrying(unit, stack.type, activity.reserved_amount)
                    for i = 1, #ids do
                        resources.deposit(storage.storage, ids[i])
                    end
                    log:info("ACTIVITY", "Unit %d (%s) deposited %d wood at building %d",
                        unit.id, unit.name, activity.reserved_amount, storage.id)
                end
            end
            activities.removeActivity(activity.id)
            unit.current_action = { type = "idle" }
        end
    end
}

ActivityHandlers["gatherer"] = {
    nextAction = function(unit, activity)
        local phase = activity.phase

        if phase == nil then
            -- Claim the resource tile and path adjacent to it
            local tile_idx = tileIndex(activity.x, activity.y)
            local tile     = world.tiles[tile_idx]
            tile.claimed_by   = unit.id
            unit.claimed_tile = tile_idx
            if getUnits().startMoveAdjacentToRect(unit, activity.x, activity.y, 1, 1) then
                activity.phase      = "travel_bush"
                unit.current_action = { type = "travel" }
            else
                tile.claimed_by   = nil
                unit.claimed_tile = nil
                activities.releaseActivity(unit)
                unit.current_action = { type = "idle" }
            end

        elseif phase == "travel_bush" then
            -- Arrived adjacent to bush: validate plant still mature
            local tile = world.tiles[tileIndex(activity.x, activity.y)]
            if tile.plant_type ~= "berry_bush" or tile.plant_growth < 3 then
                if unit.claimed_tile ~= nil then
                    world.tiles[unit.claimed_tile].claimed_by = nil
                    unit.claimed_tile = nil
                end
                if tile.designation_activity_id == activity.id then
                    tile.designation             = nil
                    tile.designation_activity_id = nil
                end
                activities.removeActivity(activity.id)
                unit.current_action = { type = "idle" }
                return
            end
            activity.phase = "work"
            unit.current_action = {
                type       = "work",
                progress   = 0,
                work_ticks = PlantConfig["berry_bush"].harvest_ticks,
            }

        elseif phase == "work" then
            -- Harvest complete: reset bush to seedling, grant berries
            local tile_idx  = tileIndex(activity.x, activity.y)
            local tile      = world.tiles[tile_idx]
            local plant_cfg = PlantConfig["berry_bush"]

            tile.plant_growth = 1
            tile.claimed_by   = nil
            unit.claimed_tile = nil
            tile.designation             = nil
            tile.designation_activity_id = nil

            resources.carryResource(unit, "berries", plant_cfg.harvest_yield)
            log:info("ACTIVITY", "Unit %d (%s) gathered berries at (%d,%d), carrying %d berries",
                unit.id, unit.name, activity.x, activity.y,
                resources.countWeight(unit.carrying) / ResourceConfig["berries"].weight)

            -- Chain: can carry another yield AND an unclaimed designation exists?
            if unit:carryableAmount("berries") >= plant_cfg.harvest_yield then
                local next_act = findNearestDesignation(unit, "gatherer")
                if next_act ~= nil then
                    activities.removeActivity(activity.id)
                    activities.claimActivity(unit, next_act)
                    activities.handlers["gatherer"].nextAction(unit, next_act)
                    return
                end
            end

            -- Self-deposit: keep activity alive to drive the deposit travel
            local carry_amount = registry[unit.carrying[1]].amount
            local storage = resources.findNearestStorage(unit, "berries", 1)
            if storage ~= nil then
                local reserve_amount = math.min(carry_amount, resources.getAvailableCapacity(storage.storage, "berries"))
                resources.reserve(storage.storage, "berries", reserve_amount, "in")
                activity.phase           = "travel_deposit"
                activity.storage_id      = storage.id
                activity.reserved_amount = reserve_amount
                if getUnits().startMoveAdjacentToRect(
                    unit, storage.x, storage.y, storage.width, storage.height) then
                    unit.current_action = { type = "travel" }
                else
                    resources.releaseReservation(storage.storage, "berries", reserve_amount, "in")
                    activities.removeActivity(activity.id)
                    unit.current_action = { type = "idle" }
                end
            else
                -- No storage: ground drop
                if #unit.carrying > 0 then
                    local rtype = registry[unit.carrying[1]].type
                    local gp = resources.groundDrop(unit)
                    if gp ~= nil then
                        activities.postGroundPileHaulIfNeeded(gp, rtype)
                    end
                end
                activities.removeActivity(activity.id)
                unit.current_action = { type = "idle" }
            end

        elseif phase == "travel_deposit" then
            -- Arrived at stockpile: deposit all berries
            local storage = registry[activity.storage_id]
            if storage == nil then
                -- Stockpile gone: ground drop
                if #unit.carrying > 0 then
                    local rtype = registry[unit.carrying[1]].type
                    local gp = resources.groundDrop(unit)
                    if gp ~= nil then
                        activities.postGroundPileHaulIfNeeded(gp, rtype)
                    end
                end
            elseif #unit.carrying > 0 then
                local stack = registry[unit.carrying[1]]
                if stack ~= nil then
                    local ids = resources.withdrawFromCarrying(unit, stack.type, activity.reserved_amount)
                    for i = 1, #ids do
                        resources.deposit(storage.storage, ids[i])
                    end
                    log:info("ACTIVITY", "Unit %d (%s) deposited %d berries at building %d",
                        unit.id, unit.name, activity.reserved_amount, storage.id)
                end
            end
            activities.removeActivity(activity.id)
            unit.current_action = { type = "idle" }
        end
    end
}

-- Haul handler: drives both public (ground pile pickup) and private (offload deposit) haul activities.
-- Public:  source_id = ground_pile id, destination_id = nil (resolved in nil phase)
-- Private: source_id = nil (unit already carrying), destination_id = storage id
--
-- Reservations made in nil phase:
--   Public:  reserve_out at pile (pick_amount items), reserve_in at dest (pick_weight)
--   Private: reserve_in at dest already made by onActionComplete before handler is called
ActivityHandlers["haul"] = {
    nextAction = function(unit, activity)
        local phase = activity.phase

        if phase == nil then
            if activity.source_id == nil then
                -- Private offload: unit is already carrying; path to destination.
                local dest = registry[activity.destination_id]
                if dest == nil then
                    local gp = resources.groundDrop(unit)
                    if gp ~= nil then
                        activities.postGroundPileHaulIfNeeded(gp, activity.resource_type)
                    end
                    activities.removeActivity(activity.id)
                    unit.current_action = { type = "idle" }
                    return
                end
                if getUnits().startMoveAdjacentToRect(unit, dest.x, dest.y, dest.width, dest.height) then
                    activity.phase      = "travel_deposit"
                    unit.current_action = { type = "travel" }
                else
                    resources.releaseReservation(dest.storage, activity.resource_type, activity.reserved_amount, "in")
                    local gp = resources.groundDrop(unit)
                    if gp ~= nil then
                        activities.postGroundPileHaulIfNeeded(gp, activity.resource_type)
                    end
                    activities.removeActivity(activity.id)
                    unit.current_action = { type = "idle" }
                end

            else
                -- Public pickup: resolve destination, reserve, travel to pile.
                local gp = registry[activity.source_id]
                if gp == nil then
                    activities.removeActivity(activity.id)
                    unit.current_action = { type = "idle" }
                    return
                end
                local avail = resources.getAvailableStock(gp, activity.resource_type)
                local pick  = math.min(avail, unit:carryableAmount(activity.resource_type))
                if pick <= 0 then
                    activities.releaseActivity(unit)
                    unit.current_action = { type = "idle" }
                    return
                end
                local dest = resources.findNearestStorage(unit, activity.resource_type, pick)
                if dest == nil then
                    activities.releaseActivity(unit)
                    unit.current_action = { type = "idle" }
                    return
                end
                resources.reserve(gp, activity.resource_type, pick, "out")
                resources.reserve(dest.storage, activity.resource_type, pick, "in")
                activity.destination_id  = dest.id
                activity.reserved_amount = pick
                if getUnits().startMoveAdjacentToRect(unit, gp.x, gp.y, 1, 1) then
                    activity.phase      = "travel_pickup"
                    unit.current_action = { type = "travel" }
                else
                    resources.releaseReservation(gp, activity.resource_type, pick, "out")
                    resources.releaseReservation(dest.storage, activity.resource_type, pick, "in")
                    activities.releaseActivity(unit)
                    unit.current_action = { type = "idle" }
                end
            end

        elseif phase == "travel_pickup" then
            local gp    = registry[activity.source_id]
            local dest  = registry[activity.destination_id]
            local rtype = activity.resource_type

            if gp == nil then
                if dest ~= nil then
                    resources.releaseReservation(dest.storage, rtype, activity.reserved_amount, "in")
                end
                activities.removeActivity(activity.id)
                unit.current_action = { type = "idle" }
                return
            end

            local actual_stock = resources.getStock(gp, rtype)
            local actual_pick  = math.min(activity.reserved_amount, actual_stock,
                                          unit:carryableAmount(rtype))
            if actual_pick > 0 then
                local ids = resources.withdraw(gp, rtype, actual_pick)
                for i = 1, #ids do
                    resources.carryEntity(unit, ids[i])
                end
            end

            if actual_pick < activity.reserved_amount then
                resources.releaseReservation(gp, rtype, activity.reserved_amount - actual_pick, "out")
                if dest ~= nil then
                    resources.releaseReservation(dest.storage, rtype, activity.reserved_amount - actual_pick, "in")
                end
            end
            activity.reserved_amount = actual_pick

            if actual_pick > 0 and dest ~= nil
                    and getUnits().startMoveAdjacentToRect(unit, dest.x, dest.y, dest.width, dest.height) then
                activity.phase      = "travel_deposit"
                unit.current_action = { type = "travel" }
                return
            end

            -- Can't reach destination or nothing picked up.
            if dest ~= nil and actual_pick > 0 then
                resources.releaseReservation(dest.storage, rtype, actual_pick, "in")
            end
            if actual_pick > 0 then
                local gp2 = resources.groundDrop(unit)
                if gp2 ~= nil then
                    activities.postGroundPileHaulIfNeeded(gp2, rtype)
                end
            end
            local remaining = resources.getStock(gp, rtype)
            activities.removeActivity(activity.id)
            if remaining > 0 then
                activities.postGroundPileHaulIfNeeded(gp, rtype)
            end
            if #gp.contents == 0 then
                resources.destroyGroundPile(gp)
            end
            unit.current_action = { type = "idle" }

        elseif phase == "travel_deposit" then
            local dest  = registry[activity.destination_id]
            local rtype = activity.resource_type

            if dest ~= nil and #unit.carrying > 0 then
                local stack = registry[unit.carrying[1]]
                local ids   = resources.withdrawFromCarrying(unit, stack.type, activity.reserved_amount)
                for i = 1, #ids do
                    resources.deposit(dest.storage, ids[i])
                end
                log:info("HAUL", "Unit %d (%s) deposited %d %s at building %d",
                    unit.id, unit.name, activity.reserved_amount, rtype, dest.id)
            elseif dest == nil and #unit.carrying > 0 then
                local gp2 = resources.groundDrop(unit)
                if gp2 ~= nil then
                    activities.postGroundPileHaulIfNeeded(gp2, rtype)
                end
            end

            -- For public haul: re-post if pile still has this type, destroy if empty.
            local gp = activity.source_id ~= nil and registry[activity.source_id] or nil
            activities.removeActivity(activity.id)
            if gp ~= nil then
                if resources.getStock(gp, rtype) > 0 then
                    activities.postGroundPileHaulIfNeeded(gp, rtype)
                end
                if #gp.contents == 0 then
                    resources.destroyGroundPile(gp)
                end
            end
            unit.current_action = { type = "idle" }
        end
    end
}

return activities
