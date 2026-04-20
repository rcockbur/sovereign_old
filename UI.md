# Sovereign — UI.md
*v15 · Player interface: camera, input, layout, selection, panels, overlays, notifications, interaction flows.*

## Camera

Top-down orthographic. Fixed orientation — no rotation.

Zoom range: `ZOOM_MIN` (0.5) to `ZOOM_MAX` (2.0). Pan via edge scroll or keyboard. Tile-to-screen conversion is a direct scale — no isometric projection math.

## Architecture

MODULE STRUCTURE

UI is organized as per-region modules coordinated by a hub (`ui/hub.lua`). Each region owns its own draw and input handling. The hub calls them in the correct order for input routing and drawing. Adding a new region means adding it to the hub's two call lists.

```
ui/
  hub.lua              -- hub: input routing, draw ordering, active_layer, interaction mode
  right_panel.lua
  left_panel.lua
  action_bar.lua      -- persistent buttons (placement, designation)
  command_bar.lua     -- contextual buttons based on selection (delete, draft, etc.)
  overlays.lua        -- management panels (population list, serf priorities)
  camera.lua
  renderer.lua
  dev_overlay.lua     -- F3 debug overlay
```

INPUT ROUTING

`ui.lua` resolves which layer owns the mouse once per frame during `update`, based on mouse position and panel visibility. The result is stored as `ui.active_layer`. Clicks dispatch to the owning layer's handler via early return. Draw code reads `active_layer` to decide whether to show hover states. The game world only processes input or draws hover effects when no UI layer claimed the mouse.

Priority chain (first match wins): management overlay (if open) → left panel (if open) → action bar → command bar → right panel → game world.

DRAW ORDER

`playing:draw()` makes two passes in sequence with no interleaving:

1. **World pass** — camera transform applied. Tiles, buildings, units, ground piles, placement ghosts, designation markers. Everything that exists in world-space.
2. **UI pass** — no camera transform. Panels, buttons, notifications, tooltips. Everything in screen-space.

The renderer handles the world pass. `ui.draw()` handles the UI pass.

INTERACTION MODES

The action bar can put the player into a mode that changes what game-world clicks mean. The current mode lives on the hub (`ui/hub.lua`) in two parallel fields so all consumers read from one place:

- `hub.mode` — a string enum naming the current mode
- `hub.mode_state` — a table holding mode-specific data, or nil when the mode has no state

| Mode | `mode_state` shape |
|---|---|
| `"normal"` | nil — clicks select entities, no state needed |
| `"placing"` | `{ building_type, orientation }` — clicks place a building. `building_type` keys into BuildingConfig. `orientation` is `"N"`/`"S"`/`"E"`/`"W"`, or nil for player-sized and solid buildings (see Building Placement § Rotation) |
| `"designating"` | `{ designation_type }` — clicks mark tiles. `designation_type` is `"chop"` or `"gather"` in P1 |
| `"cancelling"` | nil — clicks remove designations of any type, no filter |

**Transitions.** Mode changes go through a single function `hub.setMode(mode, state)` that writes both fields together, so `mode` and `mode_state` are never observed in an inconsistent combination. Each transition fully replaces `mode_state` — nothing from the previous mode's state carries forward.

**Ephemeral state.** Exiting a mode (Escape, right-click, or explicitly switching to another mode) clears `mode_state`. Re-entering placement by clicking a building's button starts fresh at the default orientation, not whatever the player had rotated to previously. Shift-hold during placement keeps the mode active continuously, which covers the "place several of the same thing" workflow without needing persistent state.

**Consumers.** The action bar sets the mode via `setMode`. The game world input handler reads `hub.mode` to decide what clicks do, then reads `hub.mode_state` for the mode-specific details. The renderer reads both to draw placement ghosts or designation previews.

## Input

Left-click selects. Right-click cancels modes and clears selection. Escape closes panels and clears selection.

HOTKEYS

All non-debug hotkeys are remappable via the `Keybinds` table in `config/keybinds.lua`. The input handler checks `love.keyboard.isDown(Keybinds.action_name)` instead of checking key literals directly. See TABLES.md for default bindings.

Debug keys (hardcoded, not remappable): F1 (spawn serf at cursor), Shift+F1 (spawn 5 serfs), F3 (toggle developer overlay).

Building placement has no hotkeys — the player clicks the action bar button. Designation hotkeys expand as new designation types come online in later phases.

## Layout

Three persistent regions:

**Right panel** — always visible, read-only. Settlement-level information: time display, speed controls, population summary, resource overview, notification feed. This is the player's at-a-glance settlement health readout.

**Left panel** — appears on selection, closes on Escape or clicking empty ground. Shows information about the selected entity. Also hosts entity configuration controls — filters, production orders, farm controls, specialty assignment. The left panel is for inspecting and managing the long-term state of an entity.

**Bottom bar** — always visible. Contains two areas: the **action bar** (persistent buttons for building placement, designation tools, management overlays) and the **command bar** (contextual buttons that change based on the current selection). The command bar is for immediate, frequent actions: delete for buildings, draft/undraft for units, combat commands (Phase 5), magic (Phase 6). If nothing is selected, the command bar is empty.

**Coexistence:** The left panel and bottom bar coexist — the player inspects a building while placing another. Management overlays (population list, serf priorities) are large panels opened from the action bar that may obscure the map. Escape closes them.

## Selection

Left-click selects a single entity: unit, building, map object (tree, bush, rock), or ground pile. Clicking empty ground clears the selection.

**Click priority** when multiple entities overlap on one tile: unit > ground pile > building > map object. No cycling on repeated clicks.

Multi-select via drag box or shift-click selects multiple units. Multi-selected units show no left panel (no inspection) but enable group commands in the command bar (draft/undraft). Building multi-select is not supported.

## Building Placement

Player enters placement mode by clicking an action bar button.

GHOST PREVIEW

A tinted footprint follows the cursor, snapping to the tile grid. Per-tile coloring shows placement validity. The ghost shows the tile map (walls, floor, door) so the player can see orientation.

**P1 coloring:** Green = valid, red = invalid. All obstructions (units, trees, berry bushes, ground piles, terrain, other buildings) show red. Left-clicking when any tile is red does not place the building — a brief red pulse on the ghost and an error sound provide feedback.

**P2 coloring:** Three colors. Green = valid (clear tile). Yellow = clearable obstruction (tree, ground pile, and berry bush once P3 clearing comes online). Red = hard block (impassable terrain, other buildings, clearing overlap violations). Units on footprint tiles are ignored — they are displaced on placement. Left-clicking when any tile is red does not place the building. Left-clicking when all tiles are green or yellow places the building — yellow tiles trigger the blueprint phase with clearing activities (see BEHAVIOR.md Construction Work Cycle).

VALIDATION

See WORLD.md Placement Validation for all placement rules (terrain, clearing overlap, door adjacency, plants, ground piles, unit occupancy, edge buildings, solid buildings).

ROTATION

Tab cycles orientation: N → E → S → W. The ghost updates immediately. Player-sized buildings (stockpile, farm) and solid buildings (gathering hubs) have no orientation and do not rotate.

FIXED-SIZE PLACEMENT

Left-click on a valid position to place. If shift is held, stay in placement mode for the same building type. If shift is not held, exit placement mode.

PLAYER-SIZED PLACEMENT (stockpile, farm)

Click-and-drag to define a rectangle. Ghost starts at the click origin and stretches to the cursor. All tiles validated individually. Minimum size 2×2. Release to place. Shift-hold behavior is the same as fixed-size.

EXITING PLACEMENT MODE

Before placing the first building: right-click or Escape exits. After placing the first building: right-click, Escape, or releasing shift exits.

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

Cancelling a designation removes the activity from `world.activities`. If a serf had claimed the activity, their `activity_id`, `claimed_tile`, and `tile.claimed_by` are cleared.

## Right Panel

Always visible. Contents from top to bottom:

TIME AND SPEED

Time display in **Year 4 - Spring - Tuesday - 3:00 PM** format. Six speed buttons (1–6) with the active speed highlighted, plus a pause indicator. Clicking speed buttons and pause works identically to the hotkeys.

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

The dump refreshes live so the player sees values changing in real time — need drain, action progress, carrying contents.

As the game matures, per-entity-type panels with designed layouts replace the debug dump. The left panel also hosts entity configuration controls (stockpile filters, production orders, farm controls, specialty assignment) as they come online in Phase 2.

## Command Bar

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

- Building placement buttons: Stockpile, Cottage, Woodcutter's Camp, Gatherer's Hut, Fishing Dock
- Designation buttons: Chop, Gather, Cancel Designation
- Management overlay buttons: Population List

FUTURE BUTTONS (Phase 2+)

- Additional building buttons as new building types come online
- Additional designation types (herbs in Phase 3)
- Management overlay buttons: Serf Priorities (Phase 2)

## Management Overlays

Large panels opened from action bar buttons. May obscure the map. Escape to close.

POPULATION LIST (Phase 1)

Sortable, filterable list of all units. P1 implementation can be a simple text list. Later phases add filtering by class, specialty, and mood.

SERF PRIORITY CONFIGURATION (Phase 2)

*Pending design.*

STORAGE FILTER CONFIGURATION (Phase 2)

Per-type filter controls on storage building left panels. Each resource type shows its current mode (reject / accept / pull) and optional limit. "Pull" entries allow selecting a source building. See ECONOMY.md Storage Filter System for filter mechanics.

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