-- ui/left_panel.lua
-- Left panel: live debug dump of the selected entity.
-- Units use a curated layout; tiles and buildings use the generic recursive dump.

local registry = require("core.registry")

local left_panel = {}

local PANEL_WIDTH = 280
local PANEL_PAD   = 8
local MAX_ARRAY   = 8
local MAX_DEPTH   = 5

local COL_BG      = { 0.08, 0.09, 0.10, 0.94 }
local COL_BORDER  = { 0.25, 0.27, 0.28, 1.00 }
local COL_HEADER  = { 0.85, 0.80, 0.55, 1.00 }
local COL_TEXT    = { 0.78, 0.80, 0.78, 1.00 }
local COL_SECTION = { 0.55, 0.65, 0.75, 1.00 }

-- ─── Generic recursive dump (tiles, buildings) ────────────────────────────────

local function buildLines(value, depth, lines, indent)
    if depth > MAX_DEPTH then
        lines[#lines + 1] = { text = indent .. "...", color = COL_TEXT }
        return
    end

    if type(value) ~= "table" then
        lines[#lines + 1] = { text = indent .. tostring(value), color = COL_TEXT }
        return
    end

    local str_keys = {}
    for key in pairs(value) do
        if type(key) == "string" then str_keys[#str_keys + 1] = key end
    end
    table.sort(str_keys)
    local str_limit = math.min(#str_keys, MAX_ARRAY)
    for i = 1, str_limit do
        local key = str_keys[i]
        local val = value[key]
        if type(val) == "table" then
            lines[#lines + 1] = { text = indent .. key .. ":", color = COL_TEXT }
            buildLines(val, depth + 1, lines, indent .. "  ")
        else
            lines[#lines + 1] = { text = indent .. key .. ": " .. tostring(val), color = COL_TEXT }
        end
    end
    if #str_keys > MAX_ARRAY then
        lines[#lines + 1] = { text = indent .. "(" .. (#str_keys - MAX_ARRAY) .. " more keys)", color = COL_TEXT }
    end

    local array_count = #value
    if array_count > 0 then
        local limit = math.min(array_count, MAX_ARRAY)
        for i = 1, limit do
            local val = value[i]
            if type(val) == "table" then
                lines[#lines + 1] = { text = indent .. "[" .. i .. "]:", color = COL_TEXT }
                buildLines(val, depth + 1, lines, indent .. "  ")
            else
                lines[#lines + 1] = { text = indent .. "[" .. i .. "]: " .. tostring(val), color = COL_TEXT }
            end
        end
        if array_count > MAX_ARRAY then
            lines[#lines + 1] = { text = indent .. "(" .. (array_count - MAX_ARRAY) .. " more)", color = COL_TEXT }
        end
    end

    local int_keys = {}
    for key in pairs(value) do
        if type(key) == "number" and (key < 1 or key > array_count or key ~= math.floor(key)) then
            int_keys[#int_keys + 1] = key
        end
    end
    if #int_keys > 0 then
        table.sort(int_keys)
        local limit = math.min(#int_keys, MAX_ARRAY)
        for i = 1, limit do
            local key = int_keys[i]
            local val = value[key]
            if type(val) == "table" then
                lines[#lines + 1] = { text = indent .. "[" .. key .. "]:", color = COL_TEXT }
                buildLines(val, depth + 1, lines, indent .. "  ")
            else
                lines[#lines + 1] = { text = indent .. "[" .. key .. "]: " .. tostring(val), color = COL_TEXT }
            end
        end
        if #int_keys > MAX_ARRAY then
            lines[#lines + 1] = { text = indent .. "(" .. (#int_keys - MAX_ARRAY) .. " more)", color = COL_TEXT }
        end
    end
end

-- ─── Curated unit display ─────────────────────────────────────────────────────

local function sec(lines, label)
    lines[#lines + 1] = { text = label, color = COL_SECTION }
end

local function row(lines, text)
    lines[#lines + 1] = { text = text, color = COL_TEXT }
end

local function displayUnitInfo(unit, lines)
    -- Identity
    row(lines, unit.name .. " " .. unit.surname .. "  #" .. unit.id)
    row(lines, unit.class .. "  age " .. unit.age .. "  " .. unit.gender)
    row(lines, "")

    -- Position and movement
    sec(lines, "position")
    row(lines, "  x: " .. unit.x .. "  y: " .. unit.y)
    if unit.target_tile ~= nil then
        local tile_x, tile_y = tileXY(unit.target_tile)
        row(lines, "  target: " .. tile_x .. ", " .. tile_y)
    end
    row(lines, "")

    -- Action
    sec(lines, "action")
    local action = unit.current_action
    if action.type == "work" then
        row(lines, "  work  " .. action.progress .. " / " .. action.work_ticks)
    elseif action.type == "travel" then
        local step  = unit.path and unit.path.current or "?"
        local total = unit.path and #unit.path.tiles or "?"
        row(lines, "  travel  step " .. tostring(step) .. " / " .. tostring(total))
    else
        row(lines, "  " .. action.type)
    end

    -- Activity
    if unit.activity_id ~= nil then
        local activity = registry[unit.activity_id]
        if activity ~= nil then
            local loc = "(" .. activity.x .. "," .. activity.y .. ")"
            row(lines, "  activity: " .. activity.type .. " #" .. activity.id .. " " .. loc)
        else
            row(lines, "  activity: #" .. unit.activity_id .. " (stale)")
        end
    else
        row(lines, "  activity: none")
    end
    if unit.secondary_haul_activity_id ~= nil then
        local haul_activity = registry[unit.secondary_haul_activity_id]
        if haul_activity ~= nil then
            row(lines, "  haul: " .. haul_activity.type .. " #" .. haul_activity.id)
        else
            row(lines, "  haul: #" .. unit.secondary_haul_activity_id .. " (stale)")
        end
    end
    row(lines, "")

    -- Needs
    sec(lines, "needs")
    row(lines, "  satiation:  " .. math.floor(unit.needs.satiation))
    row(lines, "  energy:     " .. math.floor(unit.needs.energy))
    row(lines, "  recreation: " .. math.floor(unit.needs.recreation))
    row(lines, "")

    -- Vitals
    sec(lines, "vitals")
    row(lines, "  health: " .. math.floor(unit.health)
        .. "  mood: " .. math.floor(unit.mood))
    if unit.soft_interrupt_pending == true then
        row(lines, "  soft interrupt pending")
    end
    row(lines, "")

    -- Carrying
    sec(lines, "carrying")
    if #unit.carrying == 0 then
        row(lines, "  (empty)")
    else
        for i = 1, #unit.carrying do
            local entity = registry[unit.carrying[i]]
            if entity ~= nil then
                if entity.amount ~= nil then
                    row(lines, "  " .. entity.type .. " x" .. entity.amount)
                else
                    row(lines, "  " .. entity.type .. " (item)")
                end
            end
        end
    end
    row(lines, "")

    -- Work day
    sec(lines, "work day")
    local ticks_remaining = unit.work_ticks_remaining
    local work_hours      = math.floor(ticks_remaining / TICKS_PER_HOUR)
    local work_minutes    = math.floor((ticks_remaining % TICKS_PER_HOUR) / TICKS_PER_MINUTE)
    row(lines, "  remaining: " .. work_hours .. "h " .. work_minutes .. "m")
    row(lines, "  done: " .. tostring(unit.is_done_working))
    row(lines, "")

    -- Home / draft
    sec(lines, "housing")
    if unit.home_id ~= nil then
        row(lines, "  home: #" .. unit.home_id
            .. "  bed: " .. tostring(unit.bed_index))
    else
        row(lines, "  home: none")
    end
    if unit.is_drafted then
        row(lines, "  DRAFTED")
    end
end

local function displayBuildingInfo(building, lines)
    -- Identity
    row(lines, "ID: " .. building.id)
    row(lines, building.type)
    row(lines, "")

    -- Position and movement
    row(lines, "position: "..building.x..", "..building.y)
    row(lines, "size: "..building.width..", "..building.height)
    row(lines, "")

    row(lines, "phase: "..building.phase)
    row(lines, "posted_activity_ids: "..table.concat(building.posted_activity_ids, ", "))
    row(lines, "")

    if building.storage ~= nil then
        sec(lines, "storage")
        local res_in_parts, res_out_parts = {}, {}
        for rtype, amt in pairs(building.storage.reserved_in) do
            res_in_parts[#res_in_parts + 1] = rtype .. "=" .. amt
        end
        for rtype, amt in pairs(building.storage.reserved_out) do
            res_out_parts[#res_out_parts + 1] = rtype .. "=" .. amt
        end
        row(lines, "  reserved_in:  " .. (#res_in_parts  > 0 and table.concat(res_in_parts,  " ") or "{}"))
        row(lines, "  reserved_out: " .. (#res_out_parts > 0 and table.concat(res_out_parts, " ") or "{}"))
        for tile_index, tile_entry in ipairs(building.storage.tiles) do
            for _, resource_id in ipairs(tile_entry.contents) do
                local resource = registry[resource_id]
                row(lines, "    Tile "..tile_index.." - Resource "..resource_id.." - "..resource.amount.." "..resource.type)
            end
        end
    end

    row(lines, "")
end

local function displayGroundPileInfo(entity, lines)
    row(lines, "Ground Pile    ID: " .. entity.id)
    row(lines, "position: " .. entity.x .. ", " .. entity.y)
    for _, resource_id in ipairs(entity.contents) do
        local resource = registry[resource_id]
        row(lines, "    ["..resource_id.."] "..resource.amount.." "..resource.type)
    end
end

-- ─── Draw ─────────────────────────────────────────────────────────────────────

function left_panel.draw(selected, selected_type)
    if selected == nil then
        return
    end

    local screen_height = love.graphics.getHeight()
    local font_height   = love.graphics.getFont():getHeight()
    local line_height   = font_height + 2

    local lines = {}
    if selected_type == "unit" then
        displayUnitInfo(selected, lines)
    elseif selected_type == "building" then
        displayBuildingInfo(selected, lines)
    elseif selected_type == "ground pile" then
        displayGroundPileInfo(selected, lines)
    elseif selected_type == "tile" then
        buildLines(selected, 0, lines, "")
    end

    love.graphics.setColor(COL_BG)
    love.graphics.rectangle("fill", 0, 0, PANEL_WIDTH, screen_height)
    love.graphics.setColor(COL_BORDER)
    love.graphics.line(PANEL_WIDTH, 0, PANEL_WIDTH, screen_height)

    love.graphics.setColor(COL_HEADER)
    love.graphics.print("[" .. selected_type .. "]", PANEL_PAD, PANEL_PAD)

    local y_offset  = PANEL_PAD + line_height + 4
    local max_lines = math.floor((screen_height - y_offset - PANEL_PAD) / line_height)

    for i = 1, math.min(#lines, max_lines) do
        local entry = lines[i]
        love.graphics.setColor(entry.color)
        love.graphics.print(entry.text, PANEL_PAD, y_offset + (i - 1) * line_height)
    end
end

left_panel.width = PANEL_WIDTH

return left_panel
