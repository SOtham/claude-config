---
name: claude-config-architecture
description: Design contract of this config library - settings.json/CLAUDE.md/skills layer split, where a new rule belongs, invariants, weak points. Use when placing a rule or questioning the design.
---

# Claude-Config Architecture

The load-bearing design decisions of `C:\Dev\claude-config`, why each was made, the invariants that must always hold, and the weak points stated plainly. This skill owns *why the system is shaped this way* — it contains no runbooks. Mechanics live in `claude-config-distribution`, change gates in `claude-config-change-control`. Judge every architectural question against the purpose in Section 6.

## 1. The system in one picture

```
C:\Dev\claude-config\                     CANONICAL SOURCE — edit here (NOT a git repo)
├── CLAUDE.md / settings.json / sync.ps1 / CLAUDE-SNIPPET.md / README.md
└── skills\<name>\SKILL.md
      │
      │  per-file symlinks + a junction for skills\   (setup commands: claude-config-distribution)
      ▼
~/.claude\                                what local Claude Code actually reads
      ├─► Surface 1 — LOCAL:    sessions read the links; edits are live at next session start
      ├─► Surface 2 — WEB:      sync.ps1 → ~/.claude\dist\<name>.zip → manual upload to
      │                         claude.ai → Settings → Capabilities → Skills
      └─► Surface 3 — PER-REPO: CLAUDE-SNIPPET.md pasted into a repo's CLAUDE.md; needed skills
                                copied into its .claude\skills\   (procedure: repo-setup)
```

A *symlink* is a file-level link the OS resolves transparently; a *junction* is the Windows directory equivalent that needs no admin rights. Verified 2026-07-08: `~/.claude` holds 5 symlinks (`CLAUDE.md`, `settings.json`, `sync.ps1`, `CLAUDE-SNIPPET.md`, `README.md`) plus the `skills` junction, all resolving into `C:\Dev\claude-config`.

| Surface | Delivery | Freshness |
| --- | --- | --- |
| Local Claude Code | `~/.claude` links → canonical files | Automatic — next session start |
| claude.ai + Claude Code web | `dist\` zips, uploaded by hand | Manual — drifts when an upload is skipped |
| Other repos / web sessions per repo | Snippet paste + copied skill folders | Manual per repo — drifts fastest |

## 2. The three-layer split (and where a new rule belongs)

| Layer | Contract | Why this layer exists |
| --- | --- | --- |
| `settings.json` | Machine-ENFORCED: permission `deny` rules and hooks execute in the harness | Some rules (secrets protection, session-start checks) must hold even when a model ignores prose. Enforcement cannot depend on model obedience. |
| `CLAUDE.md` | Always loaded, every session; gates and facts only; budget **~120 lines** | Its own maintainer comment states the doctrine: "every line taxes every session and long files reduce adherence." Currently 104 lines (verified 2026-07-08). |
| `skills/` | On-demand procedures; only the ≤200-char `description` is always visible; the body loads when triggered or invoked as `/<name>` | Procedures are long. Loading them only when relevant keeps the permanent tax near zero and the guidance detailed. |

**Decision rule — ask in order when placing a new rule:**

1. Must it hold even if the model misbehaves (secrets, destructive commands, mandatory automation)? → `settings.json` deny rule or hook. Prose is not enforcement.
2. Is it a standing fact or gate every session needs (environment quirks, planning gate, safety confirmations)? → `CLAUDE.md` — and if that busts the ~120-line budget, cut or merge an existing line first.
3. Is it a repeatable method for a recurring situation? → a skill (authoring method: `claude-config-skill-authoring`).
4. Does only one repository care? → that repo's own `CLAUDE.md` / `.claude\` (procedure: `repo-setup`), not this library.
5. Must it also reach web sessions or shared repos? → skills travel via zip upload; rules via `CLAUDE-SNIPPET.md` / per-repo copies (routes: `claude-config-distribution`).
6. Documentation about this setup itself? → `README.md`.

This decision rule is the single home for rule placement; `claude-config-change-control` §3 points here.

## 3. Deliberate design decisions

| Decision | Rationale | What breaks if violated |
| --- | --- | --- |
| Canonical source lives at `C:\Dev\claude-config`, outside `~/.claude`; `~/.claude` holds only links | One edit surface. `~/.claude` also accumulates runtime churn (generated `dist\`, caches, session state) that would bury hand-maintained files | Edits land in a dead copy; local sessions, zips, and repos silently diverge |
| Links, not copies, into `~/.claude` | Claude Code reads `~/.claude` natively; links deliver canonical files with zero sync steps for the local surface | Replacing a link with a copy freezes that file — sessions load stale config with no error |
| Generic method skills carry no prefix; library-maintenance skills use `claude-config-*` | Method skills (`writing-code`, `architect`, …) apply in any repo and upload for general use; the prefix keeps meta procedures from triggering during ordinary engineering work | Meta skills auto-load into normal coding sessions; routing table gets ambiguous |
| No duplication of Claude Code bundled skills (`/code-review`, `/simplify`, `/verify`, `/security-review`) or Anthropic's official document/frontend skills (README doctrine) | A copy drifts from its maintained upstream and competes with it for triggering | Two skills match one request; the stale copy sometimes wins |
| Rules written as MUST/SHOULD with the reason attached | Models generalize from the *why* (principle: `prompt-craft`); a bare rule is the first thing dropped under context pressure (Assumption — unmeasured until `claude-config-research` M2) | Cargo-cult or abandoned compliance in long sessions |
| Capability-tier language in prose ("highest reasoning tier", "lightweight tier"), never hardcoded model names | The config must outlive model generations without rewrites. The `model` key in `settings.json` is the single deliberate exception — the platform requires a concrete model id there | Instructions rot into references to retired models |

## 4. Invariants — must always hold

Automated checks for these live in `claude-config-diagnostics`; the list here is the contract.

1. Every config file Claude Code reads from `~/.claude` is a link resolving into `C:\Dev\claude-config` (the 5 symlinks + `skills` junction of Section 1). `dist\` is the only generated, non-linked artifact — never hand-edit it.
2. The 9 secrets deny rules in `settings.json` are present and never weakened (full list: `settings.json` / `claude-config-platform-reference` §2).
3. `CLAUDE.md` stays under ~120 lines; procedures do not accumulate there.
4. For every skill: folder name = frontmatter `name` (the YAML block at the top of SKILL.md) = zip name, and `description` ≤200 characters (rationale and recipe: `claude-config-skill-authoring`; platform limits: `claude-config-platform-reference`).
5. One home per fact across the library: siblings cross-reference by name, never carry a second full copy.
6. After any skill edit, `dist\` is rebuilt and changed zips re-uploaded (protocol: `claude-config-change-control`).

## 5. Known weak points — stated plainly

| Weak point | Why it matters | Status | Addressed by |
| --- | --- | --- | --- |
| **Not under version control.** `C:\Dev\claude-config` has no `.git` (verified 2026-07-08) — no history, no diff review, no rollback | The single biggest structural risk: a bad edit is unrecoverable except from memory or ad-hoc backups | open | Nothing yet. Initializing a git repo is a *candidate* remedy — the owner's call. Until then the gates in `claude-config-change-control` are the only protection |
| **Manual zip re-upload to claude.ai** | Web sessions run stale skills whenever an upload is skipped. Observed 2026-07-09: 25 skill folders vs 15 `dist\` zips — re-check with the drift one-liner in Provenance | open | Post-change protocol: `claude-config-change-control`; staleness check: `claude-config-diagnostics` |
| **No adherence eval harness yet** | Config changes ship on judgment, not measurement — no evidence a rule actually improves cheaper-tier behavior | open | Research program: `claude-config-research`; interim spot-checks: `claude-config-validation` |
| **Single-machine setup** | Links are absolute paths on one Windows 11 machine; disk loss means total loss (compounded by no git) | open | Rebuild runbook: `claude-config-distribution` — recreates the structure, not lost content |

## 6. Purpose — the yardstick

Owner statement (2026-07-07): this library exists to transfer top-tier ("Fable-class" — a dated example of the highest reasoning tier) engineering discipline to cheaper-tier sessions, so they work at the same standard when the top tier is unavailable. Judge every architectural choice against one question: **does it change what a lightweight-tier session actually does?** A line no session's behavior depends on fails the test — cut it; a must-hold rule living only in prose fails it too — promote it to enforcement.

## When NOT to use this skill

- Classifying, gating, or shipping a config change → `claude-config-change-control`
- Symlink/junction commands, sync.ps1 anatomy, rebuild-from-scratch, upload steps → `claude-config-distribution`
- Platform facts: loading hierarchy, settings precedence, hook events, upload limits → `claude-config-platform-reference`
- Running or interpreting health checks → `claude-config-diagnostics`
- Writing or editing a skill → `claude-config-skill-authoring`
- A config failure to triage → `claude-config-debugging`

## Provenance and maintenance

Written 2026-07-08; inventory re-verified 2026-07-09: 25 skill folders, 15 zips in `~/.claude\dist`, CLAUDE.md at 104 lines. Counts drift — re-run the one-liners below rather than trusting any snapshot. All commands are PowerShell, tested:

- Links resolve to canonical source: `Get-ChildItem $HOME\.claude | Where-Object { $_.LinkType } | ForEach-Object { "{0} [{1}] -> {2}" -f $_.Name, $_.LinkType, ($_.Target -join ',') }`
- Still no git repo (expect `False`; `True` means the top weak point is closed — update Section 5): `Test-Path C:\Dev\claude-config\.git`
- CLAUDE.md within budget (expect ≤ ~120): `(Get-Content "$HOME\.claude\CLAUDE.md").Count`
- Budget doctrine source: the HTML maintainer comment at the top of `C:\Dev\claude-config\CLAUDE.md`
- Secrets deny rules intact: read `permissions.deny` in `C:\Dev\claude-config\settings.json`
- Skill-vs-zip drift: `(Get-ChildItem "$HOME\.claude\skills" -Directory).Count` vs `(Get-ChildItem "$HOME\.claude\dist" -Filter *.zip).Count`
- Purpose statement: reconfirm with the owner; it is a policy, not a file fact.
