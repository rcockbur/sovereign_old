-- ui/camera.lua
-- Camera: position, zoom, pan (keyboard + middle-mouse drag), zoom (scroll wheel).
-- screen↔world coordinate conversion. applyTransform() sets up the world-pass matrix.

local camera = {}

local PAN_SPEED = 800  -- screen pixels per second

local drag_active   = false
local drag_start_x  = 0
local drag_start_y  = 0
local drag_camera_x = 0
local drag_camera_y = 0

function camera.init()
    camera.x    = (GEN_START_X - 0.5) * TILE_SIZE
    camera.y    = (GEN_START_Y - 0.5) * TILE_SIZE
    camera.zoom = 1.0
    drag_active = false
end

function camera.update(dt)
    local delta_x = 0
    local delta_y = 0
    if love.keyboard.isDown(Keybinds.pan_up)    then delta_y = delta_y - 1 end
    if love.keyboard.isDown(Keybinds.pan_down)  then delta_y = delta_y + 1 end
    if love.keyboard.isDown(Keybinds.pan_left)  then delta_x = delta_x - 1 end
    if love.keyboard.isDown(Keybinds.pan_right) then delta_x = delta_x + 1 end
    if delta_x ~= 0 or delta_y ~= 0 then
        local speed = PAN_SPEED / camera.zoom
        if delta_x ~= 0 and delta_y ~= 0 then
            speed = speed / SQRT2
        end
        camera.x = camera.x + delta_x * speed * dt
        camera.y = camera.y + delta_y * speed * dt
    end

    if drag_active then
        local mouse_x, mouse_y = love.mouse.getPosition()
        camera.x = drag_camera_x + (drag_start_x - mouse_x) / camera.zoom
        camera.y = drag_camera_y + (drag_start_y - mouse_y) / camera.zoom
    end
end

function camera.mousepressed(screen_x, screen_y, button)
    if button == 3 then
        drag_active   = true
        drag_start_x  = screen_x
        drag_start_y  = screen_y
        drag_camera_x = camera.x
        drag_camera_y = camera.y
    end
end

function camera.mousereleased(screen_x, screen_y, button)
    if button == 3 then
        drag_active = false
    end
end

function camera.wheelmoved(scroll_x, scroll_y)
    if scroll_y == 0 then
        return
    end
    local old_zoom        = camera.zoom
    local new_zoom        = math.max(ZOOM_MIN, math.min(ZOOM_MAX, camera.zoom * (1.1 ^ scroll_y)))
    local screen_width, screen_height = love.graphics.getDimensions()
    local mouse_x, mouse_y            = love.mouse.getPosition()
    camera.x    = camera.x + (mouse_x - screen_width  / 2) * (1 / old_zoom - 1 / new_zoom)
    camera.y    = camera.y + (mouse_y - screen_height / 2) * (1 / old_zoom - 1 / new_zoom)
    camera.zoom = new_zoom
end

function camera.screenToWorld(screen_x, screen_y)
    local screen_width, screen_height = love.graphics.getDimensions()
    return (screen_x - screen_width  / 2) / camera.zoom + camera.x,
           (screen_y - screen_height / 2) / camera.zoom + camera.y
end

function camera.worldToScreen(world_x, world_y)
    local screen_width, screen_height = love.graphics.getDimensions()
    return (world_x - camera.x) * camera.zoom + screen_width  / 2,
           (world_y - camera.y) * camera.zoom + screen_height / 2
end

function camera.applyTransform()
    local screen_width, screen_height = love.graphics.getDimensions()
    love.graphics.translate(screen_width / 2, screen_height / 2)
    love.graphics.scale(camera.zoom, camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)
end

return camera
