# Sovereign — HAULING.md
*v10 · Resource movement: requests, activities, reservations, variant catalog.*

## Overview

Every resource transfer in the game flows through hauling. Workers self-fetching ingredients, the merchant delivering food, units offloading to storage, ground piles being cleaned up, builders bringing materials, units fetching equipment, units traveling home to eat — all of it. This file owns the mechanics of how resource movement works as its own system: the request/activity model, the generic haul cycle, reservation placement and release timing within the haul cycle, the variant catalog, and recovery paths.

Hauling is cross-cutting. The trigger for a haul typically lives elsewhere (need interrupts, equipment wants, work cycles, building deletion) — those sections cross-reference here for the haul mechanics. The container types and reservation API are owned by ECONOMY.md (Containers, Reservation System, Resources Module). The activity entity itself is defined in TABLES.md.

## Requests vs Activities

Two entity types carry haul work. They differ in what they represent and how workers interact with them.

ACTIVITY

A concrete unit of work sized for one worker — one trip, one craft cycle, one chop. Activities live in `world.activities`. A worker claims an activity, executes it through completion, and the activity is removed. Each unit holds at most one activity at a time via `activity_id`.

For hauling, an activity is one trip: pick up an amount, carry it, deposit it. The amount, source, destination, and reservations are all concrete and known at the moment the activity exists.

REQUEST

An aggregate haul need that may take multiple workers across multiple trips to fulfill. Requests live in `world.requests`. Workers don't claim a request directly — they convert it into a concrete haul activity at claim time, sized to their own carry capacity and the source's available stock.

Requests cover three public haul variants where the structural shape is "one entity wants more than one worker's worth of fulfillment, split across independent trips":

- **Filter pull** — a storage building wants N of a type to satisfy its filter limit.
- **Construction delivery** — a constructing building wants `build_cost[type]` of each material type.
- **Ground pile cleanup** — a pile holds N of a type to be moved to storage.

Private haul variants (processing source-fetch, self-deposit, merchant delivery, equipment fetch, eating trip, offloading) are concrete by nature — one trip, one worker, posted-and-claimed atomically by the unit. They never use the request model.

The split: requests = aggregate haul needs in `world.requests`; activities = concrete in-flight or claimable assignments in `world.activities`. Workers polling for work scan both.

REQUEST ENTITY

```lua
request = {
    id = 0,
    type = "filter_pull",        -- "filter_pull" | "construction_delivery" | "ground_pile_cleanup"
    resource_type = nil,         -- the type being moved
    source_id = nil,             -- building id, ground pile id, or nil (per variant semantics)
    destination_id = nil,        -- building id, or nil (per variant semantics)
    requested_amount = 0,        -- aggregate need
    posted_tick = 0,             -- for scoring

    -- Cached per tick by validateEligibility for scoring (see Eligibility Validation below)
    cached_source_id = nil,      -- resolved source, when source was nil at request time
    cached_destination_id = nil, -- resolved destination, when destination was nil at request time
    cached_source_to_dest = nil, -- Manhattan distance between (resolved) source and destination
}
```

Requests have no `worker_id` — they aren't claimed in the activity sense. They have no `reserved_amount` — concrete reservations live on the activities created at claim time.

REQUEST → ACTIVITY CONVERSION

When a worker claims a request, the conversion is atomic:

1. Compute trip amount = `min(requested_amount, hauler_carry_for_type, source_available_stock_for_type)`.
2. Resolve source if nil (ground pile cleanup picks the pile; filter pull "from anywhere" picks the nearest valid source — see Storage Filter System in ECONOMY.md). If a cached source from this tick's validation is still valid, prefer it.
3. Resolve destination if nil (ground pile cleanup picks the nearest storage with capacity). If a cached destination from this tick's validation is still valid, prefer it.
4. Place reservations: `reserved_out` on source, `reserved_in` on destination.
5. Create a concrete haul activity with the resolved endpoints, trip amount, and reservation amounts on `source_reserved_amount` and `destination_reserved_amount`.
6. Set `activity.worker_id` and the worker's `activity_id`.
7. Decrement `request.requested_amount` by the trip amount. If it hits zero, remove the request from `world.requests` and from the posting entity's `posted_request_ids` (for building-posted requests).

The conversion is one operation. Between two workers polling in the same tick, claims serialize per-unit during per-hash iteration, so the second worker sees the updated `requested_amount` (or no request, if the first worker drained it).

## Generic Haul Cycle

Six steps for any concrete haul activity, in order:

1. **Claim** — a unit takes ownership of the activity. Private hauls are posted-and-claimed atomically by the posting unit. Activities converted from requests are created already-claimed during the conversion step. Either way, the claim sets `activity.worker_id` and the unit's `activity_id`. Concrete haul activities never sit unclaimed in `world.activities` — there is no queue-scan path for them. Worker polling scans `world.activities` for unclaimed work activities (gathering, processing, etc.) and `world.requests` for haul work; concrete haul activities only appear in `world.activities` after they've been claimed.
2. **Reserve** — `reserveOutbound` on the source container if source is set, `reserveInbound` on the destination container if destination is set. Reservation amounts are stored on the activity as `source_reserved_amount` and `destination_reserved_amount`. For activities created from requests, reservations are placed during the conversion in step 1; this step is already complete on the activity's first execution. For private hauls, reservations are placed atomically with the post.
3. **Travel to source** — path to the source container's location. Phase string: `to_source`. Skipped when source is nil (the resource is already in `unit.carrying` — self-deposit, offloading).
4. **Pickup** — `moveToCarrying` from the source, then `releaseOutbound` for the source-side reservation. Clear `source_reserved_amount` on the activity.
5. **Travel to destination** — path to the destination container's location. Phase string: `to_destination`. Skipped for pickup/use variants where consumption happens at the source (equipment fetch).
6. **Deposit** — `moveFromCarrying` into the destination, then `releaseInbound` for the destination-side reservation. Clear `destination_reserved_amount` on the activity. The activity is removed from `world.activities`. For pickup/use variants, this step collapses entirely; the resource never enters `unit.carrying`.

`source = nil` and `destination = nil` are the two shape variations on the generic cycle. Both steps that depend on the missing endpoint collapse. Pickup/use variants collapse the deposit step entirely.

PHASE STRINGS

Every activity sets `activity.phase` — always a non-nil string. Phase is used by handlers for transition logic and is visible during debugging. Cleanup does not branch on phase — see Cleanup below.

Pure haul activities share a two-string vocabulary: `to_source` (between claim/reserve and pickup) and `to_destination` (between pickup and deposit). Work activities and private need activities use type-specific phase strings — no borrowing haul strings inside a processing or gathering activity, where `to_input_source` and `to_storage` are clearer than reusing `to_source` / `to_destination` twice for different endpoints.

Starting phase varies by claim-time state (unit position, carry, whether source-fetch is needed). Handlers pick the starting phase on dispatch.

Full catalog:

| Activity | Phases |
|---|---|
| Haul (filter pull, construction delivery, ground pile cleanup, merchant delivery, offloading, self-deposit) | `to_source`, `to_destination` |
| Equipment fetch (pickup/use) | `to_source` |
| Processing | `to_input_source`, `to_workplace`, `working`, `to_storage` |
| Gathering (hub-based) | `to_hub`, `to_resource`, `working`, `to_storage` |
| Designation | `to_resource`, `working`, `to_storage` |
| Extraction | `to_workplace`, `working`, `to_storage` |
| Farming planting | `to_tile`, `working` |
| Farming harvest | `to_tile`, `working`, `to_storage` |
| Clearing (chop, bush clear, ground pile pickup) | `to_tile`, `working`, `to_storage` |
| Build | `to_site`, `waiting`, `working` |
| Sleep | `to_sleep_site`, `sleeping` |
| Wander | `wandering` |
| Tavern | `to_tavern`, `at_tavern` |
| Eat | `to_consumption_site`, `fetching_food_to_source`, `fetching_food_returning`, `consuming` |

Collapse sleep starts directly in `sleeping` (no travel). Self-deposit and offloading (both with source = nil, unit already carrying) start in `to_destination`.

## Reservations

Both `reserved_out` (source) and `reserved_in` (destination) are placed at the moment the haul activity exists with concrete endpoints. For private hauls, that's at post time (post and claim are atomic). For activities converted from requests, that's at conversion time. The "reservations placed on claim" rule holds uniformly across all transport variants. Eating is a partial carve-out: transport legs (`fetching_food_to_source`, `fetching_food_returning`) follow the standard rule; consumption legs (`to_consumption_site`, `consuming`) place no reservations — per-iteration `getAvailableStock` checks handle source-switching and race tolerance without needing them. See Eating Trip below for details.

Both reservations track the same amount in normal transport hauls — what gets reserved at the source equals what gets reserved at the destination. Two cases break the symmetry:

- **Equipment fetch** (pickup/use variant): only source is reserved; destination is nil.
- **Merchant delivery first trip**: source reserves the full carry load (to prevent other haulers grabbing the merchant's load); destination reserves only `drop_amount` (the amount actually delivered to the first home). Subsequent trips have source = nil and only destination matters.

The activity carries both `source_reserved_amount` and `destination_reserved_amount` as separate fields. Each is set when the corresponding reservation is placed and cleared when the matching release verb runs after the move. The full destination-side reservation is released when the deposit completes regardless of how much was actually deposited — the partial-fill chain handles any overflow separately. Cleanup reads both fields directly — non-zero means the reservation is still outstanding and needs release.

See ECONOMY.md Reservation System for the underlying invariant and the resources module API (`reserveInbound`, `reserveOutbound`, `releaseInbound`, `releaseOutbound`, `getAvailableStock`, `getAvailableCapacity`).

## Activity Slot

Each unit has one activity slot: `activity_id`. It holds whatever the unit is currently doing — a work assignment, a private haul, a need activity, a recreation activity. There is no separate slot for hauling activities running alongside other work; private hauls that used to occupy a "secondary" slot are now either embedded as steps of the slot-holding activity (processing's source-fetch and deposit steps) or take the slot themselves (eat, sleep, equipment fetch, offloading).

The single-slot model means cleanup paths walk one field per unit. Building deletion, unit death, draft, and need interrupts all check `activity_id` and apply the appropriate cleanup matrix.

## Cleanup

Reservations get released when the activity ends in any of these ways: normal completion (the activity handler calls `releaseOutbound` after pickup and `releaseInbound` after deposit), abandonment, building deletion, unit death, hard need interrupt, draft, or soft interrupt recheck.

For abandonment and external clearing paths, cleanup logic releases whatever reservations are still outstanding. Read `source_reserved_amount` and `destination_reserved_amount` directly from the activity; if non-zero/non-nil, release at the corresponding container via `resources.releaseOutbound` (source) or `resources.releaseInbound` (destination). The two fields are the source of truth for "what's still reserved" — no need to consult the activity's phase.

After releasing reservations, remove the activity from `world.activities` and registry, then clear the unit's `activity_id`. If the unit is carrying resources at the time of cleanup, the carry is handled by the surrounding cleanup path (hard interrupts ground-drop, building deletion offload-routes, death drops via ground pile drop in `units.sweepDead`). Hauling cleanup itself doesn't decide what happens to the carry — only the activity and reservations.

## Variant Catalog

Variants are organized by what produces the haul work and how the unit interacts with it.

REQUEST-BASED PUBLIC HAULS

Workers claim requests from `world.requests` and convert them into concrete haul activities at claim time. See Request → Activity Conversion above.

**Filter pull.** A storage building with a filter entry in "pull" mode posts a request when its deficit is non-zero. Source = the resolved source storage building (specific via `source_id` on the filter entry, or nearest with stock if unset). Destination = the pulling building's storage. See ECONOMY.md Storage Filter System for source resolution, cycle detection, and the deficit math. The filter system maintains at most one request per filter entry; the request's `requested_amount` is updated each scan to match the current deficit (and removed when the deficit reaches zero). The pulling building tracks the request in its `posted_request_ids`.

**Construction delivery.** When a building transitions from blueprint to constructing (or is placed directly as constructing in P1+), a request is posted for each `build_cost` type. Source = nil at request time; the hauler resolves the nearest storage with available stock at conversion time. Destination = the building's construction bin for the matching type. Requests are tracked on the building's `posted_request_ids` so that building deletion cleanup can remove them. See Construction Work Cycle in BEHAVIOR.md for the surrounding flow.

**Ground pile cleanup.** When a ground pile is created or grows, it posts one request per resource type it contains. Source = the ground pile entity. Destination = nil at request time; the hauler resolves the nearest valid storage with capacity at conversion time. The request's `requested_amount` matches the pile's current contents of that type and is updated on each withdrawal. When the request hits zero (all of that type withdrawn), the request is removed; when the pile is fully emptied, the pile is destroyed (see ECONOMY.md Ground Piles). If no storage anywhere has capacity, the request stays posted but no conversion succeeds — the pile persists on the ground until space opens up.

PRIVATE TRANSPORT HAULS

Posted and claimed atomically by the unit. Both endpoints are concrete at post time, source-side and destination-side reservations are placed in the same step, and the activity occupies the unit's `activity_id` slot.

**Processing source-fetch.** A processing activity is a single activity with an optional source-fetch step preceding the workplace step. When a worker claims a processing activity and the building's input bins are insufficient for the next recipe, the claim is atomic with: resolving the nearest storage with available stock for the needed input, reserving the source-side stock, and configuring the activity to start in `to_input_source`. The worker travels to source → pickup full carry load → travels to workplace (`to_workplace`) → executes the work loop (`working`) → produces output → executes the deposit step (`to_storage`). If bins are sufficient at claim time, the source-fetch is skipped; the activity starts directly in `to_workplace`. Excess input beyond the recipe's needs stays in the bin for future crafts. Applies to any worker at a processing building regardless of class. Source resolution includes stockpiles, warehouses (for stackable inputs), barns (for items), and ground piles.

Mid-craft input depletion (the worker has finished one craft, has carry room for more output, but bins are empty for the next recipe): the worker completes the current activity normally (executing the deposit step for output already in carry), returns to idle, polls. If the workplace re-posts (still has eligible work after re-validation), the worker re-claims with a fresh source-fetch. The HASH_INTERVAL gap that would have applied is short-circuited by `onActionComplete`'s on-completion poll (see Worker Polling below).

**Self-deposit.** The deposit step of a work activity that ended with output in carry — processing crafting outputs, gathering returning with resources, farming completing a harvest with crop in carry. Destination = nearest storage with available capacity for the carried type (stockpiles and warehouses for stackable resources, stockpiles and barns for items). The worker resolves destination at the moment the deposit step begins, reserves destination-side capacity, travels, deposits. If the destination's available capacity is less than the carry, the partial-fill chain handles the remainder — see below.

**Merchant delivery.** Each merchant delivery trip is a concrete private haul activity. The merchant runs an internal delivery loop (see ECONOMY.md Merchant Delivery System for the loop and food-selection logic). Per trip: source = nearest storage building with available stock of the selected food type; destination = the next eligible home's matching food bin. The merchant carries up to `CARRY_WEIGHT_MAX` and drops `drop_amount` at each home. After dropping, if still carrying and more eligible homes exist, posts a new private activity for the next home (source = nil, destination = next home's bin). When carry is empty or no more eligible homes exist, returns to market and restarts the loop.

PRIVATE PICKUP/USE HAULS

Equipment fetch reserves at the source, travels to the source, withdraws, and applies the resource to the unit immediately — no transport, no deposit, the resource never enters `unit.carrying`. The eat activity is a hybrid: its consumption legs behave like pickup/use (no transport, withdraw-and-consume at the current container), but it may also perform a full transport cycle via its fetch legs when a housed unit needs to bring food home from storage.

**Equipment fetch.** When the per-hash equipment want check identifies a missing equipment slot (slot is nil) AND a matching item is available in storage, the unit posts a private haul activity. Source = nearest stockpile or barn with a matching item, preferring higher-quality variants when multiple are available (ranking mechanism pending design). Destination = nil. The unit reserves via `reserveOutbound`, travels to the storage building, and equips-from-source in one step via `resources.equipFromContainer` — directly into `unit.equipped`, never via `unit.carrying`. The outbound reservation releases via `releaseOutbound` after the equip, or on death/interrupt cleanup.

Equipment wants fire only when a slot is nil — never for upgrades to occupied slots. Existing equipped items are replaced only through degradation-to-destruction; when durability hits 0, the item is destroyed (see ECONOMY.md Item), the slot becomes nil, and the want check fires normally on the next per-hash. See BEHAVIOR.md Equipment Wants for the want-check trigger logic.

**Eating trip.** Posted when a satiation interrupt fires (soft or hard) or when the per-hash idle fast path detects satiation below threshold. Eat is a hybrid variant: the two fetch phases are standard private transport hauls with source and destination reservations; the two consumption phases (`to_consumption_site`, `consuming`) place no reservations — per-iteration `getAvailableStock` checks during the consumption loop respect every other system's reservations without needing to place their own.

Phase strings:

- `"to_consumption_site"` — traveling to the consumption location (home for eat-at-home when home has food, or the resolved source stockpile for homeless). No reservations. Name avoids collision with `"fetching_food_to_source"` below — "source" means different things in the two phases (consumption site vs haul source).
- `"fetching_food_to_source"` — eat-at-home only: home bins are empty, traveling to a stockpile to fetch food. Standard private transport: source-side `reserved_out` and destination-side `reserved_in` placed at entry. Source and food type resolved per the fetch-leg selection rule in BEHAVIOR.md Eating Behavior (nearest storage with food, then most-available type at that source, ties by HousingBinConfig order).
- `"fetching_food_returning"` — eat-at-home only: fetched food in carry, traveling back to home to deposit. Destination reservation released on deposit per the standard rule.
- `"consuming"` — at the destination, running the consumption loop. No reservations.

Post-time path selection (atomic with the post):

- `home_id` set AND home bins contain food → post in `"to_consumption_site"` with destination = home. Unit travels home, enters `"consuming"` on arrival.
- `home_id` set AND home bins empty → post in `"fetching_food_to_source"`. Unit resolves nearest food source with available stock, reserves source-side and destination-side, travels, picks up, transitions to `"fetching_food_returning"`, walks home, deposits into home bin, releases destination reservation, enters `"consuming"`.
- `home_id` nil → post in `"to_consumption_site"` with destination = nearest food source (per Homeless Eating priority in BEHAVIOR.md). Unit travels, enters `"consuming"` on arrival.

Fetch amount (at `fetching_food_to_source` entry): `min(carryableAmount(food_type), getAvailableStock(source, food_type))`. Home bins are uncapped (see ECONOMY.md Containers), so the destination term drops out — the fetch is bounded only by the unit's carry and the source's available stock.

Consumption phase (`"consuming"`). The per-item consumption cycle runs here — see BEHAVIOR.md § Eating Work Cycle for the loop (stock check, food selection, withdraw, eat action, nutrition update, satiation check). This phase owns the trip-level fallbacks for when the loop exits without the unit being full:

- Eat-at-home: transition to `"fetching_food_to_source"` with fresh reservations, resolve nearest source, travel.
- Homeless: resolve next nearest food source, transition to `"to_consumption_site"`, travel.
- No reachable source: activity completes.

The activity's `source_id` and `destination_id` are rewritten on phase transitions to reflect the current sub-trip. Reservation fields (`source_reserved_amount`, `destination_reserved_amount`) are populated during `"fetching_food_to_source"` / `"fetching_food_returning"` and cleared before entering `"consuming"` or `"to_consumption_site"`. See BEHAVIOR.md Eating Behavior for `last_ate` tracking, food variety mood, and homeless source priority.

Races during consumption (both phases place no reservations):

- Two housemates both arrive home expecting food — whichever iterates first gets what's there; the loser's consumption loop finds nothing, falls back to `"fetching_food_to_source"` (which then places standard reservations for the fetch).
- Two homeless units walk to the same stockpile — whichever iterates first gets what's there; the loser's loop finds nothing, falls back to switching sources.

The transport legs (`fetching_food_to_source`, `fetching_food_returning`) don't race — reservations serialize them. A unit that fetches via `fetching_food_to_source` has source stock reserved at post time, so no other consumer or hauler can take it.

Races between consumption and reserving systems (filter pull haulers, merchants, self-fetch): the eating unit's per-iteration availability check uses `getAvailableStock`, which respects the other system's reservations. The eating unit only withdraws what's not already spoken for, so no clash with reserving systems.

OFFLOADING

A first-class private haul variant for the recovery case where a unit ends up idle while carrying resources. Triggered by `onActionComplete` step "idle + carrying" (see BEHAVIOR.md Action System).

**When it fires.** Offloading is narrow but important — it's the safety net for externally-cleared activities. Concrete triggers:

- Undrafting with carry. A drafted unit kept their carry through the draft (no ground drop on draft); on undraft, they're idle + carrying.
- Building deletion mid-trip. A unit carrying resources toward a building that gets deleted has their `activity_id` cleared by the deletion matrix (see Building Deletion in BEHAVIOR.md); on the next `onActionComplete`, they're idle + carrying.
- Any other external clearing that leaves a carry behind.

It does not fire in normal flow. Normal flow completes the deposit step as part of the slot-holding activity (processing, gathering trip end, farming harvest end, merchant delivery, etc.). Offloading is the recovery path for when those normal flows are interrupted.

**Mechanics.** Source = nil (resources are in `unit.carrying`). Destination = nearest storage building with available capacity for the carried type. The unit posts a private haul activity, reserves destination-side capacity, travels, deposits. The activity occupies the unit's `activity_id` slot — there is no underlying work activity to preserve, so offloading uses the only slot.

If the destination's available capacity is less than the carry, the partial-fill chain handles the remainder. If no storage anywhere has capacity for the type, the carry is dropped via ground drop search at the unit's current position (see ECONOMY.md Ground Piles).

## Partial-Fill Chain

Applies whenever a deposit doesn't consume the full carry. The driving cases:

- The destination was resolved at runtime as "nearest storage with available capacity" but holds less than the carry (self-deposit, offloading, ground pile cleanup converted into a haul activity).
- The destination's capacity has been reduced since the reservation was placed — the player lowered a filter limit on the destination mid-transit, leaving the in-flight reservation amount above the new available capacity.

Both cases are handled by the same mechanism. At deposit time, the deposit honors the destination's *current* available capacity, not the original reservation amount. Deposit `min(carried_amount, getAvailableCapacity(destination, type))`. Release the destination-side reservation in full regardless of how much was actually deposited. If carry is still non-empty after the deposit, the activity completes normally and `onActionComplete` fires with the unit still carrying the remainder. The "idle + carrying" branch routes to offloading: post a new offload activity for the next nearest storage with capacity, repeat.

The chain repeats until the carry is empty or no storage anywhere has capacity, at which point the remaining carry is dropped via ground drop search at the unit's current position.

The chain applies to any haul whose destination capacity could shrink between reservation and delivery — which under the player-intervention carve-out means effectively all variants. Variants with config-driven capacity (processing input bins, construction bins) won't see shrinkage in practice, but the mechanism is uniform. Housing bins are uncapped (see ECONOMY.md Containers), so shrinkage is definitionally impossible for eat-activity deposits.

## Worker Polling

Worker polling for new work scans both `world.activities` (unclaimed concrete activities) and `world.requests` (aggregate haul needs). Filter rules and scoring are the same:

- Specialty match for freemen and clergy (matches `unit.specialty`).
- Priority-weighted filtering for serfs (per the serf's per-activity-type priority settings).
- Activity scoring: `score = ActivityConfig.age_weight * (current_tick - posted_tick) - manhattan_distance`. Higher score wins.

Distance for activities follows BEHAVIOR.md Activity Scoring (workplace building for building-based work, target tile for designation).

Distance for requests uses `distance(hauler, source) + cached_source_to_dest`, where the source-to-destination leg is cached once per tick per request by `validateEligibility` (see Eligibility Validation below). This correctly captures the total trip cost across all three request types — a hauler far from stockpiles loses to a hauler closer to stockpiles even when both are equidistant from the destination, and cross-request ranking correctly penalizes requests whose cached source-to-destination leg is long. The `source` term in the per-hauler calc uses the cached resolved source (from validation) — no per-hauler source resolution is needed.

ON-COMPLETION POLL

`onActionComplete` polls for new work when a unit just finished an activity and is idle + not carrying. This sits between the "idle + carrying → offload" branch and the "no activity → idle" branch. If the poll finds eligible work, the unit claims and dispatches immediately. If not, falls through to idle and waits for the next per-hash tick, same as any other idle unit.

This eliminates the HASH_INTERVAL gap that would otherwise occur between completing one activity and starting the next. Per-hash polling (BEHAVIOR.md per-hash loop) remains the only polling mechanism for units who became idle without finishing an activity (e.g., after a hard interrupt completed and they're awake again).

ELIGIBILITY VALIDATION

Both activities and requests carry an `is_eligible` flag, validated once per tick at the top of `simulation.onTick` by `activities.validateEligibility()`. The validation pass walks `world.activities` and `world.requests`, calling a per-type eligibility predicate for each, and writes the flag. Workers scanning the queues skip entries flagged false.

Eligibility validation applies only to entries that sit in the scanned queues — public requests in `world.requests` and building-posted activities in `world.activities` (operational work, build, designation). Private hauls (eat, sleep, recreation, equipment fetch, offloading, merchant delivery, processing source-fetch, self-deposit) are posted-and-claimed atomically within a single tick and are never scanned by other workers, so they don't need revalidation.

As part of the same pass, eligible requests with a nil endpoint also get their endpoint resolved and their `cached_source_to_dest` computed and written. This allows scoring to read precomputed distances without per-hauler source resolution — see Worker Polling. The cache is refreshed every tick; staleness is bounded at one tick.

Predicates by type:

- **Processing activity** — at least one production order in the queue has its next recipe's inputs available somewhere reachable (the building's input bins + any storage building with stock + any ground pile with stock), respecting reservations.
- **Filter pull request** — `requested_amount > 0` AND source has stock (specific source per `source_id`, or any non-pull-mode storage if "from anywhere"). On eligible requests, resolve and cache source if needed, and cache `source_to_dest` distance.
- **Construction delivery request** — `requested_amount > 0` AND at least one storage building has stock for the type. On eligible requests, resolve and cache source, and cache `source_to_dest` distance.
- **Ground pile cleanup request** — `requested_amount > 0` AND at least one valid storage with capacity exists. On eligible requests, resolve and cache destination, and cache `source_to_dest` distance.
- **Gathering activity (building-based)** — at least one valid unclaimed target tile reachable from the building.
- **Designation activity** — target tile still has the resource.
- **Farmer planting activity** — `farming.allow_planting == true` AND `world.time.is_frost == false` AND at least one empty tile exists on the farm.
- **Farmer harvesting activity** — at least one planted tile is eligible for harvest per the farm's `auto_harvest` mode (`per_tile`: tile at maturity 1.0; `per_farm`: all planted tiles at maturity 1.0; `off`: never auto-eligible) OR has a matching `farming.harvest_flagged[tile_idx]` entry.
- **Trivially-always-valid types** (extraction, service jobs at staffed buildings) — no flag set; worker scan treats unflagged entries as eligible.

The eligibility flag is `nil` (or absent) for trivially-eligible types to avoid initialization overhead. Workers filter by `is_eligible == false` (skip), with everything else passing through.

## Carrying Interaction

Carrying is single-type (see BEHAVIOR.md Carrying). Activity handlers naturally produce single-type loads. A worker who finishes a craft cycle with output in carry and needs to switch to fetching input must complete the deposit step for the output before any source-fetch begins — the partial-fill chain ensures the carry empties cleanly.

When a worker becomes idle while carrying resources wrong for any of their next eligible activities, the `onActionComplete` "idle + carrying" branch routes to offload first. The carry is single-type, so offload is unambiguous — drop the current type to storage, then the next claim can be a fresh activity producing a different type.

## Cross-References

- **Containers and reservation API** — ECONOMY.md Resource System (Containers, Reservation System, Resources Module).
- **Activity entity structure** — TABLES.md Data Structures (ACTIVITY).
- **Request entity structure** — TABLES.md Data Structures (REQUEST).
- **Triggers for haul variants** — BEHAVIOR.md (Need Interrupts for eat, Equipment Wants for equipment fetch, Processing Work Cycle for self-fetch, Gathering Work Cycle for harvest deposit, Farming Work Cycle for harvest deposit, Construction Work Cycle for builder dispatch, Building Deletion for offload routing).
- **Storage filter mechanics and pull deficit math** — ECONOMY.md Storage Filter System.
- **Merchant delivery loop** — ECONOMY.md Merchant Delivery System.
- **Ground pile creation and drop search** — ECONOMY.md Ground Piles.
- **Carrying mechanics and weight cap** — BEHAVIOR.md Carrying.
- **`onActionComplete` priority chain** — BEHAVIOR.md Action System.
- **Activity scoring formula** — BEHAVIOR.md Activity Scoring.
- **Eating consumption loop, food variety, homeless source priority** — BEHAVIOR.md Eating Behavior, Homeless Eating.
