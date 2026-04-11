-- main.lua
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

-- Config globals must be set before any module that reads them is loaded.
require("config.constants_config")
require("config.names_config")
require("config.needs_config")
require("config.health_config")
require("config.jobs_config")
require("config.resources_config")
require("config.buildings_config")

local gamestate  = require("core.gamestate")
local log        = require("core.log")
local registry   = require("core.registry")
local time       = require("core.time")
local world      = require("core.world")
local simulation = require("core.simulation")
local units      = require("simulation.unit")
local jobqueue   = require("simulation.jobqueue")
local dynasty    = require("simulation.dynasty")

local camera   = require("ui.camera")
local input    = require("ui.input")
local overlay  = require("ui.overlay")
local renderer = require("ui.renderer")

-- ---------------------------------------------------------------------------
-- New-game setup: reset all modules then build a fresh world.
-- ---------------------------------------------------------------------------

local STARTING_X = 50   -- column in the settlement area
local STARTING_Y = 100  -- centre of the map vertically

local function newGame()
    -- Reset all stateful modules in dependency order.
    registry:reset()
    units:reset()
    world:reset()
    jobqueue:reset()
    dynasty:reset()
    time:reset()

    world:generate()

    -- Starting population: 6 Serfs + 1 Gentry (the first leader).
    local sx, sy = STARTING_X, STARTING_Y
    units:create({ x = sx,     y = sy,     tier = Tier.SERF })
    units:create({ x = sx + 2, y = sy,     tier = Tier.SERF })
    units:create({ x = sx + 4, y = sy,     tier = Tier.SERF })
    units:create({ x = sx,     y = sy + 2, tier = Tier.SERF })
    units:create({ x = sx + 2, y = sy + 2, tier = Tier.SERF })
    units:create({ x = sx + 4, y = sy + 2, tier = Tier.SERF })

    local leader = units:create({ x = sx + 2, y = sy - 2, tier = Tier.GENTRY })
    dynasty:appoint(leader)

    camera.x    = sx + 2
    camera.y    = sy
    camera.zoom = 1.0
end

-- ---------------------------------------------------------------------------
-- Loading state — require configs (already done above), switch to main_menu.
-- ---------------------------------------------------------------------------

function gamestate.loading:enter()
    gamestate:switch(gamestate.main_menu)
end

-- ---------------------------------------------------------------------------
-- Main menu state
-- ---------------------------------------------------------------------------

local TITLE_FONT = nil   -- created lazily in draw (love not yet initialised at require time)

function gamestate.main_menu:enter()
    log:info("STATE", "Main menu")
end

function gamestate.main_menu:draw()
    if TITLE_FONT == nil then
        TITLE_FONT = love.graphics.newFont(32)
    end
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(0.05, 0.05, 0.08)

    love.graphics.setFont(TITLE_FONT)
    love.graphics.setColor(0.9, 0.85, 0.6)
    love.graphics.printf("SOVEREIGN", 0, h * 0.3, w, "center")

    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.printf("New Game (N)", 0, h * 0.55, w, "center")
    love.graphics.printf("Quit (Esc)", 0, h * 0.62, w, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

function gamestate.main_menu:keypressed(key)
    if key == "n" then
        newGame()
        gamestate:switch(gamestate.playing)
    elseif key == "escape" then
        love.event.quit()
    end
end

-- ---------------------------------------------------------------------------
-- Playing state
-- ---------------------------------------------------------------------------

local function quitToMenu()
    log:info("STATE", "Returning to main menu")
    gamestate:switch(gamestate.main_menu)
end

function gamestate.playing:update(dt)
    camera:update(dt, input)

    if time.is_paused == false then
        local ticks = time:accumulate(dt)
        for _ = 1, ticks do
            simulation:onTick(time)
        end
    end
end

function gamestate.playing:draw()
    love.graphics.clear(0, 0, 0)
    camera:attach()
    renderer:drawWorld(world, units)
    camera:detach()
    overlay:draw(time, units, world, jobqueue, camera)
end

function gamestate.playing:keypressed(key)
    if input:isActionPressed("pause", key) then
        time.is_paused = not time.is_paused
        log:info("STATE", "Simulation %s", time.is_paused and "paused" or "resumed")
    elseif input:isActionPressed("speed_1", key) then
        time.speed = Speed.NORMAL
    elseif input:isActionPressed("speed_2", key) then
        time.speed = Speed.FAST
    elseif input:isActionPressed("speed_3", key) then
        time.speed = Speed.VERY_FAST
    elseif input:isActionPressed("speed_4", key) then
        time.speed = Speed.ULTRA
    elseif input:isActionPressed("dev_overlay", key) then
        overlay:toggle()
    elseif key == "escape" then
        quitToMenu()
    end
end

function gamestate.playing:wheelmoved(x, y)
    camera:adjustZoom(y)
end

-- ---------------------------------------------------------------------------
-- Love2D callbacks — delegate to gamestate
-- ---------------------------------------------------------------------------

function love.load()
    log:info("STATE", "Sovereign starting up")
    gamestate:switch(gamestate.loading)
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

function love.wheelmoved(x, y)
    gamestate:wheelmoved(x, y)
end

function love.resize(w, h)
    gamestate:resize(w, h)
end

function love.quit()
    log:info("STATE", "Sovereign shutting down")
end
