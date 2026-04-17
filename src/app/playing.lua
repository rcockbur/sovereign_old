-- app/playing.lua
-- Playing state. Runs the simulation; escape returns to main menu.

local gamestate    = require("app.gamestate")
local time         = require("core.time")
local simulation   = require("core.simulation")
local units        = require("simulation.units")
local camera       = require("ui.camera")
local renderer     = require("ui.renderer")
local hub          = require("ui.hub")

local playing = {}

function playing.enter()
    time.init()
    camera.init()
    units.spawnStarting()
end

function playing.update(dt)
    camera.update(dt)

    local ticks = time.accumulate(dt)
    for _ = 1, ticks do
        simulation.onTick()
    end
end

function playing.draw()
    love.graphics.setBackgroundColor(0.05, 0.07, 0.05)

    love.graphics.push()
    camera.applyTransform()
    renderer.drawWorld()
    renderer.drawUnits()
    renderer.drawSelection(hub.selected, hub.selected_type, hub.selected_tile)
    love.graphics.pop()

    hub.draw()
end

function playing.keypressed(key)
    if hub.keypressed(key) then return end
    if key == "escape" then
        gamestate:switch(require("app.main_menu"))
    elseif key == Keybinds.toggle_pause then
        time.togglePause()
    elseif key == Keybinds.speed_1 then
        time.setSpeed(Speed.NORMAL)
    elseif key == Keybinds.speed_2 then
        time.setSpeed(Speed.FAST)
    elseif key == Keybinds.speed_3 then
        time.setSpeed(Speed.VERY_FAST)
    elseif key == Keybinds.speed_4 then
        time.setSpeed(Speed.ULTRA)
    elseif key == Keybinds.speed_5 then
        time.setSpeed(Speed.TURBO)
    elseif key == Keybinds.speed_6 then
        time.setSpeed(Speed.MAX)
    end
end

function playing.mousepressed(x, y, button)
    hub.mousepressed(x, y, button)
    camera.mousepressed(x, y, button)
end

function playing.mousereleased(x, y, button)
    camera.mousereleased(x, y, button)
end

function playing.wheelmoved(dx, dy)
    camera.wheelmoved(dx, dy)
end

return playing
