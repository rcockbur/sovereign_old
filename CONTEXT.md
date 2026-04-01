# Sovereign — Coding Context
*Read this at the start of every session.*

---

## Stack

- **Engine:** Love2D (Lua)
- **Editor:** VS Code
- **Platform:** PC (Windows primary)
- **Population cap:** ~200 units

---

## Folder Structure

```
main.lua
/core         -- time, registry, world
/simulation   -- unit.lua, jobs, needs, mood, health
/config       -- all config tables, constants.lua
/ui           -- rendering and input
/events       -- event system, Fey, Changeling
```

---

## Entry Point

```lua
-- main.lua
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
```

---

## Conventions

### Naming
- `snake_case` for variables and table keys
- `camelCase` for functions
- String identifiers for equality-only checks (modifier sources, skill names, illness names, activity types, crop types, resource types)
- Integer constants for ordered/comparable values (tier, priority, job tier, tree growth stage)
- All boolean fields use `is_` or `has_` prefix, no exceptions. `is_` for states and properties, `has_` for possession/presence.

### Method Syntax
- Colon (`:`) for method definitions and calls — anything that operates on an instance and receives `self`
- Dot (`.`) for field access and static/utility functions that don't need `self`

### Error Handling
- Prefer hard failures over silent ones — access config tables and variables directly, let Lua throw on nil
- Use `assert` only when a clearer error message is worth the extra line
- Never guard against missing data with `if x then` when missing data indicates a programming error
- Use `== false` instead of `not`

### IDs
One global incrementing counter for all entity types (units, memories, buildings, jobs, furniture, hauling rules). No collisions possible. A unit's `id` persists when they die and become a memory. Trees and herbs are tile data, not entities — they do not receive IDs. The counter lives on the registry module (`registry:nextId()`).

### Flat Index Convention
All spatial lookups use a flat index into a single array, avoiding nested tables and string keys:

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

Returns integers 1 through `MAP_WIDTH * MAP_HEIGHT`. Applied to: tile grid, growing tree data, visibility sets, and all future spatial lookups.

### Module Pattern
Local requires per file. Each file declares its dependencies at the top. No globals for module references.

### Entity Creation
Factory functions on owning modules. `units:create(params)` allocates an ID via `registry:nextId()`, builds the entity, inserts into the global registry, appends to the module's typed list, and returns the entity. One call does everything.

### Architecture Pattern
Units carry state. Config tables carry rules. Systems read both. Tier-based behavioral differences (need drain rates, mood thresholds, etc.) live in config tables keyed by tier — not on the unit. Skill caps live in job config tables — not on the unit.

### Lua Performance Conventions
- **Never create tables in per-tick code.** Reuse buffers. Pre-allocate and clear rather than discard and recreate (e.g., double buffering for visibility sets).
- **Flat index for spatial lookups.** `tileIndex(x, y)` returns integers in Lua's array part — direct C array access, no hashing. Avoids nested table initialization and string key allocation.
- **Prefer numeric `for` loops over `ipairs`/`pairs` in hot paths.** `for i = 1, #t do` has no iterator overhead.
- **Localize frequently accessed globals and module functions** at the top of files that run hot code. `local math_floor = math.floor` replaces a `_G` table lookup per call with a register read.
- **Avoid string concatenation for keys.** Use integer-indexed tables or flat index math instead of `x .. "," .. y`.
- **Numeric keys use Lua's array part** (direct index, no hashing). String keys go through the hash part. Prefer integer keys for performance-sensitive lookups.

---

## Constants

All constants live in a single file: `/config/constants.lua`.

```lua
Tier     = { SERF = 1, FREEMAN = 2, GENTRY = 3 }
JobTier  = { T1 = 1, T2 = 2, T3 = 3 }
Priority = { DISABLED = 0, LOW = 1, NORMAL = 2, HIGH = 3 }
InterruptLevel = { NONE = 0, SOFT = 1, HARD = 2 }

-- Map
MAP_WIDTH  = 400
MAP_HEIGHT = 200
SETTLEMENT_COLUMNS = 200    -- columns 1–200
FOREST_START       = 201    -- columns 201–400

-- Calendar
MINUTES_PER_HOUR = 60
HOURS_PER_DAY    = 24
DAYS_PER_SEASON  = 7
SEASONS_PER_YEAR = 4
DAYS_PER_YEAR    = DAYS_PER_SEASON * SEASONS_PER_YEAR   -- 28
HOURS_PER_SEASON = HOURS_PER_DAY * DAYS_PER_SEASON      -- 168
HOURS_PER_YEAR   = HOURS_PER_SEASON * SEASONS_PER_YEAR   -- 672

-- Tick system
TICK_RATE        = 60     -- ticks per real second at x1
HASH_INTERVAL    = 60     -- ticks between hashed entity updates (1 real second at x1)
TICKS_PER_MINUTE = 25
TICKS_PER_HOUR   = 1500
TICKS_PER_DAY    = 36000
TICKS_PER_SEASON = 252000
TICKS_PER_YEAR   = 1008000

-- Conversion helpers for config readability
PER_MINUTE = 1 / TICKS_PER_MINUTE
PER_HOUR   = 1 / TICKS_PER_HOUR
PER_DAY    = 1 / TICKS_PER_DAY
PER_SEASON = 1 / TICKS_PER_SEASON

-- Speed
Speed = { NORMAL = 1, FAST = 2, VERY_FAST = 4, ULTRA = 8 }

-- Schedule
WAKE_HOUR  = 6   -- 6am
SLEEP_HOUR = 22  -- 10pm
DAY_START  = 6
DAY_END    = 18
CHURCH_DAY = 1   -- Sunday (day 1 of the week)

-- Aging
AGES_PER_YEAR = SEASONS_PER_YEAR
AGE_OF_ADULTHOOD = 16

-- Trees
SPREAD_TILES_PER_TICK = 50      -- tiles processed per tick by cursor scan
SPREAD_CHANCE         = 0.01    -- probability per eligible spread attempt
SPREAD_RADIUS         = 4       -- manhattan distance for spread target
SAPLING_GROWTH_TICKS  = 0       -- TBD: ticks from sapling to young
YOUNG_GROWTH_TICKS    = 0       -- TBD: ticks from young to mature

-- Visibility
SIGHT_RADIUS = 8

-- Inventory
SLOT_CAPACITY           = 20
WAREHOUSE_SLOT_CAPACITY = 60

-- Rendering
TILE_SIZE = 32
ZOOM_MIN  = 0.5
ZOOM_MAX  = 2.0

-- Day/season names
DAY_NAMES    = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
SEASON_NAMES = { "Spring", "Summer", "Autumn", "Winter" }
```

---

## Module Ownership

| Module | Owns |
|---|---|
| **Time** | Clock state (tick, minute, hour, day, season, year). Accumulator and speed. Provides `hashOffset()` utility. Does not know about other systems. |
| **Simulation** | The `onTick` orchestrator. Calls module update functions in order. Owns no data. |
| **World** | Tile grid, buildings (array, swap-and-pop), stockpiles (array, swap-and-pop), forest depth map, tree cursor scan, growing tree data, visibility state. Posts jobs to the queue when the world needs work done. |
| **Units** | Unit state: attributes, skills, needs, mood, health, relationships, tier, current activity, carrying. Owns the unit update loop (with hash offsets). Also owns creation, death (conversion to memory), promotion/demotion. Owns per-unit visibility sets. `units.all` is an array; swap-and-pop on dead sweep. |
| **Job Queue** | Standalone module. Owns the single flat array of all work tasks (regular jobs and hauling jobs). Swap-and-pop deletion on completion or discard. World and hauling system post jobs; units query and claim them. |
| **Hauling System** | Scans building outputs/inputs and stockpiles. Posts hauling jobs to the job queue based on player-configured push/pull rules. Deficit-based job posting. |
| **Dynasty** | Succession logic, leader tracking, regency state. Reads from unit relationship graphs. |
| **Events** | Event system (Changeling, Fey encounters, random occurrences, funerals, weddings, Sunday service). Reads from world and units; can modify both. Stub for now. |
| **Registry** | Global lookup: `registry[id]` returns any entity (living unit, memory, building, stockpile, job). Single hash-table pool. Also owns the global ID counter (`registry:nextId()`). |

---

## Main Loop

```lua
function love.update(dt)
    local ticks_this_frame = time:accumulate(dt)
    for i = 1, ticks_this_frame do
        time:advance()
        simulation:onTick(time)
    end
end
```

`time:accumulate(dt)` adds real delta time to an internal accumulator and returns how many ticks should fire this frame based on the current speed setting. `time:advance()` increments the tick counter and updates the clock (minute, hour, day, season, year). The main loop is the orchestrator — `time` does not know about `simulation`.

At x1 speed, 1 tick fires per frame (60 ticks/sec at 60fps). At x8, 8 ticks fire per frame.

---

## Simulation Loop

```lua
function simulation:onTick(time)
    time:updateClock()
    units:update(time)
    world:updateBuildings(time)
    world:updateResources(time)
    world:updateTrees(time)
    units:sweepDead(time)
end
```

This is a direct call chain — no event bus, no registration. Adding a new system means adding a line here and consciously deciding its position in the order. `units:sweepDead` runs last — dead units are flagged during updates and removed at the end of the tick.

Calendar-driven logic (daily events, seasonal aging, Sunday service) uses modulo checks in `simulation:onTick`, not inside individual systems. For example:

```lua
if time.tick % TICKS_PER_SEASON == 0 then
    units:processSeasonalAging(time)
end
```

---

## Hash Offset System

All entity collections use hash offsets to distribute updates evenly across ticks. Each entity updates once per `HASH_INTERVAL` ticks (once per real second at x1). A prime multiply scatters sequential IDs to avoid clustering from the shared global ID counter:

```lua
function hashOffset(id)
    return (id * 7919) % HASH_INTERVAL
end
```

Each module owns its own update loop:

```lua
function units:update(time)
    for i = 1, #self.all do
        local unit = self.all[i]
        if unit.is_dead == false then
            if (time.tick + hashOffset(unit.id)) % HASH_INTERVAL == 0 then
                unit:update(time)
            end
        end
    end
end
```

With `HASH_INTERVAL = 60`, approximate per-tick workload:

| Entity type | Typical count | Updates per tick |
|---|---|---|
| Units | ~200 | ~3.3 |
| Buildings | ~300 | ~5 |
| **Total** | ~500 | **~8.3** |

### Per-Unit Update Order

When a unit's hash fires, it runs through all its systems in one burst:

1. Update needs (drain toward depletion)
2. Check for hard need interrupts (drop everything, self-assign behavior)
3. Check for soft need interrupts (finish current delivery, then self-assign)
4. If carrying resources and not mid-delivery, deposit first (offloading if job changed)
5. If idle, poll job queue
6. Execute work progress (grow attribute; grow skill if T2/T3 job and below cap)
7. Recalculate mood (stateless, from scratch)
8. Recalculate health (stateless, from scratch)

---

## Map

400x200 tile grid, 1-indexed. Columns 1–200 = settlement area (`forest_depth` 0.0). Columns 201–400 = forest (`forest_depth` increases linearly from 0.0 at column 201 to 1.0 at column 400). `forest_danger` derived on demand as `depth²`.

Terrain types: grass, dirt, rock (impassable), water (impassable). Lakes only, no rivers. No elevation. Single zone, no separate regions.

Tile grid stored as a flat array using `tileIndex(x, y)`.

---

## Tree System

Trees are tile data, not entities. No global ID, no registry entry, no hash-offset updates.

### Growth Stages

```lua
tile.tree = 0    -- empty (passable)
tile.tree = 1    -- sapling (passable, not choppable, not spreadable)
tile.tree = 2    -- young (blocks pathing, choppable, reduced yield, not spreadable)
tile.tree = 3    -- mature (blocks pathing, choppable, full yield, can spread)
```

Integer stages: `>= 2` for pathfinding blocking checks, `>= 1` for "has any tree" rendering.

### Map Gen Distribution

Settlement area (columns 1–200): sparse small clusters (3–8 trees). Forest area (columns 201–400): dense coverage (70–85%) with natural clearings that decrease in frequency as depth increases.

### Lifecycle

Chopping sets `tile.tree = 0`. No automatic replanting. New saplings come only from mature tree spreading.

Growth timing tracked in `world.growing_tree_data[tileIndex(x, y)] = planted_tick`. Only actively growing trees (stages 1–2) have entries. Removed on promotion to mature. Timestamp resets on each stage promotion.

### Cursor Scan

Single cursor-based scan owned by the world module. Processes `SPREAD_TILES_PER_TICK` (50) tiles per tick, wrapping linearly across the full grid. Full map scan completes every ~27 real seconds at x1.

```lua
function world:updateTrees(time)
    for i = 1, SPREAD_TILES_PER_TICK do
        self.spread_cursor = self.spread_cursor + 1
        if self.spread_cursor > MAP_WIDTH * MAP_HEIGHT then
            self.spread_cursor = 1
        end

        local x, y = tileXY(self.spread_cursor)
        local tile = self.tiles[self.spread_cursor]

        if tile.tree == 1 or tile.tree == 2 then
            self:tryPromote(tile, x, y, time.tick)
        elseif tile.tree == 3 then
            self:trySpread(tile, x, y, time.tick)
        end
    end
end
```

### Spreading

Mature trees (stage 3) pick a random tile within manhattan distance `SPREAD_RADIUS` (4). If the target is empty passable ground (no tree, no building, no rock, no water) and not adjacent to a building, a sapling is planted with probability `SPREAD_CHANCE` (0.01). Invalid targets are no-ops. The forest encroaches on the settlement using the same rules.

### Growth Safety Rules

- **Building buffer:** no sapling spreads onto a tile adjacent to a building (checked at spread time).
- **Unit presence:** promotion from sapling to young deferred if a unit is on the tile.
- Units can get trapped by converging growth. Accepted as emergent gameplay. Player notified when a unit fails to path to any valid destination.

---

## Herb System

Herbs are tile data like trees. `tile.has_herb` flag on the tile. Spread via the same cursor scan system, gated by `forest_depth` per `ResourceSpawnConfig`. Herbalists gather by walking to herb tiles.

---

## Fog of War / Visibility System

Two-layer model:

```lua
tile.is_explored = false     -- permanent, flipped on first sight
tile.visible_count = 0       -- number of units currently seeing this tile
```

### Shadowcasting

Visibility computed via recursive shadowcasting from each unit's position, radius `SIGHT_RADIUS` (8). Implemented in pure Lua (~100–150 lines). Each shadowcast checks ~200 tiles. Feasible at 200 units even at x8 speed.

### Vision Blockers

Determined by a function, not hardcoded per tile type:
- Trees stage 2+ that have at least 1 cardinal neighbor also at stage 2+ block vision.
- Standalone trees (no tree neighbors) do not block.
- Buildings and rock block.
- Water does not block.
- The first blocking tile in a line of sight is itself visible; shadow falls behind it.

### Update Trigger

Recomputed per unit only when the unit changes tile. Each unit owns two pre-allocated visibility sets (double buffer). Shadowcast writes into the inactive buffer, diff against active buffer to update `visible_count`, then swap. Zero GC pressure in steady state.

```lua
unit.visible_a = {}    -- pre-allocated, keyed by tileIndex
unit.visible_b = {}    -- pre-allocated, keyed by tileIndex
unit.active_visible = "a"
```

### Diff Logic

Two passes over old and new sets using `pairs` with O(1) hash lookups. ~400 operations per unit move. Tiles leaving visibility get `visible_count` decremented. Tiles entering visibility get `visible_count` incremented and `is_explored` set to true.

### Reveal Events

Fire when `visible_count` transitions from 0 to 1 on a tile. Used for enemy spotted, ruins discovered, etc.

---

## Key Architectural Decisions

**OO, not ECS.** At ~200 units, ECS adds complexity without meaningful performance benefit.

**Composition over inheritance for units.** Tier differences (Serf, Freeman, Gentry) are data differences, not behavioral ones. A single shallow `Unit` prototype with composed tier data. No subclasses — avoids awkward runtime class-swapping on promotion/demotion.

**Hash offset updates, not global sweeps.** Entities update via hash offsets (one real-second cadence at x1). All systems for a given entity run in one burst on its assigned tick. No tiered cadence scheduling — one universal interval for everything. Prime multiply on the global ID prevents clustering.

**Direct call chain for simulation.** `simulation:onTick` calls module update functions in explicit order. No event bus, no callback registration. Tick order is visible in one function.

**Frequency scheduling in the simulation loop.** Calendar-driven logic (daily events, seasonal aging, Sunday service) uses modulo checks in `simulation:onTick`, not inside individual systems. Per-entity update logic lives inside each module's hash-offset loop.

**Job queue: polling, not idle notification.** Idle units scan the queue during their hashed update. No event bus needed. Simple, correct, negligible cost at this scale.

**Single global job queue.** Regular jobs and hauling jobs share one flat array. Jobs have a `type` field; type-specific fields coexist on the same table. Units scan the queue filtered by eligibility and personal priority. Tie-breaking by distance. Swap-and-pop deletion on completion or discard.

**Two-tier need interrupts.** Soft interrupts let workers finish current delivery before handling the need. Hard interrupts break immediately. Thresholds configured per need per tier in NeedsConfig. Needs are never posted as jobs.

**Mood and health are stateless.** Both recalculated from scratch on each unit's hashed update. Mood = sum of stored decaying modifiers + calculated modifiers derived from current state. Health = `100 + sum of all health modifier values`, clamped 0–100.

**Skill caps on the job, not the unit.** A unit's skill grows until it hits the current job's `max_skill`. Promotion to a higher-tier job sharing the same skill uncaps further growth. Serfs have no skills at all.

**Config values in per-tick terms.** All rates (drain, damage, recovery) are stored as per-tick values. Conversion constants (`PER_HOUR`, `PER_MINUTE`, etc.) make config tables human-readable. Game_minutes exist as a config unit but are not player-facing.

**Single-zone map.** 400x200 grid. Settlement on the left half (columns 1–200), forest on the right (columns 201–400). Forest depth fixed at map gen, never recalculated. `forest_depth` stored on tile; `forest_danger` derived on demand as `depth²`.

**Trees and herbs are tile data, not entities.** Lightweight map features that don't need global IDs, registry entries, or hash-offset updates. Reserve the entity/registry system for things that need unique identity and cross-reference.

**Cursor-based tree updates.** Single linear scan processes a fixed budget of tiles per tick. Handles spreading, growth promotion, and herb spreading in one pass. No per-tree tick cost for the ~30,000 mature forest trees.

**Blueprint-based building.** No room detection. Blueprint claims tiles immediately. Units fetch materials and construct. Building interiors are spatial data (bed positions, etc.) defined in building config and created automatically on construction completion.

**Building placement terrain rules.** Most buildings require all tiles on pathable ground. Mines require one edge entirely on rock. Docks require one edge entirely on water.

**Unified building inventory model.** Production and gathering buildings have separate input and output inventories using the same slot-based model as stockpiles. Three work patterns (hub gathering, stationary extraction, production crafting) share this model.

**Workers own their full job cycle.** A woodcutter finds a tree, chops, and carries. A builder fetches and builds. A smith fetches input materials, crafts, and hauls output if the buffer is full. Workers carry resources as part of their job cycle (carrying), distinct from dedicated hauling jobs.

**Stockpiles as intermediary.** All resource redistribution flows through stockpiles. No direct building-to-building hauling. Production chains go: building output → stockpile → building input.

**Market delivery model.** Merchant walks a greedy nearest-neighbor route delivering consumer goods to homes. Homes that can't be served fall back to self-fetch from stockpiles.

**Spirituality is not a need.** Sunday church service is a scheduled weekly event that applies a decaying mood modifier. No self-interrupt behavior for spirituality.

**Deferred deletion.** Dying entities get `is_dead = true`. Update loops skip dead entities. `units:sweepDead` runs at the end of each tick — removes from module lists (swap-and-pop), converts units to memories, updates registry entries. Death side effects (notifications, relationship updates) happen during the sweep.

**Hybrid registry.** `registry[id]` is a global hash lookup for any entity by ID (cross-type references). Each module also maintains typed arrays for iteration (`units.all`, `world.buildings`, `world.stockpiles`). Factory functions insert into both.

**Local requires per file.** Each file declares dependencies at the top. No globals for module references.

**Input abstraction.** All input routed through a wrapper module. Game code references actions (`input:isAction("select")`), not physical keys/buttons. Supports future remapping and alternate input methods.

---

## Data Structures (Reference)

### Unit
```lua
unit = {
    id = 0, name = "", tier = Tier.SERF,
    is_dead = false,
    age = 0,                            -- in "life years" (not calendar years)
    birth_day = 0, birth_season = 0,    -- age increments on birth_day of each new season
    is_child = true,                    -- age < AGE_OF_ADULTHOOD
    is_attending_school = false,        -- child-only: if true, greys out job priorities

    is_leader = false, is_regent = false,

    father_id = nil, mother_id = nil,
    child_ids = {}, spouse_id = nil,
    friend_ids = {}, enemy_ids = {},    -- up to 3 each

    attributes = {
        strength = 0, dexterity = 0, intelligence = 0,
        wisdom = 0, charisma = 0,
    },
    skills = {
        -- Only tracked for Freeman and Gentry. All default 0.
        melee_combat = 0, smithing = 0, hunting = 0, tailoring = 0,
        baking = 0, brewing = 0, construction = 0, scholarship = 0,
        herbalism = 0, medicine = 0, priesthood = 0, barkeeping = 0,
        trading = 0, jewelry = 0, leadership = 0,
    },
    needs = {
        hunger = 100, sleep = 100, recreation = 100,
    },

    mood = 0,               -- recalculated each hashed update, unbounded
    mood_modifiers = {},    -- { source = "family_death", value = -20, ticks_remaining = 14 * TICKS_PER_DAY }

    health = 100,           -- recalculated each hashed update, clamped 0–100
    health_modifiers = {},  -- injury, illness, malnourished conditions

    carrying = nil,         -- { resource = "logs", amount = 3 } or nil

    current_job_id = nil,
    current_activity = nil, -- "working" | "eating" | "sleeping" | "socializing" | "attending_church" | "delivering" | "offloading" | etc.
    home_id = nil,          -- assigned building id
    bed_index = nil,        -- index into building interior bed positions
    x = 0, y = 0,

    -- Visibility (double buffer, keyed by tileIndex)
    visible_a = {},
    visible_b = {},
    active_visible = "a",
}
```

### Memory (Dead Unit)
```lua
memory = {
    id = 0, name = "",
    father_id = nil, mother_id = nil,
    child_ids = {}, spouse_id = nil,
    death_day = 0, death_season = 0, death_year = 0,
    death_cause = "",
}
```

### Tile
```lua
tile = {
    terrain = "grass",      -- "grass" | "dirt" | "rock" | "water"
    tree = 0,               -- 0=empty, 1=sapling, 2=young, 3=mature
    has_herb = false,       -- true if herb patch present
    building_id = nil,
    forest_depth = 0.0,     -- precomputed at map gen, 0.0 in settlement, 0.0–1.0 in forest
    is_explored = false,    -- permanent, flipped on first sight
    visible_count = 0,      -- number of units currently seeing this tile
    claimed_by = nil,       -- unit_id claiming this tile's resource for gathering
}
```

### Job (unified structure for regular and hauling jobs)
```lua
job = {
    id = 0,
    type = "chop_tree",      -- keys into JobConfig, or "haul" for hauling jobs
    claimed_by = nil,        -- unit_id or nil

    -- Regular job fields (nil for hauling jobs)
    x = 0, y = 0,
    target_id = nil,
    progress = 0,

    -- Hauling job fields (nil for regular jobs)
    resource = nil,          -- "iron", "flour", etc.
    source_id = nil,         -- building or stockpile id
    destination_id = nil,    -- building or stockpile id
}
```

### Building
```lua
building = {
    id = 0, type = "cottage",
    x = 0, y = 0, width = 0, height = 0,
    is_built = false, build_progress = 0,
    interior = {},           -- spatial positions: { { type = "bed", x = 0, y = 0 }, ... }
    crop = nil,              -- farm plots only: "wheat" | "barley" | "flax"

    -- Worker management
    worker_ids = {},         -- currently assigned workers
    worker_limit = 0,        -- player-adjustable, clamped to config max_workers

    -- Inventories (nil if not applicable to building type)
    input = nil,             -- { slots = { ... }, slot_capacity = N }
    output = nil,            -- { slots = { ... }, slot_capacity = N }

    -- Production state
    work_in_progress = nil,  -- { recipe = "sword", progress = 0, work_required = 1200 } or nil
}
```

### Inventory (shared structure for stockpiles and building inventories)
```lua
inventory = {
    slots = {
        { resource = "logs", amount = 3 },
        { resource = "iron", amount = 2 },
        { resource = nil, amount = 0 },     -- empty slot
    },
    slot_capacity = 20,      -- SLOT_CAPACITY, WAREHOUSE_SLOT_CAPACITY, or building-specific
    filters = {
        logs = 4,            -- max slots allowed for this resource
        stone = 4,           -- default: total slot count (accept all)
    },
}
```

### Stockpile
```lua
stockpile = {
    id = 0,
    x = 0, y = 0, width = 0, height = 0,    -- player-defined dimensions
    inventory = { ... },                       -- slot count = width * height
}
```

### Household
```lua
household = {
    building_id = 0,
    member_ids = {},
    food = { bread = 0, vegetables = 0, meat = 0, fish = 0 },
    clothing = 0,
    jewelry = 0,
    max_food_per_type = 10,
    max_clothing = 5,
    max_jewelry = 2,
}
```

### World
```lua
world = {
    width = MAP_WIDTH,       -- 400
    height = MAP_HEIGHT,     -- 200
    tiles = {},              -- flat array, indexed by tileIndex(x, y)
    buildings = {},          -- array, swap-and-pop deletion
    stockpiles = {},         -- array, swap-and-pop deletion

    -- Tree system
    spread_cursor = 0,
    growing_tree_data = {},  -- keyed by tileIndex(x, y) → planted_tick
}
```

### Time
```lua
time = {
    speed = Speed.NORMAL,
    is_paused = false,
    accumulator = 0,          -- real seconds accumulated toward next tick

    tick = 0,                 -- total ticks since game start
    minute = 0,               -- 0–59
    hour = 6,                 -- 0–23 (game starts at 6am)
    day = 1,                  -- 1–7
    season = 1,               -- 1–4
    year = 1,
}
```

---

## Config Tables (Reference)

All constants and config tables live in `/config/`. All rate values are per-tick. Use conversion constants for readability.

### Needs Config

```lua
NeedsConfig = {
    child = {
        hunger     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        sleep      = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 8 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.SERF] = {
        hunger     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        sleep      = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.FREEMAN] = {
        hunger     = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
        sleep      = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
        recreation = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
    },
    [Tier.GENTRY] = {
        hunger     = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
        sleep      = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
        recreation = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
    },
}
```

### Job Config

```lua
JobConfig = {
    -- T1: Any unit, attribute only, no skill
    hauler       = { job_tier = JobTier.T1, attribute = "strength" },
    woodcutter   = { job_tier = JobTier.T1, attribute = "strength",     work_ticks = 8 * TICKS_PER_HOUR },
    miner        = { job_tier = JobTier.T1, attribute = "strength",     work_ticks = 8 * TICKS_PER_HOUR },
    stonecutter  = { job_tier = JobTier.T1, attribute = "strength",     work_ticks = 8 * TICKS_PER_HOUR },
    miller       = { job_tier = JobTier.T1, attribute = "strength" },
    farmer       = { job_tier = JobTier.T1, attribute = "wisdom",       work_ticks = 4 * TICKS_PER_HOUR },
    fisher       = { job_tier = JobTier.T1, attribute = "wisdom",       work_ticks = 4 * TICKS_PER_HOUR },
    gatherer     = { job_tier = JobTier.T1, attribute = "wisdom",       work_ticks = 4 * TICKS_PER_HOUR },

    -- T2: Freeman+, attribute + skill
    guard        = { job_tier = JobTier.T2, attribute = "strength",     skill = "melee_combat",  max_skill = 5 },
    smith        = { job_tier = JobTier.T2, attribute = "dexterity",    skill = "smithing",      max_skill = 5 },
    huntsman     = { job_tier = JobTier.T2, attribute = "dexterity",    skill = "hunting",       max_skill = 5 },
    tailor       = { job_tier = JobTier.T2, attribute = "dexterity",    skill = "tailoring",     max_skill = 5 },
    baker        = { job_tier = JobTier.T2, attribute = "intelligence", skill = "baking",        max_skill = 5 },
    brewer       = { job_tier = JobTier.T2, attribute = "intelligence", skill = "brewing",       max_skill = 5 },
    builder      = { job_tier = JobTier.T2, attribute = "intelligence", skill = "construction",  max_skill = 5 },
    teacher      = { job_tier = JobTier.T2, attribute = "intelligence", skill = "scholarship",   max_skill = 5 },
    herbalist    = { job_tier = JobTier.T2, attribute = "wisdom",       skill = "herbalism",     max_skill = 5 },
    healer       = { job_tier = JobTier.T2, attribute = "wisdom",       skill = "medicine",      max_skill = 5 },
    priest       = { job_tier = JobTier.T2, attribute = "wisdom",       skill = "priesthood",    max_skill = 5 },
    barkeep      = { job_tier = JobTier.T2, attribute = "charisma",     skill = "barkeeping",    max_skill = 5 },
    merchant     = { job_tier = JobTier.T2, attribute = "charisma",     skill = "trading",       max_skill = 5 },

    -- T3: Gentry only, attribute + skill
    knight       = { job_tier = JobTier.T3, attribute = "strength",     skill = "melee_combat",  max_skill = 10 },
    armorer      = { job_tier = JobTier.T3, attribute = "dexterity",    skill = "smithing",      max_skill = 10 },
    jeweler      = { job_tier = JobTier.T3, attribute = "dexterity",    skill = "jewelry",       max_skill = 10 },
    architect    = { job_tier = JobTier.T3, attribute = "intelligence", skill = "construction",  max_skill = 10 },
    scholar      = { job_tier = JobTier.T3, attribute = "intelligence", skill = "scholarship",   max_skill = 10 },
    physician    = { job_tier = JobTier.T3, attribute = "wisdom",       skill = "medicine",      max_skill = 10 },
    bishop       = { job_tier = JobTier.T3, attribute = "wisdom",       skill = "priesthood",    max_skill = 10 },
    steward      = { job_tier = JobTier.T3, attribute = "charisma",     skill = "trading",       max_skill = 10 },
    leader       = { job_tier = JobTier.T3, attribute = "charisma",     skill = "leadership",    max_skill = 10 },
}

-- Jobs children can perform (subset of T1)
ChildJobs = { "hauler", "farmer", "gatherer", "fisher" }
```

### Health Config

```lua
InjuryConfig = {
    bruised = { initial_damage = 10, recovery = 0.5 * PER_HOUR  },
    wounded = { initial_damage = 30, recovery = 0.2 * PER_HOUR  },
    maimed  = { initial_damage = 50, recovery = 0.05 * PER_HOUR },
}

IllnessConfig = {
    cold        = { damage = 0.1 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4 * PER_HOUR  },
    flu         = { damage = 0.2 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4 * PER_HOUR  },
    the_flux    = { damage = 0.4 * PER_HOUR, recovery_chance = 0.10,  recovery = 0.3 * PER_HOUR  },
    consumption = { damage = 0.1 * PER_HOUR, recovery_chance = 0.005, recovery = 0.2 * PER_HOUR  },
    pox         = { damage = 0.3 * PER_HOUR, recovery_chance = 0.02,  recovery = 0.2 * PER_HOUR  },
    pestilence  = { damage = 0.5 * PER_HOUR, recovery_chance = 0.01,  recovery = 0.15 * PER_HOUR },
}

MalnourishedConfig = { damage = 0.3 * PER_HOUR, recovery = 0.5 * PER_HOUR }
```

### Building Config

```lua
BuildingConfig = {
    -- Housing
    cottage = {
        width = 3, height = 3, housing_tier = Tier.SERF,
        build_cost = { logs = 40, stone = 20 },
        interior = {
            { type = "bed", x = 0, y = 0 },
            { type = "bed", x = 1, y = 0 },
            { type = "bed", x = 0, y = 2 },
            { type = "bed", x = 1, y = 2 },
        },
    },
    house = {
        width = 4, height = 3, housing_tier = Tier.FREEMAN,
        build_cost = { logs = 80, stone = 50 },
        interior = {
            { type = "bed", x = 0, y = 0 },
            { type = "bed", x = 1, y = 0 },
            { type = "bed", x = 0, y = 2 },
            { type = "bed", x = 1, y = 2 },
            { type = "bed", x = 2, y = 0 },
            { type = "bed", x = 2, y = 2 },
        },
    },
    manor = {
        width = 5, height = 4, housing_tier = Tier.GENTRY,
        build_cost = { logs = 150, stone = 120 },
        interior = {
            { type = "bed", x = 0, y = 0 },
            { type = "bed", x = 1, y = 0 },
            { type = "bed", x = 0, y = 3 },
            { type = "bed", x = 1, y = 3 },
            { type = "bed", x = 3, y = 0 },
            { type = "bed", x = 3, y = 3 },
            { type = "bed", x = 4, y = 0 },
            { type = "bed", x = 4, y = 3 },
        },
    },

    -- Farm (crop selected per plot: "wheat" | "barley" | "flax")
    farm_plot = { width = 4, height = 4, build_cost = { logs = 10 }, max_workers = 4 },

    -- Hub gathering (output only, workers gather from the world)
    woodcutters_camp = {
        width = 2, height = 2, build_cost = { logs = 20 },
        max_workers = 4,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "logs" } },
    },
    gatherers_hut = {
        width = 2, height = 2, build_cost = { logs = 15 },
        max_workers = 3,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "vegetables" } },
    },
    hunting_cabin = {
        width = 2, height = 2, build_cost = { logs = 25 },
        max_workers = 2,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "meat" } },
    },

    -- Stationary extraction (output only, workers produce on site)
    mine = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 30 },
        placement = "rock_edge",
        max_workers = 4,
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "iron", "gold", "silver", "gems" } },
    },
    quarry = {
        width = 3, height = 3, build_cost = { logs = 30 },
        max_workers = 4,
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "stone" } },
    },
    fishing_dock = {
        width = 2, height = 2, build_cost = { logs = 20 },
        placement = "water_edge",
        max_workers = 2,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "fish" } },
    },

    -- Processing (input + output, workers fetch and craft)
    mill = {
        width = 3, height = 3, build_cost = { logs = 50, stone = 30 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "wheat" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flour" } },
    },
    bakery = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 20 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flour" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "bread" } },
    },
    brewery = {
        width = 3, height = 3, build_cost = { logs = 50, stone = 20 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "barley" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "beer" } },
    },
    tailors_shop = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 15 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flax" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "clothing" } },
    },
    smithy = {
        width = 3, height = 3, build_cost = { logs = 30, stone = 40 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "iron" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "tools", "weapons", "armor" } },
    },
    foundry = {
        width = 4, height = 4, build_cost = { logs = 60, stone = 80 },
        max_workers = 2,
        input  = { slot_count = 4, slot_capacity = 20, accepted_resources = { "iron" } },
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "steel", "tools", "weapons", "armor" } },
    },
    jewelers_workshop = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 30 },
        max_workers = 1,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "gold", "silver", "gems" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "jewelry" } },
    },

    -- Services
    market = {
        width = 4, height = 3, build_cost = { logs = 60, stone = 30 },
        max_workers = 1,
    },
    church = {
        width = 5, height = 4, build_cost = { logs = 80, stone = 60 },
        max_workers = 1,
    },
    infirmary = {
        width = 3, height = 3, build_cost = { logs = 50, stone = 30 },
        max_workers = 2,
        input = { slot_count = 2, slot_capacity = 20, accepted_resources = { "herbs" } },
    },
    tavern = {
        width = 4, height = 3, build_cost = { logs = 60, stone = 30 },
        max_workers = 1,
        input = { slot_count = 2, slot_capacity = 20, accepted_resources = { "beer" } },
    },
    school = {
        width = 3, height = 3, build_cost = { logs = 50, stone = 20 },
        max_workers = 1,
    },

    -- Storage
    warehouse = {
        width = 4, height = 4, build_cost = { logs = 80, stone = 40 },
        slot_count = 16, slot_capacity = WAREHOUSE_SLOT_CAPACITY,
    },

    -- Military
    barracks   = { width = 4, height = 3, build_cost = { logs = 60, stone = 40 } },
    watchtower = { width = 2, height = 2, build_cost = { logs = 30, stone = 30 } },

    -- Governance / Late-game
    town_hall = { width = 5, height = 4, build_cost = { logs = 120, stone = 100 } },
    library   = { width = 4, height = 3, build_cost = { logs = 80, stone = 50 }, max_workers = 1 },
}
```

### Resource Config

```lua
ResourceConfig = {
    logs       = { slot_size = 2 },
    stone      = { slot_size = 2 },
    iron       = { slot_size = 2 },
    steel      = { slot_size = 2 },
    gold       = { slot_size = 2 },
    silver     = { slot_size = 2 },
    gems       = { slot_size = 2 },
    wheat      = { slot_size = 2 },
    barley     = { slot_size = 2 },
    flax       = { slot_size = 2 },
    flour      = { slot_size = 2 },
    bread      = { slot_size = 2 },
    vegetables = { slot_size = 2 },
    meat       = { slot_size = 2 },
    fish       = { slot_size = 2 },
    beer       = { slot_size = 2 },
    clothing   = { slot_size = 2 },
    herbs      = { slot_size = 2 },
    tools      = { slot_size = 2 },
    weapons    = { slot_size = 2 },
    armor      = { slot_size = 2 },
    jewelry    = { slot_size = 2 },
}

-- Units per slot = slot_capacity / slot_size
-- e.g. at slot_size 2: 20 / 2 = 10 per stockpile slot, 60 / 2 = 30 per warehouse slot

ResourceSpawnConfig = {
    timber     = { min_depth = 0.0  },
    wildlife   = { min_depth = 0.0  },
    herbs      = { min_depth = 0.01 },
    artifacts  = { min_depth = 0.8  },
}
```

### Production Chains (Reference)

```
-- Food
wheat_farm → wheat → mill → flour → bakery → bread
gatherers_hut → vegetables
hunting_cabin → meat
fishing_dock → fish

-- Alcohol
barley_farm → barley → brewery → beer

-- Textiles
flax_farm → flax → tailors_shop → clothing

-- Metal
mine → iron → smithy → tools, weapons, armor
mine → iron → foundry → steel → elite tools, weapons, armor

-- Jewelry
mine → gold/silver/gems (rare) → jewelers_workshop → jewelry

-- Construction materials
woodcutters_camp → logs
quarry → stone

-- Medicine
forest (herbalist) → herbs → infirmary (healer) → treatment
```
