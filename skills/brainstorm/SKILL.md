---
name: brainstorm
description: Socratic requirements elicitation before any code or plan - question rounds, alternatives, captured decisions. Use when a request is vague, greenfield, or before committing to a design.
---

# Brainstorm

Upstream of planning: turn a vague request into agreed requirements *before* any code or architecture work. The most common failure in agent-assisted development is building the wrong thing fast; this skill prevents it. Hand off to `architect` once decisions are captured.

## The question rounds

Ask in rounds, a few questions at a time — never one giant interrogation, never zero questions.

**Round 1 — Intent**: What problem does this solve, and for whom? What does success look like (observable, ideally measurable)? What already exists that this replaces or extends?

**Round 2 — Constraints**: What must it integrate with? What data does it touch, and who owns that data? Performance, budget, deadline, or compliance limits? What is explicitly out of scope?

**Round 3 — Reality**: What happens on failure — who notices, what breaks? Expected scale now vs in a year? What's the ugliest edge case you already know about? What would make you reject the finished work?

Adapt or skip rounds when answers are already known; the rounds are a checklist, not a script.

## Rules of engagement

- Genuinely open questions — never leading questions that smuggle in your preferred design.
- After each round, reflect back what you heard in one short paragraph; wrong reflections surface hidden assumptions cheaply.
- When the user doesn't know an answer, propose a default and mark it as an assumption to validate.
- Timebox it: 2–3 rounds is right for most work. Endless questioning is procrastination with extra steps.

## Alternatives before commitment

Present 2–3 genuinely different approaches (not one real option plus two strawmen), each with one-line wins/costs. Recommend one and say why. Cheap divergence now beats expensive rework later.

## Capture the contract

End by writing a short decisions note (in-repo doc or scratch file):

- Problem and success criteria
- Decisions made, each with its why
- Assumptions to validate
- Out of scope
- Chosen approach and rejected alternatives (one line each)

This note is the session's contract — later disagreement gets resolved against it, not re-argued from memory. Then move to `architect` for the implementation plan, or straight to `writing-code` if the change is small.
