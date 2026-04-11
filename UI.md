# Sovereign — UI.md
*v1 · Player interface: camera, input, layout, selection, panels, overlays, notifications, interaction flows.*

## Camera

Top-down orthographic. Fixed orientation — no rotation.

Zoom range: `ZOOM_MIN` (0.5) to `ZOOM_MAX` (2.0). Pan via edge scroll or keyboard. Tile-to-screen conversion is a direct scale — no isometric projection math.

## Input

Left-click selects. Right-click cancels modes and clears selection. Escape closes panels and clears selection.

HOTKEYS

| Key | Action |
|---|---|
| Space | Toggle pause/unpause (returns to previous speed) |
| 1–4 | Set speed level (1 = slowest, 4 = fastest) |
| Q | Place: Stockpile |
| W | Place: Cottage |
| E | Place: Woodcutter's Camp |
| R | Place: Gatherer's Hut |
| T | Place: Fishing Dock |
| A | Designate: Chop |
| S | Designate: Gather |
| X | Cancel Designation |
| Tab | Rotate building (in placement mode) |
| Del | Delete selected building |

Building and designation hotkeys expand as new buildings and designation types come online in later phases.

## Layout

Three persistent regions:

**Right panel** — always visible, read-only. Settlement-level information: time display, speed controls, population summary, resource overview, notification feed. This is the player's at-a-glance settlement health readout.

**Left panel** — appears on selection, closes on Escape or clicking empty ground. Shows information about the selected entity. Also hosts entity configuration controls — filters, production orders, farm controls, specialty assignment. The left panel is for inspecting and managing the long-term state of an entity.

**Bottom bar** — always visible. Contains two areas: the **action bar** (persistent buttons for building placement, designation tools, management overlays) and the **command panel** (contextual buttons that change based on the current selection). The command panel is for immediate, frequent actions: delete for buildings, draft/undraft for units, combat commands (Phase 5), magic (Phase 6). If nothing is selected, the command panel is empty.

**Coexistence:** The left panel and bottom bar coexist — the player inspects a building while placing another. Management overlays (population list, hauling orders, serf priorities) are large panels opened from the action bar that may obscure the map. Escape closes them.

## Selection

Left-click selects a single entity: unit, building, map object (tree, bush, rock), or ground pile. Clicking empty ground clears the selection.

**Click priority** when multiple entities overlap on one tile: unit > ground pile > building > map object. No cycling on repeated clicks.

Multi-select via drag box or shift-click selects multiple units. Multi-selected units show no left panel (no inspection) but enable group commands in the command panel (draft/undraft). Building multi-select is not supported.

## Building Placement

Player enters placement mode by clicking an action bar button or pressing a building hotkey.

GHOST PREVIEW

A tinted footprint follows the cursor, snapping to the tile grid. Per-tile coloring shows placement validity: green = valid, red = invalid. The ghost shows the tile map (walls, floor, door) so the player can see orientation.

VALIDATION

Standard buildings: all footprint tiles must be on pathable terrain (grass/dirt). Clearing tiles must not overlap another building's wall tiles. The tile immediately outside the door must be pathable.

Edge buildings (fishing dock, mines) have row-based terrain constraints relative to orientation. The door face is "front," the opposite edge is "back":
- Fishing dock: back row must be on water, front row must be on grass/dirt, middle rows can be any terrain.
- Mines (iron, gold): back row must be on rock, front row must be on grass/dirt, middle rows can be any terrain.

Edge buildings can transform impassable tiles (water, rock) into passable interior space when built.

ROTATION

Tab cycles orientation: N → E → S → W. The ghost updates immediately. Player-sized buildings (stockpile, farm) have no orientation and do not rotate.

FIXED-SIZE PLACEMENT

Left-click on a valid position to place. If shift is held, stay in placement mode for the same building type. If shift is not held, exit placement mode.

PLAYER-SIZED PLACEMENT (stockpile, farm)

Click-and-drag to define a rectangle. Ghost starts at the click origin and stretches to the cursor. All tiles validated individually. Minimum size 2×2. Release to place. Shift-hold behavior is the same as fixed-size.

EXITING PLACEMENT MODE

Before placing the first building: right-click or Escape exits. After placing the first building: right-click, Escape, or releasing shift exits.

INVALID PLACEMENT FEEDBACK

Left-clicking on an invalid position does not place the building. A brief red pulse on the ghost and an error sound provide feedback. The per-tile red coloring already indicates which tiles are the problem.

## Designation

Player enters designation mode by clicking an action bar button or pressing a designation hotkey.

DESIGNATION TYPES (Phase 1)

| Hotkey | Type | Valid tiles |
|---|---|---|
| A | Chop | Tile has a mature tree (stage 3) |
| S | Gather | Tile has a mature berry bush (stage 3) |

MARKING

Click-and-drag a rectangle. All valid tiles within the rectangle are designated. Invalid tiles within the drag are silently skipped. Designated tiles receive a persistent visual marker, distinct per designation type, so the player can distinguish chop from gather at a glance.

Designation mode persists after each drag — the player can mark multiple areas without re-entering the mode. Right-click or Escape exits.

CANCELLING DESIGNATIONS

X enters cancel designation mode. Click-and-drag a rectangle to remove all designations within. Stays in cancel mode until right-click or Escape.

Cancelling a designation removes the job from `world.jobs`. If a serf had claimed the job, their `job_id`, `claimed_tile`, and `tile.claimed_by` are cleared.

## Right Panel

Always visible. Contents from top to bottom:

TIME AND SPEED

Time display in **Year 4 - Spring - Tuesday - 3:00 PM** format. Four speed buttons (1–4) with the active speed highlighted, plus a pause indicator. Clicking speed buttons and pause works identically to the hotkeys.

POPULATION SUMMARY

Total population count. In P1 this is just serf count. Later phases add counts by class.

RESOURCE OVERVIEW

A table showing `world.resource_counts` across all categories. All resource types from ResourceConfig are listed as rows regardless of current amounts. Categories are columns. A visual gap separates `storage_reserved` from the other categories since reserved is a subset of storage, not a separate pool.

| | Sto | Pro | Hom | Car | Eqp | Gnd | | Rsv |
|---|---|---|---|---|---|---|---|---|
| wood | 42 | | | 8 | | | | 4 |
| berries | 16 | | 12 | 4 | | 3 | | 0 |
| fish | 8 | | 6 | | | | | 0 |

Column abbreviations: Sto = storage, Pro = processing, Hom = housing, Car = carrying, Eqp = equipped, Gnd = ground, Rsv = storage_reserved.

NOTIFICATION FEED

See Notifications section below.

## Left Panel

Appears when an entity is selected. Closes on Escape or clicking empty ground.

P1 IMPLEMENTATION (DEBUG DUMP)

A `tableToString(entity)` helper recursively formats any entity table into labeled rows of text with indentation for nested tables. Selecting a unit dumps the unit table. Selecting a building dumps the building table. Selecting a map tile dumps `world.tiles[idx]`. Selecting a ground pile dumps the ground pile entity.

The dump refreshes live so the player sees values changing in real time — need drain, activity progress, carrying contents.

As the game matures, per-entity-type panels with designed layouts replace the debug dump. The left panel also hosts entity configuration controls (stockpile filters, production orders, farm controls, specialty assignment) as they come online in Phase 2.

## Command Panel

Contextual buttons in the bottom bar based on the current selection. Empty when nothing is selected.

P1 COMMANDS

| Selection | Commands |
|---|---|
| Building | Delete (Del key) |

Delete marks the building `is_deleted = true`, processed at end of tick per BEHAVIOR.md Building Deletion. No confirmation dialog for P1.

FUTURE COMMANDS (Phase 2+)

| Selection | Commands |
|---|---|
| Unit | Draft / Undraft (Phase 5) |
| Multi-selected units | Draft / Undraft, Move (Phase 5) |
| Unit | Combat commands (Phase 5), Magic (Phase 6) |

## Action Bar

Persistent buttons in the bottom bar. Always visible regardless of selection.

P1 BUTTONS

- Building placement buttons: Stockpile (Q), Cottage (W), Woodcutter's Camp (E), Gatherer's Hut (R), Fishing Dock (T)
- Designation buttons: Chop (A), Gather (S), Cancel Designation (X)
- Management overlay buttons: Population List

FUTURE BUTTONS (Phase 2+)

- Additional building buttons as new building types come online
- Additional designation types (herbs in Phase 3)
- Management overlay buttons: Serf Priorities (Phase 2), Hauling Orders (Phase 2)

## Management Overlays

Large panels opened from action bar buttons. May obscure the map. Escape to close.

POPULATION LIST (Phase 1)

Sortable, filterable list of all units. P1 implementation can be a simple text list. Later phases add filtering by class, specialty, and mood.

SERF PRIORITY CONFIGURATION (Phase 2)

*Pending design.*

HAULING ORDER MASTER LIST (Phase 2)

*Pending design.*

## Notifications

Feed in the right panel, newest at top. Each entry is one line of text with the event type and relevant name.

P1 NOTIFICATION TYPES

| Event | Example text | Auto-pause |
|---|---|---|
| Unit death | "Serf Aldric starved to death" | Yes |
| Unit trapped | "Serf Marta is trapped" | No |
| Storage full | "No storage has capacity for wood" | No |
| Starvation warning | "Serf Aldric is starving" | No |

Clicking a notification centers the camera on the source entity or position. If the source is a living unit, also selects them.

Entries persist until dismissed or until a maximum count (20) pushes old ones off the bottom.

Auto-pause configuration per event type is a later refinement. No notification sounds for P1.