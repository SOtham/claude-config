---
name: claude-config-platform-reference
description: Dated Claude Code platform facts - CLAUDE.md loading, settings precedence, hook events, skills discovery, upload limits, web-vs-local, headless CLI. Use when checking any platform behavior here.
---

# Claude-Config Platform Reference

What the Claude Code platform actually does with this library's files — dated, source-labeled facts, no procedures. **WARNING: platform facts drift. Re-verify against the cited URLs before relying on anything here after a Claude Code version change** (local binary: 2.1.220, re-verified 2026-08-03; was 2.1.195 on 2026-07-08). Source labels: **Docs** = fetched from code.claude.com/docs on 2026-07-08; **Local** = read-only command or file read on this machine; **Repo** = this repo's README/scripts (owner-verified); **Unverified** = check before use.

## 1. Config loading — what enters context, when (as of 2026-07-08)

**CLAUDE.md hierarchy** (Docs: https://code.claude.com/docs/en/memory). Loaded at session start, concatenated broadest-first — later files never override earlier ones, they stack:

1. Managed policy — Windows: `C:\Program Files\ClaudeCode\CLAUDE.md` (not present here)
2. User — `~/.claude/CLAUDE.md` (in this setup a symlink to `<clone>\CLAUDE.md`)
3. Project — `./CLAUDE.md` or `./.claude/CLAUDE.md`, plus every parent directory up the tree from cwd
4. Local — `./CLAUDE.local.md`, appended after `CLAUDE.md` at the same directory level

- Files at or above cwd load **in full at launch**; files in subdirectories load on demand when Claude reads files there (Docs).
- Content arrives as a **user message after the system prompt** — context, not enforcement. Enforcement lives in settings permissions and hooks (Docs).
- `@path/to/file` imports expand at launch, max 4 hops deep; imports organize but do not save context (Docs).
- **HTML comments**: block-level `<!-- ... -->` in CLAUDE.md is stripped before injection (zero token cost); comments inside code blocks are preserved; the Read tool still sees them (Docs — confirms this repo's CLAUDE.md maintainer-note claim).
- Docs size guidance: under 200 lines per file; this repo holds its global file to ~120 (doctrine: `claude-config-architecture`).
- `/memory` lists every loaded file. Project-root CLAUDE.md is re-read and re-injected after `/compact`; nested ones reload only on next file access (Docs).

**settings.json precedence** (Docs: https://code.claude.com/docs/en/settings), highest to lowest: managed → CLI arguments → `.claude/settings.local.json` → `.claude/settings.json` (project) → `~/.claude/settings.json` (user). Exception: **permission rules merge across scopes** rather than override — a project file cannot silently drop a user-level deny.

## 2. settings.json keys used here (values re-read 2026-08-03; Docs semantics as of 2026-07-08)

Current file: `<clone>\settings.json` (Local, re-read 2026-08-03). Semantics per the Docs settings page (not re-fetched since 2026-07-08); none of these keys is marked experimental there.

| Key | Current value | What it does (Docs) |
| --- | --- | --- |
| `autoUpdatesChannel` | `"latest"` | Release channel: `"latest"` or `"stable"` (~1 week older, skips major regressions) |
| `model` | `"opus"` (Local, 2026-08-03) | Default model; `--model` / `ANTHROPIC_MODEL` override per session. Takes either an **alias** or a **full model id** (`--help`: "Provide an alias for the latest model (e.g. 'fable', 'opus', or 'sonnet') or a model's full name (e.g. 'claude-fable-5')" — Local 2026-08-03). Which concrete model an alias resolves to is the platform's current mapping and **moves between releases** — do not treat any resolution as durable; check https://code.claude.com/docs/en/model-config. Historical note (2026-07-08): this key held `"claude-fable-5[1m]"`; the `[1m]` long-context suffix was repo-observed working but **Unverified in docs** |
| `effortLevel` | `"xhigh"` (Local, 2026-08-03) | Persists effort across sessions — five levels, `low`/`medium`/`high`/`xhigh`/`max` (Local `--help` 2026-08-03, matching §7); written by `/effort`; `--effort` / `CLAUDE_CODE_EFFORT_LEVEL` override per session |
| `permissions.deny` | 9 `Read()` rules | Client-enforced blocklist regardless of what the model decides; covers `.env*`, `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `~/.ssh`, `~/.aws`, `~/.claude/.credentials.json` |
| `hooks.SessionStart` | 1 command hook | Section 3. Hooks reload on file change; a `ConfigChange` hook event fires per detected change (Docs) |

Adding a new key: verify it exists on the Docs settings page first, then ship through `claude-config-change-control` — settings.json is the enforced layer, so it carries the highest gate.

## 3. Hooks (as of 2026-07-08)

Docs: https://code.claude.com/docs/en/hooks. ~30 events (30 counted 2026-07-09); the ones most relevant here: `SessionStart`, `PreToolUse` (can block a tool call), `PostToolUse`, `UserPromptSubmit`, `PermissionRequest`, `Stop`, `PreCompact`/`PostCompact`, `ConfigChange`, `SessionEnd` — full list at the URL. Structure: `hooks.<Event>` → array of matcher groups → `hooks` array of handlers (`type`: `command`|`http`|`mcp_tool`|`prompt`|`agent`). `timeout` is in **seconds** (default 600 for command hooks). Exit 0 = success and stdout JSON is processed; exit 2 = blocking error on blockable events — SessionStart is NOT blockable (its stderr just shows to the user).

**The one hook in settings.json** — SessionStart, re-wrapped for reading (the real value is one line; Local read):

```bash
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0;   # not a git repo -> exit 0, hook stays silent
if [ ! -f "$root/CLAUDE.md" ] && [ ! -f "$root/.claude/CLAUDE.md" ]; then   # neither project CLAUDE.md location exists
  echo '{"systemMessage":"This repo has no CLAUDE.md - run /repo-setup to add the Claude files.",
         "hookSpecificOutput":{"hookEventName":"SessionStart",
           "additionalContext":"This repository lacks CLAUDE.md/.claude configuration. Remind the user and offer the repo-setup skill."}}'
fi
```

- No `matcher` → runs on every SessionStart source: `startup`, `resume`, `clear`, `compact` (Docs).
- Output contract (Docs): top-level `systemMessage` renders to the user; `hookSpecificOutput.additionalContext` is injected into Claude's context before the first prompt; `hookEventName` must be `"SessionStart"`. JSON is only processed on exit 0. Plain stdout would also become context for this event, but JSON splits the user-visible and model-visible halves.
- `"timeout": 10` = 10 seconds (Docs: units are seconds).
- Shell: command hooks default to bash; PowerShell only becomes the default on Windows *without* Git Bash (Docs). This machine has Git Bash — Inference: the hook runs under bash, which its `$( )`/`[ -f ]` syntax requires.

## 4. Skills mechanics (as of 2026-07-08)

Docs: https://code.claude.com/docs/en/skills.

- **Discovery locations**: enterprise (managed) → personal `~/.claude/skills/<name>/SKILL.md` → project `.claude/skills/<name>/SKILL.md` → plugin `<plugin>/skills/<name>/SKILL.md` (namespaced `plugin:skill`, cannot collide). On a name collision, enterprise beats personal beats project; any level overrides a bundled skill of the same name. Nested `.claude/skills/` below cwd load on demand; parent directories up to the repo root load too (Docs).
- **Symlinks are supported** for skill directories (Docs) — this is why `~/.claude/skills` being a junction (Windows directory link) to `<clone>\skills` works; Local: this session loaded skills through it.
- **Frontmatter the platform reads** — frontmatter is the YAML block between `---` lines atop SKILL.md (all fields optional; `description` recommended): `name` is display-only — the **directory name** is the `/command` name, which is why this repo pins folder = name (see `claude-config-skill-authoring`). Other fields: `description`, `when_to_use`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `paths`, `model`, `effort`, `context: fork` + `agent`, `hooks`, `argument-hint`, `arguments`, `shell`. Full table at the URL. Malformed YAML → body still loads with empty metadata, so `/name` works but auto-loading breaks (Docs).
- **When context is spent**: every skill's name+description sits in context all session (per-entry cap 1,536 chars of `description`+`when_to_use` combined; the whole listing is budgeted at ~1% of the context window — `/doctor` reports truncation). The **body** loads only on invocation — you typing `/name`, or Claude matching the description — and then stays in context for the rest of the session. After compaction, each invoked skill is re-attached up to 5,000 tokens within a 25,000-token shared budget, most-recent first (Docs).
- **Live edits**: changes under `~/.claude/skills/` take effect within the current session (Docs; this repo's README states the weaker "new sessions pick it up" — both hold).

## 5. claude.ai upload constraints (as of 2026-07-09)

These are claude.ai-side, NOT Claude Code platform limits — they do not appear in the Claude Code docs. Upload UI path: **Settings > Capabilities** per claude.com/docs/skills/how-to ("Enable the skill in **Settings > Capabilities**"); the support help center instead says "Customize > Skills" — the UI label drifts between surfaces/versions, so treat the exact leaf as volatile.

- `description` 200 characters — docs-advised (claude.com/docs/skills/how-to warning: "Claude.ai limits descriptions to 200 characters", fetched 2026-07-09) but **NOT enforced at upload: a 201-char description was accepted and displayed verbatim, un-truncated (verified 2026-07-10, real upload + skills-list display)**. Unknown: whether trigger-time processing truncates internally, and where enforcement begins (500? 1024?). House rule stays **≤200** (docs-aligned, keeps triggers tight, safe against Claude Code's own 250-char listing truncation — GitHub anthropics/claude-code #40121). The Agent Skills spec and API allow 1024.
- Zip layout: the skill **folder at the zip root**, with **forward-slash** entry paths (Repo: `sync.ps1` header). Backslash incident and rationale: `claude-config-distribution` §3, which also owns the rebuild/upload runbook.
- Folder name = frontmatter `name` = zip name, or local skill and upload stop matching (Repo: README; rationale in `claude-config-skill-authoring`).
- **BOM rejection — verified 2026-07-10 by real upload:** a SKILL.md beginning with a UTF-8 BOM is rejected with "SKILL.md must start with YAML frontmatter (---)" — claude.ai's parser does not strip BOMs. PS 5.1's `Out-File -Encoding utf8` writes a BOM; build upload files BOM-less (`[IO.File]::WriteAllText` with `UTF8Encoding($false)`, or python `encoding='utf-8'`). The library's 25 SKILL.md files were scanned clean that day. The library now holds **27** (Local, 2026-08-03), so a re-scan covers 2 files never checked for a BOM.
- Reject-vs-truncate at 201 chars: **RESOLVED 2026-07-10 — neither.** Accepted verbatim (see the description bullet above). Attempt 1 was rejected pre-length by the BOM (previous bullet); the BOM-less retry uploaded clean. Full test record: `references/upload-limit-test.md`.

## 6. Web vs local availability — load-bearing (as of 2026-07-08)

**User-level `~/.claude/` (CLAUDE.md, settings.json, skills) NEVER reaches Claude Code web sessions** (Repo: README "Web availability (verified)" — owner-verified by testing; the fetched docs do not contradict it). The three routes that do reach the web:

1. **claude.ai skill upload** (the `dist/*.zip` files) — uploaded skills also load into Claude Code web sessions. Primary route.
2. **Per-repo**: commit the needed `skills/<name>/` folders into the repo's `.claude/skills/` and/or paste `CLAUDE-SNIPPET.md` into its `CLAUDE.md` (procedure: `repo-setup`).
3. **Plugin + marketplace repo** declared in repos' `.claude/settings.json` — candidate, not built (see `claude-config-distribution`).

Consequence: any behavior this library must guarantee in web sessions has to travel route 1 or 2. Never assume the global CLAUDE.md, settings.json deny rules, or the SessionStart hook exist there.

## 7. Headless / programmatic use (flags re-verified 2026-08-03; Docs half as of 2026-07-08)

Verified two ways: running `--help` on the local binary — **v2.1.220, re-run 2026-08-03** (Local; note `claude` was not on PATH in this session's shells — the binary lives at `$env:USERPROFILE\.local\bin\claude.exe`) — and Docs https://code.claude.com/docs/en/headless (last fetched 2026-07-08, **not** re-fetched since). Every flag below is still present in 2.1.220 `--help`; one changed its accepted values (see `--permission-mode`). Flags confirmed in both unless noted:

- `-p, --print` — non-interactive: print response and exit; reads stdin (piped input capped at 10MB — Docs).
- `--output-format text|json|stream-json` — `json` returns `result`, `session_id`, `total_cost_usd` (Docs) → machine-gradable runs.
- `--json-schema '<schema>'` — schema-validated output in the `structured_output` field.
- `--allowedTools` / `--disallowedTools` (permission-rule syntax) and `--permission-mode` (`acceptEdits`|`auto`|`bypassPermissions`|`manual`|`dontAsk`|`plan` — Local `--help` 2026-08-03) — unattended runs without prompts. **Changed since 2026-07-08**: v2.1.195 listed `default` where v2.1.220 lists `manual`. Inference (from the `--help` choice list alone): a rename. Whether `default` is still accepted as an alias, and whether `manual` behaves identically, is **Unverified** — neither was executed.
- `-c/--continue`, `-r/--resume <id>`, `--session-id <uuid>` — multi-turn scripting; capture `session_id` from JSON output.
- `--model <model>`, `--effort low|medium|high|xhigh|max` (Local `--help` 2026-08-03 — five levels; §2's `effortLevel` row must match this list) — pin the capability tier under test.
- `--settings <file-or-json>`, `--setting-sources user,project,local` — control which config layers load.
- `--bare` — skips hooks, LSP, plugin sync, auto-memory, keychain reads, and CLAUDE.md auto-discovery, and sets `CLAUDE_CODE_SIMPLE=1`; skills still resolve via `/skill-name` (Local `--help` 2026-08-03 + Docs) → the clean **baseline** arm of an adherence eval; the with-config arm omits it. Adjacent, and newly noted 2026-08-03 (Local `--help`, **not** in the 2026-07-08 Docs fetch): `--safe-mode` disables *all* customizations — CLAUDE.md, skills, plugins, hooks, MCP, agents — while managed policy settings still apply; a broader kill-switch than `--bare`, untested here.
- `--max-budget-usd <amount>` (print mode only — Local `--help`) — spend cap per run.

Eval design on top of these flags (predict-first discipline, with/without comparison, milestones) is owned by `claude-config-research`.

## When NOT to use this skill

- Writing or editing a skill → `claude-config-skill-authoring`
- Rebuilding zips/symlinks, sync.ps1 anatomy, upload steps → `claude-config-distribution`
- A config file isn't taking effect, something broke → `claude-config-debugging`
- Whether a change is allowed and how to ship it → `claude-config-change-control`
- Why the three-layer design exists → `claude-config-architecture`

## Provenance and maintenance

Facts are dated **2026-07-08** unless a later date is given inline; local Claude Code **2.1.220** (`claude --version`, Local 2026-08-03 — was 2.1.195 on 2026-07-08).

- **Re-verified 2026-08-03 (Local):** binary version; §2 settings values (`model`, `effortLevel`, `autoUpdatesChannel`, 9 deny rules, 1 SessionStart hook); §7 headless flags via `--help`; §5 skill-file count.
- **NOT re-verified — still 2026-07-08/09:** every fact labelled **Docs**. No docs page was re-fetched on 2026-08-03, so §§1, 3, 4, 5, 6 rest on a fetch that is now 25 binary releases old. Treat drift there as likely, not merely possible.
- **The old ≥ v2.1.196 caveat is obsolete.** The docs gate some behavior (e.g. `${CLAUDE_PROJECT_DIR}` substitution in skill bodies) at ≥ v2.1.196; 2.1.195 predated that gate, but **2.1.220 meets it**, so version-parity is no longer the blocker. The substitution behavior itself is **Unverified** on this binary — meeting a version gate is not the same as having tested the feature, and nothing here exercised it.

Re-verify per fact:

- CLAUDE.md loading order, HTML-comment stripping, imports, compaction survival: re-fetch https://code.claude.com/docs/en/memory
- Settings precedence + key semantics: re-fetch https://code.claude.com/docs/en/settings
- Hook events, SessionStart contract, timeout units, exit codes: re-fetch https://code.claude.com/docs/en/hooks
- Skills discovery, frontmatter table, 1,536-char cap and listing budget, body lifecycle: re-fetch https://code.claude.com/docs/en/skills
- Headless flags: re-fetch https://code.claude.com/docs/en/headless and run (PowerShell) `& "$env:USERPROFILE\.local\bin\claude.exe" --help`
- Local version: (PowerShell) `& "$env:USERPROFILE\.local\bin\claude.exe" --version`
- Current settings values and the hook command: read `<clone>\settings.json`
- 200-char upload limit: docs-verified at https://claude.com/docs/skills/how-to (re-fetch to confirm still 200); reject-vs-truncate mechanism still undocumented — a real upload of a 201-char description is the definitive test. Zip layout: `sync.ps1` header. Upload UI path drifts (docs: Settings > Capabilities; help center: Customize > Skills) — re-check in-product.
- Web-vs-local finding: README "Web availability (verified)"; re-test by opening a Claude Code web session and checking whether personal skills appear
