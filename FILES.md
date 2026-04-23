# FILES.md — Document System Reference
*v13*

## Documents

Project files split into two tiers based on visibility.

TIER 1 — VISIBLE TO CLAUDE CODE

These files are attached to the Claude project and not in `.claudeignore`. Claude Code reads CLAUDE.md at session start; CLAUDE.md is the routing table that defines what belongs in each Tier 1 file.

- **CLAUDE.md** — Technical hub and routing table for all Tier 1 files. Read this for what's where.
- **ROADMAP.md** — Project planning. (See CLAUDE.md.)
- **BEHAVIOR.md, ECONOMY.md, HAULING.md, WORLD.md, TABLES.md** — Simulation. (See CLAUDE.md.)
- **UI.md** — User interface. (See CLAUDE.md.)
- **DEV.md** — Dev tools, testing infrastructure, and config validation. Loaded by Claude Code only when work touches those systems. (See CLAUDE.md.)
- **CODE_AUDIT.md** — Code audit reference. Loaded by Claude Code only when an audit prompt directs. (See CLAUDE.md.)

TIER 2 — VISIBLE ONLY IN DESIGN SESSIONS

These files are attached to the Claude project but excluded from Claude Code via `.claudeignore`. They appear here in design sessions but never in implementation work.

- **FILES.md** — This file. Read at the start of every design session for current project file structure and routing. Otherwise inert.
- **DESIGN.md** — Player-facing design intent: pillars, setting, feature descriptions, the "why" behind gameplay decisions. Consult freely for any discussion of design intent, player experience, or related topics. Cross-references Tier 1 files for all mechanical specifics.
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

## Content Boundary

DESIGN.md owns the game as the player experiences and imagines it. Tier 1 owns the machine that produces it — including the technical reasoning behind how it's built. Systems with no player-facing intent have no DESIGN.md presence.

**Design litmus test:** Is this sentence addressed to a reader thinking about the game — what it feels like to play, what the player faces, why features exist from the player's seat? → DESIGN.md. Is it addressed to a reader building the game — mechanics, numbers, UI elements, technical rationale? → Tier 1, regardless of formatting or how high-level it sounds.

When DESIGN.md needs to reference how a system works, use a one-line summary of the design intent followed by a cross-reference to the specific Tier 1 file and section. Do not restate the mechanics in different words.

Within Tier 1, the routing table in CLAUDE.md governs which file owns which content. Do not duplicate mechanical content across Tier 1 files; cross-reference instead.

## Document Update Procedure

Do not begin updating documents until explicitly asked. Stating a session's intent (e.g., "let's discuss X so we can update the files") is not permission to update — wait for an explicit directive like "update the files." When unsure which files need updating or whether all changes are covered, ask before proceeding.

After a design session, update the documents that changed:

1. **Route each decision.** Design intent → DESIGN.md. Mechanical detail → the relevant Tier 1 file per the routing table in CLAUDE.md. Most decisions produce content for both sides.
2. **Write the Tier 1 file(s) first.** Tier 1 files are the source of truth for how things work. Most sessions touch one file; some touch two. TABLES.md changes are usually surgical edits to specific structures or config entries.
3. **Write DESIGN.md.** Apply the litmus test to every new sentence; anything that fails becomes a design-intent summary with a cross-reference to the relevant Tier 1 file.

## Audit Directive

This section covers **document audits** — checking the spec docs themselves for boundary violations, redundancy, and inconsistency. For **code audits** (checking the codebase against the spec), see CODE_AUDIT.md.

Do NOT reference Claude's memories of past sessions — memories may be outdated. The documents are the sole source of truth.

The primary failure surface is the Tier 1 files: drift, ambiguity, and internal contradiction accumulate there over time. DESIGN.md boundary violations are a real but secondary concern.

**"Audit the files"** checks all categories across all documents, grouped by severity:

CORRECTNESS — these issues corrupt implementation

1. **Inconsistency.** Contradictions across files or within a file — differing values, conflicting rules, or systems described differently in two places. Highest priority because Claude Code will pick one side and generate bugs.
2. **Stale content.** Descriptions that no longer match the current design. Remnants of superseded approaches that linger after partial redesigns.
3. **Gaps and ambiguity.** Systems described but not fully specified; implementation would have to guess. Open questions not flagged as open.
4. **Boundary violations.** Content in the wrong file. Apply the design litmus test to DESIGN.md in both directions (mechanics leaking into DESIGN.md, design intent restated in Tier 1). Check Tier 1 content against CLAUDE.md's routing table.

HYGIENE — these issues affect only document quality

5. **Redundancy.** Same content in two places when one location should own it.
6. **Bloat.** Verbose prose, sections that could be shorter, or information that duplicates what code already expresses once implemented.

Present findings as a categorized list with specific references (file name, section, and the problematic text). Propose concrete fixes. Work through findings one at a time, waiting for explicit approval before applying each fix. After all findings are resolved, stop and ask before producing updated files. The document update rule applies here too — do not begin writing files until explicitly asked.
