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

local PAD  = 5
local LH   = 16

function dev_overlay.toggle()
    dev_overlay.is_visible = dev_overlay.is_visible == false
end

function dev_overlay.draw()
    if dev_overlay.is_visible == false then return end

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Stats bar
    local wt      = world.time
    local achieved = time.ticks_last_second
    local target   = wt.speed * TICK_RATE
    local tps_str
    if wt.is_paused == true then
        tps_str = string.format("TPS: -- / %d (paused)", target)
    else
        local pct = math.floor(achieved / target * 100)
        tps_str = string.format("TPS: %d / %d (%d%%)", achieved, target, pct)
    end

    local stats = string.format("FPS: %d  |  %s  |  Speed: %d  |  Units: %d  Bldg: %d  Act: %d  Piles: %d",
        love.timer.getFPS(), tps_str, wt.speed,
        #world.units, #world.buildings, #world.activities, #world.ground_piles)

    local stats_h = LH + PAD * 2
    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", 0, 0, sw, stats_h)
    love.graphics.setColor(COL_TEXT)
    love.graphics.print(stats, PAD, PAD)

    -- Tile inspector (hovered tile)
    local mx, my = love.mouse.getPosition()
    local wx, wy = camera.screenToWorld(mx, my)
    local tx = math.floor(wx / TILE_SIZE) + 1
    local ty = math.floor(wy / TILE_SIZE) + 1

    if tx >= 1 and tx <= MAP_WIDTH and ty >= 1 and ty <= MAP_HEIGHT then
        local t = world.tiles[tileIndex(tx, ty)]
        local uid_str = #t.unit_ids > 0 and table.concat(t.unit_ids, ", ") or "none"
        local lines = {
            string.format("(%d, %d)", tx, ty),
            "terrain:     " .. t.terrain,
            "plant:       " .. tostring(t.plant_type) .. " / " .. tostring(t.plant_growth),
            "forest_depth:" .. string.format(" %.2f", t.forest_depth),
            "building_id: " .. tostring(t.building_id),
            "bldg_role:   " .. tostring(t.building_role),
            "is_clearing: " .. tostring(t.is_clearing),
            "ground_pile: " .. tostring(t.ground_pile_id),
            "target_of:   " .. tostring(t.target_of_unit),
            "unit_ids:    " .. uid_str,
        }
        local insp_h = #lines * LH + PAD * 2
        local insp_y = stats_h + 2
        love.graphics.setColor(COL_BG)
        love.graphics.rectangle("fill", 0, insp_y, 200, insp_h)
        love.graphics.setColor(COL_TEXT)
        for i, line in ipairs(lines) do
            love.graphics.print(line, PAD, insp_y + PAD + (i - 1) * LH)
        end
    end

    -- Log tail (newest at bottom)
    local entries = log:getRecent(10)
    local n       = #entries
    local log_h   = n * LH + PAD * 2
    local log_y   = sh - log_h
    local log_w   = sw * 0.55
    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", 0, log_y, log_w, log_h)
    love.graphics.setColor(COL_DIM)
    for i = 1, n do
        love.graphics.print(entries[n - i + 1], PAD, log_y + PAD + (i - 1) * LH)
    end
end

return dev_overlay
