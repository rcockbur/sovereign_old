-- simulation/activities.lua
-- Activity lifecycle: posting, claiming, removal, scoring, and handlers.
-- ActivityHandlers lives here — activity system owns the full lifecycle.

local world    = require("core.world")
local registry = require("core.registry")
local log      = require("core.log")

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

return activities
