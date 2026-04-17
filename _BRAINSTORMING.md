# Sovereign — BRAINSTORMING.md
*v2 · Loosely defined ideas, deferred systems, and content slated for later development. Upload to Claude.ai sessions when relevant.*

## Creatures and Encounters

The game begins fully grounded. Supernatural elements escalate gradually as the player explores the forest and advances the settlement. Three creature categories exist, each with distinct encounter rules.

FEY CREATURES

Ancient, inhuman beings tied to the forest and wilderness. The Fey are not evil — they operate by their own alien logic, indifferent to human morality. Some are harmless or even helpful. Others are lethal. The deeper into the forest, the more powerful the Fey presence. Diplomatic solutions exist for many Fey encounters — a Charisma-skilled envoy may achieve outcomes that warriors cannot.

| Creature | Hostility | Power |
|---|---|---|
| Pixies/Sprites | Friendly | Weak |
| Knockers | Friendly | Weak |
| Fauns | Friendly | Weak |
| Boggarts | Hostile | Weak |
| Dryads | Neutral | Moderate |
| Will-o-Wisps | Hostile | Moderate |
| Kelpie | Hostile | Moderate |
| Merfolk | Neutral | Moderate |
| Centaurs | Neutral | Moderate |
| Unicorn | Friendly | Powerful |
| Green Man | Neutral | Powerful |
| Wild Hunt | Hostile | Powerful |
| Fey Court | Neutral | Powerful |

Notable creature concepts:
- **Knockers** — mine spirits. Treated well, they warn of cave-ins or improve ore yield. Ignored or disrespected, they cause accidents.
- **Dryads** — tied to specific trees. Chopping their tree turns them hostile — a genuine dilemma when the grove contains needed logs.
- **Will-o-Wisps** — lure units deeper into the forest, potentially triggering more dangerous encounters. A trap mechanic, not a combat creature.
- **Wild Hunt** — an event rather than a creature. A host of spectral hunters riding through the territory at night. Units caught outside are in serious danger.
- **Fey Court** — the political structure behind all Fey.

CHRISTIAN SUPERNATURAL

The moral battlefield between divine and demonic forces. Unlike the Fey, Christian supernatural is binary — things are holy or corrupt. The player's cleric is the primary tool for dealing with this category.

| Creature/Event | Hostility | Power |
|---|---|---|
| Angel | Friendly | Powerful |
| Ghost | Hostile | Weak |
| Witch/Warlock | Hostile | Weak |
| Skeleton | Hostile | Weak |
| Cursed Ground | Hostile | Moderate |
| Possessed Unit | Hostile | Moderate |
| Revenant | Hostile | Moderate |
| Demon | Hostile | Powerful |

- **Witches/Warlocks** are mortal NPC spellcasters who have made dark bargains for power. Gender is configurable (see Game Settings in DESIGN.md). They can summon skeletons and animate the dead.
- **Ghosts** are not malicious but their presence frightens settlers. They have unfinished business.
- **Cursed Ground** is a location-based effect — a tile or building causing ongoing problems until cleansed.
- **Possessed Unit** is one of the player's own settlers, making it uniquely dangerous and dramatic.

GENERIC MONSTERS

Combat encounters that add variety to forest exploration. No diplomatic solutions — purely military threats.

| Creature | Hostility | Power |
|---|---|---|
| Giant Spider | Hostile | Weak |
| Goblin | Hostile | Weak |
| Dire Wolf | Hostile | Moderate |
| Troll | Hostile | Moderate |
| Ogre | Hostile | Moderate |
| Harpy | Hostile | Moderate |
| Giant | Hostile | Powerful |
| Griffin | Neutral | Powerful |

THE CHANGELING EVENT

A rare, high-stakes event in which the Fey demand a child from the settlement. The player must decide whether to comply. If given, the child returns after a generation, changed unpredictably.

The **Changeling** trait (genetic) would be hidden from the player until discovered. Deliberately unpredictable mechanical effects. *Specific mechanical outcomes for the returned changeling are undecided.*

FEY ENCOUNTER MECHANICS

Specific encounter types, bargaining outcomes, Fey Court diplomacy. The Charisma-skilled envoy concept.

*Entirely undefined. Needs dedicated design session.*

TRAIT EFFECTS (UNDEFINED)

- **Touched** — result of direct Fey contact. Effect is ambiguous — may be positive or negative depending on the nature of the contact. *Undecided.*
- **Changeling** — hidden genetic trait. Deliberately unpredictable. *Undecided.*

## Forest and Vision

ASYMMETRIC FOREST VISION

A possible approach for the fog of war system: outside the forest, recursive shadowcasting at normal radius where trees block sight. Inside the forest, reduced sight radius but trees are transparent. This creates different tactical considerations for units inside vs. outside the tree line.

SCOUT JOB

Deferred job type. Key properties already decided:
- Always uses full `SIGHT_RADIUS` with trees always transparent regardless of location
- Moves at full speed in forest (exempt from `TREE_MOVE_MULTIPLIER`)
- Same shadowcasting algorithm as other units, different parameters
- Scouts would bypass all vision restrictions under the asymmetric model

*Job tier, attributes, skills, and full mechanical definition pending.*

## Combat Mechanics

Military behavior, threat types, combat resolution, unit formations, damage model.

*Core combat mechanics are entirely undefined. Needs dedicated design session.*

KNIGHT AND TRAINING PROPOSAL

The knight is a gentry station. Training as a universal idle fallback: instead of idling, adults without work go to the barracks to train. Units don't need a barracks to train — they practice on their own. A barracks would be an upgrade that improves training effectiveness, staffed by a knight.

Serfs train but only grow strength (they can't learn skills). Freeman+ grow combat skill. This creates a natural difference — serfs get tougher, stationed knights become skilled fighters.

Children cannot train. Barracks has a max_trainees cap. A well-run settlement with efficient supply chains produces more idle time, which means more trained fighters — rewarding good logistics with military readiness.

The entire combat system is deferred until the economy is fully functional without combat.

## Magic and Late-Game Institutions

ARCANE MAGIC

- Full spell list
- Tech tree structure beyond Alchemy gateway
- Mana generation rates
- Spell costs and effects
- Transmute spell mechanics (first spell unlocked)

DIVINE MAGIC

- Full spell/miracle list
- Vision event trigger conditions (Bishop skill threshold + settlement moment)
- Mana generation rates
- Scripture doctrine choices and their settlement bonuses

DARK MAGIC (ENEMY ONLY)

- Enemy spellcaster abilities
- Skeleton summoning mechanics
- Dead animation mechanics

CATHEDRAL

- Scripture writing mechanics (menu of repeatable or permanent doctrine choices)
- Whether scripture requires material inputs
- Doctrine bonus effects

LIBRARY

- Full tech tree structure
- Research time scaling
- Multiple Scholar contribution mechanics

## Housing and Family

*Direction established via competitive analysis session. Not yet designed — captures intent and constraints for future design work.*

FAMILY AS FIRST-CLASS ENTITY

Family is a first-class game object, not derived from relationship links. One home = one family. The family is the primary unit for housing assignment, food delivery, mood visibility, and UI presentation. At 200 population with ~4 members per family, the player manages ~50 families rather than 200 individuals.

A family is created when a couple marries. Children born to the couple belong to that family. When a child marries, they leave and form a new family. The family carries the father's surname.

Family is the management unit for housing, food, and social life. Labor and production remain individual — the player thinks in families when managing domestic life and in individual units when managing the workforce.

FAMILY SIZE

- 4-child maximum per couple
- 6-person family cap (2 parents + 4 children)
- Blended families (remarriage with children from both sides) are blocked if the combined household would exceed available housing capacity — the constraint is housing supply, which the player controls

HOUSING TYPES

Three housing types exist in the main docs (see TABLES.md BuildingConfig). Additional design direction:

- **Cottage:** Couples and small families. The standard building. *The brainstorming concept of "floor spots" (2 spots beyond the 4 beds, with a mood penalty for floor sleeping) is not yet reflected in the main docs — pending decision on whether floor sleeping is a mechanic.*
- **House:** Large families. Built when families outgrow cottages. The third child is the natural trigger — a couple with two kids fits a cottage, the third means they need more space.
- **Manor:** Gentry housing. Fewer beds than the house, but more interior space and furnishing slots. The prestige building for the ruling family.

No wood vs. stone material axis — homes are built from mixed materials (wood + stone) as a build cost, not a meaningful design axis.

FURNISHINGS AS QUALITY AXIS

Housing quality comes from contents, not building type. Slot-based system: each home has named furniture/decoration slots (bed, table, decoration, etc.). Items placed in slots contribute to a housing quality score that feeds mood.

- Bare home: meets serf expectations
- Furnished home (table, chest): meets freeman expectations
- Decorated home (pottery, tapestry, better bed): approaches gentry expectations

Larger homes and the manor have more slots, naturally supporting higher quality ceilings.

Furnishings connect directly to production chains: carpentry for furniture, pottery for decorations, tailoring for tapestries. Upgrading a home is a tangible economic investment in a specific family.

Auto-furnishing from available goods by default (based on class expectations), with manual override for players who want to prioritize specific homes. Same philosophy as storage filters — works untouched, power users can optimize.

HOUSING ASSIGNMENT AND PERMANENCE

Homes are permanent. Units do not churn between houses. Moves only occur on life events:

- **Marriage**: Both partners leave current homes. Move into smallest available empty home.
- **Family outgrowth**: Third child triggers search for a larger home. If none available, child sleeps on floor (mood penalty, visible signal to build).
- **Coming of age**: Unmarried adults past an age threshold split off into a solo family and seek their own housing. Frees beds in parents' home.
- **Spouse death**: Surviving spouse and children stay in current home. No forced move.
- **Remarriage**: New family forms from combined members. Blocked if combined size exceeds housing capacity.
- **Building deletion**: Forced displacement. Family becomes homeless and auto-assigns to available housing. Should feel bad.

Auto-assignment by default (nearest available home with enough beds). Per-building manual override: click a home, see who lives there, evict or reserve beds. Reserved beds stay reserved even if other units are homeless — the player's intent is respected.

POPULATION GROWTH

Housing-gated reproduction: no empty home available → no new couples form → no population growth. The player controls growth rate through housing construction.

Safeguards against Banished's demographic synchronization:
- **Variable courtship duration**: Marriage requires coexistence over time, not instant pairing on house completion. Building ten houses doesn't create ten simultaneous couples.
- **Variable fertility**: Some couples conceive quickly, some slowly, some never. Spreads out birth distribution naturally.
- **4-child cap**: Prevents runaway family growth.

No explicit fertility policy lever for the player. Housing construction is the gas pedal, stopping construction is the brake, immigration is the early-game boost. The 4-child cap and variable timing handle the rest.

Starting units should include a mix of pre-formed couples and singles to give immediate reproductive potential once the first house is built.

Age demographics must be clearly surfaced in the UI (children / working adults / elders) to prevent Banished's invisible demographic time bomb.

BOARDING HOUSE

A housing building for adults without families. Introduced in Phase 5 alongside the family system. Primary population:

- Clergy (celibate, will never form families)
- Unmarried adults who aged out of parents' home
- New immigrants arriving without families

Individual bed assignment, no family association. No housing bins for food delivery — boarders self-fetch or use the tavern. No furnishing bonuses. Functional but clearly worse than family housing. A roof and a bed, not a home.

Also serves as a safety net for orphans when no relatives have room.

ORPHAN PRIORITY CHAIN

When both parents die, children remain a family. Eldest child becomes head of household. The surname, relationships, and mood effects persist.

Resolution priority:
1. **Relatives with room**: Living grandparents, aunts/uncles. Child joins their family (full member, gets family_id, moves in, takes a bed). Must be under 6-person cap.
2. **Boarding house**: If no relatives have room. Child gets a bed in the boarding house.
3. **Empty home**: Children's family persists and gets assigned to an available empty home. No adults, no skilled labor, no home improvement — the family is intact but struggling. Orphaned mood modifier persists until an adult enters the family or eldest reaches adulthood.
4. **Homeless**: Only when every family is at capacity, no boarding house exists, and no homes are empty. Persistent mood penalty. Winter exposure drains health — survivable in mild conditions, lethal in harsh winter or if already weakened.

Homeless children are always the player's fault in a solvable way. A boarding house is cheap to build. If children are dying of exposure, the player neglected to build one.

ECONOMY

No money system. The communal economy (village produces collectively, units consume based on need and class) is the correct model for this scale. Orphan hardship is expressed through existing mechanics: no adult labor capacity, no skilled production, no home improvement. Money would require wages, prices, and a market economy that touches every production chain — enormous complexity for problems the existing systems already communicate.

External trade (unphased) can work through barter. The currency question can be revisited if external trade design demands it, but should not be assumed.

## Childhood Phases

*Direction established via competitive analysis session. Not yet designed — captures intent and constraints for future design work.*

THREE PHASES OF CHILDHOOD

Children progress through three phases before reaching adulthood at 16. Each phase has class-differentiated behavior.

| Phase | Age | Label |
|---|---|---|
| 1 | 0–5 | Infant |
| 2 | 6–11 | Child |
| 3 | 12–15 | Youth |

**Infant (0–5).** Purely domestic. Infants exist at home, consume food, and play. No productive contribution. Every infant is a direct economic drain on the family's food supply. All classes are identical during this phase.

**Child (6–11), by class:**

- **Serf children:** Light work from SerfChildActivities. Period-accurate (medieval peasant children worked), differentiates them from infants, and creates visible class contrast — serf kids haul berries while freeman kids sit in school.
- **Freeman children:** School. Intelligence growth. The investment phase — non-working child in exchange for better adult attributes.
- **Gentry children:** School or page. Page duty is the gentry equivalent of light work — not economically productive but socially productive. If school grows intelligence and page duty grows charisma, the player has a meaningful choice: scholar/bishop track (intelligence) vs. leader/political track (charisma).

**Youth (12–15), by class:**

- **Serf youth:** Expanded work list beyond child activities, approaching adult capability. Productivity modifier — youth work at reduced speed compared to adults. Visible progression: child serfs do light hauling, youth serfs do real work but slower, adults do full work.
- **Freeman youth:** School continues, or apprenticeship becomes available. Apprenticeship means the youth works alongside a master freeman, gaining specialty skill at a reduced rate. Tradeoff: keep in school for maximum intelligence growth, or apprentice early for a head start on their craft. The player is choosing between generalist education and early specialization.
- **Gentry youth:** School continues, or squire. Squire is the combat preparation track — strength and combat skill growth, attached to a knight if one exists. Choice between intellectual development (school → scholar/bishop path) and martial development (squire → knight path).

Clergy children do not exist (clergy are celibate).

CLASS PIPELINES

- **Serf:** work (light) → work (expanded, reduced speed) → adult serf
- **Freeman:** school → school or apprentice → adult freeman (with or without early skill)
- **Gentry:** school or page → school or squire → adult gentry

TRACK ASSIGNMENT

The player pre-selects which tracks a child will follow at each phase transition. Two controls per child:

- **Current track:** What the child is doing now. Can be changed at any time.
- **Future track:** What the child will do at the next phase transition. Can be changed at any time. Takes effect automatically when the child reaches the next phase boundary.

A 4-year-old infant can have their age-6 and age-12 tracks pre-selected. Decisions don't take effect until the child reaches the relevant age. This lets the player plan ahead for children they care about while leaving others on defaults.

APPRENTICESHIP DETAILS

The apprenticeship track requires a specialty selection (e.g., "apprentice blacksmith"). Ideally also a specific master freeman, though this may not be required. If a freeman youth reaches age 12 with "apprentice (unassigned)" and no specialty has been chosen, they stay in school by default. Nothing breaks if the player forgets.

The squire track benefits from a knight to train under but can function as general martial training at the barracks without one.

DEFAULTS

Class-appropriate defaults so the player only intervenes on exceptions:

- **Serf infant default:** work at 6, expanded work at 12
- **Freeman infant default:** school at 6, school at 12 (apprenticeship is the override, requires choosing a specialty)
- **Gentry infant default:** school at 6, school at 12 (page and squire are overrides)

VILLAGE POLICIES PAGE

A centralized "village policies" panel where the player sets defaults that apply village-wide, with per-unit overrides for special cases. Applies to more than just child tracks:

- Default child tracks per class
- Default serf priority profiles
- Default work day length for new adults
- Potentially default housing assignment preferences

This is the same "works by default, power users optimize" pattern as storage filters and housing assignment. Phase 5+ feature.

CONNECTION TO TRAIT REVEALS

The three childhood phases align naturally with the trait reveal system:

- **Infant (0–5):** Temperamental traits reveal — Hardy, Frail, Stoic, Volatile
- **Child (6–11):** Productivity and social traits reveal — Industrious, Lazy, Gregarious, Solitary
- **Youth (12–15):** Psychological traits reveal — Ambitious, Content, Devout

Each phase of childhood tells the player something new about the unit and gives them new decisions to make. A child who reveals Industrious at age 7 becomes a stronger candidate for freeman promotion. A youth who reveals Ambitious at age 13 creates pressure to plan their advancement.

## Gentry Activities

Currently gentry units idle and consume resources. Future design space exists for gentry-specific activities that provide indirect benefits: hunting, holding court, overseeing the settlement, socializing. These could provide passive bonuses (morale, productivity) without gentry directly participating in the economy.