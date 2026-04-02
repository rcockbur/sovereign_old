-- ui/camera.lua
-- Camera state: position (world-space tile coords) and zoom.
-- Provides coordinate conversion between screen pixels and world tiles.


local camera = {
    x    = 1.0,   -- world-space tile column the camera is centered on
    y    = 1.0,   -- world-space tile row the camera is centered on
    zoom = 1.0,   -- 1.0 = TILE_SIZE pixels per tile
}

local PAN_SPEED = 30  -- tiles per second

--- Pan the camera by (dx, dy) tiles. Clamps to map bounds.
function camera:pan(dx, dy)
    self.x = math.max(1, math.min(MAP_WIDTH,  self.x + dx))
    self.y = math.max(1, math.min(MAP_HEIGHT, self.y + dy))
end

--- Zoom toward/away from the screen center. delta > 0 = zoom in.
function camera:adjustZoom(delta)
    self.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, self.zoom + delta * 0.1))
end

--- Convert screen pixel coords to world tile coords (1-indexed integers).
--- Returns floats — caller rounds for tile lookups.
function camera:toWorld(screen_x, screen_y)
    local w, h   = love.graphics.getDimensions()
    local tile_px = TILE_SIZE * self.zoom
    local world_x = self.x + (screen_x - w / 2) / tile_px
    local world_y = self.y + (screen_y - h / 2) / tile_px
    return world_x, world_y
end

--- Convert world tile coords to screen pixel coords.
function camera:toScreen(world_x, world_y)
    local w, h   = love.graphics.getDimensions()
    local tile_px = TILE_SIZE * self.zoom
    local screen_x = (world_x - self.x) * tile_px + w / 2
    local screen_y = (world_y - self.y) * tile_px + h / 2
    return screen_x, screen_y
end

--- Apply the camera transform (call before drawing world content).
function camera:attach()
    love.graphics.push()
    local w, h   = love.graphics.getDimensions()
    local tile_px = TILE_SIZE * self.zoom
    love.graphics.translate(
        math.floor(w / 2 - (self.x - 1) * tile_px),
        math.floor(h / 2 - (self.y - 1) * tile_px)
    )
    love.graphics.scale(self.zoom, self.zoom)
end

--- Restore the transform (call after drawing world content).
function camera:detach()
    love.graphics.pop()
end

--- Update camera pan from held keys. Called each frame with dt.
function camera:update(dt, input_mod)
    local spd = PAN_SPEED * dt / self.zoom
    if input_mod:isAction("pan_left")  then self:pan(-spd, 0)   end
    if input_mod:isAction("pan_right") then self:pan( spd, 0)   end
    if input_mod:isAction("pan_up")    then self:pan(0,   -spd) end
    if input_mod:isAction("pan_down")  then self:pan(0,    spd) end
end

return camera
