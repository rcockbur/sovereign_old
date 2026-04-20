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

local function screenToTile(screen_x, screen_y)
    local world_x, world_y = camera.screenToWorld(screen_x, screen_y)
    return math.floor(world_x / TILE_SIZE) + 1, math.floor(world_y / TILE_SIZE) + 1
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
        local mouse_x, mouse_y = love.mouse.getPosition()
        hub.drag_x2, hub.drag_y2 = screenToTile(mouse_x, mouse_y)
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

local function designateRect(left_x, right_x, top_y, bottom_y, designation_type)
    local plant_type = DESIGNATION_PLANT[designation_type]
    local act_cfg    = DESIGNATION_ACTIVITY[designation_type]
    for x = left_x, right_x do
        for y = top_y, bottom_y do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                local tile_idx = tileIndex(x, y)
                local tile = world.tiles[tile_idx]
                if tile.plant_type == plant_type and tile.plant_growth >= 3
                        and tile.designation == nil then
                    tile.designation = designation_type
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

local function cancelRect(left_x, right_x, top_y, bottom_y)
    for x = left_x, right_x do
        for y = top_y, bottom_y do
            if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                activities.cancelDesignation(tileIndex(x, y))
            end
        end
    end
end

-- ─── Update ───────────────────────────────────────────────────────────────────

function hub.update()
    if hub.mode == "normal" then
        return
    end
    local mouse_x, mouse_y = love.mouse.getPosition()
    hub.drag_x2, hub.drag_y2 = screenToTile(mouse_x, mouse_y)
end

-- ─── Input ────────────────────────────────────────────────────────────────────

function hub.mousepressed(x, y, button)
    local tile_x, tile_y = screenToTile(x, y)

    if hub.mode == "placing" then
        if button == 1 then
            if hub.is_dragging == false then
                hub.is_dragging = true
                hub.drag_x1, hub.drag_y1 = tile_x, tile_y
            end
        elseif button == 2 then
            hub.setMode("normal")
        end
        return

    elseif hub.mode == "designating" then
        if button == 1 then
            if hub.is_dragging == false then
                hub.is_dragging = true
                hub.drag_x1, hub.drag_y1 = tile_x, tile_y
            end
        elseif button == 2 then
            hub.setMode("normal")
        end
        return

    elseif hub.mode == "cancelling" then
        if button == 1 then
            if hub.is_dragging == false then
                hub.is_dragging = true
                hub.drag_x1, hub.drag_y1 = tile_x, tile_y
            end
        elseif button == 2 then
            hub.setMode("normal")
        end
        return
    end

    -- Normal mode
    if button == 1 then
        if tile_x < 1 or tile_x > MAP_WIDTH or tile_y < 1 or tile_y > MAP_HEIGHT then
            hub.selected          = nil
            hub.selected_type     = nil
            hub.selected_tile_idx = nil
            return
        end

        local tile_idx = tileIndex(tile_x, tile_y)
        local tile     = world.tiles[tile_idx]

        for i = 1, #tile.unit_ids do
            local unit = registry[tile.unit_ids[i]]
            if unit.is_dead == false then
                hub.selected          = unit
                hub.selected_type     = "unit"
                hub.selected_tile_idx = tile_idx
                return
            end
        end

        if tile.building_id ~= nil then
            hub.selected          = registry[tile.building_id]
            hub.selected_type     = "building"
            hub.selected_tile_idx = tile_idx
            return
        end

        if tile.ground_pile_id ~= nil then
            hub.selected          = registry[tile.ground_pile_id]
            hub.selected_type     = "ground pile"
            hub.selected_tile_idx = tile_idx
            return
        end

        hub.selected          = tile
        hub.selected_type     = "tile"
        hub.selected_tile_idx = tile_idx

    elseif button == 2 then
        if hub.selected_type == "unit" then
            if tile_x >= 1 and tile_x <= MAP_WIDTH and tile_y >= 1 and tile_y <= MAP_HEIGHT then
                units.startMove(hub.selected, tileIndex(tile_x, tile_y))
            end
        else
            hub.selected          = nil
            hub.selected_type     = nil
            hub.selected_tile_idx = nil
        end
    end
end

function hub.mousereleased(x, y, button)
    if hub.is_dragging == false then
        return
    end
    if button ~= 1 then
        return
    end
    hub.is_dragging = false

    local left_x  = math.min(hub.drag_x1, hub.drag_x2)
    local right_x = math.max(hub.drag_x1, hub.drag_x2)
    local top_y   = math.min(hub.drag_y1, hub.drag_y2)
    local bottom_y = math.max(hub.drag_y1, hub.drag_y2)

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
        designateRect(left_x, right_x, top_y, bottom_y, ms.designation_type)
        hub.drag_x1 = nil
        hub.drag_y1 = nil   -- mode persists

    elseif hub.mode == "cancelling" then
        cancelRect(left_x, right_x, top_y, bottom_y)
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
        local mouse_x, mouse_y = love.mouse.getPosition()
        local tile_x, tile_y   = screenToTile(mouse_x, mouse_y)
        buildings.placeTilemapBuilding("cottage", tile_x, tile_y, "S")
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
    if hub.drag_x1 == nil or hub.drag_x2 == nil then
        return
    end

    local left_x  = math.min(hub.drag_x1, hub.drag_x2)
    local right_x = math.max(hub.drag_x1, hub.drag_x2)
    local top_y   = math.min(hub.drag_y1, hub.drag_y2)
    local bottom_y = math.max(hub.drag_y1, hub.drag_y2)
    local tile_size = TILE_SIZE

    if hub.mode == "placing" then
        for x = left_x, right_x do
            for y = top_y, bottom_y do
                if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                    if buildings.isValidTile(world.tiles[tileIndex(x, y)]) then
                        love.graphics.setColor(COL_PLACE_OK)
                    else
                        love.graphics.setColor(COL_PLACE_BAD)
                    end
                    love.graphics.rectangle("fill", (x - 1) * tile_size, (y - 1) * tile_size, tile_size, tile_size)
                end
            end
        end

    elseif hub.mode == "designating" then
        local ms         = hub.mode_state
        local plant_type = DESIGNATION_PLANT[ms.designation_type]
        for x = left_x, right_x do
            for y = top_y, bottom_y do
                if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                    local tile = world.tiles[tileIndex(x, y)]
                    if tile.plant_type == plant_type and tile.plant_growth >= 3
                            and tile.designation == nil then
                        love.graphics.setColor(COL_DESIG)
                        love.graphics.rectangle("fill", (x - 1) * tile_size, (y - 1) * tile_size, tile_size, tile_size)
                    end
                end
            end
        end

    elseif hub.mode == "cancelling" then
        for x = left_x, right_x do
            for y = top_y, bottom_y do
                if x >= 1 and x <= MAP_WIDTH and y >= 1 and y <= MAP_HEIGHT then
                    local tile = world.tiles[tileIndex(x, y)]
                    if tile.designation ~= nil then
                        love.graphics.setColor(COL_CANCEL)
                        love.graphics.rectangle("fill", (x - 1) * tile_size, (y - 1) * tile_size, tile_size, tile_size)
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
