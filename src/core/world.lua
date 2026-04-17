-- core/world.lua
-- World state: tile grid, entity arrays, time, settings. Map generation pipeline.

local world = {}

local generateName
local generateMap
local layerWater
local layerRock
local layerTrees
local layerBerries
local layerForestDepth
local layerStartingArea
local newTile
local orthogonalNeighbors

-- ── Init ──────────────────────────────────────────────────────────────────────

function world.init(seed)
    world.seed   = seed or math.random(1, 2000000000)
    world.width  = MAP_WIDTH
    world.height = MAP_HEIGHT

    world.units        = {}
    world.buildings    = {}
    world.activities   = {}
    world.stacks       = {}
    world.items        = {}
    world.ground_piles = {}

    world.spread_cursor      = 0
    world.growing_plant_data = {}

    world.resource_counts = {
        storage          = {},
        storage_reserved = {},
        processing       = {},
        housing          = {},
        carrying         = {},
        equipped         = {},
        ground           = {},
    }

    world.time = {
        speed       = Speed.NORMAL,
        is_paused   = false,
        accumulator = 0,
        tick        = 6 * TICKS_PER_HOUR,
        game_minute = 0,
        game_hour   = 6,
        game_day    = 1,
        game_season = 1,
        game_year   = 1,
        thaw_day    = 0,
        frost_day   = 0,
        is_frost    = true,
    }

    world.magic = {
        divine_mana     = 0,
        divine_mana_max = 100,
        arcane_mana     = 0,
        arcane_mana_max = 100,
        divine_unlocked = false,
        arcane_unlocked = false,
    }

    world.settings = {
        settlement_name    = "",
        combat_gender      = "male",
        clergy_gender      = "male",
        succession_priority = "male",
    }

    math.randomseed(world.seed)
    world.settings.settlement_name = generateName()
    generateMap()
end

-- ── Settlement name ───────────────────────────────────────────────────────────

generateName = function()
    local cfg = SettlementNameConfig
    local p = cfg.prefix[math.random(#cfg.prefix)]
    local s = cfg.suffix[math.random(#cfg.suffix)]
    return p .. s
end

-- ── Map generation ────────────────────────────────────────────────────────────

generateMap = function()
    local water_ox = math.random(0, 1000000)
    local water_oy = math.random(0, 1000000)
    local rock_ox  = math.random(0, 1000000)
    local rock_oy  = math.random(0, 1000000)
    local tree_ox  = math.random(0, 1000000)
    local tree_oy  = math.random(0, 1000000)

    world.tiles = {}
    for i = 1, MAP_WIDTH * MAP_HEIGHT do
        world.tiles[i] = newTile()
    end

    layerWater(water_ox, water_oy)
    layerRock(rock_ox, rock_oy)
    layerTrees(tree_ox, tree_oy)
    layerBerries()
    layerForestDepth()
    layerStartingArea()
end

layerWater = function(ox, oy)
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local n = love.math.noise((x + ox) * GEN_WATER_FREQ, (y + oy) * GEN_WATER_FREQ)
            if n < GEN_WATER_THRESHOLD then
                world.tiles[tileIndex(x, y)].terrain = "water"
            end
        end
    end
end

layerRock = function(ox, oy)
    local ts = GEN_ROCK_THRESHOLD_SETTLE
    local tf = GEN_ROCK_THRESHOLD_FOREST
    local band_start = GEN_TRANSITION_START
    local band_end   = GEN_TRANSITION_END

    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local t = world.tiles[tileIndex(x, y)]
            if t.terrain == "grass" then
                local threshold
                if x <= band_start then
                    threshold = ts
                elseif x >= band_end then
                    threshold = tf
                else
                    local frac = (x - band_start) / (band_end - band_start)
                    threshold = ts + frac * (tf - ts)
                end
                local n = love.math.noise((x + ox) * GEN_ROCK_FREQ, (y + oy) * GEN_ROCK_FREQ)
                if n > threshold then
                    t.terrain = "rock"
                end
            end
        end
    end

    -- Cull rock clusters smaller than GEN_ROCK_MIN_CLUSTER
    local visited = {}
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local idx = tileIndex(x, y)
            if world.tiles[idx].terrain == "rock" and visited[idx] == nil then
                local cluster = {}
                local queue   = { idx }
                local head    = 1
                visited[idx]  = true
                while head <= #queue do
                    local cur    = queue[head]; head = head + 1
                    cluster[#cluster + 1] = cur
                    local cx, cy = tileXY(cur)
                    for _, nidx in ipairs(orthogonalNeighbors(cx, cy)) do
                        if visited[nidx] == nil and world.tiles[nidx].terrain == "rock" then
                            visited[nidx]        = true
                            queue[#queue + 1] = nidx
                        end
                    end
                end
                if #cluster < GEN_ROCK_MIN_CLUSTER then
                    for _, cidx in ipairs(cluster) do
                        world.tiles[cidx].terrain = "grass"
                    end
                end
            end
        end
    end
end

layerTrees = function(ox, oy)
    local ts         = GEN_TREE_THRESHOLD_SETTLE
    local tf         = GEN_TREE_THRESHOLD_FOREST
    local band_start = GEN_TRANSITION_START
    local band_end   = GEN_TRANSITION_END

    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local t = world.tiles[tileIndex(x, y)]
            if t.terrain == "grass" then
                local threshold
                if x <= band_start then
                    threshold = ts
                elseif x >= band_end then
                    threshold = tf
                else
                    local frac = (x - band_start) / (band_end - band_start)
                    threshold = ts + frac * (tf - ts)
                end
                local n = love.math.noise((x + ox) * GEN_TREE_FREQ, (y + oy) * GEN_TREE_FREQ)
                if n > threshold then
                    t.plant_type   = "tree"
                    t.plant_growth = 3
                end
            end
        end
    end
end

layerBerries = function()
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local t = world.tiles[tileIndex(x, y)]
            if t.terrain == "grass" and t.plant_type == nil then
                local chance = x <= SETTLEMENT_COLUMNS
                    and GEN_BERRY_CHANCE_SETTLE
                    or  GEN_BERRY_CHANCE_FOREST
                if math.random() < chance then
                    t.plant_type   = "berry_bush"
                    t.plant_growth = 3
                end
            end
        end
    end
end

layerForestDepth = function()
    local forest_width = MAP_WIDTH - FOREST_START + 1
    for x = FOREST_START, MAP_WIDTH do
        local depth = (x - FOREST_START) / (forest_width - 1)
        for y = 1, MAP_HEIGHT do
            world.tiles[tileIndex(x, y)].forest_depth = depth
        end
    end
end

layerStartingArea = function()
    local half = math.floor(GEN_START_SIZE / 2)
    for x = GEN_START_X - half + 1, GEN_START_X + half do
        for y = GEN_START_Y - half + 1, GEN_START_Y + half do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                local t       = world.tiles[tileIndex(x, y)]
                t.terrain     = "grass"
                t.plant_type  = nil
                t.plant_growth = 0
            end
        end
    end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

newTile = function()
    return {
        terrain        = "grass",
        plant_type     = nil,
        plant_growth   = 0,
        building_id    = nil,
        ground_pile_id = nil,
        forest_depth   = 0.0,
        is_explored    = false,
        visible_count  = 0,
        claimed_by     = nil,
        target_of_unit = nil,
        unit_ids       = {},
    }
end

orthogonalNeighbors = function(x, y)
    local result = {}
    if x > 1          then result[#result + 1] = tileIndex(x - 1, y) end
    if x < MAP_WIDTH  then result[#result + 1] = tileIndex(x + 1, y) end
    if y > 1          then result[#result + 1] = tileIndex(x, y - 1) end
    if y < MAP_HEIGHT then result[#result + 1] = tileIndex(x, y + 1) end
    return result
end

return world
