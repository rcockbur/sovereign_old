-- ui/overlay.lua
-- Developer overlay. Toggled with F3 via the input system.
-- Draws stats bar, tile inspector on cursor hover, and log tail.


local log = require("core.log")

local overlay = { is_visible = false }

local FONT_SIZE   = 12
local LINE_HEIGHT = 14
local PAD         = 6
local BG          = { 0, 0, 0, 0.7 }
local TEXT        = { 1, 1, 1, 1   }
local DIM         = { 0.7, 0.7, 0.7, 1 }
local font = love.graphics.newFont(FONT_SIZE)

--- Toggle the overlay on/off.
function overlay:toggle()
    self.is_visible = not self.is_visible
end

--- Draw the overlay. Call after all world rendering, before love.graphics.present.
--- time, units_mod, world_mod, jobqueue_mod, camera_mod are module references.
function overlay:draw(time, units_mod, world_mod, jobqueue_mod, camera_mod)
    if self.is_visible == false then return end

    local w = love.graphics.getWidth()

    love.graphics.setFont(font)

    -- -----------------------------------------------------------------------
    -- Stats bar (top-left)
    -- -----------------------------------------------------------------------
    local stats = {
        string.format("FPS: %d", love.timer.getFPS()),
        string.format("Tick: %d", time.tick),
        string.format("Time: %02d:%02d  Day %d  %s  Year %d",
            time.game_hour, time.game_minute,
            time.game_day, SEASON_NAMES[time.game_season], time.game_year),
        string.format("Speed: x%d%s", time.speed, time.is_paused and " [PAUSED]" or ""),
        string.format("Units: %d  Buildings: %d  Jobs: %d",
            #units_mod.all, #world_mod.buildings, #jobqueue_mod.jobs),
    }

    local bar_h = PAD * 2 + #stats * LINE_HEIGHT
    love.graphics.setColor(BG)
    love.graphics.rectangle("fill", 0, 0, 320, bar_h)
    love.graphics.setColor(TEXT)
    for i, line in ipairs(stats) do
        love.graphics.print(line, PAD, PAD + (i - 1) * LINE_HEIGHT)
    end

    -- -----------------------------------------------------------------------
    -- Tile inspector (follows cursor)
    -- -----------------------------------------------------------------------
    local mx, my     = love.mouse.getPosition()
    local wx, wy     = camera_mod:toWorld(mx, my)
    local tx, ty     = math.floor(wx), math.floor(wy)

    if tx >= 1 and tx <= MAP_WIDTH and ty >= 1 and ty <= MAP_HEIGHT then
        local idx  = world_mod.tileIndex(tx, ty)
        local tile = world_mod.tiles[idx]

        local info = {
            string.format("Tile (%d, %d)", tx, ty),
            string.format("terrain: %s", tile.terrain),
            string.format("plant: %s  growth: %d", tile.plant_type or "none", tile.plant_growth),
            string.format("forest_depth: %.2f  danger: %.2f", tile.forest_depth, tile.danger),
            string.format("building_id: %s", tostring(tile.building_id)),
            string.format("claimed_by: %s",  tostring(tile.claimed_by)),
            string.format("explored: %s  visible: %d", tostring(tile.is_explored), tile.visible_count),
        }

        -- Unit inspector: append stats if a unit occupies this tile.
        local hovered_unit = nil
        for i = 1, #units_mod.all do
            local u = units_mod.all[i]
            if u.is_dead == false and u.x == tx and u.y == ty then
                hovered_unit = u
                break
            end
        end
        if hovered_unit ~= nil then
            local u = hovered_unit
            local tier_name = (TIER_NAMES)[u.tier] or "?"
            info[#info + 1] = "---"
            info[#info + 1] = string.format("%s - %s - %s%s", u.name, tier_name, GENDER_NAMES[u.is_male], u.is_leader and " - LEADER" or "")
            info[#info + 1] = string.format("id=%d  age=%d  dead=%s  drafted=%s", u.id, u.age, tostring(u.is_dead), tostring(u.is_drafted))
            info[#info + 1] = string.format("satiation=%.1f  energy=%.1f  recreation=%.1f", u.needs.satiation, u.needs.energy, u.needs.recreation)
            info[#info + 1] = string.format("mood=%.1f  health=%.1f", u.mood, u.health)
            info[#info + 1] = string.format("activity=%s  job=%s", tostring(u.current_activity), tostring(u.current_job_id))
        end

        local box_w = 320
        local box_h = PAD * 2 + #info * LINE_HEIGHT
        local bx    = math.min(mx + 16, w - box_w - PAD)
        local by    = math.max(bar_h + PAD, my)

        love.graphics.setColor(BG)
        love.graphics.rectangle("fill", bx, by, box_w, box_h)
        love.graphics.setColor(DIM)
        for i, line in ipairs(info) do
            love.graphics.print(line, bx + PAD, by + PAD + (i - 1) * LINE_HEIGHT)
        end
    end

    -- -----------------------------------------------------------------------
    -- Log tail (bottom-left)
    -- -----------------------------------------------------------------------
    local tail    = log:tail(10)
    local log_h   = PAD * 2 + #tail * LINE_HEIGHT
    local screen_h = love.graphics.getHeight()

    love.graphics.setColor(BG)
    love.graphics.rectangle("fill", 0, screen_h - log_h, 600, log_h)
    love.graphics.setColor(DIM)
    for i, entry in ipairs(tail) do
        local line = string.format("[%s] %s %s: %s",
            entry.timestamp, entry.label, entry.category, entry.message)
        love.graphics.print(line, PAD, screen_h - log_h + PAD + (i - 1) * LINE_HEIGHT)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return overlay
