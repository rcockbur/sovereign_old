# Sovereign — BEHAVIOR.md
*v30 · Unit behavior: tick order, update loops, action system, classes and specialties.*

## Simulation

TICK ORDER

```lua
function simulation.onTick()
    time.advance()
    activities.validateEligibility()  -- per-tick eligibility flags for activities and requests
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

`activities.validateEligibility()` runs early, before `units.update()`, so workers polling during the per-hash loop see fresh eligibility flags on activities and requests. See HAULING.md Eligibility Validation for the per-type predicates.

Calendar-driven logic uses modulo checks in `simulation.onTick`, not inside individual systems:

```lua
if world.time.tick % TICKS_PER_DAY == WORK_DAY_RESET_HOUR * TICKS_PER_HOUR then
    units.resetWorkDay()    -- walk living units, reset work_ticks_remaining / is_done_working
end
if world.time.tick % TICKS_PER_SEASON == 0 then
    units.processSeasonalAging()
end
if world.time.tick % TICKS_PER_YEAR == 0 then
    time.rollFrostDays()    -- roll thaw_day and frost_day for the new year
end
-- Per-day frost/thaw checks fire from the same orchestrator. See ECONOMY.md
-- Frost and Farming for the day-by-day rules (thaw, warning, arrival).
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

1. **Advance current action** — `moveStep()` for travel, `workStep()` for work (increments progress, grows skill for specialty workers), `eatStep()` for the eat action (increments progress), `sleepStep()` for the sleep action (recovers energy, checks wake threshold — see Sleep section). Idle does nothing per-tick.
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
2. **Check hard need interrupts** — skipped if `is_drafted`. Satiation (availability-gated) and energy checked against hard thresholds. Each need's check is skipped when the current activity is already addressing that need (satiation when activity is `"eat"`, energy when activity is `"sleep"`) — see Need Interrupts In-Progress Skip Rule. See Need Interrupts for threshold values, availability gating, priority ordering, and cleanup behavior. See Sleep for energy-specific destination logic.
3. **Check soft need interrupts** — skipped if `is_drafted`. Energy (time-varying threshold) and satiation (flat threshold, availability-gated) checked. Same in-progress skip rule as step 2. If below threshold: if the unit is already at a clean break (idle and not carrying), execute the soft interrupt directly — recheck threshold, post private need activity if still below, same priority and recheck logic as the `onActionComplete` path. No flag set. Otherwise set `soft_interrupt_pending` for deferred consumption. See Need Interrupts for the full consumption flow.
4. **Check equipment wants** — skipped if `is_drafted`. If a wanted equipment type is missing and available in storage: if the unit is already at a clean break, execute the equipment fetch directly (same logic as the `onActionComplete` path). Otherwise set `soft_interrupt_pending` for deferred consumption. See Equipment Wants for want rules, availability gating, and fetch flow.
5. **Check work day counter** — skipped if `is_drafted`. If `work_ticks_remaining` has reached 0 and `is_done_working` is not yet true, set `is_done_working = true`. The daily reset of `work_ticks_remaining` and `is_done_working` fires from the calendar-driven block in `simulation.onTick` (see Tick Order), not from here. See Work Day and Recreation.
6. **Poll activity queue or select recreation** — skipped if `is_drafted`. If idle:
   - `is_done_working == false`: scan for best activity (skipped if `class == "gentry"`). This is the periodic retry for units that were idle at `onActionComplete` — new activities may have been posted since the last hash tick.
   - `is_done_working == true`: select best available recreation activity, post and claim a private recreation activity. See Work Day and Recreation for selection logic.
7. **Recalculate mood** (stateless)
8. **Recalculate health** (stateless; death check at health <= 0)

Work action accumulates `skill_progress` per tick for specialty freemen/clergy (below activity type's `max_skill` cap). Mood and health are stateless — recalculated from scratch each hashed update.

Drafted units: per-tick loop runs normally. Per-hash: steps 2–6 skipped (see Drafting).

**Activity queue filtering:** Serfs scan for activities where `ActivityTypeConfig[type].is_specialty == false`, weighted by the serf's per-activity-type priority settings. Serf children (age 6+) use step 6 filtered to `SerfChildActivities` instead of the full non-specialty activity list. Freemen scan for activities where `type == unit.specialty`. Clergy scan the same way (matching their specialty). Gentry skip the work-polling branch of step 6 — they do not work — but still receive recreation activities when `is_done_working` is true. Freeman and gentry children under adulthood skip work polling (school attendance mechanics pending design).

UNIT DEATH CLEANUP (sweepDead)

All cleanup runs eagerly at end of tick in `units.sweepDead`:
1. Convert to memory (preserves family graph)
2. Update registry (id now points to memory)
3. Social cleanup (iterate dead unit's friend_ids/enemy_ids — max 6 — remove from each counterpart's list)
4. Family references stay (father_id/spouse_id pointing to memory is correct)
5. Target tile cleanup (clear `tiles[unit.target_tile].target_of_unit`)
6. Tile position cleanup (remove unit from `tiles[tileIndex(unit.x, unit.y)].unit_ids`)
7. Activity cleanup — if `unit.activity_id` is set, look up the activity. Release any outstanding reservations on it (read `source_reserved_amount` and `destination_reserved_amount` directly — see HAULING.md Cleanup). If the activity is a haul, remove from `world.activities` and registry. If the activity is building-posted (operational, build), remove from the building's `posted_activity_ids` and from `world.activities` so the building can post a new one.
8. Tile claim cleanup (clear `tiles[unit.claimed_tile].claimed_by`)
9. Ground pile drop (drop carried resources AND equipped items via ground drop search at unit position — each type dropped separately per ground pile rules in ECONOMY.md)
10. Home cleanup (remove from housing building's `housing.member_ids`; clear bed's unit_id via unit's bed_index)
11. Dynasty check (trigger succession if is_leader)
12. Remove from `world.units` (swap-and-pop)

BUILDING DELETION (sweepDeleted)

Runs at end of tick after `units.sweepDead`. The player marks a building for deletion by setting `is_deleted = true`. Buildings under construction follow the same path — most steps are no-ops (no residents, no operational containers, no filter pull sources).

For each building where `is_deleted == true`:

**1. Remove requests posted by this building.** Walk the building's `posted_request_ids`. For each request id, remove the request from `world.requests` and registry. This covers filter pull requests (puller's storage = this building) and construction delivery requests (destination = this building). Ground pile cleanup requests are not in `posted_request_ids` — they're posted by ground piles and unaffected by building deletion. Requests have no reservations of their own, so no per-request reservation release is needed. Concrete haul activities that were already converted from these requests are handled by step 2.

**2. Walk `world.units` once** — check each living unit's `activity_id`. For each unit whose `activity_id` references a haul activity where the activity's source or destination is this building, apply this matrix:

- **Source = this building, unit not carrying:** release the destination-side reservation, remove the activity from `world.activities` and registry, clear the unit's `activity_id`. Unit goes idle.
- **Source = this building, unit already carrying:** no action. Unit is past pickup, the source-side reservation already cleared on withdraw, resource is in `unit.carrying`. Let the delivery finish.
- **Destination = this building, unit not carrying:** release the source-side reservation, remove the activity from `world.activities` and registry, clear the unit's `activity_id`. Unit goes idle.
- **Destination = this building, unit already carrying:** clear the unit's `activity_id`. The activity and its destination-side reservation are erased implicitly when step 6 destroys the container. The unit's next `onActionComplete` sees idle + carrying and routes to offload.

Reservations on the building being deleted are not released individually anywhere in this matrix; they are erased implicitly when step 6 drops container contents and destroys the containers.

**3. Walk `posted_activity_ids`** — for each activity: if `activity.worker_id` is set, look up the claiming unit via registry, clear `unit.activity_id`, clear `unit.claimed_tile` if set. Remove the activity from `world.activities` and registry. This handles builders and operational workers — every unit working at this building got there through an activity the building posted. (Construction delivery hauls are not in `posted_activity_ids` — they were requests in step 1, with concrete activities handled in step 2.)

**4. Clear footprint tiles** — set `tile.building_id = nil` on all tiles in the footprint, restore pathability.

**5. Eject units on now-impassable tiles** — scan all units. Any unit whose position is on a tile that is now impassable (e.g., water or rock tiles restored after deleting a dock or mine) → teleport to the building's former door tile position. Update `tile.unit_ids` (remove from old, add to new) and `target_tile`/`target_of_unit` (release old, claim new). For regular buildings on grass/dirt, no tiles become impassable and this step is a no-op.

**6. Drop all container contents** as ground piles — `construction.bins` (if under construction), `production.input_bins`, `housing.bins`, `storage`. Ground drop search starts from the building's former door tile position. Routed through the resources module so `resource_counts` updates. For regular buildings the drop origin doesn't matter since all former footprint tiles are valid; for buildings on impassable terrain, the door tile is always on pathable ground.

**7. Evict residents** via `housing.member_ids` — for each member: clear `unit.home_id` and `unit.bed_index`. They become homeless.

**8. Clear filter pull sources** — iterate all storage buildings. For any filter entry with `source_id` referencing this building, revert to `{ mode = "accept", limit = <preserved> }`.

**9. Remove from `world.buildings`** via swap-and-pop. Clear `registry[id]`.

Ordering matters: requests are removed in step 1 so workers polling later in the tick don't claim doomed work. The unit walk (step 2) releases active haul reservations on living units before step 3 removes building-posted activities. Step 3 clears workplace claims before step 6 drops container contents (so no unit thinks they're still picking up from a bin that's about to become a ground pile). Step 4 restores terrain before step 5 ejects units (so impassable tiles are detectable). Step 5 ejects units before step 6 drops ground piles (so piles land on tiles that are actually passable).

## Action System

Units execute one action at a time. When an action completes, the activity handler decides what to do next.

ACTION TYPES

| Action | Per-tick behavior | Completion |
|---|---|---|
| travel | advance along path | arrived at destination |
| work | increment progress, grow skill (specialty workers only) | progress reaches work_ticks |
| eat | increment progress | progress reaches EAT_TICKS |
| sleep | recover energy per tick (see Sleep section) | energy ≥ current wake threshold |
| idle | do nothing | never (cleared by activity poll or interrupt) |

Resource transfers (picking up from buildings, depositing to buildings) are instant inline operations performed by the handler between actions — not actions themselves. Work completion auto-grants resources to `unit.carrying` for gathering activities (via `resources.produceIntoCarrying`). Eat completion destroys one item from `unit.carrying` and applies nutrition — see Eating Work Cycle.

Recreation activities (tavern visit, wandering) are private activities with handlers, following the same pattern as eat and sleep activities. They use travel and idle actions — no distinct recreation action type. See Work Day and Recreation for the behavioral flow.

ACTIVITY HANDLERS

Each activity type has a handler function that inspects the unit's state and sets the next action. `onActionComplete` is the single decision point that fires inline whenever an action finishes. It handles soft interrupt consumption, offloading, the on-completion poll, and activity handler dispatch in one priority chain:

```lua
function unit:onActionComplete()
    -- 1. Soft interrupt at clean break
    if self.soft_interrupt_pending and #self.carrying == 0 then
        self.soft_interrupt_pending = false
        -- Recheck needs (priority: energy then satiation)
        --   energy: current soft threshold (time-varying)
        --   satiation: current soft threshold (availability-gated)
        -- If below threshold → release activity_id (with reservation cleanup),
        --   claimed_tile; post private need activity (eat or sleep), claim via
        --   activity_id; return
        -- If needs pass → check equipment wants
        --   If equipment want unmet and available → release activity_id (with
        --   reservation cleanup), claimed_tile; post equipment fetch activity,
        --   claim via activity_id; return
        -- If all pass → fall through to normal handler
    end
    -- (soft_interrupt_pending + carrying > 0: flag stays set,
    --  fall through — handler routes to deposit, next call re-checks)

    -- 2. Idle + carrying → offload
    if self.activity_id == nil and #self.carrying > 0 then
        -- Post private offload haul activity to nearest valid storage with capacity.
        -- Reserve destination, claim via activity_id. See HAULING.md Offloading.
        -- If no storage anywhere has capacity → ground drop at current position.
        return
    end

    -- 3. Activity handler decides next action (if activity in progress)
    if self.activity_id ~= nil then
        local activity = registry[self.activity_id]
        ActivityHandlers[activity.type].nextAction(self, activity)
        return
    end

    -- 4. On-completion poll — unit just finished an activity, idle and not carrying.
    --    Scan world.activities (unclaimed concrete) and world.requests (aggregate
    --    haul needs). Same filter and scoring rules as per-hash queue polling.
    --    See HAULING.md Worker Polling.
    -- If poll finds eligible work → claim and dispatch (set activity_id, ActivityHandlers
    --   nextAction); return.

    -- 5. No activity → idle. Wait for next per-hash tick to retry.
    self.current_action = { type = "idle" }
end
```

Handlers check `unit.carrying` first: if carrying resources that are wrong for the current work, the handler routes to the nearest storage for offloading before starting the normal cycle. If carrying resources valid for the current work (e.g., a woodcutter returning from a need interrupt still holding wood), the handler skips directly to the `to_storage` phase.

ACTIVITY SCORING

All activities — hauling and non-hauling alike — are scored by a linear combination of distance and activity age:

```
score = ActivityConfig.age_weight * (current_tick - posted_tick) - manhattan_distance
```

Higher score wins. Distance is Manhattan distance measured to the activity's location: the source for hauling activities, the workplace building for building-based work activities, or the target tile (`activity.x`, `activity.y`) for designation activities. With `age_weight = 0.2`, five ticks of waiting compensate for one tile of extra distance — local-first, with decay prevention for distant activities. Serf priority settings (Phase 2) filter which activity *types* a serf considers — they do not affect how individual activities within a type are ranked.

SELF-FETCH AND SELF-DEPOSIT

Processing workers' input fetch and output deposit are steps of the processing activity, not separate haul activities. When a worker claims a processing activity and the building's input bins are insufficient for the next recipe, the claim is atomic with resolving a source, reserving its stock, and starting the activity in `to_input_source` before entering `to_workplace`. After the `working` phase produces output, the activity transitions to `to_storage`, routing to the nearest storage with capacity. Both steps use the partial-fill chain when relevant. See HAULING.md for the full mechanics, request/activity model, and reservation handling.

GATHERING WORK CYCLE

Gathering uses two activity sources that share activity types and identical per-tile behavior. **Designation** posts activities directly when the player marks map resources for collection (no building required). **Gathering buildings** (woodcutter's camp, gatherer's hut, herbalist's hut) post activities when they have work available. Both use the same `"woodcutter"` or `"gatherer"` activity type, the same serf priority setting, and the same per-tile work: claim tile, path to an orthogonal neighbor (adjacent-to-rect 1×1), work for `PlantConfig[type].harvest_ticks`, unclaim, grant yield. The handler branches on `activity.workplace_id`: nil for designation, building id for building-based.

Designation (player-posted, no hub):

1. Serf claims the designation activity. The tile is already identified by the activity's x/y. Claim the tile: set `unit.claimed_tile` and `tile.claimed_by`.
2. Path to the resource tile using adjacent-to-rect (1×1). If no valid orthogonal neighbor exists (all impassable or target-claimed), unclaim the tile, remove the activity, go idle.
3. On arrival validation: if the tile's plant is gone (chopped by another worker, or designation cancelled), remove the activity and go idle.
4. Execute work action (duration from `PlantConfig[type].harvest_ticks`).
5. On work completion: unclaim the tile, grant `PlantConfig[type].harvest_yield` of the resource to `unit.carrying` (via `resources.produceIntoCarrying`). Remove the designation activity from `world.activities`.
6. Check: `unit:carryableAmount(type) >= PlantConfig[type].harvest_yield` AND another unclaimed designation of the same resource type exists? If yes → claim next nearest designation activity (scan from **unit position**), go to step 2.
7. If carry full or no more designations → transition to `to_storage`: route to nearest storage with capacity, deposit, complete the activity (see HAULING.md Self-deposit).
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
6. On completion: unclaim the tile, grant `PlantConfig[type].harvest_yield` of the resource to `unit.carrying` (via `resources.produceIntoCarrying`).
7. Check: `unit:carryableAmount(type) >= PlantConfig[type].harvest_yield` AND a valid tile exists (scan from **unit position**)? If yes → claim next tile, go to step 4.
8. If carry full or no valid tiles → transition to `to_storage`: route to nearest storage with capacity, deposit (see HAULING.md Self-deposit). Activity completes.

The worker visits the hub once per activity, before scanning. The first scan uses building position (keeps gatherers working near their hub). Subsequent scans within the same trip use unit position (allows efficient chaining rather than bouncing back toward the hub). After deposit, the worker repolls via `onActionComplete` on-completion poll (see HAULING.md Worker Polling) and may re-claim the same building's next activity if one is posted.

If a worker's scan at the hub finds nothing (step 2), the worker releases the activity. The race condition (building counted a target that got claimed between the building's hash tick and the worker's arrival) resolves naturally — the building's next hash tick sees fewer targets and adjusts.

Extraction (stationary work → storage):

1. Worker stays at building, executes work action (duration from `ActivityTypeConfig[type].work_ticks`).
2. On completion: 1 unit of the resource goes into `unit.carrying` (via `resources.produceIntoCarrying`).
3. Check: `unit:carryableAmount(type) >= 1`? If yes → go to step 1.
4. If carry full → transition to `to_storage`: route to nearest storage with capacity, deposit (see HAULING.md Self-deposit). Activity completes.

Extraction yield is always 1 per work cycle. The cycle duration (work_ticks) is the tuning knob for extraction rate. Extraction buildings do not deplete — the building reposts a new activity on its next hash tick and the worker typically re-claims via the on-completion poll (see HAULING.md Worker Polling).

Unclaim fires on activity abandonment (need interrupt, draft, death). Death cleanup handles `claimed_tile` in sweepDead step 8.

PROCESSING WORK CYCLE

`work_in_progress` persists on the building across worker changes. If a worker dies or leaves mid-craft, the partial progress remains and any new worker who takes a activity at the building resumes from where the previous worker left off. Buildings with `work_in_progress` always have `max_workers = 1`.

A processing activity is a single activity with an optional source-fetch step preceding the `working` phase and a deposit step following it. The building posts the activity; the worker claims it; the starting phase and whether a source-fetch is needed are configured at claim time based on the building's input bin state. See HAULING.md (Processing source-fetch and Self-deposit) for the full mechanics.

Worker checks `production_orders` top to bottom, takes the first match with available inputs (checked against the building's input bins or any reachable source). Standing orders check if `resource_counts.storage[type]` is below `amount`. `amount = -1` means unlimited — always craft, ignore stockpile count. Finite orders decrement `amount` on each craft completion and are removed at 0.

The worker's cycle within one claim:

1. **Source-fetch** (`to_input_source` phase, configured at claim if the building's input bins are insufficient for the next recipe). Atomic with the claim: resolve nearest source with stock, reserve, route to source, withdraw a full carry load, route to building (`to_workplace`), deposit excess into the input bin. Excess beyond the recipe's needs stays in the bin for future crafts.
2. **Work** (`working` phase). Subtract recipe inputs from bins, begin work action. On completion, finished goods go into `unit.carrying` via `resources.produceIntoCarrying`.
3. **Continuation check.** If `unit:carryableAmount(output_type) >= recipe output amount` AND inputs are available in the bins for another cycle, go to step 2 (no source-fetch needed mid-claim — bins already have what's needed).
4. **Deposit** (`to_storage` phase). When carry can't hold more output, OR bins are empty for the next cycle, route to nearest storage with capacity, deposit. Activity completes. The worker's `onActionComplete` then runs the on-completion poll (HAULING.md Worker Polling) and may re-claim the same workplace immediately, with a fresh source-fetch if bins still need refilling.

Carrying stays single-type — the worker deposits finished goods before any next claim begins a new fetch cycle. No mixed-type carrying.

`#posted_activity_ids < worker_limit` remains the building's posting condition. The activity stays in `posted_activity_ids` from claim through to completion of the deposit step, preserving the workplace slot throughout.

FARMING WORK CYCLE

Planting:

1. Pick next eligible empty tile, travel to it, plant (work action, duration from `CropConfig[crop].plant_ticks`).
2. Repeat until no eligible tiles remain.
3. Leave farm, return to activity queue.

Harvest:

1. Pick next eligible tile, travel to it, harvest (work action, duration from `CropConfig[crop].harvest_ticks`).
2. Crop goes into `unit.carrying` (via `resources.produceIntoCarrying`).
3. More eligible tiles AND carrying has room for next tile's expected yield → go to step 1.
4. More eligible tiles BUT carrying would overflow → drop via ground drop search from the unit's current position (see ECONOMY.md Ground Piles), go to step 1.
5. No more eligible tiles → transition to `to_storage`: route to nearest storage with capacity, deposit (see HAULING.md Self-deposit). Activity completes. If eligible tiles remain on the farm, the farm reposts a new harvest activity and the worker typically re-claims via the on-completion poll (see HAULING.md Worker Polling).

Ground piles dropped on farm tiles during harvest self-post cleanup requests. Haulers convert and clear them in parallel while farmers keep harvesting (see HAULING.md Ground pile cleanup). During "Harvest Now" panic, the farm fills with scattered piles and haulers scramble.

EATING WORK CYCLE

The eat activity is private. See HAULING.md Eating Trip for the trip state machine (phases, post-time path selection, reservation timing) and Eating Behavior for food-selection rules. This section owns the per-item consumption cycle that runs inside the `"consuming"` phase.

On arrival at the consumption site (home bins with food, or a stockpile for a homeless unit), the eat handler enters the per-item loop:

1. Check `getAvailableStock` at the current container. No stock → fall back per HAULING.md Eating Trip (eat-at-home transitions to `"fetching_food_to_source"`; homeless switches source; no reachable source → activity completes).
2. Select the food type (least-recently-eaten available — see Eating Behavior Food Selection).
3. Withdraw 1 item from the container into `unit.carrying` via `resources.moveToCarrying`.
4. Set `current_action = { type = "eat", progress = 0, target = EAT_TICKS }`. Per-tick `eatStep` increments progress. On completion, `onActionComplete` fires.
5. In the eat handler on action complete: destroy the carried item via `resources.consumeFromCarrying`; `unit.needs.satiation += ResourceConfig[type].nutrition` (capped at 100); set `unit.last_ate[type] = current_tick`.
6. Would another item of any available type exceed 100 satiation? → complete activity. Otherwise → go to 1.

Satiation is applied at end-of-action, not at withdraw. A unit whose eat action is interrupted mid-chew (hard energy interrupt, draft, death, building deletion) drops the carried item via the surrounding cleanup path's ground-drop and gains no nutrition from that item. Items consumed earlier in the same meal stay applied.

Food is held in `unit.carrying` for the duration of each eat action. The carry briefly returns to 0 between items inside the synchronous handler, then refills on the next withdraw — no externally-observable gap. `#carrying > 0` is true throughout each action, so soft-interrupt flags (energy soft, equipment want) set during a meal wait until the activity completes per the standard clean-break rule.

SLEEP WORK CYCLE

The sleep activity is a private activity posted and claimed atomically when an energy interrupt fires (soft or hard) or when the per-hash idle fast path detects energy below threshold. Collapse (energy == 0) is a special case — see below.

1. At destination? No → travel. If `home_id` is set, destination is home. If homeless, destination is current tile (no travel).
2. On arrival → set `current_action = { type = "sleep" }`. `sleepStep` handles energy recovery per tick (see Sleep).
3. On sleep complete (energy ≥ wake threshold) → release activity. Unit goes idle.

**Collapse:** When energy hits 0, the hard interrupt fires with standard cleanup (drop, release). The sleep activity is posted with destination = current tile. The handler skips travel and immediately enters sleep. See Sleep for collapse rules.

CONSTRUCTION WORK CYCLE

On building placement: the building is created with `construction_state = "constructing"` (P1) or `construction_state = "blueprint"` (P2, when clearable obstructions exist on footprint tiles — see WORLD.md Placement Validation). A `construction` sub-table is populated — one bin per `build_cost` type, each sized to the exact required amount. For player-sized buildings, total build time is computed as `build_ticks_per_tile * tile_count` and stored on `construction.build_ticks`. Fixed-size buildings copy `build_ticks` from BuildingConfig directly. The builder reads `construction.build_ticks` regardless of building type.

All footprint tiles are immediately claimed (`tile.building_id` set) and impassable (subject to A* exemption for blueprint state — see WORLD.md A* Building Exemption).

**Blueprint state (P2).** When a building is placed with clearable obstructions (trees, berry bushes, ground piles) on its footprint, it enters blueprint state. Clearing activities are posted into `posted_activity_ids`: one chop activity per tree, one clear activity per berry bush (P3). Ground piles on footprint tiles already self-post their own cleanup requests (see HAULING.md Ground pile cleanup) — no additional posting needed for them. A build activity is also posted. Construction delivery requests are NOT posted during blueprint state.

**Unit displacement on blueprint placement (P2).** On placement, iterate all footprint tiles. For each tile, check `tile.target_of_unit`. Any unit whose `target_tile` is on a footprint tile is displaced: release their `target_tile` claim, flood fill outward from the unit's current position using the A* building exemption to find a free tile, claim the new tile, and repath. Units whose position is on a footprint tile but whose `target_tile` is outside the footprint are already leaving and need no intervention.

**Clearing activity flow (P2).** Clearing activities are public — any serf can claim them. The builder also checks for unclaimed clearing activities on their building and claims them with priority (see builder cycle below). A unit claims a clearing activity only if they have carry capacity for the yield. The clearing sequence for each activity:

1. Path to the target tile on the footprint using A* building exemption for this building (adjacent-to-rect 1×1 for trees/bushes, or onto the tile for ground pile pickup).
2. Execute action: chop (trees), clear (berry bushes, P3), or pick up (ground piles).
3. Pick up what can be carried. If yield exceeds carry capacity, excess drops as a ground pile on the same tile — this new pile self-posts a cleanup request (see HAULING.md Ground pile cleanup).
4. Deliver to nearest stockpile with capacity. If no stockpile has capacity, use standard ground drop search from the unit's position (standard merge rules — see ECONOMY.md Ground Piles).

**Blueprint → constructing transition.** When all clearing activities for a building are complete and no units remain on any footprint tile, the building transitions from `"blueprint"` to `"constructing"`. Construction delivery requests for all `build_cost` types are posted at this point (see HAULING.md Construction delivery). Requests live in `world.requests`; the building tracks them on `posted_request_ids` so deletion cleanup can remove them.

**Builder cycle.** The builder checks the building's `construction_state` remotely before deciding where to path:

1. **If blueprint (P2):** Check for unclaimed clearing activities on this building. If any, claim the highest-priority one and execute the clearing sequence (see above). Repeat until no clearing activities remain.
2. **If constructing:** Check each `construction.bins` type: `needed = build_cost[type] - bin_contents - bin_reserved_in`. If needed > 0 for any type AND the corresponding construction delivery request still has `requested_amount > 0`, the builder can claim a trip directly off the request and act as a hauler for it (path to the nearest stockpile with available stock of that type, convert the request into a concrete trip activity, pick up, deliver to building). If `requested_amount == 0` for every type but bins aren't full yet (deliveries in transit by other haulers), path to building and wait at site (adjacent-to-rect). When all materials are present, begin work action at building. `construction.progress` only advances while bins contain all required materials.
3. On completion: bin contents are consumed, `construction` is set to nil, `construction_state` is set to `"complete"`, footprint tiles activate their building roles and the clearing is registered (see WORLD.md Construction States).

When `build_cost` is empty (stockpiles), the construction sub-table has no bins and progress advances unconditionally — just the builder working through `build_ticks`.

**Sub-table initialization on completion.** When `construction_state` transitions to `"complete"`, category-specific sub-tables are populated. `production.input_bins` (processing buildings): one bin per unique input resource type across the building's recipes, with capacity from BuildingConfig. `housing.bins` (housing buildings): one bin per food type from HousingBinConfig. `market.last_delivered` (market): keyed by MerchantConfig food types, all starting at 0.

**P1 vs P2 differences.** The entire construction system — blueprint state, material delivery, builder cycle — is P2+. In P1, buildings are placed instantly as `"complete"` with no construction sub-table and no build activities. The P2 optimization of checking bins remotely and pathing directly to the stockpile applies only in P2.

OFFLOADING

When a unit becomes idle while carrying resources, `onActionComplete` step 2 routes to offloading — a private haul activity that finds the nearest storage with capacity for the carry's type. Offloading is a recovery path for externally-cleared primaries (undrafting with carry, building deletion mid-trip, other clearings that leave a carry behind). See HAULING.md Offloading for triggers, mechanics, and how it interacts with the partial-fill chain.

EQUIPMENT WANTS

The per-hash equipment want check (per-hash loop step 4) fires when a unit's equipment slot is nil AND a matching item is available in storage. Equipment wants do not fire for upgrades to occupied slots — existing equipped items are replaced only through degradation-to-destruction (durability hits 0, item destroyed, slot becomes nil, want check fires on next per-hash). Equipment wants are checked after all need interrupts pass and take priority over the work day check.

If the want fires while the unit is already at a clean break (idle and not carrying), the equipment fetch executes directly. Otherwise `soft_interrupt_pending` is set and consumed at the next clean break (action complete AND not carrying), at which point the unit re-evaluates: needs first, then equipment wants, then work day. If equipment is still wanted at consumption time, the unit posts the equipment fetch.

The fetch itself — source resolution, reservation, travel, withdraw-and-equip — lives in HAULING.md (Equipment fetch variant). The fetch occupies the unit's `activity_id` slot like any other private haul. The item is equipped directly into `unit.equipped` at the source storage building; it never enters `unit.carrying`. When multiple items match the want, higher-quality variants are preferred (ranking mechanism pending design).

NEED INTERRUPTS

Soft and hard need interrupts for satiation are gated on availability — the interrupt only fires if food exists somewhere the unit can reach, respecting reservations. Energy interrupts are never gated — sleep doesn't require a resource, only a tile to lie on. Recreation has no interrupts (see Work Day and Recreation).

**Interrupt priority:** Hard interrupts check satiation before energy — a starving unit eats before sleeping, because starvation kills. Soft interrupts check energy before satiation — sleep drives the daily rhythm, and the overnight satiation drain naturally produces breakfast on wake. Equipment wants are checked after all needs pass. See per-hash loop steps 2–4 for threshold values, availability checks, and cleanup behavior.

**In-progress skip rule.** Per-hash steps 2 and 3 skip the interrupt check for a need when the current activity is already addressing that need — satiation interrupts skip when `registry[activity_id].type == "eat"`, energy interrupts skip when `registry[activity_id].type == "sleep"`. Without this, a unit mid-meal below the hard satiation threshold (or mid-sleep below the hard energy threshold) would re-fire the interrupt every per-hash tick until the need climbed past threshold — releasing the in-progress activity, dropping any carried item, and posting a new activity in the same frame. Cross-need interrupts are unaffected: a sleeping unit still hard-interrupts to eat when satiation collapses, and a unit mid-meal still collapses when energy hits 0.

**Failure mode:** When the settlement has zero available food, no satiation interrupts fire. Units work until malnourishment drains their health to 0. The player's signal is health warnings and death notifications — a sharp, visible collapse.

**Soft interrupt consumption flow:** `soft_interrupt_pending` is consumed at the first clean break — action complete AND not carrying. Two execution paths reach the same logic:

- **Per-hash (idle fast path):** Steps 3–4 detect a threshold crossing. If the unit is already at a clean break (idle and not carrying), the per-hash executes the interrupt directly — recheck, post private need activity, or fall through. No flag set. This eliminates the gap where a flag set on an idle unit would sit unconsumed until a activity appeared or the need degraded to a hard interrupt.
- **onActionComplete (deferred path):** If the unit is mid-work or carrying when the per-hash detects the crossing, it sets `soft_interrupt_pending`. The normal handler continues — carrying units route to deposit. On the next `onActionComplete` where the unit is not carrying, the flag is consumed: clear the flag, recheck the threshold, post private need activity or fall through. See the `onActionComplete` pseudocode for the full priority chain.

**Recheck logic (both paths):** Both needs recheck against their current soft threshold at consumption time. A band transition between detection and consumption can leave the unit no longer below threshold — energy's soft threshold is time-varying by design, and satiation uses the same recheck pattern for consistency even though its threshold is currently flat. If recheck fails, clear the flag silently and fall through to normal behavior. If recheck passes: release `activity_id` (with reservation cleanup per HAULING.md Cleanup), `claimed_tile`; post a private need activity (`"eat"` or `"sleep"`) and claim it via `activity_id`. The handler takes over from there. Priority during recheck: energy, then satiation (availability-gated), then equipment wants. No resource dropping — the unit finished work and deposited cleanly.

**Hard overrides soft:** If a soft interrupt is pending and a hard interrupt fires before the unit reaches a clean break, the hard interrupt takes priority — cancel everything, drop resources, release all state. `soft_interrupt_pending` is cleared as part of the hard interrupt path. The hard interrupt then posts the same private need activity — the difference is the cleanup (hard drops and releases immediately), not the destination.

Need activities are private — posted and claimed atomically by the unit, never visible to other workers. They occupy `activity_id` like any other activity. All existing cleanup paths (death, draft, building deletion) handle need activities through the standard `activity_id` cleanup with no special-casing.

SLEEP

Energy creates the daily rhythm. Units drain energy while awake and recover while asleep. Two thresholds drive the sleep loop, both varying by time of day:

- **Soft threshold** — when energy drops below this, the unit sets `soft_interrupt_pending` and finishes work cleanly before heading to sleep (see Need Interrupts).
- **Wake threshold** — during the sleep action, the unit wakes when energy reaches this value.

Higher values at night pull units into bed and keep them there; lower values during the day let them work freely. This is what creates the synchronized rhythm without an explicit schedule layer. The hard threshold stays flat across all hours (see NeedsConfig).

Four periods divide the day: night (NIGHT_START → MORNING_START), morning (MORNING_START → DAY_START), day (DAY_START → EVENING_START), evening (EVENING_START → NIGHT_START). Period hour constants are in CLAUDE.md. See SleepConfig in TABLES.md for threshold values per period.

Both thresholds are continuous everywhere — every band boundary is a flat-to-lerp or lerp-to-flat junction. Looked up via `time.getEnergyThresholds()`, which returns `{ soft, wake }` for the current time of day.

**Interrupt tiers:**

- **Soft** (`energy < current soft`): Sets `soft_interrupt_pending`. Standard soft interrupt path with recheck on consumption (see Need Interrupts).
- **Hard** (`energy < hard_threshold`): Fires immediately. Standard hard interrupt path (drop carried via ground drop search, release activities).
- **Collapse** (`energy == 0`): Same cleanup as hard, but the unit enters the sleep action on the current tile regardless of `home_id`. No travel.

**Sleep destination:** When a soft or hard interrupt fires for energy, the destination depends on `home_id`. If `home_id` is set, the unit travels home and enters the sleep action at the assigned bed. If `home_id` is nil, the unit enters the sleep action on the current tile. Collapse always sleeps on the current tile, regardless of `home_id`. The `no_home` mood penalty already covers the homeless case continuously — there is no separate penalty for sleeping on the current tile.

**Wake check (per tick during sleep action):** `sleepStep()` adds `SleepConfig.recovery_rate` to `unit.needs.energy` (capped at 100), then checks if `energy ≥ time.getEnergyThresholds().wake`. If so, the sleep action completes and `onActionComplete` fires inline. The sleep activity handler releases the activity; the unit goes idle and picks up work on the next per-hash activity poll. The wake threshold is evaluated live each tick, so a unit sleeping through evening sees the threshold climb and sleeps longer to catch the rising bar. A unit sleeping through morning sees the threshold drop and wakes earlier than the night ceiling would have allowed.

Energy does not drain during the sleep action — drain only applies while the unit is awake (per-hash loop step 1 skips drain when current action is sleep). Hard and soft energy interrupt checks are also skipped while the current activity is `"sleep"` — see Need Interrupts In-Progress Skip Rule.

HOME ASSIGNMENT

Automatic. When a unit needs a home, the system assigns the first housing building with an available bed. Clergy are celibate and never form families, so they tend to live alone. Newborn children are assigned to their parents' home. Units only become homeless if no beds exist anywhere.

When `home_id` is set, assign the first available bed (where `unit_id == nil`). Set both `unit.bed_index` and `bed.unit_id`. If all beds are occupied, the unit still has a home but `bed_index` stays nil — they sleep on the home's tile rather than at a bed. On unit death or home change, clear both sides.

EATING BEHAVIOR

A housed unit eats from its home building's `housing.bins` when food is available; when bins are empty the unit fetches a carry load back from the nearest storage with food before consuming. A homeless unit eats directly from the nearest available food source — see Homeless Eating below. See HAULING.md Eating Trip for the full state machine, post-time path selection, reservation timing, and consumption loop.

See ECONOMY.md for the definition of "food" (resources with `ResourceConfig[type].nutrition`) and the start-time validation that keeps the food set, HousingBinConfig, and MerchantConfig aligned.

**Food selection.** Two selection rules apply at two points in the eat activity:

- *Fetch leg* (`fetching_food_to_source` entry, housed unit bringing food home): resolve the nearest storage with available stock of any food type. At that source, select the food type with the most available stock. The unit brings home whatever single type the source has most of, which makes the trip efficient and leaves variety work to the consumption loop.
- *Consumption iteration* (`consuming`, for home eating and homeless eating): select the food type the unit has eaten least recently — oldest `last_ate` value, with `nil` treated as oldest. This rotates through available types and supports the food variety mood bonus.

Both rules break ties by HousingBinConfig declaration order. This gives deterministic selection whenever two types are equally eligible — notably on a unit's first meal (all `last_ate` values are `nil`) and whenever two stockpile stock counts tie on the fetch leg.

**Food variety mood:** During mood recalculation, count how many distinct food types have `last_ate` within `FOOD_VARIETY_WINDOW` (3 days). Each type beyond the first grants `food_variety_bonus` (+5). No penalty for lack of variety, only a bonus for achieving it.

HOMELESS EATING

When a satiation interrupt fires and `home_id` is nil, the unit eats directly from the nearest available food source rather than from housing bins. The eat activity is posted in `"to_consumption_site"` with destination = the resolved source.

**Source priority:** Tavern (if exists, stocked with food, and open for the evening) → nearest storage building with food whose `getAvailableStock` is > 0 (stockpile or warehouse). Reservations placed by other systems (filter pull haulers, merchants, self-fetch) hide their claimed stock from this check, so homeless eaters never target food that's already spoken for.

**Consumption at the source:** Same per-iteration loop as eating at home. The unit reads `getAvailableStock` for each food type, withdraws 1 of the selected type if any has stock, consumes, repeats until full or out of reachable food. No reservations are placed by the homeless eater at any point.

**Source switching:** When the current source runs out mid-meal and the unit isn't full, the consuming loop resolves the next nearest food source and transitions back to `"to_consumption_site"` pointing at it. This means a homeless unit will eat across multiple stockpiles in one activity if needed to reach full satiation — matching the eat-until-full behavior of housed units.

**Races between homeless units:** Two homeless units walking to the same stockpile both see stock at `getAvailableStock` check time. The loser's per-iteration check finds nothing (single-threaded Lua guarantees the winner's `withdraw` happens-before the loser's check), and the consuming loop falls back to switching sources. Same fallback as the housemate race, different trigger.

Homeless eating is inherently less efficient than eating at home — shared food sources, potentially longer travel, competition with other homeless units.

WORK DAY AND RECREATION

Units have a configurable work day length (10, 11, or 12 hours), set per-unit by the player in the work priority menu. The work day is tracked by `work_ticks_remaining`, a counter that decrements once per tick when the unit's activity has `purpose == "work"` (see per-tick loop step 2). Interrupt and recreation activities do not decrement it.

**Daily reset:** At `WORK_DAY_RESET_HOUR` (4am), `units.resetWorkDay()` walks all living units and sets `work_ticks_remaining` to the unit's configured work hours (converted to ticks) and `is_done_working` to false. The call fires from the calendar-driven block in `simulation.onTick` — see Tick Order. Driving the reset from the orchestrator (rather than per-hash step 5) synchronizes all units to the same daily clock regardless of hash offset, sleep state, or draft state.

**Transition to recreation:** When `work_ticks_remaining` reaches 0, `is_done_working` becomes true. The unit finishes its current task cleanly (including deposit). On the next per-hash step 6 where the unit is idle, recreation selection runs instead of activity polling.

**Recreation as private activities:** Each recreation activity is a separate private activity type with its own handler, following the same pattern as eat and sleep activities. When a recreation handler completes, it releases the activity and the unit goes idle. On the next per-hash step 6, recreation selection evaluates again and may post a different recreation activity. The HASH_INTERVAL gap between recreation activities is natural — a unit standing briefly between "done wandering" and "heading to tavern" looks like a person deciding what to do next.

**Recreation selection (per-hash step 6, `is_done_working == true`):** Evaluate which recreation activity to pursue. Currently two options: visit the tavern (if exists; open hours and per-unit visit tracking pending design alongside other tavern mechanics) or wander near home. Selection runs fresh each time, so a unit that finishes wandering might discover the tavern just opened and head there next. The selection logic lives in one place — per-hash step 6 — not inside individual handlers.

**Wandering work cycle:**

1. Pick a random tile within `RECREATION_WANDER_RADIUS` of home (or current position if homeless). Travel there.
2. On arrival → release activity. Unit goes idle.
3. Next per-hash step 6 selects another recreation activity (may wander again or switch to tavern).

The HASH_INTERVAL gap between arrival and the next per-hash step 6 provides a natural brief pause at each wander destination. Recreation recovers during wandering at `RecreationConfig.recovery_rate`.

**Tavern visit work cycle:**

1. Travel to tavern.
2. On arrival → eat from tavern food bins if hungry. Tavern consumption mechanics are deferred. If beer is available, consume a beer for the `beer_consumed` mood bonus.
3. Recover recreation at the tavern recovery rate. Release activity. Unit goes idle.

The tavern combines the evening meal and recreation into one efficient trip.

**Recreation meter:** Recreation (0–100) feeds mood during recalculation — see per-hash loop step 1 for drain and recovery rates. Low recreation contributes a mood penalty. There is no bonus for high recreation.

**Need interrupts still fire during recreation.** Satiation and energy interrupts work normally while `is_done_working` is true. A recreating unit who gets hungry eats (need interrupt takes priority over recreation activity via standard soft/hard interrupt paths), then the next per-hash step 6 resumes recreation selection. A recreating unit whose energy drops below the soft threshold goes to sleep.

**Work does not preempt recreation.** Once `is_done_working` is true, per-hash step 6 runs recreation selection, not activity polling. New work activities posted during the evening are not picked up until the daily reset.

**Tavern — evening-only model.** The barkeep stocks the tavern with food and beer from storage during daytime work hours. In the evening, units visit to eat and recreate. The tavern is not open for morning meals — homeless units eat from the nearest stockpile in the morning. Barkeep schedule details are deferred.

CARRYING

`unit.carrying` is a flat array of entity ids — both stack entity ids and item entity ids. Total carried weight is `resources.countWeight(unit.carrying)`. `CARRY_WEIGHT_MAX = 32` is the hard cap, uniform across all units. `unit:carryableAmount(type)` returns how many more of a given type the unit can pick up by weight.

Weight governs both carrying and storage density. Resources have a `weight` field; containers have a `capacity` field. The same `weight` value determines how many units fit in a carry load and how many fit on a stockpile tile.

Carrying is always single-type. Activity handlers naturally produce single-type loads (a woodcutter carries wood, a hauler claims one trip for one type, a merchant selects one food type per delivery run). Processing workers who need to switch from carrying output to fetching input deposit first via the `to_storage` step, then any next claim begins a fresh fetch cycle. No exceptions.

Strength affects carrying speed penalty, not capacity — see WORLD.md Movement Speed for the formula.

Workers transport resources as part of their work cycle. This is distinct from dedicated hauling activities.

When a handler starts and the unit is carrying resources wrong for the current work, the handler routes the unit to offload first (see HAULING.md Offloading). If carrying resources valid for the new work, skip to the `working` phase.

DRAFTING

Drafted units (`unit.is_drafted = true`) skip activity polling, need interrupts, and any haul-related work cycle steps (source-fetch, deposit). Needs still drain. Player issues move commands; the command system fans destinations to adjacent tiles so each drafted unit receives a unique `target_tile`. Mid-activity when drafted → abandon (progress persists, claim cleared, reservations released per HAULING.md Cleanup). Energy hits 0 → auto-undraft + collapse on the spot (see Sleep). Undrafting resumes normal behavior on next hashed update. Resources carried when drafted are kept — no ground drop on draft. On undraft, if the unit is still carrying, the next `onActionComplete` routes to offloading.

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

No demotions are currently supported. Freeman and gentry cannot be demoted. Demotion mechanics pending.

CHILDREN

- Children under 6: wander, attend to needs. No work, no school.
- Serf children (age 6+): work unskilled activities from `SerfChildActivities` list.
- Freeman children (age 6+): attend school (grows intelligence).
- Gentry children (age 6+): attend school (grows intelligence).
- Clergy children: do not exist (clergy are celibate).

SPECIALTIES

A specialty is a career — "baker," "smith," "priest." It determines what kind of work a unit seeks, not where they work. Freemen and clergy have specialties. Serfs and gentry do not.

**Assignment:** Player promotes a serf to freeman and assigns a specialty (e.g., "baker"). The unit's `unit.specialty` is set. The unit now searches the activity queue for matching work.

**Dynamic work-finding:** Specialty workers do not have a permanent building assignment. When idle, they poll the activity queue for activities matching their specialty. Buildings post specialty activities when they have work available and an open slot (`#posted_activity_ids < worker_limit`). The worker claims the activity and paths to the building (or to a source first, if the activity has a source-fetch step per HAULING.md). On completion or when no more work is available, the worker polls again. The worker's `activity_id` claim is their slot reservation — it stays set through the entire activity including any source-fetch or deposit steps, preventing the building from double-posting while the worker is away.

**Revocation:** Most specialties are revocable with a mood penalty. Clergy specialties: irrevocable (see Promotion Paths).

**Skill growth:** Specialty freemen and clergy grow their specialty's skill through work. Progress accumulates per tick during the `work` action and is tracked per-skill in `unit.skill_progress`, so changing specialty preserves all previous skill levels and progress. Level-up threshold escalates: `skill_level_ticks * (current_skill + 1)`. Capped at `max_skill` from ActivityTypeConfig. See GrowthConfig for values.

Career ladder: priest → bishop (only). All other specialties are independent.

Knight and combat skill are **deferred** pending combat system design.

**Exception:** Physicians travel to patients rather than working in-building.

SERF ACTIVITY PRIORITIES

Serfs configure per-activity-type priorities (DISABLED / LOW / NORMAL / HIGH). Priorities are per-unit — each serf has their own settings. The player can assign serfs to **priority groups** so that members of a group share the same priority configuration. Serfs not in a group have independent settings. When idle, a serf polls the global activity queue filtered to non-specialty activity types where the serf's priority is not DISABLED, scored by distance + activity age (see Activity Scoring). Priority level (LOW / NORMAL / HIGH) determines relative weighting between activity types. Priority group data structures and group management UI are pending design.

ACTIVITY EFFECTIVENESS

Unskilled activities use `unit:getAttribute(attribute) + tool_bonus`. Specialty work uses `unit:getAttribute(attribute) + skill + tool_bonus`.