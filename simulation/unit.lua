-- simulation/unit.lua
-- Owns unit state, creation, death cleanup, and the hash-offset update loop.
-- Returns the `units` collection module. Individual units use the Unit prototype
-- for per-unit methods.


local registry = require("core.registry")
local log      = require("core.log")
local world    = require("core.world")
local needs    = require("simulation.needs")
local mood     = require("simulation.mood")
local health   = require("simulation.health")
local jobqueue = require("simulation.jobqueue")
local dynasty  = require("simulation.dynasty")


local math_random = math.random

-- ---------------------------------------------------------------------------
-- Unit prototype — per-unit methods
-- ---------------------------------------------------------------------------

local Unit = {}
Unit.__index = Unit

function Unit:onHash(time)
    -- Step 1: Drain needs
    --log:info("UNIT", "%s still alive on tick %d", self.name, time.tick)
    needs.drain(self, time)

    if self.is_drafted == false then
        -- Step 2: Hard need interrupt — drop everything, self-assign immediately
        local hard_interrupted = needs.checkHard(self)
        if hard_interrupted == false then
            -- Step 3: Soft need interrupt — finish delivery, then self-assign
            local soft_interrupted = needs.checkSoft(self)
            if soft_interrupted == false then
                -- Step 4: Offload check (Phase 11)
                -- If carrying and not mid-delivery, deposit to nearest stockpile first.

                -- Step 5: Poll job queue
                if self.current_job_id == nil then
                    jobqueue:claimJob(self, time)
                end
            end
        end
    else
        -- Drafted exception: energy = 0 → auto-undraft and force sleep
        if self.needs.energy <= 0 then
            self.is_drafted       = false
            self.current_activity = "sleeping"
            log:info("UNIT", "%s collapsed from exhaustion (auto-undraft)", self.name)
        end
    end

    -- Step 6: Execute work progress (Phase 11)

    -- Step 7: Recalculate mood (stateless)
    mood.recalculate(self, time)

    -- Step 8: Recalculate health (stateless; death check inside)
    health.recalculate(self, time)
end

-- ---------------------------------------------------------------------------
-- Units collection module
-- ---------------------------------------------------------------------------

local units = {
    all = {},
}

--- Create a new unit, insert into registry and units.all, and return it.
function units:create(params)
    local is_male = params.is_male ~= nil and params.is_male or (math_random(2) == 1)
    local name = params.name or (is_male and MALE_NAMES[math_random(#MALE_NAMES)] or FEMALE_NAMES[math_random(#FEMALE_NAMES)])

    local unit = setmetatable({
        id      = registry:nextId(),
        is_male = is_male,
        name    = name,
        tier = params.tier or Tier.SERF,

        is_dead    = false,
        is_drafted = false,

        age          = params.age or math_random(16, 40),
        birth_day    = params.birth_day    or 1,
        birth_season = params.birth_season or 1,
        is_child     = params.is_child     or false,
        is_attending_school = false,

        is_leader = params.is_leader or false,

        father_id = nil, mother_id = nil,
        child_ids = {}, spouse_id = nil,
        friend_ids = {}, enemy_ids = {},

        attributes = {
            strength     = params.strength     or math_random(3, 8),
            dexterity    = params.dexterity    or math_random(3, 8),
            intelligence = params.intelligence or math_random(3, 8),
            wisdom       = params.wisdom       or math_random(3, 8),
            charisma     = params.charisma     or math_random(3, 8),
        },

        skills = {
            melee_combat = 0, smithing    = 0, hunting  = 0, tailoring  = 0,
            baking       = 0, brewing     = 0, construction = 0, scholarship = 0,
            herbalism    = 0, medicine    = 0, priesthood   = 0, barkeeping  = 0,
            trading      = 0, jewelry     = 0, leadership   = 0,
        },

        needs = {
            satiation  = 100,
            energy     = 100,
            recreation = 100,
        },

        mood             = 0,
        mood_modifiers   = {},
        health           = 100,
        health_modifiers = {},

        carrying     = nil,
        claimed_tile = nil,

        current_job_id   = nil,
        current_activity = nil,

        home_id   = nil,
        bed_index = nil,

        x = params.x or 1,
        y = params.y or 1,

        visible_a      = {},
        visible_b      = {},
        active_visible = "a",
    }, Unit)

    registry:insert(unit)
    table.insert(self.all, unit)
    log:info("UNIT", "created %s (id=%d, tier=%d) at (%d,%d)", unit.name, unit.id, unit.tier, unit.x, unit.y)
    return unit
end

--- Hash-offset update loop. Each unit updates once per HASH_INTERVAL ticks.
function units:update(time)
    for i = 1, #self.all do
        local unit = self.all[i]
        if unit.is_dead == false then
            if (time.tick + time:hashOffset(unit.id)) % HASH_INTERVAL == 0 then
                unit:onHash(time)
            end
        end
    end
end

--- End-of-tick cleanup. Convert dead units to memories and remove all references.
function units:sweepDead(time)
    local i = 1
    while i <= #self.all do
        local unit = self.all[i]
        if unit.is_dead then
            log:info("UNIT", "%s has died (cause: %s)", unit.name, unit.death_cause or "unknown")

            -- 1. Convert to memory
            local memory = {
                id           = unit.id,
                name         = unit.name,
                father_id    = unit.father_id,
                mother_id    = unit.mother_id,
                child_ids    = unit.child_ids,
                spouse_id    = unit.spouse_id,
                death_day    = time.game_day,
                death_season = time.game_season,
                death_year   = time.game_year,
                death_cause  = unit.death_cause or "unknown",
            }

            -- 2. Update registry — id now points to the memory
            registry:insert(memory)

            -- 3. Social cleanup: remove dead unit's id from all living units' lists
            for j = 1, #self.all do
                local other = self.all[j]
                if other ~= unit and other.is_dead == false then
                    for k = #other.friend_ids, 1, -1 do
                        if other.friend_ids[k] == unit.id then
                            table.remove(other.friend_ids, k)
                        end
                    end
                    for k = #other.enemy_ids, 1, -1 do
                        if other.enemy_ids[k] == unit.id then
                            table.remove(other.enemy_ids, k)
                        end
                    end
                end
            end

            -- 4. Family references intentionally stay (father_id/spouse_id to a memory is correct)

            -- 5. Job cleanup
            if unit.current_job_id ~= nil then
                jobqueue:releaseJob(unit.current_job_id)
            end

            -- 6. Tile claim cleanup
            if unit.claimed_tile ~= nil then
                local tile = world.tiles[unit.claimed_tile]
                if tile then tile.claimed_by = nil end
            end

            -- 7. Building cleanup (Phase 6)
            -- if unit.building_id ~= nil then
            --     building:removeWorker(registry[unit.building_id], unit.id)
            -- end

            -- 8. Home cleanup (Phase 6)
            -- if unit.home_id ~= nil then
            --     households:removeMember(registry[unit.home_id], unit.id)
            -- end

            -- 9. Dynasty check
            if unit.is_leader then dynasty:onLeaderDeath(unit, self.all, time) end

            -- 10. Swap-and-pop from units.all
            self.all[i] = self.all[#self.all]
            self.all[#self.all] = nil
            -- do not increment i — recheck this slot
        else
            i = i + 1
        end
    end
end

--- Clear all unit state. Called on new game / quit-to-menu.
function units:reset()
    self.all = {}
end

--- Stub: return serializable state. Full implementation in Phase 11.
function units:serialize()   return {} end
function units:deserialize(data) end

return units
