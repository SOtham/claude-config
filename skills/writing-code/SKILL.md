---
name: writing-code
description: Disciplined procedure for writing or changing code - discover repo conventions first, keep diffs minimal, handle edge cases, verify end-to-end. Use when implementing features, fixes, or refactors.
---

# Writing Code

A procedure for producing correct, reviewable changes in any codebase. Work through the three phases in order; do not skip Phase 1 even for "obvious" changes.

## Phase 1 — Orient (before writing anything)

1. Classify the task: bug fix, feature, refactor, or mechanical. Scale the rest to match — a rename does not need architecture analysis; a bug fix does need root-cause evidence.
2. Read the code you are about to change **and at least one neighbor**: a sibling file, the caller, or an existing test. Extract the local dialect:
   - naming and file organization
   - error-handling style (exceptions vs results, logging levels)
   - test framework and assertion style
   - existing utilities that already solve part of the problem
3. Never introduce a new dependency, pattern, or abstraction without first searching for an existing one. The bar for a new pattern is "the existing one cannot do this", not "I prefer this".
4. For bug fixes: reproduce or otherwise evidence the failure first. State the root cause before writing the fix. If you cannot state it, you are still investigating.

## Phase 2 — Write

- **Minimal diff.** Touch only lines the task requires. Do not reformat, reorder imports, or "improve" adjacent code unless asked.
- **Strong typing** where the language supports it. No untyped escape hatches to save time.
- **Edge cases before happy path.** For every function you touch ask: empty/null input, boundary values, duplicate or concurrent calls, I/O or network failure, partial success. Handle or explicitly reject each.
- **Fail loudly.** Prefer an early, specific error over silently returning a default. Never swallow exceptions without logging.
- **Comments** state only what the code cannot: invariants, units, protocol quirks, links to specs. Never narrate what a line does.
- Keep functions at one level of abstraction; if a function mixes "what" and "how", extract.

## Phase 3 — Verify

1. Build/compile if the project has a build step.
2. Run the tests nearest the change, then the wider suite if cheap.
3. Exercise the change through its real entry point (CLI call, API request, UI flow) — a passing type-check is not verification.
4. Diff review: read your own diff hunk by hunk as a hostile reviewer. Every hunk must be explainable by the task.
5. Report precisely: what you verified (with output), what you did not, and any risk left open. Never claim success you did not observe.

## Anti-patterns

- Speculative generality: interfaces, flags, or config for needs nobody stated.
- Fixing symptoms: patching the call site when the defect is in the callee.
- Big-bang rewrites when incremental edits would do.
- "While I'm here" changes bundled into the diff.
- Retrying a failed command unchanged; each retry needs new evidence.
