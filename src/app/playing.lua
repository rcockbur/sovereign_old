-- app/playing.lua
-- Playing state shell. Escape returns to main menu.

local gamestate = require("app.gamestate")

local playing = {}

function playing.enter()
end

function playing.update(dt)
end

function playing.draw()
    love.graphics.setBackgroundColor(0.05, 0.07, 0.05)
end

function playing.keypressed(key)
    if key == "escape" then
        gamestate:switch(require("app.main_menu"))
    end
end

function playing.mousepressed(x, y, button)
end

return playing
