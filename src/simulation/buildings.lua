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
local function rotateTileMap(tile_map, w, h, orientation)
    if orientation == "S" then
        return tile_map, w, h
    end

    local nw, nh
    if orientation == "N" then
        nw, nh = w, h
    else
        nw, nh = h, w
    end

    local result = {}
    for old_i = 1, w * h do
        local ox = (old_i - 1) % w
        local oy = math.floor((old_i - 1) / w)
        local nx, ny
        if orientation == "N" then
            nx = w - 1 - ox
            ny = h - 1 - oy
        elseif orientation == "E" then
            nx = oy
            ny = w - 1 - ox
        else
            nx = h - 1 - oy
            ny = ox
        end
        local new_i = ny * nw + nx + 1
        result[new_i] = tile_map[old_i]
    end
    return result, nw, nh
end

-- Rotates a layout position (0-indexed) from canonical orientation to target orientation.
local function rotateLayoutPos(x, y, w, h, orientation)
    if orientation == "S" then
        return x, y
    end
    if orientation == "N" then
        return w - 1 - x, h - 1 - y
    end
    if orientation == "E" then
        return y, w - 1 - x
    end
    -- W
    return h - 1 - y, x
end

-- Places a tile-map building at (px, py) with the given orientation.
-- Returns the building entity on success, nil on failure.
function buildings.placeTilemapBuilding(building_type, px, py, orientation)
    local cfg = BuildingConfig[building_type]
    assert(cfg, "unknown building type: " .. building_type)
    assert(cfg.tile_map and #cfg.tile_map > 0,
        "building has no tile_map: " .. building_type)

    local rotated_map, rw, rh = rotateTileMap(cfg.tile_map, cfg.width, cfg.height, orientation)

    -- Find door position in the rotated map (0-indexed)
    local door_lx, door_ly = nil, nil
    for i, symbol in ipairs(rotated_map) do
        if symbol == "D" then
            door_lx = (i - 1) % rw
            door_ly = math.floor((i - 1) / rw)
            break
        end
    end

    -- Derive clearing tile from door position + orientation offset
    local clearing_tile = nil
    if door_lx ~= nil then
        local offset = CLEARING_OFFSETS[orientation]
        local cx = px + door_lx + offset[1]
        local cy = py + door_ly + offset[2]
        if cx >= 1 and cx <= MAP_WIDTH and cy >= 1 and cy <= MAP_HEIGHT then
            clearing_tile = tileIndex(cx, cy)
        end
    end

    -- Validate footprint: no existing building_id or is_clearing
    for lx = 0, rw - 1 do
        for ly = 0, rh - 1 do
            local wx = px + lx
            local wy = py + ly
            if wx < 1 or wx > MAP_WIDTH or wy < 1 or wy > MAP_HEIGHT then
                return nil
            end
            local tile = world.tiles[tileIndex(wx, wy)]
            if tile.building_id ~= nil or tile.is_clearing == true then
                return nil
            end
        end
    end

    -- Validate clearing tile: must not be on another building's footprint or impassable terrain.
    -- is_clearing overlap is allowed — two buildings may share a clearing tile.
    if clearing_tile ~= nil then
        local ct = world.tiles[clearing_tile]
        if ct.building_id ~= nil then
            return nil
        end
        if ct.terrain == "rock" or ct.terrain == "water" then
            return nil
        end
    end

    -- Build entity
    local building = registry.createEntity(world.buildings, {
        type                = building_type,
        category            = cfg.category,
        x = px, y = py,
        width               = rw,
        height              = rh,
        orientation         = orientation,
        phase               = "complete",
        is_deleted          = false,
        clearing_tile       = clearing_tile,
        posted_activity_ids = {},
    })

    -- Stamp footprint tiles
    local role_for = { I = "indoor", D = "door", X = "impassable" }
    for i, symbol in ipairs(rotated_map) do
        local lx = (i - 1) % rw
        local ly = math.floor((i - 1) / rw)
        local tile = world.tiles[tileIndex(px + lx, py + ly)]
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
    local lx = math.min(x1, x2)
    local rx = math.max(x1, x2)
    local ty = math.min(y1, y2)
    local by = math.max(y1, y2)
    if rx - lx + 1 < 2 or by - ty + 1 < 2 then
        return false
    end
    if lx < 1 or rx > MAP_WIDTH or ty < 1 or by > MAP_HEIGHT then
        return false
    end
    for x = lx, rx do
        for y = ty, by do
            if buildings.isValidTile(world.tiles[tileIndex(x, y)]) == false then
                return false
            end
        end
    end
    return true
end

function buildings.placeStockpile(x1, y1, x2, y2)
    local lx = math.min(x1, x2)
    local rx = math.max(x1, x2)
    local ty = math.min(y1, y2)
    local by = math.max(y1, y2)

    local storage_tiles = {}
    for _ = 1, (rx - lx + 1) * (by - ty + 1) do
        storage_tiles[#storage_tiles + 1] = { contents = {}, reserved_in = {}, reserved_out = {} }
    end

    local filters = {}
    for type_name, _ in pairs(ResourceConfig) do
        filters[type_name] = { mode = "accept", limit = nil }
    end

    local building = registry.createEntity(world.buildings, {
        type                = "stockpile",
        category            = "storage",
        x = lx, y = ty,
        width               = rx - lx + 1,
        height              = by - ty + 1,
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

    for x = lx, rx do
        for y = ty, by do
            world.tiles[tileIndex(x, y)].building_id = building.id
        end
    end

    log:info("WORLD", "Placed stockpile %d at (%d,%d) size %dx%d",
        building.id, lx, ty, rx - lx + 1, by - ty + 1)
    return building
end

function buildings.sweepDeleted()
    local i = 1
    while i <= #world.buildings do
        local building = world.buildings[i]
        if building.is_deleted == true then
            -- Clear building_id and building_role on all footprint tiles
            for lx = 0, building.width - 1 do
                for ly = 0, building.height - 1 do
                    local tile = world.tiles[tileIndex(building.x + lx, building.y + ly)]
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
