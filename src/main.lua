-- main.lua
ARGS_AUTO_NEWGAME = false
ARGS_DEBUG        = false
for i = 1, #arg do
    if arg[i] == "--newgame" then
        ARGS_AUTO_NEWGAME = true
    end
    if arg[i] == "--debug"   then
        ARGS_DEBUG        = true
    end
end

if ARGS_DEBUG then
    require("lldebugger").start()
end

require("core.util")
require("config.constants")
require("config.keybinds")
require("config.tables")

local gamestate = require("app.gamestate")
local loading   = require("app.loading")

function love.load()
    gamestate:switch(loading)
end

function love.update(dt)
    gamestate:update(dt)
end

function love.draw()
    gamestate:draw()
end

function love.keypressed(key)
    gamestate:keypressed(key)
end

function love.mousepressed(x, y, button)
    gamestate:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    gamestate:mousereleased(x, y, button)
end

function love.wheelmoved(dx, dy)
    gamestate:wheelmoved(dx, dy)
end
