-- app/main_menu.lua
-- Main menu state. Shows title and "New Game" button. Escape quits.

local gamestate = require("app.gamestate")
local playing   = require("app.playing")

local main_menu = {}

local btn = { w = 200, h = 48 }

function main_menu.draw()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    btn.x = (sw - btn.w) / 2
    btn.y = sh / 2

    love.graphics.setBackgroundColor(0.08, 0.08, 0.10)

    -- Title
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.printf("SOVEREIGN", 0, sh / 2 - 120, sw, "center")

    -- New Game button
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4, 4)
    love.graphics.setColor(0.6, 0.6, 0.65)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 4, 4)
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.printf("New Game", btn.x, btn.y + 14, btn.w, "center")
end

function main_menu.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function main_menu.mousepressed(x, y, button)
    if button == 1 then
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            gamestate:switch(playing)
        end
    end
end

return main_menu
