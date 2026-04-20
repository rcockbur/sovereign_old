-- app/generating.lua
-- World generation state. Drives the gen coroutine one phase per frame and draws a loading bar.

local gamestate = require("app.gamestate")
local world     = require("core.world")

local generating = {}

local gen_co   = nil
local progress = 0.0
local label    = ""

function generating.enter()
    progress = 0.0
    label    = ""
    gen_co   = world.newGenCoroutine()
end

function generating.update()
    if gen_co == nil then
        return
    end

    local ok, new_progress, new_label = coroutine.resume(gen_co)
    assert(ok, new_progress)

    if coroutine.status(gen_co) == "dead" then
        gen_co = nil
        gamestate:switch(require("app.playing"))
    else
        progress = new_progress or progress
        label    = new_label    or label
    end
end

function generating.draw()
    local screen_width  = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    love.graphics.clear(0.05, 0.07, 0.05)

    local bar_w = 400
    local bar_h = 20
    local bar_x = (screen_width  - bar_w) / 2
    local bar_y = screen_height / 2

    love.graphics.setColor(0.15, 0.18, 0.15)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 3, 3)

    love.graphics.setColor(0.35, 0.65, 0.35)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * progress, bar_h, 3, 3)

    love.graphics.setColor(0.4, 0.45, 0.4)
    love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h, 3, 3)

    love.graphics.setColor(0.75, 0.8, 0.7)
    love.graphics.printf(label, bar_x, bar_y - 24, bar_w, "center")
end

return generating
