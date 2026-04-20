# Sovereign — ROADMAP.md
*v2 · Project planning: phase scope, pending design items, implementation milestones.*

## Implementation State

*Updated by Claude Code as systems are implemented.*

Phase 1 is implemented up to and including Milestone 17

## Implementation Notes

**M02**
- Switched log output from `io.open` to `love.filesystem` — `io.popen` on Windows caused a 5-second startup hang. Logs write to `Roaming/LOVE/sovereign/logs/`.
- `t.identity = "sovereign"` added to `conf.lua` to name the save directory correctly.

## Phase 1 Milestones

Granular implementation milestones for Phase 1 (Survival). Claude Code implements these one at a time in order. Each milestone builds on the last — later milestones assume all earlier ones are complete.

T-shirt sizes: XS (<30 min), S (30–90 min), M (90 min–3 hr), L (3+ hr). Sizes are rough guides, not commitments.

After completing a milestone, Claude Code updates the Implementation State section above and adds the milestone number to the completed list.

**M01 — Project scaffold + game states** (S)
Establish the application skeleton. `main.lua` wiring, `conf.lua`, `app/gamestate.lua` (stack-based state machine with `switch`/`push`/`pop` and callback forwarding), three state files (`loading.lua`, `main_menu.lua`, `playing.lua`). Loading state runs config validation stubs and switches to main menu. Main menu draws title text and "New Game" button. Playing state is an empty shell. Quit via escape or `love.event.quit()`.
Docs: CLAUDE.md § Entry Point, Game State Machine, Folder Structure.
Verify: Launch `love src`. See main menu. Click "New Game" → switches to playing state (blank screen). Escape returns to menu.

**M02 — Config + constants + log + registry** (S)
`config/constants.lua` with all P1 constants (map, calendar, tick, speed, schedule, movement, carry, needs — full list from CLAUDE.md Constants section). `config/tables.lua` with P1 config tables (NeedsConfig, SleepConfig, ResourceConfig for wood/berries/fish, PlantConfig, BuildingConfig for P1 buildings, ActivityTypeConfig for P1 activity types, NameConfig, SettlementNameConfig, HousingBinConfig). `config/keybinds.lua` with P1 keybinds. `core/log.lua` with ring buffer, severity levels, categories, file output to `logs/`. `core/registry.lua` with `nextId()`, `createEntity()`, hash table lookup. Config validation in `loading.lua` — assert cross-references between config tables.
Docs: CLAUDE.md § Constants, Config Validation, Log System. TABLES.md § Config Tables (P1 entries only).
Verify: Launch game. Config validation passes (no errors). Log file created in `logs/`. Registry `nextId()` increments correctly. Intentionally break a config reference → see clear assert error on startup.

**M03 — Time system** (S)
`core/time.lua` module. `time.accumulate(dt)` converts real delta time into tick count based on speed. `time.advance()` increments tick counter and derives all calendar fields (game_minute, game_hour, game_day, game_season, game_year). `hashOffset(id)` function (prime multiply scatter). `time.getEnergyThresholds()` returns `{ soft, wake }` for current game_hour using SleepConfig lerp bands. Speed controls: keyboard 1–5 for speed settings, space for pause/unpause. TPS tracking fields for dev overlay.
Docs: CLAUDE.md § Constants (tick/calendar values). TABLES.md § SleepConfig. BEHAVIOR.md § Hash Offset System.
Verify: In playing state, log the current game_hour every in-game hour. Speed changes produce visibly different log rates. Pause stops time. `getEnergyThresholds()` returns night values at midnight, day values at noon, interpolated values during transitions.

**M04 — Map data + generation** (M)
`core/world.lua` with tile grid (400×200 flat array via `tileIndex`/`tileXY`), tile data structure, `world.units`/`world.buildings`/`world.activities`/`world.stacks`/`world.items`/`world.ground_piles` arrays, `world.time`, `world.settings`. Full map generation pipeline (layers 0–6): base grass, water (noise), rock (noise + cluster cull), trees (noise, density by half), berry bushes (scatter), forest depth, starting area override. Deterministic from `world.seed`. Settlement name generation from SettlementNameConfig.
Docs: WORLD.md § Map, Map Generation. CLAUDE.md § Flat Index Convention. TABLES.md § world, tile.
Verify: Log terrain distribution after generation (count of grass/water/rock/tree/berry tiles per half). Run twice with same seed → identical counts. Run with different seed → different counts. Starting area is clear grass.

**M05 — Camera + tile rendering** (M)
`ui/camera.lua` with position, zoom, pan (WASD/arrow keys + mouse drag), zoom (scroll wheel), screen↔world coordinate conversion. `ui/renderer.lua` draws the tile grid as colored rectangles (grass=green, water=blue, rock=gray, trees=dark green circles on grass, berry bushes=small purple dots on grass). Only draw tiles within the camera viewport (frustum cull). Playing state entry calls map generation and starts rendering.
Docs: UI.md § Camera. WORLD.md § Map (dimensions).
Verify: See the full generated map. Pan around. Zoom in/out. Settlement half is mostly open, forest half is dense. Lakes, rock outcrops, and the clear starting area are visible. Performance is smooth at full zoom-out.

**M06 — Unit spawning + rendering** (S)
`simulation/units.lua` with unit data structure (P1 fields only: id, name, surname, gender, class="serf", x, y, needs, carrying, equipped, target_tile, path, move_progress, move_speed, current_action, activity_id, home_id, is_dead, etc.). `units.spawnSerf(x, y)` factory function using `registry.createEntity`. Name generation from NameConfig. Spawn 6 starting serfs at the starting area on new game. Target tile system: initial claim on spawn (`unit.target_tile` ↔ `tile.target_of_unit`). `tile.unit_ids` tracking on spawn. Render units as colored shapes on their tiles.
Docs: TABLES.md § unit data structure. CLAUDE.md § Unit Name Generation. WORLD.md § Target Tile System.
Verify: See 6 colored shapes on the starting area. Each occupies a different tile. Dev log shows 6 units spawned with names and positions.

**M07 — Selection + debug dump** (S)
`ui/hub.lua` for input routing. Click a tile to select it; click a unit to select the unit on that tile; click a building to select the building. Left panel renders a debug dump: `tableToString(entity)` recursively formats the selected entity's table. Dump refreshes live. Click empty tile → dump tile data. Deselect with escape or clicking empty space. Selection highlight on the selected tile/entity.
Docs: UI.md § Selection, Left Panel, P1 Implementation (Debug Dump).
Verify: Click a unit → see full unit table in left panel (name, needs values, position, etc.). Click a tile → see tile data (terrain, plant_type, plant_growth). Values update in real time as the simulation runs.

**M08 — Pathfinding** (M)
A* implementation with binary heap open list. Two modes: destination (goal = specific tile) and adjacent-to-rect (goal = any unclaimed pathable orthogonal neighbor of a rectangle). Octile heuristic. Tile costs from WORLD.md (grass=6, trees=18, water/rock=impassable). Diagonal movement allowed when both orthogonal neighbors passable, cost = √2 × tile cost. Returns path as `{ tiles = { idx1, idx2, ... }, current = 1 }` or nil on failure.
Docs: WORLD.md § Pathfinding (all subsections: tile costs, heuristic, modes, adjacent-to-rect heuristic).
Verify: Write tests in `tests/` — optimal path on open grass, path around water, path through trees (higher cost), no path to isolated tile returns nil, adjacent-to-rect finds nearest neighbor, diagonal blocked when orthogonal neighbor impassable.

**M09 — Unit movement** (M)
`unit:moveStep()` per-tick advancement along path. Tile-per-tick with `move_progress` / `tile_cost`. Target tile lifecycle: claim destination before A*, release old tile, flood fill fallback when destination becomes unavailable during transit. `tile.unit_ids` maintenance on tile transitions. `move_speed` calculation with carry weight penalty (formula from WORLD.md). Temporary click-to-move for testing: right-click a tile → selected unit paths there.
Docs: WORLD.md § Movement Model, Movement Speed, Target Tile System. BEHAVIOR.md § Per-tick loop step 1 (travel action).
Verify: Select a unit, right-click a distant tile → unit walks there following A* path, avoiding water/rock, slowing through trees. Render lerp makes movement smooth. Two units can't stop on the same tile. Unit navigates around obstacles.

**M10 — Time controls + dev overlay** (S)
`ui/dev_overlay.lua` toggled with F3. Stats bar: FPS, game_time (day/season/year), current speed, TPS (achieved/target with percentage), unit/building/activity/ground_pile counts. Tile inspector on hover: coordinates, terrain, plant info, building_id, unit_ids, target_of_unit, ground_pile_id. Log tail: last ~10 messages. HUD time display showing current date/time and speed indicator (visible without F3).
Docs: CLAUDE.md § Developer Overlay, TPS Tracking. UI.md § Time display.
Verify: F3 shows overlay. Hover tiles → see terrain data. Speed changes reflected in TPS. Tile with a unit shows unit_id. Time display shows the in-game date advancing.

**M11 — Simulation loop + idle action** (S)
`core/simulation.lua` with `onTick()` orchestrator calling `time.advance()`, `units.tickAll()`, `units.update()` (per-hash loop stub — just need drain for now). `playing.lua` update calls `time.accumulate(dt)` and fires `onTick` the right number of times. Idle action type — units stand still and do nothing. Units start idle after spawn. The simulation is now running: time advances, units exist, nothing else happens yet.
Docs: BEHAVIOR.md § Tick Order, Per-Unit Update loops (structure only).
Verify: Game time advances. Units stand in place. Dev overlay TPS shows ticks firing. Speed changes affect tick rate. Selecting a unit shows `current_action = { type = "idle" }` in debug dump.

**M12 — Stockpile placement** (M)
Building data structure (P1 fields). Stockpile: no tile map, open area, player-sized (drag to define area). Placement mode: temporary debug key enters placement mode, click-drag to define rectangle, release to place. Placement validation: all tiles must be grass or dirt, no existing buildings, no water/rock. Ghost preview during placement (green=valid, red=invalid tiles). Instant placement in P1 — `phase = "complete"` immediately. `tile.building_id` set on all footprint tiles. Render stockpiles as a distinct ground color. Building selection + debug dump.
Docs: WORLD.md § Construction Phases (P1 behavior), Placement Validation, Buildings Without Tile Maps. TABLES.md § building data structure, BuildingConfig (stockpile). UI.md § Building placement.
Verify: Enter placement mode, drag a 4×3 area on grass → stockpile appears. Can't place on water/rock/trees. Select stockpile → see building table in debug dump. Place a second stockpile → both exist. Tiles under stockpile show `building_id` in tile inspector.

**M13 — Resources + stockpile storage** (M)
`simulation/resources.lua` module. Stack entity (id, type, amount). Tile inventory container on stockpiles (one tile_entry per tile, contents array, `reserved_in`/`reserved_out`). Core API: `resources.deposit()`, `resources.withdraw()`, `resources.getStock()`, `resources.getAvailableStock()`, `resources.getAvailableCapacity()`, `resources.accepts()`, `resources.countWeight()`. `world.resource_counts` with category tallies (storage, carrying, ground). `resources.rebuildCounts()`. `resources.carryResource()` and `resources.carryEntity()` for unit carrying. `resources.withdrawFromCarrying()`.
Docs: ECONOMY.md § Resource System (stacks), Containers (tile inventory), Reservation System, Resources Module API, Resource Counts. TABLES.md § ResourceConfig (wood, berries, fish).
Verify: Write tests — deposit wood stack to stockpile tile, withdraw partial amount (splits stack), capacity enforcement, reservation arithmetic (available = stock - reserved_out), `rebuildCounts` matches running tallies. Manually deposit resources via debug command → see them in stockpile debug dump.

**M14 — Activity system** (M)
`simulation/activities.lua`. Activity data structure (id, type, purpose, worker_id, x/y or workplace_id, posted_tick, etc.). Activity posting (`activities.postActivity()`), removal, claiming. Activity scoring: distance + age weighting. Per-hash loop step 6 (activity polling for idle units): scan `world.activities` for unclaimed activities matching the unit's class, score them, claim the best one. `onActionComplete()` shell — fires when an action finishes, dispatches to activity handler. Work action type: increment progress per tick, complete when progress reaches target.
Docs: BEHAVIOR.md § Per-hash loop step 6, Activity Scoring, Action System (action types table), onActionComplete. TABLES.md § activity data structure, ActivityTypeConfig.
Verify: Manually post an activity via debug command. Observe an idle unit claim it on their next hash tick (log output). Unit paths to activity location. Work action increments progress. Action completes. Unit goes idle again.

**M15 — Chop designation + tree felling** (M)
Designation interaction mode: A enters chop designation mode. Click-drag to designate tiles. Each designated tree tile gets a `tile.designation = "chop"` marker and a posted chop activity. Cancel designation mode (X) removes designations and their activities. Visual indicator on designated tiles. Chop work cycle: unit claims chop activity → paths adjacent-to-rect (1×1) to tree → work action (duration from PlantConfig) → tree removed (`plant_type = nil`, `plant_growth = 0`) → wood granted to `unit.carrying` via `resources.carryResource()` → check for more designated trees within reach → if carrying full or no more trees, self-deposit to nearest stockpile. Designation consumed on completion.
Docs: BEHAVIOR.md § Designation work cycle (chop). WORLD.md § Plant System (harvest). TABLES.md § PlantConfig (tree), ActivityTypeConfig (chop). UI.md § Designation buttons. ECONOMY.md § Resources Module API (carryResource).
Verify: Designate 5 trees. Units claim chop activities, walk to trees, chop them (trees disappear), carry wood, deposit at stockpile. Select stockpile → see wood stacks in storage. Designate more trees than units → units chain through them. Cancel a designation → activity removed, tree unaffected.

**M16 — Hauling + ground piles** (M)
Ground pile entity (id, x, y, contents array, reserved_out). Ground drop search algorithm (same-type merge within radius, fallback to empty tile, last resort = current tile). When a unit drops resources (no storage capacity), a ground pile is created via ground drop search. Ground piles self-post one haul activity per resource type. Haul work cycle: claim haul activity → path to ground pile → pick up → path to nearest stockpile with capacity → deposit. Offloading: if a unit becomes idle while carrying, self-deposit to nearest storage; if no capacity, ground drop. Ground pile rendering (small colored squares on tiles). Ground pile destroyed when emptied.
Docs: ECONOMY.md § Ground Piles, Ground Drop Search. BEHAVIOR.md § Offloading, Hauling. TABLES.md § ground_pile.
Verify: Fill a stockpile completely. Designate a tree chop → unit chops, can't deposit, drops wood as ground pile. Ground pile visible on map. Another idle unit claims the haul activity and delivers to a different stockpile (or the pile persists if no space anywhere). Select ground pile → see contents in debug dump.

**M17 — Gather designation + berry harvesting** (S)
Gather designation mode (S): click-drag to designate berry bush tiles. Same pattern as chop but for berry bushes. Gather work cycle: path adjacent-to-rect → work action (duration from PlantConfig) → bush resets to growth stage 1 (regrowth, not removal) → berries granted to carrying → chain or deposit. Berries are a food type with `nutrition` value in ResourceConfig.
Docs: BEHAVIOR.md § Designation work cycle (gather). WORLD.md § Plant System (harvest — bush regrowth). TABLES.md § PlantConfig (berry_bush), ResourceConfig (berries).
Verify: Designate berry bushes. Units gather berries, bushes visually shrink (stage 1). Berries deposited at stockpile. Bush regrows over time (see M25). Berries show up in resource counts.

**M18 — Energy + sleep** (M)
Needs drain in per-hash loop step 1: energy drains per hash interval while awake (skip drain during sleep action). Sleep thresholds from `time.getEnergyThresholds()` — time-of-day varying. Hard interrupt (energy < hard_threshold): drop carried resources via ground drop, release current activity, post private sleep activity, sleep on current tile. Soft interrupt (energy < current soft threshold): set `soft_interrupt_pending` if mid-work; execute directly if at clean break. Soft interrupt consumption in `onActionComplete` priority chain. Sleep action: `sleepStep()` adds `recovery_rate` per tick, wakes when energy ≥ current wake threshold. Collapse (energy == 0): sleep on current tile immediately. Sleep destination: current tile for all units (no homes yet).
Docs: BEHAVIOR.md § Sleep (all subsections), Need Interrupts, Per-hash loop steps 1–3, onActionComplete priority chain. TABLES.md § NeedsConfig (energy), SleepConfig.
Verify: Let units run. As evening approaches, energy drops, units go to sleep (action changes to "sleep" in debug dump). Units wake in the morning. Increase speed → watch sleep/wake cycle over multiple days. Force energy to 0 via debug → unit collapses on current tile. Unit carrying resources when hard interrupt fires → resources dropped as ground pile.

**M19 — Cottage + home assignment** (S)
Cottage building (3×3, tile map with walls/floor/door, 2 beds). Placement mode (temporary debug key). Instant placement in P1. Tile map rendering (walls as dark rectangles, floor as lighter area, door as gap). Home assignment: when a unit needs a home, assign first housing building with available bed. `unit.home_id` ↔ `building.housing.member_ids`, `unit.bed_index` ↔ `bed.unit_id`. Trigger home assignment on building completion and when units are homeless. Sleep destination changes: if `home_id` set, travel home to sleep. If homeless, sleep on current tile (existing behavior). Housing bins initialized from HousingBinConfig (food storage at home — used by eating in M23).
Docs: WORLD.md § Building Layout (tile maps, door, orientation). BEHAVIOR.md § Home Assignment, Sleep (destination). TABLES.md § BuildingConfig (cottage), HousingBinConfig, building.housing.
Verify: Place a cottage. Units get assigned homes (debug dump shows `home_id`). When energy drops, units walk home and sleep inside the building. Homeless units still sleep on the ground. Place a second cottage → remaining homeless units get assigned.

**M20 — Gatherer's hut** (M)
Gatherer's hut building (solid, `is_solid = true`, all-W tile map, no interior). Placement mode (temporary debug key). Building-based gathering work cycle: building posts activities gated on nearby mature berry bush count. Worker claims activity → paths to hub (adjacent-to-rect) → scans for nearest valid berry bush from building position → claims tile → paths to bush → harvests → chains (scan from unit position) or deposits when full → returns to hub → repeats. Activity posting limited by `max_workers` and available targets.
Docs: BEHAVIOR.md § Building-based work cycle (gathering). WORLD.md § Solid Buildings. TABLES.md § BuildingConfig (gatherers_hut), ActivityTypeConfig (gatherer).
Verify: Place gatherer's hut near berry bushes. Workers automatically gather berries in a loop without player designation. Workers return to hub between trips. No workers dispatched when no mature bushes exist. Multiple huts work independently.

**M21 — Woodcutter's camp** (S)
Woodcutter's camp building (solid). Placement mode (temporary debug key). Same hub → resource → storage pattern as gatherer's hut but for trees. Chop work cycle from hub: scan for mature trees from building position, chop, carry wood, deposit, return to hub.
Docs: BEHAVIOR.md § Building-based work cycle (gathering — same pattern). TABLES.md § BuildingConfig (woodcutters_camp), ActivityTypeConfig (woodcutter).
Verify: Place woodcutter's camp near trees. Workers chop trees and deposit wood at stockpile automatically. Trees are permanently removed (no regrowth). Camp stops posting activities when no trees in range.

**M22 — Fishing dock** (M)
Fishing dock building (edge building: back row on water, front row on grass). Placement validation: back row must be water, front row must be grass/dirt. Tile map with water-facing work area. Extraction work cycle: worker stays at building, executes work action (stationary), fish granted to carrying, deposits when full, returns. Fish resource type with nutrition value.
Docs: WORLD.md § Building Layout (edge buildings, door face). BEHAVIOR.md § Extraction work cycle. TABLES.md § BuildingConfig (fishing_dock), ActivityTypeConfig (fisher), ResourceConfig (fish).
Verify: Place fishing dock with back on water, front on land. Rejects placement if water requirement not met. Worker produces fish in a loop. Fish deposited at stockpile. Fish visible in resource counts as food.

**M23 — Satiation + eating** (M)
Satiation drain in per-hash loop step 1. Satiation interrupts (soft at 75, hard at 15) — availability-gated: only fires if food exists in storage (check `resource_counts.storage` for any food type). Hard interrupt: drop, release, post private eat activity. Soft interrupt: same deferred/direct pattern as energy. Eating work cycle: if `home_id` set, travel home, consume from housing bins (consumption loop: eat one item, check satiation, repeat). Food selection prefers least-recently-eaten type (`unit.last_ate`). Home food self-fetch: if home bins empty, haul food from nearest stockpile to home bin, then eat. Homeless eating: eat from nearest stockpile directly. `secondary_haul_activity_id` for food reservation during travel.
Docs: BEHAVIOR.md § Need Interrupts (satiation), Eating Behavior, Home Food Self-Fetch, Homeless Eating, Eating Work Cycle. TABLES.md § NeedsConfig (satiation), ResourceConfig (nutrition values), HousingBinConfig. ECONOMY.md § Resources Module API.
Verify: Units get hungry and eat. With a cottage, units walk home and eat from home bins. Home runs out → unit fetches food from stockpile to home. No cottage → unit eats directly from stockpile. No food anywhere → satiation drains to 0 (no interrupt fires). `last_ate` tracks food types. Food variety rotation visible in debug dump.

**M24 — Health + starvation + death** (M)
Health system: malnourishment when satiation == 0 — health drains per `MalnourishedConfig.health_drain`. Death when health ≤ 0: `unit.is_dead = true`. `units.sweepDead()` runs end-of-tick with full cleanup: convert to memory, update registry, social cleanup (stub — no relationships yet), target tile release, tile position cleanup, activity cleanup, ground pile drop (carried resources + equipped items), home cleanup (remove from housing), remove from `world.units` (swap-and-pop). Death notification with auto-pause. Starvation warning notification when satiation is low.
Docs: BEHAVIOR.md § Unit Death Cleanup (all 12 steps). TABLES.md § MalnourishedConfig, memory data structure. UI.md § Notifications (death, starvation warning).
Verify: Remove all food sources. Units starve: satiation hits 0, health drains, unit dies. Death notification appears and game pauses. Dead unit disappears from map. Carried resources drop as ground pile. Home bed freed. Other units continue. Memory entity exists in registry.

**M25 — Plant growth + spread** (S)
Plant cursor scan: `SPREAD_TILES_PER_TICK` tiles per tick, linear wrap across full grid. Growth promotion: seedling → young (if enough ticks elapsed per `PlantConfig.seedling_ticks`, defer tree seedling→young if unit on tile), young → mature (per `PlantConfig.young_ticks`). `world.growing_plant_data[tileIndex]` tracks `planted_tick` for stages 1–2, removed on promotion to mature. Mature spread: roll `spread_chance`, place same type at random tile within `spread_radius` (manhattan distance). Safety: no spread adjacent to buildings, no spread onto tiles with `building_id`.
Docs: WORLD.md § Plant System (growth stages, spread, cursor scan). TABLES.md § PlantConfig.
Verify: Gather a berry bush (resets to stage 1). Watch it regrow through stages over time (visible size changes). Mature trees spread to nearby open tiles — new seedlings appear. No plants grow on or adjacent to buildings. Plant growth data visible in dev overlay tile inspector.

**M26 — Building deletion** (S)
Delete command: select a building, press Del → `building.is_deleted = true`. `buildings.sweepDeleted()` at end of tick: release posted activities and their claimants, restore footprint tiles (clear `building_id`, restore terrain), eject units on footprint tiles (flood fill to nearest pathable tile), drop container contents as ground piles via ground drop search, free residents (clear `home_id`, `bed_index`), clear filter pull sources (stub — no filters in P1), remove from `world.buildings` (swap-and-pop).
Docs: BEHAVIOR.md § Building Deletion (full cleanup sequence). UI.md § Command Bar (Delete).
Verify: Place a stockpile with wood in it. Delete it → wood appears as ground pile on nearby tiles. Place cottage with residents → delete → residents become homeless, sleep on ground next night. Delete a building with a worker en route → worker goes idle.

**M27 — Notifications** (S)
Notification feed in right panel, newest at top. Each entry: event type + relevant name. P1 types: unit death (auto-pause), unit trapped (no pause), storage full (no pause), starvation warning (no pause). Click notification → center camera on source entity/position, select if living unit. Notifications accumulate and persist. Storage full triggers when a unit tries to deposit and no stockpile has capacity for that resource type. Trapped triggers when A* returns no path.
Docs: UI.md § Notifications (P1 types, click behavior, auto-pause).
Verify: Unit dies → notification appears, game pauses, click notification → camera centers on death location. Fill all stockpiles → "No storage has capacity for wood" appears. Surround a unit with buildings → "Serf X is trapped" appears.

**M28 — Action bar + command bar + population list** (M)
Action bar: persistent bottom bar with building placement buttons (Stockpile, Cottage, Woodcutter's Camp, Gatherer's Hut, Fishing Dock), designation buttons (Chop, Gather, Cancel Designation), and Population List button. Command bar: contextual buttons based on selection — Delete button when a building is selected. Population list: management overlay opened from action bar, sortable list of all units with name/class/needs summary. Escape to close.
Docs: UI.md § Action Bar (P1 buttons), Command Bar (P1 commands), Management Overlays (Population List).
Verify: All building placement and designation modes accessible from action bar buttons. Select building → Delete button appears in command bar. Open population list → see all units. Sort by name. Close with escape.

**M29 — Debug spawn** (XS)
F1 spawns a serf at cursor tile position. Shift+F1 spawns 5. Reject spawn on impassable tiles. Ring search outward if tile has `target_of_unit` set. Batch spawn places sequentially with ring search. Log each spawn.
Docs: CLAUDE.md § Debug Spawn.
Verify: F1 on grass → new unit appears. F1 on water → nothing happens. Shift+F1 → 5 units spread across nearby tiles. Log shows spawn messages.

**M30 — Save/load** (M)
`core/save.lua`. Serialize `world` (all entity arrays, tiles, time, settings), `registry.next_id` as Lua table literals via `love.filesystem`. Versioned format. Deserialize rebuilds everything: registry hash table from all entity arrays, `resource_counts` via `rebuildCounts()`. F5 = quicksave to `saves/quicksave.lua`. F9 = quickload (ignored if no file). Quit-to-menu autosaves. Main menu "Continue" button appears when save file exists. Full teardown on quit-to-menu (clear `world` and `registry`).
Docs: CLAUDE.md § Serialization, Save File Management (P1). TABLES.md § world data structure.
Verify: Play for a few minutes, F5. Quit to menu. "Continue" appears → click → game resumes exactly where it was. Units in same positions, stockpiles with same contents, time at same point. F9 during play → reloads to last save. Corrupt save file → clear error message.

## Development Phases

Development is organized into twelve phases. Each phase produces a qualitatively different version of the game. Pending design items are listed under each phase — when all items are resolved, the pending list disappears.

**Phase 1 — Survival.** The core simulation runs. Six serfs exist on a generated map, move via pathfinding, and have needs that drain over time. The player designates map resources for collection and places buildings to organize labor. Serfs gather berries and fish to survive, haul resources to stockpiles, chop wood, and sleep in instantly-placed housing. The game has a basic UI for placing buildings, inspecting units, and controlling time. Save/load works. If food runs out, units starve and die. No leader, no dynasty, no classes beyond serf — those arrive in later phases. This phase proves the simulation engine — time, movement, needs, actions, hauling, and death all function together.

**Phase 2 — Basic Economy.** The non-farming production economy comes online. Proper construction replaces instant-build. Freemen with specialties work at processing buildings. The player configures serf priorities, manages production orders, and assigns specialties. Extraction buildings come online — the quarry produces stone for construction, the iron mine supplies iron. The blacksmith produces iron tools. Storage progresses from stockpiles to warehouses and barns. Storage filters let the player control what each building accepts, how much, and whether it actively pulls from other storage. Equipment degrades over time, creating ongoing demand. Save/load expands from a single quicksave to multiple named saves, season-boundary autosaves, and a load screen on the main menu.

*Pending:*
- Barn details — final name, building size, item capacity, UI panel design
- Storage filter UI — per-type filter controls on storage building panels
- Serf priority system — per-unit priorities with optional priority groups, management overlay UI
- Production order UI — building left panel controls for add/remove/reorder/configure
- Specialty assignment / promotion UI — unit left panel controls for serf → freeman promotion and specialty selection
- Worker limit adjustment UI — building left panel control

**Phase 3 — Advanced Economy.** Farming and food processing transform the settlement's food supply. Farms follow the seasonal cycle — frost and thaw create yearly tension around crop selection and harvest timing. The bread chain (wheat → flour → bread) and brewery (barley → beer) come online. The tailor converts flax into plain clothing. A merchant at the market delivers food to homes, replacing manual self-fetch. The full metalworking chain arrives: the chopping block processes wood into firewood, the bloomery converts iron and firewood into steel, and the smithy gains steel tool production. Wood now competes between three uses: construction, firewood for warmth, and firewood for smelting. Firewood (processed from wood) fuels both home heating in winter and steel production at the bloomery.

*Pending:*
- Frost day ranges — exact thaw_day and frost_day value ranges for tuning
- Firewood delivery to homes — how firewood reaches housing, consumption rate, what happens when a home runs out
- Home heating mechanics — seasonal fuel consumption, cold penalties
- Berry bush clearing — permanent removal (yields berries), auto-clear on building placement, designation UI
- Equipment quality ranking — how units choose between tool variants (e.g., steel_tools vs iron_tools)
- Chopping block — building size, tile map, worker count

**Phase 4 — Mood and Health.** The settlement's quality of life matters. Mood reflects housing, food variety, clothing, and tools — giving the player something to optimize beyond survival. Food variety rewards diversification across multiple food sources. Mood thresholds affect productivity and can drive deviancy. Consumer goods degrade and must be resupplied. The tavern provides recreation and serves as the evening social hub. Illness threatens units and requires a working physician. This phase transforms the game from a logistics puzzle into a settlement that feels alive.

*Pending:*
- Ground drop UI — how to display multiple resource types on the same tile when overlap occurs
- Herbalist's hut — deferred from Phase 1; herbs have no consumer until physician exists in Phase 4
- Tavern — barkeep stocking schedule, patron capacity, beer consumption flow, diminishing returns formula for recreation recovery
- Apothecary mechanics — herb consumption, patient detection, physician travel logic
- Trait config — mechanical values for Crippled (see _BRAINSTORMING.md for Touched, Changeling)

**Phase 5 — Generations and Relationships.** Time becomes the central mechanic. Units age, marry, have children, and die of old age. Social relationships form between units. The game delivers on the "individual stories" pillar — the player watches families grow, friendships develop, and generations pass.

*Pending:*
- Immigration — triggers, frequency, unit class
- Population growth — soft caps, growth curve tuning
- Home assignment — manual player override (auto-assignment is designed; see TABLES.md)
- Demotion mechanics — whether and how freemen/gentry can be demoted
- Marriage formation — eligibility rules, triggers, ceremony, class promotion implications
- Relationship formation — how friend/enemy relationships form, deepen, and break

**Phase 6 — Institutions.** The settlement deepens with education and religion. Schools educate children, improving intelligence over generations. Churches host Sunday services, providing a mood bonus scaled by the priest's skill. The apprenticeship system offers an alternative path for skill development.

*Pending:*
- School mechanics — intelligence growth rate, teacher skill scaling, capacity overflow
- Apprenticeship system — how it works, relationship to specialties (see _BRAINSTORMING.md)

**Phase 7 — Animals.** Hunting and animal husbandry expand the economy with new resources. Hunters venture into the forest for deer, producing meat (a new food type) and leather. Pastures are player-sizable buildings for raising livestock. Sheep provide wool and meat; cows provide meat; both produce leather on slaughter. Horses offer mounted travel and utility. With leather and wool available alongside flax, the tailor can produce fine clothing (two textiles) and noble clothing (three textiles). Hunting provides early-game access to meat and leather but is unsustainable; pastures are slower to establish but renewable.

*Pending:*
- Pasture mechanics — animal capacity, breeding, feeding, culling
- Hunting mechanics — hunter building, deer spawning, sustainability limits
- Horse utility — mounted travel, draft power, military role (see _BRAINSTORMING.md)
- Fine and noble clothing recipes — specific textile input combinations

**Phase 8 — Gentry, Leaders, Succession.** The political layer arrives. Gentry are the ruling class — they do not work, consuming resources in exchange for political stability and military readiness. The leader's death triggers succession, and the heir's readiness (or lack thereof) creates drama. Gold mining and jewelry production come online. The potter's workshop converts clay into pottery. Class expectations now carry real economic weight: freemen and clergy expect fine clothing and pottery; gentry expect noble clothing, pottery, and jewelry. Every promotion has a tangible cost.

*Pending:*
- Dynasty/succession — traversal mechanics
- Leadership skill — growth mechanism, effects
- Gentry activities — what gentry do with their time (see _BRAINSTORMING.md)
- Pottery and clay — clay gathering terrain, potter's workshop details
- Class expectation mechanics — mood penalties for missing expected goods

**Phase 9 — Dangerous World.** The world beyond the village becomes a threat. Combat mechanics enable military response to bandits, wolves, and forest creatures. The blacksmith gains weapon and armor recipes. Knights train at the barracks. Drafting pulls units from their activities, creating economic tension. Injuries from combat require medical treatment. The "losing is fun" pillar expands beyond mismanagement to include external pressure.

*Pending:*
- Combat mechanics — melee system, unit stats, threat encounters (see _BRAINSTORMING.md)
- Knight specialty — granting knighthood, gentry promotion, training system (see _BRAINSTORMING.md)
- Barracks — function, training mechanics (see _BRAINSTORMING.md)
- Ranged combat, scout activity (see _BRAINSTORMING.md)
- Trait effects on movement speed

**Phase 10 — Advanced Institutions.** The settlement's intellectual and spiritual life reaches its peak. Bishops lead the clergy and unlock late-game religious events. Scholars research at libraries, expanding the settlement's knowledge. Cathedrals are the culmination of religious investment — grand buildings that serve as landmarks.

*Pending:*
- Bishop promotion mechanics — requirements, effects
- Scholar/library — research system, what knowledge unlocks
- Cathedral — function, build requirements, events (Christmas Mass)

**Phase 11 — The Forest.** The wilderness becomes a place to explore, not just harvest. Visibility and fog of war make the forest a place of uncertainty. Forest depth gameplay gates resources — basic materials are available everywhere, rarer materials require venturing deeper. Scouts reveal the map. Wildlife scales with depth: wolves appear anywhere, dire wolves are forest-only.

*Pending:*
- Visibility system — vision rules, implementation approach (see _BRAINSTORMING.md)

**Phase 12 — The Strange.** The game's supernatural layer emerges. Fey creatures inhabit the deep forest with their own alien logic — some can be bargained with, others must be fought. Christian supernatural forces introduce ghosts, demons, and possessed units. The scholar unlocks arcane magic through research, the bishop receives divine power through the Vision. The game world deepens from a grounded medieval settlement into something stranger and more mythic. See _BRAINSTORMING.md for creature lists, encounter concepts, and magic system ideas.

*Pending:*
- Fey mechanics — encounter design, diplomacy, late-game escalation (see _BRAINSTORMING.md)
- Magic — arcane tech tree, divine scripture, spell lists, mana rates (see _BRAINSTORMING.md)
- Witch gender setting — mechanical effect (depends on arcane magic system)

**Unphased.** Ideas and systems that don't belong to a specific phase yet.

- External trade (see _BRAINSTORMING.md)
- Luxury goods beyond jewelry
- Event speed controls (see _BRAINSTORMING.md)
