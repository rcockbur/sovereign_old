-- app/main_menu.lua
-- Main menu state. Shows title and "New Game" button. Escape quits.

local gamestate   = require("app.gamestate")
local generating  = require("app.generating")

local main_menu = {}

local btn = { width = 200, height = 48 }

function main_menu.draw()
    local screen_width  = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    btn.x = (screen_width - btn.width) / 2
    btn.y = screen_height / 2

    love.graphics.setBackgroundColor(0.08, 0.08, 0.10)

    -- Title
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.printf("SOVEREIGN", 0, screen_height / 2 - 120, screen_width, "center")

    -- New Game button
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 4, 4)
    love.graphics.setColor(0.6, 0.6, 0.65)
    love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 4, 4)
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.printf("New Game", btn.x, btn.y + 14, btn.width, "center")
end

function main_menu.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function main_menu.mousepressed(x, y, button)
    if button == 1 then
        if x >= btn.x and x <= btn.x + btn.width and y >= btn.y and y <= btn.y + btn.height then
            gamestate:switch(generating)
        end
    end
end

return main_menu
