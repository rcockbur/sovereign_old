# Sovereign — ECONOMY.md
*v22 · Resource infrastructure: entities, containers, reservations, storage filters, merchant delivery, firewood.*

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
    count_category = "housing",  -- "housing" | "processing" | "construction" — which resource_counts bucket this bin's contents feed
    type = "flour",      -- resource type this bin holds
    capacity = 128,      -- max weight (stackable) or max item count (items); nil = uncapped (housing bins)
    contents = {},       -- flat array of entity ids
    reserved_in = 0,     -- amount spoken for by inbound deliveries
    reserved_out = 0,    -- amount spoken for by outbound pickups
}
```

Housing food bins use `capacity = nil` — uncapped. Merchant delivery stops when a home crosses `bin_threshold × size` (see Merchant Delivery System), and residents only fetch when the home holds no food of any type (see HAULING.md Eating Trip). Neither can drive unbounded accumulation, so physical capacity enforcement is unnecessary. Processing input bins and construction bins stay capped — their sizes are recipe- and build-cost-bound and enforcement prevents overfill.

**Tile inventory** — array of building-owned tiles, each holding stacks (weight-capped) or one item. Used by: stockpiles.

```lua
tile_inventory = {
    container_type = "tile_inventory",
    count_category = "storage",
    tile_capacity = STOCKPILE_TILE_CAPACITY,  -- per-tile weight capacity for stacks
    tiles = {},          -- array of tile_entry, one per stockpile tile
    filters = {},        -- per-type filter entries — see Storage Filter System
    reserved_in = {},    -- type-keyed: amount spoken for by inbound deliveries
    reserved_out = {},   -- type-keyed: amount spoken for by outbound pickups
}

tile_entry = {
    contents = {},       -- flat array of entity ids
}
```

Items occupy one tile each regardless of weight. The tile_inventory's `filters` apply across all its tiles — filters are container-level, not per-tile. Reservations are container-level (type-keyed) — the resources module selects a specific tile internally on deposit and withdraw.

**Stack inventory** — flat array of stack entity ids with total weight capacity. Used by: warehouses. Only accepts stackable resources.

```lua
stack_inventory = {
    container_type = "stack_inventory",
    count_category = "storage",
    capacity = 0,        -- total weight capacity
    contents = {},       -- flat array of stack entity ids
    filters = {},        -- per-type filter entries (stackable resources only) — see Storage Filter System
    reserved_in = {},    -- type-keyed: amount spoken for by inbound deliveries
    reserved_out = {},   -- type-keyed: amount spoken for by outbound pickups
}
```

**Item inventory** — flat array of item entity ids with count cap. Used by: barns. Only accepts non-stackable items. No tile representation — UI panel based.

```lua
item_inventory = {
    container_type = "item_inventory",
    count_category = "storage",
    item_capacity = 40,  -- max number of items
    contents = {},       -- flat array of item entity ids
    filters = {},        -- per-type filter entries (items only) — see Storage Filter System
    reserved_in = {},    -- type-keyed: item count spoken for by inbound deliveries
    reserved_out = {},   -- type-keyed: item count spoken for by outbound pickups
}
```

**Ground pile** — entity on a map tile holding dropped resources. Flat array of entity ids (stacks and items mixed). No capacity enforcement, no filters. Transient — created by `dropToGround` / `dropUnitContents`, destroyed when emptied. See Ground Piles section for full details.

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

All containers track reservations to prevent collisions from concurrent resource movement. Bins and storage containers track both `reserved_in` (amount spoken for by inbound deliveries) and `reserved_out` (amount spoken for by outbound pickups). Ground piles track `reserved_out` only — the inbound reservation verbs (`reserveInbound`, `releaseInbound`) and the transfer verbs that would deposit into a container (`transfer`, `moveFromCarrying`) all assert against ground-pile destinations. The only deposit paths into a ground pile are `dropToGround` and `dropUnitContents`, which run GROUND DROP SEARCH and don't engage the inbound reservation system.

On single-type containers (bins), `reserved_in` and `reserved_out` are scalars. On multi-type containers (tile_inventory, stack_inventory, item_inventory), both are type-keyed tables (`{ [type] = amount }`) so a reservation on one type never pessimistically blocks availability of another. Ground piles carry only a type-keyed `reserved_out`.

Both fields store **item amounts** across all container types — not weight units. Weight conversion is internal to capacity calculations only. Callers pass amounts to the reservation and transfer verbs; `getAvailableCapacity` returns an amount, converting from the container's physical weight capacity internally via `floor((capacity - current_weight) / ResourceConfig[type].weight) - reserved_in`. This keeps units uniform across the whole API — no caller ever has to ask whether a given container counts in weight or amount.

- **Available stock** = stock - reserved_out (in item amounts)
- **Available capacity** = capacity - used - reserved_in (converted to amounts internally for weight-capped containers)

Reservations are placed when a haul activity is created with concrete endpoints (atomic with posting for private hauls; at request → activity conversion for variants spawned from requests). See HAULING.md for the full request/activity model, the generic haul cycle, the variant catalog, and the cleanup paths that release reservations.

**Inviolate except for direct player intervention.** Reservations are honored by every system that reads or writes capacity — every haul cycle places and clears them correctly, every capacity check respects them. The player is the one entity outside that contract: direct edits to filter limits and building deletion can invalidate in-flight reservations. The simulation handles the resulting mismatches gracefully via the partial-fill chain (for over-capacity at delivery — see HAULING.md) and building deletion cleanup (for destroyed endpoints — see BEHAVIOR.md Building Deletion). No other source of mid-flight invalidation exists.

RESOURCES MODULE (`simulation/resources.lua`)

The resources module is the sole writer of resource state. Every operation that creates, destroys, moves, or reserves resource entities goes through this module — no other module writes to container contents, reservation fields, or `world.resource_counts`. All functions use dot syntax (no `self`).

The module uses a generic container interface. Callers pass a container reference (e.g., `building.storage`, `building.housing.bins[i]`, `building.production.input_bins[i]`, or a ground_pile entity). The module dispatches internally based on `container.container_type`. Callers never branch on container type. `unit.carrying` uses a separate weight-based API because its single-type constraint and move-speed side effect don't fit the generic interface.

All public mutation verbs are **atomic placement verbs** — every entity the module creates is placed into a known destination in the same call, and every entity removed from a container is destroyed, placed into another container, or equipped in the same call. Entities never exist outside any container. The primitive operations (`create`, `destroy`, `deposit`, `withdraw`, `carryEntity`, `withdrawFromCarrying`, `equip`, `unequip`) are file-local helpers used only by the public atomic verbs.

All public verbs assert on contract violations — insufficient stock, insufficient capacity, type mismatch, occupied or empty equipment slot, filter rejection, ground-pile destinations on non-drop verbs. None silently no-op or partially complete. Specific assertions are noted per verb below.

All mutation operations maintain `world.resource_counts` as a running tally — see Resource Counts.

READER CONVENTION

Trivial field access is done directly by callers: `unit.equipped[slot]`, `stack.amount`, `item.durability`, `container.capacity`, `world.resource_counts[category][type]`, `#unit.carrying`, and similar single-field reads are all fine without a reader. Any read that requires iteration, computation, filtering, or crosses the container-type dispatch boundary goes through one of the Query verbs below. New readers are added here when a read of that shape emerges.

**Query operations:**

- `resources.getStock(container, type)` — total amount of `type` in the container.
- `resources.getAvailableStock(container, type)` — stock minus `reserved_out` for this type.
- `resources.getAvailableCapacity(container, type)` — remaining capacity in item amounts, minus `reserved_in` for this type. Respects per-type filter limits on storage containers: `min(physical_capacity, limit - current_stock_of_type) - reserved_in`. Uncapped containers (ground piles and housing bins with `capacity = nil`) return `math.huge`. For tile_inventory, physical capacity for a given type requires iterating tiles (sum over tiles of `tile_capacity - used` where the tile is empty or already holds that type); cost is bounded by stockpile footprint.
- `resources.accepts(container, type)` — filter check. Bins: `container.type == type`. Tile inventory / stack inventory / item inventory: `filters[type].mode ~= "reject"`. Ground piles: always true.
- `resources.countWeight(entity_ids)` — total weight across a flat array of entity ids. Used for carrying weight checks and any other case where a computed weight sum is needed.

**Transfer operations (atomic placement):**

- `resources.produceInto(container, type, amount)` — create entities and deposit into the container in one operation. Used by debug spawn commands; the only entry point that brings resources into the world without a source. Asserts container accepts type and has capacity for amount.
- `resources.produceIntoCarrying(unit, type, amount)` — create entities directly into `unit.carrying`. Used by workers producing resources (harvest, extraction, processing output). If carrying is empty, creates a new stack and appends. If carrying already holds the same type, merges (stacks) or appends (items). Asserts carrying is empty or holds the same type; asserts carry weight would not exceed `CARRY_WEIGHT_MAX`. Updates `resource_counts.carrying` and recalculates `unit.move_speed`.
- `resources.consumeFrom(container, type, amount)` — withdraw from the container and destroy the entities in one operation. Used by eating (housing bin, or a storage container directly for homeless eating), construction consumption (construction bin), and processing input consumption (input bin). Asserts container holds at least `amount` of type.
- `resources.moveToCarrying(unit, source, type, amount)` — withdraw from source and place into `unit.carrying` in one operation. Used by haulers at pickup. Same carrying constraints and side effects as `produceIntoCarrying`. Asserts source holds at least `amount` of type.
- `resources.moveFromCarrying(unit, destination, type, amount)` — withdraw from `unit.carrying` and deposit into destination in one operation. Used by haulers at delivery and by workers self-depositing. Asserts carrying holds at least `amount` of type; asserts destination accepts type and has capacity for amount; asserts `destination.container_type ~= "ground_pile"` (ground piles are reachable only via `dropToGround` / `dropUnitContents`). Updates `resource_counts.carrying` and recalculates `unit.move_speed`.
- `resources.transfer(source, destination, type, amount)` — withdraw from source and deposit into destination in one operation. Used for container-to-container moves with no unit involved. Asserts source holds at least `amount` of type; asserts destination accepts type and has capacity for amount; asserts `destination.container_type ~= "ground_pile"`.
- `resources.equipFromContainer(unit, slot, source, type)` — withdraw one item of `type` from source and place into `unit.equipped[slot]` in one operation. Used by the equipment fetch flow. Asserts source holds at least one item of type; asserts `unit.equipped[slot]` is nil.
- `resources.dropToGround(source, type, amount, origin_tile)` — withdraw `amount` of `type` from `source` and place it into ground piles at or near `origin_tile` per GROUND DROP SEARCH. `source` is a container or a unit (when a unit, drains `unit.carrying` and recalculates `move_speed`). Internally: picks or creates the target pile per the search algorithm, merges into same-type piles under the soft cap where possible, creates new ground_pile entities as needed, updates `resource_counts.ground`. Used by harvest overflow, offloading when no storage has capacity, building deletion step 6 (per container, per type), and `dropUnitContents` (per carry type). Asserts source holds at least `amount` of type.
- `resources.dropUnitContents(unit)` — atomically drops everything a unit is holding to the ground at `unit.tile`. Iterates each type in `unit.carrying` and runs the per-type ground-drop logic; iterates each occupied slot in `unit.equipped`, calls the file-local `unequip` to remove the item from the slot, then places the item via the item variant of GROUND DROP SEARCH (one item per tile, fallback to origin tile). The only path that moves resources out of `unit.equipped`, symmetric with `equipFromContainer` being the only path in. Used by unit death (`units.sweepDead`) and hard interrupts.

Reservation management is separate from the transfer verbs. The caller reserves before the operation and releases after — the verbs themselves don't touch reservations, which keeps them composable with abandonment, partial-fill, and other non-happy paths. `dropToGround` and `dropUnitContents` are the exception: they're the designated exit path for resources that have already lost their reservation context (hard interrupts, death, capacity-denied offloading), and they don't engage reservations at all.

**Reservation operations:**

- `resources.reserveInbound(container, type, amount)` — increment the type-keyed (or scalar, on bins) `reserved_in` for the container by `amount`. Asserts available capacity for type is at least `amount`. Asserts `container.container_type ~= "ground_pile"`.
- `resources.reserveOutbound(container, type, amount)` — increment `reserved_out` by `amount`. When the container belongs to a storage building, also increments `resource_counts.storage_reserved[type]`. Asserts available stock for type is at least `amount`.
- `resources.releaseInbound(container, type, amount)` — decrement `reserved_in` by `amount`. Asserts the reservation exists. Asserts `container.container_type ~= "ground_pile"`.
- `resources.releaseOutbound(container, type, amount)` — decrement `reserved_out` by `amount`. Updates `resource_counts.storage_reserved` for storage containers. Asserts the reservation exists.

For tile inventory, reservations apply to the container-level type-keyed tables, not to individual tile entries. Tile selection for deposit and withdraw happens internally in the module at operation time.

**Filter operations:**

- `resources.setFilterMode(container, type, mode)` — set `filters[type].mode` to `"accept"`, `"reject"`, or `"pull"`. Asserts mode is valid. Setting to `"pull"` asserts a limit is already set on the entry.
- `resources.setFilterLimit(container, type, limit)` — set `filters[type].limit` to a positive integer or nil.
- `resources.setFilterSource(container, type, source_id)` — set `filters[type].source_id` to a building id or nil. Asserts `filters[type].mode == "pull"`. Runs cycle detection (see Storage Filter System); asserts on cycle.

Filter mutations are the only player-initiated writes to container state. They may invalidate in-flight reservations — the partial-fill chain (HAULING.md) handles the downstream mismatch. See Storage Filter System for mode semantics, source resolution, and edge cases.

**Count operations:**

- `resources.rebuildCounts()` — full iteration of all containers, rebuilds `world.resource_counts` from scratch. Called once on new game and once on loading a save.
- `resources.validateCounts()` — debug-only full recount that asserts against the running tallies. Called once per tick at end of `simulation.onTick` when `DEBUG_VALIDATE_RESOURCE_COUNTS` is true.

The key invariant: all capacity and stock checks respect reservations. No module other than resources writes to container contents, reservation fields, or resource count tallies.

RESOURCE COUNTS

`world.resource_counts` provides O(1) lookup of settlement-wide resource totals by location category. Maintained as a running tally by the resources module — every mutation (creation, destruction, transfer between containers, carrying, equipping, unequipping) updates the relevant category. No system needs to iterate buildings or units to answer "how much X exists."

| Category | What it tracks |
|---|---|
| `storage` | Stockpiles, warehouses, barns |
| `storage_reserved` | Outbound reservations on storage buildings (`reserved_out`), keyed by type. Mirrors `storage` for tracking in-flight outbound commitments. |
| `processing` | Processing building input bins |
| `housing` | Housing bins (food only) |
| `construction` | Construction bins on buildings under construction |
| `ground` | Ground piles |
| `carrying` | `unit.carrying` |
| `equipped` | `unit.equipped` |

Only storage outbound reservations get a parallel count bucket — other reservation reads happen against a specific known container, so the resources module maintains them on the container itself without a settlement-wide tally.

Each sub-table is `{ [type] = amount }`. Systems query the category they care about. The UI can sum whichever categories are relevant to the player.

**Container dispatch enum.** Containers routed through the generic container API carry a `count_category` field whose valid values are `"storage"`, `"housing"`, `"processing"`, `"construction"`, and `"ground"` — the set of buckets reachable through the container API. The remaining two buckets (`carrying` and `equipped`) are updated through dedicated unit-level verbs (`produceIntoCarrying`, `moveToCarrying`, `moveFromCarrying`, `equipFromContainer`, `dropUnitContents`) and don't need a dispatch field — those call sites statically know the destination bucket.

**Distinction from `building.category`.** The `count_category` on a container is not the same field as `building.category`. `building.category` answers "what kind of building is this" and drives iteration filtering and UI dispatch. `count_category` on a container answers "which `resource_counts` bucket do my contents feed." They usually match (a cottage's housing bins have `count_category = "housing"` and the cottage has `building.category = "housing"`), but they diverge for construction — a half-built cottage has `building.category = "housing"` but its `construction.bins` have `count_category = "construction"` because the materials inside are committed to the build, not to housing.

`resource_counts.storage_reserved` is updated alongside container-level reservation changes — every `reserveOutbound` or `releaseOutbound` call on a storage container updates the matching bucket. This enables O(1) settlement-wide available stock: `storage[type] - storage_reserved[type]`. Used by the merchant to skip food types with no available stock and by any system that needs to short-circuit before scanning buildings.

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

The farm posts two activity types — `farmer_planting` and `farmer_harvesting` — depending on what work is currently eligible. Both compete for the farm's `worker_limit` slot budget, with harvesting taking priority: when harvesting is eligible, post `farmer_harvesting` activities up to `worker_limit`, then fill remaining slots with `farmer_planting` activities if planting is also eligible. This produces the frost-panic emergent behavior automatically — when frost approaches and "Harvest Now" is triggered, harvesting eligibility floods in and harvesting activities take all worker slots until the harvest is cleared.

Eligibility predicates for both types are owned by HAULING.md Eligibility Validation. One activity per open worker slot, not per tile. A farmer claims the activity, paths to the farm, and their handler picks the next eligible tile of the matching kind (planting or harvesting). When no more eligible tiles of that kind exist, the farmer returns to the activity queue.

During the growing season when no tiles are eligible for planting or harvesting, the farm posts no activities. Farmers return to the activity queue and pick up other serf work — summer is free labor.

HARVEST YIELD

`floor(CropConfig[crop].yield_per_tile * maturity)` per tile. At 1.0 maturity, full yield. At 0.8, 80% yield.

## Ground Piles

Ground piles are entities that hold resources on map tiles. Created by `dropToGround` and `dropUnitContents` when units drop resources (hard interrupts, death, offloading when no storage has capacity, farmer harvest overflow, building deletion step 6). Each ground pile sits on one tile. The drop logic prefers to spread resource types across separate tiles. See TABLES.md ground_pile for the entity data structure.

Ground piles self-post one cleanup request per resource type they contain. The request's `requested_amount` matches the pile's current contents of that type and is updated whenever a hauler withdraws (the haul activity converted from the request decrements the request on creation; if the withdraw amount differs, the request is reconciled to the pile's actual contents after the withdraw). When a request hits zero (all of that type withdrawn), the request is removed. When the pile is fully emptied, it is destroyed (removed from `world.ground_piles` and registry, `tile.ground_pile_id` cleared). If no valid storage has capacity, the request stays posted but no conversion succeeds — the pile persists on the ground until space opens up. See HAULING.md Ground pile cleanup for the request mechanics and HAULING.md Request → Activity Conversion for how haulers turn requests into trips.

Not a player-configurable entity. No filters, no settings.

GROUND DROP SEARCH

The search algorithm used by `dropToGround` and `dropUnitContents`. When resources are dropped, each resource type is dropped one at a time. For each type, the drop function searches outward from the origin tile:

1. Same-type ground pile with remaining weight capacity below `GROUND_PILE_PREFERRED_CAPACITY` (stackable) or empty tile → merge or place
2. Empty pathable tile within `GROUND_DROP_SEARCH_RADIUS` (flood fill along pathable tiles) → create new pile
3. Fallback: drop on the origin tile regardless (mixed-type overlap)

Items follow a simpler search: empty tile → fallback to origin tile. One item per ground tile.

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
- **accept** — building passively accepts deliveries (default routing for offloading, deposit steps of work cycles, and ground pile cleanup conversion). Optional `limit` caps how much the building will hold of this type.
- **pull** — building actively pulls this type from another storage building. Required `limit` sets the target amount. Optional `source_id` names a specific source building; nil means "from anywhere."

`resources.accepts()` returns true for "accept" and "pull" modes, false for "reject." `resources.getAvailableCapacity()` respects the filter limit — if set, capacity is `min(physical_capacity, limit - current_stock_of_type) - reserved_in`.

PULL MECHANICS

The filter system scans storage buildings via hash-offset (once per `HASH_INTERVAL`). For each building, it checks filter entries in "pull" mode and maintains at most one cleanup request per filter entry, sized to the current deficit:

```lua
needed = limit - current_stock - reserved_in
```

Where `current_stock` is the building's stock of the type and `reserved_in` is its in-flight inbound reservation amount.

If `needed > 0` and no request exists for this filter entry, post one to `world.requests` with `requested_amount = needed`, `destination_id = this building`, `source_id = filter.source_id` (or nil for "from anywhere"). Append the new request's id to the puller's `posted_request_ids`. If a request already exists, update its `requested_amount` to match the current `needed` (the deficit may have shrunk via deliveries or grown if other sources of stock changed). If `needed <= 0`, remove the request from `world.requests`, registry, and the puller's `posted_request_ids` (swap-and-pop).

Haulers pick up requests from `world.requests` and convert them into trip-sized activities at claim time:

```lua
units_per_trip = floor(CARRY_WEIGHT_MAX / ResourceConfig[resource].weight)
trip_amount = min(request.requested_amount, units_per_trip, source_available_stock)
```

The conversion places source-side and destination-side reservations atomically and decrements the request's `requested_amount`. If `requested_amount` hits zero during conversion, the request is also removed from the puller's `posted_request_ids`. See HAULING.md Request → Activity Conversion for the full atomic operation.

The `reserved_in` term in `needed` accounts for already-claimed trips (each conversion places `reserved_in`, which the next filter scan reads). The remaining `requested_amount` on the request itself accounts for trips not yet claimed. Together they describe the full in-flight commitment to filling this filter entry.

SOURCE RESOLUTION

**"Pull from specific building"** (`source_id` set): pull directly from the named building regardless of its filter mode, subject to cycle detection. Stock checks respect reservations.

**"Pull from anywhere"** (`source_id` is nil): find the nearest storage building with available stock of the type whose filter for that type is NOT in "pull" mode. Buildings with the type set to "accept" or "reject" are both valid sources — "reject" means the building won't accept new deliveries of that type, not that its existing stock is unavailable. Buildings with the type in "pull" mode are excluded to prevent tug-of-war between two buildings that are both actively acquiring the same resource.

CYCLE DETECTION

When the player sets a filter entry on building A to "pull type R from building B," reject if building B's filter for type R is already "pull from building A." 3+ building cycles are on the player.

EDGE CASES

- Source empty at conversion: the request stays posted but no conversion succeeds until stock returns. Eligibility validation (HAULING.md) catches this each tick.
- Destination capacity reduced after conversion (player lowered the filter limit mid-transit): the deposit honors current available capacity at delivery time. Overflow re-routes via the partial-fill chain (see HAULING.md). The general rule is "reservations are inviolate except for direct player intervention" — see Reservation System above.
- Competing demand (two buildings pulling same type from same source): reservations on the source prevent over-commitment. Requests don't reserve at the source themselves; the conversion does, atomically.
- Resource with no valid destination at delivery: `dropToGround` at the unit's current position.
- Source building deleted: any filter entry on other buildings with `source_id` pointing to the deleted building reverts to `{ mode = "accept", limit = <preserved> }`. Keeps the limit, drops the directive. Active requests with that source_id are removed by Building Deletion (BEHAVIOR.md).
- Destination building deleted: the puller's filter pull request is removed by Building Deletion. In-flight haul activities are handled by the deletion matrix.

RESOURCE MOVEMENT OVERVIEW

Three public haul variants — ground pile cleanup, construction delivery, and filter pull — are posted as **requests** in `world.requests` (aggregate haul needs) and converted into concrete trip-sized activities by haulers at claim time. Private hauls (processing source-fetch, self-deposit, merchant delivery, home food self-fetch as an eat path, equipment fetch, eating trip, offloading) are posted directly as activities in `world.activities`. See HAULING.md for the full request/activity model and variant catalog.

**Storage filters** control inter-storage resource flow. Default routing (offloading, ground pile cleanup conversion) delivers to the nearest storage building that accepts the type and has capacity. "Pull" filter entries post requests to actively move resources between specific buildings. The filter table on each storage building is the complete logistics configuration.

**Activity and request scoring** uses the same formula — see BEHAVIOR.md Activity Scoring (and HAULING.md Worker Polling for the request-side specifics).

## Merchant Delivery System

The merchant is a stationed specialty worker at the market. They claim the market's activity once and run an internal delivery loop for food only. Equipment (tools, clothing) is handled by units themselves — see BEHAVIOR.md Equipment Wants. Each delivery run uses the private haul activity pattern for reservation tracking: the merchant self-posts a haul activity (source = storage building, destination = housing bin), claims it immediately, reserves stock at source and capacity at destination. The merchant is the primary writer to housing food bins; the only other path that deposits into a housing bin is the eat activity's `fetching_food_returning` phase, when a unit fetches food back to their own empty home (see HAULING.md Eating trip). Without a market, units self-fetch food via the eat activity — see HAULING.md Eating trip.

MERCHANT LOOP

1. Idle at market (duration = `MerchantConfig.idle_ticks_base` scaled inversely by trading skill — formula pending)
2. Check if any home has total food < `critical_threshold` per member → if yes, start a critical food run. Total food is the sum of amounts across all food-type housing bins.
3. If no critical homes → select the food type with the highest `current_tick - last_delivered_tick`, filtered to types where `resource_counts.storage[type] - resource_counts.storage_reserved[type] > 0`. Reset `last_delivered_tick` for the winning type after the run completes. If no food type has available stock, idle and retry next loop.
4. Self-post private haul activity (source = nearest storage building with available stock, destination = first eligible home's bin). Reserve stock and capacity. Travel to storage, load up to CARRY_WEIGHT_MAX of the selected food type.
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