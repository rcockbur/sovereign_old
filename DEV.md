# Sovereign — DEV.md
*v3 · Dev tools, testing infrastructure, and startup validation.*

## Logging

LOG SYSTEM (`core/log.lua`)

Categories: `TIME`, `UNIT`, `ACTIVITY`, `WORLD`, `HEALTH`, `HAUL`, `SAVE`, `STATE`. Severity levels: OFF, ERROR, WARN, INFO, DEBUG. Ring buffer of last 200 messages for overlay. `log:info("UNIT", "Unit %d claimed activity %d", unit.id, activity.id)`.

File output writes via `love.filesystem` to a `logs/` subdirectory under the Love2D save directory (e.g., `%APPDATA%/LOVE/sovereign/logs/` on Windows). Each session creates a timestamped file, plus `current.log` always points at the most recent session for easy tailing. The active log path is exposed as `log.filepath`. Older sessions are pruned to keep the directory bounded.

## Developer Overlay

DEVELOPER OVERLAY (`ui/dev_overlay.lua`)

Toggled with F3. Stats bar: FPS, game_time, speed, TPS (achieved / target, with percentage), unit/building/activity counts. Tile inspector on hover: coordinates, terrain, plant_type/plant_growth, forest_depth, building_id, ground resources, claimed_by, visibility. Log tail: last ~10 messages.

TPS TRACKING

The time module tracks ticks-per-second for the dev overlay. `ticks_this_second` increments each tick. Once per real second, the count snapshots to `ticks_last_second` and resets. Target TPS is `speed * TICK_RATE`. The overlay displays: `TPS: 2400 / 3840 (62%)`. These fields are transient runtime state on the time module — not serialized, not part of `world.time`.

DEBUG SPAWN

F1 spawns a serf at the cursor's tile position. Shift+F1 spawns 5 serfs. Input handling lives in the UI layer (`keypressed`); the UI resolves the cursor's world tile via camera coordinate conversion, then calls `units.spawnSerf(x, y)`. Spawn logic stays in the Units module where unit lifecycle belongs.

Each spawned unit goes through the normal creation path — registry, name generation, needs initialized to full, target tile claimed, `tile.unit_ids` updated — so they're indistinguishable from game-start units. If the cursor tile is impassable (water, rock), the spawn is rejected (no fallback). If the tile is pathable but has `target_of_unit` set, ring search outward for the nearest pathable tile with `target_of_unit == nil`. Batch spawn (Shift+F1) places each unit sequentially — later units in the batch ring-search outward from tiles already claimed by earlier ones. If ring search hits the radius cap, that individual spawn is silently skipped.

Logs each spawn: `log:info("UNIT", "Debug spawned unit %d at (%d, %d)", unit.id, x, y)`.

## Config Validation

Runs during the `loading` game state — the game never reaches `playing` with broken config. Walks all config tables and asserts cross-references are valid:

- Every RecipeConfig input/output key exists in ResourceConfig
- Every BuildingConfig `activity_types` entry references a valid ActivityTypeConfig key
- Every ActivityTypeConfig entry with `skill` references a valid key in the unit skills table
- Every BuildingConfig with `category == "processing"` has `max_workers == 1`
- Every BuildingConfig with `tile_map` containing at least one `D` has exactly one `D` tile, the `D` tile is on the perimeter, all `I` tiles are contiguous and reachable from `D` through same-building edges, all layout positions fall on `I` or `D` tiles, and `X` tiles may appear anywhere
- Every BuildingConfig with `tile_map` containing no `D` (solid building) has a tile_map of only `X` tiles and an empty `layout`
- Every MerchantConfig bin_threshold key exists in ResourceConfig
- Every ResourceConfig entry with `is_stackable == false` has `max_durability`
- Every ResourceConfig entry with `nutrition` has `is_stackable == true`
- Every ResourceConfig entry with `tool_bonus` has `is_stackable == false`
- Every BuildingConfig processing `input_bins` type matches a key in the building's recipe inputs
- Every HousingBinConfig type matches a valid ResourceConfig key

Errors use `error()` or `assert` with descriptive messages. No graceful fallback — broken config is a programming error.

## Tests

LOGIC TESTS (OFFLINE)

Live in `tests/`. Run outside Love2D with `luajit tests/run.lua` from the repo root. Test pure logic where incorrect math or edge cases are hard to catch visually:

- Need drain rates and interrupt thresholds
- Carrying weight / speed penalty formula
- Mood recalculation (modifier stacking, food variety counting)
- A* pathfinding (optimal paths, impassable tiles, escape case, diagonal rules)
- Hash offset distribution
- Resource transfer (split, merge, capacity clamping)
- Resource count tally accuracy (running tallies match full recount)

Tests are added per-system as that system is implemented — not batched per-phase.

Test runner (`tests/run.lua`) prepends `src/` to `package.path`, requires each registered test file, and calls every function in its returned list. A test passes if it completes without error. Test files are manually registered in `run.lua`.

```lua
-- tests/test_carrying.lua
require("config.constants")

local function test_speedPenaltyAtMaxWeight()
    local weight_ratio = 32 / CARRY_WEIGHT_MAX
    local slow_factor = MAX_CARRY_SLOW * (1 - 0 / 10)
    local move_speed = 1.0 * (1 - weight_ratio * slow_factor)
    assert(move_speed == 0.5, "zero-strength unit at max weight should be half speed")
end

return {
    test_speedPenaltyAtMaxWeight,
}
```

Testable modules must not depend on Love2D at require time. If a test crashes on require, refactor the module to remove the engine dependency — don't mock Love2D. Headless soak testing (Love2D with `t.window = false`) is deferred until enough systems exist for meaningful integration tests.

NOT TESTED

Rendering, UI, camera, input handling, high-level integration (e.g., "does a woodcutter complete a full work cycle"). These are faster to verify by watching the game run.
