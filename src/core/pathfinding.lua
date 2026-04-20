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
        local p = math.floor(i / 2)
        if heap_f[p] > heap_f[i] then
            heap_f[p],   heap_f[i]   = heap_f[i],   heap_f[p]
            heap_idx[p], heap_idx[i] = heap_idx[i], heap_idx[p]
            i = p
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
        local l       = 2 * i
        local r       = 2 * i + 1
        local smallest = i
        if l <= heap_n and heap_f[l] < heap_f[smallest] then
            smallest = l
        end
        if r <= heap_n and heap_f[r] < heap_f[smallest] then
            smallest = r
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

local getTileCost = world.getTileCost

local function clamp(v, lo, hi)
    if v < lo then
        return lo
    end
    if v > hi then
        return hi
    end
    return v
end

local DIRS = {
    {  0, -1, is_diagonal = false }, {  0,  1, is_diagonal = false },
    { -1,  0, is_diagonal = false }, {  1,  0, is_diagonal = false },
    { -1, -1, is_diagonal = true  }, {  1, -1, is_diagonal = true  },
    { -1,  1, is_diagonal = true  }, {  1,  1, is_diagonal = true  },
}

local function reconstructPath(came_from, start_idx, end_idx)
    local path_tiles = {}
    local cur = end_idx
    while cur ~= start_idx do
        path_tiles[#path_tiles + 1] = cur
        cur = came_from[cur]
    end
    local lo, hi = 1, #path_tiles
    while lo < hi do
        path_tiles[lo], path_tiles[hi] = path_tiles[hi], path_tiles[lo]
        lo = lo + 1
        hi = hi - 1
    end
    return { tiles = path_tiles, current = 1 }
end

-- Shared A* core. is_goal(idx, x, y) and heuristic(x, y) are injected by callers.
-- Early termination on first goal discovery is valid because octile distance is consistent.
local function astar(tiles, start_idx, is_goal, heuristic)
    local sx, sy = tileXY(start_idx)
    if is_goal(start_idx, sx, sy) then
        return { tiles = {}, current = 1 }
    end

    heapReset()
    local g         = {}
    local came_from = {}
    local closed    = {}

    g[start_idx] = 0
    heapPush(heuristic(sx, sy), start_idx)

    while heap_n > 0 do
        local _, cur_idx = heapPop()

        if not closed[cur_idx] then
            closed[cur_idx] = true
            local cx, cy = tileXY(cur_idx)
            local cur_g  = g[cur_idx]

            for d = 1, 8 do
                local dir = DIRS[d]
                local nx  = cx + dir[1]
                local ny  = cy + dir[2]

                if nx >= 1 and nx <= MAP_WIDTH and ny >= 1 and ny <= MAP_HEIGHT then
                    local n_idx = tileIndex(nx, ny)
                    if not closed[n_idx] then
                        local cost = getTileCost(tiles[n_idx])
                        if cost ~= nil then
                            local passable = true
                            if dir.is_diagonal then
                                if getTileCost(tiles[tileIndex(nx, cy)]) == nil or
                                   getTileCost(tiles[tileIndex(cx, ny)]) == nil then
                                    passable = false
                                end
                                if passable then cost = cost * SQRT2 end
                            end
                            if passable then
                                local new_g = cur_g + cost
                                if g[n_idx] == nil or new_g < g[n_idx] then
                                    g[n_idx]         = new_g
                                    came_from[n_idx] = cur_idx
                                    heapPush(new_g + heuristic(nx, ny), n_idx)
                                    if is_goal(n_idx, nx, ny) then
                                        return reconstructPath(came_from, start_idx, n_idx)
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

function pathfinding.findPath(tiles, start_idx, goal_idx, exempt_building_id)
    local gx, gy = tileXY(goal_idx)

    local function is_goal(idx, tx, ty)
        return idx == goal_idx
    end

    local function heuristic(tx, ty)
        local dx = math.abs(tx - gx)
        local dy = math.abs(ty - gy)
        return (math.max(dx, dy) + (SQRT2 - 1) * math.min(dx, dy)) * BASE_MOVE_COST
    end

    return astar(tiles, start_idx, is_goal, heuristic)
end

function pathfinding.findPathAdjacentToRect(tiles, start_idx, rx, ry, rw, rh, exempt_building_id)
    local function is_goal(idx, tx, ty)
        local nearest_x = clamp(tx, rx, rx + rw - 1)
        local nearest_y = clamp(ty, ry, ry + rh - 1)
        local dist = math.abs(tx - nearest_x) + math.abs(ty - nearest_y)
        return dist == 1 and tiles[idx].target_of_unit == nil
    end

    local function heuristic(tx, ty)
        local nearest_x = clamp(tx, rx, rx + rw - 1)
        local nearest_y = clamp(ty, ry, ry + rh - 1)
        local dx = math.abs(tx - nearest_x)
        local dy = math.abs(ty - nearest_y)
        local octile = (math.max(dx, dy) + (SQRT2 - 1) * math.min(dx, dy)) * BASE_MOVE_COST
        return math.max(0, octile - BASE_MOVE_COST)
    end

    return astar(tiles, start_idx, is_goal, heuristic)
end

return pathfinding
