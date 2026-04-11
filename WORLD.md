# Sovereign — WORLD.md
*v1 · Physical map: terrain, generation, pathfinding, building layout, plant system.*

## Map

400x200 tile grid, 1-indexed. Columns 1–200 = settlement. Columns 201–400 = forest. `forest_depth` 0.0 in settlement, linear 0.0–1.0 in forest. `forest_danger = depth²`.

Terrain types: grass, dirt (both pathable), rock (impassable), water (impassable). Lakes only. No rivers. No elevation.

Tile grid stored as flat array using `tileIndex(x, y)`.

FOREST COVERAGE

Trees are dense in the forest (70–85% coverage at map gen) with natural clearings at all depths. The settlement area has sparse small clusters. Trees can be chopped down permanently — new trees come only from mature tree spreading.

Three plant types are stored as tile data: tree, herb_bush, berry_bush. Each yields a distinct resource (wood, herbs, berries). Trees are permanent removal on chop; bushes regrow after gathering.

Trees at stage 2+ significantly impede movement (see Pathfinding). Forest-native enemies are unaffected. Herb bushes and berry bushes never affect pathing.

VISIBILITY (DEFERRED)

All tiles start explored and visible until forest gameplay is implemented.

**Design (for future implementation):** `tile.is_explored` (permanent) + `tile.visible_count` (current unit count). Recompute on tile change only. Double-buffered visibility sets per unit (keyed by tileIndex). Reveal events on `visible_count` 0→1.

**Vision rules are not yet decided.** See BRAINSTORMING.md for an asymmetric vision approach under consideration. `SIGHT_RADIUS` (8) and `FOREST_SIGHT_RADIUS` (3) are placeholder values.

## Map Generation

Runs once at world creation. Deterministic from a single integer `world.seed`. The player can enter a seed manually or accept a random one.

NOISE SETUP

Uses `love.math.noise` (simplex, 2D, returns 0–1). The noise field is fixed — seeding is achieved by sampling from randomized coordinate offsets. At generation start, seed Lua's RNG with `math.randomseed(world.seed)` and roll per-layer offsets:

```lua
math.randomseed(world.seed)
local water_ox, water_oy = math.random(0, 1000000), math.random(0, 1000000)
local rock_ox, rock_oy   = math.random(0, 1000000), math.random(0, 1000000)
local tree_ox, tree_oy   = math.random(0, 1000000), math.random(0, 1000000)
```

Sampling: `love.math.noise((x + offset_x) * frequency, (y + offset_y) * frequency)`. Frequency controls feature size — lower frequency produces larger features. Each layer uses its own frequency value.

Offset generation order matters for determinism — `math.randomseed` sets the RNG to a fixed sequence, so the Nth call to `math.random` always returns the same value for a given seed. If a new layer is inserted between existing layers, downstream offsets change and existing seeds produce different maps. New layers should be appended to the offset generation sequence.

PIPELINE

Each layer runs over the full tile grid in order. Later layers skip tiles already claimed by earlier layers (water and rock are impassable; trees only go on grass).

**Layer 0 — Base terrain.** Fill every tile with grass.

**Layer 1 — Water.** Sample water noise at each tile. Values below threshold become water. No half-dependent thresholds — lakes fall where they fall. Target: 2–4 lakes, 30–100 tiles each, roughly 2–4% total map coverage.

**Layer 2 — Rock.** Sample rock noise at each tile. Skip water tiles. Values above threshold become rock. Threshold varies by map half — higher on settlement side (fewer, smaller outcrops), lower on forest side (more common, larger formations). After placement, flood-fill to identify connected clusters (orthogonal adjacency). Convert any cluster smaller than 3 tiles back to grass.

- Settlement target: 3–6 outcrops, 4–15 tiles each, ~2–3% coverage
- Forest target: larger formations, ~5–8% coverage

**Layer 3 — Trees.** Sample tree noise at each tile. Skip water and rock tiles. Values above threshold place a tree at growth stage 3 (mature). Threshold varies by map half — high on settlement side (sparse clusters), low on forest side (dense coverage). Interpolate thresholds across a transition band (roughly columns 180–220) for a gradual forest edge.

- Settlement target: 5–10% coverage, scattered clusters
- Forest target: 70–85% coverage with natural clearings

**Layer 4 — Berry bushes.** Not noise-driven — scatter placement. Iterate all grass tiles without trees. Roll a placement chance per tile using `math.random`. Higher chance on the forest side and in the transition band, lower on the settlement side. Bushes placed at growth stage 3 (mature).

- Settlement chance: starting point ~1–2% of eligible tiles
- Forest/transition chance: starting point ~3–5% of eligible tiles

Herb bushes are not placed at generation. A generation layer will be added alongside the herbalist in Phase 3.

**Layer 5 — Forest depth.** Not noise-driven. Apply the `forest_depth` formula from the Map section.

**Layer 6 — Starting area override.** Center of the settlement half (column 100, row 100). Force a 10x10 area to grass — overwrite water, rock, trees, and berry bushes. Set `plant_type = nil`, `plant_growth = 0` on cleared tiles.

TUNING

Frequency and threshold values are intentionally unspecified — they need visual iteration, not paper design. Initial implementation should expose all generation parameters as constants in `config/constants.lua` for easy adjustment.

Dirt exists as a terrain type but is not placed by the current pipeline. A cosmetic dirt layer can be added later.

## Pathfinding

A* with a binary heap open list. No path caching — computed on demand each time a unit needs to move.

TILE COSTS

- Grass/dirt: `BASE_MOVE_COST` (6 ticks)
- Building floor/door tiles (F/D): `BASE_MOVE_COST` (6 ticks)
- Building wall tiles (W): impassable
- Trees stage 2+: `BASE_MOVE_COST * TREE_MOVE_MULTIPLIER` (18 ticks). Trees slow movement but do not block pathing.
- Rock, water: impassable
- Blueprints (`building_id` set, `is_built == false`): impassable for pathfinding, passable for path-following (units with an existing path walk through)
- Diagonal movement allowed when both orthogonal neighbors are passable. Diagonal cost = √2 × destination tile cost.

HEURISTIC

All A* modes use octile distance, which accounts for diagonal movement costing √2:

```lua
local dx = math.abs(node_x - goal_x)
local dy = math.abs(node_y - goal_y)
local h = (math.max(dx, dy) + (SQRT2 - 1) * math.min(dx, dy)) * BASE_MOVE_COST
```

PATHFINDING MODES

Two modes share the same A* core. The caller specifies the mode and the target; the pathfinder handles termination and heuristic internally.

**Destination mode:** Goal is a specific tile. A* terminates when the current node equals the destination. Heuristic uses octile distance to the destination. Used for: workstations, beds, home, storage pickup/deposit, move commands, idle tile search.

**Adjacent-to-rect mode:** Goal is any unclaimed pathable orthogonal neighbor of a rectangle. A* terminates when the current node satisfies all three conditions: orthogonally adjacent to any tile in the rect, pathable, and `target_of_unit == nil`. Used for: tree chopping, berry gathering, herb gathering, construction delivery, construction building, and melee combat (Phase 5). A 1×1 rect is used for single-tile targets (trees, bushes), an NxM rect for buildings.

Adjacent-to-rect heuristic uses octile distance to the nearest point on the rect, minus one tile:

```lua
local nearest_x = clamp(node_x, rect_x, rect_x + rect_width - 1)
local nearest_y = clamp(node_y, rect_y, rect_y + rect_height - 1)
local dx = math.abs(node_x - nearest_x)
local dy = math.abs(node_y - nearest_y)
local octile = (math.max(dx, dy) + (SQRT2 - 1) * math.min(dx, dy)) * BASE_MOVE_COST
local h = math.max(0, octile - BASE_MOVE_COST)
```

This heuristic is admissible (never overestimates) but not tight for large rects — when obstacles force the path to the far side, the true cost is much higher than the estimate. This is inherent to any multi-goal pathfinding problem and is negligible at Sovereign's building sizes.

If no tile satisfies the goal condition (all orthogonal neighbors are impassable or claimed), A* returns no path.

PATH STORAGE

```lua
unit.path = nil    -- { tiles = { idx1, idx2, ... }, current = 1 } or nil
```

Unit advances `current` by 1 each movement step. When `current > #tiles`, the unit has arrived. If the next tile is blocked (building completed, new obstacle), clear the path and recompute.

**Escape case:** If a unit starts A* on a tile belonging to a completed building (e.g., building finished while unit was inside), all tiles of *that specific building* are treated as passable for that query.

TARGET TILE SYSTEM

Every living unit holds exactly one target tile at all times. Bidirectional: `unit.target_tile` ↔ `tile.target_of_unit`. When moving, the target tile is the destination. When stationary, the target tile is the unit's current position.

A tile where `target_of_unit` is set cannot be the final destination of another unit's pathfinding, but units can pass through it freely during transit. This prevents two units from ever stopping on the same tile (which would cause one to visually obscure the other) while allowing units to cross paths.

**Lifecycle:**

- **Starting a move (destination mode):** Check that the destination tile has `target_of_unit == nil`. Claim the destination: set `unit.target_tile` and `tile.target_of_unit`. Release the old target tile. Compute A*. If A* fails, release the new claim and re-claim the old tile.
- **Starting a move (adjacent-to-rect mode):** Release old target tile. Run A* — the goal check includes `target_of_unit == nil` as an acceptance condition, so the arrival tile is determined by A* itself. Claim the result tile. This all happens within a single function call with no interleaving from other unit updates.
- **Arrival:** Target tile stays on the arrival tile (no change needed).
- **Destination becomes unavailable during transit:** Another unit claimed the destination tile while this unit was en route. On arrival, the unit searches outward for the nearest unclaimed pathable tile and moves there.
- **Building placement on unit's tile:** The tile becomes impassable (blueprint). The unit searches outward for the nearest unclaimed pathable tile and moves there.
- **Death:** Release both sides (`unit.target_tile` and `tile.target_of_unit`). Handled in sweepDead.
- **Game start:** Each spawned unit claims an initial target tile at their starting position during creation.

**Tile search:** When a unit needs a place to stand and its current or intended position is unavailable, it searches outward in expanding rings for the nearest tile that is pathable and has `target_of_unit == nil`. Small radius cap before falling back to overlapping on the current tile with a notification.

MOVEMENT MODEL

Tile-per-tick with render lerp. The unit is always on exactly one tile in the simulation. The renderer interpolates visually between tiles using `move_progress / tile_cost`.

```lua
unit.move_progress = 0

function unit:moveStep()
    if self.path == nil then return end
    local next_idx = self.path.tiles[self.path.current]
    local nx, ny = tileXY(next_idx)
    local tile_cost = getTileCost(nx, ny)

    self.move_progress = self.move_progress + self.move_speed
    if self.move_progress >= tile_cost then
        self.move_progress = self.move_progress - tile_cost
        self.x = nx
        self.y = ny
        self.path.current = self.path.current + 1
        if self.path.current > #self.path.tiles then
            self.path = nil
        end
    end
end
```

MOVEMENT SPEED

`unit.move_speed` is `1.0` baseline for all units. Carrying weight reduces speed based on strength:

```lua
weight_ratio = resources.countWeight(unit.carrying) / CARRY_WEIGHT_MAX
slow_factor = MAX_CARRY_SLOW * (1 - unit:getAttribute("strength") / (genetic_attribute_max + acquired_attribute_max))
move_speed = 1.0 * (1 - weight_ratio * slow_factor)
```

A unit with 10 effective strength carries anything with no penalty. A unit with 0 strength at full carry weight loses up to `MAX_CARRY_SLOW` (0.5 — half speed). `move_speed` is recalculated when `unit.carrying` changes.

NEAREST-X RESOLUTION

- Map resources (trees, herbs, berry bushes): scan outward from building position in expanding rings
- Buildings (stockpiles, homes): linear scan of building list with distance comparison

No spatial indexing needed at ~200 units and ~20-50 buildings.

FAILURE

If A* returns no path, the unit is trapped. A notification fires. The unit idles until the obstruction is cleared.

## Building Layout

Buildings use a tile map defining which tiles are walls, floor, or doors. Units path inside buildings through the door to reach functional positions (workstations, beds, seats).

TILE TYPES

| Type | Meaning | Pathability |
|---|---|---|
| `W` | Wall | Impassable |
| `F` | Floor | Passable (interior) |
| `D` | Door | Passable (perimeter opening) |

DEAD-END RULE

Every enclosed building has exactly one door. All other perimeter tiles are walls. A* never routes through buildings because there is no second exit. No cost penalty needed.

TILE MAP

Each BuildingConfig defines a `tile_map` — a flat array of tile type strings read row by row, left to right, top to bottom:

```lua
bakery = {
    width = 3, height = 3,
    tile_map = {
        "W", "W", "W",
        "F", "F", "F",
        "W", "D", "W",
    },
}
```

Config validation asserts: exactly one D tile, all non-D perimeter tiles are W, all F/D tiles are contiguous and reachable from D, all layout positions fall on F or D tiles.

LAYOUT POSITIONS

Each building has a `layout` table defining positions within the footprint:

**Functional positions** (on F or D tiles — units path here): `workstation`, `beds`, `seats`.

```lua
bakery = {
    layout = {
        workstation    = { x = 1, y = 1 },
    },
}
cottage = {
    layout = {
        beds = {
            { x = 0, y = 0 }, { x = 2, y = 0 },
            { x = 0, y = 1 }, { x = 2, y = 1 },
        },
    },
}
```

CLEARING

A strip of tiles 1 deep on the door face extending outward from the building. These are normal ground tiles — the building does not own them — but placement validation prevents other buildings' wall tiles from being placed on them. Clearing tiles from different buildings can overlap, allowing face-to-face placement with a shared walkable corridor.

ORIENTATION

Four orientations: N/S/E/W. The tile map and layout positions are defined in one canonical orientation and rotated at construction time. The door face determines clearing direction.

PLACEMENT VALIDATION

- All building tiles must be on pathable terrain (grass/dirt) unless a `placement` field overrides (e.g., `placement = "rock"`)
- Clearing tiles must not overlap another building's wall tiles
- The tile immediately outside the door must be pathable

CONSTRUCTION STATE

While under construction, all tiles of a blueprint are impassable (current behavior). On completion, interior F/D tiles become passable. No mid-construction pathfinding weirdness.

BUILDINGS WITHOUT TILE MAPS

**Stockpiles:** Open area, every tile is a storage entry in the tile inventory. No walls, no door, no tile map. All tiles are directly accessible.

**Farms:** Player-sized open passable area. No wall/floor model. See ECONOMY.md Frost and Farming for per-tile crop state and farm controls.

PATHFINDING INTEGRATION

`getTileCost` checks building tiles: if the tile belongs to a completed building and its tile map entry is W, impassable. If F or D, passable at BASE_MOVE_COST. Blueprints (not yet built) remain fully impassable for pathfinding, passable for path-following (existing behavior).

**Escape case** (unchanged): If a unit starts A* on a tile belonging to a completed building, all tiles of that specific building are treated as passable for that query.

## Plant System

Plants are tile data, not entities. Three types: tree, herb_bush, berry_bush. Each plant yields a distinct resource: tree → wood, herb_bush → herbs, berry_bush → berries.

```lua
tile.plant_type   = nil       -- nil | "tree" | "herb_bush" | "berry_bush"
tile.plant_growth = 0         -- 0=empty, 1=seedling, 2=young, 3=mature
```

When `plant_growth == 0`, `plant_type` must be `nil`. When `plant_growth > 0`, `plant_type` identifies what's growing.

**Harvest:** Trees → chopping sets growth=0, type=nil (permanent removal). Herb bushes/berry bushes → gathering resets growth to 1 (regrowth).

**Cursor scan:** `SPREAD_TILES_PER_TICK` (50) tiles per tick, linear wrap. Seedling/young → promote if enough ticks elapsed per `PlantConfig[type].seedling_ticks` / `young_ticks` (defer tree seedling→young if unit on tile). Mature → spread same type to random tile within manhattan distance `PlantConfig[type].spread_radius`.

**Growth data:** `world.growing_plant_data[tileIndex(x, y)] = planted_tick`. Stages 1–2 only. Removed on promotion to mature.

**Safety:** No spread adjacent to buildings.

**Performance note:** The cursor scan touches every tile including mature plants. At high mature plant density (30,000+ tiles), the per-tick cost is still low (just a growth check and a `spread_chance` random roll per mature tile), but if profiling shows issues, a mature plant list could replace the full-tile scan.
