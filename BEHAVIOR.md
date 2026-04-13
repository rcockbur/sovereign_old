# Sovereign — BEHAVIOR.md
*v3 · Unit behavior: tick order, update loops, activity system, classes and specialties.*

## Simulation

TICK ORDER

```lua
function simulation.onTick()
    time.advance()
    units.tickAll()          -- per-tick: movement, work progress, activity completion
    units.update()           -- per-hash: needs, interrupts, job polling, mood, health
    world.updateBuildings()
    world.updateResources()
    world.updatePlants()
    units.sweepDead()
    buildings.sweepDeleted()
end
```

`time.accumulate(dt)` adds real delta time to an internal accumulator and returns how many ticks should fire this frame based on the current speed setting. At x1 speed, 1 tick fires per frame (60 ticks/sec at 60fps). At x8, 8 ticks fire per frame.

`time.advance()` increments the tick counter and derives all calendar fields (game_minute, game_hour, game_day, game_season, game_year) in one call.

Direct call chain — no event bus, no registration. Adding a new system means adding a line here. `units.sweepDead` runs near the end — dead units are flagged during updates and removed there. `buildings.sweepDeleted` runs last — after dead units are gone, so building cleanup only walks living units.

Calendar-driven logic uses modulo checks in `simulation.onTick`, not inside individual systems:

```lua
if world.time.tick % TICKS_PER_SEASON == 0 then
    units.processSeasonalAging()
end
if world.time.tick % TICKS_PER_YEAR == 0 then
    time.rollFrostDays()    -- roll thaw_day and frost_day for the new year
end
-- Frost/thaw day checks run per-day:
-- On spring day == thaw_day: set is_frost = false, fire "ground has thawed" notification
-- On autumn day == frost_day - FROST_WARNING_DAYS: fire "frost approaching" notification
-- On autumn day == frost_day: set is_frost = true, fire "frost has arrived" notification
```

HASH OFFSET SYSTEM

All entity collections use hash offsets to distribute updates evenly across ticks. Each entity updates once per `HASH_INTERVAL` ticks (once per real second at x1). A prime multiply scatters sequential IDs:

```lua
function hashOffset(id)
    return (id * 7919) % HASH_INTERVAL
end

-- Per-hash update (decision-making: needs, interrupts, job polling, mood, health)
function units.update()
    for i = 1, #world.units do
        local unit = world.units[i]
        if unit.is_dead == false then
            if (world.time.tick + hashOffset(unit.id)) % HASH_INTERVAL == 0 then
                unit:hashedUpdate()
            end
        end
    end
end
```

With `HASH_INTERVAL = 60`, approximate per-tick workload: ~3.3 unit updates + ~5 building updates = ~8.3 total.

PER-UNIT UPDATE — TWO LOOPS

Unit updates are split into two loops: a **per-tick** loop that runs every tick for every living unit, and a **per-hash** loop that runs once per `HASH_INTERVAL` ticks per unit. The per-tick loop handles continuous-progress work (cheap: increment a counter, check a threshold). The per-hash loop handles decision-making (expensive: need checks, job polling, mood/health recalculation).

**Per-tick loop (every tick, every living unit):**

1. **Advance current activity** — `moveStep()` for travel, `workStep()` for work (increments progress, grows skill for specialty workers), `sleepStep()` for the sleep wait activity (recovers energy, checks wake threshold — see Sleep section). Idle does nothing per-tick.
2. **On activity complete** → `onActivityComplete()` fires inline. Job handler decides next activity (includes self-fetch/self-deposit checks). If idle and carrying → offload. If soft interrupt pending and not carrying → release everything, self-assign need behavior. If idle and no job found → set `current_activity = idle`.

```lua
function units.tickAll()
    for i = 1, #world.units do
        local unit = world.units[i]
        if unit.is_dead == false then
            unit:tick()
        end
    end
end
```

**Per-hash loop (once per HASH_INTERVAL ticks per unit):**

1. **Drain needs** (satiation, energy, recreation drain toward 0 — multiplied by `HASH_INTERVAL` per application). Energy only drains while the unit is awake — sleepStep handles recovery during the sleep wait activity.
2. **Check hard need interrupts** — skipped if `is_drafted`. Energy: fires when below 10 (NeedsConfig hard_threshold) — see Sleep for sleep destination behavior. Satiation: only fires if food is available (check home bins for unreserved food, then check `resource_counts.storage[food_type] - resource_counts.storage_reserved[food_type] > 0` for any food type). Recreation: TBD (Phase 3, depends on tavern). When fired: release job_id, secondary_haul_job_id with reservation cleanup, claimed_tile; drop carried resources via ground drop search (see ECONOMY.md Ground Piles); clear soft_interrupt_pending; self-assign need behavior. For satiation: if food exists at home: travel home, eat. If food exists in storage but not at home: self-fetch to home (with reservations), then eat. If no food available: interrupt does not fire, unit keeps working.
3. **Check soft need interrupts** — skipped if `is_drafted`. Energy fires when below the current soft threshold (time-varying — see Sleep). Satiation only fires if food is available (respecting reservations). Recreation TBD. When fired: set `unit.soft_interrupt_pending = true`; the flag is checked in `onActivityComplete` during the per-tick loop, with a recheck against the current threshold at consumption time (see Need Interrupts).
4. **Check equipment wants** — skipped if `is_drafted`. All units want clothing. Only gentry want jewelry. Workers want tools (serfs including children 6+, freemen, clergy — not gentry). If missing a wanted equipment type and not already soft-interrupted, set `soft_interrupt_pending = true`. Uses availability gating with reservations: `resource_counts.storage[type] - resource_counts.storage_reserved[type] > 0`. Units prefer higher-quality variants (e.g., steel_tools over iron_tools). The fetch can short-circuit when no available stock of any matching type exists.
5. **Poll job queue** — if idle, scan for best job — skipped if `is_drafted` or `class == "gentry"`
6. **Recalculate mood** (stateless)
7. **Recalculate health** (stateless; death check at health <= 0)

Step 5 is the periodic retry for units that were idle at `onActivityComplete` — new jobs may have been posted since the last tick-level check.

Work activity accumulates `skill_progress` per tick for specialty freemen/clergy (below job type's `max_skill` cap). Mood and health are stateless — recalculated from scratch each hashed update.

Drafted units: per-tick loop runs normally (movement continues). Per-hash: steps 1, 6, 7 run. Steps 2, 3, 4, 5 skipped. Exception: energy hits 0 → auto-undraft, force sleep.

**Job queue filtering:** Serfs scan for jobs where `JobTypeConfig[type].is_specialty == false`, weighted by the serf's per-job-type priority settings. Serf children (age 6+) use step 5 filtered to `SerfChildJobs` instead of the full non-specialty job list. Freemen scan for jobs where `type == unit.specialty`. Clergy scan the same way (matching their specialty). Gentry skip step 5 entirely — they do not work. Freeman and gentry children under adulthood skip step 5 (school attendance mechanics pending design).

UNIT DEATH CLEANUP (sweepDead)

All cleanup runs eagerly at end of tick in `units.sweepDead`:
1. Convert to memory (preserves family graph)
2. Update registry (id now points to memory)
3. Social cleanup (iterate dead unit's friend_ids/enemy_ids — max 6 — remove from each counterpart's list)
4. Family references stay (father_id/spouse_id pointing to memory is correct)
5. Target tile cleanup (clear `tiles[unit.target_tile].target_of_unit`)
6. Tile position cleanup (remove unit from `tiles[tileIndex(unit.x, unit.y)].unit_ids`)
7. Job cleanup — remove `job_id` job from queue: if it's a hauling job, remove entirely (ground pile drop in step 9 will self-post a replacement if needed); otherwise, remove the job from the building's `posted_job_ids` and from `world.jobs` so the building can post a new one. If `secondary_haul_job_id` is set, remove that haul job from queue and release its reservations (reserved_in at destination, reserved_out at source).
8. Tile claim cleanup (clear `tiles[unit.claimed_tile].claimed_by`)
9. Ground pile drop (drop carried resources AND equipped items via ground drop search at unit position — each type dropped separately per ground pile rules in ECONOMY.md)
10. Home cleanup (remove from housing building's `housing.member_ids`; clear bed's unit_id via unit's bed_index)
11. Dynasty check (trigger succession if is_leader)
12. Remove from `world.units` (swap-and-pop)

BUILDING DELETION (sweepDeleted)

Runs at end of tick after `units.sweepDead`. The player marks a building for deletion by setting `is_deleted = true`. Buildings under construction follow the same path — most steps are no-ops (no residents, no operational containers, no filter pull sources).

For each building where `is_deleted == true`:

**1. Walk `world.units` once** — one field check per living unit. For each unit with `secondary_haul_job_id` where the haul job's source or destination is this building:
- Source = this building, unit not carrying: cancel. Release destination reservation, clear `secondary_haul_job_id`. Unit goes idle.
- Source = this building, unit already carrying: ignore. Unit is past pickup, resource is in `unit.carrying`. Let them finish the delivery.
- Destination = this building, unit not carrying: cancel. Release source reservation, clear `secondary_haul_job_id`.
- Destination = this building, unit already carrying: clear `secondary_haul_job_id`. Normal offloading reroutes to the next valid storage on the unit's next `onActivityComplete`.

**2. Walk `posted_job_ids`** — for each job: if `job.claimed_by` is set, look up the claiming unit via registry, clear `unit.job_id`, clear `unit.claimed_tile` if set. Remove the job from `world.jobs`. This handles builders, construction haulers, and operational workers — every unit working at this building got there through a job the building posted.

**3. Clear footprint tiles** — set `tile.building_id = nil` on all tiles in the footprint, restore pathability.

**4. Eject units on now-impassable tiles** — scan all units. Any unit whose position is on a tile that is now impassable (e.g., water or rock tiles restored after deleting a dock or mine) → teleport to the building's former door tile position. Update `tile.unit_ids` (remove from old, add to new) and `target_tile`/`target_of_unit` (release old, claim new). For regular buildings on grass/dirt, no tiles become impassable and this step is a no-op.

**5. Drop all container contents** as ground piles — `construction.bins` (if under construction), `production.input_bins`, `housing.bins`, `storage`. Ground drop search starts from the building's former door tile position. Routed through the resources module so `resource_counts` updates. For regular buildings the drop origin doesn't matter since all former footprint tiles are valid; for buildings on impassable terrain, the door tile is always on pathable ground.

**6. Evict residents** via `housing.member_ids` — for each member: clear `unit.home_id` and `unit.bed_index`. They become homeless.

**7. Clear filter pull sources** — iterate all storage buildings. For any filter entry with `source_id` referencing this building, revert to `{ mode = "accept", limit = <preserved> }`.

**8. Remove from `world.buildings`** via swap-and-pop. Clear `registry[id]`.

Ordering matters: the unit walk (step 1) releases `secondary_haul_job_id` claims before step 2 removes posted jobs. Step 2 clears primary `job_id` claims before step 5 drops container contents (so no unit thinks they're still picking up from a bin that's about to become a ground pile). Step 3 restores terrain before step 4 ejects units (so impassable tiles are detectable). Step 4 ejects units before step 5 drops ground piles (so piles land on tiles that are actually passable).

## Activity System

Units execute one activity at a time. When an activity completes, the job handler decides what to do next.

ACTIVITY TYPES

| Activity | Per-tick behavior | Completion |
|---|---|---|
| travel | advance along path | arrived at destination |
| work | increment progress, grow skill (specialty workers only) | progress reaches work_ticks |
| wait | sleep — recover energy per tick (see Sleep section) | energy ≥ current wake threshold |
| idle | do nothing | never (cleared by job poll or interrupt) |

Sleep is the only wait activity in Phase 1. Recreation (Phase 3) will define its own activity model when designed.

Resource transfers (picking up from buildings, depositing to buildings) are instant inline operations performed by the handler between activities — not activities themselves. Work completion auto-grants resources to `unit.carrying` for gathering jobs (via `resources.carryResource`).

JOB HANDLERS

Each job type has a handler function that inspects the unit's state and sets the next activity:

```lua
function unit:onActivityComplete()
    local job = registry[self.job_id]
    if job == nil then
        self.current_activity = { type = "idle" }
        return
    end
    JobHandlers[job.type].nextActivity(self, job)
end
```

Handlers check `unit.carrying` first: if carrying resources that are wrong for the current work, the handler routes to the nearest storage for offloading before starting the normal cycle. If carrying resources valid for the current work (e.g., a woodcutter returning from a need interrupt still holding wood), the handler skips to the deposit phase.

SELF-FETCH

When a worker needs resources that aren't in the building's input bins (insufficient for the next recipe), they self-fetch:

1. Post a haul job (source = nearest storage building with available stock of the needed resource, destination = this building) and claim it immediately. This is a **private job** — posted and claimed atomically, invisible to other haulers.
2. The haul job reserves stock at the source (`reserved_out`) and capacity at the destination bin (`reserved_in`).
3. The haul job is stored in `unit.secondary_haul_job_id`. The primary `unit.job_id` stays claimed.
4. Worker paths to source, picks up a full carry load (always grab as much as can be carried, not just what the recipe needs), paths back, deposits into the appropriate input bin. Excess beyond the recipe's needs stays in the bin for future crafts.
5. `secondary_haul_job_id` cleared, reservations released. Worker resumes primary job — checks input again, crafts if sufficient, self-fetches again if not.

Self-fetch applies to **any** worker at a processing building with insufficient input, regardless of class (serf miller and freeman baker behave identically).

Reservations prevent race conditions — the reserved stock cannot be claimed by another unit during transit.

"Nearest storage building with available stock" means: check stockpiles and warehouses for stackable resources, stockpiles and barns for items. Available stock respects reservations: `actual_stock - reserved_out`.

The worker's primary `job_id` stays claimed throughout the fetch trip. The building's job-posting condition (`#posted_job_ids < worker_limit`) still sees the claimed job, preventing double-staffing during self-fetch.

SELF-DEPOSIT

When a worker has finished goods in `unit.carrying` and needs to deposit them to storage:

1. Post a haul job (source = nil (unit is carrying), destination = nearest storage building with available capacity for this resource type) and claim it immediately. **Private job.**
2. The haul job reserves capacity at the destination (`reserved_in`). No source reservation (resources are in `unit.carrying`).
3. Stored in `unit.secondary_haul_job_id`. Primary `job_id` stays claimed.
4. Worker paths to destination, deposits.
5. `secondary_haul_job_id` cleared, reservation released. Worker returns to building and resumes primary job.

If destination is destroyed during transit: followthrough to next nearest valid storage. If that is also full: ground drop. One followthrough attempt maximum.

Self-deposit is used by all workers carrying finished goods: processing workers after crafting, gathering workers returning with resources, farmers carrying their final partial harvest load, and any worker offloading wrong-type resources before starting a new job.

"Nearest storage building with available capacity" means: stockpiles and warehouses for stackable resources, stockpiles and barns for items. Available capacity respects reservations: `capacity - used - reserved_in`.

GATHERING WORK CYCLE

Gathering uses two job sources that share job types and identical per-tile behavior. **Designation** posts jobs directly when the player marks map resources for collection (no building required). **Gathering buildings** (woodcutter's camp, gatherer's hut, herbalist's hut) post jobs when they have work available. Both use the same `"woodcutter"` or `"gatherer"` job type, the same serf priority setting, and the same per-tile work: claim tile, path to an orthogonal neighbor (adjacent-to-rect 1×1), work for `PlantConfig[type].harvest_ticks`, unclaim, grant yield. The handler branches on `job.target_id`: nil for designation, building id for building-based.

Designation (player-posted, no hub):

1. Serf claims the designation job. The tile is already identified by the job's x/y. Claim the tile: set `unit.claimed_tile` and `tile.claimed_by`.
2. Path to the resource tile using adjacent-to-rect (1×1). If no valid orthogonal neighbor exists (all impassable or target-claimed), unclaim the tile, remove the job, go idle.
3. On arrival validation: if the tile's plant is gone (chopped by another worker, or designation cancelled), remove the job and go idle.
4. Execute work activity (duration from `PlantConfig[type].harvest_ticks`).
5. On work completion: unclaim the tile, grant `PlantConfig[type].harvest_yield` of the resource to `unit.carrying` (via `resources.carryResource`). Remove the designation job from `world.jobs`.
6. Check: `unit:carryableAmount(type) >= PlantConfig[type].harvest_yield` AND another unclaimed designation of the same resource type exists? If yes → claim next nearest designation job (scan from **unit position**), go to step 2.
7. If carry full or no more designations → self-deposit to nearest storage (private haul job with reservation).
8. Job complete. Unit goes idle → polls for next job.

Each designation is one job per tile — consumed on completion. Cancelling a designation removes the job from `world.jobs`; if a serf had claimed it, clear `unit.job_id`, `unit.claimed_tile`, and `tile.claimed_by`.

Building-based (hub → resource → storage):

**Job posting:** Gathering buildings gate job posting on target availability. On the building's hash tick, the building scans for unclaimed valid targets (correct plant type, mature, `claimed_by == nil`) from the building position. Jobs to post = `min(unclaimed_count, max_workers) - #posted_job_ids`. If zero or negative, no jobs are posted. This prevents workers from claiming jobs at buildings with no available resources. No pre-assignment — the building counts targets but does not track which specific targets correspond to which jobs.

**Worker cycle:**

1. Path to hub building (adjacent-to-rect). Arrive.
2. Scan for the nearest valid resource tile from the **building position** (not the unit). Valid = correct plant type, mature (stage 3), and `claimed_by == nil`. If none → release job, go idle. Building's next hash tick will see fewer targets and adjust job count.
3. Claim the tile: set `unit.claimed_tile` and `tile.claimed_by`.
4. Path to the resource tile using adjacent-to-rect (1×1). If no valid orthogonal neighbor exists, unclaim the tile, scan for the next valid resource tile from unit position.
5. Execute work activity (duration from `PlantConfig[type].harvest_ticks`).
6. On completion: unclaim the tile, grant `PlantConfig[type].harvest_yield` of the resource to `unit.carrying` (via `resources.carryResource`).
7. Check: `unit:carryableAmount(type) >= PlantConfig[type].harvest_yield` AND a valid tile exists (scan from **unit position**)? If yes → claim next tile, go to step 4.
8. If carry full or no valid tiles → self-deposit to nearest storage (private haul job with reservation).
9. Go to step 1.

The worker always visits the hub before scanning. First cycle, every cycle — same flow. The first scan uses building position (keeps gatherers working near their hub). Subsequent scans within a trip use unit position (allows efficient chaining rather than bouncing back toward the hub).

If a worker's scan at the hub finds nothing (step 2), the worker releases the job. The race condition (building counted a target that got claimed between the building's hash tick and the worker's arrival) resolves naturally — the building's next hash tick sees fewer targets and adjusts.

Extraction (stationary work → storage):

1. Worker stays at building, executes work activity (duration from `JobTypeConfig[type].work_ticks`).
2. On completion: 1 unit of the resource goes into `unit.carrying` (via `resources.carryResource`).
3. Check: `unit:carryableAmount(type) >= 1`? If yes → go to step 1.
4. If carry full → self-deposit to nearest storage.
5. Return to building, repeat.

Extraction yield is always 1 per work cycle. The cycle duration (work_ticks) is the tuning knob for extraction rate. Extraction buildings do not deplete — the cycle repeats indefinitely.

Unclaim fires on job abandonment (need interrupt, draft, death). Death cleanup handles `claimed_tile` in sweepDead step 8.

PROCESSING WORK CYCLE

`work_in_progress` persists on the building across worker changes. If a worker dies or leaves mid-craft, the partial progress remains and any new worker who takes a job at the building resumes from where the previous worker left off. Buildings with `work_in_progress` always have `max_workers = 1`.

Worker checks `production_orders` top to bottom, takes the first match with available inputs (checked against the building's input bins). Standing orders check if `resource_counts.storage[type]` is below `amount`. `amount = -1` means unlimited — always craft, ignore stockpile count. Finite orders decrement `amount` on each craft completion and are removed at 0.

1. Check building's input bins — enough for the top production order's recipe?
2. If no → self-fetch. Excess stays in bin for future crafts.
3. Subtract recipe inputs from bins, begin work activity.
4. On completion → finished goods go into `unit.carrying` (via `resources.carryResource`).
5. Check: `unit:carryableAmount(output_type) >= recipe output amount` AND inputs available for another cycle? If both yes → go to step 3.
6. If can carry more but no inputs → self-deposit, then self-fetch, return, go to step 3.
7. If can't carry → self-deposit.
8. Return to building, go to step 1.

Step 6 ensures carrying stays single-type — the worker deposits finished goods before fetching raw inputs. No mixed-type carrying.

FARMING WORK CYCLE

Planting:

1. Pick next eligible empty tile, travel to it, plant (work activity, duration from `CropConfig[crop].plant_ticks`).
2. Repeat until no eligible tiles remain.
3. Leave farm, return to job queue.

Harvest:

1. Pick next eligible tile, travel to it, harvest (work activity, duration from `CropConfig[crop].harvest_ticks`).
2. Crop goes into `unit.carrying` (via `resources.carryResource`).
3. More eligible tiles AND carrying has room for next tile's expected yield → go to step 1.
4. More eligible tiles BUT carrying would overflow → drop ground pile on current tile, go to step 1.
5. No more eligible tiles → self-deposit to nearest storage building, return to farm.

Ground piles dropped on farm tiles during harvest self-post haul jobs. Haulers clear them in parallel while farmers keep harvesting. During "Harvest Now" panic, the farm fills with scattered piles and haulers scramble.

CONSTRUCTION WORK CYCLE

On building placement: the building is created with `is_built = false`. A `construction` sub-table is populated — one bin per `build_cost` type, each sized to the exact required amount. For player-sized buildings, total build time is computed as `build_ticks_per_tile * tile_count` and stored on `construction.build_ticks`. Fixed-size buildings copy `build_ticks` from BuildingConfig directly. The builder reads `construction.build_ticks` regardless of building type.

All blueprint tiles are immediately claimed and impassable. Haul jobs are posted for all `build_cost` materials (public jobs, independent of the storage filter system) and a build job is posted. All go into `posted_job_ids`. Builders and construction haulers path to the building using adjacent-to-rect, arriving at whichever side is closest.

Builder cycle:

1. Path to building via adjacent-to-rect. Check each `construction.bins` type: `needed = build_cost[type] - bin_contents - bin_reserved_in`. If needed > 0 for any type, self-fetch the gap (private haul job with reservations).
2. If needed == 0 but bins aren't full yet (deliveries in transit), wait at site.
3. When all materials are present, begin work activity. `construction.progress` only advances while bins contain all required materials.
4. On completion: bin contents are consumed, `construction` is set to nil, `is_built` is set to true, interior F/D tiles become passable. See WORLD.md Building Layout for blueprint passability rules.

When `build_cost` is empty (stockpiles), the construction sub-table has no bins and progress advances unconditionally — just the builder working through `build_ticks`.

OFFLOADING

If a unit becomes idle while carrying resources, it self-deposits to the nearest valid storage building (private job with reservation). If no storage has capacity, resources are dropped via ground drop search at the unit's current position.

EQUIPMENT WANTS

At the next clean break (`onActivityComplete` with nothing carried), the unit re-evaluates: needs take priority over equipment wants. If the interrupt was for equipment, the unit posts a private haul job (source = nearest stockpile or barn with a matching item, destination = nil), reserves the item at the source (`reserved_out`), stores the job in `secondary_haul_job_id`, paths to the storage building, picks up the item, and equips it directly onto `unit.equipped`. Reservations release on pickup or on death/interrupt cleanup via `secondary_haul_job_id`.

NEED INTERRUPTS

Both soft and hard need interrupts for resource-consuming needs (satiation, recreation) are gated on availability — the interrupt only fires if the required resource exists somewhere the unit can reach, respecting reservations. Energy interrupts are never gated — sleep doesn't require a resource, only a tile to lie on. Recreation gating is TBD (Phase 3, depends on tavern).

**Availability check for satiation:** Does the unit's home have any unreserved food in its housing bins? If not, does any storage building have unreserved food (`resource_counts.storage[food_type] - resource_counts.storage_reserved[food_type] > 0` for any food type)? If neither, the interrupt does not fire and the unit keeps working. This applies to both soft and hard satiation interrupts.

**Failure mode:** When the settlement has zero available food, no satiation interrupts fire. Units work until malnourishment drains their health to 0. The player's signal is health warnings and death notifications — a sharp, visible collapse.

- **Hard interrupt** (need below `hard_threshold`): Immediate. Release `job_id` (clear `claimed_by` on the job), release `secondary_haul_job_id` (remove haul job, release reservations), unclaim `claimed_tile`, clear `soft_interrupt_pending`, drop all carried resources via ground drop search (each type dropped separately — see ECONOMY.md Ground Piles). Self-assign need behavior — for energy, see Sleep. For satiation: if food at home, travel home and eat; if food in storage but not at home, self-fetch to home (private haul job with reservation on one food item at source and capacity at home bin), then eat.

- **Soft interrupt** (need below `soft_threshold`): Deferred. Set `unit.soft_interrupt_pending = true`. The flag is checked inside `onActivityComplete` in the per-tick loop. The handler continues running normally — if the unit finishes work and is carrying resources, the handler routes them to deposit (normal self-deposit cycle). Once the unit reaches a **clean break** (activity complete AND not carrying), the soft interrupt fires: **recheck the need against its current threshold** — energy's soft threshold is time-varying, so a band transition between flag set and flag consume can leave the unit no longer below threshold. If recheck fails, clear the flag silently and fall through to normal handler logic. Otherwise, fire the interrupt: release `job_id`, `secondary_haul_job_id` (with reservation cleanup), `claimed_tile`, clear `soft_interrupt_pending`, self-assign need behavior. No resource dropping — the unit finished their work and deposited cleanly.

```lua
-- Inside onActivityComplete (per-tick loop)
if self.soft_interrupt_pending then
    if #self.carrying > 0 then
        -- Normal handler logic: route to deposit via self-deposit
        return
    end
    self.soft_interrupt_pending = false
    -- Recheck each need against its current threshold (energy's threshold is time-varying).
    -- If any need is still below its current soft threshold → self-assign need behavior.
    -- If needs are fine, check equipment wants (missing → self-assign equipment fetch).
    -- If neither applies, the situation resolved itself — fall through to normal handler.
    return
end
-- Normal handler logic continues
```

- **Hard overrides soft:** If a soft interrupt is pending and a hard interrupt fires before the unit reaches a clean break, the hard interrupt takes priority — cancel everything, drop resources, release all state. `soft_interrupt_pending` is cleared as part of the hard interrupt path.

Needs are never posted as jobs — units self-assign need behavior directly.

SLEEP

Energy creates the daily rhythm. Units drain energy while awake and recover while asleep. Two thresholds drive the sleep loop, both varying by time of day:

- **Soft threshold** — when energy drops below this, the unit sets `soft_interrupt_pending` and finishes work cleanly before heading to sleep (see Need Interrupts).
- **Wake threshold** — during the sleep wait activity, the unit wakes when energy reaches this value.

Higher values at night pull units into bed and keep them there; lower values during the day let them work freely. This is what creates the synchronized rhythm without an explicit schedule layer. The hard threshold stays flat at 10 across all hours (NeedsConfig).

Four periods divide the day. Constants in CLAUDE.md, threshold values in SleepConfig.

| Period | Hours | Soft | Wake |
|---|---|---|---|
| Night   | NIGHT_START → MORNING_START (0 → 5)  | 50          | 100         |
| Morning | MORNING_START → DAY_START (5 → 7)    | lerp 50→20  | lerp 100→85 |
| Day     | DAY_START → EVENING_START (7 → 20)   | 20          | 85          |
| Evening | EVENING_START → NIGHT_START (20 → 0) | lerp 20→50  | lerp 85→100 |

Both thresholds are continuous everywhere — every band boundary is a flat-to-lerp or lerp-to-flat junction. Looked up via `time.getEnergyThresholds()`, which returns `{ soft, wake }` for the current `game_hour`.

**Interrupt tiers:**

- **Soft** (`energy < current soft`): Sets `soft_interrupt_pending`. Standard soft interrupt path with recheck on consumption (see Need Interrupts).
- **Hard** (`energy < 10`): Fires immediately. Standard hard interrupt path (drop carried via ground drop search, release jobs).
- **Collapse** (`energy == 0`): Same cleanup as hard, but the unit enters the sleep wait activity on the current tile regardless of `home_id`. No travel.

**Sleep destination:** When a soft or hard interrupt fires for energy, the destination depends on `home_id`. If `home_id` is set, the unit travels home and enters sleep wait at the assigned bed. If `home_id` is nil, the unit enters sleep wait on the current tile. Collapse always sleeps on the current tile, regardless of `home_id`. The `no_home` mood penalty already covers the homeless case continuously — there is no separate penalty for sleeping on the current tile.

**Wake check (per tick during sleep wait):** `sleepStep()` adds `SleepConfig.recovery_rate` to `unit.needs.energy` (capped at 100), then checks if `energy ≥ time.getEnergyThresholds().wake`. If so, the wait activity completes and `onActivityComplete` fires inline; the handler resumes normal behavior (typically idle → job poll on the next per-hash loop). The wake threshold is evaluated live each tick, so a unit sleeping through evening sees the threshold climb and sleeps longer to catch the rising bar. A unit sleeping through morning sees the threshold drop and wakes earlier than the night ceiling would have allowed.

Energy does not drain during the sleep wait activity — drain only applies while the unit is awake (per-hash loop step 1 skips drain when current activity is sleep wait).

HOME ASSIGNMENT

Automatic. When a unit needs a home, the system assigns the first housing building with an available bed. Clergy are celibate and never form families, so they tend to live alone. Newborn children are assigned to their parents' home. Units only become homeless if no beds exist anywhere.

When `home_id` is set, assign the first available bed (where `unit_id == nil`). Set both `unit.bed_index` and `bed.unit_id`. If all beds are occupied, the unit still has a home but `bed_index` stays nil — they sleep on the home's tile rather than at a bed. On unit death or home change, clear both sides.

EATING BEHAVIOR

When a unit eats at home, it consumes food from the home building's `housing.bins`. Each food type has a `nutrition` value in ResourceConfig representing how much satiation it restores.

**Pre-travel reservation:** Before traveling home to eat, the unit reserves one food item at the home bin (`reserved_out`). This prevents a housemate from consuming the food during transit. When the unit arrives and begins the consumption loop, each item consumed naturally clears its reservation (the food is gone). If the unit's trip is interrupted (death, draft), death cleanup releases the reservation via `secondary_haul_job_id`.

**Food selection:** The unit always prefers the food type it has eaten least recently (oldest `last_ate` value, or nil). This naturally rotates through available types, supporting the food variety mood bonus. The unit scans housing bins that contain unreserved food stack entities and selects based on `last_ate`.

**Consumption loop:** Eat one item (decrement the food stack's amount by 1; destroy the stack entity if amount reaches 0). Update `unit.last_ate[type]` to the current tick. Check if eating another item of any available type would exceed 100 satiation — if so, stop. Otherwise repeat.

**Food variety mood:** During mood recalculation, count how many distinct food types have `last_ate` within `FOOD_VARIETY_WINDOW` (3 days). Each type beyond the first grants `food_variety_bonus` (+5). No penalty for lack of variety, only a bonus for achieving it.

HOME FOOD SELF-FETCH

When a unit's home has no food available in its housing bins, the unit self-fetches using the same private job pattern: post a haul job (source = nearest stockpile with food, destination = home's matching food bin), claim it immediately, travel, pick up, carry home, deposit. Reservations apply — the unit reserves stock at the source and capacity at the home's bin. This is the default behavior when no market exists. Once a market is built, the merchant handles home food delivery and self-fetch becomes a fallback for empty homes.

CARRYING

`unit.carrying` is a flat array of entity ids — both stack entity ids and item entity ids. Total carried weight is `resources.countWeight(unit.carrying)`. `CARRY_WEIGHT_MAX = 32` is the hard cap — same for all units except the merchant (see MerchantConfig). `unit:carryableAmount(type)` returns how many more of a given type the unit can pick up by weight.

Weight governs both carrying and storage density. Resources have a `weight` field; containers have a `capacity` field. The same `weight` value determines how many units fit in a carry load and how many fit on a stockpile tile.

Carrying is always single-type. Job handlers naturally produce single-type loads (a woodcutter carries wood, a hauler claims a job for one type, a merchant selects one food type per delivery run). Processing workers who need to switch from carrying output to fetching input self-deposit first, then self-fetch. No exceptions.

Strength affects carrying speed penalty, not capacity — see WORLD.md Movement Speed for the formula.

Workers transport resources as part of their primary work cycle. This is distinct from dedicated hauling jobs.

When a handler starts and the unit is carrying resources wrong for the current work, the handler routes to the nearest storage via self-deposit first. If carrying resources valid for the new work, skip to the work phase.

DRAFTING

Drafted units (`unit.is_drafted = true`) skip job polling, need interrupts, and self-fetch/deposit. Needs still drain. Player issues move commands; the command system fans destinations to adjacent tiles so each drafted unit receives a unique `target_tile`. Mid-job when drafted → abandon (progress persists, claim cleared). Energy hits 0 → auto-undraft + collapse on the spot (see Sleep). Undrafting resumes normal behavior on next hashed update. Resources carried when drafted are kept — no ground drop on draft.

Units with energy below 10 (the hard threshold) cannot be drafted. They're already exhausted enough that they would auto-undraft on the next interrupt check anyway — blocking the draft up front avoids a wasted command.

## Classes and Specialties

Four classes, represented as string identifiers (no natural ordering between them):

| Class | Role | Work behavior |
|---|---|---|
| `"serf"` | Unskilled labor | Priority-based job queue polling (non-specialty jobs) |
| `"freeman"` | Skilled trades | Specialty-based job queue polling (matches `unit.specialty`) |
| `"clergy"` | Spiritual | Specialty-based, permanent, celibate, cannot marry or leave clergy |
| `"gentry"` | Ruling class | Idle — does not work. Pool for leader and knights |

PROMOTION PATHS

- **Serf → Freeman:** Player action. Economic promotion to enable specialty assignment.
- **Any → Clergy:** Player appoints as priest. Permanent and irrevocable. Unit cannot be married (appointment blocked if married).
- **Priest → Bishop:** Clergy-internal promotion. Only one bishop at a time.
- **Any → Gentry:** Via knighthood (granted by player) or marriage to an existing gentry unit. Knighthood elevates the unit, their spouse, and their children to gentry.

No demotions are currently supported. Freeman and gentry cannot be demoted. See DESIGN.md "Sections Pending Design" for demotion consideration.

CHILDREN

- Children under 6: wander, attend to needs. No work, no school.
- Serf children (age 6+): work unskilled jobs from `SerfChildJobs` list.
- Freeman children (age 6+): attend school (grows intelligence).
- Gentry children (age 6+): attend school (grows intelligence).
- Clergy children: do not exist (clergy are celibate).

Children use their class's needs tier. Serf children use meager, freeman children use standard, gentry children use luxurious.

SPECIALTIES

A specialty is a career — "baker," "smith," "priest." It determines what kind of work a unit seeks, not where they work. Freemen and clergy have specialties. Serfs and gentry do not.

**Assignment:** Player promotes a serf to freeman and assigns a specialty (e.g., "baker"). The unit's `unit.specialty` is set. The unit now searches the job queue for matching work.

**Dynamic work-finding:** Specialty workers do not have a permanent building assignment. When idle, they poll the job queue for jobs matching their specialty. Buildings post specialty jobs when they have work available and an open slot (`#posted_job_ids < worker_limit`). The worker claims the job and paths to the building. On completion or when no more work is available, the worker polls again. The worker's `job_id` claim is their slot reservation — it stays set through every self-fetch and self-deposit trip, preventing the building from double-posting while the worker is away.

**Revocation:** Most specialties are revocable with a mood penalty. Clergy specialties: irrevocable (see Promotion Paths).

**Skill growth:** Specialty freemen and clergy grow their specialty's skill through work. Progress accumulates per tick during the `work` activity and is tracked per-skill in `unit.skill_progress`, so changing specialty preserves all previous skill levels and progress. Level-up threshold escalates: `skill_level_ticks * (current_skill + 1)`. Capped at `max_skill` from JobTypeConfig. See GrowthConfig for values.

Career ladder: priest → bishop (only). All other specialties are independent.

Knight and combat skill are **deferred** pending combat system design.

**Exception:** Physicians travel to patients rather than working in-building.

SERF JOB PRIORITIES

Serfs configure per-job-type priorities (DISABLED / LOW / NORMAL / HIGH). When idle, a serf polls the global job queue filtered by non-specialty jobs and weighted by priority.

JOB EFFECTIVENESS

Unskilled jobs use `unit:getAttribute(attribute) + tool_bonus`. Specialty work uses `unit:getAttribute(attribute) + skill + tool_bonus`.
