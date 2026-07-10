---
name: recon
description: Rapidly map an unfamiliar codebase - entry points, data flow, conventions, hotspots - before making changes. Use when onboarding to a repo or starting work in unknown code.
---

# Recon

Build a working mental map of an unknown codebase in minutes, not hours. Recon is done when you can answer three questions: *where would my change go, what could it break, and how is it tested?* Stop there — deeper understanding comes from doing the work, not from more reading.

## Pass 1 — Shape (2–3 minutes)

- README and top-level docs: what does this claim to be?
- Manifest/build files (`package.json`, `pyproject.toml`, `go.mod`, CI config): the dependency list *is* the tech-stack decision record; scripts reveal how it's built, tested, and run.
- Top-level directory names and one level down: the intended architecture, whether or not reality matches.
- Entry points: `main`, server bootstrap, CLI definitions, route registrations.

## Pass 2 — Flow (the highest-value pass)

Pick **one real operation** — an HTTP request, a CLI command, a job — and trace it end to end: entry → routing → business logic → data access → response. One vertical slice teaches more than reading ten modules in isolation, because it shows how the layers *actually* connect, where the abstractions live, and what a typical unit of code looks like.

## Pass 3 — Conventions (how change happens here)

- Read 2–3 recently **merged** PRs or commits: typical change size, test expectations, review culture, files that travel together.
- Read one test file near where you'll work: framework, fixture style, what "tested" means in this repo.
- Note the error-handling and logging dialect — you'll be expected to speak it.

## Finding hotspots when needed

- Churn: `git log --oneline --since="6 months ago" -- <path> | wc -l` per area, or `git log --stat -n 50` — high-churn files are where the action (and the pain) lives.
- Blame the file you'll modify: who touched it recently, and did they leave warnings in commit messages?

## Write the map

Capture 5–10 bullets in a note (scratch file or the eventual handoff doc): purpose, entry points, the traced flow, where your change goes, test command, conventions that surprised you, open questions. Writing it forces the map to be real; the note pays again at handoff time.

## Discipline

- Timebox the whole thing; escalate depth only where your task actually lands.
- Read code in the order of the flow, not alphabetically.
- Broad questions with small answers ("where is auth enforced?") → delegate to a search subagent and keep the conclusion, don't sweep it yourself.
- Distrust docs older than the code they describe; trust tests and recent commits — they can't be stale and still pass.
