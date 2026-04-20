-- ui/right_panel.lua
-- Always-visible right panel: time display and speed controls.

local world = require("core.world")
local time  = require("core.time")

local right_panel = {}

local PANEL_WIDTH  = 200
local PANEL_PAD    = 8
local BUTTON_WIDTH = 22
local BUTTON_HEIGHT = 20
local BUTTON_GAP   = 3

local COL_BG         = { 0.08, 0.09, 0.10, 0.94 }
local COL_BORDER     = { 0.25, 0.27, 0.28, 1.00 }
local COL_TEXT       = { 0.78, 0.80, 0.78, 1.00 }
local COL_HEADER     = { 0.85, 0.80, 0.55, 1.00 }
local COL_BTN        = { 0.18, 0.20, 0.22, 1.00 }
local COL_BTN_ACTIVE = { 0.30, 0.60, 0.30, 1.00 }
local COL_BTN_PAUSE  = { 0.60, 0.45, 0.20, 1.00 }

local SPEED_LIST = {
    Speed.NORMAL, Speed.FAST, Speed.VERY_FAST,
    Speed.ULTRA,  Speed.TURBO, Speed.MAX,
}

local btn_rects = { {}, {}, {}, {}, {}, {}, {} }

local function formatTime(hour, minute)
    local period       = hour < 12 and "AM" or "PM"
    local display_hour = hour % 12
    if display_hour == 0 then
        display_hour = 12
    end
    return string.format("%d:%02d %s", display_hour, minute, period)
end

function right_panel.draw()
    local screen_width  = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    local panel_x       = screen_width - PANEL_WIDTH
    local font_height   = love.graphics.getFont():getHeight()
    local line_height   = font_height + 3

    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", panel_x, 0, PANEL_WIDTH, screen_height)
    love.graphics.setColor(COL_BORDER)
    love.graphics.line(panel_x, 0, panel_x, screen_height)

    local world_time = world.time
    love.graphics.setColor(COL_HEADER)
    love.graphics.print(
        string.format("Year %d  %s  %s", world_time.game_year, SEASON_NAMES[world_time.game_season], DAY_NAMES[world_time.game_day]),
        panel_x + PANEL_PAD, PANEL_PAD)
    love.graphics.setColor(COL_TEXT)
    love.graphics.print(formatTime(world_time.game_hour, world_time.game_minute), panel_x + PANEL_PAD, PANEL_PAD + line_height)

    local button_y = PANEL_PAD + line_height * 2 + 6

    for i = 1, 6 do
        local button_x  = panel_x + PANEL_PAD + (i - 1) * (BUTTON_WIDTH + BUTTON_GAP)
        local is_active = world.time.speed == SPEED_LIST[i] and world.time.is_paused == false
        love.graphics.setColor(is_active and COL_BTN_ACTIVE or COL_BTN)
        love.graphics.rectangle("fill", button_x, button_y, BUTTON_WIDTH, BUTTON_HEIGHT, 2, 2)
        love.graphics.setColor(COL_TEXT)
        love.graphics.printf(tostring(i), button_x, button_y + (BUTTON_HEIGHT - font_height) * 0.5, BUTTON_WIDTH, "center")
        local btn = btn_rects[i]
        btn.x      = button_x
        btn.y      = button_y
        btn.width  = BUTTON_WIDTH
        btn.height = BUTTON_HEIGHT
        btn.speed  = SPEED_LIST[i]
    end

    local pause_x     = panel_x + PANEL_PAD + 6 * (BUTTON_WIDTH + BUTTON_GAP) + 4
    local pause_width = BUTTON_WIDTH + 8
    love.graphics.setColor(world.time.is_paused == true and COL_BTN_PAUSE or COL_BTN)
    love.graphics.rectangle("fill", pause_x, button_y, pause_width, BUTTON_HEIGHT, 2, 2)
    love.graphics.setColor(COL_TEXT)
    love.graphics.printf(world.time.is_paused == true and ">" or "||", pause_x, button_y + (BUTTON_HEIGHT - font_height) * 0.5, pause_width, "center")
    local pause_btn    = btn_rects[7]
    pause_btn.x        = pause_x
    pause_btn.y        = button_y
    pause_btn.width    = pause_width
    pause_btn.height   = BUTTON_HEIGHT
    pause_btn.is_pause = true
end

-- Returns true if the click was consumed (inside the panel area).
function right_panel.mousepressed(x, y, button)
    local screen_width = love.graphics.getWidth()
    if x < screen_width - PANEL_WIDTH then
        return false
    end

    if button == 1 then
        for _, btn in ipairs(btn_rects) do
            if x >= btn.x and x <= btn.x + btn.width and y >= btn.y and y <= btn.y + btn.height then
                if btn.is_pause then
                    time.togglePause()
                else
                    time.setSpeed(btn.speed)
                end
                return true
            end
        end
    end

    return true
end

right_panel.width = PANEL_WIDTH

return right_panel
