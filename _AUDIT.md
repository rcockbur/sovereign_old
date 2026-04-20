# Sovereign — Codebase Audit M01–M17 + Cross-cutting

*Scope: M01 through M17 inclusive, plus a cross-cutting pass over the full codebase. No source files were modified.*
*Methodology: Each spec file was read in full, then all source files relevant to each milestone, then all source files read again in aggregate for cross-cutting patterns.*

---

## Running Summary

| Milestone | Correctness | Undocumented | Architectural | Improvements | Spec Ambiguity | Total |
|-----------|-------------|--------------|---------------|--------------|----------------|-------|
| M01       | 1 minor     | 1 mod, 3 min | —             | —            | —              | 5     |
| M02       | 1 critical  | 4 minor      | —             | 1 minor      | 1 minor        | 7     |
| M03       | —           | 1 moderate   | —             | 1 minor      | —              | 2     |
| M04       | 1 crit, 1 mod | 1 mod, 1 min | —           | —            | —              | 4     |
| M05       | —           | 2 minor      | 1 minor       | —            | —              | 3     |
| M06       | 1 mod, 2 min | —           | —             | —            | —              | 3     |
| M07       | —           | 1 mod, 3 min | —             | 1 minor      | —              | 5     |
| M08       | 1 minor     | 1 moderate   | 2 minor       | —            | 1 minor        | 5     |
| M09       | 1 moderate  | 1 minor      | —             | —            | —              | 2     |
| M10       | 1 minor     | —            | —             | —            | —              | 1     |
| M11       | 1 moderate  | —            | —             | —            | —              | 1     |
| M12       | 2 moderate  | 1 minor      | —             | —            | —              | 3     |
| M13       | 1 minor     | —            | —             | —            | —              | 1     |
| M14       | —           | 1 mod, 2 min | —             | —            | —              | 3     |
| M15       | —           | —            | —             | —            | —              | 0     |
| M16       | —           | 1 minor      | —             | —            | —              | 1     |
| M17       | 1 moderate  | —            | —             | —            | —              | 1     |
| **Cross** | 2 moderate  | 3 minor      | 1 mod, 1 min  | 3 minor      | —              | 10    |
| **Total** | **2c, 9m, 6mn** | **6m, 21mn** | **1m, 4mn** | **6mn**   | **2mn**        | **57** |

**By severity:** Critical: 2 · Moderate: 16 · Minor: 39
**By category:** Correctness: 17 · Undocumented: 27 · Architectural: 5 · Improvements: 6 · Spec Ambiguity: 2

---

## M01 — Foundation: Core Modules, Config, Gamestate, Entry Point

### Finding M01-01
- **Category:** Undocumented forced decision
- **Severity:** Moderate
- **File:line:** `src/app/generating.lua` (whole file), `src/app/main_menu.lua:main_menu.keypressed`
- **Spec reference:** CLAUDE.md § Game State Machine ("three state files: loading, main_menu, playing")
- **Finding:** A fourth game state `generating` exists and is not mentioned in spec. `main_menu` switches to `generating` on "New Game", not to `playing`. `generating` drives the world generation coroutine and shows a progress bar before handing off to `playing`.
- **Evidence:** CLAUDE.md names exactly three state files (`loading`, `main_menu`, `playing`). `app/generating.lua` is a separate file. `main_menu.lua` calls `gamestate:switch(generating)`. `playing.enter()` does not run map generation.
- **Suggested action:** Document the `generating` state in CLAUDE.md under Game State Machine. Describe its role (coroutine driver + progress bar) and the revised transition graph: `loading → main_menu → generating → playing`.

---

### Finding M01-02
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/main.lua:1–10`
- **Spec reference:** CLAUDE.md § Entry Point (`if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then`)
- **Finding:** The debugger guard uses `ARGS_DEBUG` (a parsed command-line flag) rather than the env-var check shown in CLAUDE.md. The arg-parsing block also handles `--newgame` and sets `ARGS_AUTO_NEWGAME`, which bypasses the main menu.
- **Evidence:** Spec shows `os.getenv("LOCAL_LUA_DEBUGGER_VSCODE")`. Actual code parses `love.arg.parseGameArguments(arg)` and checks a flag. `ARGS_AUTO_NEWGAME` appears in `loading.lua` to trigger `generating` directly.
- **Suggested action:** Update CLAUDE.md entry point snippet to match the implemented arg-parsing approach, and document `--newgame` and `--debug` CLI flags.

---

### Finding M01-03
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/main.lua` (`require("core.util")`), `src/core/util.lua` (whole file)
- **Spec reference:** CLAUDE.md § Entry Point (lists requires: `config.constants`, `config.keybinds`, `config.tables`, then `app.gamestate` and `app.loading`); § Folder Structure (no `core/util.lua` listed)
- **Finding:** `core/util.lua` exists as an undocumented module. It is required from `main.lua` and installs `tileIndex`, `tileXY`, and `table.deepCopy` as globals. The flat-index functions are defined in CLAUDE.md § Flat Index Convention as inline snippets, not as a named module.
- **Evidence:** `main.lua` has `require("core.util")`. File `src/core/util.lua` exists with those three functions. CLAUDE.md module ownership table has no `util` entry.
- **Suggested action:** Add `core/util.lua` to the folder structure and module ownership table. Note that it installs the flat-index helpers as globals.

---

### Finding M01-04
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/main.lua`, `src/app/gamestate.lua`
- **Spec reference:** CLAUDE.md § Entry Point (lists `love.load`, `love.update`, `love.draw`, `love.keypressed`, `love.mousepressed` only)
- **Finding:** Two additional Love2D callbacks are wired: `love.mousereleased` and `love.wheelmoved`. Both are forwarded through `gamestate` and handled by the UI layer.
- **Evidence:** Spec entry point snippet lists five callbacks. Implementation adds two more. `gamestate.lua` has corresponding forwarding methods.
- **Suggested action:** Add `love.mousereleased` and `love.wheelmoved` to the entry point documentation and the `gamestate` callback-forwarding list.

---

### Finding M01-05
- **Category:** Correctness
- **Severity:** Minor
- **File:line:** `src/app/playing.lua:enter()`
- **Spec reference:** CLAUDE.md § Game State Machine (`playing.enter()` initializes the game: "generate settlement name … map generation, spawn starting units and buildings, resources.rebuildCounts()")
- **Finding:** `playing.enter()` does not perform map generation. That step was relocated to `generating.lua`. The CLAUDE.md description of `playing.enter()` is therefore inaccurate.
- **Evidence:** `playing.enter()` calls `time.init()`, `camera.init()`, `units.spawnStarting()`, `resources.rebuildCounts()` — no map generation call. Map generation lives in `generating.lua`.
- **Suggested action:** Update CLAUDE.md `playing.enter()` description to reflect that map generation happens in the `generating` state. `playing.enter()` receives an already-generated world.

---

**M01 status: 5 findings (1 moderate, 4 minor — all undocumented decisions or doc drift; no logic errors).**

---

## M02 — Config, Constants, Keybinds, Log System

### Finding M02-01
- **Category:** Correctness
- **Severity:** Critical
- **File:line:** `src/config/constants.lua` (`BASE_MOVE_COST`)
- **Spec reference:** CLAUDE.md § Constants (`BASE_MOVE_COST = 6`); WORLD.md § Movement Model (`BASE_MOVE_COST: ticks per tile on open ground`)
- **Finding:** `BASE_MOVE_COST` is set to `40` in the implementation. CLAUDE.md's constants section explicitly states `BASE_MOVE_COST = 6`. This is a 6.7× discrepancy and affects every movement calculation in the game — unit travel times, lerp interpolation durations, pathfinding cost comparisons, and carry-speed penalty scaling.
- **Evidence:** `config/constants.lua` contains `BASE_MOVE_COST = 40`. CLAUDE.md states `BASE_MOVE_COST = 6`. The value 40 aligns with `TICKS_PER_MINUTE = 25` (roughly 1.6 tiles/minute at normal carry) whereas 6 aligns with approximately 10 tiles/minute. The difference is large enough that the intended design value must be resolved.
- **Suggested action:** Determine the intended value (6 or 40) and update either the constant or the CLAUDE.md spec. If 40 is intentional (tuned value), add an Implementation Note to ROADMAP.md explaining the change from the spec value.

---

### Finding M02-02
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/config/constants.lua` (`DEBUG_VALIDATE_RESOURCE_COUNTS`)
- **Spec reference:** CLAUDE.md § Constants (no `DEBUG_VALIDATE_RESOURCE_COUNTS` listed)
- **Finding:** A debug flag `DEBUG_VALIDATE_RESOURCE_COUNTS = false` is present in `constants.lua`. It is not listed in CLAUDE.md's constants section and its intended semantics (when should it be `true`, which validation it gates) are undocumented.
- **Evidence:** Constant present in `constants.lua`, absent from CLAUDE.md constants table. Referenced in `simulation/resources.lua` (`validateCounts`).
- **Suggested action:** Add to CLAUDE.md constants section with a note that it gates the per-tick resource count integrity check (enabled during development, disabled in production builds).

---

### Finding M02-03
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/config/constants.lua` (GEN_* block)
- **Spec reference:** CLAUDE.md § Constants (no GEN_* constants listed); WORLD.md § Map Generation (refers to tuning parameters but does not specify constant names)
- **Finding:** Several map-generation tuning constants (e.g. `GEN_*` prefixed) are present in `constants.lua` but are not listed in CLAUDE.md's constants section.
- **Evidence:** Constants present in `constants.lua`, absent from CLAUDE.md. WORLD.md acknowledges tuning parameters exist without specifying exact names.
- **Suggested action:** Add a "Map generation tuning" block to the CLAUDE.md constants section listing the GEN_* constants and their roles.

---

### Finding M02-04
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/core/log.lua` (file-output section)
- **Spec reference:** CLAUDE.md § Dev Tools ("Each session creates a timestamped file (e.g., `logs/2026-04-11_14-30-05.log`)")
- **Finding:** The log system writes two files per session: the documented timestamped file and an additional `logs/current.log` that always reflects the most recent session. This second file is not mentioned in the spec. `log.filepath` exposes its path.
- **Evidence:** `log.lua` opens both a timestamped file and `logs/current.log`. CLAUDE.md describes only the timestamped file. `log.filepath` is an undocumented public field.
- **Suggested action:** Document `current.log` in CLAUDE.md's log system section as a convenience symlink/alias to the latest session log. Document `log.filepath`.

---

### Finding M02-05
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/config/keybinds.lua`, `src/config/constants.lua`
- **Spec reference:** TABLES.md § Keybinds (lists specific keybind entries; `pan_up`, `pan_down`, `pan_left`, `pan_right` are absent)
- **Finding:** Four pan keybinds (`pan_up`, `pan_down`, `pan_left`, `pan_right`) are present in both `keybinds.lua` and `constants.lua` but are not in TABLES.md's Keybinds table definition.
- **Evidence:** `keybinds.lua` and `constants.lua` contain these four entries. TABLES.md Keybinds table does not list them.
- **Suggested action:** Add `pan_up`, `pan_down`, `pan_left`, `pan_right` to the Keybinds table in TABLES.md.

---

### Finding M02-06
- **Category:** Spec ambiguity
- **Severity:** Minor
- **File:line:** `src/config/constants.lua` (`BASE_MOVE_COST`), CLAUDE.md § Constants, WORLD.md § Movement Model
- **Spec reference:** CLAUDE.md § Constants and WORLD.md § Movement Model both specify `BASE_MOVE_COST = 6`
- **Finding:** Two spec files both state `BASE_MOVE_COST = 6`, making this authoritative. However, given the implemented value of 40 and the fact that both spec files are consistent, this is not an ambiguity in the spec — the spec is clear. The ambiguity is whether the implementation diverged intentionally (tuning) or accidentally. Recorded here for completeness and to flag the need for resolution.
- **Evidence:** CLAUDE.md: `BASE_MOVE_COST = 6`. WORLD.md: same. Implementation: 40.
- **Suggested action:** Resolve as part of M02-01 above. If 40 was intentional tuning, both spec files need updating to reflect the tuned value.

---

### Finding M02-07
- **Category:** Improvements
- **Severity:** Minor
- **File:line:** `tests/test_resources.lua` (`makeStockpile` helper)
- **Spec reference:** ECONOMY.md § Tile Inventory container structure; ECONOMY.md § Reservation System
- **Finding:** The `makeStockpile` test helper creates an incomplete container structure: per-tile entries use a scalar `reserved_in = 0` instead of a type-keyed table `{}`, and the container lacks top-level `reserved_in = {}` / `reserved_out = {}` fields. This means any test that calls `resources.deposit()` or `resources.withdraw()` on this fake stockpile will hit assertion failures because the production code expects the table form of reservations.
- **Evidence:** `test_resources.lua` `makeStockpile` helper initializes tile entries with scalar reservation fields. `resources.lua` deposit/withdraw assert against table lookups. The tests that exercise deposit and withdraw would fail if run against the current production resources module.
- **Suggested action:** Update `makeStockpile` to match the container shape that the production resources module expects: container-level `reserved_in = {}` and `reserved_out = {}` tables, and per-tile-entry reservation fields in the correct form.

---

**M02 status: 7 findings (1 critical constant value mismatch, 4 undocumented additions, 1 spec ambiguity note, 1 test helper bug).**

---

## M03 — Time, Clock, Calendar

### Finding M03-01
- **Category:** Undocumented forced decision
- **Severity:** Moderate
- **File:line:** `src/core/world.lua` (`newWorld` or `world.time` initializer)
- **Spec reference:** TABLES.md § World data structure (`world.time.tick` field; shown as 0 at initialization)
- **Finding:** `world.time.tick` is initialized to `6 * TICKS_PER_HOUR` (6 AM) rather than 0. This means the game always starts at 6 AM in-game time. TABLES.md shows `tick` without a specified non-zero default.
- **Evidence:** `world.lua` world initializer sets `tick = 6 * TICKS_PER_HOUR`. TABLES.md shows the field without this offset. Starting at 6 AM is a reasonable design choice (units begin their day active), but it is undocumented.
- **Suggested action:** Document the 6 AM start in ROADMAP.md Implementation Notes, and add a comment or note in TABLES.md that `tick` initializes to `6 * TICKS_PER_HOUR` by design.

---

### Finding M03-02
- **Category:** Improvements
- **Severity:** Minor
- **File:line:** `src/core/time.lua` (`getEnergyThresholds`)
- **Spec reference:** CLAUDE.md § Constants (schedule bands defined as integer hours); BEHAVIOR.md § Sleep (thresholds compared against `game_hour`)
- **Finding:** `getEnergyThresholds()` computes a continuous fractional hour from `tick % TICKS_PER_DAY / TICKS_PER_HOUR` rather than reading the integer `game_hour` field. This enables smooth sub-hour interpolation of sleep thresholds (e.g., a morning threshold that ramps from 5.0 to 7.0 hours). This is better than the spec but goes undocumented — future maintainers reading the spec would expect integer-hour comparison.
- **Evidence:** `time.lua` uses continuous fractional hour. Spec references integer schedule constants (`MORNING_START = 5`, `DAY_START = 7`, etc.).
- **Suggested action:** Note in BEHAVIOR.md § Sleep that threshold comparisons use a continuous fractional hour derived from tick, not the discrete `game_hour`, to enable smooth ramp behavior.

---

**M03 status: 2 findings (1 moderate undocumented start time, 1 minor improvement opportunity).**

---

## M04 — World Generation, Map, Plants

### Finding M04-01
- **Category:** Undocumented forced decision
- **Severity:** Moderate
- **File:line:** `src/core/world.lua` (`newTile`)
- **Spec reference:** TABLES.md § Tile data structure (lists tile fields; `designation` and `designation_activity_id` are absent)
- **Finding:** `newTile()` initializes two fields not in TABLES.md's tile structure: `designation = nil` and `designation_activity_id = nil`. These are used by the designation system (chop/gather overlays). The fields exist in practice but are absent from the authoritative data-structure spec.
- **Evidence:** `world.lua` `newTile` includes these two fields. TABLES.md tile structure does not list them. They are actively used by `hub.lua` (designation setting) and `renderer.lua` (`drawDesignations`).
- **Suggested action:** Add `designation` (string or nil) and `designation_activity_id` (id or nil) to the tile structure in TABLES.md.

---

### Finding M04-02
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/core/world.lua` (`layerBerries`, `layerForestDepth`, `layerStartingArea`)
- **Spec reference:** WORLD.md § Map Generation (pipeline stages with progress reporting)
- **Finding:** Three generation layers call `coroutine.yield(stage.start)` where `stage.start` does not exist on the stage table — stage tables only have `.p0` and `.p1` fields. This yields `nil` to the `generating` state's progress bar, so the progress indicator does not advance during the berry scatter, forest depth, and starting area phases.
- **Evidence:** Other generation layers (terrain, forest) correctly yield `stage.p0` or `stage.p1`. The three affected layers reference `.start` which is not a defined field on the stage progress tables. The progress bar in `generating.lua` reads the yielded value to update its display; receiving `nil` causes it to stall.
- **Suggested action:** Change `coroutine.yield(stage.start)` to `coroutine.yield(stage.p0)` (or `.p1` where appropriate) in all three affected layers to restore correct progress bar advancement.

---

### Finding M04-03
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/core/world.lua` (`layerBerries`)
- **Spec reference:** WORLD.md § Map Generation (transition band logic for settlement/forest boundary)
- **Finding:** Berry scatter uses the hard `x <= SETTLEMENT_COLUMNS` boundary (column 200) as its placement constraint rather than the transition band (approximately columns 180–220) that other layers use for mixed placement. Berry bushes therefore never appear in the transition zone or the forest half of the map.
- **Evidence:** `layerBerries` uses `x <= SETTLEMENT_COLUMNS` as its condition. Other layers use probability gradients across the transition band. Whether this is intentional (berries are a settlement resource only) or an oversight is not documented.
- **Suggested action:** Determine if berry bushes should appear in the transition band or forest. If settlement-only is intentional, add a comment. If it should use the transition band, update the condition.

---

### Finding M04-04
- **Category:** Correctness
- **Severity:** Critical
- **File:line:** `src/core/world.lua` (`getTileCost`)
- **Spec reference:** WORLD.md § Pathfinding — Tile Costs (wall tiles are impassable; floor/door tiles passable at BASE_MOVE_COST); WORLD.md § Building Layout (tile map types W/F/D define passability)
- **Finding:** `world.getTileCost()` checks terrain type and tree growth, but never checks `tile.building_id` or the building tile type (W/F/D). As a result, wall tiles (type W) are treated as passable at `BASE_MOVE_COST`. Units can path through and stand on building walls. This breaks containment for all constructed buildings.
- **Evidence:** `getTileCost()` handles `terrain == "water"` (impassable), `terrain == "rock"` (impassable), and tree growth ≥ 2 (multiplier). No code reads `tile.building_id` or looks up the building's tile map to check whether the tile is a W. Buildings currently placed in the world have their tile types stored on the building, but `getTileCost` never consults them.
- **Suggested action:** In `getTileCost`, if `tile.building_id ~= nil`, look up the building and its tile map position for `(x, y)`. Return `nil` (impassable) for W tiles. Return `BASE_MOVE_COST` for F and D tiles. This is the prerequisite for buildings being physically meaningful in the simulation.

---

**M04 status: 4 findings (1 critical passability bug, 1 moderate progress-bar nil yield, 1 moderate undocumented tile fields, 1 minor boundary note).**

---

## M05 — Camera, Renderer, Basic UI Shell

### Finding M05-01
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/ui/camera.lua` (pan input handling)
- **Spec reference:** UI.md § Camera ("WASD / arrow keys + mouse drag")
- **Finding:** Camera pan is implemented for arrow keys only. WASD panning is not implemented. The spec lists "WASD / arrow keys" as the pan mechanism.
- **Evidence:** `camera.lua` checks `Keybinds.pan_up` etc., which are bound to arrow keys. No WASD bindings exist in `keybinds.lua`. UI.md specifies both.
- **Suggested action:** Either add WASD bindings to `keybinds.lua` and `constants.lua`, or update UI.md to reflect that only arrow-key panning is implemented.

---

### Finding M05-02
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/ui/camera.lua` (drag input handling)
- **Spec reference:** UI.md § Camera ("mouse drag" — button not specified)
- **Finding:** Mouse-drag panning uses the middle mouse button (button 3). The spec says "mouse drag" without specifying which button. Right-click drag is conventional in many RTS games; middle-click is also common. The choice is not documented.
- **Evidence:** `camera.lua` checks `button == 3` for drag. Spec is silent on button.
- **Suggested action:** Update UI.md to specify middle-mouse-button drag, so the choice is captured in the spec.

---

### Finding M05-03
- **Category:** Architectural problem
- **Severity:** Minor
- **File:line:** `src/ui/renderer.lua:126–178` (`drawBuildings`)
- **Spec reference:** UI.md § Renderer (building rendering); WORLD.md § Building Layout (multiple building types with different tile maps)
- **Finding:** `renderer.drawBuildings()` only renders buildings of type `"stockpile"`. All other building types (houses, workshops, churches, etc.) are completely invisible. As more building types are added in later milestones, they will silently not render unless the renderer is extended.
- **Evidence:** `drawBuildings()` has an outer `if building.type == "stockpile" then` gate with no `else` branch for other types. The building data structures for non-stockpile types will exist in `world.buildings` but produce no visual output.
- **Suggested action:** Add a general building rendering path (at minimum, draw the building footprint as a colored rectangle) for building types other than stockpile. The stockpile tile-by-tile resource visualization can remain as the specialized path.

---

**M05 status: 3 findings (2 minor undocumented input decisions, 1 minor architectural gap in renderer).**

---

## M06 — Units, Movement, Spawn

### Finding M06-01
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/simulation/units.lua` (`Unit:recalcMoveSpeed`)
- **Spec reference:** BEHAVIOR.md § Carrying (carry weight / speed penalty formula); TABLES.md § Unit data structure (`move_speed` field)
- **Finding:** `Unit:recalcMoveSpeed()` is a dead stub that always sets `self.move_speed = 1.0` regardless of carried weight or strength. The actual carry-weight speed formula is implemented in a private function `recalcMoveSpeed()` inside `resources.lua`, which is called by carry/drop operations but is unreachable from the Unit prototype method. The Unit method is never updated after carry changes.
- **Evidence:** `units.lua` `Unit:recalcMoveSpeed` body: `self.move_speed = 1.0`. `resources.lua` contains a correctly implemented `recalcMoveSpeed(unit)` free function using `base_attributes + acquired_attributes` and the carry penalty formula. The resources module calls this directly; the unit method is orphaned.
- **Suggested action:** Either remove `Unit:recalcMoveSpeed` and have all callers use the resources module function, or make `Unit:recalcMoveSpeed` delegate to the resources module function. The dead stub creates confusion about where the formula lives.

---

### Finding M06-02
- **Category:** Correctness
- **Severity:** Minor
- **File:line:** `src/simulation/units.lua` (Unit prototype)
- **Spec reference:** TABLES.md § Unit data structure (`getAttribute(key)` method described)
- **Finding:** `Unit:getAttribute(key)` is not implemented on the Unit prototype. TABLES.md describes it as a method that sums `base_attributes[key]` and `acquired_attributes[key]`. All code that needs an attribute value accesses the sub-tables directly.
- **Evidence:** TABLES.md lists `getAttribute` as a unit method. No such method exists in `units.lua`. The `resources.lua` private `recalcMoveSpeed` accesses `unit.base_attributes.strength + unit.acquired_attributes.strength` directly rather than calling `unit:getAttribute("strength")`.
- **Suggested action:** Implement `Unit:getAttribute(key)` as specified in TABLES.md. Replace direct sub-table accesses with the method call to reduce coupling to the attribute storage layout.

---

### Finding M06-03
- **Category:** Correctness
- **Severity:** Minor
- **File:line:** `src/simulation/units.lua` (`spawnSerf`)
- **Spec reference:** CLAUDE.md § Dev Tools / Debug Spawn ("If the cursor tile is impassable (water, rock), the spawn is rejected (no fallback)")
- **Finding:** `spawnSerf` does not validate terrain impassability before spawning. A unit can be spawned on water or rock tiles if `target_of_unit == nil`, which is normally impossible through gameplay.
- **Evidence:** `spawnSerf` performs ring search for tiles where `target_of_unit == nil` but does not also check `world.getTileCost(tile) ~= nil` (the impassable sentinel). The spec explicitly states the spawn should be rejected on impassable terrain.
- **Suggested action:** Add a `world.getTileCost(tile) ~= nil` guard in `spawnSerf` before accepting a tile as a valid spawn location, matching the spec's rejection behavior.

---

**M06 status: 3 findings (1 moderate dead stub, 2 minor missing implementations).**

---

## M07 — UI: Selection, Panels, Overlays

### Finding M07-01
- **Category:** Undocumented forced decision
- **Severity:** Moderate
- **File:line:** `src/ui/hub.lua` (`hub.mousepressed` selection block)
- **Spec reference:** UI.md § Selection Mechanics ("click priority: unit > ground pile > building > map object")
- **Finding:** The selection priority order in `hub.mousepressed` is unit > building > ground_pile > tile. The spec specifies unit > ground pile > building > map object. Building and ground pile priority are swapped — a click on a tile with both a ground pile and a building will select the building rather than the ground pile.
- **Evidence:** `hub.lua` checks for unit first, then building, then ground_pile, then tile. UI.md § Selection Mechanics specifies ground pile before building.
- **Suggested action:** Reorder the selection checks in `hub.mousepressed` to match the spec: unit → ground pile → building → map object.

---

### Finding M07-02
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/ui/left_panel.lua` (unit display section)
- **Spec reference:** UI.md § Left Panel / M07 milestone (specifies `tableToString` generic dump for unit display at this milestone)
- **Finding:** The left panel unit display is a curated multi-section layout showing position, action, needs, vitals, carrying, work day, and housing in formatted sections. The M07 spec calls for a simpler `tableToString`-style generic dump. The elaborate layout is better UX but diverges from the milestone spec.
- **Evidence:** `left_panel.lua` has structured display sections. M07 spec (and UI.md early-milestone guidance) calls for `tableToString`. This is a "better than spec" deviation, but it is undocumented.
- **Suggested action:** Note in ROADMAP.md Implementation Notes that the left panel unit display was implemented as a curated layout rather than a generic dump, skipping the tableToString intermediate step.

---

### Finding M07-03
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/ui/hub.lua` (keypressed handler, 'b' key)
- **Spec reference:** TABLES.md § Keybinds (Keybinds table definition; no entry for building placement mode)
- **Finding:** The key `'b'` is hardcoded in `hub.lua` to enter stockpile placement mode. It is not routed through `Keybinds` and does not appear in the Keybinds config table, making it non-remappable and invisible to the keybind system.
- **Evidence:** `hub.lua` keypressed: `if key == "b" then`. `keybinds.lua` has no `place_stockpile` or similar entry. TABLES.md Keybinds table has no such entry.
- **Suggested action:** Add a `place_stockpile` entry to TABLES.md Keybinds and `keybinds.lua`, and route `hub.lua` through `Keybinds.place_stockpile`.

---

### Finding M07-04
- **Category:** Improvements
- **Severity:** Minor
- **File:line:** `src/ui/right_panel.lua` (`mousepressed`)
- **Spec reference:** UI.md § Right Panel (panel interaction)
- **Finding:** `right_panel.mousepressed` returns `true` for any click anywhere within the panel area, including clicks on regions that contain no interactive element. This means unhandled panel-area clicks are silently consumed and never reach the world, even though they landed on a non-interactive panel region.
- **Evidence:** `right_panel.mousepressed` function ends with `return true` after the panel bounds check, regardless of whether a button was actually hit. Spec does not specify this behavior explicitly, but consuming clicks on empty panel regions is a user-experience regression.
- **Suggested action:** Return `true` only when a button click was handled. Return `false` (or `nil`) for clicks that landed in the panel area but did not hit an interactive element, allowing them to fall through to world selection.

---

### Finding M07-05
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/ui/dev_overlay.lua` (tile inspector section)
- **Spec reference:** CLAUDE.md § Dev Tools / Developer Overlay ("Tile inspector on hover: coordinates, terrain, plant_type/plant_growth, forest_depth, building_id, ground resources, claimed_by, visibility")
- **Finding:** The tile inspector in the dev overlay does not display `claimed_by`. All other listed fields are present. `claimed_by` is a tile field (set when a unit has claimed the tile as their target) and is specifically listed in the spec as an inspector field.
- **Evidence:** CLAUDE.md lists `claimed_by` in the tile inspector field list. `dev_overlay.lua` tile inspector section does not render it.
- **Suggested action:** Add `claimed_by` (unit id or nil) to the dev overlay tile inspector display.

---

**M07 status: 5 findings (1 moderate priority inversion, 3 minor undocumented decisions, 1 minor improvement).**

---

## M08 — Activities, Hauling, Resources

### Finding M08-01
- **Category:** Correctness
- **Severity:** Minor
- **File:line:** `src/core/simulation.lua` (`onTick`)
- **Spec reference:** BEHAVIOR.md § Tick Order (`resources.validateCounts()` listed as the final step of `onTick`, after `units.sweepDead()` and `buildings.sweepDeleted()`)
- **Finding:** `simulation.onTick()` calls `resources.validateCounts()` before the sweep passes. BEHAVIOR.md specifies it runs at the end of the tick (after all sweeps), so the counts reflect the fully committed tick state. Called before sweeps, the counts may include entities that are about to be removed, producing false positives in the integrity check during the window when dead units still hold resources.
- **Evidence:** `simulation.lua` `onTick` call order: `time.advance()`, `units.tickAll()`, `units.update()`, `resources.validateCounts()`. Sweeps (`units.sweepDead`, `buildings.sweepDeleted`) are not yet called here (later milestones), but when they are added, `validateCounts` must follow them.
- **Suggested action:** Note the ordering constraint. When sweep calls are added in later milestones, ensure `resources.validateCounts()` is placed after both sweep calls. Consider adding a comment in `simulation.lua` marking where the sweep calls will go.

---

### Finding M08-02
- **Category:** Undocumented forced decision
- **Severity:** Moderate
- **File:line:** `src/simulation/activities.lua` (activity handler functions)
- **Spec reference:** TABLES.md § Activity data structure (lists all activity fields; `phase` is absent)
- **Finding:** Activity handlers add a `phase` field to activities at runtime to track progress within a multi-step work cycle (e.g., `"move_to"`, `"chopping"`, `"returning"`). This field is not in TABLES.md's activity data structure definition, making it invisible to serialization and any code that generically iterates activity fields.
- **Evidence:** TABLES.md activity structure does not include `phase`. Activity handlers in `activities.lua` set `activity.phase = "..."` at runtime. Serialization would need to preserve this field for save/load to work correctly once save is implemented.
- **Suggested action:** Add `phase` (string or nil) to the activity data structure in TABLES.md. Document the valid phase values per activity type, or note that phases are activity-type-specific.

---

### Finding M08-03
- **Category:** Architectural problem
- **Severity:** Minor
- **File:line:** `src/simulation/resources.lua` (`deposit` function, tile_inventory branch)
- **Spec reference:** ECONOMY.md § Resources Module API (`deposit` function contract); ECONOMY.md § Reservation System
- **Finding:** `resources.deposit()` for tile_inventory asserts `deposited_amount <= (container.reserved_in[entity.type] or 0)`. This makes unreserved deposits a hard error, but the F2 debug-deposit path in `playing.lua` calls `resources.deposit()` directly without a prior reservation. The debug key would crash the game. Similarly, any code path that needs to deposit without first reserving (e.g., initial world setup) cannot use the public API.
- **Evidence:** `resources.lua` deposit function has the assertion. `playing.lua` F2 handler calls `resources.create(...)` then `resources.deposit(...)` without an intermediate `resources.reserve(...)`. The debug path would trigger the assertion on the first F2 press.
- **Suggested action:** Either fix the F2 debug path to go through the reservation system, or add a `bypass_reservation` parameter to `deposit()` for trusted internal callers. The reservation assertion is correct for normal gameplay and should be preserved; the debug path should be fixed.

---

### Finding M08-04
- **Category:** Architectural problem
- **Severity:** Minor
- **File:line:** `src/simulation/resources.lua` (`withdraw` function, tile_inventory branch)
- **Spec reference:** ECONOMY.md § Resources Module API (`withdraw` function contract); ECONOMY.md § Reservation System
- **Finding:** `resources.withdraw()` for tile_inventory asserts `reserved_out >= amount`. This makes unreserved withdrawals a hard error. Like M08-03, any code path that needs to withdraw without a prior reservation (tests, debug tools, direct scripting) cannot use the public withdraw API and will crash.
- **Evidence:** `resources.lua` withdraw function has the assertion. `tests/test_resources.lua` `makeStockpile` does not set up reservations (see M02-07), so `test_partialWithdraw` would hit this assertion.
- **Suggested action:** Same approach as M08-03: fix test helpers to go through reservations, or add a bypass for trusted callers. The constraint is correct for production; the test infrastructure needs to match.

---

### Finding M08-05
- **Category:** Spec ambiguity
- **Severity:** Minor
- **File:line:** `src/simulation/resources.lua` (tile_inventory reservation fields); `src/simulation/buildings.lua` (`placeStockpile`)
- **Spec reference:** ECONOMY.md § Tile Inventory (reservation fields described at the per-tile-entry level: `tile_entry.reserved_in`, `tile_entry.reserved_out`)
- **Finding:** ECONOMY.md describes `reserved_in` and `reserved_out` as fields on each tile entry within the tile inventory. The implementation places these at the container level as type-keyed tables (`container.reserved_in[type]`). The per-tile-entry `reserved_in`/`reserved_out` fields are initialized by `placeStockpile` but are never read by the resources module.
- **Evidence:** ECONOMY.md tile inventory spec shows per-tile-entry reservation. `resources.lua` reads `container.reserved_in[entity.type]` (container-level). `buildings.lua` `placeStockpile` initializes both per-tile-entry reservation fields (which go unused) and container-level fields (which are used). The spec and implementation disagree on reservation granularity.
- **Suggested action:** Align the spec and implementation. If container-level type-keyed reservations are the chosen approach (simpler, sufficient for multi-tile stockpiles), update ECONOMY.md to describe this shape. If per-tile reservations are needed for correctness (e.g., preventing overfill of a specific tile), implement them. Document the decision in ROADMAP.md Implementation Notes.

---

**M08 status: 5 findings (1 moderate undocumented activity field, 2 minor architectural reservation contract issues, 1 minor tick ordering constraint, 1 minor spec/impl reservation granularity mismatch).**

---

## Cross-Milestone Notes (M01–M08)

**Finding M04-04 / getTileCost building passability** is the most structurally impactful open issue. It affects A* correctness for any map with buildings, and becomes critical once houses, workshops, and other enclosed buildings are placed. All pathfinding that routes through or around buildings will be incorrect until wall tiles return `nil` from `getTileCost`.

**Finding M02-01 / BASE_MOVE_COST** is the highest-severity single-value discrepancy. The value 40 vs 6 changes every movement duration in the game. If 40 is the intentional tuned value, the spec needs updating in two places (CLAUDE.md and WORLD.md). If 6 is correct, the constant needs fixing. Either way, both spec and code should agree.

**Findings M08-03 and M08-04** (deposit/withdraw reservation assertions) have a direct impact on testing and debug tooling. They should be resolved before any significant test expansion.

---

## M09 — Unit Movement

### Finding M09-01
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/simulation/units.lua:311` (`units.startMoveAdjacentToRect`)
- **Spec reference:** WORLD.md § Pathfinding — Movement Model (adjacent-to-rect mode: "Release old target tile, run A* to nearest tile adjacent to the rect"); BEHAVIOR.md § Carrying (bidirectional `unit.target_tile` ↔ `tile.target_of_unit`)
- **Finding:** When `#path.tiles == 0` (the unit is already adjacent to the target rect and the A* returns an empty path), `units.startMoveAdjacentToRect()` does not release `unit.target_tile` before returning. The old target tile's `target_of_unit` reference is never cleared, and no new tile is claimed for the unit's new position. This leaves a stale `target_of_unit` on the old tile, which will block other units from claiming it.
- **Evidence:** The `if #path.tiles == 0 then return end` early-exit in the adjacent-to-rect path runs before the block that calls `world.tiles[unit.target_tile].target_of_unit = nil`. The destination mode's analogous early-exit is preceded by the tile-release block; the adjacent-to-rect mode is not.
- **Suggested action:** Before the early-exit `return`, release the old target tile: `world.tiles[unit.target_tile].target_of_unit = nil; unit.target_tile = nil` — matching the release pattern used in the destination mode.

---

### Finding M09-02
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/simulation/units.lua` (`Unit:tick`)
- **Spec reference:** BEHAVIOR.md § Tick Order (per-tick unit loop includes `travel` and `work` action handlers; sleep behavior described at M18)
- **Finding:** `Unit:tick()` handles `travel` and `work` action types but has no branch and no stub comment for `sleep`. Sleep behavior is deferred to M18, but the per-tick action dispatch makes the omission look like a gap rather than a deliberate deferral. Future implementors may not realize the tick loop must be extended when sleep is added.
- **Evidence:** `Unit:tick()` action dispatch ends after `work`. No `elseif action == "sleep"` branch or comment. The sleep section of BEHAVIOR.md specifies per-tick `sleepStep()` behavior.
- **Suggested action:** Add a stub `elseif self.action == "sleep" then -- TODO M18: sleepStep` to the tick dispatch so the extension point is visible.

---

**M09 status: 2 findings (1 moderate target-tile release bug, 1 minor missing stub).**

---

## M10 — Dev Overlay

### Finding M10-01
- **Category:** Correctness
- **Severity:** Minor
- **File:line:** `src/ui/dev_overlay.lua:42` (stats bar render)
- **Spec reference:** CLAUDE.md § Dev Tools / Developer Overlay ("Stats bar: FPS, game_time, speed, TPS")
- **Finding:** The stats bar renders FPS, TPS, Speed, and entity counts but does not render `game_time` (day/season/year). CLAUDE.md explicitly lists it as a stats bar field. The current date/time is available on `world.time` and is already displayed in the right panel, so this is purely a missing render call in the overlay.
- **Evidence:** `dev_overlay.lua` stats bar line does not include any day/season/year output. CLAUDE.md stats bar spec lists `game_time` between FPS and speed.
- **Suggested action:** Add a game time display to the dev overlay stats bar (e.g., `"Day %d %s Y%d" % [day, season, year]`), consistent with the right panel's time display.

---

**M10 status: 1 finding (1 minor missing stats bar field).**

---

## M11 — Simulation Loop

### Finding M11-01
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/core/simulation.lua:11` (`simulation.onTick`)
- **Spec reference:** BEHAVIOR.md § Tick Order (authoritative tick sequence: `time.advance`, `units.tickAll`, `units.update`, `world.updateBuildings`, `world.updatePlants`, `units.sweepDead`, `buildings.sweepDeleted`, `resources.validateCounts`)
- **Finding:** `simulation.onTick()` omits `world.updateBuildings()` and `world.updatePlants()` entirely, and omits both sweep calls (`units.sweepDead`, `buildings.sweepDeleted`). These are not stubbed with comments — their absence makes the current tick loop look complete when it is not. When M20 (building updates) and M25 (plant growth) are implemented, the missing calls must be added; without a placeholder comment there is no signal to the implementor that the tick loop must be extended.
- **Evidence:** `simulation.lua` `onTick`: `time.advance()`, `units.tickAll()`, `units.update()`, `resources.validateCounts()`. Four calls specified in the tick order are missing. BEHAVIOR.md §Tick Order lists all eight steps.
- **Suggested action:** Add commented-out stubs in `onTick` at the correct positions for the four missing calls, matching the BEHAVIOR.md tick order. This makes the incomplete state explicit and preserves ordering intent for future implementors.

---

**M11 status: 1 finding (1 moderate incomplete tick loop with no placeholder comments).**

---

## M12 — Stockpile Placement

### Finding M12-01
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/simulation/buildings.lua:11` (`buildings.isValidTile`)
- **Spec reference:** WORLD.md § Placement Validation ("All building tiles must be on pathable terrain (grass or dirt)")
- **Finding:** `buildings.isValidTile()` accepts only `terrain == "grass"`, rejecting `"dirt"` tiles silently. WORLD.md specifies that both grass and dirt are valid placement terrains. Any map area with dirt tiles cannot have buildings placed on it, which excludes portions of the settlement zone that should be valid build sites.
- **Evidence:** `buildings.isValidTile` body: `if tile.terrain ~= "grass" then return false end`. No dirt branch. WORLD.md Placement Validation explicitly lists dirt as pathable and valid for placement.
- **Suggested action:** Change the terrain check to `if tile.terrain ~= "grass" and tile.terrain ~= "dirt" then return false end`.

---

### Finding M12-02
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/ui/hub.lua:211` (`hub.mousereleased`, placing branch)
- **Spec reference:** UI.md § Placement Modes (building placement should place the building type stored in `mode_state.building_type`)
- **Finding:** The placement confirmation path in `hub.mousereleased()` always calls `buildings.placeStockpile()` regardless of `hub.mode_state.building_type`. Any future building type entered via placing mode (workshop, house, etc.) will silently place a stockpile instead. The building type selector is set but never consulted at placement time.
- **Evidence:** `hub.mousereleased` placing branch: `buildings.placeStockpile(...)` — no dispatch on `mode_state.building_type`. Only one building type exists at M12, so no runtime error yet, but the architecture is incorrect for a multi-building system.
- **Suggested action:** Replace the hardcoded `buildings.placeStockpile()` call with a dispatch on `mode_state.building_type` (e.g., a table of `{ stockpile = buildings.placeStockpile, ... }` or a `buildings.place(type, ...)` dispatcher). This should be fixed before any second building type is added.

---

### Finding M12-03
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/simulation/buildings.lua:69` (`buildings.placeStockpile`)
- **Spec reference:** TABLES.md § Building data structure (common fields list includes `worker_limit`)
- **Finding:** The stockpile entity created by `buildings.placeStockpile()` does not include a `worker_limit` field. TABLES.md lists `worker_limit` as a field on all non-housing buildings. Stockpiles do not need workers, but the field is part of the canonical building structure and its absence creates an inconsistency when code iterates buildings generically.
- **Evidence:** `buildings.placeStockpile` entity construction does not include `worker_limit`. TABLES.md building structure lists it as a common field.
- **Suggested action:** Add `worker_limit = 0` to the stockpile entity in `placeStockpile()`, matching the common building structure. A value of 0 correctly represents "no workers needed" without changing behavior.

---

**M12 status: 3 findings (2 moderate correctness bugs, 1 minor missing field).**

---

## M13 — Resources and Stockpile Storage

### Finding M13-01
- **Category:** Correctness
- **Severity:** Minor
- **File:line:** `src/simulation/resources.lua:170` (`resources.getAvailableStock`, bin branch)
- **Spec reference:** ECONOMY.md § Reservation System (reservation fields are type-keyed tables on all container types)
- **Finding:** `resources.getAvailableStock()` for bins reads `container.reserved_out` as a scalar (subtracting it directly from stock). Every other container branch (tile_inventory, stack_inventory, item_inventory, ground_pile) reads `container.reserved_out[entity_type]` as a type-keyed table. Bins are single-type containers so the net result is functionally equivalent, but the structural inconsistency means the bin branch will break if the reservation shape is ever unified across container types.
- **Evidence:** Bin branch: `local available = stock - (container.reserved_out or 0)`. Tile inventory branch: `local available = stock - (container.reserved_out[entity_type] or 0)`. The scalar form does not match the canonical table-keyed pattern used everywhere else.
- **Suggested action:** Normalize the bin reservation shape to `container.reserved_out = {}` (type-keyed table, matching all other containers), and update the bin branch to read `container.reserved_out[entity_type] or 0`. This eliminates the structural divergence.

---

**M13 status: 1 finding (1 minor reservation shape inconsistency on bins).**

---

## M14 — Activity System

### Finding M14-01
- **Category:** Undocumented forced decision
- **Severity:** Moderate
- **File:line:** `src/simulation/activities.lua:19` (`activities.postActivity`)
- **Spec reference:** TABLES.md § Activity data structure (`is_private = false` listed as an activity field)
- **Finding:** `activities.postActivity()` never sets `is_private` on the created activity. TABLES.md defines `is_private = false` as a field that should be present on all activities. Private activities (offload hauls, ground-pile haul activities) are created via `postActivity` and immediately claimed, which enforces exclusion in practice — but the field is absent, making it non-serializable and invisible to any code that reads `activity.is_private`.
- **Evidence:** `activities.postActivity` entity construction has no `is_private` field. TABLES.md activity structure explicitly lists `is_private = false` as a default field.
- **Suggested action:** Add `is_private = fields.is_private or false` to the activity entity in `postActivity()`. Where a private activity is intended (offload haul, ground pile haul), pass `is_private = true` in the `fields` argument.

---

### Finding M14-02
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/simulation/activities.lua:334` (woodcutter handler), `src/simulation/activities.lua:464` (gatherer handler)
- **Spec reference:** TABLES.md § Activity data structure (complete field list; `storage_id` absent)
- **Finding:** The woodcutter and gatherer handlers add `activity.storage_id` to activities at runtime. This field is not in TABLES.md's activity data structure (beyond the already-documented `phase` field from M08-02). `storage_id` holds the id of the stockpile the unit will deposit into, and it must survive serialization for save/load to correctly resume in-progress work cycles.
- **Evidence:** `ActivityHandlers["woodcutter"]` and `ActivityHandlers["gatherer"]` both set `activity.storage_id = ...`. TABLES.md activity structure does not list this field.
- **Suggested action:** Add `storage_id` (building id or nil) to the activity data structure in TABLES.md, alongside the existing `phase` field. Document that it is set at runtime by work-cycle handlers when a deposit target is identified.

---

### Finding M14-03
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/simulation/activities.lua:32` (`activities.postActivity`)
- **Spec reference:** TABLES.md § Activity data structure (complete field list; `reserved_amount` absent)
- **Finding:** `activities.postActivity()` stores `reserved_amount` as a field on the activity entity (sourced from the `fields` parameter). This field is not in TABLES.md's activity data structure. It is used to track how much resource the activity has reserved in a container, and must be preserved across serialization for save/load to correctly release reservations on resume.
- **Evidence:** `activities.postActivity` copies `fields.reserved_amount` onto the entity. TABLES.md does not list `reserved_amount` as an activity field.
- **Suggested action:** Add `reserved_amount` (number or nil) to the activity data structure in TABLES.md with a note that it is populated by handlers that interact with the reservation system.

---

**M14 status: 3 findings (1 moderate missing is_private field, 2 minor undocumented runtime fields).**

---

## M15 — Chop Designation and Tree Felling

**M15 status: 0 findings. Implemented without issue.**

The woodcutter handler phases (nil → travel_tree → work → travel_deposit) match the spec steps. Chain carry accumulation, nearest-designation selection by distance, and the ground-pile drop via haul activity are all correct. No deviations found.

---

## M16 — Hauling and Ground Piles

### Finding M16-01
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/simulation/resources.lua:589` (`resources.createGroundPile`)
- **Spec reference:** ECONOMY.md § Resources Module API (lists public functions; `createGroundPile` absent); ECONOMY.md § Ground Piles (ground pile creation described as internal to the drop function)
- **Finding:** `resources.createGroundPile()` is an exposed public function on the resources module. ECONOMY.md describes ground pile creation as an internal implementation detail of the drop function and does not list `createGroundPile` in the public API. Activity handlers call it directly, which couples them to the internal creation path and bypasses any future drop-search logic that may gate ground pile creation.
- **Evidence:** `resources.createGroundPile` is a module-level function callable by any requiring code. ECONOMY.md Resources Module API section does not list it. Activity handlers call it directly when placing dropped resources.
- **Suggested action:** Either add `createGroundPile` to the ECONOMY.md public API with its contract documented, or internalize it and route activity handlers through the existing `resources.dropAt()` or `resources.drop()` function (which performs the drop-search and creates the pile internally). The second option is architecturally cleaner.

---

**M16 status: 1 finding (1 minor undocumented public function).**

---

## M17 — Gather Designation and Berry Harvesting

### Finding M17-01
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/simulation/activities.lua:436` (gatherer handler, `phase == "work"`)
- **Spec reference:** WORLD.md § Plant System ("Growth stages 1–2: `world.growing_plant_data[tileIndex] = planted_tick`. Cursor scan promotes plant from stage to stage when the tick delta exceeds GrowthConfig threshold."); WORLD.md § Plant System ("On harvest: plant regrows to stage 1")
- **Finding:** The gatherer handler resets `tile.plant_growth = 1` on berry bush harvest but does not write `world.growing_plant_data[tile_idx] = world.time.tick`. Without this entry, the cursor scan (implemented in M25) has no planted_tick to measure against and will never promote the regrown bush from stage 1 to stage 2. Berry bushes harvested once will remain permanently at stage 1 — never reaching maturity — breaking the regrowth cycle permanently once M25 is implemented.
- **Evidence:** `gatherer` handler `phase == "work"` block: sets `tile.plant_growth = 1`, does not write to `world.growing_plant_data`. WORLD.md plant system specifies that `growing_plant_data[tileIndex] = planted_tick` must be set for growth stages 1 and 2 so the cursor scan can track and advance them.
- **Suggested action:** Add `world.growing_plant_data[tile_idx] = world.time.tick` immediately after `tile.plant_growth = 1` in the gatherer work phase handler. This registers the bush with the growth tracker and enables normal regrowth once M25 is implemented.

---

**M17 status: 1 finding (1 moderate regrowth data not written on harvest).**

---

## Cross-Milestone Notes (M09–M17)

**Finding M17-01 / berry bush regrowth** is a silent time-bomb: the bug has no observable effect until M25 (plant growth cursor scan) is implemented, at which point all previously-harvested berry bushes will be permanently stuck at stage 1. The fix is a one-line addition in the gatherer handler and should be applied before M25 lands.

**Finding M12-02 / hardcoded placeStockpile dispatch** will silently misbehave as soon as a second building type is added. The placement path must be generalized before any new building type reaches the placing mode.

**Finding M11-01 / incomplete tick loop** creates a documentation debt: the `onTick` function looks complete but is missing four of its eight specified steps. Stub comments should be added to make the incomplete state explicit and preserve ordering intent for M20 and M25.

**Finding M09-01 / target tile release in adjacent-to-rect** is a latent corruption: the stale `target_of_unit` on the old tile will silently block other units from claiming that tile after the first unit arrives adjacent to a building. This becomes observable as unit population grows.

---

## Cross-cutting

*Scope: full codebase, all source and test files. Patterns that only emerge from looking across modules together.*
*These findings are not tied to a single milestone.*

---

### Finding CC-01
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/core/world.lua:21` (`initState`)
- **Spec reference:** CLAUDE.md § Architecture ("Teardown clears world and registry"); CLAUDE.md § Serialization ("Rebuilt on load: registry hash table (from all world.* entity arrays)")
- **Finding:** `initState()` reinitializes all `world.*` arrays to empty but never clears `registry[id]` entries from the previous game or resets `registry.next_id`. When a player quits to main menu and starts a new game — a valid flow supported by the current state machine — entities from the previous game remain in `registry` as orphaned lookups indefinitely. New entities receive new IDs (so there's no collision), but the old entries are a memory leak and a correctness hazard: code that does `registry[id]` with a stale ID from the previous session (e.g., `hub.selected.id` — see CC-02) finds a real entity from a dead world rather than `nil`.
- **Evidence:** `initState` sets `world.units = {}`, `world.buildings = {}`, etc., but has no loop over `registry` to clear old entries. `registry.next_id` is never reset. The escape-to-menu path in `playing.keypressed` calls `gamestate:switch(main_menu)` directly, then "New Game" triggers `generating` which calls `world.newGenCoroutine()` → `initState()`. Old registry entries survive this transition.
- **Suggested action:** Add explicit registry teardown to `initState()`: iterate all `world.*` entity arrays (before clearing them) and call `registry[entity.id] = nil` for each entity, then reset `registry.next_id = 0`. Alternatively, clear `registry` by replacing it with a fresh table and resetting the counter. CLAUDE.md's teardown description should also be updated to clarify that `initState` is the canonical teardown location.

---

### Finding CC-02
- **Category:** Correctness
- **Severity:** Moderate
- **File:line:** `src/ui/hub.lua:15–33` (module-level state), `src/app/playing.lua:20–25` (`playing.enter`)
- **Spec reference:** CLAUDE.md § Game State Machine (`playing.enter()` initializes the game); UI.md § UI Architecture (interaction mode state)
- **Finding:** `hub.lua` initializes its module-level state (`hub.selected`, `hub.selected_type`, `hub.selected_tile_idx`, `hub.mode`, `hub.mode_state`, `hub.is_dragging`) at require time. `playing.enter()` never calls a reset on the hub. On a second playthrough (quit-to-menu then new game), `hub.selected` may point to an entity from the previous game's registry — one that was not cleaned up (see CC-01) and may no longer be semantically valid. More concretely: if the player was mid-placement (`hub.mode == "placing"`) when they quit, the new game starts in placing mode, which will confuse the first click.
- **Evidence:** `playing.enter()` calls `time.init()`, `camera.init()`, `units.spawnStarting()`, `resources.rebuildCounts()`. There is no `hub.init()` or equivalent. `hub.mode = "normal"` and `hub.selected = nil` are set once at module load time and never reset.
- **Suggested action:** Add a `hub.init()` function that resets all module-level state to its default values, and call it from `playing.enter()` alongside `time.init()` and `camera.init()`. This mirrors the pattern already used by the camera module.

---

### Finding CC-03
- **Category:** Architectural problem
- **Severity:** Moderate
- **File:line:** `src/simulation/units.lua` (whole file), `src/simulation/buildings.lua` (whole file), `src/core/simulation.lua:11`
- **Spec reference:** CLAUDE.md § Sweep Convention ("Units have `units.sweepDead`. Buildings have `buildings.sweepDeleted`… each sweep function handles its own cleanup before removal"); BEHAVIOR.md § Tick Order (step 5: `units.sweepDead`, step 6: `buildings.sweepDeleted`)
- **Finding:** Neither `units.sweepDead` nor `buildings.sweepDeleted` exists anywhere in the codebase. The spec defines both functions in detail — including inbound-ref clearing, registry nil-out, and swap-and-pop — and lists them as mandatory tick-order steps. The per-milestone finding M11-01 noted the missing *call sites* in `simulation.onTick`; this finding notes that the *functions themselves* are absent. When unit death or building deletion becomes active (M18+ for unit death; M27+ for building deletion), both sweep functions must be written from scratch with the full cleanup contracts specified in BEHAVIOR.md. Without stubs, there is no signal to implementors that these are deferred, not just omitted.
- **Evidence:** Searching `units.lua` for `sweepDead` and `buildings.lua` for `sweepDeleted` finds nothing. The `is_dead` and `is_deleted` flags exist on entities but are never acted upon by a sweep pass.
- **Suggested action:** Add stub functions `units.sweepDead()` and `buildings.sweepDeleted()` with TODO comments citing BEHAVIOR.md. Add commented-out call sites in `simulation.onTick` at the correct positions in the tick order (after `units.update()` and before `resources.validateCounts()`, matching BEHAVIOR.md). This is low-effort and prevents the functions from being forgotten or placed in the wrong order.

---

### Finding CC-04
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/core/log.lua:34–54` (`log:init`), `src/core/log.lua:92–95` (`writeEntry`)
- **Spec reference:** CLAUDE.md § Dev Tools / Log System ("File output writes to `logs/` in the repo root using Lua's `io.open` — not `love.filesystem`, which writes to the save directory")
- **Finding:** The log system uses `love.filesystem` throughout — `createDirectory`, `getDirectoryItems`, `remove`, `write`, and `append` — rather than `io.open` as the spec requires. `love.filesystem` writes to the OS Love2D save directory (e.g., `%APPDATA%/LOVE/sovereign/logs/` on Windows), not to the repo-root `logs/` directory. The `.gitignore` entry for `logs/` and the session-management logic (pruning to 20 files) both apply to the wrong location.
- **Evidence:** `log.lua` has no `io.open` call. All file I/O goes through `love.filesystem.*`. The published `log.filepath` is `love.filesystem.getSaveDirectory() .. "/" .. current_filename`, confirming the save-directory path. CLAUDE.md explicitly prohibits `love.filesystem` for log output.
- **Suggested action:** Replace `love.filesystem.createDirectory/write/append/remove/getDirectoryItems` with `io.open` calls targeting the repo-root `logs/` directory (using a relative path from the working directory where `love src` is launched). This matches the spec and puts log files where the `.gitignore` entry expects them.

---

### Finding CC-05
- **Category:** Architectural problem
- **Severity:** Minor
- **File:line:** `src/core/util.lua:17` (`table.deepCopy`)
- **Spec reference:** CLAUDE.md § Architecture (module pattern; no guidance on standard-library extension)
- **Finding:** `core/util.lua` adds `table.deepCopy` directly to Lua's built-in `table` library (`function table.deepCopy(t) ...`). This monkey-patches the global standard-library table, making `table.deepCopy` visible everywhere in the codebase as if it were a native Lua function. The function is called only by `resources.validateCounts()` (once per validation pass). Extending the standard library is a code smell: it creates a name-collision risk with any future Lua version or library that adds its own `table.deepCopy`, and it makes the dependency invisible at the call site.
- **Evidence:** `util.lua` contains `function table.deepCopy(t)`. Called as `table.deepCopy(world.resource_counts)` in `resources.lua:817`.
- **Suggested action:** Move `deepCopy` out of the `table` namespace and expose it as a plain global function (`deepCopy`) or as a field on a `util` module that callers require explicitly. The function is used in exactly one place, so the change is trivial.

---

### Finding CC-06
- **Category:** Improvements
- **Severity:** Minor
- **File:line:** `src/simulation/resources.lua:305–401` (`resources.withdraw`, tile_inventory and bin/stack/ground_pile branches)
- **Spec reference:** CLAUDE.md § Sweep Convention ("inline removals… swap-and-pop on the world.* array"); CLAUDE.md § Lua Performance ("Prefer numeric for loops over ipairs/pairs in hot paths")
- **Finding:** `resources.withdraw` removes entities from `tile_entry.contents` and `container.contents` arrays using `table.remove(array, i)`, which shifts all subsequent elements left — O(n) per removal. The convention requires swap-and-pop (O(1)) for array removals. Both the tile_inventory branch (iterating over `tile_entry.contents`) and the combined bin/stack/ground_pile branch (iterating over `container.contents`) use `table.remove`. Element order within a container's `contents` array has no semantic meaning — same-type-last and same-type-first are equivalent — so swap-and-pop is safe here.
- **Evidence:** `resources.lua:326` — `table.remove(tile_entry.contents, i)`. `resources.lua:352` — `table.remove(container.contents, i)`. `resources.lua:363` — `table.remove(container.contents, i)`. `resources.lua:378` — `table.remove(container.contents, i)`. Multiple locations in the same function, all O(n).
- **Suggested action:** Replace each `table.remove(array, i)` with the swap-and-pop idiom: `array[i] = array[#array]; array[#array] = nil`. Since the loops already iterate in reverse (`for i = #container.contents, 1, -1 do`), swap-and-pop is safe without invalidating the current index.

---

### Finding CC-07
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/simulation/activities.lua:334` (woodcutter, `storage_id`), `src/simulation/activities.lua:577` (haul, `destination_id`)
- **Spec reference:** TABLES.md § Activity data structure; ECONOMY.md § Resources Module API
- **Finding:** Two different field names are used for the same concept — the id of the storage building a unit is traveling to deposit into. Work-cycle activities (woodcutter, gatherer) use `activity.storage_id`. Haul activities use `activity.destination_id`. Both hold a building id, both are set at runtime by their respective handlers, and both are nil-checked when the handler's travel_deposit phase begins. The split naming creates a parallel-path smell: any code that generically handles "what building is this activity targeting for deposit?" must know both names.
- **Evidence:** Woodcutter handler `phase == "work"` block: `activity.storage_id = storage.id` (line 335); travel_deposit block: `local storage = registry[activity.storage_id]` (line 360). Haul handler: `activity.destination_id = dest.id` (line 577); travel_deposit block: `local dest = registry[activity.destination_id]` (line 646).
- **Suggested action:** Standardize on `destination_id` (the name already used in `postActivity`'s `fields` parameter) for all activity types. Rename `storage_id` to `destination_id` in the woodcutter and gatherer handlers. Add `destination_id` (and its already-flagged sibling `storage_id`) to the activity data structure in TABLES.md.

---

### Finding CC-08
- **Category:** Undocumented forced decision
- **Severity:** Minor
- **File:line:** `src/simulation/units.lua:59` (`spawnSerf`, `secondary_haul_activity_id`), `src/ui/left_panel.lua:145–152`
- **Spec reference:** TABLES.md § Unit data structure (complete field list; `secondary_haul_activity_id` absent)
- **Finding:** Every unit is spawned with `secondary_haul_activity_id = nil`. The left panel checks for it and renders a "haul" line if non-nil. No code in any activity handler or unit lifecycle function ever sets `secondary_haul_activity_id` to a non-nil value. The field is a dead stub — defined on every unit, displayed in the UI, but never written. It is not in TABLES.md's unit data structure.
- **Evidence:** `spawnSerf` unit template: `secondary_haul_activity_id = nil`. `left_panel.lua:145`: `if unit.secondary_haul_activity_id ~= nil then`. Searching the codebase finds no assignment other than the initial `nil`.
- **Suggested action:** Either add `secondary_haul_activity_id` to TABLES.md with a note describing its intended role (concurrent tracking of a private haul alongside a primary work activity), or remove it from the spawn template and left panel display until the feature is designed and implemented. A dead field with display logic creates false expectations when reading the left panel.

---

### Finding CC-09
- **Category:** Improvements
- **Severity:** Minor
- **File:line:** `src/simulation/units.lua:253` (`Unit:hashedUpdate`), `src/ui/left_panel.lua:166`
- **Spec reference:** CLAUDE.md § Conventions ("Use `== false` instead of `not` — the keyword `not` is easy to miss when reading code, and `== false` makes boolean checks visually explicit")
- **Finding:** Two boolean fields are tested with bare truthiness instead of the mandated explicit comparison. `Unit:hashedUpdate` checks `if self.is_drafted then return end` — should be `if self.is_drafted == true then`. `left_panel.lua` checks `if unit.soft_interrupt_pending then` — should be `if unit.soft_interrupt_pending == true then`. Both `is_drafted` and `soft_interrupt_pending` are initialized to `false` in `spawnSerf` and are explicitly boolean fields (prefixed per convention: `is_` for states). A related violation: `pathfinding.lua` uses `if not closed[cur_idx]` (lines 116, 128) for a table-presence check rather than `if closed[cur_idx] == nil`. The pathfinding case is in the hottest path in the codebase.
- **Evidence:** `units.lua:253` — `if self.is_drafted then`. `left_panel.lua:166` — `if unit.soft_interrupt_pending then`. `pathfinding.lua:116` — `if not closed[cur_idx] then`. `pathfinding.lua:128` — `if not closed[n_idx] then`.
- **Suggested action:** Change each of the four occurrences to the explicit form: `self.is_drafted == true`, `unit.soft_interrupt_pending == true`, `closed[cur_idx] == nil`, `closed[n_idx] == nil`.

---

### Finding CC-10
- **Category:** Improvements
- **Severity:** Minor
- **File:line:** `src/core/log.lua:56–59`
- **Spec reference:** CLAUDE.md § Conventions / Formatting ("Always use full indented block style. No single-line if/then/end, for/do/end, or function bodies — put the body on a new indented line")
- **Finding:** The four log-level dispatch functions each use a single-line function body, which CLAUDE.md explicitly forbids:
  ```lua
  function log:error(category, fmt, ...) logAt(LEVEL_ERROR, category, fmt, ...) end
  function log:warn(category, fmt, ...)  logAt(LEVEL_WARN,  category, fmt, ...) end
  function log:info(category, fmt, ...)  logAt(LEVEL_INFO,  category, fmt, ...) end
  function log:debug(category, fmt, ...) logAt(LEVEL_DEBUG, category, fmt, ...) end
  ```
- **Evidence:** `log.lua` lines 56–59. Convention requires the body on a new indented line.
- **Suggested action:** Expand each to the full block form:
  ```lua
  function log:info(category, fmt, ...)
      logAt(LEVEL_INFO, category, fmt, ...)
  end
  ```

---

## Cross-cutting Notes

**Finding CC-01 / registry not cleared** is the most structurally risky finding in this pass. It means the quit-to-menu → new-game flow currently leaks the entire previous game's entity graph into the registry and would cause stale lookups on a second playthrough. It should be fixed before multiple-session play is exercised (save/load development would expose it).

**Finding CC-03 / missing sweep stubs** is the most likely to create future ordering bugs. The tick order in BEHAVIOR.md has eight steps; only four are in `onTick` and two of the missing ones (`sweepDead`, `sweepDeleted`) have specific sequencing requirements relative to `validateCounts`. Adding empty stubs now preserves the spec's ordering intent and prevents the functions from being accidentally placed out of order when they're implemented.

**Finding CC-07 / destination_id vs storage_id** should be resolved before any additional work-cycle activity type is added, since every new handler would have to choose one naming convention or the other.

**Finding CC-04 / love.filesystem vs io.open** means log files are silently going to the OS save directory rather than the repo-root `logs/` that is gitignored and where developer tooling would expect them. This is observable (the `logs/` directory in the repo stays empty during development).
