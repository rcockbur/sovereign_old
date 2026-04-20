-- ui/renderer.lua
-- World-pass tile rendering. Frustum-culled to the camera viewport.
-- Called inside a love.graphics.push/pop block with the camera transform applied.

local world    = require("core.world")
local registry = require("core.registry")
local camera   = require("ui.camera")

local renderer = {}

local function unitScreenPos(unit, tile_size, half_tile)
    local pixel_x = (unit.x - 1) * tile_size + half_tile
    local pixel_y = (unit.y - 1) * tile_size + half_tile
    if unit.path ~= nil then
        local next_idx  = unit.path.tiles[unit.path.current]
        local next_x, next_y = tileXY(next_idx)
        local from_idx  = tileIndex(unit.x, unit.y)
        local tile_cost = world.getEdgeCost(from_idx, next_idx)
        if tile_cost ~= nil then
            local dx = math.abs(next_x - unit.x)
            local dy = math.abs(next_y - unit.y)
            if dx == 1 and dy == 1 then
                tile_cost = tile_cost * SQRT2
            end
            local lerp_t = math.min(unit.move_progress / tile_cost, 1.0)
            pixel_x = pixel_x + (next_x - unit.x) * tile_size * lerp_t
            pixel_y = pixel_y + (next_y - unit.y) * tile_size * lerp_t
        end
    end
    return pixel_x, pixel_y
end

local COLOR_GRASS     = { 0.35, 0.55, 0.25 }
local COLOR_WATER     = { 0.20, 0.40, 0.75 }
local COLOR_ROCK      = { 0.50, 0.50, 0.50 }
local COLOR_TREE      = { 0.15, 0.35, 0.10 }
local COLOR_BERRY     = { 0.55, 0.25, 0.65 }
local COLOR_UNIT      = { 0.90, 0.75, 0.20 }
local COLOR_STOCKPILE = { 0.65, 0.55, 0.35 }

-- Plant radii by growth stage (fraction of half-tile)
local TREE_RADIUS = { 0.25, 0.50, 0.75 }
local BUSH_RADIUS = { 0.25, 0.50, 0.75 }

local RESOURCE_COLOR = {
    -- Raw construction
    wood            = { 0.58, 0.38, 0.18 },
    firewood        = { 0.38, 0.22, 0.10 },
    stone           = { 0.58, 0.58, 0.60 },
    iron            = { 0.42, 0.28, 0.22 },
    steel           = { 0.62, 0.65, 0.72 },
    -- Crops
    wheat           = { 0.85, 0.72, 0.22 },
    barley          = { 0.75, 0.65, 0.28 },
    flax            = { 0.60, 0.78, 0.68 },
    -- Processed goods
    flour           = { 0.92, 0.90, 0.78 },
    bread           = { 0.80, 0.55, 0.22 },
    beer            = { 0.82, 0.55, 0.12 },
    plain_clothing  = { 0.82, 0.78, 0.68 },
    -- Food (harvested)
    berries         = { 0.55, 0.25, 0.65 },
    fish            = { 0.52, 0.68, 0.82 },
    herbs           = { 0.28, 0.62, 0.28 },
    -- Tools
    iron_tools      = { 0.38, 0.35, 0.32 },
    steel_tools     = { 0.62, 0.65, 0.70 },
}

function renderer.drawWorld()
    local screen_width, screen_height = love.graphics.getDimensions()
    local zoom   = camera.zoom
    local left   = camera.x - screen_width  / (2 * zoom)
    local right  = camera.x + screen_width  / (2 * zoom)
    local top    = camera.y - screen_height / (2 * zoom)
    local bottom = camera.y + screen_height / (2 * zoom)

    local x_min = math.max(1,          math.floor(left   / TILE_SIZE) + 1)
    local x_max = math.min(MAP_WIDTH,  math.ceil( right  / TILE_SIZE))
    local y_min = math.max(1,          math.floor(top    / TILE_SIZE) + 1)
    local y_max = math.min(MAP_HEIGHT, math.ceil( bottom / TILE_SIZE))

    local tile_size = TILE_SIZE
    local half_tile = tile_size * 0.5

    for x = x_min, x_max do
        for y = y_min, y_max do
            local tile    = world.tiles[tileIndex(x, y)]
            local pixel_x = (x - 1) * tile_size
            local pixel_y = (y - 1) * tile_size

            if tile.terrain == "water" then
                love.graphics.setColor(COLOR_WATER)
            elseif tile.terrain == "rock" then
                love.graphics.setColor(COLOR_ROCK)
            else
                love.graphics.setColor(COLOR_GRASS)
            end
            love.graphics.rectangle("fill", pixel_x, pixel_y, tile_size, tile_size)

            if tile.plant_type == "tree" and tile.plant_growth >= 1 then
                love.graphics.setColor(COLOR_TREE)
                love.graphics.circle("fill", pixel_x + half_tile, pixel_y + half_tile, half_tile * TREE_RADIUS[tile.plant_growth])
            elseif tile.plant_type == "berry_bush" and tile.plant_growth >= 1 then
                love.graphics.setColor(COLOR_BERRY)
                love.graphics.circle("fill", pixel_x + half_tile, pixel_y + half_tile, half_tile * BUSH_RADIUS[tile.plant_growth])
            end
        end
    end
end

function renderer.drawUnits()
    local tile_size = TILE_SIZE
    local half_tile = tile_size * 0.5
    local radius    = half_tile * 0.4

    for i = 1, #world.units do
        local unit = world.units[i]
        if unit.is_dead == false then
            local pixel_x, pixel_y = unitScreenPos(unit, tile_size, half_tile)
            love.graphics.setColor(COLOR_UNIT)
            love.graphics.circle("fill", pixel_x, pixel_y, radius)
        end
    end
end

function renderer.drawBuildings()
    local screen_width, screen_height = love.graphics.getDimensions()
    local zoom    = camera.zoom
    local left    = camera.x - screen_width  / (2 * zoom)
    local right   = camera.x + screen_width  / (2 * zoom)
    local top     = camera.y - screen_height / (2 * zoom)
    local bottom  = camera.y + screen_height / (2 * zoom)
    local vx_min  = math.floor(left   / TILE_SIZE) + 1
    local vx_max  = math.ceil( right  / TILE_SIZE)
    local vy_min  = math.floor(top    / TILE_SIZE) + 1
    local vy_max  = math.ceil( bottom / TILE_SIZE)

    local tile_size = TILE_SIZE
    for i = 1, #world.buildings do
        local building = world.buildings[i]
        if building.type == "stockpile" then
            local x_min = math.max(building.x,                      vx_min)
            local x_max = math.min(building.x + building.width  - 1, vx_max)
            local y_min = math.max(building.y,                      vy_min)
            local y_max = math.min(building.y + building.height - 1, vy_max)
            if x_min <= x_max and y_min <= y_max then
                for x = x_min, x_max do
                    for y = y_min, y_max do
                        local pixel_x = (x - 1) * tile_size
                        local pixel_y = (y - 1) * tile_size
                        love.graphics.setColor(COLOR_STOCKPILE)
                        love.graphics.rectangle("fill", pixel_x, pixel_y, tile_size, tile_size)

                        local col        = x - building.x
                        local row        = y - building.y
                        local tile_entry = building.storage.tiles[col * building.height + row + 1]
                        local used       = 0
                        local rtype      = nil
                        for j = 1, #tile_entry.contents do
                            local entity = registry[tile_entry.contents[j]]
                            local amt    = entity.amount ~= nil and entity.amount or 1
                            used  = used + ResourceConfig[entity.type].weight * amt
                            rtype = entity.type
                        end

                        if used > 0 then
                            local pad = used >= building.storage.tile_capacity
                                and math.floor(tile_size * 0.09)
                                or  math.floor(tile_size * 0.34)
                            love.graphics.setColor(RESOURCE_COLOR[rtype])
                            love.graphics.rectangle("fill", pixel_x + pad, pixel_y + pad, tile_size - pad * 2, tile_size - pad * 2)
                        end
                    end
                end
            end
        end
    end
end

local COLOR_GROUND_PILE  = { 0.72, 0.58, 0.28 }
local COLOR_DESIG_CHOP   = { 0.95, 0.65, 0.10, 0.55 }
local COLOR_DESIG_GATHER = { 0.95, 0.90, 0.30, 0.55 }

function renderer.drawGroundPiles()
    local tile_size = TILE_SIZE
    local pad       = math.floor(tile_size * 0.25)
    local sz        = tile_size - pad * 2
    for i = 1, #world.ground_piles do
        local gp = world.ground_piles[i]
        love.graphics.setColor(COLOR_GROUND_PILE)
        love.graphics.rectangle("fill", (gp.x - 1) * tile_size + pad, (gp.y - 1) * tile_size + pad, sz, sz)
    end
end

function renderer.drawDesignations()
    local screen_width, screen_height = love.graphics.getDimensions()
    local zoom   = camera.zoom
    local left   = camera.x - screen_width  / (2 * zoom)
    local right  = camera.x + screen_width  / (2 * zoom)
    local top    = camera.y - screen_height / (2 * zoom)
    local bottom = camera.y + screen_height / (2 * zoom)

    local x_min = math.max(1,          math.floor(left   / TILE_SIZE) + 1)
    local x_max = math.min(MAP_WIDTH,  math.ceil( right  / TILE_SIZE))
    local y_min = math.max(1,          math.floor(top    / TILE_SIZE) + 1)
    local y_max = math.min(MAP_HEIGHT, math.ceil( bottom / TILE_SIZE))

    local tile_size = TILE_SIZE
    local pad       = math.floor(tile_size * 0.2)
    local size      = tile_size - pad * 2

    for x = x_min, x_max do
        for y = y_min, y_max do
            local tile = world.tiles[tileIndex(x, y)]
            if tile.designation == "chop" then
                love.graphics.setColor(COLOR_DESIG_CHOP)
                love.graphics.rectangle("fill",
                    (x - 1) * tile_size + pad, (y - 1) * tile_size + pad, size, size)
            elseif tile.designation == "gather" then
                love.graphics.setColor(COLOR_DESIG_GATHER)
                love.graphics.rectangle("fill",
                    (x - 1) * tile_size + pad, (y - 1) * tile_size + pad, size, size)
            end
        end
    end
end

function renderer.drawSelection(selected, selected_type, tile_idx)
    if selected == nil then
        return
    end
    love.graphics.setColor(1, 1, 1, 0.7)

    if selected_type == "unit" then
        local tile_size = TILE_SIZE
        local half_tile = tile_size * 0.5
        local radius    = half_tile * 0.4
        local pixel_x, pixel_y = unitScreenPos(selected, tile_size, half_tile)
        love.graphics.circle("line", pixel_x, pixel_y, radius + 3)
    elseif selected_type == "building" then
        local tile_size = TILE_SIZE
        love.graphics.rectangle("line",
            (selected.x - 1) * tile_size, (selected.y - 1) * tile_size,
            selected.width * tile_size, selected.height * tile_size)
    else
        local x, y     = tileXY(tile_idx)
        local pixel_x  = (x - 1) * TILE_SIZE
        local pixel_y  = (y - 1) * TILE_SIZE
        love.graphics.rectangle("line", pixel_x, pixel_y, TILE_SIZE, TILE_SIZE)
    end
end

return renderer
