# Sovereign — WORLD.md
*v12 · Physical map: terrain, generation, pathfinding, building layout, plant system.*

## Map

400x200 tile grid, 1-indexed. Columns 1–200 = settlement. Columns 201–400 = forest. `forest_depth` 0.0 in settlement, linear 0.0–1.0 in forest.

Terrain types: grass, dirt (both pathable), rock (impassable), water (impassable). Lakes only. No rivers. No elevation.

Tile grid stored as flat array using `tileIndex(x, y)`.

FOREST COVERAGE

Trees are dense in the forest with natural clearings at all depths. The settlement area has sparse small clusters. Trees can be chopped down permanently — new trees come only from mature tree spreading.

Three plant types are stored as tile data: tree, herb_bush, berry_bush. Each yields a distinct resource (wood, herbs, berries). Trees are permanent removal on chop; bushes regrow after gathering. Berry bushes can also be **cleared** for permanent removal — see Plant System for clearing mechanics.

Trees at stage 2+ significantly impede movement (see Pathfinding). Forest-native enemies are unaffected. Herb bushes and berry bushes never affect pathing.

VISIBILITY (DEFERRED)

All tiles start explored and visible until forest gameplay is implemented.

**Design (for future implementation):** `tile.is_explored` (permanent) + `tile.visible_count` (current unit count). Recompute on tile change only. Double-buffered visibility sets per unit (keyed by tileIndex). Reveal events on `visible_count` 0→1.

**Vision rules are not yet decided.** `SIGHT_RADIUS` (8) and `FOREST_SIGHT_RADIUS` (3) are placeholder values.

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
- Blueprint tiles (`phase == "blueprint"`): impassable unless the A* exemption applies (see A* Building Exemption)
- Constructing tiles (`phase == "constructing"`): impassable
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

**Adjacent-to-rect mode:** Goal is any unclaimed pathable orthogonal neighbor of a rectangle. A* terminates when the current node satisfies all three conditions: orthogonally adjacent to any tile in the rect, pathable, and `target_of_unit == nil`. Used for: tree chopping, berry gathering, herb gathering, construction delivery, construction building, site clearing (P2), and melee combat (Phase 9). A 1×1 rect is used for single-tile targets (trees, bushes), an NxM rect for buildings.

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

A* BUILDING EXEMPTION

A* accepts an optional `exempt_building_id` parameter. When set, all tiles belonging to that building are treated as pathable for that query regardless of building phase. This is a single mechanism that covers two cases:

- **Blueprint clearing (P2):** A unit whose current position or A* target is on a blueprint's footprint needs to path through that blueprint's tiles (to clear obstructions or evacuate). The caller passes the blueprint's building id as the exemption.
- **Escape from completed building (P2):** A unit that starts A* on a tile belonging to a completed building (e.g., after construction completes around them) needs to path out. The caller passes that building's id as the exemption.

Units without the exemption cannot path through blueprint or building tiles. This prevents non-construction units from routing through blueprints while allowing clearing workers and evacuees to reach their targets.

PATH STORAGE

```lua
unit.path = nil    -- { tiles = { idx1, idx2, ... }, current = 1 } or nil
```

Unit advances `current` by 1 each movement step. When `current > #tiles`, the unit has arrived. If the next tile is blocked (building completed, new obstacle), clear the path and recompute.

TARGET TILE SYSTEM

Every living unit holds exactly one target tile at all times. Bidirectional: `unit.target_tile` ↔ `tile.target_of_unit`. When moving, the target tile is the destination. When stationary, the target tile is the unit's current position.

A tile where `target_of_unit` is set cannot be the final destination of another unit's pathfinding, but units can pass through it freely during transit. This prevents two units from ever stopping on the same tile (which would cause one to visually obscure the other) while allowing units to cross paths.

**Lifecycle:**

- **Starting a move (destination mode):** Check that the destination tile has `target_of_unit == nil`. Claim the destination: set `unit.target_tile` and `tile.target_of_unit`. Release the old target tile. Compute A*. If A* fails, release the new claim and re-claim the old tile.
- **Starting a move (adjacent-to-rect mode):** Release old target tile. Run A* — the goal check includes `target_of_unit == nil` as an acceptance condition, so the arrival tile is determined by A* itself. Claim the result tile. This all happens within a single function call with no interleaving from other unit updates.
- **Arrival:** Target tile stays on the arrival tile (no change needed).
- **Destination becomes unavailable during transit:** Another unit claimed the destination tile while this unit was en route. On arrival, flood fill outward from the unit's current position to find the nearest reachable tile that is pathable and has `target_of_unit == nil`. Move there.
- **Death:** Release both sides (`unit.target_tile` and `tile.target_of_unit`). Handled in sweepDead.
- **Game start / debug spawn:** Each spawned unit claims an initial target tile at their starting position during creation.

**Tile position tracking:** `tile.unit_ids` tracks which units are currently on each tile. Maintained in three places: `moveStep` arrival at a new tile (remove from old, add to new), unit spawn (add), and `sweepDead` (remove). This enables O(1) lookup of units on a tile, used by placement validation and combat targeting (Phase 5).

**Tile search (flood fill):** When a unit needs a place to stand and its current position is unavailable (destination claimed during transit), flood fill outward along pathable tiles from the unit's current position. Returns the nearest reachable tile with `target_of_unit == nil`.

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
        -- update tile.unit_ids: remove from old tile, add to new tile
        local old_idx = tileIndex(self.x, self.y)
        removeFromList(tiles[old_idx].unit_ids, self.id)
        tiles[next_idx].unit_ids[#tiles[next_idx].unit_ids + 1] = self.id
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

- Map resources (trees, herbs, berry bushes): flood fill outward from building position along pathable tiles, returning the nearest reachable target. Radius cap of 100 tiles — if no valid target is found within 100 tiles of flood fill expansion, the building has no valid target this scan.
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

**Perimeter F exception:** Buildings with impassable-terrain clearing (fishing dock on water, mines on rock) may have perimeter F tiles on the face adjacent to that clearing. The dead-end property holds naturally because the opening leads onto impassable terrain — A* cannot enter from that side.

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

Config validation asserts: exactly one D tile, all non-D perimeter tiles are W (unless the perimeter F exception applies — see Dead-End Rule), all F/D tiles are contiguous and reachable from D, all layout positions fall on F or D tiles. Solid buildings (`is_solid = true`) skip all of the above — their tile map is all W, they have no door, no layout positions, and no clearing.

LAYOUT POSITIONS

Each building has a `layout` table defining positions within the footprint:

**Functional positions** (on F or D tiles — units path here): `workstation`, `beds`, `seats`. `workstation` is always an array — single-worker buildings have one element.

```lua
bakery = {
    layout = {
        workstation = { { x = 1, y = 1 } },
    },
}
cottage = {
    layout = {
        beds = {
            { x = 1, y = 1 }, { x = 3, y = 1 },
            { x = 1, y = 2 }, { x = 3, y = 2 },
        },
    },
}
```

CLEARING

A strip of tiles 1 deep on the door face extending outward from the building. These are normal ground tiles — the building does not own them — but placement validation prevents other buildings' wall tiles from being placed on them. Clearing tiles from different buildings can overlap, allowing face-to-face placement with a shared walkable corridor.

**Solid buildings** (`is_solid = true`) have no door and no clearing. Workers path adjacent-to-rect to reach them.

**Impassable-terrain clearing:** Buildings with impassable-terrain placement (fishing dock on water, mines on rock) have an additional clearing strip on the back face (opposite the door). This clearing requires the appropriate impassable terrain type rather than pathable ground. Fishing docks have a 2-deep water clearing behind the back row. Mines have a 1-deep rock clearing behind the back row.

ORIENTATION

Four orientations: N/S/E/W. The tile map and layout positions are defined in one canonical orientation and rotated at construction time. The door face determines clearing direction. Player-sized buildings (stockpile, farm) and solid buildings (gathering hubs) have no orientation.

PLACEMENT VALIDATION

- All building tiles must be on pathable terrain (grass/dirt) unless a `placement` field overrides (e.g., `placement = "rock"`)
- Clearing tiles must not overlap another building's wall tiles
- The tile immediately outside the door must be pathable
- **Perimeter F tiles** are only allowed on faces that have an impassable-terrain clearing — validation checks which face the tile is on and whether that face has such a clearing (derivable from the `placement` field)
- **Unit occupancy (P1):** any footprint tile with `target_of_unit ~= nil` or `#tile.unit_ids > 0` is invalid. In P2, units are displaced on placement instead of blocking — see BEHAVIOR.md Construction Work Cycle for the displacement sweep.
- **Plants (P1):** any footprint tile with `tile.plant_type ~= nil` is invalid (trees and berry bushes both block). In P2, trees become clearable obstructions — the building enters blueprint phase and clearing activities are posted. Berry bush clearing comes online in P3.
- **Ground piles (P1):** any footprint tile with `tile.ground_pile_id ~= nil` is invalid. In P2, ground piles become clearable obstructions — the building enters blueprint phase and clearing haul activities are posted.
- **Solid buildings** (`is_solid = true`) have no door — all tiles are wall. Validation only requires all footprint tiles on pathable terrain.

Edge buildings (fishing dock, mines) have row-based terrain constraints relative to orientation. The door face is "front," the opposite edge is "back":

- Fishing dock: back row must be on water, front row must be on grass/dirt, middle rows can be any terrain. 2-deep water clearing behind back row.
- Mines (iron, gold): back row must be on rock, front row must be on grass/dirt, middle rows can be any terrain.

Edge buildings can transform impassable tiles (water, rock) into passable interior space when built.

CONSTRUCTION PHASES

Buildings progress through three phases: `"blueprint"` → `"constructing"` → `"complete"`.

**Blueprint (P2 only).** The building has been placed but the site has not been cleared. Footprint tiles are impassable to most units, but units with the A* building exemption for this building can path through (see Pathfinding A* Building Exemption). Clearing activities (chop for trees, clear for berry bushes, haul for ground piles) are posted into `posted_activity_ids`. Construction material haul activities are NOT posted during this phase — they post on transition to constructing. The blueprint transitions to constructing when all clearing activities are complete and no units remain on footprint tiles. See BEHAVIOR.md Construction Work Cycle for clearing behavior, activity flow, and unit displacement.

**Constructing.** All footprint tiles are impassable. Construction material haul activities and the build activity are posted. Builder delivers materials and builds. See BEHAVIOR.md Construction Work Cycle.

**Complete.** Interior F/D tiles become passable. The building is operational.

**P1 behavior:** Buildings are placed instantly as `"complete"` — no construction phase, no `build_cost` consumed, no build activities posted. On placement, footprint tiles are claimed (`tile.building_id` set) and interior F/D tiles are immediately passable. The `build_cost` and `build_ticks` values in BuildingConfig exist for P2 when the construction system comes online. In P2, buildings with clearable obstructions on their footprint enter blueprint phase; buildings on clear sites are placed as `"constructing"`.

BUILDINGS WITHOUT TILE MAPS

**Stockpiles:** Open area, every tile is a storage entry in the tile inventory. No walls, no door, no tile map. All tiles are directly accessible.

**Farms:** Player-sized open passable area. No wall/floor model. See ECONOMY.md Frost and Farming for per-tile crop state and farm controls. Farms go through the blueprint phase in P2 when obstructions exist on footprint tiles.

SOLID BUILDINGS

Gathering hubs (woodcutter's camp, gatherer's hut, herbalist's hut) are solid structures with `is_solid = true`. Their tile map is all W — no door, no interior, no layout positions. Workers never enter. They path adjacent-to-rect to the building when returning from gathering trips. No clearing is generated for solid buildings.

PATHFINDING INTEGRATION

`getTileCost` checks building tiles: if the tile belongs to a completed building and its tile map entry is W, impassable. If F or D, passable at BASE_MOVE_COST. Blueprint tiles and under-construction tiles are impassable unless the A* building exemption applies (see Pathfinding A* Building Exemption).

## Plant System

Plants are tile data, not entities. Three types: tree, herb_bush, berry_bush. Each plant yields a distinct resource: tree → wood, herb_bush → herbs, berry_bush → berries.

```lua
tile.plant_type   = nil       -- nil | "tree" | "herb_bush" | "berry_bush"
tile.plant_growth = 0         -- 0=empty, 1=seedling, 2=young, 3=mature
```

When `plant_growth == 0`, `plant_type` must be `nil`. When `plant_growth > 0`, `plant_type` identifies what's growing.

**Harvest:** Trees → chopping sets growth=0, type=nil (permanent removal). Herb bushes/berry bushes → gathering resets growth to 1 (regrowth).

**Clearing (P3 for berry bushes):** Sets growth=0, type=nil (permanent removal). Yields the same resource as gathering. Distinct from harvest — clearing destroys the plant entirely.

**Cursor scan:** `SPREAD_TILES_PER_TICK` (50) tiles per tick, linear wrap. Seedling/young → promote if enough ticks elapsed per `PlantConfig[type].seedling_ticks` / `young_ticks` (defer tree seedling→young if unit on tile). Mature → spread same type to random tile within manhattan distance `PlantConfig[type].spread_radius`.

**Growth data:** `world.growing_plant_data[tileIndex(x, y)] = planted_tick`. Stages 1–2 only. Removed on promotion to mature.

**Safety:** No spread adjacent to buildings. No spread onto blueprint tiles (`tile.building_id` set).

**Performance note:** The cursor scan touches every tile including mature plants. At high mature plant density (30,000+ tiles), the per-tick cost is still low (just a growth check and a `spread_chance` random roll per mature tile), but if profiling shows issues, a mature plant list could replace the full-tile scan.
