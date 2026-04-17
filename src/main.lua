-- main.lua
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

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
