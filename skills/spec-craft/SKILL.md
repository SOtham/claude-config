---
name: spec-craft
description: Write singular, unambiguous, testable requirements and keep them true - EARS phrasing, REQ-IDs, traceability to tests. Use when writing a spec or acceptance criteria, or when code and spec disagree.
---

# Spec Craft

The *what*, written so it can be verified: every requirement states one behavior that a test can fail. `brainstorm` elicits what people want, this states it precisely, `architect` decides how to build it. A requirement no test can fail is not a requirement — it is a wish.

## When a spec is worth it

Write one when the change is **expensive to reverse** (schema, public API, pricing or permission rules), **crosses an interface** someone else depends on, or has a **second consumer** who must agree to it. Otherwise state the acceptance criteria inline and go to `writing-code`: spec ceremony on a one-field change buys nothing, and wasted overhead on small tasks is the most common and best-founded criticism of spec-driven work. Scale the artifact to the change — a spec is a numbered list of requirements plus what is out of scope, not a document with a cover page.

## Writing the requirement

Use **EARS** (Easy Approach to Requirements Syntax), five templates that keep natural language unambiguous; keywords combine for compound conditions ("WHILE `<state>`, WHEN `<trigger>`, the `<system>` shall …"):

| Pattern | Template | Use for |
| --- | --- | --- |
| Ubiquitous | The `<system>` shall `<response>` | always-true properties |
| Event-driven | WHEN `<trigger>`, the `<system>` shall `<response>` | reactions to an event |
| State-driven | WHILE `<state>`, the `<system>` shall `<response>` | behavior during a mode |
| Optional feature | WHERE `<feature is included>`, the `<system>` shall `<response>` | variant-only behavior |
| Unwanted behavior | IF `<trigger>`, THEN the `<system>` shall `<response>` | errors, abuse, failure paths |

Then apply the well-formedness rules (ISO/IEC/IEEE 29148:2018 characteristics of an individual requirement):

- **Singular** — one behavior per requirement; an "and" in a requirement is usually two requirements.
- **Verifiable** — name the observable output or effect. Barred until quantified: *gracefully, fast, robust, secure, user-friendly, appropriate*.
- **Unambiguous** — one possible reading. Define any term that could mean two things once, at the top.
- Give every requirement a stable ID (`REQ-001`) — IDs are what tests, tasks, and commits cite.
- State **out of scope** explicitly; the cheapest requirement is the one written down as excluded.
- Cover failure paths, not just the happy path — that is what the IF/THEN row is for.

**MUST NOT guess an unknown.** Write `[NEEDS CLARIFICATION: <the question>]` where the requirement would go, and surface it. A guess that reads like a requirement is the most expensive defect the file can carry, because everything downstream treats it as agreed.

## Confirm before it is the contract

The requirement list MUST be confirmed by whoever owns the outcome before design starts, and every `[NEEDS CLARIFICATION]` MUST be closed by an answer rather than by a later assumption. Reason: models are measurably weaker at writing specifications than at writing code (CodeSpecBench 2026 measured 21.0% vs 77.2% for the strongest model on executable behavioral specs — Inference when applied to natural-language requirements, but it points one way), so an unreviewed model-authored spec is the weakest link, and design, tasks, and tests all inherit its errors.

## Keeping it true

A drifted spec is worse than none: the reader with no spec investigates, the reader with a stale one acts on it (stale-doc doctrine: `doc-craft`).

- Each requirement names the test that proves it; each test cites the `REQ-ID` it covers (`test-craft` owns how that test is written). Both directions, or coverage is a guess.
- An **orphan requirement** (no test) and an **orphan test** (no requirement) are both defects — write the missing one or delete the dead one.
- Any behavior change updates or retires its requirement **in the same commit**; a deferred spec update does not happen.
- Retire by deleting, not by marking obsolete — git holds the history.
- Where the interface allows it, make the requirement executable (schema, contract test, property test). An executable requirement cannot drift silently.

## Anti-patterns

- Volume as rigor: pages of prose no test ever consumes.
- Requirements that specify implementation ("shall use a Redis cache") — that is `architect`'s decision, and stating it here forecloses it.
- A spec written after the code to rubber-stamp it; that is a summary, so label it as one.
