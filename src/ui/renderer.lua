-- ui/renderer.lua
-- World-pass tile rendering. Frustum-culled to the camera viewport.
-- Called inside a love.graphics.push/pop block with the camera transform applied.

local world    = require("core.world")
local registry = require("core.registry")
local camera   = require("ui.camera")

local renderer = {}

local function unitScreenPos(unit, ts, half)
    local px = (unit.x - 1) * ts + half
    local py = (unit.y - 1) * ts + half
    if unit.path ~= nil then
        local next_idx  = unit.path.tiles[unit.path.current]
        local nx, ny    = tileXY(next_idx)
        local tile_cost = world.getTileCost(world.tiles[next_idx])
        if tile_cost ~= nil then
            local dx = math.abs(nx - unit.x)
            local dy = math.abs(ny - unit.y)
            if dx == 1 and dy == 1 then
                tile_cost = tile_cost * SQRT2
            end
            local lerp_t = math.min(unit.move_progress / tile_cost, 1.0)
            px = px + (nx - unit.x) * ts * lerp_t
            py = py + (ny - unit.y) * ts * lerp_t
        end
    end
    return px, py
end

local COLOR_GRASS          = { 0.35, 0.55, 0.25 }
local COLOR_WATER          = { 0.20, 0.40, 0.75 }
local COLOR_ROCK           = { 0.50, 0.50, 0.50 }
local COLOR_TREE           = { 0.15, 0.35, 0.10 }
local COLOR_BERRY          = { 0.55, 0.25, 0.65 }
local COLOR_UNIT           = { 0.90, 0.75, 0.20 }
local COLOR_STOCKPILE      = { 0.65, 0.55, 0.35 }
local COLOR_STOCKPILE_FILL = { 0.35, 0.22, 0.08 }

function renderer.drawWorld()
    local sw, sh = love.graphics.getDimensions()
    local z      = camera.zoom
    local left   = camera.x - sw / (2 * z)
    local right  = camera.x + sw / (2 * z)
    local top    = camera.y - sh / (2 * z)
    local bottom = camera.y + sh / (2 * z)

    local x_min = math.max(1,          math.floor(left   / TILE_SIZE) + 1)
    local x_max = math.min(MAP_WIDTH,  math.ceil( right  / TILE_SIZE))
    local y_min = math.max(1,          math.floor(top    / TILE_SIZE) + 1)
    local y_max = math.min(MAP_HEIGHT, math.ceil( bottom / TILE_SIZE))

    local ts   = TILE_SIZE
    local half = ts * 0.5

    for x = x_min, x_max do
        for y = y_min, y_max do
            local tile = world.tiles[tileIndex(x, y)]
            local px   = (x - 1) * ts
            local py   = (y - 1) * ts

            if tile.terrain == "water" then
                love.graphics.setColor(COLOR_WATER)
            elseif tile.terrain == "rock" then
                love.graphics.setColor(COLOR_ROCK)
            else
                love.graphics.setColor(COLOR_GRASS)
            end
            love.graphics.rectangle("fill", px, py, ts, ts)

            if tile.plant_type == "tree" then
                love.graphics.setColor(COLOR_TREE)
                love.graphics.circle("fill", px + half, py + half, half * 0.75)
            elseif tile.plant_type == "berry_bush" then
                love.graphics.setColor(COLOR_BERRY)
                love.graphics.circle("fill", px + half, py + half, half * 0.35)
            end
        end
    end
end

function renderer.drawUnits()
    local ts   = TILE_SIZE
    local half = ts * 0.5
    local r    = half * 0.4

    for i = 1, #world.units do
        local unit = world.units[i]
        if unit.is_dead == false then
            local px, py = unitScreenPos(unit, ts, half)
            love.graphics.setColor(COLOR_UNIT)
            love.graphics.circle("fill", px, py, r)
        end
    end
end

function renderer.drawBuildings()
    local sw, sh = love.graphics.getDimensions()
    local z      = camera.zoom
    local left   = camera.x - sw / (2 * z)
    local right  = camera.x + sw / (2 * z)
    local top    = camera.y - sh / (2 * z)
    local bottom = camera.y + sh / (2 * z)
    local vx_min = math.floor(left   / TILE_SIZE) + 1
    local vx_max = math.ceil( right  / TILE_SIZE)
    local vy_min = math.floor(top    / TILE_SIZE) + 1
    local vy_max = math.ceil( bottom / TILE_SIZE)

    local ts = TILE_SIZE
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
                        local px = (x - 1) * ts
                        local py = (y - 1) * ts
                        love.graphics.setColor(COLOR_STOCKPILE)
                        love.graphics.rectangle("fill", px, py, ts, ts)

                        local col        = x - building.x
                        local row        = y - building.y
                        local tile_entry = building.storage.tiles[col * building.height + row + 1]
                        local used       = 0
                        for j = 1, #tile_entry.contents do
                            local entity = registry[tile_entry.contents[j]]
                            local amt    = entity.amount ~= nil and entity.amount or 1
                            used = used + ResourceConfig[entity.type].weight * amt
                        end

                        if used > 0 then
                            local pad = used >= building.storage.tile_capacity
                                and math.floor(ts * 0.09)
                                or  math.floor(ts * 0.34)
                            love.graphics.setColor(COLOR_STOCKPILE_FILL)
                            love.graphics.rectangle("fill", px + pad, py + pad, ts - pad * 2, ts - pad * 2)
                        end
                    end
                end
            end
        end
    end
end

local COLOR_GROUND_PILE = { 0.72, 0.58, 0.28 }
local COLOR_DESIG_CHOP  = { 0.95, 0.65, 0.10, 0.55 }

function renderer.drawGroundPiles()
    local ts  = TILE_SIZE
    local pad = math.floor(ts * 0.25)
    local sz  = ts - pad * 2
    for i = 1, #world.ground_piles do
        local gp = world.ground_piles[i]
        love.graphics.setColor(COLOR_GROUND_PILE)
        love.graphics.rectangle("fill", (gp.x - 1) * ts + pad, (gp.y - 1) * ts + pad, sz, sz)
    end
end

function renderer.drawDesignations()
    local sw, sh = love.graphics.getDimensions()
    local z      = camera.zoom
    local left   = camera.x - sw / (2 * z)
    local right  = camera.x + sw / (2 * z)
    local top    = camera.y - sh / (2 * z)
    local bottom = camera.y + sh / (2 * z)

    local x_min = math.max(1,          math.floor(left   / TILE_SIZE) + 1)
    local x_max = math.min(MAP_WIDTH,  math.ceil( right  / TILE_SIZE))
    local y_min = math.max(1,          math.floor(top    / TILE_SIZE) + 1)
    local y_max = math.min(MAP_HEIGHT, math.ceil( bottom / TILE_SIZE))

    local ts   = TILE_SIZE
    local pad  = math.floor(ts * 0.2)
    local size = ts - pad * 2

    for x = x_min, x_max do
        for y = y_min, y_max do
            local tile = world.tiles[tileIndex(x, y)]
            if tile.designation == "chop" then
                love.graphics.setColor(COLOR_DESIG_CHOP)
                love.graphics.rectangle("fill",
                    (x - 1) * ts + pad, (y - 1) * ts + pad, size, size)
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
        local ts     = TILE_SIZE
        local half   = ts * 0.5
        local r      = half * 0.4
        local px, py = unitScreenPos(selected, ts, half)
        love.graphics.circle("line", px, py, r + 3)
    elseif selected_type == "building" then
        local ts = TILE_SIZE
        love.graphics.rectangle("line",
            (selected.x - 1) * ts, (selected.y - 1) * ts,
            selected.width * ts, selected.height * ts)
    else
        local x, y = tileXY(tile_idx)
        local px   = (x - 1) * TILE_SIZE
        local py   = (y - 1) * TILE_SIZE
        love.graphics.rectangle("line", px, py, TILE_SIZE, TILE_SIZE)
    end
end

return renderer
