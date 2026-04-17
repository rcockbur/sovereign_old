-- ui/hub.lua
-- Input routing hub. Owns interaction mode, selection, and the UI draw pass.
-- Left panel shows a live tableToString debug dump of the selected entity.

local world    = require("core.world")
local registry = require("core.registry")
local camera   = require("ui.camera")

local hub = {}

hub.mode          = "normal"
hub.selected      = nil
hub.selected_type = nil
hub.selected_tile = nil   -- flat tile index used by renderer for the highlight

local PANEL_W   = 280
local PANEL_PAD = 8
local MAX_ARRAY = 8
local MAX_DEPTH = 5

local COL_BG     = { 0.08, 0.09, 0.10, 0.94 }
local COL_BORDER = { 0.25, 0.27, 0.28, 1.00 }
local COL_HEADER = { 0.85, 0.80, 0.55, 1.00 }
local COL_TEXT   = { 0.78, 0.80, 0.78, 1.00 }

local function buildLines(val, depth, lines, indent)
    if depth > MAX_DEPTH then
        lines[#lines + 1] = indent .. "..."
        return
    end

    if type(val) ~= "table" then
        lines[#lines + 1] = indent .. tostring(val)
        return
    end

    local str_keys = {}
    for k in pairs(val) do
        if type(k) == "string" then
            str_keys[#str_keys + 1] = k
        end
    end
    table.sort(str_keys)

    for _, k in ipairs(str_keys) do
        local v = val[k]
        if type(v) == "table" then
            lines[#lines + 1] = indent .. k .. ":"
            buildLines(v, depth + 1, lines, indent .. "  ")
        else
            lines[#lines + 1] = indent .. k .. ": " .. tostring(v)
        end
    end

    local n = #val
    if n > 0 then
        local limit = math.min(n, MAX_ARRAY)
        for i = 1, limit do
            local v = val[i]
            if type(v) == "table" then
                lines[#lines + 1] = indent .. "[" .. i .. "]:"
                buildLines(v, depth + 1, lines, indent .. "  ")
            else
                lines[#lines + 1] = indent .. "[" .. i .. "]: " .. tostring(v)
            end
        end
        if n > MAX_ARRAY then
            lines[#lines + 1] = indent .. "(" .. (n - MAX_ARRAY) .. " more)"
        end
    end
end

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
        hub.selected      = nil
        hub.selected_type = nil
        hub.selected_tile = nil
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
    if hub.selected == nil then return end

    local sh     = love.graphics.getHeight()
    local fh     = love.graphics.getFont():getHeight()
    local line_h = fh + 2

    local lines = {}
    buildLines(hub.selected, 0, lines, "")

    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", 0, 0, PANEL_W, sh)
    love.graphics.setColor(COL_BORDER)
    love.graphics.line(PANEL_W, 0, PANEL_W, sh)

    love.graphics.setColor(COL_HEADER)
    love.graphics.print("[" .. hub.selected_type .. "]", PANEL_PAD, PANEL_PAD)

    local y_off     = PANEL_PAD + line_h + 4
    local max_lines = math.floor((sh - y_off - PANEL_PAD) / line_h)

    love.graphics.setColor(COL_TEXT)
    for i = 1, math.min(#lines, max_lines) do
        love.graphics.print(lines[i], PANEL_PAD, y_off + (i - 1) * line_h)
    end
end

return hub
