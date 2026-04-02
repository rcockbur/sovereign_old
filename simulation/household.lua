-- simulation/household.lua
-- Household creation and member management. Tied to housing buildings.
-- Consumption checks stubbed for Phase 11.


local log = require("core.log")

local households = {
    all = {},
}

--- Create a household attached to a housing building.
function households:create(building_id)
    local household = {
        building_id       = building_id,
        member_ids        = {},
        food              = { bread = 0, berries = 0, meat = 0, fish = 0 },
        clothing          = 0,
        jewelry           = 0,
        max_food_per_type = 10,
        max_clothing      = 5,
        max_jewelry       = 2,
    }
    table.insert(self.all, household)
    log:info("WORLD", "created household for building %d", building_id)
    return household
end

--- Add a unit to a household.
function households:addMember(household, unit_id)
    table.insert(household.member_ids, unit_id)
end

--- Remove a unit from a household (swap-and-pop).
function households:removeMember(household, unit_id)
    for i = 1, #household.member_ids do
        if household.member_ids[i] == unit_id then
            household.member_ids[i] = household.member_ids[#household.member_ids]
            household.member_ids[#household.member_ids] = nil
            return
        end
    end
end

--- Stub: consume food, clothing, and jewelry per member per period.
function households:checkConsumption(household, time)
    -- Phase 11: deduct from household stocks; apply mood modifiers for shortfalls
end

return households
