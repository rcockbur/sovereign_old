-- simulation/buildings.lua
-- Building lifecycle: placement, validation, factory functions.

local world    = require("core.world")
local registry = require("core.registry")
local log      = require("core.log")

local buildings = {}

function buildings.isValidTile(tile)
    if tile.terrain ~= "grass" then return false end
    if tile.plant_type ~= nil then return false end
    if tile.ground_pile_id ~= nil then return false end
    if tile.building_id ~= nil then return false end
    if tile.target_of_unit ~= nil then return false end
    if #tile.unit_ids > 0 then return false end
    return true
end

function buildings.isValidPlacement(x1, y1, x2, y2)
    local lx = math.min(x1, x2)
    local rx = math.max(x1, x2)
    local ty = math.min(y1, y2)
    local by = math.max(y1, y2)
    if rx - lx + 1 < 2 or by - ty + 1 < 2 then return false end
    if lx < 1 or rx > MAP_WIDTH or ty < 1 or by > MAP_HEIGHT then return false end
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
    for x = lx, rx do
        for y = ty, by do
            storage_tiles[tileIndex(x, y)] = { contents = {}, reserved_in = 0, reserved_out = 0 }
        end
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
            tile_capacity  = STOCKPILE_TILE_CAPACITY,
            filters        = {},
            tiles          = storage_tiles,
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

return buildings
