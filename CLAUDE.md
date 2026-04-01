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
- Trees and herbs are tile data — no IDs

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

All spatial lookups use `tileIndex(x, y)`. Applied to: tile grid, growing tree data, visibility sets, and all spatial lookups.

### Module Pattern
- Local requires per file. Each file declares dependencies at the top. No globals for module references.
- Entity creation via factory functions on owning modules. One call allocates ID, builds entity, inserts into registry + typed list.

### Architecture
- Units carry state. Config tables carry rules. Systems read both.
- Tier-based behavioral differences live in config tables keyed by tier — not on the unit.
- Skill caps live in job config tables — not on the unit.
- Hybrid registry: `registry[id]` for cross-type lookup; each module maintains typed arrays for iteration.
- Deferred deletion: `is_dead = true` flag, update loops skip, `units:sweepDead` at end of tick (swap-and-pop).

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

-- Trees
SPREAD_TILES_PER_TICK = 50
SPREAD_CHANCE         = 0.01
SPREAD_RADIUS         = 4
SAPLING_GROWTH_TICKS  = 0    -- TBD
YOUNG_GROWTH_TICKS    = 0    -- TBD

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
| **Time** | Clock state (tick, minute, hour, day, season, year). Accumulator and speed. Provides `hashOffset()`. Does not know about other systems. |
| **Simulation** | The `onTick` orchestrator. Calls module update functions in order. Owns no data. |
| **World** | Tile grid, buildings (array, swap-and-pop), stockpiles (array, swap-and-pop), forest depth map, tree cursor scan, growing tree data, visibility state. Posts jobs to the queue. |
| **Units** | Unit state: attributes, skills, needs, mood, health, relationships, tier, current activity, carrying. Owns creation, death, promotion/demotion. Owns per-unit visibility sets. `units.all` is an array; swap-and-pop on dead sweep. |
| **Job Queue** | Standalone module. Single flat array of all work tasks (regular + hauling). Swap-and-pop deletion. World and hauling system post; units query and claim. |
| **Hauling System** | Scans building outputs/inputs and stockpiles. Posts hauling jobs based on push/pull rules. Deficit-based posting. |
| **Dynasty** | Succession logic, leader tracking, regency state. Reads unit relationship graphs. |
| **Events** | Changeling, Fey encounters, random occurrences, funerals, weddings, Sunday service. Reads/modifies world and units. |
| **Registry** | Global lookup: `registry[id]` returns any entity (unit, memory, building, stockpile, job). Single hash-table pool. Owns global ID counter (`registry:nextId()`). |

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
1. Update needs (drain)
2. Check hard need interrupts (drop everything, self-assign behavior)
3. Check soft need interrupts (finish current delivery, then self-assign)
4. If carrying and not mid-delivery, deposit first (offload if job changed)
5. If idle, poll job queue
6. Execute work progress (grow attribute; grow skill if T2/T3 and below cap)
7. Recalculate mood (stateless)
8. Recalculate health (stateless)

---

## Map

400x200 tile grid, 1-indexed. Columns 1–200 = settlement. Columns 201–400 = forest. `forest_depth` 0.0 in settlement, linear 0.0–1.0 in forest. `forest_danger = depth²`.

Terrain types: grass, dirt (both pathable), rock (impassable), water (impassable). Lakes only. No rivers. No elevation.

Tile grid stored as flat array using `tileIndex(x, y)`.

---

## Tree System

Trees are tile data, not entities. Growth stages: 0 (empty), 1 (sapling/passable), 2 (young/blocking), 3 (mature/blocking/spreadable).

Cursor scan: `SPREAD_TILES_PER_TICK` (50) tiles per tick, linear wrap. Saplings/young → promote if enough ticks elapsed. Mature → spread to random tile within manhattan distance `SPREAD_RADIUS` (4).

Growth data: `world.growing_tree_data[tileIndex(x, y)] = planted_tick`. Only stages 1–2. Removed on promotion to mature.

Safety: no spread adjacent to buildings. Defer promotion if unit on tile.

---

## Herb System

Herbs are tile data: `tile.has_herb`. Spread via cursor scan, gated by forest depth.

---

## Visibility System

`tile.is_explored` (permanent) + `tile.visible_count` (current unit count). Recursive shadowcasting per unit, radius `SIGHT_RADIUS` (8). Recompute on tile change only. Double-buffered visibility sets per unit. Reveal events on `visible_count` 0→1.

Vision blockers: trees stage 2+ with ≥1 tree neighbor. Buildings. Rock. First blocker is visible; shadow behind.

---

## Architectural Directives

- **OO, not ECS**
- **Single `unit.lua`** — no split unit files
- **Single global job queue** for all job types including hauling — unified job structure with type-specific fields
- **Two-tier need interrupts** — soft (finish delivery) and hard (immediate). Needs never posted as jobs.
- **Three needs only:** hunger, sleep, recreation. Spirituality is NOT a need.
- **Mood and health are stateless** — recalculated from scratch each hashed update
- **Skill caps on the job, not the unit** — Serfs have no skills at all
- **Workers own their full job cycle** — carrying is part of the job, not a separate hauling task
- **Offloading** — when switching job types while carrying, deposit to nearest stockpile first
- **Single resource type carried at a time** — deposit before starting new work
- **Blueprint-based buildings** — no room detection; interiors are spatial data from config
- **Building placement rules** — most need pathable ground; mines need rock edge; docks need water edge
- **Unified building inventory model** — input/output inventories using slot system; three work patterns (hub gathering, stationary extraction, production crafting)
- **Stockpiles as intermediary** — all redistribution flows through stockpiles, no direct building-to-building
- **Slot-based inventory** — slot_capacity / resource slot_size = units per slot
- **Hauling system posts deficit-based jobs** — validated at claim time
- **Trees and herbs are tile data** — not entities, no IDs, no registry
- **Cursor-based tree/herb updates** — fixed budget per tick, linear scan
- **Shadowcasting visibility** — per unit, recompute on tile change, double-buffered
- **Single-zone map** — 400x200, settlement left, forest right
- **Flat index convention** — `tileIndex(x, y)` for all spatial lookups
- **All rate values stored as per-tick** — use conversion constants in config tables
- **Market delivery model** — merchant walks greedy nearest-neighbor route to homes
- **Deferred deletion** — `is_dead` flag, sweep at end of tick, swap-and-pop removal
- **Hybrid registry** — global hash lookup + per-module typed arrays
- **Local requires per file** — no globals for module references
- **Input abstraction** — game code references actions, not physical keys

---

## Data Structures

### Unit
```lua
unit = {
    id = 0, name = "", tier = Tier.SERF,
    is_dead = false,
    age = 0,
    birth_day = 0, birth_season = 0,
    is_child = true,
    is_attending_school = false,

    is_leader = false, is_regent = false,

    father_id = nil, mother_id = nil,
    child_ids = {}, spouse_id = nil,
    friend_ids = {}, enemy_ids = {},    -- up to 3 each

    attributes = {
        strength = 0, dexterity = 0, intelligence = 0,
        wisdom = 0, charisma = 0,
    },
    skills = {
        -- Freeman and Gentry only. All default 0.
        melee_combat = 0, smithing = 0, hunting = 0, tailoring = 0,
        baking = 0, brewing = 0, construction = 0, scholarship = 0,
        herbalism = 0, medicine = 0, priesthood = 0, barkeeping = 0,
        trading = 0, jewelry = 0, leadership = 0,
    },
    needs = {
        hunger = 100, sleep = 100, recreation = 100,
    },

    mood = 0,
    mood_modifiers = {},    -- { source, value, ticks_remaining }

    health = 100,
    health_modifiers = {},

    carrying = nil,         -- { resource = "logs", amount = 3 } or nil

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
    terrain = "grass",      -- "grass" | "dirt" | "rock" | "water"
    tree = 0,               -- 0=empty, 1=sapling, 2=young, 3=mature
    has_herb = false,
    building_id = nil,
    forest_depth = 0.0,
    is_explored = false,
    visible_count = 0,
    claimed_by = nil,       -- unit_id claiming resource for gathering
}
```

### Job (unified structure)
```lua
job = {
    id = 0,
    type = "chop_tree",      -- keys into JobConfig, or "haul"
    claimed_by = nil,

    -- Regular job fields (nil for hauling)
    x = 0, y = 0,
    target_id = nil,
    progress = 0,

    -- Hauling job fields (nil for regular)
    resource = nil,
    source_id = nil,
    destination_id = nil,
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
    slot_capacity = 20,
    filters = { logs = 4, stone = 4 },
}
```

### Stockpile
```lua
stockpile = {
    id = 0,
    x = 0, y = 0, width = 0, height = 0,
    inventory = { ... },    -- slot count = width * height
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
    width = MAP_WIDTH,
    height = MAP_HEIGHT,
    tiles = {},              -- flat array, tileIndex(x, y)
    buildings = {},          -- array, swap-and-pop deletion
    stockpiles = {},         -- array, swap-and-pop deletion

    spread_cursor = 0,
    growing_tree_data = {},  -- tileIndex → planted_tick
}
```

### Time
```lua
time = {
    speed = Speed.NORMAL,
    is_paused = false,
    accumulator = 0,
    tick = 0,
    minute = 0,
    hour = 6,
    day = 1,
    season = 1,
    year = 1,
}
```

---

## Config Tables

```lua
NeedsConfig = {
    child = {
        hunger     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        sleep      = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 8 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.SERF]    = { hunger = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 }, ... },
    [Tier.FREEMAN] = { hunger = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 }, ... },
    [Tier.GENTRY]  = { hunger = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 }, ... },
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

ResourceSpawnConfig = {
    timber     = { min_depth = 0.0  },
    wildlife   = { min_depth = 0.0  },
    herbs      = { min_depth = 0.01 },
    artifacts  = { min_depth = 0.8  },
}
```

See CONTEXT.md for full BuildingConfig with input/output inventory definitions.
