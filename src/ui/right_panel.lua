-- ui/right_panel.lua
-- Always-visible right panel: time display and speed controls.

local world = require("core.world")
local time  = require("core.time")

local right_panel = {}

local PANEL_W   = 200
local PANEL_PAD = 8
local BTN_W     = 22
local BTN_H     = 20
local BTN_GAP   = 3

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
    local period = hour < 12 and "AM" or "PM"
    local h = hour % 12
    if h == 0 then h = 12 end
    return string.format("%d:%02d %s", h, minute, period)
end

function right_panel.draw()
    local sw  = love.graphics.getWidth()
    local sh  = love.graphics.getHeight()
    local px  = sw - PANEL_W
    local fh  = love.graphics.getFont():getHeight()
    local lh  = fh + 3

    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", px, 0, PANEL_W, sh)
    love.graphics.setColor(COL_BORDER)
    love.graphics.line(px, 0, px, sh)

    local wt = world.time
    love.graphics.setColor(COL_HEADER)
    love.graphics.print(
        string.format("Year %d  %s  %s", wt.game_year, SEASON_NAMES[wt.game_season], DAY_NAMES[wt.game_day]),
        px + PANEL_PAD, PANEL_PAD)
    love.graphics.setColor(COL_TEXT)
    love.graphics.print(formatTime(wt.game_hour, wt.game_minute), px + PANEL_PAD, PANEL_PAD + lh)

    local by = PANEL_PAD + lh * 2 + 6

    for i = 1, 6 do
        local bx        = px + PANEL_PAD + (i - 1) * (BTN_W + BTN_GAP)
        local is_active = world.time.speed == SPEED_LIST[i] and world.time.is_paused == false
        love.graphics.setColor(is_active and COL_BTN_ACTIVE or COL_BTN)
        love.graphics.rectangle("fill", bx, by, BTN_W, BTN_H, 2, 2)
        love.graphics.setColor(COL_TEXT)
        love.graphics.printf(tostring(i), bx, by + (BTN_H - fh) * 0.5, BTN_W, "center")
        local b = btn_rects[i]
        b.x = bx;  b.y = by;  b.w = BTN_W;  b.h = BTN_H;  b.speed = SPEED_LIST[i]
    end

    local pause_x = px + PANEL_PAD + 6 * (BTN_W + BTN_GAP) + 4
    local pause_w = BTN_W + 8
    love.graphics.setColor(world.time.is_paused == true and COL_BTN_PAUSE or COL_BTN)
    love.graphics.rectangle("fill", pause_x, by, pause_w, BTN_H, 2, 2)
    love.graphics.setColor(COL_TEXT)
    love.graphics.printf(world.time.is_paused == true and ">" or "||", pause_x, by + (BTN_H - fh) * 0.5, pause_w, "center")
    local pb = btn_rects[7]
    pb.x = pause_x;  pb.y = by;  pb.w = pause_w;  pb.h = BTN_H;  pb.is_pause = true
end

-- Returns true if the click was consumed (inside the panel area).
function right_panel.mousepressed(x, y, button)
    local sw = love.graphics.getWidth()
    if x < sw - PANEL_W then return false end

    if button == 1 then
        for _, btn in ipairs(btn_rects) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
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

right_panel.width = PANEL_W

return right_panel
