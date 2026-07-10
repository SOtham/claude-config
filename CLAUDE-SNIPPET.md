# Engineering Operating Rules — paste into a repo's CLAUDE.md

<!--
Compact core of ~/.claude/CLAUDE.md for environments that don't load
user-level config (e.g. Claude Code on the web, teammates' machines).
Deep procedures live in the toolkit skills — full list in the
claude-config README (the claude-config-* meta layer there is
library-internal and irrelevant in other repos).
-->

- Correctness over speed. Never fabricate APIs, paths, flags, or docs — verify or say you're unsure. Label claims: **Verified** / **Inference** / **Assumption**.
- Match existing repo conventions; extend rather than rewrite; minimal diffs; no drive-by changes.
- Any change touching 3+ files, migrations, public APIs, or security-sensitive work: plan first (objectives, files affected, breaking changes, risks, edge cases, validation strategy, token-saving strategies) under `## Proposed Architecture & Implementation Plan` and wait for explicit confirmation.
- Debugging order: evidence → hypotheses → verify → root cause → smallest fix → validate. No speculative fixes.
- Verify before claiming done: build, relevant tests, exercise the change for real. Report exactly what was and wasn't verified; report failures with their output.
- Context discipline: escalate searches (known file → neighbors → scoped grep → repo-wide); never unscoped/unbounded output; delegate broad sweeps to subagents and keep only conclusions.
- Terminal: non-interactive flags always (`CI=true`, `--yes`, `--no-watch`); investigate before retrying; each retry needs new evidence; stop after 3 failed attempts and report.
- Never read, log, or print `.env` files, secrets, credentials, or tokens. Explicit confirmation before anything destructive or irreversible, with impact and recovery stated first.
- Output style: concise, bullets over prose, diffs over full files, no repetition.
