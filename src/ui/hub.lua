-- ui/hub.lua
-- Input routing hub. Owns interaction mode, selection, and the UI draw pass.
-- Left panel shows a live tableToString debug dump of the selected entity.

local world      = require("core.world")
local registry   = require("core.registry")
local camera     = require("ui.camera")
local units      = require("simulation.units")
local left_panel = require("ui.left_panel")

local hub = {}

hub.mode          = "normal"
hub.selected      = nil
hub.selected_type = nil
hub.selected_tile = nil   -- flat tile index used by renderer for the highlight

function hub.mousepressed(x, y, button)
    if button == 1 then
        local wx, wy = camera.screenToWorld(x, y)
        local tx = math.floor(wx / TILE_SIZE) + 1
        local ty = math.floor(wy / TILE_SIZE) + 1

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

        hub.selected      = t
        hub.selected_type = "tile"
        hub.selected_tile = tile_idx

    elseif button == 2 then
        if hub.selected_type == "unit" then
            local wx, wy = camera.screenToWorld(x, y)
            local tx = math.floor(wx / TILE_SIZE) + 1
            local ty = math.floor(wy / TILE_SIZE) + 1
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

-- Returns true if the key was consumed (suppresses further handling by playing).
function hub.keypressed(key)
    if key == "escape" and hub.selected ~= nil then
        hub.selected      = nil
        hub.selected_type = nil
        hub.selected_tile = nil
        return true
    end
    return false
end

function hub.draw()
    left_panel.draw(hub.selected, hub.selected_type)
end

return hub
