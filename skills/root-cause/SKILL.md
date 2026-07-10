---
name: root-cause
description: Systematic debugging - reproduce, isolate by bisection, trace the dependency chain, prove the cause before fixing. Use when investigating bugs, test failures, regressions, or weird behavior.
---

# Root Cause

A four-phase method for finding *why* something breaks. Speculative fixes are forbidden: never ship a fix you cannot explain.

## Phase 1 — Capture, then reproduce

- Record the evidence verbatim first: exact error text, stack trace, failing input, environment, timestamps. Paraphrased errors lose the clue half the time.
- Build the smallest deterministic reproduction you can — smallest input, fewest steps, no unrelated services. A minimal repro is half the fix and becomes the regression test.
- "Cannot reproduce" is a finding, not a dead end: add targeted instrumentation at the suspected boundary and let the next occurrence report itself.

## Phase 2 — Isolate by bisection

Halve the search space repeatedly instead of reading everything:

- **Time**: when did it last work? `git bisect` over commits; diff configs/dependency versions between working and broken.
- **Space**: cut the pipeline in half — is the data already wrong at the midpoint? Move the probe until the corruption boundary is found.
- **Input**: shrink the failing input until removing anything more makes it pass.

Change **one variable at a time**; a two-variable experiment proves nothing. Prefer adding one precise log/probe over guessing from re-reading code.

## Phase 3 — Explain

- Trace *up* the dependency chain: the crash site is rarely the defect site. Follow the bad value backwards to the first place it was wrong.
- Distinguish **trigger** (the deploy, the unusual input) from **cause** (the latent defect it exposed). Fixing only the trigger leaves the mine in the field.
- The gate: your explanation must account for **all** symptoms — the failures *and* the cases that still pass, and the timing of when it started. An explanation that covers only one symptom is a hypothesis, not a cause.
- State the root cause in one sentence before writing any fix. If you can't, you're still in Phase 2.

## Phase 4 — Fix and harden

1. Smallest fix that addresses the cause (not the symptom).
2. Add the regression test: watch it fail on the old code, pass on the fix.
3. Hunt siblings: the same defect class usually exists elsewhere — grep for the pattern you just fixed.
4. Ask what let this escape: missing validation, missing test, misleading API? Fix the cheapest layer of that too, or note it.

## Discipline

- Keep a terse investigation log (hypothesis → test → result); it prevents circling and makes the handoff free.
- Three identical failed fix attempts means the model of the problem is wrong — return to Phase 1 with fresh evidence, don't iterate on the same guess.
- Beware "it works now": if nothing you did explains the recovery, the bug is still there, hiding.
