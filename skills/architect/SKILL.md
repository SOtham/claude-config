---
name: architect
description: Produce a structured implementation plan before large changes - objectives, files affected, risks, edge cases, validation. Use for architecture, migrations, API changes, or work touching 3+ files.
---

# Architect

Use this before any change that is expensive to reverse: architecture, migrations, public API or schema changes, security-sensitive work, infrastructure, or anything touching 3+ files. Output a plan, get explicit confirmation, then execute.

## Step 1 — Bound the problem

- Restate the goal in one sentence, plus explicit non-goals.
- List the hard constraints: compatibility promises, performance budgets, deadlines, tech already mandated by the repo.
- Explore just enough code to know the blast radius: entry points, data flow through the affected area, who consumes what you will change. Timebox this; you need the shape, not every line.

## Step 2 — Compare options (2–3, no more)

For each candidate design, one short block:

- **Sketch**: components and data flow in a few lines.
- **Wins / costs**: complexity, migration effort, performance, operability.
- **Failure modes**: what breaks first under load, partial failure, or bad input.

Then commit: name the chosen option and the deciding reason in one sentence. Do not present a menu without a recommendation.

## Step 3 — Write the plan

Emit under this exact heading:

`## Proposed Architecture & Implementation Plan`

- **Objectives** — measurable outcomes, plus non-goals.
- **Files affected** — every file created/modified/deleted; group by step.
- **Potential breaking changes** — API/schema/config/behavior; who is affected and the migration path for each.
- **Risks** — likelihood × impact, with a mitigation or early-warning signal per risk.
- **Edge cases** — data, timing, permissions, rollback-mid-migration.
- **Validation strategy** — how each objective is proven: tests, staged rollout, monitoring signal.
- **Token-saving strategies** — what you will avoid re-reading, what gets delegated to subagents.

Sequence the work in increments that each leave the system working; big-bang cutovers need explicit justification.

## Step 4 — Gate and execute

- Wait for explicit confirmation before touching code. Silence is not consent.
- While executing, when reality contradicts the plan (an assumed API doesn't exist, hidden coupling appears), stop and update the plan rather than improvising silently.
- Close by verifying the Validation strategy items and reporting each as done or not done.

## Rules of thumb

- Prefer boring technology already in the repo; novelty must pay rent.
- Design for deletion: the best module is one that can be removed cleanly.
- Every abstraction must have at least 2 real (not hypothetical) users.
- Rollback is part of the design, not an afterthought — know the undo for each step before doing it.
