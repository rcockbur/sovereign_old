-- simulation/dynasty.lua
-- Leader tracking and succession logic.
-- Succession order: eldest living adult Gentry child → any living adult Gentry.


local registry = require("core.registry")
local log      = require("core.log")

local dynasty = {
    leader_id = nil,
}

--- Appoint a unit as leader. Clears any previous leader flag.
function dynasty:appoint(unit)
    self.leader_id  = unit.id
    unit.is_leader  = true
    log:info("WORLD", "%s appointed as leader (id=%d)", unit.name, unit.id)
end

--- Called from units:sweepDead when a leader dies.
--- units_all is passed in to avoid a circular require with simulation/unit.lua.
--- Succession order: eldest living adult Gentry child of the dead leader,
--- then fall back to any living adult Gentry unit.
function dynasty:onLeaderDeath(dead_unit, units_all, time)
    self.leader_id = nil
    log:info("WORLD", "Leader %s has died — seeking successor", dead_unit.name)

    -- Try eldest living adult Gentry child first
    local best = nil
    for i = 1, #dead_unit.child_ids do
        local child = registry[dead_unit.child_ids[i]]
        if child and child.is_dead == false and child.is_child == false
           and child.tier == Tier.GENTRY then
            if best == nil or child.age > best.age then
                best = child
            end
        end
    end
    if best then
        self:appoint(best)
        return
    end

    -- Fall back to any living adult Gentry
    for i = 1, #units_all do
        local unit = units_all[i]
        if unit.is_dead == false and unit.is_child == false
           and unit.tier == Tier.GENTRY then
            self:appoint(unit)
            return
        end
    end

    log:warn("WORLD", "No successor found — settlement has no living Gentry")
end

--- Clear dynasty state. Called on new game / quit-to-menu.
function dynasty:reset()
    self.leader_id = nil
end

--- Stub: return serializable state. Full implementation in Phase 11.
function dynasty:serialize()   return {} end
function dynasty:deserialize(data) end

return dynasty
