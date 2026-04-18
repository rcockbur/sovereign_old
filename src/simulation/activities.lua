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
        resource_type  = fields.resource_type,
        source_id      = fields.source_id,
        destination_id = fields.destination_id,
        is_private     = fields.is_private or false,
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
    if activity == nil then return end
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
    if unit.activity_id == nil then return end
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
    local ax, ay = getActivityPosition(activity)
    local dist = math.abs(unit.x - ax) + math.abs(unit.y - ay)
    return ActivityConfig.age_weight * (world.time.tick - activity.posted_tick) - dist
end

local function canClaim(unit, activity)
    if activity.worker_id ~= nil then return false end
    if activity.is_private == true then return false end
    local type_cfg = ActivityTypeConfig[activity.type]
    if type_cfg == nil then return false end
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
    if tile.designation == nil then return end
    local act_id = tile.designation_activity_id
    tile.designation             = nil
    tile.designation_activity_id = nil
    if act_id ~= nil then
        local act = registry[act_id]
        if act ~= nil and act.worker_id ~= nil then
            local worker = registry[act.worker_id]
            if worker ~= nil then
                worker.claimed_tile = nil
            end
        end
        tile.claimed_by = nil
        activities.removeActivity(act_id)
    end
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
        local a = world.activities[i]
        if a.type == act_type and a.worker_id == nil then
            local dist = math.abs(unit.x - a.x) + math.abs(unit.y - a.y)
            if best_dist == nil or dist < best_dist then
                best_dist = dist
                best_act  = a
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
                if tile.designation_activity_id == activity.id then
                    tile.designation             = nil
                    tile.designation_activity_id = nil
                end
                activities.removeActivity(activity.id)
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
            local storage = resources.findNearestStorage(unit, "wood")
            if storage ~= nil then
                activity.phase      = "travel_deposit"
                activity.storage_id = storage.id
                if getUnits().startMoveAdjacentToRect(
                    unit, storage.x, storage.y, storage.width, storage.height) then
                    unit.current_action = { type = "travel" }
                else
                    activities.removeActivity(activity.id)
                    unit.current_action = { type = "idle" }
                end
            else
                activities.removeActivity(activity.id)
                unit.current_action = { type = "idle" }
            end

        elseif phase == "travel_deposit" then
            -- Arrived at stockpile: deposit all wood
            local storage = registry[activity.storage_id]
            if storage ~= nil and #unit.carrying > 0 then
                local stack = registry[unit.carrying[1]]
                if stack ~= nil then
                    local ids = resources.withdrawFromCarrying(unit, stack.type, stack.amount)
                    for i = 1, #ids do
                        resources.deposit(storage.storage, ids[i])
                    end
                    log:info("ACTIVITY", "Unit %d (%s) deposited wood at building %d",
                        unit.id, unit.name, storage.id)
                end
            end
            activities.removeActivity(activity.id)
            unit.current_action = { type = "idle" }
        end
    end
}

return activities
