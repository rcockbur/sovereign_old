-- ui/hub.lua
-- Input routing hub. Owns interaction mode, selection, and the UI draw pass.
-- Left panel shows a live tableToString debug dump of the selected entity.

local world      = require("core.world")
local registry   = require("core.registry")
local camera     = require("ui.camera")
local units      = require("simulation.units")
local buildings  = require("simulation.buildings")
local left_panel = require("ui.left_panel")

local hub = {}

hub.selected      = nil
hub.selected_type = nil
hub.selected_tile = nil   -- flat tile index used by renderer for the highlight

local placement = {
    active   = false,
    type     = nil,
    dragging = false,
    x1 = nil, y1 = nil,
    x2 = nil, y2 = nil,
}
hub.placement = placement

function hub.enterPlacement(btype)
    hub.selected      = nil
    hub.selected_type = nil
    hub.selected_tile = nil
    placement.active   = true
    placement.type     = btype
    placement.dragging = false
    placement.x1 = nil
    placement.y1 = nil
    local mx, my = love.mouse.getPosition()
    local wx, wy = camera.screenToWorld(mx, my)
    placement.x2 = math.floor(wx / TILE_SIZE) + 1
    placement.y2 = math.floor(wy / TILE_SIZE) + 1
end

function hub.exitPlacement()
    placement.active   = false
    placement.dragging = false
end

function hub.update()
    if placement.active == false then return end
    local mx, my = love.mouse.getPosition()
    local wx, wy = camera.screenToWorld(mx, my)
    placement.x2 = math.floor(wx / TILE_SIZE) + 1
    placement.y2 = math.floor(wy / TILE_SIZE) + 1
end

function hub.mousepressed(x, y, button)
    local wx, wy = camera.screenToWorld(x, y)
    local tx = math.floor(wx / TILE_SIZE) + 1
    local ty = math.floor(wy / TILE_SIZE) + 1

    if placement.active then
        if button == 1 then
            if placement.dragging == false then
                placement.dragging = true
                placement.x1 = tx
                placement.y1 = ty
            end
        elseif button == 2 then
            hub.exitPlacement()
        end
        return
    end

    if button == 1 then
        if tx < 1 or tx > MAP_WIDTH or ty < 1 or ty > MAP_HEIGHT then
            hub.selected      = nil
            hub.selected_type = nil
            hub.selected_tile = nil
            return
        end

        local tile_idx = tileIndex(tx, ty)
        local t        = world.tiles[tile_idx]

        for i = 1, #t.unit_ids do
            local u = registry[t.unit_ids[i]]
            if u.is_dead == false then
                hub.selected      = u
                hub.selected_type = "unit"
                hub.selected_tile = tile_idx
                return
            end
        end

        if t.building_id ~= nil then
            hub.selected      = registry[t.building_id]
            hub.selected_type = "building"
            hub.selected_tile = tile_idx
            return
        end

        hub.selected      = t
        hub.selected_type = "tile"
        hub.selected_tile = tile_idx

    elseif button == 2 then
        if hub.selected_type == "unit" then
            if tx >= 1 and tx <= MAP_WIDTH and ty >= 1 and ty <= MAP_HEIGHT then
                units.startMove(hub.selected, tileIndex(tx, ty))
            end
        else
            hub.selected      = nil
            hub.selected_type = nil
            hub.selected_tile = nil
        end
    end
end

function hub.mousereleased(x, y, button)
    if placement.active == false then return end
    if placement.dragging == false then return end
    if button ~= 1 then return end
    placement.dragging = false
    if buildings.isValidPlacement(placement.x1, placement.y1, placement.x2, placement.y2) then
        buildings.placeStockpile(placement.x1, placement.y1, placement.x2, placement.y2)
    end
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    if shift == false then
        hub.exitPlacement()
    else
        placement.x1 = nil
        placement.y1 = nil
    end
end

-- Returns true if the key was consumed (suppresses further handling by playing).
function hub.keypressed(key)
    if key == "b" then
        hub.enterPlacement("stockpile")
        return true
    end
    if placement.active then
        if key == "escape" then
            hub.exitPlacement()
            return true
        end
        return false
    end
    if key == "escape" and hub.selected ~= nil then
        hub.selected      = nil
        hub.selected_type = nil
        hub.selected_tile = nil
        return true
    end
    return false
end

function hub.drawWorld()
    if placement.active == false then return end
    if placement.x1 == nil or placement.x2 == nil then return end

    local lx = math.min(placement.x1, placement.x2)
    local rx = math.max(placement.x1, placement.x2)
    local ty = math.min(placement.y1, placement.y2)
    local by = math.max(placement.y1, placement.y2)
    local ts = TILE_SIZE

    for x = lx, rx do
        for y = ty, by do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                if buildings.isValidTile(world.tiles[tileIndex(x, y)]) then
                    love.graphics.setColor(0, 1, 0, 0.35)
                else
                    love.graphics.setColor(1, 0, 0, 0.35)
                end
                love.graphics.rectangle("fill", (x - 1) * ts, (y - 1) * ts, ts, ts)
            end
        end
    end
end

function hub.draw()
    left_panel.draw(hub.selected, hub.selected_type)
end

return hub
