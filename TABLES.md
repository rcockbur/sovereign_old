# Sovereign — TABLES.md
*v23 · Reference data: game entity data structures, config tables, and production chains.*

## Data Structures

UNIT

```lua
unit = {
    id = 0, name = "", surname = "", gender = "male", class = "serf",
    is_dead = false,
    is_drafted = false,
    draft_tile = nil,           -- flat index assigned by command system
    age = 0,                    -- life-years (increments once per season)
    birth_day = 0, birth_season = 0,
    death_age = 0,              -- predetermined at birth, bell curve around ~60
    is_child = true,            -- set to false when age >= AGE_OF_ADULTHOOD during processSeasonalAging

    is_leader = false,
    specialty = nil,            -- "baker" | "priest" | etc., or nil. Career, not a building assignment.
    needs_tier = "meager",      -- "meager" | "standard" | "luxurious"
                                -- Set on creation, updated on promotion.
                                -- meager: all serfs. standard: freemen, priests. luxurious: gentry, bishops.

    father_id = nil, mother_id = nil,
    child_ids = {}, spouse_id = nil,
    friend_ids = {}, enemy_ids = {},    -- up to 3 each, bidirectional

    is_pregnant = false,
    pregnancy_season_count = 0,         -- 0–3, birth at 3 on next sleep

    traits = {},    -- flat array of string identifiers

    genetic_attributes = {
        strength = 0, intelligence = 0, charisma = 0,
    },
    base_attributes = {
        strength = 1, intelligence = 1, charisma = 1,
    },
    acquired_attributes = {
        strength = 0, intelligence = 0, charisma = 0,
    },
    skills = {
        -- All units get all keys at 0. Only specialty freemen/clergy grow skills.
        smithing = 0, smelting = 0, tailoring = 0,
        baking = 0, brewing = 0, teaching = 0, research = 0,
        medicine = 0, priesthood = 0, barkeeping = 0,
        trading = 0,
    },
    skill_progress = {
        -- Per-skill progress toward next level. Mirrors skills keys.
        -- Accumulates 1 per tick during specialty work action.
        -- Threshold: skill_level_ticks * (current_skill + 1). Resets on level-up.
        smithing = 0, smelting = 0, tailoring = 0,
        baking = 0, brewing = 0, teaching = 0, research = 0,
        medicine = 0, priesthood = 0, barkeeping = 0,
        trading = 0,
    },
    needs = {
        satiation = 100, energy = 100, recreation = 100,
        -- Recreation is a mood meter, not a behavioral interrupt.
        -- Drains while awake and not recreating. Recovers during recreation activities.
        -- Does not drain during sleep. See BEHAVIOR.md Work Day and Recreation.
    },

    mood = 0,
    mood_modifiers = {},    -- { source, value, ticks_remaining }

    health = 100,
    health_modifiers = {},

    equipped = {
        tool = nil,             -- item entity id or nil
        clothing = nil,         -- item entity id or nil
    },
    carrying = {},          -- flat array of entity ids (single resource type; see BEHAVIOR.md Carrying)
    claimed_tile = nil,     -- tileIndex of claimed resource tile, or nil

    activity_id = nil,                   -- the unit's current activity (work, haul, need, recreation). One slot, one activity at a time.
    current_action = nil,          -- { type = "travel"|"work"|"sleep"|"idle", ... }
    soft_interrupt_pending = false, -- set by per-hash soft interrupt check, consumed by onActionComplete
    home_id = nil,                  -- building id of housing building
    bed_index = nil,                -- index into home building's housing.beds array, or nil

    -- Work day (see BEHAVIOR.md Work Day and Recreation)
    work_hours = 11,                    -- configurable 10/11/12 by player
    work_ticks_remaining = 0,           -- decrements during work-related states; reset at WORK_DAY_RESET_HOUR
    is_done_working = false,            -- true when work_ticks_remaining hits 0; reset at WORK_DAY_RESET_HOUR
    x = 0, y = 0,
    target_tile = nil,      -- tileIndex of destination (moving) or standing position (stationary)

    -- Food variety tracking
    last_ate = {},          -- { bread = tick, fish = tick, berries = tick } or empty

    -- Movement
    move_progress = 0,
    move_speed = 1.0,       -- recalculated when carrying changes
    path = nil,             -- { tiles = { idx1, idx2, ... }, current = 1 }

    -- Visibility (double buffer, keyed by tileIndex — deferred)
    visible_a = {},
    visible_b = {},
    active_visible = "a",
}
```

```lua
function unit:getAttribute(key)
    return self.base_attributes[key] + self.acquired_attributes[key]
end

function unit:carryableAmount(type)
    local remaining_weight = CARRY_WEIGHT_MAX - resources.countWeight(self.carrying)
    return math.floor(remaining_weight / ResourceConfig[type].weight)
end

function unit:recalcMoveSpeed()
    -- Updates self.move_speed from current carry weight and strength.
    -- Called after any change to self.carrying (carry, drop, deposit, withdraw).
    -- Formula in WORLD.md Movement Speed.
end
```

**Attributes** use three tables. `genetic_attributes` are derived from parents at birth and represent the growth target — capped at `genetic_attribute_max` (7), never change after birth. `base_attributes` track current genetic growth, starting at `{1,1,1}` and growing toward `genetic_attributes` by adulthood. `acquired_attributes` are environmental bonuses, capped at `acquired_attribute_max` (3) per attribute. Effective attribute = `unit:getAttribute(key)` = `base + acquired`. Max effective value is 10. Parent derivation formula and childhood growth curve are pending design (Phase 5).

**Equipment:** Units wear individual items (tools, clothing). Each equipped slot holds an item entity id referencing a first-class item entity in the registry. Units self-fetch equipment from the nearest stockpile or barn when missing a wanted item, preferring higher-quality variants (e.g., steel_tools over iron_tools — ranking mechanism pending). See BEHAVIOR.md Equipment Wants. Items degrade over time — see ECONOMY.md Item for drain rules. When durability reaches 0, the item is destroyed (resource counts updated via `equipped` category) and the unit continues at base effectiveness until a replacement is equipped. Exact drain rates are pending tuning. Additional equipped slots (jewelry, weapon, armor) arrive in later phases.

MEMORY (DEAD UNIT)

```lua
memory = {
    id = 0, name = "", surname = "",
    father_id = nil, mother_id = nil,
    child_ids = {}, spouse_id = nil,
    death_day = 0, death_season = 0, death_year = 0,
    death_cause = "",
}
```

TILE

```lua
tile = {
    terrain = "grass",       -- "grass" | "dirt" | "rock" | "water"
    plant_type = nil,        -- nil | "tree" | "herb_bush" | "berry_bush"
    plant_growth = 0,        -- 0=empty, 1=seedling, 2=young, 3=mature
    building_id = nil,
    building_role = nil,     -- nil | "indoor" | "door" | "impassable"
                             --   Set when tile belongs to a building footprint (with building_id).
                             --   See WORLD.md Building Layout, Pathfinding Edge Connectivity.
    is_clearing = false,     -- true when this tile is any building's derived clearing tile.
                             --   N:1 with buildings (can be shared) — no back-reference stored here.
    ground_pile_id = nil,    -- ground pile entity id, or nil
    forest_depth = 0.0,
    is_explored = false,
    visible_count = 0,
    claimed_by = nil,        -- unit_id claiming resource for gathering
    target_of_unit = nil,    -- unit_id whose target_tile is this tile, or nil
    unit_ids = {},           -- unit ids currently on this tile (maintained on move, spawn, death)
    designation = nil,       -- nil | "chop" | "gather". Set when player marks the tile for collection.
    designation_activity_id = nil,  -- activity id paired with the designation, or nil. Maintained
                             --   alongside designation on post and cancellation. Lets the renderer
                             --   and cancel-designation drag look up the activity in O(1).
}
```

ACTIVITY (UNIFIED STRUCTURE)

```lua
activity = {
    id = 0,
    type = "woodcutter",     -- keys into ActivityTypeConfig, or "haul"
    purpose = "work",        -- "work" | "interrupt" | "recreation"
    worker_id = nil,
    posted_tick = 0,
    is_eligible = true,      -- per-tick eligibility flag, written by activities.validateEligibility().
                             --   Workers skip activities flagged false during scan. Trivially-eligible
                             --   activity types may leave this nil — treated as eligible.

    -- Regular activity fields (nil for hauling)
    x = 0, y = 0,
    workplace_id = nil,      -- building id where work is performed
    progress = 0,

    -- Hauling activity fields (nil for regular)
    resource_type = nil,
    source_id = nil,         -- building id, ground pile id, or nil (unit is carrying — self-deposit phase, offloading)
    destination_id = nil,    -- building id where the unit will deposit, or nil. Always nil for non-haul
                             --   activities. For haul variants, the value is set on post (self-fetch as
                             --   primary head phase, self-deposit as primary tail phase, merchant delivery,
                             --   home food self-fetch as eat sub-step, offloading) or set at request →
                             --   activity conversion (filter pull, construction delivery — destination
                             --   known from the request; ground pile cleanup — destination resolved as
                             --   nearest with capacity at conversion). Pickup/use variants stay nil for
                             --   the duration (equipment fetch, eating trip — use happens at the source).
    is_private = false,      -- true for self-posted activities (self-fetch as head phase, self-deposit
                             --   as tail phase, merchant delivery, home food self-fetch as eat sub-step,
                             --   offloading, equipment fetch, eating trip)

    -- Handler-internal state (set at runtime by activity handlers)
    phase = nil,             -- string or nil. Tracks the activity's internal state machine.
                             --   For haul activities the standard values are "to_source" (after
                             --   claim/reserve, before pickup) and "to_destination" (after pickup,
                             --   before deposit). Other activity types use type-specific phase strings.
                             --   See HAULING.md Phase Strings.
    source_reserved_amount = nil,        -- number or nil. Amount reserved on the source container
                                         --   (`reserved_out`). Set when the source-side reservation is
                                         --   placed; cleared when the withdraw clears the reservation.
                                         --   Cleanup reads this directly to release outstanding source
                                         --   reservations. See HAULING.md Cleanup.
    destination_reserved_amount = nil,   -- number or nil. Amount reserved on the destination container
                                         --   (`reserved_in`). Set when the destination-side reservation
                                         --   is placed; cleared when the deposit clears the reservation.
                                         --   Cleanup reads this directly to release outstanding
                                         --   destination reservations. See HAULING.md Cleanup.
}
```

`type` keys into ActivityTypeConfig, or `"haul"` for hauling activities. `purpose` classifies the activity — see BEHAVIOR.md for how purpose interacts with the work day counter. `is_private` marks self-posted activities — see HAULING.md for the request/activity distinction and the variant catalog.

In normal transport hauls, `source_reserved_amount` and `destination_reserved_amount` track equal values. They diverge only in pickup/use variants (only source is reserved, destination_reserved_amount is nil) and merchant delivery's first trip (source reserves the full carry load, destination reserves only `drop_amount`).

Buildings post activities when they have work available and `#posted_activity_ids < worker_limit`. Building-posted activities (operational, build) are tracked in `building.posted_activity_ids`. Building-posted **requests** (filter pull, construction delivery) are tracked in `building.posted_request_ids`. The activity's `workplace_id` references the building. When a worker claims the activity, they path to the building and work. When the activity completes or the worker leaves, the building may post a new activity.

REQUEST

```lua
request = {
    id = 0,
    type = "filter_pull",        -- "filter_pull" | "construction_delivery" | "ground_pile_cleanup"
    resource_type = nil,         -- the type being moved
    source_id = nil,             -- building id, ground pile id, or nil (resolved at conversion per variant)
    destination_id = nil,        -- building id, or nil (resolved at conversion per variant)
    requested_amount = 0,        -- aggregate need; decremented by each conversion
    posted_tick = 0,             -- for activity scoring
    is_eligible = true,          -- per-tick eligibility flag, written by activities.validateEligibility().
}
```

A request represents an aggregate haul need that may take multiple workers across multiple trips to fulfill. Requests are not claimed in the activity sense — workers convert them into concrete haul activities at claim time, sized to their carry capacity and source availability. Conversion places reservations atomically and decrements `requested_amount` (or removes the request when it hits zero). See HAULING.md Requests vs Activities and HAULING.md Request → Activity Conversion for the full mechanics.

PRODUCTION ORDER

```lua
production_order = {
    recipe = "iron_tools",   -- keys into RecipeConfig
    is_standing = true,      -- true: repeats, checks threshold. false: finite
    amount = 50,             -- standing: global count threshold. finite: remaining crafts.
                             -- -1 = unlimited (standing orders only): always craft, ignore stockpile count.
}
```

WORK IN PROGRESS

```lua
work_in_progress = {
    recipe = "bread",        -- keys into RecipeConfig
    progress = 0,            -- ticks of work completed
}
```

Stored on the building (`building.production.work_in_progress`). See BEHAVIOR.md Processing Work Cycle for persistence behavior.

BUILDING

Buildings use sub-tables to group related fields by function. Factory functions per category populate only the relevant sub-tables — absent sub-tables are nil. Accessing a sub-table that doesn't belong to a building's category produces an immediate nil error, enforcing correctness.

```lua
building = {
    -- Identity (all buildings)
    id = 0, type = "cottage",
    category = "housing",    -- "storage" | "housing" | "farming" | "gathering" | "extraction" | "processing" | "service"
    x = 0, y = 0, width = 0, height = 0,
    orientation = "S",       -- "N" | "S" | "E" | "W" — door facing direction (nil for player-sized and solid buildings)
    clearing_tile = nil,     -- flat tile index of this building's clearing (nil for solid and player-sized buildings).
                             --   Derived at placement time as the tile immediately outward from the door on the door face.
                             --   See WORLD.md Building Layout Clearing.
    phase = "constructing",  -- "blueprint" | "constructing" | "complete"
    is_deleted = false,      -- flagged for deletion, swept at end of tick

    -- Construction (present only while phase ~= "complete", nil after completion)
    construction = {
        bins = {},           -- array of bins (container_type = "bin"): { type, capacity, contents, reserved_in, reserved_out }
                             -- one bin per build_cost type, capacity = exact required amount
        build_ticks = 0,     -- total ticks to complete (computed at placement from BuildingConfig)
        progress = 0,        -- ticks of work completed
    },

    -- Activity and request tracking (all buildings)
    posted_activity_ids = {},     -- every activity this building posted (operational work, build).
                                  -- Used for staffing check (#posted_activity_ids < worker_limit) and deletion cleanup.
                                  -- Construction material delivery is tracked separately via posted_request_ids.
    posted_request_ids = {},      -- every request this building posted (filter pull, construction delivery).
                                  -- Used for deletion cleanup so requests can be removed from world.requests.

    -- Workforce (work-capable categories only: farming, gathering, extraction, processing, service)
    worker_limit = 0,        -- player-adjustable; capped at max_workers from BuildingConfig

    -- Production (processing buildings only)
    production = {
        input_bins = {},         -- array of bins: one per recipe input type
                                 -- capacity from BuildingConfig
        production_orders = {},  -- array of production_order structs
        work_in_progress = nil,  -- { recipe, progress }
    },

    -- Housing
    housing = {
        beds = {},              -- array of { unit_id = nil } — positions from layout, unit_id set on assignment
                                -- APPEND-ONLY: never remove or reorder entries (preserves unit.bed_index)
        member_ids = {},
        bins = {},              -- array of bins: one per food type from HousingBinConfig
                                -- populated at construction
    },

    -- Storage (one container per storage building — type determined by building type)
    -- Stockpiles use tile_inventory, warehouses use stack_inventory, barns use item_inventory.
    -- Callers pass building.storage to the resources module; it dispatches on container_type.
    storage = nil,           -- tile_inventory | stack_inventory | item_inventory (see ECONOMY.md Containers)

    -- Farming
    farming = {
        crop = nil,             -- "wheat" | "barley" | "flax" | nil. Player-selected crop. nil = fallow.
        allow_planting = false, -- toggle. When on, empty tiles are eligible for planting work.
        auto_harvest = "off",   -- "off" | "per_tile" | "per_farm" — see ECONOMY.md Farm Controls
        planted_ticks = {},     -- sparse: planted_ticks[tileIndex] = tick when planted, nil = empty
    },

    -- Market (service building — merchant food delivery state)
    market = {
        last_delivered = {},    -- populated from MerchantConfig food type keys at construction, all starting at 0
    },
}
```

`housing.bins` is one bin per food type from HousingBinConfig. Equipment (tools, clothing) is not stored in housing — units self-fetch from storage buildings. See BEHAVIOR.md Equipment Wants.

`production.input_bins` is one bin per unique input resource type across the building's recipes, with capacity from BuildingConfig.

`market.last_delivered` is keyed by MerchantConfig food types and tracks the tick of the last completed delivery run per food type.

**`worker_limit` vs `max_workers`:** `max_workers` in BuildingConfig is the design-time ceiling. `worker_limit` on the runtime building is the player-adjustable value, defaulting to `max_workers` on construction. The player can lower `worker_limit` but never raise it above `max_workers`.

**`posted_activity_ids` vs `worker_limit`:** `posted_activity_ids` tracks every operational activity the building has posted — both claimed and unclaimed. The activity-posting condition is `#posted_activity_ids < worker_limit`. This correctly reflects staffing even when workers are physically away from the building during the source-fetch head phase or deposit tail phase of a primary activity (see HAULING.md). A worker who leaves to fetch inputs still holds a claimed activity in `posted_activity_ids`, so the building does not double-post. Activities are added to `posted_activity_ids` on posting and removed on activity completion, cancellation, or building deletion.

**`posted_request_ids` vs `posted_activity_ids`:** Requests are aggregate haul needs (filter pull, construction delivery) that haulers convert into trip-sized activities at claim time. Requests live in `world.requests`, not `world.activities`, so they're tracked on the building separately. Deletion cleanup walks both lists. See HAULING.md.

**Building categories and valid sub-tables:**

| Category | Sub-tables present (beyond common) |
|---|---|
| storage | `storage` |
| housing | `housing` |
| farming | `farming` |
| gathering | (none beyond common) |
| extraction | (none beyond common) |
| processing | `production` |
| service | building-specific fields (`max_students`, `market`, etc.) |

Common fields on all buildings: `id`, `type`, `category`, `x`, `y`, `width`, `height`, `orientation`, `phase`, `is_deleted`, `posted_activity_ids`, `posted_request_ids`. Constructing: `construction` sub-table. Buildings with workers (categories: farming, gathering, extraction, processing, service) additionally have `worker_limit`. Storage and housing buildings have no `worker_limit` — workers don't *work at* a stockpile or a cottage. Player-sized buildings and solid buildings have no `orientation`.

**Construction:** Building placement creates a building entity with `phase = "complete"` (P1, instant placement — no construction sub-table) or `phase = "constructing"` / `"blueprint"` (P2, when the construction system comes online) and populates a `construction` sub-table. See BEHAVIOR.md Construction Work Cycle for the full behavioral sequence.

**Building deletion:** The player marks a building for deletion by setting `is_deleted = true`. Deletion is processed at end of tick in `buildings.sweepDeleted`, after `units.sweepDead`. See BEHAVIOR.md Building Deletion for the full cleanup sequence.

**Placement constraints:** See WORLD.md Building Layout for placement validation rules.

**Home and bed assignment:** Automatic. See BEHAVIOR.md Home Assignment for rules. The `beds` array is **append-only** — entries are never removed or reordered, preserving `unit.bed_index` validity. When a unit vacates a bed, clear `bed.unit_id` but leave the entry in place.

**Crop change:** Changing crop destroys planted tiles. See ECONOMY.md Farm Controls.

**Extraction:** No depletion. See BEHAVIOR.md Gathering Work Cycle (extraction variant).

**Storage filter system and container type constraints** (stockpile/warehouse/barn): see ECONOMY.md Storage Filter System and Containers.

GROUND PILE

```lua
ground_pile = {
    container_type = "ground_pile",
    count_category = "ground",
    id = 0,
    x = 0, y = 0,
    contents = {},       -- flat array of entity ids (stacks and items mixed)
    reserved_out = 0,    -- amount spoken for by haulers claiming pickup activities
}
```

Holds a flat array of entity ids (stacks and items mixed). No capacity enforcement, no filters. The tile references the ground pile entity via `tile.ground_pile_id`. See ECONOMY.md Ground Piles for creation, self-posting, and the ground drop search algorithm.

WORLD

```lua
world = {
    seed = 0,                -- integer, set at world creation, used for deterministic map generation
    width = MAP_WIDTH,
    height = MAP_HEIGHT,
    tiles = {},

    -- All entity arrays (world owns all game state)
    units = {},
    buildings = {},
    activities = {},
    requests = {},
    stacks = {},
    items = {},
    ground_piles = {},

    -- Plant system
    spread_cursor = 0,
    growing_plant_data = {},

    -- Resource counts — see ECONOMY.md Resource Counts for category definitions and maintenance rules
    resource_counts = {
        storage = {},
        storage_reserved = {},
        processing = {},
        housing = {},
        construction = {},
        ground = {},
        carrying = {},
        equipped = {},
    },

    -- Game state (formerly standalone modules)
    time = {
        speed = Speed.NORMAL,
        is_paused = false,
        accumulator = 0,
        tick = 6 * TICKS_PER_HOUR,    -- 6 AM start
        game_minute = 0,
        game_hour = 6,
        game_day = 1,
        game_season = 1,
        game_year = 1,
        -- Frost system (rolled at year start)
        thaw_day = 0,           -- spring day when ground thaws (planting becomes possible)
        frost_day = 0,          -- autumn day when frost arrives (unharvested crops begin decaying)
        is_frost = true,        -- true when outside the thaw→frost growing window
    },

    magic = {
        divine_mana = 0,
        divine_mana_max = 100,      -- TBD
        arcane_mana = 0,
        arcane_mana_max = 100,      -- TBD
        divine_unlocked = false,
        arcane_unlocked = false,
    },

    settings = {
        settlement_name   = "",        -- randomly generated on new game
        combat_gender     = "male",    -- "male" | "both" | "female"
        clergy_gender     = "male",    -- "male" | "both" | "female"
        succession_priority = "male",  -- "male" | "both" | "female"
    },
}
```

A season is 7 days. `game_day` (1–7) is both the day-of-season and the weekday index into `DAY_NAMES`. The terms "week" and "season" refer to the same 7-day period; "season" is used everywhere.

## Config Tables

```lua
-- Three needs tiers: meager (serfs), standard (freemen, priests), luxurious (gentry, bishops).
-- Satiation is uniform across all tiers. Energy differs by tier for mood (higher tiers are
-- unhappier when tired). Recreation: mood meter, not a behavioral interrupt (see BEHAVIOR.md
-- Work Day and Recreation); only mood_threshold and mood_penalty live here per tier.
-- Lookup: NeedsConfig[unit.needs_tier]
--
-- Energy is uniform across all tiers for drain and hard_threshold. The soft threshold for
-- energy is time-of-day rather than per-tier — see SleepConfig and BEHAVIOR.md Sleep.
-- Satiation soft_threshold is flat at 75 (not time-varying). See BEHAVIOR.md Need Interrupts.
NeedsConfig = {
    meager = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 75, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 4 * PER_HOUR,                      hard_threshold = 10, mood_threshold = 30, mood_penalty = -10 },
        recreation = { mood_threshold = 30, mood_penalty = -10 },
    },
    standard = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 75, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 4 * PER_HOUR,                      hard_threshold = 10, mood_threshold = 50, mood_penalty = -15 },
        recreation = { mood_threshold = 50, mood_penalty = -15 },
    },
    luxurious = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 75, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 4 * PER_HOUR,                      hard_threshold = 10, mood_threshold = 60, mood_penalty = -20 },
        recreation = { mood_threshold = 60, mood_penalty = -20 },
    },
}

-- Sleep mechanics. Recovery is the per-tick energy gain while in the sleep action.
-- Soft and wake thresholds vary by time of day — looked up via time.getEnergyThresholds().
-- Four periods divide the day (constants in CLAUDE.md):
--   Night    NIGHT_START → MORNING_START      flat night values
--   Morning  MORNING_START → DAY_START        lerp night → day
--   Day      DAY_START → EVENING_START        flat day values
--   Evening  EVENING_START → NIGHT_START      lerp day → night
-- Both thresholds are continuous everywhere — every band boundary is flat-to-lerp or lerp-to-flat.
-- See BEHAVIOR.md Sleep for the full behavior.
SleepConfig = {
    recovery_rate = 8 * PER_HOUR,
    night = { soft = 50, wake = 100 },
    day   = { soft = 20, wake = 85  },
}

-- Recreation: mood meter, not a behavioral interrupt. See BEHAVIOR.md Work Day and Recreation.
-- Mood thresholds live in NeedsConfig per tier.
RecreationConfig = {
    work_drain      = 4.55 * PER_HOUR,    -- drains while awake and not recreating
    recovery_rate   = 10 * PER_HOUR,       -- base rate; subject to diminishing returns
    -- Diminishing returns formula TBD during tuning. Effective recovery =
    -- recovery_rate * diminishing_factor(current_recreation).
}

-- Children use their class's needs tier (no separate child profile).
-- Serf children use meager, freeman children use standard, gentry children use luxurious.

MerchantConfig = {
    carry_capacity = 64,                       -- merchant's carry cap (overrides CARRY_WEIGHT_MAX)
    idle_ticks_base = 2 * TICKS_PER_HOUR,      -- reduced by trading skill
    drop_amount = 2,
    critical_threshold = 2,     -- per member, total food across all types
    serious_threshold = 4,      -- per member, total food across all types

    -- Per-type bin thresholds — merchant considers homes below these as eligible for standard runs
    -- Values are per member (multiplied by household size)
    bin_threshold = {
        bread = 6, berries = 6, fish = 6,
    },
}

-- Housing bin definitions — built dynamically on housing construction.
-- One bin per entry. Food bins use weight-based capacity (stackable).
-- Equipment (tools, clothing) is not stored in housing — units self-fetch from storage.
HousingBinConfig = {
    { type = "bread",       capacity = 128 },
    { type = "berries",     capacity = 128 },
    { type = "fish",        capacity = 128 },
}

ActivityConfig = {
    age_weight = 0.2,   -- score = age_weight * (current_tick - posted_tick) - manhattan_distance
                        -- 5 ticks of waiting = 1 tile of extra reach
}

-- Unified activity type config. is_specialty = false means any serf can do it.
-- is_specialty = true means only a freeman/clergy with matching unit.specialty.
--
-- work_source determines where work_ticks comes from:
--   "plant"  — PlantConfig[plant_type].harvest_ticks (woodcutter, gatherer, herbalist)
--   "recipe" — RecipeConfig[recipe].work_ticks (miller, baker, brewer, tailor, smith, smelter)
--   "crop"   — CropConfig[crop].plant_ticks or .harvest_ticks depending on current work (farmer)
--   "activity"    — work_ticks on this ActivityTypeConfig entry (iron_miner, stonecutter, fisher)
--   "target" — target building's build_ticks (builder)
--   nil      — no work_ticks, ongoing service (hauler, priest, bishop, teacher, barkeep, merchant, physician)
ActivityTypeConfig = {
    -- Unskilled (any serf)
    hauler       = { is_specialty = false, attribute = "strength" },
    woodcutter   = { is_specialty = false, attribute = "strength",     work_source = "plant" },
    iron_miner   = { is_specialty = false, attribute = "strength",     work_source = "activity", work_ticks = 2 * TICKS_PER_HOUR },
    stonecutter  = { is_specialty = false, attribute = "strength",     work_source = "activity", work_ticks = 2 * TICKS_PER_HOUR },
    miller       = { is_specialty = false, attribute = "strength",     work_source = "recipe" },
    builder      = { is_specialty = false, attribute = "intelligence", work_source = "target" },
    farmer       = { is_specialty = false, attribute = "intelligence", work_source = "crop" },
    fisher       = { is_specialty = false, attribute = "intelligence", work_source = "activity", work_ticks = 2 * TICKS_PER_HOUR },
    gatherer     = { is_specialty = false, attribute = "intelligence", work_source = "plant" },
    herbalist    = { is_specialty = false, attribute = "intelligence", work_source = "plant" },

    -- Specialty — freeman
    smith        = { is_specialty = true, class = "freeman", attribute = "strength",     skill = "smithing",     max_skill = 10, work_source = "recipe" },
    smelter      = { is_specialty = true, class = "freeman", attribute = "strength",     skill = "smelting",     max_skill = 10, work_source = "recipe" },
    tailor       = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "tailoring",    max_skill = 10, work_source = "recipe" },
    baker        = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "baking",       max_skill = 10, work_source = "recipe" },
    brewer       = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "brewing",      max_skill = 10, work_source = "recipe" },
    teacher      = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "teaching",     max_skill = 10 },
    scholar      = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "research",     max_skill = 10 },
    physician    = { is_specialty = true, class = "freeman", attribute = "intelligence", skill = "medicine",     max_skill = 10 },
    barkeep      = { is_specialty = true, class = "freeman", attribute = "charisma",     skill = "barkeeping",   max_skill = 10 },
    merchant     = { is_specialty = true, class = "freeman", attribute = "charisma",     skill = "trading",      max_skill = 10 },

    -- Specialty — clergy
    priest       = { is_specialty = true, class = "clergy",  attribute = "charisma",     skill = "priesthood",   max_skill = 10 },
    bishop       = { is_specialty = true, class = "clergy",  attribute = "charisma",     skill = "priesthood",   max_skill = 10 },
}

SerfChildActivities = { "hauler", "farmer", "gatherer", "fisher" }

RecipeConfig = {
    flour           = { input = { wheat = 1 },              output = { flour = 1 },           work_ticks = 30 * TICKS_PER_MINUTE },
    bread           = { input = { flour = 1 },              output = { bread = 1 },           work_ticks = 1 * TICKS_PER_HOUR },
    beer            = { input = { barley = 1 },             output = { beer = 1 },            work_ticks = 1 * TICKS_PER_HOUR },
    plain_clothing  = { input = { flax = 2 },               output = { plain_clothing = 1 },  work_ticks = 2 * TICKS_PER_HOUR },
    steel           = { input = { iron = 2, firewood = 4 }, output = { steel = 1 },           work_ticks = 2 * TICKS_PER_HOUR },
    iron_tools      = { input = { iron = 2 },               output = { iron_tools = 1 },      work_ticks = 2 * TICKS_PER_HOUR },
    steel_tools     = { input = { steel = 2 },              output = { steel_tools = 1 },     work_ticks = 2 * TICKS_PER_HOUR },
}

GrowthConfig = {
    -- Skill growth: progress accumulates per tick during specialty work action.
    -- Threshold to reach next level = skill_level_ticks * (current_skill + 1).
    -- On reaching threshold: skill increments by 1, progress resets to 0.
    -- Growth stops at max_skill from ActivityTypeConfig.
    -- Mastery (skill 10) takes ~35 seasons of dedicated work (~age 51 if promoted at 16).
    skill_level_ticks = 70000,

    -- Attribute caps
    -- Genetic cap is the ceiling for inherited attributes. Acquired cap is the ceiling for
    -- environmental bonuses (school, future systems). Max effective = genetic + acquired = 10.
    genetic_attribute_max      = 7,
    acquired_attribute_max     = 3,
    school_intelligence_gain   = 0,     -- TBD: total bonus by adulthood, max 3
}

MoodThresholdConfig = {
    inspired   = 80,    -- 80+: productivity bonus
    content    = 40,    -- 40–80: no effect (baseline)
    sad        = 20,    -- 20–40: slight productivity penalty
    distraught = 0,     -- 0–20: productivity penalty + chance for deviancy
                        -- below 0: defiant — won't work, high chance for deviancy
}

MoodModifierConfig = {
    -- Calculated modifiers (derived fresh each update)
    no_home               = -20,
    food_variety_bonus    =   5,        -- per food type beyond the first eaten within FOOD_VARIETY_WINDOW
    has_clothing          =   5,
    no_clothing           = -15,
    low_health            = -10,        -- applied when health < 50
    -- Recreation mood penalty uses NeedsConfig[tier].recreation.mood_threshold and mood_penalty.
    -- Applied when recreation < mood_threshold. No bonus for high recreation.

    -- Stored modifiers (event-driven, with ticks_remaining)
    family_death          = { value = -20, duration = 14 * TICKS_PER_DAY },
    friend_death          = { value = -10, duration = 7 * TICKS_PER_DAY },
    marriage              = { value =  20, duration = 14 * TICKS_PER_DAY },
    specialty_revoked     = { value = -15, duration = 7 * TICKS_PER_DAY },
    sunday_service_base   = { value =  10, duration = 7 * TICKS_PER_DAY },    -- scaled by priest skill
    funeral_attended      = { value =   5, duration = 3 * TICKS_PER_DAY },
    wedding_attended      = { value =   5, duration = 3 * TICKS_PER_DAY },
    beer_consumed         = { value =  10, duration = 1 * TICKS_PER_DAY },
}

InjuryConfig = {
    bruised = { initial_damage = 10, recovery = 0.5 * PER_HOUR  },
    wounded = { initial_damage = 30, recovery = 0.2 * PER_HOUR  },
    maimed  = { initial_damage = 50, recovery = 0.05 * PER_HOUR },
}

IllnessConfig = {
    cold        = { damage = 0.1 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4 * PER_HOUR  },
    flu         = { damage = 0.2 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4 * PER_HOUR  },
    flux        = { damage = 0.4 * PER_HOUR, recovery_chance = 0.10,  recovery = 0.3 * PER_HOUR  },
    consumption = { damage = 0.1 * PER_HOUR, recovery_chance = 0.005, recovery = 0.2 * PER_HOUR  },
    pox         = { damage = 0.3 * PER_HOUR, recovery_chance = 0.02,  recovery = 0.2 * PER_HOUR  },
    pestilence  = { damage = 0.5 * PER_HOUR, recovery_chance = 0.01,  recovery = 0.15 * PER_HOUR },
}

MalnourishedConfig = { damage = 0.3 * PER_HOUR, recovery = 0.5 * PER_HOUR }

-- Unified resource config. is_stackable determines entity type (stack vs item).
-- Stackable resources are fungible (split, merge, no per-unit state). Weight determines both
-- carrying cost and storage density — a resource's weight is used against carry capacity and
-- container capacity alike.
-- Non-stackable resources are items (unique entities with durability, future quality/enchantment).
-- Items use count-based storage — one item per stockpile tile or bin entry. See ECONOMY.md Containers.
-- Optional fields: nutrition (food), tool_bonus (tools), max_durability (items).
ResourceConfig = {
    -- Construction (stackable)
    wood            = { weight = 4, is_stackable = true },
    stone           = { weight = 4, is_stackable = true },

    -- Metals (stackable)
    iron            = { weight = 4, is_stackable = true },
    steel           = { weight = 4, is_stackable = true },

    -- Fuel (stackable)
    firewood        = { weight = 4, is_stackable = true },

    -- Crops (stackable)
    wheat           = { weight = 1, is_stackable = true },
    barley          = { weight = 1, is_stackable = true },
    flax            = { weight = 1, is_stackable = true },

    -- Processed crops (stackable)
    flour           = { weight = 1, is_stackable = true },

    -- Food (stackable, with nutrition — all food is weight 4, nutrition 24)
    bread           = { weight = 4, is_stackable = true, nutrition = 24 },
    berries         = { weight = 4, is_stackable = true, nutrition = 24 },
    fish            = { weight = 4, is_stackable = true, nutrition = 24 },

    -- Other consumables (stackable)
    beer            = { weight = 4, is_stackable = true },
    herbs           = { weight = 1, is_stackable = true },

    -- Equipment (items — non-stackable, with durability)
    plain_clothing  = { weight = 1, is_stackable = false, max_durability = 100 },
    iron_tools      = { weight = 2, is_stackable = false, max_durability = 100, tool_bonus = 3 },
    steel_tools     = { weight = 2, is_stackable = false, max_durability = 200, tool_bonus = 5 },
}

PlantConfig = {
    tree = {
        min_depth = 0.0,
        seedling_ticks = 1 * TICKS_PER_SEASON,
        young_ticks = 2 * TICKS_PER_SEASON,
        harvest_ticks = 1 * TICKS_PER_HOUR,
        harvest_yield = 4,
        spread_chance = 0.01,
        spread_radius = 4,
    },
    herb_bush = {
        min_depth = 0.0,
        seedling_ticks = math.floor(0.5 * TICKS_PER_SEASON),
        young_ticks = math.floor(0.5 * TICKS_PER_SEASON),
        harvest_ticks = 4 * TICKS_PER_HOUR,
        harvest_yield = 0,      -- TBD: herbs have no consumer until Phase 4
        spread_chance = 0.01,
        spread_radius = 4,
    },
    berry_bush = {
        min_depth = 0.0,
        seedling_ticks = math.floor(0.5 * TICKS_PER_SEASON),
        young_ticks = math.floor(0.5 * TICKS_PER_SEASON),
        harvest_ticks = 1 * TICKS_PER_HOUR,
        harvest_yield = 4,
        spread_chance = 0.01,
        spread_radius = 4,
    },
}

CropConfig = {
    -- growth_ticks: time from planted_tick to 1.0 maturity. Crops differ — wheat is slowest/riskiest,
    -- flax is fastest/safest. Maturity per tile = clamp((current_tick - planted_tick) / growth_ticks, 0, 1).
    -- yield_per_tile: output at 1.0 maturity. Partial harvest = floor(yield_per_tile * maturity).
    -- 1:1:1 conversion through the bread chain: 1 wheat → 1 flour → 1 bread. Each unit of wheat
    -- represents one potential unit of bread, making food assessment intuitive.
    wheat  = { plant_ticks = 15 * TICKS_PER_MINUTE, harvest_ticks = 30 * TICKS_PER_MINUTE, growth_ticks = 0, yield_per_tile = 8 },   -- growth_ticks TBD (longest)
    barley = { plant_ticks = 15 * TICKS_PER_MINUTE, harvest_ticks = 30 * TICKS_PER_MINUTE, growth_ticks = 0, yield_per_tile = 6 },   -- growth_ticks TBD (medium)
    flax   = { plant_ticks = 15 * TICKS_PER_MINUTE, harvest_ticks = 30 * TICKS_PER_MINUTE, growth_ticks = 0, yield_per_tile = 10 },  -- growth_ticks TBD (shortest)
}
```

PRODUCTION CHAINS

| Chain | Flow |
|---|---|
| Bread | Farm (farmer) → wheat → Mill (miller) → flour → Bakery (baker) → bread |
| Berries | Gatherer's Hut (gatherer) → berries |
| Fish | Fishing Dock (fisher) → fish |
| Herbs (pending) | Herbalist's Hut (herbalist) → herbs → Apothecary (physician) → physician travels to patient |
| Beer | Farm (farmer) → barley → Brewery (brewer) → beer |
| Plain clothing | Farm (farmer) → flax → Tailor's Shop (tailor) → plain clothing |
| Iron tools | Iron Mine (iron_miner) → iron → Smithy (smith) → iron tools |
| Steel | Iron Mine (iron_miner) → iron + Firewood → Bloomery (smelter) → steel |
| Steel tools | Steel → Smithy (smith) → steel tools |
| Firewood | Woodcutter's Camp (woodcutter) → wood → Chopping Block (TBD) → firewood |
| Stone | Quarry (stonecutter) → stone |
| Wood | Woodcutter's Camp (woodcutter) → wood |

BUILDING CONFIG

Phase 1 building layouts (tile maps, layout positions, dimensions) are authored. Remaining buildings (Phase 2+) have placeholder sizes and empty tile maps — exact layouts will be authored as they come online in later phases. Sizes may increase to accommodate interiors (especially community buildings: tavern).

Input bin and storage capacity values are in weight units. Capacity per resource type = `floor(capacity / ResourceConfig[type].weight)`.

```lua
BuildingConfig = {
    -- Storage
    -- Storage-specific config lives under a storage key. The factory function reads config.storage
    -- and builds the appropriate container type for building.storage at runtime.
    -- Filters are a runtime field (initialized to {}), not a config value.
    stockpile = {
        category = "storage",
        is_player_sized = true,
        build_cost = {},
        build_ticks_per_tile = 15 * TICKS_PER_MINUTE,
        storage = { tile_capacity = STOCKPILE_TILE_CAPACITY },
    },
    warehouse = {
        category = "storage",
        width = 4, height = 4,
        build_cost = { wood = 60, stone = 40 },
        build_ticks = 12 * TICKS_PER_HOUR,
        storage = { is_stackable_only = true, capacity = WAREHOUSE_CAPACITY },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
    barn = {
        category = "storage",
        width = 4, height = 3,       -- TBD
        build_cost = { wood = 50, stone = 30 },
        build_ticks = 10 * TICKS_PER_HOUR,
        storage = { is_items_only = true, item_capacity = 40 },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },

    -- Housing (food stored in typed bins from HousingBinConfig)
    cottage = {
        category = "housing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 6 * TICKS_PER_HOUR,
        tile_map = {
            "I", "I", "I",
            "I", "I", "I",
            "I", "D", "I",
        },
        layout = {
            beds = {
                { x = 0, y = 0 }, { x = 2, y = 0 },
                { x = 0, y = 1 }, { x = 2, y = 1 },
            },
        },
    },
    house = {
        category = "housing",
        width = 4, height = 3,    -- TBD: may increase
        build_cost = { wood = 60, stone = 40 },
        build_ticks = 10 * TICKS_PER_HOUR,
        tile_map = {},   -- TBD
        layout = { beds = {} },   -- TBD
    },
    manor = {
        category = "housing",
        width = 5, height = 4,
        build_cost = { wood = 100, stone = 80 },
        build_ticks = 14 * TICKS_PER_HOUR,
        tile_map = {},   -- TBD
        layout = { beds = {} },   -- TBD
    },

    -- Farming (frost-gated growing season, area-based yield, player-selected crop)
    -- Open area — no tile_map. Uses access_edge instead of door orientation.
    -- Per-tile state: planted_tick (set when farmer finishes planting). Maturity derived.
    farm = {
        category = "farming",
        is_player_sized = true,
        build_cost = { wood = 10 },
        build_ticks_per_tile = 15 * TICKS_PER_MINUTE,
        max_workers = 4,
        activity_type = "farmer",
        -- crop set by player: "wheat" | "barley" | "flax" | nil (fallow)
        -- per-crop plant_ticks, harvest_ticks, growth_ticks, and yield_per_tile live in CropConfig
        -- farm controls: allow_planting (toggle), auto_harvest (off/per_tile/per_farm), "Harvest Now" button
    },

    -- Hub gathering (see WORLD.md Solid Buildings)
    -- Activity posting gated on unclaimed valid target count (see BEHAVIOR.md Gathering Work Cycle).
    woodcutters_camp = {
        category = "gathering",
        width = 2, height = 2,
        build_cost = { wood = 20 },
        build_ticks = 4 * TICKS_PER_HOUR,
        max_workers = 4,
        activity_type = "woodcutter",
        tile_map = {
            "X", "X",
            "X", "X",
        },
        layout = {},
    },
    gatherers_hut = {
        category = "gathering",
        width = 2, height = 2,
        build_cost = { wood = 15 },
        build_ticks = 4 * TICKS_PER_HOUR,
        max_workers = 4,
        activity_type = "gatherer",
        tile_map = {
            "X", "X",
            "X", "X",
        },
        layout = {},
    },
    herbalists_hut = {
        category = "gathering",
        width = 2, height = 2,
        build_cost = { wood = 15 },
        build_ticks = 4 * TICKS_PER_HOUR,
        max_workers = 4,
        activity_type = "herbalist",
        tile_map = {
            "X", "X",
            "X", "X",
        },
        layout = {},
    },

    -- Stationary extraction (worker stays at building, output accumulates, no depletion)
    fishing_dock = {
        category = "extraction",
        width = 3, height = 3,
        build_cost = { wood = 20 },
        build_ticks = 6 * TICKS_PER_HOUR,
        placement = "water",
        max_workers = 3,
        activity_type = "fisher",
        tile_map = {
            "I", "I", "I",
            "I", "I", "I",
            "I", "D", "I",
        },
        layout = {
            workstation = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 2, y = 0 } },
        },
        -- Back row on water, front row on grass/dirt. 2 tiles behind back row must also be water.
    },
    iron_mine = {
        category = "extraction",
        width = 3, height = 3,    -- TBD: may increase to 4x3 for interior space
        build_cost = { wood = 40, stone = 30 },
        build_ticks = 10 * TICKS_PER_HOUR,
        placement = "rock",
        max_workers = 4,
        activity_type = "iron_miner",
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
    quarry = {
        category = "extraction",
        width = 3, height = 3,
        build_cost = { wood = 30, stone = 10 },
        build_ticks = 10 * TICKS_PER_HOUR,
        placement = "rock",
        max_workers = 4,
        activity_type = "stonecutter",
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },

    -- Processing (order system, max_workers = 1, slotted input, flat output)
    mill = {
        category = "processing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 8 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "miller",
        recipes = { "flour" },
        default_production_orders = {
            { recipe = "flour", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "wheat", capacity = 128 },
        },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
    bakery = {
        category = "processing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 8 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "baker",
        recipes = { "bread" },
        default_production_orders = {
            { recipe = "bread", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "flour", capacity = 128 },
        },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
    brewery = {
        category = "processing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 8 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "brewer",
        recipes = { "beer" },
        default_production_orders = {
            { recipe = "beer", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "barley", capacity = 128 },
        },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
    tailors_shop = {
        category = "processing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 8 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "tailor",
        recipes = { "plain_clothing" },
        default_production_orders = {
            { recipe = "plain_clothing", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "flax", capacity = 128 },
        },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
    smithy = {
        category = "processing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 40 },
        build_ticks = 12 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "smith",
        recipes = { "iron_tools" },       -- Phase 3 adds "steel_tools" and a steel input bin
        default_production_orders = {
            { recipe = "iron_tools", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "iron", capacity = 128 },
        },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
    bloomery = {
        category = "processing",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 40 },
        build_ticks = 12 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "smelter",
        recipes = { "steel" },
        default_production_orders = {
            { recipe = "steel", is_standing = true, amount = -1 },
        },
        input_bins = {
            { type = "iron", capacity = 128 },
            { type = "firewood", capacity = 128 },
        },
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },

    -- Service (community buildings — sizes TBD, will be larger to support interiors with seats/pews)
    market = {
        category = "service",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 8 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "merchant",
        tile_map = {},   -- TBD
        layout = {},     -- TBD
        -- Runtime: market.last_delivered populated from MerchantConfig food type keys at construction
    },
    tavern = {
        category = "service",
        width = 3, height = 3,    -- TBD: will likely grow for patron seating
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 8 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "barkeep",
        tile_map = {},   -- TBD
        layout = {},     -- TBD: barkeep station + patron seats
        -- input/consumption mechanics pending (Phase 4)
    },
    apothecary = {
        category = "service",
        width = 3, height = 3,
        build_cost = { wood = 40, stone = 20 },
        build_ticks = 8 * TICKS_PER_HOUR,
        max_workers = 1,
        activity_type = "physician",
        tile_map = {},   -- TBD
        layout = {},     -- TBD
    },
}
```

**Note on bloomery/smelter:** The building is `bloomery`, the activity_type is `smelter`, and the skill is `smelting`. Smelting is a distinct skill from smithing.

```lua
NameConfig = {
    male = {
        "Aldric", "Alfred", "Baldwin", "Beric", "Brand", "Cedric", "Colin",
        "Conrad", "Edmund", "Edward", "Garrett", "Geoffrey", "Gilbert",
        "Godwin", "Gunther", "Harold", "Henry", "Hugh", "Miles", "Oswin",
        "Ralph", "Reynard", "Richard", "Robert", "Roger", "Roland", "Rolf",
        "Thomas", "Walter", "William",
    },
    female = {
        "Ada", "Agnes", "Alice", "Annette", "Astrid", "Aveline", "Beatrice",
        "Brenna", "Cecily", "Constance", "Eleanor", "Elise", "Emma", "Freya",
        "Greta", "Gwynn", "Hadley", "Hilda", "Ingrid", "Isabel", "Lena",
        "Maren", "Margery", "Matilda", "Marta", "Millicent", "Roslyn",
        "Seren", "Sigrid", "Wynna",
    },
    surname = {
        "Aldham", "Aldren", "Barrow", "Breck", "Caskwell", "Corwin",
        "Delling", "Dunbar", "Elsworth", "Falkner", "Fenwick", "Hale",
        "Harren", "Hollis", "Kessler", "Langford", "Leclerc", "Merrick",
        "Norwick", "Overton", "Pemberton", "Rathmore", "Selwyn", "Stroud",
        "Talbot", "Voss", "Wardell", "Wyndham", "Yoren",
    },
}

SettlementNameConfig = {
    prefix = {
        "Alder", "Amber", "Black", "Bramble", "Crow", "Elder", "Fen",
        "Glen", "Hallow", "Holly", "Iron", "Meadow", "Oak", "Raven",
        "Silver", "Stone", "Thorn", "Willow", "Winter",
    },
    suffix = {
        "bridge", "crest", "dale", "fall", "field", "ford", "gate",
        "glen", "haven", "holm", "keep", "march", "mere", "moor",
        "ton", "vale", "watch", "wick", "wood",
    },
}
```

```lua
-- Default keybindings. All non-debug hotkeys are remappable — the input handler checks
-- Keybinds[action] instead of key literals. Debug keys (F1, Shift+F1, F3) are hardcoded.
-- Mouse bindings, Escape, and modifier keys (Shift for multi-select / placement hold) are
-- hardcoded — not part of this table.
Keybinds = {
    toggle_pause       = "space",
    speed_1            = "1",
    speed_2            = "2",
    speed_3            = "3",
    speed_4            = "4",
    speed_5            = "5",
    speed_6            = "6",
    pan_up             = "up",
    pan_down           = "down",
    pan_left           = "left",
    pan_right          = "right",
    designate_chop     = "a",
    designate_gather   = "s",
    cancel_designation = "x",
    rotate_building    = "tab",
    delete_building    = "delete",
    quicksave          = "f5",
    quickload          = "f9",
}
```