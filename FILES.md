# FILES.md — Document System Reference

This project uses three living documents. When asked to update the documents, generate updated versions of all three as appropriate based on decisions made in the session.

---

## CONTEXT.md
**Audience:** Claude (chat session)
**Purpose:** Coding reference for active development sessions. Contains conventions, constants, module ownership, tick order, data structures, config tables, and architectural decisions with rationale.
**Update trigger:** Any session that changes or adds technical decisions, data structures, constants, or implementation patterns.

## DESIGN.md
**Audience:** Claude (chat session)
**Purpose:** Design intent and narrative systems. Contains pillars, feature descriptions, pending design sections, and the "why" behind gameplay decisions.
**Update trigger:** Any session that changes or adds design decisions, systems, or pending items.

## CLAUDE.md
**Audience:** Claude Code (VS Code extension, lives in the repo)
**Purpose:** Actionable coding reference for in-editor assistance. A tighter subset of CONTEXT.md — conventions, constants, data structures, module ownership, and architectural decisions as directives. No rationale, no narrative. Optimized for code generation and completion.
**Update trigger:** Any session that changes conventions, constants, data structures, or module ownership. Rationale changes in CONTEXT.md do not require a CLAUDE.md update.
