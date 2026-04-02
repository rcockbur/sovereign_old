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

Love2D callbacks (`update`, `draw`, `keypressed`, etc.) delegate to the game state machine. Only the `playing` state runs the tick accumulator and simulation loop.

---

## Game State Machine

Stack-based state machine in `core/gamestate.lua`. Each state is a table with optional hooks: `enter`, `exit`, `update(dt)`, `draw`, `keypressed`, `mousepressed`, etc. Love2D callbacks delegate to the current state.

| State | Purpose |
|---|---|
| `loading` | One-frame initialization (load configs, build registry). Transitions immediately to `main_menu`. |
| `main_menu` | New Game, Load Game (greyed out until save/load works), Quit. |
| `playing` | The simulation loop. Owns `time`, `simulation`, rendering. Pause/unpause is a flag within this state, not a separate state. |

`gamestate:switch(state)` for flat transitions. `gamestate:push(state)` and `gamestate:pop()` reserved for future modal overlays (pause menu, etc.) — not needed for initial build.

Quit-to-menu from `playing` tears down the current game (clear registry, units, world) and returns to `main_menu`. Quit from `main_menu` calls `love.event.quit()`.

---

## Conventions

### Naming
- `snake_case` for variables and table keys
- `camelCase` for functions
- String identifiers for equality-only checks (modifier sources, skill names, illness names, activity types, crop types, resource types, plant types)
- Integer constants for ordered/comparable values (tier, priority, job tier, plant growth stage)
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
One global incrementing counter for all entity types (units, memories, buildings, jobs, furniture, hauling rules). No collisions possible. A unit's `id` persists when they die and become a memory. Plants (trees, herbs, berry bushes) are tile data, not entities — they do not receive IDs. The counter lives on the registry module (`registry:nextId()`).

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

Returns integers 1 through `MAP_WIDTH * MAP_HEIGHT`. Applied to: tile grid, growing plant data, visibility sets, and all future spatial lookups.

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

-- Plants
SPREAD_TILES_PER_TICK = 50      -- tiles processed per tick by cursor scan
SPREAD_CHANCE         = 0.01    -- probability per eligible spread attempt
SPREAD_RADIUS         = 4       -- manhattan distance for spread target
SEEDLING_GROWTH_TICKS = 0       -- TBD: ticks from seedling to young
YOUNG_GROWTH_TICKS    = 0       -- TBD: ticks from young to mature

-- Visibility
SIGHT_RADIUS = 8

-- Hauling
CARRY_CAPACITY = 10             -- units of any resource per trip, fixed for all units

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

### Log System

Lightweight module (`core/log.lua`) that writes timestamped, categorized messages. Categories: `TIME`, `UNIT`, `JOB`, `WORLD`, `HEALTH`, `HAUL`, `SAVE`, `STATE`. Two outputs: `print()` to the Love2D console during development, and `love.filesystem.write()` to a log file for post-session review.

Global verbosity level: OFF, ERROR, WARN, INFO, DEBUG. Each call: `log:info("UNIT", "Unit %d claimed job %d", unit.id, job.id)`.

The module owns a ring buffer of the last 200 messages for the dev overlay to read — no file I/O needed for display.

### Developer Overlay

Toggled with F3. Draws on top of the game in fixed screen-space. Three sections:

- **Stats bar (always visible when overlay is on):** FPS, current game_time (tick, game_hour, game_day, game_season, game_year), speed, unit count (alive/dead), building count, job queue size (total/unclaimed).
- **Tile inspector (cursor hover):** Tile coordinates, terrain, plant_type/plant_growth, forest_depth, building_id, claimed_by, is_explored, visible_count.
- **Log tail:** Last ~10 log messages scrolling at the bottom.

The overlay reads from game state directly — no special hooks. Pure UI module, never writes to simulation state.

---

## Module Ownership

| Module | Owns |
|---|---|
| **Game State** | State stack, current state, Love2D callback delegation. |
| **Time** | Clock state (tick, game_minute, game_hour, game_day, game_season, game_year). Accumulator and speed. Provides `hashOffset()` utility. Does not know about other systems. |
| **Simulation** | The `onTick` orchestrator. Calls module update functions in order. Owns no data. |
| **World** | Tile grid, buildings (array, swap-and-pop), forest depth map, plant cursor scan, growing plant data, visibility state. Posts jobs to the queue when the world needs work done. |
| **Units** | Unit state: attributes, skills, needs, mood, health, relationships, tier, current activity, carrying, drafted state. Owns the unit update loop (with hash offsets). Also owns creation, death (conversion to memory), promotion/demotion. Owns per-unit visibility sets. `units.all` is an array; swap-and-pop on dead sweep. |
| **Job Queue** | Standalone module. Owns the single flat array of all work tasks (regular jobs and hauling jobs). Swap-and-pop deletion on completion or discard. World and hauling system post jobs; units query and claim them. |
| **Hauling System** | Scans buildings with hauling rules. Posts hauling jobs to the job queue based on push/pull thresholds. Deficit-based job posting. |
| **Dynasty** | Succession logic, leader tracking. Reads from unit relationship graphs. |
| **Events** | Event system (Changeling, Fey encounters, random occurrences, funerals, weddings, Sunday service). Reads from world and units; can modify both. Stub for now. |
| **Registry** | Global lookup: `registry[id]` returns any entity (living unit, memory, building, job). Single hash-table pool. Also owns the global ID counter (`registry:nextId()`). |
| **Log** | Ring buffer of categorized messages. Severity filtering. File output. |
| **Save** | Serialization/deserialization. Collects state from all modules, writes Lua table literal via `love.filesystem`. |
| **Camera** | Camera position (x, y), zoom level. Coordinate conversion (screen ↔ world). |
| **Input** | Input abstraction. Action map (`input:isAction("select")` → checks bound key). |
| **Overlay** | Dev overlay rendering. Reads game state, log ring buffer. |
| **Renderer** | Tile, building, unit rendering. Fog of war. Camera transform. |

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

`time:accumulate(dt)` adds real delta time to an internal accumulator and returns how many ticks should fire this frame based on the current speed setting. `time:advance()` increments the tick counter and updates the clock (game_minute, game_hour, game_day, game_season, game_year). The main loop is the orchestrator — `time` does not know about `simulation`.

At x1 speed, 1 tick fires per frame (60 ticks/sec at 60fps). At x8, 8 ticks fire per frame.

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

1. **Drain needs** (satiation, energy, recreation drain toward 0)
2. **Check hard need interrupts** (drop everything, self-assign behavior) — skipped if `is_drafted`
3. **Check soft need interrupts** (finish current delivery, then self-assign) — skipped if `is_drafted`
4. **Offload check** — if carrying resources and not mid-delivery, deposit first (offloading if job changed)
5. **Poll job queue** — if idle, scan for best available job — skipped if `is_drafted`
6. **Execute work progress** (grow attribute; grow skill if T2/T3 job and below cap)
7. **Recalculate mood** (stateless, from scratch)
8. **Recalculate health** (stateless, from scratch; death check at health <= 0)

Drafted units still drain needs (step 1), recalculate mood and health (steps 7–8), and execute move commands (step 6), but skip need interrupts (steps 2–3) and job polling (step 5). Exception: if energy hits 0, auto-undraft and force sleep regardless.

---

## Map

400x200 tile grid, 1-indexed. Columns 1–200 = settlement area (`forest_depth` 0.0). Columns 201–400 = forest (`forest_depth` increases linearly from 0.0 at column 201 to 1.0 at column 400). `forest_danger` derived on demand as `depth²`.

Terrain types: grass, dirt, rock (impassable), water (impassable). Lakes only, no rivers. No elevation. Single zone, no separate regions.

Tile grid stored as a flat array using `tileIndex(x, y)`.

---

## Plant System

Plants are tile data, not entities. No global ID, no registry entry, no hash-offset updates. Three plant types: tree, herb, berry_bush.

### Plant Fields

```lua
tile.plant_type   = nil       -- nil | "tree" | "herb" | "berry_bush"
tile.plant_growth = 0         -- 0=empty, 1=seedling, 2=young, 3=mature
```

When `plant_growth == 0`, `plant_type` must be `nil`. When `plant_growth > 0`, `plant_type` identifies what's growing.

### Growth Stages

All plant types share the same integer growth stages:

| Stage | Name | Tree | Herb / Berry Bush |
|---|---|---|---|
| 0 | Empty | Passable | Passable |
| 1 | Seedling | Passable, not harvestable | Passable, not harvestable |
| 2 | Young | Blocks pathing, choppable (reduced yield) | Passable, not harvestable |
| 3 | Mature | Blocks pathing, choppable (full yield), can spread | Passable, harvestable, can spread |

Integer stages: for trees, `>= 2` for pathfinding blocking checks. For herbs and berry bushes, no stage blocks pathing.

### Harvest Behavior

- **Trees:** Chopping sets `plant_growth = 0` and `plant_type = nil`. Permanent removal — new trees come only from mature tree spreading.
- **Herbs and berry bushes:** Gathering resets `plant_growth` to 1 (seedling). The plant regrows naturally. Renewable resource if the player doesn't build over them.

### Map Gen Distribution

Settlement area (columns 1–200): sparse small clusters of trees (3–8 trees), scattered berry bushes. Forest area (columns 201–400): dense tree coverage (70–85%) with natural clearings distributed uniformly at all depths. Herbs gated by `forest_depth` per `ResourceSpawnConfig`. Berry bushes found everywhere.

### Lifecycle

Growth timing tracked in `world.growing_plant_data[tileIndex(x, y)] = planted_tick`. Only actively growing plants (stages 1–2) have entries. Removed on promotion to mature. Timestamp resets on each stage promotion.

### Cursor Scan

Single cursor-based scan owned by the world module. Processes `SPREAD_TILES_PER_TICK` (50) tiles per tick, wrapping linearly across the full grid. Full map scan completes every ~27 real seconds at x1.

```lua
function world:updatePlants(time)
    for i = 1, SPREAD_TILES_PER_TICK do
        self.spread_cursor = self.spread_cursor + 1
        if self.spread_cursor > MAP_WIDTH * MAP_HEIGHT then
            self.spread_cursor = 1
        end

        local x, y = tileXY(self.spread_cursor)
        local tile = self.tiles[self.spread_cursor]

        if tile.plant_growth == 1 or tile.plant_growth == 2 then
            self:tryPromote(tile, x, y, time.tick)
        elseif tile.plant_growth == 3 then
            self:trySpread(tile, x, y, time.tick)
        end
    end
end
```

### Spreading

Mature plants (stage 3) pick a random tile within manhattan distance `SPREAD_RADIUS` (4). If the target is empty passable ground (no plant, no building, no rock, no water) and not adjacent to a building, a seedling of the same plant_type is planted with probability `SPREAD_CHANCE` (0.01). Invalid targets are no-ops. Forest plants encroach on the settlement using the same rules.

Plants only spread to their own type — a mature tree spreads tree seedlings, a mature herb spreads herb seedlings, etc.

### Growth Safety Rules

- **Building buffer:** no seedling spreads onto a tile adjacent to a building (checked at spread time).
- **Unit presence:** promotion from seedling to young deferred if a unit is on the tile (trees only — herbs and berry bushes don't block pathing so no deferral needed).
- Units can get trapped by converging tree growth. Accepted as emergent gameplay. Player notified when a unit fails to path to any valid destination.

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
- Trees (`plant_type == "tree"`) at stage 2+ that have at least 1 cardinal neighbor also a tree at stage 2+ block vision. Herbs and berry bushes never block vision.
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

## Drafting (Direct Unit Control)

The player can draft a unit to take direct control, similar to RimWorld.

```lua
unit.is_drafted = false
```

**Behavior when drafted:**
- Unit does **not** poll the job queue
- Unit does **not** respond to need interrupts (soft or hard)
- Needs still drain normally — the simulation doesn't care about drafted status
- Player issues move commands (click-to-move to a tile)
- If the unit was mid-job when drafted, the job is abandoned (progress persists on the job, claim is cleared, job returns to the queue)
- If carrying resources when drafted, they keep carrying — offloading only happens on job type change, and drafting isn't a job
- Drafted units are still visible to other systems (hauling, job system targeting their building, etc.)

**Consequences (emergent from existing systems):**
- Satiation hits 0 → malnourished health modifier starts ticking, unit eventually dies. Player's fault.
- Energy hits 0 → unit auto-undrafts, forces sleep wherever they are (sleeping on the ground, mood penalty). Sleep collapse is involuntary even for drafted units — prevents soft-lock from forgotten drafts.
- Mood still recalculates normally — a drafted, hungry, exhausted unit's mood craters, providing visible feedback.

**Undrafting:** Clears `is_drafted`. Unit resumes normal behavior on next hashed update — checks needs, polls queue, etc.

---

## Unit Death and Cleanup

When a unit dies (`health <= 0`), `is_dead` is set to `true`. The unit is skipped by update loops for the remainder of the tick. All cleanup happens eagerly in `units:sweepDead` at the end of the tick — the game state is fully consistent before the next tick starts.

### sweepDead Cleanup Steps

1. **Convert to memory.** Create a memory object preserving family graph (father_id, mother_id, child_ids, spouse_id, death info).
2. **Update registry.** `registry[id]` now points to the memory instead of the unit.
3. **Social cleanup.** Iterate `units.all`, remove the dead unit's ID from every living unit's `friend_ids` and `enemy_ids`. At 200 units with up to 3+3 each, ~1200 comparisons per death — trivial.
4. **Family references stay.** A living unit's `father_id` pointing to a memory is correct — the relationship is real, the person is just dead. `spouse_id` stays (widow/widower meaningful for mood).
5. **Job cleanup.** If the dead unit had `current_job_id`, clear the job's `claimed_by`. Job returns to unclaimed.
6. **Tile claim cleanup.** If `unit.claimed_tile` is set, clear `world.tiles[unit.claimed_tile].claimed_by`.
7. **Building cleanup.** Remove from `worker_ids` of their assigned building.
8. **Home cleanup.** Remove from household `member_ids`.
9. **Dynasty check.** If `unit.is_leader`, trigger succession.
10. **Remove from `units.all`.** Swap-and-pop.

The social cleanup pass piggybacks on the same `units.all` iteration that finds dead units.

---

## Key Architectural Decisions

**OO, not ECS.** At ~200 units, ECS adds complexity without meaningful performance benefit.

**Composition over inheritance for units.** Tier differences (Serf, Freeman, Gentry) are data differences, not behavioral ones. A single shallow `Unit` prototype with composed tier data. No subclasses — avoids awkward runtime class-swapping on promotion/demotion.

**All skill keys on every unit.** All 15 skill keys present at 0 regardless of tier. Negligible memory cost (~12KB total at 200 units). Promotion from Serf to Freeman doesn't require adding keys. Systems that read skills don't need tier-conditional access. Tier gate is enforced at job eligibility, not at the data level.

**Hash offset updates, not global sweeps.** Entities update via hash offsets (one real-second cadence at x1). All systems for a given entity run in one burst on its assigned tick. No tiered cadence scheduling — one universal interval for everything. Prime multiply on the global ID prevents clustering.

**Direct call chain for simulation.** `simulation:onTick` calls module update functions in explicit order. No event bus, no callback registration. Tick order is visible in one function.

**Frequency scheduling in the simulation loop.** Calendar-driven logic (daily events, seasonal aging, Sunday service) uses modulo checks in `simulation:onTick`, not inside individual systems. Per-entity update logic lives inside each module's hash-offset loop.

**Job queue: polling, not idle notification.** Idle units scan the queue during their hashed update. No event bus needed. Simple, correct, negligible cost at this scale.

**Single global job queue.** Regular jobs and hauling jobs share one flat array. Jobs have a `type` field; type-specific fields coexist on the same table. Units scan the queue filtered by eligibility and personal priority. Tie-breaking by a weighted combination of distance and job age — ensures old jobs at the far edge of the map eventually get claimed. Swap-and-pop deletion on completion or discard.

**Two-tier need interrupts.** Soft interrupts let workers finish current delivery before handling the need. Hard interrupts break immediately. Thresholds configured per need per tier in NeedsConfig. Needs are never posted as jobs.

**Mood and health are stateless.** Both recalculated from scratch on each unit's hashed update. Mood = sum of stored decaying modifiers + calculated modifiers derived from current state. Health = `100 + sum of all health modifier values`, clamped 0–100.

**Skill caps on the job, not the unit.** A unit's skill grows until it hits the current job's `max_skill`. Promotion to a higher-tier job sharing the same skill uncaps further growth. Serfs have no skills at all.

**Config values in per-tick terms.** All rates (drain, damage, recovery) are stored as per-tick values. Conversion constants (`PER_HOUR`, `PER_MINUTE`, etc.) make config tables human-readable. Game_minutes exist as a config unit but are not player-facing.

**Single-zone map.** 400x200 grid. Settlement on the left half (columns 1–200), forest on the right (columns 201–400). Forest depth fixed at map gen, never recalculated. `forest_depth` stored on tile; `forest_danger` derived on demand as `depth²`.

**Plants are tile data, not entities.** Trees, herbs, and berry bushes are lightweight map features that don't need global IDs, registry entries, or hash-offset updates. Reserve the entity/registry system for things that need unique identity and cross-reference.

**Cursor-based plant updates.** Single linear scan processes a fixed budget of tiles per tick. Handles spreading and growth promotion for all plant types in one pass. No per-plant tick cost for the ~30,000 mature forest plants.

**Blueprint-based building.** No room detection. Blueprint claims tiles immediately. Units fetch materials and construct. Building interiors are spatial data (bed positions, etc.) defined in building config and created automatically on construction completion.

**Building placement terrain rules.** Most buildings require all tiles on pathable ground. Mines require one edge entirely on rock. Docks require one edge entirely on water.

**Stockpiles are buildings.** Stockpiles and warehouses are both building types in BuildingConfig. Stockpiles are the one building type where width/height are player-defined at placement (`is_player_sized = true`). No separate `world.stockpiles` array — `world.buildings` is the single array for all placed structures. `slot_capacity` is defined per building type in config, not as a global constant.

**Unified building inventory model.** Production and gathering buildings have separate input and output inventories using the same slot-based model as stockpile/warehouse buildings. Three work patterns (hub gathering, stationary extraction, production crafting) share this model.

**Workers own their full job cycle.** A woodcutter finds a tree, chops, and carries. A builder fetches and builds. A smith fetches input materials, crafts, and carries output if the buffer is full. Workers carry resources as part of their job cycle (carrying), distinct from dedicated hauling jobs.

**Fixed carry capacity.** All units carry `CARRY_CAPACITY` (10) units of any resource per trip. Strength affects hauling speed, not carry amount. This keeps deficit calculations exact.

**Stockpiles as intermediary.** All resource redistribution flows through stockpiles. No direct building-to-building hauling. Production chains go: building output → stockpile → building input.

**Hauling rules on buildings.** Each building has a `hauling_rules` table with push/pull thresholds. BuildingConfig defines sensible defaults per building type (smithy auto-pulls iron, auto-pushes tools). Player can override. The hauling system scans buildings with rules and posts deficit-based jobs. Rules specify the building and threshold only — the hauling system resolves the counterpart (nearest stockpile with capacity/stock) at job-posting time. One hauling job = one trip = one worker.

**Market delivery model.** Merchant walks a greedy nearest-neighbor route delivering consumer goods to homes. Homes that can't be served fall back to self-fetch from stockpiles.

**Spirituality is not a need.** Sunday church service is a scheduled weekly event that applies a decaying mood modifier. No self-interrupt behavior for spirituality.

**Eager death cleanup.** Dying entities get `is_dead = true`. Update loops skip dead entities. `units:sweepDead` runs at the end of each tick — converts to memory, updates registry, cleans up all references (social, job, tile claim, building, household), triggers succession if leader. Game state is fully consistent before the next tick starts.

**Hybrid registry.** `registry[id]` is a global hash lookup for any entity by ID (cross-type references). Each module also maintains typed arrays for iteration (`units.all`, `world.buildings`). Factory functions insert into both.

**Local requires per file.** Each file declares dependencies at the top. No globals for module references.

**Input abstraction.** All input routed through a wrapper module. Game code references actions (`input:isAction("select")`), not physical keys/buttons. Supports future remapping and alternate input methods.

**Game state machine.** Stack-based. Love2D callbacks delegate to current state. Simulation only runs in the `playing` state. Clean teardown on quit-to-menu.

**Pure Lua table serialization.** Save files are Lua table literals written via `love.filesystem`. Versioned format. Each module implements `:serialize()` and `:deserialize()`. Visibility buffers and registry are rebuilt on load, not saved.

---

## Serialization

### What Gets Saved

- **Time** — full clock state (tick, game_minute, game_hour, game_day, game_season, game_year, speed, is_paused)
- **World** — tile grid (terrain, plant_type, plant_growth, forest_depth, building_id, claimed_by; skip visibility fields), spread_cursor, growing_plant_data
- **Units** — all fields on living units except visibility double buffers
- **Memories** — all dead unit memories
- **Buildings** — all fields including inventories, work_in_progress, hauling_rules
- **Households** — all fields
- **Job queue** — all active jobs
- **Dynasty** — leader_id, succession state
- **Registry next_id counter** — so new IDs don't collide
- **Player settings** — building worker_limits, stockpile filters, event speed config

### What Gets Rebuilt on Load (Not Saved)

- Registry hash table (rebuilt by re-inserting all loaded entities)
- Per-unit visibility buffers (rebuilt by running one shadowcast per unit)
- `tile.is_explored` and `tile.visible_count` (rebuilt from unit visibility passes)
- Module typed arrays (`units.all`, `world.buildings`) — rebuilt by re-inserting loaded entities

### Format

Pure Lua table serialization. One save file = one `.lua` file in `love.filesystem.getSaveDirectory()`:

```lua
return {
    version = 1,
    time = { ... },
    tiles = { ... },
    units = { ... },
    memories = { ... },
    buildings = { ... },
    -- etc.
}
```

The `version` field enables format migrations. Tile grid strips default values to reduce file size — most settlement tiles are just `{ terrain = "grass" }`.

---

## Data Structures (Reference)

### Unit
```lua
unit = {
    id = 0, name = "", tier = Tier.SERF,
    is_dead = false,
    is_drafted = false,
    age = 0,                            -- in "life years" (not calendar years)
    birth_day = 0, birth_season = 0,    -- age increments on birth_day of each new game_season
    is_child = true,                    -- age < AGE_OF_ADULTHOOD
    is_attending_school = false,        -- child-only: if true, greys out job priorities

    is_leader = false,

    father_id = nil, mother_id = nil,
    child_ids = {}, spouse_id = nil,
    friend_ids = {}, enemy_ids = {},    -- up to 3 each

    attributes = {
        strength = 0, dexterity = 0, intelligence = 0,
        wisdom = 0, charisma = 0,
    },
    skills = {
        -- All units get all keys at 0. Serfs never grow skills (gate is job eligibility).
        melee_combat = 0, smithing = 0, hunting = 0, tailoring = 0,
        baking = 0, brewing = 0, construction = 0, scholarship = 0,
        herbalism = 0, medicine = 0, priesthood = 0, barkeeping = 0,
        trading = 0, jewelry = 0, leadership = 0,
    },
    needs = {
        satiation = 100, energy = 100, recreation = 100,
    },

    mood = 0,               -- recalculated each hashed update, unbounded
    mood_modifiers = {},    -- { source = "family_death", value = -20, ticks_remaining = 14 * TICKS_PER_DAY }

    health = 100,           -- recalculated each hashed update, clamped 0–100
    health_modifiers = {},  -- injury, illness, malnourished conditions

    carrying = nil,         -- { resource = "logs", amount = 3 } or nil
    claimed_tile = nil,     -- tileIndex of tile this unit has claimed for gathering, or nil

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
    plant_type = nil,        -- nil | "tree" | "herb" | "berry_bush"
    plant_growth = 0,        -- 0=empty, 1=seedling, 2=young, 3=mature
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
    posted_tick = 0,         -- tick when job was posted, used for age-based tie-breaking

    -- Regular job fields (nil for hauling jobs)
    x = 0, y = 0,
    target_id = nil,
    progress = 0,

    -- Hauling job fields (nil for regular jobs)
    resource = nil,          -- "iron", "flour", etc.
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
    interior = {},           -- spatial positions: { { type = "bed", x = 0, y = 0 }, ... }
    crop = nil,              -- farm plots only: "wheat" | "barley" | "flax"

    -- Worker management
    worker_ids = {},         -- currently assigned workers
    worker_limit = 0,        -- player-adjustable, clamped to config max_workers

    -- Inventories (nil if not applicable to building type)
    input = nil,             -- { slots = { ... }, slot_capacity = N }
    output = nil,            -- { slots = { ... }, slot_capacity = N }

    -- Hauling rules (nil if not applicable)
    hauling_rules = nil,     -- { { direction = "push", resource = "logs", threshold = 15 }, ... }

    -- Production state
    work_in_progress = nil,  -- { recipe = "sword", progress = 0, work_required = 1200 } or nil
}
```

### Inventory (shared structure for stockpile/warehouse buildings and building inventories)
```lua
inventory = {
    slots = {
        { resource = "logs", amount = 3 },
        { resource = "iron", amount = 2 },
        { resource = nil, amount = 0 },     -- empty slot
    },
    slot_capacity = 20,      -- defined per building type in BuildingConfig
    filters = {
        logs = 4,            -- max slots allowed for this resource
        stone = 4,           -- default: total slot count (accept all)
    },
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
    width = MAP_WIDTH,       -- 400
    height = MAP_HEIGHT,     -- 200
    tiles = {},              -- flat array, indexed by tileIndex(x, y)
    buildings = {},          -- array, swap-and-pop deletion (includes stockpiles and warehouses)

    -- Plant system
    spread_cursor = 0,
    growing_plant_data = {},  -- keyed by tileIndex(x, y) → planted_tick
}
```

### Time
```lua
time = {
    speed = Speed.NORMAL,
    is_paused = false,
    accumulator = 0,          -- real seconds accumulated toward next tick

    tick = 0,                 -- total ticks since game start
    game_minute = 0,          -- 0–59
    game_hour = 6,            -- 0–23 (game starts at 6am)
    game_day = 1,             -- 1–7
    game_season = 1,          -- 1–4
    game_year = 1,
}
```

---

## Config Tables (Reference)

All constants and config tables live in `/config/`. All rate values are per-tick. Use conversion constants for readability.

### Needs Config

```lua
NeedsConfig = {
    child = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 8 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.SERF] = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.FREEMAN] = {
        satiation  = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
        energy     = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
        recreation = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
    },
    [Tier.GENTRY] = {
        satiation  = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
        energy     = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
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
    -- Storage
    stockpile = {
        is_player_sized = true,     -- width/height set by player at placement
        build_cost = {},             -- free, no construction required
        slot_capacity = 20,
    },
    warehouse = {
        width = 4, height = 4,
        build_cost = { logs = 80, stone = 40 },
        slot_count = 16, slot_capacity = 60,
    },

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
        default_hauling_rules = {
            { direction = "push", resource = "logs", threshold = 15 },
        },
    },
    gatherers_hut = {
        width = 2, height = 2, build_cost = { logs = 15 },
        max_workers = 3,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "berries" } },
        default_hauling_rules = {
            { direction = "push", resource = "berries", threshold = 15 },
        },
    },
    hunting_cabin = {
        width = 2, height = 2, build_cost = { logs = 25 },
        max_workers = 2,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "meat" } },
        default_hauling_rules = {
            { direction = "push", resource = "meat", threshold = 15 },
        },
    },

    -- Stationary extraction (output only, workers produce on site)
    mine = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 30 },
        placement = "rock_edge",
        max_workers = 4,
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "iron", "gold", "silver", "gems" } },
        default_hauling_rules = {
            { direction = "push", resource = "iron", threshold = 15 },
            { direction = "push", resource = "gold", threshold = 5 },
            { direction = "push", resource = "silver", threshold = 5 },
            { direction = "push", resource = "gems", threshold = 5 },
        },
    },
    quarry = {
        width = 3, height = 3, build_cost = { logs = 30 },
        max_workers = 4,
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "stone" } },
        default_hauling_rules = {
            { direction = "push", resource = "stone", threshold = 15 },
        },
    },
    fishing_dock = {
        width = 2, height = 2, build_cost = { logs = 20 },
        placement = "water_edge",
        max_workers = 2,
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "fish" } },
        default_hauling_rules = {
            { direction = "push", resource = "fish", threshold = 15 },
        },
    },

    -- Processing (input + output, workers fetch and craft)
    mill = {
        width = 3, height = 3, build_cost = { logs = 50, stone = 30 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "wheat" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flour" } },
        default_hauling_rules = {
            { direction = "pull", resource = "wheat", threshold = 5 },
            { direction = "push", resource = "flour", threshold = 15 },
        },
    },
    bakery = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 20 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flour" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "bread" } },
        default_hauling_rules = {
            { direction = "pull", resource = "flour", threshold = 5 },
            { direction = "push", resource = "bread", threshold = 15 },
        },
    },
    brewery = {
        width = 3, height = 3, build_cost = { logs = 50, stone = 20 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "barley" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "beer" } },
        default_hauling_rules = {
            { direction = "pull", resource = "barley", threshold = 5 },
            { direction = "push", resource = "beer", threshold = 15 },
        },
    },
    tailors_shop = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 15 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "flax" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "clothing" } },
        default_hauling_rules = {
            { direction = "pull", resource = "flax", threshold = 5 },
            { direction = "push", resource = "clothing", threshold = 15 },
        },
    },
    smithy = {
        width = 3, height = 3, build_cost = { logs = 30, stone = 40 },
        max_workers = 2,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "iron" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "tools", "weapons", "armor" } },
        default_hauling_rules = {
            { direction = "pull", resource = "iron", threshold = 5 },
            { direction = "push", resource = "tools", threshold = 15 },
            { direction = "push", resource = "weapons", threshold = 15 },
            { direction = "push", resource = "armor", threshold = 15 },
        },
    },
    foundry = {
        width = 4, height = 4, build_cost = { logs = 60, stone = 80 },
        max_workers = 2,
        input  = { slot_count = 4, slot_capacity = 20, accepted_resources = { "iron" } },
        output = { slot_count = 4, slot_capacity = 20, accepted_resources = { "steel", "tools", "weapons", "armor" } },
        default_hauling_rules = {
            { direction = "pull", resource = "iron", threshold = 5 },
            { direction = "push", resource = "steel", threshold = 15 },
            { direction = "push", resource = "tools", threshold = 15 },
            { direction = "push", resource = "weapons", threshold = 15 },
            { direction = "push", resource = "armor", threshold = 15 },
        },
    },
    jewelers_workshop = {
        width = 3, height = 3, build_cost = { logs = 40, stone = 30 },
        max_workers = 1,
        input  = { slot_count = 2, slot_capacity = 20, accepted_resources = { "gold", "silver", "gems" } },
        output = { slot_count = 2, slot_capacity = 20, accepted_resources = { "jewelry" } },
        default_hauling_rules = {
            { direction = "pull", resource = "gold", threshold = 5 },
            { direction = "pull", resource = "silver", threshold = 5 },
            { direction = "pull", resource = "gems", threshold = 5 },
            { direction = "push", resource = "jewelry", threshold = 10 },
        },
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
        default_hauling_rules = {
            { direction = "pull", resource = "herbs", threshold = 5 },
        },
    },
    tavern = {
        width = 4, height = 3, build_cost = { logs = 60, stone = 30 },
        max_workers = 1,
        input = { slot_count = 2, slot_capacity = 20, accepted_resources = { "beer" } },
        default_hauling_rules = {
            { direction = "pull", resource = "beer", threshold = 5 },
        },
    },
    school = {
        width = 3, height = 3, build_cost = { logs = 50, stone = 20 },
        max_workers = 1,
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

-- Units per slot = slot_capacity / slot_size
-- e.g. at slot_size 2: 20 / 2 = 10 per stockpile slot, 60 / 2 = 30 per warehouse slot

ResourceSpawnConfig = {
    timber      = { min_depth = 0.0  },
    wildlife    = { min_depth = 0.0  },
    herbs       = { min_depth = 0.01 },
    berry_bush  = { min_depth = 0.0  },
    artifacts   = { min_depth = 0.8  },
}
```

### Production Chains (Reference)

```
-- Food
wheat_farm → wheat → mill → flour → bakery → bread
gatherers_hut → berries
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
