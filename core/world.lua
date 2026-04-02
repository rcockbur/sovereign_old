-- core/world.lua
-- Owns the tile grid, buildings, forest depth map, plant cursor scan,
-- growing plant data, and visibility state.


local log = require("core.log")

local math_floor  = math.floor
local math_random = math.random

local world = {
    width              = MAP_WIDTH,
    height             = MAP_HEIGHT,
    tiles              = {},
    buildings          = {},   -- flat array, swap-and-pop deletion
    spread_cursor      = 0,
    growing_plant_data = {},   -- tileIndex -> planted_tick (stages 1-2 only)
}

--- Flat index for all spatial lookups.
function world.tileIndex(x, y)
    return (x - 1) * MAP_HEIGHT + y
end

--- Inverse flat index.
function world.tileXY(index)
    local x = math_floor((index - 1) / MAP_HEIGHT) + 1
    local y = (index - 1) % MAP_HEIGHT + 1
    return x, y
end

--- Return tile at (x, y), or nil if out of bounds.
function world:getTile(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return nil
    end
    return self.tiles[world.tileIndex(x, y)]
end

--- Return true if the tile at (x, y) can be walked on.
function world:isWalkable(x, y)
    local tile = self:getTile(x, y)
    if tile == nil then return false end
    if tile.terrain == "rock" or tile.terrain == "water" then return false end
    if tile.building_id ~= nil then return false end
    if tile.plant_type == "tree" and tile.plant_growth >= 2 then return false end
    return true
end

--- Allocate all tiles and build the hardcoded test map.
--- Settlement (cols 1-200): grass, lake, rock patches, sparse trees, berry bushes.
--- Forest (cols 201-400): dense trees (~75%) with clearings, herbs, berry bushes.
function world:generate()
    log:info("WORLD", "generating world (%dx%d)", MAP_WIDTH, MAP_HEIGHT)
    math.randomseed(12345)   -- deterministic test map

    -- Allocate 80,000 tiles with defaults
    for x = 1, MAP_WIDTH do
        local depth = 0.0
        if x >= FOREST_START then
            depth = (x - FOREST_START) / (MAP_WIDTH - FOREST_START)
        end
        for y = 1, MAP_HEIGHT do
            self.tiles[world.tileIndex(x, y)] = {
                terrain       = "grass",
                plant_type    = nil,
                plant_growth  = 0,
                building_id   = nil,
                forest_depth  = depth,
                danger = depth ^ 2,
                is_explored   = false,
                visible_count = 0,
                claimed_by    = nil,
            }
        end
    end

    -- Lake: circular blob at ~(150, 100), radius 8
    local lx, ly, lr = 150, 100, 8
    for x = lx - lr, lx + lr do
        for y = ly - lr, ly + lr do
            local dx, dy = x - lx, y - ly
            if dx * dx + dy * dy <= lr * lr then
                local tile = self:getTile(x, y)
                if tile then tile.terrain = "water" end
            end
        end
    end

    -- Rock patches in settlement
    for _, c in ipairs({ {50, 50}, {80, 150}, {170, 30}, {120, 80} }) do
        for x = c[1] - 2, c[1] + 2 do
            for y = c[2] - 2, c[2] + 2 do
                local tile = self:getTile(x, y)
                if tile and tile.terrain == "grass" and math_random() < 0.6 then
                    tile.terrain = "rock"
                end
            end
        end
    end

    -- Sparse trees in settlement: 4 small clusters (3-8 trees each)
    for _, c in ipairs({ {30, 60}, {90, 120}, {140, 40}, {60, 170} }) do
        for _ = 1, math_random(3, 8) do
            local tile = self:getTile(c[1] + math_random(-4, 4), c[2] + math_random(-4, 4))
            if tile and tile.terrain == "grass" and tile.plant_growth == 0 then
                tile.plant_type  = "tree"
                tile.plant_growth = math_random(2, 3)
            end
        end
    end

    -- Berry bushes scattered through settlement
    for _ = 1, 25 do
        local tile = self:getTile(
            math_random(5, SETTLEMENT_COLUMNS - 5),
            math_random(5, MAP_HEIGHT - 5)
        )
        if tile and tile.terrain == "grass" and tile.plant_growth == 0 then
            tile.plant_type  = "berry_bush"
            tile.plant_growth = 3
        end
    end

    -- Forest: ~75% tree coverage with ~20 circular clearings
    local clearings = {}
    for _ = 1, 20 do
        table.insert(clearings, {
            x = math_random(FOREST_START, MAP_WIDTH),
            y = math_random(1, MAP_HEIGHT),
            r = math_random(5, 15),
        })
    end

    for x = FOREST_START, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local tile = self.tiles[world.tileIndex(x, y)]

            local in_clearing = false
            for _, c in ipairs(clearings) do
                local dx, dy = x - c.x, y - c.y
                if dx * dx + dy * dy <= c.r * c.r then
                    in_clearing = true
                    break
                end
            end

            if in_clearing == false then
                if math_random() < 0.75 then
                    tile.plant_type  = "tree"
                    tile.plant_growth = 3
                elseif math_random() < 0.05 then
                    tile.plant_type  = "berry_bush"
                    tile.plant_growth = 3
                end
            end

            -- Herbs in gaps, gated by forest_depth
            if tile.plant_growth == 0 and tile.forest_depth >= 0.01 and math_random() < 0.03 then
                tile.plant_type  = "herb"
                tile.plant_growth = 3
            end
        end
    end

    log:info("WORLD", "world generation complete")
end

--- Attempt to promote a seedling or young plant to the next stage.
function world:tryPromote(tile, x, y, tick)
    local growth_ticks = tile.plant_growth == 1 and SEEDLING_GROWTH_TICKS or YOUNG_GROWTH_TICKS
    if growth_ticks == 0 then return end   -- TBD growth timings

    local idx = world.tileIndex(x, y)
    local planted_tick = self.growing_plant_data[idx]
    if planted_tick == nil then return end
    if tick - planted_tick < growth_ticks then return end

    -- Phase 4: defer tree seedling->young if a unit is on this tile

    tile.plant_growth = tile.plant_growth + 1
    if tile.plant_growth >= 3 then
        self.growing_plant_data[idx] = nil   -- promoted to mature; no longer tracked
    else
        self.growing_plant_data[idx] = tick  -- reset timestamp for next stage
    end
end

--- Attempt to spread a mature plant to a nearby empty tile.
function world:trySpread(tile, x, y, tick)
    if math_random() >= SPREAD_CHANCE then return end

    local tx = x + math_random(-SPREAD_RADIUS, SPREAD_RADIUS)
    local ty = y + math_random(-SPREAD_RADIUS, SPREAD_RADIUS)
    local target = self:getTile(tx, ty)
    if target == nil then return end
    if target.terrain ~= "grass" then return end
    if target.plant_growth ~= 0 then return end
    if target.building_id ~= nil then return end

    -- No spread adjacent to a building
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local neighbor = self:getTile(tx + dx, ty + dy)
                if neighbor and neighbor.building_id ~= nil then return end
            end
        end
    end

    target.plant_type  = tile.plant_type
    target.plant_growth = 1
    self.growing_plant_data[world.tileIndex(tx, ty)] = tick
end

--- Cursor-based plant scan: processes SPREAD_TILES_PER_TICK tiles per tick,
--- wrapping linearly across the full grid.
function world:updatePlants(time)
    for _ = 1, SPREAD_TILES_PER_TICK do
        self.spread_cursor = self.spread_cursor + 1
        if self.spread_cursor > MAP_WIDTH * MAP_HEIGHT then
            self.spread_cursor = 1
        end

        local tile = self.tiles[self.spread_cursor]
        if tile.plant_growth == 1 or tile.plant_growth == 2 then
            local x, y = world.tileXY(self.spread_cursor)
            self:tryPromote(tile, x, y, time.tick)
        elseif tile.plant_growth == 3 then
            local x, y = world.tileXY(self.spread_cursor)
            self:trySpread(tile, x, y, time.tick)
        end
    end
end

--- Stub: building work cycles. Phase 6.
function world:updateBuildings(time)
    -- Phase 6
end

--- Stub: resource node updates. Phase 6.
function world:updateResources(time)
    -- Phase 6
end

--- Stub: double-buffered recursive shadowcasting.
--- Called by units module when a unit moves to a new tile.
--- Algorithm: 8-octant recursive shadowcasting, radius SIGHT_RADIUS (8).
--- Vision blockers: rock terrain, building_id set, tree stage 2+ with at
--- least one cardinal neighbor also tree stage 2+. First blocker is visible.
--- Diffs old/new visibility buffers to update tile.visible_count and
--- tile.is_explored. Zero allocations in steady state (double-buffer swap).
function world:computeVisibility(unit)
    -- Phase 4
end

--- Clear all world state. Called before generate() on new game / quit-to-menu.
function world:reset()
    self.tiles             = {}
    self.buildings         = {}
    self.spread_cursor     = 0
    self.growing_plant_data = {}
end

--- Stub: return serializable state. Full implementation in Phase 11.
function world:serialize()   return {} end
function world:deserialize(data) end

return world
