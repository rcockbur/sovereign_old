-- app/playing.lua
-- Playing state. Runs the simulation; escape returns to main menu.

local gamestate    = require("app.gamestate")
local time         = require("core.time")
local simulation   = require("core.simulation")
local units        = require("simulation.units")
local resources    = require("simulation.resources")
local activities   = require("simulation.activities")
local world        = require("core.world")
local log          = require("core.log")
local camera       = require("ui.camera")
local renderer     = require("ui.renderer")
local hub          = require("ui.hub")
local right_panel  = require("ui.right_panel")
local dev_overlay  = require("ui.dev_overlay")

local playing = {}

function playing.enter()
    time.init()
    camera.init()
    units.spawnStarting()
    resources.rebuildCounts()
    -- M14 debug: three test activities for verifying the activity system.
    -- Units will claim, travel to, work at, and release these on their own.
    activities.postActivity({ type = "fisher", x = 85,  y = 100 })
    activities.postActivity({ type = "fisher", x = 115, y = 100 })
    activities.postActivity({ type = "fisher", x = 100, y = 85  })
end

function playing.update(dt)
    camera.update(dt)
    hub.update()

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
    renderer.drawBuildings()
    renderer.drawUnits()
    renderer.drawSelection(hub.selected, hub.selected_type, hub.selected_tile)
    hub.drawWorld()
    love.graphics.pop()

    hub.draw()
    right_panel.draw()
    dev_overlay.draw()
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
    elseif key == "f3" then
        dev_overlay.toggle()
    elseif key == "f2" then
        for i = 1, #world.buildings do
            local b = world.buildings[i]
            if b.type == "stockpile" then
                local amount = math.floor(CARRY_WEIGHT_MAX / ResourceConfig["wood"].weight)
                if resources.getAvailableCapacity(b.storage, "wood") >= ResourceConfig["wood"].weight * amount then
                    local id = resources.create("wood", amount)
                    resources.deposit(b.storage, id)
                    log:info("WORLD", "Debug: deposited %d wood into stockpile %d", amount, b.id)
                else
                    log:info("WORLD", "Debug: stockpile %d is full", b.id)
                end
                break
            end
        end
    end
end

function playing.mousepressed(x, y, button)
    if right_panel.mousepressed(x, y, button) then return end
    hub.mousepressed(x, y, button)
    camera.mousepressed(x, y, button)
end

function playing.mousereleased(x, y, button)
    hub.mousereleased(x, y, button)
    camera.mousereleased(x, y, button)
end

function playing.wheelmoved(dx, dy)
    camera.wheelmoved(dx, dy)
end

return playing
