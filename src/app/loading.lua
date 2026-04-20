-- app/loading.lua
-- Transient startup state. Initialises logging, validates config, then switches to main_menu.

local gamestate = require("app.gamestate")
local main_menu = require("app.main_menu")
local log       = require("core.log")

local loading = {}

local validateResourceConfig
local validateRecipeConfig
local validateActivityTypeConfig
local validateMerchantConfig
local validateHousingBinConfig
local validateBuildingConfig
local validateTileMap
local reachableFromDoor
local getTile

-- Skills defined on every unit (must match TABLES.md unit data structure).
local UNIT_SKILL_KEYS = {
    smithing = true, smelting = true, tailoring = true,
    baking = true, brewing = true, teaching = true, research = true,
    medicine = true, priesthood = true, barkeeping = true, trading = true,
}

function loading.enter()
    log:init()
    validateResourceConfig()
    validateRecipeConfig()
    validateActivityTypeConfig()
    validateMerchantConfig()
    validateHousingBinConfig()
    validateBuildingConfig()
    if ARGS_AUTO_NEWGAME then
        gamestate:switch(require("app.generating"))
    else
        gamestate:switch(main_menu)
    end
end

function validateResourceConfig()
    for res_type, cfg in pairs(ResourceConfig) do
        if cfg.is_stackable == false then
            assert(cfg.max_durability,
                "ResourceConfig." .. res_type .. ": is_stackable=false requires max_durability")
        end
        if cfg.nutrition then
            assert(cfg.is_stackable == true,
                "ResourceConfig." .. res_type .. ": nutrition requires is_stackable=true")
        end
        if cfg.tool_bonus then
            assert(cfg.is_stackable == false,
                "ResourceConfig." .. res_type .. ": tool_bonus requires is_stackable=false")
        end
    end
end

function validateRecipeConfig()
    for recipe_name, recipe in pairs(RecipeConfig) do
        for res_type in pairs(recipe.input) do
            assert(ResourceConfig[res_type],
                "RecipeConfig." .. recipe_name .. ": input '" .. res_type .. "' not in ResourceConfig")
        end
        for res_type in pairs(recipe.output) do
            assert(ResourceConfig[res_type],
                "RecipeConfig." .. recipe_name .. ": output '" .. res_type .. "' not in ResourceConfig")
        end
    end
end

function validateActivityTypeConfig()
    for activity_name, cfg in pairs(ActivityTypeConfig) do
        if cfg.skill then
            assert(UNIT_SKILL_KEYS[cfg.skill],
                "ActivityTypeConfig." .. activity_name
                .. ": skill '" .. cfg.skill .. "' not in unit skills table")
        end
    end
end

function validateMerchantConfig()
    for res_type in pairs(MerchantConfig.bin_threshold) do
        assert(ResourceConfig[res_type],
            "MerchantConfig.bin_threshold: '" .. res_type .. "' not in ResourceConfig")
    end
end

function validateHousingBinConfig()
    for i, entry in ipairs(HousingBinConfig) do
        assert(ResourceConfig[entry.type],
            "HousingBinConfig[" .. i .. "]: type '" .. tostring(entry.type) .. "' not in ResourceConfig")
    end
end

function validateBuildingConfig()
    for building_type, cfg in pairs(BuildingConfig) do
        if cfg.activity_type then
            assert(ActivityTypeConfig[cfg.activity_type],
                "BuildingConfig." .. building_type
                .. ": activity_type '" .. cfg.activity_type .. "' not in ActivityTypeConfig")
        end

        if cfg.category == "processing" then
            assert(cfg.max_workers == 1,
                "BuildingConfig." .. building_type
                .. ": processing building must have max_workers == 1 (is " .. tostring(cfg.max_workers) .. ")")
        end

        if cfg.category == "processing" and cfg.input_bins and cfg.recipes then
            local recipe_inputs = {}
            for _, recipe_name in ipairs(cfg.recipes) do
                local recipe = RecipeConfig[recipe_name]
                assert(recipe,
                    "BuildingConfig." .. building_type
                    .. ": recipes entry '" .. recipe_name .. "' not in RecipeConfig")
                for res_type in pairs(recipe.input) do
                    recipe_inputs[res_type] = true
                end
            end
            for _, bin in ipairs(cfg.input_bins) do
                assert(recipe_inputs[bin.type],
                    "BuildingConfig." .. building_type
                    .. ": input_bin type '" .. bin.type .. "' not found in recipe inputs")
            end
        end

        validateTileMap(building_type, cfg)
    end
end

function validateTileMap(building_type, cfg)
    if cfg.tile_map == nil or #cfg.tile_map == 0 then
        return
    end

    local width  = cfg.width
    local height = cfg.height
    assert(width and height,
        "BuildingConfig." .. building_type .. ": has tile_map but missing width or height")
    assert(#cfg.tile_map == width * height,
        "BuildingConfig." .. building_type .. ": tile_map length " .. #cfg.tile_map
        .. " does not match width*height=" .. (width * height))

    local d_count = 0
    for _, symbol in ipairs(cfg.tile_map) do
        if symbol == "D" then
            d_count = d_count + 1
        end
    end

    if d_count == 0 then
        -- Solid building: all tiles must be X, layout must be empty
        assert(cfg.layout and next(cfg.layout) == nil,
            "BuildingConfig." .. building_type .. ": solid tile_map (no D) requires empty layout table")
        for i, symbol in ipairs(cfg.tile_map) do
            assert(symbol == "X",
                "BuildingConfig." .. building_type
                .. ": solid tile_map must contain only X tiles (index " .. i .. " is '" .. symbol .. "')")
        end
        return
    end

    assert(d_count == 1,
        "BuildingConfig." .. building_type
        .. ": tile_map must have exactly 1 D tile (found " .. d_count .. ")")

    if cfg.layout then
        for field, positions in pairs(cfg.layout) do
            if type(positions) == "table" then
                for _, pos in ipairs(positions) do
                    if type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
                        local symbol = getTile(cfg.tile_map, width, pos.x, pos.y)
                        assert(symbol == "I" or symbol == "D",
                            "BuildingConfig." .. building_type .. ": layout." .. field
                            .. " position (" .. pos.x .. "," .. pos.y .. ") is on '"
                            .. tostring(symbol) .. "' (must be I or D)")
                    end
                end
            end
        end
    end

    local reachable = reachableFromDoor(cfg.tile_map, width, height)
    for i, symbol in ipairs(cfg.tile_map) do
        if symbol == "I" or symbol == "D" then
            local tile_x = (i - 1) % width
            local tile_y = math.floor((i - 1) / width)
            assert(reachable[tile_y * width + tile_x],
                "BuildingConfig." .. building_type .. ": tile '" .. symbol
                .. "' at (" .. tile_x .. "," .. tile_y .. ") is not reachable from the D tile")
        end
    end

    -- D must be on the perimeter (skip for placement-constrained buildings — see WORLD.md)
    if cfg.placement == nil then
        for i, symbol in ipairs(cfg.tile_map) do
            if symbol == "D" then
                local tile_x = (i - 1) % width
                local tile_y = math.floor((i - 1) / width)
                local is_perimeter = (tile_x == 0 or tile_x == width - 1 or tile_y == 0 or tile_y == height - 1)
                assert(is_perimeter,
                    "BuildingConfig." .. building_type
                    .. ": D tile at (" .. tile_x .. "," .. tile_y .. ") must be on the perimeter")
            end
        end
    end
end

function reachableFromDoor(tile_map, width, height)
    local door_x, door_y = nil, nil
    for i, symbol in ipairs(tile_map) do
        if symbol == "D" then
            door_x = (i - 1) % width
            door_y = math.floor((i - 1) / width)
            break
        end
    end
    if door_x == nil then
        return {}
    end

    local visited  = {}
    local queue    = { { door_x, door_y } }
    visited[door_y * width + door_x] = true
    local queue_head = 1
    while queue_head <= #queue do
        local current_x = queue[queue_head][1]
        local current_y = queue[queue_head][2]
        queue_head = queue_head + 1
        local neighbor_entries = {
            { current_x - 1, current_y },
            { current_x + 1, current_y },
            { current_x, current_y - 1 },
            { current_x, current_y + 1 },
        }
        for _, neighbor_entry in ipairs(neighbor_entries) do
            local neighbor_x = neighbor_entry[1]
            local neighbor_y = neighbor_entry[2]
            if neighbor_x >= 0 and neighbor_x < width and neighbor_y >= 0 and neighbor_y < height then
                local key = neighbor_y * width + neighbor_x
                if visited[key] == nil then
                    local neighbor_symbol = getTile(tile_map, width, neighbor_x, neighbor_y)
                    if neighbor_symbol == "I" or neighbor_symbol == "D" then
                        visited[key] = true
                        queue[#queue + 1] = { neighbor_x, neighbor_y }
                    end
                end
            end
        end
    end
    return visited
end

function getTile(tile_map, width, x, y)
    return tile_map[y * width + x + 1]
end

return loading
