---
name: test-craft
description: Test-driven development and test quality - red-green-refactor, characterization tests, async flakiness fixes, anti-patterns like weakening tests to pass. Use when writing tests or doing TDD.
---

# Test Craft

How to write tests that catch bugs instead of confirming code, and how to run a real TDD loop.

## The iron rule

When a test fails, there are exactly two honest moves: **fix the code**, or **fix a genuinely wrong test** (and say why it was wrong). Weakening an assertion, widening a tolerance, deleting a case, or mocking away the failure to get to green is falsifying evidence. If tempted, the test just did its job — listen to it.

## The TDD loop

1. **Red** — write one failing test for the next small behavior. Run it and *watch it fail for the right reason*; a test that fails with a typo error proves nothing.
2. **Green** — write the minimum code to pass. Resist implementing ahead of the tests.
3. **Refactor** — clean up code *and tests* only while green; commit.
4. Repeat in small increments. If a test takes more than a few minutes to make pass, the step was too big — back up and split it.

TDD pays most for: pure logic, parsers, pricing/permission rules, bug fixes (regression test first — watch it fail on the old code, pass on the fix). It pays least for: exploratory spikes and thin UI glue; don't force it there.

## Test quality bar

- One behavior per test; the name is a sentence stating that behavior.
- Arrange–Act–Assert with the assert focused: prefer one strong assertion over ten weak ones.
- Test the contract (inputs → observable outputs/effects), not the implementation. If a refactor with identical behavior breaks the test, the test was wrong.
- Each test independent and order-agnostic: no shared mutable fixtures, no reliance on prior tests.
- Cover the edges deliberately: empty/null, boundaries, duplicates, failure paths — not just the happy path.

## Async and flakiness

Never `sleep` and hope. Wait on **conditions**: poll for the state/element/message with a timeout, fail with a message saying what condition never became true. A flaky test is a bug — quarantine and root-cause it (shared state, timing, external dependency); don't retry-until-green.

## Legacy code: characterization tests

Before changing untested code, pin its *current* behavior: feed it representative inputs, assert whatever it actually does today — bugs included, marked with a comment. These tests are a tripwire for unintended change, not a spec. Once they're green, refactor or fix with confidence (see `refactor-safely`).

## Anti-patterns

- Mocking so much the test only exercises the mocks.
- Snapshot tests as a default — they assert "something changed", which trains everyone to approve blindly.
- Asserting on log output or private state.
- Chasing coverage percent instead of risk: 100% coverage with weak asserts is worse than 70% with sharp ones.
