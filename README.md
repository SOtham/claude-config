# ~/.claude — Personal Claude Setup

Maintained source lives in `C:\Dev\claude-config\`. The files below are symlinked into `~/.claude\` so Claude Code picks them up automatically.

## Layout

```
C:\Dev\claude-config\       ← edit files here
├── CLAUDE.md               # global operating instructions, loaded every session (keep under ~120 lines — budget owned by its maintainer comment)
├── settings.json           # model, effort, enforced permission deny rules (secrets protection)
├── skills/<name>/          # personal skills — CANONICAL, edit SKILL.md here directly
├── sync.ps1                # rebuilds dist/ zips from skills/
├── CLAUDE-SNIPPET.md       # compact rules block to paste into a repo's CLAUDE.md (for web sessions)
└── README.md               # this file

~/.claude\                  ← symlinks only (plus runtime dirs below)
├── CLAUDE.md → C:\Dev\claude-config\CLAUDE.md
├── settings.json → C:\Dev\claude-config\settings.json
├── skills\ → C:\Dev\claude-config\skills\  (junction)
├── sync.ps1 → C:\Dev\claude-config\sync.ps1
├── CLAUDE-SNIPPET.md → C:\Dev\claude-config\CLAUDE-SNIPPET.md
├── README.md → C:\Dev\claude-config\README.md
└── dist/<name>.zip         # built by sync.ps1, not symlinked (generated output)
```

## Skills

Two layers. **Method skills** (generic, no prefix) apply in any repo. **Meta skills** (`claude-config-*`) maintain this config library itself.

**Core method**: writing-code, architect, token-economy, prompt-craft, orchestrate, loops
**Workflow** (from community research 2026-07): brainstorm, test-craft, root-cause, shipping, refactor-safely, handoff, recon, doc-craft
**Setup**: repo-setup (checklist for adding the needed Claude files to a repository)
**Meta** — maintaining this library (added 2026-07): claude-config-architecture (design contract), claude-config-change-control (change gates), claude-config-skill-authoring, claude-config-platform-reference, claude-config-distribution, claude-config-debugging, claude-config-diagnostics (health scripts), claude-config-validation, claude-config-model-uplift (run cheaper models at standard), claude-config-research (eval-harness frontier). Start at `claude-config-change-control` for any change here.

Each is invocable as `/<name>` and auto-loads when relevant. Deliberately not duplicated: Claude Code bundled skills (`/code-review`, `/simplify`, `/verify`, `/security-review`, and `/loop`/`/schedule` — which own *scheduling* recurring runs; the personal `loops` skill owns only the design discipline, per experiment-log entry #4) and Anthropic's official document/frontend skills.

## Editing a skill

Gate the change first per the `claude-config-change-control` skill (classification, non-negotiables, evidence). Then:

1. Edit `skills/<name>/SKILL.md` directly. New local Claude Code sessions pick it up automatically.
2. Run `powershell -ExecutionPolicy Bypass -File "$HOME\.claude\sync.ps1"` to rebuild the zips.
3. Re-upload the changed zip(s) at claude.ai → Settings → Capabilities → Skills (uploaded skills also load into Claude Code web sessions).

Constraints: folder name = frontmatter `name` = zip name; `description` ≤200 chars (claude.ai limit), front-loading *when to use*.

## Web availability (verified)

User-level `~/.claude/` never carries over to Claude Code web sessions. Routes to the web:
- **claude.ai skill upload** (the zips in `dist/`) — loads into web sessions automatically. Primary route.
- **Per-repo**: commit needed `skills/<name>/` folders into a repo's `.claude/skills/` and/or paste `CLAUDE-SNIPPET.md` into its `CLAUDE.md`.
- **Later, if sharing is wanted**: convert skills into a plugin + marketplace repo on GitHub and declare it in repos' `.claude/settings.json`.
