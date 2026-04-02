# Sovereign — CLAUDE.md
*Coding reference for Claude Code. See CONTEXT.md for full rationale.*

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
/core         -- gamestate, time, registry, world, simulation, log, save
/simulation   -- unit.lua, jobs, needs, mood, health, hauling, building, household, dynasty
/config       -- all config tables, constants.lua
/ui           -- renderer, camera, input, overlay
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

Love2D callbacks delegate to `core/gamestate.lua`. Only the `playing` state runs the simulation.

---

## Game State Machine

Stack-based in `core/gamestate.lua`. States: `loading`, `main_menu`, `playing`. Each state is a table with hooks: `enter`, `exit`, `update(dt)`, `draw`, `keypressed`, `mousepressed`. `gamestate:switch(state)` for transitions. `gamestate:push`/`pop` reserved for future modal overlays.

---

## Conventions

### Naming
- `snake_case` for variables and table keys
- `camelCase` for functions
- String identifiers for equality-only checks (modifier sources, skill names, illness names, activity types, crop types, resource types, plant types)
- Integer constants for ordered/comparable values (tier, priority, job tier, plant growth stage)
- All boolean fields use `is_` or `has_` prefix, no exceptions. `is_` for states/properties, `has_` for possession/presence.

### Method Syntax
- Colon (`:`) for method definitions and calls — anything with `self`
- Dot (`.`) for field access and static/utility functions

### Error Handling
- Prefer hard failures over silent ones — access config tables and variables directly, let Lua throw on nil
- Use `assert` only when a clearer error message is worth the extra line
- Never guard against missing data with `if x then` when missing data indicates a programming error
- Use `== false` instead of `not`

### IDs
- One global incrementing counter for all entity types (units, memories, buildings, jobs, furniture, hauling rules)
- Counter lives on the registry module: `registry:nextId()`
- A unit's `id` persists when they die and become a memory
- Plants (trees, herbs, berry bushes) are tile data — no IDs

### Flat Index Convention
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

### Module Pattern
- Local requires per file. Each file declares dependencies at the top. No globals for module references.
- Entity creation via factory functions on owning modules. One call allocates ID, builds entity, inserts into registry + typed list.

### Architecture
- Units carry state. Config tables carry rules. Systems read both.
- Tier-based behavioral differences live in config tables keyed by tier — not on the unit.
- Skill caps live in job config tables — not on the unit.
- All 15 skill keys present on every unit at 0 regardless of tier. Tier gate enforced at job eligibility, not data level.
- Hybrid registry: `registry[id]` for cross-type lookup; each module maintains typed arrays for iteration.
- Deferred deletion: `is_dead = true` flag, update loops skip, `units:sweepDead` at end of tick (swap-and-pop). All cleanup (social, job, tile claim, building, household, dynasty) happens eagerly in sweepDead.

### Lua Performance
- **Never create tables in per-tick code.** Reuse buffers, pre-allocate and clear.
- **Flat index for spatial lookups.** Integer keys use Lua's array part (direct C array access).
- **Prefer numeric `for` loops** over `ipairs`/`pairs` in hot paths.
- **Localize globals** in hot files: `local math_floor = math.floor`.
- **No string concatenation for keys.** Use integer-indexed tables or flat index math.

---

## Constants

All constants in `/config/constants.lua`.

```lua
Tier     = { SERF = 1, FREEMAN = 2, GENTRY = 3 }
JobTier  = { T1 = 1, T2 = 2, T3 = 3 }
Priority = { DISABLED = 0, LOW = 1, NORMAL = 2, HIGH = 3 }
InterruptLevel = { NONE = 0, SOFT = 1, HARD = 2 }

-- Map
MAP_WIDTH  = 400
MAP_HEIGHT = 200
SETTLEMENT_COLUMNS = 200
FOREST_START       = 201

-- Calendar
MINUTES_PER_HOUR = 60
HOURS_PER_DAY    = 24
DAYS_PER_SEASON  = 7
SEASONS_PER_YEAR = 4
DAYS_PER_YEAR    = DAYS_PER_SEASON * SEASONS_PER_YEAR   -- 28
HOURS_PER_SEASON = HOURS_PER_DAY * DAYS_PER_SEASON      -- 168
HOURS_PER_YEAR   = HOURS_PER_SEASON * SEASONS_PER_YEAR  -- 672

-- Tick system
TICK_RATE        = 60
HASH_INTERVAL    = 60
TICKS_PER_MINUTE = 25
TICKS_PER_HOUR   = 1500
TICKS_PER_DAY    = 36000
TICKS_PER_SEASON = 252000
TICKS_PER_YEAR   = 1008000

-- Conversion helpers
PER_MINUTE = 1 / TICKS_PER_MINUTE
PER_HOUR   = 1 / TICKS_PER_HOUR
PER_DAY    = 1 / TICKS_PER_DAY
PER_SEASON = 1 / TICKS_PER_SEASON

-- Speed
Speed = { NORMAL = 1, FAST = 2, VERY_FAST = 4, ULTRA = 8 }

-- Schedule
WAKE_HOUR  = 6
SLEEP_HOUR = 22
DAY_START  = 6
DAY_END    = 18
CHURCH_DAY = 1   -- Sunday

-- Aging
AGES_PER_YEAR    = SEASONS_PER_YEAR
AGE_OF_ADULTHOOD = 16

-- Plants
SPREAD_TILES_PER_TICK = 50
SPREAD_CHANCE         = 0.01
SPREAD_RADIUS         = 4
SEEDLING_GROWTH_TICKS = 0    -- TBD
YOUNG_GROWTH_TICKS    = 0    -- TBD

-- Visibility
SIGHT_RADIUS = 8

-- Hauling
CARRY_CAPACITY = 10    -- units of any resource per trip, fixed for all units

-- Rendering
TILE_SIZE = 32
ZOOM_MIN  = 0.5
ZOOM_MAX  = 2.0

-- Day/season names
DAY_NAMES    = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
SEASON_NAMES = { "Spring", "Summer", "Autumn", "Winter" }
```

---

## Debugging Tools

### Log System (`core/log.lua`)
Categories: `TIME`, `UNIT`, `JOB`, `WORLD`, `HEALTH`, `HAUL`, `SAVE`, `STATE`. Severity levels: OFF, ERROR, WARN, INFO, DEBUG. Ring buffer of last 200 messages for overlay. `log:info("UNIT", "Unit %d claimed job %d", unit.id, job.id)`.

### Developer Overlay (`ui/overlay.lua`)
Toggled with F3. Stats bar: FPS, game_time, speed, unit/building/job counts. Tile inspector on hover: coordinates, terrain, plant_type/plant_growth, forest_depth, building_id, claimed_by, visibility. Log tail: last ~10 messages.

---

## Module Ownership

| Module | Owns |
|---|---|
| **Game State** | State stack, current state, Love2D callback delegation. |
| **Time** | Clock state (tick, game_minute, game_hour, game_day, game_season, game_year). Accumulator and speed. Provides `hashOffset()`. Does not know about other systems. |
| **Simulation** | The `onTick` orchestrator. Calls module update functions in order. Owns no data. |
| **World** | Tile grid, buildings (array, swap-and-pop), forest depth map, plant cursor scan, growing plant data, visibility state. Posts jobs to the queue. |
| **Units** | Unit state: attributes, skills, needs, mood, health, relationships, tier, current activity, carrying, drafted state. Owns creation, death, promotion/demotion. Owns per-unit visibility sets. `units.all` is an array; swap-and-pop on dead sweep. |
| **Job Queue** | Standalone module. Single flat array of all work tasks (regular + hauling). Swap-and-pop deletion. World and hauling system post; units query and claim. |
| **Hauling System** | Scans buildings with hauling rules. Posts hauling jobs based on push/pull thresholds. Deficit-based posting. |
| **Dynasty** | Succession logic, leader tracking. Reads unit relationship graphs. |
| **Events** | Changeling, Fey encounters, random occurrences, funerals, weddings, Sunday service. Reads/modifies world and units. |
| **Registry** | Global lookup: `registry[id]` returns any entity (unit, memory, building, job). Single hash-table pool. Owns global ID counter (`registry:nextId()`). |
| **Log** | Ring buffer, severity filtering, file output. |
| **Save** | Serialization/deserialization via Lua table literals and `love.filesystem`. |

---

## Main Loop

```lua
function love.update(dt)
    gamestate:update(dt)
end

-- Inside the playing state:
function playing:update(dt)
    if time.is_paused == false then
        local ticks_this_frame = time:accumulate(dt)
        for i = 1, ticks_this_frame do
            time:advance()
            simulation:onTick(time)
        end
    end
end
```

---

## Simulation Loop

```lua
function simulation:onTick(time)
    time:updateClock()
    units:update(time)
    world:updateBuildings(time)
    world:updateResources(time)
    world:updatePlants(time)
    units:sweepDead(time)
end
```

Calendar-driven logic uses modulo checks in `simulation:onTick`, not inside individual systems:

```lua
if time.tick % TICKS_PER_SEASON == 0 then
    units:processSeasonalAging(time)
end
```

---

## Hash Offset System

```lua
function hashOffset(id)
    return (id * 7919) % HASH_INTERVAL
end

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

### Per-Unit Update Order
1. **Drain needs** (satiation, energy, recreation drain toward 0)
2. **Check hard need interrupts** (drop everything, self-assign) — skipped if `is_drafted`
3. **Check soft need interrupts** (finish delivery, then self-assign) — skipped if `is_drafted`
4. **Offload check** — if carrying and not mid-delivery, deposit first
5. **Poll job queue** — if idle, scan for best job — skipped if `is_drafted`
6. **Execute work progress** (grow attribute; grow skill if T2/T3 and below cap)
7. **Recalculate mood** (stateless)
8. **Recalculate health** (stateless; death check at health <= 0)

Drafted units: steps 1, 6, 7, 8 run normally. Steps 2, 3, 5 skipped. Exception: energy hits 0 → auto-undraft, force sleep.

---

## Map

400x200 tile grid, 1-indexed. Columns 1–200 = settlement. Columns 201–400 = forest. `forest_depth` 0.0 in settlement, linear 0.0–1.0 in forest. `forest_danger = depth²`.

Terrain types: grass, dirt (both pathable), rock (impassable), water (impassable). Lakes only. No rivers. No elevation.

Tile grid stored as flat array using `tileIndex(x, y)`.

---

## Plant System

Plants are tile data, not entities. Three types: tree, herb, berry_bush.

```lua
tile.plant_type   = nil       -- nil | "tree" | "herb" | "berry_bush"
tile.plant_growth = 0         -- 0=empty, 1=seedling, 2=young, 3=mature
```

When `plant_growth == 0`, `plant_type` must be `nil`. When `plant_growth > 0`, `plant_type` identifies what's growing.

Trees block pathing at stage 2+. Herbs and berry bushes never block pathing. Trees block vision at stage 2+ with ≥1 tree neighbor. Herbs and berry bushes never block vision.

**Harvest:** Trees → chopping sets growth=0, type=nil (permanent removal). Herbs/berry bushes → gathering resets growth to 1 (regrowth).

Cursor scan: `SPREAD_TILES_PER_TICK` (50) tiles per tick, linear wrap. Seedling/young → promote if enough ticks elapsed (defer tree seedling→young if unit on tile). Mature → spread same type to random tile within manhattan distance `SPREAD_RADIUS` (4).

Growth data: `world.growing_plant_data[tileIndex(x, y)] = planted_tick`. Stages 1–2 only. Removed on promotion to mature.

Safety: no spread adjacent to buildings.

---

## Visibility System

`tile.is_explored` (permanent) + `tile.visible_count` (current unit count). Recursive shadowcasting per unit, radius `SIGHT_RADIUS` (8). Recompute on tile change only. Double-buffered visibility sets per unit. Reveal events on `visible_count` 0→1.

Vision blockers: trees (`plant_type == "tree"`) stage 2+ with ≥1 tree neighbor. Buildings. Rock. Herbs and berry bushes never block. First blocker is visible; shadow behind.

---

## Drafting

```lua
unit.is_drafted = false
```

Drafted: skip job polling and need interrupts. Needs still drain. Player issues move commands. Mid-job when drafted → abandon (progress persists, claim cleared). Energy hits 0 → auto-undraft + force sleep. Undrafting resumes normal behavior on next hashed update.

---

## Unit Death Cleanup (sweepDead)

All cleanup runs eagerly at end of tick in `units:sweepDead`:
1. Convert to memory (preserves family graph)
2. Update registry (id now points to memory)
3. Social cleanup (remove from all living units' friend_ids/enemy_ids)
4. Family references stay (father_id/spouse_id pointing to memory is correct)
5. Job cleanup (clear claimed_by if had current_job_id)
6. Tile claim cleanup (clear `tiles[unit.claimed_tile].claimed_by`)
7. Building cleanup (remove from worker_ids)
8. Home cleanup (remove from household member_ids)
9. Dynasty check (trigger succession if is_leader)
10. Remove from units.all (swap-and-pop)

---

## Serialization

Pure Lua table literals via `love.filesystem`. Versioned format. Each module has `:serialize()` / `:deserialize()`.

**Saved:** time, tiles (skip visibility), units (skip visibility buffers), memories, buildings, households, jobs, dynasty, registry next_id, player settings.

**Rebuilt on load:** registry hash table, per-unit visibility buffers, tile.is_explored/visible_count, module typed arrays.

---

## Architectural Directives

- **OO, not ECS**
- **Single `unit.lua`** — no split unit files
- **Single global job queue** for all job types including hauling — unified job structure with type-specific fields
- **Job tie-breaking** by weighted combination of distance and job age
- **Two-tier need interrupts** — soft (finish delivery) and hard (immediate). Needs never posted as jobs.
- **Three needs only:** satiation, energy, recreation. Spirituality is NOT a need.
- **Mood and health are stateless** — recalculated from scratch each hashed update
- **Skill caps on the job, not the unit** — all 15 skill keys on every unit at 0
- **Workers own their full job cycle** — carrying is part of the job, not a separate hauling task
- **Fixed carry capacity** — `CARRY_CAPACITY = 10` for all units. Strength affects hauling speed, not amount.
- **Offloading** — when switching job types while carrying, deposit to nearest stockpile first
- **Single resource type carried at a time** — deposit before starting new work
- **Blueprint-based buildings** — no room detection; interiors are spatial data from config
- **Building placement rules** — most need pathable ground; mines need rock edge; docks need water edge
- **Stockpiles are buildings** — `is_player_sized = true`, player-defined dimensions. No separate stockpile array.
- **Unified building inventory model** — input/output inventories using slot system; three work patterns (hub gathering, stationary extraction, production crafting)
- **slot_capacity per building type** — defined in BuildingConfig, not as global constants
- **Hauling rules on buildings** — push/pull thresholds, defaults from BuildingConfig, player-overridable. One job = one trip = one worker. Deficit-based posting.
- **Stockpiles as intermediary** — all redistribution flows through stockpile/warehouse buildings, no direct building-to-building
- **Slot-based inventory** — slot_capacity / resource slot_size = units per slot
- **Plants are tile data** — not entities, no IDs, no registry. Three types: tree, herb, berry_bush.
- **Tree harvest destroys, herb/berry harvest regrows** — chopping → growth=0/type=nil; gathering → growth=1
- **Cursor-based plant updates** — fixed budget per tick, linear scan, all plant types in one pass
- **Shadowcasting visibility** — per unit, recompute on tile change, double-buffered
- **Single-zone map** — 400×200, settlement left, forest right
- **Flat index convention** — `tileIndex(x, y)` for all spatial lookups
- **All rate values stored as per-tick** — use conversion constants in config tables
- **Market delivery model** — merchant walks greedy nearest-neighbor route to homes
- **Eager death cleanup** — all references cleaned in sweepDead. Unit stores `claimed_tile` for O(1) tile cleanup.
- **Hybrid registry** — global hash lookup + per-module typed arrays
- **Local requires per file** — no globals for module references
- **Input abstraction** — game code references actions, not physical keys
- **Game state machine** — stack-based, Love2D callbacks delegate to current state
- **Pure Lua table serialization** — versioned save files, visibility rebuilt on load
- **Drafting** — `is_drafted` flag skips job polling and need interrupts. Energy=0 → auto-undraft + force sleep.

---

## Data Structures

### Unit
```lua
unit = {
    id = 0, name = "", tier = Tier.SERF,
    is_dead = false,
    is_drafted = false,
    age = 0,
    birth_day = 0, birth_season = 0,
    is_child = true,
    is_attending_school = false,

    is_leader = false,

    father_id = nil, mother_id = nil,
    child_ids = {}, spouse_id = nil,
    friend_ids = {}, enemy_ids = {},    -- up to 3 each

    attributes = {
        strength = 0, dexterity = 0, intelligence = 0,
        wisdom = 0, charisma = 0,
    },
    skills = {
        -- All units get all keys at 0. Serfs never grow skills.
        melee_combat = 0, smithing = 0, hunting = 0, tailoring = 0,
        baking = 0, brewing = 0, construction = 0, scholarship = 0,
        herbalism = 0, medicine = 0, priesthood = 0, barkeeping = 0,
        trading = 0, jewelry = 0, leadership = 0,
    },
    needs = {
        satiation = 100, energy = 100, recreation = 100,
    },

    mood = 0,
    mood_modifiers = {},    -- { source, value, ticks_remaining }

    health = 100,
    health_modifiers = {},

    carrying = nil,         -- { resource = "logs", amount = 3 } or nil
    claimed_tile = nil,     -- tileIndex of claimed resource tile, or nil

    current_job_id = nil,
    current_activity = nil,
    home_id = nil,
    bed_index = nil,
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
    terrain = "grass",       -- "grass" | "dirt" | "rock" | "water"
    plant_type = nil,        -- nil | "tree" | "herb" | "berry_bush"
    plant_growth = 0,        -- 0=empty, 1=seedling, 2=young, 3=mature
    building_id = nil,
    forest_depth = 0.0,
    is_explored = false,
    visible_count = 0,
    claimed_by = nil,        -- unit_id claiming resource for gathering
}
```

### Job (unified structure)
```lua
job = {
    id = 0,
    type = "chop_tree",      -- keys into JobConfig, or "haul"
    claimed_by = nil,
    posted_tick = 0,         -- tick when posted, for age-based tie-breaking

    -- Regular job fields (nil for hauling)
    x = 0, y = 0,
    target_id = nil,
    progress = 0,

    -- Hauling job fields (nil for regular)
    resource = nil,
    source_id = nil,         -- building id
    destination_id = nil,    -- building id
}
```

### Building
```lua
building = {
    id = 0, type = "cottage",
    x = 0, y = 0, width = 0, height = 0,
    is_built = false, build_progress = 0,
    interior = {},
    crop = nil,

    worker_ids = {},
    worker_limit = 0,

    input = nil,             -- inventory or nil
    output = nil,            -- inventory or nil

    hauling_rules = nil,     -- { { direction = "push", resource = "logs", threshold = 15 }, ... } or nil

    work_in_progress = nil,  -- { recipe, progress, work_required } or nil
}
```

### Inventory
```lua
inventory = {
    slots = {
        { resource = "logs", amount = 3 },
        { resource = nil, amount = 0 },
    },
    slot_capacity = 20,      -- defined per building type in BuildingConfig
    filters = { logs = 4, stone = 4 },
}
```

### Household
```lua
household = {
    building_id = 0,
    member_ids = {},
    food = { bread = 0, berries = 0, meat = 0, fish = 0 },
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
    width = MAP_WIDTH,
    height = MAP_HEIGHT,
    tiles = {},              -- flat array, tileIndex(x, y)
    buildings = {},          -- array, swap-and-pop deletion (includes stockpiles/warehouses)

    spread_cursor = 0,
    growing_plant_data = {},  -- tileIndex → planted_tick
}
```

### Time
```lua
time = {
    speed = Speed.NORMAL,
    is_paused = false,
    accumulator = 0,
    tick = 0,
    game_minute = 0,
    game_hour = 6,
    game_day = 1,
    game_season = 1,
    game_year = 1,
}
```

---

## Config Tables

```lua
NeedsConfig = {
    child = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 8 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.SERF]    = { satiation = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 }, ... },
    [Tier.FREEMAN] = { satiation = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 }, ... },
    [Tier.GENTRY]  = { satiation = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 }, ... },
}

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

ChildJobs = { "hauler", "farmer", "gatherer", "fisher" }

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
    berries    = { slot_size = 2 },
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

ResourceSpawnConfig = {
    timber      = { min_depth = 0.0  },
    wildlife    = { min_depth = 0.0  },
    herbs       = { min_depth = 0.01 },
    berry_bush  = { min_depth = 0.0  },
    artifacts   = { min_depth = 0.8  },
}
```

See CONTEXT.md for full BuildingConfig with input/output inventory definitions and default_hauling_rules.
