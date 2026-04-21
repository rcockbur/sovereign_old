# Sovereign — Code Audit Prompts

Copy-paste prompts for triggering Claude Code to run a code audit. Each prompt directs Claude Code to read `CODE_AUDIT.md` first, which is the reference document containing calibrations, sanity checks, and finding format.

An audit consists of one or more **per-milestone passes** followed by one **codebase-wide pass**. The number of per-milestone passes depends on context budget — split the milestone range across multiple sessions if a single pass would exceed working capacity.

Each pass appends to a single `AUDIT.md` file at the repo root. Findings accumulate; the running summary at the top is updated after each pass.

---

## Per-milestone pass

Use this prompt for each per-milestone pass. Substitute the milestone range (e.g., M01–M08, M09–M17, M18–M25). Run multiple times with different ranges if the milestone count is large.

```
Audit the current codebase against milestones X through Y. Do not modify any source code. Append findings to AUDIT.md at the repo root, under `## M##` headings, organized by milestone. If AUDIT.md doesn't exist yet, create it.

Before starting, read CODE_AUDIT.md at the repo root in full. It contains the 7 calibrations, the 6 silent per-finding sanity checks, the finding format, and the rationale behind them. Apply these throughout.

Also read CLAUDE.md (full) and ROADMAP.md — particularly Implementation Decisions and Pending Implementation Tasks. A deviation already captured in Implementation Decisions is not a finding.

For each milestone in the range, in order:

1. Re-read the milestone spec in ROADMAP.md.
2. Re-read the docs the milestone cites.
3. Read the code that implements it.
4. Apply the calibrations and sanity checks per finding.
5. Record findings as you go. Do not batch — findings go to disk immediately.
6. After each milestone, write a one-line status (`clean` or `N findings`).

Do not rely on summaries or memory. Re-read.

Be adversarial to the code. The default answer is "something might be wrong here" — justify the absence of findings, don't assume cleanliness. The sanity checks exist precisely to prevent adversarial framing from producing false positives. Apply both.

If unsure whether something is a bug or an intentional choice, record it as a moderate finding with `Suggested action: discuss` rather than skipping.

Do not modify any file other than AUDIT.md. Do not "quickly fix" anything you find, even trivial things.

At the top of AUDIT.md, maintain a running summary: counts per severity and per milestone.

Take as long as you need. This is not a fast task.
```

---

## Codebase-wide pass

Use this prompt once after all per-milestone passes are done.

```
Cross-cutting architectural audit of the full codebase. Per-milestone passes are already done — findings are in AUDIT.md. Read those first to understand what's already been flagged. Do not modify any source code. Append new findings to AUDIT.md under a `## Cross-cutting` heading.

Before starting, read CODE_AUDIT.md at the repo root in full. It contains the 7 calibrations, the 6 silent per-finding sanity checks, the finding format, and the rationale behind them. Apply these throughout.

Also read CLAUDE.md (full) and ROADMAP.md — particularly Implementation Decisions and Pending Implementation Tasks. A deviation already captured in Implementation Decisions is not a finding.

This pass is for issues that aren't tied to a single milestone — patterns that only become visible when looking at the whole system.

Focus areas:

- **Module ownership violations** — modules holding state that belongs on `world`, or reading state they shouldn't own.
- **State duplication** — the same information stored in two places, or two systems driving the same outcome.
- **Bidirectional ref integrity** — every pair listed in CLAUDE.md should be maintained on create and destroy. Walk each pair and verify.
- **Sweep / cleanup correctness** — deferred deletion, inbound ref clearing, registry clearing, swap-and-pop.
- **Registry consistency** — all entities routed through `registry.createEntity`, IDs never reused inappropriately, teardown clears registry on new game.
- **Tile index convention** — all spatial lookups go through `tileIndex` / `tileXY`, no ad-hoc indexing.
- **Config-to-runtime naming** — `default_` stripped correctly on copy.
- **Serialization readiness** — `world` ownership respected, no hidden state in modules, runtime fields on entities are declared in TABLES.md so save/load preserves them.
- **Two-systems-doing-the-same-job smells** — anywhere the code has grown parallel paths that should consolidate.
- **Naming consistency** — same concept named differently in different modules.
- **Convention adherence across the codebase** — snake_case/camelCase, `== false` over `not`, full block formatting, hard failures vs guards.

Be adversarial. Cross-cutting findings are often the most valuable because they're invisible to per-milestone work.

After finishing, update the summary at the top of AUDIT.md to include the cross-cutting counts.

Take as long as you need. This is not a fast task.
```
