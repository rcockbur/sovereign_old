# Sovereign — BRAINSTORMING.md
*v1 · Loosely defined ideas, deferred systems, and content slated for later development. Upload to Claude.ai sessions when relevant.*

---

## Fey Creatures

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

**Notable creature concepts:**
- **Knockers** — mine spirits. Treated well, they warn of cave-ins or improve ore yield. Ignored or disrespected, they cause accidents.
- **Dryads** — tied to specific trees. Chopping their tree turns them hostile — a genuine dilemma when the grove contains needed logs.
- **Will-o-Wisps** — lure units deeper into the forest, potentially triggering more dangerous encounters. A trap mechanic, not a combat creature.
- **Wild Hunt** — an event rather than a creature. A host of spectral hunters riding through the territory at night. Units caught outside are in serious danger.
- **Fey Court** — the political structure behind all Fey.

---

## Christian Supernatural

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

**Notes:**
- **Witches/Warlocks** are mortal NPC spellcasters who have made dark bargains for power. Gender is configurable (see Game Settings). They can summon skeletons and animate the dead.
- **Ghosts** are not malicious but their presence frightens settlers. They have unfinished business.
- **Cursed Ground** is a location-based effect — a tile or building causing ongoing problems until cleansed.
- **Possessed Unit** is one of the player's own settlers, making it uniquely dangerous and dramatic.

---

## Generic Monsters

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

---

## The Changeling Event

A rare, high-stakes event in which the Fey demand a child from the settlement. The player must decide whether to comply. If given, the child returns after a generation, changed unpredictably.

The **Changeling** trait (genetic) would be hidden from the player until discovered. Deliberately unpredictable mechanical effects.

*Specific mechanical outcomes for the returned changeling are undecided.*

---

## Fey Encounter Mechanics

Specific encounter types, bargaining outcomes, Fey Court diplomacy. The Charisma-skilled envoy concept.

*Entirely undefined. Needs dedicated design session.*

---

## Asymmetric Forest Vision

A possible approach for the fog of war system: outside the forest, recursive shadowcasting at normal radius where trees block sight. Inside the forest, reduced sight radius but trees are transparent. Scouts would bypass all vision restrictions. This creates different tactical considerations for units inside vs. outside the tree line.

---

## Combat Mechanics

Military behavior, threat types, combat resolution, unit formations, damage model.

*Core combat mechanics are entirely undefined. Needs dedicated design session.*

### Knight and Training Proposal

The knight is a gentry station. Any unit granted knighthood becomes gentry (along with their spouse and children).

Training as a universal idle fallback: instead of idling, adults without work go to the barracks to train. Units don't need a barracks to train — they practice on their own. A barracks would be an upgrade that improves training effectiveness, staffed by a knight.

Serfs train but only grow strength (they can't learn skills). Freeman+ grow combat skill. This creates a natural difference — serfs get tougher, stationed knights become skilled fighters.

Children cannot train. Barracks has a max_trainees cap. A well-run settlement with efficient supply chains produces more idle time, which means more trained fighters — rewarding good logistics with military readiness.

The entire combat system is deferred until the economy is fully functional without combat.

---

## Magic System Implementation

### Arcane
- Full spell list
- Tech tree structure beyond Alchemy gateway
- Mana generation rates
- Spell costs and effects
- Transmute spell mechanics (first spell unlocked)

### Divine
- Full spell/miracle list
- Vision event trigger conditions (Bishop skill threshold + settlement moment)
- Mana generation rates
- Scripture doctrine choices and their settlement bonuses

### Dark Magic (Enemy Only)
- Enemy spellcaster abilities
- Skeleton summoning mechanics
- Dead animation mechanics

---

## Cathedral and Library Late-Game Details

### Cathedral
- Scripture writing mechanics (menu of repeatable or permanent doctrine choices)
- Whether scripture requires material inputs
- Doctrine bonus effects

### Library
- Full tech tree structure
- Research time scaling
- Multiple Scholar contribution mechanics

---

## Scout Job

Deferred job type. Key properties already decided:
- Always uses full `SIGHT_RADIUS` with trees always transparent regardless of location
- Moves at full speed in forest (exempt from `FOREST_MOVE_MULTIPLIER`)
- Same shadowcasting algorithm as other units, different parameters

*Job tier, attributes, skills, and full mechanical definition pending.*

---

## Trait Effects (Undefined)

- **Touched** — result of direct Fey contact. Effect is ambiguous — may be positive or negative depending on the nature of the contact. *Undecided.*
- **Changeling** — hidden genetic trait. Deliberately unpredictable. *Undecided.*

---

## Deer Mechanics

Deer are wandering creatures that exist on the map and replenish over time. Primary target for the Huntsman job.

*Movement patterns, replenishment rates, hunting interaction mechanics all undefined.*

---

## Animal Husbandry

Livestock, pastures, breeding. Explicitly deferred.

---

## External Trade

Caravans, external economy, trade routes. Scope TBD.

---

## Event Speed Controls

Configurable auto-pause or auto-slowdown for specific event types (unit death, succession, Fey encounter, illness outbreak, unit trapped).

*Event type list and configuration UI pending.*

---

## Apprenticeship System

Freeman children could be appointed as apprentices to a specific station instead of attending school. An apprentice follows a stationed freeman and grows the station's skill, but does not grow intelligence. This creates a tradeoff: schooling produces a generalist (higher intelligence, adaptable to any station), apprenticeship produces a specialist (head start in one skill, but less adaptable).

Apprentices require a mentor — an active stationed freeman in the same role. This system is deferred — for now all freeman and gentry children attend school.

---

## Gentry Activities

Currently gentry units idle and consume resources. Future design space exists for gentry-specific activities that provide indirect benefits: hunting, holding court, overseeing the settlement, socializing. These could provide passive bonuses (morale, productivity) without gentry directly participating in the economy.
