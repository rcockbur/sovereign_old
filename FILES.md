# FILES.md — Document System Reference
*v9*

## Documents

Project files split into two tiers based on visibility.

VISIBLE TO CLAUDE CODE

These files are attached to the Claude project and not in `.claudeignore`. Claude Code reads CLAUDE.md at session start; CLAUDE.md routes among them.

- **CLAUDE.md** — Technical hub and routing table for all Tier 1 files. Read this for what's where.
- **ROADMAP.md** — Project planning. (See CLAUDE.md.)
- **BEHAVIOR.md, ECONOMY.md, WORLD.md, TABLES.md** — Simulation files. (See CLAUDE.md.)
- **UI.md** — UI file. (See CLAUDE.md.)
- **CODE_AUDIT.md** — Code audit reference. Loaded by Claude Code only when an audit prompt directs. (See CLAUDE.md.)

VISIBLE ONLY IN DESIGN SESSIONS

These files are attached to the Claude project but excluded from Claude Code via `.claudeignore`. They appear here in design sessions but never in implementation work.

- **FILES.md** — This file. Read at the start of every design session for current project file structure and routing. Otherwise inert.
- **DESIGN.md** — Player-facing design intent: pillars, setting, feature descriptions, the "why" behind gameplay decisions. Consult freely for any discussion of design intent, player experience, or topics in its design routing table. Cross-references the technical files for all mechanical specifics.
- **BRAINSTORMING.md** — Loosely defined ideas, deferred systems, and speculative content. Do not reference unless the user explicitly mentions brainstorming, speculative ideas, or asks about deferred designs. Speculative content may contradict the canonical files; the canonical files always win.
- **CODE_AUDIT_PROMPTS.md** — Copy-paste prompts the user pastes into Claude Code to trigger code audits. Not relevant to design or implementation discussion. Reference only if the user asks about the audit workflow itself.

ADDING A NEW FILE

When a new file enters the project, decide its tier deliberately. Tier 1 if Claude Code needs it during implementation; Tier 2 if it's only useful in design sessions or as user-facing tooling. Update CLAUDE.md's routing table for Tier 1 additions; update FILES.md for Tier 2 additions. Do not duplicate routing across the two files.

## Structure and Formatting

All documents should favor fewer, larger sections over many small ones. Combine related topics under shared headings rather than giving each its own section. The goal is documents that read as cohesive references, not fragmented wikis.

All documents follow the same formatting rules. These rules prioritize readability in plain text editors.

HEADER TIERS

`#` is used once per document for the title. `##` is the only section-level header. No `###` or deeper headers anywhere. Within a `##` section, subsections use ALL CAPS labels on their own line.

INLINE FORMATTING

Bold (`**text**`), italic (`*text*`), bullet lists (`-`), blockquotes (`>`), code blocks, and tables are all fine. No `---` horizontal rules as section dividers.

FILE DELIVERY

When updating project documents during a session, always present the complete revised file so it can be downloaded directly. Do not present partial diffs or fragments that require manual copy-paste into an existing file.

VERSION NUMBERS

Every document has a version number on the subtitle line: `*v1*` if standalone, or `*v1 · subtitle text*` if the file has a subtitle. Bump the version each time the file is delivered in a session. If multiple deliveries happen in one session (e.g., a fix after the first delivery), each delivery increments. Version numbers are per-file — files update independently.

## Content Boundary: Design vs Technical

The primary failure mode is DESIGN.md accumulating restated mechanics — not as config tables or code, but as prose descriptions of system behavior. Use this test on every sentence written into DESIGN.md:

**Design litmus test:** Does this sentence describe *what the player experiences or why the system exists*? → DESIGN.md. Does it describe *what the system does mechanically* — behavior rules, state transitions, trigger conditions, formulas, data flow, implementation constraints? → technical files, regardless of whether it uses code formatting. Does it name a UI element (panel, button, toolbar) or an input action (click, drag, key press)? → UI.md, regardless of how high-level it sounds.

When a DESIGN.md section needs to reference how a system works, use a one-line summary of the design intent followed by a cross-reference to the specific technical file and section. Do not restate the mechanics in different words.

DESIGN ROUTING TABLE

This table defines what DESIGN.md owns versus what the technical files own, per topic. When writing or auditing DESIGN.md, check this table — if a sentence covers the right column, it belongs in the technical files.

| Topic | DESIGN.md owns (intent, player experience) | Technical files own (mechanics, rules, values) |
|---|---|---|
| Classes | Why four classes exist, social structure flavor, cost of elevation | Promotion rules, needs tiers, activity filtering, children behavior |
| Specialties | Career concept, player assigns specialties, dynamic work-finding as player experience | Skill growth formula, activity queue polling, specialty revocation, activity effectiveness |
| Needs | Three needs as pressure to stop working, starvation as failure mode | Drain rates, thresholds, interrupt firing conditions, availability gating |
| Mood | Composite score concept, what drives it, productivity/deviancy consequences | Modifier values, threshold config, recalculation rules, food variety formula |
| Health | Injury/illness/malnourishment as threats, death at 0 | Damage rates, recovery rates, illness config |
| Economy | Production chain rationale, food fungibility, storage progression, storage filters as player tool | Resource entities, containers, reservations, resource counts, unit work cycles, self-fetch/deposit |
| Designation | Bootstrap role, player's first tool, relationship to building-based gathering | Activity posting, tile claiming, work cycle (BEHAVIOR.md), UI interaction (UI.md) |
| Farming | Crop risk/reward tradeoffs, seasonal personality, harvest timing as player agency | Per-tile crop state, frost mechanics, farm controls, farm activity posting, maturity formula |
| Buildings | Interior spaces, rotation, housing types, construction phases as player experience, site clearing, deletion consequences | Tile maps, layout positions, clearing, placement validation, construction phases, A* building exemption, pathfinding integration, site clearing activities, unit displacement, deletion cleanup sequence |
| Storage | Stockpile/warehouse/barn progression and why each exists | Capacity values, filter system, container types, tile inventory vs stack/item inventory |
| Merchant | Market as infrastructure milestone, food delivery concept, skill effect | Merchant loop, critical/standard runs, route order, drop amount, thresholds |
| Map | Settlement vs forest, procedural generation from seed, forest as mysterious | Dimensions, terrain types, generation pipeline, forest depth formula |
| Forest | Resource tiers by depth, atmosphere, inhabitants | Coverage percentages, plant types, growth/spread mechanics, movement costs |
| Pathfinding | (not in DESIGN.md) | A*, tile costs, movement model, speed formula, collision |
| Storage Filters | Storage filters as optional logistics tool, both playstyles work | Filter modes, pull mechanics, source resolution, cycle detection, activity selection |
| Dynasty | Leader as through-line, succession as drama, heir readiness | (succession traversal mechanics pending) |
| Traits | Permanent tags, rarity, all have mechanical effects | (trait config values pending) |
| Equipment | Degradation creates ongoing demand, units self-fetch | Equipment want checks, soft interrupt, fetch flow, durability drain |
| Events | Sunday service, funerals, marriage as player experiences | (event scheduling mechanics pending) |
| Magic | Late-game emergence, divine vs arcane distinction, progression paths | Mana structures, unlock conditions, (spells/rates pending) |
| Time | Seasonal cadence, player controls pacing, game start conditions | Constants, tick system, calendar derivation, frost day rolls |
| Aging | Faster than real time, generational play | Aging constants, death age, seasonal aging |
| Naming | Cultural flavor, surname inheritance reinforces dynasty | Name lists (TABLES.md), generation rules (CLAUDE.md) |

## Content Boundary: Between Technical Files

CLAUDE.md's technical routing table is the sole authority for which technical file owns which content. When mechanical content needs to be written or moved, consult the technical routing table in CLAUDE.md. Do not duplicate mechanical content across technical files — if one file needs to reference another's content, use a brief cross-reference.

## Document Update Procedure

Do not begin updating documents until explicitly asked. Stating a session's intent (e.g., "let's discuss X so we can update the files") is not permission to update — wait for an explicit directive like "update the files." When unsure which files need updating or whether all changes are covered, ask before proceeding.

After a design session, update the documents that changed:

1. **Route each decision.** Design intent → DESIGN.md. Mechanical detail → the relevant technical file per the technical routing table in CLAUDE.md. Most decisions produce content for both sides.
2. **Write the technical file(s) first.** The technical files are the source of truth for how things work. Most sessions touch one domain file; some touch two. TABLES.md changes are usually surgical edits to specific structures or config entries.
3. **Write DESIGN.md second.** For each updated section, check the design routing table — if a sentence covers the technical column, replace it with a design-intent summary and a cross-reference.
4. **Verify.** Scan DESIGN.md for sentences that describe behavior rules, state transitions, trigger conditions, data flow, or that name specific UI elements or input actions. Move or delete.

## Audit Directive

This section covers **document audits** — checking the spec docs themselves for boundary violations, redundancy, and inconsistency. For **code audits** (checking the codebase against the spec), see CODE_AUDIT.md.

Do NOT reference Claude's memories of past sessions — memories may be outdated. The documents are the sole source of truth.

**"Audit the files"** checks for boundary violations only. Apply the design litmus test to every sentence in DESIGN.md. Flag mechanical detail and UI-element language that has crept into DESIGN.md. Require quoted evidence for each finding.

**"Audit the files carefully"** checks all five categories, across and within all documents:

1. **Boundary violations.** Apply the design litmus test to DESIGN.md. Flag mechanical detail and UI-element language in DESIGN.md, and design intent restated in technical files.
2. **Redundancy.** Content that appears in two places — across files or within the same file. One location should own each piece of information.
3. **Inconsistency.** Contradictions — differing values, conflicting rules, or systems described differently in two places.
4. **Architectural problems.** Design gaps, unresolved questions that block implementation, or systems whose descriptions have drifted from the current design direction.
5. **Bloat and structure.** Verbose prose, sections that could be shorter, information that duplicates what the code already expresses (once implemented).

Present findings as a categorized list with specific references (file name, section, and the problematic text). Propose concrete fixes.

After all findings are resolved, stop and ask before producing updated files. The document update rule applies here too — do not begin writing files until explicitly asked.
