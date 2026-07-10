---
name: repo-setup
description: Ensure a repository has the needed Claude files - project CLAUDE.md, .claude settings and skills for web sessions, gitignore entries. Use when starting work in a repo or when setup is missing.
---

# Repo Setup

Bring a repository up to standard for working with Claude, locally and on the web. Run the checklist; add only what's missing, and confirm with the user before creating files in a repo that isn't theirs alone.

## The checklist

1. **Project `CLAUDE.md`** (root or `.claude/CLAUDE.md`) — the always-loaded facts: what the project is, build/test/run commands with exact invocations, architecture in 3–5 directory bullets, conventions Claude can't guess. Generate a starting point with `/init`, or seed from `~/.claude/CLAUDE-SNIPPET.md` (compact rules block) plus project facts. Keep it under 200 lines; procedures go in skills, not here.
2. **`AGENTS.md` repos** — if the repo already has `AGENTS.md` for other coding agents, don't duplicate: create a `CLAUDE.md` containing `@AGENTS.md` on its first line, then any Claude-specific additions below.
3. **`.claude/settings.json`** (committed) — only if the team wants shared hooks, permission rules, or plugin declarations. Personal overrides go in `.claude/settings.local.json` instead.
4. **Web-session needs** — user-level `~/.claude/` (skills, CLAUDE.md, settings) never carries over to Claude Code on the web; only the repo's own files do. If this repo will be worked on via claude.ai/code: copy the personal skills the repo actually needs into `.claude/skills/`, and make sure the project CLAUDE.md carries the important rules (the snippet covers the core).
5. **`.gitignore`** — add `CLAUDE.local.md` and `.claude/settings.local.json` so personal config never gets committed.
6. **`.mcp.json`** — if the project depends on MCP servers, declare them here (committed) rather than in personal config, so teammates and web sessions get them.

## Verify

- Run `/memory` (or check at next session start) to confirm the CLAUDE.md files load.
- The project CLAUDE.md quickstart claims (build/test commands) must be actually runnable — test them before writing them down.

## Judgment calls

- Team repo: propose the files as a PR like any other change; other people's sessions will load them, so they deserve review.
- Tiny throwaway repo: a 10-line CLAUDE.md (purpose + commands) is enough; don't scaffold ceremony.
- Never commit secrets, tokens, or personal paths into `.claude/` files.
