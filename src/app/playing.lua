-- app/playing.lua
-- Playing state. Runs the simulation; escape returns to main menu.

local gamestate = require("app.gamestate")
local world     = require("core.world")
local time      = require("core.time")
local log       = require("core.log")

local playing = {}

local prev_hour

function playing.enter()
    world.init()
    time.init()
    prev_hour = -1

    local settle = { grass=0, water=0, rock=0, tree=0, berry=0 }
    local forest  = { grass=0, water=0, rock=0, tree=0, berry=0 }
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local t    = world.tiles[tileIndex(x, y)]
            local half = x <= SETTLEMENT_COLUMNS and settle or forest
            if t.terrain == "water" then
                half.water = half.water + 1
            elseif t.terrain == "rock" then
                half.rock = half.rock + 1
            elseif t.plant_type == "tree" then
                half.tree = half.tree + 1
            elseif t.plant_type == "berry_bush" then
                half.berry = half.berry + 1
            else
                half.grass = half.grass + 1
            end
        end
    end
    log:info("WORLD", "Settlement — grass:%d water:%d rock:%d tree:%d berry:%d",
        settle.grass, settle.water, settle.rock, settle.tree, settle.berry)
    log:info("WORLD", "Forest     — grass:%d water:%d rock:%d tree:%d berry:%d",
        forest.grass, forest.water, forest.rock, forest.tree, forest.berry)
    log:info("WORLD", "Settlement: %s  Seed: %d",
        world.settings.settlement_name, world.seed)
end

function playing.update(dt)
    local ticks = time.accumulate(dt)
    for _ = 1, ticks do
        time.advance()
    end

    local wt = world.time
    if wt.game_hour ~= prev_hour then
        prev_hour = wt.game_hour
        log:info("TIME", "Year %d  Season %d  Day %d  Hour %d",
            wt.game_year, wt.game_season, wt.game_day, wt.game_hour)
    end
end

function playing.draw()
    love.graphics.setBackgroundColor(0.05, 0.07, 0.05)
end

function playing.keypressed(key)
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
end

return playing
