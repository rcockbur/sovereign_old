-- core/world.lua
-- World state: tile grid, entity arrays, time, settings. Map generation pipeline.

local log = require("core.log")

local world = {}

local generateName
local logGenStats
local layerWater
local layerRock
local layerTrees
local layerBerries
local layerForestDepth
local layerStartingArea
local newTile
local orthogonalNeighbors

-- ── Init ──────────────────────────────────────────────────────────────────────

local function initState(seed)
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
        construction     = {},
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
end

function world.newGenCoroutine(seed)
    return coroutine.create(function()
        initState(seed)

        local water_ox = math.random(0, 1000000)
        local water_oy = math.random(0, 1000000)
        local rock_ox  = math.random(0, 1000000)
        local rock_oy  = math.random(0, 1000000)
        local tree_ox  = math.random(0, 1000000)
        local tree_oy  = math.random(0, 1000000)

        local STAGES = {
            tiles   = { p0 = 0.00, p1 = 0.35, msg = "Allocating Memory" },
            water   = { p0 = 0.35, p1 = 0.45, msg = "Generating Terrain" },
            rock    = { p0 = 0.45, p1 = 0.70, },
            trees   = { p0 = 0.70, p1 = 0.97, },
            berries = { p0 = 0.97, p1 = 0.98 },
            depth   = { p0 = 0.98, p1 = 0.99 },
            start   = { p0 = 0.99, p1 = 1.00 },
        }

        coroutine.yield(STAGES.tiles.p0, STAGES.tiles.msg)
        local total = MAP_WIDTH * MAP_HEIGHT
        world.tiles = {}
        for i = 1, total do
            world.tiles[i] = newTile()
            if i % 2000 == 0 then
                coroutine.yield(STAGES.tiles.p0 + (STAGES.tiles.p1 - STAGES.tiles.p0) * i / total, STAGES.tiles.msg)
            end
        end

        layerWater(water_ox, water_oy, STAGES.water)
        layerRock (rock_ox,  rock_oy,  STAGES.rock)
        layerTrees(tree_ox,  tree_oy,  STAGES.trees)

        --coroutine.yield(STAGES.berries.p1)
        layerBerries(STAGES.berries)

        --coroutine.yield(STAGES.depth.p1)
        layerForestDepth(STAGES.depth)

        --coroutine.yield(STAGES.start)
        layerStartingArea(STAGES.start)

        logGenStats()
    end)
end

-- ── Settlement name ───────────────────────────────────────────────────────────

generateName = function()
    local cfg    = SettlementNameConfig
    local prefix = cfg.prefix[math.random(#cfg.prefix)]
    local suffix = cfg.suffix[math.random(#cfg.suffix)]
    return prefix .. suffix
end

-- ── Map generation ────────────────────────────────────────────────────────────

layerWater = function(ox, oy, stage)
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local n = love.math.noise((x + ox) * GEN_WATER_FREQ, (y + oy) * GEN_WATER_FREQ)
            if n < GEN_WATER_THRESHOLD then
                world.tiles[tileIndex(x, y)].terrain = "water"
            end
        end
        if x % 40 == 0 then
            coroutine.yield(stage.p0 + (x / MAP_WIDTH) * (stage.p1 - stage.p0), stage.msg)
        end
    end
end

layerRock = function(ox, oy, stage)
    local ts = GEN_ROCK_THRESHOLD_SETTLE
    local tf = GEN_ROCK_THRESHOLD_FOREST
    local band_start = GEN_TRANSITION_START
    local band_end   = GEN_TRANSITION_END
    local p_mid      = stage.p0 + (stage.p1 - stage.p0) * 0.5

    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local tile = world.tiles[tileIndex(x, y)]
            if tile.terrain == "grass" then
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
                    tile.terrain = "rock"
                end
            end
        end
        if x % 40 == 0 then
            coroutine.yield(stage.p0 + (x / MAP_WIDTH) * (p_mid - stage.p0), stage.msg)
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
        if x % 40 == 0 then
            coroutine.yield(p_mid + (x / MAP_WIDTH) * (stage.p1 - p_mid), stage.msg)
        end
    end
end

layerTrees = function(ox, oy, stage)
    local ts         = GEN_TREE_THRESHOLD_SETTLE
    local tf         = GEN_TREE_THRESHOLD_FOREST
    local band_start = GEN_TRANSITION_START
    local band_end   = GEN_TRANSITION_END

    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local tile = world.tiles[tileIndex(x, y)]
            if tile.terrain == "grass" then
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
                    tile.plant_type   = "tree"
                    tile.plant_growth = 3
                end
            end
        end
        if x % 40 == 0 then
            coroutine.yield(stage.p0 + (x / MAP_WIDTH) * (stage.p1 - stage.p0), stage.msg)
        end
    end
end

layerBerries = function(stage)
    coroutine.yield(stage.start)
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local tile = world.tiles[tileIndex(x, y)]
            if tile.terrain == "grass" and tile.plant_type == nil then
                local chance = x <= SETTLEMENT_COLUMNS
                    and GEN_BERRY_CHANCE_SETTLE
                    or  GEN_BERRY_CHANCE_FOREST
                if math.random() < chance then
                    tile.plant_type   = "berry_bush"
                    tile.plant_growth = 3
                end
            end
        end
    end
end

layerForestDepth = function(stage)
    coroutine.yield(stage.start)
    local forest_width = MAP_WIDTH - FOREST_START + 1
    for x = FOREST_START, MAP_WIDTH do
        local depth = (x - FOREST_START) / (forest_width - 1)
        for y = 1, MAP_HEIGHT do
            world.tiles[tileIndex(x, y)].forest_depth = depth
        end
    end
end

layerStartingArea = function(stage)
    coroutine.yield(stage.start)
    local half = math.floor(GEN_START_SIZE / 2)
    for x = GEN_START_X - half + 1, GEN_START_X + half do
        for y = GEN_START_Y - half + 1, GEN_START_Y + half do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                local tile       = world.tiles[tileIndex(x, y)]
                tile.terrain     = "grass"
                tile.plant_type  = nil
                tile.plant_growth = 0
            end
        end
    end
end

-- ── Gen stats ────────────────────────────────────────────────────────────────

logGenStats = function()
    local settle = { grass=0, water=0, rock=0, tree=0, berry=0 }
    local forest  = { grass=0, water=0, rock=0, tree=0, berry=0 }
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local tile = world.tiles[tileIndex(x, y)]
            local half = x <= SETTLEMENT_COLUMNS and settle or forest
            if tile.terrain == "water" then
                half.water = half.water + 1
            elseif tile.terrain == "rock" then
                half.rock = half.rock + 1
            elseif tile.plant_type == "tree" then
                half.tree = half.tree + 1
            elseif tile.plant_type == "berry_bush" then
                half.berry = half.berry + 1
            else
                half.grass = half.grass + 1
            end
        end
    end
    log:info("WORLD", "Town: %s  Seed: %d",
        world.settings.settlement_name, world.seed)
    log:info("WORLD", "  grass:%d water:%d rock:%d tree:%d berry:%d",
        settle.grass, settle.water, settle.rock, settle.tree, settle.berry)
    log:info("WORLD", "  grass:%d water:%d rock:%d tree:%d berry:%d",
        forest.grass, forest.water, forest.rock, forest.tree, forest.berry)
end

-- ── Tile cost ────────────────────────────────────────────────────────────────

function world.getTileCost(tile)
    if tile.terrain == "water" or tile.terrain == "rock" then
        return nil
    end
    if tile.plant_type == "tree" and tile.plant_growth >= 2 then
        return BASE_MOVE_COST * TREE_MOVE_MULTIPLIER
    end
    return BASE_MOVE_COST
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
        claimed_by              = nil,
        target_of_unit          = nil,
        unit_ids                = {},
        designation             = nil,
        designation_activity_id = nil,
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
