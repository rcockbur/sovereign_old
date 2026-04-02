-- ui/renderer.lua
-- Placeholder renderer. Rectangles and colors — no sprites yet.
-- Terrain, plants, buildings, and units are all colored rectangles.
-- Fog of war: black = unexplored, dimmed = explored-not-visible, full = visible.
-- Camera transform is applied by the caller (camera:attach / camera:detach).


-- ---------------------------------------------------------------------------
-- Color palette
-- ---------------------------------------------------------------------------

local TERRAIN_COLOR = {
    grass = { 0.35, 0.55, 0.25 },
    dirt  = { 0.55, 0.42, 0.28 },
    rock  = { 0.50, 0.50, 0.50 },
    water = { 0.20, 0.40, 0.75 },
}

local PLANT_COLOR = {
    tree       = { 0.10, 0.35, 0.10 },
    herb       = { 0.50, 0.80, 0.30 },
    berry_bush = { 0.60, 0.20, 0.40 },
}

local TIER_COLOR = {
    [Tier.SERF]    = { 0.80, 0.80, 0.80 },
    [Tier.FREEMAN] = { 0.90, 0.75, 0.30 },
    [Tier.GENTRY]  = { 0.90, 0.30, 0.30 },
}

local BUILDING_COLOR     = { 0.70, 0.60, 0.45 }
local BUILDING_OUTLINE   = { 0.40, 0.30, 0.20 }
local BLUEPRINT_COLOR    = { 0.70, 0.60, 0.45, 0.40 }

local FOG_UNEXPLORED     = { 0,    0,    0,    1    }
local FOG_DIM            = { 0,    0,    0,    0.55 }

local GRID_COLOR         = { 0,    0,    0,    0.18 }

-- ---------------------------------------------------------------------------
-- Renderer module
-- ---------------------------------------------------------------------------

local renderer = {}

--- Draw the full world: tiles, plants, buildings, units, then fog of war.
--- world_mod, units_mod are the live module references.
function renderer:drawWorld(world_mod, units_mod)
    local tiles    = world_mod.tiles
    local tile_px  = TILE_SIZE   -- camera:attach() handles zoom scaling

    -- Determine which tile range is on screen (in unscaled tile coords).
    -- We draw everything — clipping happens in Love2D scissor. For now draw all.
    -- (Phase 11: add visible-range culling for performance.)

    -- -----------------------------------------------------------------------
    -- Pass 1: Terrain and plants
    -- -----------------------------------------------------------------------
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local idx  = world_mod.tileIndex(x, y)
            local tile = tiles[idx]
            local px   = (x - 1) * tile_px
            local py   = (y - 1) * tile_px

            -- Base terrain
            local tc = TERRAIN_COLOR[tile.terrain] or TERRAIN_COLOR.grass
            love.graphics.setColor(tc)
            love.graphics.rectangle("fill", px, py, tile_px, tile_px)

            -- Plant overlay (growth-dependent size)
            if tile.plant_growth > 0 and tile.plant_type ~= nil then
                local pc      = PLANT_COLOR[tile.plant_type]
                local ratio   = tile.plant_growth / 3   -- 0.33 / 0.67 / 1.0
                local margin  = math.floor(tile_px * (1 - ratio) * 0.5)
                local size    = tile_px - margin * 2
                if pc then
                    love.graphics.setColor(pc)
                    love.graphics.rectangle("fill",
                        px + margin, py + margin, size, size)
                end
            end
        end
    end

    -- -----------------------------------------------------------------------
    -- Pass 2: Buildings
    -- -----------------------------------------------------------------------
    for i = 1, #world_mod.buildings do
        local b  = world_mod.buildings[i]
        local px = (b.x - 1) * tile_px
        local py = (b.y - 1) * tile_px
        local bw = b.width  * tile_px
        local bh = b.height * tile_px

        if b.is_built then
            love.graphics.setColor(BUILDING_COLOR)
            love.graphics.rectangle("fill", px, py, bw, bh)
            love.graphics.setColor(BUILDING_OUTLINE)
            love.graphics.rectangle("line", px, py, bw, bh)
        else
            love.graphics.setColor(BLUEPRINT_COLOR)
            love.graphics.rectangle("fill", px, py, bw, bh)
            love.graphics.setColor(BUILDING_OUTLINE)
            love.graphics.rectangle("line", px, py, bw, bh)
        end
    end

    -- -----------------------------------------------------------------------
    -- Pass 3: Units
    -- -----------------------------------------------------------------------
    local unit_size   = math.max(4, tile_px - 6)
    local unit_offset = math.floor((tile_px - unit_size) / 2)

    for i = 1, #units_mod.all do
        local unit = units_mod.all[i]
        if unit.is_dead == false then
            local px = (unit.x - 1) * tile_px + unit_offset
            local py = (unit.y - 1) * tile_px + unit_offset
            local uc = TIER_COLOR[unit.tier] or TIER_COLOR[Tier.SERF]
            love.graphics.setColor(uc)
            love.graphics.rectangle("fill", px, py, unit_size, unit_size)
        end
    end

    -- -----------------------------------------------------------------------
    -- Pass 4: Grid lines
    -- Draw MAP_HEIGHT+1 horizontals and MAP_WIDTH+1 verticals — 602 line calls
    -- total, far cheaper than per-tile rectangle outlines.
    -- -----------------------------------------------------------------------
    love.graphics.setColor(GRID_COLOR)
    love.graphics.setLineWidth(1)
    local map_px_w = MAP_WIDTH  * tile_px
    local map_px_h = MAP_HEIGHT * tile_px
    for x = 0, MAP_WIDTH do
        local lx = x * tile_px
        love.graphics.line(lx, 0, lx, map_px_h)
    end
    for y = 0, MAP_HEIGHT do
        local ly = y * tile_px
        love.graphics.line(0, ly, map_px_w, ly)
    end

    -- -----------------------------------------------------------------------
    -- Pass 5: Fog of war (disabled until shadowcasting is implemented)
    -- -----------------------------------------------------------------------
    -- for x = 1, MAP_WIDTH do
    --     for y = 1, MAP_HEIGHT do
    --         local idx  = world_mod.tileIndex(x, y)
    --         local tile = tiles[idx]
    --         local px   = (x - 1) * tile_px
    --         local py   = (y - 1) * tile_px
    --
    --         if tile.is_explored == false then
    --             love.graphics.setColor(FOG_UNEXPLORED)
    --             love.graphics.rectangle("fill", px, py, tile_px, tile_px)
    --         elseif tile.visible_count == 0 then
    --             love.graphics.setColor(FOG_DIM)
    --             love.graphics.rectangle("fill", px, py, tile_px, tile_px)
    --         end
    --     end
    -- end

    love.graphics.setColor(1, 1, 1, 1)
end

return renderer
