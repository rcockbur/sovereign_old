-- tests/test_pathfinding.lua

require("config.constants")

-- Override map dimensions so tile indices are small and predictable.
MAP_WIDTH  = 10
MAP_HEIGHT = 10

local world       = require("core.world")
local registry    = require("core.registry")
local pathfinding = require("core.pathfinding")

local function makeTile(terrain, plant_type, plant_growth)
    return {
        terrain        = terrain      or "grass",
        plant_type     = plant_type,
        plant_growth   = plant_growth or 0,
        building_id    = nil,
        building_role  = nil,
        is_clearing    = false,
        target_of_unit = nil,
    }
end

local function makeGrassGrid()
    local tiles = {}
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            tiles[tileIndex(x, y)] = makeTile("grass")
        end
    end
    return tiles
end

-- Path on open grass — straight orthogonal route exists and has the right length.
local function test_straightPathOnGrass()
    local tiles = makeGrassGrid()
    world.tiles = tiles
    local path  = pathfinding.findPath(tileIndex(1, 1), tileIndex(4, 1))
    assert(path ~= nil,          "path on open grass should be found")
    assert(#path.tiles == 3,     "path (1,1)→(4,1) should be 3 tiles")
    assert(path.current == 1,    "path.current starts at 1")
end

-- Diagonal shortcut — A* picks the cheaper 2-step diagonal over 4 orthogonal steps.
local function test_diagonalShortcut()
    local tiles = makeGrassGrid()
    world.tiles = tiles
    local path  = pathfinding.findPath(tileIndex(1, 1), tileIndex(3, 3))
    assert(path ~= nil,       "diagonal path should be found")
    assert(#path.tiles == 2,  "optimal path (1,1)→(3,3) is 2 diagonal steps")
    local x1, y1 = tileXY(path.tiles[1])
    local x2, y2 = tileXY(path.tiles[2])
    assert(x1 == 2 and y1 == 2, "first step should be (2,2)")
    assert(x2 == 3 and y2 == 3, "second step should be (3,3)")
end

-- Path around water — obstacle forces detour.
local function test_pathAroundWater()
    local tiles = makeGrassGrid()
    -- Water wall at column 3, rows 1–8; rows 9–10 left open as a passage around
    for y = 1, MAP_HEIGHT - 2 do
        tiles[tileIndex(3, y)] = makeTile("water")
    end
    world.tiles = tiles
    local path = pathfinding.findPath(tileIndex(1, 1), tileIndex(5, 1))
    assert(path ~= nil, "path around water should be found")
    -- Verify no tile in the path is the water column (x == 3)
    for _, idx in ipairs(path.tiles) do
        assert(tiles[idx].terrain ~= "water", "path should not step on water")
    end
end

-- Path through trees — trees are slow but not impassable.
local function test_pathThroughTrees()
    local tiles = makeGrassGrid()
    -- Fill the whole grid with mature trees except start/end
    for x = 1, MAP_WIDTH do
        for y = 1, MAP_HEIGHT do
            local idx = tileIndex(x, y)
            if not (x == 1 and y == 1) and not (x == 4 and y == 1) then
                tiles[idx] = makeTile("grass", "tree", 2)
            end
        end
    end
    world.tiles = tiles
    local path = pathfinding.findPath(tileIndex(1, 1), tileIndex(4, 1))
    assert(path ~= nil, "path through trees should be found (trees are passable)")
end

-- No path to isolated tile — all neighbors are water.
local function test_noPathToIsolatedTile()
    local tiles = makeGrassGrid()
    -- Surround (5,5) with water on all 8 neighbors
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                tiles[tileIndex(5 + dx, 5 + dy)] = makeTile("water")
            end
        end
    end
    world.tiles = tiles
    local path = pathfinding.findPath(tileIndex(1, 1), tileIndex(5, 5))
    assert(path == nil, "isolated tile surrounded by water should return nil")
end

-- Adjacent-to-rect — finds a tile orthogonally adjacent to a 1×1 target.
local function test_adjacentToRect()
    local tiles = makeGrassGrid()
    world.tiles = tiles
    local path  = pathfinding.findPathAdjacentToRect(tileIndex(1, 1), 5, 5, 1, 1)
    assert(path ~= nil, "adjacent-to-rect path should be found")
    local dest_idx     = path.tiles[#path.tiles]
    local dx, dy       = tileXY(dest_idx)
    local manhattan    = math.abs(dx - 5) + math.abs(dy - 5)
    assert(manhattan == 1, "destination must be orthogonally adjacent to (5,5)")
    assert(tiles[dest_idx].target_of_unit == nil, "destination must be unclaimed")
end

-- Adjacent-to-rect respects target_of_unit — all claimed neighbors returns nil.
local function test_adjacentToRectSkipsClaimed()
    local tiles = makeGrassGrid()
    -- Claim all four orthogonal neighbors of (5,5)
    tiles[tileIndex(5, 4)].target_of_unit = 99
    tiles[tileIndex(5, 6)].target_of_unit = 99
    tiles[tileIndex(4, 5)].target_of_unit = 99
    tiles[tileIndex(6, 5)].target_of_unit = 99
    world.tiles = tiles
    local path = pathfinding.findPathAdjacentToRect(tileIndex(1, 1), 5, 5, 1, 1)
    assert(path == nil, "all adjacent tiles claimed → no valid goal → nil")
end

-- Diagonal blocked when both orthogonal neighbors are impassable —
-- creating an hourglass where (1,1) and (2,2) can only connect diagonally.
local function test_diagonalBlockedByImpassable()
    local tiles = makeGrassGrid()
    -- Make (2,1) and (1,2) water — only connection from (1,1) to (2,2) would be diagonal
    tiles[tileIndex(2, 1)] = makeTile("water")
    tiles[tileIndex(1, 2)] = makeTile("water")
    world.tiles = tiles
    local path = pathfinding.findPath(tileIndex(1, 1), tileIndex(2, 2))
    assert(path == nil, "diagonal blocked by impassable orthogonal neighbors should return nil")
end

-- Diagonal allowed when only one orthogonal neighbor is impassable.
local function test_diagonalAllowedWithOneBlockedNeighbor()
    local tiles = makeGrassGrid()
    -- Make (2,1) water but leave (1,2) clear — diagonal to (2,2) is still blocked
    -- (both neighbors must be passable), but path can go (1,1)→(1,2)→(2,2)
    tiles[tileIndex(2, 1)] = makeTile("water")
    world.tiles = tiles
    local path = pathfinding.findPath(tileIndex(1, 1), tileIndex(2, 2))
    assert(path ~= nil, "path via orthogonal detour should be found")
    -- First step cannot be a diagonal to (2,2) since (2,1) is water
    local fx, fy = tileXY(path.tiles[1])
    assert(not (fx == 2 and fy == 2), "diagonal to (2,2) from (1,1) should be blocked")
end

-- Trivial path — start equals goal.
local function test_trivialPath()
    local tiles = makeGrassGrid()
    world.tiles = tiles
    local path  = pathfinding.findPath(tileIndex(3, 3), tileIndex(3, 3))
    assert(path ~= nil,       "trivial path should not be nil")
    assert(#path.tiles == 0,  "trivial path has no tiles to traverse")
    assert(path.current == 1, "trivial path.current starts at 1")
end

-- Building impassable tile blocks path just like water.
local function test_impassableBuildingBlocks()
    local tiles = makeGrassGrid()
    -- Solid building wall across column 5
    for y = 1, MAP_HEIGHT do
        tiles[tileIndex(5, y)].building_id   = 1
        tiles[tileIndex(5, y)].building_role = "impassable"
    end
    registry[1] = { phase = "complete", clearing_tile = nil }
    world.tiles = tiles
    local path = pathfinding.findPath(tileIndex(1, 5), tileIndex(9, 5))
    registry[1] = nil
    assert(path == nil, "solid building wall should block path with no way around")
end

-- Door→clearing transition is allowed when clearing_tile matches.
local function test_doorToClearingTransition()
    local tiles   = makeGrassGrid()
    local door_idx  = tileIndex(5, 5)
    local clear_idx = tileIndex(5, 6)
    tiles[door_idx].building_id   = 1
    tiles[door_idx].building_role = "door"
    tiles[clear_idx].is_clearing  = true
    registry[1] = { phase = "complete", clearing_tile = clear_idx }
    world.tiles = tiles
    local cost = world.getEdgeCost(door_idx, clear_idx)
    registry[1] = nil
    assert(cost ~= nil, "door→clearing (matching clearing_tile) should be passable")
end

-- Door→clearing blocked when clearing_tile does not match.
local function test_doorToClearingWrongTile()
    local tiles     = makeGrassGrid()
    local door_idx  = tileIndex(5, 5)
    local clear_idx = tileIndex(5, 6)
    local other_idx = tileIndex(5, 4)
    tiles[door_idx].building_id   = 1
    tiles[door_idx].building_role = "door"
    tiles[clear_idx].is_clearing  = true
    registry[1] = { phase = "complete", clearing_tile = other_idx }
    world.tiles = tiles
    local cost = world.getEdgeCost(door_idx, clear_idx)
    registry[1] = nil
    assert(cost == nil, "door→clearing (wrong clearing_tile) should be blocked")
end

-- Diagonal corner-clip around a building impassable tile is blocked.
local function test_diagonalClipAroundBuildingWall()
    local tiles = makeGrassGrid()
    -- Impassable building tiles at (2,1) and (1,2)
    tiles[tileIndex(2, 1)].building_id   = 1
    tiles[tileIndex(2, 1)].building_role = "impassable"
    tiles[tileIndex(1, 2)].building_id   = 1
    tiles[tileIndex(1, 2)].building_role = "impassable"
    registry[1] = { phase = "complete", clearing_tile = nil }
    world.tiles = tiles
    local path = pathfinding.findPath(tileIndex(1, 1), tileIndex(2, 2))
    registry[1] = nil
    assert(path == nil, "diagonal blocked by impassable building walls should return nil")
end

return {
    { "straightPathOnGrass",                   test_straightPathOnGrass                   },
    { "diagonalShortcut",                       test_diagonalShortcut                      },
    { "pathAroundWater",                        test_pathAroundWater                       },
    { "pathThroughTrees",                       test_pathThroughTrees                      },
    { "noPathToIsolatedTile",                   test_noPathToIsolatedTile                  },
    { "adjacentToRect",                         test_adjacentToRect                        },
    { "adjacentToRectSkipsClaimed",             test_adjacentToRectSkipsClaimed            },
    { "diagonalBlockedByImpassable",            test_diagonalBlockedByImpassable           },
    { "diagonalAllowedWithOneBlockedNeighbor",  test_diagonalAllowedWithOneBlockedNeighbor },
    { "trivialPath",                            test_trivialPath                            },
    { "impassableBuildingBlocks",               test_impassableBuildingBlocks               },
    { "doorToClearingTransition",               test_doorToClearingTransition               },
    { "doorToClearingWrongTile",                test_doorToClearingWrongTile                },
    { "diagonalClipAroundBuildingWall",         test_diagonalClipAroundBuildingWall         },
}
