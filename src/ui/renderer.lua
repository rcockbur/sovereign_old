-- ui/renderer.lua
-- World-pass tile rendering. Frustum-culled to the camera viewport.
-- Called inside a love.graphics.push/pop block with the camera transform applied.

local world    = require("core.world")
local camera   = require("ui.camera")

local renderer = {}

local COLOR_GRASS = { 0.35, 0.55, 0.25 }
local COLOR_WATER = { 0.20, 0.40, 0.75 }
local COLOR_ROCK  = { 0.50, 0.50, 0.50 }
local COLOR_TREE  = { 0.15, 0.35, 0.10 }
local COLOR_BERRY = { 0.55, 0.25, 0.65 }
local COLOR_UNIT  = { 0.90, 0.75, 0.20 }

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
            local t  = world.tiles[tileIndex(x, y)]
            local px = (x - 1) * ts
            local py = (y - 1) * ts

            if t.terrain == "water" then
                love.graphics.setColor(COLOR_WATER)
            elseif t.terrain == "rock" then
                love.graphics.setColor(COLOR_ROCK)
            else
                love.graphics.setColor(COLOR_GRASS)
            end
            love.graphics.rectangle("fill", px, py, ts, ts)

            if t.plant_type == "tree" then
                love.graphics.setColor(COLOR_TREE)
                love.graphics.circle("fill", px + half, py + half, half * 0.75)
            elseif t.plant_type == "berry_bush" then
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
        local u = world.units[i]
        if u.is_dead == false then
            love.graphics.setColor(COLOR_UNIT)
            love.graphics.circle("fill", (u.x - 1) * ts + half, (u.y - 1) * ts + half, r)
        end
    end
end

function renderer.drawSelection(tile_idx)
    if tile_idx == nil then return end
    local x, y = tileXY(tile_idx)
    local px   = (x - 1) * TILE_SIZE
    local py   = (y - 1) * TILE_SIZE
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.rectangle("line", px, py, TILE_SIZE, TILE_SIZE)
end

return renderer
