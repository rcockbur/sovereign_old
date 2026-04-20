-- simulation/units.lua
-- Unit lifecycle: creation, spawn, movement, death sweep. Operates on world.units.

local world       = require("core.world")
local registry    = require("core.registry")
local log         = require("core.log")
local pathfinding = require("core.pathfinding")
local time        = require("core.time")
local activities  = require("simulation.activities")
local resources   = require("simulation.resources")

local units = {}

local Unit = {}
Unit.__index = Unit

function units.spawnSerf(x, y)
    local tile_idx = tileIndex(x, y)
    local tile = world.tiles[tile_idx]
    if tile.target_of_unit ~= nil then
        return nil
    end

    local gender     = math.random() < 0.5 and "male" or "female"
    local name_list  = gender == "male" and NameConfig.male or NameConfig.female
    local first_name = name_list[math.random(#name_list)]
    local surname    = NameConfig.surname[math.random(#NameConfig.surname)]

    local unit = registry.createEntity(world.units, setmetatable({
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
    }, Unit))

    unit.target_tile   = tile_idx
    tile.target_of_unit   = unit.id
    tile.unit_ids[#tile.unit_ids + 1] = unit.id

    log:info("UNIT", "Spawned %s %s at (%d, %d)", unit.name, unit.surname, x, y)
    return unit
end

function units.spawnStarting()
    local half_size = math.floor(GEN_START_SIZE / 2)
    local x_start   = GEN_START_X - half_size + 1
    local x_end     = GEN_START_X + half_size
    local y_start   = GEN_START_Y - half_size + 1
    local y_end     = GEN_START_Y + half_size

    local count = 0
    for x = x_start, x_end do
        for y = y_start, y_end do
            if world.tiles[tileIndex(x, y)].target_of_unit == nil then
                units.spawnSerf(x, y)
                count = count + 1
                if count == 6 then
                    return
                end
            end
        end
    end
end

local FLOOD_DIRS = { {0,-1}, {0,1}, {-1,0}, {1,0} }

function Unit:recalcMoveSpeed()
    self.move_speed = 1.0
end

function Unit:moveStep()
    if self.path == nil then
        return
    end
    if self.path.current > #self.path.tiles then
        self.path = nil
        return
    end

    local next_idx  = self.path.tiles[self.path.current]
    local next_x, next_y = tileXY(next_idx)
    local next_tile = world.tiles[next_idx]
    local from_idx  = tileIndex(self.x, self.y)
    local cost      = world.getEdgeCost(from_idx, next_idx)
    if cost == nil then
        self.path = nil
        return
    end

    local delta_x = math.abs(next_x - self.x)
    local delta_y = math.abs(next_y - self.y)
    if delta_x == 1 and delta_y == 1 then
        cost = cost * SQRT2
    end

    self.move_progress = self.move_progress + self.move_speed
    if self.move_progress >= cost then
        self.move_progress = self.move_progress - cost

        local old_tile = world.tiles[tileIndex(self.x, self.y)]
        for i = 1, #old_tile.unit_ids do
            if old_tile.unit_ids[i] == self.id then
                old_tile.unit_ids[i] = old_tile.unit_ids[#old_tile.unit_ids]
                old_tile.unit_ids[#old_tile.unit_ids] = nil
                break
            end
        end
        next_tile.unit_ids[#next_tile.unit_ids + 1] = self.id
        self.x = next_x
        self.y = next_y

        self.path.current = self.path.current + 1
        if self.path.current > #self.path.tiles then
            self.path = nil
            -- Verify the arrival tile is still claimed by this unit; flood-fill if not.
            if world.tiles[tileIndex(self.x, self.y)].target_of_unit ~= self.id then
                units.floodFillNearest(self)
            end
        end
    end
end

function Unit:carryableAmount(type)
    local used      = resources.countWeight(self.carrying)
    local remaining = CARRY_WEIGHT_MAX - used
    return math.floor(remaining / ResourceConfig[type].weight)
end

function Unit:workStep()
    local action = self.current_action
    action.progress = action.progress + 1
    return action.progress >= action.work_ticks
end

function Unit:onActionComplete()
    -- 1. Soft interrupt at clean break (M18)

    -- 2. Idle + carrying → offload
    if self.activity_id == nil and #self.carrying > 0 then
        local stack  = registry[self.carrying[1]]
        local rtype  = stack.type
        local dest   = resources.findNearestStorage(self, rtype, 1)
        if dest ~= nil then
            local reserve_amount = math.min(stack.amount, resources.getAvailableCapacity(dest.storage, rtype))
            local act = activities.postActivity({
                type            = "haul",
                source_id       = nil,
                destination_id  = dest.id,
                resource_type   = rtype,
                reserved_amount = reserve_amount,
            })
            resources.reserve(dest.storage, rtype, reserve_amount, "in")
            activities.claimActivity(self, act)
            log:info("HAUL", "Unit %d (%s) offloading %d %s to building %d",
                self.id, self.name, reserve_amount, rtype, dest.id)
            activities.handlers["haul"].nextAction(self, act)
        else
            local gp = resources.groundDrop(self)
            if gp ~= nil then
                activities.postGroundPileHaulIfNeeded(gp, rtype)
            end
            self.current_action = { type = "idle" }
        end
        return
    end

    -- 3. No activity → idle
    if self.activity_id == nil then
        self.current_action = { type = "idle" }
        return
    end

    -- 4. Activity handler decides next action
    local activity = registry[self.activity_id]
    activities.handlers[activity.type].nextAction(self, activity)
end

function Unit:tick()
    local action    = self.current_action
    local completed = false

    if action.type == "travel" then
        local had_path = self.path ~= nil
        self:moveStep()
        if had_path and self.path == nil then
            completed = true
        end
    elseif action.type == "work" then
        completed = self:workStep()
    end

    -- Per-tick step 2: decrement work day counter for work-purpose activities
    if self.activity_id ~= nil then
        local activity = registry[self.activity_id]
        if activity ~= nil and activity.purpose == "work" then
            if self.work_ticks_remaining > 0 then
                self.work_ticks_remaining = self.work_ticks_remaining - 1
            end
        end
    end

    if completed then
        self:onActionComplete()
    end
end

function units.tickAll()
    for i = 1, #world.units do
        local unit = world.units[i]
        if unit.is_dead == false then
            unit:tick()
        end
    end
end

function Unit:hashedUpdate()
    if self.is_drafted then return end

    -- Steps 1–5: needs drain, interrupts, equipment wants, work day (M18+)

    -- Step 6: Activity polling
    if self.current_action.type == "idle" and self.activity_id == nil then
        if self.class ~= "gentry" and self.is_done_working == false then
            local best = activities.pollBest(self)
            if best ~= nil then
                activities.claimActivity(self, best)
                log:info("ACTIVITY", "Unit %d (%s) claimed %s activity %d at (%d,%d)",
                    self.id, self.name, best.type, best.id, best.x, best.y)
                self:onActionComplete()
            end
        end
    end
end

function units.update()
    for i = 1, #world.units do
        local unit = world.units[i]
        if unit.is_dead == false then
            if (world.time.tick + time.hashOffset(unit.id)) % HASH_INTERVAL == 0 then
                unit:hashedUpdate()
            end
        end
    end
end

function units.startMove(unit, goal_idx)
    local goal_tile = world.tiles[goal_idx]
    if goal_tile.target_of_unit ~= nil then
        return false
    end

    local old_target_idx = unit.target_tile

    goal_tile.target_of_unit = unit.id
    unit.target_tile          = goal_idx
    if old_target_idx ~= nil then
        world.tiles[old_target_idx].target_of_unit = nil
    end

    local path = pathfinding.findPath(tileIndex(unit.x, unit.y), goal_idx)
    if path == nil then
        goal_tile.target_of_unit = nil
        unit.target_tile          = old_target_idx
        if old_target_idx ~= nil then
            world.tiles[old_target_idx].target_of_unit = unit.id
        end
        return false
    end

    unit.path          = path
    unit.move_progress = 0
    return true
end

function units.startMoveAdjacentToRect(unit, rx, ry, rw, rh)
    local start_idx = tileIndex(unit.x, unit.y)
    local path = pathfinding.findPathAdjacentToRect(start_idx, rx, ry, rw, rh)
    if path == nil then
        return false
    end

    if #path.tiles > 0 then
        local goal_idx = path.tiles[#path.tiles]
        if unit.target_tile ~= nil then
            world.tiles[unit.target_tile].target_of_unit = nil
        end
        world.tiles[goal_idx].target_of_unit = unit.id
        unit.target_tile = goal_idx
    end

    unit.path          = path
    unit.move_progress = 0
    return true
end

function units.floodFillNearest(unit)
    local start_idx = tileIndex(unit.x, unit.y)
    local queue     = { start_idx }
    local head      = 1
    local visited   = { [start_idx] = true }

    while head <= #queue do
        local current_tile = queue[head]
        head = head + 1
        local current_x, current_y = tileXY(current_tile)

        if world.tiles[current_tile].target_of_unit == nil and current_tile ~= start_idx then
            world.tiles[current_tile].target_of_unit = unit.id
            unit.target_tile                         = current_tile
            return current_tile
        end

        for _, direction in ipairs(FLOOD_DIRS) do
            local neighbor_x = current_x + direction[1]
            local neighbor_y = current_y + direction[2]
            if neighbor_x >= 1 and neighbor_x <= MAP_WIDTH and neighbor_y >= 1 and neighbor_y <= MAP_HEIGHT then
                local neighbor_idx = tileIndex(neighbor_x, neighbor_y)
                if visited[neighbor_idx] == nil and world.getEdgeCost(current_tile, neighbor_idx) ~= nil then
                    visited[neighbor_idx]   = true
                    queue[#queue + 1]       = neighbor_idx
                end
            end
        end
    end

    return nil
end

return units
