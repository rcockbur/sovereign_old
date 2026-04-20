Note the current phase scope paragraph, then 
find milestone $ARGUMENTS.

Read the files and sections listed in the milestone's Docs: line.
CLAUDE.md is already loaded — only read the others.

Identify which Pending Implementation Tasks entries apply to this 
milestone — both forward dependencies this milestone must satisfy 
and cleanup obligations that should be resolved here.

Once you've read the spec, ask the user any questions you have 
about implementation, including which pending tasks you've 
identified as applicable. After all questions are resolved, say 
you're ready to implement and ask for permission.

Once permission is granted, implement the milestone according to 
its spec, following the conventions in CLAUDE.md for 
Implementation Decisions, Pending Implementation Tasks, and TEMP 
markers.

When done:
- Update Implementation State in ROADMAP.md (pxmy format).
- Run the milestone's Verify: step.