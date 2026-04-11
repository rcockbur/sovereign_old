# Sovereign — Design Document
*v1*

## Project Overview

**Stack:** Love2D · Lua · VS Code · PC (Windows primary)

**Concept:** A medieval village survival and management sim in the vein of Banished, RimWorld, and Dwarf Fortress. The player oversees a small settlement from its earliest days, guiding it through generations of growth, hardship, and discovery. Single-player only. Not a roguelike, not an RTS — combat exists but is not the focus. Not trying to match DF's simulation depth or content breadth.

## Setting

Sovereign is set in medieval Western Europe, primarily English and Norman in character. The most emblematic period is roughly 1250–1350, when plate armor is beginning to emerge and the classic image of the medieval knight is taking shape. A broad blending of the 800–1400 period is acceptable — the goal is a setting that feels familiar and legible to modern audiences rather than one that is historically precise.

Terminology should remain internally consistent. Viking, Renaissance, and Dark Ages terminology should be avoided. Words like baron, serf, and knight are appropriate. Gunpowder, guilds as formal institutions, and perspective art are out of period.

## Design Pillars

**Individual stories over aggregate statistics.**
At any point in the game, the player should be aware of a handful of specific individuals and following their development. Units are never anonymous — they have families, skills, histories, and fates the player comes to care about. Systems should actively surface interesting individuals rather than letting them be lost in the crowd.

**The dynasty is the through-line.**
The player's leader and their family are the main characters of every playthrough. The leader begins as a Gentry unit and may rise to become a baron as the settlement grows. When the leader dies, succession rules determine who inherits. The leader's family, their heirs, and the crises that threaten the dynasty give each playthrough its narrative shape.

**Losing is fun.**
The goal is to build a large, stable village, and this is achievable — but random events, cascading failures, and chaotic emergent situations mean that losing is always possible. Failure should feel dramatic and earned rather than arbitrary.

**The forest is always there.**
The wilderness at the map's edge is a source of mystery, danger, and reward. Players can thrive without exploring it deeply, but the forest exerts a pull — some resources and late-game possibilities require venturing in. The deeper you go, the stranger it gets.

**Streamlined depth.**
DF depth without DF bloat. Systems should be rich enough to generate interesting situations but legible enough that the player always understands what is happening and why.

## Design Goals

- Readable, intuitive UI — a direct response to DF's weaknesses
- Mouse-driven PC controls (with potential for Steam Deck support)
- Systems that remain engaging and legible at both small and large population sizes
- Population cap of approximately 200 units
- Multi-generational play within a single playthrough
- Late-game magic systems emerging naturally from existing unit progression

## Development Phases

Development is organized into six phases. Each phase produces a qualitatively different version of the game. Pending design items are listed under each phase — when all items are resolved, the pending list disappears.

**Phase 1 — Survival.** The core simulation runs. Six serfs exist on a generated map, move via pathfinding, and have needs that drain over time. The player designates map resources for collection and places buildings to organize labor. Serfs gather berries and fish to survive, haul resources to stockpiles, chop wood, and sleep in instantly-placed housing. The game has a basic UI for placing buildings, inspecting units, and controlling time. Save/load works. If food runs out, units starve and die. No leader, no dynasty, no classes beyond serf — those arrive in later phases. This phase proves the simulation engine — time, movement, needs, activities, hauling, and death all function together.

*Pending:*
- Building tile map system and Phase 1 building layouts — authoring tile maps, layout positions, and final dimensions for Phase 1 buildings (stockpile, cottage, woodcutter's camp, gatherer's hut, fishing dock); remaining buildings authored as they come online in later phases

**Phase 2 — Economy.** The full production economy is online. Proper construction replaces instant-build. Freemen with specialties work at processing buildings, transforming raw resources through production chains (wheat → flour → bread). Farms follow the seasonal cycle. The player configures serf priorities, manages building orders, and assigns specialties. A merchant delivers food to homes; units self-fetch their own equipment from storage. Extraction buildings feed the metalworking chain. The settlement sustains itself through infrastructure rather than foraging.

*Pending:*
- Frost day ranges — exact thaw_day and frost_day value ranges for tuning
- Building construction over obstructions — allowing placement on tiles with clearable obstructions (trees, bushes), with units clearing before construction begins
- Barn details — final name, building size, item capacity, UI panel design
- Hauling order UI — storage building filtered views, master hauling overview

**Phase 3 — Mood & Health.** The settlement's quality of life matters. Mood reflects housing, food variety, clothing, and tools — giving the player something to optimize beyond survival. Mood thresholds affect productivity and can drive deviancy. Consumer goods degrade and must be resupplied. The tavern fulfills recreation needs. Illness threatens units and requires a working physician. This phase transforms the game from a logistics puzzle into a settlement that feels alive.

*Pending:*
- Ground drop UI — how to display multiple resource types on the same tile when overlap occurs
- Herbalist's hut — deferred from Phase 1; herbs have no consumer until physician exists in Phase 3
- Tavern — recreation fulfillment, beer delivery/consumption, staffed vs unstaffed behavior
- Apothecary mechanics — herb consumption, patient detection, physician travel logic
- Trait config — mechanical values for Crippled, Haunted (see BRAINSTORMING.md for Touched, Changeling)

**Phase 4 — Generations.** Time becomes the central mechanic. Units age, marry, have children, and die of old age. Children attend school or work based on class. The dynasty matters — the leader's death triggers succession, and the heir's readiness (or lack thereof) creates drama. Clergy provide spiritual services, gentry consume resources without working. Social relationships form between units. The game delivers on the "individual stories" and "dynasty as through-line" pillars.

*Pending:*
- Dynasty/succession — traversal mechanics
- Leadership skill — growth mechanism, effects
- Immigration — triggers, frequency, unit class
- Population growth — soft caps, growth curve tuning
- Home assignment — manual player override (auto-assignment is designed; see TABLES.md)
- Demotion mechanics — whether and how freemen/gentry can be demoted
- School mechanics — intelligence growth rate, teacher skill scaling, capacity overflow
- Marriage formation — eligibility rules, triggers, ceremony, class promotion implications
- Relationship formation — how friend/enemy relationships form, deepen, and break

**Phase 5 — Dangerous World.** The world beyond the village becomes a threat. Combat mechanics enable military response to bandits, wolves, and forest creatures. Visibility and fog of war make the forest a place of uncertainty. Scouts reveal the map, knights train at the barracks. Drafting pulls units from their jobs, creating economic tension. Injuries from combat require medical treatment. The "losing is fun" pillar expands beyond mismanagement to include external pressure.

*Pending:*
- Combat mechanics — melee system, unit stats, threat encounters (see BRAINSTORMING.md)
- Knight specialty — granting knighthood, gentry promotion, training system (see BRAINSTORMING.md)
- Barracks — function, training mechanics (see BRAINSTORMING.md)
- Ranged combat, scout job (see BRAINSTORMING.md)
- Visibility system — vision rules, implementation approach (see BRAINSTORMING.md)
- Movement speed formula — trait effects on speed

**Phase 6 — The Strange.** The game's supernatural layer emerges. Fey creatures inhabit the deep forest with their own alien logic — some can be bargained with, others must be fought. Christian supernatural forces introduce ghosts, demons, and possessed units. The scholar unlocks arcane magic through research, the bishop receives divine power through the Vision. The game world deepens from a grounded medieval settlement into something stranger and more mythic. See BRAINSTORMING.md for creature lists, encounter concepts, and magic system ideas.

*Pending:*
- Fey mechanics — encounter design, diplomacy, late-game escalation (see BRAINSTORMING.md)
- Magic — arcane tech tree, divine scripture, spell lists, mana rates (see BRAINSTORMING.md)
- Witch gender setting — mechanical effect (depends on arcane magic system)
- Cathedral, Library, and Christmas Mass — late-game service buildings and events (see BRAINSTORMING.md)

**Unphased.** Ideas and systems that don't belong to a specific phase yet.

- Hauling order priority — per-order priority for scarce hauler situations
- Town hall — function, governance mechanics
- Luxury goods beyond jewelry
- Animal husbandry (see BRAINSTORMING.md)
- External trade (see BRAINSTORMING.md)
- Event speed controls (see BRAINSTORMING.md)
- Apprenticeship system (see BRAINSTORMING.md)
- Gentry activities (see BRAINSTORMING.md)

## Time

The seasonal cadence supports recurring events: church on Sundays, market days, festivals. The smallest player-facing time unit is the game_hour. See UI.md for time display format.

The player controls game pacing with multiple speed settings. The player can configure automatic pausing and slowdown for important events.

The game begins on a spring morning with a small group of units. No buildings, no resources. Pure survival start. Surviving the first winter is an intended milestone; subsequent winters become progressively less threatening as new pressure sources take over.

See CLAUDE.md for time constants and game start conditions.

FROST AND GROWING SEASONS

Seasons are calendar labels. Frost is weather. The growing season varies year to year — some years are generous, others punishingly short. The player receives advance warning of both thaw and frost. See ECONOMY.md for frost/thaw mechanics.

A warm year gives extra time for long-maturing crops. A cold year compresses the window — late thaws delay planting, early frosts threaten unharvested fields. Experienced players plan crop selection around risk tolerance. New players get burned once and adapt.

This creates distinct seasonal personalities. Spring is planning time — the thaw arrives, the player decides which farms to plant and which crops to risk. Summer is the constructive season — crops grow without farmer input, freeing labor for building and hauling. Autumn is the busiest season — harvest is time-sensitive, and an approaching frost creates real urgency. Winter is quiet — no farming, and (eventually) additional challenges from cold.

See ECONOMY.md for frost/thaw mechanics.

## Aging

Units age faster than real time — generations pass in a few real hours of play rather than dozens.

See CLAUDE.md for aging constants and TABLES.md for death_age.

## The Dynasty

When the leader dies, succession follows family bloodlines — but an unprepared heir inherits all the same, creating dramatic moments.

*Detailed succession traversal mechanics are pending.*

## Game Settings

Configurable at new game creation: combat eligibility, clergy eligibility, and succession priority. Historical defaults apply unless changed. These settings have real mechanical implications — restricting clergy to one gender limits the pool of valid Priest and Bishop candidates.

See TABLES.md for world.settings structure.

## Map

Left half is the settlement area, right half is the forest with increasing danger. Procedurally generated from a seed. Single zone — no separate maps or regions.

The visibility system is **deferred** — all tiles start explored and visible until forest gameplay is implemented.

The map is procedurally generated from a single seed. The settlement half is mostly open grass with scattered tree clusters, a few rock outcrops, and one or two lakes — terrain that cooperates with the player. The forest half is dense with natural clearings, more and larger rock formations, and berry bushes growing in gaps between trees. A transition band at the boundary blends the two halves so the forest edge feels gradual rather than a hard line. The starting area near the center of the settlement half is guaranteed to have a clear grass patch for initial building placement.

See WORLD.md for map dimensions, terrain, forest coverage, visibility, and the generation pipeline.

## The Forest

The wilderness surrounding the settlement is not simply a resource zone — it is a place with its own character, rules, and inhabitants. It is the primary source of late-game mystery and opt-in escalation.

The forest is dense and resource-rich — a wall the player carves into.

Forest resources are tiered by depth. Basic materials are available everywhere, rarer materials require venturing deeper. Some late-game systems, including magic, are gated behind deep resources.

The forest is home to animals, hostile human factions, ruins, and Fey. The game begins feeling entirely grounded — supernatural elements escalate gradually. See BRAINSTORMING.md for creature lists and encounter concepts.

See WORLD.md for forest coverage, plant types, growth/spread mechanics, and movement costs.

## Supernatural & Magic

The game begins fully grounded. Supernatural elements escalate gradually as the player explores the forest and advances the settlement.

**Fey** — ancient, inhuman beings tied to the forest. Not evil — they operate by alien logic. Diplomatic solutions exist for many encounters. Deeper forest = stronger presence.

**Christian Supernatural** — binary holy or corrupt forces. The player's cleric is the primary countermeasure. Includes ghosts, possessed units, cursed ground, and demons.

**Generic Monsters** — combat encounters for forest exploration variety. No faction, no diplomacy.

**Bandits** — human raiders. The player's introduction to external threats.

**Wildlife** — wolves appear anywhere; dire wolves are forest-only. Keeps the early game grounded.

Magic is a late-game system that emerges from existing unit progression. Rare, significant, and partially gated behind deep forest resources. The game begins with no indication that magic exists.

**Divine magic** is reactive and protective. Safe and predictable. **Arcane magic** is active and transformative. More powerful but carries risk. **Dark magic** is wielded only by enemies. Shorthand: **divine magic fixes, arcane magic does.**

**Arcane progression:** Scholar researches through a directed tech tree. Alchemy is the gateway — unlocking it reveals the arcane mana bar and grants the Magician trait.

**Divine progression:** Priest/Bishop levels priesthood skill. Divine magic unlocks through the Vision — a dramatic narrative event at a Bishop skill threshold. All divine spells unlock simultaneously. The Bishop gains the Blessed trait.

*Specific spells, mana rates, tech tree, and scripture mechanics deferred to BRAINSTORMING.md.*

See TABLES.md for magic data structure.

## Classes and Social Structure

The settlement is organized into four classes, inspired by the medieval Three Estates but with a distinct serf/freeman split to reflect the game's labor mechanics:

**Serfs** are unskilled laborers — the majority of the population. They choose work from a player-configured priority list.

**Freemen** are skilled tradespeople. Each freeman is given a **specialty** — a career such as baker, smith, or physician. The player appoints specialists; they find their own work. See BEHAVIOR.md for dynamic work-finding mechanics.

**Clergy** exist outside the economic hierarchy. Appointment is permanent and irrevocable — a weighty decision with lasting consequences. See BEHAVIOR.md for promotion rules.

**Gentry** are the ruling class. They do not work. Their purpose is to provide the dynasty's leader and, eventually, knights. The player trades economic efficiency for political stability and military readiness.

Higher classes are needier, making gentry and bishops expensive to maintain. This creates a real cost to elevation — every knight or bishop is a drain on the settlement's resources.

ATTRIBUTES

Three attributes: **Strength, Intelligence, Charisma.** Attributes are partly inherited and partly developed over a unit's life. Schooling is a meaningful investment — educated freeman children become better craftspeople over generations. See TABLES.md for attribute data structures and growth mechanics.

See BEHAVIOR.md for class system, promotion rules, and children behavior. See TABLES.md for JobTypeConfig and NeedsConfig.

## Traits

Traits are permanent tags representing significant thresholds or events. Rare — most units have none. All traits have mechanical effects.

| Trait | Type | Effect |
|---|---|---|
| Blessed (name TBD) | Acquired | Received the Vision. Unlocks divine magic. |
| Magician | Acquired | Unlocked arcane magic through Alchemy. Can cast arcane spells. |
| Haunted | Acquired | Persistent mood penalty. Worsens near supernatural events. |
| Crippled | Acquired | Permanent movement or productivity penalty. |
| Marked | Genetic | The Fey take interest. Affects Fey encounter outcomes. |
| Touched | Acquired | Result of direct Fey contact. Ambiguous effect. |

*TraitConfig with mechanical values is pending. Blessed/Magician depend on magic system; Marked/Touched depend on Fey system.*

## Needs, Mood, and Health

**Needs:** Three needs (satiation, energy, recreation) that create pressure to stop working and attend to personal survival. All units consume food at the same rate. Spirituality is not a need — it is handled by the scheduled Sunday church service.

**Sleep:** Units need sleep. They tend to be awake during the day and asleep at night, recovering energy while they rest. Sleep deprivation is visible and punishing. See BEHAVIOR.md Sleep for the full behavior.

**Mood:** A composite score reflecting the unit's overall wellbeing. Driven by housing, food variety, clothing, luxury goods, health, social events, and life events. High mood boosts productivity; low mood causes productivity penalties and eventually deviancy (abandoning work, antisocial behavior).

**Health:** Driven by injury, illness, and malnourishment. Unit dies at 0.

Units wear tools, clothing, and jewelry that degrade over time, creating ongoing demand for production. See BEHAVIOR.md for equipment want behavior and TABLES.md for durability values.

See TABLES.md for NeedsConfig, ResourceConfig, MoodThresholdConfig, MoodModifierConfig, InjuryConfig, IllnessConfig.

## Job System

All work flows through a single job queue. Buildings post jobs when they have work available. Serfs and freemen both poll the same queue — they differ only in what they're looking for. One system, one queue, one mental model for the player.

Workers are self-sufficient — they fetch their own inputs from storage and deposit their own outputs to storage as part of their work cycle. Dedicated haulers clear ground piles, deliver construction materials, and execute player-configured storage-to-storage hauling orders.

See BEHAVIOR.md for activity system, job queue filtering, work cycles, and self-fetch/self-deposit.

## Economy

The economy is built around production chains that transform raw resources into consumable goods. The bread chain (farm → mill → bakery) is the backbone of food production. Berries and fish provide simpler alternatives with no processing infrastructure but higher labor cost per unit of food. The player transitions from foraged food to farming as the settlement grows.

Three food types exist: bread, berries, and fish. Food is designed so the player can assess total supply at a glance — conversion ratios are intuitive and all food types have equal value. Food variety rewards diversification — players benefit from maintaining multiple food sources even after bread becomes the staple. See TABLES.md ResourceConfig and RecipeConfig for specific values.

Consumer goods (food, clothing, jewelry, tools) are produced through the economy and consumed by units over time. Food is delivered to homes by the merchant, a specialty worker at the market. The market is a meaningful infrastructure milestone — before building one, units fetch their own food, which is less efficient. A skilled merchant delivers more efficiently and naturally diversifies home food supplies, supporting the food variety mood bonus. Equipment degrades over time, and units replace their own gear from storage when needed — infrequent enough that it doesn't burden the economy. See ECONOMY.md for Merchant Delivery System. See BEHAVIOR.md for Equipment Wants and Home Food Self-Fetch.

RESOURCE COLLECTION

Raw resources enter the economy through two methods. The player can **designate** map resources (trees, berry bushes) for direct collection — any idle serf walks to the designated resource, harvests it, and hauls the result to storage. No building required. This is the player's first tool for shaping the settlement: clearing trees for building space, gathering food before any infrastructure exists, and carving paths into the forest. Designation is the bootstrap — the way the settlement gets its first wood before a woodcutter's camp can be built.

**Gathering buildings** (woodcutter's camp, gatherer's hut) automate what designation does manually — workers cycle between the hub and nearby resources without per-resource player input. Both remain useful throughout the game: designation for targeted, intentional collection; buildings for sustained production.

Designation and building-based gathering are identical from the player's perspective — a serf chopping a designated tree looks and behaves exactly the same as a serf chopping a tree for a woodcutter's camp. A woodcutter's camp effectively automates the task of designating trees. The player designates resources for chopping or foraging. See UI.md for designation interaction.

See BEHAVIOR.md Gathering Work Cycle for the unified handler.

STORAGE

Three storage building types serve different roles as the settlement grows. **Stockpiles** are the early-game generalist. **Warehouses** specialize in bulk stackable resources. **Barns** specialize in items.

The progression gives the player a clear reason to build each type. Stockpiles remain useful at every stage as the only storage type that accepts everything. See ECONOMY.md for storage mechanics and TABLES.md for capacity values.

Farms are player-sized open areas with a per-building crop selection. Three crops serve different roles: **wheat** is the riskiest but feeds the bread chain; **barley** is moderate and feeds the brewery; **flax** is the safest and feeds the tailor. Crop selection carries real weight — wheat is the greedy choice that rewards warm years, while barley and flax are safer bets against a short growing season. The player who diversifies has insurance; the player who plants all wheat gambles on the weather. See TABLES.md CropConfig for growth times and yields.

The player can harvest early at reduced yield, creating real agency when frost approaches: lock in a partial return now, or wait for full maturity and risk losing everything. The player controls harvest timing — from fully manual to automatic — and can trigger an emergency harvest at any time. See ECONOMY.md for farm controls, crop growth mechanics, and frost interaction.

Food production requires a meaningful commitment of settlement land.

CARRYING AND GROUND PILES

Units carry resources as part of their work cycle. Resources are never destroyed due to lack of storage — they persist on the ground until collected. Ground drops are always temporary — a visible signal that the supply chain needs attention. See BEHAVIOR.md for carrying mechanics. See WORLD.md for speed penalty formula. See ECONOMY.md for ground drop rules.

HAULING ORDERS

Resource movement between storage buildings is controlled through **hauling orders** — player-created directives for logistics optimization.

Some players will never touch hauling orders — stockpile proximity to production buildings is the natural optimization lever. Other players will build elaborate routing networks to stage resources near production clusters. Both approaches work. See ECONOMY.md for the hauling order system.

See TABLES.md for RecipeConfig, ResourceConfig, production chains, and BuildingConfig.

## Buildings

Buildings have interior spaces that units can enter and work in. The player can see workers at their stations, patrons in the tavern, and families at home. See WORLD.md for building layout system and tile maps.

The player can inspect buildings to see supply chain health at a glance. See UI.md for panel contents.

Buildings rotate in four orientations at placement.

Three housing types with no quality tiers — any unit can live in any housing type. They differ in bed count, size, and build cost.

Three storage types with distinct roles. See Storage above for design rationale.

See TABLES.md for BuildingConfig and bed assignment. See WORLD.md for building layout and construction state.

The player can delete buildings. Deletion has real consequences — residents are displaced, stored resources spill onto the ground, and linked logistics are severed. Buildings under construction can also be deleted. See BEHAVIOR.md Building Deletion for the full cleanup sequence.

## Events and Notifications

**Sunday Service:** Weekly at Church. More effective with a skilled Priest.

**Funeral:** Triggered by unit death. Attendees receive a mood bonus.

**Marriage:** Permanent bond between two units. Can affect class standing. *Formation mechanics pending.*

**Notifications:** The game notifies the player of important events (unit trapped, storage full, no matching building for specialty). Some can be configured to auto-pause or auto-slowdown. See UI.md for notification types, display, and auto-pause rules. *Additional notification types and event speed controls pending.*