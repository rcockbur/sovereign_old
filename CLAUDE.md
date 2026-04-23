# Sovereign — CLAUDE.md
*v35 · Technical reference for Claude Code and Claude.ai design sessions.*

> **Temporary content:** Config table values and data structure field listings are included in the technical reference files until the corresponding Lua files exist in the repo. Once implemented, trim those sections to shape/intent only — the code becomes the source of truth for specific values and fields.

## Technical Routing Table

Detailed specs live in separate files. Read the relevant file before implementing a system. All files live at the repo root and are attached to the Claude.ai project.

| File | Contents |
|---|---|
| **BEHAVIOR.md** | Tick order, hash offset, per-unit update loops (per-tick and per-hash), action types and handlers, `onActionComplete` priority chain (soft interrupt consumption, offloading dispatch, on-completion poll, activity handler dispatch), need interrupts (soft/hard, availability gating, priority ordering), sleep (time-of-day thresholds, wake check, sleep destination, collapse), home assignment, eating behavior, homeless eating, work day and recreation (work_ticks_remaining, is_done_working, daily reset, tavern visits, wandering), carrying (rules, single-type invariant, weight cap), work cycles (designation, gathering, extraction, processing, farming, construction — site clearing, unit displacement, blueprint transition, builder cycle), production order evaluation, work in progress, equipment want detection (fetch mechanics live in HAULING.md), drafting, unit death cleanup, building deletion cleanup, classes and specialties (promotion, children, activity filtering, skill growth). |
| **HAULING.md** | Request and activity model, generic haul cycle, reservation placement and release timing, activity slot, cleanup, variant catalog (request-based public: filter pull, construction delivery, ground pile cleanup; private transport: self-fetch as head phase, self-deposit as tail phase, merchant delivery; private pickup/use: equipment fetch, eating trip; offloading as recovery path), request → activity conversion, partial-fill chain, worker polling (queue scan + on-completion poll), eligibility validation, carrying interaction. |
| **ECONOMY.md** | Resource entities (stacks, items), containers (bin, tile inventory, stack inventory, item inventory, ground pile), reservation system (mechanism and lifecycle, inviolate-except-player-intervention rule), resources module API, resource counts system, frost and farming (thaw/frost system, per-tile crop state, farm controls, farm activity posting, harvest yield), ground piles (creation, request self-posting, ground drop search algorithm), storage filter system (filter modes, pull mechanics via requests, source resolution, cycle detection), merchant delivery system, firewood production and home heating. |
| **WORLD.md** | Map (dimensions, terrain, forest coverage, forest depth), map generation (noise setup, full pipeline, tuning), pathfinding (A*, tile costs, A* building exemption, movement model, movement speed, collision, failure), building layout (tile types, tile maps, clearing, orientation, placement validation, construction phases, buildings without tile maps, pathfinding integration), plant system (growth stages, spread, cursor scan), visibility (deferred). |
| **TABLES.md** | Game entity data structures (unit, memory, tile, activity, request, production order, work in progress, building, ground pile, world). All config tables (NeedsConfig, SleepConfig, RecreationConfig, MerchantConfig, HousingBinConfig, ActivityConfig, ActivityTypeConfig, SerfChildActivities, RecipeConfig, GrowthConfig, MoodThresholdConfig, MoodModifierConfig, InjuryConfig, IllnessConfig, MalnourishedConfig, ResourceConfig, PlantConfig, CropConfig, BuildingConfig, NameConfig, SettlementNameConfig, Keybinds). Production chains. |
| **UI.md** | UI architecture (module structure, module lifecycle, input routing, draw order, interaction modes), camera, input handling, hotkeys and remappable keybinds, layout (right panel, left panel, bottom bar), selection mechanics, panel contents and variations, command bar, management overlays, notification display. |
| **DEV.md** | Logging system, developer overlay (F3 hotkey, stats bar, tile inspector), TPS tracking, debug spawn (F1), config validation rules, logic tests. Loaded only when work touches dev tooling, the log system, validation, or tests. |
| **CODE_AUDIT.md** | Code audit process: 7 calibrations, 6 silent per-finding sanity checks, finding format, recurring failure modes. Loaded only when an audit prompt directs. |

**BEHAVIOR.md vs HAULING.md vs ECONOMY.md boundary:** BEHAVIOR.md owns what units do — work cycles, action types, need interrupts, sleep, drafting, classes, the `onActionComplete` priority chain. HAULING.md owns the resource-movement system as its own mechanism — request/activity model, generic haul cycle, reservation lifecycle, variant catalog, partial-fill chain, offloading. ECONOMY.md owns what the resource system provides — entities, containers, the resources module API, reservations as a low-level mechanism, the storage filter table, merchant delivery loop, ground pile drop algorithm. When a unit's behavior triggers a haul (need interrupt fires, equipment want fires, work cycle reaches a deposit phase), the trigger lives in BEHAVIOR.md and cross-references HAULING.md for the haul mechanics. When HAULING.md needs reservation primitives or container APIs, it cross-references ECONOMY.md. A task involving unit behavior typically needs BEHAVIOR.md plus TABLES.md, with HAULING.md added when the task involves resource movement. ECONOMY.md is loaded when working on resource infrastructure itself.

**Simulation vs UI split:** BEHAVIOR.md, HAULING.md, ECONOMY.md, WORLD.md, and TABLES.md own everything that would exist in a headless run — rules, state, behavior, formulas. UI.md owns how the player sees and interacts with the simulation — panels, input handling, camera, layout, interaction flows. None of it exists in a headless run.

Claude Code should read the relevant file(s) before starting implementation. Most tasks require TABLES.md plus one other file from the routing table. This file (CLAUDE.md) is always loaded automatically.

## Stack

- **Engine:** Love2D (Lua)
- **Editor:** VS Code
- **Platform:** PC (Windows primary)
- **Population cap:** ~200 units

## Folder Structure

```
src/              -- Love2D root (launch with `love src`)
  main.lua
  app/            -- gamestate machine + state files (application lifecycle)
    gamestate.lua
    loading.lua
    main_menu.lua
    generating.lua
    playing.lua
  core/           -- time, registry, world, simulation, log, save, util
  simulation/     -- units, buildings, activities, resources, filters, dynasty
  config/         -- constants.lua, keybinds.lua, tables.lua, strings.lua
  ui/             -- hub.lua, right_panel, left_panel, action_bar, command_bar, overlays, camera, renderer, dev_overlay
tests/            -- plain Lua tests, run outside Love2D (lua tests/run.lua)
```

Logs do not live in the repo. They write to `logs/` under the Love2D save directory — see DEV.md § Logging.

All requires use paths relative to `src/` (e.g., `require("core.world")`). Build a `.love` archive by zipping the contents of `src/`, not the repo root.

## Entry Point

```lua
-- main.lua
local args = love.arg.parseGameArguments(arg)
ARGS_DEBUG = false
ARGS_AUTO_NEWGAME = false
for _, a in ipairs(args) do
    if a == "--debug" then ARGS_DEBUG = true end
    if a == "--newgame" then ARGS_AUTO_NEWGAME = true end
end

if ARGS_DEBUG then
    require("lldebugger").start()
end

require("config.constants")
require("config.keybinds")
require("config.tables")
require("core.util")

local gamestate = require("app.gamestate")
local loading = require("app.loading")

function love.load()
    gamestate:switch(loading)
end

function love.update(dt) gamestate:update(dt) end
function love.draw() gamestate:draw() end
function love.keypressed(key) gamestate:keypressed(key) end
function love.mousepressed(x, y, button) gamestate:mousepressed(x, y, button) end
function love.mousereleased(x, y, button) gamestate:mousereleased(x, y, button) end
function love.wheelmoved(x, y) gamestate:wheelmoved(x, y) end
```

`main.lua` is pure wiring. Constants, keybinds, and config tables load first as globals (see Constants section, Keybinds in TABLES.md, and Config Tables in TABLES.md). Constants must load before tables since tables reference conversion constants. `core.util` installs `tileIndex`, `tileXY`, and `deepCopy` as globals (see Flat Index Convention and Module Ownership). Love2D callbacks delegate to `app/gamestate.lua`, which forwards to the current state's hooks. The `src/` directory is the Love2D root — launch with `love src` from the repo root.

CLI flags: `--debug` enables the lldebugger startup hook (used by VS Code's lldebugger extension via `launch.json`). `--newgame` bypasses the main menu and jumps directly into world generation — convenience for iterating on simulation without clicking through the menu every launch.

## Game State Machine

Stack-based in `app/gamestate.lua`. Gamestate owns only the stack mechanism — `switch`, `push`, `pop`, and callback forwarding. Each state is a separate file returning a table with hooks: `enter`, `exit`, `update(dt)`, `draw`, `keypressed`, `mousepressed`, `mousereleased`, `wheelmoved`. `gamestate:switch(state)` for transitions. `gamestate:push`/`pop` reserved for future modal overlays.

**State files:**

- `app/loading.lua` — `enter()` runs config validation (see DEV.md § Config Validation). Switches to `main_menu` on success (or to `generating` directly when launched with `--newgame`). Transient state — never runs `update`.
- `app/main_menu.lua` — draws menu, handles input. "New Game" switches to `generating`. "Continue" appears only when a save file exists — loads the most recent save and switches to `playing`. Quit calls `love.event.quit()`.
- `app/generating.lua` — drives map generation as a coroutine (see WORLD.md § Map Generation). Renders a progress bar while generation runs. On completion, switches to `playing`. Transient state.
- `app/playing.lua` — `enter()` initializes the game on a freshly-generated world: `time.init()`, `camera.init()`, `hub.init()`, `units.spawnStarting()`, `resources.rebuildCounts()`. `update()` runs `simulation.onTick()`. Only `playing` runs the simulation.

Transition graph: `loading → main_menu → generating → playing` (or `loading → generating → playing` with `--newgame`).

Quit-to-menu from `playing` tears down the current game (clear `world` and `registry` — see `world.initState()`) and returns to `main_menu`.

## Conventions

NAMING

- `snake_case` for variables and table keys
- `camelCase` for functions
- String identifiers for equality-only checks (modifier sources, skill names, illness names, action types, crop types, resource types, plant types, trait identifiers, class names, specialty names, needs tier names, activity type names, building tile types)
- Integer constants for ordered/comparable values (priority, plant growth stage)
- All boolean fields use `is_`, `has_`, `in_`, or `can_` prefix, no exceptions. `is_` for states/properties, `has_` for possession/presence, `in_` for membership/containment, `can_` for capability/permission.
- Resource names are plural (wood, herbs, berries). Plant and map spawn item names are singular (tree, herb_bush, berry_bush).
- Leave meaningful parameter names on stubs even if they produce unused-variable warnings. Do not suppress with `_` or `_name` — that erases intent.
- Two position representations: bare `x`, `y` fields for an entity's own world position; `_tile` suffix for flat index tile references (from `tileIndex(x, y)`). No `{x, y}` table fields.
- Prefer full descriptive names over abbreviations — `entity` not `e`, `building` not `b`, `activity` not `act`. Short names are only acceptable for well-understood loop indices (`i`, `j`).

FORMATTING

- Always use full indented block style. No single-line `if/then/end`, `for/do/end`, or function bodies — put the body on a new indented line.

ERROR HANDLING

- Prefer hard failures over silent ones — access config tables and variables directly, let Lua throw on nil
- Use `assert` only when a clearer error message is worth the extra line
- Never guard against missing data with `if x then` when missing data indicates a programming error
- Use `== false` instead of `not` — the keyword `not` is easy to miss when reading code, and `== false` makes boolean checks visually explicit

BIDIRECTIONAL REFERENCES

Prefer bidirectional references for entity relationships. Both sides should be maintained on create and destroy.

Examples: `unit.home_id` ↔ `building.housing.member_ids`, `unit.activity_id` ↔ `activity.worker_id`, `unit.claimed_tile` ↔ `tile.claimed_by`, `unit.target_tile` ↔ `tile.target_of_unit`, `unit.bed_index` ↔ `bed.unit_id`, `unit.friend_ids` ↔ counterpart's `friend_ids`, `building.posted_activity_ids` ↔ `activity.workplace_id`.

Rationale: simplifies cleanup (if a building is deleted, its `posted_activity_ids` immediately identifies affected activities and their claimants) and makes traversal straightforward in both directions. Bidirectional refs are appropriate for stable entity relationships — not for transient operational state like private haul activities (those are found via the unit walk during deletion).

IDS

One global incrementing counter for all entity types (units, memories, buildings, activities, stacks, items, ground piles). Counter lives on the registry module: `registry.nextId()`. A unit's `id` persists when they die and become a memory. Plants (trees, herbs, berry bushes) are tile data — no IDs.

CONFIG-TO-RUNTIME NAMING

BuildingConfig uses `default_` prefixed fields for values that are copied to runtime building fields on construction: `default_production_orders` → `building.production.production_orders`. The runtime field drops the `default_` prefix.

CLAUDE CODE GUIDANCE

Read ROADMAP.md at the start of every session. Pay particular attention to the Pending Implementation Tasks section — it is short and may contain entries that intersect with the work being requested.

Claude Code edits only the **Implementation State**, **Pending Implementation Tasks**, and **Implementation Decisions** sections of ROADMAP.md. All other content in all project documents is off-limits without explicit instruction.

When implementation requires a placeholder, stub, or temporary solution because the proper implementation is blocked by later work, follow the TEMP MARKERS convention below.

If implementation reveals a discrepancy or design gap large enough to require design decisions beyond the spec, stop implementing and discuss with the user. Once resolved, record the decision in Implementation Decisions.

TEMP MARKERS

When implementation requires a placeholder, stub, or temporary solution because the proper implementation is blocked by later work, mark the code with a `TEMP(keyword)` comment and add a corresponding entry to the Pending Implementation Tasks section in ROADMAP.md.

Keywords are specific descriptions, not generic labels: `stockpile_color`, `bin_category_field`, `frost_placeholder` — never `temp1` or `placeholder`. There should never be more than one TEMP entry with the same keyword in the codebase at the same time.

Resolving a TEMP requires three steps in the same change: remove the marker from the code, remove the entry from Pending Implementation Tasks, and do the actual work. None of the three is complete until all three are.

Pending Implementation Tasks has two subsections. **Forward Dependencies** are entries that a specific later milestone must satisfy or it will fail. **Cleanup Obligations** are placeholder solutions that should be replaced when the proper implementation arrives.

Example:

```
-- in code:
-- TEMP(stockpile_color): placeholder until proper sprites land

-- in ROADMAP.md Pending Implementation Tasks:
FORWARD DEPENDENCIES
- TEMP(bin_category_field) — Bins must be initialized with a category 
  field matching their role. Expected: p1m19.

CLEANUP OBLIGATIONS
- TEMP(stockpile_color) — Stockpile renders as flat color in the 
  building renderer. Expected: p3.
```

MILESTONE REFERENCES

References to implementation milestones use the `pxmy` format — lowercase `p` and `m` with phase and milestone numbers (e.g. `p1m19`, `p3m05`). Use the most precise form available: `pxmy` when the specific milestone is known, `px` alone when only the phase is known, omit the reference when neither is known with confidence.

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

Module skeleton:

```lua
-- simulation/filters.lua
local world = require("core.world")
local registry = require("core.registry")
local log = require("core.log")

local filters = {}

function filters.scanBuildings(tick)
    -- ...
end

return filters
```

OWNERSHIP MODEL

`world` owns all game state: every entity array, time, magic, settings. Modules own behavior, not data. `units.update(time)` iterates `world.units`. `activities.postActivity(...)` inserts into `world.activities`. Serialization saves `world` and `registry.next_id`. Teardown clears `world` and `registry`.

SWEEP CONVENTION

Units and buildings use deferred deletion with a flag and end-of-tick sweep. Units have `units.sweepDead`. Buildings have `buildings.sweepDeleted` (runs after `units.sweepDead` — see BEHAVIOR.md Building Deletion). Each sweep function handles its own cleanup before removal (clearing inbound references) and calls `registry[entity.id] = nil` followed by swap-and-pop on the `world.*` array. Not a shared utility — each module writes its own loop. The convention is the consistent shape.

Stacks, items, activities, and ground piles use **inline removal** — they are destroyed at the call site when their removal condition is met (stacks at `amount == 0`, items at `durability <= 0`, activities on completion/cancellation, ground piles at `#contents == 0`). The resources module handles stack/item destruction. Activity removal is handled by activity handlers and deletion cleanup. Ground pile removal clears `tile.ground_pile_id` before destroying the entity. All inline removals call `registry[entity.id] = nil` and swap-and-pop on the `world.*` array, same as sweeps.

ARCHITECTURE

- OO, not ECS — at ~200 units, ECS adds complexity without performance benefit.
- Units carry state. Config tables carry rules. Systems read both.
- Class-based behavioral differences live in config tables keyed by class — not on the unit.
- Composition over inheritance for units — class differences are data, not behavior. Single shallow `Unit` prototype. No subclasses — avoids runtime class-swapping on promotion. Single `unit.lua` file.
- All skill keys present on every unit at 0 regardless of class. Serfs and gentry never grow skills. Only specialty freemen and clergy grow skills.
- Hybrid registry: `registry[id]` for cross-type lookup; `world.*` arrays for typed iteration.
- Deferred deletion: `is_dead`/`is_deleted` flag, update loops skip, sweep at end of tick (swap-and-pop). Unit cleanup (social, activity, tile claim, home, bed, dynasty, ground pile drops) happens eagerly in `units.sweepDead`. Building cleanup (unit walk for private hauls, posted activity cleanup, container drops, tile clearing, resident eviction, filter source cleanup) happens eagerly in `buildings.sweepDeleted`.
- All social relationships (friends, enemies) are bidirectional. When unit A befriends unit B, both `A.friend_ids` and `B.friend_ids` are updated. Death cleanup iterates only the dead unit's relationship lists (max 6 lookups), not all living units.
- All rate values stored as per-tick — use conversion constants in config tables.

LUA PERFORMANCE

- **Never create tables in per-tick code.** Reuse buffers, pre-allocate and clear.
- **Flat index for spatial lookups.** Integer keys use Lua's array part (direct C array access).
- **Prefer numeric `for` loops** over `ipairs`/`pairs` in hot paths.
- **Localize globals** in hot files: `local math_floor = math.floor`.
- **No string concatenation for keys.** Use integer-indexed tables or flat index math.

## Constants

All constants in `config/constants.lua`. Loaded once via `require("config.constants")` in `main.lua` before any other module. All values are globals — no per-file require needed.

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
Speed = { NORMAL = 1, FAST = 2, VERY_FAST = 4, ULTRA = 8, TURBO = 32, MAX = 64 }

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
BASE_MOVE_COST       = 40     -- ticks per tile on open ground
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
GROUND_DROP_SEARCH_RADIUS = 2   -- flood fill distance to search for an empty tile when dropping

-- Resource scanning
RESOURCE_SCAN_RADIUS = 100  -- flood fill tile cap for nearest map resource search from buildings

-- Food
FOOD_VARIETY_WINDOW = 3 * TICKS_PER_DAY   -- food types eaten within this window count for variety bonus

-- Work day and recreation
WORK_DAY_RESET_HOUR      = 4     -- is_done_working resets, work_ticks_remaining refills
RECREATION_WANDER_RADIUS = 6     -- tiles from home for wandering recreation

-- Rendering
TILE_SIZE = 32
ZOOM_MIN  = 0.5
ZOOM_MAX  = 2.0

-- Day/season names
DAY_NAMES    = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
SEASON_NAMES = { "Spring", "Summer", "Autumn", "Winter" }
```

## Strings

Display names and descriptions for all game entities live in `config/strings.lua`. Regular module (not globals) — required only by UI code via `local strings = require("config.strings")`. Keyed by entity type and then by internal identifier: `strings.buildings[building_type].name`, `strings.resources[resource_type].name`. Simulation and log code use internal string keys directly — they never need display names.

## Module Ownership

| Module | Owns |
|---|---|
| **Game State** | State stack, current state, Love2D callback delegation. Lives in `app/`. |
| **Time** | Clock behavior: `advance()`, `accumulate(dt)`, `hashOffset()`, `getEnergyThresholds()`. Operates on `world.time`. |
| **Simulation** | The `onTick` orchestrator. Owns no data. |
| **World** | Tile grid, forest depth map, plant system. Owns all entity arrays and game state: `world.units`, `world.buildings`, `world.activities`, `world.stacks`, `world.items`, `world.ground_piles`, `world.time`, `world.magic`, `world.settings`. Ground resource storage is implementation-dependent. Also owns teardown — `world.initState()` clears all `world.*` arrays, walks them to remove registry entries, and resets `registry.next_id`. Called on new game and on quit-to-menu. |
| **Util** | Lives in `core/util.lua`. Installs `tileIndex`, `tileXY`, and `deepCopy` as globals at require time. No state. Required from `main.lua` after constants/keybinds/tables. |
| **Units** | Unit lifecycle and behavior (creation, death, promotion). Operates on `world.units`. |
| **Buildings** | Building updates, deletion cleanup, sweep. Operates on `world.buildings`. |
| **Resources** | Stack/item creation, destruction, transfer, counting. Maintains `world.resource_counts`. Operates on `world.stacks` and `world.items`. |
| **Activity Queue** | Activity posting and filtering logic. Operates on `world.activities`. |
| **Storage Filters** | Filter pull scanning and activity posting. Operates on storage building filter tables. |
| **Magic** | Spell execution. Operates on `world.magic`. |
| **Dynasty** | Succession logic, leader tracking. |
| **Events** | Scheduled and triggered events. |
| **Registry** | Global ID-based lookup across all entity types. Entity creation helper. |
| **Log** | Ring buffer, severity filtering, file output. |
| **Save** | Serialization/deserialization. |
| **Camera** | Position, zoom, coordinate conversion. |
| **UI Hub** | Input routing (mouse and keyboard dispatch), draw ordering, active layer resolution, interaction mode state. Lives in `ui/hub.lua`. |
| **Dev Overlay** | Dev overlay rendering (F3). Pure UI, never writes to simulation. |
| **Renderer** | Tile, building, unit, ground pile rendering. Fog of war. |

## Serialization

Pure Lua table literals via `love.filesystem`. Versioned format. Each module has `.serialize()` / `.deserialize()`.

**Saved:** `world` (all entity arrays: units, buildings, activities, stacks, items, ground_piles; tiles skipping visibility; time, magic, settings), memories, dynasty, `registry.next_id`, player settings.

**Rebuilt on load:** registry hash table (from all `world.*` entity arrays), per-unit visibility buffers, tile.is_explored/visible_count, `world.resource_counts` (via `resources.rebuildCounts()`).

SAVE FILE MANAGEMENT

All save files live under `saves/` in the `love.filesystem` save directory.

**Phase 1 — single quicksave.** One save file at `saves/quicksave.lua`. F5 writes it, F9 loads it (silently ignored if no file exists). Quit-to-menu autosaves to the same file. Main menu shows "Continue" when the file exists.

**Phase 2 — multiple saves.** Manual saves create new files named `saves/<settlement_name>_<timestamp>.lua` (e.g., `saves/oakvale_20260414_143022.lua`). F5 creates a new file each time. Autosave writes to a separate `saves/autosave.lua` at season boundaries. Main menu adds "Load Game" — a list showing settlement name, in-game date, and real-world timestamp, sorted newest first.

SETTLEMENT NAME GENERATION

On new game, a settlement name is randomly generated by combining a random prefix with a random suffix from SettlementNameConfig. Stored in `world.settings.settlement_name`. Used for save file naming starting in Phase 2. The generator lives in `config/` as a data table — no complex logic.

UNIT NAME GENERATION

Random first name from `NameConfig.male` or `NameConfig.female` based on `unit.gender`. Starting units and immigrants receive a random surname from `NameConfig.surname`. Children inherit their father's surname. No duplicate check — repeated names are allowed. UI code composes the full name (`name .. " " .. surname`) for display.