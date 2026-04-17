# Sovereign — BEHAVIOR.md
*v16 · Unit behavior: tick order, update loops, action system, classes and specialties.*

## Simulation

TICK ORDER

```lua
function simulation.onTick()
    time.advance()
    units.tickAll()          -- per-tick: movement, work progress, action completion
    units.update()           -- per-hash: needs, interrupts, activity polling, mood, health
    world.updateBuildings()
    world.updatePlants()
    units.sweepDead()
    buildings.sweepDeleted()
    if DEBUG_VALIDATE_RESOURCE_COUNTS then resources.validateCounts() end
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

-- Per-hash update (decision-making: needs, interrupts, activity polling, mood, health)
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

Unit updates are split into two loops: a **per-tick** loop that runs every tick for every living unit, and a **per-hash** loop that runs once per `HASH_INTERVAL` ticks per unit. The per-tick loop handles continuous-progress work (cheap: increment a counter, check a threshold). The per-hash loop handles decision-making (expensive: need checks, activity polling, mood/health recalculation).

**Per-tick loop (every tick, every living unit):**

1. **Advance current action** — `moveStep()` for travel, `workStep()` for work (increments progress, grows skill for specialty workers), `sleepStep()` for the sleep action (recovers energy, checks wake threshold — see Sleep section). Idle does nothing per-tick.
2. **Decrement work day counter** — if `activity_id` is set and `registry[activity_id].purpose == "work"`, decrement `work_ticks_remaining` by 1 (clamped at 0). Interrupt and recreation activities do not decrement it.
3. **On action complete** → `onActionComplete()` fires inline. See the `onActionComplete` pseudocode for the full priority chain: soft interrupt consumption, offloading, idle, activity handler dispatch.

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

1. **Drain needs** (satiation and energy drain toward 0 — multiplied by `HASH_INTERVAL` per application). Energy only drains while the unit is awake — sleepStep handles recovery during the sleep action. Recreation drains while awake and not recreating (see Work Day and Recreation).
2. **Check hard need interrupts** — skipped if `is_drafted`. Satiation (availability-gated) and energy checked against hard thresholds. See Need Interrupts for threshold values, availability gating, priority ordering, and cleanup behavior. See Sleep for energy-specific destination logic.
3. **Check soft need interrupts** — skipped if `is_drafted`. Energy (time-varying threshold) and satiation (flat threshold, availability-gated) checked. If below threshold: if the unit is already at a clean break (idle and not carrying), execute the soft interrupt directly — recheck threshold, post private need activity if still below, same priority and recheck logic as the `onActionComplete` path. No flag set. Otherwise set `soft_interrupt_pending` for deferred consumption. See Need Interrupts for the full consumption flow.
4. **Check equipment wants** — skipped if `is_drafted`. If a wanted equipment type is missing and available in storage: if the unit is already at a clean break, execute the equipment fetch directly (same logic as the `onActionComplete` path). Otherwise set `soft_interrupt_pending` for deferred consumption. See Equipment Wants for want rules, availability gating, and fetch flow.
5. **Check work day counter** — skipped if `is_drafted`. If `work_ticks_remaining` has reached 0 and `is_done_working` is not yet true, set `is_done_working = true`. If `game_hour` has crossed `WORK_DAY_RESET_HOUR` since last check, reset `work_ticks_remaining` to the unit's configured work hours (in ticks) and set `is_done_working` to false. See Work Day and Recreation.
6. **Poll activity queue or select recreation** — skipped if `is_drafted`. If idle:
   - `is_done_working == false`: scan for best activity (skipped if `class == "gentry"`). This is the periodic retry for units that were idle at `onActionComplete` — new activities may have been posted since the last hash tick.
   - `is_done_working == true`: select best available recreation activity, post and claim a private recreation activity. See Work Day and Recreation for selection logic.
7. **Recalculate mood** (stateless)
8. **Recalculate health** (stateless; death check at health <= 0)

Work action accumulates `skill_progress` per tick for specialty freemen/clergy (below activity type's `max_skill` cap). Mood and health are stateless — recalculated from scratch each hashed update.

Drafted units: per-tick loop runs normally. Per-hash: steps 2–6 skipped (see Drafting).

**Activity queue filtering:** Serfs scan for activities where `ActivityTypeConfig[type].is_specialty == false`, weighted by the serf's per-activity-type priority settings. Serf children (age 6+) use step 6 filtered to `SerfChildActivities` instead of the full non-specialty activity list. Freemen scan for activities where `type == unit.specialty`. Clergy scan the same way (matching their specialty). Gentry skip the work-polling branch of step 6 — they do not work — but still receive recreation activities when `is_done_working` is true. Freeman and gentry children under adulthood skip work polling (school attendance mechanics pending design).

**Activity scoring:** All activities — hauling and non-hauling alike — are scored by a linear combination of distance and activity age:

```
score = ActivityConfig.age_weight * (current_tick - posted_tick) - manhattan_distance
```

Higher score wins. Distance is Manhattan distance measured to the activity's location: the source for hauling activities, the workplace building for building-based work activities, or the target tile (`activity.x`, `activity.y`) for designation activities. With `age_weight = 0.2`, five ticks of waiting compensate for one tile of extra distance — local-first, with decay prevention for distant activities. Serf priority settings (Phase 2) filter which activity *types* a serf considers — they do not affect how individual activities within a type are ranked.

UNIT DEATH CLEANUP (sweepDead)

All cleanup runs eagerly at end of tick in `units.sweepDead`:
1. Convert to memory (preserves family graph)
2. Update registry (id now points to memory)
3. Social cleanup (iterate dead unit's friend_ids/enemy_ids — max 6 — remove from each counterpart's list)
4. Family references stay (father_id/spouse_id pointing to memory is correct)
5. Target tile cleanup (clear `tiles[unit.target_tile].target_of_unit`)
6. Tile position cleanup (remove unit from `tiles[tileIndex(unit.x, unit.y)].unit_ids`)
7. Activity cleanup — remove `activity_id` activity from queue: if it's a hauling activity, remove entirely (ground pile drop in step 9 will self-post a replacement if needed); otherwise, remove the activity from the building's `posted_activity_ids` and from `world.activities` so the building can post a new one. If `secondary_haul_activity_id` is set, remove that haul activity from queue and release its reservations (reserved_in at destination, reserved_out at source).
8. Tile claim cleanup (clear `tiles[unit.claimed_tile].claimed_by`)
9. Ground pile drop (drop carried resources AND equipped items via ground drop search at unit position — each type dropped separately per ground pile rules in ECONOMY.md)
10. Home cleanup (remove from housing building's `housing.member_ids`; clear bed's unit_id via unit's bed_index)
11. Dynasty check (trigger succession if is_leader)
12. Remove from `world.units` (swap-and-pop)

BUILDING DELETION (sweepDeleted)

Runs at end of tick after `units.sweepDead`. The player marks a building for deletion by setting `is_deleted = true`. Buildings under construction follow the same path — most steps are no-ops (no residents, no operational containers, no filter pull sources).

For each building where `is_deleted == true`:

**1. Walk `world.units` once** — one field check per living unit. For each unit with `secondary_haul_activity_id` where the haul activity's source or destination is this building:
- Source = this building, unit not carrying: cancel. Release destination reservation, clear `secondary_haul_activity_id`. Unit goes idle.
- Source = this building, unit already carrying: ignore. Unit is past pickup, resource is in `unit.carrying`. Let them finish the delivery.
- Destination = this building, unit not carrying: cancel. Release source reservation, clear `secondary_haul_activity_id`.
- Destination = this building, unit already carrying: clear `secondary_haul_activity_id`. Normal offloading reroutes to the next valid storage on the unit's next `onActionComplete`.

**2. Walk `posted_activity_ids`** — for each activity: if `activity.worker_id` is set, look up the claiming unit via registry, clear `unit.activity_id`, clear `unit.claimed_tile` if set. Remove the activity from `world.activities`. This handles builders, construction haulers, and operational workers — every unit working at this building got there through a activity the building posted.

**3. Clear footprint tiles** — set `tile.building_id = nil` on all tiles in the footprint, restore pathability.

**4. Eject units on now-impassable tiles** — scan all units. Any unit whose position is on a tile that is now impassable (e.g., water or rock tiles restored after deleting a dock or mine) → teleport to the building's former door tile position. Update `tile.unit_ids` (remove from old, add to new) and `target_tile`/`target_of_unit` (release old, claim new). For regular buildings on grass/dirt, no tiles become impassable and this step is a no-op.

**5. Drop all container contents** as ground piles — `construction.bins` (if under construction), `production.input_bins`, `housing.bins`, `storage`. Ground drop search starts from the building's former door tile position. Routed through the resources module so `resource_counts` updates. For regular buildings the drop origin doesn't matter since all former footprint tiles are valid; for buildings on impassable terrain, the door tile is always on pathable ground.

**6. Evict residents** via `housing.member_ids` — for each member: clear `unit.home_id` and `unit.bed_index`. They become homeless.

**7. Clear filter pull sources** — iterate all storage buildings. For any filter entry with `source_id` referencing this building, revert to `{ mode = "accept", limit = <preserved> }`.

**8. Remove from `world.buildings`** via swap-and-pop. Clear `registry[id]`.

Ordering matters: the unit walk (step 1) releases `secondary_haul_activity_id` claims before step 2 removes posted activities. Step 2 clears primary `activity_id` claims before step 5 drops container contents (so no unit thinks they're still picking up from a bin that's about to become a ground pile). Step 3 restores terrain before step 4 ejects units (so impassable tiles are detectable). Step 4 ejects units before step 5 drops ground piles (so piles land on tiles that are actually passable).

## Action System

Units execute one action at a time. When an action completes, the activity handler decides what to do next.

ACTION TYPES

| Action | Per-tick behavior | Completion |
|---|---|---|
| travel | advance along path | arrived at destination |
| work | increment progress, grow skill (specialty workers only) | progress reaches work_ticks |
| sleep | recover energy per tick (see Sleep section) | energy ≥ current wake threshold |
| idle | do nothing | never (cleared by activity poll or interrupt) |

Resource transfers (picking up from buildings, depositing to buildings) are instant inline operations performed by the handler between actions — not actions themselves. Work completion auto-grants resources to `unit.carrying` for gathering activities (via `resources.carryResource`).

Recreation activities (tavern visit, wandering) are private activities with handlers, following the same pattern as eat and sleep activities. They use travel and idle actions — no distinct recreation action type. See Work Day and Recreation for the behavioral flow.

ACTIVITY HANDLERS

Each activity type has a handler function that inspects the unit's state and sets the next action. `onActionComplete` is the single decision point that fires inline whenever an action finishes. It handles soft interrupt consumption, offloading, and activity handler dispatch in one priority chain:

```lua
function unit:onActionComplete()
    -- 1. Soft interrupt at clean break
    if self.soft_interrupt_pending and #self.carrying == 0 then
        self.soft_interrupt_pending = false
        -- Recheck needs (priority: energy then satiation)
        --   energy: current soft threshold (time-varying)
        --   satiation: current soft threshold (availability-gated)
        -- If below threshold → release activity_id, secondary_haul_activity_id
        --   (with reservation cleanup), claimed_tile;
        --   post private need activity, claim via activity_id; return
        -- If needs pass → check equipment wants
        --   If equipment want unmet and available → release all;
        --   post private equipment fetch activity; return
        -- If all pass → fall through to normal handler
    end
    -- (soft_interrupt_pending + carrying > 0: flag stays set,
    --  fall through — handler routes to deposit, next call re-checks)

    -- 2. Idle + carrying → offload
    if self.activity_id == nil and #self.carrying > 0 then
        -- self-deposit to nearest valid storage (private activity with reservation)
        -- if no capacity → ground drop at current position
        return
    end

    -- 3. No activity → idle
    if self.activity_id == nil then
        self.current_action = { type = "idle" }
        return
    end

    -- 4. Activity handler decides next action
    local activity = registry[self.activity_id]
    ActivityHandlers[activity.type].nextAction(self, activity)
end
```

Handlers check `unit.carrying` first: if carrying resources that are wrong for the current work, the handler routes to the nearest storage for offloading before starting the normal cycle. If carrying resources valid for the current work (e.g., a woodcutter returning from a need interrupt still holding wood), the handler skips to the deposit phase.

SELF-FETCH

When a worker needs resources that aren't in the building's input bins (insufficient for the next recipe), they self-fetch:

1. Post a haul activity (source = nearest storage building with available stock of the needed resource, destination = this building) and claim it immediately. This is a **private activity** — posted and claimed atomically, invisible to other haulers.
2. The haul activity reserves stock at the source (`reserved_out`) and capacity at the destination bin (`reserved_in`).
3. The haul activity is stored in `unit.secondary_haul_activity_id`. The primary `unit.activity_id` stays claimed.
4. Worker paths to source, picks up a full carry load (always grab as much as can be carried, not just what the recipe needs), paths back, deposits into the appropriate input bin. Excess beyond the recipe's needs stays in the bin for future crafts.
5. `secondary_haul_activity_id` cleared, reservations released. Worker resumes primary activity — checks input again, crafts if sufficient, self-fetches again if not.

Self-fetch applies to **any** worker at a processing building with insufficient input, regardless of class (serf miller and freeman baker behave identically).

Reservations prevent race conditions — the reserved stock cannot be claimed by another unit during transit.

"Nearest storage building with available stock" means: check stockpiles and warehouses for stackable resources, stockpiles and barns for items. Available stock respects reservations: `actual_stock - reserved_out`.

The worker's primary `activity_id` stays claimed throughout the fetch trip. The building's activity-posting condition (`#posted_activity_ids < worker_limit`) still sees the claimed activity, preventing double-staffing during self-fetch.

SELF-DEPOSIT

When a worker has finished goods in `unit.carrying` and needs to deposit them to storage:

1. Post a haul activity (source = nil (unit is carrying), destination = nearest storage building with available capacity for this resource type) and claim it immediately. **Private activity.**
2. The haul activity reserves capacity at the destination (`reserved_in`). No source reservation (resources are in `unit.carrying`).
3. Stored in `unit.secondary_haul_activity_id`. Primary `activity_id` stays claimed.
4. Worker paths to destination, deposits.
5. `secondary_haul_activity_id` cleared, reservation released. Worker returns to building and resumes primary activity.

If destination is destroyed during transit: followthrough to next nearest valid storage. If that is also full: ground drop. One followthrough attempt maximum.

Self-deposit is used by all workers carrying finished goods: processing workers after crafting, gathering workers returning with resources, farmers carrying their final partial harvest load, and any worker offloading wrong-type resources before starting a new activity.

"Nearest storage building with available capacity" means: stockpiles and warehouses for stackable resources, stockpiles and barns for items. Available capacity respects reservations: `capacity - used - reserved_in`.

GATHERING WORK CYCLE

Gathering uses two activity sources that share activity types and identical per-tile behavior. **Designation** posts activities directly when the player marks map resources for collection (no building required). **Gathering buildings** (woodcutter's camp, gatherer's hut, herbalist's hut) post activities when they have work available. Both use the same `"woodcutter"` or `"gatherer"` activity type, the same serf priority setting, and the same per-tile work: claim tile, path to an orthogonal neighbor (adjacent-to-rect 1×1), work for `PlantConfig[type].harvest_ticks`, unclaim, grant yield. The handler branches on `activity.workplace_id`: nil for designation, building id for building-based.

Designation (player-posted, no hub):

1. Serf claims the designation activity. The tile is already identified by the activity's x/y. Claim the tile: set `unit.claimed_tile` and `tile.claimed_by`.
2. Path to the resource tile using adjacent-to-rect (1×1). If no valid orthogonal neighbor exists (all impassable or target-claimed), unclaim the tile, remove the activity, go idle.
3. On arrival validation: if the tile's plant is gone (chopped by another worker, or designation cancelled), remove the activity and go idle.
4. Execute work action (duration from `PlantConfig[type].harvest_ticks`).
5. On work completion: unclaim the tile, grant `PlantConfig[type].harvest_yield` of the resource to `unit.carrying` (via `resources.carryResource`). Remove the designation activity from `world.activities`.
6. Check: `unit:carryableAmount(type) >= PlantConfig[type].harvest_yield` AND another unclaimed designation of the same resource type exists? If yes → claim next nearest designation activity (scan from **unit position**), go to step 2.
7. If carry full or no more designations → self-deposit to nearest storage (private haul activity with reservation).
8. Activity complete. Unit goes idle → polls for next activity.

Each designation is one activity per tile — consumed on completion. Cancelling a designation removes the activity from `world.activities`; if a serf had claimed it, clear `unit.activity_id`, `unit.claimed_tile`, and `tile.claimed_by`.

Building-based (hub → resource → storage):

**Activity posting:** Gathering buildings gate activity posting on target availability. On the building's hash tick, the building scans for unclaimed valid targets (correct plant type, mature, `claimed_by == nil`) from the building position. Activities to post = `min(unclaimed_count, max_workers) - #posted_activity_ids`. If zero or negative, no activities are posted. This prevents workers from claiming activities at buildings with no available resources. No pre-assignment — the building counts targets but does not track which specific targets correspond to which activities.

**Worker cycle:**

1. Path to hub building (adjacent-to-rect). Arrive.
2. Scan for the nearest valid resource tile from the **building position** (not the unit). Valid = correct plant type, mature (stage 3), and `claimed_by == nil`. If none → release activity, go idle. Building's next hash tick will see fewer targets and adjust activity count.
3. Claim the tile: set `unit.claimed_tile` and `tile.claimed_by`.
4. Path to the resource tile using adjacent-to-rect (1×1). If no valid orthogonal neighbor exists, unclaim the tile, scan for the next valid resource tile from unit position.
5. Execute work action (duration from `PlantConfig[type].harvest_ticks`).
6. On completion: unclaim the tile, grant `PlantConfig[type].harvest_yield` of the resource to `unit.carrying` (via `resources.carryResource`).
7. Check: `unit:carryableAmount(type) >= PlantConfig[type].harvest_yield` AND a valid tile exists (scan from **unit position**)? If yes → claim next tile, go to step 4.
8. If carry full or no valid tiles → self-deposit to nearest storage (private haul activity with reservation).
9. Go to step 1.

The worker always visits the hub before scanning. First cycle, every cycle — same flow. The first scan uses building position (keeps gatherers working near their hub). Subsequent scans within a trip use unit position (allows efficient chaining rather than bouncing back toward the hub).

If a worker's scan at the hub finds nothing (step 2), the worker releases the activity. The race condition (building counted a target that got claimed between the building's hash tick and the worker's arrival) resolves naturally — the building's next hash tick sees fewer targets and adjusts.

Extraction (stationary work → storage):

1. Worker stays at building, executes work action (duration from `ActivityTypeConfig[type].work_ticks`).
2. On completion: 1 unit of the resource goes into `unit.carrying` (via `resources.carryResource`).
3. Check: `unit:carryableAmount(type) >= 1`? If yes → go to step 1.
4. If carry full → self-deposit to nearest storage.
5. Return to building, repeat.

Extraction yield is always 1 per work cycle. The cycle duration (work_ticks) is the tuning knob for extraction rate. Extraction buildings do not deplete — the cycle repeats indefinitely.

Unclaim fires on activity abandonment (need interrupt, draft, death). Death cleanup handles `claimed_tile` in sweepDead step 8.

PROCESSING WORK CYCLE

`work_in_progress` persists on the building across worker changes. If a worker dies or leaves mid-craft, the partial progress remains and any new worker who takes a activity at the building resumes from where the previous worker left off. Buildings with `work_in_progress` always have `max_workers = 1`.

Worker checks `production_orders` top to bottom, takes the first match with available inputs (checked against the building's input bins). Standing orders check if `resource_counts.storage[type]` is below `amount`. `amount = -1` means unlimited — always craft, ignore stockpile count. Finite orders decrement `amount` on each craft completion and are removed at 0.

1. Check building's input bins — enough for the top production order's recipe?
2. If no → self-fetch. Excess stays in bin for future crafts.
3. Subtract recipe inputs from bins, begin work action.
4. On completion → finished goods go into `unit.carrying` (via `resources.carryResource`).
5. Check: `unit:carryableAmount(output_type) >= recipe output amount` AND inputs available for another cycle? If both yes → go to step 3.
6. If can carry more but no inputs → self-deposit, then self-fetch, return, go to step 3.
7. If can't carry → self-deposit.
8. Return to building, go to step 1.

Step 6 ensures carrying stays single-type — the worker deposits finished goods before fetching raw inputs. No mixed-type carrying.

FARMING WORK CYCLE

Planting:

1. Pick next eligible empty tile, travel to it, plant (work action, duration from `CropConfig[crop].plant_ticks`).
2. Repeat until no eligible tiles remain.
3. Leave farm, return to activity queue.

Harvest:

1. Pick next eligible tile, travel to it, harvest (work action, duration from `CropConfig[crop].harvest_ticks`).
2. Crop goes into `unit.carrying` (via `resources.carryResource`).
3. More eligible tiles AND carrying has room for next tile's expected yield → go to step 1.
4. More eligible tiles BUT carrying would overflow → drop via ground drop search from the unit's current position (see ECONOMY.md Ground Piles), go to step 1.
5. No more eligible tiles → self-deposit to nearest storage building, return to farm.

Ground piles dropped on farm tiles during harvest self-post haul activities. Haulers clear them in parallel while farmers keep harvesting. During "Harvest Now" panic, the farm fills with scattered piles and haulers scramble.

EATING WORK CYCLE

The eat activity is a private activity posted and claimed atomically when a satiation interrupt fires (soft or hard) or when the per-hash idle fast path detects satiation below threshold.

1. At destination? No → travel. If `home_id` is set, destination is home. If homeless, destination is nearest food source (see Homeless Eating for source priority). Pre-travel food reservation uses `secondary_haul_activity_id` (see Eating Behavior).
2. On arrival → run consumption loop inline (see Eating Behavior for food selection, consumption, and variety tracking).
3. Release activity. Unit goes idle.

If the home has no food on arrival, the handler triggers a home food self-fetch (see Home Food Self-Fetch) before the consumption loop.

SLEEP WORK CYCLE

The sleep activity is a private activity posted and claimed atomically when an energy interrupt fires (soft or hard) or when the per-hash idle fast path detects energy below threshold. Collapse (energy == 0) is a special case — see below.

1. At destination? No → travel. If `home_id` is set, destination is home. If homeless, destination is current tile (no travel).
2. On arrival → set `current_action = { type = "sleep" }`. `sleepStep` handles energy recovery per tick (see Sleep).
3. On sleep complete (energy ≥ wake threshold) → release activity. Unit goes idle.

**Collapse:** When energy hits 0, the hard interrupt fires with standard cleanup (drop, release). The sleep activity is posted with destination = current tile. The handler skips travel and immediately enters sleep. See Sleep for collapse rules.

CONSTRUCTION WORK CYCLE

On building placement: the building is created with `phase = "constructing"` (P1) or `phase = "blueprint"` (P2, when clearable obstructions exist on footprint tiles — see WORLD.md Placement Validation). A `construction` sub-table is populated — one bin per `build_cost` type, each sized to the exact required amount. For player-sized buildings, total build time is computed as `build_ticks_per_tile * tile_count` and stored on `construction.build_ticks`. Fixed-size buildings copy `build_ticks` from BuildingConfig directly. The builder reads `construction.build_ticks` regardless of building type.

All footprint tiles are immediately claimed (`tile.building_id` set) and impassable (subject to A* exemption for blueprint phase — see WORLD.md A* Building Exemption).

**Blueprint phase (P2).** When a building is placed with clearable obstructions (trees, berry bushes, ground piles) on its footprint, it enters blueprint phase. Clearing activities are posted into `posted_activity_ids`: one chop activity per tree, one clear activity per berry bush (P3), one haul activity per resource type per ground pile. A build activity is also posted. Material haul activities are NOT posted during blueprint phase.

**Unit displacement on blueprint placement (P2).** On placement, iterate all footprint tiles. For each tile, check `tile.target_of_unit`. Any unit whose `target_tile` is on a footprint tile is displaced: release their `target_tile` claim, flood fill outward from the unit's current position using the A* building exemption to find a free tile, claim the new tile, and repath. Units whose position is on a footprint tile but whose `target_tile` is outside the footprint are already leaving and need no intervention.

**Clearing activity flow (P2).** Clearing activities are public — any serf can claim them. The builder also checks for unclaimed clearing activities on their building and claims them with priority (see builder cycle below). A unit claims a clearing activity only if they have carry capacity for the yield. The clearing sequence for each activity:

1. Path to the target tile on the footprint using A* building exemption for this building (adjacent-to-rect 1×1 for trees/bushes, or onto the tile for ground pile pickup).
2. Execute action: chop (trees), clear (berry bushes, P3), or pick up (ground piles).
3. Pick up what can be carried. If yield exceeds carry capacity, excess drops as a ground pile on the same tile — this new pile self-posts a new clearing haul activity.
4. Deliver to nearest stockpile with capacity. If no stockpile has capacity, use standard ground drop search from the unit's position (standard merge rules — see ECONOMY.md Ground Piles).

**Blueprint → constructing transition.** When all clearing activities for a building are complete and no units remain on any footprint tile, the building transitions from `"blueprint"` to `"constructing"`. Material haul activities for all `build_cost` types are posted at this point (public activities, independent of the storage filter system). All go into `posted_activity_ids`.

**Builder cycle.** The builder checks the building's phase remotely before deciding where to path:

1. **If blueprint (P2):** Check for unclaimed clearing activities on this building. If any, claim the highest-priority one and execute the clearing sequence (see above). Repeat until no clearing activities remain.
2. **If constructing:** Check each `construction.bins` type: `needed = build_cost[type] - bin_contents - bin_reserved_in`. If needed > 0 for any type, path directly to the nearest stockpile with available stock of that type, pick up, deliver to building. If needed == 0 but bins aren't full yet (deliveries in transit), path to building and wait at site (adjacent-to-rect). When all materials are present, begin work action at building. `construction.progress` only advances while bins contain all required materials.
3. On completion: bin contents are consumed, `construction` is set to nil, `phase` is set to `"complete"`, interior F/D tiles become passable.

When `build_cost` is empty (stockpiles), the construction sub-table has no bins and progress advances unconditionally — just the builder working through `build_ticks`.

**P1 vs P2 differences.** The entire construction system — blueprint phase, material delivery, builder cycle — is P2+. In P1, buildings are placed instantly as `"complete"` with no construction sub-table and no build activities. The P2 optimization of checking bins remotely and pathing directly to the stockpile applies only in P2.

OFFLOADING

If a unit becomes idle while carrying resources, it self-deposits to the nearest valid storage building (private activity with reservation). If no storage has capacity, resources are dropped via ground drop search at the unit's current position.

EQUIPMENT WANTS

At the next clean break (idle and not carrying — reached via `onActionComplete` or the per-hash idle fast path), the unit re-evaluates: needs take priority over equipment wants, and equipment wants take priority over the work day check. If the interrupt was for equipment, the unit posts a private haul activity (source = nearest stockpile or barn with a matching item, destination = nil), reserves the item at the source (`reserved_out`), stores the activity in `secondary_haul_activity_id`, paths to the storage building, picks up the item, and equips it directly onto `unit.equipped`. Reservations release on pickup or on death/interrupt cleanup via `secondary_haul_activity_id`.

NEED INTERRUPTS

Soft and hard need interrupts for satiation are gated on availability — the interrupt only fires if food exists somewhere the unit can reach, respecting reservations. Energy interrupts are never gated — sleep doesn't require a resource, only a tile to lie on. Recreation has no interrupts (see Work Day and Recreation).

**Interrupt priority:** Hard interrupts check satiation before energy — a starving unit eats before sleeping, because starvation kills. Soft interrupts check energy before satiation — sleep drives the daily rhythm, and the overnight satiation drain naturally produces breakfast on wake. Equipment wants are checked after all needs pass. See per-hash loop steps 2–4 for threshold values, availability checks, and cleanup behavior.

**Failure mode:** When the settlement has zero available food, no satiation interrupts fire. Units work until malnourishment drains their health to 0. The player's signal is health warnings and death notifications — a sharp, visible collapse.

**Soft interrupt consumption flow:** `soft_interrupt_pending` is consumed at the first clean break — action complete AND not carrying. Two execution paths reach the same logic:

- **Per-hash (idle fast path):** Steps 3–4 detect a threshold crossing. If the unit is already at a clean break (idle and not carrying), the per-hash executes the interrupt directly — recheck, post private need activity, or fall through. No flag set. This eliminates the gap where a flag set on an idle unit would sit unconsumed until a activity appeared or the need degraded to a hard interrupt.
- **onActionComplete (deferred path):** If the unit is mid-work or carrying when the per-hash detects the crossing, it sets `soft_interrupt_pending`. The normal handler continues — carrying units route to deposit. On the next `onActionComplete` where the unit is not carrying, the flag is consumed: clear the flag, recheck the threshold, post private need activity or fall through. See the `onActionComplete` pseudocode for the full priority chain.

**Recheck logic (both paths):** Both needs recheck against their current soft threshold at consumption time. A band transition between detection and consumption can leave the unit no longer below threshold — energy's soft threshold is time-varying by design, and satiation uses the same recheck pattern for consistency even though its threshold is currently flat. If recheck fails, clear the flag silently and fall through to normal behavior. If recheck passes: release `activity_id`, `secondary_haul_activity_id` (with reservation cleanup), `claimed_tile`; post a private need activity (`"eat"` or `"sleep"`) and claim it via `activity_id`. The handler takes over from there. Priority during recheck: energy, then satiation (availability-gated), then equipment wants. No resource dropping — the unit finished work and deposited cleanly.

**Hard overrides soft:** If a soft interrupt is pending and a hard interrupt fires before the unit reaches a clean break, the hard interrupt takes priority — cancel everything, drop resources, release all state. `soft_interrupt_pending` is cleared as part of the hard interrupt path. The hard interrupt then posts the same private need activity — the difference is the cleanup (hard drops and releases immediately), not the destination.

Need activities are private — posted and claimed atomically by the unit, never visible to other workers. This is the same pattern as self-fetch and self-deposit. All existing cleanup paths (death, draft, building deletion) handle need activities through the standard `activity_id` cleanup with no special-casing.

SLEEP

Energy creates the daily rhythm. Units drain energy while awake and recover while asleep. Two thresholds drive the sleep loop, both varying by time of day:

- **Soft threshold** — when energy drops below this, the unit sets `soft_interrupt_pending` and finishes work cleanly before heading to sleep (see Need Interrupts).
- **Wake threshold** — during the sleep action, the unit wakes when energy reaches this value.

Higher values at night pull units into bed and keep them there; lower values during the day let them work freely. This is what creates the synchronized rhythm without an explicit schedule layer. The hard threshold stays flat across all hours (see NeedsConfig).

Four periods divide the day: night (NIGHT_START → MORNING_START), morning (MORNING_START → DAY_START), day (DAY_START → EVENING_START), evening (EVENING_START → NIGHT_START). Period hour constants are in CLAUDE.md. See SleepConfig in TABLES.md for threshold values per period.

Both thresholds are continuous everywhere — every band boundary is a flat-to-lerp or lerp-to-flat junction. Looked up via `time.getEnergyThresholds()`, which returns `{ soft, wake }` for the current `game_hour`.

**Interrupt tiers:**

- **Soft** (`energy < current soft`): Sets `soft_interrupt_pending`. Standard soft interrupt path with recheck on consumption (see Need Interrupts).
- **Hard** (`energy < hard_threshold`): Fires immediately. Standard hard interrupt path (drop carried via ground drop search, release activities).
- **Collapse** (`energy == 0`): Same cleanup as hard, but the unit enters the sleep action on the current tile regardless of `home_id`. No travel.

**Sleep destination:** When a soft or hard interrupt fires for energy, the destination depends on `home_id`. If `home_id` is set, the unit travels home and enters the sleep action at the assigned bed. If `home_id` is nil, the unit enters the sleep action on the current tile. Collapse always sleeps on the current tile, regardless of `home_id`. The `no_home` mood penalty already covers the homeless case continuously — there is no separate penalty for sleeping on the current tile.

**Wake check (per tick during sleep action):** `sleepStep()` adds `SleepConfig.recovery_rate` to `unit.needs.energy` (capped at 100), then checks if `energy ≥ time.getEnergyThresholds().wake`. If so, the sleep action completes and `onActionComplete` fires inline. The sleep activity handler releases the activity; the unit goes idle and picks up work on the next per-hash activity poll. The wake threshold is evaluated live each tick, so a unit sleeping through evening sees the threshold climb and sleeps longer to catch the rising bar. A unit sleeping through morning sees the threshold drop and wakes earlier than the night ceiling would have allowed.

Energy does not drain during the sleep action — drain only applies while the unit is awake (per-hash loop step 1 skips drain when current action is sleep).

HOME ASSIGNMENT

Automatic. When a unit needs a home, the system assigns the first housing building with an available bed. Clergy are celibate and never form families, so they tend to live alone. Newborn children are assigned to their parents' home. Units only become homeless if no beds exist anywhere.

When `home_id` is set, assign the first available bed (where `unit_id == nil`). Set both `unit.bed_index` and `bed.unit_id`. If all beds are occupied, the unit still has a home but `bed_index` stays nil — they sleep on the home's tile rather than at a bed. On unit death or home change, clear both sides.

EATING BEHAVIOR

When a unit eats at home, it consumes food from the home building's `housing.bins`. Each food type has a `nutrition` value in ResourceConfig representing how much satiation it restores.

**Pre-travel reservation:** Before traveling home to eat, the unit reserves one food item at the home bin (`reserved_out`). This prevents a housemate from consuming the food during transit. When the unit arrives and begins the consumption loop, each item consumed naturally clears its reservation (the food is gone). If the unit's trip is interrupted (death, draft), death cleanup releases the reservation via `secondary_haul_activity_id`.

**Food selection:** The unit always prefers the food type it has eaten least recently (oldest `last_ate` value, or nil). This naturally rotates through available types, supporting the food variety mood bonus. The unit scans housing bins that contain unreserved food stack entities and selects based on `last_ate`.

**Consumption loop:** Eat one item (decrement the food stack's amount by 1; destroy the stack entity if amount reaches 0). Update `unit.last_ate[type]` to the current tick. Check if eating another item of any available type would exceed 100 satiation — if so, stop. Otherwise repeat.

**Food variety mood:** During mood recalculation, count how many distinct food types have `last_ate` within `FOOD_VARIETY_WINDOW` (3 days). Each type beyond the first grants `food_variety_bonus` (+5). No penalty for lack of variety, only a bonus for achieving it.

HOME FOOD SELF-FETCH

When a unit's home has no food available in its housing bins, the unit self-fetches using the same private activity pattern: post a haul activity (source = nearest stockpile with food, destination = home's matching food bin), claim it immediately, travel, pick up, carry home, deposit. Reservations apply — the unit reserves stock at the source and capacity at the home's bin. This is the default behavior when no market exists. Once a market is built, the merchant handles home food delivery and self-fetch becomes a fallback for empty homes.

HOMELESS EATING

When a satiation interrupt fires and `home_id` is nil, the unit eats directly from the nearest available food source rather than from housing bins.

**Source priority:** Tavern (if exists, stocked with food, and open for the evening) → nearest storage building with unreserved food (stockpile or warehouse).

**Mechanism:** Same consumption loop as home eating, but targeting a different container. The unit reserves one food item at the source (`reserved_out`) before traveling, eats from the container on arrival, and follows the same food selection and consumption rules. Reservations release on pickup or on death/interrupt cleanup via `secondary_haul_activity_id`.

Homeless eating is inherently less efficient than eating at home — shared food sources, potentially longer travel, competition with other homeless units.

WORK DAY AND RECREATION

Units have a configurable work day length (10, 11, or 12 hours), set per-unit by the player in the work priority menu. The work day is tracked by `work_ticks_remaining`, a counter that decrements once per tick when the unit's primary activity has `purpose == "work"` (see per-tick loop step 2). Interrupt and recreation activities do not decrement it.

**Daily reset:** At `WORK_DAY_RESET_HOUR` (4am), `work_ticks_remaining` is set to the unit's configured work hours (converted to ticks) and `is_done_working` is set to false. The reset fires regardless of unit state — sleeping, awake, or drafted. This synchronizes all units to the same daily clock.

**Transition to recreation:** When `work_ticks_remaining` reaches 0, `is_done_working` becomes true. The unit finishes its current task cleanly (including deposit). On the next per-hash step 6 where the unit is idle, recreation selection runs instead of activity polling.

**Recreation as private activities:** Each recreation activity is a separate private activity type with its own handler, following the same pattern as eat and sleep activities. When a recreation handler completes, it releases the activity and the unit goes idle. On the next per-hash step 6, recreation selection evaluates again and may post a different recreation activity. The HASH_INTERVAL gap between recreation activities is natural — a unit standing briefly between "done wandering" and "heading to tavern" looks like a person deciding what to do next.

**Recreation selection (per-hash step 6, `is_done_working == true`):** Evaluate which recreation activity to pursue. Currently two options: visit the tavern (if exists, open for the evening, and not already visited this evening) or wander near home. Selection runs fresh each time, so a unit that finishes wandering might discover the tavern just opened and head there next. The selection logic lives in one place — per-hash step 6 — not inside individual handlers.

**Wandering work cycle:**

1. Pick a random tile within `RECREATION_WANDER_RADIUS` of home (or current position if homeless). Travel there.
2. On arrival → release activity. Unit goes idle.
3. Next per-hash step 6 selects another recreation activity (may wander again or switch to tavern).

The HASH_INTERVAL gap between arrival and the next per-hash step 6 provides a natural brief pause at each wander destination. Recreation recovers during wandering at `RecreationConfig.recovery_rate`.

**Tavern visit work cycle:**

1. Travel to tavern.
2. On arrival → eat from tavern food bins if hungry (satisfying satiation, same consumption loop as home eating). If beer is available, consume a beer for the `beer_consumed` mood bonus.
3. Recover recreation at the tavern recovery rate. Release activity. Unit goes idle.

The tavern combines the evening meal and recreation into one efficient trip.

**Recreation meter:** Recreation (0–100) feeds mood during recalculation — see per-hash loop step 1 for drain and recovery rates. Low recreation contributes a mood penalty. There is no bonus for high recreation.

**Need interrupts still fire during recreation.** Satiation and energy interrupts work normally while `is_done_working` is true. A recreating unit who gets hungry eats (need interrupt takes priority over recreation activity via standard soft/hard interrupt paths), then the next per-hash step 6 resumes recreation selection. A recreating unit whose energy drops below the soft threshold goes to sleep.

**Work does not preempt recreation.** Once `is_done_working` is true, per-hash step 6 runs recreation selection, not activity polling. New work activities posted during the evening are not picked up until the daily reset.

**Tavern — evening-only model.** The barkeep stocks the tavern with food and beer from storage during daytime work hours. In the evening, units visit to eat and recreate. The tavern is not open for morning meals — homeless units eat from the nearest stockpile in the morning. Barkeep schedule details are deferred.

CARRYING

`unit.carrying` is a flat array of entity ids — both stack entity ids and item entity ids. Total carried weight is `resources.countWeight(unit.carrying)`. `CARRY_WEIGHT_MAX = 32` is the hard cap — same for all units except the merchant (see MerchantConfig). `unit:carryableAmount(type)` returns how many more of a given type the unit can pick up by weight.

Weight governs both carrying and storage density. Resources have a `weight` field; containers have a `capacity` field. The same `weight` value determines how many units fit in a carry load and how many fit on a stockpile tile.

Carrying is always single-type. Activity handlers naturally produce single-type loads (a woodcutter carries wood, a hauler claims a activity for one type, a merchant selects one food type per delivery run). Processing workers who need to switch from carrying output to fetching input self-deposit first, then self-fetch. No exceptions.

Strength affects carrying speed penalty, not capacity — see WORLD.md Movement Speed for the formula.

Workers transport resources as part of their primary work cycle. This is distinct from dedicated hauling activities.

When a handler starts and the unit is carrying resources wrong for the current work, the handler routes to the nearest storage via self-deposit first. If carrying resources valid for the new work, skip to the work phase.

DRAFTING

Drafted units (`unit.is_drafted = true`) skip activity polling, need interrupts, and self-fetch/deposit. Needs still drain. Player issues move commands; the command system fans destinations to adjacent tiles so each drafted unit receives a unique `target_tile`. Mid-activity when drafted → abandon (progress persists, claim cleared). Energy hits 0 → auto-undraft + collapse on the spot (see Sleep). Undrafting resumes normal behavior on next hashed update. Resources carried when drafted are kept — no ground drop on draft.

Units with energy below the hard threshold cannot be drafted. They're already exhausted enough that they would auto-undraft on the next interrupt check anyway — blocking the draft up front avoids a wasted command.

## Classes and Specialties

Four classes, represented as string identifiers (no natural ordering between them):

| Class | Role | Work behavior |
|---|---|---|
| `"serf"` | Unskilled labor | Priority-based activity queue polling (non-specialty activities) |
| `"freeman"` | Skilled trades | Specialty-based activity queue polling (matches `unit.specialty`) |
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
- Serf children (age 6+): work unskilled activities from `SerfChildActivities` list.
- Freeman children (age 6+): attend school (grows intelligence).
- Gentry children (age 6+): attend school (grows intelligence).
- Clergy children: do not exist (clergy are celibate).

Children use their class's needs tier. Serf children use meager, freeman children use standard, gentry children use luxurious.

SPECIALTIES

A specialty is a career — "baker," "smith," "priest." It determines what kind of work a unit seeks, not where they work. Freemen and clergy have specialties. Serfs and gentry do not.

**Assignment:** Player promotes a serf to freeman and assigns a specialty (e.g., "baker"). The unit's `unit.specialty` is set. The unit now searches the activity queue for matching work.

**Dynamic work-finding:** Specialty workers do not have a permanent building assignment. When idle, they poll the activity queue for activities matching their specialty. Buildings post specialty activities when they have work available and an open slot (`#posted_activity_ids < worker_limit`). The worker claims the activity and paths to the building. On completion or when no more work is available, the worker polls again. The worker's `activity_id` claim is their slot reservation — it stays set through every self-fetch and self-deposit trip, preventing the building from double-posting while the worker is away.

**Revocation:** Most specialties are revocable with a mood penalty. Clergy specialties: irrevocable (see Promotion Paths).

**Skill growth:** Specialty freemen and clergy grow their specialty's skill through work. Progress accumulates per tick during the `work` action and is tracked per-skill in `unit.skill_progress`, so changing specialty preserves all previous skill levels and progress. Level-up threshold escalates: `skill_level_ticks * (current_skill + 1)`. Capped at `max_skill` from ActivityTypeConfig. See GrowthConfig for values.

Career ladder: priest → bishop (only). All other specialties are independent.

Knight and combat skill are **deferred** pending combat system design.

**Exception:** Physicians travel to patients rather than working in-building.

SERF ACTIVITY PRIORITIES

Serfs configure per-activity-type priorities (DISABLED / LOW / NORMAL / HIGH). Priorities are per-unit — each serf has their own settings. The player can assign serfs to **priority groups** so that members of a group share the same priority configuration. Serfs not in a group have independent settings. When idle, a serf polls the global activity queue filtered to non-specialty activity types where the serf's priority is not DISABLED, scored by distance + activity age (see Activity Scoring). Priority level (LOW / NORMAL / HIGH) determines relative weighting between activity types. Priority group data structures and group management UI are pending design.

ACTIVITY EFFECTIVENESS

Unskilled activities use `unit:getAttribute(attribute) + tool_bonus`. Specialty work uses `unit:getAttribute(attribute) + skill + tool_bonus`.