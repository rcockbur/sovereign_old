-- ui/dev_overlay.lua
-- Developer overlay toggled with F3: stats bar, tile inspector, log tail.

local world  = require("core.world")
local time   = require("core.time")
local log    = require("core.log")
local camera = require("ui.camera")

local dev_overlay = {}

dev_overlay.is_visible = false

local COL_BG   = { 0.05, 0.06, 0.07, 1.00 }
local COL_TEXT = { 0.80, 0.85, 0.80, 1.00 }
local COL_DIM  = { 0.55, 0.60, 0.55, 1.00 }

local PAD = 5
local LH  = 16

function dev_overlay.toggle()
    dev_overlay.is_visible = dev_overlay.is_visible == false
end

function dev_overlay.draw()
    if dev_overlay.is_visible == false then
        return
    end

    local screen_width  = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    -- Stats bar
    local world_time = world.time
    local achieved   = time.ticks_last_second
    local target     = world_time.speed * TICK_RATE
    local tps_str
    if world_time.is_paused == true then
        tps_str = string.format("TPS: -- / %d (paused)", target)
    else
        local pct = math.floor(achieved / target * 100)
        tps_str = string.format("TPS: %d / %d (%d%%)", achieved, target, pct)
    end

    local stats = string.format("FPS: %d  |  %s  |  Speed: %d  |  Units: %d  Bldg: %d  Act: %d  Piles: %d",
        love.timer.getFPS(), tps_str, world_time.speed,
        #world.units, #world.buildings, #world.activities, #world.ground_piles)

    local stats_h = LH + PAD * 2
    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", 0, 0, screen_width, stats_h)
    love.graphics.setColor(COL_TEXT)
    love.graphics.print(stats, PAD, PAD)

    -- Tile inspector (hovered tile)
    local mouse_x, mouse_y = love.mouse.getPosition()
    local world_x, world_y = camera.screenToWorld(mouse_x, mouse_y)
    local tile_x = math.floor(world_x / TILE_SIZE) + 1
    local tile_y = math.floor(world_y / TILE_SIZE) + 1

    if tile_x >= 1 and tile_x <= MAP_WIDTH and tile_y >= 1 and tile_y <= MAP_HEIGHT then
        local tile    = world.tiles[tileIndex(tile_x, tile_y)]
        local uid_str = #tile.unit_ids > 0 and table.concat(tile.unit_ids, ", ") or "none"
        local lines = {
            string.format("(%d, %d)", tile_x, tile_y),
            "terrain:     " .. tile.terrain,
            "plant:       " .. tostring(tile.plant_type) .. " / " .. tostring(tile.plant_growth),
            "forest_depth:" .. string.format(" %.2f", tile.forest_depth),
            "building_id: " .. tostring(tile.building_id),
            "bldg_role:   " .. tostring(tile.building_role),
            "is_clearing: " .. tostring(tile.is_clearing),
            "ground_pile: " .. tostring(tile.ground_pile_id),
            "target_of:   " .. tostring(tile.target_of_unit),
            "unit_ids:    " .. uid_str,
        }
        local insp_h   = #lines * LH + PAD * 2
        local insp_y   = stats_h + 2
        love.graphics.setColor(COL_BG)
        love.graphics.rectangle("fill", 0, insp_y, 200, insp_h)
        love.graphics.setColor(COL_TEXT)
        for i, line in ipairs(lines) do
            love.graphics.print(line, PAD, insp_y + PAD + (i - 1) * LH)
        end
    end

    -- Log tail (newest at bottom)
    local entries     = log:getRecent(10)
    local entry_count = #entries
    local log_height  = entry_count * LH + PAD * 2
    local log_y       = screen_height - log_height
    local log_width   = screen_width * 0.55
    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", 0, log_y, log_width, log_height)
    love.graphics.setColor(COL_DIM)
    for i = 1, entry_count do
        love.graphics.print(entries[entry_count - i + 1], PAD, log_y + PAD + (i - 1) * LH)
    end
end

return dev_overlay
