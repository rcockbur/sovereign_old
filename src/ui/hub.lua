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
-- mode_state shapes:
--   "normal"      → nil
--   "cancelling"  → nil
--   "placing"     → { building_type, orientation }  (orientation nil for player-sized/solid)
--   "designating" → { designation_type }
hub.mode       = "normal"
hub.mode_state = nil

-- Drag operation state (separate from mode configuration)
hub.is_dragging = false
hub.drag_x1     = nil
hub.drag_y1     = nil
hub.drag_x2     = nil
hub.drag_y2     = nil

local function screenToTile(sx, sy)
    local wx, wy = camera.screenToWorld(sx, sy)
    return math.floor(wx / TILE_SIZE) + 1, math.floor(wy / TILE_SIZE) + 1
end

function hub.setMode(mode, state)
    hub.mode       = mode
    hub.mode_state = state
    hub.is_dragging = false
    hub.drag_x1     = nil
    hub.drag_y1     = nil
    if mode ~= "normal" then
        hub.selected          = nil
        hub.selected_type     = nil
        hub.selected_tile_idx = nil
        local mx, my = love.mouse.getPosition()
        hub.drag_x2, hub.drag_y2 = screenToTile(mx, my)
    else
        hub.drag_x2 = nil
        hub.drag_y2 = nil
    end
end

-- ─── Designation helpers ──────────────────────────────────────────────────────

local DESIGNATION_PLANT    = { chop = "tree", gather = "berry_bush" }
local DESIGNATION_ACTIVITY = {
    chop   = { activity_type = "woodcutter", resource_type = "wood" },
    gather = { activity_type = "gatherer",   resource_type = "berries" },
}

local function designateRect(lx, rx, ty, by, dtype)
    local plant_type = DESIGNATION_PLANT[dtype]
    local act_cfg    = DESIGNATION_ACTIVITY[dtype]
    for x = lx, rx do
        for y = ty, by do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                local tile_idx = tileIndex(x, y)
                local tile = world.tiles[tile_idx]
                if tile.plant_type == plant_type and tile.plant_growth >= 3
                        and tile.designation == nil then
                    tile.designation = dtype
                    local act = activities.postActivity({
                        type          = act_cfg.activity_type,
                        x             = x,
                        y             = y,
                        resource_type = act_cfg.resource_type,
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
    hub.drag_x2, hub.drag_y2 = screenToTile(mx, my)
end

-- ─── Input ────────────────────────────────────────────────────────────────────

function hub.mousepressed(x, y, button)
    local tx, ty = screenToTile(x, y)

    if hub.mode == "placing" then
        if button == 1 then
            if hub.is_dragging == false then
                hub.is_dragging = true
                hub.drag_x1, hub.drag_y1 = tx, ty
            end
        elseif button == 2 then
            hub.setMode("normal")
        end
        return

    elseif hub.mode == "designating" then
        if button == 1 then
            if hub.is_dragging == false then
                hub.is_dragging = true
                hub.drag_x1, hub.drag_y1 = tx, ty
            end
        elseif button == 2 then
            hub.setMode("normal")
        end
        return

    elseif hub.mode == "cancelling" then
        if button == 1 then
            if hub.is_dragging == false then
                hub.is_dragging = true
                hub.drag_x1, hub.drag_y1 = tx, ty
            end
        elseif button == 2 then
            hub.setMode("normal")
        end
        return
    end

    -- Normal mode
    if button == 1 then
        if tx < 1 or tx > MAP_WIDTH or ty < 1 or ty > MAP_HEIGHT then
            hub.selected          = nil
            hub.selected_type     = nil
            hub.selected_tile_idx = nil
            return
        end

        local tile_idx = tileIndex(tx, ty)
        local t        = world.tiles[tile_idx]

        for i = 1, #t.unit_ids do
            local u = registry[t.unit_ids[i]]
            if u.is_dead == false then
                hub.selected          = u
                hub.selected_type     = "unit"
                hub.selected_tile_idx = tile_idx
                return
            end
        end

        if t.building_id ~= nil then
            hub.selected          = registry[t.building_id]
            hub.selected_type     = "building"
            hub.selected_tile_idx = tile_idx
            return
        end

        if t.ground_pile_id ~= nil then
            hub.selected          = registry[t.ground_pile_id]
            hub.selected_type     = "ground pile"
            hub.selected_tile_idx = tile_idx
            return
        end

        hub.selected          = t
        hub.selected_type     = "tile"
        hub.selected_tile_idx = tile_idx

    elseif button == 2 then
        if hub.selected_type == "unit" then
            if tx >= 1 and tx <= MAP_WIDTH and ty >= 1 and ty <= MAP_HEIGHT then
                units.startMove(hub.selected, tileIndex(tx, ty))
            end
        else
            hub.selected          = nil
            hub.selected_type     = nil
            hub.selected_tile_idx = nil
        end
    end
end

function hub.mousereleased(x, y, button)
    if hub.is_dragging == false then return end
    if button ~= 1 then return end
    hub.is_dragging = false

    local lx = math.min(hub.drag_x1, hub.drag_x2)
    local rx = math.max(hub.drag_x1, hub.drag_x2)
    local ty = math.min(hub.drag_y1, hub.drag_y2)
    local by = math.max(hub.drag_y1, hub.drag_y2)

    if hub.mode == "placing" then
        if buildings.isValidPlacement(hub.drag_x1, hub.drag_y1, hub.drag_x2, hub.drag_y2) then
            buildings.placeStockpile(hub.drag_x1, hub.drag_y1, hub.drag_x2, hub.drag_y2)
        end
        local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        if shift == false then
            hub.setMode("normal")
        else
            hub.drag_x1 = nil
            hub.drag_y1 = nil
        end

    elseif hub.mode == "designating" then
        local ms = hub.mode_state
        designateRect(lx, rx, ty, by, ms.designation_type)
        hub.drag_x1 = nil
        hub.drag_y1 = nil   -- mode persists

    elseif hub.mode == "cancelling" then
        cancelRect(lx, rx, ty, by)
        hub.drag_x1 = nil
        hub.drag_y1 = nil   -- mode persists
    end
end

-- Returns true if the key was consumed.
function hub.keypressed(key)
    if key == Keybinds.designate_chop then
        hub.setMode("designating", { designation_type = "chop" })
        return true
    end
    if key == Keybinds.designate_gather then
        hub.setMode("designating", { designation_type = "gather" })
        return true
    end
    if key == Keybinds.cancel_designation then
        hub.setMode("cancelling")
        return true
    end
    if key == "b" then
        hub.setMode("placing", { building_type = "stockpile", orientation = nil })
        return true
    end
    if key == "f4" then
        local mx, my = love.mouse.getPosition()
        local tx, ty = screenToTile(mx, my)
        buildings.placeTilemapBuilding("cottage", tx, ty, "S")
        return true
    end
    if hub.mode ~= "normal" then
        if key == "escape" then
            hub.setMode("normal")
            return true
        end
        return false
    end
    if key == "escape" and hub.selected ~= nil then
        hub.selected          = nil
        hub.selected_type     = nil
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
    if hub.drag_x1 == nil or hub.drag_x2 == nil then return end

    local lx = math.min(hub.drag_x1, hub.drag_x2)
    local rx = math.max(hub.drag_x1, hub.drag_x2)
    local ty = math.min(hub.drag_y1, hub.drag_y2)
    local by = math.max(hub.drag_y1, hub.drag_y2)
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
        local ms = hub.mode_state
        local plant_type = DESIGNATION_PLANT[ms.designation_type]
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
