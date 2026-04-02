-- simulation/needs.lua
-- Need drain and interrupt logic. Reads NeedsConfig (set by config/needs.lua).
-- Called from unit:update once per HASH_INTERVAL ticks, so rates are
-- multiplied by HASH_INTERVAL to apply the correct per-tick delta.

local math_max = math.max

local needs = {}

--- Drain all three needs by one hash interval's worth of drain.
function needs.drain(unit, time)
    local cfg = NeedsConfig[unit.is_child and "child" or unit.tier]
    unit.needs.satiation  = math_max(0, unit.needs.satiation  - cfg.satiation.drain  * HASH_INTERVAL)
    unit.needs.energy     = math_max(0, unit.needs.energy     - cfg.energy.drain     * HASH_INTERVAL)
    unit.needs.recreation = math_max(0, unit.needs.recreation - cfg.recreation.drain * HASH_INTERVAL)
end

--- Hard interrupt: need is critically low. Drop everything and self-assign immediately.
--- Skipped if is_drafted. Returns true if an interrupt fired.
function needs.checkHard(unit)
    local cfg = NeedsConfig[unit.is_child and "child" or unit.tier]
    if unit.needs.satiation <= cfg.satiation.hard_threshold then
        needs.selfAssignEat(unit)
        return true
    end
    if unit.needs.energy <= cfg.energy.hard_threshold then
        needs.selfAssignSleep(unit)
        return true
    end
    if unit.needs.recreation <= cfg.recreation.hard_threshold then
        needs.selfAssignRecreate(unit)
        return true
    end
    return false
end

--- Soft interrupt: need is low but not critical. Finish current delivery first,
--- then self-assign. Returns true if an interrupt fired.
function needs.checkSoft(unit)
    -- Don't interrupt mid-delivery (unit is carrying resources to a destination)
    if unit.carrying ~= nil then return false end

    local cfg = NeedsConfig[unit.is_child and "child" or unit.tier]
    if unit.needs.satiation <= cfg.satiation.soft_threshold then
        needs.selfAssignEat(unit)
        return true
    end
    if unit.needs.energy <= cfg.energy.soft_threshold then
        needs.selfAssignSleep(unit)
        return true
    end
    if unit.needs.recreation <= cfg.recreation.soft_threshold then
        needs.selfAssignRecreate(unit)
        return true
    end
    return false
end

--- Self-assign behaviors. Stubs: pathfinding and action execution Phase 11.

function needs.selfAssignEat(unit)
    unit.current_activity = "eating"
    unit.current_job_id   = nil
    -- Phase 11: find nearest food source or household food stock and path there
end

function needs.selfAssignSleep(unit)
    unit.current_activity = "sleeping"
    unit.current_job_id   = nil
    -- Phase 11: path to assigned bed or nearest rest spot
end

function needs.selfAssignRecreate(unit)
    unit.current_activity = "socializing"
    unit.current_job_id   = nil
    -- Phase 11: path to tavern, church square, or nearest idle unit
end

return needs
