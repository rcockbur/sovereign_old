# Sovereign — Code Audit Reference

This document is the reference Claude Code consults when conducting a code audit. It is loaded by the audit prompt — see `CODE_AUDIT_PROMPTS.md` for the prompts that trigger an audit and reference this document.

The audit checks whether the code matches the spec, whether the spec matches the code, and whether either contains drift, gaps, or inconsistencies that should be addressed. Document audits (the inverse — checking whether the spec is internally coherent) are a separate process and not covered here.

This document is expected to evolve. Each audit reveals new patterns. After running an audit, revise this document if the experience surfaces calibrations that should be added, removed, or sharpened.

---

## The 7 calibrations

These are principles that apply throughout the audit. Internalize them before starting.

### 1. Read ROADMAP Implementation Decisions as part of the spec corpus

The ROADMAP § Implementation Decisions section records deliberate, documented divergences from the original spec. Before flagging any code/spec mismatch, check whether it's already documented as a decision. If it is, no finding is needed.

### 2. Cross-reference between spec files before flagging undocumented fields

A field can be declared in TABLES.md and described in BEHAVIOR.md/ECONOMY.md/WORLD.md, or vice versa. Before flagging "field X is in code but not in spec," check all relevant spec files. The field may already be documented in a different file than expected.

### 3. Treat documented project conventions as binding rules

CLAUDE.md § Conventions defines project-wide rules: snake_case/camelCase naming, `== false` instead of `not`, full block style, swap-and-pop for array removal, hard failures over silent ones. Code that violates these is wrong against spec. Findings about convention violations are correctness issues, not nice-to-have improvements.

### 4. Distinguish forward-dependency findings from current bugs

Some findings are bugs now. Others are hypotheticals about what will happen when a future milestone lands. The two need different actions.

**Rule:** If the spec correctly gates the future state (e.g., BEHAVIOR.md § Tick Order shows where new calls go when sweeps are added), the future implementer will read the spec and do the right thing. Defensive stubs and TODO comments duplicate the spec without adding enforcement. Default to ignore for these findings.

**Counter-rule:** If the bug is dormant but the spec doesn't gate when it activates, fix now. Example: a placement validator that rejects a valid terrain type — the bug is dormant if that terrain doesn't exist yet, but no spec gate prevents it from manifesting once it does.

### 5. Don't suggest fixes that legitimize hacks or weaken invariants

When an assertion fires correctly, the architecture is working. The bug is in the caller, not in the assertion. Fix the caller; don't add bypass parameters, fallback paths, or "for consistency" exceptions.

Pattern recognition: when a suggested fix reads "for consistency, change X to match Y" or "add a parameter to allow Z" — pause and check whether the inconsistency reflects real semantic divergence, and whether the parameter would erode a working safeguard.

### 6. The "undocumented decision" framing is over-applied — check the spec carefully

Many findings that look like undocumented decisions are actually:

- **Spec gaps the audit didn't read** (the relevant spec section exists; it just wasn't checked).
- **Spec self-contradictions** where the implementation correctly resolved one of two contradictory parts. The fix is to repair the spec contradiction, not document a "decision" that was already implicit.
- **Implementation hygiene that doesn't belong in spec** (debug flags, internal helpers, log file paths). These should be ignored, not documented.

Before framing a finding as "the implementation made a choice the spec didn't sanction," confirm the spec actually didn't sanction it. Search the spec corpus for the relevant section.

### 7. Split or bundle findings deliberately

Each finding should cover one concern with one suggested action. Watch for:

- **Bundled findings** — one finding number covering multiple unrelated changes. Forces a binary outcome on the pair when the changes might warrant different responses.
- **Split findings** — same issue described from two angles, given two finding numbers. Inflates the finding count and creates ambiguity.

Before recording a finding, ask: "is this one decision or two?" If two, split. If two findings would have the same resolution, merge.

---

## The 6 sanity checks (silent, per-finding)

Apply these to every finding before recording it. They run silently — the checks themselves never appear in finding output. They exist to catch the recurring failure modes at the moment of decision rather than as post-hoc review.

A finding that fails any check should be reframed or dropped, not recorded as originally drafted.

1. **Citation check** — does the spec text the finding cites actually exist in the file at the location given? If no, the finding is a false alarm. Drop or reframe.

2. **Decision check** — has this been logged as an Implementation Decision in ROADMAP? If yes, no finding is needed.

3. **Cross-file check** — is the field/concept declared or described in another spec file? If yes, the finding is a cross-reference issue, not an undocumented one. Reframe accordingly or drop.

4. **Convention check** — does this violate a documented convention in CLAUDE.md? If yes, frame as correctness against project conventions.

5. **Forward-vs-now check** — does the bug manifest now, or only when a future milestone lands? If only future, and the spec gates the future state correctly, default to no finding.

6. **Suggested-fix check** — would the suggested fix legitimize a hack or weaken an invariant? If yes, replace the suggested fix with one that preserves the invariant (typically: fix the caller, not the API).

---

## Finding format

Each finding includes:

- **Severity:** critical | moderate | minor
- **File:line** (or file range, or doc:section for spec-only findings)
- **Spec reference:** doc + section, or "spec silent" if genuinely silent after sanity checks 2 and 3 confirm
- **Finding:** one sentence
- **Evidence:** the relevant code excerpt or behavior
- **Suggested action:** fix code | tighten spec | ignore | discuss
- **Rationale:** one sentence explaining why this action

The action hypothesis is the audit's best guess at the resolution. The reviewer (the project owner) confirms or overrides. Brief rationale lets the reviewer evaluate without re-deriving context.

---

## Recurring failure modes (rationale for the calibrations and sanity checks)

This section explains *why* the calibrations and sanity checks exist. Not part of the per-finding process — context only.

These are the recurring miscalibrations observed in past audits. Each one motivates one or more of the 7 calibrations and 6 sanity checks above.

**Audit doesn't read ROADMAP Implementation Decisions.** Documented decisions get re-flagged as drift. (Calibration 1, sanity check 2.)

**Audit doesn't cross-reference between spec files.** A field declared in one file and described in another gets flagged as undocumented when only one file is checked. (Calibration 2, sanity check 3.)

**Audit downgrades convention violations to "Improvements."** Convention violations are correctness issues. The downgrade reduces visibility and lets real bugs accumulate as low-priority cleanup. (Calibration 3, sanity check 4.)

**Audit treats forward-dependency hypotheticals as current bugs.** When the spec correctly gates the future state, defensive stubs are duplicates with no enforcement value. The spec is the safety net. (Calibration 4, sanity check 5.)

**Audit suggests fixes that legitimize hacks or weaken invariants.** Bypass parameters, fallback paths, "for consistency" changes that erode safeguards. The bug is usually in the caller, not the API. (Calibration 5, sanity check 6.)

**Audit over-applies "undocumented decision" framing.** Used as a default when the actual issue is spec gap, spec self-contradiction, or implementation hygiene that shouldn't be in spec. (Calibration 6.)

**Audit miscites spec sources.** A finding cites "UI.md § Camera" but the cited text is actually in ROADMAP milestone descriptions, not UI.md. The reviewer can't distinguish actual spec violations from confused citations without manual verification. (Sanity check 1.)

**Audit bundles or splits findings inconsistently.** One finding covers multiple unrelated changes; another splits one issue across two finding numbers. Both make the count and the resolution path ambiguous. (Calibration 7.)

---

## Empirical observation: dense spec → zero findings

In the p1m01–p1m17 audit, M15 (chop designation + tree felling) returned zero findings. The corresponding spec coverage in BEHAVIOR.md § Gathering Work Cycle and UI.md § Designation was unusually detailed and precise. The implementer had no surface to drift on.

Implication: spending more time on spec precision *before* implementation reduces audit findings *after* implementation. Not an audit guideline per se, but the strongest signal from past audits about where to invest effort on future systems.
