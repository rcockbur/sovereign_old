-- simulation/buildings.lua
-- Building lifecycle: placement, validation, factory functions.

local world    = require("core.world")
local registry = require("core.registry")
local log      = require("core.log")

local buildings = {}

-- World-space offset from door tile to clearing tile, per orientation.
local CLEARING_OFFSETS = {
    S = {  0,  1 },
    N = {  0, -1 },
    E = {  1,  0 },
    W = { -1,  0 },
}

function buildings.isValidTile(tile)
    if tile.terrain ~= "grass" then
        return false
    end
    if tile.plant_type ~= nil then
        return false
    end
    if tile.ground_pile_id ~= nil then
        return false
    end
    if tile.building_id ~= nil then
        return false
    end
    if tile.is_clearing == true then
        return false
    end
    if tile.target_of_unit ~= nil then
        return false
    end
    if #tile.unit_ids > 0 then
        return false
    end
    return true
end

-- Returns rotated tile_map, new_width, new_height.
-- tile_map is row-major: index = y * w + x + 1 (0-indexed x,y).
local function rotateTileMap(tile_map, width, height, orientation)
    if orientation == "S" then
        return tile_map, width, height
    end

    local new_width, new_height
    if orientation == "N" then
        new_width, new_height = width, height
    else
        new_width, new_height = height, width
    end

    local result = {}
    for old_i = 1, width * height do
        local offset_x = (old_i - 1) % width
        local offset_y = math.floor((old_i - 1) / width)
        local new_x, new_y
        if orientation == "N" then
            new_x = width - 1 - offset_x
            new_y = height - 1 - offset_y
        elseif orientation == "E" then
            new_x = offset_y
            new_y = width - 1 - offset_x
        else
            new_x = height - 1 - offset_y
            new_y = offset_x
        end
        local new_i = new_y * new_width + new_x + 1
        result[new_i] = tile_map[old_i]
    end
    return result, new_width, new_height
end

-- Rotates a layout position (0-indexed) from canonical orientation to target orientation.
local function rotateLayoutPos(x, y, width, height, orientation)
    if orientation == "S" then
        return x, y
    end
    if orientation == "N" then
        return width - 1 - x, height - 1 - y
    end
    if orientation == "E" then
        return y, width - 1 - x
    end
    -- W
    return height - 1 - y, x
end

-- Places a tile-map building at (px, py) with the given orientation.
-- Returns the building entity on success, nil on failure.
function buildings.placeTilemapBuilding(building_type, px, py, orientation)
    local cfg = BuildingConfig[building_type]
    assert(cfg, "unknown building type: " .. building_type)
    assert(cfg.tile_map and #cfg.tile_map > 0,
        "building has no tile_map: " .. building_type)

    local rotated_map, rotated_width, rotated_height = rotateTileMap(cfg.tile_map, cfg.width, cfg.height, orientation)

    -- Find door position in the rotated map (0-indexed)
    local door_local_x, door_local_y = nil, nil
    for i, symbol in ipairs(rotated_map) do
        if symbol == "D" then
            door_local_x = (i - 1) % rotated_width
            door_local_y = math.floor((i - 1) / rotated_width)
            break
        end
    end

    -- Derive clearing tile from door position + orientation offset
    local clearing_tile = nil
    if door_local_x ~= nil then
        local offset = CLEARING_OFFSETS[orientation]
        local clearing_x = px + door_local_x + offset[1]
        local clearing_y = py + door_local_y + offset[2]
        if clearing_x >= 1 and clearing_x <= MAP_WIDTH and clearing_y >= 1 and clearing_y <= MAP_HEIGHT then
            clearing_tile = tileIndex(clearing_x, clearing_y)
        end
    end

    -- Validate footprint: no existing building_id or is_clearing
    for local_x = 0, rotated_width - 1 do
        for local_y = 0, rotated_height - 1 do
            local world_x = px + local_x
            local world_y = py + local_y
            if world_x < 1 or world_x > MAP_WIDTH or world_y < 1 or world_y > MAP_HEIGHT then
                return nil
            end
            local tile = world.tiles[tileIndex(world_x, world_y)]
            if tile.building_id ~= nil or tile.is_clearing == true then
                return nil
            end
        end
    end

    -- Validate clearing tile: must not be on another building's footprint or impassable terrain.
    -- is_clearing overlap is allowed — two buildings may share a clearing tile.
    if clearing_tile ~= nil then
        local clearing_tile_data = world.tiles[clearing_tile]
        if clearing_tile_data.building_id ~= nil then
            return nil
        end
        if clearing_tile_data.terrain == "rock" or clearing_tile_data.terrain == "water" then
            return nil
        end
    end

    -- Build entity
    local building = registry.createEntity(world.buildings, {
        type                = building_type,
        category            = cfg.category,
        x = px, y = py,
        width               = rotated_width,
        height              = rotated_height,
        orientation         = orientation,
        phase               = "complete",
        is_deleted          = false,
        clearing_tile       = clearing_tile,
        posted_activity_ids = {},
    })

    -- Stamp footprint tiles
    local role_for = { I = "indoor", D = "door", X = "impassable" }
    for i, symbol in ipairs(rotated_map) do
        local local_x = (i - 1) % rotated_width
        local local_y = math.floor((i - 1) / rotated_width)
        local tile = world.tiles[tileIndex(px + local_x, py + local_y)]
        tile.building_id   = building.id
        tile.building_role = role_for[symbol]
    end

    -- Stamp clearing tile
    if clearing_tile ~= nil then
        world.tiles[clearing_tile].is_clearing = true
    end

    log:info("WORLD", "Placed %s %d at (%d,%d) orientation %s",
        building_type, building.id, px, py, orientation)
    return building
end

function buildings.isValidPlacement(x1, y1, x2, y2)
    local left_x  = math.min(x1, x2)
    local right_x = math.max(x1, x2)
    local top_y   = math.min(y1, y2)
    local bottom_y = math.max(y1, y2)
    if right_x - left_x + 1 < 2 or bottom_y - top_y + 1 < 2 then
        return false
    end
    if left_x < 1 or right_x > MAP_WIDTH or top_y < 1 or bottom_y > MAP_HEIGHT then
        return false
    end
    for x = left_x, right_x do
        for y = top_y, bottom_y do
            if buildings.isValidTile(world.tiles[tileIndex(x, y)]) == false then
                return false
            end
        end
    end
    return true
end

function buildings.placeStockpile(x1, y1, x2, y2)
    local left_x  = math.min(x1, x2)
    local right_x = math.max(x1, x2)
    local top_y   = math.min(y1, y2)
    local bottom_y = math.max(y1, y2)

    local storage_tiles = {}
    for _ = 1, (right_x - left_x + 1) * (bottom_y - top_y + 1) do
        storage_tiles[#storage_tiles + 1] = { contents = {}, reserved_in = {}, reserved_out = {} }
    end

    local filters = {}
    for type_name, _ in pairs(ResourceConfig) do
        filters[type_name] = { mode = "accept", limit = nil }
    end

    local building = registry.createEntity(world.buildings, {
        type                = "stockpile",
        category            = "storage",
        x = left_x, y = top_y,
        width               = right_x - left_x + 1,
        height              = bottom_y - top_y + 1,
        orientation         = nil,
        phase               = "complete",
        is_deleted          = false,
        posted_activity_ids = {},
        storage = {
            container_type = "tile_inventory",
            count_category = "storage",
            tile_capacity  = STOCKPILE_TILE_CAPACITY,
            filters        = filters,
            tiles          = storage_tiles,
            reserved_in    = {},
            reserved_out   = {},
        },
    })

    for x = left_x, right_x do
        for y = top_y, bottom_y do
            world.tiles[tileIndex(x, y)].building_id = building.id
        end
    end

    log:info("WORLD", "Placed stockpile %d at (%d,%d) size %dx%d",
        building.id, left_x, top_y, right_x - left_x + 1, bottom_y - top_y + 1)
    return building
end

function buildings.sweepDeleted()
    local i = 1
    while i <= #world.buildings do
        local building = world.buildings[i]
        if building.is_deleted == true then
            -- Clear building_id and building_role on all footprint tiles
            for local_x = 0, building.width - 1 do
                for local_y = 0, building.height - 1 do
                    local tile = world.tiles[tileIndex(building.x + local_x, building.y + local_y)]
                    tile.building_id   = nil
                    tile.building_role = nil
                end
            end

            -- Conditionally clear is_clearing: only if no other live building claims this tile
            if building.clearing_tile ~= nil then
                local still_claimed = false
                for _, other in ipairs(world.buildings) do
                    if other.id ~= building.id and other.is_deleted == false
                            and other.clearing_tile == building.clearing_tile then
                        still_claimed = true
                        break
                    end
                end
                if still_claimed == false then
                    world.tiles[building.clearing_tile].is_clearing = false
                end
            end

            registry[building.id] = nil
            world.buildings[i] = world.buildings[#world.buildings]
            world.buildings[#world.buildings] = nil
        else
            i = i + 1
        end
    end
end

function buildings.tileWorldXY(building, i)
    local col = math.floor((i - 1) / building.height)
    local row = (i - 1) % building.height
    return building.x + col, building.y + row
end

function buildings.tileLocalIndex(building, wx, wy)
    local col = wx - building.x
    local row = wy - building.y
    return col * building.height + row + 1
end

return buildings
