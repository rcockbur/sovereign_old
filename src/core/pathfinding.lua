-- core/pathfinding.lua
-- A* pathfinder with binary heap open list.
-- Two modes: destination (specific tile) and adjacent-to-rect (any unclaimed orthogonal neighbor).

local world = require("core.world")

local pathfinding = {}

-- Reusable parallel-array heap; reset at the start of each search.
local heap_f   = {}
local heap_idx = {}
local heap_n   = 0

local function heapReset()
    heap_n = 0
end

local function heapPush(f, idx)
    heap_n = heap_n + 1
    heap_f[heap_n]   = f
    heap_idx[heap_n] = idx
    local i = heap_n
    while i > 1 do
        local parent_index = math.floor(i / 2)
        if heap_f[parent_index] > heap_f[i] then
            heap_f[parent_index],   heap_f[i]   = heap_f[i],   heap_f[parent_index]
            heap_idx[parent_index], heap_idx[i] = heap_idx[i], heap_idx[parent_index]
            i = parent_index
        else
            break
        end
    end
end

local function heapPop()
    local f   = heap_f[1]
    local idx = heap_idx[1]
    heap_f[1]   = heap_f[heap_n]
    heap_idx[1] = heap_idx[heap_n]
    heap_n = heap_n - 1
    local i = 1
    while true do
        local left_child  = 2 * i
        local right_child = 2 * i + 1
        local smallest = i
        if left_child <= heap_n and heap_f[left_child] < heap_f[smallest] then
            smallest = left_child
        end
        if right_child <= heap_n and heap_f[right_child] < heap_f[smallest] then
            smallest = right_child
        end
        if smallest == i then
            break
        end
        heap_f[i],   heap_f[smallest]   = heap_f[smallest],   heap_f[i]
        heap_idx[i], heap_idx[smallest] = heap_idx[smallest], heap_idx[i]
        i = smallest
    end
    return f, idx
end

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local DIRS = {
    {  0, -1, is_diagonal = false }, {  0,  1, is_diagonal = false },
    { -1,  0, is_diagonal = false }, {  1,  0, is_diagonal = false },
    { -1, -1, is_diagonal = true  }, {  1, -1, is_diagonal = true  },
    { -1,  1, is_diagonal = true  }, {  1,  1, is_diagonal = true  },
}

local function reconstructPath(came_from, start_idx, end_idx)
    local path_tiles = {}
    local current_idx = end_idx
    while current_idx ~= start_idx do
        path_tiles[#path_tiles + 1] = current_idx
        current_idx = came_from[current_idx]
    end
    local low_index  = 1
    local high_index = #path_tiles
    while low_index < high_index do
        path_tiles[low_index], path_tiles[high_index] = path_tiles[high_index], path_tiles[low_index]
        low_index  = low_index  + 1
        high_index = high_index - 1
    end
    return { tiles = path_tiles, current = 1 }
end

-- Shared A* core. is_goal(idx, x, y) and heuristic(x, y) are injected by callers.
-- Early termination on first goal discovery is valid because octile distance is consistent.
local function astar(start_idx, is_goal, heuristic, exempt_building_id)
    local start_x, start_y = tileXY(start_idx)
    if is_goal(start_idx, start_x, start_y) then
        return { tiles = {}, current = 1 }
    end

    heapReset()
    local g         = {}
    local came_from = {}
    local closed    = {}

    g[start_idx] = 0
    heapPush(heuristic(start_x, start_y), start_idx)

    while heap_n > 0 do
        local _, current_idx = heapPop()

        if closed[current_idx] == nil then
            closed[current_idx] = true
            local current_x, current_y = tileXY(current_idx)
            local current_g  = g[current_idx]

            for d = 1, 8 do
                local dir    = DIRS[d]
                local next_x = current_x + dir[1]
                local next_y = current_y + dir[2]

                if next_x >= 1 and next_x <= MAP_WIDTH and next_y >= 1 and next_y <= MAP_HEIGHT then
                    local next_idx = tileIndex(next_x, next_y)
                    if closed[next_idx] == nil then
                        local cost = world.getEdgeCost(current_idx, next_idx, exempt_building_id)
                        if cost ~= nil then
                            local passable = true
                            if dir.is_diagonal then
                                local a_idx = tileIndex(next_x, current_y)
                                local b_idx = tileIndex(current_x, next_y)
                                if world.getEdgeCost(current_idx, a_idx, exempt_building_id) == nil or
                                   world.getEdgeCost(current_idx, b_idx, exempt_building_id) == nil or
                                   world.getEdgeCost(a_idx,   next_idx, exempt_building_id) == nil or
                                   world.getEdgeCost(b_idx,   next_idx, exempt_building_id) == nil then
                                    passable = false
                                end
                                if passable then
                                    cost = cost * SQRT2
                                end
                            end
                            if passable then
                                local new_g = current_g + cost
                                if g[next_idx] == nil or new_g < g[next_idx] then
                                    g[next_idx]         = new_g
                                    came_from[next_idx] = current_idx
                                    heapPush(new_g + heuristic(next_x, next_y), next_idx)
                                    if is_goal(next_idx, next_x, next_y) then
                                        return reconstructPath(came_from, start_idx, next_idx)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

function pathfinding.findPath(start_idx, goal_idx, exempt_building_id)
    local goal_x, goal_y = tileXY(goal_idx)

    local function is_goal(idx, x, y)
        return idx == goal_idx
    end

    local function heuristic(x, y)
        local delta_x = math.abs(x - goal_x)
        local delta_y = math.abs(y - goal_y)
        return (math.max(delta_x, delta_y) + (SQRT2 - 1) * math.min(delta_x, delta_y)) * BASE_MOVE_COST
    end

    return astar(start_idx, is_goal, heuristic, exempt_building_id)
end

function pathfinding.findPathAdjacentToRect(start_idx, rect_x, rect_y, rect_width, rect_height, exempt_building_id)
    local function is_goal(idx, x, y)
        local nearest_x = clamp(x, rect_x, rect_x + rect_width - 1)
        local nearest_y = clamp(y, rect_y, rect_y + rect_height - 1)
        local dist = math.abs(x - nearest_x) + math.abs(y - nearest_y)
        return dist == 1 and world.tiles[idx].target_of_unit == nil
    end

    local function heuristic(x, y)
        local nearest_x = clamp(x, rect_x, rect_x + rect_width - 1)
        local nearest_y = clamp(y, rect_y, rect_y + rect_height - 1)
        local delta_x = math.abs(x - nearest_x)
        local delta_y = math.abs(y - nearest_y)
        local octile = (math.max(delta_x, delta_y) + (SQRT2 - 1) * math.min(delta_x, delta_y)) * BASE_MOVE_COST
        return math.max(0, octile - BASE_MOVE_COST)
    end

    return astar(start_idx, is_goal, heuristic, exempt_building_id)
end

return pathfinding
