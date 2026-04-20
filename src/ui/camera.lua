-- ui/camera.lua
-- Camera: position, zoom, pan (keyboard + middle-mouse drag), zoom (scroll wheel).
-- screen↔world coordinate conversion. applyTransform() sets up the world-pass matrix.

local camera = {}

local PAN_SPEED = 800  -- screen pixels per second

local drag_active = false
local drag_sx     = 0
local drag_sy     = 0
local drag_cam_x  = 0
local drag_cam_y  = 0

function camera.init()
    camera.x    = (GEN_START_X - 0.5) * TILE_SIZE
    camera.y    = (GEN_START_Y - 0.5) * TILE_SIZE
    camera.zoom = 1.0
    drag_active = false
end

function camera.update(dt)
    local dx = 0
    local dy = 0
    if love.keyboard.isDown(Keybinds.pan_up)    then dy = dy - 1 end
    if love.keyboard.isDown(Keybinds.pan_down)  then dy = dy + 1 end
    if love.keyboard.isDown(Keybinds.pan_left)  then dx = dx - 1 end
    if love.keyboard.isDown(Keybinds.pan_right) then dx = dx + 1 end
    if dx ~= 0 or dy ~= 0 then
        local speed = PAN_SPEED / camera.zoom
        if dx ~= 0 and dy ~= 0 then
            speed = speed / SQRT2
        end
        camera.x = camera.x + dx * speed * dt
        camera.y = camera.y + dy * speed * dt
    end

    if drag_active then
        local mx, my = love.mouse.getPosition()
        camera.x = drag_cam_x + (drag_sx - mx) / camera.zoom
        camera.y = drag_cam_y + (drag_sy - my) / camera.zoom
    end
end

function camera.mousepressed(sx, sy, button)
    if button == 3 then
        drag_active = true
        drag_sx     = sx
        drag_sy     = sy
        drag_cam_x  = camera.x
        drag_cam_y  = camera.y
    end
end

function camera.mousereleased(sx, sy, button)
    if button == 3 then
        drag_active = false
    end
end

function camera.wheelmoved(dx, dy)
    if dy == 0 then
        return
    end
    local old_zoom = camera.zoom
    local new_zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, camera.zoom * (1.1 ^ dy)))
    local sw, sh   = love.graphics.getDimensions()
    local mx, my   = love.mouse.getPosition()
    camera.x    = camera.x + (mx - sw / 2) * (1 / old_zoom - 1 / new_zoom)
    camera.y    = camera.y + (my - sh / 2) * (1 / old_zoom - 1 / new_zoom)
    camera.zoom = new_zoom
end

function camera.screenToWorld(sx, sy)
    local sw, sh = love.graphics.getDimensions()
    return (sx - sw / 2) / camera.zoom + camera.x,
           (sy - sh / 2) / camera.zoom + camera.y
end

function camera.worldToScreen(wx, wy)
    local sw, sh = love.graphics.getDimensions()
    return (wx - camera.x) * camera.zoom + sw / 2,
           (wy - camera.y) * camera.zoom + sh / 2
end

function camera.applyTransform()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.translate(sw / 2, sh / 2)
    love.graphics.scale(camera.zoom, camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)
end

return camera
