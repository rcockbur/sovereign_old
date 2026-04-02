-- events/events.lua
-- Scheduled and triggered events: Sunday service, funerals, weddings.
-- Changeling and Fey are placeholder stubs for future content.


local log = require("core.log")

local events = {}

--- Called once per week on Sunday morning (from simulation:onTick modulo check).
--- Applies a decaying church-attendance mood modifier to every living unit.
--- units_all is passed in to avoid a circular require with simulation/unit.lua.
function events:onSundayService(units_all, time)
    log:info("WORLD", "Sunday service (day=%d season=%d year=%d)",
        time.game_day, time.game_season, time.game_year)
    for i = 1, #units_all do
        local unit = units_all[i]
        if unit.is_dead == false then
            table.insert(unit.mood_modifiers, {
                source          = "church_attendance",
                value           = 10,
                ticks_remaining = 3 * TICKS_PER_DAY,
            })
        end
    end
end

--- Stub: apply grief mood modifiers to family and friends of the deceased.
function events:onFuneral(dead_unit, units_all, time)
    -- Phase 11
end

--- Stub: apply celebration mood modifiers to attendees of a wedding.
function events:onWedding(unit_a, unit_b, units_all, time)
    -- Phase 11
end

--- Placeholder: a Serf child is secretly a Changeling.
function events:onChangeling(time)
    -- Future content
end

--- Placeholder: strange occurrences near the deep forest.
function events:onFey(time)
    -- Future content
end

return events
