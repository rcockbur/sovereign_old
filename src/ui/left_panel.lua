-- ui/left_panel.lua
-- Left panel: live debug dump of the selected entity.

local left_panel = {}

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

    -- String keys (sorted, capped at MAX_ARRAY)
    local str_keys = {}
    for k in pairs(val) do
        if type(k) == "string" then str_keys[#str_keys + 1] = k end
    end
    table.sort(str_keys)
    local str_limit = math.min(#str_keys, MAX_ARRAY)
    for i = 1, str_limit do
        local k = str_keys[i]
        local v = val[k]
        if type(v) == "table" then
            lines[#lines + 1] = indent .. k .. ":"
            buildLines(v, depth + 1, lines, indent .. "  ")
        else
            lines[#lines + 1] = indent .. k .. ": " .. tostring(v)
        end
    end
    if #str_keys > MAX_ARRAY then
        lines[#lines + 1] = indent .. "(" .. (#str_keys - MAX_ARRAY) .. " more keys)"
    end

    -- Sequential integer keys [1..n]
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

    -- Sparse non-sequential integer keys (e.g. tileIndex-keyed tables)
    local int_keys = {}
    for k in pairs(val) do
        if type(k) == "number" and (k < 1 or k > n or k ~= math.floor(k)) then
            int_keys[#int_keys + 1] = k
        end
    end
    if #int_keys > 0 then
        table.sort(int_keys)
        local limit = math.min(#int_keys, MAX_ARRAY)
        for i = 1, limit do
            local k = int_keys[i]
            local v = val[k]
            if type(v) == "table" then
                lines[#lines + 1] = indent .. "[" .. k .. "]:"
                buildLines(v, depth + 1, lines, indent .. "  ")
            else
                lines[#lines + 1] = indent .. "[" .. k .. "]: " .. tostring(v)
            end
        end
        if #int_keys > MAX_ARRAY then
            lines[#lines + 1] = indent .. "(" .. (#int_keys - MAX_ARRAY) .. " more)"
        end
    end
end

function left_panel.draw(selected, selected_type)
    if selected == nil then return end

    local sh     = love.graphics.getHeight()
    local fh     = love.graphics.getFont():getHeight()
    local line_h = fh + 2

    local lines = {}
    buildLines(selected, 0, lines, "")

    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", 0, 0, PANEL_W, sh)
    love.graphics.setColor(COL_BORDER)
    love.graphics.line(PANEL_W, 0, PANEL_W, sh)

    love.graphics.setColor(COL_HEADER)
    love.graphics.print("[" .. selected_type .. "]", PANEL_PAD, PANEL_PAD)

    local y_off     = PANEL_PAD + line_h + 4
    local max_lines = math.floor((sh - y_off - PANEL_PAD) / line_h)

    love.graphics.setColor(COL_TEXT)
    for i = 1, math.min(#lines, max_lines) do
        love.graphics.print(lines[i], PANEL_PAD, y_off + (i - 1) * line_h)
    end
end

left_panel.width = PANEL_W

return left_panel
