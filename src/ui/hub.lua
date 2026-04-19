-- ui/hub.lua
-- Input routing hub. Owns interaction mode, selection, and the UI draw pass.
-- Left panel shows a curated debug view of the selected entity.

local world      = require("core.world")
local registry   = require("core.registry")
local camera     = require("ui.camera")
local units      = require("simulation.units")
local buildings  = require("simulation.buildings")
local activities = require("simulation.activities")
local left_panel = require("ui.left_panel")

local hub = {}

hub.selected      = nil
hub.selected_type = nil
hub.selected_tile_idx = nil   -- flat tile index used by renderer for the highlight

-- Interaction mode: "normal" | "placing" | "designating" | "cancelling"
hub.mode = "normal"
hub.mode_state = {
    type     = nil,     -- building type ("stockpile") or designation type ("chop")
    dragging = false,
    x1 = nil, y1 = nil,
    x2 = nil, y2 = nil,
}

local function screenToTile(sx, sy)
    local wx, wy = camera.screenToWorld(sx, sy)
    return math.floor(wx / TILE_SIZE) + 1, math.floor(wy / TILE_SIZE) + 1
end

function hub.enterMode(mode, mtype)
    hub.selected      = nil
    hub.selected_type = nil
    hub.selected_tile_idx = nil
    hub.mode = mode
    hub.mode_state.type     = mtype
    hub.mode_state.dragging = false
    hub.mode_state.x1 = nil
    hub.mode_state.y1 = nil
    local mx, my = love.mouse.getPosition()
    hub.mode_state.x2, hub.mode_state.y2 = screenToTile(mx, my)
end

function hub.exitMode()
    hub.mode = "normal"
    hub.mode_state.dragging = false
    hub.mode_state.x1 = nil
    hub.mode_state.y1 = nil
end

-- ─── Designation helpers ──────────────────────────────────────────────────────

local DESIGNATION_PLANT = { chop = "tree" }

local function designateRect(lx, rx, ty, by, dtype)
    local plant_type = DESIGNATION_PLANT[dtype]
    for x = lx, rx do
        for y = ty, by do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                local tile_idx = tileIndex(x, y)
                local tile = world.tiles[tile_idx]
                if tile.plant_type == plant_type and tile.plant_growth >= 3
                        and tile.designation == nil then
                    tile.designation = dtype
                    local act = activities.postActivity({
                        type          = "woodcutter",
                        x             = x,
                        y             = y,
                        resource_type = "wood",
                    })
                    tile.designation_activity_id = act.id
                end
            end
        end
    end
end

local function cancelRect(lx, rx, ty, by)
    for x = lx, rx do
        for y = ty, by do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                activities.cancelDesignation(tileIndex(x, y))
            end
        end
    end
end

-- ─── Update ───────────────────────────────────────────────────────────────────

function hub.update()
    if hub.mode == "normal" then return end
    local mx, my = love.mouse.getPosition()
    hub.mode_state.x2, hub.mode_state.y2 = screenToTile(mx, my)
end

-- ─── Input ────────────────────────────────────────────────────────────────────

function hub.mousepressed(x, y, button)
    local tx, ty = screenToTile(x, y)
    local ms = hub.mode_state

    if hub.mode == "placing" then
        if button == 1 then
            if ms.dragging == false then
                ms.dragging = true
                ms.x1, ms.y1 = tx, ty
            end
        elseif button == 2 then
            hub.exitMode()
        end
        return

    elseif hub.mode == "designating" then
        if button == 1 then
            if ms.dragging == false then
                ms.dragging = true
                ms.x1, ms.y1 = tx, ty
            end
        elseif button == 2 then
            hub.exitMode()
        end
        return

    elseif hub.mode == "cancelling" then
        if button == 1 then
            if ms.dragging == false then
                ms.dragging = true
                ms.x1, ms.y1 = tx, ty
            end
        elseif button == 2 then
            hub.exitMode()
        end
        return
    end

    -- Normal mode
    if button == 1 then
        if tx < 1 or tx > MAP_WIDTH or ty < 1 or ty > MAP_HEIGHT then
            hub.selected      = nil
            hub.selected_type = nil
            hub.selected_tile_idx = nil
            return
        end

        local tile_idx = tileIndex(tx, ty)
        local t        = world.tiles[tile_idx]

        for i = 1, #t.unit_ids do
            local u = registry[t.unit_ids[i]]
            if u.is_dead == false then
                hub.selected      = u
                hub.selected_type = "unit"
                hub.selected_tile_idx = tile_idx
                return
            end
        end

        if t.building_id ~= nil then
            hub.selected      = registry[t.building_id]
            hub.selected_type = "building"
            hub.selected_tile_idx = tile_idx
            return
        end

        if t.ground_pile_id ~= nil then
            hub.selected      = registry[t.ground_pile_id]
            hub.selected_type = "ground pile"
            hub.selected_tile_idx = tile_idx
            return
        end

        hub.selected      = t
        hub.selected_type = "tile"
        hub.selected_tile_idx = tile_idx

    elseif button == 2 then
        if hub.selected_type == "unit" then
            if tx >= 1 and tx <= MAP_WIDTH and ty >= 1 and ty <= MAP_HEIGHT then
                units.startMove(hub.selected, tileIndex(tx, ty))
            end
        else
            hub.selected      = nil
            hub.selected_type = nil
            hub.selected_tile_idx = nil
        end
    end
end

function hub.mousereleased(x, y, button)
    local ms = hub.mode_state
    if ms.dragging == false then return end
    if button ~= 1 then return end
    ms.dragging = false

    local lx = math.min(ms.x1, ms.x2)
    local rx = math.max(ms.x1, ms.x2)
    local ty = math.min(ms.y1, ms.y2)
    local by = math.max(ms.y1, ms.y2)

    if hub.mode == "placing" then
        if buildings.isValidPlacement(ms.x1, ms.y1, ms.x2, ms.y2) then
            buildings.placeStockpile(ms.x1, ms.y1, ms.x2, ms.y2)
        end
        local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        if shift == false then
            hub.exitMode()
        else
            ms.x1 = nil; ms.y1 = nil
        end

    elseif hub.mode == "designating" then
        designateRect(lx, rx, ty, by, ms.type)
        ms.x1 = nil; ms.y1 = nil   -- mode persists

    elseif hub.mode == "cancelling" then
        cancelRect(lx, rx, ty, by)
        ms.x1 = nil; ms.y1 = nil   -- mode persists
    end
end

-- Returns true if the key was consumed.
function hub.keypressed(key)
    if key == Keybinds.designate_chop then
        hub.enterMode("designating", "chop")
        return true
    end
    if key == Keybinds.cancel_designation then
        hub.enterMode("cancelling", nil)
        return true
    end
    if key == "b" then
        hub.enterMode("placing", "stockpile")
        return true
    end
    if hub.mode ~= "normal" then
        if key == "escape" then
            hub.exitMode()
            return true
        end
        return false
    end
    if key == "escape" and hub.selected ~= nil then
        hub.selected      = nil
        hub.selected_type = nil
        hub.selected_tile_idx = nil
        return true
    end
    return false
end

-- ─── World-space draw (inside camera transform) ───────────────────────────────

local COL_PLACE_OK  = { 0, 1, 0, 0.35 }
local COL_PLACE_BAD = { 1, 0, 0, 0.35 }
local COL_DESIG     = { 0.95, 0.65, 0.10, 0.45 }
local COL_CANCEL    = { 1, 0.20, 0.20, 0.45 }

function hub.drawWorld()
    local ms = hub.mode_state
    if ms.x1 == nil or ms.x2 == nil then return end

    local lx = math.min(ms.x1, ms.x2)
    local rx = math.max(ms.x1, ms.x2)
    local ty = math.min(ms.y1, ms.y2)
    local by = math.max(ms.y1, ms.y2)
    local ts = TILE_SIZE

    if hub.mode == "placing" then
        for x = lx, rx do
            for y = ty, by do
                if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                    if buildings.isValidTile(world.tiles[tileIndex(x, y)]) then
                        love.graphics.setColor(COL_PLACE_OK)
                    else
                        love.graphics.setColor(COL_PLACE_BAD)
                    end
                    love.graphics.rectangle("fill", (x - 1) * ts, (y - 1) * ts, ts, ts)
                end
            end
        end

    elseif hub.mode == "designating" then
        local plant_type = DESIGNATION_PLANT[ms.type]
        for x = lx, rx do
            for y = ty, by do
                if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                    local tile = world.tiles[tileIndex(x, y)]
                    if tile.plant_type == plant_type and tile.plant_growth >= 3
                            and tile.designation == nil then
                        love.graphics.setColor(COL_DESIG)
                        love.graphics.rectangle("fill", (x - 1) * ts, (y - 1) * ts, ts, ts)
                    end
                end
            end
        end

    elseif hub.mode == "cancelling" then
        for x = lx, rx do
            for y = ty, by do
                if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                    local tile = world.tiles[tileIndex(x, y)]
                    if tile.designation ~= nil then
                        love.graphics.setColor(COL_CANCEL)
                        love.graphics.rectangle("fill", (x - 1) * ts, (y - 1) * ts, ts, ts)
                    end
                end
            end
        end
    end
end

-- ─── Screen-space draw ────────────────────────────────────────────────────────

function hub.draw()
    left_panel.draw(hub.selected, hub.selected_type)
end

return hub
