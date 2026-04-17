# Sovereign — ECONOMY.md
*v12 · Resource infrastructure: entities, containers, reservations, storage filters, merchant delivery, firewood.*

## Resource System

Resources exist as two entity types: **stacks** (fungible, mergeable) and **items** (unique, non-fungible). `ResourceConfig[type].is_stackable` determines which type a resource uses. All resource entities live in `world.stacks` or `world.items` and are indexed in `registry[id]`.

STACK

```lua
stack = {
    id = 0,
    type = "wood",
    amount = 12,
}
```

Stacks are fungible — two stacks of wood are interchangeable. The id gives the stack a handle for the registry and hauling system, not meaningful identity. Stacks can be split and merged. When a stack's amount reaches 0, it is destroyed (removed from `world.stacks` and registry).

ITEM

```lua
item = {
    id = 0,
    type = "iron_tools",
    durability = 100,    -- starts at ResourceConfig[type].max_durability
    -- future: quality, enchantment
}
```

Items are non-fungible — each one is unique. Durability decreases over time: tools drain per tick during the `work` action, clothing drains per tick while awake. When durability reaches 0, the item is destroyed (removed from `world.items` and registry). The unit continues at base effectiveness until a replacement is equipped. Exact drain rates are pending tuning per phase.

CONTAINERS

Five container types, each with reservation tracking for in-transit resources:

**Bin** — single-typed container with its own capacity. Holds a flat array of entity ids (stacks or items depending on the resource type). Used by: housing (one bin per food type), processing building inputs (one bin per recipe input type), construction build inventory (one bin per build_cost type).

```lua
bin = {
    container_type = "bin",
    type = "flour",      -- resource type this bin holds
    capacity = 128,      -- max weight (stackable) or max item count (items)
    contents = {},       -- flat array of entity ids
    reserved_in = 0,     -- weight/count spoken for by inbound deliveries
    reserved_out = 0,    -- weight/count spoken for by outbound pickups
}
```

**Tile inventory** — array of building-owned tiles, each holding stacks (weight-capped) or one item. Used by: stockpiles. Each tile entry:

```lua
tile_entry = {
    contents = {},       -- flat array of entity ids
    reserved_in = 0,
    reserved_out = 0,
}
```

Per-tile capacity is `STOCKPILE_TILE_CAPACITY` for stacks. Items: one per tile regardless of weight. A building-level `filters` table controls which types the stockpile accepts and how — see Storage Filter System for filter semantics.

**Stack inventory** — flat array of stack entity ids with total weight capacity. Used by: warehouses. Only accepts stackable resources.

```lua
stack_inventory = {
    container_type = "stack_inventory",
    capacity = 0,        -- total weight capacity
    contents = {},       -- flat array of stack entity ids
    filters = {},        -- per-type filter entries (stackable resources only) — see Storage Filter System
    reserved_in = 0,
    reserved_out = 0,
}
```

**Item inventory** — flat array of item entity ids with count cap. Used by: barns. Only accepts non-stackable items. No tile representation — UI panel based.

```lua
item_inventory = {
    container_type = "item_inventory",
    item_capacity = 40,  -- max number of items
    contents = {},       -- flat array of item entity ids
    filters = {},        -- per-type filter entries (items only) — see Storage Filter System
    reserved_in = 0,
    reserved_out = 0,
}
```

**Ground pile** — entity on a map tile holding dropped resources. Flat array of entity ids (stacks and items mixed). No capacity enforcement, no filters. Transient — created by the drop function, destroyed when emptied. See Ground Piles section for full details.

Which buildings use which:

| Building type | Container | Access path |
|---|---|---|
| Stockpile | Tile inventory (1 tile entry per stockpile tile) | `building.storage` |
| Warehouse | Stack inventory | `building.storage` |
| Barn | Item inventory | `building.storage` |
| Housing | Bins (one per food type from HousingBinConfig) | `building.housing.bins` |
| Processing input | Bins (one per recipe input type, from BuildingConfig) | `building.production.input_bins` |
| Construction | Bins (one per build_cost type, exact capacity) | `building.construction.bins` |
| unit.carrying | Flat array of entity ids (weight-capped, single-type) | `unit.carrying` |
| Ground pile | Entity with flat contents array | `ground_pile` entity |

Storage buildings access their container through `building.storage`. The `container_type` field on the container discriminates between tile_inventory, stack_inventory, and item_inventory — the resources module dispatches internally.

RESERVATION SYSTEM

All containers use `reserved_in` and `reserved_out` to prevent collisions from concurrent resource movement. Ground piles use `reserved_out` only (nothing delivers into a ground pile).

- **Available capacity** = capacity - used - reserved_in
- **Available stock** = stock - reserved_out

Reservations are placed when a haul activity is claimed (whether public or private). Every resource transfer in the game goes through a haul activity — self-fetch, self-deposit, filter pull activities, construction delivery, merchant delivery, and ground pile cleanup all post activities and all use reservations.

Activities fall into two categories:

| Category | Posted by | Claimable by | Examples |
|---|---|---|---|
| Private | Unit, claimed atomically | Same unit only | Self-fetch, self-deposit, merchant delivery, home food self-fetch, eating trip reservation, equipment want fetch |
| Public | System or entity | Any eligible hauler | Construction delivery, ground pile cleanup, filter pull activities |

Private activities are invisible to other units but visible to the reservation system. They exist purely as a vehicle for reservation tracking and cleanup.

**Reservation lifecycle:** Reserve on claim → release on delivery/pickup → also release on death, need interrupt, activity cancellation, or building deletion. The `secondary_haul_activity_id` on the unit tracks private activities so death cleanup can find and release their reservations.

RESOURCES MODULE (`simulation/resources.lua`)

The resources module is the sole owner of all resource mutations. Every operation that creates, destroys, moves, or reserves resource entities goes through this module — no other module writes directly to container contents, reservation fields, or `world.resource_counts`. All functions use dot syntax (no `self`).

All mutation operations maintain `world.resource_counts` as a running tally — see Resource Counts.

The module uses a generic container interface. Callers pass a container reference (e.g., `building.storage`, `building.housing.bins[i]`, `building.production.input_bins[i]`, or a ground_pile entity). The module dispatches internally based on `container.container_type`. Callers never branch on container type.

**Query operations:**

- `resources.getStock(container, type)` — total amount of `type` in the container.
- `resources.getAvailableStock(container, type)` — stock minus `reserved_out`. What can actually be picked up.
- `resources.getAvailableCapacity(container, type)` — remaining capacity minus `reserved_in`. For storage containers with a filter limit on `type`, returns `min(physical_capacity, limit - current_stock_of_type) - reserved_in`. Ground piles return a large value (no capacity enforcement by the container — the drop function manages per-tile weight limits externally).
- `resources.accepts(container, type)` — filter check. Bins: `container.type == type`. Tile inventory / stack inventory / item inventory: `filters[type].mode ~= "reject"`. Ground piles: always true.
- `resources.countWeight(carrying)` — total weight across all entity ids in a flat array. Used for carrying weight checks.

**Transfer operations:**

- `resources.deposit(container, entity_id)` — add a resource entity to the container. For tile inventory, selects the best tile internally (same-type tile with capacity, or empty tile). Updates resource counts for the destination category.
- `resources.withdraw(container, type, amount)` — remove `amount` of `type` from the container. Returns an array of entity ids (may split a stack). For tile inventory, scans tiles internally. Updates resource counts for the source category.
- `resources.transfer(source, destination, type, amount)` — withdraw from source + deposit to destination in one call. Updates resource counts for both categories.

**Carrying operations (weight-based, separate from generic container API):**

- `resources.carryEntity(unit, entity_id)` — move an existing entity into `unit.carrying`. For stacks, if already carrying the same type, merges (adds amount, destroys the incoming entity). If carrying is empty, appends. Asserts if carrying contains a different type. Updates `resource_counts.carrying` and recalculates `unit.move_speed`. Used by haulers after withdrawing from a container.
- `resources.carryResource(unit, type, amount)` — create resources directly into `unit.carrying`. If already carrying a stack of the same type, increments its amount. If carrying is empty, creates a new stack and appends. Asserts if carrying contains a different type. Asserts if total weight would exceed carry cap. Updates `resource_counts.carrying` and recalculates `unit.move_speed`. Used by workers who produce resources (harvest, extraction, crafting).
- `resources.withdrawFromCarrying(unit, type, amount)` — remove `amount` of `type` from `unit.carrying`. Returns entity ids. Updates `resource_counts.carrying` and recalculates `unit.move_speed`.

**Equip operations:**

- `resources.equip(unit, slot, item_id)` — set `unit.equipped[slot]` to `item_id`. Decrements source category count, increments `resource_counts.equipped`.
- `resources.unequip(unit, slot)` — clear `unit.equipped[slot]`, return item_id. Decrements `resource_counts.equipped`. Caller decides where the item goes next (carrying, destroy, etc.).

**Reservation operations:**

- `resources.reserve(container, type, amount, direction)` — increment `reserved_in` or `reserved_out` on the container. `direction` is `"in"` or `"out"`. When the container belongs to a storage building and direction is `"out"`, also increments `resource_counts.storage_reserved[type]`. Asserts: cannot reserve more than available stock (for `"out"`) or available capacity (for `"in"`).
- `resources.releaseReservation(container, type, amount, direction)` — decrement `reserved_in` or `reserved_out`. Updates `resource_counts.storage_reserved` when applicable. Asserts: cannot release more than currently reserved.

For tile inventory, reserve/release operate on a specific tile entry (the module selects one internally). The caller passes the container (`building.storage` for stockpiles); the module finds a tile with available stock or capacity.

**Lifecycle operations:**

- `resources.create(type, amount)` — creates stack or item entities in `world.stacks`/`world.items` via `registry.createEntity`. For stacks, creates one stack with the given amount. For items, `amount` is how many to create (returns an array of ids). Does not place them in a container — caller uses `deposit` or `carryEntity` next. Not used for production output — workers use `carryResource` which handles creation internally.
- `resources.destroy(entity_id)` — removes from `world.stacks`/`world.items` and registry. Caller must have already removed the entity from its container. Updates resource counts for the appropriate category.

**Count operations:**

- `resources.rebuildCounts()` — full iteration of all containers, rebuilds `world.resource_counts` from scratch. Called once on game load and save load.
- `resources.validateCounts()` — debug-only full recount that asserts against the running tallies. Called once per tick at end of `simulation.onTick` when debug validation is enabled. Guarded behind `DEBUG_VALIDATE_RESOURCE_COUNTS` in constants.

The key invariant: all capacity and stock checks respect reservations. No module other than resources writes to container contents, reservation fields, or resource count tallies.

RESOURCE COUNTS

`world.resource_counts` provides O(1) lookup of settlement-wide resource totals by location category. Maintained as a running tally by the resources module — every create, destroy, transfer, equip, and durability-break updates the relevant category. No system needs to iterate buildings or units to answer "how much X exists."

| Category | What it tracks |
|---|---|
| `storage` | Stockpiles, warehouses, barns |
| `processing` | Processing building input bins |
| `housing` | Housing bins (food only) |
| `carrying` | `unit.carrying` |
| `equipped` | `unit.equipped` |
| `ground` | Ground piles |

Each sub-table is `{ [type] = amount }`. Systems query the category they care about. The UI can sum whichever categories are relevant to the player.

`resource_counts.storage_reserved` tracks the sum of `reserved_out` across all storage buildings, keyed by resource type. Updated alongside container-level reservation changes. This enables O(1) settlement-wide available stock: `storage[type] - storage_reserved[type]`. Used by the merchant to skip food types with no available stock and by any system that needs to short-circuit before scanning buildings.

`reserved_in` is not tracked globally — available capacity is per-building and depends on filters, bin sizes, and tile layouts, making a global sum meaningless.

Running tallies are maintained as a side effect of every resources module mutation operation.

## Frost and Farming

FROST/THAW SYSTEM

At the start of each year, the game rolls two values: `thaw_day` (a spring day number) and `frost_day` (an autumn day number). The growing window is the period between thaw and frost. Outside this window, `world.time.is_frost` is true and farming is restricted.

**Thaw:** When the calendar reaches spring day `thaw_day`, `is_frost` is set to false. Notification: "The ground has thawed." Planting becomes possible (farms with `allow_planting` enabled begin posting activities).

**Frost warning:** 1–2 days before `frost_day` (configurable via `FROST_WARNING_DAYS`), notification: "Frost is approaching." This is the player's signal to trigger "Harvest Now" on any farms with immature crops.

**Frost arrival:** When the calendar reaches autumn day `frost_day`, `is_frost` is set to true. Notification: "Frost has arrived." Crops stop growing (maturity no longer advances). Unharvested crops begin decaying — maturity decreases at `FROST_DECAY_RATE` per tick. The player has a grace window to harvest at reduced yield. Crops that decay to 0 maturity are destroyed (tile's `planted_tick` set to nil).

**Year start roll:** `thaw_day` and `frost_day` are rolled using the seeded RNG at the start of each year (same deterministic sequence as map generation). Exact day ranges are TBD during tuning — the ranges should create years where wheat is sometimes risky but barley and flax are almost always safe.

PER-TILE CROP STATE

Farm tiles track crop state with a single value: `planted_tick`. This is stored in a sparse table on the farm building, keyed by tile index.

- `planted_tick = nil` → tile is empty, eligible for planting (if `allow_planting` is on and `is_frost` is false)
- `planted_tick = tick` → tile is planted, maturity derived as `clamp((current_tick - planted_tick) / CropConfig[crop].growth_ticks, 0, 1)`

No per-tile state machine — just a timestamp and a formula.

FARM CONTROLS

Four controls on each farm:

- **Crop selector:** wheat / barley / flax / nil (fallow). Changing crop destroys any currently planted tiles. Setting to nil disables all farming work.
- **`allow_planting` toggle:** When on and `is_frost` is false, empty tiles are eligible for planting work. When off, no planting activities post regardless of season.
- **`auto_harvest`:** Three states:
  - `"off"` — No auto-harvest. Player uses "Harvest Now" for all harvesting.
  - `"per_tile"` — Each tile becomes eligible for harvest work individually when it reaches 1.0 maturity.
  - `"per_farm"` — The farm waits for all planted tiles to reach 1.0 maturity, then all become eligible simultaneously. Punishes staggered planting — the earliest tiles sit at 100% waiting for the last.
- **"Harvest Now" button:** One-shot action. Makes all planted tiles immediately eligible for harvest at their current maturity. This is the only way to harvest immature crops. Does not change the `auto_harvest` setting.

FARM ACTIVITY POSTING

The farm posts activities when there are eligible tiles (for planting or harvesting) and `#posted_activity_ids < worker_limit`. One activity per open worker slot, not per tile. A farmer claims the activity, paths to the farm, and their handler picks the next eligible tile. When no more eligible tiles exist, the farmer returns to the activity queue.

During the growing season when no tiles are eligible for planting or harvesting, the farm posts no activities. Farmers return to the activity queue and pick up other serf work — summer is free labor.

HARVEST YIELD

`floor(CropConfig[crop].yield_per_tile * maturity)` per tile. At 1.0 maturity, full yield. At 0.8, 80% yield.

## Ground Piles

Ground piles are entities that hold resources on map tiles. Created when units drop resources (hard interrupts, death, offloading when no storage has capacity, farmer harvest overflow). Each ground pile sits on one tile. The drop function prefers to spread resource types across separate tiles.

A ground pile holds a flat array of entity ids (stacks and items mixed). No capacity enforcement, no filters. The tile references the ground pile entity via `tile.ground_pile_id`.

```lua
ground_pile = {
    container_type = "ground_pile",
    id = 0,
    x = 0, y = 0,
    contents = {},       -- flat array of entity ids (stacks and items mixed)
    reserved_out = 0,    -- reserved by haulers claiming pickup activities
}
```

Ground piles self-post one haul activity per resource type they contain. When a hauler picks up all entities of a given type, the corresponding activity is removed. When the pile is fully emptied, it is destroyed (removed from `world.ground_piles` and registry, `tile.ground_pile_id` cleared). If no valid storage has capacity, the activities still post but won't be claimed until space opens up — the pile persists on the ground indefinitely. Ground pile haul activities use `destination_id = nil` — the hauler resolves the nearest valid storage with capacity at claim time. If no storage has capacity, the activity is skipped.

Not a player-configurable entity. No filters, no settings.

GROUND DROP SEARCH

When a unit drops resources, each resource type is dropped one at a time. For each type, the drop function searches outward from the unit's position:

1. Same-type ground pile with remaining weight capacity below `GROUND_PILE_PREFERRED_CAPACITY` (stackable) or empty tile → merge or place
2. Empty pathable tile within `GROUND_DROP_SEARCH_RADIUS` (flood fill along pathable tiles) → create new pile
3. Fallback: drop on the unit's current tile regardless (mixed-type overlap)

Items follow a simpler search: empty tile → fallback to current tile. One item per ground tile.

`GROUND_DROP_SEARCH_RADIUS` is 2. The search uses flood fill along pathable tiles (not ring search), so drops never land across water or behind walls. At radius 2 this is at most ~24 tiles — trivial cost. The search should NOT prefer any strategically useful direction (e.g., toward stockpiles).

The drop function prefers to keep ground piles below `GROUND_PILE_PREFERRED_CAPACITY` (64) by creating new piles on adjacent tiles. This is a soft cap — if no adjacent tiles are available, stacking beyond the limit is allowed.

## Storage Filter System

Storage buildings (stockpiles, warehouses, barns) use a per-type filter system that controls both what the building accepts and whether it actively pulls resources from other storage.

FILTER TABLE

Every storage building has a `filters` table on its container, populated at building creation from ResourceConfig. Stockpiles get all resource types. Warehouses get stackable types only (constrained by `is_stackable_only`). Barns get item types only (constrained by `is_items_only`). Every entry defaults to `{ mode = "accept", limit = nil }`.

```lua
filters = {
    wood  = { mode = "accept", limit = nil },
    iron  = { mode = "pull",   limit = 100, source_id = 5 },
    stone = { mode = "reject" },
}
```

Three modes per type:

- **reject** — building will not accept this type. Existing stock of a rejected type is not automatically removed — it remains until withdrawn by a pull from another building.
- **accept** — building passively accepts deliveries (default routing, ground pile cleanup, self-deposit). Optional `limit` caps how much the building will hold of this type.
- **pull** — building actively pulls this type from another storage building. Required `limit` sets the target amount. Optional `source_id` names a specific source building; nil means "from anywhere."

`resources.accepts()` returns true for "accept" and "pull" modes, false for "reject." `resources.getAvailableCapacity()` respects the filter limit — if set, capacity is `min(physical_capacity, limit - current_stock_of_type) - reserved_in`.

PULL MECHANICS

The filter system scans storage buildings via hash-offset (once per `HASH_INTERVAL`). For each building, it checks filter entries in "pull" mode and posts haul activities based on deficit:

```lua
needed = limit - current_stock - reserved_in
available = source_available_stock
transfer = min(needed, available)

units_per_trip = floor(CARRY_WEIGHT_MAX / ResourceConfig[resource].weight)
trips_needed = ceil(transfer / units_per_trip)
activities_to_post = max(0, trips_needed - activities_in_transit_for_this_filter)
```

SOURCE RESOLUTION

**"Pull from specific building"** (`source_id` set): pull directly from the named building regardless of its filter mode, subject to cycle detection. Stock checks respect reservations.

**"Pull from anywhere"** (`source_id` is nil): find the nearest storage building with available stock of the type whose filter for that type is NOT in "pull" mode. Buildings with the type set to "accept" or "reject" are both valid sources — "reject" means the building won't accept new deliveries of that type, not that its existing stock is unavailable. Buildings with the type in "pull" mode are excluded to prevent tug-of-war between two buildings that are both actively acquiring the same resource.

CYCLE DETECTION

When the player sets a filter entry on building A to "pull type R from building B," reject if building B's filter for type R is already "pull from building A." 3+ building cycles are on the player.

EDGE CASES

- Source empty at pickup: activity fails, removed, reservations released, re-evaluated next scan.
- Destination full at delivery: hauler follows through to next valid storage, or drops via ground drop search. One followthrough attempt.
- Competing demand (two buildings pulling same type from same source): reservations prevent over-commitment.
- Resource with no valid destination: drop via ground drop search. Always.
- Source building deleted: any filter entry on other buildings with `source_id` pointing to the deleted building reverts to `{ mode = "accept", limit = <preserved> }`. Keeps the limit, drops the directive.

RESOURCE MOVEMENT OVERVIEW

Two systems handle resource movement. They don't overlap.

**Ground pile cleanup** posts haul activities directly when piles are created. **Construction delivery** posts haul activities on building placement. Both are independent of the filter system.

**Storage filters** control all inter-storage resource flow. Default routing (self-deposit, ground pile cleanup) delivers to the nearest storage building that accepts the type and has capacity. "Pull" filter entries post pull activities to actively move resources between specific buildings. The filter table on each storage building is the complete logistics configuration.

**Activity selection:** All haul activities are scored the same way as any other activity — see BEHAVIOR.md Activity Scoring.

## Merchant Delivery System

The merchant is a stationed specialty worker at the market. They claim the market's activity once and run an internal delivery loop for food only. Equipment (tools, clothing) is handled by units themselves — see BEHAVIOR.md Equipment Wants. Each delivery run uses the private haul activity pattern for reservation tracking: the merchant self-posts a haul activity (source = storage building, destination = housing bin), claims it immediately, reserves stock at source and capacity at destination. This is the only system that writes to housing building bins. Without a market, units self-fetch food — see BEHAVIOR.md Home Food Self-Fetch.

MERCHANT LOOP

1. Idle at market (duration = `MerchantConfig.idle_ticks_base` scaled inversely by trading skill — formula pending)
2. Check if any home has total food < `critical_threshold` per member → if yes, start a critical food run. Total food is the sum of amounts across all food-type housing bins.
3. If no critical homes → select the food type with the highest `current_tick - last_delivered_tick`, filtered to types where `resource_counts.storage[type] - resource_counts.storage_reserved[type] > 0`. Reset `last_delivered_tick` for the winning type after the run completes. If no food type has available stock, idle and retry next loop.
4. Self-post private haul activity (source = nearest storage building with available stock, destination = first eligible home's bin). Reserve stock and capacity. Travel to storage, load up to MerchantConfig.carry_capacity of the selected food type.
5. Find eligible home with lowest total food per member (ties broken by nearest), travel there, deposit into the matching food bin. Drop `drop_amount`. Release reservation for this home, post new private activity for next home if continuing.
6. If still carrying and more eligible homes exist → repeat step 5
7. When carry empty or no more eligible homes → return to market, restart at 1

CRITICAL FOOD RUNS

Triggered when any home's total food (across all food-type housing bins) falls below `critical_threshold` (2) per household member. The merchant selects whichever food type has the most stockpile availability and delivers to all homes below `serious_threshold` (4) per member, ordered by lowest total food per member first. The serious threshold prevents thrashing — the merchant catches near-critical homes while already out delivering, avoiding frequent short runs.

STANDARD FOOD RUNS

When no homes are critical, the merchant selects the food type that has gone longest without delivery, filtered to types with available stock in storage.

A home is eligible for a standard food delivery when its stock of the selected food type (checked on the matching housing bin) is below the per-type `bin_threshold` value from MerchantConfig (multiplied by household size).

ROUTE ORDER

Within a single delivery run, the merchant resolves the next destination after each drop — no pre-planned route. Next destination = eligible home with lowest total food per member, ties broken by nearest distance. This ensures homes that have gone longest without delivery are served first, preventing systematic neglect of distant homes. Both critical and standard runs use this same ordering.

DROP AMOUNT

The merchant drops `drop_amount` (2) at each home per visit. This distributes supply broadly rather than filling one home completely before visiting others.

ROUTE ELIGIBILITY

Homes visited on a critical run must be below the serious threshold (total food per member). Homes visited on a standard run must be below the `bin_threshold` for the selected food type. The criteria that triggered the run determine which homes are eligible stops — a critical food run does not also deliver to homes that merely want variety.

## Firewood and Home Heating

FIREWOOD PRODUCTION

Wood is processed into firewood at a chopping block (or similar simple building — exact building name TBD). Firewood is a stackable resource consumed by two systems: home heating in winter and steel production at the bloomery. The bloomery recipe requires firewood as an input alongside iron. See TABLES.md RecipeConfig for the steel recipe. See DESIGN.md Firewood and Home Heating for design rationale.

HOME HEATING

*Pending detailed design.* High-level concept:

Homes consume firewood during winter to keep residents warm. Firewood must be delivered to homes (delivery mechanism TBD — possibly an extension of the merchant system, or a dedicated firewood delivery activity). Homes that run out of firewood impose a mood or health penalty on residents.

Key design questions to resolve:
- Delivery mechanism — merchant, storage filter pulls, or a new system
- Consumption rate — per-home or per-resident, constant or temperature-dependent
- Failure consequence — mood penalty, health damage, or both
- Storage — does housing need a firewood bin (similar to food bins), or is firewood tracked differently
