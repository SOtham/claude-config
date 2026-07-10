---
name: refactor-safely
description: Behavior-preserving refactoring of legacy or working code - characterization tests first, small reversible steps, strangler pattern. Use when restructuring code without changing what it does.
---

# Refactor Safely

Refactoring changes structure, **never behavior**. The moment behavior changes on purpose, it's a feature or a fix — plan it as one. This skill is for reshaping code that works.

## Step 0 — Build the safety net

No net, no refactor:

- Existing tests cover the area and pass → proceed.
- No meaningful tests → write **characterization tests** first: feed the code representative inputs (including weird ones) and assert whatever it *actually does today*, current bugs included (mark those with a comment). They are a tripwire for unintended change, not a spec.
- Truly untestable code → extract the smallest seam that makes it testable; that extraction is your first refactor, done with extra care.

Record any bugs you discover — fix them in separate commits *before or after*, never mid-refactor.

## The loop: small, mechanical, reversible

1. One named, mechanical transformation at a time: rename, extract function/module, inline, move, replace conditional with polymorphism.
2. Run the tests after each step. Green → commit immediately with the transformation as the message ("extract PriceCalculator from OrderService"). Red → **revert the step**, don't debug forward; a failed refactor step means you misunderstood the code.
3. Prefer automated refactors (IDE / language-server rename, extract) over hand-editing — they don't make typos across 40 call sites.

The commit trail should read as a sequence of obviously-safe moves. If a single step can't be described in one sentence, it's too big — split it.

## Large-scale replacement: strangler fig

To replace a subsystem, don't big-bang rewrite:

1. Build the new implementation alongside the old, behind the same interface.
2. Route traffic incrementally (by feature flag, by caller, by case), comparing outputs where feasible.
3. Delete the old path only when nothing routes to it. Deleting dead code is the last, most satisfying commit.

Every intermediate state ships and works; there is never a "don't touch anything for three weeks" branch.

## Knowing when to stop

- Stop at the boundary of the task: reshaping what you needed to touch is refactoring; continuing into code you don't understand "while you're here" is risk without payoff.
- Stop when steps stop being mechanical — needing to *reason hard* about whether behavior is preserved means you've left refactoring and entered rewriting; go get requirements and tests.
- Done means: identical behavior (tests prove it), better shape (you can state the improvement in one sentence), and a diff trail a reviewer can trust step by step.
