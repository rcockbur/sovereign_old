-- simulation/units.lua
-- Unit lifecycle: creation, spawn, death sweep. Operates on world.units.

local world    = require("core.world")
local registry = require("core.registry")
local log      = require("core.log")

local units = {}

function units.spawnSerf(x, y)
    local tile_idx = tileIndex(x, y)
    local t = world.tiles[tile_idx]
    if t.target_of_unit ~= nil then return nil end

    local gender     = math.random() < 0.5 and "male" or "female"
    local name_list  = gender == "male" and NameConfig.male or NameConfig.female
    local first_name = name_list[math.random(#name_list)]
    local surname    = NameConfig.surname[math.random(#NameConfig.surname)]

    local unit = registry.createEntity(world.units, {
        name = first_name, surname = surname, gender = gender, class = "serf",
        is_dead = false, is_drafted = false, draft_tile = nil,
        age = 20, birth_day = 1, birth_season = 1, death_age = 60, is_child = false,
        is_leader = false, specialty = nil, needs_tier = "meager",
        father_id = nil, mother_id = nil, child_ids = {}, spouse_id = nil,
        friend_ids = {}, enemy_ids = {},
        is_pregnant = false, pregnancy_season_count = 0,
        traits = {},
        genetic_attributes  = { strength = 0, intelligence = 0, charisma = 0 },
        base_attributes     = { strength = 1, intelligence = 1, charisma = 1 },
        acquired_attributes = { strength = 0, intelligence = 0, charisma = 0 },
        skills = {
            smithing = 0, smelting = 0, tailoring = 0, baking = 0, brewing = 0,
            teaching = 0, research = 0, medicine = 0, priesthood = 0,
            barkeeping = 0, trading = 0,
        },
        skill_progress = {
            smithing = 0, smelting = 0, tailoring = 0, baking = 0, brewing = 0,
            teaching = 0, research = 0, medicine = 0, priesthood = 0,
            barkeeping = 0, trading = 0,
        },
        needs          = { satiation = 100, energy = 100, recreation = 100 },
        mood           = 0,
        mood_modifiers = {},
        health         = 100,
        health_modifiers = {},
        equipped       = { tool = nil, clothing = nil },
        carrying       = {},
        claimed_tile   = nil,
        activity_id               = nil,
        secondary_haul_activity_id = nil,
        current_action        = { type = "idle" },
        soft_interrupt_pending = false,
        home_id = nil, bed_index = nil,
        work_hours            = 11,
        work_ticks_remaining  = 0,
        is_done_working       = false,
        x = x, y = y,
        target_tile  = nil,
        last_ate     = {},
        move_progress = 0,
        move_speed    = 1.0,
        path          = nil,
        visible_a     = {}, visible_b = {}, active_visible = "a",
    })

    unit.target_tile   = tile_idx
    t.target_of_unit   = unit.id
    t.unit_ids[#t.unit_ids + 1] = unit.id

    log:info("UNIT", "Spawned %s %s at (%d, %d)", unit.name, unit.surname, x, y)
    return unit
end

function units.spawnStarting()
    local half    = math.floor(GEN_START_SIZE / 2)
    local x_start = GEN_START_X - half + 1
    local x_end   = GEN_START_X + half
    local y_start = GEN_START_Y - half + 1
    local y_end   = GEN_START_Y + half

    local count = 0
    for x = x_start, x_end do
        for y = y_start, y_end do
            if world.tiles[tileIndex(x, y)].target_of_unit == nil then
                units.spawnSerf(x, y)
                count = count + 1
                if count == 6 then return end
            end
        end
    end
end

return units
