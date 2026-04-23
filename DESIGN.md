# Sovereign — Design Document
*v19*

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

Development is organized into twelve phases. Each phase produces a qualitatively different version of the game. The arc moves from bare survival to a living settlement with economy, social life, politics, combat, and the supernatural. See ROADMAP.md for full phase scope, pending design items, and implementation milestones.

- **Phase 1 — Survival.** Core simulation: needs, movement, pathfinding, building placement, hauling, save/load.
- **Phase 2 — Basic Economy.** Construction, freemen, specialties, production chains, storage filters, equipment.
- **Phase 3 — Advanced Economy.** Farming, frost, food processing, metalworking, merchant delivery, firewood.
- **Phase 4 — Mood and Health.** Mood system, food variety, tavern, illness, physician, consumer goods.
- **Phase 5 — Generations and Relationships.** Aging, marriage, children, social relationships, immigration.
- **Phase 6 — Institutions.** Schools, churches, Sunday service, apprenticeship.
- **Phase 7 — Animals.** Hunting, pastures, livestock, meat, leather, wool, fine/noble clothing.
- **Phase 8 — Gentry, Leaders, Succession.** Dynasty, succession, class expectations, gold, pottery, jewelry.
- **Phase 9 — Dangerous World.** Combat, bandits, wolves, weapons, armor, knights, drafting, injuries.
- **Phase 10 — Advanced Institutions.** Bishops, scholars, libraries, cathedrals.
- **Phase 11 — The Forest.** Visibility, fog of war, forest depth gameplay, scouts, wildlife.
- **Phase 12 — The Strange.** Fey, Christian supernatural, arcane and divine magic.

## Time

The seasonal cadence supports recurring events: church on Sundays, market days, festivals. The smallest player-facing time unit is the game_hour. See UI.md for time display format.

The player controls game pacing with multiple speed settings. The player can configure automatic pausing and slowdown for important events.

The game begins on a spring morning with a small group of units. No buildings, no resources. Pure survival start. Surviving the first winter is an intended milestone; subsequent winters become progressively less threatening as new pressure sources take over.

See CLAUDE.md for time constants and game start conditions.

FROST AND GROWING SEASONS

Seasons are calendar labels. Frost is weather. The growing season varies year to year — some years are generous, others punishingly short. The player receives advance warning of both thaw and frost. See ECONOMY.md for frost/thaw mechanics.

A warm year gives extra time for long-maturing crops. A cold year compresses the window — late thaws delay planting, early frosts threaten unharvested fields. Experienced players plan crop selection around risk tolerance. New players get burned once and adapt.

This creates distinct seasonal personalities. Spring is planning time — the thaw arrives, the player decides which farms to plant and which crops to risk. Summer is the constructive season — crops grow without farmer input, freeing labor for building and hauling. Autumn is the busiest season — harvest is time-sensitive, and an approaching frost creates real urgency. Winter is quiet — no farming, and additional challenges from cold as homes consume firewood for heating.

## Aging

Units age faster than real time — generations pass in a few real hours of play rather than dozens.

See CLAUDE.md for aging constants and TABLES.md for death_age.

## The Dynasty

When the leader dies, succession follows family bloodlines — but an unprepared heir inherits all the same, creating dramatic moments.

*Detailed succession traversal mechanics are pending.*

## Game Settings

Configurable at new game creation: combat eligibility, clergy eligibility, and succession priority. Historical defaults apply unless changed. These settings have real mechanical implications — restricting clergy to one gender limits the pool of valid Priest and Bishop candidates. Each new game also receives a randomly generated settlement name, used for save file naming and displayed in the UI.

See TABLES.md for world.settings structure.

## Naming

Unit names and settlement names draw from curated word lists with Anglo-Saxon, Norman, and Germanic influences — recognizable, pronounceable, medieval. Surnames are inherited through the father's line, reinforcing the dynasty as a visible thread across generations. Settlement names are randomly composed from prefix+suffix pairs.

See TABLES.md for name lists and CLAUDE.md for generation rules.

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

CLASS EXPECTATIONS

Each class expects a baseline standard of goods. Missing expected goods causes mood penalties. Higher classes expect more, making each promotion a tangible economic commitment.

- **Serfs** expect: food, plain clothing
- **Freemen and Clergy** expect: food, fine clothing, pottery
- **Gentry** expect: food, noble clothing, pottery, jewelry

Promoting a serf to freeman requires a second textile source and pottery production. Promoting to gentry requires all three textile types (flax, leather, wool) plus gold for jewelry. Each step up has a visible, lasting economic burden.

ATTRIBUTES

Three attributes: **Strength, Intelligence, Charisma.** Attributes are partly inherited and partly developed over a unit's life. Schooling is a meaningful investment — educated freeman children become better craftspeople over generations. See TABLES.md for attribute data structures and growth mechanics.

See BEHAVIOR.md for class system, promotion rules, and children behavior. See TABLES.md for ActivityTypeConfig and NeedsConfig.

## Traits

Traits are permanent tags representing significant thresholds or events. Rare — most units have none. All traits have mechanical effects.

| Trait | Type | Effect |
|---|---|---|
| Blessed (name TBD) | Acquired | Received the Vision. Unlocks divine magic. |
| Magician | Acquired | Unlocked arcane magic through Alchemy. Can cast arcane spells. |
| Haunted | Acquired | Persistent mood penalty. Worsens near supernatural events. |
| Crippled | Acquired | Permanent movement or productivity penalty. |
| Changeling | Genetic | The Fey take interest. Affects Fey encounter outcomes. |
| Touched | Acquired | Result of direct Fey contact. Ambiguous effect. |

*TraitConfig with mechanical values is pending. Blessed/Magician depend on magic system; Changeling/Touched depend on Fey system.*

## Needs, Mood, and Health

**Needs:** Two needs (satiation, energy) create pressure to stop working and attend to personal survival. Spirituality is not a need — it is handled by the scheduled Sunday church service.

**Sleep:** Units need sleep. They tend to be awake during the day and asleep at night, recovering energy while they rest. Sleep deprivation is visible and punishing. See BEHAVIOR.md Sleep for the full behavior.

**Recreation:** Recreation rewards the player for balancing work and leisure. The player configures each unit's work day length — shorter work days mean more recreation time and higher mood. Longer work days mean more output but less recreation time, meaning lower mood. The tavern combines food and recreation into one efficient evening trip, making it a key quality-of-life building. See BEHAVIOR.md Work Day and Recreation for the full behavior.

**Mood:** A composite score reflecting the unit's overall wellbeing. Driven by housing, food variety, clothing, pottery, tools, recreation, health, social events, and life events. Mood thresholds affect productivity and can drive deviancy (abandoning work, antisocial behavior). Low mood is the primary threat — there is no meaningful bonus for high mood.

**Health:** Driven by injury, illness, and malnourishment.

Units wear tools and clothing that degrade over time, creating ongoing demand for production. See BEHAVIOR.md for equipment want behavior and TABLES.md for durability values.

See TABLES.md for NeedsConfig, RecreationConfig, ResourceConfig, MoodThresholdConfig, MoodModifierConfig, InjuryConfig, IllnessConfig.

## Activity System

All work flows through a single activity queue — one system, one mental model for the player. Workers handle their own supply chain; dedicated haulers manage logistics. See BEHAVIOR.md for action system, activity queue filtering, and work cycles. See HAULING.md for the resource-movement system.

## Economy

The economy is built around production chains that transform raw resources into consumable goods. The bread chain (farm → mill → bakery) is the backbone of food production. Berries and fish provide simpler alternatives with no processing infrastructure but higher labor cost per unit of food. The player transitions from foraged food to farming as the settlement grows.

Four food types exist: bread, berries, fish, and meat. Bread, berries, and fish are available through the early economy. Meat arrives with hunting and animal husbandry. Food is designed so the player can assess total supply at a glance — conversion ratios are intuitive and all food types have equal value. Food variety rewards diversification — players benefit from maintaining multiple food sources even after bread becomes the staple. See TABLES.md ResourceConfig and RecipeConfig for specific values.

Consumer goods (food, clothing, tools) are produced through the economy and consumed by units over time. Food is delivered to homes by the merchant, a specialty worker at the market. The market is a meaningful infrastructure milestone — before building one, units fetch their own food, which is less efficient. A skilled merchant delivers more efficiently and naturally diversifies home food supplies, supporting the food variety mood bonus. Equipment degrades over time, and units replace their own gear from storage when needed — infrequent enough that it doesn't burden the economy. See ECONOMY.md for Merchant Delivery System. See BEHAVIOR.md for Equipment Wants. See HAULING.md for the variant catalog including merchant delivery, home food self-fetch, and equipment fetch.

CLOTHING AND TEXTILES

Three textile sources feed the tailor: flax (crop-based, seasonal risk), leather (from hunting and animal slaughter), and wool (from sheep, requires pastures). Each has a different acquisition method and cost structure, meaning diversification requires investment across different systems.

Three clothing tiers reward textile diversity rather than material quality: **plain clothing** requires one textile type, **fine clothing** requires two, and **noble clothing** requires three. This mirrors the food variety pattern — the player maintains multiple supply chains simultaneously rather than abandoning earlier ones.

Clothing tiers map to class expectations — serfs wear plain clothing, freemen expect fine, gentry expect noble. See Class Expectations under Classes and Social Structure.

FIREWOOD AND HOME HEATING

Wood serves three competing purposes: construction, firewood for home heating, and firewood for steel production. Firewood is processed from wood at a chopping block (or similar simple building). Homes consume firewood in winter for warmth. A cold winter forces the player to choose between keeping people warm and fueling industry — the player who over-invests in steel production going into winter risks running short on heating fuel. See ECONOMY.md for firewood production and home heating mechanics.

ANIMALS AND PASTURES

Hunting and animal husbandry expand the resource economy with meat, leather, and wool. Hunters venture into the forest for deer — an early-game source of meat and leather that is active but unsustainable. Pastures are player-sizable buildings for raising livestock: sheep (wool, meat, leather on slaughter), cows (meat, leather on slaughter), and horses (mounted travel and utility). Pastures provide a sustainable alternative to hunting. All animals produce leather when slaughtered, making hides a byproduct of culling rather than a primary motivation. See Phase 7 for pending design items.

RESOURCE COLLECTION

Raw resources enter the economy through two methods. The player can **designate** map resources (trees, berry bushes) for direct collection — any idle serf walks to the designated resource, harvests it, and hauls the result to storage. No building required. **Gathering buildings** (woodcutter's camp, gatherer's hut) automate the same work — workers cycle between the hub and nearby resources without per-resource player input. Both remain useful throughout the game: designation for targeted, intentional collection; buildings for sustained production. From the player's perspective the two methods are identical — a serf chopping a designated tree looks and behaves exactly the same as a serf chopping a tree for a woodcutter's camp. See UI.md for designation interaction. See BEHAVIOR.md Gathering Work Cycle for the unified handler.

STORAGE

Three storage building types serve different roles as the settlement grows. **Stockpiles** are the early-game generalist. **Warehouses** specialize in bulk stackable resources. **Barns** specialize in items.

The progression gives the player a clear reason to build each type. Stockpiles remain useful at every stage as the only storage type that accepts everything. See ECONOMY.md for storage mechanics and TABLES.md for capacity values.

Farms are player-sized open areas with a per-building crop selection. Three crops serve different roles: **wheat** is the riskiest but feeds the bread chain; **barley** is moderate and feeds the brewery; **flax** is the safest and feeds the tailor. Crop selection carries real weight — wheat is the greedy choice that rewards warm years, while barley and flax are safer bets against a short growing season. The player who diversifies has insurance; the player who plants all wheat gambles on the weather. See TABLES.md CropConfig for growth times and yields.

The player can harvest early at reduced yield, creating real agency when frost approaches: lock in a partial return now, or wait for full maturity and risk losing everything. The player controls harvest timing — from fully manual to automatic — and can trigger an emergency harvest at any time. See ECONOMY.md for farm controls, crop growth mechanics, and frost interaction.

Food production requires a meaningful commitment of settlement land.

CARRYING AND GROUND PILES

Ground drops are always temporary — a visible signal that the supply chain needs attention. See BEHAVIOR.md for carrying mechanics. See WORLD.md for speed penalty formula. See ECONOMY.md for ground drop rules.

STORAGE FILTERS

Resource logistics are controlled through **storage filters** — per-type settings on each storage building that give the player optional control over what the building accepts and whether it actively acquires resources from other storage.

Some players will never adjust filters — stockpile proximity to production buildings is the natural optimization lever. Other players will build targeted pull networks to stage resources near production clusters. Both approaches work. See ECONOMY.md for the storage filter system.

See TABLES.md for RecipeConfig, ResourceConfig, production chains, and BuildingConfig.

## Buildings

Buildings have interior spaces that units can enter and work in. The player can see workers at their stations, patrons in the tavern, and families at home. See WORLD.md for building layout system and tile maps.

The player can inspect buildings to see supply chain health at a glance. See UI.md for panel contents.

Buildings rotate in four orientations at placement.

Three housing types with no quality tiers — any unit can live in any housing type. They differ in bed count, size, and build cost.

Three storage types with distinct roles. See Storage above for design rationale.

See TABLES.md for BuildingConfig and bed assignment. See WORLD.md for building layout and construction states.

In Phase 1, buildings are placed instantly — no construction time, no material cost. All obstructions (trees, bushes, ground piles, units) block placement — the player must clear the site first. Starting in Phase 2, proper construction replaces instant-build. Placing a building begins a construction process — the site is cleared of obstructions, materials are delivered, and a builder works until the structure is complete. See WORLD.md Construction States for lifecycle rules. See BEHAVIOR.md Construction Work Cycle for clearing and building behavior.

The player can delete buildings. Deletion has real consequences — residents are displaced, stored resources spill onto the ground, and linked logistics are severed. Buildings under construction can also be deleted. See BEHAVIOR.md Building Deletion for the full cleanup sequence.

## Events and Notifications

**Sunday Service:** Weekly at Church. More effective with a skilled Priest.

**Funeral:** Triggered by unit death. Attendees receive a mood bonus.

**Marriage:** Permanent bond between two units. Can affect class standing. *Formation mechanics pending.*

**Notifications:** The game notifies the player of important events (unit trapped, storage full, no matching building for specialty). Some can be configured to auto-pause or auto-slowdown. See UI.md for notification types, display, and auto-pause rules. *Additional notification types and event speed controls pending.*
