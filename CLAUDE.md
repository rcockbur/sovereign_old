# Sovereign — CLAUDE.md
*v1 · Technical reference for Claude Code and Claude.ai design sessions.*

> **Temporary content:** Config table values and data structure field listings are included in the technical reference files until the corresponding Lua files exist in the repo. Once implemented, trim those sections to shape/intent only — the code becomes the source of truth for specific values and fields.

## Pending Review

*Items added by Claude Code during implementation that need design review in the next Claude.ai chat session. Resolved items are removed during document updates at session end.*

(none)

## Technical Routing Table

Detailed specs live in separate files. Read the relevant file before implementing a system. All files live at the repo root and are attached to the Claude.ai project.

| File | Contents |
|---|---|
| **BEHAVIOR.md** | Tick order, hash offset, per-unit update loops (per-tick and per-hash), activity types and handlers, need interrupts (soft/hard, availability gating), sleep (time-of-day thresholds, wake check, sleep destination, collapse), eating behavior, home food self-fetch, carrying (rules, single-type invariant, weight cap), offloading, self-fetch and self-deposit (behavioral patterns), work cycles (designation, gathering, extraction, processing, farming), production order evaluation, work in progress, equipment want behavior, drafting, unit death cleanup, building deletion cleanup, classes and specialties (promotion, children, job filtering, skill growth). |
| **ECONOMY.md** | Resource entities (stacks, items), containers (bin, tile inventory, stack inventory, item inventory, ground pile), reservation system (mechanism and lifecycle), resources module API, resource counts system, frost and farming (thaw/frost system, per-tile crop state, farm controls, farm job posting, harvest yield), ground piles (entity structure, ground drop search algorithm), hauling order system, merchant delivery system. |
| **WORLD.md** | Map (dimensions, terrain, forest coverage, forest depth), map generation (noise setup, full pipeline, tuning), pathfinding (A*, tile costs, movement model, movement speed, collision, failure), building layout (tile types, tile maps, clearing, orientation, placement validation, construction state, buildings without tile maps, pathfinding integration), plant system (growth stages, spread, cursor scan), visibility (deferred). |
| **TABLES.md** | Game entity data structures (unit, memory, tile, job, hauling order, production order, work in progress, building, world). All config tables (NeedsConfig, SleepConfig, MerchantConfig, HousingBinConfig, JobTypeConfig, SerfChildJobs, RecipeConfig, GrowthConfig, MoodThresholdConfig, MoodModifierConfig, InjuryConfig, IllnessConfig, MalnourishedConfig, ResourceConfig, PlantConfig, CropConfig, BuildingConfig). Production chains. |
| **UI.md** | Camera, input handling, layout (right panel, left panel, bottom bar), selection mechanics, panel contents and variations, command panel, management overlays, notification display. |

**BEHAVIOR.md vs ECONOMY.md boundary:** BEHAVIOR.md owns what units do — all step-by-step behavioral sequences including work cycles, self-fetch/deposit flows, carrying rules, equipment want behavior, and interrupt handling. ECONOMY.md owns what the resource system provides — entities, containers, the resources module API, reservations as a mechanism, and autonomous systems like the merchant and hauling orders. When a unit calls a resources module function, the call sequence lives in BEHAVIOR.md; the function's contract and implementation details live in ECONOMY.md. A task involving unit behavior should only need BEHAVIOR.md (plus TABLES.md). ECONOMY.md is loaded when working on resource infrastructure itself.

**Simulation files vs UI file:** The domain files split into **simulation files** (BEHAVIOR.md, ECONOMY.md, WORLD.md, TABLES.md) and the **UI file** (UI.md). The simulation files own everything that would exist in a headless run — rules, state, behavior, formulas. UI.md owns how the player sees and interacts with the simulation — panels, input handling, camera, layout, interaction flows. None of it exists in a headless run.

Claude Code should read the relevant file(s) before starting implementation. Most tasks require TABLES.md plus one domain file. This file (CLAUDE.md) is always loaded automatically.

## Stack

- **Engine:** Love2D (Lua)
- **Editor:** VS Code
- **Platform:** PC (Windows primary)
- **Population cap:** ~200 units

## Folder Structure

```
src/              -- Love2D root (launch with `love src`)
  main.lua
  core/           -- gamestate, time, registry, world, simulation, log, save
  simulation/     -- unit.lua, jobs, needs, mood, health, hauling, building, dynasty, resources
  config/         -- all config tables, constants.lua
  ui/             -- renderer, camera, input, overlay
  events/         -- event system, Fey
tests/            -- plain Lua tests, run outside Love2D (lua tests/run.lua)
```

All requires use paths relative to `src/` (e.g., `require("core.gamestate")`). Build a `.love` archive by zipping the contents of `src/`, not the repo root.

## Entry Point

```lua
-- main.lua
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
```

Love2D callbacks delegate to `core/gamestate.lua`. Only the `playing` state runs the simulation. The `src/` directory is the Love2D root — launch with `love src` from the repo root.

## Game State Machine

Stack-based in `core/gamestate.lua`. States: `loading`, `main_menu`, `playing`. Each state is a table with hooks: `enter`, `exit`, `update(dt)`, `draw`, `keypressed`, `mousepressed`. `gamestate:switch(state)` for transitions. `gamestate:push`/`pop` reserved for future modal overlays.

Quit-to-menu from `playing` tears down the current game (clear `world` and `registry`) and returns to `main_menu`. Quit from `main_menu` calls `love.event.quit()`.

## Conventions

NAMING

- `snake_case` for variables and table keys
- `camelCase` for functions
- String identifiers for equality-only checks (modifier sources, skill names, illness names, activity types, crop types, resource types, plant types, trait identifiers, class names, specialty names, needs tier names, job type names, building tile types)
- Integer constants for ordered/comparable values (priority, plant growth stage)
- All boolean fields use `is_`, `has_`, `in_`, or `can_` prefix, no exceptions. `is_` for states/properties, `has_` for possession/presence, `in_` for membership/containment, `can_` for capability/permission.
- Resource names are plural (wood, herbs, berries). Plant and map spawn item names are singular (tree, herb_bush, berry_bush).
- Leave meaningful parameter names on stubs even if they produce unused-variable warnings. Do not suppress with `_` or `_name` — that erases intent.

ERROR HANDLING

- Prefer hard failures over silent ones — access config tables and variables directly, let Lua throw on nil
- Use `assert` only when a clearer error message is worth the extra line
- Never guard against missing data with `if x then` when missing data indicates a programming error
- Use `== false` instead of `not` — the keyword `not` is easy to miss when reading code, and `== false` makes boolean checks visually explicit

BIDIRECTIONAL REFERENCES

Prefer bidirectional references for entity relationships. Both sides should be maintained on create and destroy.

Examples: `unit.home_id` ↔ `building.housing.member_ids`, `unit.job_id` ↔ `job.claimed_by`, `unit.claimed_tile` ↔ `tile.claimed_by`, `unit.target_tile` ↔ `tile.target_of_unit`, `unit.bed_index` ↔ `bed.unit_id`, `unit.friend_ids` ↔ counterpart's `friend_ids`, `building.posted_job_ids` ↔ `job.target_id`, `building.hauling_order_ids` ↔ `hauling_order.source_id`/`destination_id`.

Rationale: simplifies cleanup (if a building is deleted, its `posted_job_ids` immediately identifies affected jobs and their claimants, its `hauling_order_ids` identifies orders to remove) and makes traversal straightforward in both directions. Bidirectional refs are appropriate for stable entity relationships — not for transient operational state like private haul jobs (those are found via the unit walk during deletion).

IDS

One global incrementing counter for all entity types (units, memories, buildings, jobs, stacks, items, hauling orders, ground piles). Counter lives on the registry module: `registry.nextId()`. A unit's `id` persists when they die and become a memory. Plants (trees, herbs, berry bushes) are tile data — no IDs.

CONFIG-TO-RUNTIME NAMING

BuildingConfig uses `default_` prefixed fields for values that are copied to runtime building fields on construction: `default_production_orders` → `building.production.production_orders`. The runtime field drops the `default_` prefix.

CLAUDE CODE GUIDANCE

- Claude Code may update CLAUDE.md and the technical reference files to reflect implementation details: function signatures, module locations, call patterns, actual field names used in code.
- Claude Code does **not** add, change, or remove design decisions. If implementation reveals a design gap or forces a choice not covered by the specs, add a brief note to the **Pending Review** section at the top of this file. Do not decide and document it as settled.
- The test: "Would Ross want to discuss this before it was locked in?" If yes, it goes in Pending Review.

FLAT INDEX CONVENTION

```lua
function tileIndex(x, y)
    return (x - 1) * MAP_HEIGHT + y
end

function tileXY(index)
    local x = math.floor((index - 1) / MAP_HEIGHT) + 1
    local y = (index - 1) % MAP_HEIGHT + 1
    return x, y
end
```

All spatial lookups use `tileIndex(x, y)`. Applied to: tile grid, growing plant data, visibility sets, and all spatial lookups.

MODULE PATTERN

Local requires per file. Each file declares dependencies at the top. No globals for module references. Entity creation via `registry.createEntity(collection, entity)` — one call allocates ID, inserts into the typed array and registry, returns the entity. Modules define factory functions that build the entity table (they know the shape) and delegate the id/insert/register step.

```lua
function registry.createEntity(collection, entity)
    entity.id = registry.nextId()
    collection[#collection + 1] = entity
    registry[entity.id] = entity
    return entity
end
```

OWNERSHIP MODEL

`world` owns all game state: every entity array, time, magic, settings. Modules own behavior, not data. `units.update(time)` iterates `world.units`. `jobs.postJob(...)` inserts into `world.jobs`. Serialization saves `world` and `registry.next_id`. Teardown clears `world` and `registry`.

SWEEP CONVENTION

Every entity type that can be removed uses the same swap-and-pop pattern in a per-module sweep function. Units have `units.sweepDead`. Buildings have `buildings.sweepDeleted` (runs after `units.sweepDead` — see BEHAVIOR.md Building Deletion). Stacks, items, and jobs each have their own sweep with a type-appropriate removal condition (e.g., `amount == 0` for stacks, `durability <= 0` for items). Each sweep function handles its own cleanup before removal (clearing inbound references) and calls `registry[entity.id] = nil` followed by swap-and-pop on the `world.*` array. Not a shared utility — each module writes its own loop. The convention is the consistent shape. Ground piles follow the same pattern — sweep when `#contents == 0`, clear `tile.ground_pile_id` before removal.

ARCHITECTURE

- OO, not ECS — at ~200 units, ECS adds complexity without performance benefit.
- Units carry state. Config tables carry rules. Systems read both.
- Class-based behavioral differences live in config tables keyed by class — not on the unit.
- Composition over inheritance for units — class differences are data, not behavior. Single shallow `Unit` prototype. No subclasses — avoids runtime class-swapping on promotion. Single `unit.lua` file.
- All skill keys present on every unit at 0 regardless of class. Serfs and gentry never grow skills. Only specialty freemen and clergy grow skills.
- Hybrid registry: `registry[id]` for cross-type lookup; `world.*` arrays for typed iteration.
- Deferred deletion: `is_dead`/`is_deleted` flag, update loops skip, sweep at end of tick (swap-and-pop). Unit cleanup (social, job, tile claim, home, bed, dynasty, ground pile drops) happens eagerly in `units.sweepDead`. Building cleanup (unit walk for private hauls, posted job cleanup, container drops, tile clearing, resident eviction, hauling order removal) happens eagerly in `buildings.sweepDeleted`.
- All social relationships (friends, enemies) are bidirectional. When unit A befriends unit B, both `A.friend_ids` and `B.friend_ids` are updated. Death cleanup iterates only the dead unit's relationship lists (max 6 lookups), not all living units.
- All rate values stored as per-tick — use conversion constants in config tables.

LUA PERFORMANCE

- **Never create tables in per-tick code.** Reuse buffers, pre-allocate and clear.
- **Flat index for spatial lookups.** Integer keys use Lua's array part (direct C array access).
- **Prefer numeric `for` loops** over `ipairs`/`pairs` in hot paths.
- **Localize globals** in hot files: `local math_floor = math.floor`.
- **No string concatenation for keys.** Use integer-indexed tables or flat index math.

## Constants

All constants in `config/constants.lua`.

```lua
-- Priorities
Priority = { DISABLED = 0, LOW = 1, NORMAL = 2, HIGH = 3 }
InterruptLevel = { NONE = 0, SOFT = 1, HARD = 2 }

-- Classes are string identifiers, not integer enums (no natural ordering)
-- Valid classes: "serf", "freeman", "clergy", "gentry"

-- Map
MAP_WIDTH  = 400
MAP_HEIGHT = 200
SETTLEMENT_COLUMNS = 200
FOREST_START       = 201

-- Calendar (authored values)
MINUTES_PER_HOUR = 60
HOURS_PER_DAY    = 24
DAYS_PER_SEASON  = 7
SEASONS_PER_YEAR = 4

-- Calendar (derived)
DAYS_PER_YEAR    = DAYS_PER_SEASON * SEASONS_PER_YEAR   -- 28
HOURS_PER_SEASON = HOURS_PER_DAY * DAYS_PER_SEASON      -- 168
HOURS_PER_YEAR   = HOURS_PER_SEASON * SEASONS_PER_YEAR  -- 672

-- Tick system (authored values)
TICK_RATE        = 60
HASH_INTERVAL    = 60
TICKS_PER_MINUTE = 25

-- Tick system (derived)
TICKS_PER_HOUR   = 1500
TICKS_PER_DAY    = 36000
TICKS_PER_SEASON = 252000
TICKS_PER_YEAR   = 1008000

-- Derived conversion helpers (per-tick rates — not design decisions)
PER_MINUTE = 1 / TICKS_PER_MINUTE
PER_HOUR   = 1 / TICKS_PER_HOUR
PER_DAY    = 1 / TICKS_PER_DAY
PER_SEASON = 1 / TICKS_PER_SEASON

-- Speed
Speed = { NORMAL = 1, FAST = 2, VERY_FAST = 4, ULTRA = 8 }

-- Schedule (sleep periods — see SleepConfig in TABLES.md and BEHAVIOR.md Sleep)
MORNING_START = 5    -- morning lerp begins (night → day thresholds)
DAY_START     = 7    -- day band begins (flat day thresholds)
EVENING_START = 20   -- evening lerp begins (day → night thresholds)
NIGHT_START   = 0    -- night band begins at midnight (flat night thresholds)
CHURCH_DAY    = 1    -- Sunday

-- Aging
AGES_PER_YEAR    = SEASONS_PER_YEAR
AGE_OF_ADULTHOOD = 16
AGE_OF_SCHOOLING = 6

-- Frost (rolled at year start — exact day ranges TBD during tuning)
-- THAW_DAY_MIN / THAW_DAY_MAX: range for spring thaw day roll
-- FROST_DAY_MIN / FROST_DAY_MAX: range for autumn frost day roll
-- FROST_WARNING_DAYS: days before frost_day that "frost approaching" notification fires
-- FROST_DECAY_RATE: maturity loss per tick on unharvested crops after frost arrives (TBD)

-- Plants
SPREAD_TILES_PER_TICK = 50

-- Visibility (designed but deferred — all tiles explored/visible until implemented)
SIGHT_RADIUS        = 8
FOREST_SIGHT_RADIUS = 3    -- TBD exact value

-- Movement
BASE_MOVE_COST       = 6     -- ticks per tile on open ground
TREE_MOVE_MULTIPLIER = 3.0   -- trees stage 2+ slow movement (don't block)
SQRT2                = math.sqrt(2)  -- diagonal movement cost multiplier

-- Carrying
CARRY_WEIGHT_MAX  = 32       -- max total weight a unit can carry
MAX_CARRY_SLOW    = 0.5      -- max speed reduction at full weight and 0 strength

-- Storage
STOCKPILE_TILE_CAPACITY      = 64   -- weight capacity per stockpile tile
WAREHOUSE_CAPACITY            = 128  -- total weight capacity for warehouse
GROUND_PILE_PREFERRED_CAPACITY = 64   -- soft cap: drop function prefers to spread to adjacent tiles above this

-- Ground drops
GROUND_DROP_SEARCH_RADIUS = 0   -- Manhattan distance to search for an empty tile when dropping

-- Food
FOOD_VARIETY_WINDOW = 3 * TICKS_PER_DAY   -- food types eaten within this window count for variety bonus

-- Building layout tile types
TILE_WALL  = "W"    -- impassable
TILE_FLOOR = "F"    -- passable interior
TILE_DOOR  = "D"    -- passable, on perimeter, building entrance

-- Building
CLEARING_DEPTH = 1  -- tiles in front of door face that cannot have buildings placed on them

-- Rendering
TILE_SIZE = 32
ZOOM_MIN  = 0.5
ZOOM_MAX  = 2.0

-- Day/season names
DAY_NAMES    = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
SEASON_NAMES = { "Spring", "Summer", "Autumn", "Winter" }
```

## Dev Tools and Testing

LOG SYSTEM (`core/log.lua`)

Categories: `TIME`, `UNIT`, `JOB`, `WORLD`, `HEALTH`, `HAUL`, `SAVE`, `STATE`. Severity levels: OFF, ERROR, WARN, INFO, DEBUG. Ring buffer of last 200 messages for overlay. `log:info("UNIT", "Unit %d claimed job %d", unit.id, job.id)`.

DEVELOPER OVERLAY (`ui/overlay.lua`)

Toggled with F3. Stats bar: FPS, game_time, speed, unit/building/job counts. Tile inspector on hover: coordinates, terrain, plant_type/plant_growth, forest_depth, building_id, ground resources, claimed_by, visibility. Log tail: last ~10 messages.

CONFIG VALIDATION (STARTUP)

Runs during the `loading` game state — the game never reaches `playing` with broken config. Walks all config tables and asserts cross-references are valid:

- Every RecipeConfig input/output key exists in ResourceConfig
- Every BuildingConfig `job_type` references a valid JobTypeConfig key
- Every JobTypeConfig entry with `skill` references a valid key in the unit skills table
- Every BuildingConfig with `category == "processing"` has `max_workers == 1`
- Every BuildingConfig with `tile_map` has exactly one D tile, all layout positions fall on F or D tiles, all F/D tiles are contiguous and reachable from D, all non-D perimeter tiles are W
- Every MerchantConfig bin_threshold key exists in ResourceConfig
- Every ResourceConfig entry with `is_stackable == false` has `max_durability`
- Every ResourceConfig entry with `nutrition` has `is_stackable == true`
- Every ResourceConfig entry with `tool_bonus` has `is_stackable == false`
- Every BuildingConfig processing `input_bins` type matches a key in the building's recipe inputs
- Every HousingBinConfig type matches a valid ResourceConfig key

Errors use `error()` or `assert` with descriptive messages. No graceful fallback — broken config is a programming error.

LOGIC TESTS (OFFLINE)

Live in `tests/`. Run outside Love2D with `lua tests/run.lua` from the repo root. Test pure logic where incorrect math or edge cases are hard to catch visually:

- Need drain rates and interrupt thresholds
- Carrying weight / speed penalty formula
- Mood recalculation (modifier stacking, food variety counting)
- A* pathfinding (optimal paths, impassable tiles, escape case, diagonal rules)
- Hash offset distribution
- Resource transfer (split, merge, capacity clamping)
- Resource count tally accuracy (running tallies match full recount)

Tests are added per-system as that system is implemented — not batched per-phase.

NOT TESTED

Rendering, UI, camera, input handling, high-level integration (e.g., "does a woodcutter complete a full work cycle"). These are faster to verify by watching the game run.

## Module Ownership

| Module | Owns |
|---|---|
| **Game State** | State stack, current state, Love2D callback delegation. |
| **Time** | Clock behavior: `advance()`, `accumulate(dt)`, `hashOffset()`, `getEnergyThresholds()`. Operates on `world.time`. |
| **Simulation** | The `onTick` orchestrator. Owns no data. |
| **World** | Tile grid, forest depth map, plant system. Owns all entity arrays and game state: `world.units`, `world.buildings`, `world.jobs`, `world.stacks`, `world.items`, `world.hauling_orders`, `world.time`, `world.magic`, `world.settings`. Ground resource storage is implementation-dependent. |
| **Units** | Unit lifecycle and behavior (creation, death, promotion). Operates on `world.units`. |
| **Resources** | Stack/item creation, destruction, transfer, counting. Maintains `world.resource_counts`. Operates on `world.stacks` and `world.items`. |
| **Job Queue** | Job posting and filtering logic. Operates on `world.jobs`. |
| **Hauling Orders** | Hauling order scanning and job posting. Operates on `world.hauling_orders`. |
| **Magic** | Spell execution. Operates on `world.magic`. |
| **Dynasty** | Succession logic, leader tracking. |
| **Events** | Scheduled and triggered events. |
| **Registry** | Global ID-based lookup across all entity types. Entity creation helper. |
| **Log** | Ring buffer, severity filtering, file output. |
| **Save** | Serialization/deserialization. |
| **Camera** | Position, zoom, coordinate conversion. |
| **Input** | Input abstraction and action map. |
| **Overlay** | Dev overlay rendering. Pure UI, never writes to simulation. |
| **Renderer** | Tile, building, unit, ground pile rendering. Fog of war. |

## Serialization

Pure Lua table literals via `love.filesystem`. Versioned format. Each module has `.serialize()` / `.deserialize()`.

**Saved:** `world` (all entity arrays: units, buildings, jobs, stacks, items, hauling_orders, ground_piles; tiles skipping visibility; time, magic, settings), memories, dynasty, `registry.next_id`, player settings.

**Rebuilt on load:** registry hash table (from all `world.*` entity arrays), per-unit visibility buffers, tile.is_explored/visible_count, `world.resource_counts` (via `resources.rebuildCounts()`).
