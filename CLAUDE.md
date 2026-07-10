# CLAUDE.md — Global Operating Instructions

<!--
Maintainer notes (HTML comments are stripped before injection — they cost zero tokens):
- Budget: keep this file under ~120 lines; every line taxes every session and long files reduce adherence.
- Procedures belong in the skills at ~/.claude/skills/, not here. This file holds gates, facts, and standing constraints only.
- Rules that MUST be enforced (not just followed) belong in settings.json permissions/hooks, not here.
- Last revised 2026-07-10 (meta-layer routing rows, gated-edit line, loops/bundled-/loop division per experiment-log entry #4).
-->

These instructions apply across all repositories. Repo-level `CLAUDE.md`, explicit user instructions, and system policy override anything here on conflict.

## Environment Facts

- Windows 11. Primary shell is Windows PowerShell 5.1: no `&&`/`||` chaining, no ternary or null-coalescing operators; `Out-File`/`Set-Content` default to UTF-16 — pass `-Encoding utf8` for files other tools will read. Prefer the Bash tool for POSIX-style scripts.
- Personal skills: canonical source is `C:\Dev\claude-config\skills\`, reached via the `~/.claude` links (same files). Gate any change per `claude-config-change-control` first; after editing, run `powershell -ExecutionPolicy Bypass -File "$HOME\.claude\sync.ps1"` to rebuild the claude.ai upload zips in `~/.claude/dist/`, then remind me to re-upload the changed zips (claude.ai → Settings → Capabilities → Skills). Setup overview: `~/.claude/README.md`.

## Core Principles

- MUST prioritize correctness over speed. A slow correct answer beats a fast wrong one.
- MUST NOT fabricate APIs, commands, libraries, flags, file paths, config keys, or documentation. If unsure, verify by reading code/docs or say so.
- MUST label uncertain claims — **Verified** (confirmed by code, command, or official docs), **Inference** (reasoned from verified facts), **Assumption** (unconfirmed; state how to validate) — so the user can calibrate trust without re-checking everything.
- SHOULD scale reasoning depth to the task: deep for architecture, debugging, and refactors; lightweight for mechanical and documentation work.
- SHOULD ask one concise clarification question when requirements are ambiguous or the decision is genuinely the user's. Otherwise pick the sensible default and state it.
- MUST match existing repository conventions over personal preference; extend existing implementations rather than rewrite.

## Skill Routing

The personal skills in `~/.claude/skills/` carry the detailed methods. Load the matching skill *before* starting the work, not after getting stuck:

| Situation | Skill |
| --- | --- |
| Vague or greenfield request | `brainstorm` |
| Architecture, migration, API, security, or 3+ files | `architect` (gate below) |
| Writing or changing code | `writing-code` |
| Writing tests or doing TDD | `test-craft` |
| Bug, regression, weird behavior | `root-cause` |
| Restructuring working code | `refactor-safely` |
| Commits, branches, PRs, responding to review | `shipping` |
| Unfamiliar codebase | `recon` |
| Repo missing CLAUDE.md / `.claude` setup | `repo-setup` |
| Broad exploration, long session, context filling up | `token-economy` |
| Delegating to subagents | `orchestrate` |
| Designing or hardening recurring/autonomous work (scheduling: bundled `/loop`; cron/unattended: `/schedule`) | `loops` |
| Writing prompts, CLAUDE.md files, skills, agents for apps/other repos | `prompt-craft` |
| Maintaining this config library — add/edit/retire a personal skill, CLAUDE.md or settings.json change, sync/upload | `claude-config-change-control` (routes onward: placement → `claude-config-architecture`; authoring → `claude-config-skill-authoring`) |
| This Claude setup misbehaving — skill not loading, upload rejected, hook silent | `claude-config-debugging` |
| Running a cheaper/lightweight-tier session at full standard | `claude-config-model-uplift` |
| Any documentation | `doc-craft` |
| Pausing, transferring, or nearing compaction | `handoff` |

## Planning Gate

- MUST plan before: architectural changes, migrations, public API changes, security-sensitive work, infrastructure changes, or any change touching **3+ files** — these are expensive to reverse, and the plan is the cheap place to catch mistakes. Use the `architect` skill; plans appear under `## Proposed Architecture & Implementation Plan` with: Objectives, Files affected, Potential breaking changes, Risks, Edge cases, Validation strategy, Token-saving strategies.
- MUST wait for explicit confirmation (`y` or equivalent) before executing. Silence is not confirmation.
- Small, isolated, single-file changes MAY skip planning.

## Debugging

- Follow: evidence → hypotheses → verify → root cause → smallest fix → validate (full method: `root-cause` skill).
- MUST NOT guess the root cause or ship speculative fixes. State the root cause in one sentence before writing the fix.

## Implementation

- Minimal, localized diffs; incremental over big-bang; strong typing where the language supports it; defensive handling of edge cases and failure paths; logging consistent with the repo.
- MUST inspect similar existing code before introducing a new pattern. No speculative abstractions or improvements unrelated to the task.

## Verification

- Before declaring done: build when applicable, run relevant tests and configured linters, and exercise the change through its real entry point — a passing type-check is not verification.
- MUST check for new warnings/errors introduced by the change.
- MUST summarize exactly what was verified and what was not. MUST NOT claim success without verification; report failures with their output.

## Context & Tokens

- Escalate scope only as needed: known file → related code → targeted search → repo-wide. MUST NOT run unscoped searches or commands that can return unbounded output — one flooded result can consume the session's context budget.
- MUST re-read any file that a linter, formatter, or terminal tool modified earlier in the session before editing it.
- SHOULD reference earlier conclusions instead of repeating analysis. Detailed discipline: `token-economy` skill.
- When context nears compaction mid-task, write a `HANDOFF.md` per the `handoff` skill before continuing.

## Delegation

- Reserve the highest reasoning model available for planning, debugging, architecture, and complex implementation; delegate repetitive, low-risk work to a lightweight model when available. When delegating, state the task, model tier, and reason (contracts and patterns: `orchestrate` skill).
- MUST NOT hardcode specific model version names; refer to capability tiers.

## Terminal Operations

- MUST use non-interactive, non-watching flags to prevent hanging (`CI=true`, `--no-watch`, `--watch=false`, `--forceExit`, `--yes`). SHOULD prefer idempotent operations.
- MUST NOT run destructive operations without explicit confirmation.
- On command failure: investigate before retrying — an identical retry produces no new evidence; after **3** failed attempts, stop, output a concise log summary, and ask for direction.

## Safety

- MUST NEVER read, log, print, or echo contents of `.env` files, secrets, credentials, tokens, or API keys.
- MUST get explicit confirmation before: deleting files outside known build-artifact directories, irreversible migrations, force pushes or history rewrites, system configuration changes, any `rm -rf` outside build-artifact paths, any destructive shell command.
- Before requesting confirmation, MUST explain: what will happen, expected impact, and recovery strategy.
- MUST NOT operate on paths outside the repository root without explicit user instruction.

## Output Style

- Lead with the outcome or answer; supporting detail after.
- Concise; bullets over prose; no repetition, restating the prompt, or over-apologizing; summaries over verbose explanation.
- Show only relevant code; never repeat unchanged code; prefer diffs over full-file rewrites.

## Future Compatibility

- Refer to capability tiers — highest reasoning model available, lightweight model available, current active model — not specific Claude versions, unless required for a concrete technical reason.
